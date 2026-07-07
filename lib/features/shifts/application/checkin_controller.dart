import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:avogs/core/api/api_exception.dart';
import 'package:avogs/core/config/app_config_provider.dart';
import 'package:avogs/core/notifications/shift_reminder_service.dart';
import 'package:avogs/core/sync/sync_service.dart';
import 'package:avogs/core/transactions/transaction_submitter.dart';
import 'package:avogs/core/utils/formatters.dart';
import 'package:avogs/features/history/application/history_provider.dart';
import 'package:avogs/features/master_data/master_data_repository.dart';
import 'package:avogs/features/shifts/application/shift_gate_provider.dart';
import 'package:avogs/features/shifts/shifts_repository.dart';
import 'package:avogs/shared/models/transaction_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class PhotoSlotState {
  const PhotoSlotState({
    this.bytes,
    this.uploadId,
    this.uploading = false,
    this.error,
  });

  // Held in memory (not a file path) so previews and upload both work on
  // Flutter Web, where dart:io files aren't available.
  final Uint8List? bytes;
  final String? uploadId;
  final bool uploading;
  final String? error;

  bool get isUploaded => uploadId != null && uploadId!.isNotEmpty;
}

class StockCountEntry {
  const StockCountEntry({
    required this.stockId,
    required this.name,
    required this.expectedQty,
    required this.actualQty,
  });

  final String stockId;
  final String name;
  final double expectedQty;
  final double actualQty;

  StockCountEntry copyWith({double? actualQty}) {
    return StockCountEntry(
      stockId: stockId,
      name: name,
      expectedQty: expectedQty,
      actualQty: actualQty ?? this.actualQty,
    );
  }
}

class CheckinFormState {
  const CheckinFormState({
    this.loading = true,
    this.loadingPrefill = true,
    this.submitting = false,
    this.blocked = false,
    this.blockedStatus,
    this.store = 'DEF',
    this.shift = 'morning',
    this.definitions = const [],
    this.stockCounts = const [],
    this.photoSlots = const [],
    this.till = 0,
    this.floatAmount = 0,
    this.photos = const {},
    this.callsDeliveries = '',
    this.pendingOrders = '',
    this.errorMessage,
  });

  // Gates only the "do we even show the form, or the blocked view" decision
  // — true just long enough to learn whether a shift is already open.
  final bool loading;
  // True while stock counts / cash / photo slots are still being fetched in
  // the background. The shell (shift toggle, section headers, layout)
  // renders as soon as [loading] clears; sections bound to this flag show
  // skeleton placeholders until it does.
  final bool loadingPrefill;
  final bool submitting;
  final bool blocked;
  final ShiftStatus? blockedStatus;
  final String store;
  final String shift;
  final List<ShiftDefinition> definitions;
  final List<StockCountEntry> stockCounts;
  final List<PhotoSlotSpec> photoSlots;
  final double till;
  final double floatAmount;
  final Map<String, PhotoSlotState> photos;
  final String callsDeliveries;
  final String pendingOrders;
  final String? errorMessage;

  ShiftDefinition? get shiftDefinition {
    for (final d in definitions) {
      if (d.key == shift) return d;
    }
    return null;
  }

  bool get allPhotosUploaded =>
      photoSlots.isNotEmpty &&
      photoSlots.every((slot) => photos[slot.key]?.isUploaded ?? false);

