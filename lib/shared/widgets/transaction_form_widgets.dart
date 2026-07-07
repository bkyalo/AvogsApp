import 'package:avogs/core/theme/app_colors.dart';
import 'package:avogs/core/theme/app_theme.dart';
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

class CustomerPickerField extends StatelessWidget {
  const CustomerPickerField({
    super.key,
    required this.customers,
    required this.selectedId,
    required this.onSelected,
    this.enabled = true,
  });

  final List<CustomerInfo> customers;
  final int? selectedId;
  final ValueChanged<int> onSelected;
  final bool enabled;

  CustomerInfo? get _selected {
    for (final c in customers) {
      if (c.id == selectedId) return c;
    }
    return null;
  }

  static Future<void> show(
    BuildContext context, {
    required List<CustomerInfo> customers,
    required int? selectedId,
    required ValueChanged<int> onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CustomerPickerSheet(
        customers: customers,
        selectedId: selectedId,
        onSelected: onSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = _selected?.name ?? 'Select customer';

    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Customer',
        isDense: true,
        suffixIcon: Icon(Icons.arrow_drop_down),
      ),
      child: InkWell(
        onTap: enabled
            ? () => show(
                  context,
                  customers: customers,
                  selectedId: selectedId,
                  onSelected: onSelected,
                )
            : null,
        child: Text(
          label,
          style: enabled
              ? null
              : TextStyle(color: Theme.of(context).disabledColor),
        ),
      ),
    );
  }
}

class _CustomerPickerSheet extends StatefulWidget {
  const _CustomerPickerSheet({
    required this.customers,
    required this.selectedId,
    required this.onSelected,
  });

  final List<CustomerInfo> customers;
  final int? selectedId;
  final ValueChanged<int> onSelected;

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.customers.where((c) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return c.name.toLowerCase().contains(q) ||
          '${c.id}'.contains(q);
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
                  hintText: 'Search customers...',
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
                    final customer = filtered[index];
                    final selected = customer.id == widget.selectedId;
                    return ListTile(
                      title: Text(customer.name),
                      subtitle: Text('#${customer.id}'),
                      trailing: selected
                          ? const Icon(Icons.check, color: AppColors.primaryGreen)
                          : null,
                      onTap: () {
                        widget.onSelected(customer.id);
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
    this.requirePrice = false,
  });

  final List<TransactionLine> lines;
  final void Function(int index, double quantity) onQuantityChanged;
  final void Function(int index) onRemove;
  final void Function(int index, double price)? onUnitPriceChanged;
  final bool showDiscount;
  final bool allowNegativeQuantity;

  /// When true, lines with a zero price show an inline "Enter price" error.
  final bool requirePrice;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    if (lines.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            children: [
              Icon(
                Icons.shopping_basket_outlined,
                size: 34,
                color: muted.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 10),
              Text(
                'No items yet',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                'Items you add will appear here',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: muted,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    // Keys are stockId + occurrence count so field state stays attached to
    // the right line when lines are added/removed (duplicates are possible
    // on the adjustment screen).
    final seen = <String, int>{};
    String keyFor(String stockId) {
      final n = seen.update(stockId, (v) => v + 1, ifAbsent: () => 0);
      return '$stockId#$n';
    }

    return Column(
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          _LineCard(
            key: ValueKey(keyFor(lines[i].stockId)),
            line: lines[i],
            showDiscount: showDiscount,
            allowNegativeQuantity: allowNegativeQuantity,
            requirePrice: requirePrice,
            onQuantityChanged: (q) => onQuantityChanged(i, q),
            onUnitPriceChanged:
                onUnitPriceChanged == null ? null : (p) => onUnitPriceChanged!(i, p),
            onRemove: () => onRemove(i),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    super.key,
    required this.line,
    required this.onQuantityChanged,
    required this.onRemove,
    this.onUnitPriceChanged,
    required this.showDiscount,
    required this.allowNegativeQuantity,
    this.requirePrice = false,
  });

  final TransactionLine line;
  final ValueChanged<double> onQuantityChanged;
  final ValueChanged<double>? onUnitPriceChanged;
  final VoidCallback onRemove;
  final bool showDiscount;
  final bool allowNegativeQuantity;
  final bool requirePrice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ItemBadge(description: line.description),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.description,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _SkuPill(stockId: line.stockId),
                          if (line.units.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              line.units,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Remove',
                  icon: Icon(Icons.close, size: 18, color: muted),
                ),
              ],
            ),
            if (line.exceedsQoh)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.honey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.honey,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Only ${line.qoh!.toStringAsFixed(0)} in stock',
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
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                _QtyStepper(
                  value: line.quantity,
                  allowNegative: allowNegativeQuantity,
                  onChanged: onQuantityChanged,
                ),
                const SizedBox(width: 10),
                if (onUnitPriceChanged != null)
                  Expanded(
                    flex: 5,
                    child: _PriceField(
                      price: line.unitPrice,
                      showRequiredError: requirePrice && line.unitPrice <= 0,
                      onChanged: onUnitPriceChanged!,
                    ),
                  ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        formatMoney(line.lineTotal),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
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

class _ItemBadge extends StatelessWidget {
  const _ItemBadge({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trimmed = description.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();

    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: scheme.primary,
        ),
      ),
    );
  }
}

class _SkuPill extends StatelessWidget {
  const _SkuPill({required this.stockId});

  final String stockId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        stockId,
        style: AppTheme.mono(size: 11, color: scheme.onSurfaceVariant),
      ),
    );
  }
}

