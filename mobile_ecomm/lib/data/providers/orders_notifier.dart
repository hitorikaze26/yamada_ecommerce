import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order_model.dart';
import '../services/orders_api.dart';

class OrdersState {
  final List<Order> orders;
  final bool isLoading;
  final String? error;
  final String filterStatus;

  OrdersState({
    this.orders = const [],
    this.isLoading = false,
    this.error,
    this.filterStatus = 'all',
  });

  OrdersState copyWith({
    List<Order>? orders,
    bool? isLoading,
    String? error,
    String? filterStatus,
    bool clearError = false,
  }) {
    return OrdersState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      filterStatus: filterStatus ?? this.filterStatus,
    );
  }

  List<Order> get filteredOrders {
    switch (filterStatus) {
      case 'all':
        return orders;
      case 'pending':
      case 'to_pay':
        return orders.where((o) => o.status.toLowerCase() == 'pending').toList();
      case 'processing':
      case 'to_ship':
        return orders
            .where((o) => ['confirmed', 'processing']
                .contains(o.status.toLowerCase()))
            .toList();
      case 'packed':
        return orders.where((o) => o.status.toLowerCase() == 'packed').toList();
      case 'shipped':
      case 'to_receive':
        return orders
            .where((o) => [
                  'shipped',
                  'out_for_delivery',
                ].contains(effectiveOrderStatusForOrder(o)))
            .toList();
      case 'completed':
      case 'delivered':
        return orders
            .where((o) => ['delivered', 'completed']
                .contains(effectiveOrderStatusForOrder(o)))
            .toList();
      case 'cancelled':
        return orders.where((o) => o.status.toLowerCase() == 'cancelled').toList();
      default:
        return orders.where((o) => o.status.toLowerCase() == filterStatus).toList();
    }
  }

  int get totalOrders => orders.length;
  int get pendingOrders => orders.where((o) => o.status.toLowerCase() == 'pending').length;
  int get processingOrders => orders.where((o) => o.status.toLowerCase() == 'processing').length;
  int get completedOrders => orders.where((o) => o.status.toLowerCase() == 'completed' || o.status.toLowerCase() == 'delivered').length;
}

class OrdersNotifier extends StateNotifier<OrdersState> {
  OrdersNotifier() : super(OrdersState());

  Future<void> fetchOrders() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final orders = await OrdersApi.getBuyerOrders();
      // Sort by createdAt in descending order (newest first)
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = state.copyWith(
        orders: orders,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  void setFilter(String status) {
    state = state.copyWith(filterStatus: status);
  }

  void refresh() {
    fetchOrders();
  }

  /// Clear all orders - called on logout
  void clearOrders() {
    state = OrdersState();
  }
}

final ordersProvider = StateNotifierProvider<OrdersNotifier, OrdersState>((ref) {
  final notifier = OrdersNotifier();
  notifier.fetchOrders();
  return notifier;
});
