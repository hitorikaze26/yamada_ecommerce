import '../../core/services/api_client.dart';

class RefundOrderItem {
  final String productName;
  final int quantity;
  final double unitPrice;
  final String? variation;

  const RefundOrderItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.variation,
  });

  factory RefundOrderItem.fromJson(Map<String, dynamic> json) {
    return RefundOrderItem(
      productName: json['productName']?.toString() ?? 'Item',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
      variation: json['variation']?.toString(),
    );
  }
}

class RefundOrderInfo {
  final int id;
  final String displayId;
  final String status;
  final double totalAmount;
  final double shippingFee;
  final double grandTotal;
  final String? paymentMethod;
  final String? createdAt;
  final List<RefundOrderItem> items;

  const RefundOrderInfo({
    required this.id,
    required this.displayId,
    required this.status,
    required this.totalAmount,
    required this.shippingFee,
    required this.grandTotal,
    this.paymentMethod,
    this.createdAt,
    this.items = const [],
  });

  factory RefundOrderInfo.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? [];
    return RefundOrderInfo(
      id: (json['id'] as num?)?.toInt() ?? 0,
      displayId: json['displayId']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      shippingFee: (json['shippingFee'] as num?)?.toDouble() ?? 0,
      grandTotal: (json['grandTotal'] as num?)?.toDouble() ?? 0,
      paymentMethod: json['paymentMethod']?.toString(),
      createdAt: json['createdAt']?.toString(),
      items: rawItems
          .map((e) => RefundOrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RefundBuyerInfo {
  final int id;
  final String? name;
  final String? email;
  final String? contactNumber;

  const RefundBuyerInfo({
    required this.id,
    this.name,
    this.email,
    this.contactNumber,
  });

  factory RefundBuyerInfo.fromJson(Map<String, dynamic> json) {
    return RefundBuyerInfo(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString(),
      email: json['email']?.toString(),
      contactNumber: json['contactNumber']?.toString(),
    );
  }
}

class SellerRefundRequest {
  final int id;
  final int? transactionId;
  final int? orderId;
  final double amount;
  final double platformFee;
  final double netAmount;
  final String status;
  final String? reason;
  final String? createdAt;
  final String? updatedAt;
  final String? paymentStatus;
  final RefundBuyerInfo? buyer;
  final RefundOrderInfo? order;

  const SellerRefundRequest({
    required this.id,
    this.transactionId,
    this.orderId,
    required this.amount,
    required this.platformFee,
    required this.netAmount,
    required this.status,
    this.reason,
    this.createdAt,
    this.updatedAt,
    this.paymentStatus,
    this.buyer,
    this.order,
  });

  factory SellerRefundRequest.fromJson(Map<String, dynamic> json) {
    return SellerRefundRequest(
      id: (json['id'] as num?)?.toInt() ?? 0,
      transactionId: (json['transactionId'] as num?)?.toInt(),
      orderId: (json['orderId'] as num?)?.toInt(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      platformFee: (json['platformFee'] as num?)?.toDouble() ?? 0,
      netAmount: (json['netAmount'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? '',
      reason: json['reason']?.toString(),
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
      paymentStatus: json['paymentStatus']?.toString(),
      buyer: json['buyer'] is Map<String, dynamic>
          ? RefundBuyerInfo.fromJson(json['buyer'] as Map<String, dynamic>)
          : null,
      order: json['order'] is Map<String, dynamic>
          ? RefundOrderInfo.fromJson(json['order'] as Map<String, dynamic>)
          : null,
    );
  }
}

class SellerRefundsApi {
  static Future<List<SellerRefundRequest>> getRefundRequests() async {
    final dio = await ApiClient.getInstance();
    final res = await dio.get('/seller/refund-requests');
    final list = res.data['refunds'] as List? ?? [];
    return list
        .map((e) => SellerRefundRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> approve(int refundId) async {
    final dio = await ApiClient.getInstance();
    await dio.post('/seller/refund-requests/$refundId/approve');
  }

  static Future<void> reject(int refundId) async {
    final dio = await ApiClient.getInstance();
    await dio.post('/seller/refund-requests/$refundId/reject');
  }
}
