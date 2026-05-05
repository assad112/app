import 'package:driver_app/shared/models/tracking_route_point.dart';

class DeliveryOrderItem {
  const DeliveryOrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productCode,
    required this.productNameAr,
    required this.productNameEn,
    required this.sizeLabel,
    required this.driverInventoryCode,
    required this.quantity,
    required this.unitPrice,
    required this.deliveryFee,
    required this.lineTotal,
  });

  final String id;
  final String orderId;
  final String? productId;
  final String productCode;
  final String productNameAr;
  final String productNameEn;
  final String sizeLabel;
  final String driverInventoryCode;
  final int quantity;
  final double? unitPrice;
  final double? deliveryFee;
  final double? lineTotal;

  String localizedName(bool isArabic) =>
      isArabic ? productNameAr : productNameEn;
}

class DeliveryOrder {
  const DeliveryOrder({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    required this.location,
    required this.addressFull,
    required this.gasType,
    required this.quantity,
    required this.paymentMethod,
    required this.notes,
    required this.preferredDeliveryWindow,
    required this.totalAmount,
    required this.status,
    required this.publicStatus,
    required this.driverStage,
    required this.assignedDriverId,
    required this.currentCandidateDriverId,
    required this.driverName,
    required this.driverPhone,
    required this.driverLocation,
    required this.driverLatitude,
    required this.driverLongitude,
    required this.customerLatitude,
    required this.customerLongitude,
    required this.routePoints,
    required this.routeDistanceMeters,
    required this.routeDurationSeconds,
    required this.etaMinutes,
    required this.createdAt,
    required this.updatedAt,
    required this.acceptedAt,
    required this.deliveredAt,
    required this.cancelledAt,
    required this.dispatchExpiresAt,
    required this.items,
    required this.parentOrderId,
    required this.fulfillmentType,
    required this.fulfillmentInventoryCode,
  });

  final String id;
  final String? customerId;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String location;
  final String addressFull;
  final String gasType;
  final int quantity;
  final String paymentMethod;
  final String notes;
  final String preferredDeliveryWindow;
  final double totalAmount;
  final String status;
  final String publicStatus;
  final String driverStage;
  final String? assignedDriverId;
  final String? currentCandidateDriverId;
  final String driverName;
  final String driverPhone;
  final String driverLocation;
  final double? driverLatitude;
  final double? driverLongitude;
  final double? customerLatitude;
  final double? customerLongitude;
  final List<TrackingRoutePoint> routePoints;
  final int? routeDistanceMeters;
  final int? routeDurationSeconds;
  final int? etaMinutes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? acceptedAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;
  final DateTime? dispatchExpiresAt;
  final List<DeliveryOrderItem> items;
  final String? parentOrderId;
  final String fulfillmentType;
  final String? fulfillmentInventoryCode;

  bool get isAvailable =>
      status == "pending" && driverStage == "driver_notified";
  bool get isActive =>
      status == "accepted" &&
      const {"accepted", "on_the_way", "arrived"}.contains(driverStage);
  bool get isCompleted => status == "delivered";
  bool get isCancelled => status == "cancelled";
  bool get isSplitChild => fulfillmentType == "split_child";
  bool get hasStructuredItems => items.isNotEmpty;
  int get totalRequestedQuantity =>
      items.isNotEmpty
          ? items.fold<int>(0, (sum, item) => sum + item.quantity)
          : quantity;

  String localizedItemsSummary(bool isArabic) {
    if (items.isEmpty) {
      return '$gasType x$quantity';
    }

    return items
        .map(
          (item) => '${item.localizedName(isArabic)} x${item.quantity}',
        )
        .join(isArabic ? ' + ' : ' + ');
  }

  String localizedFulfillmentLabel(bool isArabic) {
    switch (fulfillmentType) {
      case "split_child":
        return isArabic ? 'جزء من طلب رئيسي' : 'Part of a main order';
      case "group_parent":
        return isArabic ? 'طلب متعدد الأنواع' : 'Multi-item order';
      default:
        return isArabic ? 'طلب مفرد' : 'Single delivery';
    }
  }

  bool isOfferForDriver(String? driverId) =>
      driverId != null && currentCandidateDriverId == driverId && isAvailable;

