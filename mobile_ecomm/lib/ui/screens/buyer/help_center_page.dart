import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/chat/chat_navigation.dart';

class HelpCenterPage extends ConsumerWidget {
  const HelpCenterPage({super.key});

  static const _supportEmail = 'yamadaecommerce929@gmail.com';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.background;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: const Text('Help Center'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(
            context,
            isDark,
            'Orders & delivery',
            'Track orders under Profile → My Orders. After a rider delivers, confirm receipt so you can leave a review.',
          ),
          _section(
            context,
            isDark,
            'Payments',
            'We currently support Cash on Delivery (COD). Pay when your order arrives.',
          ),
          _section(
            context,
            isDark,
            'Account verification',
            'New buyer accounts need admin approval before checkout. You can browse and add to cart while waiting.',
          ),
          _section(
            context,
            isDark,
            'Refunds & issues',
            'Request a refund from order details when eligible, or view reports you submitted from orders and stores.',
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => openSupportChat(context, ref),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Chat with support'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => context.push(AppRouter.myReports),
            icon: const Icon(Icons.report_outlined),
            label: const Text('My Reports'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(text: _supportEmail),
              );
              if (context.mounted) {
                AlertService.showSnackBar(
                  context: context,
                  message: 'Support email copied',
                  variant: AlertVariant.success,
                );
              }
            },
            icon: const Icon(Icons.email_outlined),
            label: Text('Copy $_supportEmail'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => context.push(AppRouter.addresses),
            child: const Text('Manage saved addresses'),
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context,
    bool isDark,
    String title,
    String body,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: TextStyle(
                height: 1.45,
                color: isDark
                    ? AppColors.darkMutedForeground
                    : AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
