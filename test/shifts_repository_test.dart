import 'package:avogs/features/shifts/shifts_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CheckinPrefill parses MOBILE_APP_GUIDE response shape', () {
    final prefill = CheckinPrefill.fromJson({
      'store': 'DEF',
      'shift': 'morning',
      'cash': {'expected_till': 2000, 'expected_float': 500},
      'stock_items': [
        {
          'stock_id': 'AVO-RT-S1',
          'description': 'Avocado Retail S1',
          'expected_qty': 12,
        },
      ],
      'photo_slots': [
        {'key': 'shop_opening', 'label': 'Opening shop / taking over'},
      ],
    });

    expect(prefill.shift, 'morning');
    expect(prefill.cash.till, 2000);
    expect(prefill.cash.floatAmount, 500);
    expect(prefill.stockCounts, hasLength(1));
    expect(prefill.stockCounts.first.stockId, 'AVO-RT-S1');
    expect(prefill.stockCounts.first.name, 'Avocado Retail S1');
    expect(prefill.stockCounts.first.expectedQty, 12);
    expect(prefill.photoSlots.first.key, 'shop_opening');
  });
}
