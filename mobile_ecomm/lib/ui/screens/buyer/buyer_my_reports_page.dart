import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/routes/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/problem_report_model.dart';
import '../../../data/providers/reports_notifier.dart';

class BuyerMyReportsPage extends ConsumerStatefulWidget {
  const BuyerMyReportsPage({super.key});

  @override
  ConsumerState<BuyerMyReportsPage> createState() => _BuyerMyReportsPageState();
}

class _BuyerMyReportsPageState extends ConsumerState<BuyerMyReportsPage> {
  String _statusFilter = 'all';
  int? _expandedId;

  static const _filters = [
    ('all', 'All'),
    ('pending', 'Pending'),
    ('under_review', 'Under review'),
    ('investigating', 'Investigating'),
    ('resolved', 'Resolved'),
    ('dismissed', 'Dismissed'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reportsProvider.notifier).fetchMyReports();
    });
  }

  List<ProblemReportModel> _filtered(List<ProblemReportModel> reports) {
    if (_statusFilter == 'all') return reports;
    return reports.where((r) => r.status == _statusFilter).toList();
  }

  Color _statusColor(String status, bool isDark) {
    switch (status) {
      case 'pending':
        return isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706);
      case 'under_review':
        return isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
      case 'investigating':
        return isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
      case 'resolved':
        return isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
      case 'dismissed':
        return isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.background;
    final muted = isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground;
    final foreground = isDark ? AppColors.darkForeground : AppColors.charcoal;
    final filtered = _filtered(state.myReports);
    final openCount = state.openReportCount;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: foreground,
        title: const Text('My Reports'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(reportsProvider.notifier).fetchMyReports(),
        child: state.isLoadingReports && state.myReports.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Track problems you reported about stores, riders, or orders.',
                    style: TextStyle(
                      color: muted,
                      fontSize: 14,
                    ),
                  ),
                  if (openCount > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '$openCount open ${openCount == 1 ? 'report' : 'reports'}',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filters.map((f) {
                        final selected = _statusFilter == f.$1;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(f.$2),
                            selected: selected,
                            showCheckmark: false,
                            onSelected: (_) =>
                                setState(() => _statusFilter = f.$1),
                            labelStyle: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            selectedColor: theme.colorScheme.primary,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            side: BorderSide(
                              color: selected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline
                                      .withValues(alpha: 0.35),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (state.error != null && state.myReports.isEmpty)
                    Text(
                      state.error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  if (filtered.isEmpty && !state.isLoadingReports)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          Icon(
                            Icons.report_outlined,
                            size: 48,
                            color: muted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No reports in this view',
                            style: TextStyle(color: muted),
                          ),
                        ],
                      ),
                    ),
                  ...filtered.map((report) {
                    final expanded = _expandedId == report.id;
                    final statusColor = _statusColor(report.status, isDark);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: isDark ? AppColors.darkCard : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.border,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(
                          () => _expandedId = expanded ? null : report.id,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          report.reportType ??
                                              'Report #${report.id}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                            color: foreground,
                                          ),
                                        ),
                                        if (report.targetLabel != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            report.targetLabel!,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: muted,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      reportStatusLabel(report.status),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _formatDate(report.createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: muted,
                                ),
                              ),
                              if (expanded) ...[
                                Divider(
                                  height: 20,
                                  color: isDark
                                      ? AppColors.darkBorder
                                      : AppColors.border,
                                ),
                                Text(
                                  report.description,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: foreground,
                                  ),
                                ),
                                if (report.evidence.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    'Evidence',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: report.evidence.map((e) {
                                      if (e.isPdf) {
                                        return OutlinedButton.icon(
                                          onPressed: () async {
                                            final url = e.fileUrl;
                                            if (url == null) return;
                                            await launchUrl(Uri.parse(url));
                                          },
                                          icon: const Icon(Icons.picture_as_pdf),
                                          label: Text(
                                            e.originalFilename ?? 'PDF',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }
                                      final url = e.fileUrl;
                                      if (url == null) return const SizedBox.shrink();
                                      return ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedNetworkImage(
                                          imageUrl: url,
                                          width: 72,
                                          height: 72,
                                          fit: BoxFit.cover,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 12,
                                  children: [
                                    if (report.orderId != null)
                                      TextButton.icon(
                                        onPressed: () => context.push(
                                          AppRouter.buyerOrderPath(
                                            report.orderId.toString(),
                                          ),
                                        ),
                                        icon: const Icon(Icons.receipt_long_outlined),
                                        label: Text(
                                          report.order?.displayId ??
                                              'Order #${report.orderId}',
                                        ),
                                      ),
                                    if (report.storeId != null)
                                      TextButton.icon(
                                        onPressed: () => context.push(
                                          AppRouter.storePath(
                                            report.storeId.toString(),
                                          ),
                                        ),
                                        icon: const Icon(Icons.storefront_outlined),
                                        label: Text(
                                          report.store?.name ??
                                              'Store #${report.storeId}',
                                        ),
                                      ),
                                  ],
                                ),
                              ] else ...[
                                const SizedBox(height: 6),
                                Text(
                                  report.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: muted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.month}/${d.day}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
