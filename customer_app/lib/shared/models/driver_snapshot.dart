class DriverSnapshot {
  const DriverSnapshot({
    required this.id,
    required this.name,
    required this.phone,
    required this.vehicleLabel,
    required this.etaMinutes,
  });

  final String id;
  final String name;
  final String phone;
  final String vehicleLabel;
  final int etaMinutes;
}
