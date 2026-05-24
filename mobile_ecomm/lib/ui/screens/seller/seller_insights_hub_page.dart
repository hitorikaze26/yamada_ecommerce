import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'seller_feedback_page.dart';
import 'seller_store_insights_page.dart';

/// Combined insights + reviews with tabs.
class SellerInsightsHubPage extends StatefulWidget {
  final int initialTabIndex;

  const SellerInsightsHubPage({super.key, this.initialTabIndex = 0});

  @override
  State<SellerInsightsHubPage> createState() => _SellerInsightsHubPageState();
}

class _SellerInsightsHubPageState extends State<SellerInsightsHubPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights & Reviews'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.rosewood,
          tabs: const [
            Tab(text: 'Store insights'),
            Tab(text: 'Reviews'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          SellerStoreInsightsPage(embedded: true),
          SellerFeedbackPage(embedded: true),
        ],
      ),
    );
  }
}
