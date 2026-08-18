from __future__ import annotations

from dataclasses import dataclass
import re
from datetime import date, timedelta
from typing import Iterable, Sequence

import json
import os

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

import httpx

from app.core.config import settings
from app.models.journal import JournalEntry
from app.schemas.journal import RiskInsight, SentimentInsight

print(">>> LOADED journal_risk.py FROM:", __file__)


# ================================================================
#  Global toggle: which sentiment engine to use
# ================================================================
# True  = use LLM-based sentiment analysis
# False = use heuristic v2.0
USE_LLM_SENTIMENT = True
# True = use LLM to extract event triggers from note text
USE_LLM_TRIGGERS = True

# Ollama model + endpoint (override via env)
LLM_MODEL_NAME = (
    os.getenv("OLLAMA_MODEL_NAME")
    or os.getenv("LLM_MODEL_NAME")
    or "gemma:2b"
)
OLLAMA_ENDPOINT = os.getenv("OLLAMA_ENDPOINT") or settings.ollama_endpoint


# ================================================================
#  Emotion Tags v1.0 — 12 primary emotion tags + parameters
# ================================================================
# valence: -1 ~ +1,  arousal: -1 ~ +1
EMOTION_TAG_PARAMS: dict[str, dict[str, float]] = {
    # Positive
    "joy": {"valence": 0.9, "arousal": 0.6},
    "excitement": {"valence": 0.8, "arousal": 0.9},
    "calm": {"valence": 0.7, "arousal": -0.3},
    "safety": {"valence": 0.6, "arousal": -0.2},
    "content": {"valence": 0.8, "arousal": 0.1},
    # Negative
    "sadness": {"valence": -0.8, "arousal": -0.3},
    "anxiety": {"valence": -0.6, "arousal": 0.7},
    "anger": {"valence": -0.7, "arousal": 0.8},
    "fatigue": {"valence": -0.5, "arousal": -0.5},
    "stress": {"valence": -0.6, "arousal": 0.5},
    "disappointment": {"valence": -0.7, "arousal": -0.1},
}

POSITIVE_EMOTION_TAGS = {"joy", "excitement", "calm", "safety", "content"}
NEGATIVE_EMOTION_TAGS = {
    "sadness",
    "anxiety",
    "anger",
    "fatigue",
    "stress",
    "disappointment",
}


# ----------------------------------------------------------------
#  Simple keyword dictionaries for heuristic sentiment analysis
# ----------------------------------------------------------------
POSITIVE_KEYWORDS = {
    "grateful",
    "gratitude",
    "hopeful",
    "proud",
    "relieved",
    "peaceful",
    "excited",
    "happy",
    "joy",
    "satisfied",
    "content",
    "calm",
}

NEGATIVE_KEYWORDS = {
    "lonely",
    "useless",
    "worthless",
    "stressed",
    "stress",
    "anxious",
    "anxiety",
    "tired",
    "exhausted",
    "burnout",
    "burned out",
    "sad",
    "depressed",
    "angry",
    "afraid",
    "scared",
    "panic",
    "panicking",
    "overwhelmed",
    "fail",
    "failing",
    "failure",
    "disappointed",
    "disappointment",
}

# Red-flag phrases — if they appear, we pay special attention
CRITICAL_KEYWORDS = {
    "suicide",
    "kill myself",
    "end my life",
    "self-harm",
    "self harm",
    "cut myself",
    "hurt myself",
    "can't go on",
    "cannot go on",
    "don't want to live",
    "dont want to live",
    "want to die",
    "wish i was dead",
}


# =====================================================================
#  Helper functions
# =====================================================================
def _keyword_root(word: str) -> str:
    """
    Very rough stemming to avoid double-counting (e.g. stress/stressed/stressing).
    """
    w = word.lower().strip()
    for suffix in ("ness", "ed", "ing", "s"):
        if w.endswith(suffix) and len(w) > len(suffix) + 2:
            return w[: -len(suffix)]
    return w


def _count_critical_keywords(text: str) -> int:
    text = text.lower()
    return sum(1 for kw in CRITICAL_KEYWORDS if kw in text)


