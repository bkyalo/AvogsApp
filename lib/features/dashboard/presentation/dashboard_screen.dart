import 'package:avogs/core/sync/sync_service.dart';
import 'package:avogs/core/theme/app_colors.dart';
import 'package:avogs/core/theme/app_theme.dart';
import 'package:avogs/core/utils/formatters.dart';
import 'package:avogs/features/reports/reports_repository.dart';
import 'package:avogs/shared/widgets/sync_status_banner.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  var _isRefreshing = false;

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    ref.invalidate(todaySalesSummaryProvider);
    ref.invalidate(salesTrendProvider);
    try {
      await Future.wait([
        ref.read(syncServiceProvider.notifier).syncPending(),
        ref.read(todaySalesSummaryProvider.future),
        ref.read(salesTrendProvider.future),
      ]);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(todaySalesSummaryProvider);
    final trendAsync = ref.watch(salesTrendProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF162B1E) : AppColors.white;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : (hour < 17 ? 'Good afternoon' : 'Good evening');
    final isMorning = hour < 14;

    return Column(
      children: [
        const SyncStatusBanner(),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primaryGreen,
            onRefresh: _onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  greeting,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('EEE, d MMM yyyy').format(now),
                  style: TextStyle(
                    fontSize: 12,
                    color: onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                summaryAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text(
                    'Could not load sales summary: $e',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  data: (summary) => Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMorning ? 'Morning Shift' : 'Evening Shift',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              isMorning ? '7:00 AM — 2:00 PM' : '2:00 PM — 9:00 PM',
                              style: TextStyle(
                                color: AppColors.white.withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatMoney(summary.total),
                              style: AppTheme.mono(
                                size: 18,
                                color: AppColors.accentLime,
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              "Today's sales",
                              style: TextStyle(
                                color: AppColors.white.withValues(alpha: 0.6),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                trendAsync.when(
                  loading: () => const SizedBox(
                    height: 180,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text('Trend unavailable: $e'),
                  data: (days) => _SalesTrendChart(
                    days: days,
                    cardColor: cardColor,
                    onSurface: onSurface,
                    onSurfaceVariant: onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                summaryAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (summary) => GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.25,
                    children: [
                      _KpiCard(
                        icon: Icons.point_of_sale_outlined,
                        value: formatMoney(summary.total),
                        label: "Today's Sales",
                        tag: summary.date,
                        accent: const Color(0xFF4AAA60),
                        cardColor: cardColor,
                        onSurface: onSurface,
                        onSurfaceVariant: onSurfaceVariant,
                      ),
                      _KpiCard(
                        icon: Icons.shopping_bag_outlined,
                        value: '${summary.units}',
                        label: 'Units Sold',
                        tag: 'Today',
                        accent: AppColors.errorRed,
                        cardColor: cardColor,
                        onSurface: onSurface,
                        onSurfaceVariant: onSurfaceVariant,
                      ),
                      _KpiCard(
                        icon: Icons.eco_outlined,
                        value: formatMoney(summary.retail + summary.wholesale),
                        label: 'Avocado',
                        tag: 'Retail + wholesale',
                        accent: AppColors.primaryGreen,
                        cardColor: cardColor,
                        onSurface: onSurface,
                        onSurfaceVariant: onSurfaceVariant,
                      ),
                      _KpiCard(
                        icon: Icons.local_drink_outlined,
                        value: formatMoney(summary.honey + summary.beverage),
                        label: 'Honey & Drinks',
                        tag: 'Categories',
                        accent: AppColors.honey,
                        cardColor: cardColor,
                        onSurface: onSurface,
                        onSurfaceVariant: onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.tag,
    required this.accent,
    required this.cardColor,
    required this.onSurface,
    required this.onSurfaceVariant,
  });

  final IconData icon;
  final String value;
  final String label;
  final String tag;
  final Color accent;
  final Color cardColor;
  final Color onSurface;
  final Color onSurfaceVariant;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: accent, width: 4)),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: accent, size: 26),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                child: Text(
                  value,
                  style: AppTheme.mono(size: 18, color: onSurface).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: onSurface,
                ),
              ),
              Text(
                tag,
                style: TextStyle(fontSize: 10, color: onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SalesTrendChart extends StatelessWidget {
  const _SalesTrendChart({
    required this.days,
    required this.cardColor,
    required this.onSurface,
    required this.onSurfaceVariant,
  });

  final List<SalesTrendDay> days;
  final Color cardColor;
  final Color onSurface;
  final Color onSurfaceVariant;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final values = days.map((d) => d.total).toList();
    final dateKeys = days.map((d) => d.date).toList();
    final hasData = values.any((v) => v > 0);
    final maxV = values.fold(0.0, (a, v) => a > v ? a : v);
    final maxY = (maxV == 0 ? 1000 : maxV) * 1.25;
    final lastIdx = values.length - 1;
    final total = values.fold(0.0, (a, v) => a + v);
    final gridColor =
        isDark ? AppColors.white.withValues(alpha: 0.08) : const Color(0xFFEFECE4);
    final backRodColor =
        isDark ? AppColors.white.withValues(alpha: 0.06) : const Color(0xFFF3F1EA);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.trending_up,
                    color: isDark ? AppColors.accentLime : AppColors.primaryDark,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Sales',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Last 7 days',
                    style: TextStyle(
                      fontSize: 11,
                      color: onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (hasData)
                Text(
                  formatMoney(total),
                  style: AppTheme.mono(
                    size: 14,
                    color: AppColors.primaryGreen,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            child: hasData
                ? BarChart(
                    BarChartData(
                      maxY: maxY,
                      alignment: BarChartAlignment.spaceAround,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxY / 4,
                        getDrawingHorizontalLine: (_) =>
                            FlLine(color: gridColor, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => AppColors.primaryDark,
                          tooltipBorderRadius: BorderRadius.circular(8),
                          getTooltipItem: (group, _, rod, __) {
                            final k = dateKeys[group.x];
                            final label =
                                DateFormat('EEE d').format(DateTime.parse(k));
                            return BarTooltipItem(
                              '$label\n',
                              const TextStyle(
                                color: AppColors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                              children: [
                                TextSpan(
                                  text: formatMoney(rod.toY),
                                  style: const TextStyle(
                                    color: AppColors.accentLime,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            interval: maxY / 4,
                            getTitlesWidget: (v, _) => Text(
                              compactMoney(v),
                              style: AppTheme.mono(
                                size: 9,
                                color: onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            getTitlesWidget: (v, _) {
                              final i = v.toInt();
                              if (i < 0 || i >= dateKeys.length) {
                                return const SizedBox.shrink();
                              }
                              final wd = DateFormat('E')
                                  .format(DateTime.parse(dateKeys[i]));
                              final isLast = i == lastIdx;
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  wd,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isLast
                                        ? (isDark
                                            ? AppColors.accentLime
                                            : AppColors.primaryDark)
                                        : onSurfaceVariant,
                                    fontWeight:
                                        isLast ? FontWeight.w800 : FontWeight.w500,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < values.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: values[i],
                                width: 18,
                                color: i == lastIdx
                                    ? AppColors.accentLime
                                    : const Color(0xFF4AAA60),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(5),
                                ),
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: maxY,
                                  color: backRodColor,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                  )
                : Center(
                    child: Text(
                      'Save sales to see your trend',
                      style: TextStyle(color: onSurfaceVariant, fontSize: 13),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
