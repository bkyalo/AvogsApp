import 'package:avogs/core/database/connection/connection.dart';
import 'package:avogs/core/database/tables.dart';
import 'package:drift/drift.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [SyncQueueItems, CachedStores, CachedSalesPrefills])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? openDatabaseConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(cachedSalesPrefills);
          }
        },
      );

  Future<List<SyncQueueItem>> pendingSyncItems() {
    return (select(syncQueueItems)
          ..where((t) => t.status.equals('pending') | t.status.equals('failed'))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<List<SyncQueueItem>> allSyncItems() {
    return (select(syncQueueItems)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<int> pendingSyncCount() async {
    final count = countAll();
    final query = selectOnly(syncQueueItems)
      ..addColumns([count])
      ..where(
        syncQueueItems.status.equals('pending') |
            syncQueueItems.status.equals('failed'),
      );
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<void> enqueueSyncItem(SyncQueueItemsCompanion item) {
    return into(syncQueueItems).insert(item);
  }

  Future<void> updateSyncStatus(
    String id, {
    required String status,
    int? serverId,
    String? errorMessage,
    int? retryCount,
  }) {
    return (update(syncQueueItems)..where((t) => t.id.equals(id))).write(
      SyncQueueItemsCompanion(
        status: Value(status),
        serverId: serverId == null ? const Value.absent() : Value(serverId),
        errorMessage:
            errorMessage == null ? const Value.absent() : Value(errorMessage),
        retryCount:
            retryCount == null ? const Value.absent() : Value(retryCount),
      ),
    );
  }
}
