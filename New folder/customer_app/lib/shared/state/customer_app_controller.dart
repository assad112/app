import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:customer_app/core/device/device_location_service.dart';
import 'package:customer_app/core/network/socket_service.dart';
import 'package:customer_app/data/mock/mock_data.dart';
import 'package:customer_app/data/services/auth_service.dart';
import 'package:customer_app/data/services/customer_catalog_service.dart';
import 'package:customer_app/data/services/customer_order_service.dart';
import 'package:customer_app/data/services/customer_profile_service.dart';
import 'package:customer_app/data/services/session_storage_service.dart';
import 'package:customer_app/shared/localization/app_copy.dart';
import 'package:customer_app/shared/models/app_runtime_settings.dart';
import 'package:customer_app/shared/models/address_model.dart';
import 'package:customer_app/shared/models/driver_snapshot.dart';
import 'package:customer_app/shared/models/gas_product.dart';
import 'package:customer_app/shared/models/order_model.dart';
import 'package:customer_app/shared/models/order_status.dart';
import 'package:customer_app/shared/models/payment_method.dart';
import 'package:customer_app/shared/models/tracking_route_point.dart';
import 'package:customer_app/shared/models/user_profile.dart';
import 'package:customer_app/shared/state/customer_app_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final customerAppControllerProvider =
    NotifierProvider<CustomerAppController, CustomerAppState>(
      CustomerAppController.new,
    );

class BundledOrderItem {
  const BundledOrderItem({required this.product, required this.quantity});

  final GasProduct product;
  final int quantity;
}

class CurrentLocationUpdateResult {
  const CurrentLocationUpdateResult._({
    required this.success,
    this.address,
    this.failure,
  });

  const CurrentLocationUpdateResult.success(AddressModel address)
    : this._(success: true, address: address);

  const CurrentLocationUpdateResult.failure(DeviceLocationFailure failure)
    : this._(success: false, failure: failure);

  final bool success;
  final AddressModel? address;
  final DeviceLocationFailure? failure;
}

class CustomerAppController extends Notifier<CustomerAppState> {
  static const double _omanLatitudeMin = 15.0;
  static const double _omanLatitudeMax = 28.8;
  static const double _omanLongitudeMin = 51.0;
  static const double _omanLongitudeMax = 60.9;

  @override
  CustomerAppState build() {
    final socketService = ref.read(socketServiceProvider);
    ref.onDispose(socketService.dispose);
    return CustomerAppState.initial();
  }

  Future<void> initialize() async {
    if (state.isInitialized) {
      return;
    }

    final storage = ref.read(sessionStorageServiceProvider);
    final language = await storage.readLanguage();
    final wasAuthenticated = await storage.readSessionActive();
    final storedUser = await storage.readUser();
    final storedToken = await storage.readAuthToken();
    final storedCurrentAddress = await storage.readCurrentAddress();
    final resolvedStoredCurrentAddress =
        _shouldKeepCurrentLocationAddress(storedCurrentAddress)
        ? storedCurrentAddress
        : null;
    var isAuthenticated = wasAuthenticated;
    UserProfile? resolvedUser = storedUser;

    if (wasAuthenticated && storedToken != null) {
      final remoteUser = await ref.read(authServiceProvider).me(storedToken);

      if (remoteUser != null) {
        resolvedUser = remoteUser;
        await storage.persistSession(remoteUser, authToken: storedToken);
        // ربط المستخدم بـ OneSignal عند استعادة الجلسة
        await OneSignal.login(remoteUser.id);
        OneSignal.User.addTagWithKey('userType', 'customer');
      } else if (storedUser != null) {
        resolvedUser = storedUser;
        isAuthenticated = true;
      } else {
        isAuthenticated = false;
        resolvedUser = null;
        await storage.clearSession();
      }
    } else if (wasAuthenticated) {
      isAuthenticated = false;
      resolvedUser = null;
      await storage.clearSession();
    }

    if (storedCurrentAddress != null && resolvedStoredCurrentAddress == null) {
      await storage.persistCurrentAddress(null);
      if (resolvedUser != null &&
          resolvedUser.defaultAddressId == AddressModel.currentLocationId) {
        resolvedUser = resolvedUser.copyWith(
          defaultAddressId: _fallbackSavedAddressId(),
        );
        await storage.persistUserProfile(resolvedUser);
      }
    }

    state = state.copyWith(
      isInitialized: true,
      language: language,
      isAuthenticated: isAuthenticated,
      user: isAuthenticated ? resolvedUser : null,
      products: MockData.gasProducts,
      addresses: _mergeAddresses(
        MockData.addresses,
        resolvedStoredCurrentAddress == null
            ? const []
            : [resolvedStoredCurrentAddress],
      ),
      orders: const [],
      runtimeSettings: const AppRuntimeSettings.fallback(),
    );

    await _refreshLiveOrderSubscription();
    await _syncCatalogFromBackend();

    if (state.isAuthenticated) {
      await _syncCustomerOrdersFromBackend();
    }
  }

  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    if (identifier.trim().isEmpty || password.trim().isEmpty) {
      state = state.copyWith(
        lastAuthErrorMessage: AppCopy(state.language).t('validation.required'),
      );
      return false;
    }

    state = state.copyWith(isBusy: true, clearLastAuthErrorMessage: true);
    final storage = ref.read(sessionStorageServiceProvider);
    final authRequest = await ref
        .read(authServiceProvider)
        .login(identifier: identifier.trim(), password: password.trim());

    if (!authRequest.isSuccess || authRequest.data == null) {
      state = state.copyWith(
        isBusy: false,
        lastAuthErrorMessage: _resolveAuthFailureMessage(
          authRequest.errorMessage,
        ),
      );
      return false;
    }

    final authResult = authRequest.data!;

    state = state.copyWith(
      isBusy: true,
      isAuthenticated: true,
      user: authResult.user,
      clearLastAuthErrorMessage: true,
    );

