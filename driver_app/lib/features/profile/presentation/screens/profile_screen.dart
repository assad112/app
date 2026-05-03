import 'package:driver_app/core/localization/app_strings.dart';
import 'package:driver_app/core/theme/app_theme.dart';
import 'package:driver_app/core/utils/formatters.dart';
import 'package:driver_app/features/auth/presentation/auth_controller.dart';
import 'package:driver_app/features/auth/presentation/screens/login_screen.dart';
import 'package:driver_app/features/earnings/presentation/screens/earnings_screen.dart';
import 'package:driver_app/features/home/presentation/home_controller.dart';
import 'package:driver_app/features/orders/presentation/screens/order_history_screen.dart';
import 'package:driver_app/features/profile/presentation/profile_controller.dart';
import 'package:driver_app/shared/widgets/language_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const _cylinderSizes = ['11', '22', '44'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final dashboardState = ref.watch(homeControllerProvider);
    final driver = authState.driver;
    final strings = context.strings;
    final textTheme = Theme.of(context).textTheme;
    final profileState = ref.watch(profileControllerProvider);
    final isSavingProfile = profileState.isLoading;
    final lastLocationLabel = driver?.currentLocation.isNotEmpty == true
        ? driver!.currentLocation
        : (driver?.currentLatitude != null && driver?.currentLongitude != null)
        ? '${driver!.currentLatitude!.toStringAsFixed(5)}, ${driver.currentLongitude!.toStringAsFixed(5)}'
        : strings.noLiveLocationYet;

    final syncTime = driver?.lastLocationAt ?? driver?.lastSeenAt;
    final completedValue =
        dashboardState.valueOrNull?.totalCompleted.toString() ?? '0';
    final activeValue =
        dashboardState.valueOrNull?.activeDeliveries.toString() ?? '0';
    final earningsValue = Formatters.currency(
      dashboardState.valueOrNull?.todayEarnings ?? 0,
      localeCode: strings.localeCode,
    );

    Future<void> refreshAll() async {
      await ref.read(authControllerProvider.notifier).refreshDriver();
      await ref.read(homeControllerProvider.notifier).refreshSilently();
    }

    Future<void> showMessage(String message) async {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }

    Future<double?> promptDispatchDistance() async {
      final initialDistance = driver?.maxDispatchDistanceKm;
      final controller = TextEditingController(
        text: initialDistance == null
            ? ''
            : _formatEditableDistance(initialDistance),
      );
      String? validationMessage;

      final result = await showDialog<double>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              void applyPreset(double value) {
                controller.text = _formatEditableDistance(value);
                setDialogState(() {
                  validationMessage = null;
                });
              }

              void submit() {
                final parsedValue = double.tryParse(controller.text.trim());

                if (parsedValue == null || parsedValue <= 0) {
                  setDialogState(() {
                    validationMessage = strings.dispatchDistanceRequired;
                  });
                  return;
                }

                Navigator.of(dialogContext).pop(parsedValue);
              }

              return AlertDialog(
                title: Text(strings.dispatchDistanceDialogTitle),
                content: SizedBox(
                  width: 380,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.dispatchDistanceDialogSubtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final preset in const [3, 5, 8, 10, 12, 15, 20])
                            ActionChip(
                              label: Text(strings.kilometers(preset.toDouble())),
                              onPressed: () => applyPreset(preset.toDouble()),
                              backgroundColor: AppColors.surfaceAlt,
                              side: BorderSide(
                                color: AppColors.primary.withValues(alpha: 0.12),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        decoration: InputDecoration(
                          labelText: strings.dispatchDistanceInputLabel,
                          hintText: strings.dispatchDistanceInputHint,
                          errorText: validationMessage,
                          suffixText: strings.kilometerShort,
                        ),
                        onSubmitted: (_) => submit(),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      MaterialLocalizations.of(dialogContext).cancelButtonLabel,
                    ),
                  ),
                  FilledButton(
                    onPressed: submit,
                    child: Text(MaterialLocalizations.of(dialogContext).okButtonLabel),
                  ),
                ],
              );
            },
          );
        },
      );

      controller.dispose();
      return result;
    }

    Future<void> saveDispatchPreferences({
      required String dispatchScopeType,
      double? maxDispatchDistanceKm,
    }) async {
      try {
        await ref
            .read(profileControllerProvider.notifier)
            .updateDispatchPreferences(
              dispatchScopeType: dispatchScopeType,
              maxDispatchDistanceKm: maxDispatchDistanceKm,
            );
        await refreshAll();
        if (!context.mounted) return;
        await showMessage(strings.dispatchPreferencesSaved);
      } catch (error) {
        if (!context.mounted) return;
        await showMessage(_friendlyErrorMessage(error));
      }
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refreshAll,
          color: AppColors.primary,
          child: ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.all(20),
            children: [
              // ── Page header ───────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.profileTitle,
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          strings.profileSubtitle,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const LanguageSwitcher(compact: true),
                ],
              ),
              const SizedBox(height: 20),
              // ── Profile hero card ─────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0D1732),
                      Color(0xFF1B2E5B),
                      Color(0xFF26457E),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D1732).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        // Avatar
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withOpacity(0.8),
                                AppColors.primary,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Center(
                            child: Text(
                              (driver?.name.isNotEmpty == true
                                      ? driver!.name.substring(0, 1)
                                      : 'D')
                                  .toUpperCase(),
                              style: textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                driver?.name ?? strings.driverLabel,
                                style: textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _ContactRow(
                                icon: Icons.phone_rounded,
                                text: driver?.phone ?? '--',
                              ),
                              if (driver?.email.isNotEmpty == true) ...[
                                const SizedBox(height: 4),
                                _ContactRow(
                                  icon: Icons.alternate_email_rounded,
                                  text: driver!.email,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // Status badges
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusBadge(
                          icon: Icons.wifi_tethering_rounded,
                          label: driver?.isOnline == true
                              ? strings.online
                              : strings.offline,
                          active: driver?.isOnline == true,
                          activeColor: AppColors.success,
                        ),
                        _StatusBadge(
                          icon: Icons.local_shipping_rounded,
                          label: driver?.isBusy == true
                              ? strings.busy
                              : strings.available,
                          active: driver?.isBusy != true,
                          activeColor: AppColors.info,
                        ),
                        _StatusBadge(
                          icon: Icons.location_on_outlined,
                          label: syncTime == null
                              ? strings.noSyncYet
                              : Formatters.time(
                                  syncTime,
                                  localeCode: strings.localeCode,
                                ),
                          active: syncTime != null,
                          activeColor: AppColors.warning,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── Performance metrics ───────────────────────
              _SectionCard(
                title: strings.profilePerformance,
                child: Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.verified_rounded,
                        color: AppColors.success,
                        title: strings.completed,
                        value: completedValue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.route_rounded,
                        color: AppColors.info,
                        title: strings.activeDeliveries,
                        value: activeValue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.payments_rounded,
                        color: AppColors.warning,
                        title: strings.todayEarnings,
                        value: earningsValue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // ── Availability controls ─────────────────────
              _SectionCard(
                title: strings.profileControls,
                child: Column(
                  children: [
                    _SwitchTile(
                      icon: Icons.power_settings_new_rounded,
                      iconColor: AppColors.success,
                      title: strings.onlineMode,
                      subtitle: driver?.isOnline == true
                          ? strings.onlineReadyMessage
                          : strings.offlineReadyMessage,
                      value: driver?.isOnline == true,
                      onChanged: isSavingProfile
                          ? null
                          : (value) async {
                        await ref
                            .read(profileControllerProvider.notifier)
                            .setAvailability(
                              online: value,
                              busy: driver?.isBusy == true,
                            );
                        await refreshAll();
                      },
                    ),
                    const SizedBox(height: 10),
                    _SwitchTile(
                      icon: Icons.work_history_rounded,
                      iconColor: AppColors.warning,
                      title: strings.busyMode,
                      subtitle: driver?.isBusy == true
                          ? strings.currentStatus
                          : strings.availability,
                      value: driver?.isBusy == true,
                      onChanged: isSavingProfile
                          ? null
                          : (value) async {
                        await ref
                            .read(profileControllerProvider.notifier)
                            .setAvailability(
                              online: driver?.isOnline == true,
                              busy: value,
                            );
                        await refreshAll();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: strings.dispatchPreferencesTitle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFF5F9FF),
                            Color(0xFFEDF4FF),
                            Color(0xFFFFFBF4),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.tune_rounded,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  strings.dispatchPreferencesSubtitle,
                                  style: textTheme.bodyMedium?.copyWith(
                                    height: 1.45,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _DispatchModeOptionCard(
                            label: strings.dispatchWilayahOnly,
                            caption: strings.dispatchWilayahOnlySubtitle,
                            selected:
                                driver?.dispatchScopeType != 'wilayah_with_distance',
                            icon: Icons.map_outlined,
                            enabled: !isSavingProfile,
                            onTap: () => saveDispatchPreferences(
                              dispatchScopeType: 'wilayah_only',
                            ),
                          ),
                          const SizedBox(height: 10),
                          _DispatchModeOptionCard(
                            label: strings.dispatchWilayahWithDistance,
                            caption: strings.dispatchWilayahWithDistanceSubtitle,
                            selected:
                                driver?.dispatchScopeType == 'wilayah_with_distance',
                            icon: Icons.radar_rounded,
                            enabled: !isSavingProfile,
                            onTap: () async {
                              final selectedDistance =
                                  await promptDispatchDistance();
                              if (selectedDistance == null) {
                                return;
                              }

                              await saveDispatchPreferences(
                                dispatchScopeType: 'wilayah_with_distance',
                                maxDispatchDistanceKm: selectedDistance,
                              );
                            },
                          ),
                          if (driver?.usesDistanceDispatchScope == true) ...[
                            const SizedBox(height: 14),
                            _DispatchDistanceSummaryCard(
                              label: strings.dispatchDistanceLabel,
                              value: driver?.maxDispatchDistanceKm == null
                                  ? strings.dispatchDistanceUnset
                                  : strings.kilometers(
                                      driver!.maxDispatchDistanceKm!,
                                    ),
                              buttonLabel: driver?.maxDispatchDistanceKm == null
                                  ? strings.setDistance
                                  : strings.editDistance,
                              busy: isSavingProfile,
                              onPressed: () async {
                                final selectedDistance =
                                    await promptDispatchDistance();
                                if (selectedDistance == null) {
                                  return;
                                }

                                await saveDispatchPreferences(
                                  dispatchScopeType: 'wilayah_with_distance',
                                  maxDispatchDistanceKm: selectedDistance,
                                );
                              },
                            ),
                          ],
                          if (isSavingProfile) ...[
                            const SizedBox(height: 12),
                            Text(
                              strings.dispatchPreferencesSaving,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // ── Account details ───────────────────────────
              _SectionCard(
                title: strings.isArabic
                    ? 'مخزون الأسطوانات'
                    : 'Cylinder inventory',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFF8F1),
                            Color(0xFFFFEFE1),
                            Color(0xFFFFF7ED),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.propane_tank_rounded,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      strings.isArabic
                                          ? 'حدد الأحجام المتوفرة معك الآن ليعرف التشغيل ما يمكنك توصيله مباشرة.'
                                          : 'Select the cylinder sizes you currently carry so dispatch knows what you can deliver right away.',
                                      style: textTheme.bodyMedium?.copyWith(
                                        height: 1.45,
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      strings.isArabic
                                          ? 'يمكنك تفعيل أكثر من حجم في نفس الوقت.'
                                          : 'You can enable more than one size at the same time.',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          for (final size in _cylinderSizes) ...[
                            _InventoryOptionCard(
                              label: strings.isArabic
                                  ? '$size كيلو'
                                  : '$size kg',
                              caption: _cylinderCaption(strings, size),
                              selected:
                                  driver?.availableCylinderSizes.contains(
                                    size,
                                  ) ==
                                  true,
                              enabled: !isSavingProfile,
                              onTap: () async {
                                final currentSizes = List<String>.from(
                                  driver?.availableCylinderSizes ?? const [],
                                );

                                if (currentSizes.contains(size)) {
                                  currentSizes.remove(size);
                                } else {
                                  currentSizes.add(size);
                                }

                                currentSizes.sort(
                                  (a, b) =>
                                      int.parse(a).compareTo(int.parse(b)),
                                );

                                await ref
                                    .read(profileControllerProvider.notifier)
                                    .updateInventory(currentSizes);

                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      strings.isArabic
                                          ? 'تم تحديث الأحجام المتوفرة'
                                          : 'Available sizes updated',
                                    ),
                                  ),
                                );
                              },
                            ),
                            if (size != _cylinderSizes.last)
                              const SizedBox(height: 10),
                          ],
                          const SizedBox(height: 14),
                          Text(
                            driver?.availableCylinderSizes.isNotEmpty == true
                                ? (driver?.availableCylinderSizes
                                          .map(
                                            (size) => strings.isArabic
                                                ? '$size كيلو'
                                                : '$size kg',
                                          )
                                          .join('  •  ') ??
                                      '')
                                : (strings.isArabic
                                      ? 'لم يتم تحديد أي حجم بعد'
                                      : 'No cylinder size selected yet'),
                            style: textTheme.labelLarge?.copyWith(
                              color:
                                  driver?.availableCylinderSizes.isNotEmpty ==
                                      true
                                  ? AppColors.primaryDark
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (isSavingProfile) ...[
                            const SizedBox(height: 10),
                            Text(
                              strings.isArabic
                                  ? 'جارٍ حفظ التحديث...'
                                  : 'Saving inventory...',
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: strings.accountDetails,
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.local_shipping_outlined,
                      iconColor: AppColors.primary,
                      label: strings.vehicle,
                      value: driver?.vehicleLabel.isNotEmpty == true
                          ? driver!.vehicleLabel
                          : strings.notAssignedYet,
                    ),
                    _InfoRow(
                      icon: Icons.badge_outlined,
                      iconColor: AppColors.info,
                      label: strings.license,
                      value: driver?.licenseNumber.isNotEmpty == true
                          ? driver!.licenseNumber
                          : strings.notAssignedYet,
                    ),
                    _InfoRow(
                      icon: Icons.place_outlined,
                      iconColor: AppColors.error,
                      label: strings.lastLocation,
                      value: lastLocationLabel,
                    ),
                    _InfoRow(
                      icon: Icons.update_rounded,
                      iconColor: AppColors.textSecondary,
                      label: strings.lastSync,
                      value: syncTime == null
                          ? strings.noSyncYet
                          : Formatters.dateTime(
                              syncTime,
                              localeCode: strings.localeCode,
                            ),
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // ── Language ──────────────────────────────────
              _SectionCard(
                title: strings.manageLanguage,
                child: const Center(child: LanguageSwitcher()),
              ),
              const SizedBox(height: 12),
              // ── Quick links ───────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _ActionTile(
                      icon: Icons.stacked_line_chart_rounded,
                      iconColor: AppColors.success,
                      title: strings.earningsSummary,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const EarningsScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 70),
                    _ActionTile(
                      icon: Icons.history_rounded,
                      iconColor: AppColors.info,
                      title: strings.orderHistoryTitle,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const OrderHistoryScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // ── Logout ────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppColors.errorSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.error,
                  ),
                  title: Text(
                    strings.logout,
                    style: textTheme.titleSmall?.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.error,
                  ),
                  onTap: () async {
                    await ref.read(authControllerProvider.notifier).logout();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false,
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

String _cylinderCaption(AppStrings strings, String size) {
  if (strings.isArabic) {
    switch (size) {
      case '11':
        return 'طلبات سريعة ومنازل صغيرة';
      case '22':
        return 'الخيار الأكثر طلبًا يوميًا';
      case '44':
        return 'الطلبات الكبيرة والمطاعم';
    }
  } else {
    switch (size) {
      case '11':
        return 'Fast runs and compact homes';
      case '22':
        return 'Most requested daily size';
      case '44':
        return 'Large orders and restaurants';
    }
  }

  return size;
}

String _formatEditableDistance(double value) {
  final roundedValue = value.roundToDouble();

  if ((value - roundedValue).abs() < 0.001) {
    return roundedValue.toStringAsFixed(0);
  }

  return value.toStringAsFixed(1);
}

String _friendlyErrorMessage(Object error) {
  final message = error.toString().trim();
  const dioPrefix = 'DioException [unknown]: ';

  if (message.startsWith(dioPrefix)) {
    return message.substring(dioPrefix.length).trim();
  }

  return message;
}

class _DispatchModeOptionCard extends StatelessWidget {
  const _DispatchModeOptionCard({
    required this.label,
    required this.caption,
    required this.selected,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String caption;
  final bool selected;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : 0.7,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.white.withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : AppColors.border,
                width: selected ? 1.6 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: selected
                          ? [
                              AppColors.primary.withValues(alpha: 0.18),
                              AppColors.info.withValues(alpha: 0.14),
                            ]
                          : [AppColors.surfaceAlt, AppColors.surfaceAlt],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: selected
                        ? AppColors.primaryDark
                        : AppColors.textTertiary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        caption,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? AppColors.primaryDark : AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DispatchDistanceSummaryCard extends StatelessWidget {
  const _DispatchDistanceSummaryCard({
    required this.label,
    required this.value,
    required this.buttonLabel,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final String value;
  final String buttonLabel;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.social_distance_rounded,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: busy ? null : onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 52),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

class _InventoryOptionCard extends StatelessWidget {
  const _InventoryOptionCard({
    required this.label,
    required this.caption,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String caption;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : 0.7,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.45)
                    : AppColors.border,
                width: selected ? 1.6 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: selected
                          ? [
                              AppColors.primary.withValues(alpha: 0.18),
                              AppColors.warning.withValues(alpha: 0.16),
                            ]
                          : [AppColors.surfaceAlt, AppColors.surfaceAlt],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selected
                        ? AppColors.primaryDark
                        : AppColors.textTertiary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        caption,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    selected
                        ? (context.strings.isArabic ? 'متوفر' : 'Ready')
                        : (context.strings.isArabic ? 'غير مفعل' : 'Off'),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected
                          ? AppColors.primaryDark
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: Colors.white54),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active
            ? activeColor.withOpacity(0.15)
            : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: active
              ? activeColor.withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: active ? activeColor : Colors.white38),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: active ? Colors.white : Colors.white38,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 17, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 48, color: AppColors.border),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textTertiary,
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
