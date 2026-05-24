import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Shared banner when a buyer account is pending admin verification.
class BuyerVerificationBanner extends StatelessWidget {
  final bool isDark;
  final EdgeInsetsGeometry? margin;

  const BuyerVerificationBanner({
    super.key,
    required this.isDark,
    this.margin,
  });

  static const String message =
      'Your account is not yet verified. Please wait for admin approval before placing orders.';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin ?? const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.processing.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.processing.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: AppColors.processing,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.darkForeground : AppColors.charcoal,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Whether the current auth state should show the buyer verification banner.
bool shouldShowBuyerVerificationBanner({
  required bool isAuthenticated,
  required bool isVerified,
  required dynamic role,
}) {
  if (!isAuthenticated || isVerified) return false;
  final roleName = role?.toString() ?? '';
  return !roleName.contains('seller') &&
      !roleName.contains('rider') &&
      !roleName.contains('admin');
}
