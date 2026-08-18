from __future__ import annotations

from sqlalchemy import select

from app.db.session import async_session_factory
from app.models.companion import Companion, CompanionPersona

DEFAULT_COMPANIONS = [
    {
        "id": "c_listener",
        "name": "Listener",
        "persona": CompanionPersona.listener,
        "description": "Empathic listening, helping you finish your thoughts.",
        "tagline": "Attentive support when you need to unpack a feeling.",
        "system_prompt": (
            "You are Listener, an attentive mental health companion. Reflect back key feelings, "
            "ask gentle clarifying questions, and avoid giving directives unless asked."
        ),
        "quick_prompts": [
            "I have been holding onto this feeling...",
            "Can you help me explore why I felt this way today?",
            "I need someone to hear me out about...",
        ],
        "ui_config": {
            "primaryColor": "#050D25",
            "secondaryColor": "#1A3C7A",
            "gradient": ["#050D25", "#102754", "#1A3C7A"],
            "icon": "hearing_rounded",
        },
    },
    {
        "id": "c_coach",
        "name": "Coach",
        "persona": CompanionPersona.coach,
        "description": "Goal breakdown and action follow-up.",
        "tagline": "Keep momentum with small, actionable goals.",
        "system_prompt": (
            "You are Coach, a pragmatic wellbeing mentor. Help the user turn goals into actionable steps, "
            "follow up on progress, and keep the tone encouraging yet grounded."
        ),
        "quick_prompts": [
            "Let us build a plan for...",
            "Can you help me break this goal into steps?",
            "I want to stay accountable for...",
        ],
        "ui_config": {
            "primaryColor": "#041428",
            "secondaryColor": "#0E4F72",
            "gradient": ["#041428", "#0C324A", "#0E4F72"],
            "icon": "sports_gymnastics_rounded",
        },
    },
    {
        "id": "c_planner",
        "name": "Planner",
        "persona": CompanionPersona.planner,
        "description": "Task breakdown, time blocking, reminders.",
        "tagline": "Structure your day so energy goes where you need it.",
        "system_prompt": (
            "You are Planner, a structured support companion. Break tasks into manageable pieces, suggest time blocks, "
            "and offer gentle reminders to help the user stay organized."
        ),
        "quick_prompts": [
            "I need help organizing my day around...",
            "What is the best way to schedule...",
            "Remind me to tackle...",
        ],
        "ui_config": {
            "primaryColor": "#041522",
            "secondaryColor": "#0F4D4F",
            "gradient": ["#041522", "#0A2E38", "#0F4D4F"],
            "icon": "event_note_rounded",
        },
    },
    {
        "id": "c_cheer",
        "name": "Cheerleader",
        "persona": CompanionPersona.cheerleader,
        "description": "Positive reinforcement and supportive encouragement.",
        "tagline": "Celebrate small wins and keep spirits lifted.",
        "system_prompt": (
            "You are Cheerleader, an uplifting encourager. Celebrate small wins, provide supportive affirmations, "
            "and keep the energy optimistic without dismissing concerns."
        ),
        "quick_prompts": [
            "I would love a boost around...",
            "Can we celebrate that I...",
            "Remind me why I can do...",
        ],
        "ui_config": {
            "primaryColor": "#14062C",
            "secondaryColor": "#4A2B79",
            "gradient": ["#14062C", "#341A55", "#4A2B79"],
            "icon": "emoji_emotions_rounded",
        },
    },
]


async def seed_defaults() -> None:
  """Ensure we have the baseline companions configured for the app."""
  async with async_session_factory() as session:
    result = await session.execute(select(Companion.id))
    existing_ids = set(result.scalars().all())
    new_records = [
        Companion(**payload) for payload in DEFAULT_COMPANIONS if payload["id"] not in existing_ids
    ]
    if not new_records:
      return
    session.add_all(new_records)
    await session.commit()
