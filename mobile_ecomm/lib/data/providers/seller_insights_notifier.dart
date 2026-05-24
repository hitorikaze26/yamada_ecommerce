import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/seller_insights_api.dart';

class SellerInsightsState {
  final SellerInsights? insights;
  final bool isLoading;
  final String? error;

  const SellerInsightsState({
    this.insights,
    this.isLoading = false,
    this.error,
  });

  SellerInsightsState copyWith({
    SellerInsights? insights,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return SellerInsightsState(
      insights: insights ?? this.insights,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SellerInsightsNotifier extends StateNotifier<SellerInsightsState> {
  SellerInsightsNotifier() : super(const SellerInsightsState());

  Future<void> fetch() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await SellerInsightsApi.getInsights();
      state = state.copyWith(insights: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }
}

final sellerInsightsProvider =
    StateNotifierProvider<SellerInsightsNotifier, SellerInsightsState>((ref) {
  final n = SellerInsightsNotifier();
  n.fetch();
  return n;
});