# =====================================================================
#  Trigger labels & keyword fallbacks (fixed label set)
# =====================================================================

# Canonical trigger labels used across the system.
# Final stored triggers will always be a subset of this list.
ALLOWED_TRIGGER_LABELS = [
    "exam",
    "assignment",
    "presentation",
    "workload",
    "family",
    "friends",
    "relationship",
    "money",
    "health",
    "sleep",
    "future",
    "social",
    "study",
    "meeting",
    "conflict",
    "interview",
    "performance",
    "travel",
    "alone_time",
    "unknown",
]

# Keyword mapping for both:
# - pure keyword fallback (no LLM)
# - mapping LLM-selected text spans into one of the canonical labels.
EVENT_KEYWORDS: dict[str, set[str]] = {
    "exam": {"exam", "test", "midterm", "final", "quiz"},
    "assignment": {"assignment", "homework", "project", "report", "submission"},
    "presentation": {"presentation", "slides", "ppt"},
    "workload": {
        "deadline",
        "deliverable",
        "due",
        "workload",
        "overtime",
        "too much work",
        "so much work",
        "busy with work",
        "redo everything",
        "redoing",
        "lost my work",
        "lost work",
    },
    "family": {"family", "parents", "mum", "dad", "mother", "father"},
    "friends": {"friend", "friends", "buddy", "classmate", "roommate"},
    "relationship": {"girlfriend", "boyfriend", "partner", "crush", "dating"},
    "money": {"money", "broke", "salary", "allowance", "loan", "debt"},
    "health": {"sick", "ill", "flu", "covid", "hospital", "doctor", "clinic"},
    "sleep": {"sleep", "insomnia", "couldn't sleep", "couldnt sleep", "too tired"},
    "future": {"future", "career", "job", "internship", "graduation"},
    "social": {"party", "gathering", "dinner", "hangout", "meetup", "gift"},
    "study": {"study", "studying", "revision", "library"},
    "meeting": {"meeting", "standup", "sync"},
    "conflict": {"argue", "argument", "conflict", "fight"},
    "interview": {"interview"},
    "performance": {
        "performance",
        "rehearsal",
        "edit",
        "editing",
        "recording",
        "video",
    },
    "travel": {"travel", "trip", "flight", "train", "bus"},
    "alone_time": {"alone", "solo"},
}


def _extract_event_triggers_keyword(text: str) -> list[str]:
    """
    Pure keyword-based extraction from the full note text.
    Used as a fallback when LLM trigger extraction fails or is empty.
    """
    t = text.lower()
    found: set[str] = set()
    for label, keywords in EVENT_KEYWORDS.items():
        if any(k in t for k in keywords):
            found.add(label)
    # Always return in sorted order for consistency
    return sorted(found)


def _extract_json_object(text: str) -> str:
    """
    Best-effort extraction of the first JSON object from a text response.
    Used when the LLM returns extra explanation around the JSON.
    """
    start = text.find("{")
    end = text.rfind("}")
    if start == -1 or end == -1 or end <= start:
        raise ValueError("No JSON object found in LLM response.")
    return text[start : end + 1]


# =====================================================================
#  User-specific trigger learning (Option 2)
# =====================================================================

# In-memory per-user trigger preferences.
# Example structure:
# {
#   "user_primary": {
#       "unknown": {"money": 3, "workload": 1},
#       "health": {"future": 2},
#   }
# }
USER_TRIGGER_PREFERENCES: dict[str, dict[str, dict[str, int]]] = {}

# Minimum times a user must override (auto_label -> manual_label)
# before we auto-apply this preference in future analyses.
USER_TRIGGER_PREF_THRESHOLD = 2


def _normalize_trigger_label(label: str) -> str:
    """Normalize a single trigger label into canonical form."""
    l = str(label).strip().lower()
    if not l:
        return ""
    if l not in ALLOWED_TRIGGER_LABELS:
        # Anything unknown / custom is treated as "unknown" category
        return "unknown"
    return l


