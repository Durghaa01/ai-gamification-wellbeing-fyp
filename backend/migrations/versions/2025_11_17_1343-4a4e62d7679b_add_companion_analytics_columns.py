"""add companion analytics columns

Revision ID: 4a4e62d7679b
Revises: 0c87948df753
Create Date: 2025-11-17 13:43:55.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '4a4e62d7679b'
down_revision = '0c87948df753'
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table('companion_sessions', schema=None) as batch_op:
        batch_op.add_column(sa.Column('summary', sa.Text(), nullable=True))
        batch_op.add_column(
            sa.Column(
                'token_count',
                sa.Integer(),
                nullable=False,
                server_default='0',
            )
        )
        batch_op.add_column(
            sa.Column(
                'latency_ms',
                sa.Integer(),
                nullable=False,
                server_default='0',
            )
        )
        batch_op.create_unique_constraint(
            'uq_companion_sessions_user_companion',
            ['user_id', 'companion_id'],
        )
        batch_op.alter_column('token_count', server_default=None)
        batch_op.alter_column('latency_ms', server_default=None)

    with op.batch_alter_table('companion_messages', schema=None) as batch_op:
        batch_op.add_column(
            sa.Column(
                'token_count',
                sa.Integer(),
                nullable=False,
                server_default='0',
            )
        )
        batch_op.add_column(
            sa.Column(
                'latency_ms',
                sa.Integer(),
                nullable=False,
                server_default='0',
            )
        )
        batch_op.alter_column('token_count', server_default=None)
        batch_op.alter_column('latency_ms', server_default=None)


def downgrade() -> None:
    with op.batch_alter_table('companion_messages', schema=None) as batch_op:
        batch_op.drop_column('latency_ms')
        batch_op.drop_column('token_count')

    with op.batch_alter_table('companion_sessions', schema=None) as batch_op:
        batch_op.drop_constraint('uq_companion_sessions_user_companion', type_='unique')
        batch_op.drop_column('latency_ms')
        batch_op.drop_column('token_count')
        batch_op.drop_column('summary')
