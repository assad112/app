import 'package:customer_app/shared/models/address_model.dart';
import 'package:customer_app/shared/models/driver_snapshot.dart';
import 'package:customer_app/shared/models/gas_product.dart';
import 'package:customer_app/shared/models/order_status.dart';
import 'package:customer_app/shared/models/payment_method.dart';
import 'package:customer_app/shared/models/tracking_route_point.dart';

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
    );
  }
}
