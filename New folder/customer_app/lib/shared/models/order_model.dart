import 'package:customer_app/shared/models/address_model.dart';
import 'package:customer_app/shared/models/driver_snapshot.dart';
import 'package:customer_app/shared/models/gas_product.dart';
import 'package:customer_app/shared/models/order_status.dart';
import 'package:customer_app/shared/models/payment_method.dart';
import 'package:customer_app/shared/models/tracking_route_point.dart';

class OrderLineItem {
  const OrderLineItem({
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

  String localizedName(bool isRtl) => isRtl ? productNameAr : productNameEn;

  OrderLineItem copyWith({
    String? id,
    String? orderId,
    String? productId,
    String? productCode,
    String? productNameAr,
    String? productNameEn,
    String? sizeLabel,
    String? driverInventoryCode,
    int? quantity,
    double? unitPrice,
    double? deliveryFee,
    double? lineTotal,
  }) {
    return OrderLineItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      productCode: productCode ?? this.productCode,
      productNameAr: productNameAr ?? this.productNameAr,
      productNameEn: productNameEn ?? this.productNameEn,
      sizeLabel: sizeLabel ?? this.sizeLabel,
      driverInventoryCode: driverInventoryCode ?? this.driverInventoryCode,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      lineTotal: lineTotal ?? this.lineTotal,
    );
  }
}

class OrderModel {
  const OrderModel({
    required this.orderId,
    required this.customerId,
    required this.customerName,
    required this.phone,
    required this.gasProduct,
    required this.quantity,
    required this.address,
    required this.notes,
    required this.paymentMethod,
    required this.orderStatus,
    required this.subtotalPrice,
    required this.deliveryFee,
    required this.totalPrice,
    required this.createdAt,
    required this.updatedAt,
    this.driver,
    this.driverLatitude,
    this.driverLongitude,
    this.routePoints = const [],
    this.routeDistanceMeters,
    this.routeDurationSeconds,
    this.preferredDeliveryWindow,
    this.items = const [],
    this.childOrders = const [],
    this.parentOrderId,
    this.fulfillmentType = 'standalone',
    this.fulfillmentInventoryCode,
  });

  final String orderId;
  final String customerId;
  final String customerName;
  final String phone;
  final GasProduct gasProduct;
  final int quantity;
  final AddressModel address;
  final String notes;
  final PaymentMethod paymentMethod;
  final OrderStatus orderStatus;
  final double subtotalPrice;
  final double deliveryFee;
  final double totalPrice;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DriverSnapshot? driver;
  final double? driverLatitude;
  final double? driverLongitude;
  final List<TrackingRoutePoint> routePoints;
  final int? routeDistanceMeters;
  final int? routeDurationSeconds;
  final String? preferredDeliveryWindow;
  final List<OrderLineItem> items;
  final List<OrderModel> childOrders;
  final String? parentOrderId;
  final String fulfillmentType;
  final String? fulfillmentInventoryCode;

  bool get isSplitParent => fulfillmentType == 'group_parent';
  bool get isSplitChild => fulfillmentType == 'split_child';
  bool get hasChildOrders => childOrders.isNotEmpty;
  bool get isMultiItem => items.length > 1 || hasChildOrders;
  int get totalRequestedQuantity =>
      items.isNotEmpty
          ? items.fold<int>(0, (sum, item) => sum + item.quantity)
          : quantity;

  String localizedItemsSummary(bool isRtl) {
    if (items.isEmpty) {
      return '${gasProduct.localizedName(isRtl)} x$quantity';
    }

    return items
        .map((item) => '${item.localizedName(isRtl)} x${item.quantity}')
        .join(isRtl ? ' + ' : ' + ');
  }

  String localizedFulfillmentLabel(bool isRtl) {
    switch (fulfillmentType) {
      case 'group_parent':
        return isRtl ? 'طلب متعدد الأنواع' : 'Multi-item order';
      case 'split_child':
        return isRtl ? 'جزء من طلب رئيسي' : 'Part of a main order';
      default:
        return isRtl ? 'طلب مفرد' : 'Single delivery';
    }
  }

  OrderModel copyWith({
    String? orderId,
    String? customerId,
    String? customerName,
    String? phone,
    GasProduct? gasProduct,
    int? quantity,
    AddressModel? address,
    String? notes,
    PaymentMethod? paymentMethod,
    OrderStatus? orderStatus,
    double? subtotalPrice,
    double? deliveryFee,
    double? totalPrice,
    DateTime? createdAt,
    DateTime? updatedAt,
    DriverSnapshot? driver,
    double? driverLatitude,
    double? driverLongitude,
    List<TrackingRoutePoint>? routePoints,
    int? routeDistanceMeters,
    int? routeDurationSeconds,
    String? preferredDeliveryWindow,
    List<OrderLineItem>? items,
    List<OrderModel>? childOrders,
    String? parentOrderId,
    String? fulfillmentType,
    String? fulfillmentInventoryCode,
  }) {
    return OrderModel(
      orderId: orderId ?? this.orderId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      phone: phone ?? this.phone,
      gasProduct: gasProduct ?? this.gasProduct,
      quantity: quantity ?? this.quantity,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      orderStatus: orderStatus ?? this.orderStatus,
      subtotalPrice: subtotalPrice ?? this.subtotalPrice,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      totalPrice: totalPrice ?? this.totalPrice,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      driver: driver ?? this.driver,
      driverLatitude: driverLatitude ?? this.driverLatitude,
      driverLongitude: driverLongitude ?? this.driverLongitude,
      routePoints: routePoints ?? this.routePoints,
      routeDistanceMeters: routeDistanceMeters ?? this.routeDistanceMeters,
      routeDurationSeconds: routeDurationSeconds ?? this.routeDurationSeconds,
      preferredDeliveryWindow:
          preferredDeliveryWindow ?? this.preferredDeliveryWindow,
      items: items ?? this.items,
      childOrders: childOrders ?? this.childOrders,
      parentOrderId: parentOrderId ?? this.parentOrderId,
      fulfillmentType: fulfillmentType ?? this.fulfillmentType,
      fulfillmentInventoryCode:
          fulfillmentInventoryCode ?? this.fulfillmentInventoryCode,
    );
  }
}
