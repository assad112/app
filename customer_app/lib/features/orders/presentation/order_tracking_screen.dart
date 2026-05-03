import 'dart:async';

import 'package:customer_app/core/constants/app_colors.dart';
import 'package:customer_app/core/device/device_location_service.dart';
import 'package:customer_app/data/services/customer_route_service.dart';
import 'package:customer_app/data/services/customer_order_service.dart';
import 'package:customer_app/core/widgets/primary_button.dart';
import 'package:customer_app/core/widgets/status_chip.dart';
import 'package:customer_app/shared/localization/app_copy.dart';
import 'package:customer_app/shared/models/address_model.dart';
import 'package:customer_app/shared/models/delivery_route.dart';
import 'package:customer_app/shared/models/order_model.dart';
import 'package:customer_app/shared/models/order_status.dart';
import 'package:customer_app/shared/state/customer_app_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:latlong2/latlong.dart';

class OrderTrackingScreen extends ConsumerStatefulWidget {
  const OrderTrackingScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderTrackingScreen> createState() =>
      _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen>
    with WidgetsBindingObserver {
  static const LatLng _fallbackLocation = LatLng(23.5880, 58.3829);
  static const double _fallbackZoom = 10.5;
  static const double _trackingPointTolerance = 0.00002;

  late final Future<void> _mapInitializationFuture;
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  DeviceLocationSnapshot? _currentLocationSnapshot;
  bool _isRefreshingTracking = false;
  bool _isFetchingTrackingData = false;
  bool _isLoadingCurrentLocation = false;
  bool _isUpdatingDeliveryLocation = false;
  bool _isLiveTrackingEnabled = false;
  bool _isMapReady = false;
  String? _currentLocationError;
  String? _lastCameraSignature;
  String? _lastAnnouncedOrderId;
  OrderStatus? _lastAnnouncedOrderStatus;
  String? _trackedOrderId;
  DateTime? _lastDriverMovementAt;
  final List<LatLng> _driverTrail = <LatLng>[];
  Timer? _noDriverRetryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mapInitializationFuture = _initializeTracking();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final order = _resolveTrackedOrder(
        ref.read(customerAppControllerProvider).orders,
      );
      if (_supportsLiveTracking(order)) {
        unawaited(_refreshTrackingData(showLoader: false));
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mapController.dispose();
    _noDriverRetryTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeTracking() async {
    await _refreshTrackingData(showLoader: false);
    unawaited(_loadCurrentLocation());
  }

  Future<void> _refreshTrackingData({bool showLoader = true}) async {
    if (_isFetchingTrackingData) {
      return;
    }

    _isFetchingTrackingData = true;

    if (showLoader && mounted) {
      setState(() {
        _isRefreshingTracking = true;
      });
    }

    try {
      await ref
          .read(customerAppControllerProvider.notifier)
          .refreshOrdersFromBackend();

      if (!mounted) {
        return;
      }

      if (showLoader) {
        setState(() {
          _isRefreshingTracking = false;
        });
      }

      _scheduleCameraFit(force: true);
    } finally {
      _isFetchingTrackingData = false;

      if (showLoader && mounted && _isRefreshingTracking) {
        setState(() {
          _isRefreshingTracking = false;
        });
      }
    }
  }

  Future<void> _loadCurrentLocation() async {
    final appState = ref.read(customerAppControllerProvider);
    final copy = AppCopy(appState.language);
    final localeIdentifier = copy.isRtl ? 'ar_OM' : 'en_OM';

    setState(() {
      _isLoadingCurrentLocation = true;
      _currentLocationError = null;
    });

    try {
      final snapshot = await ref
          .read(deviceLocationServiceProvider)
          .getPreciseLocation(localeIdentifier: localeIdentifier);
      final nextLocation = LatLng(snapshot.latitude, snapshot.longitude);

      if (!mounted) {
        return;
      }

      setState(() {
        _currentLocation = nextLocation;
        _currentLocationSnapshot = snapshot;
        _isLoadingCurrentLocation = false;
      });

      _scheduleCameraFit(force: true);
    } on DeviceLocationException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _currentLocation = null;
        _currentLocationSnapshot = null;
        _isLoadingCurrentLocation = false;
        _currentLocationError = _locationFailureMessage(error.failure, copy);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _currentLocation = null;
        _currentLocationSnapshot = null;
        _isLoadingCurrentLocation = false;
        _currentLocationError = copy.t('location.unavailable');
      });
    }
  }

  String _locationFailureMessage(DeviceLocationFailure failure, AppCopy copy) {
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

  String? _buildCurrentLocationGuidance(AppCopy copy) {
    final snapshot = _currentLocationSnapshot;
    if (snapshot == null) {
      return null;
    }

    final accuracy = snapshot.accuracyMeters;
    if (!snapshot.isFromLastKnown && accuracy != null && accuracy <= 60) {
      return null;
    }

    return copy.isRtl
        ? 'الموقع الحالي ما زال تقريبيًا. اضغط "استخدام الموقع الحالي" مرة أخرى قرب نافذة أو في مكان مفتوح لتحسين الدقة.'
        : 'Your current position is still approximate. Tap "Use current location" again near a window or open area for a better fix.';
  }

  OrderModel? _resolveTrackedOrder(List<OrderModel> orders) {
    final orderId = widget.orderId.trim();
    final candidates = <String>{
      orderId,
      if (!orderId.toUpperCase().startsWith('ORD-')) 'ORD-$orderId',
    };

    for (final order in orders) {
      if (candidates.contains(order.orderId)) {
        return order;
      }
    }

    return null;
  }

  LatLng? _asLatLng(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) {
      return null;
    }

    if (latitude == 0 && longitude == 0) {
      return null;
    }

    return LatLng(latitude, longitude);
  }

  LatLng? _customerLocation(OrderModel? order) {
    if (order == null) {
      return null;
    }

    return _asLatLng(order.address.latitude, order.address.longitude);
  }

  LatLng? _effectiveDeliveryLocation(OrderModel? order) {
    return _customerLocation(order) ?? _currentLocation;
  }

  bool _isUsingCurrentLocationAsDelivery(OrderModel? order) {
    final currentLocation = _currentLocation;
    final deliveryLocation = _customerLocation(order);

    if (deliveryLocation == null) {
      return currentLocation != null;
    }

    if (currentLocation == null) {
      return false;
    }

    return _isSameTrackingPoint(deliveryLocation, currentLocation);
  }

  String _deliveryAddressText(AppCopy copy, OrderModel? order) {
    if (_isUsingCurrentLocationAsDelivery(order)) {
      final placemark = _currentLocationSnapshot?.placemark;
      final parts = <String>[
        if (placemark?.street?.trim().isNotEmpty ?? false)
          placemark!.street!.trim(),
        if (placemark?.subLocality?.trim().isNotEmpty ?? false)
          placemark!.subLocality!.trim(),
        if (placemark?.locality?.trim().isNotEmpty ?? false)
          placemark!.locality!.trim(),
      ];

      if (parts.isNotEmpty) {
        return parts.join(copy.isRtl ? '، ' : ', ');
      }

      final currentLocation = _currentLocation;
      if (currentLocation != null) {
        return '${currentLocation.latitude.toStringAsFixed(6)}, ${currentLocation.longitude.toStringAsFixed(6)}';
      }
    }

    return order?.address.fullAddress ?? '';
  }

  LatLng? _driverLocation(OrderModel? order) {
    if (order == null) {
      return null;
    }

    return _asLatLng(order.driverLatitude, order.driverLongitude);
  }

  bool _supportsLiveTracking(OrderModel? order) {
    if (order == null) {
      return false;
    }

    switch (order.orderStatus) {
      case OrderStatus.searchingDriver:
      case OrderStatus.driverNotified:
      case OrderStatus.noDriverFound:
      case OrderStatus.pendingReview:
      case OrderStatus.delivered:
      case OrderStatus.cancelled:
        return false;
      case OrderStatus.accepted:
      case OrderStatus.preparing:
      case OrderStatus.onTheWay:
        return true;
    }
  }

  bool _isSameTrackingPoint(LatLng left, LatLng right) {
    return (left.latitude - right.latitude).abs() <= _trackingPointTolerance &&
        (left.longitude - right.longitude).abs() <= _trackingPointTolerance;
  }

  void _recordDriverMovement(LatLng? driverLocation, DateTime? updatedAt) {
    if (driverLocation == null) {
      return;
    }

    if (_driverTrail.isNotEmpty &&
        _isSameTrackingPoint(_driverTrail.last, driverLocation)) {
      return;
    }

    _driverTrail.add(driverLocation);
    if (_driverTrail.length > 90) {
      _driverTrail.removeRange(0, _driverTrail.length - 90);
    }

    _lastDriverMovementAt = updatedAt ?? DateTime.now();
  }

  void _syncLiveTrackingState(OrderModel? order) {
    if (_trackedOrderId != order?.orderId) {
      _trackedOrderId = order?.orderId;
      _driverTrail.clear();
      _lastDriverMovementAt = null;
      _lastCameraSignature = null;
    }

    final nextTrackingEnabled = _supportsLiveTracking(order);
    if (nextTrackingEnabled != _isLiveTrackingEnabled) {
      _isLiveTrackingEnabled = nextTrackingEnabled;
    }

    _recordDriverMovement(_driverLocation(order), order?.updatedAt);
    _syncNoDriverPolling(order);
  }

  void _syncNoDriverPolling(OrderModel? order) {
    final isWaitingForDriver =
        order?.orderStatus == OrderStatus.noDriverFound ||
        order?.orderStatus == OrderStatus.searchingDriver;

    if (isWaitingForDriver && _noDriverRetryTimer == null) {
      _noDriverRetryTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _refreshTrackingData(showLoader: false),
      );
    } else if (!isWaitingForDriver) {
      _noDriverRetryTimer?.cancel();
      _noDriverRetryTimer = null;
    }
  }

  void _syncProgressAnnouncement(OrderModel? order, AppCopy copy) {
    final orderId = order?.orderId;
    final nextStatus = order?.orderStatus;

    if (orderId == null || nextStatus == null) {
      _lastAnnouncedOrderId = null;
      _lastAnnouncedOrderStatus = null;
      return;
    }

    if (_lastAnnouncedOrderId != orderId) {
      _lastAnnouncedOrderId = orderId;
      _lastAnnouncedOrderStatus = nextStatus;
      return;
    }

    if (_lastAnnouncedOrderStatus == nextStatus) {
      return;
    }

    _lastAnnouncedOrderStatus = nextStatus;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(copy.t(nextStatus.progressMessageKey()))),
        );
    });
  }

  void _scheduleCameraFit({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isMapReady) {
        return;
      }

      final appState = ref.read(customerAppControllerProvider);
      final order = _resolveTrackedOrder(appState.orders);
      final signature = [
        order?.orderId ?? 'missing',
        order?.address.latitude.toStringAsFixed(6) ?? 'na',
        order?.address.longitude.toStringAsFixed(6) ?? 'na',
        order?.driverLatitude?.toStringAsFixed(6) ?? 'na',
        order?.driverLongitude?.toStringAsFixed(6) ?? 'na',
        _currentLocation?.latitude.toStringAsFixed(6) ?? 'na',
        _currentLocation?.longitude.toStringAsFixed(6) ?? 'na',
      ].join('|');

      if (!force && _lastCameraSignature == signature) {
        return;
      }

      _lastCameraSignature = signature;
      unawaited(_fitCamera(order));
    });
  }

  Future<void> _fitCamera(OrderModel? order) async {
    if (!_isMapReady) {
      return;
    }

    final deliveryLocation = _effectiveDeliveryLocation(order);
    final driverLocation = _driverLocation(order);

    final points = <LatLng>[];
    if (deliveryLocation != null) {
      points.add(deliveryLocation);
    }
    if (driverLocation != null) {
      points.add(driverLocation);
    }
    if (_currentLocation != null && !_isUsingCurrentLocationAsDelivery(order)) {
      points.add(_currentLocation!);
    }

    if (points.isEmpty) {
      _mapController.move(_fallbackLocation, _fallbackZoom);
      return;
    }

    if (points.length == 1) {
      _mapController.move(points.first, 15.5);
      return;
    }

    try {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(72),
          maxZoom: 16.2,
        ),
      );
    } catch (_) {
      _mapController.move(points.first, 14.5);
    }
  }

  void _handleMapReady() {
    _isMapReady = true;
    _scheduleCameraFit(force: true);
  }

  double? _normalizedRouteCoordinate(double? value) {
    if (value == null) {
      return null;
    }

    return double.parse(value.toStringAsFixed(6));
  }

  List<Marker> _buildMarkers(OrderModel? order) {
    final deliveryLocation = _effectiveDeliveryLocation(order);
    final driverLocation = _driverLocation(order);
    final useCurrentAsDelivery = _isUsingCurrentLocationAsDelivery(order);

    return <Marker>[
      if (deliveryLocation != null)
        Marker(
          point: deliveryLocation,
          width: 52,
          height: 52,
          child: _MapPin(
            icon: Icons.home_rounded,
            color: useCurrentAsDelivery ? AppColors.teal : AppColors.brand,
          ),
        ),
      if (driverLocation != null)
        Marker(
          point: driverLocation,
          width: 52,
          height: 52,
          child: const _MapPin(
            icon: Icons.local_shipping_rounded,
            color: AppColors.info,
          ),
        ),
      if (_currentLocation != null && !useCurrentAsDelivery)
        Marker(
          point: _currentLocation!,
          width: 48,
          height: 48,
          child: const _MapPin(
            icon: Icons.my_location_rounded,
            color: AppColors.teal,
          ),
        ),
    ];
  }

  List<Polyline> _buildPolylines(OrderModel? order, DeliveryRoute? route) {
    final deliveryLocation = _effectiveDeliveryLocation(order);
    final driverLocation = _driverLocation(order);
    final resolvedRoute = route?.hasPath == true
        ? route
        : (order?.routePoints.length ?? 0) > 1
        ? DeliveryRoute(points: order!.routePoints)
        : null;
    final trackingRoutePoints =
        resolvedRoute?.points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList(growable: false) ??
        const <LatLng>[];

    final polylines = <Polyline>[];

    if (_driverTrail.length > 1) {
      polylines.add(
        Polyline(
          points: List<LatLng>.from(_driverTrail),
          color: AppColors.teal,
          strokeWidth: 6,
        ),
      );
    }

    if (trackingRoutePoints.length > 1) {
      polylines.add(
        Polyline(
          points: trackingRoutePoints,
          color: AppColors.brand,
          strokeWidth: 5,
        ),
      );
    } else if (deliveryLocation != null && driverLocation != null) {
      polylines.add(
        Polyline(
          points: [driverLocation, deliveryLocation],
          color: AppColors.brand,
          strokeWidth: 5,
        ),
      );
    }

    return polylines;
  }

  List<CircleMarker> _buildCircles(OrderModel? order) {
    final driverLocation = _driverLocation(order);
    if (driverLocation == null || !_isLiveTrackingEnabled) {
      return const <CircleMarker>[];
    }

    return <CircleMarker>[
      CircleMarker(
        point: driverLocation,
        radius: 38,
        useRadiusInMeter: true,
        color: AppColors.teal.withValues(alpha: 0.14),
        borderColor: AppColors.teal.withValues(alpha: 0.34),
        borderStrokeWidth: 2,
      ),
    ];
  }

  String _formatUpdatedAt(DateTime value, AppCopy copy) {
    final locale = copy.isRtl ? 'ar_OM' : 'en_OM';
    return DateFormat('dd MMM - hh:mm a', locale).format(value);
  }

  Widget _buildMap(OrderModel? order, DeliveryRoute? route) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _fallbackLocation,
            initialZoom: _fallbackZoom,
            onMapReady: _handleMapReady,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.omangas.customer_app',
            ),
            PolylineLayer(polylines: _buildPolylines(order, route)),
            CircleLayer(circles: _buildCircles(order)),
            MarkerLayer(markers: _buildMarkers(order)),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        if (_isRefreshingTracking && order == null)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
              ),
              child: const Center(child: CircularProgressIndicator.adaptive()),
            ),
          ),
      ],
    );
  }

  AddressModel _buildCurrentLocationAddress(AppCopy copy) {
    final snapshot = _currentLocationSnapshot;
    final currentLocation = _currentLocation!;
    final placemark = snapshot?.placemark;
    final latitudeText = currentLocation.latitude.toStringAsFixed(6);
    final longitudeText = currentLocation.longitude.toStringAsFixed(6);

    String firstNonEmpty(List<String?> values, String fallback) {
      for (final value in values) {
        final trimmed = value?.trim() ?? '';
        if (trimmed.isNotEmpty) {
          return trimmed;
        }
      }

      return fallback;
    }

    final governorate = firstNonEmpty([
      placemark?.administrativeArea,
      placemark?.subAdministrativeArea,
      placemark?.country,
    ], copy.isRtl ? 'موقعي الحالي' : 'My current location');
    final wilayat = firstNonEmpty([
      placemark?.subAdministrativeArea,
      placemark?.locality,
      placemark?.subLocality,
    ], governorate);
    final area = firstNonEmpty([
      placemark?.subLocality,
      placemark?.locality,
      placemark?.name,
    ], '$latitudeText, $longitudeText');
    final street = firstNonEmpty([
      placemark?.street,
      placemark?.thoroughfare,
      placemark?.name,
    ], copy.isRtl ? 'تم تحديده عبر GPS' : 'Detected by GPS');
    final houseNumber = firstNonEmpty([
      placemark?.subThoroughfare,
      placemark?.name,
    ], '-');
    final landmark = firstNonEmpty([
      placemark?.name,
      placemark?.street,
      placemark?.locality,
    ], '$latitudeText, $longitudeText');

    return AddressModel(
      id: AddressModel.currentLocationId,
      label: firstNonEmpty([
        placemark?.subLocality,
        placemark?.locality,
        placemark?.street,
      ], copy.isRtl ? 'موقعي الحالي' : 'My current location'),
      governorate: governorate,
      wilayat: wilayat,
      area: area,
      street: street,
      houseNumber: houseNumber,
      landmark: landmark,
      latitude: currentLocation.latitude,
      longitude: currentLocation.longitude,
      isDefault: true,
    );
  }

  List<AddressModel> _buildDeliveryLocationOptions(AppCopy copy) {
    final appState = ref.read(customerAppControllerProvider);
    final options = <AddressModel>[];

    void addOption(AddressModel address) {
      final point = _asLatLng(address.latitude, address.longitude);
      if (point == null) {
        return;
      }

      for (final existing in options) {
        final existingPoint = _asLatLng(existing.latitude, existing.longitude);
        if (existing.id == address.id) {
          return;
        }

        if (existingPoint != null &&
            _isSameTrackingPoint(existingPoint, point)) {
          return;
        }
      }

      options.add(address);
    }

    if (_currentLocation != null) {
      addOption(
        _buildCurrentLocationAddress(
          copy,
        ).copyWith(label: copy.t('order.currentGpsAddress')),
      );
    }

    for (final address in appState.addresses) {
      addOption(address);
    }

    return options;
  }

  String _deliveryLocationOptionSubtitle(AddressModel address) {
    if (address.fullAddress.trim().isNotEmpty) {
      return address.fullAddress;
    }

    return '${address.latitude.toStringAsFixed(6)}, ${address.longitude.toStringAsFixed(6)}';
  }

  bool _isSelectedDeliveryLocation(OrderModel? order, AddressModel address) {
    final currentDelivery = _customerLocation(order);
    final optionLocation = _asLatLng(address.latitude, address.longitude);
    if (currentDelivery == null || optionLocation == null) {
      return false;
    }

    return _isSameTrackingPoint(currentDelivery, optionLocation);
  }

  Future<void> _changeDeliveryLocation(AppCopy copy) async {
    if (_isUpdatingDeliveryLocation) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    if (_currentLocation == null && !_isLoadingCurrentLocation) {
      await _loadCurrentLocation();
    }

    if (!mounted) {
      return;
    }

    final appState = ref.read(customerAppControllerProvider);
    final order = _resolveTrackedOrder(appState.orders);
    final options = _buildDeliveryLocationOptions(copy);

    if (options.isEmpty) {
      final message =
          _currentLocationError ??
          copy.t('tracking.deliveryLocationUnavailable');
      messenger.showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    final selectedAddress = await showModalBottomSheet<AddressModel>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.t('tracking.chooseDeliveryLocation'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 380),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (sheetContext, index) {
                      final address = options[index];
                      final isSelected = _isSelectedDeliveryLocation(
                        order,
                        address,
                      );

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () => Navigator.of(sheetContext).pop(address),
                        leading: Icon(
                          address.isCurrentLocation
                              ? Icons.my_location_rounded
                              : Icons.location_on_rounded,
                          color: isSelected ? AppColors.teal : AppColors.muted,
                        ),
                        title: Text(
                          address.label.trim().isNotEmpty
                              ? address.label
                              : copy.t('tracking.deliveryAddress'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _deliveryLocationOptionSubtitle(address),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.muted,
                              height: 1.45,
                            ),
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.teal,
                              )
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selectedAddress == null) {
      return;
    }

    setState(() {
      _isUpdatingDeliveryLocation = true;
    });

    try {
      await ref
          .read(customerAppControllerProvider.notifier)
          .updateOrderDeliveryLocation(
            orderId: widget.orderId,
            address: selectedAddress,
          );

      if (!mounted) {
        return;
      }

      _scheduleCameraFit(force: true);
      messenger.showSnackBar(
        SnackBar(content: Text(copy.t('tracking.deliveryLocationUpdated'))),
      );
    } on RemoteOrderSubmissionException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } on DioException catch (error) {
      if (!mounted) return;
      final message = switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'تعذّر الاتصال بالخادم. تحقق من اتصالك بالإنترنت وحاول مجدداً.',
        DioExceptionType.connectionError =>
          'تعذّر الوصول إلى الخادم. تحقق من اتصالك بالإنترنت.',
        _ => 'تعذّر تحديث موقع التسليم. حاول مجدداً.',
      };
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingDeliveryLocation = false;
        });
      }
    }
  }

  Widget _buildChangeDeliveryLocationButton(AppCopy copy, OrderModel? order) {
    final canChange =
        order != null &&
        order.orderStatus != OrderStatus.delivered &&
        order.orderStatus != OrderStatus.cancelled;

    return SecondaryButton(
      label: copy.t('tracking.changeDeliveryLocation'),
      onPressed: !canChange || _isUpdatingDeliveryLocation
          ? null
          : () => _changeDeliveryLocation(copy),
      icon: _isUpdatingDeliveryLocation
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          : const Icon(Icons.edit_location_alt_rounded),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(customerAppControllerProvider);
    final copy = AppCopy(appState.language);
    final order = _resolveTrackedOrder(appState.orders);
    _syncLiveTrackingState(order);
    _syncProgressAnnouncement(order, copy);
    final driverLocation = _driverLocation(order);
    final deliveryLocation = _effectiveDeliveryLocation(order);
    final routeAsync = ref.watch(
      customerRouteProvider((
        fromLat: _normalizedRouteCoordinate(driverLocation?.latitude),
        fromLng: _normalizedRouteCoordinate(driverLocation?.longitude),
        toLat: _normalizedRouteCoordinate(deliveryLocation?.latitude),
        toLng: _normalizedRouteCoordinate(deliveryLocation?.longitude),
      )),
    );
    final route = routeAsync.asData?.value;
    final routeDistanceMeters =
        route?.distanceMeters ?? order?.routeDistanceMeters;
    final routeDurationSeconds =
        route?.durationSeconds ?? order?.routeDurationSeconds;
    final resolvedEtaMinutes =
        route?.etaMinutes ??
        order?.driver?.etaMinutes ??
        (routeDurationSeconds == null
            ? null
            : (routeDurationSeconds / 60).ceil());
    final hasRealRoute =
        route?.hasPath == true || (order?.routePoints.length ?? 0) > 1;
    final hasDriverMovementTrail = _driverTrail.length > 1;
    final currentLocationGuidance = _buildCurrentLocationGuidance(copy);
    final usingCurrentLocationAsDelivery = _isUsingCurrentLocationAsDelivery(
      order,
    );
    final theme = Theme.of(context);

    _scheduleCameraFit();

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.88),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: const EdgeInsetsDirectional.only(start: 12),
          child: Center(
            child: _BackButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/orders');
                }
              },
            ),
          ),
        ),
        title: Text(
          copy.t('tracking.title'),
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Stack(
        children: [
          // --- Full-screen map ---
          Positioned.fill(
            child: FutureBuilder<void>(
              future: _mapInitializationFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done &&
                    order == null) {
                  return ColoredBox(
                    color: AppColors.surfaceMuted,
                    child: const Center(
                      child: CircularProgressIndicator.adaptive(),
                    ),
                  );
                }
                return _buildMap(order, route);
              },
            ),
          ),

          // --- Bottom details sheet ---
          DraggableScrollableSheet(
            initialChildSize: 0.44,
            minChildSize: 0.13,
            maxChildSize: 0.88,
            snap: true,
            snapSizes: const [0.13, 0.44, 0.88],
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1A091D33),
                      blurRadius: 32,
                      offset: Offset(0, -6),
                    ),
                  ],
                ),
                child: order == null
                    ? _buildEmptySheetContent(scrollController, copy, theme)
                    : _buildOrderSheetContent(
                        scrollController: scrollController,
                        theme: theme,
                        copy: copy,
                        order: order,
                        driverLocation: driverLocation,
                        deliveryLocation: deliveryLocation,
                        routeDistanceMeters: routeDistanceMeters,
                        resolvedEtaMinutes: resolvedEtaMinutes,
                        hasRealRoute: hasRealRoute,
                        hasDriverMovementTrail: hasDriverMovementTrail,
                        currentLocationGuidance: currentLocationGuidance,
                        usingCurrentLocationAsDelivery:
                            usingCurrentLocationAsDelivery,
                      ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.stroke,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }

  Widget _buildEmptySheetContent(
    ScrollController scrollController,
    AppCopy copy,
    ThemeData theme,
  ) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        _buildDragHandle(),
        const SizedBox(height: 20),
        Center(
          child: Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.search_off_rounded,
              color: AppColors.warning,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          copy.t('tracking.orderNotFound'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppColors.navy,
            fontWeight: FontWeight.w700,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: copy.t('tracking.refreshData'),
          onPressed: _isRefreshingTracking
              ? null
              : () => _refreshTrackingData(),
          isLoading: _isRefreshingTracking,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  Widget _buildOrderSheetContent({
    required ScrollController scrollController,
    required ThemeData theme,
    required AppCopy copy,
    required OrderModel order,
    required LatLng? driverLocation,
    required LatLng? deliveryLocation,
    required int? routeDistanceMeters,
    required int? resolvedEtaMinutes,
    required bool hasRealRoute,
    required bool hasDriverMovementTrail,
    required String? currentLocationGuidance,
    required bool usingCurrentLocationAsDelivery,
  }) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        _buildDragHandle(),

        // ── Section 1: Order header ──
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    order.orderStatus.tone().withValues(alpha: 0.15),
                    order.orderStatus.softTone(),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                Icons.route_rounded,
                color: order.orderStatus.tone(),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.orderId,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatUpdatedAt(order.updatedAt, copy),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            StatusChip(status: order.orderStatus, copy: copy),
          ],
        ),

        // ── Section 2: Order status timeline ──
        const SizedBox(height: 20),
        _OrderProgressBanner(status: order.orderStatus, copy: copy),
        const SizedBox(height: 14),
        _OrderStatusTimeline(status: order.orderStatus, copy: copy),

        // ── Section 3: ETA & Distance cards ──
        if (routeDistanceMeters != null || resolvedEtaMinutes != null) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              if (resolvedEtaMinutes != null)
                Expanded(
                  child: _MetricCard(
                    icon: Icons.schedule_rounded,
                    iconColor: AppColors.brand,
                    iconBgColor: AppColors.brandSoft,
                    value: '$resolvedEtaMinutes',
                    unit: copy.isRtl ? 'دقيقة' : 'min',
                    label: copy.t('tracking.eta'),
                  ),
                ),
              if (routeDistanceMeters != null && resolvedEtaMinutes != null)
                const SizedBox(width: 12),
              if (routeDistanceMeters != null)
                Expanded(
                  child: _MetricCard(
                    icon: Icons.straighten_rounded,
                    iconColor: AppColors.teal,
                    iconBgColor: AppColors.tealSoft,
                    value: (routeDistanceMeters / 1000).toStringAsFixed(1),
                    unit: copy.isRtl ? 'كم' : 'km',
                    label: copy.t('tracking.distance'),
                  ),
                ),
            ],
          ),
        ],

        // ── Section 4: Route status hint ──
        const SizedBox(height: 16),
        _RouteHintBanner(
          hasDriver: driverLocation != null,
          hasRealRoute: hasRealRoute,
          copy: copy,
        ),

        // ── Section 5: Live tracking badge ──
        if (_isLiveTrackingEnabled) ...[
          const SizedBox(height: 12),
          _LiveTrackingBadge(
            copy: copy,
            hasDriverLocation: driverLocation != null,
            lastMovementAt: _lastDriverMovementAt,
            trailLength: _driverTrail.length,
            hasDriverMovementTrail: hasDriverMovementTrail,
            formatUpdatedAt: (dt) => _formatUpdatedAt(dt, copy),
          ),
        ],

        // ── Divider ──
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Divider(
            color: AppColors.stroke.withValues(alpha: 0.6),
            height: 1,
          ),
        ),

        // ── Section 6: Driver info ──
        if (order.driver != null)
          _DriverInfoCard(copy: copy, order: order)
        else
          _PendingDriverCard(copy: copy),

        // ── Section 7: Delivery address ──
        const SizedBox(height: 16),
        _DeliveryAddressCard(
          copy: copy,
          addressText: _deliveryAddressText(copy, order),
          isUsingCurrentLocation: usingCurrentLocationAsDelivery,
        ),

        // ── Section 8: Location warnings ──
        if (currentLocationGuidance != null) ...[
          const SizedBox(height: 12),
          _WarningBanner(text: currentLocationGuidance),
        ],
        if (_currentLocationError != null) ...[
          const SizedBox(height: 12),
          _ErrorText(text: _currentLocationError!),
        ],

        // ── Section 9: Action buttons ──
        const SizedBox(height: 20),
        Row(
          children: [
            _CircleActionButton(
              icon: Icons.refresh_rounded,
              color: AppColors.teal,
              isLoading: _isRefreshingTracking,
              onPressed: _isRefreshingTracking ? null : _refreshTrackingData,
            ),
            const SizedBox(width: 10),
            _CircleActionButton(
              icon: Icons.my_location_rounded,
              color: AppColors.info,
              isLoading: _isLoadingCurrentLocation,
              onPressed: _isLoadingCurrentLocation
                  ? null
                  : _loadCurrentLocation,
            ),
            const SizedBox(width: 14),
            Expanded(child: _buildChangeDeliveryLocationButton(copy, order)),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Back button
// ─────────────────────────────────────────────────────────
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 40,
        width: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.stroke),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A091D33),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          isRtl ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
          color: AppColors.navy,
          size: 20,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Map pin marker
