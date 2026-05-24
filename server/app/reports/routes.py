import os
import datetime
from werkzeug.utils import secure_filename

from flask import (
    jsonify,
    request,
    current_app,
)
from flask_jwt_extended import (
    jwt_required,
    get_jwt,
    current_user,
)
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from . import (
    reports as reports_bp,
    db,
    User,
    ReportType,
    ProblemReport,
    ReportStatus,
    ReportEvidence,
    Punishment,
    PunishmentSeverity,
    ViolationHistory,
)
from app.decorators import admin_required
from app.reports.validation import TYPE_PUNISHMENT_DEFAULTS, validate_and_resolve_report
from app.notifications.service import create_notification
from app.models import Role, RoleTypes, UserRole, Store, Order
from app.utils.static_urls import public_static_url

ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'pdf'}
MAX_EVIDENCE_FILES = 5


def allowed_file(filename: str) -> bool:
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


def serialize_report_type(rt: ReportType) -> dict:
    return {
        'id': rt.id,
        'targetRole': rt.target_role,
        'typeKey': rt.type_key,
        'displayName': rt.display_name,
        'description': rt.description,
        'category': getattr(rt, 'category', None),
    }


def serialize_report(r: ProblemReport, *, for_reporter: bool = False) -> dict:
    evidence_list = []
    try:
        for e in r.evidence:
            evidence_list.append({
                'id': e.id,
                'filePath': e.file_path,
                'fileUrl': public_static_url(e.file_path),
                'fileType': e.file_type,
                'originalFilename': e.original_filename,
                'uploadedAt': e.uploaded_at.isoformat() if e.uploaded_at else None,
            })
    except Exception:
        pass

    punishments_list = []
    try:
        for p in r.punishments:
            punishments_list.append({
                'id': p.id,
                'severity': p.severity.value,
                'restrictionType': p.restriction_type,
                'reason': p.reason,
                'issuedBy': p.issued_by,
                'startDate': p.start_date.isoformat() if p.start_date else None,
                'endDate': p.end_date.isoformat() if p.end_date else None,
                'isActive': p.is_active,
                'createdAt': p.created_at.isoformat() if p.created_at else None,
            })
    except Exception:
        pass

    report_type_name = None
    report_type_category = None
    try:
        if r.report_type is not None:
            report_type_name = r.report_type.display_name
            report_type_category = getattr(r.report_type, 'category', None)
    except Exception:
        pass

    payload = {
        'id': r.id,
        'reporterUserId': r.reporter_user_id,
        'reporterRole': r.reporter_role,
        'reportTypeId': r.report_type_id,
        'reportType': report_type_name,
        'reportTypeCategory': report_type_category,
        'description': r.description,
        'status': r.status.value if r.status else 'pending',
        'priority': r.priority or 'medium',
        'targetUserId': r.target_user_id,
        'targetRole': r.target_role,
        'storeId': r.store_id,
        'orderId': r.order_id,
        'evidence': evidence_list,
        'evidenceCount': len(evidence_list),
        'createdAt': r.created_at.isoformat() if r.created_at else None,
        'updatedAt': r.updated_at.isoformat() if r.updated_at else None,
        'resolvedAt': r.resolved_at.isoformat() if r.resolved_at else None,
    }

    if for_reporter:
        return payload

    payload.update({
        'adminNotes': r.admin_notes,
        'resolvedBy': r.resolved_by,
        'punishments': punishments_list,
    })
    return payload


