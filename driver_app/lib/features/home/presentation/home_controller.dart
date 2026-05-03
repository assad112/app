import 'package:driver_app/features/home/data/home_repository.dart';
import 'package:driver_app/shared/models/driver_dashboard_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final homeControllerProvider =
    AsyncNotifierProvider<HomeController, DriverDashboardData>(
      HomeController.new,
    );

class HomeController extends AsyncNotifier<DriverDashboardData> {
  @override
  Future<DriverDashboardData> build() {
    return ref.read(homeRepositoryProvider).fetchDashboard();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(homeRepositoryProvider).fetchDashboard(),
    );
  }

  Future<void> refreshSilently() async {
    final currentValue = state.valueOrNull;

    try {
      final dashboard = await ref.read(homeRepositoryProvider).fetchDashboard();
      state = AsyncData(dashboard);
    } catch (_) {
      if (currentValue != null) {
        state = AsyncData(currentValue);
      }
    }
  }
}
