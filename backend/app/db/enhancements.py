"""Enhanced database models with additional indexes and constraints."""
from sqlalchemy import CheckConstraint, Index

from app.models.companion import Companion, CompanionMessage, CompanionSession
from app.models.journal import JournalEntry
from app.models.user import AppUser


def add_performance_indexes() -> None:
    """Add composite indexes for common query patterns.
    
    These indexes significantly improve query performance for:
    - User session listing with message count/date sorting
    - Message history pagination
    - Journal entry date range queries
    - Risk assessment filtering
    """
    
    # Companion session indexes for better query performance
    Index(
        "ix_companion_sessions_user_archived_lastmsg",
        CompanionSession.user_id,
        CompanionSession.is_archived,
        CompanionSession.last_message_at,
    )
    
    Index(
        "ix_companion_sessions_user_created",
        CompanionSession.user_id,
        CompanionSession.created_at,
    )
    
    # Message indexes for pagination and filtering
    Index(
        "ix_companion_messages_session_created",
        CompanionMessage.session_id,
        CompanionMessage.created_at,
    )
    
    Index(
        "ix_companion_messages_role_created",
        CompanionMessage.role,
        CompanionMessage.created_at,
    )
    
    # Journal entry indexes for analytics queries
    Index(
        "ix_journal_entries_user_date_desc",
        JournalEntry.user_id,
        JournalEntry.entry_date.desc(),
    )
    
    Index(
        "ix_journal_entries_risk_date",
        JournalEntry.risk_level,
        JournalEntry.entry_date,
    )
    
    Index(
        "ix_journal_entries_sentiment_date",
        JournalEntry.sentiment_label,
        JournalEntry.entry_date,
    )


def add_data_constraints() -> None:
    """Add CHECK constraints for data validation.
    
    These constraints ensure data integrity at the database level:
    - Valid mood range (1-5)
    - Valid sentiment confidence (0.0-1.0)
    - Valid risk score (0.0-1.0)
    - Positive message counts
    """
    
    # Journal entry validation
    CheckConstraint(
        "mood >= 1 AND mood <= 5",
        name="ck_journal_entries_mood_range"
    )
    
    CheckConstraint(
        "sentiment_confidence >= 0.0 AND sentiment_confidence <= 1.0",
        name="ck_journal_entries_sentiment_confidence"
    )
    
    CheckConstraint(
        "risk_score >= 0.0 AND risk_score <= 1.0",
        name="ck_journal_entries_risk_score"
    )
    
    CheckConstraint(
        "sentiment_label IN ('positive', 'negative', 'neutral')",
        name="ck_journal_entries_sentiment_label"
    )
    
    CheckConstraint(
        "risk_level IN ('low', 'moderate', 'high', 'critical')",
        name="ck_journal_entries_risk_level"
    )
    
    # Companion session validation
    CheckConstraint(
        "message_count >= 0",
        name="ck_companion_sessions_message_count"
    )
    
    CheckConstraint(
        "(is_archived = FALSE AND archived_at IS NULL) OR "
        "(is_archived = TRUE AND archived_at IS NOT NULL)",
        name="ck_companion_sessions_archived_consistency"
    )


# Note: These indexes and constraints should be added via Alembic migrations
# Run: alembic revision --autogenerate -m "add performance indexes and constraints"
