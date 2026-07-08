import 'package:avogs/core/theme/app_colors.dart';
import 'package:avogs/core/utils/formatters.dart';
import 'package:avogs/shared/models/transaction_models.dart';
import 'package:flutter/material.dart';

class PaymentReceiptScreen extends StatelessWidget {
  const PaymentReceiptScreen({
    super.key,
    required this.reference,
    required this.amount,
    this.paymentNo,
    this.customerName,
    this.documentDate,
    this.memo,
    this.currency,
    this.discount,
    this.allocations = const [],
    this.queuedOffline = false,
  });

  factory PaymentReceiptScreen.fromDetail(
    PaymentDetail detail, {
    String? customerName,
    bool queuedOffline = false,
  }) {
    return PaymentReceiptScreen(
      reference: detail.reference,
      amount: detail.amount,
      paymentNo: detail.paymentNo > 0 ? detail.paymentNo : null,
      customerName: customerName,
      documentDate: detail.documentDate,
      memo: detail.memo,
      currency: detail.currency,
      discount: detail.discount,
      allocations: detail.allocations,
      queuedOffline: queuedOffline,
    );
  }

  factory PaymentReceiptScreen.fromPayload(
    Map<String, dynamic> payload, {
    String? customerName,
    bool queuedOffline = false,
  }) {
    final allocationMaps =
        (payload['allocations'] as List<dynamic>? ?? []).whereType<Map>();
    return PaymentReceiptScreen(
      reference: payload['reference'] as String? ?? 'Payment',
      amount: (payload['amount'] as num?)?.toDouble() ?? 0,
      customerName: customerName,
      documentDate: payload['document_date'] as String?,
      memo: payload['memo'] as String?,
      allocations: allocationMaps
          .map((a) => PaymentAllocationDetail.fromJson(
                Map<String, dynamic>.from(a),
              ))
          .toList(),
      queuedOffline: queuedOffline,
    );
  }

  final String reference;
  final double amount;
  final int? paymentNo;
  final String? customerName;
  final String? documentDate;
  final String? memo;
  final String? currency;
  final double? discount;
  final List<PaymentAllocationDetail> allocations;
  final bool queuedOffline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('Payment receipt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (queuedOffline)
            const Card(
              child: ListTile(
                leading: Icon(Icons.cloud_upload, color: AppColors.honey),
                title: Text('Queued offline'),
                subtitle: Text('Will sync when connection is restored.'),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reference,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (paymentNo != null) Text('Payment #$paymentNo'),
                  if (customerName != null && customerName!.isNotEmpty)
                    Text(customerName!),
                  if (documentDate != null) Text('Date: $documentDate'),
                  if (memo != null && memo!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Memo: $memo'),
                  ],
                  const Divider(height: 24),
                  Row(
                    children: [
                      Text('Amount received', style: theme.textTheme.titleMedium),
                      const Spacer(),
                      Text(
                        formatMoney(amount),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                  if (discount != null && discount! > 0) ...[
                    const SizedBox(height: 8),
                    Text('Discount: ${formatMoney(discount!)}'),
                  ],
                  if (allocations.isNotEmpty) ...[
                    const Divider(height: 24),
                    Text('Allocated to', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    for (final alloc in allocations)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    alloc.reference ??
                                        'Invoice #${alloc.transNo}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (alloc.date != null)
                                    Text(
                                      alloc.date!,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: muted,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Text(formatMoney(alloc.allocated)),
                          ],
                        ),
                      ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'No invoice allocations recorded',
                        style: theme.textTheme.bodySmall?.copyWith(color: muted),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
