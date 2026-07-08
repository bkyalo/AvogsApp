import 'package:avogs/core/api/api_exception.dart';
import 'package:avogs/core/config/app_config_provider.dart';
import 'package:avogs/core/sync/sync_service.dart';
import 'package:avogs/core/transactions/transaction_submitter.dart';
import 'package:avogs/features/history/application/history_provider.dart';
import 'package:avogs/features/master_data/master_data_repository.dart';
import 'package:avogs/features/reports/reports_repository.dart';
import 'package:avogs/features/sales/application/sales_prefill_cache.dart';
import 'package:avogs/features/transactions/transaction_repositories.dart';
import 'package:avogs/shared/models/transaction_models.dart';
import 'package:avogs/shared/services/receipt_pdf_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PosState {
  const PosState({
    this.loading = true,
    this.submitting = false,
    this.prefill,
    this.bankAccounts = const [],
    this.lines = const [],
    this.customerId = 1,
    this.location = 'DEF',
    this.saleTiming = SaleTiming.payNow,
    this.paymentMethod = PaymentMethod.cash,
    this.selectedBankAccountId,
    this.paymentMemo = '',
    this.errorMessage,
  });

  final bool loading;
  final bool submitting;
  final SalesPrefill? prefill;
  final List<BankAccount> bankAccounts;
  final List<TransactionLine> lines;
  final int customerId;
  final String location;
  final SaleTiming saleTiming;
  final PaymentMethod paymentMethod;
  final int? selectedBankAccountId;
  final String paymentMemo;
  final String? errorMessage;

  double get total => lines.fold(0, (sum, line) => sum + line.lineTotal);

  PosState copyWith({
    bool? loading,
    bool? submitting,
    SalesPrefill? prefill,
    List<BankAccount>? bankAccounts,
    List<TransactionLine>? lines,
    int? customerId,
    String? location,
    SaleTiming? saleTiming,
    PaymentMethod? paymentMethod,
    int? selectedBankAccountId,
    String? paymentMemo,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PosState(
      loading: loading ?? this.loading,
      submitting: submitting ?? this.submitting,
      prefill: prefill ?? this.prefill,
      bankAccounts: bankAccounts ?? this.bankAccounts,
      lines: lines ?? this.lines,
      customerId: customerId ?? this.customerId,
      location: location ?? this.location,
      saleTiming: saleTiming ?? this.saleTiming,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      selectedBankAccountId:
          selectedBankAccountId ?? this.selectedBankAccountId,
      paymentMemo: paymentMemo ?? this.paymentMemo,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class PosSubmitResult {
  const PosSubmitResult({
    required this.reference,
    required this.customerName,
    required this.storeCode,
    required this.documentDate,
    required this.lines,
    required this.total,
    this.paymentMethod,
    this.paymentStatus,
    this.balanceDue,
    this.invoiceNo,
    this.customerId,
    this.queuedOffline = false,
  });

  final String reference;
  final String customerName;
  final String storeCode;
  final String documentDate;
  final List<ReceiptLine> lines;
  final double total;
  final String? paymentMethod;
  final String? paymentStatus;
  final double? balanceDue;
  final int? invoiceNo;
  final int? customerId;
  final bool queuedOffline;
}

final posControllerProvider =
    StateNotifierProvider.autoDispose<PosController, PosState>((ref) {
  return PosController(ref);
});

class PosController extends StateNotifier<PosState> {
  PosController(this._ref) : super(const PosState()) {
    _init();
  }

  final Ref _ref;

  Future<void> _init() async {
    try {
      await _ref.read(appConfigProvider.notifier).ready;
      final config = _ref.read(appConfigProvider);
      var location = config.selectedStoreCode;
      if (location == null || location.isEmpty) {
        final stores = await _ref.read(storesProvider.future);
        location = stores.isNotEmpty ? stores.first.code : 'DEF';
        if (stores.isNotEmpty) {
          await _ref.read(appConfigProvider.notifier).setStore(location);
        }
      }
      final customers = await _ref.read(customersProvider.future);
      final customerId = customers.cashSalesCustomerId;
      await loadPrefill(customerId: customerId, location: location);
    } catch (e) {
      state = state.copyWith(loading: false, errorMessage: '$e');
    }
  }

  void setCustomer(int customerId) {
    if (customerId == state.customerId) return;
    loadPrefill(customerId: customerId, location: state.location);
  }

  Future<void> loadPrefill({
    required int customerId,
    required String location,
  }) async {
    state = state.copyWith(loading: true, clearError: true, lines: []);
    try {
      final cache = _ref.read(salesPrefillCacheProvider);
      final isOnline = _ref.read(syncServiceProvider).isOnline;
      SalesPrefill? prefill;

      if (isOnline) {
        prefill = await cache.fetchAndCache(
          customerId: customerId,
          location: location,
        );
      } else {
        prefill = await cache.load(
          customerId: customerId,
          location: location,
        );
      }

      if (prefill == null) {
        state = state.copyWith(
          loading: false,
          errorMessage: isOnline
              ? 'Could not load sale catalog'
              : 'Offline — tap Home while online to sync stock and prices first',
        );
        return;
      }

      // Bank accounts come from payment prefill — optional; don't block the sale
      // screen if that endpoint is unavailable.
      var bankAccounts = <BankAccount>[];
      if (isOnline) {
        try {
          final paymentPrefill = await _ref
              .read(paymentRepositoryProvider)
              .fetchPrefill(customerId: customerId);
          bankAccounts = paymentPrefill.bankAccounts;
        } on ApiException {
          // Pay-now may lack bank accounts until payment prefill works.
        }
      }

      var bankAccountId = bankAccountForPaymentMethod(
        state.paymentMethod,
        bankAccounts,
      );
      if (bankAccountId == null && bankAccounts.isNotEmpty) {
        bankAccountId = bankAccounts.first.id;
      }

      final saleTiming =
          prefill.defaults.onCredit ? SaleTiming.payLater : SaleTiming.payNow;

      state = state.copyWith(
        loading: false,
        prefill: prefill,
        bankAccounts: bankAccounts,
        customerId: customerId,
        location: location,
        saleTiming: saleTiming,
        selectedBankAccountId: bankAccountId,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(loading: false, errorMessage: '$e');
    }
  }

  void setSaleTiming(SaleTiming timing) {
    state = state.copyWith(saleTiming: timing);
  }

  void setPaymentMethod(PaymentMethod method) {
    final bankAccountId = bankAccountForPaymentMethod(
      method,
      state.bankAccounts,
    );
    state = state.copyWith(
      paymentMethod: method,
      selectedBankAccountId: bankAccountId,
    );
  }

  void setPaymentMemo(String memo) {
    state = state.copyWith(paymentMemo: memo);
  }

  void addLine(CatalogItem item) {
    final existingIndex =
        state.lines.indexWhere((l) => l.stockId == item.stockId);
    if (existingIndex >= 0) {
      final updated = [...state.lines];
      final line = updated[existingIndex];
      updated[existingIndex] = line.copyWith(quantity: line.quantity + 1);
      state = state.copyWith(lines: updated);
      return;
    }
    state = state.copyWith(lines: [...state.lines, item.toSalesLine()]);
  }

  void updateQuantity(int index, double quantity) {
    if (quantity == 0) {
      removeLine(index);
      return;
    }
    final updated = [...state.lines];
    updated[index] = updated[index].copyWith(quantity: quantity);
    state = state.copyWith(lines: updated);
  }

  void updatePrice(int index, double price) {
    final updated = [...state.lines];
    updated[index] = updated[index].copyWith(unitPrice: price);
    state = state.copyWith(lines: updated);
  }

  void removeLine(int index) {
    final updated = [...state.lines]..removeAt(index);
    state = state.copyWith(lines: updated);
  }

  Future<PosSubmitResult?> submit() async {
    final prefill = state.prefill;
    if (prefill == null || state.lines.isEmpty) return null;

    if (state.saleTiming == SaleTiming.payNow &&
        state.selectedBankAccountId == null) {
      state = state.copyWith(
        errorMessage: 'Select a bank account for payment',
      );
      return null;
    }

    state = state.copyWith(submitting: true, clearError: true);
    try {
      final isOnline = _ref.read(syncServiceProvider).isOnline;
      final reference = isOnline
          ? prefill.defaults.reference
          : 'OFF-${DateTime.now().toIso8601String().replaceAll(':', '').split('.').first}';

      final payload = <String, dynamic>{
        'customer_id': prefill.defaults.customerId,
        'branch_id': prefill.defaults.branchId,
        'location': prefill.defaults.location,
        'document_date': prefill.defaults.documentDate,
        'reference': reference,
        'lines': state.lines
            .map(
              (l) => {
                ...l.toSalesJson(),
                'description': l.description,
              },
            )
            .toList(),
      };

      if (state.saleTiming == SaleTiming.payLater) {
        payload['on_credit'] = true;
      } else {
        final memo = state.paymentMemo.trim();
        payload['payment'] = {
          'bank_account': state.selectedBankAccountId,
          'amount': state.total,
          if (memo.isNotEmpty) 'memo': memo,
        };
      }

      final result = await _ref.read(transactionSubmitterProvider).submit(
            type: SyncItemType.salesInvoice,
            payload: payload,
          );

      if (!result.isSuccess) {
        state = state.copyWith(submitting: false, errorMessage: 'Submit failed');
        return null;
      }

      final response = result.response ?? const {};
      final paymentStatus = response['payment_status'] as String?;
      final balanceDue = (response['balance_due'] as num?)?.toDouble();
      final invoiceNo = extractTransactionServerId(response);

      final receiptLines = state.lines
          .map(
            (l) => ReceiptLine(
              description: l.description,
              quantity: l.quantity,
              unitPrice: l.unitPrice,
              total: l.lineTotal,
            ),
          )
          .toList();

      final submitResult = PosSubmitResult(
        reference: result.reference ?? prefill.defaults.reference,
        customerName: prefill.defaults.deliverTo ?? 'Customer',
        storeCode: prefill.defaults.location,
        documentDate: prefill.defaults.documentDate,
        lines: receiptLines,
        total: result.total ?? state.total,
        paymentMethod: state.saleTiming == SaleTiming.payNow
            ? state.paymentMethod.label
            : null,
        paymentStatus: paymentStatus,
        balanceDue: balanceDue,
        invoiceNo: invoiceNo,
        customerId: prefill.defaults.customerId,
        queuedOffline: result.queuedOffline,
      );

      _ref.invalidate(dashboardProvider);
      _ref.invalidate(shadowSalesProvider);
      _ref.invalidate(historyEntriesProvider);

      final keepCustomerId = state.customerId;
      final keepLocation = prefill.defaults.location;
      final keepPaymentMethod = state.paymentMethod;
      state = PosState(
        loading: true,
        customerId: keepCustomerId,
        location: keepLocation,
        paymentMethod: keepPaymentMethod,
      );
      await loadPrefill(
        customerId: keepCustomerId,
        location: keepLocation,
      );
      return submitResult;
    } on ApiException catch (e) {
      state = state.copyWith(submitting: false, errorMessage: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(submitting: false, errorMessage: '$e');
      return null;
    }
  }
}
