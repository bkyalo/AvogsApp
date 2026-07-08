import 'package:avogs/core/api/api_client.dart';
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

final customersProvider = FutureProvider<List<CustomerInfo>>((ref) async {
  return ref.watch(masterDataRepositoryProvider).fetchCustomers();
});

final suppliersProvider = FutureProvider<List<SupplierInfo>>((ref) async {
  return ref.watch(masterDataRepositoryProvider).fetchSuppliers();
});

final paymentTermsProvider = FutureProvider<List<PaymentTermsOption>>((ref) async {
  return ref.watch(masterDataRepositoryProvider).fetchPaymentTerms();
});

class MasterDataSyncNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> refreshCustomersAndSuppliers() async {
    ref.invalidate(customersProvider);
    ref.invalidate(suppliersProvider);
    await Future.wait([
      ref.read(customersProvider.future),
      ref.read(suppliersProvider.future),
    ]);
  }
}

final masterDataSyncProvider =
    NotifierProvider<MasterDataSyncNotifier, void>(MasterDataSyncNotifier.new);