  factory DeliveryOrder.fromJson(Map<String, dynamic> json) {
    final locationPayload = json["location"];
    final locationMap = locationPayload is Map<String, dynamic>
        ? locationPayload
        : locationPayload is Map
            ? Map<String, dynamic>.from(locationPayload)
            : null;

    double? parseCoordinate(dynamic value) {
      if (value == null || value == "") {
        return null;
      }

      return double.tryParse(value.toString());
    }

    String parseLocationText(dynamic value) {
      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        return (map["addressText"] ??
                map["address_text"] ??
                map["address"] ??
                map["label"] ??
                map["name"] ??
                "")
            .toString();
      }

      return (value ?? "").toString();
    }

    double parseAmount(dynamic value) {
      if (value == null || value == "") {
        return 0;
      }

      return double.tryParse(value.toString()) ?? 0;
    }

    int parseQuantity(dynamic value) {
      if (value == null || value == "") {
        return 1;
      }

      return int.tryParse(value.toString()) ?? 1;
    }

    int? parseInteger(dynamic value) {
      if (value == null || value == "") {
        return null;
      }

      if (value is int) {
        return value;
      }

      if (value is num) {
        return value.round();
      }

      return int.tryParse(value.toString());
    }

    DateTime? parseDate(dynamic value) {
      if (value == null || value == "") {
        return null;
      }

      return DateTime.tryParse(value.toString());
    }