def _normalize_trigger_list(triggers: Iterable[str] | None) -> list[str]:
    """
    Normalize a list of trigger labels:
    - lowercased
    - strip spaces
    - filter to allowed labels
    - deduplicate, keep order
    """
    if not triggers:
        return []

    seen: set[str] = set()
    result: list[str] = []

    for t in triggers:
        norm = _normalize_trigger_label(t)
        if not norm:
            continue
        if norm in seen:
            continue
        seen.add(norm)
        result.append(norm)

    return result


def _update_user_trigger_preferences(
    *,
    user_id: str,
    auto_triggers: Iterable[str],
    manual_triggers: Iterable[str],
) -> None:
    """
    Learn from a mismatch between auto-detected triggers and
    user-selected triggers for a single entry.

    - We only store relationships in label space, not raw text.
    - Example: auto=["unknown"], manual=["money"]
      → USER_TRIGGER_PREFERENCES[user]["unknown"]["money"] += 1
    """
    auto_norm = _normalize_trigger_list(auto_triggers)
    manual_norm = _normalize_trigger_list(manual_triggers)

    if not auto_norm or not manual_norm:
        return

    user_stats = USER_TRIGGER_PREFERENCES.setdefault(user_id, {})

    for auto_label in auto_norm:
        stats_for_auto = user_stats.setdefault(auto_label, {})
        for manual_label in manual_norm:
            if manual_label == auto_label:
                # same label, no conflict → no need to learn
                continue
            stats_for_auto[manual_label] = stats_for_auto.get(manual_label, 0) + 1


def _apply_user_trigger_preferences(
    *,
    user_id: str,
    auto_triggers: Iterable[str],
) -> list[str]:
    """
    When there is NO explicit manual override in this call,
    use the user's historical preference (if strong enough) to
    adjust the auto triggers.

    For each auto_label:
    - if user has often changed this label to some manual_label
      and count >= USER_TRIGGER_PREF_THRESHOLD, we replace it.
    """
    auto_norm = _normalize_trigger_list(auto_triggers)
    if not auto_norm:
        return []

    user_stats = USER_TRIGGER_PREFERENCES.get(user_id)
    if not user_stats:
        return auto_norm

    adjusted: list[str] = []

    for auto_label in auto_norm:
        stats_for_auto = user_stats.get(auto_label)
        if not stats_for_auto:
            adjusted.append(auto_label)
            continue

        # Find the manual label with highest count
        best_label, best_count = max(stats_for_auto.items(), key=lambda kv: kv[1])
        if best_count >= USER_TRIGGER_PREF_THRESHOLD:
            adjusted.append(best_label)
        else:
            adjusted.append(auto_label)

    # Deduplicate while preserving order
    seen: set[str] = set()
    final: list[str] = []
    for lbl in adjusted:
        if lbl in seen:
            continue
        seen.add(lbl)
        final.append(lbl)

    return final


@dataclass(slots=True)
class JournalAnalysisResult:
    sentiment: SentimentInsight
    risk: RiskInsight


# =====================================================================
#  Public entrypoint: sentiment + risk (with last 7 days history)
# =====================================================================
async def analyse_journal_note(
    *,
    session: AsyncSession,
    user_id: str,
    user_mood: int,
    note: str,
    tags: Iterable[str],
    entry_date: date,
    manual_triggers: Iterable[str] | None = None,
) -> JournalAnalysisResult:
    """
    1) Run sentiment analysis (LLM by default, or heuristic v2.0)
    2) Query the user's last 7 days of JournalEntry as historical context
    3) Run risk engine v3.0 combining mood + tags + sentiment + history
    4) (Optional) Apply user-provided manual triggers + update preferences
    """
    # 1. Sentiment analysis
    if USE_LLM_SENTIMENT:
        sentiment = await _run_sentiment_llm(note=note, mood=user_mood, tags=tags)
    else:
        sentiment = _run_sentiment_v2(note=note, mood=user_mood, tags=tags)

    # 2. Last 7 days history
    since = entry_date - timedelta(days=6)
    stmt = (
        select(JournalEntry)
        .where(
            JournalEntry.user_id == user_id,
            JournalEntry.entry_date >= since,
            JournalEntry.entry_date <= entry_date,
        )
        .order_by(JournalEntry.entry_date)
    )
    result = await session.execute(stmt)
    history: Sequence[JournalEntry] = list(result.scalars())

    # 3. Risk scoring (+ trigger logic)
    risk = await _run_risk_engine_v3(
        user_id=user_id,
        mood=user_mood,
        note=note,
        tags=tags,
        sentiment=sentiment,
        history=history,
        manual_triggers=manual_triggers,
    )

    return JournalAnalysisResult(sentiment=sentiment, risk=risk)


