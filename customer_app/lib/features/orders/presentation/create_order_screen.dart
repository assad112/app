import 'package:customer_app/core/constants/app_colors.dart';
import 'package:customer_app/core/device/device_location_service.dart';
import 'package:customer_app/shared/localization/app_copy.dart';
import 'package:customer_app/shared/models/address_model.dart';
import 'package:customer_app/shared/models/order_status.dart';
import 'package:customer_app/shared/models/payment_method.dart';
import 'package:customer_app/shared/state/customer_app_controller.dart';
import 'package:customer_app/shared/state/customer_app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  static const _now = 'delivery_now';
  static const _scheduled = 'delivery_scheduled';

  String? _selectedAddressId;
  // Multi-item cart: productId → quantity
  final Map<String, int> _cart = {};
  String _deliveryWindow = _now;
  TimeOfDay? _scheduledTime;
  PaymentMethod _paymentMethod = PaymentMethod.cashOnDelivery;
  double? _selectedLatitude;
  double? _selectedLongitude;
  bool _didPrimeCurrentLocation = false;

  int _cartQty(String productId) => _cart[productId] ?? 0;
  int get _totalItems => _cart.values.fold(0, (s, q) => s + q);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(customerAppControllerProvider);
      final address = _resolveSelectedAddress(s);
      if (!mounted) return;
      setState(() {
        _selectedAddressId = address?.id;
        _selectedLatitude = address?.latitude;
        _selectedLongitude = address?.longitude;
      });
      _primeCurrentLocation();
    });
  }

  AddressModel? _resolveSelectedAddress(CustomerAppState state) {
    for (final address in state.addresses) {
      if (address.id == _selectedAddressId) {
        return address;
      }
    }

    for (final address in state.addresses) {
      if (address.isCurrentLocation) {
        return address;
      }
    }

    return state.defaultAddress ??
        (state.addresses.isNotEmpty ? state.addresses.first : null);
  }

  bool _hasUsableCoordinates(double? latitude, double? longitude) {
    return latitude != null &&
        longitude != null &&
        latitude.isFinite &&
        longitude.isFinite;
  }

  Future<void> _primeCurrentLocation() async {
    if (_didPrimeCurrentLocation) {
      return;
    }

    _didPrimeCurrentLocation = true;
    final result = await ref
        .read(customerAppControllerProvider.notifier)
        .refreshCurrentLocation();

    if (!mounted || !result.success || result.address == null) {
      return;
    }

    setState(() {
      _selectedAddressId = result.address!.id;
      _selectedLatitude = result.address!.latitude;
      _selectedLongitude = result.address!.longitude;
    });
  }

  String _formatCurrency(double value, AppCopy copy) {
    final locale = copy.isRtl ? 'ar_OM' : 'en_OM';
    return NumberFormat.currency(
      locale: locale,
      symbol: copy.t('common.omr'),
      decimalDigits: 3,
    ).format(value);
  }

  String _deliveryWindowLabel(AppCopy copy) {
    if (_deliveryWindow == _scheduled && _scheduledTime != null) {
      final h = _scheduledTime!.hour.toString().padLeft(2, '0');
      final m = _scheduledTime!.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    return copy.isRtl ? 'التوصيل الآن' : 'Deliver now';
  }

  Future<void> _pickTime(AppCopy copy) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ?? TimeOfDay.now(),
      helpText: copy.isRtl ? 'اختر وقت التوصيل' : 'Select delivery time',
    );
    if (picked != null) {
      setState(() {
        _scheduledTime = picked;
        _deliveryWindow = _scheduled;
      });
    }
  }

  String _locationFailureMessage(DeviceLocationFailure? failure, AppCopy copy) {
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
      case null:
        return copy.t('location.unavailable');
    }
  }

  Future<void> _syncGps(AppCopy copy) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final result = await ref
        .read(customerAppControllerProvider.notifier)
        .refreshCurrentLocation();
    if (!mounted) return;
    if (result.success && result.address != null) {
      setState(() {
        _selectedAddressId = result.address!.id;
        _selectedLatitude = result.address!.latitude;
        _selectedLongitude = result.address!.longitude;
      });
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? copy.t('location.updatedSuccess')
              : _locationFailureMessage(result.failure, copy),
        ),
      ),
    );
  }

  Future<void> _submit(AppCopy copy) async {
    var state = ref.read(customerAppControllerProvider);
    if (!state.runtimeSettings.orderIntakeEnabled || _cart.isEmpty) return;

    final controller = ref.read(customerAppControllerProvider.notifier);

    var savedAddress = _resolveSelectedAddress(state);
    final hasSelectedCoordinates = _hasUsableCoordinates(
      _selectedLatitude ?? savedAddress?.latitude,
      _selectedLongitude ?? savedAddress?.longitude,
    );

    if (savedAddress?.isCurrentLocation != true || !hasSelectedCoordinates) {
      final locationResult = await controller.refreshCurrentLocation();
      if (locationResult.success && locationResult.address != null) {
        savedAddress = locationResult.address;
        state = ref.read(customerAppControllerProvider);
        _selectedAddressId = locationResult.address!.id;
        _selectedLatitude = locationResult.address!.latitude;
        _selectedLongitude = locationResult.address!.longitude;
        if (mounted) setState(() {});
      }
    }

    if (!mounted) return;

    final latitude = _selectedLatitude ?? savedAddress?.latitude;
    final longitude = _selectedLongitude ?? savedAddress?.longitude;

    if (savedAddress == null || !_hasUsableCoordinates(latitude, longitude)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(copy.t('order.locationRequired'))),
        );
      return;
    }

    final address = AddressModel(
      id: savedAddress.id,
      label: copy.isRtl ? 'العنوان الحالي' : 'Current Address',
      governorate: savedAddress.governorate,
      wilayat: savedAddress.wilayat,
      area: savedAddress.area,
      street: savedAddress.street,
      houseNumber: savedAddress.houseNumber,
      landmark: savedAddress.landmark,
      latitude: latitude!,
      longitude: longitude!,
      isDefault: savedAddress.id == state.defaultAddress?.id,
    );

    final cartEntries = _cart.entries.where((e) => e.value > 0).toList();
    final bundleItems = cartEntries
        .map((entry) {
          final product = state.products.firstWhere(
            (p) => p.id == entry.key,
            orElse: () => state.products.first,
          );

          return BundledOrderItem(product: product, quantity: entry.value);
        })
        .toList(growable: false);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(copy.t('order.creatingInProgress'))),
      );

    final created = await controller.createBundledOrder(
      items: bundleItems,
      address: address,
      paymentMethod: _paymentMethod,
      preferredDeliveryWindow: _deliveryWindowLabel(copy),
    );

    if (!mounted) return;

    if (created == null) {
      final errorMessage = ref
          .read(customerAppControllerProvider)
          .lastOrderSubmissionErrorMessage;
      final fallback = copy.t('order.serverUnavailable');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(errorMessage ?? fallback)));
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(copy.t(created.orderStatus.progressMessageKey())),
        ),
      );
    context.go('/tracking/${created.orderId}');
  }

  static String _productIconAsset(String productId) {
    switch (productId) {
      case 'gas-001':
        return 'assets/icons/gas_11.svg';
      case 'gas-002':
        return 'assets/icons/gas_22.svg';
      case 'gas-003':
        return 'assets/icons/gas_44.svg';
      default:
        return 'assets/icons/gas_11.svg';
    }
  }

  static String _formatProductSize(String sizeLabel) {
    final parts = sizeLabel.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first} ${parts.last.toUpperCase()}';
    }
    return sizeLabel.toUpperCase();
  }

  static Color _productColor(int i) {
    switch (i % 3) {
      case 1:
        return AppColors.teal;
      case 2:
        return AppColors.info;
      default:
        return AppColors.brand;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(customerAppControllerProvider);
    final copy = AppCopy(appState.language);
    final isRtl = copy.isRtl;

    final selectedAddress = _resolveSelectedAddress(appState);

    // Multi-item totals
    double subtotal = 0;
    double deliveryFee = appState.runtimeSettings.defaultDeliveryFee;
    for (final entry in _cart.entries) {
      if (entry.value <= 0) continue;
      final product = appState.products.firstWhere(
        (p) => p.id == entry.key,
        orElse: () => appState.products.first,
      );
      subtotal += product.priceOmr * entry.value;
      if (product.deliveryFeeOmr > deliveryFee) {
        deliveryFee = product.deliveryFeeOmr;
      }
    }
    final total = subtotal + deliveryFee;

    final canSubmit =
        _totalItems > 0 && appState.runtimeSettings.orderIntakeEnabled;

    final disabledMessage = !appState.runtimeSettings.orderIntakeEnabled
        ? (appState.runtimeSettings.systemMessage.isNotEmpty
              ? appState.runtimeSettings.systemMessage
              : (isRtl
                    ? 'استقبال الطلبات متوقف حاليًا'
                    : 'Order intake is currently disabled'))
        : (_totalItems == 0
              ? (isRtl
                    ? 'أضف أسطوانة واحدة على الأقل'
                    : 'Add at least one cylinder')
              : null);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          copy.t('order.createTitle'),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
        ),
        leading: IconButton(
          icon: Icon(
            isRtl
                ? Icons.arrow_forward_ios_rounded
                : Icons.arrow_back_ios_rounded,
            size: 20,
            color: const Color(0xFF1A1A2E),
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SmartBanner(isRtl: isRtl),
                  const SizedBox(height: 16),

                  // Location
                  _OrderCard(
                    child: Row(
                      children: [
                        _IconCircle(
                          icon: Icons.place_rounded,
                          color: AppColors.brand,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isRtl ? 'عنوان التوصيل' : 'Delivery address',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF8A8FA8),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                selectedAddress?.compactAddress.isNotEmpty ==
                                        true
                                    ? selectedAddress!.compactAddress
                                    : (isRtl
                                          ? 'لم يتم تحديد عنوان'
                                          : 'No address selected'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A2E),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _GpsButton(
                          label: isRtl ? 'موقعي' : 'GPS',
                          isLoading: appState.isResolvingCurrentLocation,
                          onTap: appState.isResolvingCurrentLocation
                              ? null
                              : () => _syncGps(copy),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Product — multi-select with per-item quantity
                  Row(
                    children: [
                      Expanded(
                        child: _SectionLabel(
                          text: isRtl ? 'اختر الأسطوانات' : 'Select cylinders',
                        ),
                      ),
                      if (_totalItems > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brand,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isRtl
                                ? '$_totalItems أسطوانة'
                                : '$_totalItems item${_totalItems > 1 ? 's' : ''}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_totalItems == 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        isRtl
                            ? 'يمكنك إضافة أكثر من نوع في طلب واحد'
                            : 'You can mix multiple cylinder types in one order',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8A8FA8),
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  if (appState.products.isEmpty)
                    _EmptyHint(
                      text: isRtl
                          ? 'لا توجد منتجات متاحة حاليًا'
                          : 'No products available',
                    )
                  else
                    ...appState.products.asMap().entries.map((entry) {
                      final i = entry.key;
                      final product = entry.value;
                      final qty = _cartQty(product.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ProductTile(
                          name: product.localizedName(isRtl),
                          subtitle: product.localizedSubtitle(isRtl),
                          price: _formatCurrency(product.priceOmr, copy),
                          sizeLabel: _formatProductSize(product.sizeLabel),
                          iconAsset: _productIconAsset(product.id),
                          color: _productColor(i),
                          quantity: qty,
                          onAdd: () =>
                              setState(() => _cart[product.id] = qty + 1),
                          onRemove: qty > 0
                              ? () => setState(() {
                                  if (qty <= 1) {
                                    _cart.remove(product.id);
                                  } else {
                                    _cart[product.id] = qty - 1;
                                  }
                                })
                              : null,
                        ),
                      );
                    }),
                  const SizedBox(height: 16),

                  // Delivery time
                  _SectionLabel(text: isRtl ? 'وقت التوصيل' : 'Delivery time'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _DeliveryChip(
                          icon: Icons.bolt_rounded,
                          label: isRtl ? 'التوصيل الآن' : 'Deliver now',
                          selected: _deliveryWindow == _now,
                          onTap: () => setState(() {
                            _deliveryWindow = _now;
                            _scheduledTime = null;
                          }),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DeliveryChip(
                          icon: Icons.access_time_rounded,
                          label:
                              _deliveryWindow == _scheduled &&
                                  _scheduledTime != null
                              ? _deliveryWindowLabel(copy)
                              : (isRtl ? 'وقت محدد' : 'Schedule'),
                          selected: _deliveryWindow == _scheduled,
                          onTap: () => _pickTime(copy),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Payment method
                  _OrderCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isRtl ? 'طريقة الدفع' : 'Payment method',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8A8FA8),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _PaymentToggle(
                          isRtl: isRtl,
                          method: _paymentMethod,
                          onChanged: (m) => setState(() => _paymentMethod = m),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Price summary
                  _PriceSummaryCard(
                    cartItems: _cart.entries.where((e) => e.value > 0).map((e) {
                      final p = appState.products.firstWhere(
                        (pr) => pr.id == e.key,
                        orElse: () => appState.products.first,
                      );
                      return _CartSummaryItem(
                        name: p.localizedName(isRtl),
                        qty: e.value,
                        price: _formatCurrency(p.priceOmr * e.value, copy),
                      );
                    }).toList(),
                    subtotalLabel: copy.t('order.subtotal'),
                    subtotalValue: _formatCurrency(subtotal, copy),
                    deliveryLabel: copy.t('order.deliveryFee'),
                    deliveryValue: _formatCurrency(deliveryFee, copy),
                    totalLabel: copy.t('order.total'),
                    totalValue: _formatCurrency(total, copy),
                  ),
                ],
              ),
            ),
          ),

          // Fixed bottom button
          _ConfirmButton(
            label: isRtl ? 'تأكيد الطلب' : 'Confirm Order',
            isLoading: appState.isBusy,
            enabled: canSubmit,
            disabledMessage: canSubmit ? null : disabledMessage,
            onTap: canSubmit ? () => _submit(copy) : null,
          ),
        ],
      ),
    );
  }
}

// ── Models ────────────────────────────────────────────────────────────────────

// ── Shared Components ─────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4A4F6A),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _IconCircle extends StatelessWidget {
  const _IconCircle({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

// ── Screen Widgets ────────────────────────────────────────────────────────────

class _SmartBanner extends StatelessWidget {
  const _SmartBanner({required this.isRtl});

  final bool isRtl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brand.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.tips_and_updates_outlined,
            color: AppColors.brand,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isRtl
                  ? 'اقتراح ذكي: اخترت أسرع نافذة متاحة، وهي مناسبة للطلبات السريعة.'
                  : 'Smart tip: fastest window selected — ideal for quick deliveries.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.brandDeep,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GpsButton extends StatelessWidget {
  const _GpsButton({required this.label, required this.isLoading, this.onTap});

  final String label;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.teal.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.teal.withOpacity(0.3)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.teal,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.my_location_rounded,
                    size: 13,
                    color: AppColors.teal,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.name,
    required this.subtitle,
    required this.price,
    required this.sizeLabel,
    required this.iconAsset,
    required this.color,
    required this.quantity,
    required this.onAdd,
    this.onRemove,
  });

  final String name;
  final String subtitle;
  final String price;
  final String sizeLabel;
  final String iconAsset;
  final Color color;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;

  bool get _inCart => quantity > 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _inCart ? color.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _inCart ? color : const Color(0xFFEAECF4),
          width: _inCart ? 1.8 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          _ProductCylinderBadge(iconAsset: iconAsset, sizeLabel: sizeLabel),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _inCart ? color : const Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8A8FA8),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _inCart ? color : const Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        sizeLabel,
                        style: TextStyle(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Quantity stepper
          if (_inCart)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MiniStepBtn(
                  icon: Icons.remove_rounded,
                  color: color,
                  onTap: onRemove,
                ),
                SizedBox(
                  width: 32,
                  child: Text(
                    '$quantity',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ),
                _MiniStepBtn(
                  icon: Icons.add_rounded,
                  color: color,
                  onTap: onAdd,
                  filled: true,
                ),
              ],
            )
          else
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add_rounded, color: color, size: 20),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductCylinderBadge extends StatelessWidget {
  const _ProductCylinderBadge({
    required this.iconAsset,
    required this.sizeLabel,
  });

  final String iconAsset;
  final String sizeLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 62,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: SvgPicture.asset(
              iconAsset,
              width: 42,
              height: 58,
              fit: BoxFit.contain,
            ),
          ),
          const Positioned(
            bottom: 28,
            child: SizedBox(
              width: 30,
              child: Text(
                'OGAS',
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 5.2,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF7C2D12),
                  letterSpacing: 0.6,
                  height: 1,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 13,
            child: SizedBox(
              width: 30,
              child: Text(
                '\u200E$sizeLabel',
                textAlign: TextAlign.center,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 4.8,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF7C2D12),
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStepBtn extends StatelessWidget {
  const _MiniStepBtn({
    required this.icon,
    required this.color,
    this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: filled ? color : color.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: filled ? Colors.white : color),
      ),
    );
  }
}

class _DeliveryChip extends StatelessWidget {
  const _DeliveryChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.brand : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.brand : const Color(0xFFEAECF4),
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: AppColors.brand.withOpacity(0.28),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : const Color(0xFF8A8FA8),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF4A4F6A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentToggle extends StatelessWidget {
  const _PaymentToggle({
    required this.isRtl,
    required this.method,
    required this.onChanged,
  });

  final bool isRtl;
  final PaymentMethod method;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PaymentOption(
          icon: Icons.payments_outlined,
          label: isRtl ? 'نقدًا عند الاستلام' : 'Cash on delivery',
          selected: method == PaymentMethod.cashOnDelivery,
          color: AppColors.brand,
          onTap: () => onChanged(PaymentMethod.cashOnDelivery),
        ),
        const SizedBox(height: 6),
        _PaymentOption(
          icon: Icons.account_balance_wallet_outlined,
          label: isRtl ? 'دفع إلكتروني' : 'Digital wallet',
          selected: method == PaymentMethod.digitalWallet,
          color: AppColors.teal,
          onTap: () => onChanged(PaymentMethod.digitalWallet),
        ),
      ],
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.09) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color.withOpacity(0.4) : const Color(0xFFEAECF4),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? color : const Color(0xFF8A8FA8),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? color : const Color(0xFF8A8FA8),
                ),
              ),
            ),
            if (selected) Icon(Icons.check_rounded, size: 13, color: color),
          ],
        ),
      ),
    );
  }
}