// ─────────────────────────────────────────────────────────
class _MapPin extends StatelessWidget {
  const _MapPin({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.26),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(child: Icon(icon, color: Colors.white, size: 24)),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Order status timeline (horizontal stepper)
// ─────────────────────────────────────────────────────────
class _OrderStatusTimeline extends StatelessWidget {
  const _OrderStatusTimeline({required this.status, required this.copy});

  final OrderStatus status;
  final AppCopy copy;

  static const _steps = [
    OrderStatus.pendingReview,
    OrderStatus.accepted,
    OrderStatus.preparing,
    OrderStatus.onTheWay,
    OrderStatus.delivered,
  ];

  int get _activeIndex {
    if (status == OrderStatus.cancelled) return -1;
    if (status == OrderStatus.searchingDriver ||
        status == OrderStatus.driverNotified ||
        status == OrderStatus.noDriverFound) {
      return 0;
    }
    return _steps.indexOf(status);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCancelled = status == OrderStatus.cancelled;
    final activeIdx = _activeIndex;

    if (isCancelled) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.errorSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cancel_rounded, color: AppColors.error, size: 20),
            const SizedBox(width: 8),
            Text(
              copy.t('status.cancelled'),
              style: theme.textTheme.titleSmall?.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: List.generate(_steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final stepBefore = i ~/ 2;
          final isCompleted = stepBefore < activeIdx;
          return Expanded(
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: isCompleted ? AppColors.teal : AppColors.stroke,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }

        final stepIdx = i ~/ 2;
        final isActive = stepIdx == activeIdx;
        final isCompleted = stepIdx < activeIdx;
        final step = _steps[stepIdx];

        return _TimelineNode(
          isActive: isActive,
          isCompleted: isCompleted,
          label: copy.t(step.labelKey()),
          theme: theme,
        );
      }),
    );
  }
}

