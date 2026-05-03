import 'package:flutter/material.dart';

class AppStrings {
  AppStrings(this.localeCode);

  final String localeCode;

  bool get isArabic => localeCode == 'ar';

  static AppStrings of(BuildContext context) {
    return AppStrings(Localizations.localeOf(context).languageCode);
  }

  String get appName => isArabic ? 'سائق ogas' : 'ogas Driver';
  String get dashboardNav => isArabic ? 'الرئيسية' : 'Dashboard';
  String get ordersNav => isArabic ? 'الطلبات' : 'Orders';
  String get alertsNav => isArabic ? 'التنبيهات' : 'Alerts';
  String get profileNav => isArabic ? 'الحساب' : 'Profile';
  String get language => isArabic ? 'اللغة' : 'Language';
  String get arabic => isArabic ? 'العربية' : 'Arabic';
  String get english => isArabic ? 'الإنجليزية' : 'English';
  String get retry => isArabic ? 'إعادة المحاولة' : 'Retry';
  String get nothingHereYet =>
      isArabic ? 'لا يوجد شيء هنا بعد' : 'Nothing here yet';

  String get splashTitle => appName;
  String get splashSubtitle => isArabic
      ? 'تطبيق ميداني احترافي لإدارة طلبات الغاز والتوصيل المباشر.'
      : 'Professional field operations for live gas delivery requests.';

  String get loginHeroTitle => isArabic ? 'دخول السائق' : 'Driver sign in';
  String get loginHeroSubtitle => isArabic
      ? 'اتصل بنظام التشغيل المباشر واستقبل طلبات التوصيل لحظة بلحظة.'
      : 'Connect to the live dispatch system and start receiving delivery requests.';
  String get loginWelcome => isArabic ? 'أهلًا بعودتك' : 'Welcome back';
  String get loginDescription => isArabic
      ? 'استخدم بيانات الدخول التي أنشأها لك لوحة الأدمن.'
      : 'Use the login credentials created for you by the admin dashboard.';
  String get loginIdentifier => isArabic
      ? 'اسم المستخدم أو الهاتف أو البريد'
      : 'Username, phone, or email';
  String get loginIdentifierHint => isArabic
      ? 'أدخل اسم المستخدم أو الهاتف أو البريد'
      : 'Enter your username, phone, or email';
  String get password => isArabic ? 'كلمة المرور' : 'Password';
  String get passwordHint => isArabic
      ? 'يجب أن تكون 6 أحرف على الأقل'
      : 'Password must be at least 6 characters';
  String get signIn => isArabic ? 'تسجيل الدخول' : 'Sign in';
  String get loginFailed => isArabic ? 'فشل تسجيل الدخول' : 'Login failed';
  String get adminOnlyAccountNotice => isArabic
      ? 'يتم إنشاء حسابات السائقين من قبل الأدمن فقط. استخدم اسم المستخدم وكلمة المرور المؤقتة التي تم تسليمها لك.'
      : 'Driver accounts are created by admin only. Use the username and temporary password assigned from the admin dashboard.';

  String helloDriver(String name) =>
      isArabic ? 'مرحبًا، $name' : 'Hello, $name';
  String get driverLabel => isArabic ? 'السائق' : 'Driver';
  String get onlineReadyMessage => isArabic
      ? 'أنت الآن ظاهر لفريق التشغيل وجاهز لاستقبال الطلبات المباشرة.'
      : 'You are visible to dispatch and ready for live orders.';
  String get offlineReadyMessage => isArabic
      ? 'فعّل وضع الاتصال لتبدأ باستقبال طلبات التوصيل المباشرة.'
      : 'Switch online to receive live delivery requests.';
  String get availability => isArabic ? 'التوفر' : 'Availability';
  String get vehicle => isArabic ? 'المركبة' : 'Vehicle';
  String get currentStatus => isArabic ? 'الحالة الحالية' : 'Current status';
  String get notSet => isArabic ? 'غير محدد' : 'Not set';
  String get online => isArabic ? 'متصل' : 'Online';
  String get offline => isArabic ? 'غير متصل' : 'Offline';
  String get busy => isArabic ? 'مشغول' : 'Busy';
  String get available => isArabic ? 'متاح' : 'Available';

