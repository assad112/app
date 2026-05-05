import 'package:customer_app/shared/localization/app_copy.dart';
import 'package:customer_app/shared/state/customer_app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    await ref.read(customerAppControllerProvider.notifier).initialize();
    await Future<void>.delayed(const Duration(seconds: 2));

    if (!mounted) {
      return;
    }

    final appState = ref.read(customerAppControllerProvider);
    context.go(appState.isAuthenticated ? '/home' : '/auth');
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(customerAppControllerProvider);
    final copy = AppCopy(appState.language);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFB923C), Color(0xFFEA580C)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -80,
              child: _SplashGlow(
                size: 280,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            Positioned(
              bottom: -140,
              left: -90,
              child: _SplashGlow(
                size: 320,
                color: const Color(0xFFFFE2C7).withValues(alpha: 0.16),
              ),
            ),
            Positioned.fill(
              child: SafeArea(
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 28 * (1 - value)),
                          child: Transform.scale(
                            scale: 0.92 + (0.08 * value),
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 176,
                            height: 176,
                            padding: const EdgeInsets.all(26),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(42),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF7C2D12,
                                  ).withValues(alpha: 0.18),
                                  blurRadius: 34,
                                  offset: const Offset(0, 20),
                                ),
                              ],
                            ),
                            child: SvgPicture.asset(
                              'assets/Splash/ogas_app_icon.svg',
                            ),
                          ),
                          const SizedBox(height: 36),
                          Text(
                            copy.t('app.name').toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 52,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 10,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 300),
                            child: Text(
                              copy.t('app.tagline'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFFFEDD5),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                height: 1.65,
                              ),
                            ),
                          ),
                          const SizedBox(height: 42),
                          const _SplashDots(),
                          const SizedBox(height: 16),
                          Text(
                            copy.t('splash.loading'),
                            style: const TextStyle(
                              color: Color(0xFFFFF1E4),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashGlow extends StatelessWidget {
  const _SplashGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}

class _SplashDots extends StatelessWidget {
  const _SplashDots();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeInOut,
      builder: (context, value, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final active = ((value * 3) + index) % 3;
            final opacity = active < 1 ? 1.0 : 0.45;
            return Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: opacity),
              ),
            );
          }),
        );
      },
    );
  }
}
