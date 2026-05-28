import 'dart:convert';
import '../../core/services/api_client.dart';

String _normalizeOrderStatus(String status) {
  return status.toLowerCase().trim().replaceAll(' ', '_');
}

/// Buyer-facing status when orders.status lags behind rider delivery.
String effectiveOrderStatusForOrder(Order order) {
  final rd = order.riderDelivery;
  return effectiveOrderStatus(
    order.status,
    riderDeliveryStatus: rd?.status,
    riderProofPhotoUrl: rd?.proofPhotoUrl,
    riderHasProofPhoto: rd?.hasProofPhoto,
  );
}

String effectiveOrderStatus(
  String orderStatus, {
  String? riderDeliveryStatus,
  String? riderProofPhotoUrl,
  bool? riderHasProofPhoto,
}) {
  final order = _normalizeOrderStatus(orderStatus);
  final rider = riderDeliveryStatus != null
      ? _normalizeOrderStatus(riderDeliveryStatus)
      : null;
  final hasProof = riderHasProofPhoto == true ||
      (riderProofPhotoUrl != null && riderProofPhotoUrl.trim().isNotEmpty);
  final riderComplete = rider == 'delivered' || hasProof;

  if (riderComplete &&
      !{'delivered', 'completed', 'cancelled', 'canceled', 'returned'}
          .contains(order)) {
    return 'delivered';
  }
  return order;
}

bool canBuyerConfirmReceiptForOrder(Order order) {
  final raw = _normalizeOrderStatus(order.status);
  if (const {'completed', 'cancelled', 'canceled', 'returned', 'pending'}.contains(raw)) {
    return false;
  }
  final effective = effectiveOrderStatusForOrder(order);
  return effective == 'delivered' || raw == 'out_for_delivery';
}

bool canBuyerLeaveReviewForOrder(Order order) {
  return _normalizeOrderStatus(order.status) == 'completed';
}

class Order {
  final String id;
  final String orderNumber;
  final String status;
  final List<OrderItem> items;
  final double subtotal;
  final double shipping;
  final double total;
  final DateTime createdAt;
  final String? shippingAddress;
  final String? paymentMethod;
  final double? adminCommission;
  final StoreInfo? store;
  final RiderDeliveryInfo? riderDelivery;
  final AddressParts? shippingAddressParts;

  Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.items,
    required this.subtotal,
    required this.shipping,
    required this.total,
    required this.createdAt,
    this.shippingAddress,
    this.paymentMethod,
    this.adminCommission,
    this.store,
    this.riderDelivery,
    this.shippingAddressParts,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    // Server returns: subtotal, shipping/shippingFee, total/grandTotal
    final subtotal = (json['subtotal'] as num?)?.toDouble() ?? 
                     (json['total'] as num?)?.toDouble() ?? 0.0;
    final shipping = (json['shipping'] as num?)?.toDouble() ?? 
                     (json['shippingFee'] as num?)?.toDouble() ?? 0.0;
    final grandTotal = (json['grandTotal'] as num?)?.toDouble() ?? 
                       (json['total'] as num?)?.toDouble() ??
                       (subtotal + shipping);
    
    return Order(
      id: json['id']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? json['id']?.toString() ?? '',
      status: (json['status']?.toString() ?? 'pending').toLowerCase(),
      items: (json['items'] as List?)
              ?.map((item) => OrderItem.fromJson(item))
              .toList() ??
          [],
      subtotal: subtotal,
      shipping: shipping,
      total: grandTotal,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      shippingAddress: json['shippingAddress']?.toString(),
      paymentMethod: json['paymentMethod']?.toString(),
      adminCommission: (json['adminCommission'] as num?)?.toDouble(),
      store: json['store'] != null ? StoreInfo.fromJson(json['store']) : null,
      riderDelivery: json['riderDelivery'] != null 
          ? RiderDeliveryInfo.fromJson(json['riderDelivery']) 
          : null,
      shippingAddressParts: json['shippingAddressParts'] != null
          ? AddressParts.fromJson(json['shippingAddressParts'])
          : null,
    );
  }

  String get formattedDate {
    final day = createdAt.day.toString().padLeft(2, '0');
    final month = createdAt.month.toString().padLeft(2, '0');
    final year = createdAt.year.toString();
    return '$day/$month/$year';
  }
}

// Helper to parse variation which can be a Map or a JSON string
Map<String, dynamic>? _parseVariation(dynamic variation) {
  if (variation == null) return null;
  if (variation is Map) return Map<String, dynamic>.from(variation);
  if (variation is String) {
    try {
      // Handle both single and double quotes
      String jsonStr = variation
          .replaceAll("'", '"')
          .replaceAll('"{', '{')
          .replaceAll('}"', '}');
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }
  return null;
}

class OrderItem {
  final String id;
  final String productId;
  final String productName;
  final String? productImage;
  final int quantity;
  final double price;
  final double? salePrice;
  final String? size;
  final String? color;
  final String? sku;
  final String? productSlug;
  final String sellerId;
  final String sellerName;

  OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.productImage,
    required this.quantity,
    required this.price,
    this.salePrice,
    this.size,
    this.color,
    this.sku,
    this.productSlug,
    required this.sellerId,
    required this.sellerName,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'];
    final variation = _parseVariation(json['variation']);

    // Resolve image URL properly using ApiClient
    String? imageUrl = product?['imageUrl'] ?? product?['image'];
    imageUrl = ApiClient.resolveImageUrl(imageUrl);

    return OrderItem(
      id: json['id']?.toString() ?? '',
      productId: json['productId']?.toString() ?? product?['id']?.toString() ?? '',
      productName: product?['name'] ?? 'Unknown Product',
      productImage: imageUrl,
      quantity: json['quantity'] ?? 1,
      price: (product?['price'] ?? json['unitPrice'] ?? 0).toDouble(),
      salePrice: product?['salePrice']?.toDouble(),
      size: variation?['size']?.toString(),
      color: variation?['color']?.toString(),
      sku: variation?['sku']?.toString(),
        productSlug: product?['slug'] ?? product?['id']?.toString(),
      sellerId: json['sellerId']?.toString() ?? '',
      sellerName: json['sellerName'] ?? 'Unknown Seller',
    );
  }

  double get total => (salePrice ?? price) * quantity;
}