# =====================================================================
#  LLM-based sentiment analysis (Ollama)
# =====================================================================
async def _run_sentiment_llm(
    *,
    note: str,
    mood: int,
    tags: Iterable[str],
) -> SentimentInsight:
    print("\n===== [LLM TEST] _run_sentiment_llm CALLED (Ollama) =====\n")

    if not OLLAMA_ENDPOINT:
        print("[LLM] Missing OLLAMA_ENDPOINT → using heuristic fallback")
        return _run_sentiment_v2(note=note, mood=mood, tags=tags)

    tags_clean = [t.strip().lower() for t in tags if t.strip()]

    system_instruction = (
        "You are an assistant for a mental health journaling system. "
        "Your job is to analyse the emotional tone of the user's note. "
        "You MUST output ONLY valid JSON, with no extra text."
    )

    user_prompt = f"""
{system_instruction}

Consider this journal entry:

- Mood rating (1=very happy, 5=very unhappy): {mood}
- Emotion tags: {tags_clean}
- Text: {note!r}

Return a JSON object with:
- "label": one of "positive", "neutral", or "negative"
- "confidence": a float between 0 and 1
- "scores": an object with keys "positive", "neutral", "negative"
  whose values are probabilities that sum to ~1.0

Example:
{{
  "label": "negative",
  "confidence": 0.92,
  "scores": {{
    "positive": 0.05,
    "neutral": 0.10,
    "negative": 0.85
  }}
}}

Output ONLY JSON.
""".strip()

    payload = {
        "model": LLM_MODEL_NAME,
        "prompt": user_prompt,
        "stream": False,
        "options": {"temperature": 0.0},
    }

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(OLLAMA_ENDPOINT, json=payload)
            resp.raise_for_status()
            data = resp.json()
            raw = (data.get("response") or "").strip()
            if not raw:
                raise ValueError("Empty response from Ollama")

            try:
                parsed = json.loads(raw)
            except Exception:
                parsed = json.loads(_extract_json_object(raw))
    except httpx.TimeoutException:
        print("[LLM] Request timeout → fallback to heuristic")
        return _run_sentiment_v2(note=note, mood=mood, tags=tags)
    except httpx.HTTPStatusError as e:
        print(f"[LLM] HTTP Error {e.response.status_code}: {e.response.text}")
        print("[LLM] → fallback to heuristic")
        return _run_sentiment_v2(note=note, mood=mood, tags=tags)
    except Exception as e:
        print(f"[LLM] Error ({type(e).__name__}): {e}")
        print("[LLM] → fallback to heuristic")
        return _run_sentiment_v2(note=note, mood=mood, tags=tags)

    # --- clean & normalize ---
    label = str(parsed.get("label", "neutral")).lower()
    if label not in {"positive", "neutral", "negative"}:
        label = "neutral"

    confidence = float(parsed.get("confidence", 0.7))
    confidence = max(0.0, min(1.0, confidence))

    scores = parsed.get("scores", {}) or {}
    pos = float(scores.get("positive", 0.33))
    neu = float(scores.get("neutral", 0.34))
    neg = float(scores.get("negative", 0.33))

    total = pos + neu + neg
    if total > 0:
        pos /= total
        neu /= total
        neg /= total

    return SentimentInsight(
        label=label,
        confidence=round(confidence, 3),
        scores={
            "positive": round(pos, 3),
            "neutral": round(neu, 3),
            "negative": round(neg, 3),
        },
        version="sentiment-llm-ollama-v1.0",
    )


