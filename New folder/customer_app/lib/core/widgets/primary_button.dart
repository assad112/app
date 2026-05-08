import 'package:customer_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool isLoading;
  final bool fullWidth;

  bool get _disabled => isLoading || onPressed == null;

  @override
  Widget build(BuildContext context) {
    final child = _GradientButton(
      onTap: _disabled ? null : onPressed,
      isLoading: isLoading,
      label: label,
      icon: icon,
    );

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: child);
    }
    return child;
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.onTap,
    required this.isLoading,
    required this.label,
    this.icon,
  });

  final VoidCallback? onTap;
  final bool isLoading;
  final String label;
  final Widget? icon;

  bool get _disabled => onTap == null && !isLoading;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _disabled ? 0.58 : 1.0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _disabled
              ? null
              : const LinearGradient(
                  colors: [AppColors.brand, AppColors.brandDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: _disabled ? AppColors.brand : null,
          borderRadius: BorderRadius.circular(22),
          boxShadow: _disabled
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x44FF7A1A),
                    blurRadius: 18,
                    spreadRadius: 0,
                    offset: Offset(0, 8),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: isLoading
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : _ButtonContent(
                          label: label,
                          icon: icon,
                          iconColor: Colors.white,
                          textStyle: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: Colors.white, fontSize: 15),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.textStyle,
    this.icon,
    this.iconColor,
  });

  final String label;
  final Widget? icon;
  final TextStyle? textStyle;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          IconTheme(
            data: IconThemeData(color: iconColor, size: 20),
            child: icon!,
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            textAlign: TextAlign.center,
            style: textStyle,
          ),
        ),
      ],
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        side: BorderSide(
          color: onPressed == null ? AppColors.stroke : AppColors.stroke,
          width: 1.5,
        ),
        minimumSize: const Size(0, 54),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      child: _ButtonContent(
        label: label,
        icon: icon,
        iconColor: AppColors.navy,
        textStyle: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: AppColors.navy),
      ),
    );

    if (!fullWidth) {
      return button;
    }

    return SizedBox(width: double.infinity, child: button);
  }
}
