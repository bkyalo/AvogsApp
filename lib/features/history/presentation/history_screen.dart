import 'dart:convert';

import 'package:avogs/core/sync/sync_service.dart';
import 'package:avogs/core/theme/app_colors.dart';
import 'package:avogs/core/utils/formatters.dart';
import 'package:avogs/features/history/application/history_provider.dart';
import 'package:avogs/features/master_data/master_data_repository.dart';
import 'package:avogs/features/payments/presentation/payment_receipt_screen.dart';
import 'package:avogs/features/reports/reports_repository.dart';
import 'package:avogs/features/sales/presentation/sales_receipt_screen.dart';
import 'package:avogs/features/transactions/transaction_repositories.dart';
import 'package:avogs/shared/services/receipt_pdf_service.dart';
import 'package:avogs/shared/widgets/sync_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(historyEntriesProvider);

    return Column(
      children: [
        const SyncStatusBanner(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search reference or customer...',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: entriesAsync.when(
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
                      onPressed: () => ref.invalidate(historyEntriesProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
            data: (entries) {
              final filtered = entries.where((e) {
                if (_query.isEmpty) return true;
                return e.reference.toLowerCase().contains(_query) ||
                    e.subtitle.toLowerCase().contains(_query) ||
                    e.typeLabel.toLowerCase().contains(_query);
              }).toList();

              if (filtered.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Text('No transactions yet')),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    return _HistoryTile(
                      entry: entry,
                      onTap: () => _openDetail(context, entry),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(historyEntriesProvider);
    ref.invalidate(shadowSalesProvider);
    await ref.read(historyEntriesProvider.future);
  }

  Future<void> _openDetail(BuildContext context, HistoryEntry entry) async {
    if (entry.type == SyncItemType.salesPayment) {
      String? customerName;
      try {
        final customers = await ref.read(customersProvider.future);
        final customerId = entry.customerId;
        if (customerId != null) {
          customerName = customers
              .where((c) => c.id == customerId)
              .map((c) => c.name)
              .firstOrNull;
        }
      } catch (_) {}

      if (entry.source == HistoryEntrySource.api && entry.serverId != null) {
        try {
          final payment = await ref
              .read(paymentRepositoryProvider)
              .fetchPayment(entry.serverId!);
          if (!context.mounted) return;
          await Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => PaymentReceiptScreen.fromDetail(
                payment,
                customerName: customerName,
              ),
            ),
          );
          return;
        } catch (_) {}
      }

      if (entry.payloadJson != null) {
        try {
          final payload = Map<String, dynamic>.from(
            jsonDecode(entry.payloadJson!) as Map,
          );
          if (!context.mounted) return;
          await Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => PaymentReceiptScreen.fromPayload(
                payload,
                customerName: customerName ?? entry.subtitle,
                queuedOffline: entry.status != 'synced',
              ),
            ),
          );
        } catch (_) {}
      }
      return;
    }

    if (entry.type != SyncItemType.salesInvoice) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${entry.typeLabel} detail coming soon')),
      );
      return;
    }

    if (entry.source == HistoryEntrySource.api && entry.serverId != null) {
      try {
        final sale = (await ref.read(shadowSalesProvider.future))
            .firstWhere((s) => s.invoiceNo == entry.serverId);
        if (!context.mounted) return;
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => SalesReceiptScreen(
              reference: sale.reference,
              customerName: sale.customer,
              storeCode: '',
              documentDate: sale.time.split('T').first,
              lines: sale.lines
                  .map(
                    (l) => ReceiptLine(
                      description: l.name,
                      quantity: l.qty.toDouble(),
                      unitPrice: l.unitPrice,
                      total: (l.qty * l.unitPrice) - l.discount,
                    ),
                  )
                  .toList(),
              total: sale.total,
              paymentMethod: sale.paymentMethod,
            ),
          ),
        );
        return;
      } catch (_) {}
    }

    if (entry.payloadJson != null) {
      final payload = entry.payloadJson!;
      final lines = _linesFromPayload(payload);
      if (lines.isEmpty) return;
      if (!context.mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => SalesReceiptScreen(
            reference: entry.reference,
            customerName: entry.subtitle,
            storeCode: '',
            documentDate: DateTime.now().toString().split(' ').first,
            lines: lines,
            total: entry.total ?? lines.fold(0.0, (s, l) => s + l.total),
            queuedOffline: entry.status != 'synced',
          ),
        ),
      );
    }
  }

  List<ReceiptLine> _linesFromPayload(String payloadJson) {
    try {
      final payload = Map<String, dynamic>.from(
        jsonDecode(payloadJson) as Map,
      );
      final lines = payload['lines'] as List<dynamic>? ?? [];
      return lines.whereType<Map<String, dynamic>>().map((l) {
        final qty = (l['quantity'] as num?)?.toDouble() ?? 0;
        final price = (l['unit_price'] as num?)?.toDouble() ?? 0;
        final discount = (l['discount_percent'] as num?)?.toDouble() ?? 0;
        final total = qty * price * (1 - discount / 100);
        return ReceiptLine(
          description: l['stock_id'] as String? ?? 'Item',
          quantity: qty,
          unitPrice: price,
          total: total,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry, required this.onTap});

  final HistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (entry.status) {
      'synced' => AppColors.primaryGreen,
      'pending' => Colors.orange,
      'failed' => AppColors.errorRed,
      'syncing' => Colors.blue,
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
    };

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Icon(_iconForType(entry.type), color: statusColor, size: 20),
        ),
        title: Text(entry.reference),
        subtitle: Text(
          '${entry.typeLabel} · ${entry.subtitle}\n${formatDate(entry.timestamp)}',
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (entry.total != null)
              Text(
                formatMoney(entry.total!),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 4),
            Text(
              entry.status,
              style: TextStyle(fontSize: 12, color: statusColor),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(SyncItemType type) => switch (type) {
        SyncItemType.salesInvoice => Icons.point_of_sale,
        SyncItemType.salesPayment => Icons.payments_outlined,
        SyncItemType.supplierInvoice => Icons.local_shipping_outlined,
        SyncItemType.inventoryAdjustment => Icons.inventory_2_outlined,
        SyncItemType.shiftCheckin => Icons.schedule,
        SyncItemType.shiftCheckout => Icons.schedule_outlined,
      };
}