# =====================================================================
#  LLM-based event trigger extraction (Ollama) — Option B
# =====================================================================
async def _extract_event_triggers_llm(
    *,
    note: str,
    mood: int,
    tags: Iterable[str],
) -> list[str]:
    """
    Use the same Ollama model to extract 1–3 concrete event spans,
    then map each span into ONE canonical trigger label using our own
    keyword rules.

    IMPORTANT:
    - We completely ignore the LLM's "label" field.
      LLM is only used to highlight short text spans from the note.
    - Each span must be a substring of the original note.
    - Final triggers are always a subset of ALLOWED_TRIGGER_LABELS.
    """
    if not OLLAMA_ENDPOINT:
        raise ValueError("Missing OLLAMA_ENDPOINT")

    # This list is only used as a hint in the prompt; final labels
    # are always computed locally from EVENT_KEYWORDS.
    preferred_labels = list(EVENT_KEYWORDS.keys()) + [
        "study",
        "travel",
        "alone_time",
        "unknown",
    ]

    prompt = f"""
You are extracting event triggers from a mental health journal entry.

Step 1 — Find situations:
- Read the user's journal entry.
- Identify up to 3 concrete situations or events explicitly mentioned in the text.
  Examples: "upcoming midterm exam", "argument with my parents",
  "scrolling TikTok until 3am", "dinner with friends".

Step 2 — Mark spans:
- For each situation, return a short "text" span that is copied exactly
  from the original note (continuous substring, no paraphrase).
- You may also propose a short label, but it will only be used as a hint.

Rules:
- The "text" field MUST come directly from the original note (no invented text).
- If the entry has no clear situation, return an empty list.

Return ONLY JSON in this format:
{{
  "events": [
    {{"text": "...", "label": "exam"}},
    {{"text": "...", "label": "sleep"}}
  ]
}}

Entry:
- Mood (1 very happy, 5 very unhappy): {mood}
- User tags: {list(tags)}
- Note: {note}
""".strip()

    payload = {
        "model": LLM_MODEL_NAME,
        "prompt": prompt,
        "stream": False,
        "options": {"temperature": 0.0},
    }

    async with httpx.AsyncClient(timeout=20.0) as client:
        resp = await client.post(OLLAMA_ENDPOINT, json=payload)
        resp.raise_for_status()
        data = resp.json()

    raw = (data.get("response") or "").strip()
    print(f"[TRIGGERS/LLM] raw response: {raw[:200]}...")
    if not raw:
        raise ValueError("Empty response from Ollama trigger extraction")

    try:
        parsed = json.loads(raw)
    except Exception:
        parsed = json.loads(_extract_json_object(raw))

    events = parsed.get("events") or []
    if not isinstance(events, list):
        raise ValueError("Invalid events payload")

    note_lower = (note or "").lower()
    span_labels: list[str] = []

    # --- Validate spans and map them using our own keywords only ---
    for ev in events:
        if not isinstance(ev, dict):
            continue

        text_span = ev.get("text")
        if not isinstance(text_span, str):
            continue

        span = text_span.strip()
        if not span:
            continue

        span_lower = span.lower()

        # 1) text span must be an exact substring of the note (case-insensitive)
        if span_lower not in note_lower:
            # LLM hallucinated some text that is not really in the note
            continue

        # 2) Map this span to ONE canonical label via EVENT_KEYWORDS
        chosen_label: str | None = None
        for label, keywords in EVENT_KEYWORDS.items():
            if any(k in span_lower for k in keywords):
                chosen_label = label
                break

        if not chosen_label:
            chosen_label = "unknown"

        # Safety: only allow labels from the canonical list
        if chosen_label not in ALLOWED_TRIGGER_LABELS:
            chosen_label = "unknown"

        span_labels.append(chosen_label)

    # Deduplicate, keep order
    deduped: list[str] = []
    seen: set[str] = set()
    for lbl in span_labels:
        if lbl in seen:
            continue
        seen.add(lbl)
        deduped.append(lbl)

    if not deduped:
        print("[TRIGGERS/LLM] no valid spans → returning empty list")
    else:
        print(f"[TRIGGERS/LLM] labels (from spans): {deduped}")

    return deduped


