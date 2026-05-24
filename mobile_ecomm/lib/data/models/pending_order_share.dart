/// Order attachment queued above the composer until the seller sends a message.
class PendingOrderShare {
  final int orderId;
  final String productName;
  final String? productImageUrl;
  final String status;
  final double totalAmount;
  final String displayId;

  const PendingOrderShare({
    required this.orderId,
    required this.productName,
    this.productImageUrl,
    required this.status,
    required this.totalAmount,
    required this.displayId,
  });

  String get previewLabel {
    final name = productName.trim();
    return name.isNotEmpty ? name : displayId;
  }
}