def _enrich_reports_for_reporter(
    reports: list[ProblemReport],
    stores_by_id: dict[int, Store],
    orders_by_id: dict[int, Order],
) -> list[dict]:
    enriched: list[dict] = []
    for r in reports:
        data = serialize_report(r, for_reporter=True)
        store = stores_by_id.get(r.store_id) if r.store_id else None
        order = orders_by_id.get(r.order_id) if r.order_id else None
        if store:
            data['store'] = {
                'id': store.id,
                'name': store.store_name,
            }
        if order:
            status = order.status.value if hasattr(order.status, 'value') else str(order.status)
            data['order'] = {
                'id': order.id,
                'displayId': f'ORD-{order.id}',
                'status': status,
                'totalAmount': float(order.total_amount or 0),
                'grandTotal': float(order.grand_total),
                'createdAt': order.created_at.isoformat() if order.created_at else None,
            }
        target_role = r.target_role or ''
        if target_role == 'seller' and store:
            data['targetLabel'] = store.store_name or f'Store #{store.id}'
        elif target_role == 'rider' and order:
            data['targetLabel'] = f'Rider on order ORD-{order.id}'
        elif target_role:
            data['targetLabel'] = target_role.capitalize()
        else:
            data['targetLabel'] = None
        enriched.append(data)
    return enriched


def serialize_punishment(p: Punishment) -> dict:
    return {
        'id': p.id,
        'reportId': p.report_id,
        'userId': p.user_id,
        'severity': p.severity.value,
        'restrictionType': p.restriction_type,
        'reason': p.reason,
        'issuedBy': p.issued_by,
        'startDate': p.start_date.isoformat() if p.start_date else None,
        'endDate': p.end_date.isoformat() if p.end_date else None,
        'isActive': p.is_active,
        'createdAt': p.created_at.isoformat() if p.created_at else None,
    }


def serialize_violation(v: ViolationHistory) -> dict:
    return {
        'id': v.id,
        'userId': v.user_id,
        'reportId': v.report_id,
        'punishmentId': v.punishment_id,
        'violationType': v.violation_type,
        'description': v.description,
        'issuedBy': v.issued_by,
        'createdAt': v.created_at.isoformat() if v.created_at else None,
    }


def _get_user_role_from_claims() -> str:
    claims = get_jwt()
    if claims.get('is_admin'):
        return 'admin'
    if claims.get('is_buyer'):
        return 'buyer'
    if claims.get('is_seller'):
        return 'seller'
    if claims.get('is_rider'):
        return 'rider'
    return 'buyer'


# ---- Public / User-facing endpoints ----

@reports_bp.get('/types')
@jwt_required()
def get_report_types():
    """Return report reason types for the role being reported (targetRole).

    Query: targetRole=buyer|seller|rider (required).
    Legacy ?role= is accepted as an alias for targetRole.
    """
    target_role = (request.args.get('targetRole') or request.args.get('role') or '').strip().lower()
    if target_role not in ('buyer', 'seller', 'rider'):
        return jsonify(msg='targetRole is required (buyer, seller, or rider)'), 400

    stmt = select(ReportType).where(
        ReportType.target_role == target_role,
        ReportType.is_active.is_(True),
    )
    types = db.session.execute(stmt).scalars().all()
    return jsonify(types=[serialize_report_type(t) for t in types]), 200


def _notify_admins_new_report(report: ProblemReport) -> None:
    admin_role = db.session.execute(
        select(Role).where(Role.id == RoleTypes.ADMIN.value)
    ).scalar_one_or_none()
    if admin_role is None:
        return

    admins = db.session.execute(
        select(User)
        .join(UserRole, UserRole.user_id == User.id)
        .where(UserRole.role_id == admin_role.id, User.active.is_(True))
    ).scalars().all()

    type_label = report.report_type.display_name if report.report_type else "Problem"
    for admin in admins:
        create_notification(
            user_id=admin.id,
            role="admin",
            title=f"New report: {type_label}",
            message=report.description[:200],
            page=f"/admin/reports/{report.id}",
            category="support",
            data={
                "reportId": report.id,
                "reporterRole": report.reporter_role,
                "targetRole": report.target_role,
                "storeId": report.store_id,
                "orderId": report.order_id,
            },
        )