    await storage.persistSession(authResult.user, authToken: authResult.token);
    await storage.persistLastIdentifier(identifier);
    await OneSignal.login(authResult.user.id);
    OneSignal.User.addTagWithKey('userType', 'customer');
    state = state.copyWith(isBusy: false);
    await _refreshLiveOrderSubscription();
    await _syncCatalogFromBackend();
    await _syncCustomerOrdersFromBackend();
    return true;
  }

  Future<bool> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    if (fullName.trim().isEmpty ||
        phone.trim().isEmpty ||
        password.trim().isEmpty) {
      state = state.copyWith(
        lastAuthErrorMessage: AppCopy(state.language).t('validation.required'),
      );
      return false;
    }

    state = state.copyWith(isBusy: true, clearLastAuthErrorMessage: true);
    final authRequest = await ref
        .read(authServiceProvider)
        .register(
          fullName: fullName.trim(),
          phone: phone.trim(),
          email: email.trim(),
          password: password.trim(),
        );

    if (!authRequest.isSuccess || authRequest.data == null) {
      state = state.copyWith(
        isBusy: false,
        lastAuthErrorMessage: _resolveAuthFailureMessage(
          authRequest.errorMessage,
        ),
      );
      return false;
    }

    final authResult = authRequest.data!;
    final storage = ref.read(sessionStorageServiceProvider);

    state = state.copyWith(
      isBusy: true,
      isAuthenticated: true,
      user: authResult.user,
      clearLastAuthErrorMessage: true,
    );

    await storage.persistSession(authResult.user, authToken: authResult.token);
    await storage.persistLastIdentifier(
      phone.trim().isNotEmpty ? phone : email,
    );
    await OneSignal.login(authResult.user.id);
    OneSignal.User.addTagWithKey('userType', 'customer');
    state = state.copyWith(isBusy: false);
    await _refreshLiveOrderSubscription();
    await _syncCatalogFromBackend();
    await _syncCustomerOrdersFromBackend();
    return true;
  }

  Future<void> logout() async {
    final storage = ref.read(sessionStorageServiceProvider);
    final authToken = await storage.readAuthToken();

    if (authToken != null) {
      await ref.read(authServiceProvider).logout(authToken);
    }

    _stopLiveOrderUpdates();
    await storage.clearSession();
    OneSignal.logout();

    state = state.copyWith(
      isAuthenticated: false,
      clearUser: true,
      clearLastAuthErrorMessage: true,
    );
  }

  String _resolveAuthFailureMessage(String? rawMessage) {
    final copy = AppCopy(state.language);
    final message = rawMessage?.trim();

    if (message == null || message.isEmpty) {
      return copy.t('auth.invalidCredentials');
    }

    final normalized = message.toLowerCase();

    if (normalized.contains('phone number already exists') ||
        (normalized.contains('phone') &&
            normalized.contains('already exists'))) {
      return copy.t('auth.phoneExists');
    }

    if (normalized.contains('email already exists')) {
      return copy.t('auth.emailExists');
    }

    if (normalized.contains('invalid login credentials')) {
      return copy.t('auth.invalidLogin');
    }

    if (normalized.contains('cleartext') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('connection refused') ||
        normalized.contains('connection terminated') ||
        normalized.contains('connection error') ||
        normalized.contains('socketexception') ||
        normalized.contains('timed out') ||
        normalized.contains('unable to reach the server')) {
      return copy.t('auth.serverUnavailable');
    }

    return message;
  }

  String _extractDioErrorMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'تعذّر الاتصال بالخادم. تحقق من اتصالك بالإنترنت وحاول مجدداً.';
      case DioExceptionType.connectionError:
        return 'تعذّر الوصول إلى الخادم. تحقق من اتصالك بالإنترنت.';
      default:
        break;
    }

    final responseData = error.response?.data;
    if (responseData is Map) {
      final message = responseData['message'];
      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString().trim();
      }
    }

    return 'تعذّر إتمام الطلب في الوقت الحالي. حاول مجدداً.';
  }

  String _resolveOrderSubmissionFailureMessage(String? rawMessage) {
    final copy = AppCopy(state.language);
    final message = rawMessage?.trim();

    if (message == null || message.isEmpty) {
      return copy.t('order.serverUnavailable');
    }

    final normalized = message.toLowerCase();

    if (normalized.contains('api_base_url') ||
        normalized.contains('socket_base_url') ||
        normalized.contains('--dart-define') ||
        normalized.contains('/api/orders') ||
        normalized.contains('تمت محاولة الإرسال')) {
      return message;
    }

    if (normalized.contains('cleartext') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('connection refused') ||
        normalized.contains('connection terminated') ||
        normalized.contains('connection error') ||
        normalized.contains('socketexception') ||
        normalized.contains('timed out') ||
        normalized.contains('unable to reach the server')) {
      return copy.t('order.serverUnavailable');
    }

    return message;
  }

  Future<void> switchLanguage(AppLanguage language) async {
    final storage = ref.read(sessionStorageServiceProvider);
    await storage.persistLanguage(language);
    state = state.copyWith(language: language);
  }

  Future<CurrentLocationUpdateResult> refreshCurrentLocation() async {
    state = state.copyWith(isResolvingCurrentLocation: true);

    try {
      final localeIdentifier = state.language == AppLanguage.ar
          ? 'ar_OM'
          : 'en_OM';
      final snapshot = await ref
          .read(deviceLocationServiceProvider)
          .getPreciseLocation(localeIdentifier: localeIdentifier);

      if (!_isLocationWithinOman(snapshot)) {
        state = state.copyWith(isResolvingCurrentLocation: false);
        return const CurrentLocationUpdateResult.failure(
          DeviceLocationFailure.outOfCoverage,
        );
      }

      final address = _buildCurrentLocationAddress(snapshot);
      final nextAddresses = _mergeAddresses([address], state.addresses);
      final nextUser = state.user?.copyWith(defaultAddressId: address.id);
      final storage = ref.read(sessionStorageServiceProvider);

      state = state.copyWith(
        isResolvingCurrentLocation: false,
        addresses: nextAddresses,
        user: nextUser,
      );

      await storage.persistCurrentAddress(address);
      if (nextUser != null) {
        await storage.persistUserProfile(nextUser);
      }
      await ref
          .read(customerProfileServiceProvider)
          .saveDefaultAddress(address);

      return CurrentLocationUpdateResult.success(address);
    } on DeviceLocationException catch (error) {
      state = state.copyWith(isResolvingCurrentLocation: false);
      return CurrentLocationUpdateResult.failure(error.failure);
    } catch (_) {
      state = state.copyWith(isResolvingCurrentLocation: false);
      return const CurrentLocationUpdateResult.failure(
        DeviceLocationFailure.unavailable,
      );
    }
  }

  Future<void> selectDefaultAddress(AddressModel address) async {
    final nextAddresses = <AddressModel>[];
    var didUpdate = false;

    for (final item in state.addresses) {
      if (item.id == address.id) {
        nextAddresses.add(address.copyWith(isDefault: true));
        didUpdate = true;
      } else {
        nextAddresses.add(item.copyWith(isDefault: false));
      }
    }

    if (!didUpdate) {
      nextAddresses.add(address.copyWith(isDefault: true));
    }

    final nextUser = state.user?.copyWith(defaultAddressId: address.id);
    state = state.copyWith(addresses: nextAddresses, user: nextUser);

    final storage = ref.read(sessionStorageServiceProvider);
    await storage.persistCurrentAddress(
      address.isCurrentLocation ? address : null,
    );
    if (nextUser != null) {
      await storage.persistUserProfile(nextUser);
    }
    await ref.read(customerProfileServiceProvider).saveDefaultAddress(address);
  }

  Future<void> refreshOrdersFromBackend() async {
    await _syncCustomerOrdersFromBackend();
  }

  Future<OrderModel?> updateOrderDeliveryLocation({
    required String orderId,
    required AddressModel address,
  }) async {
    final response = await ref
        .read(customerOrderServiceProvider)
        .updateOrderDeliveryLocation(orderId: orderId, address: address);

    final patch = _parseLiveOrderPatch(response);
    if (patch != null) {
      _applyLiveOrderPatch(patch);
      return orderById(patch.orderId);
    }

    await _syncCustomerOrdersFromBackend();
    return orderById(orderId);
  }

  OrderModel? orderById(String orderId) {
    for (final order in state.orders) {
      if (order.orderId == orderId) {
        return order;
      }
    }

    return null;
  }

  Future<OrderModel?> createOrder({
    required GasProduct product,
    required int quantity,
    required AddressModel address,
    required String notes,
    required PaymentMethod paymentMethod,
    String? preferredDeliveryWindow,
  }) async {
    final customer = state.user;

    if (customer == null || !state.runtimeSettings.orderIntakeEnabled) {
      return null;
    }

    final subtotal = product.priceOmr * quantity;
    final deliveryFee = product.deliveryFeeOmr > 0
        ? product.deliveryFeeOmr
        : state.runtimeSettings.defaultDeliveryFee;
    final totalPrice = subtotal + deliveryFee;

    state = state.copyWith(
      isBusy: true,
      clearLastOrderSubmissionErrorMessage: true,
    );

    try {
      final remoteReceipt = await ref
          .read(customerOrderServiceProvider)
          .submitOrder(
            customer: customer,
            address: address,
            product: product,
            quantity: quantity,
            notes: notes,
            paymentMethod: paymentMethod,
            preferredDeliveryWindow: preferredDeliveryWindow,
            totalAmount: totalPrice,
          );

      final order = OrderModel(
      orderId: remoteReceipt.orderId,
      customerId: customer.id,
      customerName: customer.fullName,
      phone: customer.phone,
      gasProduct: product,
      quantity: quantity,
      address: address,
      notes: notes.trim(),
      paymentMethod: paymentMethod,
      orderStatus: remoteReceipt.status,
      subtotalPrice: subtotal,
      deliveryFee: deliveryFee,
      totalPrice: totalPrice,
      createdAt: remoteReceipt.createdAt,
      updatedAt: DateTime.now(),
      preferredDeliveryWindow: preferredDeliveryWindow,
      items: [
        OrderLineItem(
          id: 'local-${product.id}-${DateTime.now().millisecondsSinceEpoch}',
          orderId: remoteReceipt.orderId,
          productId: product.id,
          productCode: product.id,
          productNameAr: product.nameAr,
          productNameEn: product.nameEn,
          sizeLabel: product.sizeLabel,
          driverInventoryCode: '',
          quantity: quantity,
          unitPrice: product.priceOmr,
          deliveryFee: product.deliveryFeeOmr,
          lineTotal: subtotal,
        ),
      ],
    );

      final nextOrders =
          state.orders.any((item) => item.orderId == order.orderId)
          ? state.orders
          : _sortOrders([order, ...state.orders]);

      state = state.copyWith(
        orders: nextOrders,
        clearLastOrderSubmissionErrorMessage: true,
      );

      return order;
    } on RemoteOrderSubmissionException catch (error) {
      state = state.copyWith(
        lastOrderSubmissionErrorMessage: _resolveOrderSubmissionFailureMessage(
          error.message,
        ),
      );
      return null;
    } on DioException catch (error) {
      state = state.copyWith(
        lastOrderSubmissionErrorMessage: _resolveOrderSubmissionFailureMessage(
          _extractDioErrorMessage(error),
        ),
      );
      return null;
    } catch (_) {
      state = state.copyWith(
        lastOrderSubmissionErrorMessage: _resolveOrderSubmissionFailureMessage(
          null,
        ),
      );
      return null;
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  Future<OrderModel?> createBundledOrder({
    required List<BundledOrderItem> items,
    required AddressModel address,
    required PaymentMethod paymentMethod,
    String? preferredDeliveryWindow,
  }) async {
    final customer = state.user;
    final validItems = items
        .where((item) => item.quantity > 0)
        .toList(growable: false);

    if (customer == null ||
        !state.runtimeSettings.orderIntakeEnabled ||
        validItems.isEmpty) {
      return null;
    }

    final subtotal = validItems.fold<double>(
      0,
      (sum, item) => sum + (item.product.priceOmr * item.quantity),
    );
    final deliveryFee = validItems
        .map((item) => item.product.deliveryFeeOmr)
        .where((fee) => fee > 0)
        .fold<double>(
          state.runtimeSettings.defaultDeliveryFee,
          (current, fee) => fee > current ? fee : current,
        );
    final totalPrice = subtotal + deliveryFee;
    final totalQuantity = validItems.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );
    final gasTypeSummary = validItems
        .map((item) => '${item.product.nameAr} x${item.quantity}')
        .join(' + ');
    final notes = _buildBundledOrderNotes(
      items: validItems,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      totalPrice: totalPrice,
    );
    final summaryProduct = GasProduct(
      id: 'bundle-${DateTime.now().millisecondsSinceEpoch}',
      nameAr: gasTypeSummary,
      nameEn: validItems
          .map((item) => '${item.product.nameEn} x${item.quantity}')
          .join(' + '),
      sizeLabel: '$totalQuantity',
      priceOmr: subtotal,
      deliveryFeeOmr: deliveryFee,
      subtitleAr: 'طلب مجمع بعدة أنواع وكميات في طلب واحد.',
      subtitleEn: 'Bundled order with multiple cylinder types in one request.',
    );

    state = state.copyWith(
      isBusy: true,
      clearLastOrderSubmissionErrorMessage: true,
    );

    try {
      final remoteReceipt = await ref
          .read(customerOrderServiceProvider)
          .submitBundledOrder(
            customer: customer,
            address: address,
            items: validItems
                .map(
                  (item) => BundledRemoteOrderItem(
                    productId: item.product.id,
                    quantity: item.quantity,
                  ),
                )
                .toList(growable: false),
            gasType: gasTypeSummary,
            quantity: totalQuantity,
            notes: notes,
            paymentMethod: paymentMethod,
            preferredDeliveryWindow: preferredDeliveryWindow,
            totalAmount: totalPrice,
          );

      var order = OrderModel(
      orderId: remoteReceipt.orderId,
      customerId: customer.id,
      customerName: customer.fullName,
      phone: customer.phone,
      gasProduct: summaryProduct,
      quantity: totalQuantity,
      address: address,
      notes: notes,
      paymentMethod: paymentMethod,
      orderStatus: remoteReceipt.status,
      subtotalPrice: subtotal,
      deliveryFee: deliveryFee,
      totalPrice: totalPrice,
      createdAt: remoteReceipt.createdAt,
      updatedAt: DateTime.now(),
      preferredDeliveryWindow: preferredDeliveryWindow,
      items: validItems
          .map(
            (item) => OrderLineItem(
              id: 'local-${item.product.id}-${DateTime.now().millisecondsSinceEpoch}',
              orderId: remoteReceipt.orderId,
              productId: item.product.id,
              productCode: item.product.id,
              productNameAr: item.product.nameAr,
              productNameEn: item.product.nameEn,
              sizeLabel: item.product.sizeLabel,
              driverInventoryCode: '',
              quantity: item.quantity,
              unitPrice: item.product.priceOmr,
              deliveryFee: item.product.deliveryFeeOmr,
              lineTotal: item.product.priceOmr * item.quantity,
            ),
          )
          .toList(growable: false),
    );

      try {
        await _syncCustomerOrdersFromBackend();
        order = orderById(remoteReceipt.orderId) ?? order;
      } catch (_) {
        // Keep the locally created order and let realtime or later refreshes
        // reconcile server state without trapping the user in a loading state.
      }

      final nextOrders =
          state.orders.any((item) => item.orderId == order.orderId)
          ? state.orders
          : _sortOrders([order, ...state.orders]);

      state = state.copyWith(
        orders: nextOrders,
        clearLastOrderSubmissionErrorMessage: true,
      );

      return order;
    } on RemoteOrderSubmissionException catch (error) {
      state = state.copyWith(
        lastOrderSubmissionErrorMessage: _resolveOrderSubmissionFailureMessage(
          error.message,
        ),
      );
      return null;
    } on DioException catch (error) {
      state = state.copyWith(
        lastOrderSubmissionErrorMessage: _resolveOrderSubmissionFailureMessage(
          _extractDioErrorMessage(error),
        ),
      );
      return null;
    } catch (_) {
      state = state.copyWith(
        lastOrderSubmissionErrorMessage: _resolveOrderSubmissionFailureMessage(
          null,
        ),
      );
      return null;
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  Future<OrderModel?> reorder(String orderId) async {
    final existingOrder = orderById(orderId);

    if (existingOrder == null) {
      return null;
    }

    if (existingOrder.items.length > 1) {
      return createBundledOrder(
        items: existingOrder.items
            .map((item) {
              final mappedProduct = item.productId == null
                  ? null
                  : _findProductById(item.productId!);
              if (mappedProduct == null) {
                return null;
              }

              return BundledOrderItem(
                product: mappedProduct,
                quantity: item.quantity,
              );
            })
            .whereType<BundledOrderItem>()
            .toList(growable: false),
        address: existingOrder.address,
        paymentMethod: existingOrder.paymentMethod,
        preferredDeliveryWindow: existingOrder.preferredDeliveryWindow,
      );
    }

    return createOrder(
      product: existingOrder.gasProduct,
      quantity: existingOrder.quantity,
      address: existingOrder.address,
      notes: existingOrder.notes,
      paymentMethod: existingOrder.paymentMethod,
      preferredDeliveryWindow: existingOrder.preferredDeliveryWindow,
    );
  }

  void cancelOrder(String orderId) {
    final updatedOrders = state.orders.map((order) {
      if (order.orderId != orderId || !order.orderStatus.canCancel) {
        return order;
      }

      return order.copyWith(
        orderStatus: OrderStatus.cancelled,
        updatedAt: DateTime.now(),
      );
    }).toList();

    state = state.copyWith(orders: _sortOrders(updatedOrders));
  }

  Future<void> _refreshLiveOrderSubscription() async {
    final user = state.user;
    if (!state.isAuthenticated || user == null) {
      _stopLiveOrderUpdates();
      return;
    }

    final authToken = await ref
        .read(sessionStorageServiceProvider)
        .readAuthToken();

    ref
        .read(socketServiceProvider)
        .connect(
          customerId: user.id,
          authToken: authToken,
          onOrderStatusChanged: _handleOrderStatusChanged,
          onDriverLocationUpdated: _handleDriverLocationUpdated,
          onProductUpdated: _handleProductUpdated,
          onZoneUpdated: _handleZoneUpdated,
          onSettingsUpdated: _handleSettingsUpdated,
          onNotification: _handleRealtimeNotification,
        );
  }

  void _stopLiveOrderUpdates() {
    ref.read(socketServiceProvider).disconnect();
  }

  Future<void> _syncCatalogFromBackend() async {
    final snapshot = await ref
        .read(customerCatalogServiceProvider)
        .fetchCatalogSnapshot();

    if (snapshot == null) {
      return;
    }

    final mappedProducts = snapshot.products
        .map(_mapProductFromBackend)
        .whereType<GasProduct>()
        .where((item) => item.isAvailable)
        .toList(growable: false);

    final mappedAddresses = snapshot.zones
        .map(_mapAddressFromZone)
        .whereType<AddressModel>()
        .toList(growable: false);

    final mappedSettings =
        _mapRuntimeSettingsFromBackend(snapshot.settings) ??
        state.runtimeSettings;
    final nextAddresses = mappedAddresses.isEmpty
        ? state.addresses
        : _mergeAddresses(
            state.addresses.where((item) => item.isCurrentLocation),
            mappedAddresses,
          );

    state = state.copyWith(
      products: mappedProducts.isEmpty ? state.products : mappedProducts,
      addresses: nextAddresses,
      runtimeSettings: mappedSettings,
    );
  }

  void _handleProductUpdated(Map<String, dynamic> payload) {
    final product = _mapProductFromBackend(payload);
    if (product == null) {
      return;
    }

    final nextProducts = [...state.products];
    final existingIndex = nextProducts.indexWhere(
      (item) => item.id == product.id,
    );

    if (!product.isAvailable) {
      if (existingIndex != -1) {
        nextProducts.removeAt(existingIndex);
      }
    } else if (existingIndex == -1) {
      nextProducts.add(product);
    } else {
      nextProducts[existingIndex] = product;
    }

    if (nextProducts.isEmpty) {
      return;
    }

    state = state.copyWith(products: nextProducts);
  }

  void _handleZoneUpdated(Map<String, dynamic> payload) {
    final mappedAddress = _mapAddressFromZone(payload);
    if (mappedAddress == null) {
      return;
    }

    final isActive =
        _readBool(payload, const ['is_active', 'isActive']) ?? true;
    final nextAddresses = [...state.addresses];
    final existingIndex = nextAddresses.indexWhere(
      (item) => item.id == mappedAddress.id,
    );

    if (!isActive) {
      if (existingIndex != -1) {
        nextAddresses.removeAt(existingIndex);
      }
    } else if (existingIndex == -1) {
      nextAddresses.add(mappedAddress);
    } else {
      nextAddresses[existingIndex] = mappedAddress;
    }

    if (nextAddresses.isEmpty) {
      return;
    }

    state = state.copyWith(addresses: nextAddresses);
  }

  void _handleSettingsUpdated(Map<String, dynamic> payload) {
    final mappedSettings = _mapRuntimeSettingsFromBackend(payload);
    if (mappedSettings == null) {
      return;
    }

    state = state.copyWith(runtimeSettings: mappedSettings);
  }

  Future<void> _syncCustomerOrdersFromBackend() async {
    if (!state.isAuthenticated || state.user == null) {
      return;
    }

    final remoteOrders = await ref
        .read(customerOrderServiceProvider)
        .fetchMyOrders();

    if (remoteOrders == null) {
      return;
    }

    final mappedOrders = <OrderModel>[];

    for (final item in remoteOrders) {
      final patch = _parseLiveOrderPatch(item);
      if (patch == null) {
        continue;
      }

      if (!_isPayloadForCurrentCustomer(patch.sourceData, patch.orderId)) {
        continue;
      }

      final order = _buildOrderFromPatch(patch);
      if (order != null) {
        if (order.parentOrderId == null) {
          mappedOrders.add(order);
        }
      }
    }

    if (remoteOrders.isEmpty) {
      state = state.copyWith(orders: const []);
      return;
    }

    if (mappedOrders.isEmpty) {
      return;
    }

    state = state.copyWith(orders: _sortOrders(mappedOrders));
  }

  void _handleRealtimeOrderPayload(Map<String, dynamic> payload) {
    final patch = _parseLiveOrderPatch(payload);
    if (patch == null) {
      return;
    }

    if (!_isPayloadForCurrentCustomer(patch.sourceData, patch.orderId)) {
      return;
    }

    _applyLiveOrderPatch(patch);
  }

  void _handleOrderStatusChanged(Map<String, dynamic> payload) {
    _handleRealtimeOrderPayload(payload);
  }

  void _handleDriverLocationUpdated(Map<String, dynamic> payload) {
    _handleRealtimeOrderPayload(payload);
  }

  void _handleRealtimeNotification(Map<String, dynamic> payload) {
    final type = _readString(_flattenPayload(payload), const [
      'type',
      'event',
      'notificationType',
    ])?.toLowerCase();

    if (type == null || type.isEmpty) {
      _handleRealtimeOrderPayload(payload);
      return;
    }

    if (type.contains('status') || type.contains('order')) {
      _handleRealtimeOrderPayload(payload);
    }

    if (type.contains('location') || type.contains('driver')) {
      _handleRealtimeOrderPayload(payload);
    }
  }

  _LiveOrderPatch? _parseLiveOrderPatch(Map<String, dynamic> payload) {
    final data = _flattenPayload(payload);
    final orderId = _resolveOrderId(data);
    if (orderId == null) {
      return null;
    }

    final driverData = _mapFromKeys(data, const [
      'driver',
      'driverSnapshot',
      'driver_snapshot',
    ]);
    final locationData = _mapFromKeys(data, const [
      'driverLocation',
      'driver_location',
      'coordinates',
      'driverCoordinates',
    ]);
    final customerLocationData = _mapFromKeys(data, const [
      'customerLocation',
      'customer_location',
      'destination',
      'dropoff',
    ]);
    final trackingRouteData = _mapFromKeys(data, const [
      'trackingRoute',
      'tracking_route',
    ]);

    final status = _parseStatus(
      _readString(data, const [
        'publicStatus',
        'public_status',
        'orderStatus',
        'order_status',
        'driverStage',
        'driver_stage',
        'status',
      ]),
    );
    final customerLatitude =
        _readDouble(data, const [
          'customerLatitude',
          'customer_latitude',
          'latitude',
        ]) ??
        _readDouble(customerLocationData, const ['lat', 'latitude']);
    final customerLongitude =
        _readDouble(data, const [
          'customerLongitude',
          'customer_longitude',
          'longitude',
        ]) ??
        _readDouble(customerLocationData, const [
          'lng',
          'lon',
          'longitude',
          'long',
        ]);
    final addressText =
        _readString(data, const [
          'addressText',
          'address_text',
          'addressFull',
          'address_full',
          'location',
        ]) ??
        _readString(customerLocationData, const [
          'addressText',
          'address_text',
          'addressFull',
          'address_full',
          'label',
        ]);
    final addressFull =
        _readString(data, const ['addressFull', 'address_full']) ??
        _readString(customerLocationData, const [
          'addressFull',
          'address_full',
        ]);
    final driverLatitude =
        _readDouble(data, const [
          'driverLatitude',
          'driver_latitude',
          'currentLatitude',
          'current_latitude',
        ]) ??
        _readDouble(locationData, const ['lat', 'latitude']);
    final driverLongitude =
        _readDouble(data, const [
          'driverLongitude',
          'driver_longitude',
          'currentLongitude',
          'current_longitude',
        ]) ??
        _readDouble(locationData, const ['lng', 'lon', 'longitude', 'long']);
    final driverId = _readString(driverData ?? data, const [
      'id',
      'driverId',
      'driver_id',
    ]);
    final driverName = _readString(driverData ?? data, const [
      'name',
      'driverName',
      'driver_name',
    ]);
    final driverPhone = _readString(driverData ?? data, const [
      'phone',
      'driverPhone',
      'driver_phone',
    ]);
    final driverVehicleLabel = _readString(driverData ?? data, const [
      'vehicleLabel',
      'vehicle_label',
      'vehicle',
      'car',
    ]);
    final etaMinutes =
        _readInt(driverData ?? data, const [
          'etaMinutes',
          'eta_minutes',
          'eta',
        ]) ??
        _readInt(data, const ['etaMinutes', 'eta_minutes', 'eta']) ??
        _readInt(trackingRouteData, const ['etaMinutes', 'eta_minutes']);
    final routePoints = _readRoutePoints(data, trackingRouteData);
    final routeDistanceMeters =
        _readInt(data, const [
          'routeDistanceMeters',
          'route_distance_meters',
        ]) ??
        _readInt(trackingRouteData, const [
          'distanceMeters',
          'routeDistanceMeters',
          'route_distance_meters',
        ]);
    final routeDurationSeconds =
        _readInt(data, const [
          'routeDurationSeconds',
          'route_duration_seconds',
        ]) ??
        _readInt(trackingRouteData, const [
          'durationSeconds',
          'routeDurationSeconds',
          'route_duration_seconds',
        ]);

    if (status == null &&
        customerLatitude == null &&
        customerLongitude == null &&
        addressText == null &&
        addressFull == null &&
        driverLatitude == null &&
        driverLongitude == null &&
        driverId == null &&
        driverName == null &&
        driverPhone == null &&
        driverVehicleLabel == null &&
        etaMinutes == null &&
        routePoints.isEmpty &&
        routeDistanceMeters == null &&
        routeDurationSeconds == null) {
      return null;
    }

    return _LiveOrderPatch(
      orderId: orderId,
      sourceData: data,
      status: status,
      customerLatitude: customerLatitude,
      customerLongitude: customerLongitude,
      addressText: addressText,
      addressFull: addressFull,
      driverId: driverId,
      driverName: driverName,
      driverPhone: driverPhone,
      driverVehicleLabel: driverVehicleLabel,
      etaMinutes: etaMinutes,
      driverLatitude: driverLatitude,
      driverLongitude: driverLongitude,
      routePoints: routePoints,
      routeDistanceMeters: routeDistanceMeters,
      routeDurationSeconds: routeDurationSeconds,
      updatedAt:
          _parseDateTime(
            data['updatedAt'] ??
                data['updated_at'] ??
                data['timestamp'] ??
                data['createdAt'] ??
                data['created_at'],
          ) ??
          DateTime.now(),
    );
  }

  void _applyLiveOrderPatch(_LiveOrderPatch patch) {
    final orderIndex = state.orders.indexWhere(
      (order) => order.orderId == patch.orderId,
    );
    final patchParentOrderId = _readString(patch.sourceData, const [
      'parentOrderId',
      'parent_order_id',
    ]);
    final patchItems = _parseOrderLineItems(patch.sourceData, patch.orderId);
    final patchChildOrders = _parseChildOrders(patch.sourceData);
    final patchFulfillmentType =
        _readString(patch.sourceData, const [
          'fulfillmentType',
          'fulfillment_type',
        ]) ??
        'standalone';
    final patchFulfillmentInventoryCode = _readString(patch.sourceData, const [
      'fulfillmentInventoryCode',
      'fulfillment_inventory_code',
    ]);

    if (orderIndex == -1) {
      final parentIndex = state.orders.indexWhere(
        (order) =>
            order.childOrders.any((child) => child.orderId == patch.orderId),
      );

      if (parentIndex != -1) {
        final parentOrder = state.orders[parentIndex];
        final nextChildren = parentOrder.childOrders
            .map((childOrder) {
              if (childOrder.orderId != patch.orderId) {
                return childOrder;
              }

              final nextDriver = _buildNextDriverSnapshot(
                currentDriver: childOrder.driver,
                patch: patch,
              );
              final nextAddress = _resolveUpdatedTrackingAddress(
                childOrder.address,
                patch,
              );

              return childOrder.copyWith(
                orderStatus: patch.status ?? childOrder.orderStatus,
                updatedAt: patch.updatedAt,
                address: nextAddress,
                driver: nextDriver,
                driverLatitude:
                    patch.driverLatitude ?? childOrder.driverLatitude,
                driverLongitude:
                    patch.driverLongitude ?? childOrder.driverLongitude,
                routePoints: patch.routePoints.isNotEmpty
                    ? patch.routePoints
                    : childOrder.routePoints,
                routeDistanceMeters:
                    patch.routeDistanceMeters ?? childOrder.routeDistanceMeters,
                routeDurationSeconds:
                    patch.routeDurationSeconds ??
                    childOrder.routeDurationSeconds,
                items: patchItems.isNotEmpty ? patchItems : childOrder.items,
                fulfillmentType: patchFulfillmentType,
                fulfillmentInventoryCode:
                    patchFulfillmentInventoryCode ??
                    childOrder.fulfillmentInventoryCode,
                parentOrderId: patchParentOrderId ?? childOrder.parentOrderId,
              );
            })
            .toList(growable: false);

        final updatedParent = parentOrder.copyWith(
          childOrders: _sortOrders(nextChildren),
          updatedAt: patch.updatedAt,
        );
        final nextOrders = [...state.orders];
        nextOrders[parentIndex] = updatedParent;
        state = state.copyWith(orders: _sortOrders(nextOrders));
        return;
      }

      final createdOrder = _buildOrderFromPatch(patch);
      if (createdOrder == null) {
        return;
      }

      if (createdOrder.parentOrderId != null) {
        return;
      }

      state = state.copyWith(
        orders: _sortOrders([createdOrder, ...state.orders]),
      );
      return;
    }

    final currentOrder = state.orders[orderIndex];
    final nextDriver = _buildNextDriverSnapshot(
      currentDriver: currentOrder.driver,
      patch: patch,
    );

    final nextAddress = _resolveUpdatedTrackingAddress(
      currentOrder.address,
      patch,
    );

    final updatedOrder = currentOrder.copyWith(
      orderStatus: patch.status ?? currentOrder.orderStatus,
      updatedAt: patch.updatedAt,
      address: nextAddress,
      driver: nextDriver,
      driverLatitude: patch.driverLatitude ?? currentOrder.driverLatitude,
      driverLongitude: patch.driverLongitude ?? currentOrder.driverLongitude,
      routePoints: patch.routePoints.isNotEmpty
          ? patch.routePoints
          : currentOrder.routePoints,
      routeDistanceMeters:
          patch.routeDistanceMeters ?? currentOrder.routeDistanceMeters,
      routeDurationSeconds:
          patch.routeDurationSeconds ?? currentOrder.routeDurationSeconds,
      items: patchItems.isNotEmpty ? patchItems : currentOrder.items,
      childOrders: patchChildOrders.isNotEmpty
          ? patchChildOrders
          : currentOrder.childOrders,
      parentOrderId: patchParentOrderId ?? currentOrder.parentOrderId,
      fulfillmentType: patchFulfillmentType,
      fulfillmentInventoryCode:
          patchFulfillmentInventoryCode ??
          currentOrder.fulfillmentInventoryCode,
    );

    final nextOrders = [...state.orders];
    nextOrders[orderIndex] = updatedOrder;
    state = state.copyWith(orders: _sortOrders(nextOrders));
  }

  DriverSnapshot? _buildNextDriverSnapshot({
    required DriverSnapshot? currentDriver,
    required _LiveOrderPatch patch,
  }) {
    final hasDriverUpdate =
        patch.driverId != null ||
        patch.driverName != null ||
        patch.driverPhone != null ||
        patch.driverVehicleLabel != null ||
        patch.etaMinutes != null;

    if (!hasDriverUpdate) {
      return currentDriver;
    }

    return DriverSnapshot(
      id: patch.driverId ?? currentDriver?.id ?? 'driver-${patch.orderId}',
      name: patch.driverName ?? currentDriver?.name ?? '',
      phone: patch.driverPhone ?? currentDriver?.phone ?? '',
      vehicleLabel:
          patch.driverVehicleLabel ?? currentDriver?.vehicleLabel ?? '',
      etaMinutes: patch.etaMinutes ?? currentDriver?.etaMinutes ?? 0,
    );
  }

  bool _isPayloadForCurrentCustomer(
    Map<String, dynamic> payload,
    String orderId,
  ) {
    final user = state.user;
    if (user == null) {
      return false;
    }

    final payloadCustomerId = _readString(payload, const [
      'customerId',
      'customer_id',
    ]);

    if (payloadCustomerId != null) {
      return payloadCustomerId == user.id;
    }

    for (final order in state.orders) {
      if (order.orderId == orderId) {
        return order.customerId == user.id;
      }
    }

    return false;
  }

  OrderModel? _buildOrderFromPatch(_LiveOrderPatch patch) {
    final user = state.user;
    if (user == null) {
      return null;
    }

    final data = patch.sourceData;
    final customerLocationData = _mapFromKeys(data, const [
      'customerLocation',
      'customer_location',
      'destination',
      'dropoff',
    ]);
    final gasType = _readString(data, const ['gasType', 'gas_type']) ?? '';
    final items = _parseOrderLineItems(data, patch.orderId);
    final childOrders = _parseChildOrders(data);
    final fulfillmentType =
        _readString(data, const ['fulfillmentType', 'fulfillment_type']) ??
        'standalone';
    final fulfillmentInventoryCode = _readString(data, const [
      'fulfillmentInventoryCode',
      'fulfillment_inventory_code',
    ]);
    final parentOrderId = _readString(data, const [
      'parentOrderId',
      'parent_order_id',
    ]);
    final product = _createSummaryProduct(
      orderId: patch.orderId,
      gasType: gasType,
      items: items,
    );
    final quantity =
        _readInt(data, const ['quantity', 'qty']) ??
        _sumLineItemQuantities(items) ??
        _extractQuantityFromGasType(gasType) ??
        1;
    final rawAddress =
        _readString(data, const [
          'addressText',
          'address_text',
          'addressFull',
          'address_full',
          'location',
        ]) ??
        _readString(customerLocationData, const [
          'addressText',
          'address_text',
          'addressFull',
          'address_full',
          'label',
        ]) ??
        '';
    final resolvedAddressBase = _resolveAddressFromLocation(
      rawAddress,
      patch.orderId,
    );
    final resolvedAddress = resolvedAddressBase.copyWith(
      latitude:
          _readDouble(data, const [
            'latitude',
            'customerLatitude',
            'customer_latitude',
          ]) ??
          _readDouble(customerLocationData, const ['lat', 'latitude']) ??
          resolvedAddressBase.latitude,
      longitude:
          _readDouble(data, const [
            'longitude',
            'customerLongitude',
            'customer_longitude',
          ]) ??
          _readDouble(customerLocationData, const [
            'lng',
            'lon',
            'longitude',
            'long',
          ]) ??
          resolvedAddressBase.longitude,
    );
    final paymentMethod = _parsePaymentMethod(
      _readString(data, const ['paymentMethod', 'payment_method']),
    );
    final subtotal =
        _calculateSubtotalFromItems(items) ?? (product.priceOmr * quantity);
    final remoteTotal =
        _parseNumber(data['totalAmount']) ?? _parseNumber(data['total_amount']);
    final double deliveryFee = remoteTotal != null
        ? (remoteTotal - subtotal).clamp(0, double.infinity).toDouble()
        : (_resolveDeliveryFeeFromItems(items) ?? 0.0);
    final double totalPrice = remoteTotal ?? (subtotal + deliveryFee);
    final createdAt =
        _parseDateTime(data['createdAt'] ?? data['created_at']) ??
        patch.updatedAt;

    DriverSnapshot? driver;
    if (patch.driverId != null ||
        patch.driverName != null ||
        patch.driverPhone != null ||
        patch.driverVehicleLabel != null ||
        patch.etaMinutes != null) {
      driver = DriverSnapshot(
        id: patch.driverId ?? 'driver-${patch.orderId}',
        name: patch.driverName ?? '',
        phone: patch.driverPhone ?? '',
        vehicleLabel: patch.driverVehicleLabel ?? '',
        etaMinutes: patch.etaMinutes ?? 0,
      );
    }

    return OrderModel(
      orderId: patch.orderId,
      customerId: user.id,
      customerName:
          _readString(data, const ['name', 'customer_full_name']) ??
          user.fullName,
      phone: _readString(data, const ['phone']) ?? user.phone,
      gasProduct: product,
      quantity: quantity,
      address: resolvedAddress,
      notes: _readString(data, const ['notes']) ?? '',
      paymentMethod: paymentMethod,
      orderStatus: patch.status ?? OrderStatus.pendingReview,
      subtotalPrice: subtotal,
      deliveryFee: deliveryFee,
      totalPrice: totalPrice,
      createdAt: createdAt,
      updatedAt: patch.updatedAt,
      driver: driver,
      driverLatitude: patch.driverLatitude,
      driverLongitude: patch.driverLongitude,
      routePoints: patch.routePoints,
      routeDistanceMeters: patch.routeDistanceMeters,
      routeDurationSeconds: patch.routeDurationSeconds,
      preferredDeliveryWindow: _readString(data, const [
        'preferredDeliveryWindow',
        'preferred_delivery_window',
      ]),
      items: items,
      childOrders: childOrders,
      parentOrderId: parentOrderId,
      fulfillmentType: fulfillmentType,
      fulfillmentInventoryCode: fulfillmentInventoryCode,
    );
  }

  List<OrderLineItem> _parseOrderLineItems(
    Map<String, dynamic> data,
    String orderId,
  ) {
    final rawItems = data['items'] ?? data['orderItems'] ?? data['order_items'];

    if (rawItems is! List) {
      return const <OrderLineItem>[];
    }

    return rawItems
        .map((item) {
          if (item is Map<String, dynamic>) {
            return item;
          }
          if (item is Map) {
            return Map<String, dynamic>.from(item);
          }
          return null;
        })
        .whereType<Map<String, dynamic>>()
        .map((item) {
          final productId =
              item['productId']?.toString() ?? item['product_id']?.toString();
          final mappedProduct = productId == null
              ? null
              : _findProductById(productId);
          return OrderLineItem(
            id: (item['id'] ?? '').toString(),
            orderId: (item['orderId'] ?? item['order_id'] ?? orderId)
                .toString(),
            productId: productId,
            productCode: (item['productCode'] ?? item['product_code'] ?? '')
                .toString(),
            productNameAr:
                (item['productNameAr'] ??
                        item['product_name_ar'] ??
                        mappedProduct?.nameAr ??
                        '')
                    .toString(),
            productNameEn:
                (item['productNameEn'] ??
                        item['product_name_en'] ??
                        mappedProduct?.nameEn ??
                        '')
                    .toString(),
            sizeLabel:
                (item['sizeLabel'] ??
                        item['size_label'] ??
                        mappedProduct?.sizeLabel ??
                        '-')
                    .toString(),
            driverInventoryCode:
                (item['driverInventoryCode'] ??
                        item['driver_inventory_code'] ??
                        '')
                    .toString(),
            quantity: _readInt(item, const ['quantity', 'qty']) ?? 1,
            unitPrice: _parseNumber(item['unitPrice'] ?? item['unit_price']),
            deliveryFee: _parseNumber(
              item['deliveryFee'] ?? item['delivery_fee'],
            ),
            lineTotal: _parseNumber(item['lineTotal'] ?? item['line_total']),
          );
        })
        .toList(growable: false);
  }

  List<OrderModel> _parseChildOrders(Map<String, dynamic> data) {
    final rawChildren = data['childOrders'] ?? data['child_orders'];

    if (rawChildren is! List) {
      return const <OrderModel>[];
    }

    final children = <OrderModel>[];
    for (final child in rawChildren) {
      final childMap = child is Map<String, dynamic>
          ? child
          : child is Map
          ? Map<String, dynamic>.from(child)
          : null;
      if (childMap == null) {
        continue;
      }
      final childPatch = _parseLiveOrderPatch(childMap);
      if (childPatch == null) {
        continue;
      }
      final childOrder = _buildOrderFromPatch(childPatch);
      if (childOrder != null) {
        children.add(childOrder);
      }
    }

    return _sortOrders(children);
  }

  GasProduct _createSummaryProduct({
    required String orderId,
    required String gasType,
    required List<OrderLineItem> items,
  }) {
    if (items.length == 1) {
      final singleItem = items.first;
      final mappedProduct = singleItem.productId == null
          ? null
          : _findProductById(singleItem.productId!);

      if (mappedProduct != null) {
        return mappedProduct;
      }

      return GasProduct(
        id: singleItem.productId ?? 'remote-product-$orderId',
        nameAr: singleItem.productNameAr,
        nameEn: singleItem.productNameEn,
        sizeLabel: singleItem.sizeLabel,
        priceOmr: singleItem.unitPrice ?? 0,
        deliveryFeeOmr: singleItem.deliveryFee ?? 0,
        subtitleAr: 'عنصر طلب مفرد من النظام المباشر',
        subtitleEn: 'Single order item from live backend',
      );
    }

    return _resolveProductFromGasType(gasType, orderId, items: items);
  }

  double? _calculateSubtotalFromItems(List<OrderLineItem> items) {
    if (items.isEmpty) {
      return null;
    }

    return items.fold<double>(
      0,
      (sum, item) =>
          sum + (item.lineTotal ?? ((item.unitPrice ?? 0) * item.quantity)),
    );
  }

  double? _resolveDeliveryFeeFromItems(List<OrderLineItem> items) {
    if (items.isEmpty) {
      return null;
    }

    return items
        .map((item) => item.deliveryFee ?? 0)
        .fold<double>(0, (maxFee, fee) => fee > maxFee ? fee : maxFee);
  }

  int? _sumLineItemQuantities(List<OrderLineItem> items) {
    if (items.isEmpty) {
      return null;
    }

    return items.fold<int>(0, (sum, item) => sum + item.quantity);
  }

  GasProduct? _findProductById(String productId) {
    for (final product in state.products) {
      if (product.id == productId) {
        return product;
      }
    }

    return null;
  }

  AddressModel _resolveUpdatedTrackingAddress(
    AddressModel currentAddress,
    _LiveOrderPatch patch,
  ) {
    final nextLatitude = patch.customerLatitude ?? currentAddress.latitude;
    final nextLongitude = patch.customerLongitude ?? currentAddress.longitude;
    final nextRawAddress =
        patch.addressFull ?? patch.addressText ?? currentAddress.fullAddress;

    final resolvedAddress = _resolveAddressFromLocation(
      nextRawAddress,
      patch.orderId,
    );

    return currentAddress.copyWith(
      label: resolvedAddress.label,
      governorate: resolvedAddress.governorate,
      wilayat: resolvedAddress.wilayat,
      area: resolvedAddress.area,
      street: resolvedAddress.street,
      houseNumber: resolvedAddress.houseNumber,
      landmark: resolvedAddress.landmark,
      latitude: nextLatitude,
      longitude: nextLongitude,
    );
  }

  GasProduct _resolveProductFromGasType(
    String gasType,
    String orderId, {
    List<OrderLineItem> items = const [],
  }) {
    final normalizedGasType = gasType.trim();
    final looksBundled =
        items.length > 1 ||
        normalizedGasType.contains(' + ') ||
        normalizedGasType.contains('|') ||
        RegExp(
              r'x\s*\d+',
              caseSensitive: false,
            ).allMatches(normalizedGasType).length >
            1;

    if (!looksBundled) {
      for (final product in state.products) {
        final nameAr = product.nameAr.toLowerCase();
        final nameEn = product.nameEn.toLowerCase();
        final sample = normalizedGasType.toLowerCase();

        if (sample.contains(nameAr) || sample.contains(nameEn)) {
          return product;
        }
      }
    }

    final fallbackName = normalizedGasType.isEmpty
        ? (items.isNotEmpty
              ? items
                    .map((item) => '${item.productNameAr} x${item.quantity}')
                    .join(' + ')
              : (state.products.isNotEmpty
                    ? state.products.first.nameAr
                    : 'أسطوانة'))
        : normalizedGasType;

    return GasProduct(
      id: 'remote-product-$orderId',
      nameAr: fallbackName,
      nameEn: fallbackName,
      sizeLabel: '-',
      priceOmr: 0,
      subtitleAr: 'تم استلامه من النظام المباشر',
      subtitleEn: 'Received from live backend',
    );
  }

  String _buildBundledOrderNotes({
    required List<BundledOrderItem> items,
    required double subtotal,
    required double deliveryFee,
    required double totalPrice,
  }) {
    final isArabic = state.language == AppLanguage.ar;
    final itemLines = items
        .map(
          (item) =>
              '- ${item.product.localizedName(isArabic)} x${item.quantity} = ${(item.product.priceOmr * item.quantity).toStringAsFixed(3)}',
        )
        .join('\n');
    final totalQuantity = items.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );

    if (isArabic) {
      return 'طلب مجمع\n'
          '$itemLines\n'
          'إجمالي الأسطوانات: $totalQuantity\n'
          'المجموع الفرعي: ${subtotal.toStringAsFixed(3)} ر.ع\n'
          'رسوم التوصيل: ${deliveryFee.toStringAsFixed(3)} ر.ع\n'
          'الإجمالي: ${totalPrice.toStringAsFixed(3)} ر.ع';
    }

    return 'Bundled order\n'
        '$itemLines\n'
        'Total cylinders: $totalQuantity\n'
        'Subtotal: ${subtotal.toStringAsFixed(3)} OMR\n'
        'Delivery fee: ${deliveryFee.toStringAsFixed(3)} OMR\n'
        'Total: ${totalPrice.toStringAsFixed(3)} OMR';
  }

  AddressModel _resolveAddressFromLocation(String rawAddress, String orderId) {
    final cleanedAddress = rawAddress.trim();
    final normalizedAddress = _normalizedAddressSignature(cleanedAddress);

    for (final address in state.addresses) {
      if (normalizedAddress.isNotEmpty &&
          _normalizedAddressSignature(address.fullAddress) ==
              normalizedAddress) {
        return address;
      }
    }

    if (cleanedAddress.isEmpty) {
      final defaultAddress = state.defaultAddress;
      if (defaultAddress != null) {
        return defaultAddress;
      }

      if (state.addresses.isNotEmpty) {
        return state.addresses.first;
      }
    }

    final parts = cleanedAddress.isEmpty
        ? const <String>[]
        : _splitAddressParts(cleanedAddress);

    final fallbackLabel = state.language == AppLanguage.ar
        ? 'عنوان الطلب'
        : 'Order address';
    final governorate = parts.isNotEmpty ? parts.first : fallbackLabel;
    final wilayat = parts.length > 1 ? parts[1] : governorate;
    final area = parts.length > 2
        ? parts[2]
        : parts.isNotEmpty
        ? parts.last
        : fallbackLabel;
    final street = parts.length > 3 ? parts[3] : area;
    final houseNumber = parts.length > 4 ? parts[4] : '-';
    final landmark = parts.isNotEmpty ? parts.last : area;

    return AddressModel(
      id: 'remote-address-$orderId',
      label: parts.isNotEmpty ? parts.last : fallbackLabel,
      governorate: governorate,
      wilayat: wilayat,
      area: area,
      street: street,
      houseNumber: houseNumber,
      landmark: landmark,
      latitude: 23.5880,
      longitude: 58.3829,
    );
  }

  PaymentMethod _parsePaymentMethod(String? rawPaymentMethod) {
    final value = rawPaymentMethod?.toLowerCase().trim();

    if (value == 'online' ||
        value == 'card' ||
        value == 'wallet' ||
        value == 'digital_wallet' ||
        value == 'digitalwallet') {
      return PaymentMethod.digitalWallet;
    }

    return PaymentMethod.cashOnDelivery;
  }

  int? _extractQuantityFromGasType(String gasType) {
    final match = RegExp(
      r'x\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(gasType);
    if (match == null) {
      return null;
    }

    return int.tryParse(match.group(1) ?? '');
  }

  double? _parseNumber(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value == null) {
      return null;
    }

    return double.tryParse(value.toString());
  }

  GasProduct? _mapProductFromBackend(Map<String, dynamic>? raw) {
    if (raw == null) {
      return null;
    }

    final id = _readString(raw, const ['id', 'code']);
    final rawNameAr = _readString(raw, const ['name_ar', 'nameAr']);
    final rawNameEn = _readString(raw, const ['name_en', 'nameEn']);
    final rawSizeLabel = _readString(raw, const ['size_label', 'sizeLabel']);
    final price = _parseNumber(raw['price']);
    final isAvailable =
        _readBool(raw, const ['is_available', 'isAvailable']) ?? true;
    final deliveryFee =
        _parseNumber(raw['delivery_fee']) ??
        state.runtimeSettings.defaultDeliveryFee;
    final notes = _readString(raw, const [
      'operational_notes',
      'operationalNotes',
    ]);

    if (id == null ||
        rawNameAr == null ||
        rawNameEn == null ||
        rawSizeLabel == null) {
      return null;
    }

    final normalizedSize = _normalizeCylinderSize(
      id: id,
      nameAr: rawNameAr,
      nameEn: rawNameEn,
      sizeLabel: rawSizeLabel,
    );

    return GasProduct(
      id: id,
      nameAr:
          '\u0623\u0633\u0637\u0648\u0627\u0646\u0629 $normalizedSize \u0643\u064a\u0644\u0648',
      nameEn: '$normalizedSize kg Cylinder',
      sizeLabel: '$normalizedSize kg',
      priceOmr: price ?? 0,
      deliveryFeeOmr: deliveryFee,
      isAvailable: isAvailable,
      subtitleAr: notes ?? _normalizedCylinderSubtitleAr(normalizedSize),
      subtitleEn: _normalizedCylinderSubtitleEn(normalizedSize),
    );
  }

  String _normalizeCylinderSize({
    required String id,
    required String nameAr,
    required String nameEn,
    required String sizeLabel,
  }) {
    final normalizedId = id.toLowerCase();
    final normalizedAr = nameAr.toLowerCase();
    final normalizedEn = nameEn.toLowerCase();
    final normalizedSize = sizeLabel.toLowerCase();

    if (normalizedSize.contains('11') ||
        normalizedSize.contains('22') ||
        normalizedSize.contains('44')) {
      return normalizedSize.replaceAll(RegExp(r'[^0-9]'), '');
    }

    if (normalizedId.contains('001') ||
        normalizedAr.contains('\u0645\u0646\u0632\u0644') ||
        normalizedEn.contains('home') ||
        normalizedSize.contains('20')) {
      return '11';
    }

    if (normalizedId.contains('002') ||
        normalizedAr.contains('\u062a\u062c\u0627\u0631') ||
        normalizedEn.contains('commercial') ||
        normalizedSize.contains('35')) {
      return '22';
    }

    if (normalizedId.contains('003') ||
        normalizedAr.contains('\u0627\u062d\u062a\u064a\u0627\u0637') ||
        normalizedEn.contains('reserve') ||
        normalizedSize.contains('15')) {
      return '44';
    }

    return '11';
  }

  String _normalizedCylinderSubtitleAr(String size) {
    switch (size) {
      case '11':
        return '\u0645\u0646\u0627\u0633\u0628\u0629 \u0644\u0644\u0627\u0633\u062a\u062e\u062f\u0627\u0645 \u0627\u0644\u0645\u0646\u0632\u0644\u064a \u0627\u0644\u064a\u0648\u0645\u064a.';
      case '22':
        return '\u062e\u064a\u0627\u0631 \u0623\u0643\u0628\u0631 \u0644\u0644\u0645\u0646\u0627\u0632\u0644 \u0648\u0627\u0644\u0645\u0637\u0627\u0628\u062e \u0630\u0627\u062a \u0627\u0644\u0627\u0633\u062a\u0647\u0644\u0627\u0643 \u0627\u0644\u0623\u0639\u0644\u0649.';
      case '44':
        return '\u0645\u0646\u0627\u0633\u0628\u0629 \u0644\u0644\u0623\u0646\u0634\u0637\u0629 \u0627\u0644\u062a\u062c\u0627\u0631\u064a\u0629 \u0648\u0627\u0644\u0627\u0633\u062a\u062e\u062f\u0627\u0645 \u0627\u0644\u0645\u0643\u062b\u0641.';
      default:
        return '\u0645\u062a\u0648\u0641\u0631 \u0636\u0645\u0646 \u0627\u0644\u062a\u062d\u062f\u064a\u062b\u0627\u062a \u0627\u0644\u0645\u0628\u0627\u0634\u0631\u0629.';
    }
  }

  String _normalizedCylinderSubtitleEn(String size) {
    switch (size) {
      case '11':
        return 'Suitable for everyday home use.';
      case '22':
        return 'A larger option for homes and higher-consumption kitchens.';
      case '44':
        return 'Suitable for commercial and heavy-duty use.';
      default:
        return 'Available from live backend updates.';
    }
  }

  AddressModel? _mapAddressFromZone(Map<String, dynamic>? raw) {
    if (raw == null) {
      return null;
    }

    final id = _readString(raw, const ['id', 'code']);
    final nameAr = _readString(raw, const ['name_ar', 'nameAr']);
    final nameEn = _readString(raw, const ['name_en', 'nameEn']);
    final governorate = _readString(raw, const ['governorate']);
    final isActive = _readBool(raw, const ['is_active', 'isActive']) ?? true;

    if (!isActive || id == null || governorate == null) {
      return null;
    }

    final localizedName = nameAr ?? nameEn ?? 'منطقة التوصيل';

    return AddressModel(
      id: 'zone-$id',
      label: localizedName,
      governorate: governorate,
      wilayat: localizedName,
      area: localizedName,
      street:
          _readString(raw, const ['operational_notes', 'operationalNotes']) ??
          localizedName,
      houseNumber: '-',
      landmark: localizedName,
      latitude: 23.5880,
      longitude: 58.3829,
    );
  }

  AppRuntimeSettings? _mapRuntimeSettingsFromBackend(
    Map<String, dynamic>? raw,
  ) {
    if (raw == null) {
      return null;
    }

    return AppRuntimeSettings(
      systemName:
          _readString(raw, const ['system_name', 'systemName']) ??
          state.runtimeSettings.systemName,
      supportPhone:
          _readString(raw, const ['support_phone', 'supportPhone']) ??
          state.runtimeSettings.supportPhone,
      defaultLanguageCode:
          _readString(raw, const ['default_language', 'defaultLanguage']) ??
          state.runtimeSettings.defaultLanguageCode,
      currencyCode:
          _readString(raw, const ['currency_code', 'currencyCode']) ??
          state.runtimeSettings.currencyCode,
      defaultDeliveryFee:
          _parseNumber(raw['default_delivery_fee']) ??
          state.runtimeSettings.defaultDeliveryFee,
      orderIntakeEnabled:
          _readBool(raw, const [
            'order_intake_enabled',
            'orderIntakeEnabled',
          ]) ??
          state.runtimeSettings.orderIntakeEnabled,
      notificationsEnabled:
          _readBool(raw, const [
            'notifications_enabled',
            'notificationsEnabled',
          ]) ??
          state.runtimeSettings.notificationsEnabled,
      maintenanceMode:
          _readBool(raw, const ['maintenance_mode', 'maintenanceMode']) ??
          state.runtimeSettings.maintenanceMode,
      systemMessage:
          _readString(raw, const ['system_message', 'systemMessage']) ??
          state.runtimeSettings.systemMessage,
    );
  }

  AddressModel _buildCurrentLocationAddress(DeviceLocationSnapshot snapshot) {
    final placemark = snapshot.placemark;
    final latitudeText = snapshot.latitude.toStringAsFixed(6);
    final longitudeText = snapshot.longitude.toStringAsFixed(6);

    final governorate =
        _firstNonEmpty([
          placemark?.administrativeArea,
          placemark?.subAdministrativeArea,
          placemark?.country,
        ]) ??
        (state.language == AppLanguage.ar
            ? 'موقعي الحالي'
            : 'Current location');
    final wilayat =
        _firstNonEmpty([
          placemark?.subAdministrativeArea,
          placemark?.locality,
          placemark?.subLocality,
        ]) ??
        governorate;
    final area =
        _firstNonEmpty([
          placemark?.subLocality,
          placemark?.locality,
          placemark?.name,
        ]) ??
        '$latitudeText, $longitudeText';
    final street =
        _firstNonEmpty([
          placemark?.street,
          placemark?.thoroughfare,
          placemark?.name,
        ]) ??
        (state.language == AppLanguage.ar
            ? 'تم تحديده عبر GPS'
            : 'Detected by GPS');
    final houseNumber =
        _firstNonEmpty([placemark?.subThoroughfare, placemark?.name]) ?? '-';
    final landmark =
        _firstNonEmpty([
          placemark?.name,
          placemark?.street,
          placemark?.locality,
        ]) ??
        '$latitudeText, $longitudeText';

    return AddressModel(
      id: AddressModel.currentLocationId,
      label:
          _firstNonEmpty([
            placemark?.subLocality,
            placemark?.locality,
            placemark?.street,
          ]) ??
          (state.language == AppLanguage.ar
              ? 'موقعي الحالي'
              : 'My current location'),
      governorate: governorate,
      wilayat: wilayat,
      area: area,
      street: street,
      houseNumber: houseNumber,
      landmark: landmark,
      latitude: snapshot.latitude,
      longitude: snapshot.longitude,
      isDefault: true,
    );
  }

  String _fallbackSavedAddressId() {
    for (final address in MockData.addresses) {
      if (address.isDefault) {
        return address.id;
      }
    }

    return MockData.addresses.first.id;
  }

  bool _shouldKeepCurrentLocationAddress(AddressModel? address) {
    if (address == null) {
      return false;
    }

    if (!address.isCurrentLocation) {
      return true;
    }

    return _isCoordinateWithinOman(address.latitude, address.longitude) ||
        _containsOmanMarker([
          address.governorate,
          address.wilayat,
          address.area,
          address.street,
          address.landmark,
        ]);
  }

  bool _isLocationWithinOman(DeviceLocationSnapshot snapshot) {
    if (_isCoordinateWithinOman(snapshot.latitude, snapshot.longitude)) {
      return true;
    }

    final placemark = snapshot.placemark;
    return _containsOmanMarker([
      placemark?.isoCountryCode,
      placemark?.country,
      placemark?.administrativeArea,
      placemark?.subAdministrativeArea,
    ]);
  }

  bool _isCoordinateWithinOman(double latitude, double longitude) {
    return latitude >= _omanLatitudeMin &&
        latitude <= _omanLatitudeMax &&
        longitude >= _omanLongitudeMin &&
        longitude <= _omanLongitudeMax;
  }

  bool _containsOmanMarker(Iterable<String?> values) {
    for (final value in values) {
      final normalized = _normalizeLocationText(value);
      if (normalized.isEmpty) {
        continue;
      }

      if (normalized == 'om' ||
          normalized == 'oman' ||
          normalized.contains('oman') ||
          normalized == 'عمان' ||
          normalized.contains('سلطنةعمان')) {
        return true;
      }
    }

    return false;
  }

  String _normalizeLocationText(String? value) {
    if (value == null) {
      return '';
    }

    return value.trim().toLowerCase().replaceAll(RegExp(r'[\s\-_،,]'), '');
  }

  List<String> _splitAddressParts(String rawAddress) {
    final parts = <String>[];
    final seen = <String>{};

    for (final item in rawAddress.split(RegExp(r'[,،]'))) {
      final trimmed = item.trim();
      final normalized = _normalizeLocationText(trimmed);
      if (trimmed.isEmpty || normalized.isEmpty || !seen.add(normalized)) {
        continue;
      }

      parts.add(trimmed);
    }

    return parts;
  }

  String _normalizedAddressSignature(String rawAddress) {
    final parts = _splitAddressParts(rawAddress);
    if (parts.isEmpty) {
      return _normalizeLocationText(rawAddress);
    }

    return parts.map(_normalizeLocationText).join('|');
  }

  List<AddressModel> _mergeAddresses(
    Iterable<AddressModel> primary,
    Iterable<AddressModel> secondary,
  ) {
    final merged = <AddressModel>[];
    final seenIds = <String>{};

    for (final address in [...primary, ...secondary]) {
      if (!seenIds.add(address.id)) {
        continue;
      }
      merged.add(address);
    }

    return merged;
  }

  String? _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      if (value == null) {
        continue;
      }

      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }

    return null;
  }

  List<OrderModel> _sortOrders(Iterable<OrderModel> orders) {
    final items = List<OrderModel>.from(orders);
    items.sort(_compareOrders);
    return items;
  }

  int _compareOrders(OrderModel left, OrderModel right) {
    final updatedCompare = right.updatedAt.compareTo(left.updatedAt);
    if (updatedCompare != 0) {
      return updatedCompare;
    }

    return right.createdAt.compareTo(left.createdAt);
  }

  Map<String, dynamic> _flattenPayload(Map<String, dynamic> payload) {
    final data = <String, dynamic>{}..addAll(payload);

    for (final key in const ['payload', 'data', 'order']) {
      final nested = _mapFrom(payload[key]);
      if (nested != null) {
        data.addAll(nested);
      }
    }

    return data;
  }

  Map<String, dynamic>? _mapFromKeys(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final nested = _mapFrom(data[key]);
      if (nested != null) {
        return nested;
      }
    }

    return null;
  }

  Map<String, dynamic>? _mapFrom(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }

    if (value is List && value.isNotEmpty) {
      return _mapFrom(value.first);
    }

    return null;
  }

  List<TrackingRoutePoint> _readRoutePoints(
    Map<String, dynamic>? data,
    Map<String, dynamic>? trackingRouteData,
  ) {
    final rawPoints =
        data?['routePoints'] ??
        data?['route_points'] ??
        trackingRouteData?['points'] ??
        trackingRouteData?['routePoints'] ??
        trackingRouteData?['route_points'];

    if (rawPoints is! List) {
      return const <TrackingRoutePoint>[];
    }

    final points = <TrackingRoutePoint>[];

    for (final item in rawPoints) {
      final map = _mapFrom(item);
      if (map == null) {
        continue;
      }

      final latitude = _readDouble(map, const ['latitude', 'lat', 'y']);
      final longitude = _readDouble(map, const [
        'longitude',
        'lng',
        'lon',
        'long',
        'x',
      ]);

      if (latitude == null || longitude == null) {
        continue;
      }

      points.add(TrackingRoutePoint(latitude: latitude, longitude: longitude));
    }

    return points;
  }

  String? _resolveOrderId(Map<String, dynamic> data) {
    final raw = _readString(data, const [
      'orderId',
      'order_id',
      'currentOrderId',
      'current_order_id',
      'id',
    ]);
    if (raw == null) {
      return null;
    }

    final candidates = <String>[
      raw,
      if (!raw.toUpperCase().startsWith('ORD-')) 'ORD-$raw',
    ];

    for (final candidate in candidates) {
      for (final order in state.orders) {
        if (order.orderId == candidate) {
          return candidate;
        }
      }
    }

    if (raw.toUpperCase().startsWith('ORD-')) {
      return raw;
    }

    return 'ORD-$raw';
  }

  String? _readString(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) {
      return null;
    }

    for (final key in keys) {
      final value = data[key];
      if (value == null) {
        continue;
      }

      final text = value.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }

    return null;
  }

  double? _readDouble(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) {
      return null;
    }

    for (final key in keys) {
      final value = data[key];
      if (value is num) {
        return value.toDouble();
      }

      if (value == null) {
        continue;
      }

      final parsed = double.tryParse(value.toString());
      if (parsed != null) {
        return parsed;
      }
    }

    return null;
  }

  int? _readInt(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) {
      return null;
    }

    for (final key in keys) {
      final value = data[key];
      if (value is int) {
        return value;
      }

      if (value is num) {
        return value.round();
      }

      if (value == null) {
        continue;
      }

      final parsed = int.tryParse(value.toString());
      if (parsed != null) {
        return parsed;
      }
    }

    return null;
  }

  bool? _readBool(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) {
      return null;
    }

    for (final key in keys) {
      final value = data[key];
      if (value is bool) {
        return value;
      }

      if (value == null) {
        continue;
      }

      final text = value.toString().trim().toLowerCase();
      if (text == 'true' || text == '1' || text == 'yes') {
        return true;
      }
      if (text == 'false' || text == '0' || text == 'no') {
        return false;
      }
    }

    return null;
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    }

    if (value == null) {
      return null;
    }

    final raw = value.toString().trim();
    if (raw.isEmpty) {
      return null;
    }

    final epoch = int.tryParse(raw);
    if (epoch != null) {
      return DateTime.fromMillisecondsSinceEpoch(
        raw.length > 10 ? epoch : epoch * 1000,
      );
    }

    return DateTime.tryParse(raw);
  }

  OrderStatus? _parseStatus(String? rawStatus) {
    if (rawStatus == null) {
      return null;
    }

    switch (rawStatus.trim().toLowerCase().replaceAll('-', '_')) {
      case 'searching_driver':
        return OrderStatus.searchingDriver;
      case 'driver_notified':
        return OrderStatus.driverNotified;
      case 'no_driver_found':
        return OrderStatus.noDriverFound;
      case 'pending':
      case 'pending_review':
      case 'pendingreview':
      case 'reviewing':
        return OrderStatus.pendingReview;
      case 'accepted':
      case 'confirmed':
        return OrderStatus.accepted;
      case 'preparing':
      case 'preparation':
        return OrderStatus.preparing;
      case 'on_the_way':
      case 'ontheway':
      case 'out_for_delivery':
      case 'driver_on_the_way':
      case 'en_route':
        return OrderStatus.onTheWay;
      case 'delivered':
      case 'completed':
        return OrderStatus.delivered;
      case 'cancelled':
      case 'canceled':
        return OrderStatus.cancelled;
    }

    return null;
  }
}

class _LiveOrderPatch {
  const _LiveOrderPatch({
    required this.orderId,
    required this.sourceData,
    required this.updatedAt,
    this.routePoints = const [],
    this.status,
    this.customerLatitude,
    this.customerLongitude,
    this.addressText,
    this.addressFull,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.driverVehicleLabel,
    this.etaMinutes,
    this.driverLatitude,
    this.driverLongitude,
    this.routeDistanceMeters,
    this.routeDurationSeconds,
  });

  final String orderId;
  final Map<String, dynamic> sourceData;
  final DateTime updatedAt;
  final List<TrackingRoutePoint> routePoints;
  final OrderStatus? status;
  final double? customerLatitude;
  final double? customerLongitude;
  final String? addressText;
  final String? addressFull;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final String? driverVehicleLabel;
  final int? etaMinutes;
  final double? driverLatitude;
  final double? driverLongitude;
  final int? routeDistanceMeters;
  final int? routeDurationSeconds;
}
