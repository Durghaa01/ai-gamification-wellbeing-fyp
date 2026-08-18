"""add hybrid companion tables

Revision ID: 8de7c2e1a8d0
Revises: 4a4e62d7679b
Create Date: 2025-11-17 13:44:18.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '8de7c2e1a8d0'
down_revision = '4a4e62d7679b'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'companion_message_index',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('session_id', sa.String(length=128), nullable=False),
        sa.Column('role', sa.Enum('user', 'assistant', 'system', name='companionmessagerole', create_type=False), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('token_count', sa.Integer(), nullable=False),
        sa.Column('latency_ms', sa.Integer(), nullable=False),
        sa.Column('document_key', sa.String(length=256), nullable=False),
        sa.Column('version', sa.Integer(), nullable=False),
        sa.Column('extra_meta', postgresql.JSONB(astext_type=sa.Text()).with_variant(sa.JSON(), 'sqlite'), nullable=True),
        sa.ForeignKeyConstraint(['session_id'], ['companion_sessions.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(
        'ix_companion_message_index_session_time',
        'companion_message_index',
        ['session_id', 'created_at']
    )

    op.create_table(
        'companion_session_metrics',
        sa.Column('session_id', sa.String(length=128), nullable=False),
        sa.Column('total_latency_ms', sa.Integer(), nullable=False),
        sa.Column('assistant_turns', sa.Integer(), nullable=False),
        sa.Column('user_turns', sa.Integer(), nullable=False),
        sa.Column('avg_sentiment', sa.Float(), nullable=True),
        sa.Column('last_summary_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('tags', postgresql.ARRAY(sa.String()).with_variant(sa.JSON(), 'sqlite'), nullable=False),
        sa.Column('embeddings_ready', sa.Boolean(), nullable=False),
        sa.ForeignKeyConstraint(['session_id'], ['companion_sessions.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('session_id'),
    )

    op.create_table(
        'companion_outbox',
        sa.Column('id', sa.BigInteger().with_variant(sa.Integer(), 'sqlite'), nullable=False),
        sa.Column('aggregate_id', sa.String(length=128), nullable=False),
        sa.Column('event_type', sa.String(length=64), nullable=False),
        sa.Column('payload', postgresql.JSONB(astext_type=sa.Text()).with_variant(sa.JSON(), 'sqlite'), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('processed_at', sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_companion_outbox_aggregate_id', 'companion_outbox', ['aggregate_id'], unique=False)
    op.create_index(
        'ix_companion_outbox_unprocessed',
        'companion_outbox',
        ['processed_at'],
        unique=False,
        postgresql_where=sa.text("processed_at IS NULL"),
    )


def downgrade() -> None:
    op.drop_index('ix_companion_outbox_unprocessed', table_name='companion_outbox')
    op.drop_index('ix_companion_outbox_aggregate_id', table_name='companion_outbox')
    op.drop_table('companion_outbox')
    op.drop_table('companion_session_metrics')
    op.drop_index('ix_companion_message_index_session_time', table_name='companion_message_index')
    op.drop_table('companion_message_index')
