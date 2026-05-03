import 'package:driver_app/app/app_realtime_bindings.dart';
import 'package:driver_app/app/app_driver_presence_bindings.dart';
import 'package:driver_app/core/localization/app_strings.dart';
import 'package:driver_app/core/localization/locale_controller.dart';
import 'package:driver_app/core/services/app_permission_service.dart';
import 'package:driver_app/core/theme/app_theme.dart';
import 'package:driver_app/features/auth/presentation/screens/splash_screen.dart';
import 'package:driver_app/features/home/presentation/screens/home_screen.dart';
import 'package:driver_app/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:driver_app/features/orders/presentation/screens/incoming_orders_screen.dart';
import 'package:driver_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DriverApp extends ConsumerWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider);
    final strings = AppStrings(locale.languageCode);

    return MaterialApp(
      title: strings.appName,
      debugShowCheckedModeBanner: false,
      locale: locale,
      theme: AppTheme.light(locale),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: const SplashScreen(),
    );
  }
}

class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(appPermissionServiceProvider).requestImportantPermissions();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appRealtimeBindingsProvider);
    ref.watch(appDriverPresenceBindingsProvider);
    final strings = context.strings;

    const screens = [
      HomeScreen(),
      IncomingOrdersScreen(),
      NotificationsScreen(),
      ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.07),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
          },
          backgroundColor: Colors.white,
          elevation: 0,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard_rounded),
              label: strings.dashboardNav,
            ),
            NavigationDestination(
              icon: const Icon(Icons.local_shipping_outlined),
              selectedIcon: const Icon(Icons.local_shipping_rounded),
              label: strings.ordersNav,
            ),
            NavigationDestination(
              icon: const Icon(Icons.notifications_none_rounded),
              selectedIcon: const Icon(Icons.notifications_rounded),
              label: strings.alertsNav,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: strings.profileNav,
            ),
          ],
        ),
      ),
    );
  }
}
