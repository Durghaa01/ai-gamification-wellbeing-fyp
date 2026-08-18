# ⚠️ Deprecated: This module is kept only for reference.
# The active engine is journal_risk.py (sentiment-v2.0 + risk-engine-v3.0)

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, timedelta
from typing import Iterable, Sequence

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.journal import JournalEntry
from app.schemas.journal import RiskInsight, SentimentInsight

# ---- 基础关键词表（情绪 + 升级触发） ----

POSITIVE_KEYWORDS = {
    "progress",
    "calm",
    "hope",
    "grateful",
    "excited",
    "peaceful",
    "confident",
}

NEGATIVE_KEYWORDS = {
    "stressed",
    "anxious",
    "angry",
    "overwhelmed",
    "tired",
    "sad",
    "panic",
    "hopeless",
    "exhausted",
}

ESCALATION_TRIGGERS = {
    "panic": "panic indicators",
    "harm": "self-harm language",
    "worthless": "low self-worth",
    "suicide": "self-harm language",
    "relapse": "relapse concern",
    "sleep": "sleep disruption",
    "medication": "medication adherence",
}


def _keyword_root(word: str) -> str:
    """
    把 stress / stressed / stressing 统一成 stress
    把 tired / tiring 统一成 tired
    这样就可以避免 tag + text 里“同一种情绪”被重复计分。
    """
    w = word.lower()
    for suffix in ("ness", "ed", "ing", "s"):
        if w.endswith(suffix) and len(w) > len(suffix) + 2:
            return w[: -len(suffix)]
    return w


# 与前端 Dart RiskEngine 对齐的一组 tag 权重（可再调整）
TAG_WEIGHTS: dict[str, float] = {
    "anxious": 12,
    "stress": 10,
    "stressed": 10,
    "lonely": 10,
    "tired": 8,
    "sleep": 8,
    "relationship": 8,
    "work": 6,
    "study": 6,
    "health": 8,
    "burnout": 10,
}


@dataclass(slots=True)
class JournalAnalysisResult:
    sentiment: SentimentInsight
    risk: RiskInsight


# =====================================================================
#  对外主入口：情绪 + 风险（带“最近 7 天历史”）
# =====================================================================

async def analyse_journal_note(
    *,
    session: AsyncSession,
    user_id: str,
    user_mood: int,
    note: str,
    tags: Iterable[str],
    entry_date: date,
) -> JournalAnalysisResult:
    """
    1) 通过简单关键词 + mood 做情绪分析 → SentimentInsight
    2) 查询该用户最近 7 天的 JournalEntry 作为历史特征
    3) 使用风控 v2（mood + sentiment + tags + history + 强触发词）→ RiskInsight
    """

    # 1. 情绪分析（保留你原来的 heuristic，略作整理）
    sentiment = _run_sentiment(note=note, mood=user_mood, tags=tags)

    # 2. 最近 7 天历史记录
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

    # 3. 风险评分 v2
    risk = _run_risk_engine_v2(
        mood=user_mood,
        note=note,
        tags=tags,
        sentiment=sentiment,
        history=history,
    )

    return JournalAnalysisResult(sentiment=sentiment, risk=risk)


# =====================================================================
#  Sentiment heuristic（保留版本：heuristic-v1）
# =====================================================================

def _run_sentiment(
    *,
    note: str,
    mood: int,
    tags: Iterable[str],
) -> SentimentInsight:
    text = (note or "").lower()

    # 统一把 tags 变成小写、去空格
    tags_lower = [t.strip().lower() for t in tags if t.strip()]
    tags_set = set(tags_lower)

    # 1) mood 影响：把 1..5 映射到一个 [-0.24, +0.24] 左右的小范围
    #   mood=1 非常开心 → score 偏正
    #   mood=5 非常不开心 → score 偏负
    score = (3 - mood) * 0.12  # mood sway

    # 2) 关键词命中
    # 正向关键词：只要出现在文本里就加
    positive_hits = sum(w in text for w in POSITIVE_KEYWORDS)

    # 记录 tag 已经表达过的负向情绪“词根”，避免 text 里重复计分
    negative_roots_from_tags = {_keyword_root(t) for t in tags_lower}

    negative_hits = 0
    for w in NEGATIVE_KEYWORDS:
        if w in text:
            root = _keyword_root(w)
            # 如果这个负向词已经在 tag 里出现过（同一个词根），就不再额外扣分
            if root in negative_roots_from_tags:
                continue
            negative_hits += 1

    # 文本情绪对分数的影响
    score += (positive_hits - negative_hits) * 0.08

    # 3) 标签的轻微影响（可以后面再调）
    if "grateful" in tags_set or "gratitude" in tags_set:
        score += 0.05
    if "burnout" in tags_set:
        score -= 0.05

    # 4) 限制上下界
    score = max(-0.9, min(0.9, score))
    confidence = 0.55 + abs(score)

    if score > 0.05:
        label = "positive"
    elif score < -0.05:
        label = "negative"
    else:
        label = "neutral"

    positive_prob = max(0.0, 0.5 + score)
    negative_prob = max(0.0, 0.5 - score)
    neutral_prob = max(0.0, 1.0 - abs(score * 2))

    return SentimentInsight(
        label=label,
        confidence=round(min(0.99, confidence), 3),
        scores={
            "positive": positive_prob,
            "neutral": neutral_prob,
            "negative": negative_prob,
        },
        version="heuristic-v1",
    )


