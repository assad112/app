import 'package:driver_app/core/localization/app_strings.dart';
import 'package:driver_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class AppAsyncView extends StatelessWidget {
  const AppAsyncView({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.child,
    this.onRetry,
    this.emptyTitle,
    this.emptyMessage,
    this.isEmpty = false,
  });

  final bool isLoading;
  final bool isEmpty;
  final String? errorMessage;
  final String? emptyTitle;
  final String? emptyMessage;
  final VoidCallback? onRetry;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (errorMessage != null && errorMessage!.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.errorSoft,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  size: 36,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                strings.retry,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: 160,
                  child: FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(strings.retry),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.inbox_outlined,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                emptyTitle ?? strings.nothingHereYet,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (emptyMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  emptyMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return child;
  }
}