class _CartSummaryItem {
  const _CartSummaryItem({
    required this.name,
    required this.qty,
    required this.price,
  });
  final String name;
  final int qty;
  final String price;
}

class _PriceSummaryCard extends StatelessWidget {
  const _PriceSummaryCard({
    required this.cartItems,
    required this.subtotalLabel,
    required this.subtotalValue,
    required this.deliveryLabel,
    required this.deliveryValue,
    required this.totalLabel,
    required this.totalValue,
  });

  final List<_CartSummaryItem> cartItems;
  final String subtotalLabel;
  final String subtotalValue;
  final String deliveryLabel;
  final String deliveryValue;
  final String totalLabel;
  final String totalValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Cart items breakdown
          if (cartItems.isNotEmpty) ...[
            ...cartItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppColors.brand.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${item.qty}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brand,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4A4F6A),
                        ),
                      ),
                    ),
                    Text(
                      item.price,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1, color: Color(0xFFEAECF4)),
            ),
          ],
          _PriceRow(label: subtotalLabel, value: subtotalValue),
          const SizedBox(height: 8),
          _PriceRow(label: deliveryLabel, value: deliveryValue),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFEAECF4)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                totalLabel,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              Text(
                totalValue,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.brand,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF8A8FA8)),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4A4F6A),
          ),
        ),
      ],
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({
    required this.label,
    required this.isLoading,
    required this.enabled,
    this.onTap,
    this.disabledMessage,
  });

  final String label;
  final bool isLoading;
  final bool enabled;
  final VoidCallback? onTap;
  final String? disabledMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!enabled && disabledMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                disabledMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.brandDeep,
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: enabled
                    ? AppColors.brand
                    : const Color(0xFFDDE0EC),
                foregroundColor: Colors.white,
                elevation: enabled ? 4 : 0,
                shadowColor: AppColors.brand.withOpacity(0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
