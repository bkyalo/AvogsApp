import 'package:avogs/shared/services/receipt_pdf_service.dart';

/// Builds a short item list for Activity tiles, e.g. "Avocado, Tomato +1 more".
String? formatItemSummary(
  Iterable<String> names, {
  int maxItems = 2,
}) {
  final items = names.map((n) => n.trim()).where((n) => n.isNotEmpty).toList();
  if (items.isEmpty) return null;
  if (items.length == 1) return items.first;
  if (items.length <= maxItems) return items.join(', ');
  return '${items.take(maxItems).join(', ')} +${items.length - maxItems} more';
}

String? itemSummaryFromPayload(Map<String, dynamic> payload) {
  final lines = payload['lines'] as List<dynamic>? ?? [];
  return formatItemSummary(
    lines.whereType<Map<String, dynamic>>().map(_lineDescription),
  );
}

List<ReceiptLine> salesReceiptLinesFromPayload(Map<String, dynamic> payload) {
  final lines = payload['lines'] as List<dynamic>? ?? [];
  return lines.whereType<Map<String, dynamic>>().map(_salesReceiptLine).toList();
}

List<AdjustmentReceiptLine> adjustmentLinesFromPayload(
  Map<String, dynamic> payload,
) {
  final lines = payload['lines'] as List<dynamic>? ?? [];
  return lines
      .whereType<Map<String, dynamic>>()
      .map(AdjustmentReceiptLine.fromJson)
      .toList();
}

List<ReceiptLine> salesReceiptLinesFromInvoice(Map<String, dynamic> invoice) {
  final lines = invoice['lines'] as List<dynamic>? ?? [];
  return lines.whereType<Map<String, dynamic>>().map((line) {
    final qty = _asDouble(line['quantity'] ?? line['qty']);
    final price = _asDouble(line['unit_price']);
    final discount = _asDouble(line['discount_percent'] ?? line['discount']);
    return ReceiptLine(
      description: _lineDescription(line),
      quantity: qty,
      unitPrice: price,
      total: qty * price * (1 - discount / 100),
    );
  }).toList();
}

ReceiptLine _salesReceiptLine(Map<String, dynamic> line) {
  final qty = _asDouble(line['quantity']);
  final price = _asDouble(line['unit_price']);
  final discount = _asDouble(line['discount_percent']);
  return ReceiptLine(
    description: _lineDescription(line),
    quantity: qty,
    unitPrice: price,
    total: qty * price * (1 - discount / 100),
  );
}

String _lineDescription(Map<String, dynamic> line) {
  final description = line['description'] as String?;
  if (description != null && description.trim().isNotEmpty) return description;
  final name = line['name'] as String?;
  if (name != null && name.trim().isNotEmpty) return name;
  final stockId = line['stock_id'] as String?;
  if (stockId != null && stockId.trim().isNotEmpty) return stockId;
  return 'Item';
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

class AdjustmentReceiptLine {
  const AdjustmentReceiptLine({
    required this.description,
    required this.quantity,
    this.standardCost,
  });

  factory AdjustmentReceiptLine.fromJson(Map<String, dynamic> json) {
    return AdjustmentReceiptLine(
      description: _lineDescription(json),
      quantity: _asDouble(json['quantity']),
      standardCost: json['standard_cost'] == null
          ? null
          : _asDouble(json['standard_cost']),
    );
  }

  final String description;
  final double quantity;
  final double? standardCost;

  String get quantityLabel {
    if (quantity > 0) return '+${quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 2)}';
    return quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 2);
  }
}
