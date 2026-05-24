import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_client.dart';
import '../../core/utils/address_utils.dart';
import '../../ui/screens/seller/orders/seller_order_status.dart';
import 'package:dio/dio.dart';

// ─── Models ────────────────────────────────────────────────────────────────

class SellerOrderRider {
  final String id;
  final String name;
  final String email;
  final String contactNumber;
  final String? vehicleType;
  final String? licenseNumber;

  const SellerOrderRider({
    required this.id,
    required this.name,
    required this.email,
    required this.contactNumber,
    this.vehicleType,
    this.licenseNumber,
  });

  factory SellerOrderRider.fromJson(Map<String, dynamic> json) {
    return SellerOrderRider(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Rider',
      email: json['email']?.toString() ?? '',
      contactNumber: json['contactNumber']?.toString() ?? '',
      vehicleType: json['vehicleType']?.toString(),
      licenseNumber: json['licenseNumber']?.toString(),
    );
  }
}

class SellerOrderDelivery {
  final String id;
  final String status;
  final double fee;
  final double? distanceKm;
  final String? proofPhotoUrl;
  final String? proofNote;
  final SellerOrderRider? rider;

  const SellerOrderDelivery({
    required this.id,
    required this.status,
    required this.fee,
    this.distanceKm,
    this.proofPhotoUrl,
    this.proofNote,
    this.rider,
  });

  factory SellerOrderDelivery.fromJson(Map<String, dynamic> json) {
    return SellerOrderDelivery(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      fee: (json['fee'] as num?)?.toDouble() ?? 0.0,
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      proofPhotoUrl: ApiClient.resolveImageUrl(json['proofPhotoUrl']?.toString()),
      proofNote: json['proofNote']?.toString(),
      rider: json['rider'] != null
          ? SellerOrderRider.fromJson(json['rider'] as Map<String, dynamic>)
          : null,
    );
  }
}

class SellerOrderItem {
  final String id;
  final String productId;
  final String productName;
  final String? productImageUrl;
  final int quantity;
  final double unitPrice;
  final double discountAmount;
  final double costPrice;
  final String? color;
  final String? size;
  final String? sku;

  const SellerOrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.productImageUrl,
    required this.quantity,
    required this.unitPrice,
    this.discountAmount = 0,
    this.costPrice = 0,
    this.color,
    this.size,
    this.sku,
  });

  double get lineTotal => unitPrice * quantity;

  factory SellerOrderItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;
    Map<String, dynamic>? variation;
    try {
      final raw = json['variation'];
      if (raw is Map) {
        variation = Map<String, dynamic>.from(raw);
      } else if (raw is String && raw.isNotEmpty) {
        final cleaned = raw.replaceAll("'", '"');
        variation = jsonDecode(cleaned) as Map<String, dynamic>?;
      }
    } catch (_) {}

    String? imageUrl = product?['imageUrl']?.toString();
    imageUrl = ApiClient.resolveImageUrl(imageUrl);

    final discountRaw = json['discountAmount'];
    double discount = 0;
    if (discountRaw is num) discount = discountRaw.toDouble();
    if (discountRaw is String) discount = double.tryParse(discountRaw) ?? 0;

    final costRaw = product?['costPrice'];
    double cost = 0;
    if (costRaw is num) cost = costRaw.toDouble();
    if (costRaw is String) cost = double.tryParse(costRaw) ?? 0;

    return SellerOrderItem(
      id: json['id']?.toString() ?? '',
      productId: json['productId']?.toString() ?? product?['id']?.toString() ?? '',
      productName: product?['name']?.toString() ?? 'Unknown Product',
      productImageUrl: imageUrl,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ??
          (product?['price'] as num?)?.toDouble() ??
          0.0,
      discountAmount: discount,
      costPrice: cost,
      color: variation?['color']?.toString(),
      size: variation?['size']?.toString(),
      sku: variation?['sku']?.toString(),
    );
  }
}

class SellerOrderBuyer {
  final String id;
  final String name;
  final String email;

  const SellerOrderBuyer({
    required this.id,
    required this.name,
    required this.email,
  });

  factory SellerOrderBuyer.fromJson(Map<String, dynamic> json) {
    return SellerOrderBuyer(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Customer',
      email: json['email']?.toString() ?? '',
    );
  }
}

class SellerOrder {
  final int backendId;
  final String displayId;
  final String status;
  final double total;
  final double shippingFee;
  final double adminCommission;
  final String? paymentMethod;
  final String? shippingAddress;
  final DateTime createdAt;
  final SellerOrderBuyer? buyer;
  final List<SellerOrderItem> items;
  final SellerOrderDelivery? riderDelivery;

  const SellerOrder({
    required this.backendId,
    required this.displayId,
    required this.status,
    required this.total,
    this.shippingFee = 0,
    this.adminCommission = 0,
    this.paymentMethod,
    this.shippingAddress,
    required this.createdAt,
    this.buyer,
    required this.items,
    this.riderDelivery,
  });

