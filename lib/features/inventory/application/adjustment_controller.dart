import 'package:avogs/core/api/api_exception.dart';
import 'package:avogs/core/config/app_config_provider.dart';
import 'package:avogs/core/sync/sync_service.dart';
import 'package:avogs/core/transactions/transaction_submitter.dart';
import 'package:avogs/features/history/application/history_provider.dart';
import 'package:avogs/features/inventory/inventory_repository.dart';
import 'package:avogs/features/master_data/master_data_repository.dart';
import 'package:avogs/features/transactions/transaction_repositories.dart';
import 'package:avogs/shared/models/transaction_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdjustmentFormState {
  const AdjustmentFormState({
    this.loading = true,
    this.submitting = false,
    this.prefill,
    this.location = 'DEF',
    this.memo = '',
    this.lines = const [],
    this.errorMessage,
  });

  final bool loading;
  final bool submitting;
  final AdjustmentPrefill? prefill;
  final String location;
  final String memo;
  final List<TransactionLine> lines;
  final String? errorMessage;

  AdjustmentFormState copyWith({
    bool? loading,
    bool? submitting,
    AdjustmentPrefill? prefill,
    String? location,
    String? memo,
    List<TransactionLine>? lines,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdjustmentFormState(
      loading: loading ?? this.loading,
      submitting: submitting ?? this.submitting,
      prefill: prefill ?? this.prefill,
      location: location ?? this.location,
      memo: memo ?? this.memo,
      lines: lines ?? this.lines,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final adjustmentControllerProvider =
    StateNotifierProvider.autoDispose<AdjustmentController, AdjustmentFormState>(
  (ref) => AdjustmentController(ref),
);

class AdjustmentController extends StateNotifier<AdjustmentFormState> {
  AdjustmentController(this._ref) : super(const AdjustmentFormState()) {
    _init();
  }

  final Ref _ref;

  Future<void> _init() async {
    try {
      final config = _ref.read(appConfigProvider);
      var location = config.selectedStoreCode ?? 'DEF';
      if (config.selectedStoreCode == null) {
        final stores = await _ref.read(storesProvider.future);
        if (stores.isNotEmpty) {
          location = stores.first.code;
          await _ref.read(appConfigProvider.notifier).setStore(location);
        }
      }
      await load(location: location);
    } catch (e) {
      state = state.copyWith(loading: false, errorMessage: '$e');
    }
  }

  Future<void> load({required String location}) async {
    state = state.copyWith(loading: true, clearError: true, lines: []);
    try {
      final prefill =
          await _ref.read(adjustmentRepositoryProvider).fetchPrefill(location: location);
      state = state.copyWith(
        loading: false,
        prefill: prefill,
        location: location,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, errorMessage: e.message);
    }
  }

  void setMemo(String value) => state = state.copyWith(memo: value);

  void addLine(CatalogItem item, {bool decrease = true}) {
    state = state.copyWith(
      lines: [
        ...state.lines,
        item.toAdjustmentLine(quantity: decrease ? -1 : 1),
      ],
    );
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

  void removeLine(int index) {
    state = state.copyWith(lines: [...state.lines]..removeAt(index));
  }

  Future<TransactionSuccessDetails?> submit() async {
    final prefill = state.prefill;
    if (prefill == null || state.lines.isEmpty) {
      state = state.copyWith(errorMessage: 'Add at least one line');
      return null;
    }

    state = state.copyWith(submitting: true, clearError: true);
    try {
      final memo = state.memo.trim();
      final payload = {
        'location': prefill.defaults.location,
        'document_date': prefill.defaults.documentDate,
        'reference': prefill.defaults.reference,
        if (memo.isNotEmpty) 'memo': memo,
        'lines': state.lines.map((l) => l.toAdjustmentJson()).toList(),
      };

      final result = await _ref.read(transactionSubmitterProvider).submit(
            type: SyncItemType.inventoryAdjustment,
            payload: payload,
          );

      if (!result.isSuccess) {
        state = state.copyWith(
          submitting: false,
          errorMessage: 'Submit failed — no confirmation from server',
        );
        return null;
      }

      final lineCount = state.lines.length;
      final details = TransactionSuccessDetails(
        title: result.queuedOffline ? 'Adjustment queued' : 'Adjustment saved',
        reference: result.reference ?? prefill.defaults.reference,
        subtitle: prefill.defaults.location,
        detailLines: [
          if (memo.isNotEmpty) memo,
          '$lineCount line(s)',
        ],
        queuedOffline: result.queuedOffline,
      );

      // Refresh stock balances and history to reflect the adjustment.
      _ref.invalidate(inventoryBalancesProvider);
      _ref.invalidate(historyEntriesProvider);

      await load(location: prefill.defaults.location);
      state = state.copyWith(memo: '', submitting: false);
      return details;
    } on ApiException catch (e) {
      state = state.copyWith(submitting: false, errorMessage: e.message);
      return null;
    }
  }
}
