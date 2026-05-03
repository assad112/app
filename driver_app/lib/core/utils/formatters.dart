import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static String currency(num value, {String localeCode = 'ar'}) {
    final formatter = NumberFormat.currency(
      locale: localeCode == 'ar' ? 'ar_OM' : 'en_US',
      symbol: localeCode == 'ar' ? 'ر.ع.' : 'OMR',
      decimalDigits: 3,
    );

    return formatter.format(value);
  }

  static String dateTime(DateTime? value, {String localeCode = 'ar'}) {
    if (value == null) {
      return localeCode == 'ar' ? 'غير متاح' : 'Unavailable';
    }

    final formatter = DateFormat(
      'dd MMM, hh:mm a',
      localeCode == 'ar' ? 'ar' : 'en_US',
    );
    return formatter.format(value.toLocal());
  }

  static String time(DateTime? value, {String localeCode = 'ar'}) {
    if (value == null) {
      return '--:--';
    }

    final formatter = DateFormat(
      'hh:mm a',
      localeCode == 'ar' ? 'ar' : 'en_US',
    );
    return formatter.format(value.toLocal());
  }

  static String paymentMethod(String value, {String localeCode = 'ar'}) {
    switch (value) {
      case 'cash_on_delivery':
        return localeCode == 'ar' ? 'الدفع عند الاستلام' : 'Cash on delivery';
      case 'card':
        return localeCode == 'ar' ? 'بطاقة' : 'Card';
      case 'cash':
        return localeCode == 'ar' ? 'نقدًا' : 'Cash';
      default:
        return value.replaceAll('_', ' ');
    }
  }

  static String driverStage(String value, {String localeCode = 'ar'}) {
    switch (value) {
      case 'new_order':
        return localeCode == 'ar' ? 'طلب جديد' : 'New order';
      case 'accepted':
        return localeCode == 'ar' ? 'مقبول' : 'Accepted';
      case 'on_the_way':
        return localeCode == 'ar' ? 'في الطريق' : 'On the way';
      case 'arrived':
        return localeCode == 'ar' ? 'تم الوصول' : 'Arrived';
      case 'delivered':
        return localeCode == 'ar' ? 'تم التسليم' : 'Delivered';
      case 'cancelled':
        return localeCode == 'ar' ? 'ملغي' : 'Cancelled';
      case 'pending':
        return localeCode == 'ar' ? 'معلق' : 'Pending';
      default:
        return value;
    }
  }
}