@reports_bp.post('')
@jwt_required()
def submit_report():
    user = db.session.execute(
        select(User).where(User.id == current_user.id)
    ).scalar_one_or_none()
    if user is None:
        return jsonify(msg='User not found'), 404

    reporter_role = _get_user_role_from_claims()

    report_type_id = request.form.get('reportTypeId', type=int)
    description = (request.form.get('description') or '').strip()
    target_user_id = request.form.get('targetUserId', type=int)
    target_role = request.form.get('targetRole')
    store_id = request.form.get('storeId', type=int)
    order_id = request.form.get('orderId', type=int)

    if not description:
        return jsonify(msg='Description is required'), 400
    if len(description) < 10:
        return jsonify(msg='Please provide at least 10 characters'), 400

    resolved, err = validate_and_resolve_report(
        reporter_user_id=user.id,
        reporter_role=reporter_role,
        report_type_id=report_type_id,
        target_user_id=target_user_id,
        target_role=target_role,
        store_id=store_id,
        order_id=order_id,
    )
    if err:
        return jsonify(msg=err), 400

    rt = resolved["report_type"]
    target_user_id = resolved["target_user_id"]
    target_role = resolved["target_role"]
    store_id = resolved.get("store_id")
    order_id = resolved.get("order_id")

    try:
        report = ProblemReport(
            reporter_user_id=user.id,
            reporter_role=reporter_role,
            report_type_id=rt.id,
            description=description,
            status=ReportStatus.PENDING,
            priority='medium',
            target_user_id=target_user_id,
            target_role=target_role,
            store_id=store_id,
            order_id=order_id,
        )
        db.session.add(report)
        db.session.flush()

        from app.utils.upload import save_upload

        files = request.files.getlist('evidence')
        file_count = 0
        for f in files:
            if f and f.filename and allowed_file(f.filename):
                if file_count >= MAX_EVIDENCE_FILES:
                    break
                filename = secure_filename(f.filename)
                ts = datetime.datetime.now().strftime('%Y%m%d%H%M%S')
                unique_name = f'report_{report.id}_{ts}_{filename}'
                stored_path = save_upload(
                    f, "report_evidence", filename=unique_name
                )

                evidence = ReportEvidence(
                    report_id=report.id,
                    file_path=stored_path,
                    file_type='image',
                    original_filename=filename,
                )
                db.session.add(evidence)
                file_count += 1

        try:
            _notify_admins_new_report(report)
        except Exception:
            current_app.logger.warning("Failed to notify admins about new report", exc_info=True)

        if target_role == "seller" and store_id:
            try:
                from app.services.product_moderation_service import ProductModerationService

                ProductModerationService.flag_products_for_store_report(
                    store_id=store_id,
                    reason=f"Report #{report.id}: {description[:200]}",
                    order_id=order_id,
                )
            except Exception:
                current_app.logger.warning("Failed to flag products for report", exc_info=True)

        db.session.commit()

        return jsonify(
            msg='Report submitted. Our team will review it shortly.',
            report=serialize_report(report),
        ), 201

    except Exception:
        db.session.rollback()
        return jsonify(msg='Failed to submit report'), 500


@reports_bp.get('')
@jwt_required()
def get_my_reports():
    user_id = current_user.id
    stmt = (
        select(ProblemReport)
        .where(ProblemReport.reporter_user_id == user_id)
        .options(
            selectinload(ProblemReport.evidence),
            selectinload(ProblemReport.report_type),
        )
        .order_by(ProblemReport.created_at.desc())
    )
    reports = db.session.execute(stmt).scalars().all()

    store_ids = {r.store_id for r in reports if r.store_id}
    order_ids = {r.order_id for r in reports if r.order_id}
    stores_by_id: dict[int, Store] = {}
    orders_by_id: dict[int, Order] = {}
    if store_ids:
        for s in db.session.execute(select(Store).where(Store.id.in_(store_ids))).scalars():
            stores_by_id[s.id] = s
    if order_ids:
        for o in db.session.execute(select(Order).where(Order.id.in_(order_ids))).scalars():
            orders_by_id[o.id] = o

    return jsonify(
        reports=_enrich_reports_for_reporter(reports, stores_by_id, orders_by_id),
    ), 200


