import 'package:driver_app/core/localization/app_strings.dart';
import 'package:driver_app/core/localization/locale_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LanguageSwitcher extends ConsumerWidget {
  const LanguageSwitcher({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider);
    final strings = context.strings;

    return SegmentedButton<String>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment<String>(value: 'ar', label: Text(strings.arabic)),
        ButtonSegment<String>(value: 'en', label: Text(strings.english)),
      ],
      selected: {locale.languageCode},
      onSelectionChanged: (selection) {
        ref.read(localeControllerProvider.notifier).setLocale(selection.first);
      },
      style: ButtonStyle(
        visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
        padding: WidgetStateProperty.all(
          EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: compact ? 10 : 12,
          ),
        ),
      ),
    );
  }
}
