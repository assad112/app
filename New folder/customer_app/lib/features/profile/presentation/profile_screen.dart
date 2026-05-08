import 'package:customer_app/core/constants/app_colors.dart';
import 'package:customer_app/core/widgets/app_card.dart';
import 'package:customer_app/shared/localization/app_copy.dart';
import 'package:customer_app/shared/models/address_model.dart';
import 'package:customer_app/shared/models/order_model.dart';
import 'package:customer_app/shared/models/order_status.dart';
import 'package:customer_app/shared/state/customer_app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  int _activeOrdersCount(List<OrderModel> orders) {
    return orders
        .where(
          (item) =>
              item.orderStatus != OrderStatus.delivered &&
              item.orderStatus != OrderStatus.cancelled,
        )
        .length;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(customerAppControllerProvider);
    final copy = AppCopy(appState.language);
    final user = appState.user;
    final savedAddresses = appState.addresses
        .where(
          (item) =>
              !item.isCurrentLocation &&
              !item.id.startsWith('zone-') &&
              !item.id.startsWith('remote-'),
        )
        .toList(growable: false);
    AddressModel? defaultAddress;
    for (final address in savedAddresses) {
      if (address.id == user?.defaultAddressId) {
        defaultAddress = address;
        break;
      }
    }
    if (defaultAddress == null && savedAddresses.isNotEmpty) {
      defaultAddress = savedAddresses.firstWhere(
        (item) => item.isDefault,
        orElse: () => savedAddresses.first,
      );
    }
    final avatarLetter = user != null && user.fullName.isNotEmpty
        ? user.fullName.characters.first
        : (copy.isRtl ? 'غ' : 'G');
    final totalOrders = appState.orders.length;
    final activeOrders = _activeOrdersCount(appState.orders);
    final totalAddresses = savedAddresses.length;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 104),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProfileHero(
              copy: copy,
              avatarLetter: avatarLetter,
              fullName: user?.fullName ?? copy.t('profile.title'),
              phone: user?.phone ?? '',
              email: user?.email ?? '',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ProfileStatTile(
                    icon: Icons.receipt_long_rounded,
                    title: copy.isRtl ? 'الطلبات' : 'Orders',
                    value: '$totalOrders',
                    tone: AppColors.brand,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ProfileStatTile(
                    icon: Icons.bolt_rounded,
                    title: copy.isRtl ? 'النشطة' : 'Active',
                    value: '$activeOrders',
                    tone: AppColors.teal,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ProfileStatTile(
                    icon: Icons.place_outlined,
                    title: copy.isRtl ? 'العناوين' : 'Addresses',
                    value: '$totalAddresses',
                    tone: AppColors.info,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeading(
                    title: copy.t('profile.savedAddresses'),
                    subtitle: copy.t('profile.defaultAddress'),
                  ),
                  const SizedBox(height: 12),
                  if (defaultAddress != null)
                    _PrimaryAddressCard(address: defaultAddress),
                  const SizedBox(height: 12),
                  _CurrentLocationButton(copy: copy, ref: ref),
                  if (savedAddresses.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...savedAddresses.map((address) {
                      final isDefault = address.id == defaultAddress?.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _AddressListTile(
                          address: address,
                          isDefault: isDefault,
                          copy: copy,
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeading(
                    title: copy.t('profile.language'),
                    subtitle: copy.isRtl
                        ? 'إدارة اللغة والتواصل والدعم من مكان واحد.'
                        : 'Manage language, communication, and support in one place.',
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<AppLanguage>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment<AppLanguage>(
                        value: AppLanguage.ar,
                        label: Text('العربية'),
                      ),
                      ButtonSegment<AppLanguage>(
                        value: AppLanguage.en,
                        label: Text('English'),
                      ),
                    ],
                    selected: {appState.language},
                    onSelectionChanged: (selection) {
                      ref
                          .read(customerAppControllerProvider.notifier)
                          .switchLanguage(selection.first);
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.stroke),
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 36,
                          width: 36,
                          decoration: BoxDecoration(
                            color: AppColors.brandSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.support_agent_rounded,
                            color: AppColors.brandDeep,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                copy.t('profile.support'),
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                appState.runtimeSettings.supportPhone,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.muted),
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
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeading(
                    title: copy.isRtl ? 'خدمات الحساب' : 'Account services',
                    subtitle: copy.isRtl
                        ? 'اختصارات إدارة الحساب والتفضيلات.'
                        : 'Quick shortcuts for account management.',
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.25,
                    children: [
                      _ServiceTile(
                        icon: Icons.notifications_none_rounded,
                        title: copy.t('profile.notifications'),
                      ),
                      _ServiceTile(
                        icon: Icons.credit_card_outlined,
                        title: copy.t('profile.paymentMethods'),
                      ),
                      _ServiceTile(
                        icon: Icons.lock_reset_rounded,
                        title: copy.t('profile.changePassword'),
                      ),
                      _ServiceTile(
                        icon: Icons.policy_outlined,
                        title: copy.t('profile.terms'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await ref
                      .read(customerAppControllerProvider.notifier)
                      .logout();
                  if (!context.mounted) {
                    return;
                  }
                  context.go('/home');
                },
                icon: const Icon(Icons.logout_rounded),
                label: Text(copy.t('common.logout')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  backgroundColor: AppColors.errorSoft,
                  minimumSize: const Size(0, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
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

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.copy,
    required this.avatarLetter,
    required this.fullName,
    required this.phone,
    required this.email,
  });

  final AppCopy copy;
  final String avatarLetter;
  final String fullName;
  final String phone;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, Color(0xFF152B4D), Color(0xFF1C385E)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22091D33),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            end: -32,
            top: -34,
            child: Container(
              height: 108,
              width: 108,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.t('profile.title'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      fullName,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (phone.trim().isNotEmpty)
                      _HeroInfoChip(icon: Icons.phone_rounded, label: phone),
                    if (email.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _HeroInfoChip(
                        icon: Icons.alternate_email_rounded,
                        label: email,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 84,
                width: 84,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  avatarLetter,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroInfoChip extends StatelessWidget {
  const _HeroInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStatTile extends StatelessWidget {
  const _ProfileStatTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12091D33),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 28,
            width: 28,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: tone),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryAddressCard extends StatelessWidget {
  const _PrimaryAddressCard({required this.address});

  final AddressModel address;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF6EE), Colors.white],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 28,
                width: 28,
                decoration: BoxDecoration(
                  color: AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.place_rounded,
                  size: 16,
                  color: AppColors.brandDeep,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  address.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            address.fullAddress,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _CurrentLocationButton extends StatelessWidget {
  const _CurrentLocationButton({required this.copy, required this.ref});

  final AppCopy copy;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(customerAppControllerProvider);
    final isLoading = appState.isResolvingCurrentLocation;

    return GestureDetector(
      onTap: isLoading
          ? null
          : () async {
              final messenger = ScaffoldMessenger.of(context);
              final result = await ref
                  .read(customerAppControllerProvider.notifier)
                  .refreshCurrentLocation();
              if (!context.mounted) return;
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    result.success
                        ? copy.t('location.updatedSuccess')
                        : copy.t('location.unavailable'),
                  ),
                ),
              );
            },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.tealSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.teal.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.teal,
                      ),
                    )
                  : const Icon(
                      Icons.my_location_rounded,
                      color: AppColors.teal,
                      size: 20,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    copy.isRtl ? 'موقعي الحالي' : 'My current location',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    copy.isRtl
                        ? 'اضغط لتحديث موقعك عبر GPS'
                        : 'Tap to update your location via GPS',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.teal,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressListTile extends StatelessWidget {
  const _AddressListTile({
    required this.address,
    required this.isDefault,
    required this.copy,
  });

  final AddressModel address;
  final bool isDefault;
  final AppCopy copy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDefault
            ? AppColors.brandSoft.withValues(alpha: 0.5)
            : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDefault
              ? AppColors.brand.withValues(alpha: 0.2)
              : AppColors.stroke,
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: isDefault ? AppColors.brandSoft : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDefault
                    ? AppColors.brand.withValues(alpha: 0.2)
                    : AppColors.stroke,
              ),
            ),
            child: Icon(
              isDefault
                  ? Icons.home_rounded
                  : address.isCurrentLocation
                  ? Icons.my_location_rounded
                  : Icons.place_outlined,
              size: 17,
              color: isDefault ? AppColors.brand : AppColors.muted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        address.label.isNotEmpty
                            ? address.label
                            : (copy.isRtl ? 'عنوان' : 'Address'),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isDefault)
                      Container(
                        margin: const EdgeInsetsDirectional.only(start: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brand,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          copy.isRtl ? 'افتراضي' : 'Default',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                if (address.fullAddress.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    address.fullAddress,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.navy,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.stroke),
          ),
          child: Row(
            children: [
              Container(
                height: 32,
                width: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: Icon(icon, size: 16, color: AppColors.navy),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: AppColors.navy),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.muted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
