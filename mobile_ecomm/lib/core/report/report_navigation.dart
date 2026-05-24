import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routes/app_router.dart';
import '../services/alert_service.dart';

/// Arguments for [ReportSubmitScreen].
class ReportSubmitArgs {
  final String targetRole;
  final int? storeId;
  final int? orderId;
  final int? targetUserId;
  final String? contextLabel;

  const ReportSubmitArgs({
    required this.targetRole,
    this.storeId,
    this.orderId,
    this.targetUserId,
    this.contextLabel,
  });

  bool get hasRequiredContext {
    final role = targetRole.toLowerCase();
    if (role == 'seller') return storeId != null;
    if (role == 'rider' || role == 'buyer') return orderId != null;
    return false;
  }
}

ReportSubmitArgs? reportSubmitArgsFromExtra(Object? extra) {
  if (extra is ReportSubmitArgs) return extra;
  if (extra is Map) {
    return ReportSubmitArgs(
      targetRole: extra['targetRole']?.toString() ?? '',
      storeId: (extra['storeId'] as num?)?.toInt(),
      orderId: (extra['orderId'] as num?)?.toInt(),
      targetUserId: (extra['targetUserId'] as num?)?.toInt(),
      contextLabel: extra['contextLabel']?.toString(),
    );
  }
  return null;
}

void openReportSubmit(
  BuildContext context, {
  required String targetRole,
  int? storeId,
  int? orderId,
  int? targetUserId,
  String? label,
}) {
  final args = ReportSubmitArgs(
    targetRole: targetRole,
    storeId: storeId,
    orderId: orderId,
    targetUserId: targetUserId,
    contextLabel: label,
  );

  if (!args.hasRequiredContext) {
    AlertService.showSnackBar(
      context: context,
      message:
          'Open a report from a store profile or order to provide the required context.',
      variant: AlertVariant.warning,
    );
    return;
  }

  context.push(AppRouter.reportSubmit, extra: args);
}

void openMyReports(BuildContext context) {
  context.push(AppRouter.myReports);
}
