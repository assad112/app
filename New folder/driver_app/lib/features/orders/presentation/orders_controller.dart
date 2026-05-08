import 'package:driver_app/features/auth/presentation/auth_controller.dart';
import 'package:driver_app/features/earnings/presentation/earnings_controller.dart';
import 'package:driver_app/features/home/presentation/home_controller.dart';
import 'package:driver_app/features/notifications/presentation/notifications_controller.dart';
import 'package:driver_app/features/orders/data/orders_repository.dart';
import 'package:driver_app/features/orders/presentation/orders_state.dart';
import 'package:driver_app/shared/models/delivery_order.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final ordersControllerProvider =
    NotifierProvider<OrdersController, OrdersState>(OrdersController.new);

final orderDetailsProvider = FutureProvider.family<DeliveryOrder, String>((
  ref,
  orderId,
) async {
  final ordersState = ref.watch(ordersControllerProvider);

  for (final collection in [
    ordersState.activeOrders,
    ordersState.availableOrders,
    ordersState.historyOrders,
  ]) {
    for (final order in collection) {
      if (order.id == orderId) {
        return order;
      }
    }
  }

  return ref.read(ordersRepositoryProvider).fetchOrderDetails(orderId);
});

class OrdersController extends Notifier<OrdersState> {
  @override
  OrdersState build() {
    return const OrdersState.initial();
  }

  Future<void> ensureLoaded() async {
    if (state.hasLoaded || state.isLoading) {
      return;
    }

    await refreshAll();
  }

  Future<void> refreshAll({bool silent = false}) async {
    state = state.copyWith(
      isLoading: !silent,
      isRefreshing: silent,
      clearError: true,
    );

    try {
      final repository = ref.read(ordersRepositoryProvider);
      final results = await Future.wait([
        repository.fetchAvailableOrders(),
        repository.fetchActiveOrders(),
        repository.fetchHistory(),
      ]);

      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        hasLoaded: true,
        availableOrders: results[0],
        activeOrders: results[1],
        historyOrders: results[2],
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        hasLoaded: true,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> refreshAvailable({String? search}) async {
    final repository = ref.read(ordersRepositoryProvider);
    final availableOrders = await repository.fetchAvailableOrders(
      search: search,
    );
    state = state.copyWith(availableOrders: availableOrders, hasLoaded: true);
  }

  Future<void> refreshHistory({String? search}) async {
    final repository = ref.read(ordersRepositoryProvider);
    final historyOrders = await repository.fetchHistory(search: search);
    state = state.copyWith(historyOrders: historyOrders, hasLoaded: true);
  }

  Future<void> acceptOrder(String orderId) async {
    await _runMutation(orderId, () async {
      final order = await ref
          .read(ordersRepositoryProvider)
          .acceptOrder(orderId);
      _applyOrderUpdate(order);
      await _refreshLinkedViews();
    });
  }

  Future<void> rejectOrder(String orderId, {String? reason}) async {
    await _runMutation(orderId, () async {
      await ref
          .read(ordersRepositoryProvider)
          .rejectOrder(orderId, reason: reason);
      state = state.copyWith(
        availableOrders: state.availableOrders
            .where((order) => order.id != orderId)
            .toList(),
      );
      await _refreshLinkedViews();
    });
  }

  Future<void> updateStage({
    required String orderId,
    required String stage,
  }) async {
    await _runMutation(orderId, () async {
      final order = await ref
          .read(ordersRepositoryProvider)
          .updateOrderStage(orderId: orderId, stage: stage);
      _applyOrderUpdate(order);
      await _refreshLinkedViews();
    });
  }

  void handleRealtime(DeliveryOrder order) {
    _applyOrderUpdate(order);
  }

  Future<void> _runMutation(
    String orderId,
    Future<void> Function() action,
  ) async {
    state = state.copyWith(
      pendingOrderIds: {...state.pendingOrderIds, orderId},
      clearError: true,
    );

    try {
      await action();
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
      rethrow;
    } finally {
      final pending = {...state.pendingOrderIds}..remove(orderId);
      state = state.copyWith(pendingOrderIds: pending);
    }
  }

  void _applyOrderUpdate(DeliveryOrder order) {
    List<DeliveryOrder> upsert(
      List<DeliveryOrder> orders,
      DeliveryOrder nextOrder,
    ) {
      final index = orders.indexWhere((item) => item.id == nextOrder.id);

      if (index == -1) {
        return [nextOrder, ...orders];
      }

      final updated = [...orders];
      updated[index] = nextOrder;
      return updated;
    }

    List<DeliveryOrder> remove(List<DeliveryOrder> orders, String orderId) {
      return orders.where((item) => item.id != orderId).toList();
    }

    final currentDriverId = ref.read(authControllerProvider).driver?.id;
    final belongsToCurrentDriver =
        currentDriverId != null && order.assignedDriverId == currentDriverId;
    final isOfferForCurrentDriver = order.isOfferForDriver(currentDriverId);

    var availableOrders = remove(state.availableOrders, order.id);
    var activeOrders = remove(state.activeOrders, order.id);
    var historyOrders = remove(state.historyOrders, order.id);

    if (isOfferForCurrentDriver) {
      availableOrders = upsert(availableOrders, order);
    } else if (belongsToCurrentDriver && order.isActive) {
      activeOrders = upsert(activeOrders, order);
    } else if (belongsToCurrentDriver &&
        (order.isCompleted || order.isCancelled)) {
      historyOrders = upsert(historyOrders, order);
    }

    state = state.copyWith(
      availableOrders: availableOrders,
      activeOrders: activeOrders,
      historyOrders: historyOrders,
      hasLoaded: true,
    );
  }

  Future<void> _refreshLinkedViews() async {
    ref.invalidate(homeControllerProvider);
    ref.invalidate(earningsControllerProvider);
    await ref.read(notificationsControllerProvider.notifier).refreshSilently();
  }
}