# =====================================================================
#  Sentiment heuristic v2.0 (baseline / fallback)
# =====================================================================
def _run_sentiment_v2(
    *,
    note: str,
    mood: int,
    tags: Iterable[str],
) -> SentimentInsight:
    text = (note or "").lower()
    tags_lower = {t.strip().lower() for t in tags if t.strip()}

    # 1) Mood effect:
    #    mood = 1 (very happy)  → positive shift
    #    mood = 5 (very unhappy) → negative shift
    #    approximate range: [-0.3, +0.3]
    mood = max(1, min(5, mood))
    score = (3 - mood) * 0.15  # 1→+0.3, 3→0, 5→-0.3

    # 2) Keyword hits in text
    positive_hits = sum(1 for w in POSITIVE_KEYWORDS if w in text)
    negative_hits = 0

    negative_roots_from_tags = {_keyword_root(t) for t in tags_lower}

    for w in NEGATIVE_KEYWORDS:
        if w in text:
            root = _keyword_root(w)
            # If a tag already expresses the same emotion, avoid double-counting
            if root in negative_roots_from_tags:
                negative_hits += 0.3  # still adds a bit, but less than full point
            else:
                negative_hits += 1.0

    score += (positive_hits - negative_hits) * 0.08

    # 3) Tag-based small adjustments
    if tags_lower & POSITIVE_EMOTION_TAGS:
        score += 0.05
    if tags_lower & NEGATIVE_EMOTION_TAGS:
        score -= 0.05

    # 4) Clamp range and compute confidence
    score = max(-0.9, min(0.9, score))
    confidence = 0.55 + abs(score)  # minimum 0.55, more extreme = more confident
    confidence = min(confidence, 0.99)

    if score > 0.05:
        label = "positive"
    elif score < -0.05:
        label = "negative"
    else:
        label = "neutral"

    positive_prob = max(0.0, 0.5 + score)
    negative_prob = max(0.0, 0.5 - score)
    neutral_prob = max(0.0, 1.0 - abs(score * 2))

    # Normalize to sum to 1.0
    total = positive_prob + neutral_prob + negative_prob
    if total > 0:
        positive_prob /= total
        neutral_prob /= total
        negative_prob /= total

    return SentimentInsight(
        label=label,
        confidence=round(confidence, 3),
        scores={
            "positive": round(positive_prob, 3),
            "neutral": round(neutral_prob, 3),
            "negative": round(negative_prob, 3),
        },
        version="sentiment-v2.0",
    )


