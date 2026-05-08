import 'package:driver_app/features/auth/presentation/auth_controller.dart';
import 'package:driver_app/features/profile/data/profile_repository.dart';
import 'package:driver_app/shared/models/driver_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, DriverProfile>(
      ProfileController.new,
    );

class ProfileController extends AsyncNotifier<DriverProfile> {
  @override
  Future<DriverProfile> build() {
    return ref.read(profileRepositoryProvider).fetchProfile();
  }

  Future<void> refresh() async {
    final profile = await ref.read(profileRepositoryProvider).fetchProfile();
    state = AsyncData(profile);
    await ref
        .read(authControllerProvider.notifier)
        .updateDriverLocally(profile);
  }

  Future<void> _applyMutation(Future<DriverProfile> Function() mutation) async {
    final previousProfile = switch (state) {
      AsyncData(:final value) => value,
      _ => null,
    };
    state = const AsyncLoading();

    try {
      final profile = await mutation();
      state = AsyncData(profile);
      await ref
          .read(authControllerProvider.notifier)
          .updateDriverLocally(profile);
    } catch (error, stackTrace) {
      if (previousProfile != null) {
        state = AsyncData(previousProfile);
      } else {
        state = AsyncError(error, stackTrace);
      }
      rethrow;
    }
  }

  Future<void> setAvailability({
    required bool online,
    required bool busy,
  }) async {
    await _applyMutation(
      () => ref.read(profileRepositoryProvider).updateAvailability(
        status: online ? 'online' : 'offline',
        availability: busy ? 'busy' : 'available',
      ),
    );
  }

  Future<void> updateInventory(List<String> availableCylinderSizes) async {
    await _applyMutation(
      () => ref
          .read(profileRepositoryProvider)
          .updateInventory(availableCylinderSizes: availableCylinderSizes),
    );
  }

  Future<void> updateDispatchPreferences({
    required String dispatchScopeType,
    double? maxDispatchDistanceKm,
  }) async {
    await _applyMutation(
      () => ref.read(profileRepositoryProvider).updateDispatchPreferences(
        dispatchScopeType: dispatchScopeType,
        maxDispatchDistanceKm: maxDispatchDistanceKm,
      ),
    );
  }
}
