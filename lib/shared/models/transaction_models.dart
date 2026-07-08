enum PaymentMethod { cash, mpesa }

extension PaymentMethodX on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.cash => 'Cash',
        PaymentMethod.mpesa => 'M-Pesa',
      };
}

/// Whether a direct sale is settled immediately or posted to AR.
enum SaleTiming { payNow, payLater }

extension SaleTimingX on SaleTiming {
  String get label => switch (this) {
        SaleTiming.payNow => 'Pay now',
        SaleTiming.payLater => 'Pay later',
      };
}

class PaymentTermsOption {
  const PaymentTermsOption({
    required this.id,
    required this.name,
    required this.daysDue,
    required this.cashSale,
    required this.onCredit,
  });

  factory PaymentTermsOption.fromJson(Map<String, dynamic> json) {
    return PaymentTermsOption(
      id: json['id'] as int,
      name: json['name'] as String,
      daysDue: json['days_due'] as int? ?? 0,
      cashSale: json['cash_sale'] as bool? ?? false,
      onCredit: json['on_credit'] as bool? ?? false,
    );
  }

  final int id;
  final String name;
  final int daysDue;
  final bool cashSale;
  final bool onCredit;
}

/// Picks a bank account id that best matches Cash vs M-Pesa from prefill.
int? bankAccountForPaymentMethod(
  PaymentMethod method,
  List<BankAccount> accounts,
) {
  if (accounts.isEmpty) return null;
  final pattern = method == PaymentMethod.cash
      ? RegExp(r'cash', caseSensitive: false)
      : RegExp(r'm\s*-?\s*pesa', caseSensitive: false);
  for (final account in accounts) {
    if (pattern.hasMatch(account.name)) return account.id;
  }
  return accounts.first.id;
}

class TransactionLine {
  const TransactionLine({
    required this.stockId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.discountPercent = 0,
    this.qoh,
    this.units = '',
    this.standardCost,
  });

  final String stockId;
  final String description;
  final double quantity;
  final double unitPrice;
  final double discountPercent;
  final double? qoh;
  final String units;
  final double? standardCost;

  double get lineTotal =>
      quantity * unitPrice * (1 - discountPercent / 100);

  bool get exceedsQoh => qoh != null && quantity > qoh!;

  TransactionLine copyWith({
    String? stockId,
    String? description,
    double? quantity,
    double? unitPrice,
    double? discountPercent,
    double? qoh,
    String? units,
    double? standardCost,
  }) {
    return TransactionLine(
      stockId: stockId ?? this.stockId,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discountPercent: discountPercent ?? this.discountPercent,
      qoh: qoh ?? this.qoh,
      units: units ?? this.units,
      standardCost: standardCost ?? this.standardCost,
    );
  }

  Map<String, dynamic> toSalesJson() => {
        'stock_id': stockId,
        'quantity': quantity,
        'unit_price': unitPrice,
        'discount_percent': discountPercent,
      };

  Map<String, dynamic> toPurchaseJson() => {
        'stock_id': stockId,
        'quantity': quantity,
        'unit_price': unitPrice,
      };

  Map<String, dynamic> toAdjustmentJson() => {
        'stock_id': stockId,
        'quantity': quantity,
        if (standardCost != null) 'standard_cost': standardCost,
      };
}

class CatalogItem {
  const CatalogItem({
    required this.stockId,
    required this.description,
    this.units = '',
    this.unitPrice,
    this.supplierPrice,
    this.qoh,
    this.materialCost,
    this.isKit = false,
  });

  factory CatalogItem.fromJson(Map<String, dynamic> json) {
    return CatalogItem(
      stockId: json['stock_id'] as String,
      description: json['description'] as String? ?? json['stock_id'] as String,
      units: json['units'] as String? ?? '',
      unitPrice: _toDouble(json['unit_price']),
      supplierPrice: _toDouble(json['supplier_price']),
      qoh: _toDouble(json['qoh'] ?? json['qoh_at_location']),
      materialCost: _toDouble(json['material_cost']),
      isKit: json['is_kit'] as bool? ?? false,
    );
  }

