
.# Customer App

تطبيق Flutter للعميل النهائي في مشروع بيع وتوصيل أسطوانات الغاز داخل سلطنة عمان.

## الحالة الحالية

- تم إنشاء الهيكل الأساسي للتطبيق داخل `apps/customer_app`
- تم بناء الشاشات الأساسية التالية:
  - `Splash`
  - `Login / Register`
  - `Home`
  - `Create Order`
  - `My Orders`
  - `Order Tracking`
  - `Profile`
- تم تجهيز دعم:
  - العربية والإنجليزية
  - تنسيق عماني للتواريخ والأسعار
  - Riverpod لإدارة الحالة
  - GoRouter للتنقل
  - Dio للـ API
  - Socket.IO Client للتحديث الحي لاحقًا

## التشغيل

```bash
cd apps/customer_app
flutter pub get
flutter run
```

ملاحظة:
- العنوان الافتراضي الحالي لتطبيق العميل هو:
  - API + Socket: `http://72.61.149.88:3009`
- يتم إرسال `POST /api/orders` إلى:
  - `http://72.61.149.88:3009/api/orders`
- يمكن تغيير العنوان عبر `--dart-define`:
  - `--dart-define=API_BASE_URL=http://YOUR_SERVER:PORT`
  - `--dart-define=SOCKET_BASE_URL=http://YOUR_SERVER:PORT`
- إذا تم تمرير override وفشل الاتصال، سيحاول التطبيق fallback إلى عنوان الإنتاج الافتراضي تلقائيًا.

## ملاحظة مهمة لويندوز

إذا كان مسار المشروع يحتوي على أحرف عربية أو أي أحرف غير ASCII، قد يفشل Android build حتى لو كان الكود صحيحًا.

تمت إضافة سكربت جاهز داخل التطبيق:

```bat
flutter_ascii.bat
```

أمثلة:

```bat
flutter_ascii.bat pub get
flutter_ascii.bat run
flutter_ascii.bat build apk --debug
```

هذا السكربت ينشئ Junction تلقائيًا على مسار ASCII:

```text
<project-drive>:\gas_customer_app_ascii
```

ثم يشغّل أو يبني Flutter من خلاله لتفادي مشاكل Gradle و shader compiler على ويندوز.

## الهيكل

```text
lib/
├─ app/
│  ├─ app.dart
│  ├─ router/
│  └─ theme/
├─ core/
│  ├─ constants/
│  ├─ network/
│  └─ widgets/
├─ data/
│  ├─ mock/
│  └─ services/
├─ features/
│  ├─ auth/
│  ├─ home/
│  ├─ orders/
│  ├─ profile/
│  └─ splash/
├─ shared/
│  ├─ localization/
│  ├─ models/
│  └─ state/
└─ main.dart
```

## الربط الحالي مع الـ Backend

المربوط فعليًا الآن:

- `POST /api/orders`
- `GET /api/orders?mine=true`
- Socket.IO على نفس أصل الخادم

ويتم استخدام `POST /api/orders` من شاشة `Create Order` لإنشاء طلب جديد.

آلية العنوان الحالية:
- التطبيق يجرّب `API_BASE_URL` أولًا إذا تم تمريره.
- إذا لم يتم تمرير `SOCKET_BASE_URL` لكن تم تمرير `API_BASE_URL`، يتم اشتقاق عنوان الـ Socket من نفس الأصل تلقائيًا.
- إذا فشل الاتصال بالعنوان الممرّر، يعود التطبيق تلقائيًا إلى عنوان الإنتاج الافتراضي `http://72.61.149.88:3009`.
- عند فشل إنشاء الطلب بسبب عنوان خاطئ أو انقطاع شبكة، تظهر رسالة أوضح تذكر المسار الذي فشل والعناوين التي تمت محاولتها.

## الـ APIs المقترحة للمرحلة القادمة

### Auth

- `POST /api/auth/register`
- `POST /api/auth/login`
- `GET /api/auth/me`
- `POST /api/auth/forgot-password`

### Customer Profile

- `GET /api/customer/profile`
- `PUT /api/customer/profile`

### Addresses

- `GET /api/customer/addresses`
- `POST /api/customer/addresses`
- `PUT /api/customer/addresses/:id`
- `DELETE /api/customer/addresses/:id`

### Orders

- `GET /api/customer/orders`
- `GET /api/customer/orders/:id`
- `POST /api/customer/orders/:id/cancel`
- `POST /api/customer/orders/:id/reorder`

### Tracking

- `GET /api/customer/orders/:id/tracking`
- Socket events:
  - `order_status_changed`
  - `driver_location_updated`
  - `new_notification`

## الشاشات الحالية

### Splash

- يعرض هوية التطبيق
- يفحص الجلسة
- يوجّه إلى `Home` أو `Auth`

### Auth

- تسجيل دخول
- إنشاء حساب
- تحقق أساسي من الحقول

### Home

- ترحيب بالمستخدم
- عرض الموقع الافتراضي
- عرض أنواع الأسطوانات
- آخر طلب
- زر سريع لإنشاء طلب

### Create Order

- اختيار عنوان محفوظ
- إدخال تفاصيل العنوان
- اختيار نوع الأسطوانة
- تحديد الكمية
- اختيار طريقة الدفع
- ملخص الطلب والسعر بالريال العماني

### My Orders

- عرض الطلبات الحالية والسابقة
- فلترة حسب الحالة
- إعادة الطلب
- فتح شاشة التتبع

### Order Tracking

- عرض حالة الطلب الحالية
- Timeline للحالة
- بيانات السائق
- زر إلغاء الطلب عند السماح

### Profile

- بيانات العميل
- العناوين المحفوظة
- تغيير اللغة
- عناصر إعدادات عامة
- تسجيل الخروج

## التحقق المنجز

تم التحقق من المشروع عبر:

```bash
flutter analyze
flutter test
```

والنتيجة الحالية:
- `No issues found!`
- `All tests passed!`

## الخطوة التالية المقترحة

1. ربط شاشة `My Orders` بواجهة `GET /api/customer/orders`
2. إضافة JWT Auth حقيقي
3. إضافة خرائط فعلية وتتبّع السائق live
4. إضافة الإشعارات الفورية
5. إضافة حفظ عدة عناوين للمستخدم
