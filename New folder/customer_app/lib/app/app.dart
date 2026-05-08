import 'package:customer_app/app/router/app_router.dart';
import 'package:customer_app/app/theme/app_theme.dart';
import 'package:customer_app/shared/state/customer_app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CustomerApp extends ConsumerWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(customerAppControllerProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'ogas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(appState.language),
      locale: appState.language.locale,
      supportedLocales: const [Locale('ar', 'OM'), Locale('en', 'OM')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
