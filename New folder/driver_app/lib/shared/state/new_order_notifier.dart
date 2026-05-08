import 'package:driver_app/shared/models/delivery_order.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NewOrderNotifier extends Notifier<DeliveryOrder?> {
  @override
  DeliveryOrder? build() => null;

  void show(DeliveryOrder order) => state = order;
  void dismiss() => state = null;
}

final newOrderNotifierProvider =
    NotifierProvider<NewOrderNotifier, DeliveryOrder?>(NewOrderNotifier.new);
