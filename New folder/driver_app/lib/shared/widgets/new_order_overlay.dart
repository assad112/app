import 'dart:async';

import 'package:driver_app/core/localization/app_strings.dart';
import 'package:driver_app/core/theme/app_theme.dart';
import 'package:driver_app/core/utils/formatters.dart';
import 'package:driver_app/features/orders/presentation/orders_controller.dart';
import 'package:driver_app/shared/models/delivery_order.dart';
import 'package:driver_app/shared/state/new_order_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NewOrderOverlay extends ConsumerStatefulWidget {
  const NewOrderOverlay({super.key, required this.order});

  final DeliveryOrder order;

  @override
  ConsumerState<NewOrderOverlay> createState() => _NewOrderOverlayState();
}

class _NewOrderOverlayState extends ConsumerState<NewOrderOverlay>
    with SingleTickerProviderStateMixin {
  static const _totalSeconds = 30;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  Timer? _countdownTimer;
  int _secondsLeft = _totalSeconds;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        timer.cancel();
        _dismiss();
      }
    });
  }

  void _dismiss() {
    ref.read(newOrderNotifierProvider.notifier).dismiss();
  }

  Future<void> _accept() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    _countdownTimer?.cancel();
    try {
      await ref
          .read(ordersControllerProvider.notifier)
          .acceptOrder(widget.order.id);
    } finally {
      if (mounted) _dismiss();
    }
  }

  Future<void> _reject() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    _countdownTimer?.cancel();
    try {
      await ref
          .read(ordersControllerProvider.notifier)
          .rejectOrder(widget.order.id);
    } finally {
      if (mounted) _dismiss();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final isAr = strings.localeCode == 'ar';
    final order = widget.order;

    final progress = _secondsLeft / _totalSeconds;
    final progressColor = _secondsLeft > 10
        ? AppColors.success
        : _secondsLeft > 5
        ? AppColors.warning
        : AppColors.error;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // dim background
          GestureDetector(
            onTap: () {},
            child: Container(color: Colors.black.withValues(alpha: 0.55)),
          ),

          // card
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _buildCard(
                  context,
                  isAr,
                  order,
                  progress,
                  progressColor,
                  strings,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    bool isAr,
    DeliveryOrder order,
    double progress,
    Color progressColor,
    AppStrings strings,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 40,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── header ──
            _buildHeader(isAr, order, progress, progressColor),

            // ── body ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    Icons.location_on_rounded,
                    AppColors.error,
                    isAr ? 'العنوان' : 'Address',
                    order.location.isNotEmpty
                        ? order.location
                        : order.addressFull,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.local_fire_department_rounded,
                    AppColors.primary,
                    isAr ? 'المنتج' : 'Product',
                    '${order.gasType}  ×${order.quantity}',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.payments_rounded,
                    AppColors.success,
                    isAr ? 'الدفع' : 'Payment',
                    _localizePayment(order.paymentMethod, isAr),
                  ),
                  if (order.totalAmount > 0) ...[
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.attach_money_rounded,
                      AppColors.warning,
                      isAr ? 'المبلغ' : 'Total',
                      Formatters.currency(order.totalAmount),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _buildActions(isAr),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    bool isAr,
    DeliveryOrder order,
    double progress,
    Color progressColor,
  ) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF7A1A), Color(0xFFFF4500)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_shipping_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr ? 'طلب توصيل جديد!' : 'New Delivery Request!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      order.customerName.isNotEmpty
                          ? order.customerName
                          : 'ORD-${order.id}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // countdown badge
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 3,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                      ),
                    ),
                    Text(
                      '$_secondsLeft',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    Color iconColor,
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions(bool isAr) {
    return Row(
      children: [
        // reject
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isBusy ? null : _reject,
            icon: const Icon(Icons.close_rounded, size: 18),
            label: Text(isAr ? 'رفض' : 'Reject'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error, width: 1.5),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // accept
        Expanded(
          flex: 2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FilledButton.icon(
              onPressed: _isBusy ? null : _accept,
              icon: _isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 20),
              label: Text(isAr ? 'قبول الطلب' : 'Accept'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _localizePayment(String method, bool isAr) {
    if (!isAr) return method;
    switch (method.toLowerCase()) {
      case 'cash_on_delivery':
      case 'cash':
        return 'نقداً عند التسليم';
      case 'digital_wallet':
      case 'card':
        return 'محفظة رقمية';
      default:
        return method;
    }
  }
}
