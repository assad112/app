import 'package:driver_app/core/localization/app_strings.dart';
import 'package:driver_app/core/theme/app_theme.dart';
import 'package:driver_app/core/utils/formatters.dart';
import 'package:driver_app/features/auth/presentation/auth_controller.dart';
import 'package:driver_app/features/orders/presentation/order_error_resolver.dart';
import 'package:driver_app/features/orders/presentation/orders_controller.dart';
import 'package:driver_app/features/tracking/presentation/screens/active_delivery_screen.dart';
import 'package:driver_app/shared/widgets/app_async_view.dart';
import 'package:driver_app/shared/widgets/app_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OrderDetailsScreen extends ConsumerWidget {
  const OrderDetailsScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderState = ref.watch(orderDetailsProvider(orderId));
    final pendingIds = ref.watch(ordersControllerProvider).pendingOrderIds;
    final currentDriverId = ref.watch(authControllerProvider).driver?.id;
    final isBusy = pendingIds.contains(orderId);
    final strings = context.strings;

    return Scaffold(
      appBar: AppBar(title: Text(strings.orderNumber(orderId))),
      body: orderState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, _) {
          final isUnassigned = isOrderNotAvailableForDriverError(error);
          return AppAsyncView(
            isLoading: false,
            errorMessage: resolveDriverOrderErrorMessage(error, strings),
            onRetry: () {
              ref.read(ordersControllerProvider.notifier).refreshAll(silent: true);
              if (isUnassigned) {
                Navigator.of(context).maybePop();
                return;
              }
              ref.invalidate(orderDetailsProvider(orderId));
            },
            child: const SizedBox.shrink(),
          );
        },
        data: (order) {
          final isAssignedToCurrentDriver =
              currentDriverId == order.assignedDriverId;
          final isOfferForCurrentDriver = order.isOfferForDriver(currentDriverId);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Customer hero card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D1732), Color(0xFF1E3A7A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: Text(
                          order.customerName.isNotEmpty
                              ? order.customerName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.customerName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.phone_outlined,
                                size: 13,
                                color: Colors.white54,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                order.customerPhone,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    StatusChip(label: order.driverStage),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Order details card
              Container(
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
                child: Column(
                  children: [
                    _DetailRow(
                      icon: Icons.local_fire_department_rounded,
                      iconColor: AppColors.primary,
                      iconBg: AppColors.primarySoft,
                      label: strings.gasType,
                      value: order.gasType,
                    ),
                    _Divider(),
                    _DetailRow(
                      icon: Icons.inventory_2_outlined,
                      iconColor: AppColors.info,
                      iconBg: AppColors.infoSoft,
                      label: strings.quantity,
                      value: order.quantity.toString(),
                    ),
                    _Divider(),
                    _DetailRow(
                      icon: Icons.payments_outlined,
                      iconColor: AppColors.success,
                      iconBg: AppColors.successSoft,
                      label: strings.payment,
                      value: Formatters.paymentMethod(
                        order.paymentMethod,
                        localeCode: strings.localeCode,
                      ),
                    ),
                    _Divider(),
                    _DetailRow(
                      icon: Icons.attach_money_rounded,
                      iconColor: AppColors.warning,
                      iconBg: AppColors.warningSoft,
                      label: strings.total,
                      value: Formatters.currency(
                        order.totalAmount,
                        localeCode: strings.localeCode,
                      ),
                      bold: true,
                    ),
                    _Divider(),
                    _DetailRow(
                      icon: Icons.location_on_outlined,
                      iconColor: AppColors.error,
                      iconBg: AppColors.errorSoft,
                      label: strings.address,
                      value: order.addressFull,
                    ),
                    if (order.notes.isNotEmpty) ...[
                      _Divider(),
                      _DetailRow(
                        icon: Icons.notes_rounded,
                        iconColor: AppColors.textSecondary,
                        iconBg: AppColors.surfaceAlt,
                        label: strings.notes,
                        value: order.notes,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Actions
              if (isOfferForCurrentDriver) ...[
                FilledButton(
                  onPressed: isBusy
                      ? null
                      : () async {
                          try {
                            await ref
                                .read(ordersControllerProvider.notifier)
                                .acceptOrder(order.id);
                            if (!context.mounted) return;
                            ref.invalidate(orderDetailsProvider(order.id));
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ActiveDeliveryScreen(orderId: order.id),
                              ),
                            );
                          } catch (error) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error.toString())),
                            );
                          }
                        },
                  child: isBusy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(strings.acceptOrder),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: isBusy
                      ? null
                      : () async {
                          try {
                            await ref
                                .read(ordersControllerProvider.notifier)
                                .rejectOrder(order.id);
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                          } catch (error) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error.toString())),
                            );
                          }
                        },
                  child: Text(strings.rejectForMe),
                ),
              ] else if (isAssignedToCurrentDriver && order.isActive) ...[
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ActiveDeliveryScreen(orderId: order.id),
                      ),
                    );
                  },
                  child: Text(strings.openActiveDelivery),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 68, endIndent: 20);
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    this.bold = false,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                    color: bold ? AppColors.textPrimary : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
