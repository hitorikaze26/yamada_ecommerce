import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/rider_dashboard_stats.dart';
import '../models/rider_delivery_model.dart';
import '../services/rider_api.dart';
import 'auth_notifier.dart';

class RiderNotifierState {
  final RiderDashboardStats stats;
  final List<RiderDeliveryModel> deliveries;
  final bool isLoading;
  final bool notVerified;
  final String? error;

  const RiderNotifierState({
    this.stats = const RiderDashboardStats(),
    this.deliveries = const [],
    this.isLoading = false,
    this.notVerified = false,
    this.error,
  });

  RiderNotifierState copyWith({
    RiderDashboardStats? stats,
    List<RiderDeliveryModel>? deliveries,
    bool? isLoading,
    bool? notVerified,
    String? error,
    bool clearError = false,
  }) {
    return RiderNotifierState(
      stats: stats ?? this.stats,
      deliveries: deliveries ?? this.deliveries,
      isLoading: isLoading ?? this.isLoading,
      notVerified: notVerified ?? this.notVerified,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class RiderNotifier extends StateNotifier<RiderNotifierState> {
  final Ref ref;

  RiderNotifier(this.ref) : super(const RiderNotifierState());

  List<RiderDeliveryModel> get activeDeliveries => state.deliveries
      .where((d) => ['pickup', 'transit', 'pending'].contains(d.status))
      .toList();

  List<RiderDeliveryModel> get completedDeliveries =>
      state.deliveries.where((d) => d.status == 'delivered').toList();

  List<RiderDeliveryModel> recentDeliveries([int limit = 3]) =>
      state.deliveries.take(limit).toList();

  List<RiderEarningsPoint> earningsSeries(String range) {
    final days = range == 'month' ? 30 : 7;
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days - 1));
    final weekdayShort = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    final buckets = <String, Map<String, num>>{};
    for (int i = 0; i < days; i++) {
      final d = start.add(Duration(days: i));
      final key = d.toIso8601String().substring(0, 10);
      buckets[key] = {'earnings': 0.0, 'deliveries': 0};
    }

    for (final delivery in state.deliveries) {
      if (delivery.status != 'delivered') continue;
      final createdAt = delivery.createdAt;
      if (createdAt == null) continue;
      final d = DateTime.tryParse(createdAt);
      if (d == null) continue;
      final key = d.toIso8601String().substring(0, 10);
      if (buckets.containsKey(key)) {
        buckets[key]!['earnings'] =
            (buckets[key]!['earnings'] ?? 0) + delivery.fee;
        buckets[key]!['deliveries'] =
            (buckets[key]!['deliveries'] ?? 0) + 1;
      }
    }

    return buckets.entries.map((entry) {
      final d = DateTime.parse(entry.key);
      final dayLabel = range == 'month' ? '${d.month}/${d.day}' : weekdayShort[d.weekday % 7];
      return RiderEarningsPoint(
        day: dayLabel,
        earnings: entry.value['earnings']?.toDouble() ?? 0,
        deliveries: entry.value['deliveries']?.toInt() ?? 0,
      );
    }).toList();
  }

  Future<void> load() async {
    final isVerified = ref.read(authProvider).isVerified;
    if (!isVerified) {
      state = state.copyWith(
        isLoading: false,
        notVerified: true,
        deliveries: const [],
        stats: const RiderDashboardStats(),
        clearError: true,
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true, notVerified: false);

    try {
      final results = await Future.wait([
        RiderApi.getDashboard(),
        RiderApi.getDeliveries(),
      ]);

      final dashboardRes = results[0] as Map<String, dynamic>;
      final deliveriesRes = results[1] as RiderDeliveriesResult;

      if (deliveriesRes.notVerified) {
        state = state.copyWith(
          isLoading: false,
          notVerified: true,
          deliveries: const [],
          stats: const RiderDashboardStats(),
        );
        return;
      }

      if (deliveriesRes.hasError) {
        state = state.copyWith(
          isLoading: false,
          error: deliveriesRes.errorMessage,
        );
        return;
      }

      final statsJson = dashboardRes['stats'] as Map<String, dynamic>?;
      final list = deliveriesRes.deliveries
          .map((d) => RiderDeliveryModel.fromJson(Map<String, dynamic>.from(d)))
          .toList();

      state = state.copyWith(
        isLoading: false,
        stats: RiderDashboardStats.fromJson(statsJson),
        deliveries: list,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> refresh() => load();

  Future<void> acceptDelivery(RiderDeliveryModel delivery) async {
    if (!delivery.isAutoMatched || delivery.orderId == null) return;
    await RiderApi.acceptDelivery(delivery.orderId!);
    await refresh();
  }

  Future<void> updateStatus(RiderDeliveryModel delivery, String status) async {
    final deliveryId = delivery.actionDeliveryId;
    if (deliveryId == null || delivery.isAutoMatched) return;
    await RiderApi.updateDeliveryStatus(deliveryId, status);
    await refresh();
  }

  Future<void> uploadProof(
    RiderDeliveryModel delivery, {
    String? note,
    File? photo,
  }) async {
    final deliveryId = delivery.actionDeliveryId;
    if (deliveryId == null) {
      throw Exception('Accept this delivery before uploading proof.');
    }
    await RiderApi.uploadDeliveryProof(
      deliveryId,
      note: note,
      photo: photo,
    );
    await refresh();
  }
}

final riderProvider =
    StateNotifierProvider<RiderNotifier, RiderNotifierState>((ref) {
  return RiderNotifier(ref);
});
