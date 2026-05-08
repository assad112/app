import 'package:driver_app/shared/models/delivery_order.dart';

class OrdersState {
  const OrdersState({
    required this.isLoading,
    required this.hasLoaded,
    required this.isRefreshing,
    required this.errorMessage,
    required this.availableOrders,
    required this.activeOrders,
    required this.historyOrders,
    required this.pendingOrderIds,
  });

  const OrdersState.initial()
    : isLoading = false,
      hasLoaded = false,
      isRefreshing = false,
      errorMessage = null,
      availableOrders = const [],
      activeOrders = const [],
      historyOrders = const [],
      pendingOrderIds = const <String>{};

  final bool isLoading;
  final bool hasLoaded;
  final bool isRefreshing;
  final String? errorMessage;
  final List<DeliveryOrder> availableOrders;
  final List<DeliveryOrder> activeOrders;
  final List<DeliveryOrder> historyOrders;
  final Set<String> pendingOrderIds;

  OrdersState copyWith({
    bool? isLoading,
    bool? hasLoaded,
    bool? isRefreshing,
    String? errorMessage,
    List<DeliveryOrder>? availableOrders,
    List<DeliveryOrder>? activeOrders,
    List<DeliveryOrder>? historyOrders,
    Set<String>? pendingOrderIds,
    bool clearError = false,
  }) {
    return OrdersState(
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      availableOrders: availableOrders ?? this.availableOrders,
      activeOrders: activeOrders ?? this.activeOrders,
      historyOrders: historyOrders ?? this.historyOrders,
      pendingOrderIds: pendingOrderIds ?? this.pendingOrderIds,
    );
  }
}
