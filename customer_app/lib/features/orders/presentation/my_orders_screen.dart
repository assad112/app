import 'package:customer_app/core/constants/app_colors.dart';
import 'package:customer_app/core/widgets/app_card.dart';
import 'package:customer_app/core/widgets/primary_button.dart';
import 'package:customer_app/core/widgets/status_chip.dart';
import 'package:customer_app/shared/localization/app_copy.dart';
import 'package:customer_app/shared/models/order_model.dart';
import 'package:customer_app/shared/models/order_status.dart';
import 'package:customer_app/shared/models/payment_method.dart';
import 'package:customer_app/shared/state/customer_app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class MyOrdersScreen extends ConsumerStatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  ConsumerState<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends ConsumerState<MyOrdersScreen> {
  OrderStatus? _selectedStatus;

  Future<void> _refreshOrders() async {
    await ref.read(customerAppControllerProvider.notifier).refreshOrdersFromBackend();
  }

  bool _matchesStatus(OrderModel order, OrderStatus? status) {
    if (status == null) {
      return true;
    }

    if (status == OrderStatus.pendingReview) {
      return const {
        OrderStatus.pendingReview,
        OrderStatus.searchingDriver,
        OrderStatus.driverNotified,
        OrderStatus.noDriverFound,
      }.contains(order.orderStatus);
    }

    return order.orderStatus == status;
  }

  String _formatDate(DateTime value, AppCopy copy) {
    final locale = copy.isRtl ? 'ar_OM' : 'en_OM';
    return DateFormat('dd MMM yyyy - hh:mm a', locale).format(value);
  }

  String _formatShortTime(DateTime value, AppCopy copy) {
    final locale = copy.isRtl ? 'ar_OM' : 'en_OM';
    return DateFormat('hh:mm a', locale).format(value);
  }

  String _formatMoney(double value, AppCopy copy) {
    final locale = copy.isRtl ? 'ar_OM' : 'en_OM';
    final amount = NumberFormat('#,##0.000', locale).format(value);
    return '$amount ${copy.t('common.omr')}';
  }

  int _countByStatus(List<OrderModel> orders, OrderStatus status) {
    return orders.where((item) => _matchesStatus(item, status)).length;
  }

  IconData _statusIcon(OrderStatus? status) {
    switch (status) {
      case null:
        return Icons.widgets_rounded;
      case OrderStatus.searchingDriver:
        return Icons.radar_rounded;
      case OrderStatus.driverNotified:
        return Icons.notifications_active_rounded;
      case OrderStatus.noDriverFound:
        return Icons.person_off_rounded;
      case OrderStatus.pendingReview:
        return Icons.pending_actions_rounded;
      case OrderStatus.accepted:
        return Icons.verified_rounded;
      case OrderStatus.preparing:
        return Icons.local_fire_department_rounded;
      case OrderStatus.onTheWay:
        return Icons.route_rounded;
      case OrderStatus.delivered:
        return Icons.inventory_2_rounded;
      case OrderStatus.cancelled:
        return Icons.cancel_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(customerAppControllerProvider);
    final copy = AppCopy(appState.language);
    final allOrders = appState.orders;
    final filteredOrders = _selectedStatus == null
        ? allOrders
        : allOrders.where((item) => _matchesStatus(item, _selectedStatus)).toList();
    final activeOrders = allOrders
        .where(
          (item) =>
              item.orderStatus != OrderStatus.delivered &&
              item.orderStatus != OrderStatus.cancelled,
        )
        .length;
    final completedOrders = _countByStatus(allOrders, OrderStatus.delivered);
    final totalSpent = allOrders.fold<double>(
      0,
      (sum, item) => sum + item.totalPrice,
    );

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refreshOrders,
        color: AppColors.brand,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OrdersHeroCard(
                copy: copy,
                totalOrders: allOrders.length,
                activeOrders: activeOrders,
                completedOrders: completedOrders,
                totalSpentLabel: _formatMoney(totalSpent, copy),
              ),
              const SizedBox(height: 14),
              _OrdersFilterWrap(
                copy: copy,
                selectedStatus: _selectedStatus,
                countAll: allOrders.length,
                countPending: _countByStatus(
                  allOrders,
                  OrderStatus.pendingReview,
                ),
                countAccepted: _countByStatus(allOrders, OrderStatus.accepted),
                countDelivered: _countByStatus(allOrders, OrderStatus.delivered),
                countCancelled: _countByStatus(allOrders, OrderStatus.cancelled),
                statusIcon: _statusIcon,
                onSelected: (status) {
                  setState(() {
                    _selectedStatus = status;
                  });
                },
              ),
              const SizedBox(height: 18),
              if (filteredOrders.isEmpty)
                _OrdersEmptyState(copy: copy)
              else
                Column(
                  children: [
                    for (final order in filteredOrders) ...[
                      _OrderCard(
                        order: order,
                        copy: copy,
                        formattedDate: _formatDate(order.createdAt, copy),
                        formattedUpdatedAt: _formatShortTime(
                          order.updatedAt,
                          copy,
                        ),
                        formattedTotalPrice: _formatMoney(order.totalPrice, copy),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrdersHeroCard extends StatelessWidget {
  const _OrdersHeroCard({
    required this.copy,
    required this.totalOrders,
    required this.activeOrders,
    required this.completedOrders,
    required this.totalSpentLabel,
  });

  final AppCopy copy;
  final int totalOrders;
  final int activeOrders;
  final int completedOrders;
  final String totalSpentLabel;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w800,
    );
    final subtitleStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.45);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, Color(0xFF14284A), Color(0xFF1A325A)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22091D33),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            top: -36,
            end: -36,
            child: Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          PositionedDirectional(
            bottom: -30,
            start: -30,
            child: Container(
              height: 92,
              width: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.brand.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: AppColors.brand,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(copy.t('orders.title'), style: titleStyle),
                        const SizedBox(height: 4),
                        Text(copy.t('orders.subtitle'), style: subtitleStyle),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.35,
                children: [
                  _HeroMetricTile(
                    icon: Icons.format_list_bulleted_rounded,
                    label: copy.isRtl ? 'كل الطلبات' : 'Total orders',
                    value: '$totalOrders',
                  ),
                  _HeroMetricTile(
                    icon: Icons.bolt_rounded,
                    label: copy.isRtl ? 'الطلبات النشطة' : 'Active now',
                    value: '$activeOrders',
                  ),
                  _HeroMetricTile(
                    icon: Icons.task_alt_rounded,
                    label: copy.isRtl ? 'المكتملة' : 'Completed',
                    value: '$completedOrders',
                  ),
                  _HeroMetricTile(
                    icon: Icons.payments_rounded,
                    label: copy.isRtl ? 'إجمالي القيمة' : 'Total value',
                    value: totalSpentLabel,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetricTile extends StatelessWidget {
  const _HeroMetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Container(
            height: 30,
            width: 30,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
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

class _OrdersFilterWrap extends StatelessWidget {
  const _OrdersFilterWrap({
    required this.copy,
    required this.selectedStatus,
    required this.countAll,
    required this.countPending,
    required this.countAccepted,
    required this.countDelivered,
    required this.countCancelled,
    required this.statusIcon,
    required this.onSelected,
  });

  final AppCopy copy;
  final OrderStatus? selectedStatus;
  final int countAll;
  final int countPending;
  final int countAccepted;
  final int countDelivered;
  final int countCancelled;
  final IconData Function(OrderStatus? status) statusIcon;
  final ValueChanged<OrderStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = <_StatusFilterItem>[
      _StatusFilterItem(
        status: null,
        label: copy.t('orders.all'),
        count: countAll,
        tone: AppColors.navy,
      ),
      _StatusFilterItem(
        status: OrderStatus.pendingReview,
        label: copy.t(OrderStatus.pendingReview.labelKey()),
        count: countPending,
        tone: OrderStatus.pendingReview.tone(),
      ),
      _StatusFilterItem(
        status: OrderStatus.accepted,
        label: copy.t(OrderStatus.accepted.labelKey()),
        count: countAccepted,
        tone: OrderStatus.accepted.tone(),
      ),
      _StatusFilterItem(
        status: OrderStatus.delivered,
        label: copy.t(OrderStatus.delivered.labelKey()),
        count: countDelivered,
        tone: OrderStatus.delivered.tone(),
      ),
      _StatusFilterItem(
        status: OrderStatus.cancelled,
        label: copy.t(OrderStatus.cancelled.labelKey()),
        count: countCancelled,
        tone: OrderStatus.cancelled.tone(),
      ),
    ];

    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: AppColors.navy.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 8),
                Text(
                  copy.isRtl ? 'تصفية الطلبات' : 'Filter orders',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  copy.isRtl ? 'اسحب يمين/يسار' : 'Swipe left/right',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return _StatusFilterPill(
                  label: item.label,
                  count: item.count,
                  icon: statusIcon(item.status),
                  tone: item.tone,
                  isSelected: selectedStatus == item.status,
                  onTap: () => onSelected(item.status),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilterItem {
  const _StatusFilterItem({
    required this.status,
    required this.label,
    required this.count,
    required this.tone,
  });

  final OrderStatus? status;
  final String label;
  final int count;
  final Color tone;
}

class _StatusFilterPill extends StatelessWidget {
  const _StatusFilterPill({
    required this.label,
    required this.count,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.tone = AppColors.navy,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color tone;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectedBackground = tone.withValues(alpha: 0.14);
    final idleBackground = Colors.white;
    final textColor = isSelected ? tone : AppColors.navy;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? selectedBackground : idleBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? tone.withValues(alpha: 0.32) : AppColors.stroke,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 6),
            Flexible(
              fit: FlexFit.loose,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: textColor),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected ? tone : AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isSelected ? Colors.white : AppColors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersEmptyState extends StatelessWidget {
  const _OrdersEmptyState({required this.copy});

  final AppCopy copy;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          Container(
            height: 72,
            width: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.brand, AppColors.brandDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x30FF7A1A),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.inbox_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            copy.t('orders.empty'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            copy.isRtl
                ? 'غيّر الفلتر أو أنشئ طلبًا جديدًا وسيظهر هنا مباشرة.'
                : 'Try another filter or create a new order and it will appear here.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({
    required this.order,
    required this.copy,
    required this.formattedDate,
    required this.formattedUpdatedAt,
    required this.formattedTotalPrice,
  });

  final OrderModel order;
  final AppCopy copy;
  final String formattedDate;
  final String formattedUpdatedAt;
  final String formattedTotalPrice;

  String _paymentLabel() {
    if (order.paymentMethod == PaymentMethod.digitalWallet) {
      return copy.t('order.wallet');
    }
    return copy.t('order.cash');
  }

  String _orderHeadline() => order.localizedItemsSummary(copy.isRtl);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(customerAppControllerProvider.notifier);
    final statusTone = order.orderStatus.tone();
    final statusSoft = order.orderStatus.softTone();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusSoft.withValues(alpha: 0.4), Colors.white],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: statusTone.withValues(alpha: 0.22)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14091D33),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderId,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppColors.navy,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _orderHeadline(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(status: order.orderStatus, copy: copy),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.stroke),
            ),
            child: Column(
              children: [
                _OrderQuickMeta(
                  icon: Icons.place_outlined,
                  label: '${order.address.area} - ${order.address.wilayat}',
                ),
                const SizedBox(height: 8),
                _OrderQuickMeta(
                  icon: Icons.calendar_today_rounded,
                  label: formattedDate,
                ),
                const SizedBox(height: 8),
                _OrderQuickMeta(
                  icon: Icons.payments_outlined,
                  label: _paymentLabel(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (order.isMultiItem || order.hasChildOrders) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (order.isMultiItem)
                  _OrderMetaChip(
                    icon: Icons.layers_rounded,
                    label: copy.t('orders.multiItemBadge'),
                    tone: AppColors.brand,
                  ),
                if (order.hasChildOrders)
                  _OrderMetaChip(
                    icon: Icons.alt_route_rounded,
                    label:
                        '${copy.t('orders.childDeliveries')}: ${order.childOrders.length}',
                    tone: AppColors.teal,
                  ),
                _OrderMetaChip(
                  icon: Icons.category_outlined,
                  label:
                      '${copy.t('orders.itemsCount')}: ${order.items.isNotEmpty ? order.items.length : 1}',
                  tone: AppColors.navy,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _OrderItemsPreview(order: order, copy: copy),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _OrderMetaChip(
                icon: Icons.sync_rounded,
                label: copy.isRtl
                    ? 'آخر تحديث: $formattedUpdatedAt'
                    : 'Updated: $formattedUpdatedAt',
                tone: AppColors.brandDeep,
              ),
              _OrderMetaChip(
                icon: Icons.receipt_long_rounded,
                label: formattedTotalPrice,
                tone: AppColors.navy,
              ),
              if (order.driver != null &&
                  order.orderStatus != OrderStatus.delivered &&
                  order.orderStatus != OrderStatus.cancelled)
                _OrderMetaChip(
                  icon: Icons.schedule_rounded,
                  label:
                      '${copy.t('tracking.eta')}: ${order.driver!.etaMinutes} ${copy.isRtl ? 'دقيقة' : 'min'}',
                  tone: AppColors.teal,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: copy.t('orders.reorder'),
                  onPressed: () async {
                    final created = await controller.reorder(order.orderId);
                    if (!context.mounted || created == null) {
                      return;
                    }
                    context.go('/tracking/${created.orderId}');
                  },
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  label: copy.t('orders.track'),
                  onPressed: () => context.push('/tracking/${order.orderId}'),
                  icon: const Icon(Icons.route_rounded),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderItemsPreview extends StatelessWidget {
  const _OrderItemsPreview({required this.order, required this.copy});

  final OrderModel order;
  final AppCopy copy;

  @override
  Widget build(BuildContext context) {
    final items = order.items.isNotEmpty
        ? order.items
        : [
            OrderLineItem(
              id: 'fallback-${order.orderId}',
              orderId: order.orderId,
              productId: order.gasProduct.id,
              productCode: order.gasProduct.id,
              productNameAr: order.gasProduct.nameAr,
              productNameEn: order.gasProduct.nameEn,
              sizeLabel: order.gasProduct.sizeLabel,
              driverInventoryCode: '',
              quantity: order.quantity,
              unitPrice: order.gasProduct.priceOmr,
              deliveryFee: order.deliveryFee,
              lineTotal: order.subtotalPrice,
            ),
          ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.t('tracking.orderContents'),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          for (final item in items) ...[
            Row(
              children: [
                Container(
                  height: 9,
                  width: 9,
                  decoration: const BoxDecoration(
                    color: AppColors.brand,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${item.localizedName(copy.isRtl)} x${item.quantity}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (item.sizeLabel.trim().isNotEmpty)
                  Text(
                    item.sizeLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            if (item != items.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _OrderQuickMeta extends StatelessWidget {
  const _OrderQuickMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.navy),
          ),
        ),
      ],
    );
  }
}

class _OrderMetaChip extends StatelessWidget {
  const _OrderMetaChip({
    required this.icon,
    required this.label,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: tone),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: tone,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
