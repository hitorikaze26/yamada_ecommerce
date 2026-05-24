import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/utils/format_utils.dart';
import '../../../data/models/product_review_model.dart';
import '../../../data/services/orders_api.dart';

class OrderReviewPage extends StatefulWidget {
  final String orderId;
  final bool fromConfirm;

  const OrderReviewPage({
    super.key,
    required this.orderId,
    this.fromConfirm = false,
  });

  @override
  State<OrderReviewPage> createState() => _OrderReviewPageState();
}

class _OrderReviewPageState extends State<OrderReviewPage> {
  bool _loading = true;
  OrderReviewsData? _data;
  final Set<int> _submitted = {};
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await OrdersApi.getOrderReviews(widget.orderId);
      if (mounted) setState(() => _data = data);
    } catch (_) {
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: 'Failed to load review form',
          variant: AlertVariant.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _pendingCount {
    if (_data == null) return 0;
    return _data!.reviewableItems
        .where((i) => !_submitted.contains(i.orderItemId))
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.background;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        title: const Text(
          'Rate your order',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text(
              'Skip',
              style: TextStyle(
                color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? _buildMessage(
                  isDark,
                  icon: Icons.error_outline,
                  title: 'Unable to load',
                  subtitle: 'Please try again from your orders.',
                )
              : _data!.reviewableItems.isEmpty
                  ? _buildAllDone(isDark)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(isDark),
                        if (_data!.reviewableItems.length > 1) _buildProgress(isDark),
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            onPageChanged: (i) => setState(() => _currentPage = i),
                            itemCount: _data!.reviewableItems.length,
                            itemBuilder: (context, index) {
                              final item = _data!.reviewableItems[index];
                              if (_submitted.contains(item.orderItemId)) {
                                return _SubmittedCard(
                                  item: item,
                                  isDark: isDark,
                                );
                              }
                              return SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                child: _ReviewItemForm(
                                  item: item,
                                  deliveryPillOptions: _data!.deliveryPillOptions,
                                  orderId: widget.orderId,
                                  itemIndex: index + 1,
                                  itemTotal: _data!.reviewableItems.length,
                                  onSubmitted: () {
                                    setState(() {
                                      _submitted.add(item.orderItemId);
                                    });
                                    if (_pendingCount > 0 &&
                                        index < _data!.reviewableItems.length - 1) {
                                      _pageController.nextPage(
                                        duration: const Duration(milliseconds: 350),
                                        curve: Curves.easeOutCubic,
                                      );
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  AppColors.rosewood.withValues(alpha: 0.25),
                  AppColors.darkCard,
                ]
              : [
                  AppColors.rosewood.withValues(alpha: 0.08),
                  Colors.white,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.rosewood.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.star_rounded, color: Colors.amber, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.fromConfirm
                      ? 'Thanks for confirming!'
                      : 'Share your experience',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: isDark ? Colors.white : AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _pendingCount > 0
                      ? 'Rate $_pendingCount item${_pendingCount == 1 ? '' : 's'} — helps other shoppers.'
                      : 'All items reviewed. You can go back anytime.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkMutedForeground
                        : AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate(effects: AppAnimations.fadeIn());
  }

  Widget _buildProgress(bool isDark) {
    final items = _data!.reviewableItems;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Item ${_currentPage + 1} of ${items.length}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(items.length, (i) {
              final done = _submitted.contains(items[i].orderItemId);
              final active = i == _currentPage;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < items.length - 1 ? 6 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: done
                        ? Colors.green
                        : active
                            ? AppColors.rosewood
                            : (isDark ? AppColors.darkMuted : AppColors.muted),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildAllDone(bool isDark) {
    final allReviewed = _data!.reviews.isNotEmpty;
    return _buildMessage(
      isDark,
      icon: Icons.check_circle_outline,
      iconColor: Colors.green,
      title: allReviewed ? 'All done!' : 'Nothing to review',
      subtitle: allReviewed
          ? 'Thank you for your feedback.'
          : 'No items available for review on this order.',
      action: FilledButton(
        onPressed: () => context.pop(),
        child: const Text('Back to order'),
      ),
    );
  }

  Widget _buildMessage(
    bool isDark, {
    required IconData icon,
    required String title,
    required String subtitle,
    Color? iconColor,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: iconColor ?? AppColors.mutedForeground),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 24), action],
          ],
        ),
      ),
    );
  }
}

class _SubmittedCard extends StatelessWidget {
  final ReviewableOrderItem item;
  final bool isDark;

  const _SubmittedCard({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: isDark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 48),
              const SizedBox(height: 12),
              Text(
                item.productName ?? 'Item',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.charcoal,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Review submitted — thank you!',
                style: TextStyle(color: AppColors.mutedForeground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewItemForm extends StatefulWidget {
  final ReviewableOrderItem item;
  final List<String> deliveryPillOptions;
  final String orderId;
  final int itemIndex;
  final int itemTotal;
  final VoidCallback onSubmitted;

  const _ReviewItemForm({
    required this.item,
    required this.deliveryPillOptions,
    required this.orderId,
    required this.itemIndex,
    required this.itemTotal,
    required this.onSubmitted,
  });

  @override
  State<_ReviewItemForm> createState() => _ReviewItemFormState();
}

class _ReviewItemFormState extends State<_ReviewItemForm> {
  int _overallRating = 0;
  final Map<String, int> _ratings = {};
  final _commentController = TextEditingController();
  int _deliverySatisfaction = 0;
  final Set<String> _pills = {};
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final format = widget.item.reviewFormat;
    final keys = dimensionKeysForFormat(format);
    final labels = dimensionLabelsForFormat(format);

    if (format == 'default' && _overallRating < 1) {
      _toast('Please select an overall rating', AlertVariant.warning);
      return;
    }
    for (final key in keys) {
      if ((_ratings[key] ?? 0) < 1) {
        _toast('Please rate ${labels[key]}', AlertVariant.warning);
        return;
      }
    }
    if (_deliverySatisfaction < 1) {
      _toast('Please rate delivery satisfaction', AlertVariant.warning);
      return;
    }

    setState(() => _submitting = true);
    try {
      await OrdersApi.addReview(
        widget.orderId,
        orderItemId: widget.item.orderItemId,
        reviewFormat: format,
        overallRating: format == 'default' ? _overallRating : null,
        ratings: _ratings,
        customerReview: _commentController.text.trim(),
        deliverySatisfaction: _deliverySatisfaction,
        deliveryPills: _pills.toList(),
      );
      widget.onSubmitted();
      if (mounted) {
        _toast('Review submitted', AlertVariant.success);
      }
    } catch (e) {
      if (mounted) {
        _toast(e.toString().replaceFirst('Exception: ', ''), AlertVariant.error);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String message, AlertVariant variant) {
    AlertService.showSnackBar(context: context, message: message, variant: variant);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = widget.item;
    final format = item.reviewFormat;
    final keys = dimensionKeysForFormat(format);
    final labels = dimensionLabelsForFormat(format);
    final lineTotal = item.unitPrice != null && item.quantity != null
        ? item.unitPrice! * item.quantity!
        : item.unitPrice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProductHeader(
          item: item,
          lineTotal: lineTotal,
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        if (format == 'default') ...[
          _SectionCard(
            isDark: isDark,
            icon: Icons.star_rounded,
            iconColor: Colors.amber,
            title: 'Overall rating',
            child: _LargeStars(
              value: _overallRating,
              onChanged: (v) => setState(() => _overallRating = v),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _SectionCard(
          isDark: isDark,
          icon: Icons.fact_check_outlined,
          title: 'Product quality',
          child: Column(
            children: keys
                .map(
                  (key) => _RatingRow(
                    label: labels[key] ?? key,
                    value: _ratings[key] ?? 0,
                    onChanged: (v) => setState(() => _ratings[key] = v),
                    isDark: isDark,
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          isDark: isDark,
          icon: Icons.rate_review_outlined,
          title: 'Your review',
          child: TextField(
            controller: _commentController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Fit, fabric, accuracy vs photos, etc.',
              filled: true,
              fillColor: isDark ? AppColors.darkBackground : AppColors.offWhite,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          isDark: isDark,
          icon: Icons.local_shipping_outlined,
          iconColor: AppColors.primary,
          title: 'Delivery experience',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Satisfaction',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 8),
              _LargeStars(
                value: _deliverySatisfaction,
                onChanged: (v) => setState(() => _deliverySatisfaction = v),
              ),
              const SizedBox(height: 16),
              Text(
                'Comments (optional)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.deliveryPillOptions.map((pill) {
                  final selected = _pills.contains(pill);
                  return FilterChip(
                    label: Text(pill, style: const TextStyle(fontSize: 12)),
                    selected: selected,
                    selectedColor: AppColors.rosewood.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.rosewood,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _pills.add(pill);
                        } else {
                          _pills.remove(pill);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.rosewood,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _submitting
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Submit review',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
        ),
      ],
    );
  }
}

class _ProductHeader extends StatelessWidget {
  final ReviewableOrderItem item;
  final double? lineTotal;
  final bool isDark;

  const _ProductHeader({
    required this.item,
    required this.lineTotal,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PRODUCT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.productName ?? 'Item',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: isDark ? Colors.white : AppColors.charcoal,
                  ),
                ),
                if (item.variantLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.variantLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (lineTotal != null)
            Text(
              FormatUtils.peso(lineTotal!),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.rosewood,
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final Color? iconColor;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.child,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor ?? AppColors.rosewood),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? Colors.white : AppColors.charcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _LargeStars extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _LargeStars({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final star = i + 1;
        return IconButton(
          onPressed: () => onChanged(star),
          icon: Icon(
            star <= value ? Icons.star_rounded : Icons.star_outline_rounded,
            color: Colors.amber,
            size: 36,
          ),
        );
      }),
    );
  }
}

class _RatingRow extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final bool isDark;

  const _RatingRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkForeground : AppColors.charcoal,
              ),
            ),
          ),
          ...List.generate(5, (i) {
            final star = i + 1;
            return GestureDetector(
              onTap: () => onChanged(star),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  star <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: Colors.amber,
                  size: 22,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
