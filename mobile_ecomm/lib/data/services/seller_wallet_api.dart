import '../../core/services/api_client.dart';

class SellerWallet {
  final int sellerId;
  final double balance;
  final String? updatedAt;

  const SellerWallet({
    required this.sellerId,
    required this.balance,
    this.updatedAt,
  });

  factory SellerWallet.fromJson(Map<String, dynamic> json) {
    return SellerWallet(
      sellerId: (json['sellerId'] as num?)?.toInt() ?? 0,
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      updatedAt: json['updatedAt']?.toString(),
    );
  }
}

class WalletTransaction {
  final int id;
  final int? orderId;
  final double amount;
  final double platformFee;
  final double netAmount;
  final String status;
  final String? createdAt;

  const WalletTransaction({
    required this.id,
    this.orderId,
    required this.amount,
    required this.platformFee,
    required this.netAmount,
    required this.status,
    this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: (json['id'] as num?)?.toInt() ?? 0,
      orderId: (json['orderId'] as num?)?.toInt(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      platformFee: (json['platformFee'] as num?)?.toDouble() ?? 0,
      netAmount: (json['netAmount'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? '',
      createdAt: json['createdAt']?.toString(),
    );
  }
}

class SellerWalletApi {
  static Future<SellerWallet> getWallet() async {
    final dio = await ApiClient.getInstance();
    final res = await dio.get('/seller/wallet');
    final data = res.data['wallet'] as Map<String, dynamic>? ?? {};
    return SellerWallet.fromJson(data);
  }

  static Future<List<WalletTransaction>> getTransactions() async {
    final dio = await ApiClient.getInstance();
    final res = await dio.get('/seller/wallet/transactions');
    final list = res.data['transactions'] as List? ?? [];
    return list
        .map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
