import 'package:driver_app/core/localization/app_strings.dart';
import 'package:driver_app/core/theme/app_theme.dart';
import 'package:driver_app/features/orders/presentation/orders_controller.dart';
import 'package:driver_app/features/orders/presentation/screens/order_details_screen.dart';
import 'package:driver_app/features/orders/presentation/screens/order_history_screen.dart';
import 'package:driver_app/shared/widgets/app_async_view.dart';
import 'package:driver_app/shared/widgets/order_card.dart';
import 'package:driver_app/shared/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IncomingOrdersScreen extends ConsumerStatefulWidget {
  const IncomingOrdersScreen({super.key});

  @override
  ConsumerState<IncomingOrdersScreen> createState() =>
      _IncomingOrdersScreenState();
}

class _IncomingOrdersScreenState extends ConsumerState<IncomingOrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(
      () => ref.read(ordersControllerProvider.notifier).ensureLoaded(),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ordersControllerProvider);
    final strings = context.strings;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.ordersTitle),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
              );
            },
            icon: const Icon(Icons.history_rounded),
            tooltip: strings.orderHistoryTitle,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(ordersControllerProvider.notifier).refreshAll(),
        color: AppColors.primary,
        child: ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            // Search bar
            TextField(
              controller: _searchController,
              onChanged: (value) {
                ref
                    .read(ordersControllerProvider.notifier)
                    .refreshAvailable(search: value);
              },
              decoration: InputDecoration(
                hintText: strings.ordersSearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(ordersControllerProvider.notifier)
                              .refreshAvailable(search: '');
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            // Tab bar
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(4),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textTertiary,
                labelStyle: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                unselectedLabelStyle: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inbox_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          strings.availableTab(state.availableOrders.length),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.local_shipping_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text(strings.activeTab(state.activeOrders.length)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.72,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Available orders tab
                  AppAsyncView(
                    isLoading: state.isLoading,
                    errorMessage: state.errorMessage,
                    isEmpty: state.availableOrders.isEmpty,
                    emptyTitle: strings.noLiveRequests,
                    emptyMessage: strings.noLiveRequestsSubtitle,
                    onRetry: () => ref
                        .read(ordersControllerProvider.notifier)
                        .refreshAll(),
                    child: ListView.separated(
                      itemCount: state.availableOrders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final order = state.availableOrders[index];
                        return OrderCard(
                          order: order,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    OrderDetailsScreen(orderId: order.id),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  // Active orders tab
                  AppAsyncView(
                    isLoading: state.isLoading,
                    errorMessage: state.errorMessage,
                    isEmpty: state.activeOrders.isEmpty,
                    emptyTitle: strings.noActiveDelivery,
                    emptyMessage: strings.noActiveDeliverySubtitle,
                    onRetry: () => ref
                        .read(ordersControllerProvider.notifier)
                        .refreshAll(),
                    child: ListView(
                      children: [
                        SectionHeader(
                          title: strings.currentDeliveryQueue,
                          subtitle: strings.currentDeliveryQueueSubtitle,
                        ),
                        const SizedBox(height: 12),
                        ...state.activeOrders.map(
                          (order) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: OrderCard(
                              order: order,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        OrderDetailsScreen(orderId: order.id),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
