import 'package:avogs/core/api/api_exception.dart';
import 'package:avogs/core/auth/auth_repository.dart';
import 'package:avogs/core/config/app_config_provider.dart';
import 'package:avogs/core/notifications/shift_reminder_service.dart';
import 'package:avogs/core/sync/sync_service.dart';
import 'package:avogs/core/transactions/transaction_submitter.dart';
import 'package:avogs/core/utils/formatters.dart';
import 'package:avogs/features/history/application/history_provider.dart';
import 'package:avogs/features/shifts/application/shift_gate_provider.dart';
import 'package:avogs/features/shifts/shifts_repository.dart';
import 'package:avogs/shared/models/transaction_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Deliberately smaller than [StockCountEntry]-based check-in: no photos,
/// no definitions lookup, no calls/deliveries notes — just the two things
/// the user asked for (stock, cash) plus a single free-text notes field.
class CheckoutStockCountEntry {
  const CheckoutStockCountEntry({
    required this.stockId,
    required this.name,
    required this.expectedQty,
    required this.actualQty,
  });

  final String stockId;
  final String name;
  final double expectedQty;
  final double actualQty;

  CheckoutStockCountEntry copyWith({double? actualQty}) {
    return CheckoutStockCountEntry(
      stockId: stockId,
      name: name,
      expectedQty: expectedQty,
      actualQty: actualQty ?? this.actualQty,
    );
  }
}

class CheckoutFormState {
  const CheckoutFormState({
    this.loading = true,
    this.submitting = false,
    this.blocked = false,
    this.blockedStatus,
    this.store = 'DEF',
    this.shift = 'morning',
    this.stockCounts = const [],
    this.till = 0,
    this.floatAmount = 0,
    this.notes = '',
    this.errorMessage,
  });

  final bool loading;
  final bool submitting;
  // True when there's no open shift to close — checkout is a no-op then.
  final bool blocked;
  final ShiftStatus? blockedStatus;
  final String store;
  final String shift;
  final List<CheckoutStockCountEntry> stockCounts;
  final double till;
  final double floatAmount;
  final String notes;
  final String? errorMessage;

  CheckoutFormState copyWith({
    bool? loading,
    bool? submitting,
    bool? blocked,
    ShiftStatus? blockedStatus,
    String? store,
    String? shift,
    List<CheckoutStockCountEntry>? stockCounts,
    double? till,
    double? floatAmount,
    String? notes,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CheckoutFormState(
      loading: loading ?? this.loading,
      submitting: submitting ?? this.submitting,
      blocked: blocked ?? this.blocked,
      blockedStatus: blockedStatus ?? this.blockedStatus,
      store: store ?? this.store,
      shift: shift ?? this.shift,
      stockCounts: stockCounts ?? this.stockCounts,
      till: till ?? this.till,
      floatAmount: floatAmount ?? this.floatAmount,
      notes: notes ?? this.notes,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final checkoutControllerProvider =
    StateNotifierProvider.autoDispose<CheckoutController, CheckoutFormState>(
  (ref) => CheckoutController(ref),
);

class CheckoutController extends StateNotifier<CheckoutFormState> {
  CheckoutController(this._ref) : super(const CheckoutFormState()) {
    _init();
  }

  final Ref _ref;

  Future<void> _init() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      // See ShiftGateController._performCheck() / CheckinController for the
      // same race: reading this before secure storage finishes loading
      // silently falls back to 'DEF'.
      await _ref.read(appConfigProvider.notifier).ready;
      final config = _ref.read(appConfigProvider);
      final store = config.selectedStoreCode?.isNotEmpty == true
          ? config.selectedStoreCode!
          : 'DEF';
      state = state.copyWith(store: store);

      // Always fetch fresh here (unlike check-in, which reuses the app-level
      // gate's cached answer) — this is the "closing the books" action, so
      // it should reflect the current state, not a possibly stale snapshot
      // from whenever the gate last checked.
      final status =
          await _ref.read(shiftsRepositoryProvider).fetchCurrentShift();
      if (!status.active) {
        state = state.copyWith(
          loading: false,
          blocked: true,
          blockedStatus: status,
        );
        return;
      }

      state = state.copyWith(shift: status.shift);

      final prefill = await _ref
          .read(shiftsRepositoryProvider)
          .fetchCheckoutPrefill(shift: status.shift);
      state = state.copyWith(
        loading: false,
        shift: prefill.shift,
        stockCounts: [
          for (final s in prefill.stockCounts)
            CheckoutStockCountEntry(
              stockId: s.stockId,
              name: s.name,
              expectedQty: s.expectedQty,
              actualQty: s.expectedQty,
            ),
        ],
        till: prefill.cash.till,
        floatAmount: prefill.cash.floatAmount,
      );
    } catch (e) {
      state = state.copyWith(loading: false, errorMessage: '$e');
    }
  }

  void updateActualQty(int index, double qty) {
    final updated = [...state.stockCounts];
    updated[index] = updated[index].copyWith(actualQty: qty);
    state = state.copyWith(stockCounts: updated);
  }

  void setTill(double value) => state = state.copyWith(till: value);

  void setFloat(double value) => state = state.copyWith(floatAmount: value);

  void setNotes(String value) => state = state.copyWith(notes: value);

  Future<TransactionSuccessDetails?> submit() async {
    state = state.copyWith(submitting: true, clearError: true);
    try {
      final payload = {
        'store': state.store,
        'shift': state.shift,
        'cash': {'till': state.till, 'float': state.floatAmount},
        'stock_counts': [
          for (final s in state.stockCounts)
            {
              'stock_id': s.stockId,
              'expected_qty': s.expectedQty,
              'actual_qty': s.actualQty,
            },
        ],
        'notes': state.notes.trim(),
      };

      final result = await _ref.read(transactionSubmitterProvider).submit(
            type: SyncItemType.shiftCheckout,
            payload: payload,
          );

      if (!result.isSuccess) {
        state = state.copyWith(
          submitting: false,
          errorMessage: 'Submit failed — no confirmation from server',
        );
        return null;
      }

      final details = TransactionSuccessDetails(
        title: result.queuedOffline ? 'Check-out queued' : 'Shop closed',
        reference: result.reference ?? '${state.store}-${state.shift}',
        subtitle: '${state.store} · ${state.shift} shift',
        detailLines: [
          'Till ${formatMoney(state.till)} · Float ${formatMoney(state.floatAmount)}',
          '${state.stockCounts.length} item(s) counted',
        ],
        queuedOffline: result.queuedOffline,
      );

      _ref.invalidate(historyEntriesProvider);
      // No more reminder to fire once the shop is actually closed.
      await ShiftReminderService.instance.cancelShiftEndReminder();
      // Re-lock behind check-in for the next shift.
      _ref.read(shiftGateProvider.notifier).markClosed();
      // Closing the shop ends the session on this device — lock behind
      // PIN entry (not a full logout) so whoever's next just unlocks
      // rather than the shift-closer being signed out entirely.
      _ref.read(authControllerProvider.notifier).lock();

      state = state.copyWith(submitting: false);
      return details;
    } on ApiException catch (e) {
      state = state.copyWith(submitting: false, errorMessage: e.message);
      return null;
    }
  }
}
