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
    final bottomInset = MediaQuery.paddingOf(context).bottom;

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
              ref
                  .read(ordersControllerProvider.notifier)
                  .refreshAll(silent: true);
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
          final isOfferForCurrentDriver = order.isOfferForDriver(
            currentDriverId,
          );
          final itemSummary = order.localizedItemsSummary(strings.isArabic);
          final hasBottomAction =
              isOfferForCurrentDriver ||
              (isAssignedToCurrentDriver && order.isActive);
          final contentBottomPadding = hasBottomAction
              ? 144 + bottomInset
              : 20 + bottomInset;

          return ListView(
            padding: EdgeInsets.fromLTRB(20, 20, 20, contentBottomPadding),
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
                        color: Colors.white.withValues(alpha: 0.15),
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
              if (order.isSplitChild)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warningSoft,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.alt_route_rounded,
                          color: AppColors.warning,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.splitOrderBadge,
                              style: const TextStyle(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              strings.childOrderHint,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                height: 1.45,
                              ),
                            ),
                            if ((order.parentOrderId ?? '').trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '${strings.parentOrderReference}: ${order.parentOrderId}',
                                  style: const TextStyle(
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              // Order details card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.05),
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
                      value: itemSummary,
                    ),
                    _Divider(),
                    _DetailRow(
                      icon: Icons.inventory_2_outlined,
                      iconColor: AppColors.info,
                      iconBg: AppColors.infoSoft,
                      label: strings.quantity,
                      value: order.totalRequestedQuantity.toString(),
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
              if (order.hasStructuredItems) ...[
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.multiItemSummary,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        for (final item in order.items) ...[
                          Row(
                            children: [
                              Container(
                                width: 9,
                                height: 9,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.localizedName(strings.isArabic),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              Text(
                                'x${item.quantity}',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              if (item.sizeLabel.trim().isNotEmpty) ...[
                                const SizedBox(width: 10),
                                Text(
                                  item.sizeLabel,
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: AppColors.textTertiary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ],
                          ),
                          if (item != order.items.last)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Divider(height: 1),
                            ),
                        ],
                        if ((order.fulfillmentInventoryCode ?? '')
                            .trim()
                            .isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              '${strings.inventoryGroup}: ${order.fulfillmentInventoryCode}',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: AppColors.info,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: orderState.whenOrNull(
        data: (order) {
          final isAssignedToCurrentDriver =
              currentDriverId == order.assignedDriverId;
          final isOfferForCurrentDriver = order.isOfferForDriver(
            currentDriverId,
          );

          if (!isOfferForCurrentDriver &&
              !(isAssignedToCurrentDriver && order.isActive)) {
            return null;
          }

          return SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (isOfferForCurrentDriver) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: isBusy
                              ? null
                              : () async {
                                  try {
                                    await ref
                                        .read(ordersControllerProvider.notifier)
                                        .acceptOrder(order.id);
                                    if (!context.mounted) return;
                                    ref.invalidate(
                                      orderDetailsProvider(order.id),
                                    );
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (_) => ActiveDeliveryScreen(
                                          orderId: order.id,
                                        ),
                                      ),
                                    );
                                  } catch (error) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(error.toString())),
                                    );
                                  }
                                },
                          icon: isBusy
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline_rounded),
                          label: Text(strings.acceptOrder),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
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
                          icon: const Icon(Icons.close_rounded),
                          label: Text(strings.rejectForMe),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            side: const BorderSide(color: Color(0xFFD6DEE8)),
                            foregroundColor: AppColors.textPrimary,
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                    ] else if (isAssignedToCurrentDriver && order.isActive) ...[
                      Container(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF8C2B), Color(0xFFFF6A00)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFFF7A1A,
                              ).withValues(alpha: 0.28),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ActiveDeliveryScreen(orderId: order.id),
                                ),
                              );
                            },
                            icon: const Icon(Icons.local_shipping_rounded),
                            label: Text(strings.openActiveDelivery),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(50),
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
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