class _OrderProgressBanner extends StatefulWidget {
  const _OrderProgressBanner({required this.status, required this.copy});

  final OrderStatus status;
  final AppCopy copy;

  @override
  State<_OrderProgressBanner> createState() => _OrderProgressBannerState();
}

class _OrderProgressBannerState extends State<_OrderProgressBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _sweepAnimation;

  OrderStatus get status => widget.status;
  AppCopy get copy => widget.copy;

  bool get _shouldAnimateSearch =>
      status == OrderStatus.searchingDriver ||
      status == OrderStatus.driverNotified ||
      status == OrderStatus.noDriverFound;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseAnimation = Tween<double>(
      begin: 0.96,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _sweepAnimation = Tween<double>(
      begin: -0.18,
      end: 0.18,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (_shouldAnimateSearch) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _OrderProgressBanner oldWidget) {
    super.didUpdateWidget(oldWidget);

    final shouldAnimateNow =
        status == OrderStatus.searchingDriver ||
        status == OrderStatus.driverNotified ||
        status == OrderStatus.noDriverFound;
    final shouldAnimateBefore =
        oldWidget.status == OrderStatus.searchingDriver ||
        oldWidget.status == OrderStatus.driverNotified ||
        oldWidget.status == OrderStatus.noDriverFound;

    if (shouldAnimateNow && !shouldAnimateBefore) {
      _controller.repeat(reverse: true);
    } else if (!shouldAnimateNow && shouldAnimateBefore) {
      _controller
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData _iconForStatus() {
    switch (status) {
      case OrderStatus.pendingReview:
        return Icons.inventory_2_rounded;
      case OrderStatus.searchingDriver:
        return Icons.radar_rounded;
      case OrderStatus.driverNotified:
        return Icons.notifications_active_rounded;
      case OrderStatus.noDriverFound:
        return Icons.person_search_rounded;
      case OrderStatus.accepted:
        return Icons.verified_rounded;
      case OrderStatus.preparing:
        return Icons.local_shipping_rounded;
      case OrderStatus.onTheWay:
        return Icons.route_rounded;
      case OrderStatus.delivered:
        return Icons.check_circle_rounded;
      case OrderStatus.cancelled:
        return Icons.cancel_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = status.tone();
    final softTone = status.softTone();
    final icon = _iconForStatus();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: softTone.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final scale = _shouldAnimateSearch ? _pulseAnimation.value : 1.0;
              final rotation = _shouldAnimateSearch
                  ? _sweepAnimation.value
                  : 0.0;

              return Transform.rotate(
                angle: rotation,
                child: Transform.scale(scale: scale, child: child),
              );
            },
            child: Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                boxShadow: _shouldAnimateSearch
                    ? [
                        BoxShadow(
                          color: tone.withValues(alpha: 0.14),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon, color: tone, size: 20),
                  if (_shouldAnimateSearch)
                    Positioned(
                      top: 9,
                      right: 8,
                      child: Container(
                        height: 6,
                        width: 6,
                        decoration: BoxDecoration(
                          color: tone,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.t(status.labelKey()),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: tone,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  copy.t(status.progressMessageKey()),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.navy,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({
    required this.isActive,
    required this.isCompleted,
    required this.label,
    required this.theme,
  });

  final bool isActive;
  final bool isCompleted;
  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? AppColors.brand
        : isCompleted
        ? AppColors.teal
        : AppColors.stroke;

    return Tooltip(
      message: label,
      child: Container(
        height: isActive ? 18 : 12,
        width: isActive ? 18 : 12,
        decoration: BoxDecoration(
          color: isActive || isCompleted ? color : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: isActive ? 3 : 2),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: isCompleted
            ? const Center(
                child: Icon(Icons.check_rounded, size: 8, color: Colors.white),
              )
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Metric card (ETA / Distance)
// ─────────────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.value,
    required this.unit,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: iconBgColor.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: iconColor.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Route hint banner
// ─────────────────────────────────────────────────────────
class _RouteHintBanner extends StatelessWidget {
  const _RouteHintBanner({
    required this.hasDriver,
    required this.hasRealRoute,
    required this.copy,
  });

  final bool hasDriver;
  final bool hasRealRoute;
  final AppCopy copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = hasDriver ? AppColors.brand : AppColors.warning;
    final bgColor = hasDriver ? AppColors.brandSoft : AppColors.warningSoft;
    final icon = hasDriver
        ? (hasRealRoute ? Icons.alt_route_rounded : Icons.route_rounded)
        : Icons.hourglass_top_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasDriver
                  ? hasRealRoute
                        ? copy.t('tracking.realRouteHint')
                        : copy.t('tracking.routeHint')
                  : copy.t('tracking.driverPending'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: hasDriver ? AppColors.brandDeep : AppColors.warning,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Live tracking badge
// ─────────────────────────────────────────────────────────
class _LiveTrackingBadge extends StatelessWidget {
  const _LiveTrackingBadge({
    required this.copy,
    required this.hasDriverLocation,
    required this.lastMovementAt,
    required this.trailLength,
    required this.hasDriverMovementTrail,
    required this.formatUpdatedAt,
  });

  final AppCopy copy;
  final bool hasDriverLocation;
  final DateTime? lastMovementAt;
  final int trailLength;
  final bool hasDriverMovementTrail;
  final String Function(DateTime) formatUpdatedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tealSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 32,
                width: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.radar_rounded,
                  color: AppColors.teal,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.t('tracking.liveTrackingActive'),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasDriverLocation
                          ? copy.t('tracking.autoRefreshHint')
                          : copy.t('tracking.liveTrackingStandby'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (lastMovementAt != null || hasDriverMovementTrail) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (lastMovementAt != null)
                  _TrackingMetaPill(
                    icon: Icons.schedule_rounded,
                    label: formatUpdatedAt(lastMovementAt!),
                  ),
                if (hasDriverMovementTrail)
                  _TrackingMetaPill(
                    icon: Icons.timeline_rounded,
                    label: '${copy.t('tracking.map')}: $trailLength',
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Driver info card
// ─────────────────────────────────────────────────────────
class _DriverInfoCard extends StatelessWidget {
  const _DriverInfoCard({required this.copy, required this.order});

  final AppCopy copy;
  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final driver = order.driver;
    if (driver == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.12)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08091D33),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Driver avatar
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.info, Color(0xFF4F8FFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          // Driver details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver.name.isNotEmpty
                      ? driver.name
                      : copy.t('tracking.driver'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (driver.vehicleLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.local_shipping_rounded,
                        size: 14,
                        color: AppColors.muted.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          driver.vehicleLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (driver.phone.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.phone_rounded,
                        size: 14,
                        color: AppColors.muted.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        driver.phone,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // ETA badge
          if (driver.etaMinutes > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(
                    '${driver.etaMinutes}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.brand,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    copy.isRtl ? 'دقيقة' : 'min',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.brandDeep,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Pending driver placeholder
// ─────────────────────────────────────────────────────────
class _PendingDriverCard extends StatelessWidget {
  const _PendingDriverCard({required this.copy});

  final AppCopy copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.stroke),
            ),
            child: const Icon(
              Icons.person_search_rounded,
              color: AppColors.muted,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              copy.t('tracking.driverPending'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Delivery address card
// ─────────────────────────────────────────────────────────
class _DeliveryAddressCard extends StatelessWidget {
  const _DeliveryAddressCard({
    required this.copy,
    required this.addressText,
    required this.isUsingCurrentLocation,
  });

  final AppCopy copy;
  final String addressText;
  final bool isUsingCurrentLocation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUsingCurrentLocation
            ? AppColors.tealSoft.withValues(alpha: 0.5)
            : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUsingCurrentLocation
              ? AppColors.teal.withValues(alpha: 0.15)
              : AppColors.stroke,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: isUsingCurrentLocation ? AppColors.tealSoft : Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: isUsingCurrentLocation
                    ? AppColors.teal.withValues(alpha: 0.2)
                    : AppColors.stroke,
              ),
            ),
            child: Icon(
              isUsingCurrentLocation
                  ? Icons.my_location_rounded
                  : Icons.location_on_rounded,
              color: isUsingCurrentLocation ? AppColors.teal : AppColors.brand,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.t('tracking.deliveryAddress'),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  addressText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                    height: 1.6,
                  ),
                ),
                if (isUsingCurrentLocation) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      copy.isRtl ? 'موقعك الحالي' : 'Current location',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.teal,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Warning banner
// ─────────────────────────────────────────────────────────
class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.warning,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w600,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Error text
// ─────────────────────────────────────────────────────────
class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: AppColors.error,
          size: 16,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Circular action button
// ─────────────────────────────────────────────────────────
class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.icon,
    required this.color,
    this.isLoading = false,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 50,
        width: 50,
        decoration: BoxDecoration(
          color: onPressed == null
              ? AppColors.surfaceMuted
              : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: onPressed == null
                ? AppColors.stroke
                : color.withValues(alpha: 0.2),
          ),
        ),
        child: Center(
          child: isLoading
              ? SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              : Icon(
                  icon,
                  color: onPressed == null ? AppColors.muted : color,
                  size: 22,
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Small meta pill
// ─────────────────────────────────────────────────────────
class _TrackingMetaPill extends StatelessWidget {
  const _TrackingMetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.teal),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
