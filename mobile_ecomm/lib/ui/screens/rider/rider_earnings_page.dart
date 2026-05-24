import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/format_utils.dart';
import '../../../data/models/rider_dashboard_stats.dart';
import '../../../data/providers/auth_notifier.dart';
import '../../../data/providers/rider_notifier.dart';
import '../../widgets/rider_delivery_widgets.dart';

const Color kPrimaryPink = Color(0xFFE891A0);

class RiderEarningsPage extends ConsumerStatefulWidget {
  const RiderEarningsPage({super.key});

  @override
  ConsumerState<RiderEarningsPage> createState() => _RiderEarningsPageState();
}

class _RiderEarningsPageState extends ConsumerState<RiderEarningsPage> {
  String _timeRange = 'week';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(riderProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isVerified = ref.watch(authProvider).isVerified;
    final riderState = ref.watch(riderProvider);
    final series =
        ref.read(riderProvider.notifier).earningsSeries(_timeRange);
    final totalEarnings =
        series.fold(0.0, (sum, d) => sum + d.earnings);
    final totalDeliveries =
        series.fold(0, (sum, d) => sum + d.deliveries);
    final avgPerDelivery =
        totalDeliveries > 0 ? totalEarnings / totalDeliveries : 0.0;

    return RefreshIndicator(
      onRefresh: () => ref.read(riderProvider.notifier).refresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Earnings',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Track your delivery earnings and performance.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
          if (!isVerified)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: RiderVerificationNotice(),
              ),
            ),
          if (riderState.error != null && isVerified)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: MaterialBanner(
                  content: Text(riderState.error!),
                  actions: [
                    TextButton(
                      onPressed: () =>
                          ref.read(riderProvider.notifier).refresh(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: [
                  _statCard(Icons.account_balance_wallet, Colors.green,
                      FormatUtils.peso(riderState.stats.earnings), "Today's Earnings"),
                  _statCard(Icons.local_shipping, Colors.blue,
                      '${riderState.stats.todayDeliveries}', "Today's Deliveries"),
                  _statCard(Icons.check_circle, Colors.purple,
                      '${riderState.stats.completed}', 'Completed'),
                  _statCard(Icons.calculate, Colors.orange,
                      FormatUtils.pesoWhole(avgPerDelivery), 'Avg per Delivery'),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _rangeChip('week', 'Week'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _rangeChip('month', 'Month'),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Earnings Overview',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          FormatUtils.peso(totalEarnings),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: kPrimaryPink,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 200,
                      child: riderState.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : series.isEmpty
                              ? const Center(
                                  child: Text('No earnings in this period.'),
                                )
                              : _buildChart(series),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _rangeChip(String value, String label) {
    final selected = _timeRange == value;
    return GestureDetector(
      onTap: () => setState(() => _timeRange = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? kPrimaryPink : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, Color color, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const Spacer(),
          Text(value,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildChart(List<RiderEarningsPoint> series) {
    final maxEarnings = series.fold<double>(
      0,
      (max, d) => d.earnings > max ? d.earnings : max,
    );
    final scale = maxEarnings > 0 ? 160 / maxEarnings : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        const barWidth = 32.0;
        const spacing = 4.0;
        final totalContentWidth =
            series.length * barWidth + (series.length - 1) * spacing;
        final fillViewport = totalContentWidth < constraints.maxWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: fillViewport ? constraints.maxWidth : null,
            child: Row(
              mainAxisAlignment: fillViewport
                  ? MainAxisAlignment.spaceEvenly
                  : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: series.map((data) {
                final barHeight = data.earnings * scale;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 32,
                        height: maxEarnings > 0 ? barHeight.clamp(4.0, 160.0) : 4,
                        decoration: const BoxDecoration(
                          color: kPrimaryPink,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data.day,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF757575)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
