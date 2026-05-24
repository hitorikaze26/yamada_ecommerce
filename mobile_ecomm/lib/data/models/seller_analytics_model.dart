int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    return int.tryParse(value) ?? double.tryParse(value)?.toInt() ?? 0;
  }
  return 0;
}

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

class SellerAnalyticsSummary {
  final double totalRevenue;
  final int totalOrders;
  final int totalCustomers;
  final double avgOrderValue;
  final double revenueGrowth;
  final double ordersGrowth;

  const SellerAnalyticsSummary({
    this.totalRevenue = 0,
    this.totalOrders = 0,
    this.totalCustomers = 0,
    this.avgOrderValue = 0,
    this.revenueGrowth = 0,
    this.ordersGrowth = 0,
  });

  factory SellerAnalyticsSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SellerAnalyticsSummary();
    final totalRevenue = _toDouble(
      json['totalRevenue'] ?? json['total_revenue'],
    );
    final totalOrders = _toInt(json['totalOrders'] ?? json['total_orders']);
    var avgOrderValue = _toDouble(
      json['avgOrderValue'] ?? json['avg_order_value'],
    );
    if (avgOrderValue == 0 && totalOrders > 0 && totalRevenue > 0) {
      avgOrderValue = totalRevenue / totalOrders;
    }
    return SellerAnalyticsSummary(
      totalRevenue: totalRevenue,
      totalOrders: totalOrders,
      totalCustomers: _toInt(json['totalCustomers'] ?? json['total_customers']),
      avgOrderValue: avgOrderValue,
      revenueGrowth: _toDouble(json['revenueGrowth'] ?? json['revenue_growth']),
      ordersGrowth: _toDouble(json['ordersGrowth'] ?? json['orders_growth']),
    );
  }
}

class SellerSalesChartPoint {
  final String name;
  final double sales;
  final int orders;

  const SellerSalesChartPoint({
    required this.name,
    required this.sales,
    required this.orders,
  });

  factory SellerSalesChartPoint.fromJson(Map<String, dynamic> json) {
    return SellerSalesChartPoint(
      name: json['name']?.toString() ?? '',
      sales: _toDouble(json['sales']),
      orders: _toInt(json['orders']),
    );
  }
}

class SellerTopProduct {
  final String name;
  final double revenue;
  final int quantitySold;
  final double growth;

  const SellerTopProduct({
    required this.name,
    required this.revenue,
    required this.quantitySold,
    this.growth = 0,
  });

  factory SellerTopProduct.fromJson(Map<String, dynamic> json) {
    return SellerTopProduct(
      name: json['name']?.toString() ?? 'Unknown',
      revenue: _toDouble(json['revenue']),
      quantitySold: _toInt(json['quantitySold']),
      growth: _toDouble(json['growth']),
    );
  }
}

class SellerCategoryDatum {
  final String name;
  final double value;

  const SellerCategoryDatum({required this.name, required this.value});

  factory SellerCategoryDatum.fromJson(Map<String, dynamic> json) {
    return SellerCategoryDatum(
      name: json['name']?.toString() ?? 'Other',
      value: _toDouble(json['value']),
    );
  }
}

class SellerAnalyticsData {
  final String period;
  final SellerAnalyticsSummary summary;
  final List<SellerSalesChartPoint> salesChart;
  final List<SellerTopProduct> topProducts;
  final List<SellerCategoryDatum> categoryData;

  const SellerAnalyticsData({
    this.period = '30d',
    this.summary = const SellerAnalyticsSummary(),
    this.salesChart = const [],
    this.topProducts = const [],
    this.categoryData = const [],
  });

  /// Sum of daily sales in [salesChart] for the selected period.
  double get chartSalesTotal =>
      salesChart.fold(0.0, (sum, p) => sum + p.sales);

  /// Sum of daily orders in [salesChart].
  int get chartOrdersTotal =>
      salesChart.fold(0, (sum, p) => sum + p.orders);

  factory SellerAnalyticsData.fromJson(Map<String, dynamic> json) {
    final summaryRaw = json['summary'];
    final chartRaw = json['salesChart'] ?? json['sales_chart'];
    final topRaw = json['topProducts'] ?? json['top_products'];
    final categoryRaw = json['categoryData'] ?? json['category_data'];

    return SellerAnalyticsData(
      period: json['period']?.toString() ?? '30d',
      summary: SellerAnalyticsSummary.fromJson(
        summaryRaw != null
            ? Map<String, dynamic>.from(summaryRaw as Map)
            : null,
      ),
      salesChart: (chartRaw as List? ?? [])
          .map((e) => SellerSalesChartPoint.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(),
      topProducts: (topRaw as List? ?? [])
          .map((e) => SellerTopProduct.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(),
      categoryData: (categoryRaw as List? ?? [])
          .map((e) => SellerCategoryDatum.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(),
    );
  }
}
