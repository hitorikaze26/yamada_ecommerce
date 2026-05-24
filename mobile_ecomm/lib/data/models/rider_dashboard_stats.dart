class RiderDashboardStats {
  final int todayDeliveries;
  final int completed;
  final int pending;
  final double earnings;
  final double lifetimeEarnings;

  const RiderDashboardStats({
    this.todayDeliveries = 0,
    this.completed = 0,
    this.pending = 0,
    this.earnings = 0,
    this.lifetimeEarnings = 0,
  });

  factory RiderDashboardStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const RiderDashboardStats();
    return RiderDashboardStats(
      todayDeliveries: json['todayDeliveries'] as int? ?? 0,
      completed: json['completed'] as int? ?? 0,
      pending: json['pending'] as int? ?? 0,
      earnings: (json['earnings'] as num?)?.toDouble() ?? 0,
      lifetimeEarnings: (json['lifetimeEarnings'] as num?)?.toDouble() ?? 0,
    );
  }
}

class RiderEarningsPoint {
  final String day;
  final double earnings;
  final int deliveries;

  const RiderEarningsPoint({
    required this.day,
    required this.earnings,
    required this.deliveries,
  });
}