@reports_bp.get('/<int:report_id>')
@jwt_required()
def get_my_report(report_id: int):
    user_id = current_user.id
    report = db.session.execute(
        select(ProblemReport)
        .where(
            ProblemReport.id == report_id,
            ProblemReport.reporter_user_id == user_id,
        )
        .options(
            selectinload(ProblemReport.evidence),
            selectinload(ProblemReport.report_type),
        )
    ).scalar_one_or_none()
    if report is None:
        return jsonify(msg='Report not found'), 404

    stores_by_id: dict[int, Store] = {}
    orders_by_id: dict[int, Order] = {}
    if report.store_id:
        store = db.session.get(Store, report.store_id)
        if store:
            stores_by_id[store.id] = store
    if report.order_id:
        order = db.session.get(Order, report.order_id)
        if order:
            orders_by_id[order.id] = order

    enriched = _enrich_reports_for_reporter([report], stores_by_id, orders_by_id)
    return jsonify(report=enriched[0]), 200


@reports_bp.get('/punishments')
@jwt_required()
def get_my_punishments():
    user_id = current_user.id
    stmt = select(Punishment).where(
        Punishment.user_id == user_id
    ).order_by(Punishment.created_at.desc())
    punishments = db.session.execute(stmt).scalars().all()
    return jsonify(punishments=[serialize_punishment(p) for p in punishments]), 200


@reports_bp.get('/violations')
@jwt_required()
def get_my_violations():
    user_id = current_user.id
    stmt = select(ViolationHistory).where(
        ViolationHistory.user_id == user_id
    ).order_by(ViolationHistory.created_at.desc())
    violations = db.session.execute(stmt).scalars().all()
    return jsonify(violations=[serialize_violation(v) for v in violations]), 200


# ---- Admin endpoints ----

@reports_bp.get('/admin')
@jwt_required()
@admin_required()
def admin_list_reports():
    status = request.args.get('status')
    reporter_role = request.args.get('reporterRole')
    target_role = request.args.get('targetRole')
    priority = request.args.get('priority')
    report_type_id = request.args.get('reportTypeId', type=int)

    stmt = select(ProblemReport).order_by(ProblemReport.created_at.desc())

    if status:
        stmt = stmt.where(ProblemReport.status == ReportStatus(status))
    if reporter_role:
        stmt = stmt.where(ProblemReport.reporter_role == reporter_role)
    if target_role:
        stmt = stmt.where(ProblemReport.target_role == target_role)
    if priority:
        stmt = stmt.where(ProblemReport.priority == priority)
    if report_type_id:
        stmt = stmt.where(ProblemReport.report_type_id == report_type_id)

    reports = db.session.execute(stmt).scalars().all()
    return jsonify(reports=[serialize_report(r) for r in reports]), 200


@reports_bp.get('/admin/<int:report_id>')
@jwt_required()
@admin_required()
def admin_get_report(report_id: int):
    report = db.session.execute(
        select(ProblemReport)
        .where(ProblemReport.id == report_id)
        .options(
            selectinload(ProblemReport.evidence),
            selectinload(ProblemReport.punishments),
            selectinload(ProblemReport.report_type),
        )
    ).scalar_one_or_none()
    if report is None:
        return jsonify(msg='Report not found'), 404
    return jsonify(report=serialize_report(report)), 200


@reports_bp.patch('/admin/<int:report_id>')
@jwt_required()
@admin_required()
def admin_update_report(report_id: int):
    report = db.session.get(ProblemReport, report_id)
    if report is None:
        return jsonify(msg='Report not found'), 404

    data = request.get_json() or {}

    new_status = data.get('status')
    if new_status:
        report.status = ReportStatus(new_status)
        if new_status in ('resolved', 'dismissed'):
            report.resolved_by = current_user.id
            report.resolved_at = datetime.datetime.now()

    if 'adminNotes' in data:
        report.admin_notes = data['adminNotes']

    if 'priority' in data:
        report.priority = data['priority']

    db.session.commit()
    return jsonify(report=serialize_report(report)), 200


