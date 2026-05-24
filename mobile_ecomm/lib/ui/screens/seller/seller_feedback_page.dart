import 'package:flutter/material.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/seller_insights_api.dart';
import '../../../data/models/product_review_model.dart';

class SellerFeedbackPage extends StatefulWidget {
  final bool embedded;

  const SellerFeedbackPage({super.key, this.embedded = false});

  @override
  State<SellerFeedbackPage> createState() => _SellerFeedbackPageState();
}

class _SellerFeedbackPageState extends State<SellerFeedbackPage> {
  String _sort = 'newest';
  String _status = 'all';
  List<SellerReviewItem> _reviews = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list =
          await SellerInsightsApi.getReviews(sort: _sort, status: _status);
      if (mounted) setState(() => _reviews = list);
    } catch (e) {
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: 'Failed to load reviews',
          variant: AlertVariant.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _patchReview(SellerReviewItem updated) {
    setState(() {
      _reviews = _reviews
          .map((r) => r.id == updated.id ? updated : r)
          .toList();
    });
  }

  Future<void> _reply(SellerReviewItem review) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasExisting =
        review.sellerReply != null && review.sellerReply!.isNotEmpty;
    final replyText = await showDialog<String>(
      context: context,
      builder: (ctx) => _SellerReplyDialog(
        initialText: review.sellerReply ?? '',
        isDark: isDark,
        isEdit: hasExisting,
      ),
    );
    if (!mounted || replyText == null || replyText.isEmpty) return;

    try {
      final updated =
          await SellerInsightsApi.replyToReview(review.id, replyText);
      if (!mounted) return;
      _patchReview(updated);
      AlertService.showSnackBar(
        context: context,
        message: 'Reply sent',
        variant: AlertVariant.success,
      );
    } catch (e) {
      if (!mounted) return;
      AlertService.showSnackBar(
        context: context,
        message: e.toString().replaceFirst('Exception: ', ''),
        variant: AlertVariant.error,
      );
    }
  }

  Future<void> _deleteReply(SellerReviewItem review) async {
    if (review.sellerReply == null || review.sellerReply!.trim().isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your reply?'),
        content: const Text(
          'The buyer will no longer see your response on this review.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
            child: const Text('Delete reply'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final updated = await SellerInsightsApi.deleteReviewReply(review.id);
      if (mounted) {
        _patchReview(updated);
        AlertService.showSnackBar(
          context: context,
          message: 'Reply removed',
          variant: AlertVariant.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: e.toString().replaceFirst('Exception: ', ''),
          variant: AlertVariant.error,
        );
      }
    }
  }

  Future<void> _moderate(
    SellerReviewItem review, {
    String? visibility,
    bool delete = false,
  }) async {
    try {
      await SellerInsightsApi.moderateReview(
        review.id,
        visibility: visibility,
        delete: delete,
      );
      await _load();
      if (mounted && delete) {
        AlertService.showSnackBar(
          context: context,
          message: 'Review removed',
          variant: AlertVariant.success,
        );
      }
    } catch (_) {
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: 'Action failed',
          variant: AlertVariant.error,
        );
      }
    }
  }

  void _confirmDelete(SellerReviewItem review) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete review?'),
        content: const Text(
          'This removes the review from your storefront. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _moderate(review, delete: true);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final muted = isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground;

    final body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                          AppColors.darkCard,
                        ]
                      : [
                          const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                          Colors.white,
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.rate_review_rounded,
                      color: Color(0xFF8B5CF6),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _loading ? '…' : '${_reviews.length} reviews',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppColors.charcoal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Reply, hide, or archive customer reviews on your products.',
                          style: TextStyle(fontSize: 12, color: muted, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _FilterRow(
            title: 'Sort',
            isDark: isDark,
            chips: [
              _FilterChipData('Newest', _sort == 'newest', () {
                setState(() => _sort = 'newest');
                _load();
              }),
              _FilterChipData('Oldest', _sort == 'oldest', () {
                setState(() => _sort = 'oldest');
                _load();
              }),
              _FilterChipData('High ★', _sort == 'rating_high', () {
                setState(() => _sort = 'rating_high');
                _load();
              }),
              _FilterChipData('Low ★', _sort == 'rating_low', () {
                setState(() => _sort = 'rating_low');
                _load();
              }),
            ],
          ),
          _FilterRow(
            title: 'Status',
            isDark: isDark,
            chips: [
              _FilterChipData('All', _status == 'all', () {
                setState(() => _status = 'all');
                _load();
              }),
              _FilterChipData('Visible', _status == 'visible', () {
                setState(() => _status = 'visible');
                _load();
              }),
              _FilterChipData('Hidden', _status == 'hidden', () {
                setState(() => _status = 'hidden');
                _load();
              }),
              _FilterChipData('Archived', _status == 'archived', () {
                setState(() => _status = 'archived');
                _load();
              }),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _reviews.isEmpty
                    ? _EmptyState(isDark: isDark)
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.rosewood,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: _reviews.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) => _ReviewCard(
                            review: _reviews[i],
                            isDark: isDark,
                            cardColor: cardColor,
                            borderColor: borderColor,
                            onReply: () => _reply(_reviews[i]),
                            onDeleteReply: () => _deleteReply(_reviews[i]),
                            onHide: () =>
                                _moderate(_reviews[i], visibility: 'hidden'),
                            onArchive: () =>
                                _moderate(_reviews[i], visibility: 'archived'),
                            onDelete: () => _confirmDelete(_reviews[i]),
                          ),
                        ),
                      ),
          ),
        ],
    );

    if (widget.embedded) {
      return ColoredBox(
        color: isDark ? AppColors.darkBackground : AppColors.background,
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Customer Feedback',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: body,
    );
  }
}

