import 'dart:convert';

import 'package:avogs/core/api/api_client.dart';
import 'package:avogs/core/config/app_config_provider.dart';
import 'package:avogs/core/database/app_database.dart';
import 'package:avogs/core/sync/sync_service.dart';
import 'package:avogs/core/utils/formatters.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(
    api: ref.watch(apiClientProvider),
    storeCode: ref.watch(appConfigProvider).selectedStoreCode,
  );
});

/// Today's KPI figures, per MOBILE_APP_GUIDE.md v2.4.0 (`GET /api/dashboard`).
class DashboardToday {
  const DashboardToday({
    required this.salesAmount,
    required this.unitsSold,
    required this.purchasesAmount,
    required this.invoiceCount,
    required this.purchaseCount,
  });

  factory DashboardToday.fromJson(Map<String, dynamic> json) {
    return DashboardToday(
      salesAmount: _asDouble(json['sales_amount']),
      unitsSold: _asInt(json['units_sold']),
      purchasesAmount: _asDouble(json['purchases_amount']),
      invoiceCount: _asInt(json['invoice_count']),
      purchaseCount: _asInt(json['purchase_count']),
    );
  }

  final double salesAmount;
  final int unitsSold;
  final double purchasesAmount;
  final int invoiceCount;
  final int purchaseCount;
}

/// One point in the 7-day trend series.
class DashboardTrendPoint {
  const DashboardTrendPoint({
    required this.date,
    required this.salesAmount,
    required this.unitsSold,
    required this.purchasesAmount,
  });

  factory DashboardTrendPoint.fromJson(Map<String, dynamic> json) {
    return DashboardTrendPoint(
      date: json['date'] as String? ?? '',
      salesAmount: _asDouble(json['sales_amount']),
      unitsSold: _asInt(json['units_sold']),
      purchasesAmount: _asDouble(json['purchases_amount']),
    );
  }

  final String date;
  final double salesAmount;
  final int unitsSold;
  final double purchasesAmount;
}

/// Full response from `GET /api/dashboard?days=7`.
class DashboardSnapshot {
  const DashboardSnapshot({
    required this.date,
    required this.currency,
    required this.today,
    required this.trend,
    this.isOffline = false,
  });

