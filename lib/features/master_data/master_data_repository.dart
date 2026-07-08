import 'package:avogs/core/api/api_client.dart';
import 'package:avogs/core/config/app_config_provider.dart';
import 'package:avogs/features/sales/application/sales_prefill_cache.dart';
import 'package:avogs/shared/models/transaction_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final masterDataRepositoryProvider = Provider<MasterDataRepository>((ref) {
  return MasterDataRepository(ref.watch(apiClientProvider));
});

class MasterDataRepository {
  MasterDataRepository(this._api);

  final ApiClient _api;

  Future<List<StoreInfo>> fetchStores() async {
    final data = await _api.getJsonList('/stores');
    return data
        .whereType<Map<String, dynamic>>()
        .map(StoreInfo.fromJson)
        .where((s) => s.code.isNotEmpty)
        .toList();
  }

  Future<List<CustomerInfo>> fetchCustomers() async {
    final data = await _api.getJsonList('/customers');
    return data
        .whereType<Map<String, dynamic>>()
        .map(CustomerInfo.fromJson)
        .toList();
  }

  Future<List<SupplierInfo>> fetchSuppliers() async {
    final data = await _api.getJsonList('/suppliers');
    return data
        .whereType<Map<String, dynamic>>()
        .map(SupplierInfo.fromJson)
        .toList();
  }

  Future<List<String>> fetchPaymentMethodLabels() async {
    final data = await _api.getJsonList('/payment-methods');
    return data.map((e) {
      if (e is Map<String, dynamic>) {
        return e['name'] as String? ?? e['label'] as String? ?? '$e';
      }
      return '$e';
    }).toList();
  }

  Future<List<PaymentTermsOption>> fetchPaymentTerms() async {
    final data = await _api.getJsonList('/payment-terms');
    return data
        .whereType<Map<String, dynamic>>()
        .map(PaymentTermsOption.fromJson)
        .toList();
  }

  Future<CatalogItem> fetchItemContext({
    required String stockId,
    int? customerId,
    int? supplierId,
    required String location,
  }) async {
    final query = <String, dynamic>{'location': location};
    if (customerId != null) query['customer_id'] = customerId;
    if (supplierId != null) query['supplier_id'] = supplierId;

    final data = await _api.getJson('/items/$stockId/context', queryParameters: query);
    return CatalogItem.fromJson(data);
  }
}

final storesProvider = FutureProvider<List<StoreInfo>>((ref) async {
  return ref.watch(masterDataRepositoryProvider).fetchStores();
});

class CustomersNotifier extends AsyncNotifier<List<CustomerInfo>> {
  @override
  Future<List<CustomerInfo>> build() async {
    ref.keepAlive();
    return ref.read(masterDataRepositoryProvider).fetchCustomers();
  }

  Future<void> refresh() async {
    final previous = state.valueOrNull;
    if (previous == null) {
      state = const AsyncLoading();
    } else {
      state = AsyncData(previous);
    }
    state = await AsyncValue.guard(
      () => ref.read(masterDataRepositoryProvider).fetchCustomers(),
    );
  }
}

final customersProvider =
    AsyncNotifierProvider<CustomersNotifier, List<CustomerInfo>>(
  CustomersNotifier.new,
);

class SuppliersNotifier extends AsyncNotifier<List<SupplierInfo>> {
  @override
  Future<List<SupplierInfo>> build() async {
    ref.keepAlive();
    return ref.read(masterDataRepositoryProvider).fetchSuppliers();
  }

  Future<void> refresh() async {
    final previous = state.valueOrNull;
    if (previous == null) {
      state = const AsyncLoading();
    } else {
      state = AsyncData(previous);
    }
    state = await AsyncValue.guard(
      () => ref.read(masterDataRepositoryProvider).fetchSuppliers(),
    );
  }
}

final suppliersProvider =
    AsyncNotifierProvider<SuppliersNotifier, List<SupplierInfo>>(
  SuppliersNotifier.new,
);

final paymentTermsProvider = FutureProvider<List<PaymentTermsOption>>((ref) async {
  return ref.watch(masterDataRepositoryProvider).fetchPaymentTerms();
});

class MasterDataSyncNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> refreshCustomersAndSuppliers() async {
    await Future.wait([
      ref.read(customersProvider.notifier).refresh(),
      ref.read(suppliersProvider.notifier).refresh(),
    ]);
  }

  /// Reload master data and warm the POS catalog cache for offline sales.
  Future<void> refreshForHome() async {
    await refreshCustomersAndSuppliers();
    await ref.read(appConfigProvider.notifier).ready;
    final config = ref.read(appConfigProvider);
    final location = config.selectedStoreCode;
    if (location == null || location.isEmpty) return;

    try {
      final customers = await ref.read(customersProvider.future);
      await ref.read(salesPrefillCacheProvider).prefetchForStore(
            location: location,
            customerId: customers.cashSalesCustomerId,
          );
    } catch (_) {}
  }
}

final masterDataSyncProvider =
    NotifierProvider<MasterDataSyncNotifier, void>(MasterDataSyncNotifier.new);