# =====================================================================
#  Risk Engine v2（带历史 + 强触发词 + tag 权重）
# =====================================================================

def _run_risk_engine_v2(
    *,
    mood: int,
    note: str,
    tags: Iterable[str],
    sentiment: SentimentInsight,
    history: Sequence[JournalEntry],
) -> RiskInsight:
    text = (note or "").lower()
    tags_norm = [t.strip().lower() for t in tags if t.strip()]

    # -------- 1. 基础分：来自 mood --------
    # 1 非常好 → 接近 0；5 非常差 → 接近 1
    mood_score01 = max(0.0, min(1.0, (mood - 1) / 4))
    base_from_mood = 10.0 + 30.0 * mood_score01  # 10..40 之间

    # -------- 2. 文本情绪影响 --------
    scores = sentiment.scores or {}
    pos_prob = float(scores.get("positive", 0.0))
    neg_prob = float(scores.get("negative", 0.0))

    from_sentiment = 25.0 * neg_prob - 10.0 * pos_prob  # 负情绪加分，正情绪减分

    # -------- 3. 标签权重（与前端 Dart 风格一致）--------
    from_tags = 0.0
    triggers: list[str] = []

    for tag in tags_norm:
        if tag in TAG_WEIGHTS:
            from_tags += TAG_WEIGHTS[tag]
            triggers.append(tag)
        else:
            # 未知 tag 小权重，避免完全忽略用户标记
            from_tags += 3.0

    # -------- 4. 历史模式（最近 7 天）--------
    low_days = 0
    sum_mood = 0.0
    for e in history:
        sum_mood += e.mood
        if e.mood >= 4 or e.risk_level == "high":
            low_days += 1

    avg_mood = (sum_mood / len(history)) if history else None
    from_history = 0.0
    from_history += low_days * 4.0  # 每一天低 mood / high risk 都加一点
    if avg_mood is not None and avg_mood >= 4.0:
        from_history += 6.0  # 最近整体偏低

    # -------- 5. 强触发词（文本级别）--------
    from_escalation = 0.0
    for keyword, reason in ESCALATION_TRIGGERS.items():
        if keyword in text:
            from_escalation += 10.0
            triggers.append(reason)

    # -------- 6. mood 与文本情绪不一致惩罚 --------
    from_mismatch = 0.0
    is_negative_text = (
        sentiment.label == "negative" or neg_prob >= 0.6
    )
    is_positive_text = (
        sentiment.label == "positive" or pos_prob >= 0.6
    )

    # mood <=2 但文本偏负 → 可能「自评偏乐观」
    if mood <= 2 and is_negative_text and sentiment.confidence >= 0.6:
        from_mismatch += 8.0

    # mood >=4 但文本偏正 → 可能「自评偏悲观」或文本压抑
    if mood >= 4 and is_positive_text and sentiment.confidence >= 0.6:
        from_mismatch += 8.0

    # 长篇 rumination
    if len(note) > 500:
        from_mismatch += 3.0

    # -------- 7. 汇总总分 0..100 --------
    total = (
        base_from_mood
        + from_sentiment
        + from_tags
        + from_history
        + from_escalation
        + from_mismatch
    )
    raw_score = max(0.0, min(100.0, total))
    score = round(raw_score / 100.0, 4)

    # -------- 8. 风险等级 --------
    if score >= 0.7:
        level = "high"
    elif score >= 0.35:
        level = "moderate"
    else:
        level = "low"

    # -------- 9. 解释文本（给前端 UI / 报告写法用）--------
    parts: list[str] = []
    parts.append(f"mood={mood} (base {base_from_mood:.1f})")
    parts.append(
        f"sentiment={sentiment.label} ({sentiment.confidence:.2f})"
    )
    if from_tags > 0:
        parts.append(f"tags weight +{from_tags:.1f}")
    if low_days:
        parts.append(
            f"{low_days} low-risk days in last 7 (+{low_days*4:.1f})"
        )
    if from_escalation > 0:
        parts.append("escalation keywords")
    if from_mismatch > 0:
        parts.append("mood-text mismatch / rumination")

    reason = " | ".join(parts) if parts else "Heuristic risk estimate"

    return RiskInsight(
        level=level,
        score=score,
        reason=reason,
        triggers=triggers,
        version="risk-engine-v2",
    )