  factory DashboardSnapshot.fromJson(Map<String, dynamic> json) {
    return DashboardSnapshot(
      date: json['date'] as String? ?? toApiDate(DateTime.now()),
      currency: json['currency'] as String? ?? 'KES',
      today: DashboardToday.fromJson(
        json['today'] as Map<String, dynamic>? ?? const {},
      ),
      trend: (json['trend'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(DashboardTrendPoint.fromJson)
          .toList(),
    );
  }

  final String date;
  final String currency;
  final DashboardToday today;
  final List<DashboardTrendPoint> trend;
  // True when this snapshot was computed locally because the API call
  // failed (offline, unreachable, error). Lets the UI show a subtle notice
  // instead of silently presenting figures that may only cover this device.
  final bool isOffline;
}

class ShadowSaleLine {
  const ShadowSaleLine({
    required this.stockId,
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.discount,
  });

  factory ShadowSaleLine.fromJson(Map<String, dynamic> json) {
    return ShadowSaleLine(
      stockId: json['stock_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      qty: _asInt(json['qty']),
      unitPrice: _asDouble(json['unit_price']),
      discount: _asDouble(json['discount']),
    );
  }

  final String stockId;
  final String name;
  final int qty;
  final double unitPrice;
  final double discount;
}

class ShadowSale {
  const ShadowSale({
    required this.invoiceNo,
    required this.reference,
    required this.customer,
    required this.paymentMethod,
    required this.time,
    required this.total,
    required this.lines,
  });

  factory ShadowSale.fromJson(Map<String, dynamic> json) {
    return ShadowSale(
      invoiceNo: _asInt(json['invoice_no']),
      reference: json['reference'] as String? ?? '',
      customer: json['customer'] as String? ?? '',
      paymentMethod: json['payment_method'] as String? ?? '',
      time: json['time'] as String? ?? '',
      total: _asDouble(json['total']),
      lines: (json['lines'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ShadowSaleLine.fromJson)
          .toList(),
    );
  }

  final int invoiceNo;
  final String reference;
  final String customer;
  final String paymentMethod;
  final String time;
  final double total;
  final List<ShadowSaleLine> lines;
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

class ReportsRepository {
  ReportsRepository({required ApiClient api, required String? storeCode})
      : _api = api,
        _storeCode = storeCode;

  final ApiClient _api;
  final String? _storeCode;

  Map<String, dynamic> _storeQuery([Map<String, dynamic>? extra]) {
    final query = <String, dynamic>{...?extra};
    if (_storeCode != null && _storeCode.isNotEmpty) {
      query['store'] = _storeCode;
    }
    return query;
  }

  /// GET /api/dashboard?days=7 — combined today + trend in one call.
  /// NOTE: MOBILE_APP_GUIDE.md doesn't document a `store` filter for this
  /// endpoint (unlike the other report endpoints below), so none is sent.
  /// If the backend actually scopes by the authenticated user/token that's
  /// fine; if it turns out multi-store totals bleed together, this is the
  /// first place to add `?store=`.
  Future<DashboardSnapshot> fetchDashboard({int days = 7, String? date}) async {
    final query = <String, dynamic>{'days': days};
    if (date != null) query['date'] = date;
    final data = await _api.getJson('/dashboard', queryParameters: query);
    return DashboardSnapshot.fromJson(data);
  }

  Future<List<ShadowSale>> fetchShadowSales({String? date}) async {
    final data = await _api.getJsonList(
      '/sales/invoices',
      queryParameters: _storeQuery(date != null ? {'date': date} : null),
    );
    return data
        .whereType<Map<String, dynamic>>()
        .map(ShadowSale.fromJson)
        .toList();
  }
}

/// Single source for the whole dashboard: tries the real API first, and
/// falls back to a snapshot computed from the local sync queue (sales +
/// purchases already submitted through this app/device) if the call fails
/// for any reason — offline, unreachable, timeout, server error. This way
/// the dashboard never goes blank, but prefers the authoritative store-wide
/// numbers whenever they're reachable.
final dashboardProvider = FutureProvider<DashboardSnapshot>((ref) async {
  final repo = ref.watch(reportsRepositoryProvider);
  try {
    return await repo.fetchDashboard(days: 7);
  } catch (_) {
    final db = ref.watch(appDatabaseProvider);
    final items = await db.allSyncItems();
    return _localDashboardSnapshot(items);
  }
});

final shadowSalesProvider = FutureProvider<List<ShadowSale>>((ref) async {
  return ref.watch(reportsRepositoryProvider).fetchShadowSales();
});

bool _isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _DayTotals {
  const _DayTotals({
    required this.date,
    required this.salesAmount,
    required this.unitsSold,
    required this.purchasesAmount,
    required this.invoiceCount,
    required this.purchaseCount,
  });

  final String date;
  final double salesAmount;
  final int unitsSold;
  final double purchasesAmount;
  final int invoiceCount;
  final int purchaseCount;
}

/// Sums sales-invoice and supplier-invoice sync items (both queued offline
/// and already-synced, since either way the transaction genuinely happened)
/// created on [day]. Sales lines carry a discount_percent; purchase lines
/// don't (see TransactionLine.toPurchaseJson).
_DayTotals _localDayTotals(List<SyncQueueItem> items, DateTime day) {
  var salesAmount = 0.0;
  var unitsSoldRaw = 0.0;
  var purchasesAmount = 0.0;
  var invoiceCount = 0;
  var purchaseCount = 0;

  for (final item in items) {
    if (!_isSameDate(item.createdAt, day)) continue;

    Map<String, dynamic> payload;
    try {
      payload = Map<String, dynamic>.from(jsonDecode(item.payloadJson) as Map);
    } catch (_) {
      continue;
    }
    final lines = payload['lines'] as List<dynamic>? ?? [];

    if (item.type == SyncItemType.salesInvoice.value) {
      invoiceCount++;
      for (final raw in lines) {
        if (raw is! Map<String, dynamic>) continue;
        final qty = _asDouble(raw['quantity']);
        final price = _asDouble(raw['unit_price']);
        final discountPct = _asDouble(raw['discount_percent']);
        salesAmount += qty * price * (1 - discountPct / 100);
        unitsSoldRaw += qty;
      }
    } else if (item.type == SyncItemType.supplierInvoice.value) {
      purchaseCount++;
      for (final raw in lines) {
        if (raw is! Map<String, dynamic>) continue;
        final qty = _asDouble(raw['quantity']);
        final price = _asDouble(raw['unit_price']);
        purchasesAmount += qty * price;
      }
    }
  }

  return _DayTotals(
    date: toApiDate(day),
    salesAmount: salesAmount,
    unitsSold: unitsSoldRaw.round(),
    purchasesAmount: purchasesAmount,
    invoiceCount: invoiceCount,
    purchaseCount: purchaseCount,
  );
}

DashboardSnapshot _localDashboardSnapshot(List<SyncQueueItem> items) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final trendTotals = [
    for (var offset = 6; offset >= 0; offset--)
      _localDayTotals(items, today.subtract(Duration(days: offset))),
  ];
  final todayTotals = trendTotals.last;

  return DashboardSnapshot(
    date: todayTotals.date,
    currency: 'KES',
    today: DashboardToday(
      salesAmount: todayTotals.salesAmount,
      unitsSold: todayTotals.unitsSold,
      purchasesAmount: todayTotals.purchasesAmount,
      invoiceCount: todayTotals.invoiceCount,
      purchaseCount: todayTotals.purchaseCount,
    ),
    trend: [
      for (final t in trendTotals)
        DashboardTrendPoint(
          date: t.date,
          salesAmount: t.salesAmount,
          unitsSold: t.unitsSold,
          purchasesAmount: t.purchasesAmount,
        ),
    ],
    isOffline: true,
  );
}