  String get availableNow => isArabic ? 'الطلبات المتاحة' : 'Available now';
  String get activeDeliveries =>
      isArabic ? 'الطلبات النشطة' : 'Active deliveries';
  String get completed => isArabic ? 'المكتملة' : 'Completed';
  String get todayEarnings => isArabic ? 'دخل اليوم' : 'Today earnings';
  String get quickActions => isArabic ? 'إجراءات سريعة' : 'Quick actions';
  String get quickActionsSubtitle => isArabic
      ? 'أنجز يوم التوصيل المباشر من شاشة واحدة.'
      : 'Operate the live delivery day from one place.';
  String get earnings => isArabic ? 'الأرباح' : 'Earnings';
  String get history => isArabic ? 'السجل' : 'History';
  String get activeDelivery => isArabic ? 'التوصيل الحالي' : 'Active delivery';
  String get open => isArabic ? 'فتح' : 'Open';
  String get incomingRequests =>
      isArabic ? 'الطلبات الجديدة' : 'Incoming requests';
  String get incomingRequestsSubtitle => isArabic
      ? 'طلبات مباشرة جاهزة للقبول.'
      : 'Live orders ready for acceptance.';
  String get noPendingOrders =>
      isArabic ? 'لا توجد طلبات معلقة' : 'No pending orders';
  String get noPendingOrdersSubtitle => isArabic
      ? 'أي طلب جديد من العملاء سيظهر هنا مباشرة.'
      : 'New requests from customers will appear here in real time.';

  String get ordersTitle => isArabic ? 'الطلبات' : 'Orders';
  String get orderHistoryTitle => isArabic ? 'سجل الطلبات' : 'Order history';
  String get ordersSearchHint => isArabic
      ? 'ابحث برقم الطلب أو العميل أو الهاتف أو الموقع'
      : 'Search by order id, customer, phone, or location';
  String availableTab(int count) =>
      isArabic ? 'المتاحة ($count)' : 'Available ($count)';
  String activeTab(int count) =>
      isArabic ? 'النشطة ($count)' : 'Active ($count)';
  String get noLiveRequests =>
      isArabic ? 'لا توجد طلبات مباشرة' : 'No live requests';
  String get noLiveRequestsSubtitle => isArabic
      ? 'عند نشر طلب جديد من الباكند سيظهر هنا فورًا.'
      : 'When the backend publishes a new order, it will appear here instantly.';
  String get noActiveDelivery =>
      isArabic ? 'لا يوجد توصيل نشط' : 'No active delivery';
  String get noActiveDeliverySubtitle => isArabic
      ? 'الطلبات المقبولة تبقى هنا حتى يتم إنجازها.'
      : 'Accepted orders in progress will stay here until completion.';
  String get currentDeliveryQueue =>
      isArabic ? 'قائمة التوصيل الحالية' : 'Current delivery queue';
  String get currentDeliveryQueueSubtitle => isArabic
      ? 'أدر التوصيلات الجارية لحظة بلحظة.'
      : 'Manage active customer deliveries in real time.';
  String get historySearchHint => isArabic
      ? 'ابحث في الطلبات المكتملة والملغاة'
      : 'Search delivered and cancelled orders';
  String get noClosedOrders =>
      isArabic ? 'لا توجد طلبات مغلقة بعد' : 'No closed orders yet';
  String get noClosedOrdersSubtitle => isArabic
      ? 'الطلبات المكتملة والملغاة ستُؤرشف هنا.'
      : 'Completed and cancelled deliveries will be archived here.';

  String orderNumber(String orderId) =>
      isArabic ? 'الطلب #$orderId' : 'Order #$orderId';
  String deliveryNumber(String orderId) =>
      isArabic ? 'التوصيل #$orderId' : 'Delivery #$orderId';
  String get phone => isArabic ? 'الهاتف' : 'Phone';
  String get gasType => isArabic ? 'نوع الأسطوانة' : 'Gas type';
  String get quantity => isArabic ? 'الكمية' : 'Quantity';
  String get payment => isArabic ? 'الدفع' : 'Payment';
  String get address => isArabic ? 'العنوان' : 'Address';
  String get notes => isArabic ? 'الملاحظات' : 'Notes';
  String get noOperationalNotes =>
      isArabic ? 'لا توجد ملاحظات تشغيلية' : 'No operational notes';
  String get acceptOrder => isArabic ? 'قبول الطلب' : 'Accept order';
  String get rejectForMe => isArabic ? 'رفض لي فقط' : 'Reject for me';
  String get openActiveDelivery =>
      isArabic ? 'فتح التوصيل النشط' : 'Open active delivery';
  String get orderNoLongerAssignedMessage => isArabic
      ? 'هذا الطلب لم يعد مخصصًا لك، أو انتهت مهلة العرض، أو تم تحويله.'
      : 'This order is no longer assigned to you, its offer expired, or it was forwarded.';

