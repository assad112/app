import 'package:customer_app/core/constants/app_colors.dart';
import 'package:customer_app/core/device/device_location_service.dart';
import 'package:customer_app/shared/localization/app_copy.dart';
import 'package:customer_app/shared/models/address_model.dart';
import 'package:customer_app/shared/state/customer_app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  ConsumerState<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  static const _fallbackLocation = LatLng(23.5880, 58.3829);
  static const _initialZoom = 16.0;

  final MapController _mapController = MapController();
  late LatLng _selectedPoint;
  bool _isResolving = false;
  bool _isSaving = false;
  double? _accuracyMeters;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final state = ref.read(customerAppControllerProvider);
    final address = state.defaultAddress;
    _selectedPoint = address == null
        ? _fallbackLocation
        : LatLng(address.latitude, address.longitude);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _locateMe();
    });
  }

  Future<void> _locateMe() async {
    if (_isResolving) return;

    setState(() {
      _isResolving = true;
      _errorMessage = null;
    });

    final copy = AppCopy(ref.read(customerAppControllerProvider).language);
    try {
      final snapshot = await ref
          .read(deviceLocationServiceProvider)
          .getPreciseLocation(localeIdentifier: copy.isRtl ? 'ar_OM' : 'en_OM');

      if (!mounted) return;
      final point = LatLng(snapshot.latitude, snapshot.longitude);
      setState(() {
        _selectedPoint = point;
        _accuracyMeters = snapshot.accuracyMeters;
        _isResolving = false;
      });
      _mapController.move(point, 17);
    } on DeviceLocationException catch (error) {
      if (!mounted) return;
      setState(() {
        _isResolving = false;
        _errorMessage = _locationError(error.failure, copy);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isResolving = false;
        _errorMessage = copy.t('location.unavailable');
      });
    }
  }

  String _locationError(DeviceLocationFailure failure, AppCopy copy) {
    switch (failure) {
      case DeviceLocationFailure.serviceDisabled:
        return copy.t('location.serviceDisabled');
      case DeviceLocationFailure.permissionDenied:
        return copy.t('location.permissionDenied');
      case DeviceLocationFailure.permissionDeniedForever:
        return copy.t('location.permissionDeniedForever');
      case DeviceLocationFailure.outOfCoverage:
        return copy.t('location.outOfCoverage');
      case DeviceLocationFailure.unavailable:
        return copy.t('location.unavailable');
    }
  }

  Future<void> _confirm(AppCopy copy) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final address = await _buildAddress(copy);
    if (!mounted) return;

    await ref
        .read(customerAppControllerProvider.notifier)
        .selectDefaultAddress(address);

    if (!mounted) return;
    context.pop(address);
  }

  Future<AddressModel> _buildAddress(AppCopy copy) async {
    Placemark? placemark;
    try {
      await setLocaleIdentifier(
        copy.isRtl ? 'ar_OM' : 'en_OM',
      ).timeout(const Duration(seconds: 1));
      final placemarks = await placemarkFromCoordinates(
        _selectedPoint.latitude,
        _selectedPoint.longitude,
      ).timeout(const Duration(seconds: 2));
      if (placemarks.isNotEmpty) {
        placemark = placemarks.first;
      }
    } catch (_) {
      placemark = null;
    }

    final latitudeText = _selectedPoint.latitude.toStringAsFixed(6);
    final longitudeText = _selectedPoint.longitude.toStringAsFixed(6);

    String firstNonEmpty(List<String?> values, String fallback) {
      for (final value in values) {
        final trimmed = value?.trim() ?? '';
        if (trimmed.isNotEmpty) return trimmed;
      }
      return fallback;
    }

    final title = copy.isRtl ? 'الموقع المحدد' : 'Selected location';
    final coordinates = '$latitudeText, $longitudeText';

    return AddressModel(
      id: AddressModel.currentLocationId,
      label: firstNonEmpty([
        placemark?.subLocality,
        placemark?.locality,
        placemark?.street,
      ], title),
      governorate: firstNonEmpty([
        placemark?.administrativeArea,
        placemark?.subAdministrativeArea,
        placemark?.country,
      ], title),
      wilayat: firstNonEmpty([
        placemark?.subAdministrativeArea,
        placemark?.locality,
        placemark?.subLocality,
      ], title),
      area: firstNonEmpty([
        placemark?.subLocality,
        placemark?.locality,
        placemark?.name,
      ], coordinates),
      street: firstNonEmpty([
        placemark?.street,
        placemark?.thoroughfare,
        placemark?.name,
      ], copy.isRtl ? 'تم تحديده من الخريطة' : 'Selected on map'),
      houseNumber: firstNonEmpty([
        placemark?.subThoroughfare,
        placemark?.name,
      ], '-'),
      landmark: firstNonEmpty([
        placemark?.name,
        placemark?.street,
        placemark?.locality,
      ], coordinates),
      latitude: _selectedPoint.latitude,
      longitude: _selectedPoint.longitude,
      isDefault: true,
    );
  }

  String? _accuracyText(AppCopy copy) {
    final accuracy = _accuracyMeters;
    if (accuracy == null) {
      return null;
    }

    final rounded = accuracy.round();
    if (accuracy <= 5) {
      return copy.isRtl
          ? 'دقة ممتازة: $rounded م'
          : 'Excellent accuracy: $rounded m';
    }
    if (accuracy <= 20) {
      return copy.isRtl ? 'دقة جيدة: $rounded م' : 'Good accuracy: $rounded m';
    }
    return copy.isRtl
        ? 'الدقة $rounded م، حرّك المؤشر للتأكيد'
        : 'Accuracy $rounded m, adjust the pin to confirm';
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(customerAppControllerProvider);
    final copy = AppCopy(appState.language);
    final accuracyText = _accuracyText(copy);

    return Directionality(
      textDirection: copy.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _selectedPoint,
                initialZoom: _initialZoom,
                onTap: (_, point) {
                  setState(() => _selectedPoint = point);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.omangas.customer_app',
                  errorImage: MemoryImage(TileProvider.transparentImage),
                  errorTileCallback: (tile, error, stackTrace) {},
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedPoint,
                      width: 54,
                      height: 54,
                      child: const _PickerPin(),
                    ),
                  ],
                ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  _MapIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Text(
                        copy.isRtl
                            ? 'حدد موقعك بدقة'
                            : 'Pick your exact location',
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _MapIconButton(
                    icon: Icons.my_location_rounded,
                    isLoading: _isResolving,
                    onTap: _locateMe,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 16,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.brand,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              copy.isRtl
                                  ? 'اضغط على الخريطة أو استخدم زر موقعي الحالي'
                                  : 'Tap the map or use current location',
                              style: const TextStyle(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (accuracyText != null || _errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            _errorMessage ?? accuracyText!,
                            style: TextStyle(
                              color: _errorMessage == null
                                  ? AppColors.muted
                                  : Colors.redAccent,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : () => _confirm(copy),
                          icon: _isSaving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          label: Text(
                            copy.isRtl ? 'تأكيد الموقع' : 'Confirm location',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapIconButton extends StatelessWidget {
  const _MapIconButton({
    required this.icon,
    required this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: const Color(0x33000000),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: isLoading ? null : onTap,
        child: SizedBox(
          height: 48,
          width: 48,
          child: Center(
            child: isLoading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : Icon(icon, color: AppColors.navy),
          ),
        ),
      ),
    );
  }
}

class _PickerPin extends StatelessWidget {
  const _PickerPin();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.brand,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(
        Icons.location_on_rounded,
        color: Colors.white,
        size: 28,
      ),
    );
  }
}
