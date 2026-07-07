import 'package:avogs/core/api/api_exception.dart';
import 'package:avogs/core/config/app_config_provider.dart';
import 'package:avogs/core/sync/sync_service.dart';
import 'package:avogs/core/transactions/transaction_submitter.dart';
import 'package:avogs/features/master_data/master_data_repository.dart';
import 'package:avogs/features/transactions/transaction_repositories.dart';
import 'package:avogs/shared/models/transaction_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PurchaseFormState {
  const PurchaseFormState({
    this.loading = true,
    this.submitting = false,
    this.prefill,
    this.supplierId = 1,
    this.location = 'DEF',
    this.supplierRef = '',
    this.lines = const [],
    this.errorMessage,
  });

  final bool loading;
  final bool submitting;
  final PurchasePrefill? prefill;
  final int supplierId;
  final String location;
  final String supplierRef;
  final List<TransactionLine> lines;
  final String? errorMessage;

  double get total => lines.fold(0, (sum, l) => sum + l.lineTotal);

  PurchaseFormState copyWith({
    bool? loading,
    bool? submitting,
    PurchasePrefill? prefill,
    int? supplierId,
    String? location,
    String? supplierRef,
    List<TransactionLine>? lines,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PurchaseFormState(
      loading: loading ?? this.loading,
      submitting: submitting ?? this.submitting,
      prefill: prefill ?? this.prefill,
      supplierId: supplierId ?? this.supplierId,
      location: location ?? this.location,
      supplierRef: supplierRef ?? this.supplierRef,
      lines: lines ?? this.lines,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final purchaseControllerProvider =
    StateNotifierProvider.autoDispose<PurchaseController, PurchaseFormState>(
  (ref) => PurchaseController(ref),
);

class PurchaseController extends StateNotifier<PurchaseFormState> {
  PurchaseController(this._ref) : super(const PurchaseFormState()) {
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
      await load(supplierId: 1, location: location);
    } catch (e) {
      state = state.copyWith(loading: false, errorMessage: '$e');
    }
  }

  Future<void> load({required int supplierId, required String location}) async {
    state = state.copyWith(loading: true, clearError: true, lines: []);
    try {
      final prefill = await _ref.read(purchaseRepositoryProvider).fetchPrefill(
            supplierId: supplierId,
            location: location,
          );
      state = state.copyWith(
        loading: false,
        prefill: prefill,
        supplierId: supplierId,
        location: location,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, errorMessage: e.message);
    }
  }

  void setSupplierRef(String value) => state = state.copyWith(supplierRef: value);

  void addLine(CatalogItem item) {
    final existing = state.lines.indexWhere((l) => l.stockId == item.stockId);
    if (existing >= 0) {
      final updated = [...state.lines];
      final line = updated[existing];
      updated[existing] = line.copyWith(quantity: line.quantity + 1);
      state = state.copyWith(lines: updated);
      return;
    }
    state = state.copyWith(lines: [...state.lines, item.toPurchaseLine()]);
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
    state = state.copyWith(lines: [...state.lines]..removeAt(index));
  }

  Future<TransactionSuccessDetails?> submit() async {
    final prefill = state.prefill;
    if (prefill == null || state.lines.isEmpty) {
      state = state.copyWith(errorMessage: 'Add at least one line');
      return null;
    }
    if (state.supplierRef.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Supplier invoice # is required');
      return null;
    }

    state = state.copyWith(submitting: true, clearError: true);
    try {
      final supplierRef = state.supplierRef.trim();
      final payload = {
        'supplier_id': prefill.defaults.supplierId,
        'supplier_ref': supplierRef,
        'location': prefill.defaults.location,
        'document_date': prefill.defaults.documentDate,
        'reference': prefill.defaults.reference,
        'lines': state.lines.map((l) => l.toPurchaseJson()).toList(),
      };

      final result = await _ref.read(transactionSubmitterProvider).submit(
            type: SyncItemType.supplierInvoice,
            payload: payload,
          );

      if (!result.isSuccess) {
        state = state.copyWith(submitting: false, errorMessage: 'Submit failed');
        return null;
      }

      final details = TransactionSuccessDetails(
        title: result.queuedOffline ? 'Invoice queued' : 'Stock received',
        reference: result.reference ?? prefill.defaults.reference,
        subtitle: '${prefill.defaults.location} · $supplierRef',
        total: state.total,
        detailLines: ['${state.lines.length} item(s)'],
        queuedOffline: result.queuedOffline,
      );

      await load(
        supplierId: prefill.defaults.supplierId,
        location: prefill.defaults.location,
      );
      state = state.copyWith(supplierRef: '', submitting: false);
      return details;
    } on ApiException catch (e) {
      state = state.copyWith(submitting: false, errorMessage: e.message);
      return null;
    }
  }
}
