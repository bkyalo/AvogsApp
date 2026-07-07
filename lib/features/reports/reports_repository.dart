import 'package:avogs/core/api/api_client.dart';
import 'package:avogs/core/config/app_config_provider.dart';
import 'package:avogs/core/utils/formatters.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(
    api: ref.watch(apiClientProvider),
    storeCode: ref.watch(appConfigProvider).selectedStoreCode,
  );
});

class SalesDaySummary {
  const SalesDaySummary({
    required this.date,
    required this.total,
    required this.units,
    required this.retail,
    required this.wholesale,
    required this.honey,
    required this.beverage,
    required this.discountTotal,
  });

  factory SalesDaySummary.fromJson(Map<String, dynamic> json) {
    final day = json['day'] as Map<String, dynamic>? ?? {};
    return SalesDaySummary(
      date: json['date'] as String? ?? toApiDate(DateTime.now()),
      total: _asDouble(day['total']),
      units: _asInt(day['units']),
      retail: _asDouble(day['retail']),
      wholesale: _asDouble(day['wholesale']),
      honey: _asDouble(day['honey']),
      beverage: _asDouble(day['beverage']),
      discountTotal: _asDouble(json['discount_total']),
    );
  }

  final String date;
  final double total;
  final int units;
  final double retail;
  final double wholesale;
  final double honey;
  final double beverage;
  final double discountTotal;
}

class SalesTrendDay {
  const SalesTrendDay({
    required this.date,
    required this.total,
    required this.avocado,
    required this.honey,
    required this.beverage,
  });

  factory SalesTrendDay.fromJson(Map<String, dynamic> json) {
    return SalesTrendDay(
      date: json['date'] as String,
      total: _asDouble(json['total']),
      avocado: _asDouble(json['avocado']),
      honey: _asDouble(json['honey']),
      beverage: _asDouble(json['beverage']),
    );
  }

  final String date;
  final double total;
  final double avocado;
  final double honey;
  final double beverage;
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

  Future<SalesDaySummary> fetchTodaySummary({String? date}) async {
    final data = await _api.getJson(
      '/sales/summary',
      queryParameters: _storeQuery(date != null ? {'date': date} : null),
    );
    return SalesDaySummary.fromJson(data);
  }

  Future<List<SalesTrendDay>> fetchSalesTrend({int days = 7}) async {
    final data = await _api.getJson(
      '/reports/sales-trend',
      queryParameters: _storeQuery({'days': days}),
    );
    return (data['days'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(SalesTrendDay.fromJson)
        .toList();
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

final todaySalesSummaryProvider = FutureProvider<SalesDaySummary>((ref) async {
  return ref.watch(reportsRepositoryProvider).fetchTodaySummary();
});

final salesTrendProvider = FutureProvider<List<SalesTrendDay>>((ref) async {
  return ref.watch(reportsRepositoryProvider).fetchSalesTrend(days: 7);
});

final shadowSalesProvider = FutureProvider<List<ShadowSale>>((ref) async {
  return ref.watch(reportsRepositoryProvider).fetchShadowSales();
});