  CheckinFormState copyWith({
    bool? loading,
    bool? loadingPrefill,
    bool? submitting,
    bool? blocked,
    ShiftStatus? blockedStatus,
    String? store,
    String? shift,
    List<ShiftDefinition>? definitions,
    List<StockCountEntry>? stockCounts,
    List<PhotoSlotSpec>? photoSlots,
    double? till,
    double? floatAmount,
    Map<String, PhotoSlotState>? photos,
    String? callsDeliveries,
    String? pendingOrders,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CheckinFormState(
      loading: loading ?? this.loading,
      loadingPrefill: loadingPrefill ?? this.loadingPrefill,
      submitting: submitting ?? this.submitting,
      blocked: blocked ?? this.blocked,
      blockedStatus: blockedStatus ?? this.blockedStatus,
      store: store ?? this.store,
      shift: shift ?? this.shift,
      definitions: definitions ?? this.definitions,
      stockCounts: stockCounts ?? this.stockCounts,
      photoSlots: photoSlots ?? this.photoSlots,
      till: till ?? this.till,
      floatAmount: floatAmount ?? this.floatAmount,
      photos: photos ?? this.photos,
      callsDeliveries: callsDeliveries ?? this.callsDeliveries,
      pendingOrders: pendingOrders ?? this.pendingOrders,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final checkinControllerProvider =
    StateNotifierProvider.autoDispose<CheckinController, CheckinFormState>(
  (ref) => CheckinController(ref),
);

class CheckinController extends StateNotifier<CheckinFormState> {
  CheckinController(this._ref) : super(const CheckinFormState()) {
    _init();
  }

  final Ref _ref;
  final _picker = ImagePicker();

  Future<void> retry() => _init();

  Future<void> _init() async {
    state = state.copyWith(loading: true, clearError: true, blocked: false);
    try {
      await _loadInitialData().timeout(
        const Duration(seconds: 45),
        onTimeout: () => throw TimeoutException(
          'Loading timed out. Check your API environment in Settings and try again.',
        ),
      );
    } on TimeoutException catch (e) {
      state = state.copyWith(loading: false, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(loading: false, errorMessage: '$e');
    }
  }

  Future<void> _loadInitialData() async {
    // Same reasoning as ShiftGateController._performCheck(): the persisted
    // store selection is read from secure storage asynchronously, so
    // reading it too early returns null and this would silently fall back
    // to 'DEF' below — both for deciding whether a shift is open AND for
    // what gets submitted on the final payload.
    await _ref.read(appConfigProvider.notifier).ready;
    final config = _ref.read(appConfigProvider);
    var store = config.selectedStoreCode;
    if (store == null || store.isEmpty) {
      final stores = await _ref.read(storesProvider.future);
      store = stores.isNotEmpty ? stores.first.code : 'DEF';
      if (stores.isNotEmpty) {
        await _ref.read(appConfigProvider.notifier).setStore(store);
      }
    }
    state = state.copyWith(store: store);

    // GET /shifts/current — block the wizard if a shift is already open.
    // Wait for the app-level gate check when it's in flight (right after
    // login) so we don't fire a duplicate request and race on lastStatus.
    final gate = _ref.read(shiftGateProvider);
    if (gate.status == ShiftGateStatus.checking) {
      await _ref.read(shiftGateProvider.notifier).check();
    }

    final gateStatus = _ref.read(shiftGateProvider).lastStatus;
    final status = gateStatus ??
        await _ref.read(shiftsRepositoryProvider).fetchCurrentShift();
    if (status.active) {
      state = state.copyWith(
        loading: false,
        blocked: true,
        blockedStatus: status,
      );
      return;
    }

    // We know enough now to draw the form itself (shift toggle, section
    // headers, layout) — stop blocking on the slower "what's actually in
    // the checklist" calls below and let them fill in their own sections
    // in the background instead of holding up the whole screen.
    state = state.copyWith(loading: false, shift: status.shift);

    unawaited(_loadDefinitions());
    unawaited(_loadPrefill(shift: status.shift));
  }

  Future<void> _loadDefinitions() async {
    try {
      final definitions =
          await _ref.read(shiftsRepositoryProvider).fetchShiftDefinitions();
      if (!mounted) return;
      state = state.copyWith(definitions: definitions);
    } catch (_) {
      // Non-fatal on its own — the shift toggle already falls back to
      // generic Morning/Evening labels when definitions haven't loaded.
    }
  }

  /// Re-fetches the prefill for [shift]. Pass null to let the server
  /// autodetect; pass an explicit key when staff flips the manual shift
  /// toggle ("?shift=morning" / "?shift=evening" forces that shift).
  Future<void> _loadPrefill({String? shift}) async {
    state = state.copyWith(loadingPrefill: true, clearError: true);
    try {
      final prefill = await _ref
          .read(shiftsRepositoryProvider)
          .fetchCheckinPrefill(shift: shift);
      if (!mounted) return;
      state = state.copyWith(
        loadingPrefill: false,
        shift: prefill.shift,
        stockCounts: [
          for (final s in prefill.stockCounts)
            StockCountEntry(
              stockId: s.stockId,
              name: s.name,
              expectedQty: s.expectedQty,
              actualQty: s.expectedQty,
            ),
        ],
        photoSlots: prefill.photoSlots,
        photos: {
          for (final slot in prefill.photoSlots)
            slot.key: const PhotoSlotState(),
        },
        till: prefill.cash.till,
        floatAmount: prefill.cash.floatAmount,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(loadingPrefill: false, errorMessage: '$e');
    }
  }

  /// Manual override toggle — re-fetches the prefill scoped to that shift
  /// (different checklist/expected cash per shift per the spec).
  Future<void> setShift(String shift) async {
    if (shift == state.shift || state.loadingPrefill) return;
    await _loadPrefill(shift: shift);
  }

  void updateActualQty(int index, double qty) {
    final updated = [...state.stockCounts];
    updated[index] = updated[index].copyWith(actualQty: qty);
    state = state.copyWith(stockCounts: updated);
  }

  void setTill(double value) => state = state.copyWith(till: value);

  void setFloat(double value) => state = state.copyWith(floatAmount: value);

  void setCallsDeliveries(String value) =>
      state = state.copyWith(callsDeliveries: value);

  void setPendingOrders(String value) =>
      state = state.copyWith(pendingOrders: value);

  Future<void> capturePhoto(String slotKey) async {
    final XFile? photo;
    try {
      photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1600,
      );
    } catch (e) {
      _setPhotoSlot(slotKey, PhotoSlotState(error: '$e'));
      return;
    }
    if (photo == null) return;

    final Uint8List bytes;
    try {
      bytes = await photo.readAsBytes();
    } catch (e) {
      _setPhotoSlot(slotKey, PhotoSlotState(error: '$e'));
      return;
    }

    _setPhotoSlot(slotKey, PhotoSlotState(bytes: bytes, uploading: true));
    try {
      final result = await _ref
          .read(shiftsRepositoryProvider)
          .uploadPhoto(bytes, filename: '$slotKey.jpg');
      if (result.uploadId.isEmpty) {
        const message = 'Upload succeeded but returned no upload_id';
        developer.log(message, name: 'CheckinController');
        _setPhotoSlot(slotKey, PhotoSlotState(bytes: bytes, error: message));
        return;
      }
      _setPhotoSlot(
        slotKey,
        PhotoSlotState(bytes: bytes, uploadId: result.uploadId),
      );
    } on ApiException catch (e) {
      developer.log('Photo upload failed: ${e.message}', name: 'CheckinController');
      _setPhotoSlot(slotKey, PhotoSlotState(bytes: bytes, error: e.message));
    } catch (e) {
      developer.log('Photo upload failed: $e', name: 'CheckinController');
      _setPhotoSlot(slotKey, PhotoSlotState(bytes: bytes, error: '$e'));
    }
  }

  void _setPhotoSlot(String key, PhotoSlotState value) {
    state = state.copyWith(photos: {...state.photos, key: value});
  }

  Future<TransactionSuccessDetails?> submit() async {
    if (!state.allPhotosUploaded) {
      state = state.copyWith(
        errorMessage: 'Capture and upload all photos before saving',
      );
      return null;
    }

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
        'photos': {
          for (final entry in state.photos.entries) entry.key: entry.value.uploadId,
        },
        'comments': {
          'calls_deliveries': state.callsDeliveries.trim(),
          'pending_orders': state.pendingOrders.trim(),
        },
      };

      // Photos are already uploaded (real upload_ids collected above); this
      // final JSON save can safely go through the same offline queue as
      // sales/purchases/adjustments if the connection drops right now.
      final result = await _ref.read(transactionSubmitterProvider).submit(
            type: SyncItemType.shiftCheckin,
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
        title: result.queuedOffline ? 'Check-in queued' : 'Shop opened',
        reference: result.reference ?? '${state.store}-${state.shift}',
        subtitle:
            '${state.store} · ${state.shiftDefinition?.name ?? state.shift}',
        detailLines: [
          'Till ${formatMoney(state.till)} · Float ${formatMoney(state.floatAmount)}',
          '${state.stockCounts.length} item(s) counted',
        ],
        queuedOffline: result.queuedOffline,
      );

      _ref.invalidate(historyEntriesProvider);
      // Clear the app-level gate immediately — don't make staff wait on
      // another round trip to GET /shifts/current before they can proceed.
      _ref.read(shiftGateProvider.notifier).markOpen();

      // Best-effort — a shift with no known end time (or one already past)
      // just means no reminder fires; never block a successful check-in.
      final endTime = _endTimeForShiftDefinition(state.shiftDefinition);
      if (endTime != null) {
        unawaited(
          ShiftReminderService.instance.scheduleShiftEndReminder(
            endTime: endTime,
            shiftLabel: state.shiftDefinition?.name ?? state.shift,
          ),
        );
      }

      state = state.copyWith(submitting: false);
      return details;
    } on ApiException catch (e) {
      state = state.copyWith(submitting: false, errorMessage: e.message);
      return null;
    }
  }
}

/// [ShiftDefinition.end] is an "HH:mm" string with no date attached — this
/// resolves it against today's date so the reminder service has an actual
/// DateTime to schedule against. Returns null if there's no definition to
/// go on, or the time string doesn't parse.
DateTime? _endTimeForShiftDefinition(ShiftDefinition? definition) {
  final end = definition?.end;
  if (end == null || end.isEmpty) return null;
  final parts = end.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, hour, minute);
}
