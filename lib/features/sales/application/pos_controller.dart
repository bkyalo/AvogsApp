import 'package:avogs/core/api/api_exception.dart';
import 'package:avogs/core/config/app_config_provider.dart';
import 'package:avogs/core/sync/sync_service.dart';
import 'package:avogs/core/transactions/transaction_submitter.dart';
import 'package:avogs/features/history/application/history_provider.dart';
import 'package:avogs/features/master_data/master_data_repository.dart';
import 'package:avogs/features/reports/reports_repository.dart';
import 'package:avogs/features/transactions/transaction_repositories.dart';
import 'package:avogs/shared/models/transaction_models.dart';
import 'package:avogs/shared/services/receipt_pdf_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PosState {
  const PosState({
    this.loading = true,
    this.submitting = false,
    this.prefill,
    this.lines = const [],
    this.customerId = 1,
    this.location = 'DEF',
    this.paymentMethod = PaymentMethod.cash,
    this.errorMessage,
  });

  final bool loading;
  final bool submitting;
  final SalesPrefill? prefill;
  final List<TransactionLine> lines;
  final int customerId;
  final String location;
  final PaymentMethod paymentMethod;
  final String? errorMessage;

  double get total => lines.fold(0, (sum, line) => sum + line.lineTotal);

  PosState copyWith({
    bool? loading,
    bool? submitting,
    SalesPrefill? prefill,
    List<TransactionLine>? lines,
    int? customerId,
    String? location,
    PaymentMethod? paymentMethod,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PosState(
      loading: loading ?? this.loading,
      submitting: submitting ?? this.submitting,
      prefill: prefill ?? this.prefill,
      lines: lines ?? this.lines,
      customerId: customerId ?? this.customerId,
      location: location ?? this.location,
      paymentMethod: paymentMethod ?? this.paymentMethod,
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
    required this.paymentMethod,
    this.queuedOffline = false,
  });

  final String reference;
  final String customerName;
  final String storeCode;
  final String documentDate;
  final List<ReceiptLine> lines;
  final double total;
  final String paymentMethod;
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
      final config = _ref.read(appConfigProvider);
      var location = config.selectedStoreCode;
      if (location == null) {
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
      final prefill = await _ref.read(salesRepositoryProvider).fetchPrefill(
            customerId: customerId,
            location: location,
          );
      state = state.copyWith(
        loading: false,
        prefill: prefill,
        customerId: customerId,
        location: location,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, errorMessage: e.message);
    }
  }

  void setPaymentMethod(PaymentMethod method) {
    state = state.copyWith(paymentMethod: method);
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

    state = state.copyWith(submitting: true, clearError: true);
    try {
      final payload = {
        'customer_id': prefill.defaults.customerId,
        'branch_id': prefill.defaults.branchId,
        'location': prefill.defaults.location,
        'document_date': prefill.defaults.documentDate,
        'reference': prefill.defaults.reference,
        'lines': state.lines.map((l) => l.toSalesJson()).toList(),
      };

      final result = await _ref.read(transactionSubmitterProvider).submit(
            type: SyncItemType.salesInvoice,
            payload: payload,
          );

      if (!result.isSuccess) {
        state = state.copyWith(submitting: false, errorMessage: 'Submit failed');
        return null;
      }

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
        paymentMethod: state.paymentMethod.label,
        queuedOffline: result.queuedOffline,
      );

      // Refresh dashboard and history so the sale shows up immediately.
      _ref.invalidate(dashboardProvider);
      _ref.invalidate(shadowSalesProvider);
      _ref.invalidate(historyEntriesProvider);

      final keepCustomerId = state.customerId;
      final keepLocation = prefill.defaults.location;
      state = PosState(
        loading: true,
        customerId: keepCustomerId,
        location: keepLocation,
        paymentMethod: state.paymentMethod,
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
