"""add performance indexes

Revision ID: f2d368444d85
Revises: 3bdb70b225db
Create Date: 2025-11-17 13:41:39.433080

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'f2d368444d85'
down_revision = '3bdb70b225db'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Composite indexes for common query patterns
    # These significantly improve query performance for listing, filtering, and analytics
    
    # Companion sessions - for user session listing with archive filter and sorting
    op.create_index(
        'ix_companion_sessions_user_archived_lastmsg',
        'companion_sessions',
        ['user_id', 'is_archived', 'last_message_at'],
    )
    
    # Companion sessions - for user session chronological listing
    op.create_index(
        'ix_companion_sessions_user_created',
        'companion_sessions',
        ['user_id', 'created_at'],
    )
    
    # Messages - for pagination by session and time
    op.create_index(
        'ix_companion_messages_session_created',
        'companion_messages',
        ['session_id', 'created_at'],
    )
    
    # Messages - for filtering by role and time (analytics)
    op.create_index(
        'ix_companion_messages_role_created',
        'companion_messages',
        ['role', 'created_at'],
    )
    
    # Journal entries - for user date range queries (descending)
    op.execute(
        'CREATE INDEX ix_journal_entries_user_date_desc '
        'ON journal_entries (user_id, entry_date DESC)'
    )
    
    # Journal entries - for risk level filtering by date
    op.create_index(
        'ix_journal_entries_risk_date',
        'journal_entries',
        ['risk_level', 'entry_date'],
    )
    
    # Journal entries - for sentiment analysis by date
    op.create_index(
        'ix_journal_entries_sentiment_date',
        'journal_entries',
        ['sentiment_label', 'entry_date'],
    )


def downgrade() -> None:
    # Drop all performance indexes in reverse order
    op.drop_index('ix_journal_entries_sentiment_date', table_name='journal_entries')
    op.drop_index('ix_journal_entries_risk_date', table_name='journal_entries')
    op.drop_index('ix_journal_entries_user_date_desc', table_name='journal_entries')
    op.drop_index('ix_companion_messages_role_created', table_name='companion_messages')
    op.drop_index('ix_companion_messages_session_created', table_name='companion_messages')
    op.drop_index('ix_companion_sessions_user_created', table_name='companion_sessions')
    op.drop_index('ix_companion_sessions_user_archived_lastmsg', table_name='companion_sessions')
