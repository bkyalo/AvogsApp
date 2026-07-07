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
    ref.invalidate(dashboardProvider);
    try {
      await Future.wait([
        ref.read(syncServiceProvider.notifier).syncPending(),
        ref.read(dashboardProvider.future),
      ]);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardProvider);
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
                dashboardAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text(
                    'Could not load dashboard: $e',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  data: (snapshot) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (snapshot.isOffline)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 14, color: onSurfaceVariant),
                              const SizedBox(width: 6),
                              Text(
                                "Showing sales made on this device — couldn't reach the server",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Container(
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
                                  isMorning
                                      ? '7:00 AM — 2:00 PM'
                                      : '2:00 PM — 9:00 PM',
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
                                  formatMoney(snapshot.today.salesAmount),
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
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                dashboardAsync.when(
                  loading: () => const SizedBox(
                    height: 180,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text('Trend unavailable: $e'),
                  data: (snapshot) => _DashboardTrendChart(
                    days: snapshot.trend,
                    cardColor: cardColor,
                    onSurface: onSurface,
                    onSurfaceVariant: onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                dashboardAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (snapshot) {
                    final today = snapshot.today;
                    return GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.25,
                      children: [
                        _KpiCard(
                          icon: Icons.point_of_sale_outlined,
                          value: formatMoney(today.salesAmount),
                          label: "Today's Sales",
                          tag: snapshot.date,
                          accent: const Color(0xFF4AAA60),
                          cardColor: cardColor,
                          onSurface: onSurface,
                          onSurfaceVariant: onSurfaceVariant,
                        ),
                        _KpiCard(
                          icon: Icons.shopping_bag_outlined,
                          value: '${today.unitsSold}',
                          label: 'Units Sold',
                          tag: 'Today',
                          accent: AppColors.errorRed,
                          cardColor: cardColor,
                          onSurface: onSurface,
                          onSurfaceVariant: onSurfaceVariant,
                        ),
                        _KpiCard(
                          icon: Icons.local_shipping_outlined,
                          value: formatMoney(today.purchasesAmount),
                          label: 'Purchases Today',
                          tag: '${today.purchaseCount} invoice(s)',
                          accent: AppColors.infoBlue,
                          cardColor: cardColor,
                          onSurface: onSurface,
                          onSurfaceVariant: onSurfaceVariant,
                        ),
                        _KpiCard(
                          icon: Icons.receipt_long_outlined,
                          value: '${today.invoiceCount}',
                          label: 'Invoices Today',
                          tag: 'Sales transactions',
                          accent: AppColors.honey,
                          cardColor: cardColor,
                          onSurface: onSurface,
                          onSurfaceVariant: onSurfaceVariant,
                        ),
                      ],
                    );
                  },
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

/// Grouped bar chart: two series (sales vs purchases) per the Flutter
/// chart guidance in MOBILE_APP_GUIDE.md v2.4.0. units_sold is available
/// per KPI card already and is left out here — it's a unit count, not a
/// currency amount, so mixing it into a money-scaled chart would make both
/// series unreadable.
class _DashboardTrendChart extends StatelessWidget {
  const _DashboardTrendChart({
    required this.days,
    required this.cardColor,
    required this.onSurface,
    required this.onSurfaceVariant,
  });

  final List<DashboardTrendPoint> days;
  final Color cardColor;
  final Color onSurface;
  final Color onSurfaceVariant;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final salesValues = days.map((d) => d.salesAmount).toList();
    final purchaseValues = days.map((d) => d.purchasesAmount).toList();
    final dateKeys = days.map((d) => d.date).toList();
    final hasData = salesValues.any((v) => v > 0) || purchaseValues.any((v) => v > 0);
    final maxV = [...salesValues, ...purchaseValues]
        .fold(0.0, (a, v) => a > v ? a : v);
    final maxY = (maxV == 0 ? 1000 : maxV) * 1.25;
    final lastIdx = salesValues.length - 1;
    final salesTotal = salesValues.fold(0.0, (a, v) => a + v);
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
                    'Sales vs Purchases',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: onSurface,
                    ),
                  ),
                ],
              ),
              if (hasData)
                Text(
                  formatMoney(salesTotal),
                  style: AppTheme.mono(
                    size: 14,
                    color: AppColors.primaryGreen,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _LegendDot(color: AppColors.primaryGreen, label: 'Sales'),
              const SizedBox(width: 12),
              _LegendDot(color: AppColors.infoBlue, label: 'Purchases'),
            ],
          ),
          const SizedBox(height: 10),
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
                          getTooltipItem: (group, _, rod, rodIndex) {
                            final k = dateKeys[group.x];
                            final label =
                                DateFormat('EEE d').format(DateTime.parse(k));
                            final seriesLabel =
                                rodIndex == 0 ? 'Sales' : 'Purchases';
                            return BarTooltipItem(
                              '$label · $seriesLabel\n',
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
                        for (var i = 0; i < salesValues.length; i++)
                          BarChartGroupData(
                            x: i,
                            barsSpace: 3,
                            barRods: [
                              BarChartRodData(
                                toY: salesValues[i],
                                width: 8,
                                color: i == lastIdx
                                    ? AppColors.accentLime
                                    : AppColors.primaryGreen,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(3),
                                ),
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: maxY,
                                  color: backRodColor,
                                ),
                              ),
                              BarChartRodData(
                                toY: purchaseValues[i],
                                width: 8,
                                color: AppColors.infoBlue,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(3),
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

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: onSurfaceVariant),
        ),
      ],
    );
  }
}
