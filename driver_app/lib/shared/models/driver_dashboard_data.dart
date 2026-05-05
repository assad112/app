import 'package:driver_app/shared/models/delivery_order.dart';
import 'package:driver_app/shared/models/driver_profile.dart';
import 'package:driver_app/shared/models/earnings_summary.dart';

class DriverDashboardData {
  const DriverDashboardData({
    required this.driver,
    required this.totalCompleted,
    required this.activeDeliveries,
    required this.availableOrdersCount,
    required this.todayEarnings,
    required this.lifetimeEarnings,
    required this.availableOrders,
    required this.activeOrders,
    required this.earningsSummary,
  });

  final DriverProfile driver;
  final int totalCompleted;
  final int activeDeliveries;
  final int availableOrdersCount;
  final double todayEarnings;
  final double lifetimeEarnings;
  final List<DeliveryOrder> availableOrders;
  final List<DeliveryOrder> activeOrders;
  final EarningsSummary earningsSummary;

  factory DriverDashboardData.fromJson(Map<String, dynamic> json) {
    double parseAmount(dynamic value) {
      if (value == null || value == "") {
        return 0;
      }

      return double.tryParse(value.toString()) ?? 0;
    }

    int parseInt(dynamic value) {
      if (value == null || value == "") {
        return 0;
      }

      return int.tryParse(value.toString()) ?? 0;
    }

    return DriverDashboardData(
      driver: DriverProfile.fromJson(
        Map<String, dynamic>.from(json["driver"] as Map? ?? const {}),
      ),
      totalCompleted: parseInt(json["summary"]?["total_completed"]),
      activeDeliveries: parseInt(json["summary"]?["active_deliveries"]),
      availableOrdersCount: parseInt(json["summary"]?["available_orders"]),
      todayEarnings: parseAmount(json["summary"]?["today_earnings"]),
      lifetimeEarnings: parseAmount(json["summary"]?["lifetime_earnings"]),
      availableOrders:
          ((json["availableOrders"] ?? json["available_orders"]) as List? ??
                  const [])
              .map(
                (item) => DeliveryOrder.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList(),
      activeOrders:
          ((json["activeOrders"] ?? json["active_orders"]) as List? ?? const [])
              .map(
                (item) => DeliveryOrder.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList(),
      earningsSummary: EarningsSummary.fromJson(
        Map<String, dynamic>.from(json["earnings"] as Map? ?? const {}),
      ),
    );
  }
}
