import 'package:driver_app/core/localization/app_strings.dart';
import 'package:driver_app/core/services/location_service.dart';
import 'package:driver_app/core/services/map_launcher_service.dart';
import 'package:driver_app/core/theme/app_theme.dart';
import 'package:driver_app/core/utils/formatters.dart';
import 'package:driver_app/features/orders/presentation/order_error_resolver.dart';
import 'package:driver_app/features/orders/presentation/orders_controller.dart';
import 'package:driver_app/features/tracking/data/driver_route_service.dart';
import 'package:driver_app/features/tracking/presentation/tracking_controller.dart';
import 'package:driver_app/shared/widgets/app_async_view.dart';
import 'package:driver_app/shared/widgets/app_chip.dart';
import 'package:driver_app/shared/widgets/status_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class ActiveDeliveryScreen extends ConsumerStatefulWidget {
  const ActiveDeliveryScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<ActiveDeliveryScreen> createState() =>
      _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends ConsumerState<ActiveDeliveryScreen>
    with WidgetsBindingObserver {
  static const _fallbackLocation = LatLng(23.5880, 58.3829);
  static const _fallbackZoom = 10.5;

  final _mapController = MapController();
  bool _isMapReady = false;
  String? _lastCameraSignature;
  late final TrackingController _trackingController;

  @override
  void initState() {
    super.initState();
    _trackingController = ref.read(trackingControllerProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      if (!mounted) {
        return;
      }
      await _trackingController.startSharing(widget.orderId);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || state != AppLifecycleState.resumed) {
      return;
    }

    final trackingState = ref.read(trackingControllerProvider);
    if (!trackingState.isSharing && trackingState.errorMessage != null) {
      _trackingController.startSharing(widget.orderId);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _trackingController.stopSharing();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _openNavigation({
    required String address,
    String? label,
    double? latitude,
    double? longitude,
    double? originLatitude,
    double? originLongitude,
  }) async {
    final result = await ref
        .read(mapLauncherServiceProvider)
        .openDrivingNavigation(
          address: address,
          label: label,
          destinationLatitude: latitude,
          destinationLongitude: longitude,
          originLatitude: originLatitude,
          originLongitude: originLongitude,
        );

    if (!mounted || result.isSuccess) {
      return;
    }

    final strings = context.strings;
    final message = result.reason == MapLaunchFailureReason.destinationMissing
        ? (strings.isArabic
              ? 'موقع العميل غير متوفر حالياً، لذلك لا يمكن بدء الملاحة.'
              : 'Customer destination is not available yet, so navigation cannot start.')
        : (strings.isArabic
              ? 'تعذر فتح تطبيق ملاحة مدعوم على هذا الجهاز.'
              : 'Could not open a supported navigation app on this device.');

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _callCustomer(String phone) async {
    await launchUrl(
      Uri.parse('tel:$phone'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _handleTrackingPermissionAction(String errorCode) async {
    final locationService = ref.read(locationServiceProvider);

    if (errorCode == TrackingController.locationServiceDisabledCode) {
      await locationService.openLocationSettings();
      return;
    }

    if (errorCode == TrackingController.locationPermissionDeniedForeverCode) {
      await locationService.openAppSettings();
      return;
    }

    await _trackingController.startSharing(widget.orderId);
  }

  String _trackingPermissionMessage(BuildContext context, String errorCode) {
    final strings = context.strings;
    if (errorCode == TrackingController.locationServiceDisabledCode) {
      return strings.isArabic
          ? 'خدمة الموقع متوقفة على الجهاز. فعّل GPS ثم ارجع لمتابعة التتبع الحي.'
          : 'Location services are turned off on this device. Enable GPS and return to continue live tracking.';
    }

    if (errorCode == TrackingController.locationPermissionDeniedForeverCode) {
      return strings.isArabic
          ? 'تم رفض إذن الموقع بشكل دائم. افتح إعدادات التطبيق واسمح بالموقع لتشغيل التتبع الحي.'
          : 'Location permission was denied permanently. Open app settings and allow location to enable live tracking.';
    }

    return strings.locationPermissionRequired;
  }

  String _trackingPermissionActionLabel(
    BuildContext context,
    String errorCode,
  ) {
    final strings = context.strings;
    if (errorCode == TrackingController.locationServiceDisabledCode) {
      return strings.isArabic ? 'فتح الموقع' : 'Open location';
    }
    if (errorCode == TrackingController.locationPermissionDeniedForeverCode) {
      return strings.isArabic ? 'فتح الإعدادات' : 'Open settings';
    }
    return strings.retry;
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

  LatLng? _customerLocation(dynamic order) =>
      _asLatLng(order.customerLatitude, order.customerLongitude);

  LatLng? _driverLocation(dynamic order, TrackingState trackingState) {
    final live = trackingState.currentPosition;
    if (live != null) {
      return LatLng(live.latitude, live.longitude);
    }
    return _asLatLng(order.driverLatitude, order.driverLongitude);
  }

  double? _routeValue(double? value) =>
      value == null ? null : double.parse(value.toStringAsFixed(6));

  void _scheduleCameraFit({
    required LatLng? customerLatLng,
    required LatLng? driverLatLng,
    bool force = false,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isMapReady) {
        return;
      }

      final signature = [
        widget.orderId,
        customerLatLng?.latitude.toStringAsFixed(6) ?? 'na',
        customerLatLng?.longitude.toStringAsFixed(6) ?? 'na',
        driverLatLng?.latitude.toStringAsFixed(6) ?? 'na',
        driverLatLng?.longitude.toStringAsFixed(6) ?? 'na',
      ].join('|');

      if (!force && _lastCameraSignature == signature) {
        return;
      }

      _lastCameraSignature = signature;
      final points = <LatLng?>[
        customerLatLng,
        driverLatLng,
      ].whereType<LatLng>().toList(growable: false);

      if (points.isEmpty) {
        _mapController.move(_fallbackLocation, _fallbackZoom);
        return;
      }

      if (points.length == 1) {
        _mapController.move(points.first, 15.5);
        return;
      }

      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(68),
          maxZoom: 16.2,
        ),
      );
    });
  }

  List<LatLng> _routePoints(
    dynamic order,
    dynamic route,
    LatLng? from,
    LatLng? to,
  ) {
    final apiPoints =
        route?.points
            .map<LatLng>((point) => LatLng(point.latitude, point.longitude))
            .toList(growable: false) ??
        const <LatLng>[];
    if (apiPoints.length > 1) {
      return apiPoints;
    }

    final backendPoints = order.routePoints
        .map<LatLng>((point) => LatLng(point.latitude, point.longitude))
        .toList(growable: false);
    if (backendPoints.length > 1) {
      return backendPoints;
    }

    if (from != null && to != null) {
      return [from, to];
    }

    return const <LatLng>[];
  }

  String _formatTimestamp(DateTime value) {
    final minute = value.minute.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(orderDetailsProvider(widget.orderId));
    final trackingState = ref.watch(trackingControllerProvider);
    final strings = context.strings;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.deliveryNumber(widget.orderId)),
        backgroundColor: Colors.white,
      ),
      backgroundColor: AppColors.background,
      body: orderState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, _) {
          final isUnassigned = isOrderNotAvailableForDriverError(error);
          return AppAsyncView(
            isLoading: false,
            errorMessage: resolveDriverOrderErrorMessage(error, strings),
            onRetry: () {
              ref.read(ordersControllerProvider.notifier).refreshAll(silent: true);
              if (isUnassigned) {
                Navigator.of(context).maybePop();
                return;
              }
              ref.invalidate(orderDetailsProvider(widget.orderId));
            },
            child: const SizedBox.shrink(),
          );
        },
        data: (order) {
          final customerLatLng = _customerLocation(order);
          final driverLatLng = _driverLocation(order, trackingState);
          final routeAsync = ref.watch(
            driverRouteProvider((
              fromLat: _routeValue(driverLatLng?.latitude),
              fromLng: _routeValue(driverLatLng?.longitude),
              toLat: _routeValue(customerLatLng?.latitude),
              toLng: _routeValue(customerLatLng?.longitude),
            )),
          );
          final route = routeAsync.asData?.value;
          final routePoints = _routePoints(
            order,
            route,
            driverLatLng,
            customerLatLng,
          );
          final fallbackDistance =
              customerLatLng != null && driverLatLng != null
              ? Geolocator.distanceBetween(
                  driverLatLng.latitude,
                  driverLatLng.longitude,
                  customerLatLng.latitude,
                  customerLatLng.longitude,
                )
              : null;
          final distanceMeters =
              route?.distanceMeters?.toDouble() ??
              order.routeDistanceMeters?.toDouble() ??
              fallbackDistance;
          final durationSeconds =
              route?.durationSeconds ?? order.routeDurationSeconds;
          final etaMinutes =
              route?.etaMinutes ??
              order.etaMinutes ??
              (durationSeconds != null
                  ? (durationSeconds / 60).ceil()
                  : distanceMeters != null
                  ? (distanceMeters / 450).ceil().clamp(3, 120)
                  : null);
          final hasRealRoute =
              route?.hasPath == true || order.routePoints.length > 1;
          final updatedAt =
              order.updatedAt ??
              order.acceptedAt ??
              order.createdAt ??
              DateTime.now();

          _scheduleCameraFit(
            customerLatLng: customerLatLng,
            driverLatLng: driverLatLng,
          );

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _DeliveryMapSection(
                customerLatLng: customerLatLng,
                driverLatLng: driverLatLng,
                mapController: _mapController,
                fallbackLocation: _fallbackLocation,
                fallbackZoom: _fallbackZoom,
                routePoints: routePoints,
                isRouteLoading: routeAsync.isLoading,
                onMapReady: () => _isMapReady = true,
                emptyText: strings.customerCoordinatesUnavailable,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _DeliverySummaryCard(
                  order: order,
                  strings: strings,
                  hasRealRoute: hasRealRoute,
                  distanceMeters: distanceMeters,
                  etaMinutes: etaMinutes,
                  driverLatLng: driverLatLng,
                  customerLatLng: customerLatLng,
                  updatedAtLabel: _formatTimestamp(updatedAt),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _callCustomer(order.customerPhone),
                        icon: const Icon(Icons.call_rounded, size: 18),
                        label: Text(strings.callCustomer),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.info,
                          side: const BorderSide(
                            color: AppColors.info,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _openNavigation(
                          address: order.addressFull,
                          label: order.customerName,
                          latitude: order.customerLatitude,
                          longitude: order.customerLongitude,
                          originLatitude: driverLatLng?.latitude,
                          originLongitude: driverLatLng?.longitude,
                        ),
                        icon: const Icon(Icons.navigation_rounded, size: 18),
                        label: Text(strings.navigate),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _StageActions(
                  currentStage: order.driverStage,
                  onAdvance: (stage) async {
                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await ref
                          .read(ordersControllerProvider.notifier)
                          .updateStage(orderId: order.id, stage: stage);
                      if (!context.mounted) {
                        return;
                      }
                      if (stage == 'delivered') {
                        await _trackingController.stopSharing();
                        navigator.pop();
                      }
                    } catch (error) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(error.toString())),
                      );
                    }
                  },
                ),
              ),
              if (trackingState.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: _TrackingErrorCard(
                    message: trackingState.errorMessage!,
                    resolvedMessage:
                        trackingState.errorMessage ==
                                TrackingController
                                    .locationPermissionRequiredCode ||
                            trackingState.errorMessage ==
                                TrackingController
                                    .locationServiceDisabledCode ||
                            trackingState.errorMessage ==
                                TrackingController
                                    .locationPermissionDeniedForeverCode
                        ? _trackingPermissionMessage(
                            context,
                            trackingState.errorMessage!,
                          )
                        : trackingState.errorMessage!,
                    actionLabel: _trackingPermissionActionLabel(
                      context,
                      trackingState.errorMessage!,
                    ),
                    onPressed: () => _handleTrackingPermissionAction(
                      trackingState.errorMessage!,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _DeliveryMapSection extends StatelessWidget {
  const _DeliveryMapSection({
    required this.customerLatLng,
    required this.driverLatLng,
    required this.mapController,
    required this.fallbackLocation,
    required this.fallbackZoom,
    required this.routePoints,
    required this.isRouteLoading,
    required this.onMapReady,
    required this.emptyText,
  });

  final LatLng? customerLatLng;
  final LatLng? driverLatLng;
  final MapController mapController;
  final LatLng fallbackLocation;
  final double fallbackZoom;
  final List<LatLng> routePoints;
  final bool isRouteLoading;
  final VoidCallback onMapReady;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (customerLatLng == null && driverLatLng == null) {
      return Container(
        height: 160,
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.map_outlined,
              size: 36,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 10),
            Text(
              emptyText,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: SizedBox(
        height: 280,
        child: Stack(
          children: [
            FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter:
                    customerLatLng ?? driverLatLng ?? fallbackLocation,
                initialZoom: customerLatLng == null && driverLatLng == null
                    ? fallbackZoom
                    : 14.5,
                onMapReady: onMapReady,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.omangas.driver_app',
                ),
                if (routePoints.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routePoints,
                        color: AppColors.primary,
                        strokeWidth: 5,
                      ),
                    ],
                  ),
                if (driverLatLng != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: driverLatLng!,
                        radius: 34,
                        useRadiusInMeter: true,
                        color: AppColors.warning.withValues(alpha: 0.14),
                        borderColor: AppColors.warning.withValues(alpha: 0.34),
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (customerLatLng != null)
                      Marker(
                        point: customerLatLng!,
                        width: 52,
                        height: 52,
                        child: const _MapPin(
                          icon: Icons.home_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                    if (driverLatLng != null)
                      Marker(
                        point: driverLatLng!,
                        width: 52,
                        height: 52,
                        child: const _MapPin(
                          icon: Icons.local_shipping_rounded,
                          color: AppColors.warning,
                        ),
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
            if (isRouteLoading)
              Positioned(
                top: 16,
                right: 16,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
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

class _DeliverySummaryCard extends StatelessWidget {
  const _DeliverySummaryCard({
    required this.order,
    required this.strings,
    required this.hasRealRoute,
    required this.distanceMeters,
    required this.etaMinutes,
    required this.driverLatLng,
    required this.customerLatLng,
    required this.updatedAtLabel,
  });

  final dynamic order;
  final AppStrings strings;
  final bool hasRealRoute;
  final double? distanceMeters;
  final int? etaMinutes;
  final LatLng? driverLatLng;
  final LatLng? customerLatLng;
  final String updatedAtLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Center(
                  child: Text(
                    order.customerName.isNotEmpty
                        ? order.customerName[0].toUpperCase()
                        : '?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customerName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            order.addressFull,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              StatusChip(label: order.driverStage),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 16),
          StatusTimeline(currentStage: order.driverStage),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: hasRealRoute
                  ? AppColors.primarySoft
                  : AppColors.warningSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasRealRoute
                    ? AppColors.primary.withValues(alpha: 0.18)
                    : AppColors.warning.withValues(alpha: 0.24),
              ),
            ),
            child: Text(
              hasRealRoute
                  ? (strings.isArabic
                        ? 'يتم عرض المسار الفعلي بين موقعك وموقع العميل.'
                        : 'Showing the routed path between your location and the customer.')
                  : (strings.isArabic
                        ? 'تعذر جلب مسار تفصيلي حالياً، لذلك يتم عرض خط مباشر مؤقت.'
                        : 'A detailed route is unavailable right now, so a straight fallback line is shown.'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: hasRealRoute ? AppColors.primary : AppColors.warning,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetaBadge(
                  icon: Icons.straighten_rounded,
                  label: strings.distance,
                  value: distanceMeters == null
                      ? strings.unknown
                      : '${(distanceMeters! / 1000).toStringAsFixed(1)} ${strings.kilometerShort}',
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetaBadge(
                  icon: Icons.timer_outlined,
                  label: strings.eta,
                  value: etaMinutes == null
                      ? strings.unknown
                      : '$etaMinutes ${strings.minuteShort}',
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetaBadge(
                  icon: Icons.payments_outlined,
                  label: strings.total,
                  value: Formatters.currency(
                    order.totalAmount,
                    localeCode: strings.localeCode,
                  ),
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (customerLatLng != null)
                _TrackingMetaPill(
                  icon: Icons.place_outlined,
                  label:
                      '${strings.isArabic ? 'العميل' : 'Customer'}: ${customerLatLng!.latitude.toStringAsFixed(5)}, ${customerLatLng!.longitude.toStringAsFixed(5)}',
                ),
              if (driverLatLng != null)
                _TrackingMetaPill(
                  icon: Icons.my_location_rounded,
                  label:
                      '${strings.driverLabel}: ${driverLatLng!.latitude.toStringAsFixed(5)}, ${driverLatLng!.longitude.toStringAsFixed(5)}',
                ),
              _TrackingMetaPill(
                icon: Icons.schedule_rounded,
                label:
                    '${strings.isArabic ? 'آخر تحديث' : 'Updated'}: $updatedAtLabel',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrackingErrorCard extends StatelessWidget {
  const _TrackingErrorCard({
    required this.message,
    required this.resolvedMessage,
    required this.actionLabel,
    required this.onPressed,
  });

  final String message;
  final String resolvedMessage;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_off_rounded,
            size: 18,
            color: AppColors.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              resolvedMessage,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.error),
            ),
          ),
          const SizedBox(width: 10),
          TextButton(onPressed: onPressed, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

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
            color: color.withValues(alpha: 0.24),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(child: Icon(icon, color: Colors.white, size: 24)),
    );
  }
}

class _TrackingMetaPill extends StatelessWidget {
  const _TrackingMetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 5),
          Text(
            value,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _StageActions extends StatelessWidget {
  const _StageActions({required this.currentStage, required this.onAdvance});

  final String currentStage;
  final Future<void> Function(String stage) onAdvance;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final actions = <MapEntry<String, String>>[];

    if (currentStage == 'accepted') {
      actions.add(const MapEntry('on_the_way', 'start_trip'));
    } else if (currentStage == 'on_the_way') {
      actions.add(const MapEntry('arrived', 'mark_arrived'));
    } else if (currentStage == 'arrived') {
      actions.add(const MapEntry('delivered', 'complete_delivery'));
    }

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDelivered = actions.any((entry) => entry.key == 'delivered');

    return Column(
      children: actions.map((action) {
        final label = switch (action.value) {
          'start_trip' => strings.startTrip,
          'mark_arrived' => strings.markArrived,
          'complete_delivery' => strings.completeDelivery,
          _ => action.value,
        };
        final icon = switch (action.value) {
          'start_trip' => Icons.local_shipping_rounded,
          'mark_arrived' => Icons.location_on_rounded,
          'complete_delivery' => Icons.check_circle_rounded,
          _ => Icons.arrow_forward_rounded,
        };

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FilledButton.icon(
            onPressed: () => onAdvance(action.key),
            icon: Icon(icon, size: 20),
            label: Text(label),
            style: FilledButton.styleFrom(
              backgroundColor: isDelivered
                  ? AppColors.success
                  : AppColors.primary,
            ),
          ),
        );
      }).toList(),
    );
  }
}
