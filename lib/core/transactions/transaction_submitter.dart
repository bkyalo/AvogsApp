import 'dart:convert';

import 'package:avogs/core/api/api_client.dart';
import 'package:avogs/core/sync/sync_service.dart';
import 'package:avogs/shared/models/transaction_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final transactionSubmitterProvider = Provider<TransactionSubmitter>((ref) {
  return TransactionSubmitter(
    api: ref.watch(apiClientProvider),
    sync: ref.watch(syncServiceProvider.notifier),
    isOnline: () => ref.read(syncServiceProvider).isOnline,
  );
});

class TransactionSubmitter {
  TransactionSubmitter({
    required ApiClient api,
    required SyncService sync,
    required bool Function() isOnline,
  })  : _api = api,
        _sync = sync,
        _isOnline = isOnline;

  final ApiClient _api;
  final SyncService _sync;
  final bool Function() _isOnline;

  Future<SubmitResult> submit({
    required SyncItemType type,
    required Map<String, dynamic> payload,
  }) async {
    if (_isOnline()) {
      final response = await _api.postJson(type.apiPath, body: payload);
      final result = SubmitResult.fromOnlineResponse(response);
      await _sync.recordCompleted(
        type: type,
        payloadJson: jsonEncode(payload),
        serverId: result.serverId,
      );
      return result;
    }

    final queueId = await _sync.enqueue(
      type: type,
      payloadJson: jsonEncode(payload),
    );
    return SubmitResult(
      queuedOffline: true,
      queueId: queueId,
      reference: payload['reference'] as String?,
    );
  }
}
