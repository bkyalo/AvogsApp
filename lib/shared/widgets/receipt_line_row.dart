import 'package:avogs/core/utils/formatters.dart';
import 'package:avogs/shared/services/receipt_pdf_service.dart';
import 'package:flutter/material.dart';

class ReceiptLineRow extends StatelessWidget {
  const ReceiptLineRow({
    super.key,
    required this.line,
    this.showPricing = true,
  });

  final ReceiptLine line;
  final bool showPricing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Padding(
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
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (showPricing)
                  Text(
                    '${_formatQty(line.quantity)} x ${formatMoney(line.unitPrice)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
              ],
            ),
          ),
          if (showPricing)
            Text(
              formatMoney(line.total),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }

  String _formatQty(double qty) {
    return qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2);
  }
}
