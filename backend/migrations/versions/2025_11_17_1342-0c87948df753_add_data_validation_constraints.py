"""add data validation constraints

Revision ID: 0c87948df753
Revises: f2d368444d85
Create Date: 2025-11-17 13:42:27.842689

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '0c87948df753'
down_revision = 'f2d368444d85'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add CHECK constraints for data validation at database level
    # These ensure data integrity and prevent invalid values
    # Using batch mode for SQLite compatibility
    
    # Journal entry validation constraints
    with op.batch_alter_table('journal_entries', schema=None) as batch_op:
        batch_op.create_check_constraint(
            'ck_journal_entries_mood_range',
            'mood >= 1 AND mood <= 5'
        )
        batch_op.create_check_constraint(
            'ck_journal_entries_sentiment_confidence',
            'sentiment_confidence >= 0.0 AND sentiment_confidence <= 1.0'
        )
        batch_op.create_check_constraint(
            'ck_journal_entries_risk_score',
            'risk_score >= 0.0 AND risk_score <= 1.0'
        )
        batch_op.create_check_constraint(
            'ck_journal_entries_sentiment_label',
            "sentiment_label IN ('positive', 'negative', 'neutral')"
        )
        batch_op.create_check_constraint(
            'ck_journal_entries_risk_level',
            "risk_level IN ('low', 'moderate', 'high', 'critical')"
        )
    
    # Companion session validation constraints
    with op.batch_alter_table('companion_sessions', schema=None) as batch_op:
        batch_op.create_check_constraint(
            'ck_companion_sessions_message_count',
            'message_count >= 0'
        )
        batch_op.create_check_constraint(
            'ck_companion_sessions_archived_consistency',
            '(is_archived = FALSE AND archived_at IS NULL) OR '
            '(is_archived = TRUE AND archived_at IS NOT NULL)'
        )


def downgrade() -> None:
    # Drop all CHECK constraints in reverse order using batch mode
    with op.batch_alter_table('companion_sessions', schema=None) as batch_op:
        batch_op.drop_constraint('ck_companion_sessions_archived_consistency', type_='check')
        batch_op.drop_constraint('ck_companion_sessions_message_count', type_='check')
    
    with op.batch_alter_table('journal_entries', schema=None) as batch_op:
        batch_op.drop_constraint('ck_journal_entries_risk_level', type_='check')
        batch_op.drop_constraint('ck_journal_entries_sentiment_label', type_='check')
        batch_op.drop_constraint('ck_journal_entries_risk_score', type_='check')
        batch_op.drop_constraint('ck_journal_entries_sentiment_confidence', type_='check')
        batch_op.drop_constraint('ck_journal_entries_mood_range', type_='check')
