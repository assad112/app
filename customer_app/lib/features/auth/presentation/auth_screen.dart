import 'package:customer_app/core/constants/app_colors.dart';
import 'package:customer_app/core/widgets/app_card.dart';
import 'package:customer_app/core/widgets/app_text_field.dart';
import 'package:customer_app/core/widgets/primary_button.dart';
import 'package:customer_app/data/services/session_storage_service.dart';
import 'package:customer_app/shared/localization/app_copy.dart';
import 'package:customer_app/shared/state/customer_app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_restoreLastLoginIdentifier);
  }

  Future<void> _restoreLastLoginIdentifier() async {
    final lastIdentifier = await ref
        .read(sessionStorageServiceProvider)
        .readLastIdentifier();

    if (!mounted || lastIdentifier == null || lastIdentifier.isEmpty) {
      return;
    }

    _identifierController.text = lastIdentifier;
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value, AppCopy copy) {
    if (value == null || value.trim().isEmpty) {
      return copy.t('validation.required');
    }

    return null;
  }

  Future<void> _submit(AppCopy copy) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final controller = ref.read(customerAppControllerProvider.notifier);
    bool success;

    if (_isLogin) {
      success = await controller.login(
        identifier: _identifierController.text,
        password: _passwordController.text,
      );
    } else {
      if (_passwordController.text != _confirmPasswordController.text) {
        _showMessage(copy.t('auth.passwordMismatch'));
        return;
      }

      success = await controller.register(
        fullName: _fullNameController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );
    }

    if (!mounted) {
      return;
    }

    if (success) {
      context.go('/home');
    } else {
      final latestAppState = ref.read(customerAppControllerProvider);
      _showMessage(
        latestAppState.lastAuthErrorMessage ??
            copy.t('auth.invalidCredentials'),
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggleMode(bool nextLoginState) {
    if (_isLogin == nextLoginState) {
      return;
    }

    setState(() {
      _isLogin = nextLoginState;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(customerAppControllerProvider);
    final copy = AppCopy(appState.language);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          const _AuthBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AuthHeader(copy: copy, isLogin: _isLogin),
                      const SizedBox(height: 18),
                      AppCard(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                        child: Column(
                          children: [
                            _AuthModeToggle(
                              copy: copy,
                              isLogin: _isLogin,
                              onModeChanged: _toggleMode,
                            ),
                            const SizedBox(height: 18),
                            Form(
                              key: _formKey,
                              child: AutofillGroup(
                                child: Column(
                                  children: [
                                    AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 240,
                                      ),
                                      child: _isLogin
                                          ? _LoginFields(
                                              key: const ValueKey(
                                                'loginFields',
                                              ),
                                              copy: copy,
                                              identifierController:
                                                  _identifierController,
                                            )
                                          : _RegisterFields(
                                              key: const ValueKey(
                                                'registerFields',
                                              ),
                                              copy: copy,
                                              fullNameController:
                                                  _fullNameController,
                                              phoneController: _phoneController,
                                              emailController: _emailController,
                                              requiredValidator:
                                                  _requiredValidator,
                                            ),
                                    ),
                                    AppTextField(
                                      controller: _passwordController,
                                      label: copy.t('auth.password'),
                                      obscureText: _obscurePassword,
                                      prefixIcon: const Icon(
                                        Icons.lock_outline_rounded,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off_rounded
                                              : Icons.visibility_rounded,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _obscurePassword =
                                                !_obscurePassword;
                                          });
                                        },
                                      ),
                                      validator: (value) =>
                                          _requiredValidator(value, copy),
                                    ),
                                    if (!_isLogin) ...[
                                      const SizedBox(height: 14),
                                      AppTextField(
                                        controller: _confirmPasswordController,
                                        label: copy.t('auth.confirmPassword'),
                                        obscureText: _obscureConfirmPassword,
                                        prefixIcon: const Icon(
                                          Icons.verified_user_outlined,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscureConfirmPassword
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscureConfirmPassword =
                                                  !_obscureConfirmPassword;
                                            });
                                          },
                                        ),
                                        validator: (value) =>
                                            _requiredValidator(value, copy),
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    if (_isLogin)
                                      Align(
                                        alignment:
                                            AlignmentDirectional.centerStart,
                                        child: TextButton(
                                          onPressed: () {
                                            _showMessage(
                                              copy.t('auth.forgotPassword'),
                                            );
                                          },
                                          child: Text(
                                            copy.t('auth.forgotPassword'),
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    PrimaryButton(
                                      label: _isLogin
                                          ? copy.t('auth.loginCta')
                                          : copy.t('auth.registerCta'),
                                      onPressed: () => _submit(copy),
                                      isLoading: appState.isBusy,
                                      icon: Icon(
                                        copy.isRtl
                                            ? Icons.arrow_back_rounded
                                            : Icons.arrow_forward_rounded,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _AuthFeatureStrip(copy: copy),
                      const SizedBox(height: 14),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          gradient: const LinearGradient(
                            colors: [AppColors.navy, Color(0xFF14284A)],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x32061124),
                              blurRadius: 34,
                              offset: Offset(0, 20),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                        child: Row(
                          children: [
                            Container(
                              height: 42,
                              width: 42,
                              decoration: BoxDecoration(
                                color: AppColors.brand.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.propane_tank_outlined,
                                color: AppColors.brand,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    copy.t('app.name'),
                                    style: textTheme.titleLarge?.copyWith(
                                      color: AppColors.brand,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    copy.t('app.tagline'),
                                    style: textTheme.bodySmall?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.72,
                                      ),
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFF9FCFF),
            AppColors.background.withValues(alpha: 0.96),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -92,
            right: -40,
            child: _Blob(
              size: 210,
              color: AppColors.brand.withValues(alpha: 0.16),
            ),
          ),
          Positioned(
            top: 180,
            left: -70,
            child: _Blob(
              size: 190,
              color: AppColors.teal.withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            bottom: -64,
            right: 24,
            child: _Blob(
              size: 160,
              color: AppColors.navy.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader({required this.copy, required this.isLogin});

  final AppCopy copy;
  final bool isLogin;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFF7FAFF)],
        ),
        border: Border.all(color: Colors.white),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16091224),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.navy, Color(0xFF152B4D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x30091124),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(
              Icons.propane_tank_outlined,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            copy.t('auth.welcome'),
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall?.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isLogin
                ? copy.t('auth.loginSubtitle')
                : copy.t('auth.registerSubtitle'),
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _AuthModeToggle extends StatelessWidget {
  const _AuthModeToggle({
    required this.copy,
    required this.isLogin,
    required this.onModeChanged,
  });

  final AppCopy copy;
  final bool isLogin;
  final ValueChanged<bool> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AuthModeItem(
              selected: isLogin,
              label: copy.t('common.login'),
              onTap: () => onModeChanged(true),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _AuthModeItem(
              selected: !isLogin,
              label: copy.t('common.register'),
              onTap: () => onModeChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthModeItem extends StatelessWidget {
  const _AuthModeItem({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? AppColors.brandSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: selected
            ? Border.all(color: AppColors.brand.withValues(alpha: 0.32))
            : Border.all(color: Colors.transparent),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? AppColors.navy : AppColors.muted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginFields extends StatelessWidget {
  const _LoginFields({
    super.key,
    required this.copy,
    required this.identifierController,
  });

  final AppCopy copy;
  final TextEditingController identifierController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppTextField(
          controller: identifierController,
          label: copy.t('auth.identifier'),
          hintText: copy.t('auth.identifier'),
          keyboardType: TextInputType.emailAddress,
          prefixIcon: const Icon(Icons.phone_iphone_rounded),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return copy.t('validation.required');
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

class _RegisterFields extends StatelessWidget {
  const _RegisterFields({
    super.key,
    required this.copy,
    required this.fullNameController,
    required this.phoneController,
    required this.emailController,
    required this.requiredValidator,
  });

  final AppCopy copy;
  final TextEditingController fullNameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final String? Function(String?, AppCopy) requiredValidator;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppTextField(
          controller: fullNameController,
          label: copy.t('auth.fullName'),
          prefixIcon: const Icon(Icons.badge_outlined),
          validator: (value) => requiredValidator(value, copy),
        ),
        const SizedBox(height: 14),
        AppTextField(
          controller: phoneController,
          label: copy.t('auth.phone'),
          keyboardType: TextInputType.phone,
          prefixIcon: const Icon(Icons.phone_rounded),
          validator: (value) => requiredValidator(value, copy),
        ),
        const SizedBox(height: 14),
        AppTextField(
          controller: emailController,
          label: copy.t('auth.email'),
          keyboardType: TextInputType.emailAddress,
          prefixIcon: const Icon(Icons.alternate_email_rounded),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

class _AuthFeatureStrip extends StatelessWidget {
  const _AuthFeatureStrip({required this.copy});

  final AppCopy copy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _FeatureChip(
            icon: Icons.flash_on_rounded,
            label: copy.t('home.service.fast'),
            tint: AppColors.warningSoft,
            iconColor: AppColors.warning,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _FeatureChip(
            icon: Icons.verified_user_rounded,
            label: copy.t('home.service.safe'),
            tint: AppColors.successSoft,
            iconColor: AppColors.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _FeatureChip(
            icon: Icons.radar_rounded,
            label: copy.t('home.service.live'),
            tint: AppColors.infoSoft,
            iconColor: AppColors.info,
          ),
        ),
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({
    required this.icon,
    required this.label,
    required this.tint,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