class _FilterChipData {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipData(this.label, this.selected, this.onTap);
}

class _FilterRow extends StatelessWidget {
  final String title;
  final bool isDark;
  final List<_FilterChipData> chips;

  const _FilterRow({
    required this.title,
    required this.isDark,
    required this.chips,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
            ),
          ),
        ),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: chips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final c = chips[i];
              return FilterChip(
                label: Text(c.label),
                selected: c.selected,
                onSelected: (_) => c.onTap(),
                showCheckmark: false,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.selected
                      ? Colors.white
                      : (isDark ? Colors.white70 : AppColors.charcoal),
                ),
                selectedColor: const Color(0xFF8B5CF6),
                backgroundColor:
                    isDark ? AppColors.darkCard : AppColors.offWhite,
                side: BorderSide(
                  color: c.selected
                      ? const Color(0xFF8B5CF6)
                      : (isDark ? AppColors.darkBorder : AppColors.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDark;

  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.reviews_outlined,
              size: 56,
              color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
            ),
            const SizedBox(height: 16),
            Text(
              'No reviews yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When customers rate your products, they will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final SellerReviewItem review;
  final bool isDark;
  final Color cardColor;
  final Color borderColor;
  final VoidCallback onReply;
  final VoidCallback onDeleteReply;
  final VoidCallback onHide;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  const _ReviewCard({
    required this.review,
    required this.isDark,
    required this.cardColor,
    required this.borderColor,
    required this.onReply,
    required this.onDeleteReply,
    required this.onHide,
    required this.onArchive,
    required this.onDelete,
  });

  Color _visibilityColor() {
    switch (review.visibility) {
      case 'hidden':
        return AppColors.pending;
      case 'archived':
        return AppColors.mutedForeground;
      default:
        return AppColors.delivered;
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
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
                        review.productName ?? 'Product',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isDark ? Colors.white : AppColors.charcoal,
                        ),
                      ),
                      if (review.buyerName != null) ...[
                        const SizedBox(height: 2),
                        Text(review.buyerName!, style: TextStyle(fontSize: 12, color: muted)),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _visibilityColor().withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    review.visibility,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _visibilityColor(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(
                5,
                (s) => Icon(
                  s < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 18,
                  color: Colors.amber.shade700,
                ),
              ),
            ),
            if (review.ratings.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...review.ratings.entries.map((e) {
                final labels = dimensionLabelsForFormat(review.reviewFormat);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        labels[e.key] ?? e.key,
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                      Text('${e.value}/5', style: TextStyle(fontSize: 12, color: muted)),
                    ],
                  ),
                );
              }),
            ],
            if (review.deliverySatisfaction != null) ...[
              const SizedBox(height: 6),
              Text(
                'Delivery satisfaction: ${review.deliverySatisfaction}/5',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
            if (review.deliveryPills.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: review.deliveryPills
                    .map((p) => Chip(
                          label: Text(p, style: const TextStyle(fontSize: 10)),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ],
            if (review.comment != null && review.comment!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                review.comment!,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.charcoal,
                ),
              ),
            ],
            if (review.sellerReply != null && review.sellerReply!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.rosewood.withValues(alpha: 0.15)
                      : AppColors.deliveredBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.rosewood.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Your reply',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.rosewood,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: onDeleteReply,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Delete reply',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.destructive,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      review.sellerReply!,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: isDark ? Colors.white70 : AppColors.charcoal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: onReply,
                  icon: const Icon(Icons.reply_outlined, size: 16),
                  label: Text(
                    review.sellerReply != null && review.sellerReply!.isNotEmpty
                        ? 'Edit reply'
                        : 'Reply',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.rosewood,
                    side: const BorderSide(color: AppColors.rosewood),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: onHide,
                  child: const Text('Hide', style: TextStyle(fontSize: 12)),
                ),
                TextButton(
                  onPressed: onArchive,
                  child: const Text('Archive', style: TextStyle(fontSize: 12)),
                ),
                TextButton(
                  onPressed: onDelete,
                  child: const Text(
                    'Delete review',
                    style: TextStyle(fontSize: 12, color: AppColors.destructive),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Reply dialog that owns its [TextEditingController] lifecycle (avoids disposing
/// the controller while the route is still closing — fixes _dependents.isEmpty).
class _SellerReplyDialog extends StatefulWidget {
  final String initialText;
  final bool isDark;
  final bool isEdit;

  const _SellerReplyDialog({
    required this.initialText,
    required this.isDark,
    required this.isEdit,
  });

  @override
  State<_SellerReplyDialog> createState() => _SellerReplyDialogState();
}

class _SellerReplyDialogState extends State<_SellerReplyDialog> {
  late final TextEditingController _controller;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reply cannot be empty')),
      );
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      title: Text(
        widget.isEdit ? 'Edit reply' : 'Reply to customer',
        style: TextStyle(color: isDark ? Colors.white : AppColors.charcoal),
      ),
      content: TextField(
        controller: _controller,
        maxLines: 4,
        enabled: !_submitting,
        style: TextStyle(color: isDark ? Colors.white : AppColors.charcoal),
        decoration: InputDecoration(
          hintText: 'Thank them and address their feedback…',
          filled: true,
          fillColor: isDark ? AppColors.darkBackground : AppColors.offWhite,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: AppColors.rosewood),
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Send reply'),
        ),
      ],
    );
  }
}
