import '../../core/services/api_client.dart';

class RiderDeliveryModel {
  final int id;
  final int? deliveryId;
  final int? orderId;
  final String displayLabel;
  final String status;
  final double fee;
  final double? distanceKm;
  final String? createdAt;
  final String? shippingAddress;
  final String? municipalityName;
  final String? storeName;
  final String? pickupAddress;
  final String? dropoffAddress;
  final bool isAutoMatched;
  final Map<String, dynamic>? buyer;
  final Map<String, dynamic>? seller;
  final int? storeId;
  final List<Map<String, dynamic>>? items;
  final String? proofPhotoUrl;
  final String? proofNote;
  final String? deliveryNotes;

  RiderDeliveryModel({
    required this.id,
    this.deliveryId,
    this.orderId,
    required this.displayLabel,
    required this.status,
    required this.fee,
    this.distanceKm,
    this.createdAt,
    this.shippingAddress,
    this.municipalityName,
    this.storeName,
    this.pickupAddress,
    this.dropoffAddress,
    this.isAutoMatched = false,
    this.buyer,
    this.seller,
    this.storeId,
    this.items,
    this.proofPhotoUrl,
    this.proofNote,
    this.deliveryNotes,
  });

  bool get hasProof =>
      proofPhotoUrl != null && proofPhotoUrl!.trim().isNotEmpty;

  /// Backend delivery row id for status/proof APIs (null until accepted).
  int? get actionDeliveryId => deliveryId ?? (isAutoMatched ? null : id);

  factory RiderDeliveryModel.fromJson(Map<String, dynamic> json) {
    final orderId = json['orderId'] as int?;
    final isAuto = json['isAutoMatched'] == true;
    final display = json['displayLabel']?.toString() ??
        (isAuto ? 'ORD-${orderId ?? json['id']}' : 'DEL-${json['id']}');

    return RiderDeliveryModel(
      id: json['id'] as int,
      deliveryId: json['deliveryId'] as int?,
      orderId: orderId,
      displayLabel: display,
      status: json['status']?.toString() ?? 'pending',
      fee: (json['fee'] as num?)?.toDouble() ?? 0,
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      createdAt: json['createdAt']?.toString(),
      shippingAddress: json['shippingAddress']?.toString(),
      municipalityName: json['municipalityName']?.toString(),
      storeName: json['storeName']?.toString() ??
          (json['store'] is Map ? json['store']['name']?.toString() : null) ??
          json['pickup']?.toString(),
      pickupAddress: json['pickupAddress']?.toString() ?? json['pickup']?.toString(),
      dropoffAddress: json['dropoffAddress']?.toString() ?? json['dropoff']?.toString(),
      isAutoMatched: isAuto,
      buyer: json['buyer'] != null
          ? Map<String, dynamic>.from(json['buyer'] as Map)
          : null,
      seller: json['seller'] != null
          ? Map<String, dynamic>.from(json['seller'] as Map)
          : null,
      storeId: json['storeId'] as int? ??
          (json['store'] is Map ? json['store']['id'] as int? : null),
      items: json['items'] != null
          ? List<Map<String, dynamic>>.from(
              (json['items'] as List).map(
                (e) => Map<String, dynamic>.from(e as Map),
              ),
            )
          : null,
      proofPhotoUrl: ApiClient.resolveImageUrl(json['proofPhotoUrl']?.toString()),
      proofNote: json['proofNote']?.toString(),
      deliveryNotes: json['deliveryNotes']?.toString(),
    );
  }

  RiderDeliveryModel copyWith({String? status, String? proofPhotoUrl, String? proofNote}) {
    return RiderDeliveryModel(
      id: id,
      deliveryId: deliveryId,
      orderId: orderId,
      displayLabel: displayLabel,
      status: status ?? this.status,
      fee: fee,
      distanceKm: distanceKm,
      createdAt: createdAt,
      shippingAddress: shippingAddress,
      municipalityName: municipalityName,
      storeName: storeName,
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      isAutoMatched: isAutoMatched,
      buyer: buyer,
      seller: seller,
      storeId: storeId,
      items: items,
      proofPhotoUrl: proofPhotoUrl ?? this.proofPhotoUrl,
      proofNote: proofNote ?? this.proofNote,
      deliveryNotes: deliveryNotes,
    );
  }
}
