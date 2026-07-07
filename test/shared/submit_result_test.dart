import 'package:avogs/shared/models/transaction_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SubmitResult.isSuccess', () {
    test('succeeds with adjustment_no only', () {
      final result = SubmitResult.fromOnlineResponse({
        'adjustment_no': 42,
        'reference': 'ADJ/2026/001',
      });
      expect(result.isSuccess, isTrue);
      expect(result.serverId, 42);
    });

    test('succeeds with reference only', () {
      final result = SubmitResult.fromOnlineResponse({
        'reference': 'ADJ/2026/001',
      });
      expect(result.isSuccess, isTrue);
    });

    test('succeeds when queued offline', () {
      const result = SubmitResult(
        queuedOffline: true,
        reference: 'ADJ/2026/001',
      );
      expect(result.isSuccess, isTrue);
    });

    test('fails on empty online response', () {
      final result = SubmitResult.fromOnlineResponse({});
      expect(result.isSuccess, isFalse);
    });
  });
}
