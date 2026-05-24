import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../order/buyer_orders_ui.dart';
import 'buyer_profile_page.dart';

/// Buyer profile / orders host inside [BuyerShell].
class BuyerDashboard extends ConsumerWidget {
  final int initialTab;
  final bool embeddedInShell;
  final String? initialOrderFilter;

  const BuyerDashboard({
    super.key,
    this.initialTab = 0,
    this.embeddedInShell = false,
    this.initialOrderFilter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!embeddedInShell) {
      return const BuyerProfilePage();
    }

    if (initialTab == 1) {
      return Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.background,
        appBar: AppBar(
          title: const Text('My Orders'),
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: BuyerOrdersListView(
          initialFilter: initialOrderFilter,
          showInlineHeader: false,
        ),
      );
    }

    return const BuyerProfilePage();
  }
}
