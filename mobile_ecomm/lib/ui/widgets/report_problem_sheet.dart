import 'package:flutter/material.dart';

import '../../core/report/report_navigation.dart';

/// Legacy entry points — navigates to v2 [ReportSubmitScreen] or My Reports.
enum ReportCategory { store, rider }

extension ReportCategoryTarget on ReportCategory {
  String get targetRole {
    switch (this) {
      case ReportCategory.store:
        return 'seller';
      case ReportCategory.rider:
        return 'rider';
    }
  }
}

/// Opens the full report submit flow (replaces deprecated bottom sheet).
void showReportProblemSheet(
  BuildContext context, {
  required ReportCategory category,
  int? storeId,
  int? orderId,
  String? label,
}) {
  openReportSubmit(
    context,
    targetRole: category.targetRole,
    storeId: storeId,
    orderId: orderId,
    label: label,
  );
}

/// Profile/help: no target context — open My Reports instead.
void showReportHelpOrMyReports(BuildContext context) {
  openMyReports(context);
}
