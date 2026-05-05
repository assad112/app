import 'package:customer_app/shared/localization/app_copy.dart';
import 'package:customer_app/shared/models/app_runtime_settings.dart';
import 'package:customer_app/shared/models/address_model.dart';
import 'package:customer_app/shared/models/gas_product.dart';
import 'package:customer_app/shared/models/order_model.dart';
import 'package:customer_app/shared/models/user_profile.dart';

class CustomerAppState {
  const CustomerAppState({
    required this.isInitialized,
    required this.isAuthenticated,
    required this.isBusy,
    required this.isResolvingCurrentLocation,
    required this.lastAuthErrorMessage,
    required this.lastOrderSubmissionErrorMessage,
    required this.language,
    required this.products,
    required this.addresses,
    required this.orders,
    required this.runtimeSettings,
    this.user,
  });

  factory CustomerAppState.initial() {
    return const CustomerAppState(
      isInitialized: false,
      isAuthenticated: false,
      isBusy: false,
      isResolvingCurrentLocation: false,
      lastAuthErrorMessage: null,
      lastOrderSubmissionErrorMessage: null,
      language: AppLanguage.ar,
      products: [],
      addresses: [],
      orders: [],
      runtimeSettings: AppRuntimeSettings.fallback(),
    );
  }

  final bool isInitialized;
  final bool isAuthenticated;
  final bool isBusy;
  final bool isResolvingCurrentLocation;
  final String? lastAuthErrorMessage;
  final String? lastOrderSubmissionErrorMessage;
  final AppLanguage language;
  final List<GasProduct> products;
  final List<AddressModel> addresses;
  final List<OrderModel> orders;
  final AppRuntimeSettings runtimeSettings;
  final UserProfile? user;

  AddressModel? get defaultAddress {
    if (user == null || addresses.isEmpty) {
      return null;
    }

    for (final address in addresses) {
      if (address.id == user!.defaultAddressId) {
        return address;
      }
    }

    return addresses.first;
  }

  OrderModel? get latestOrder => orders.isEmpty ? null : orders.first;

  CustomerAppState copyWith({
    bool? isInitialized,
    bool? isAuthenticated,
    bool? isBusy,
    bool? isResolvingCurrentLocation,
    String? lastAuthErrorMessage,
    String? lastOrderSubmissionErrorMessage,
    AppLanguage? language,
    List<GasProduct>? products,
    List<AddressModel>? addresses,
    List<OrderModel>? orders,
    AppRuntimeSettings? runtimeSettings,
    UserProfile? user,
    bool clearUser = false,
    bool clearLastAuthErrorMessage = false,
    bool clearLastOrderSubmissionErrorMessage = false,
  }) {
    return CustomerAppState(
      isInitialized: isInitialized ?? this.isInitialized,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isBusy: isBusy ?? this.isBusy,
      isResolvingCurrentLocation:
          isResolvingCurrentLocation ?? this.isResolvingCurrentLocation,
      lastAuthErrorMessage: clearLastAuthErrorMessage
          ? null
          : lastAuthErrorMessage ?? this.lastAuthErrorMessage,
      lastOrderSubmissionErrorMessage: clearLastOrderSubmissionErrorMessage
          ? null
          : lastOrderSubmissionErrorMessage ??
                this.lastOrderSubmissionErrorMessage,
      language: language ?? this.language,
      products: products ?? this.products,
      addresses: addresses ?? this.addresses,
      orders: orders ?? this.orders,
      runtimeSettings: runtimeSettings ?? this.runtimeSettings,
      user: clearUser ? null : user ?? this.user,
    );
  }
}