  factory SellerOrder.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    final rawStatus = json['status']?.toString().toLowerCase() ?? 'pending';
    final items = (json['items'] as List?)
            ?.map((e) => SellerOrderItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final shipRaw = json['shippingFee'];
    double ship = 0;
    if (shipRaw is num) ship = shipRaw.toDouble();
    if (shipRaw is String) ship = double.tryParse(shipRaw) ?? 0;

    final commRaw = json['adminCommission'];
    double comm = 0;
    if (commRaw is num) comm = commRaw.toDouble();
    if (commRaw is String) comm = double.tryParse(commRaw) ?? 0;

    return SellerOrder(
      backendId: id,
      displayId: 'ORD-${id.toString().padLeft(6, '0')}',
      status: rawStatus,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      shippingFee: ship,
      adminCommission: comm,
      paymentMethod: json['paymentMethod']?.toString(),
      shippingAddress: AddressUtils.formatShippingAddress(
        shippingAddress: json['shippingAddress']?.toString(),
      ),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      buyer: json['buyer'] != null
          ? SellerOrderBuyer.fromJson(json['buyer'] as Map<String, dynamic>)
          : null,
      items: items,
      riderDelivery: json['riderDelivery'] != null
          ? SellerOrderDelivery.fromJson(
              json['riderDelivery'] as Map<String, dynamic>)
          : null,
    );
  }

  SellerOrder copyWith({String? status}) {
    return SellerOrder(
      backendId: backendId,
      displayId: displayId,
      status: status ?? this.status,
      total: total,
      shippingFee: shippingFee,
      adminCommission: adminCommission,
      paymentMethod: paymentMethod,
      shippingAddress: shippingAddress,
      createdAt: createdAt,
      buyer: buyer,
      items: items,
      riderDelivery: riderDelivery,
    );
  }
}

// ─── State ─────────────────────────────────────────────────────────────────

class SellerOrdersState {
  final List<SellerOrder> orders;
  final bool isLoading;
  final String? error;
  final String? successMessage;
  final String? statusError;

  const SellerOrdersState({
    this.orders = const [],
    this.isLoading = false,
    this.error,
    this.successMessage,
    this.statusError,
  });

  SellerOrdersState copyWith({
    List<SellerOrder>? orders,
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
    String? statusError,
    bool clearStatusError = false,
  }) {
    return SellerOrdersState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      statusError: clearStatusError ? null : (statusError ?? this.statusError),
    );
  }

  int countByStatus(String status) =>
      orders.where((o) => sellerOrderMatchesTab(o.status, status)).length;
}

// ─── Notifier ──────────────────────────────────────────────────────────────

class SellerOrdersNotifier extends StateNotifier<SellerOrdersState> {
  SellerOrdersNotifier() : super(const SellerOrdersState()) {
    fetchOrders();
  }

  Future<void> fetchOrders({bool silent = false}) async {
    final hasData = state.orders.isNotEmpty;
    state = state.copyWith(
      isLoading: !silent || !hasData,
      clearError: true,
    );
    try {
      final dio = await ApiClient.getInstance();
      final res = await dio.get('/seller/orders');
      final raw = (res.data['orders'] as List?) ?? [];
      final orders = raw
          .map((e) => SellerOrder.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(orders: orders, isLoading: false);
    } catch (e) {
      developer.log('fetchOrders error: $e', name: 'SellerOrdersNotifier');
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<bool> updateStatus(int backendId, String newStatus) async {
    final prev = state.orders;
    // Optimistic update
    state = state.copyWith(
      orders: prev
          .map((o) => o.backendId == backendId ? o.copyWith(status: newStatus) : o)
          .toList(),
      clearStatusError: true,
    );

    try {
      final dio = await ApiClient.getInstance();
      await dio.put(
        '/orders/$backendId/status',
        data: {'status': newStatus},
      );
      state = state.copyWith(
        successMessage: _successMsg(newStatus),
        clearStatusError: true,
      );
      return true;
    } on DioException catch (e) {
      developer.log('updateStatus error: $e', name: 'SellerOrdersNotifier');
      // Revert
      final serverMsg = e.response?.data?['msg']?.toString();
      state = state.copyWith(
        orders: prev,
        statusError: serverMsg ??
            (e.response?.statusCode == 400
                ? 'This status change is not allowed for this order.'
                : 'Failed to update order status.'),
      );
      return false;
    } catch (e) {
      state = state.copyWith(orders: prev, statusError: 'Failed to update order status.');
      return false;
    }
  }

  void clearSuccess() => state = state.copyWith(clearSuccess: true);
  void clearStatusError() => state = state.copyWith(clearStatusError: true);

  String _successMsg(String status) {
    switch (status) {
      case 'processing':
        return 'Order accepted successfully.';
      case 'shipped':
        return 'Order marked as ready for pickup.';
      case 'cancelled':
        return 'Order cancelled.';
      default:
        return 'Order status updated.';
    }
  }
}

final sellerOrdersProvider =
    StateNotifierProvider<SellerOrdersNotifier, SellerOrdersState>((ref) {
  return SellerOrdersNotifier();
});
