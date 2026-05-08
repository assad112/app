import 'package:customer_app/core/widgets/bottom_shell.dart';
import 'package:customer_app/features/auth/presentation/auth_screen.dart';
import 'package:customer_app/features/home/presentation/home_screen.dart';
import 'package:customer_app/features/location/presentation/location_picker_screen.dart';
import 'package:customer_app/features/orders/presentation/create_order_screen.dart';
import 'package:customer_app/features/orders/presentation/my_orders_screen.dart';
import 'package:customer_app/features/orders/presentation/order_tracking_screen.dart';
import 'package:customer_app/features/profile/presentation/profile_screen.dart';
import 'package:customer_app/features/splash/presentation/splash_screen.dart';
import 'package:customer_app/shared/state/customer_app_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final appState = ref.read(customerAppControllerProvider);
      final path = state.uri.path;
      final isAuthRoute = path == '/auth';
      final isProtectedRoute =
          path == '/create-order' || path == '/orders' || path == '/profile';

      if (isProtectedRoute && !appState.isAuthenticated) {
        final returnTo = Uri.encodeComponent(state.uri.toString());
        return '/auth?returnTo=$returnTo';
      }

      if (isAuthRoute && appState.isAuthenticated) {
        final returnTo = state.uri.queryParameters['returnTo'];
        if (returnTo != null &&
            returnTo.isNotEmpty &&
            returnTo.startsWith('/') &&
            !returnTo.startsWith('/auth')) {
          return returnTo;
        }
        return '/home';
      }

      return null;
    },
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
        path: '/pick-location',
        builder: (context, state) => const LocationPickerScreen(),
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
