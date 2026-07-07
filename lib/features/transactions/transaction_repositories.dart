import 'package:avogs/core/api/api_client.dart';
import 'package:avogs/core/api/api_exception.dart';
import 'package:avogs/shared/models/transaction_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepository(ref.watch(apiClientProvider));
});

class SalesPrefill {
  const SalesPrefill({
    required this.defaults,
    required this.catalog,
  });

  factory SalesPrefill.fromJson(Map<String, dynamic> json) {
    return SalesPrefill(
      defaults: SalesDefaults.fromJson(json['defaults'] as Map<String, dynamic>),
      catalog: (json['catalog'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(CatalogItem.fromJson)
          .toList(),
    );
  }

  final SalesDefaults defaults;
  final List<CatalogItem> catalog;
}

class SalesDefaults {
  const SalesDefaults({
    required this.customerId,
    required this.branchId,
    required this.location,
    required this.documentDate,
    required this.reference,
    required this.currency,
    this.dueDate,
    this.deliverTo,
  });

  factory SalesDefaults.fromJson(Map<String, dynamic> json) {
    return SalesDefaults(
      customerId: json['customer_id'] as int,
      branchId: json['branch_id'] as int,
      location: json['location'] as String,
      documentDate: json['document_date'] as String,
      reference: json['reference'] as String,
      currency: json['currency'] as String? ?? 'KES',
      dueDate: json['due_date'] as String?,
      deliverTo: json['deliver_to'] as String?,
    );
  }

  final int customerId;
  final int branchId;
  final String location;
  final String documentDate;
  final String reference;
  final String currency;
  final String? dueDate;
  final String? deliverTo;
}

class SalesRepository {
  SalesRepository(this._api);

  final ApiClient _api;

  Future<SalesPrefill> fetchPrefill({
    required int customerId,
    required String location,
  }) async {
    final data = await _api.getJson(
      '/sales/invoices/prefill',
      queryParameters: {
        'customer_id': customerId,
        'location': location,
      },
    );
    return SalesPrefill.fromJson(data);
  }

  Future<Map<String, dynamic>> fetchInvoice(int id) async {
    return _api.getJson('/sales/invoices/$id');
  }
}

class PaymentPrefill {
  const PaymentPrefill({
    required this.defaults,
    required this.openDocuments,
    required this.bankAccounts,
  });

  factory PaymentPrefill.fromJson(Map<String, dynamic> json) {
    return PaymentPrefill(
      defaults: PaymentDefaults.fromJson(json['defaults'] as Map<String, dynamic>),
      openDocuments: (json['open_documents'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(OpenDocument.fromJson)
          .toList(),
      bankAccounts: (json['bank_accounts'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(BankAccount.fromJson)
          .toList(),
    );
  }

  final PaymentDefaults defaults;
  final List<OpenDocument> openDocuments;
  final List<BankAccount> bankAccounts;
}

class PaymentDefaults {
  const PaymentDefaults({
    required this.customerId,
    required this.branchId,
    required this.currency,
    required this.documentDate,
    required this.reference,
    required this.bankAccount,
  });

  factory PaymentDefaults.fromJson(Map<String, dynamic> json) {
    return PaymentDefaults(
      customerId: json['customer_id'] as int,
      branchId: json['branch_id'] as int,
      currency: json['currency'] as String? ?? 'KES',
      documentDate: json['document_date'] as String,
      reference: json['reference'] as String,
      bankAccount: json['bank_account'] as int,
    );
  }

  final int customerId;
  final int branchId;
  final String currency;
  final String documentDate;
  final String reference;
  final int bankAccount;
}

class PaymentRepository {
  PaymentRepository(this._api);

  final ApiClient _api;

  Future<PaymentPrefill> fetchPrefill({required int customerId}) async {
    final data = await _api.getJson(
      '/sales/payments/prefill',
      queryParameters: {'customer_id': customerId},
    );
    return PaymentPrefill.fromJson(data);
  }
}

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.watch(apiClientProvider));
});

class PurchasePrefill {
  const PurchasePrefill({
    required this.defaults,
    required this.catalog,
  });

  factory PurchasePrefill.fromJson(Map<String, dynamic> json) {
    return PurchasePrefill(
      defaults: PurchaseDefaults.fromJson(json['defaults'] as Map<String, dynamic>),
      catalog: (json['catalog'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(CatalogItem.fromJson)
          .toList(),
    );
  }

  final PurchaseDefaults defaults;
  final List<CatalogItem> catalog;
}

class PurchaseDefaults {
  const PurchaseDefaults({
    required this.supplierId,
    required this.supplierName,
    required this.location,
    required this.documentDate,
    required this.reference,
    required this.currency,
  });

  factory PurchaseDefaults.fromJson(Map<String, dynamic> json) {
    return PurchaseDefaults(
      supplierId: json['supplier_id'] as int,
      supplierName: json['supplier_name'] as String? ?? '',
      location: json['location'] as String,
      documentDate: json['document_date'] as String,
      reference: json['reference'] as String,
      currency: json['currency'] as String? ?? 'KES',
    );
  }

  final int supplierId;
  final String supplierName;
  final String location;
  final String documentDate;
  final String reference;
  final String currency;
}

class PurchaseRepository {
  PurchaseRepository(this._api);

  final ApiClient _api;

  Future<PurchasePrefill> fetchPrefill({
    required int supplierId,
    required String location,
  }) async {
    final data = await _api.getJson(
      '/purchasing/invoices/prefill',
      queryParameters: {
        'supplier_id': supplierId,
        'location': location,
      },
    );
    return PurchasePrefill.fromJson(data);
  }
}

final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) {
  return PurchaseRepository(ref.watch(apiClientProvider));
});

class AdjustmentPrefill {
  const AdjustmentPrefill({
    required this.defaults,
    required this.catalog,
  });

  factory AdjustmentPrefill.fromJson(Map<String, dynamic> json) {
    return AdjustmentPrefill(
      defaults: AdjustmentDefaults.fromJson(json['defaults'] as Map<String, dynamic>),
      catalog: (json['catalog'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(CatalogItem.fromJson)
          .toList(),
    );
  }

  final AdjustmentDefaults defaults;
  final List<CatalogItem> catalog;
}

class AdjustmentDefaults {
  const AdjustmentDefaults({
    required this.location,
    required this.documentDate,
    required this.reference,
  });

  factory AdjustmentDefaults.fromJson(Map<String, dynamic> json) {
    return AdjustmentDefaults(
      location: json['location'] as String,
      documentDate: json['document_date'] as String,
      reference: json['reference'] as String,
    );
  }

  final String location;
  final String documentDate;
  final String reference;
}

class AdjustmentRepository {
  AdjustmentRepository(this._api);

  final ApiClient _api;

  Future<AdjustmentPrefill> fetchPrefill({required String location}) async {
    final data = await _api.getJson(
      '/inventory/adjustments/prefill',
      queryParameters: {'location': location},
    );
    return AdjustmentPrefill.fromJson(data);
  }
}

final adjustmentRepositoryProvider = Provider<AdjustmentRepository>((ref) {
  return AdjustmentRepository(ref.watch(apiClientProvider));
});
