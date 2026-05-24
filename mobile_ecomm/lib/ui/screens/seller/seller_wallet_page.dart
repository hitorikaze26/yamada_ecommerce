import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format_utils.dart';
import '../../../data/services/seller_wallet_api.dart';

class SellerWalletPage extends StatefulWidget {
  const SellerWalletPage({super.key});

  @override
  State<SellerWalletPage> createState() => _SellerWalletPageState();
}

class _SellerWalletPageState extends State<SellerWalletPage> {
  SellerWallet? _wallet;
  List<WalletTransaction> _transactions = [];
  bool _loading = true;
  String? _error;

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
      final results = await Future.wait([
        SellerWalletApi.getWallet(),
        SellerWalletApi.getTransactions(),
      ]);
      if (mounted) {
        setState(() {
          _wallet = results[0] as SellerWallet;
          _transactions = results[1] as List<WalletTransaction>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.rosewood, AppColors.blush],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Available balance',
                                style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 8),
                            Text(
                              FormatUtils.peso(_wallet?.balance ?? 0),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () => context.push(AppRouter.sellerRefunds),
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('View refund requests'),
                      ),
                      const SizedBox(height: 8),
                      Text('Transactions',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (_transactions.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text('No transactions yet'),
                          ),
                        )
                      else
                        ..._transactions.map((tx) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text('Order #${tx.orderId ?? '—'}'),
                              subtitle: Text(
                                '${tx.status} · ${tx.createdAt ?? ''}',
                              ),
                              trailing: Text(
                                FormatUtils.peso(tx.netAmount),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.charcoal,
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
}
