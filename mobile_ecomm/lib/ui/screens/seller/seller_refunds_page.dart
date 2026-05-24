import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/services/alert_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format_utils.dart';
import '../../../data/services/seller_refunds_api.dart';

class SellerRefundsPage extends StatefulWidget {
  const SellerRefundsPage({super.key});

  @override
  State<SellerRefundsPage> createState() => _SellerRefundsPageState();
}

class _SellerRefundsPageState extends State<SellerRefundsPage> {
  List<SellerRefundRequest> _refunds = [];
  bool _loading = true;
  int? _expandedId;
  int? _actingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await SellerRefundsApi.getRefundRequests();
      if (mounted) setState(() => _refunds = list);
    } catch (e) {
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: 'Failed to load refunds',
          variant: AlertVariant.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _canAct(String status) {
    final s = status.toLowerCase();
    return s == 'requested' || s == 'pending';
  }

  String _formatStatus(String status) {
    final s = status.toLowerCase();
    switch (s) {
      case 'requested':
        return 'Pending review';
      case 'approved_by_seller':
        return 'Approved by you';
      case 'rejected_by_seller':
        return 'Rejected by you';
      default:
        return s
            .replaceAll('_', ' ')
            .split(' ')
            .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' ');
    }
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'requested' || s == 'pending') return AppColors.processing;
    if (s.contains('approved') || s == 'completed') return AppColors.delivered;
    if (s.contains('reject')) return AppColors.destructive;
    return AppColors.mutedForeground;
  }

  Future<void> _approve(SellerRefundRequest r) async {
    final orderLabel = r.order?.displayId ?? (r.orderId != null ? '#${r.orderId}' : '—');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve refund?'),
        content: Text(
          'Approve refund of ${FormatUtils.peso(r.netAmount)} for order $orderLabel?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Approve')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _actingId = r.id);
    try {
      await SellerRefundsApi.approve(r.id);
      await _load();
      if (mounted) {
        setState(() => _expandedId = null);
        AlertService.showSnackBar(
          context: context,
          message: 'Refund approved',
          variant: AlertVariant.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: e.toString().replaceAll('Exception: ', ''),
          variant: AlertVariant.error,
        );
      }
    } finally {
      if (mounted) setState(() => _actingId = null);
    }
  }

  Future<void> _reject(SellerRefundRequest r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject refund?'),
        content: const Text('The buyer will be notified of your decision.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _actingId = r.id);
    try {
      await SellerRefundsApi.reject(r.id);
      await _load();
      if (mounted) {
        setState(() => _expandedId = null);
        AlertService.showSnackBar(
          context: context,
          message: 'Refund rejected',
          variant: AlertVariant.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: e.toString().replaceAll('Exception: ', ''),
          variant: AlertVariant.error,
        );
      }
    } finally {
      if (mounted) setState(() => _actingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkCard : AppColors.card;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return Scaffold(
      appBar: AppBar(title: const Text('Refund requests')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _refunds.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 48, color: theme.colorScheme.outline),
                        const SizedBox(height: 12),
                        Text('No refund requests',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Text(
                          'Tap a request when one appears to view full details.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      Text(
                        'Tap a request to view buyer, order, and reason. Approve or reject while pending.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._refunds.map((r) {
                        final expanded = _expandedId == r.id;
                        final buyerName =
                            r.buyer?.name ?? r.buyer?.email ?? 'Customer';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          color: cardColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: expanded
                                  ? AppColors.rosewood.withValues(alpha: 0.5)
                                  : borderColor,
                            ),
                          ),
                          child: Column(
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => setState(
                                  () => _expandedId = expanded ? null : r.id,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: AppColors.rosewood
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.receipt_long_outlined,
                                          color: AppColors.rosewood,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Refund #${r.id}'
                                              '${r.order != null ? ' · ${r.order!.displayId}' : ''}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              buyerName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: theme
                                                    .colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            FormatUtils.peso(r.netAmount),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.rosewood,
                                            ),
                                          ),
                                          Container(
                                            margin: const EdgeInsets.only(top: 4),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _statusColor(r.status)
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              _formatStatus(r.status),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: _statusColor(r.status),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Icon(
                                        expanded
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (expanded)
                                _RefundExpandedBody(
                                  refund: r,
                                  acting: _actingId == r.id,
                                  canAct: _canAct(r.status),
                                  onApprove: () => _approve(r),
                                  onReject: () => _reject(r),
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}

class _RefundExpandedBody extends StatelessWidget {
  final SellerRefundRequest refund;
  final bool acting;
  final bool canAct;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RefundExpandedBody({
    required this.refund,
    required this.acting,
    required this.canAct,
    required this.onApprove,
    required this.onReject,
  });

  Map<String, String> _parseVariation(String? variation) {
    if (variation == null || variation.isEmpty) return {};
    try {
      final m = jsonDecode(variation) as Map<String, dynamic>;
      return {
        if (m['color'] != null) 'color': m['color'].toString(),
        if (m['size'] != null) 'size': m['size'].toString(),
      };
    } catch (_) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = refund;
    final order = r.order;
    final buyer = r.buyer;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _infoChip(context, 'Gross', FormatUtils.peso(r.amount)),
              _infoChip(context, 'Platform fee', FormatUtils.peso(r.platformFee)),
              if (r.transactionId != null)
                _infoChip(context, 'Transaction', '#${r.transactionId}'),
              if (r.paymentStatus != null)
                _infoChip(context, 'Payment', r.paymentStatus!),
              if (r.createdAt != null)
                _infoChip(context, 'Requested', _shortDate(r.createdAt!)),
              if (r.updatedAt != null)
                _infoChip(context, 'Updated', _shortDate(r.updatedAt!)),
            ],
          ),
          if (buyer != null) ...[
            const SizedBox(height: 12),
            _sectionCard(
              context,
              title: 'Buyer',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Name: ${buyer.name ?? '—'}',
                      style: const TextStyle(fontSize: 13)),
                  Text('Email: ${buyer.email ?? '—'}',
                      style: const TextStyle(fontSize: 13)),
                  if (buyer.contactNumber != null)
                    Text('Phone: ${buyer.contactNumber}',
                        style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
          if (order != null) ...[
            const SizedBox(height: 12),
            _sectionCard(
              context,
              title: 'Order summary',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Text('Subtotal: ${FormatUtils.peso(order.totalAmount)}',
                          style: const TextStyle(fontSize: 13)),
                      Text('Shipping: ${FormatUtils.peso(order.shippingFee)}',
                          style: const TextStyle(fontSize: 13)),
                      Text('Total: ${FormatUtils.peso(order.grandTotal)}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      if (order.paymentMethod != null)
                        Text('Payment: ${order.paymentMethod}',
                            style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                  if (order.items.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    ...order.items.map((item) {
                      final v = _parseVariation(item.variation);
                      final parts = <String>[
                        if (v['color'] != null) 'Color: ${v['color']}',
                        if (v['size'] != null) 'Size: ${v['size']}',
                        'Qty: ${item.quantity}',
                      ];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.productName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13)),
                                  if (parts.isNotEmpty)
                                    Text(parts.join(' · '),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        )),
                                ],
                              ),
                            ),
                            Text(
                              FormatUtils.peso(item.unitPrice * item.quantity),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _sectionCard(
            context,
            title: 'Buyer reason',
            child: Text(
              (r.reason?.trim().isNotEmpty ?? false)
                  ? r.reason!.trim()
                  : 'No reason provided.',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          if (canAct) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: acting ? null : onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.destructive,
                      side: const BorderSide(color: AppColors.destructive),
                    ),
                    child: const Text('Reject refund'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: acting ? null : onApprove,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.rosewood,
                    ),
                    child: acting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Approve refund'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoChip(BuildContext context, String label, String value) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _sectionCard(BuildContext context,
      {required String title, required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkMuted.withValues(alpha: 0.35)
            : AppColors.muted.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  String _shortDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${_month(d.month)} ${d.day}, ${d.year}';
    } catch (_) {
      return iso;
    }
  }

  String _month(int m) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return names[m - 1];
  }
}
