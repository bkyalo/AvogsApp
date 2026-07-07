import 'dart:convert';

import 'package:avogs/core/database/app_database.dart';
import 'package:avogs/core/sync/sync_service.dart';
import 'package:avogs/features/reports/reports_repository.dart';
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

  String get typeLabel => switch (type) {
        SyncItemType.salesInvoice => 'Sale',
        SyncItemType.salesPayment => 'Payment',
        SyncItemType.supplierInvoice => 'Purchase',
        SyncItemType.inventoryAdjustment => 'Adjustment',
      };
}

final historyEntriesProvider = FutureProvider<List<HistoryEntry>>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final localItems = await db.allSyncItems();
  final localEntries = localItems.map(_entryFromSyncItem).toList();

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

HistoryEntry _entryFromSyncItem(SyncQueueItem item) {
  final type = SyncItemType.values.firstWhere(
    (t) => t.value == item.type,
    orElse: () => SyncItemType.salesInvoice,
  );
  final payload = Map<String, dynamic>.from(
    jsonDecode(item.payloadJson) as Map,
  );
  final reference = payload['reference'] as String? ?? item.clientRef;
  final subtitle = _subtitleForPayload(type, payload);
  final total = _totalFromPayload(payload);

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
  );
}

HistoryEntry _entryFromShadowSale(ShadowSale sale) {
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
  );
}

String _subtitleForPayload(SyncItemType type, Map<String, dynamic> payload) {
  return switch (type) {
    SyncItemType.salesInvoice =>
      'Customer #${payload['customer_id'] ?? '?'} · ${payload['location'] ?? ''}',
    SyncItemType.salesPayment =>
      'Customer #${payload['customer_id'] ?? '?'}',
    SyncItemType.supplierInvoice =>
      '${payload['supplier_id'] ?? '?'} · ${payload['location'] ?? ''}',
    SyncItemType.inventoryAdjustment =>
      payload['location'] as String? ?? 'Adjustment',
  };
}

double? _totalFromPayload(Map<String, dynamic> payload) {
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
