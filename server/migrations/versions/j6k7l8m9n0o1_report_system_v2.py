"""Add report system v2: ReportType, expanded ProblemReport, evidence, punishments, violations

Revision ID: j6k7l8m9n0o1
Revises: i5j6k7l8m9n0
Create Date: 2026-05-24 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect
from sqlalchemy.dialects import mysql

revision = 'j6k7l8m9n0o1'
down_revision = 'i5j6k7l8m9n0'
branch_labels = None
depends_on = None


def upgrade():
    bind = op.get_bind()
    inspector = inspect(bind)

    # ---- 1. Create report_types table ----
    if 'report_types' not in inspector.get_table_names():
        op.create_table('report_types',
            sa.Column('id', sa.BIGINT(), nullable=False),
            sa.Column('reporter_role', sa.String(20), nullable=False, index=True),
            sa.Column('type_key', sa.String(50), nullable=False),
            sa.Column('display_name', sa.String(100), nullable=False),
            sa.Column('description', sa.Text(), nullable=True),
            sa.Column('is_active', sa.Boolean(), server_default=sa.text('true'), nullable=False),
            sa.Column('created_at', sa.DateTime(), nullable=False,
                      server_default=sa.text('CURRENT_TIMESTAMP')),
            sa.PrimaryKeyConstraint('id'),
        )

    # ---- 2. Create report_evidence table ----
    if 'report_evidence' not in inspector.get_table_names():
        op.create_table('report_evidence',
            sa.Column('id', sa.BIGINT(), nullable=False),
            sa.Column('report_id', sa.BIGINT(), nullable=False),
            sa.Column('file_path', sa.String(500), nullable=False),
            sa.Column('file_type', sa.String(50), server_default='image', nullable=False),
            sa.Column('original_filename', sa.String(255), nullable=True),
            sa.Column('uploaded_at', sa.DateTime(), nullable=False,
                      server_default=sa.text('CURRENT_TIMESTAMP')),
            sa.ForeignKeyConstraint(['report_id'], ['problem_reports.id'],
                                    ondelete='CASCADE'),
            sa.PrimaryKeyConstraint('id'),
        )

    # ---- 3. Create punishments table ----
    if 'punishments' not in inspector.get_table_names():
        op.create_table('punishments',
            sa.Column('id', sa.BIGINT(), nullable=False),
            sa.Column('report_id', sa.BIGINT(), nullable=True),
            sa.Column('user_id', sa.BIGINT(), nullable=False),
            sa.Column('severity', sa.Enum('WARNING', 'RESTRICTION', 'BAN',
                      name='punishmentseverity'), nullable=False),
            sa.Column('restriction_type', sa.String(100), nullable=True),
            sa.Column('reason', sa.Text(), nullable=False),
            sa.Column('issued_by', sa.BIGINT(), nullable=True),
            sa.Column('start_date', sa.DateTime(), nullable=False,
                      server_default=sa.text('CURRENT_TIMESTAMP')),
            sa.Column('end_date', sa.DateTime(), nullable=True),
            sa.Column('is_active', sa.Boolean(), server_default=sa.text('true'), nullable=False),
            sa.Column('created_at', sa.DateTime(), nullable=False,
                      server_default=sa.text('CURRENT_TIMESTAMP')),
            sa.ForeignKeyConstraint(['report_id'], ['problem_reports.id'],
                                    ondelete='SET NULL'),
            sa.ForeignKeyConstraint(['user_id'], ['user.id'], ondelete='CASCADE'),
            sa.ForeignKeyConstraint(['issued_by'], ['user.id'], ondelete='SET NULL'),
            sa.PrimaryKeyConstraint('id'),
        )

    # ---- 4. Create violation_history table ----
    if 'violation_history' not in inspector.get_table_names():
        op.create_table('violation_history',
            sa.Column('id', sa.BIGINT(), nullable=False),
            sa.Column('user_id', sa.BIGINT(), nullable=False),
            sa.Column('report_id', sa.BIGINT(), nullable=True),
            sa.Column('punishment_id', sa.BIGINT(), nullable=True),
            sa.Column('violation_type', sa.String(50), nullable=False),
            sa.Column('description', sa.Text(), nullable=True),
            sa.Column('issued_by', sa.BIGINT(), nullable=True),
            sa.Column('created_at', sa.DateTime(), nullable=False,
                      server_default=sa.text('CURRENT_TIMESTAMP')),
            sa.ForeignKeyConstraint(['user_id'], ['user.id'], ondelete='CASCADE'),
            sa.ForeignKeyConstraint(['report_id'], ['problem_reports.id'],
                                    ondelete='SET NULL'),
            sa.ForeignKeyConstraint(['punishment_id'], ['punishments.id'],
                                    ondelete='SET NULL'),
            sa.ForeignKeyConstraint(['issued_by'], ['user.id'], ondelete='SET NULL'),
            sa.PrimaryKeyConstraint('id'),
        )

    # ---- 5. Alter problem_reports table ----
    pr_columns = [c['name'] for c in inspector.get_columns('problem_reports')]

    # Add new columns
    new_cols = {
        'reporter_role': (sa.Column('reporter_role', sa.String(20), nullable=True), 'reporter_role'),
        'report_type_id': (sa.Column('report_type_id', sa.BIGINT(), nullable=True), 'report_type_id'),
        'priority': (sa.Column('priority', sa.String(20), server_default='medium'), 'priority'),
        'target_user_id': (sa.Column('target_user_id', sa.BIGINT(), nullable=True), 'target_user_id'),
        'target_role': (sa.Column('target_role', sa.String(20), nullable=True), 'target_role'),
        'admin_notes': (sa.Column('admin_notes', sa.Text(), nullable=True), 'admin_notes'),
        'resolved_by': (sa.Column('resolved_by', sa.BIGINT(), nullable=True), 'resolved_by'),
        'updated_at': (sa.Column('updated_at', sa.DateTime(), nullable=True), 'updated_at'),
        'resolved_at': (sa.Column('resolved_at', sa.DateTime(), nullable=True), 'resolved_at'),
    }
    for col_name, (col, _) in new_cols.items():
        if col_name not in pr_columns:
            op.add_column('problem_reports', col)

    # Add foreign keys for new columns
    if 'report_type_id' not in pr_columns:
        op.create_foreign_key(
            'fk_problem_reports_report_type',
            'problem_reports', 'report_types',
            ['report_type_id'], ['id'],
            ondelete='SET NULL',
        )
    if 'target_user_id' not in pr_columns:
        op.create_foreign_key(
            'fk_problem_reports_target_user',
            'problem_reports', 'user',
            ['target_user_id'], ['id'],
            ondelete='SET NULL',
        )
    if 'resolved_by' not in pr_columns:
        op.create_foreign_key(
            'fk_problem_reports_resolved_by',
            'problem_reports', 'user',
            ['resolved_by'], ['id'],
            ondelete='SET NULL',
        )

    # Change status column from ProblemReportStatus enum to ReportStatus enum
    if 'status' in pr_columns:
        if bind.dialect.name == 'postgresql':
            reportstatus = sa.Enum(
                'PENDING', 'UNDER_REVIEW', 'INVESTIGATING',
                'RESOLVED', 'DISMISSED', name='reportstatus',
            )
            reportstatus.create(bind, checkfirst=True)
            op.execute(
                "ALTER TABLE problem_reports "
                "ALTER COLUMN status TYPE reportstatus "
                "USING (CASE status::text "
                "WHEN 'pending' THEN 'PENDING'::reportstatus "
                "WHEN 'reviewed' THEN 'UNDER_REVIEW'::reportstatus "
                "WHEN 'resolved' THEN 'RESOLVED'::reportstatus "
                "WHEN 'PENDING' THEN 'PENDING'::reportstatus "
                "WHEN 'REVIEWED' THEN 'UNDER_REVIEW'::reportstatus "
                "WHEN 'RESOLVED' THEN 'RESOLVED'::reportstatus "
                "ELSE 'PENDING'::reportstatus END)"
            )
            op.execute(
                "ALTER TABLE problem_reports "
                "ALTER COLUMN status SET DEFAULT 'PENDING'::reportstatus"
            )
        else:
            op.alter_column('problem_reports', 'status',
                            existing_type=sa.Enum('PENDING', 'REVIEWED', 'RESOLVED',
                                                 name='problemreportstatus'),
                            type_=sa.Enum('PENDING', 'UNDER_REVIEW', 'INVESTIGATING',
                                         'RESOLVED', 'DISMISSED', name='reportstatus'),
                            existing_server_default=sa.text("'pending'"),
                            server_default=sa.text("'pending'"),
                            nullable=False)

    # Drop old rider_id column (replaced by target_user_id)
    if 'rider_id' in pr_columns:
        for fk in inspector.get_foreign_keys('problem_reports'):
            if 'rider_id' in fk.get('constrained_columns', []):
                op.drop_constraint(fk['name'], 'problem_reports', type_='foreignkey')
                break
        op.drop_column('problem_reports', 'rider_id')

    # Drop old category column (replaced by report_type_id)
    if 'category' in pr_columns:
        op.drop_column('problem_reports', 'category')


def downgrade():
    bind = op.get_bind()
    inspector = inspect(bind)

    # Drop violation_history
    if 'violation_history' in inspector.get_table_names():
        op.drop_table('violation_history')

    # Drop punishments
    if 'punishments' in inspector.get_table_names():
        op.drop_table('punishments')

    # Drop report_evidence
    if 'report_evidence' in inspector.get_table_names():
        op.drop_table('report_evidence')

    # Drop report_types
    if 'report_types' in inspector.get_table_names():
        op.drop_table('report_types')

    # Revert problem_reports changes
    pr_columns = [c['name'] for c in inspector.get_columns('problem_reports')]

    # Restore rider_id
    if 'rider_id' not in pr_columns:
        op.add_column('problem_reports',
                      sa.Column('rider_id', sa.BIGINT(), nullable=True))
        op.create_foreign_key(
            None, 'problem_reports', 'user',
            ['rider_id'], ['id'], ondelete='SET NULL',
        )

    # Restore category
    if 'category' not in pr_columns:
        op.add_column('problem_reports',
                      sa.Column('category', sa.String(20), nullable=True))

    # Revert status enum
    if 'status' in pr_columns:
        if bind.dialect.name == 'postgresql':
            problemreportstatus = sa.Enum(
                'pending', 'reviewed', 'resolved', name='problemreportstatus',
            )
            problemreportstatus.create(bind, checkfirst=True)
            op.execute(
                "ALTER TABLE problem_reports "
                "ALTER COLUMN status TYPE problemreportstatus "
                "USING (CASE status::text "
                "WHEN 'PENDING' THEN 'pending'::problemreportstatus "
                "WHEN 'UNDER_REVIEW' THEN 'reviewed'::problemreportstatus "
                "WHEN 'INVESTIGATING' THEN 'reviewed'::problemreportstatus "
                "WHEN 'RESOLVED' THEN 'resolved'::problemreportstatus "
                "WHEN 'DISMISSED' THEN 'resolved'::problemreportstatus "
                "ELSE 'pending'::problemreportstatus END)"
            )
            op.execute(
                "ALTER TABLE problem_reports "
                "ALTER COLUMN status SET DEFAULT 'pending'::problemreportstatus"
            )
        else:
            op.alter_column('problem_reports', 'status',
                            existing_type=sa.Enum('PENDING', 'UNDER_REVIEW', 'INVESTIGATING',
                                                 'RESOLVED', 'DISMISSED', name='reportstatus'),
                            type_=sa.Enum('PENDING', 'REVIEWED', 'RESOLVED',
                                         name='problemreportstatus'),
                            existing_server_default=sa.text("'pending'"),
                            server_default=sa.text("'pending'"),
                            nullable=False)

    # Drop new columns (reverse order)
    drop_cols = ['resolved_at', 'updated_at', 'resolved_by', 'admin_notes',
                 'target_role', 'target_user_id', 'priority', 'report_type_id',
                 'reporter_role']
    for col_name in drop_cols:
        if col_name in pr_columns:
            op.drop_column('problem_reports', col_name)
