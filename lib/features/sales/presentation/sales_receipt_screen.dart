import 'package:avogs/core/theme/app_colors.dart';
import 'package:avogs/core/utils/formatters.dart';
import 'package:avogs/shared/services/receipt_pdf_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SalesReceiptScreen extends ConsumerStatefulWidget {
  const SalesReceiptScreen({
    super.key,
    required this.reference,
    required this.customerName,
    required this.storeCode,
    required this.documentDate,
    required this.lines,
    required this.total,
    this.paymentMethod,
    this.queuedOffline = false,
  });

  final String reference;
  final String customerName;
  final String storeCode;
  final String documentDate;
  final List<ReceiptLine> lines;
  final double total;
  final String? paymentMethod;
  final bool queuedOffline;

  @override
  ConsumerState<SalesReceiptScreen> createState() => _SalesReceiptScreenState();
}

class _SalesReceiptScreenState extends ConsumerState<SalesReceiptScreen> {
  var _sharing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt'),
        actions: [
          if (!widget.queuedOffline)
            IconButton(
              onPressed: _sharing ? null : () => _share(context),
              icon: _sharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share),
            ),
          if (!widget.queuedOffline)
            IconButton(
              onPressed: () => _print(context),
              icon: const Icon(Icons.print),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.queuedOffline)
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
                    widget.reference,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(widget.customerName),
                  Text('Store: ${widget.storeCode} · ${widget.documentDate}'),
                  if (widget.paymentMethod != null)
                    Text('Payment: ${widget.paymentMethod}'),
                  const Divider(height: 24),
                  for (final line in widget.lines)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(child: Text(line.description)),
                          Text(formatMoney(line.total)),
                        ],
                      ),
                    ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Text(
                        'Total',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      Text(
                        formatMoney(widget.total),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryGreen,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _sharing ? null : () => _share(context),
            icon: const Icon(Icons.share),
            label: const Text('Share receipt'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    setState(() => _sharing = true);
    try {
      await ref.read(receiptPdfServiceProvider).shareSalesReceipt(
            reference: widget.reference,
            customerName: widget.customerName,
            storeCode: widget.storeCode,
            documentDate: widget.documentDate,
            lines: widget.lines,
            total: widget.total,
            paymentMethod: widget.paymentMethod,
          );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share receipt: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _print(BuildContext context) async {
    try {
      await ref.read(receiptPdfServiceProvider).printSalesReceipt(
            reference: widget.reference,
            customerName: widget.customerName,
            storeCode: widget.storeCode,
            documentDate: widget.documentDate,
            lines: widget.lines,
            total: widget.total,
            paymentMethod: widget.paymentMethod,
          );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not print receipt: $e')),
        );
      }
    }
  }
}