# =====================================================================
#  Risk Engine v3.0
# =====================================================================
async def _run_risk_engine_v3(
    *,
    user_id: str,
    mood: int,
    note: str,
    tags: Iterable[str],
    sentiment: SentimentInsight,
    history: Sequence[JournalEntry],
    manual_triggers: Iterable[str] | None = None,
) -> RiskInsight:
    text = (note or "").lower()
    tags_norm = [t.strip().lower() for t in tags if t.strip()]

    # -------- 1. Emotion parameters (valence, arousal) --------
    valences = []
    neg_arousals = []

    for t in tags_norm:
        params = EMOTION_TAG_PARAMS.get(t)
        if not params:
            continue
        v = params["valence"]
        a = params["arousal"]
        valences.append(v)
        if v < 0:
            neg_arousals.append(a)

    valence_avg = sum(valences) / len(valences) if valences else 0.0
    neg_arousal_avg = (
        sum(neg_arousals) / len(neg_arousals) if neg_arousals else 0.0
    )

    # -------- 2. Mood factor --------
    mood = max(1, min(5, mood))
    mood_factor = (mood - 3) / 2.0  # 1→-1, 3→0, 5→+1

    # -------- 3. Historical features (last 7 days) --------
    days_low_mood = 0
    days_high_risk = 0

    for e in history:
        if e.mood is not None and e.mood >= 4:
            days_low_mood += 1
        if e.risk_level == "high":
            days_high_risk += 1

    # -------- 4. Sentiment probabilities --------
    scores = sentiment.scores or {}
    neg_prob = float(scores.get("negative", 0.0))
    pos_prob = float(scores.get("positive", 0.0))

    # -------- 5. Critical trigger phrases --------
    num_critical = _count_critical_keywords(text)

    # =========================================================
    #  Scoring: first compute 0–100, then store as 0–1 in DB
    # =========================================================
    base = 10.0

    # 1) Current mood: closer to 5 => higher risk
    from_mood = max(0.0, mood_factor) * 20.0

    # 2) Tag valence: more negative => higher risk
    from_valence = max(0.0, -valence_avg) * 35.0

    # 3) Negative emotion arousal
    from_arousal = max(0.0, neg_arousal_avg) * 25.0

    # 4) Sentiment: only add if negative > positive
    from_sentiment = max(0.0, neg_prob - pos_prob) * 20.0

    # 5) Last 7 days history
    from_history = days_low_mood * 3.0 + days_high_risk * 6.0

    # 6) Critical keywords
    from_triggers = min(num_critical, 3) * 15.0  # max +45

    raw_score = (
        base
        + from_mood
        + from_valence
        + from_arousal
        + from_sentiment
        + from_history
        + from_triggers
    )

    # Clamp to 0–100
    raw_score = max(0.0, min(100.0, raw_score))

    # Store as 0–1; frontend can multiply or format as percentage
    score01 = raw_score / 100.0

    # -------- Risk level rules --------
    high_from_critical = num_critical >= 1 and (
        mood >= 4 or valence_avg <= -0.5
    )

    if high_from_critical or raw_score >= 60.0:
        level = "high"
    elif raw_score >= 30.0:
        level = "moderate"
    else:
        level = "low"

    # -------- Reason text --------
    parts: list[str] = []

    parts.append(f"mood={mood} (factor {mood_factor:.2f})")

    if valences:
        parts.append(f"valence_avg={valence_avg:.2f}")
    if neg_arousals:
        parts.append(f"neg_arousal_avg={neg_arousal_avg:.2f}")

    parts.append(
        f"sentiment={sentiment.label} "
        f"(neg={neg_prob:.2f}, pos={pos_prob:.2f})"
    )

    if days_low_mood:
        parts.append(f"{days_low_mood} low-mood days in last week")
    if days_high_risk:
        parts.append(f"{days_high_risk} previous high-risk days")
    if num_critical:
        parts.append(f"{num_critical} critical keyword(s) detected")

    reason = " | ".join(parts) if parts else "Heuristic risk estimate"

    # -------- Triggers: LLM → keyword → user preference --------
    auto_triggers: list[str] = []

    if USE_LLM_TRIGGERS:
        try:
            auto_triggers = await _extract_event_triggers_llm(
                note=note,
                mood=mood,
                tags=tags,
            )
            print(f"[TRIGGERS] using LLM triggers: {auto_triggers}")
        except Exception as e:
            print(f"[TRIGGERS] LLM extraction failed: {e}")
            auto_triggers = []

    if not auto_triggers:
        auto_triggers = _extract_event_triggers_keyword(note)
        print(f"[TRIGGERS] fallback keyword triggers: {auto_triggers}")

    auto_triggers = _normalize_trigger_list(auto_triggers)

    # Manual override (if provided in this call)
    manual_norm = _normalize_trigger_list(manual_triggers) if manual_triggers else []

    if manual_norm:
        # 1) Learn from mismatch (Option 2: user preference learning)
        _update_user_trigger_preferences(
            user_id=user_id,
            auto_triggers=auto_triggers,
            manual_triggers=manual_norm,
        )
        # 2) For this entry, user choice always wins
        final_triggers = manual_norm
    else:
        # No new override this time → apply historical preference if any
        final_triggers = _apply_user_trigger_preferences(
            user_id=user_id,
            auto_triggers=auto_triggers,
        )

    return RiskInsight(
        level=level,
        score=round(score01, 3),  # 0–1
        reason=reason,
        triggers=final_triggers,
        version="risk-engine-v3.0",
    )
