import 'package:flutter/material.dart';
import 'package:driver_app/core/localization/app_strings.dart';
import 'package:driver_app/core/utils/formatters.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  Color get _backgroundColor {
    switch (label) {
      case 'accepted':
      case 'Accepted':
        return const Color(0xFFD1FAE5);
      case 'on_the_way':
      case 'On the way':
        return const Color(0xFFDBEAFE);
      case 'arrived':
      case 'Arrived':
        return const Color(0xFFFEF3C7);
      case 'delivered':
      case 'Delivered':
        return const Color(0xFFD1FAE5);
      case 'cancelled':
      case 'Cancelled':
        return const Color(0xFFFEE2E2);
      case 'pending':
      case 'new_order':
      case 'New order':
        return const Color(0xFFFFF3EA);
      case 'driver_notified':
      case 'Offered to you':
        return const Color(0xFFFFF3EA);
      case 'searching_driver':
      case 'Searching':
        return const Color(0xFFF8FAFC);
      case 'no_driver_found':
      case 'No driver found':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color get _foregroundColor {
    switch (label) {
      case 'accepted':
      case 'Accepted':
        return const Color(0xFF059669);
      case 'on_the_way':
      case 'On the way':
        return const Color(0xFF2563EB);
      case 'arrived':
      case 'Arrived':
        return const Color(0xFFD97706);
      case 'delivered':
      case 'Delivered':
        return const Color(0xFF059669);
      case 'cancelled':
      case 'Cancelled':
        return const Color(0xFFDC2626);
      case 'pending':
      case 'new_order':
      case 'New order':
        return const Color(0xFFFF7A1A);
      case 'driver_notified':
      case 'Offered to you':
        return const Color(0xFFFF7A1A);
      case 'searching_driver':
      case 'Searching':
        return const Color(0xFF64748B);
      case 'no_driver_found':
      case 'No driver found':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData get _statusIcon {
    switch (label) {
      case 'accepted':
      case 'Accepted':
        return Icons.check_circle_rounded;
      case 'on_the_way':
      case 'On the way':
        return Icons.local_shipping_rounded;
      case 'arrived':
      case 'Arrived':
        return Icons.location_on_rounded;
      case 'delivered':
      case 'Delivered':
        return Icons.verified_rounded;
      case 'cancelled':
      case 'Cancelled':
        return Icons.cancel_rounded;
      case 'pending':
      case 'new_order':
      case 'New order':
        return Icons.pending_rounded;
      case 'driver_notified':
      case 'Offered to you':
        return Icons.notifications_active_rounded;
      case 'searching_driver':
      case 'Searching':
        return Icons.radar_rounded;
      case 'no_driver_found':
      case 'No driver found':
        return Icons.person_off_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalizedLabel =
        label == 'driver_notified'
            ? context.strings.isArabic
                ? 'معروض عليك'
                : 'Offered to you'
            : label == 'searching_driver'
            ? context.strings.isArabic
                ? 'جارٍ البحث'
                : 'Searching'
            : label == 'no_driver_found'
            ? context.strings.isArabic
                ? 'لا يوجد سائق'
                : 'No driver found'
            : label.contains('_')
            ? Formatters.driverStage(label, localeCode: context.strings.localeCode)
            : label;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? _statusIcon, size: 13, color: _foregroundColor),
          const SizedBox(width: 5),
          Text(
            normalizedLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: _foregroundColor,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
