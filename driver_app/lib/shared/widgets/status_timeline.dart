import 'package:driver_app/core/theme/app_theme.dart';
import 'package:driver_app/core/utils/formatters.dart';
import 'package:driver_app/core/localization/app_strings.dart';
import 'package:flutter/material.dart';

class StatusTimeline extends StatelessWidget {
  const StatusTimeline({super.key, required this.currentStage});

  final String currentStage;

  static const _stages = ['accepted', 'on_the_way', 'arrived', 'delivered'];

  static const _stageIcons = [
    Icons.check_circle_outline_rounded,
    Icons.local_shipping_rounded,
    Icons.location_on_rounded,
    Icons.verified_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _stages.indexOf(currentStage);

    return Row(
      children: [
        for (var i = 0; i < _stages.length; i++) ...[
          _StageNode(
            icon: _stageIcons[i],
            label: Formatters.driverStage(
              _stages[i],
              localeCode: context.strings.localeCode,
            ),
            isCompleted: i < currentIndex,
            isCurrent: i == currentIndex,
            isPending: i > currentIndex,
          ),
          if (i < _stages.length - 1)
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 24),
                height: 3,
                decoration: BoxDecoration(
                  color: i < currentIndex
                      ? AppColors.primary
                      : AppColors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _StageNode extends StatelessWidget {
  const _StageNode({
    required this.icon,
    required this.label,
    required this.isCompleted,
    required this.isCurrent,
    required this.isPending,
  });

  final IconData icon;
  final String label;
  final bool isCompleted;
  final bool isCurrent;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color iconColor;

    if (isCompleted) {
      bgColor = AppColors.primary;
      iconColor = Colors.white;
    } else if (isCurrent) {
      bgColor = AppColors.primarySoft;
      iconColor = AppColors.primary;
    } else {
      bgColor = AppColors.border;
      iconColor = AppColors.textTertiary;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: isCurrent
                ? Border.all(color: AppColors.primary, width: 2)
                : null,
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            isCompleted ? Icons.check_rounded : icon,
            size: 17,
            color: iconColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: isPending ? AppColors.textTertiary : AppColors.textPrimary,
            fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
