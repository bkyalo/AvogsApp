import 'package:avogs/core/theme/app_colors.dart';
import 'package:avogs/core/utils/formatters.dart';
import 'package:avogs/shared/models/transaction_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CatalogPickerSheet extends StatefulWidget {
  const CatalogPickerSheet({
    super.key,
    required this.catalog,
    required this.onSelected,
    this.showPrice,
    this.showQoh = true,
  });

  final List<CatalogItem> catalog;
  final ValueChanged<CatalogItem> onSelected;
  final double? Function(CatalogItem item)? showPrice;
  final bool showQoh;

  static Future<void> show(
    BuildContext context, {
    required List<CatalogItem> catalog,
    required ValueChanged<CatalogItem> onSelected,
    double? Function(CatalogItem item)? showPrice,
    bool showQoh = true,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CatalogPickerSheet(
        catalog: catalog,
        onSelected: onSelected,
        showPrice: showPrice,
        showQoh: showQoh,
      ),
    );
  }

  @override
  State<CatalogPickerSheet> createState() => _CatalogPickerSheetState();
}

class _CatalogPickerSheetState extends State<CatalogPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final filtered = widget.catalog.where((item) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return item.stockId.toLowerCase().contains(q) ||
          item.description.toLowerCase().contains(q);
    }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search items...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final price = widget.showPrice?.call(item);
                    return ListTile(
                      title: Text(item.description),
                      subtitle: Text(
                        [
                          item.stockId,
                          if (widget.showQoh && item.qoh != null)
                            'QOH ${item.qoh!.toStringAsFixed(0)}',
                          if (price != null) formatMoney(price),
                        ].join(' · '),
                        style: TextStyle(color: muted),
                      ),
                      trailing: const Icon(Icons.add_circle_outline),
                      onTap: () {
                        widget.onSelected(item);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class TransactionLineList extends StatelessWidget {
  const TransactionLineList({
    super.key,
    required this.lines,
    required this.onQuantityChanged,
    required this.onRemove,
    this.onUnitPriceChanged,
    this.showDiscount = false,
    this.allowNegativeQuantity = false,
  });

  final List<TransactionLine> lines;
  final void Function(int index, double quantity) onQuantityChanged;
  final void Function(int index) onRemove;
  final void Function(int index, double price)? onUnitPriceChanged;
  final bool showDiscount;
  final bool allowNegativeQuantity;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    if (lines.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No lines yet — add items from the catalog',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: muted,
                  ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          _LineCard(
            line: lines[i],
            showDiscount: showDiscount,
            allowNegativeQuantity: allowNegativeQuantity,
            onQuantityChanged: (q) => onQuantityChanged(i, q),
            onUnitPriceChanged:
                onUnitPriceChanged == null ? null : (p) => onUnitPriceChanged!(i, p),
            onRemove: () => onRemove(i),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.line,
    required this.onQuantityChanged,
    required this.onRemove,
    this.onUnitPriceChanged,
    required this.showDiscount,
    required this.allowNegativeQuantity,
  });

  final TransactionLine line;
  final ValueChanged<double> onQuantityChanged;
  final ValueChanged<double>? onUnitPriceChanged;
  final VoidCallback onRemove;
  final bool showDiscount;
  final bool allowNegativeQuantity;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.description,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        line.stockId,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: muted,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            if (line.exceedsQoh)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: AppColors.honey, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Quantity exceeds stock on hand (${line.qoh!.toStringAsFixed(0)})',
                        style: const TextStyle(
                          color: AppColors.honey,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                _QtyField(
                  value: line.quantity,
                  allowNegative: allowNegativeQuantity,
                  onChanged: onQuantityChanged,
                ),
                const SizedBox(width: 12),
                if (onUnitPriceChanged != null)
                  Expanded(
                    child: TextFormField(
                      initialValue: line.unitPrice.toStringAsFixed(2),
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        isDense: true,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      onChanged: (v) {
                        final parsed = double.tryParse(v);
                        if (parsed != null) onUnitPriceChanged!(parsed);
                      },
                    ),
                  ),
                const Spacer(),
                Text(
                  formatMoney(line.lineTotal),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyField extends StatelessWidget {
  const _QtyField({
    required this.value,
    required this.onChanged,
    required this.allowNegative,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final bool allowNegative;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () {
            final next = value - 1;
            if (next == 0 && !allowNegative) return;
            onChanged(next);
          },
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 48,
          child: Text(
            value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}

class TransactionTotalBar extends StatelessWidget {
  const TransactionTotalBar({
    super.key,
    required this.total,
    required this.onSubmit,
    required this.submitLabel,
    this.submitting = false,
    this.enabled = true,
  });

  final double total;
  final VoidCallback? onSubmit;
  final String submitLabel;
  final bool submitting;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      elevation: 8,
      color: colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  Text(
                    formatMoney(total),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                  ),
                ],
              ),
              const Spacer(),
              FilledButton(
                onPressed: (enabled && !submitting) ? onSubmit : null,
                child: submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(submitLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> confirmStockWarnings(
  BuildContext context,
  List<TransactionLine> lines,
) async {
  final warnings = lines.where((l) => l.exceedsQoh).toList();
  if (warnings.isEmpty) return true;

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Low stock warning'),
      content: Text(
        '${warnings.length} line(s) exceed quantity on hand. Continue anyway?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  return result ?? false;
}
