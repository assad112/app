import 'package:driver_app/core/localization/app_strings.dart';
import 'package:driver_app/core/theme/app_theme.dart';
import 'package:driver_app/features/orders/presentation/orders_controller.dart';
import 'package:driver_app/shared/widgets/app_async_view.dart';
import 'package:driver_app/shared/widgets/order_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  ConsumerState<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(ordersControllerProvider.notifier).ensureLoaded(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ordersControllerProvider);
    final strings = context.strings;

    return Scaffold(
      appBar: AppBar(title: Text(strings.orderHistoryTitle)),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(ordersControllerProvider.notifier).refreshAll(),
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            // Search bar
            TextField(
              controller: _searchController,
              onChanged: (value) {
                ref
                    .read(ordersControllerProvider.notifier)
                    .refreshHistory(search: value);
              },
              decoration: InputDecoration(
                hintText: strings.historySearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(ordersControllerProvider.notifier)
                              .refreshHistory(search: '');
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            // Summary chip
            if (state.historyOrders.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.receipt_long_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${state.historyOrders.length} ${strings.orderHistoryTitle}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            // Orders list
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.72,
              child: AppAsyncView(
                isLoading: state.isLoading,
                errorMessage: state.errorMessage,
                isEmpty: state.historyOrders.isEmpty,
                emptyTitle: strings.noClosedOrders,
                emptyMessage: strings.noClosedOrdersSubtitle,
                onRetry: () =>
                    ref.read(ordersControllerProvider.notifier).refreshAll(),
                child: ListView.separated(
                  itemCount: state.historyOrders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return OrderCard(order: state.historyOrders[index]);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
