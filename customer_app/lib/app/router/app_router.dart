import 'package:customer_app/core/widgets/bottom_shell.dart';
import 'package:customer_app/features/auth/presentation/auth_screen.dart';
import 'package:customer_app/features/home/presentation/home_screen.dart';
import 'package:customer_app/features/orders/presentation/create_order_screen.dart';
import 'package:customer_app/features/orders/presentation/my_orders_screen.dart';
import 'package:customer_app/features/orders/presentation/order_tracking_screen.dart';
import 'package:customer_app/features/profile/presentation/profile_screen.dart';
import 'package:customer_app/features/splash/presentation/splash_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return CustomerBottomShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/orders',
                builder: (context, state) => const MyOrdersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/create-order',
        builder: (context, state) => const CreateOrderScreen(),
      ),
      GoRoute(
        path: '/tracking/:orderId',
        builder: (context, state) {
          final orderId = state.pathParameters['orderId'] ?? '';
          return OrderTrackingScreen(orderId: orderId);
        },
      ),
    ],
  );
});
