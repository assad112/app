import 'package:driver_app/core/utils/formatters.dart';
import 'package:driver_app/core/localization/app_strings.dart';
import 'package:driver_app/core/theme/app_theme.dart';
import 'package:driver_app/features/auth/presentation/auth_controller.dart';
import 'package:driver_app/features/earnings/presentation/screens/earnings_screen.dart';
import 'package:driver_app/features/home/presentation/home_controller.dart';
import 'package:driver_app/features/orders/presentation/screens/order_details_screen.dart';
import 'package:driver_app/features/orders/presentation/screens/order_history_screen.dart';
import 'package:driver_app/features/tracking/presentation/screens/active_delivery_screen.dart';
import 'package:driver_app/features/profile/presentation/profile_controller.dart';
import 'package:driver_app/shared/widgets/app_async_view.dart';
import 'package:driver_app/shared/widgets/order_card.dart';
import 'package:driver_app/shared/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(homeControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final driver = authState.driver;
    final strings = context.strings;
    final isOnline = driver?.isOnline == true;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(homeControllerProvider.notifier).refresh(),
          color: AppColors.primary,
          child: ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.all(20),
            children: [
              // ─── Header ───────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.helloDriver(
                            driver?.name ?? strings.driverLabel,
                          ),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isOnline
                                    ? AppColors.success
                                    : AppColors.textTertiary,
                                shape: BoxShape.circle,
                                boxShadow: isOnline
                                    ? [
                                        BoxShadow(
                                          color: AppColors.success.withOpacity(
                                            0.4,
                                          ),
                                          blurRadius: 6,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                isOnline
                                    ? strings.onlineReadyMessage
                                    : strings.offlineReadyMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: isOnline
                                          ? AppColors.success
                                          : AppColors.textTertiary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Online toggle
                  _OnlineToggle(
                    isOnline: isOnline,
                    onChanged: (value) async {
                      await ref
                          .read(profileControllerProvider.notifier)
                          .setAvailability(
                            online: value,
                            busy: driver?.isBusy == true,
                          );
                      await ref
                          .read(authControllerProvider.notifier)
                          .refreshDriver();
                      await ref
                          .read(homeControllerProvider.notifier)
                          .refreshSilently();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // ─── Driver status card ───────────────────────
              _DriverStatusCard(
                isOnline: isOnline,
                vehicleLabel: driver?.vehicleLabel.isNotEmpty == true
                    ? driver!.vehicleLabel
                    : strings.notSet,
                statusLabel: driver?.isBusy == true
                    ? strings.busy
                    : strings.available,
                isBusy: driver?.isBusy == true,
              ),
              const SizedBox(height: 20),
              // ─── Dashboard metrics ────────────────────────
              dashboardState.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
                error: (error, _) => AppAsyncView(
                  isLoading: false,
                  errorMessage: error.toString(),
                  onRetry: () =>
                      ref.read(homeControllerProvider.notifier).refresh(),
                  child: const SizedBox.shrink(),
                ),
                data: (dashboard) {
                  final activeOrder = dashboard.activeOrders.isEmpty
                      ? null
                      : dashboard.activeOrders.first;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Metrics grid
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              title: strings.availableNow,
                              value: dashboard.availableOrdersCount.toString(),
                              icon: Icons.inbox_rounded,
                              iconBg: AppColors.primarySoft,
                              iconColor: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MetricCard(
                              title: strings.activeDeliveries,
                              value: dashboard.activeDeliveries.toString(),
                              icon: Icons.local_shipping_rounded,
                              iconBg: AppColors.infoSoft,
                              iconColor: AppColors.info,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              title: strings.completed,
                              value: dashboard.totalCompleted.toString(),
                              icon: Icons.verified_rounded,
                              iconBg: AppColors.successSoft,
                              iconColor: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MetricCard(
                              title: strings.todayEarnings,
                              value: Formatters.currency(
                                dashboard.todayEarnings,
                                localeCode: strings.localeCode,
                              ),
                              icon: Icons.payments_rounded,
                              iconBg: AppColors.warningSoft,
                              iconColor: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Quick actions
                      SectionHeader(
                        title: strings.quickActions,
                        subtitle: strings.quickActionsSubtitle,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.stacked_line_chart_rounded,
                              title: strings.earnings,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF34D399)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const EarningsScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.history_rounded,
                              title: strings.history,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const OrderHistoryScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      // Active delivery
                      if (activeOrder != null) ...[
                        const SizedBox(height: 24),
                        SectionHeader(
                          title: strings.activeDelivery,
                          trailing: TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ActiveDeliveryScreen(
                                    orderId: activeOrder.id,
                                  ),
                                ),
                              );
                            },
                            child: Text(strings.open),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OrderCard(
                          order: activeOrder,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ActiveDeliveryScreen(
                                  orderId: activeOrder.id,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                      // Incoming requests
                      const SizedBox(height: 24),
                      SectionHeader(
                        title: strings.incomingRequests,
                        subtitle: strings.incomingRequestsSubtitle,
                      ),
                      const SizedBox(height: 12),
                      AppAsyncView(
                        isLoading: false,
                        errorMessage: null,
                        isEmpty: dashboard.availableOrders.isEmpty,
                        emptyTitle: strings.noPendingOrders,
                        emptyMessage: strings.noPendingOrdersSubtitle,
                        child: Column(
                          children: dashboard.availableOrders
                              .take(3)
                              .map(
                                (order) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: OrderCard(
                                    order: order,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => OrderDetailsScreen(
                                            orderId: order.id,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Online Toggle ───────────────────────────────────────────────────────────

class _OnlineToggle extends StatelessWidget {
  const _OnlineToggle({required this.isOnline, required this.onChanged});

  final bool isOnline;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!isOnline),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 64,
        height: 34,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isOnline ? AppColors.success : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: isOnline
                  ? AlignmentDirectional.centerEnd
                  : AlignmentDirectional.centerStart,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  isOnline
                      ? Icons.power_settings_new_rounded
                      : Icons.power_off_outlined,
                  size: 14,
                  color: isOnline ? AppColors.success : AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Driver status card ──────────────────────────────────────────────────────

class _DriverStatusCard extends StatelessWidget {
  const _DriverStatusCard({
    required this.isOnline,
    required this.vehicleLabel,
    required this.statusLabel,
    required this.isBusy,
  });

  final bool isOnline;
  final String vehicleLabel;
  final String statusLabel;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1732), Color(0xFF1E3A7A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D1732).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatusBadgeItem(
              icon: Icons.wifi_tethering_rounded,
              label: isOnline
                  ? _locStr(context, 'online')
                  : _locStr(context, 'offline'),
              active: isOnline,
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white12),
          Expanded(
            child: _StatusBadgeItem(
              icon: Icons.local_shipping_rounded,
              label: vehicleLabel,
              active: true,
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white12),
          Expanded(
            child: _StatusBadgeItem(
              icon: isBusy
                  ? Icons.work_history_rounded
                  : Icons.check_circle_outline_rounded,
              label: statusLabel,
              active: !isBusy,
            ),
          ),
        ],
      ),
    );
  }

  String _locStr(BuildContext context, String key) {
    final strings = context.strings;
    if (key == 'online') return strings.online;
    if (key == 'offline') return strings.offline;
    return '';
  }
}

class _StatusBadgeItem extends StatelessWidget {
  const _StatusBadgeItem({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 22, color: active ? Colors.white : Colors.white38),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? Colors.white : Colors.white38,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─── Metric card ─────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Quick action card ────────────────────────────────────────────────────────

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white70,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
