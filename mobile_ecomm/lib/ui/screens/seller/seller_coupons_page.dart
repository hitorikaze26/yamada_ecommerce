import 'package:flutter/material.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/seller_coupons_api.dart';

class SellerCouponsPage extends StatefulWidget {
  const SellerCouponsPage({super.key});

  @override
  State<SellerCouponsPage> createState() => _SellerCouponsPageState();
}

class _SellerCouponsPageState extends State<SellerCouponsPage> {
  List<SellerCoupon> _coupons = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await SellerCouponsApi.listCoupons();
      if (mounted) setState(() => _coupons = list);
    } catch (e) {
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: 'Failed to load coupons',
          variant: AlertVariant.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showCreateDialog() async {
    final codeCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final minCtrl = TextEditingController(text: '0');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New coupon'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(labelText: 'Code'),
              ),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: valueCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Discount %',
                ),
              ),
              TextField(
                controller: minCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Min order amount',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await SellerCouponsApi.createCoupon({
        'code': codeCtrl.text.trim().toUpperCase(),
        'title': titleCtrl.text.trim(),
        'discountType': 'percent',
        'discountValue': double.tryParse(valueCtrl.text) ?? 0,
        'minOrderAmount': double.tryParse(minCtrl.text) ?? 0,
        'isActive': true,
      });
      await _load();
    } catch (e) {
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: e.toString().replaceAll('Exception: ', ''),
          variant: AlertVariant.error,
        );
      }
    }
  }

  Future<void> _delete(SellerCoupon c) async {
    try {
      await SellerCouponsApi.deleteCoupon(c.id);
      await _load();
    } catch (e) {
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: e.toString().replaceAll('Exception: ', ''),
          variant: AlertVariant.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Store coupons')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: AppColors.rosewood,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _coupons.isEmpty
              ? const Center(child: Text('No coupons yet'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _coupons.length,
                    itemBuilder: (context, i) {
                      final c = _coupons[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text(c.title),
                          subtitle: Text(
                            '${c.code} · ${c.discountValue}% off · min ${c.minOrderAmount}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(c),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
