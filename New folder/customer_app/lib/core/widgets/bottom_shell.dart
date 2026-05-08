import 'package:customer_app/core/constants/app_colors.dart';
import 'package:customer_app/shared/localization/app_copy.dart';
import 'package:customer_app/shared/state/customer_app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CustomerBottomShell extends ConsumerWidget {
  const CustomerBottomShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _showGuestAccessDialog(
    BuildContext context,
    AppCopy copy, {
    required String returnTo,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _GuestAccessDialog(
          copy: copy,
          onLogin: () {
            Navigator.of(dialogContext).pop();
            context.go('/auth?returnTo=$returnTo');
          },
          onGuest: () {
            Navigator.of(dialogContext).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(customerAppControllerProvider);
    final copy = AppCopy(appState.language);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.stroke, width: 1)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x16091D33),
              blurRadius: 24,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) {
            if (!appState.isAuthenticated && (index == 1 || index == 2)) {
              _showGuestAccessDialog(
                context,
                copy,
                returnTo: index == 1 ? '/orders' : '/profile',
              );
              return;
            }

            navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            );
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: copy.t('nav.home'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long_rounded),
              label: copy.t('nav.orders'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: copy.t('nav.profile'),
            ),
          ],
        ),
      ),
      floatingActionButton:
          navigationShell.currentIndex == 0 &&
              appState.runtimeSettings.orderIntakeEnabled
          ? _GradientFab(
              label: copy.t('home.orderNow'),
              onTap: () => context.push('/create-order'),
            )
          : null,
    );
  }
}

class _GuestAccessDialog extends StatelessWidget {
  const _GuestAccessDialog({
    required this.copy,
    required this.onLogin,
    required this.onGuest,
  });

  final AppCopy copy;
  final VoidCallback onLogin;
  final VoidCallback onGuest;

  String get _title => copy.isRtl
      ? '\u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062f\u062e\u0648\u0644'
      : 'Sign in';

  String get _message => copy.isRtl
      ? '\u064a\u0645\u0643\u0646\u0643 \u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062f\u062e\u0648\u0644 \u0644\u062d\u0641\u0638 \u0637\u0644\u0628\u0627\u062a\u0643 \u0648\u062a\u062a\u0628\u0639\u0647\u0627\u060c \u0623\u0648 \u0627\u0644\u0645\u062a\u0627\u0628\u0639\u0629 \u0643\u0636\u064a\u0641 \u0644\u062a\u0635\u0641\u062d \u0627\u0644\u062e\u062f\u0645\u0627\u062a.'
      : 'Sign in to save and track your orders, or continue as a guest to browse services.';

  String get _loginLabel => copy.isRtl
      ? '\u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062f\u062e\u0648\u0644'
      : 'Sign in';

  String get _guestLabel => copy.isRtl
      ? '\u0627\u0644\u0645\u062a\u0627\u0628\u0639\u0629 \u0643\u0636\u064a\u0641'
      : 'Continue as guest';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Directionality(
      textDirection: copy.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 22),
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 430),
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33091124),
                blurRadius: 32,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 82,
                width: 82,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.brand, AppColors.brandDeep],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3DFF7A1A),
                      blurRadius: 22,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person_pin_circle_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _title,
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _message,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: AppColors.muted,
                  height: 1.65,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _GuestDialogButton(
                      label: _guestLabel,
                      icon: Icons.person_outline_rounded,
                      onTap: onGuest,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _GuestDialogButton(
                      label: _loginLabel,
                      icon: Icons.login_rounded,
                      onTap: onLogin,
                      isPrimary: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestDialogButton extends StatelessWidget {
  const _GuestDialogButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final foreground = isPrimary ? Colors.white : AppColors.navy;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isPrimary
            ? const LinearGradient(
                colors: [AppColors.brand, AppColors.brandDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isPrimary ? null : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPrimary
              ? AppColors.brand.withValues(alpha: 0.22)
              : AppColors.stroke,
        ),
        boxShadow: isPrimary
            ? const [
                BoxShadow(
                  color: Color(0x36FF7A1A),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: SizedBox(
            height: 54,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: foreground, size: 19),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientFab extends StatelessWidget {
  const _GradientFab({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brand, AppColors.brandDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44FF7A1A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_shipping_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
