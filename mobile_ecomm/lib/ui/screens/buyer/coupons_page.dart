import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format_utils.dart';
import '../../../data/services/coupons_api.dart';

class CouponsPage extends StatefulWidget {
  const CouponsPage({super.key});

  @override
  State<CouponsPage> createState() => _CouponsPageState();
}

class _CouponsPageState extends State<CouponsPage> {
  bool _loading = true;
  String? _error;
  List<CouponModel> _platform = [];
  List<CouponModel> _store = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await CouponsApi.getCoupons();
      setState(() {
        _platform = all.where((c) => c.scope == 'platform').toList();
        _store = all.where((c) => c.scope == 'store').toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    AlertService.showSnackBar(
      context: context,
      message: 'Coupon code copied',
      variant: AlertVariant.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.background;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? AppColors.darkForeground : AppColors.charcoal,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Vouchers & Coupons',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkForeground : AppColors.charcoal,
              ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: _buildBody(isDark),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ],
      );
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Center(
            child: TextButton(onPressed: _load, child: const Text('Retry')),
          ),
        ],
      );
    }
    if (_platform.isEmpty && _store.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Icon(
            Icons.local_offer_outlined,
            size: 64,
            color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
          ),
          const SizedBox(height: 16),
          Text(
            'No coupons available right now',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (_platform.isNotEmpty) ...[
          _sectionTitle('Platform offers', isDark),
          const SizedBox(height: 10),
          ..._platform.map((c) => _couponCard(c, isDark)),
          const SizedBox(height: 20),
        ],
        if (_store.isNotEmpty) ...[
          _sectionTitle('Store offers', isDark),
          const SizedBox(height: 10),
          ..._store.map((c) => _couponCard(c, isDark)),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _sectionTitle(String label, bool isDark) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white70 : AppColors.mutedForeground,
      ),
    );
  }

  Widget _couponCard(CouponModel coupon, bool isDark) {
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _copyCode(coupon.code),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_offer, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coupon.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        coupon.discountLabel,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      if (coupon.minOrderAmount > 0)
                        Text(
                          'Min. ${FormatUtils.peso(coupon.minOrderAmount)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkMutedForeground
                                : AppColors.mutedForeground,
                          ),
                        ),
                      if (coupon.expiresAt != null)
                        Text(
                          'Expires ${_formatDate(coupon.expiresAt!)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkMutedForeground
                                : AppColors.mutedForeground,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      coupon.code,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: isDark ? Colors.white : AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to copy',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? AppColors.darkMutedForeground
                            : AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.month}/${d.day}/${d.year}';
  }
}
