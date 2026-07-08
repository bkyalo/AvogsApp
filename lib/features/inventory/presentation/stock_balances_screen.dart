import 'package:avogs/core/theme/app_colors.dart';
import 'package:avogs/core/theme/app_theme.dart';
import 'package:avogs/features/inventory/inventory_repository.dart';
import 'package:avogs/shared/widgets/sync_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class StockBalancesScreen extends ConsumerStatefulWidget {
  const StockBalancesScreen({super.key});

  @override
  ConsumerState<StockBalancesScreen> createState() =>
      _StockBalancesScreenState();
}

class _StockBalancesScreenState extends ConsumerState<StockBalancesScreen> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final balancesAsync = ref.watch(inventoryBalancesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF162B1E) : AppColors.white;

    return Column(
      children: [
        const SyncStatusBanner(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search item name or code...',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _query = value.trim()),
          ),
        ),
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
              final categories = snapshot.categoriesForQuery(_query);
              final visibleCount =
                  categories.fold(0, (sum, c) => sum + c.items.length);

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
                                  '${snapshot.location} · ${DateFormat('d MMM yyyy').format(DateTime.parse(snapshot.date))}',
                                  style: TextStyle(
                                    color: AppColors.white.withValues(alpha: 0.6),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${snapshot.items.length} items',
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
                    if (snapshot.items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 48),
                        child: Center(
                          child: Text('No stock items found for this store'),
                        ),
                      )
                    else if (visibleCount == 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 48),
                        child: Center(
                          child: Text('No items match "$_query"'),
                        ),
                      )
                    else
                      for (final category in categories) ...[
                        _SectionHeader(
                          icon: category.icon,
                          title: category.title,
                          total: _formatTotal(category.total, category.unit),
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

  String _formatTotal(double total, String unit) {
    final value = total % 1 == 0
        ? total.toStringAsFixed(0)
        : total.toStringAsFixed(2);
    return unit.isEmpty ? value : '$value $unit';
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
    final qtyLabel = out
        ? 'Out of stock'
        : item.available % 1 == 0
            ? item.available.toStringAsFixed(0)
            : item.available.toStringAsFixed(2);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  item.stockId,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                qtyLabel,
                style: AppTheme.mono(
                  size: 15,
                  color: color,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              if (item.units.isNotEmpty && !out)
                Text(
                  item.units,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
