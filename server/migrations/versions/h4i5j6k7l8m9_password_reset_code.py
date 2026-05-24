"""Add password_reset_code table

Revision ID: h4i5j6k7l8m9
Revises: g3h4i5j6k7l8
Create Date: 2026-05-23 18:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = 'h4i5j6k7l8m9'
down_revision = 'g3h4i5j6k7l8'
branch_labels = None
depends_on = None


def upgrade():
    bind = op.get_bind()
    inspector = inspect(bind)
    if 'password_reset_code' in inspector.get_table_names():
        return
    op.create_table(
        'password_reset_code',
        sa.Column('id', sa.BIGINT(), nullable=False),
        sa.Column('user_id', sa.BIGINT(), nullable=False),
        sa.Column('code_hash', sa.String(255), nullable=False),
        sa.Column('channel', sa.String(16), nullable=False),
        sa.Column('expires_at', sa.DateTime(), nullable=False),
        sa.Column('attempts', sa.Integer(), nullable=False),
        sa.Column('verified', sa.Boolean(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['user.id']),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(
        'ix_password_reset_code_user_id',
        'password_reset_code',
        ['user_id'],
    )


def downgrade():
    op.drop_index('ix_password_reset_code_user_id', table_name='password_reset_code')
    op.drop_table('password_reset_code')
