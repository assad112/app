import 'package:driver_app/core/localization/app_strings.dart';
import 'package:driver_app/core/theme/app_theme.dart';
import 'package:driver_app/core/utils/formatters.dart';
import 'package:driver_app/shared/models/delivery_order.dart';
import 'package:driver_app/shared/widgets/app_chip.dart';
import 'package:flutter/material.dart';

class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, this.onTap, this.trailing});

  final DeliveryOrder order;
  final VoidCallback? onTap;
  final Widget? trailing;

  Color get _accentColor {
    switch (order.driverStage) {
      case 'on_the_way':
        return AppColors.info;
      case 'arrived':
        return AppColors.warning;
      case 'delivered':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left accent strip
              Container(width: 4, color: _accentColor),
              // Card content
              Expanded(
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row
                        Row(
                          children: [
                            // Customer avatar
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: Text(
                                  order.customerName.isNotEmpty
                                      ? order.customerName[0].toUpperCase()
                                      : '?',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order.customerName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    strings.orderNumber(order.id),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.textTertiary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            StatusChip(label: order.driverStage),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: 12),
                        // Info row
                        Row(
                          children: [
                            Expanded(
                              child: _InfoItem(
                                icon: Icons.local_fire_department_rounded,
                                label: order.gasType,
                                iconColor: AppColors.primary,
                              ),
                            ),
                            Expanded(
                              child: _InfoItem(
                                icon: Icons.inventory_2_outlined,
                                label: '${strings.quantity} ${order.quantity}',
                                iconColor: AppColors.info,
                              ),
                            ),
                            Expanded(
                              child: _InfoItem(
                                icon: Icons.payments_outlined,
                                label: Formatters.currency(
                                  order.totalAmount,
                                  localeCode: strings.localeCode,
                                ),
                                iconColor: AppColors.success,
                                bold: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Address row
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                order.addressFull,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Footer row
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 13,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                Formatters.dateTime(
                                  order.updatedAt ?? order.createdAt,
                                  localeCode: strings.localeCode,
                                ),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppColors.textTertiary,
                                      fontSize: 11,
                                    ),
                              ),
                            ),
                            if (trailing != null) trailing!,
                            if (onTap != null)
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: AppColors.textTertiary,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.iconColor,
    this.bold = false,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: bold ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
