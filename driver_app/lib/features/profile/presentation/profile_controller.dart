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

  Future<void> setAvailability({
    required bool online,
    required bool busy,
  }) async {
    final profile = await ref
        .read(profileRepositoryProvider)
        .updateAvailability(
          status: online ? 'online' : 'offline',
          availability: busy ? 'busy' : 'available',
        );
    state = AsyncData(profile);
    await ref
        .read(authControllerProvider.notifier)
        .updateDriverLocally(profile);
  }

  Future<void> updateInventory(List<String> availableCylinderSizes) async {
    final profile = await ref
        .read(profileRepositoryProvider)
        .updateInventory(availableCylinderSizes: availableCylinderSizes);
    state = AsyncData(profile);
    await ref
        .read(authControllerProvider.notifier)
        .updateDriverLocally(profile);
  }
}
