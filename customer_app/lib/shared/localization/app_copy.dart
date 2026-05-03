import 'package:flutter/material.dart';

enum AppLanguage {
  ar,
  en;

  Locale get locale {
    return this == AppLanguage.ar
        ? const Locale('ar', 'OM')
        : const Locale('en', 'OM');
  }

  bool get isRtl => this == AppLanguage.ar;

  String get code => name;

  static AppLanguage fromCode(String? code) {
    return code == 'en' ? AppLanguage.en : AppLanguage.ar;
  }
}

class AppCopy {
  const AppCopy(this.language);

  final AppLanguage language;

  bool get isRtl => language.isRtl;

  String t(String key) {
    return _translations[language]?[key] ??
        _translations[AppLanguage.ar]?[key] ??
        key;
  }
}

const _translations = <AppLanguage, Map<String, String>>{
  AppLanguage.ar: {
    'app.name': 'ogas',
    'app.tagline': 'اطلب أسطوانة الغاز بسرعة وأمان داخل سلطنة عمان',
    'common.next': 'التالي',
    'common.login': 'تسجيل الدخول',
    'common.register': 'إنشاء حساب',
    'common.logout': 'تسجيل الخروج',
    'common.save': 'حفظ',
    'common.cancel': 'إلغاء',
    'common.search': 'بحث',
    'common.sendOrder': 'إرسال الطلب',
    'common.tryAgain': 'إعادة المحاولة',
    'common.omr': 'ر.ع.',
    'nav.home': 'الرئيسية',
    'nav.orders': 'طلباتي',
    'nav.profile': 'الملف الشخصي',
    'splash.loading': 'جاري تجهيز تجربتك...',
    'auth.welcome': 'مرحبًا بك في ogas',
    'auth.loginSubtitle':
        'سجّل الدخول للوصول السريع إلى طلباتك وعناوينك المحفوظة.',
    'auth.registerSubtitle':
        'أنشئ حسابك لبدء طلب أسطوانات الغاز وتتبعها مباشرة.',
    'auth.identifier': 'رقم الهاتف أو البريد الإلكتروني',
    'auth.fullName': 'الاسم الكامل',
    'auth.phone': 'رقم الهاتف',
    'auth.email': 'البريد الإلكتروني',
    'auth.password': 'كلمة المرور',
    'auth.confirmPassword': 'تأكيد كلمة المرور',
    'auth.forgotPassword': 'نسيت كلمة المرور؟',
    'auth.loginCta': 'دخول سريع',
    'auth.registerCta': 'إنشاء الحساب',
    'auth.invalidCredentials': 'تحقق من الحقول المطلوبة ثم حاول مرة أخرى.',
    'auth.passwordMismatch': 'تأكيد كلمة المرور غير مطابق.',
    'auth.serverUnavailable':
        'تعذر الاتصال بالخادم. تأكد من تشغيل الـ API وأن التطبيق متصل على العنوان الصحيح.',
    'auth.phoneExists': 'رقم الهاتف مستخدم مسبقًا.',
    'auth.emailExists': 'البريد الإلكتروني مستخدم مسبقًا.',
    'auth.invalidLogin': 'بيانات تسجيل الدخول غير صحيحة.',
    'home.greeting': 'مرحبًا',
    'home.heroTitle': 'توصيل الغاز في عمان بخطوات بسيطة وسريعة',
    'home.heroSubtitle':
        'حدد موقعك، اختر نوع الأسطوانة، وأرسل الطلب في أقل من دقيقة.',
    'home.orderNow': 'اطلب الآن',
    'home.currentLocation': 'الموقع الحالي',
    'home.changeLocation': 'تغيير الموقع',
    'location.updatedSuccess': 'تم تحديث موقعك بنجاح',
    'location.serviceDisabled': 'يرجى تشغيل خدمة تحديد الموقع',
    'location.permissionDenied': 'لم يتم السماح للتطبيق باستخدام الموقع',
    'location.permissionDeniedForever':
        'تم رفض صلاحية الموقع بشكل دائم، فعّلها من إعدادات الجهاز',
    'location.unavailable': 'تعذر تحديد الموقع حالياً',
    'location.outOfCoverage': 'الموقع الحالي خارج نطاق الخدمة داخل سلطنة عُمان',
    'home.availableProducts': 'الأسطوانات المتوفرة',
    'home.quickActions': 'اختصارات سريعة',
    'home.latestOrder': 'آخر طلب',
    'home.noOrders': 'لا توجد طلبات بعد',
    'home.services': 'الخدمات المتاحة',
    'home.service.fast': 'توصيل سريع',
    'home.service.safe': 'سائقون موثوقون',
    'home.service.live': 'تتبع مباشر',
    'order.createTitle': 'إنشاء طلب جديد',
    'order.createSubtitle':
        'املأ بيانات التوصيل واختر الأسطوانة المناسبة لمنزلك أو نشاطك.',
    'order.address': 'عنوان التوصيل',
    'order.governorate': 'المحافظة',
    'order.wilayat': 'الولاية',
    'order.area': 'الحي / المنطقة',
    'order.street': 'الشارع / المبنى',
    'order.house': 'رقم المنزل / علامة مميزة',
    'order.landmark': 'ملاحظة موقعية',
    'order.useGps': 'استخدام الموقع الحالي',
    'order.gasType': 'نوع الأسطوانة',
    'order.quantity': 'الكمية',
    'order.notes': 'ملاحظات إضافية',
    'order.deliveryWindow': 'وقت التوصيل المطلوب',
    'order.paymentMethod': 'طريقة الدفع',
    'order.cash': 'نقدًا عند الاستلام',
    'order.wallet': 'دفع إلكتروني لاحقًا',
    'order.summary': 'ملخص الطلب',
    'order.subtotal': 'سعر الأسطوانات',
    'order.deliveryFee': 'رسوم التوصيل',
    'order.total': 'الإجمالي',
    'order.createdSuccess': 'تم إنشاء الطلب بنجاح',
    'order.creatingInProgress': 'جاري إنشاء طلبك...',
    'order.locationRequired':
        'حدد موقعك الحالي أولاً ثم أعد تأكيد الطلب.',
    'order.serverUnavailable':
        'تعذر إرسال الطلب حاليًا. تأكد من تشغيل الخادم وأن الهاتف متصل بنفس الشبكة أو أن adb reverse مفعل.',
    'order.currentGpsAddress': 'عنوان GPS الحالي',
    'order.currentCoordinates': 'الإحداثيات الحالية',
    'order.gpsReadyHint':
        'سيتم استخدام هذا العنوان والإحداثيات عند إرسال الطلب الحالي.',
    'orders.title': 'طلباتي',
    'orders.subtitle':
        'تابع جميع الطلبات الحالية والسابقة، وأعد الطلب متى شئت.',
    'orders.all': 'الكل',
    'orders.reorder': 'إعادة الطلب',
    'orders.track': 'عرض التتبع',
    'orders.empty': 'لا توجد طلبات مطابقة',
    'tracking.title': 'تتبع الطلب',
    'tracking.currentStatus': 'الحالة الحالية',
    'tracking.driver': 'بيانات السائق',
    'tracking.eta': 'الوقت المتوقع للوصول',
    'tracking.distance': 'المسافة',
    'tracking.callDriver': 'اتصال',
    'tracking.cancelOrder': 'إلغاء الطلب',
    'tracking.map': 'خريطة التتبع المباشر',
    'tracking.orderNotFound':
        'لم يتم العثور على بيانات هذا الطلب بعد. حدّث البيانات أو ارجع إلى قائمة الطلبات.',
    'tracking.refreshData': 'تحديث بيانات التتبع',
    'tracking.deliveryAddress': 'عنوان التوصيل',
    'tracking.customerLocation': 'موقع التسليم',
    'tracking.driverLocation': 'موقع السائق',
    'tracking.yourLocation': 'موقعك الحالي',
    'tracking.driverPending': 'بانتظار تعيين السائق أو وصول موقعه الحي.',
    'tracking.lastUpdated': 'آخر تحديث',
    'tracking.changeDeliveryLocation': 'تغيير موقع التسليم',
    'tracking.chooseDeliveryLocation': 'اختر موقع التسليم الجديد',
    'tracking.deliveryLocationUpdated': 'تم تحديث موقع التسليم بنجاح.',
    'tracking.deliveryLocationUnavailable':
        'لا يوجد موقع متاح حالياً لتحديث موقع التسليم.',
    'tracking.routeHint':
        'الخط الظاهر تقريبي بين السائق وموقع التسليم وليس مسار طرق فعلي بعد.',
    'tracking.realRouteHint':
        'المسار الظاهر مبني على طرق الخرائط ويُحدَّث مباشرة من النظام مع حركة السائق.',
    'tracking.liveTrackingActive': 'تتبع السائق الحي مفعل',
    'tracking.liveTrackingStandby':
        'سيبدأ عرض حركة السائق تلقائيًا فور وصول أول تحديث حي بعد قبول الطلب.',
    'tracking.autoRefreshHint':
        'يتم تحديث موقع السائق والمسار مباشرة عبر التتبع الحي من الباكيند.',
    'profile.title': 'الملف الشخصي',
    'profile.edit': 'تعديل البيانات',
    'profile.savedAddresses': 'العناوين المحفوظة',
    'profile.notifications': 'الإشعارات',
    'profile.language': 'اللغة',
    'profile.support': 'الدعم الفني',
    'profile.terms': 'الشروط والأحكام',
    'profile.defaultAddress': 'العنوان الافتراضي',
    'profile.changePassword': 'تغيير كلمة المرور',
    'profile.paymentMethods': 'طرق الدفع',
    'validation.required': 'هذا الحقل مطلوب',
    'validation.phone': 'أدخل رقم هاتف صحيح',
    'status.pendingReview': 'قيد المراجعة',
    'status.searchingDriver': 'جارٍ البحث عن أقرب سائق',
    'status.driverNotified': 'تم إشعار السائق الأقرب',
    'status.noDriverFound': 'لا يوجد سائق متاح',
    'status.accepted': 'تم قبول الطلب',
    'status.preparing': 'جاري التجهيز',
    'status.onTheWay': 'في الطريق',
    'status.delivered': 'تم التسليم',
    'status.cancelled': 'تم الإلغاء',
    'statusMessage.pendingReview': 'تم استلام طلبك وجارٍ تهيئته داخل النظام.',
    'statusMessage.searchingDriver':
        'جاري البحث عن أقرب سيارة غاز إلى موقعك.',
    'statusMessage.driverNotified':
        'تم إرسال طلبك إلى أقرب سائق وبانتظار تأكيده.',
    'statusMessage.noDriverFound':
        'لم يتم العثور على سائق متاح حاليًا، وسيعاد المحاولة عند توفر أحد.',
    'statusMessage.accepted':
        'تم قبول الطلب، وبدأت إجراءات التوصيل إلى موقعك.',
    'statusMessage.preparing':
        'تم تأكيد الطلب وجارٍ تجهيزه قبل الانطلاق.',
    'statusMessage.onTheWay':
        'السائق في الطريق إليك الآن. تابع التتبع المباشر.',
    'statusMessage.delivered':
        'تم توصيل الطلب بنجاح. شكرًا لاستخدامك ogas.',
    'statusMessage.cancelled': 'تم إلغاء الطلب.',
    'tracking.step.received': 'تم استلام الطلب',
    'tracking.step.confirmed': 'تم تأكيد الطلب',
    'tracking.step.preparing': 'جاري التحضير',
    'tracking.step.onTheWay': 'السائق في الطريق',
    'tracking.step.delivered': 'تم التسليم',
  },
  AppLanguage.en: {
    'app.name': 'ogas',
    'app.tagline': 'Order gas cylinders quickly and safely across Oman',
    'common.next': 'Next',
    'common.login': 'Login',
    'common.register': 'Register',
    'common.logout': 'Logout',
    'common.save': 'Save',
    'common.cancel': 'Cancel',
    'common.search': 'Search',
    'common.sendOrder': 'Submit Order',
    'common.tryAgain': 'Try Again',
    'common.omr': 'OMR',
    'nav.home': 'Home',
    'nav.orders': 'Orders',
    'nav.profile': 'Profile',
    'splash.loading': 'Preparing your experience...',
    'auth.welcome': 'Welcome to ogas',
    'auth.loginSubtitle':
        'Sign in for fast access to your orders and saved addresses.',
    'auth.registerSubtitle':
        'Create your account to start ordering and tracking gas deliveries.',
    'auth.identifier': 'Phone number or email',
    'auth.fullName': 'Full name',
    'auth.phone': 'Phone number',
    'auth.email': 'Email',
    'auth.password': 'Password',
    'auth.confirmPassword': 'Confirm password',
    'auth.forgotPassword': 'Forgot password?',
    'auth.loginCta': 'Quick login',
    'auth.registerCta': 'Create account',
    'auth.invalidCredentials':
        'Please review the required fields and try again.',
    'auth.passwordMismatch': 'Password confirmation does not match.',
    'auth.serverUnavailable':
        'Unable to reach the server. Make sure the API is running and the app points to the correct address.',
    'auth.phoneExists': 'This phone number is already in use.',
    'auth.emailExists': 'This email address is already in use.',
    'auth.invalidLogin': 'Invalid login credentials.',
    'home.greeting': 'Hello',
    'home.heroTitle': 'Gas delivery in Oman with a simple mobile-first flow',
    'home.heroSubtitle':
        'Set your location, choose the cylinder, and place the order in under a minute.',
    'home.orderNow': 'Order now',
    'home.currentLocation': 'Current location',
    'home.changeLocation': 'Change location',
    'location.updatedSuccess': 'Your location was updated successfully',
    'location.serviceDisabled':
        'Please enable location services on your device',
    'location.permissionDenied': 'Location access was denied for this app',
    'location.permissionDeniedForever':
        'Location access is permanently denied. Enable it from device settings',
    'location.unavailable': 'Unable to determine your location right now',
    'location.outOfCoverage':
        'Your current location is outside the Oman service area',
    'home.availableProducts': 'Available cylinders',
    'home.quickActions': 'Quick actions',
    'home.latestOrder': 'Latest order',
    'home.noOrders': 'No orders yet',
    'home.services': 'Available services',
    'home.service.fast': 'Fast delivery',
    'home.service.safe': 'Trusted drivers',
    'home.service.live': 'Live tracking',
    'order.createTitle': 'Create a new order',
    'order.createSubtitle':
        'Fill in the delivery details and choose the right cylinder for your home or business.',
    'order.address': 'Delivery address',
    'order.governorate': 'Governorate',
    'order.wilayat': 'Wilayat',
    'order.area': 'Area / Neighborhood',
    'order.street': 'Street / Building',
    'order.house': 'House no. / Landmark',
    'order.landmark': 'Location note',
    'order.useGps': 'Use current location',
    'order.gasType': 'Cylinder type',
    'order.quantity': 'Quantity',
    'order.notes': 'Additional notes',
    'order.deliveryWindow': 'Preferred delivery time',
    'order.paymentMethod': 'Payment method',
    'order.cash': 'Cash on delivery',
    'order.wallet': 'Digital payment later',
    'order.summary': 'Order summary',
    'order.subtotal': 'Cylinder subtotal',
    'order.deliveryFee': 'Delivery fee',
    'order.total': 'Total',
    'order.createdSuccess': 'Order created successfully',
    'order.creatingInProgress': 'Creating your order...',
    'order.locationRequired':
        'Confirm your current location first, then submit the order again.',
    'order.serverUnavailable':
        'Unable to submit the order right now. Make sure the server is running and the phone can reach it on the local network or through adb reverse.',
    'order.currentGpsAddress': 'Current GPS address',
    'order.currentCoordinates': 'Current coordinates',
    'order.gpsReadyHint':
        'This GPS-based address and coordinates will be used when submitting the order.',
    'orders.title': 'My Orders',
    'orders.subtitle':
        'Track current and previous orders, and reorder anytime.',
    'orders.all': 'All',
    'orders.reorder': 'Reorder',
    'orders.track': 'Track order',
    'orders.empty': 'No matching orders',
    'tracking.title': 'Order Tracking',
    'tracking.currentStatus': 'Current status',
    'tracking.driver': 'Driver details',
    'tracking.eta': 'Estimated arrival',
    'tracking.distance': 'Distance',
    'tracking.callDriver': 'Call',
    'tracking.cancelOrder': 'Cancel order',
    'tracking.map': 'Live tracking map',
    'tracking.orderNotFound':
        'We could not find this order yet. Refresh tracking data or return to your orders list.',
    'tracking.refreshData': 'Refresh tracking',
    'tracking.deliveryAddress': 'Delivery address',
    'tracking.customerLocation': 'Drop-off location',
    'tracking.driverLocation': 'Driver location',
    'tracking.yourLocation': 'Your current location',
    'tracking.driverPending':
        'Waiting for driver assignment or live driver coordinates.',
    'tracking.lastUpdated': 'Last updated',
    'tracking.changeDeliveryLocation': 'Change delivery location',
    'tracking.chooseDeliveryLocation': 'Choose a new delivery location',
    'tracking.deliveryLocationUpdated':
        'Delivery location updated successfully.',
    'tracking.deliveryLocationUnavailable':
        'There is no available location to update the delivery point right now.',
    'tracking.routeHint':
        'The visible line is an approximate connection between the driver and the delivery point, not a real road route yet.',
    'tracking.realRouteHint':
        'The visible route follows real roads and updates live from the backend as the driver moves.',
    'tracking.liveTrackingActive': 'Live driver tracking is active',
    'tracking.liveTrackingStandby':
        'Driver movement will appear automatically as soon as the first live update arrives after acceptance.',
    'tracking.autoRefreshHint':
        'Driver location and route update live from backend tracking while the order is active.',
    'profile.title': 'Profile',
    'profile.edit': 'Edit profile',
    'profile.savedAddresses': 'Saved addresses',
    'profile.notifications': 'Notifications',
    'profile.language': 'Language',
    'profile.support': 'Support',
    'profile.terms': 'Terms & Conditions',
    'profile.defaultAddress': 'Default address',
    'profile.changePassword': 'Change password',
    'profile.paymentMethods': 'Payment methods',
    'validation.required': 'This field is required',
    'validation.phone': 'Enter a valid phone number',
    'status.pendingReview': 'Pending review',
    'status.searchingDriver': 'Searching for nearest driver',
    'status.driverNotified': 'Nearest driver notified',
    'status.noDriverFound': 'No driver available',
    'status.accepted': 'Accepted',
    'status.preparing': 'Preparing',
    'status.onTheWay': 'On the way',
    'status.delivered': 'Delivered',
    'status.cancelled': 'Cancelled',
    'statusMessage.pendingReview':
        'Your order was received and is being prepared by the system.',
    'statusMessage.searchingDriver':
        'We are searching for the nearest gas vehicle to your location.',
    'statusMessage.driverNotified':
        'Your order was sent to the nearest driver and is waiting for confirmation.',
    'statusMessage.noDriverFound':
        'No driver is available right now. We will retry when one becomes available.',
    'statusMessage.accepted':
        'Your order was accepted and delivery is now in progress.',
    'statusMessage.preparing':
        'Your order is confirmed and being prepared before dispatch.',
    'statusMessage.onTheWay':
        'The driver is on the way to you now. Follow the live tracking.',
    'statusMessage.delivered':
        'Your order has been delivered successfully. Thanks for using ogas.',
    'statusMessage.cancelled': 'The order has been cancelled.',
    'tracking.step.received': 'Order received',
    'tracking.step.confirmed': 'Order confirmed',
    'tracking.step.preparing': 'Preparing order',
    'tracking.step.onTheWay': 'Driver is on the way',
    'tracking.step.delivered': 'Delivered',
  },
};
