import 'package:drift/drift.dart';

class SyncQueueItems extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get payloadJson => text()();
  TextColumn get status => text()();
  TextColumn get clientRef => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get errorMessage => text().nullable()();
  IntColumn get serverId => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class CachedSalesPrefills extends Table {
  IntColumn get customerId => integer()();
  TextColumn get location => text()();
  TextColumn get prefillJson => text()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {customerId, location};
}

class CachedStores extends Table {
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get json => text()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {code};
}