  String get notificationsTitle => isArabic ? 'التنبيهات' : 'Notifications';
  String get noNotifications =>
      isArabic ? 'لا توجد تنبيهات بعد' : 'No notifications yet';
  String get noNotificationsSubtitle => isArabic
      ? 'تحديثات الطلبات والتنبيهات المباشرة ستظهر هنا.'
      : 'Live order updates and delivery alerts will show here.';

  String get earningsTitle => isArabic ? 'الأرباح' : 'Earnings';
  String get today => isArabic ? 'اليوم' : 'Today';
  String get weekly => isArabic ? 'أسبوعي' : 'Weekly';
  String get monthly => isArabic ? 'شهري' : 'Monthly';
  String get lifetime => isArabic ? 'إجمالي' : 'Lifetime';
  String get completedDeliveries =>
      isArabic ? 'التوصيلات المكتملة' : 'Completed deliveries';

  String get profileTitle => isArabic ? 'الحساب' : 'Profile';
  String get profileSubtitle => isArabic
      ? 'إدارة جاهزية السائق، اللغة، وبيانات التشغيل من شاشة واحدة.'
      : 'Manage driver readiness, language, and field details from one place.';
  String get profilePerformance =>
      isArabic ? 'مؤشرات الأداء' : 'Performance snapshot';
  String get profileControls => isArabic ? 'عناصر التحكم' : 'Dispatch controls';
  String get accountDetails => isArabic ? 'بيانات الحساب' : 'Account details';
  String get workTools => isArabic ? 'أدوات العمل' : 'Work tools';
  String get liveTrackingReady =>
      isArabic ? 'التتبع الحي جاهز' : 'Live tracking ready';
  String get liveTrackingReadySubtitle => isArabic
      ? 'سيتم إرسال موقعك مباشرة أثناء أي توصيل نشط.'
      : 'Your location will be shared automatically during active deliveries.';
  String get manageLanguage =>
      isArabic ? 'إدارة اللغة' : 'Language preferences';
  String get manageLanguageSubtitle => isArabic
      ? 'يمكنك التبديل فورًا بين العربية والإنجليزية مع دعم RTL.'
      : 'Switch instantly between Arabic and English with RTL support.';
  String get contactStatus => isArabic ? 'حالة الاتصال' : 'Connection status';
  String get lastSync => isArabic ? 'آخر مزامنة' : 'Last sync';
  String get noSyncYet => isArabic ? 'لم تتم مزامنة بعد' : 'No sync yet';
  String get onlineMode => isArabic ? 'وضع الاتصال' : 'Online mode';
  String get busyMode => isArabic ? 'وضع الانشغال' : 'Busy mode';
  String get license => isArabic ? 'الرخصة' : 'License';
  String get lastLocation => isArabic ? 'آخر موقع' : 'Last location';
  String get notAssignedYet => isArabic ? 'غير مخصص بعد' : 'Not assigned yet';
  String get noLiveLocationYet =>
      isArabic ? 'لا يوجد موقع حي بعد' : 'No live location yet';
  String get earningsSummary => isArabic ? 'ملخص الأرباح' : 'Earnings summary';
  String get logout => isArabic ? 'تسجيل الخروج' : 'Logout';
  String get locationPermissionRequired => isArabic
      ? 'يجب تفعيل إذن الموقع لمشاركة التتبع الحي.'
      : 'Location permission is required to share live tracking.';

  String get customerCoordinatesUnavailable => isArabic
      ? 'إحداثيات العميل غير متوفرة بعد من الباكند.'
      : 'Customer coordinates are not yet available from backend.';
  String get distance => isArabic ? 'المسافة' : 'Distance';
  String get eta => isArabic ? 'وقت الوصول' : 'ETA';
  String get total => isArabic ? 'الإجمالي' : 'Total';
  String get unknown => isArabic ? 'غير معروف' : 'Unknown';
  String get minuteShort => isArabic ? 'د' : 'min';
  String get kilometerShort => isArabic ? 'كم' : 'km';
  String get callCustomer => isArabic ? 'اتصال بالعميل' : 'Call customer';
  String get navigate => isArabic ? 'ابدأ الملاحة' : 'Navigate';
  String get startTrip => isArabic ? 'ابدأ الرحلة' : 'Start trip';
  String get markArrived => isArabic ? 'تم الوصول' : 'Mark arrived';
  String get completeDelivery =>
      isArabic ? 'إكمال التوصيل' : 'Complete delivery';
}

extension AppStringsContext on BuildContext {
  AppStrings get strings => AppStrings.of(this);
}
