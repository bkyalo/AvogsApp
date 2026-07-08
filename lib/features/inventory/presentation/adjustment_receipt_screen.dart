import 'package:avogs/core/theme/app_colors.dart';
import 'package:avogs/core/utils/formatters.dart';
import 'package:avogs/shared/utils/receipt_line_parser.dart';
import 'package:flutter/material.dart';

class AdjustmentReceiptScreen extends StatelessWidget {
  const AdjustmentReceiptScreen({
    super.key,
    required this.reference,
    required this.location,
    required this.documentDate,
    required this.lines,
    this.memo,
    this.queuedOffline = false,
  });

  factory AdjustmentReceiptScreen.fromPayload(
    Map<String, dynamic> payload, {
    bool queuedOffline = false,
  }) {
    return AdjustmentReceiptScreen(
      reference: payload['reference'] as String? ?? 'Adjustment',
      location: payload['location'] as String? ?? '',
      documentDate: payload['document_date'] as String? ?? '',
      memo: payload['memo'] as String?,
      lines: adjustmentLinesFromPayload(payload),
      queuedOffline: queuedOffline,
    );
  }

  final String reference;
  final String location;
  final String documentDate;
  final List<AdjustmentReceiptLine> lines;
  final String? memo;
  final bool queuedOffline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final unitsChanged =
        lines.fold<double>(0, (sum, line) => sum + line.quantity.abs());

    return Scaffold(
      appBar: AppBar(title: const Text('Adjustment receipt')),
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
                  if (location.isNotEmpty) Text('Store: $location'),
                  if (documentDate.isNotEmpty) Text('Date: $documentDate'),
                  if (memo != null && memo!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Memo: $memo'),
                  ],
                  const Divider(height: 24),
                  Text('Items adjusted', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  for (final line in lines)
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
                                  line.description,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (line.standardCost != null &&
                                    line.standardCost! > 0)
                                  Text(
                                    'Cost: ${formatMoney(line.standardCost!)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: muted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            line.quantityLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: line.quantity < 0
                                  ? AppColors.errorRed
                                  : AppColors.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (lines.isEmpty)
                    Text(
                      'No line items recorded',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Text('Units changed', style: theme.textTheme.titleMedium),
                      const Spacer(),
                      Text(
                        unitsChanged.toStringAsFixed(
                          unitsChanged % 1 == 0 ? 0 : 2,
                        ),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
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
