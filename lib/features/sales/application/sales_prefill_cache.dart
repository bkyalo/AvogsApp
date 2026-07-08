import 'dart:convert';

import 'package:avogs/core/database/app_database.dart';
import 'package:avogs/core/sync/sync_service.dart';
import 'package:avogs/features/transactions/transaction_repositories.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final salesPrefillCacheProvider = Provider<SalesPrefillCache>((ref) {
  return SalesPrefillCache(
    db: ref.watch(appDatabaseProvider),
    salesRepo: ref.watch(salesRepositoryProvider),
    isOnline: () => ref.read(syncServiceProvider).isOnline,
  );
});

class SalesPrefillCache {
  SalesPrefillCache({
    required AppDatabase db,
    required SalesRepository salesRepo,
    required bool Function() isOnline,
  })  : _db = db,
        _salesRepo = salesRepo,
        _isOnline = isOnline;

  final AppDatabase _db;
  final SalesRepository _salesRepo;
  final bool Function() _isOnline;

  Future<SalesPrefill?> load({
    required int customerId,
    required String location,
  }) {
    return _db.loadCachedSalesPrefill(
      customerId: customerId,
      location: location,
    );
  }

  Future<void> save({
    required int customerId,
    required String location,
    required SalesPrefill prefill,
  }) {
    return _db.saveCachedSalesPrefill(
      customerId: customerId,
      location: location,
      prefillJson: jsonEncode(_prefillToJson(prefill)),
    );
  }

  /// Fetch from API when online and persist for offline POS.
  Future<SalesPrefill?> fetchAndCache({
    required int customerId,
    required String location,
  }) async {
    if (!_isOnline()) return load(customerId: customerId, location: location);
    try {
      final prefill = await _salesRepo.fetchPrefill(
        customerId: customerId,
        location: location,
      );
      await save(
        customerId: customerId,
        location: location,
        prefill: prefill,
      );
      return prefill;
    } catch (_) {
      return load(customerId: customerId, location: location);
    }
  }

  /// Warm catalog cache for walk-in sales at the current store.
  Future<void> prefetchForStore({
    required String location,
    required int customerId,
  }) async {
    if (!_isOnline()) return;
    await fetchAndCache(customerId: customerId, location: location);
  }

  Map<String, dynamic> _prefillToJson(SalesPrefill prefill) {
    return {
      'defaults': {
        'customer_id': prefill.defaults.customerId,
        'branch_id': prefill.defaults.branchId,
        'location': prefill.defaults.location,
        'document_date': prefill.defaults.documentDate,
        'reference': prefill.defaults.reference,
        'currency': prefill.defaults.currency,
        if (prefill.defaults.dueDate != null)
          'due_date': prefill.defaults.dueDate,
        if (prefill.defaults.deliverTo != null)
          'deliver_to': prefill.defaults.deliverTo,
        'on_credit': prefill.defaults.onCredit,
      },
      'catalog': prefill.catalog
          .map(
            (item) => {
              'stock_id': item.stockId,
              'description': item.description,
              'units': item.units,
              'unit_price': item.unitPrice,
              'qoh': item.qoh,
              'is_kit': item.isKit,
            },
          )
          .toList(),
      if (prefill.paymentTermsOptions.isNotEmpty)
        'payment_terms_options': prefill.paymentTermsOptions
            .map(
              (t) => {
                'id': t.id,
                'name': t.name,
                'days_due': t.daysDue,
                'cash_sale': t.cashSale,
                'on_credit': t.onCredit,
              },
            )
            .toList(),
    };
  }
}

extension SalesPrefillCacheDb on AppDatabase {
  Future<SalesPrefill?> loadCachedSalesPrefill({
    required int customerId,
    required String location,
  }) async {
    final row = await (select(cachedSalesPrefills)
          ..where(
            (t) =>
                t.customerId.equals(customerId) & t.location.equals(location),
          ))
        .getSingleOrNull();
    if (row == null) return null;
    try {
      final json =
          Map<String, dynamic>.from(jsonDecode(row.prefillJson) as Map);
      return SalesPrefill.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCachedSalesPrefill({
    required int customerId,
    required String location,
    required String prefillJson,
  }) {
    return into(cachedSalesPrefills).insertOnConflictUpdate(
      CachedSalesPrefillsCompanion.insert(
        customerId: customerId,
        location: location,
        prefillJson: prefillJson,
        cachedAt: DateTime.now(),
      ),
    );
  }
}