    List<DeliveryOrderItem> parseItems(dynamic rawItems, String orderId) {
      if (rawItems is! List) {
        return const <DeliveryOrderItem>[];
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
          .map(
            (item) => DeliveryOrderItem(
              id: (item["id"] ?? "").toString(),
              orderId:
                  (item["orderId"] ?? item["order_id"] ?? orderId).toString(),
              productId:
                  item["productId"]?.toString() ??
                  item["product_id"]?.toString(),
              productCode:
                  (item["productCode"] ?? item["product_code"] ?? "").toString(),
              productNameAr:
                  (item["productNameAr"] ?? item["product_name_ar"] ?? "")
                      .toString(),
              productNameEn:
                  (item["productNameEn"] ?? item["product_name_en"] ?? "")
                      .toString(),
              sizeLabel:
                  (item["sizeLabel"] ?? item["size_label"] ?? "").toString(),
              driverInventoryCode:
                  (item["driverInventoryCode"] ??
                          item["driver_inventory_code"] ??
                          "")
                      .toString(),
              quantity: parseQuantity(item["quantity"]),
              unitPrice: parseCoordinate(item["unitPrice"] ?? item["unit_price"]),
              deliveryFee:
                  parseCoordinate(item["deliveryFee"] ?? item["delivery_fee"]),
              lineTotal: parseCoordinate(item["lineTotal"] ?? item["line_total"]),
            ),
          )
          .toList(growable: false);
    }

    final locationText = parseLocationText(locationPayload);
    final customerLatitude = parseCoordinate(
      json["customerLatitude"] ??
          json["customer_latitude"] ??
          json["latitude"] ??
          locationMap?["lat"] ??
          locationMap?["latitude"],
    );
    final customerLongitude = parseCoordinate(
      json["customerLongitude"] ??
          json["customer_longitude"] ??
          json["longitude"] ??
          locationMap?["lng"] ??
          locationMap?["lon"] ??
          locationMap?["longitude"],
    );
    final trackingRoutePayload =
        json["trackingRoute"] ?? json["tracking_route"];
    final trackingRouteMap = trackingRoutePayload is Map<String, dynamic>
        ? trackingRoutePayload
        : trackingRoutePayload is Map
            ? Map<String, dynamic>.from(trackingRoutePayload)
            : null;
    final routePointsPayload =
        json["routePoints"] ??
        json["route_points"] ??
        trackingRouteMap?["points"] ??
        trackingRouteMap?["routePoints"] ??
        trackingRouteMap?["route_points"];
    final routePoints = routePointsPayload is List
        ? routePointsPayload
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
            .map(
              (item) => TrackingRoutePoint(
                latitude:
                    parseCoordinate(item["latitude"] ?? item["lat"] ?? item["y"]) ??
                    0,
                longitude:
                    parseCoordinate(
                      item["longitude"] ??
                          item["lng"] ??
                          item["lon"] ??
                          item["x"],
                    ) ??
                    0,
              ),
            )
            .where((point) => point.latitude != 0 || point.longitude != 0)
            .toList(growable: false)
        : const <TrackingRoutePoint>[];
    final routeDistanceMeters = parseInteger(
      json["routeDistanceMeters"] ??
          json["route_distance_meters"] ??
          trackingRouteMap?["distanceMeters"] ??
          trackingRouteMap?["routeDistanceMeters"],
    );
    final routeDurationSeconds = parseInteger(
      json["routeDurationSeconds"] ??
          json["route_duration_seconds"] ??
          trackingRouteMap?["durationSeconds"] ??
          trackingRouteMap?["routeDurationSeconds"],
    );
    final etaMinutes = parseInteger(
      json["etaMinutes"] ??
          json["eta_minutes"] ??
          trackingRouteMap?["etaMinutes"] ??
          trackingRouteMap?["eta_minutes"],
    );
    final orderId = (json["id"] ?? "").toString();
    final items = parseItems(
      json["items"] ?? json["orderItems"] ?? json["order_items"],
      orderId,
    );

    return DeliveryOrder(
      id: orderId,
      customerId:
          json["customerId"]?.toString() ?? json["customer_id"]?.toString(),
      customerName:
          (json["customerFullName"] ??
                  json["customer_full_name"] ??
                  json["name"] ??
                  "")
              .toString(),
      customerPhone: (json["phone"] ?? "").toString(),
      customerEmail: (json["customerEmail"] ?? json["customer_email"] ?? "")
          .toString(),
      location: locationText,
      addressFull:
          (json["addressFull"] ?? json["address_full"] ?? locationText).toString(),
      gasType: (json["gasType"] ?? json["gas_type"] ?? "").toString(),
      quantity: parseQuantity(json["quantity"]),
      paymentMethod:
          (json["paymentMethod"] ?? json["payment_method"] ?? "").toString(),
      notes: (json["notes"] ?? "").toString(),
      preferredDeliveryWindow:
          (json["preferredDeliveryWindow"] ??
                  json["preferred_delivery_window"] ??
                  "")
              .toString(),
      totalAmount: parseAmount(json["totalAmount"] ?? json["total_amount"]),
      status: (json["status"] ?? "").toString(),
      publicStatus:
          (json["publicStatus"] ??
                  json["public_status"] ??
                  json["status"] ??
                  "")
              .toString(),
      driverStage: (json["driverStage"] ?? json["driver_stage"] ?? "").toString(),
      assignedDriverId:
          json["assignedDriverId"]?.toString() ??
          json["assigned_driver_id"]?.toString(),
      currentCandidateDriverId:
          json["currentCandidateDriverId"]?.toString() ??
          json["current_candidate_driver_id"]?.toString(),
      driverName: (json["driverName"] ?? json["driver_name"] ?? "").toString(),
      driverPhone:
          (json["driverPhone"] ?? json["driver_phone"] ?? "").toString(),
      driverLocation:
          (json["driverLocation"] ?? json["driver_location"] ?? "").toString(),
      driverLatitude:
          parseCoordinate(json["driverLatitude"] ?? json["driver_latitude"]),
      driverLongitude:
          parseCoordinate(json["driverLongitude"] ?? json["driver_longitude"]),
      customerLatitude: customerLatitude,
      customerLongitude: customerLongitude,
      routePoints: routePoints,
      routeDistanceMeters: routeDistanceMeters,
      routeDurationSeconds: routeDurationSeconds,
      etaMinutes: etaMinutes,
      createdAt: parseDate(json["createdAt"] ?? json["created_at"]),
      updatedAt: parseDate(json["updatedAt"] ?? json["updated_at"]),
      acceptedAt: parseDate(json["acceptedAt"] ?? json["accepted_at"]),
      deliveredAt: parseDate(json["deliveredAt"] ?? json["delivered_at"]),
      cancelledAt: parseDate(json["cancelledAt"] ?? json["cancelled_at"]),
      dispatchExpiresAt:
          parseDate(json["dispatchExpiresAt"] ?? json["dispatch_expires_at"]),
      items: items,
      parentOrderId:
          json["parentOrderId"]?.toString() ??
          json["parent_order_id"]?.toString(),
      fulfillmentType:
          (json["fulfillmentType"] ??
                  json["fulfillment_type"] ??
                  "standalone")
              .toString(),
      fulfillmentInventoryCode:
          json["fulfillmentInventoryCode"]?.toString() ??
          json["fulfillment_inventory_code"]?.toString(),
    );
  }
}
