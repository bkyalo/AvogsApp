import 'dart:convert';

import 'package:avogs/core/database/app_database.dart';
import 'package:avogs/core/sync/sync_service.dart';
import 'package:avogs/features/master_data/master_data_repository.dart';
import 'package:avogs/features/reports/reports_repository.dart';
import 'package:avogs/shared/utils/receipt_line_parser.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum HistoryEntrySource { local, api }

class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.type,
    required this.reference,
    required this.subtitle,
    required this.total,
    required this.timestamp,
    required this.status,
    required this.source,
    this.serverId,
    this.payloadJson,
    this.customerId,
    this.itemSummary,
  });

  final String id;
  final SyncItemType type;
  final String reference;
  final String subtitle;
  final double? total;
  final DateTime timestamp;
  final String status;
  final HistoryEntrySource source;
  final int? serverId;
  final String? payloadJson;
  final int? customerId;
  final String? itemSummary;

  String get typeLabel => switch (type) {
        SyncItemType.salesInvoice => 'Sale',
        SyncItemType.salesPayment => 'Payment',
        SyncItemType.supplierInvoice => 'Purchase',
        SyncItemType.inventoryAdjustment => 'Adjustment',
        SyncItemType.shiftCheckin => 'Shift check-in',
        SyncItemType.shiftCheckout => 'Shift check-out',
      };
}

final historyEntriesProvider = FutureProvider<List<HistoryEntry>>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final localItems = await db.allSyncItems();

  Map<int, String> customerNames = {};
  try {
    final customers = await ref.watch(customersProvider.future);
    customerNames = {
      for (final c in customers) c.id: c.name,
    };
  } catch (_) {}

  final localEntries = localItems
      .map((item) => _entryFromSyncItem(item, customerNames))
      .toList();

  List<HistoryEntry> apiEntries = [];
  try {
    final shadowSales = await ref.watch(shadowSalesProvider.future);
    final localRefs = localEntries.map((e) => e.reference).toSet();
    apiEntries = shadowSales
        .where((s) => !localRefs.contains(s.reference))
        .map(_entryFromShadowSale)
        .toList();
  } catch (_) {}

  final merged = [...localEntries, ...apiEntries]
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return merged;
});

HistoryEntry _entryFromSyncItem(
  SyncQueueItem item,
  Map<int, String> customerNames,
) {
  final type = SyncItemType.values.firstWhere(
    (t) => t.value == item.type,
    orElse: () => SyncItemType.salesInvoice,
  );
  final payload = Map<String, dynamic>.from(
    jsonDecode(item.payloadJson) as Map,
  );
  final reference = payload['reference'] as String? ?? item.clientRef;
  final customerId = _parseInt(payload['customer_id']);
  final subtitle = _subtitleForPayload(type, payload, customerNames);
  final total = _totalFromPayload(type, payload);
  final itemSummary = itemSummaryFromPayload(payload);

  return HistoryEntry(
    id: item.id,
    type: type,
    reference: reference,
    subtitle: subtitle,
    total: total,
    timestamp: item.createdAt,
    status: item.status,
    source: HistoryEntrySource.local,
    serverId: item.serverId,
    payloadJson: item.payloadJson,
    customerId: customerId,
    itemSummary: itemSummary,
  );
}

HistoryEntry _entryFromShadowSale(ShadowSale sale) {
  final itemSummary = formatItemSummary(
    sale.lines.map((l) => l.name.isNotEmpty ? l.name : l.stockId),
  );

  return HistoryEntry(
    id: 'shadow-${sale.invoiceNo}',
    type: SyncItemType.salesInvoice,
    reference: sale.reference,
    subtitle: '${sale.customer} · ${sale.paymentMethod}',
    total: sale.total,
    timestamp: DateTime.tryParse(sale.time) ?? DateTime.now(),
    status: 'synced',
    source: HistoryEntrySource.api,
    serverId: sale.invoiceNo,
    itemSummary: itemSummary,
  );
}

String _subtitleForPayload(
  SyncItemType type,
  Map<String, dynamic> payload,
  Map<int, String> customerNames,
) {
  final customerId = _parseInt(payload['customer_id']);
  final customerLabel = customerId == null
      ? 'Customer #?'
      : customerNames[customerId] ?? 'Customer #$customerId';

  return switch (type) {
    SyncItemType.salesInvoice =>
      '$customerLabel · ${payload['location'] ?? ''}',
    SyncItemType.salesPayment => customerLabel,
    SyncItemType.supplierInvoice =>
      '${payload['supplier_id'] ?? '?'} · ${payload['location'] ?? ''}',
    SyncItemType.inventoryAdjustment =>
      payload['location'] as String? ?? 'Adjustment',
    SyncItemType.shiftCheckin =>
      '${payload['store'] ?? '?'} · ${payload['shift'] ?? ''} shift',
    SyncItemType.shiftCheckout =>
      '${payload['store'] ?? '?'} · ${payload['shift'] ?? ''} shift closed',
  };
}

int? _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _totalFromPayload(SyncItemType type, Map<String, dynamic> payload) {
  if (type == SyncItemType.salesPayment) {
    final amount = (payload['amount'] as num?)?.toDouble();
    if (amount != null && amount > 0) return amount;
  }

  final lines = payload['lines'] as List<dynamic>? ?? [];
  if (lines.isEmpty) return null;
  var sum = 0.0;
  for (final line in lines) {
    if (line is! Map<String, dynamic>) continue;
    final qty = (line['quantity'] as num?)?.toDouble() ?? 0;
    final price = (line['unit_price'] as num?)?.toDouble() ?? 0;
    final discount = (line['discount_percent'] as num?)?.toDouble() ?? 0;
    sum += qty * price * (1 - discount / 100);
  }
  return sum > 0 ? sum : null;
}
