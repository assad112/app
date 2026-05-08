class EarningsSummary {
  const EarningsSummary({
    required this.completedOrders,
    required this.todayEarnings,
    required this.weeklyEarnings,
    required this.monthlyEarnings,
    required this.lifetimeEarnings,
  });

  final int completedOrders;
  final double todayEarnings;
  final double weeklyEarnings;
  final double monthlyEarnings;
  final double lifetimeEarnings;

  factory EarningsSummary.fromJson(Map<String, dynamic> json) {
    double parseAmount(dynamic value) {
      if (value == null || value == "") {
        return 0;
      }

      return double.tryParse(value.toString()) ?? 0;
    }

    return EarningsSummary(
      completedOrders:
          int.tryParse(
            (json["completed_orders"] ?? json["completedOrders"] ?? 0)
                .toString(),
          ) ??
          0,
      todayEarnings: parseAmount(
        json["today_earnings"] ?? json["todayEarnings"],
      ),
      weeklyEarnings: parseAmount(
        json["weekly_earnings"] ?? json["weeklyEarnings"],
      ),
      monthlyEarnings: parseAmount(
        json["monthly_earnings"] ?? json["monthlyEarnings"],
      ),
      lifetimeEarnings: parseAmount(
        json["lifetime_earnings"] ?? json["lifetimeEarnings"],
      ),
    );
  }
}
