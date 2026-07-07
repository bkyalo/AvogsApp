import 'package:avogs/core/theme/app_colors.dart';
import 'package:avogs/core/theme/app_theme.dart';
import 'package:avogs/features/inventory/inventory_repository.dart';
import 'package:avogs/shared/widgets/sync_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class StockBalancesScreen extends ConsumerWidget {
  const StockBalancesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balancesAsync = ref.watch(inventoryBalancesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF162B1E) : AppColors.white;

    return Column(
      children: [
        const SyncStatusBanner(),
        Expanded(
          child: balancesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$e', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(inventoryBalancesProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
            data: (snapshot) {
              final shiftName =
                  snapshot.shift == 'evening' ? 'Evening' : 'Morning';
              final categories = snapshot.categories;

              return RefreshIndicator(
                color: AppColors.primaryGreen,
                onRefresh: () async {
                  ref.invalidate(inventoryBalancesProvider);
                  await ref.read(inventoryBalancesProvider.future);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            color: AppColors.accentLime,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Stock Balances',
                                  style: TextStyle(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '${snapshot.store} · $shiftName · ${DateFormat('d MMM').format(DateTime.parse(snapshot.date))}',
                                  style: TextStyle(
                                    color: AppColors.white.withValues(alpha: 0.6),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'Live',
                            style: TextStyle(
                              color: AppColors.accentLime.withValues(alpha: 0.9),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final category in categories) ...[
                      _SectionHeader(
                        icon: category.icon,
                        title: category.title,
                        total: '${category.total} ${category.unit}',
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: isDark
                              ? null
                              : const [
                                  BoxShadow(
                                    color: Color(0x0A000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < category.items.length; i++) ...[
                              _BalanceRow(item: category.items[i]),
                              if (i < category.items.length - 1)
                                Divider(
                                  height: 1,
                                  color: isDark
                                      ? AppColors.white.withValues(alpha: 0.08)
                                      : const Color(0xFFF0EDE6),
                                ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.total,
  });

  final IconData icon;
  final String title;
  final String total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accentLime, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            total,
            style: AppTheme.mono(
              size: 13,
              color: AppColors.accentLime,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.item});

  final InventoryBalanceItem item;

  @override
  Widget build(BuildContext context) {
    final out = item.available <= 0;
    final low = item.available > 0 && item.available <= 5;
    final color = out
        ? AppColors.errorRed
        : low
            ? AppColors.honey
            : AppColors.primaryGreen;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            out ? 'Out of stock' : '${item.available}',
            style: AppTheme.mono(
              size: 15,
              color: color,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