@reports_bp.post('/admin/<int:report_id>/punish')
@jwt_required()
@admin_required()
def admin_issue_punishment(report_id: int):
    report = db.session.get(ProblemReport, report_id)
    if report is None:
        return jsonify(msg='Report not found'), 404

    data = request.get_json() or {}

    severity_str = data.get('severity')
    user_id = data.get('userId') or report.target_user_id
    restriction_type = data.get('restrictionType')
    reason = data.get('reason', '').strip()
    end_date_str = data.get('endDate')

    if not severity_str or severity_str not in ('warning', 'restriction', 'ban'):
        return jsonify(msg='Valid severity (warning/restriction/ban) is required'), 400
    if not user_id:
        return jsonify(msg='userId is required'), 400
    if not reason:
        return jsonify(msg='Reason is required'), 400

    target_user = db.session.get(User, user_id)
    if target_user is None:
        return jsonify(msg='User not found'), 404

    end_date = None
    if end_date_str:
        try:
            end_date = datetime.datetime.fromisoformat(end_date_str)
        except ValueError:
            return jsonify(msg='Invalid endDate format'), 400

    report_type_key = report.report_type.type_key if report.report_type else None
    if report_type_key and not restriction_type:
        defaults = TYPE_PUNISHMENT_DEFAULTS.get(report_type_key)
        if defaults:
            if severity_str == 'warning' and defaults.get('severity') != 'warning':
                severity_str = defaults['severity']
            restriction_type = defaults.get('restrictionType')
            if not end_date and defaults.get('days'):
                end_date = datetime.datetime.utcnow() + datetime.timedelta(days=int(defaults['days']))

    try:
        punishment = Punishment(
            report_id=report.id,
            user_id=user_id,
            severity=PunishmentSeverity(severity_str),
            restriction_type=restriction_type,
            reason=reason,
            issued_by=current_user.id,
            end_date=end_date,
            is_active=True,
        )
        db.session.add(punishment)
        db.session.flush()

        violation = ViolationHistory(
            user_id=user_id,
            report_id=report.id,
            punishment_id=punishment.id,
            violation_type=severity_str,
            description=f"{severity_str.capitalize()} issued for: {reason[:200]}",
            issued_by=current_user.id,
        )
        db.session.add(violation)

        report.status = ReportStatus.RESOLVED
        report.resolved_by = current_user.id
        report.resolved_at = datetime.datetime.now()

        db.session.commit()
        return jsonify(
            msg=f'{severity_str.capitalize()} issued successfully',
            punishment=serialize_punishment(punishment),
        ), 201

    except Exception:
        db.session.rollback()
        return jsonify(msg='Failed to issue punishment'), 500


@reports_bp.get('/admin/punishments')
@jwt_required()
@admin_required()
def admin_list_punishments():
    user_id = request.args.get('userId', type=int)
    stmt = select(Punishment).order_by(Punishment.created_at.desc())
    if user_id:
        stmt = stmt.where(Punishment.user_id == user_id)
    punishments = db.session.execute(stmt).scalars().all()
    return jsonify(punishments=[serialize_punishment(p) for p in punishments]), 200


@reports_bp.patch('/admin/punishments/<int:punishment_id>')
@jwt_required()
@admin_required()
def admin_update_punishment(punishment_id: int):
    punishment = db.session.get(Punishment, punishment_id)
    if punishment is None:
        return jsonify(msg='Punishment not found'), 404

    data = request.get_json() or {}

    if 'isActive' in data:
        punishment.is_active = data['isActive']
    if 'endDate' in data:
        if data['endDate']:
            punishment.end_date = datetime.datetime.fromisoformat(data['endDate'])
        else:
            punishment.end_date = None
    if 'reason' in data:
        punishment.reason = data['reason']

    db.session.commit()
    return jsonify(punishment=serialize_punishment(punishment)), 200


@reports_bp.get('/admin/violations/<int:user_id>')
@jwt_required()
@admin_required()
def admin_user_violations(user_id: int):
    stmt = select(ViolationHistory).where(
        ViolationHistory.user_id == user_id
    ).order_by(ViolationHistory.created_at.desc())
    violations = db.session.execute(stmt).scalars().all()
    return jsonify(violations=[serialize_violation(v) for v in violations]), 200
