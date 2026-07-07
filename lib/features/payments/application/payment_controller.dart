import 'package:avogs/core/api/api_exception.dart';
import 'package:avogs/core/sync/sync_service.dart';
import 'package:avogs/core/transactions/transaction_submitter.dart';
import 'package:avogs/features/transactions/transaction_repositories.dart';
import 'package:avogs/shared/models/transaction_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PaymentFormState {
  const PaymentFormState({
    this.loading = true,
    this.submitting = false,
    this.prefill,
    this.customerId = 1,
    this.amount = 0,
    this.selectedBankAccountId,
    this.allocations = const {},
    this.errorMessage,
  });

  final bool loading;
  final bool submitting;
  final PaymentPrefill? prefill;
  final int customerId;
  final double amount;
  final int? selectedBankAccountId;
  final Map<int, double> allocations;
  final String? errorMessage;

  double get allocatedTotal =>
      allocations.values.fold(0, (sum, value) => sum + value);

  PaymentFormState copyWith({
    bool? loading,
    bool? submitting,
    PaymentPrefill? prefill,
    int? customerId,
    double? amount,
    int? selectedBankAccountId,
    Map<int, double>? allocations,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PaymentFormState(
      loading: loading ?? this.loading,
      submitting: submitting ?? this.submitting,
      prefill: prefill ?? this.prefill,
      customerId: customerId ?? this.customerId,
      amount: amount ?? this.amount,
      selectedBankAccountId:
          selectedBankAccountId ?? this.selectedBankAccountId,
      allocations: allocations ?? this.allocations,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final paymentControllerProvider =
    StateNotifierProvider.autoDispose<PaymentController, PaymentFormState>(
  (ref) => PaymentController(ref),
);

class PaymentController extends StateNotifier<PaymentFormState> {
  PaymentController(this._ref) : super(const PaymentFormState()) {
    load(customerId: 1);
  }

  final Ref _ref;

  Future<void> load({required int customerId}) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final prefill =
          await _ref.read(paymentRepositoryProvider).fetchPrefill(customerId: customerId);
      state = PaymentFormState(
        loading: false,
        prefill: prefill,
        customerId: customerId,
        selectedBankAccountId: prefill.defaults.bankAccount,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, errorMessage: e.message);
    }
  }

  void setCustomer(int customerId) => load(customerId: customerId);

  void setAmount(double amount) => state = state.copyWith(amount: amount);

  void setBankAccount(int id) =>
      state = state.copyWith(selectedBankAccountId: id);

  void toggleAllocation(OpenDocument doc, bool selected) {
    final updated = Map<int, double>.from(state.allocations);
    if (selected) {
      updated[doc.transNo] = doc.balance;
    } else {
      updated.remove(doc.transNo);
    }
    final amount = updated.values.fold(0.0, (a, b) => a + b);
    state = state.copyWith(allocations: updated, amount: amount);
  }

  void setAllocationAmount(int transNo, double amount) {
    final updated = Map<int, double>.from(state.allocations);
    updated[transNo] = amount;
    // Keep the payment amount in sync with allocations, same as toggling.
    final total = updated.values.fold(0.0, (a, b) => a + b);
    state = state.copyWith(allocations: updated, amount: total);
  }

  Future<TransactionSuccessDetails?> submit() async {
    final prefill = state.prefill;
    final bankAccount = state.selectedBankAccountId;
    if (prefill == null || bankAccount == null || state.amount <= 0) {
      state = state.copyWith(errorMessage: 'Enter a valid payment amount');
      return null;
    }
    const epsilon = 0.005;
    final overBalance = prefill.openDocuments.any(
      (d) => (state.allocations[d.transNo] ?? 0) > d.balance + epsilon,
    );
    if (overBalance) {
      state = state.copyWith(
        errorMessage: 'An allocation exceeds the invoice balance',
      );
      return null;
    }
    if (state.allocatedTotal > state.amount + epsilon) {
      state = state.copyWith(
        errorMessage: 'Allocations exceed the payment amount',
      );
      return null;
    }

    state = state.copyWith(submitting: true, clearError: true);
    try {
      final allocationEntries = state.allocations.entries
          .where((e) => e.value > 0)
          .map(
            (e) => {
              'trans_type': 10,
              'trans_no': e.key,
              'amount': e.value,
            },
          )
          .toList();

      final payload = {
        'customer_id': prefill.defaults.customerId,
        'branch_id': prefill.defaults.branchId,
        'bank_account': bankAccount,
        'document_date': prefill.defaults.documentDate,
        'reference': prefill.defaults.reference,
        'amount': state.amount,
        if (allocationEntries.isNotEmpty) 'allocations': allocationEntries,
      };

      final result = await _ref.read(transactionSubmitterProvider).submit(
            type: SyncItemType.salesPayment,
            payload: payload,
          );

      if (!result.isSuccess) {
        state = state.copyWith(submitting: false, errorMessage: 'Submit failed');
        return null;
      }

      final details = TransactionSuccessDetails(
        title: result.queuedOffline ? 'Payment queued' : 'Payment recorded',
        reference: result.reference ?? prefill.defaults.reference,
        subtitle: prefill.defaults.documentDate,
        total: state.amount,
        totalLabel: 'Amount',
        detailLines: allocationEntries.isNotEmpty
            ? ['${allocationEntries.length} invoice(s) allocated']
            : const [],
        queuedOffline: result.queuedOffline,
      );

      await load(customerId: prefill.defaults.customerId);
      return details;
    } on ApiException catch (e) {
      state = state.copyWith(submitting: false, errorMessage: e.message);
      return null;
    }
  }
}