/// Quantity stepper with a directly editable value.
///
/// The value commits when editing completes (done / focus loss), so a
/// partially typed "0" never removes the line mid-edit.
class _QtyStepper extends StatefulWidget {
  const _QtyStepper({
    required this.value,
    required this.onChanged,
    required this.allowNegative,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final bool allowNegative;

  @override
  State<_QtyStepper> createState() => _QtyStepperState();
}

class _QtyStepperState extends State<_QtyStepper> {
  late final TextEditingController _controller =
      TextEditingController(text: _format(widget.value));
  final FocusNode _focusNode = FocusNode();
  var _selectAllOnTap = false;

  static String _format(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _selectAll() {
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  void _handleTap() {
    if (_selectAllOnTap) {
      _selectAllOnTap = false;
      _selectAll();
    }
  }

  @override
  void didUpdateWidget(covariant _QtyStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && oldWidget.value != widget.value) {
      _controller.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _selectAllOnTap = true;
      _selectAll();
    } else {
      _selectAllOnTap = false;
      _commit();
    }
  }

  void _commit() {
    final parsed = double.tryParse(_controller.text);
    if (parsed == null || (parsed == 0 && !widget.allowNegative)) {
      _controller.text = _format(widget.value);
      return;
    }
    _controller.text = _format(parsed);
    if (parsed != widget.value) widget.onChanged(parsed);
  }

  void _step(int delta) {
    final base = double.tryParse(_controller.text) ?? widget.value;
    final next = base + delta;
    if (next == 0 && !widget.allowNegative) return;
    _controller.text = _format(next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(icon: Icons.remove, onTap: () => _step(-1)),
          SizedBox(
            width: 44,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.numberWithOptions(
                decimal: true,
                signed: widget.allowNegative,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(widget.allowNegative ? r'[\d.\-]' : r'[\d.]'),
                ),
              ],
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              onTap: _handleTap,
              onEditingComplete: _focusNode.unfocus,
            ),
          ),
          _StepButton(icon: Icons.add, onTap: () => _step(1)),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Price input that keeps its own text state while focused, so typing is
/// never interrupted by rebuilds. Selects all on tap; reformats to two
/// decimals (or reverts, if invalid) when focus leaves.
class _PriceField extends StatefulWidget {
  const _PriceField({
    required this.price,
    required this.onChanged,
    this.showRequiredError = false,
  });

  final double price;
  final ValueChanged<double> onChanged;
  final bool showRequiredError;

  @override
  State<_PriceField> createState() => _PriceFieldState();
}

class _PriceFieldState extends State<_PriceField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.price.toStringAsFixed(2));
  final FocusNode _focusNode = FocusNode();
  var _selectAllOnTap = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _selectAll() {
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  void _handleTap() {
    if (_selectAllOnTap) {
      _selectAllOnTap = false;
      _selectAll();
    }
  }

  @override
  void didUpdateWidget(covariant _PriceField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && oldWidget.price != widget.price) {
      _controller.text = widget.price.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _selectAllOnTap = true;
      _selectAll();
    } else {
      _selectAllOnTap = false;
      final parsed = double.tryParse(_controller.text);
      _controller.text = (parsed ?? widget.price).toStringAsFixed(2);
      if (parsed != null && parsed != widget.price) {
        widget.onChanged(parsed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
      ],
      decoration: InputDecoration(
        labelText: 'Price',
        prefixText: 'KES ',
        isDense: true,
        errorText: widget.showRequiredError ? 'Enter price' : null,
        errorStyle: const TextStyle(fontSize: 10, height: 0.9),
      ),
      onTap: _handleTap,
      onChanged: (v) {
        final parsed = double.tryParse(v);
        if (parsed != null) widget.onChanged(parsed);
      },
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
    this.totalLabel = 'Total',
    this.totalText,
  });

  final double total;
  final VoidCallback? onSubmit;
  final String submitLabel;
  final bool submitting;
  final bool enabled;

  /// Label above the amount (e.g. "Units changed" on adjustments).
  final String totalLabel;

  /// Overrides the money-formatted [total] (e.g. a plain unit count).
  final String? totalText;

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
                    totalLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  Text(
                    totalText ?? formatMoney(total),
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
