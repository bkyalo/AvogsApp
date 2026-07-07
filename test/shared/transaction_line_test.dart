import 'package:avogs/shared/models/transaction_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lineTotal applies discount', () {
    const line = TransactionLine(
      stockId: 'AVO-RT-S1',
      description: 'Avocado',
      quantity: 2,
      unitPrice: 100,
      discountPercent: 10,
    );
    expect(line.lineTotal, 180);
  });

  test('exceedsQoh when quantity above stock', () {
    const line = TransactionLine(
      stockId: 'AVO-RT-S1',
      description: 'Avocado',
      quantity: 5,
      unitPrice: 75,
      qoh: 3,
    );
    expect(line.exceedsQoh, isTrue);
  });

  test('sales json includes required fields', () {
    const line = TransactionLine(
      stockId: 'AVO-RT-S1',
      description: 'Avocado',
      quantity: 2,
      unitPrice: 75,
    );
    expect(line.toSalesJson(), {
      'stock_id': 'AVO-RT-S1',
      'quantity': 2,
      'unit_price': 75,
      'discount_percent': 0,
    });
  });
}