/// Store information in order
class StoreInfo {
  final String? id;
  final String? name;
  final String? email;

  StoreInfo({
    this.id,
    this.name,
    this.email,
  });

  factory StoreInfo.fromJson(Map<String, dynamic> json) {
    return StoreInfo(
      id: json['id']?.toString(),
      name: json['name']?.toString(),
      email: json['email']?.toString(),
    );
  }
}

/// Rider delivery information
class RiderDeliveryInfo {
  final String? id;
  final String status;
  final RiderInfo? rider;
  final bool hasProofPhoto;
  final String? proofPhotoUrl;
  final String? proofNote;

  RiderDeliveryInfo({
    this.id,
    required this.status,
    this.rider,
    this.hasProofPhoto = false,
    this.proofPhotoUrl,
    this.proofNote,
  });

  factory RiderDeliveryInfo.fromJson(Map<String, dynamic> json) {
    final proofUrl = ApiClient.resolveImageUrl(json['proofPhotoUrl']?.toString());
    final hasProof = json['hasProofPhoto'] == true ||
        json['has_proof_photo'] == true ||
        (proofUrl != null && proofUrl.isNotEmpty);
    return RiderDeliveryInfo(
      id: json['id']?.toString(),
      status: (json['status']?.toString() ?? 'pending').toLowerCase(),
      rider: json['rider'] != null ? RiderInfo.fromJson(json['rider']) : null,
      hasProofPhoto: hasProof,
      proofPhotoUrl: proofUrl,
      proofNote: json['proofNote']?.toString(),
    );
  }
}

/// Rider information
class RiderInfo {
  final String? id;
  final String? email;
  final String? name;
  final String? contactNumber;
  final String? vehicleType;
  final String? licenseNumber;

  RiderInfo({
    this.id,
    this.email,
    this.name,
    this.contactNumber,
    this.vehicleType,
    this.licenseNumber,
  });

  factory RiderInfo.fromJson(Map<String, dynamic> json) {
    return RiderInfo(
      id: json['id']?.toString(),
      email: json['email']?.toString(),
      name: json['name']?.toString(),
      contactNumber: json['contactNumber']?.toString(),
      vehicleType: json['vehicleType']?.toString(),
      licenseNumber: json['licenseNumber']?.toString(),
    );
  }
}

/// Structured address parts
class AddressParts {
  final String? streetAddress;
  final String? barangayName;
  final String? municipalityName;
  final String? provinceName;
  final String? regionName;
  final String? postalCode;

  AddressParts({
    this.streetAddress,
    this.barangayName,
    this.municipalityName,
    this.provinceName,
    this.regionName,
    this.postalCode,
  });

  factory AddressParts.fromJson(Map<String, dynamic> json) {
    return AddressParts(
      streetAddress: json['streetAddress']?.toString(),
      barangayName: json['barangayName']?.toString(),
      municipalityName: json['municipalityName']?.toString(),
      provinceName: json['provinceName']?.toString(),
      regionName: json['regionName']?.toString(),
      postalCode: json['postalCode']?.toString(),
    );
  }

  String get fullAddress {
    final parts = [
      streetAddress,
      barangayName,
      municipalityName,
      provinceName,
      regionName,
      postalCode,
    ].where((part) => part != null && part.isNotEmpty);
    return parts.join(', ');
  }
}

class CartItem {
  final String id;
  final String productId;
  final String productName;
  final String? productImage;
  final double productPrice;
  final double? salePrice;
  final int quantity;
  final String? size;
  final String? color;
  final String? sku;
  final String? productSlug;
  final String sellerId;
  final String sellerName;

  CartItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.productImage,
    required this.productPrice,
    this.salePrice,
    required this.quantity,
    this.size,
    this.color,
    this.sku,
    this.productSlug,
    required this.sellerId,
    required this.sellerName,
  });

  double get price => salePrice ?? productPrice;
  double get total => price * quantity;

  CartItem copyWith({
    String? id,
    String? productId,
    String? productName,
    String? productImage,
    double? productPrice,
    double? salePrice,
    int? quantity,
    String? size,
    String? color,
    String? sku,
    String? productSlug,
    String? sellerId,
    String? sellerName,
  }) {
    return CartItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productImage: productImage ?? this.productImage,
      productPrice: productPrice ?? this.productPrice,
      salePrice: salePrice ?? this.salePrice,
      quantity: quantity ?? this.quantity,
      size: size ?? this.size,
      color: color ?? this.color,
      sku: sku ?? this.sku,
      productSlug: productSlug ?? this.productSlug,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
    );
  }
}