  final String stockId;
  final String description;
  final String units;
  final double? unitPrice;
  final double? supplierPrice;
  final double? qoh;
  final double? materialCost;
  final bool isKit;

  TransactionLine toSalesLine({double quantity = 1}) {
    return TransactionLine(
      stockId: stockId,
      description: description,
      quantity: quantity,
      unitPrice: unitPrice ?? 0,
      qoh: qoh,
      units: units,
    );
  }

  TransactionLine toPurchaseLine({double quantity = 1}) {
    return TransactionLine(
      stockId: stockId,
      description: description,
      quantity: quantity,
      unitPrice: supplierPrice ?? 0,
      qoh: qoh,
      units: units,
    );
  }

  TransactionLine toAdjustmentLine({double quantity = -1}) {
    return TransactionLine(
      stockId: stockId,
      description: description,
      quantity: quantity,
      unitPrice: materialCost ?? 0,
      qoh: qoh,
      units: units,
      standardCost: materialCost,
    );
  }
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

class StoreInfo {
  const StoreInfo({required this.code, required this.name});

  factory StoreInfo.fromJson(Map<String, dynamic> json) {
    return StoreInfo(
      code: json['code'] as String? ?? json['loc_code'] as String? ?? '',
      name: json['name'] as String? ?? json['location_name'] as String? ?? '',
    );
  }

  final String code;
  final String name;
}

class CustomerInfo {
  const CustomerInfo({
    required this.id,
    required this.name,
    this.salesTypeId,
  });

  factory CustomerInfo.fromJson(Map<String, dynamic> json) {
    return CustomerInfo(
      id: json['id'] as int? ?? json['debtor_no'] as int,
      name: json['name'] as String? ?? json['debtor_ref'] as String? ?? '',
      salesTypeId: json['sales_type_id'] as int?,
    );
  }

  final int id;
  final String name;
  final int? salesTypeId;
}

extension CustomerListX on List<CustomerInfo> {
  /// Prefer the walk-in customer used for counter sales.
  int get cashSalesCustomerId {
    final normalized = map(
      (c) => (customer: c, name: c.name.trim().toUpperCase()),
    );
    final exact = normalized.where((e) => e.name == 'CASH SALES');
    if (exact.isNotEmpty) return exact.first.customer.id;
    final partial = normalized.where((e) => e.name.contains('CASH SALES'));
    if (partial.isNotEmpty) return partial.first.customer.id;
    return isNotEmpty ? first.id : 1;
  }
}

class SupplierInfo {
  const SupplierInfo({required this.id, required this.name});

  factory SupplierInfo.fromJson(Map<String, dynamic> json) {
    return SupplierInfo(
      id: json['id'] as int? ?? json['supplier_id'] as int,
      name: json['name'] as String? ?? json['supp_name'] as String? ?? '',
    );
  }

  final int id;
  final String name;
}

class BankAccount {
  const BankAccount({
    required this.id,
    required this.name,
    required this.currency,
  });

  factory BankAccount.fromJson(Map<String, dynamic> json) {
    return BankAccount(
      id: json['id'] as int,
      name: json['name'] as String,
      currency: json['currency'] as String? ?? 'KES',
    );
  }

  final int id;
  final String name;
  final String currency;
}

class OpenDocument {
  const OpenDocument({
    required this.transType,
    required this.transNo,
    required this.reference,
    required this.documentDate,
    required this.amount,
    required this.allocated,
    required this.balance,
    this.dueDate,
  });

  factory OpenDocument.fromJson(Map<String, dynamic> json) {
    return OpenDocument(
      transType: json['trans_type'] as int,
      transNo: json['trans_no'] as int,
      reference: json['reference'] as String,
      documentDate: json['document_date'] as String,
      amount: (json['amount'] as num).toDouble(),
      allocated: (json['allocated'] as num).toDouble(),
      balance: (json['balance'] as num).toDouble(),
      dueDate: json['due_date'] as String?,
    );
  }

  final int transType;
  final int transNo;
  final String reference;
  final String documentDate;
  final double amount;
  final double allocated;
  final double balance;
  final String? dueDate;
}

class PendingInvoicesResponse {
  const PendingInvoicesResponse({
    required this.customerId,
    required this.pendingInvoices,
    required this.invoiceCount,
    required this.totalOutstanding,
  });

