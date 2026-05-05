import 'package:driver_app/features/earnings/data/earnings_repository.dart';
import 'package:driver_app/shared/models/earnings_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final earningsControllerProvider =
    AsyncNotifierProvider<EarningsController, EarningsSummary>(
      EarningsController.new,
    );

class EarningsController extends AsyncNotifier<EarningsSummary> {
  @override
  Future<EarningsSummary> build() {
    return ref.read(earningsRepositoryProvider).fetchSummary();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(earningsRepositoryProvider).fetchSummary(),
    );
  }
}
