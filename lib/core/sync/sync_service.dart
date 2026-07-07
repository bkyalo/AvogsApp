import 'dart:convert';

import 'package:avogs/core/api/api_client.dart';
import 'package:avogs/core/database/app_database.dart';
import 'package:avogs/shared/models/transaction_models.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

enum SyncItemType {
  salesInvoice,
  salesPayment,
  supplierInvoice,
  inventoryAdjustment,
}

extension SyncItemTypeX on SyncItemType {
  String get apiPath => switch (this) {
        SyncItemType.salesInvoice => '/sales/invoices',
        SyncItemType.salesPayment => '/sales/payments',
        SyncItemType.supplierInvoice => '/purchasing/invoices',
        SyncItemType.inventoryAdjustment => '/inventory/adjustments',
      };

  String get value => name;
}

class SyncState {
  const SyncState({
    this.pendingCount = 0,
    this.isSyncing = false,
    this.isOnline = true,
    this.lastError,
  });

  final int pendingCount;
  final bool isSyncing;
  final bool isOnline;
  final String? lastError;

  SyncState copyWith({
    int? pendingCount,
    bool? isSyncing,
    bool? isOnline,
    String? lastError,
    bool clearError = false,
  }) {
    return SyncState(
      pendingCount: pendingCount ?? this.pendingCount,
      isSyncing: isSyncing ?? this.isSyncing,
      isOnline: isOnline ?? this.isOnline,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final syncServiceProvider =
    StateNotifierProvider<SyncService, SyncState>((ref) {
  return SyncService(
    db: ref.watch(appDatabaseProvider),
    api: ref.watch(apiClientProvider),
    connectivity: Connectivity(),
  );
});

class SyncService extends StateNotifier<SyncState> {
  SyncService({
    required AppDatabase db,
    required ApiClient api,
    required Connectivity connectivity,
  })  : _db = db,
        _api = api,
        _connectivity = connectivity,
        super(const SyncState()) {
    _init();
  }

  final AppDatabase _db;
  final ApiClient _api;
  final Connectivity _connectivity;
  final _uuid = const Uuid();

  Future<void> _init() async {
    await refreshPendingCount();
    _connectivity.onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      state = state.copyWith(isOnline: online);
      if (online) {
        syncPending();
      }
    });
    final current = await _connectivity.checkConnectivity();
    state = state.copyWith(
      isOnline: current.any((r) => r != ConnectivityResult.none),
    );
  }

  Future<void> refreshPendingCount() async {
    final count = await _db.pendingSyncCount();
    state = state.copyWith(pendingCount: count);
  }

  Future<void> recordCompleted({
    required SyncItemType type,
    required String payloadJson,
    int? serverId,
  }) async {
    final id = _uuid.v4();
    final clientRef = _uuid.v4();
    await _db.enqueueSyncItem(
      SyncQueueItemsCompanion.insert(
        id: id,
        type: type.value,
        payloadJson: payloadJson,
        status: 'synced',
        clientRef: clientRef,
        createdAt: DateTime.now(),
        serverId: Value(serverId),
      ),
    );
    await refreshPendingCount();
  }

  Future<String> enqueue({
    required SyncItemType type,
    required String payloadJson,
  }) async {
    final id = _uuid.v4();
    final clientRef = _uuid.v4();
    await _db.enqueueSyncItem(
      SyncQueueItemsCompanion.insert(
        id: id,
        type: type.value,
        payloadJson: payloadJson,
        status: 'pending',
        clientRef: clientRef,
        createdAt: DateTime.now(),
      ),
    );
    await refreshPendingCount();
    if (state.isOnline) {
      await syncPending();
    }
    return id;
  }

  Future<void> syncPending() async {
    if (state.isSyncing || !state.isOnline) return;
    state = state.copyWith(isSyncing: true, clearError: true);
    try {
      final items = await _db.pendingSyncItems();
      for (final item in items) {
        await _db.updateSyncStatus(item.id, status: 'syncing');
        try {
          final type = SyncItemType.values.firstWhere(
            (t) => t.value == item.type,
          );
          final body = Map<String, dynamic>.from(
            jsonDecode(item.payloadJson) as Map,
          )..['client_ref'] = item.clientRef;
          final response = await _api.postJson(type.apiPath, body: body);
          final serverId = extractTransactionServerId(response);
          await _db.updateSyncStatus(
            item.id,
            status: 'synced',
            serverId: serverId,
          );
        } catch (e) {
          await _db.updateSyncStatus(
            item.id,
            status: 'failed',
            errorMessage: '$e',
            retryCount: item.retryCount + 1,
          );
          state = state.copyWith(lastError: '$e');
        }
      }
    } finally {
      await refreshPendingCount();
      state = state.copyWith(isSyncing: false);
    }
  }
}