  factory PendingInvoicesResponse.fromJson(Map<String, dynamic> json) {
    return PendingInvoicesResponse(
      customerId: json['customer_id'] as int,
      pendingInvoices: (json['pending_invoices'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(OpenDocument.fromJson)
          .toList(),
      invoiceCount: json['invoice_count'] as int? ?? 0,
      totalOutstanding: (json['total_outstanding'] as num?)?.toDouble() ?? 0,
    );
  }

  final int customerId;
  final List<OpenDocument> pendingInvoices;
  final int invoiceCount;
  final double totalOutstanding;
}

class PaymentAllocationDetail {
  const PaymentAllocationDetail({
    required this.transType,
    required this.transNo,
    required this.allocated,
    this.reference,
    this.date,
  });

  factory PaymentAllocationDetail.fromJson(Map<String, dynamic> json) {
    return PaymentAllocationDetail(
      transType: json['trans_type'] as int? ?? 10,
      transNo: json['trans_no'] as int? ?? 0,
      allocated: (json['allocated'] as num?)?.toDouble() ??
          (json['amount'] as num?)?.toDouble() ??
          0,
      reference: json['reference'] as String?,
      date: json['date'] as String? ?? json['document_date'] as String?,
    );
  }

  final int transType;
  final int transNo;
  final double allocated;
  final String? reference;
  final String? date;
}

class PaymentDetail {
  const PaymentDetail({
    required this.paymentNo,
    required this.reference,
    required this.amount,
    this.documentDate,
    this.memo,
    this.customerId,
    this.currency,
    this.discount,
    this.allocations = const [],
  });

  factory PaymentDetail.fromJson(Map<String, dynamic> json) {
    return PaymentDetail(
      paymentNo: json['payment_no'] as int? ?? json['trans_no'] as int? ?? 0,
      reference: json['reference'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      documentDate: json['document_date'] as String?,
      memo: json['memo'] as String?,
      customerId: json['customer_id'] as int?,
      currency: json['currency'] as String?,
      discount: (json['discount'] as num?)?.toDouble(),
      allocations: (json['allocations'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PaymentAllocationDetail.fromJson)
          .toList(),
    );
  }

  final int paymentNo;
  final String reference;
  final double amount;
  final String? documentDate;
  final String? memo;
  final int? customerId;
  final String? currency;
  final double? discount;
  final List<PaymentAllocationDetail> allocations;
}

class SubmitResult {
  const SubmitResult({
    this.serverId,
    this.reference,
    this.total,
    this.queuedOffline = false,
    this.queueId,
    this.response,
  });

  factory SubmitResult.fromOnlineResponse(Map<String, dynamic> response) {
    return SubmitResult(
      serverId: extractTransactionServerId(response),
      reference: response['reference'] as String?,
      total: (response['total'] as num?)?.toDouble(),
      response: response,
    );
  }

  final int? serverId;
  final String? reference;
  final double? total;
  final bool queuedOffline;
  final String? queueId;
  final Map<String, dynamic>? response;

  bool get isSuccess {
    if (queuedOffline || serverId != null) return true;
    if (reference != null && reference!.isNotEmpty) return true;
    final resp = response;
    if (resp != null && resp['success'] == true) return true;
    return false;
  }
}

/// Reads a server-side transaction id from common API response shapes.
int? extractTransactionServerId(Map<String, dynamic> response) {
  for (final key in [
    'invoice_no',
    'payment_no',
    'trans_no',
    'adjustment_no',
    'id',
  ]) {
    final value = response[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
  }

  final nested = response['data'];
  if (nested is Map<String, dynamic>) {
    return extractTransactionServerId(nested);
  }
  return null;
}

class TransactionSuccessDetails {
  const TransactionSuccessDetails({
    required this.title,
    required this.reference,
    this.subtitle,
    this.total,
    this.totalLabel = 'Total',
    this.detailLines = const [],
    this.queuedOffline = false,
  });

  final String title;
  final String reference;
  final String? subtitle;
  final double? total;
  final String totalLabel;
  final List<String> detailLines;
  final bool queuedOffline;
}
