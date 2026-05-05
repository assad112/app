import 'package:driver_app/core/localization/app_strings.dart';
import 'package:driver_app/core/theme/app_theme.dart';
import 'package:driver_app/core/utils/formatters.dart';
import 'package:driver_app/features/notifications/presentation/notifications_controller.dart';
import 'package:driver_app/shared/widgets/app_async_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsState = ref.watch(notificationsControllerProvider);
    final strings = context.strings;

    return Scaffold(
      appBar: AppBar(title: Text(strings.notificationsTitle)),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(notificationsControllerProvider.notifier).refresh(),
        color: AppColors.primary,
        child: notificationsState.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (error, _) => AppAsyncView(
            isLoading: false,
            errorMessage: error.toString(),
            onRetry: () =>
                ref.read(notificationsControllerProvider.notifier).refresh(),
            child: const SizedBox.shrink(),
          ),
          data: (notifications) => AppAsyncView(
            isLoading: false,
            errorMessage: null,
            isEmpty: notifications.isEmpty,
            emptyTitle: strings.noNotifications,
            emptyMessage: strings.noNotificationsSubtitle,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                final isFirst = index == 0;

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: isFirst
                        ? Border.all(
                            color: AppColors.primary.withOpacity(0.25),
                            width: 1.5,
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _iconBg(notification.type),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _iconForType(notification.type),
                            size: 22,
                            color: _iconColor(notification.type),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      notification.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    Formatters.time(
                                      notification.timestamp,
                                      localeCode: strings.localeCode,
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: AppColors.textTertiary,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                notification.body,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                      height: 1.5,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'new_order':
        return Icons.add_shopping_cart_rounded;
      case 'order_updated':
        return Icons.edit_rounded;
      case 'order_status_changed':
        return Icons.sync_rounded;
      case 'driver_notification':
        return Icons.campaign_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _iconBg(String type) {
    switch (type) {
      case 'new_order':
        return AppColors.primarySoft;
      case 'order_updated':
        return AppColors.infoSoft;
      case 'order_status_changed':
        return AppColors.warningSoft;
      default:
        return AppColors.surfaceAlt;
    }
  }

  Color _iconColor(String type) {
    switch (type) {
      case 'new_order':
        return AppColors.primary;
      case 'order_updated':
        return AppColors.info;
      case 'order_status_changed':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }
}
