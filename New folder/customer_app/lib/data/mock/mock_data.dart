import 'package:customer_app/shared/models/address_model.dart';
import 'package:customer_app/shared/models/driver_snapshot.dart';
import 'package:customer_app/shared/models/gas_product.dart';
import 'package:customer_app/shared/models/order_model.dart';
import 'package:customer_app/shared/models/order_status.dart';
import 'package:customer_app/shared/models/payment_method.dart';
import 'package:customer_app/shared/models/user_profile.dart';

class MockData {
  const MockData._();

  static const user = UserProfile(
    id: 'customer-001',
    fullName: 'سالم بن حمد الكندي',
    phone: '+96891234567',
    email: 'salim.kindi@omangas.app',
    defaultAddressId: 'addr-001',
  );

  static const addresses = [
    AddressModel(
      id: 'addr-001',
      label: 'المنزل',
      governorate: 'محافظة مسقط',
      wilayat: 'بوشر',
      area: 'الخوير',
      street: 'شارع 23',
      houseNumber: 'فيلا 118',
      landmark: 'بالقرب من مركز عمان أفينيوز',
      latitude: 23.5859,
      longitude: 58.4059,
      isDefault: true,
    ),
    AddressModel(
      id: 'addr-002',
      label: 'العمل',
      governorate: 'محافظة مسقط',
      wilayat: 'السيب',
      area: 'الموالح الجنوبية',
      street: 'المرحلة الرابعة',
      houseNumber: 'مبنى 14',
      landmark: 'خلف كلية الشرق الأوسط',
      latitude: 23.6220,
      longitude: 58.1894,
    ),
  ];

  static const gasProducts = [
    GasProduct(
      id: 'gas-001',
      nameAr: 'أسطوانة 11 كيلو',
      nameEn: '11 kg Cylinder',
      sizeLabel: '11 kg',
      priceOmr: 2.8,
      subtitleAr: 'مناسبة للاستخدام المنزلي اليومي.',
      subtitleEn: 'Suitable for everyday home use.',
    ),
    GasProduct(
      id: 'gas-002',
      nameAr: 'أسطوانة 22 كيلو',
      nameEn: '22 kg Cylinder',
      sizeLabel: '22 kg',
      priceOmr: 3.85,
      subtitleAr: 'خيار أكبر للمنازل والمطابخ ذات الاستهلاك الأعلى.',
      subtitleEn: 'A larger option for homes and higher-consumption kitchens.',
    ),
    GasProduct(
      id: 'gas-003',
      nameAr: 'أسطوانة 44 كيلو',
      nameEn: '44 kg Cylinder',
      sizeLabel: '44 kg',
      priceOmr: 7.25,
      subtitleAr: 'مناسبة للأنشطة التجارية والاستخدام المكثف.',
      subtitleEn: 'Suitable for commercial and heavy-duty use.',
    ),
  ];

  static const assignedDriver = DriverSnapshot(
    id: 'driver-001',
    name: 'مازن البلوشي',
    phone: '+96892345678',
    vehicleLabel: 'Toyota Hilux',
    etaMinutes: 18,
  );

  static final orders = <OrderModel>[
    OrderModel(
      orderId: 'ORD-1029',
      customerId: user.id,
      customerName: user.fullName,
      phone: user.phone,
      gasProduct: gasProducts[0],
      quantity: 2,
      address: addresses[0],
      notes: 'يرجى الاتصال قبل الوصول بخمس دقائق.',
      paymentMethod: PaymentMethod.cashOnDelivery,
      orderStatus: OrderStatus.onTheWay,
      subtotalPrice: 5.6,
      deliveryFee: 1.25,
      totalPrice: 6.85,
      createdAt: DateTime(2026, 3, 21, 10, 20),
      updatedAt: DateTime(2026, 3, 21, 10, 48),
      driver: assignedDriver,
      driverLatitude: 23.5941,
      driverLongitude: 58.3911,
      preferredDeliveryWindow: 'خلال 30 دقيقة',
    ),
    OrderModel(
      orderId: 'ORD-1021',
      customerId: user.id,
      customerName: user.fullName,
      phone: user.phone,
      gasProduct: gasProducts[1],
      quantity: 1,
      address: addresses[1],
      notes: 'التسليم عبر الاستقبال الرئيسي.',
      paymentMethod: PaymentMethod.cashOnDelivery,
      orderStatus: OrderStatus.delivered,
      subtotalPrice: 3.85,
      deliveryFee: 1.5,
      totalPrice: 5.35,
      createdAt: DateTime(2026, 3, 19, 14, 5),
      updatedAt: DateTime(2026, 3, 19, 15, 4),
      preferredDeliveryWindow: 'بعد الظهر',
    ),
    OrderModel(
      orderId: 'ORD-1014',
      customerId: user.id,
      customerName: user.fullName,
      phone: user.phone,
      gasProduct: gasProducts[2],
      quantity: 3,
      address: addresses[0],
      notes: '',
      paymentMethod: PaymentMethod.digitalWallet,
      orderStatus: OrderStatus.pendingReview,
      subtotalPrice: 21.75,
      deliveryFee: 1.25,
      totalPrice: 23.0,
      createdAt: DateTime(2026, 3, 18, 20, 15),
      updatedAt: DateTime(2026, 3, 18, 20, 15),
      preferredDeliveryWindow: 'المساء',
    ),
  ];
}
