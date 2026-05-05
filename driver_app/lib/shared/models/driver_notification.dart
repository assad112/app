class DriverNotificationItem {
  const DriverNotificationItem({
    required this.id,
    required this.orderId,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
  });

  final String id;
  final String? orderId;
  final String type;
  final String title;
  final String body;
  final DateTime timestamp;

  String get dedupeKey {
    final normalizedOrderId = orderId?.trim();
    if (normalizedOrderId != null && normalizedOrderId.isNotEmpty) {
      return 'order:$normalizedOrderId';
    }
    return 'id:$id';
  }

  factory DriverNotificationItem.fromBackend(Map<String, dynamic> json) {
    final orderId =
        (json["orderId"] ??
                json["order_id"] ??
                json["id"] ??
                json["order"]?["id"])
            ?.toString();
    final type = (json["notification_type"] ?? json["type"] ?? "order_update")
        .toString();
    final customerName = (json["name"] ?? json["customer_name"] ?? "Customer")
        .toString();
    final gasType = (json["gas_type"] ?? json["gasType"] ?? "Gas Cylinder")
        .toString();

    String buildTitle() {
      switch (type) {
        case "new_order":
          return "New delivery request";
        case "driver_notified":
          return "Order offer";
        case "offer_timeout":
          return "Offer expired";
        case "accepted":
          return "Order accepted";
        case "on_the_way":
          return "Heading to customer";
        case "arrived":
          return "Arrived at delivery point";
        case "delivered":
          return "Delivery completed";
        case "cancelled":
          return "Order cancelled";
        default:
          return "Order update";
      }
    }

    String buildBody() {
      switch (type) {
        case "new_order":
          return "$gasType request from $customerName is waiting for pickup.";
        case "driver_notified":
          return "A nearby customer request is waiting for your response.";
        case "offer_timeout":
          return "The offer for order #$orderId was forwarded to another driver.";
        case "delivered":
          return "Order #$orderId was completed successfully.";
        case "cancelled":
          return "Order #$orderId is no longer active.";
        default:
          return "Order #$orderId for $customerName has a new update.";
      }
    }

    final timestamp =
        DateTime.tryParse(
          (json["updated_at"] ?? json["created_at"] ?? "").toString(),
        ) ??
        DateTime.now();

    return DriverNotificationItem(
      id: "$type-${orderId ?? timestamp.microsecondsSinceEpoch}",
      orderId: orderId,
      type: type,
      title: buildTitle(),
      body: buildBody(),
      timestamp: timestamp,
    );
  }

  factory DriverNotificationItem.fromRealtime(Map<String, dynamic> json) {
    final orderId = (json["orderId"] ?? json["order_id"] ?? json["id"])
        ?.toString();
    final type = (json["type"] ?? "order_update").toString();

    return DriverNotificationItem(
      id: "$type-${orderId ?? DateTime.now().microsecondsSinceEpoch}",
      orderId: orderId,
      type: type,
      title: "Live update",
      body: (json["message"] ?? "A new update was received.").toString(),
      timestamp: DateTime.now(),
    );
  }
}
