import '../../core/services/api_client.dart';

class ReportTypeModel {
  final int id;
  final String targetRole;
  final String typeKey;
  final String displayName;
  final String? description;
  final String? category;

  const ReportTypeModel({
    required this.id,
    required this.targetRole,
    required this.typeKey,
    required this.displayName,
    this.description,
    this.category,
  });

  factory ReportTypeModel.fromJson(Map<String, dynamic> json) {
    return ReportTypeModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      targetRole: json['targetRole']?.toString() ?? '',
      typeKey: json['typeKey']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      description: json['description']?.toString(),
      category: json['category']?.toString(),
    );
  }
}

class ReportEvidenceModel {
  final int id;
  final String filePath;
  final String? fileUrl;
  final String fileType;
  final String? originalFilename;
  final String? uploadedAt;

  const ReportEvidenceModel({
    required this.id,
    required this.filePath,
    this.fileUrl,
    required this.fileType,
    this.originalFilename,
    this.uploadedAt,
  });

  factory ReportEvidenceModel.fromJson(Map<String, dynamic> json) {
    final path = json['filePath']?.toString() ?? '';
    final url = json['fileUrl']?.toString();
    return ReportEvidenceModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      filePath: path,
      fileUrl: ApiClient.resolveImageUrl(url ?? path),
      fileType: json['fileType']?.toString() ?? 'image',
      originalFilename: json['originalFilename']?.toString(),
      uploadedAt: json['uploadedAt']?.toString(),
    );
  }

  bool get isPdf => fileType.toLowerCase() == 'pdf' ||
      (originalFilename ?? filePath).toLowerCase().endsWith('.pdf');
}

class ReportStoreSummary {
  final int id;
  final String? name;

  const ReportStoreSummary({required this.id, this.name});

  factory ReportStoreSummary.fromJson(Map<String, dynamic> json) {
    return ReportStoreSummary(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString(),
    );
  }
}

class ReportOrderSummary {
  final int id;
  final String displayId;
  final String status;
  final double totalAmount;
  final double grandTotal;
  final String? createdAt;

  const ReportOrderSummary({
    required this.id,
    required this.displayId,
    required this.status,
    required this.totalAmount,
    required this.grandTotal,
    this.createdAt,
  });

  factory ReportOrderSummary.fromJson(Map<String, dynamic> json) {
    return ReportOrderSummary(
      id: (json['id'] as num?)?.toInt() ?? 0,
      displayId: json['displayId']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      grandTotal: (json['grandTotal'] as num?)?.toDouble() ?? 0,
      createdAt: json['createdAt']?.toString(),
    );
  }
}

class ProblemReportModel {
  final int id;
  final int reporterUserId;
  final String reporterRole;
  final int? reportTypeId;
  final String? reportType;
  final String? reportTypeCategory;
  final String description;
  final String status;
  final String priority;
  final int? targetUserId;
  final String? targetRole;
  final String? targetLabel;
  final int? storeId;
  final int? orderId;
  final ReportStoreSummary? store;
  final ReportOrderSummary? order;
  final List<ReportEvidenceModel> evidence;
  final int evidenceCount;
  final String? createdAt;
  final String? updatedAt;
  final String? resolvedAt;

  const ProblemReportModel({
    required this.id,
    required this.reporterUserId,
    required this.reporterRole,
    this.reportTypeId,
    this.reportType,
    this.reportTypeCategory,
    required this.description,
    required this.status,
    required this.priority,
    this.targetUserId,
    this.targetRole,
    this.targetLabel,
    this.storeId,
    this.orderId,
    this.store,
    this.order,
    this.evidence = const [],
    this.evidenceCount = 0,
    this.createdAt,
    this.updatedAt,
    this.resolvedAt,
  });

  factory ProblemReportModel.fromJson(Map<String, dynamic> json) {
    final evidenceRaw = json['evidence'];
    final evidence = evidenceRaw is List
        ? evidenceRaw
            .whereType<Map>()
            .map((e) => ReportEvidenceModel.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <ReportEvidenceModel>[];

    return ProblemReportModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      reporterUserId: (json['reporterUserId'] as num?)?.toInt() ?? 0,
      reporterRole: json['reporterRole']?.toString() ?? '',
      reportTypeId: (json['reportTypeId'] as num?)?.toInt(),
      reportType: json['reportType']?.toString(),
      reportTypeCategory: json['reportTypeCategory']?.toString(),
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      priority: json['priority']?.toString() ?? 'medium',
      targetUserId: (json['targetUserId'] as num?)?.toInt(),
      targetRole: json['targetRole']?.toString(),
      targetLabel: json['targetLabel']?.toString(),
      storeId: (json['storeId'] as num?)?.toInt(),
      orderId: (json['orderId'] as num?)?.toInt(),
      store: json['store'] is Map
          ? ReportStoreSummary.fromJson(Map<String, dynamic>.from(json['store'] as Map))
          : null,
      order: json['order'] is Map
          ? ReportOrderSummary.fromJson(Map<String, dynamic>.from(json['order'] as Map))
          : null,
      evidence: evidence,
      evidenceCount: (json['evidenceCount'] as num?)?.toInt() ?? evidence.length,
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
      resolvedAt: json['resolvedAt']?.toString(),
    );
  }

  bool get isOpen =>
      const {'pending', 'under_review', 'investigating'}.contains(status);
}

const reportCategoryLabels = <String, String>{
  'fraud': 'Fraud',
  'harassment': 'Harassment',
  'spam': 'Spam',
  'misconduct': 'Misconduct',
  'safety': 'Safety',
  'inappropriate_content': 'Inappropriate content',
  'other': 'Other',
};

String reportCategoryLabel(String? category) {
  if (category == null || category.isEmpty) return 'Other';
  return reportCategoryLabels[category] ??
      category.replaceAll('_', ' ').split(' ').map((w) {
        if (w.isEmpty) return w;
        return '${w[0].toUpperCase()}${w.substring(1)}';
      }).join(' ');
}

String reportStatusLabel(String status) {
  return status
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

String reportTargetRoleLabel(String? role) {
  switch (role?.toLowerCase()) {
    case 'seller':
      return 'Store / Seller';
    case 'rider':
      return 'Rider';
    case 'buyer':
      return 'Buyer';
    default:
      return role ?? 'Unknown';
  }
}
