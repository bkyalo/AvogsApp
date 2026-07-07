import 'package:avogs/core/responsive/breakpoints.dart';
import 'package:avogs/core/routing/app_routes.dart';
import 'package:avogs/core/theme/app_colors.dart';
import 'package:avogs/shared/widgets/sync_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  static const _featured = _ServiceAction(
    icon: Icons.point_of_sale_outlined,
    label: 'New Sale',
    description: 'Direct sale to customer',
    category: 'Sales',
    route: AppRoutes.salesNew,
    accent: Color(0xFF4AAA60),
    featured: true,
  );

  static const _services = [
    _ServiceAction(
      icon: Icons.payments_outlined,
      label: 'Payment',
      description: 'Record customer payment',
      category: 'Finance',
      route: AppRoutes.paymentsNew,
      accent: AppColors.infoBlue,
    ),
    _ServiceAction(
      icon: Icons.local_shipping_outlined,
      label: 'Receive Stock',
      description: 'Supplier invoice / goods in',
      category: 'Purchasing',
      route: AppRoutes.purchasingNew,
      accent: AppColors.primaryGreen,
    ),
    _ServiceAction(
      icon: Icons.inventory_2_outlined,
      label: 'Stock Balances',
      description: 'View current inventory levels',
      category: 'Inventory',
      route: AppRoutes.inventoryBalances,
      accent: AppColors.honey,
    ),
    _ServiceAction(
      icon: Icons.tune_outlined,
      label: 'Adjust Stock',
      description: 'Inventory adjustment',
      category: 'Inventory',
      route: AppRoutes.inventoryAdjust,
      accent: AppColors.mutedGray,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final layout = layoutSizeOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF162B1E) : AppColors.white;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final borderColor =
        isDark ? AppColors.white.withValues(alpha: 0.1) : const Color(0xFFE8E4DC);

    return Column(
      children: [
        const SyncStatusBanner(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Services',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose a transaction type to get started.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 18),
              _FeaturedServiceCard(
                service: _featured,
                onTap: () => context.go(_featured.route),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: layout == LayoutSize.compact ? 2 : 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: layout == LayoutSize.compact ? 0.92 : 1.05,
                ),
                itemCount: _services.length,
                itemBuilder: (context, index) {
                  final service = _services[index];
                  return _ServiceCard(
                    key: ValueKey(service.route),
                    service: service,
                    cardColor: cardColor,
                    borderColor: borderColor,
                    isDark: isDark,
                    onSurface: onSurface,
                    onSurfaceVariant: onSurfaceVariant,
                    onTap: () => context.go(service.route),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ServiceAction {
  const _ServiceAction({
    required this.icon,
    required this.label,
    required this.description,
    required this.category,
    required this.route,
    required this.accent,
    this.featured = false,
  });

  final IconData icon;
  final String label;
  final String description;
  final String category;
  final String route;
  final Color accent;
  final bool featured;
}

class _FeaturedServiceCard extends StatelessWidget {
  const _FeaturedServiceCard({
    required this.service,
    required this.onTap,
  });

  final _ServiceAction service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryDark,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: service.accent.withValues(alpha: 0.45),
              width: 1.5,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryDark,
                Color.lerp(AppColors.primaryDark, service.accent, 0.18)!,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: service.accent.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(service.icon, color: service.accent, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.category.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: AppColors.accentLime.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        service.label,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        service.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.white.withValues(alpha: 0.62),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.accentLime.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.accentLime,
                    size: 18,
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

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    super.key,
    required this.service,
    required this.cardColor,
    required this.borderColor,
    required this.isDark,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.onTap,
  });

  final _ServiceAction service;
  final Color cardColor;
  final Color borderColor;
  final bool isDark;
  final Color onSurface;
  final Color onSurfaceVariant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _IconBadge(
                        icon: service.icon,
                        accent: service.accent,
                        isDark: isDark,
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 13,
                        color: onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    service.category.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                      color: service.accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    service.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: onSurface,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    service.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.3,
                      color: onSurfaceVariant,
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

class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
    required this.accent,
    required this.isDark,
  });

  final IconData icon;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.35 : 0.22),
        ),
      ),
      child: Icon(icon, color: accent, size: 22),
    );
  }
}
