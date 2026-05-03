class AppRuntimeSettings {
  const AppRuntimeSettings({
    required this.systemName,
    required this.supportPhone,
    required this.defaultLanguageCode,
    required this.currencyCode,
    required this.defaultDeliveryFee,
    required this.orderIntakeEnabled,
    required this.notificationsEnabled,
    required this.maintenanceMode,
    required this.systemMessage,
  });

  const AppRuntimeSettings.fallback()
    : systemName = 'غاز عُمان',
      supportPhone = '+96880001111',
      defaultLanguageCode = 'ar',
      currencyCode = 'OMR',
      defaultDeliveryFee = 1.25,
      orderIntakeEnabled = true,
      notificationsEnabled = true,
      maintenanceMode = false,
      systemMessage = '';

  final String systemName;
  final String supportPhone;
  final String defaultLanguageCode;
  final String currencyCode;
  final double defaultDeliveryFee;
  final bool orderIntakeEnabled;
  final bool notificationsEnabled;
  final bool maintenanceMode;
  final String systemMessage;

  AppRuntimeSettings copyWith({
    String? systemName,
    String? supportPhone,
    String? defaultLanguageCode,
    String? currencyCode,
    double? defaultDeliveryFee,
    bool? orderIntakeEnabled,
    bool? notificationsEnabled,
    bool? maintenanceMode,
    String? systemMessage,
  }) {
    return AppRuntimeSettings(
      systemName: systemName ?? this.systemName,
      supportPhone: supportPhone ?? this.supportPhone,
      defaultLanguageCode: defaultLanguageCode ?? this.defaultLanguageCode,
      currencyCode: currencyCode ?? this.currencyCode,
      defaultDeliveryFee: defaultDeliveryFee ?? this.defaultDeliveryFee,
      orderIntakeEnabled: orderIntakeEnabled ?? this.orderIntakeEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      systemMessage: systemMessage ?? this.systemMessage,
    );
  }
}
