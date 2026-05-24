from flask import Blueprint
from app.models import (
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

reports = Blueprint('reports', __name__)

from . import routes
