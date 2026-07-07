import 'package:avogs/core/responsive/breakpoints.dart';
import 'package:avogs/core/routing/app_routes.dart';
import 'package:avogs/core/theme/app_colors.dart';
import 'package:avogs/shared/widgets/sync_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  static const _services = [
    _ServiceAction(
      icon: Icons.point_of_sale,
      label: 'New Sale',
      description: 'Direct sale to customer',
      route: AppRoutes.salesNew,
    ),
    _ServiceAction(
      icon: Icons.payments,
      label: 'Payment',
      description: 'Record customer payment',
      route: AppRoutes.paymentsNew,
    ),
    _ServiceAction(
      icon: Icons.local_shipping,
      label: 'Receive Stock',
      description: 'Supplier invoice / goods in',
      route: AppRoutes.purchasingNew,
    ),
    _ServiceAction(
      icon: Icons.inventory_2,
      label: 'Adjust Stock',
      description: 'Inventory adjustment',
      route: AppRoutes.inventoryAdjust,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final layout = layoutSizeOf(context);

    return Column(
      children: [
        const SyncStatusBanner(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Services',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Choose a transaction type to get started.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: layout == LayoutSize.compact ? 2 : 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                itemCount: _services.length,
                itemBuilder: (context, index) {
                  final service = _services[index];
                  return _ServiceCard(
                    service: service,
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
    required this.route,
  });

  final IconData icon;
  final String label;
  final String description;
  final String route;
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service, required this.onTap});

  final _ServiceAction service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(service.icon, color: AppColors.primaryGreen, size: 28),
              const Spacer(),
              Text(
                service.label,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                service.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
