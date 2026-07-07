import 'package:avogs/core/config/app_config_provider.dart';
import 'package:avogs/features/shifts/shifts_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the currently logged-in staff member can get into the app, or
/// needs to go through shift check-in first.
///
/// - [checking] — GET /shifts/current is in flight (right after login). The
///   router treats this the same as [closed] so staff land on the check-in
///   screen's own loading spinner instead of flashing the dashboard first.
/// - [closed] — confirmed no shift is open; check-in is required.
/// - [open] — confirmed a shift is open; the app is unlocked.
/// - [unreachable] — the check failed (offline, server error, etc). We
///   never trap staff behind a network problem, so this behaves like
///   [open] for routing purposes — they get in, and can check in once
///   connectivity returns.
enum ShiftGateStatus { checking, closed, open, unreachable }

class ShiftGateState {
  const ShiftGateState({this.status = ShiftGateStatus.checking, this.lastStatus});

  final ShiftGateStatus status;

  /// The most recent GET /shifts/current response, if any — reused by
  /// CheckinController so it doesn't have to re-fetch what the gate just
  /// fetched a moment earlier.
  final ShiftStatus? lastStatus;
}

final shiftGateProvider =
    StateNotifierProvider<ShiftGateController, ShiftGateState>((ref) {
  return ShiftGateController(ref);
});

class ShiftGateController extends StateNotifier<ShiftGateState> {
  ShiftGateController(this._ref) : super(const ShiftGateState());

  final Ref _ref;
  Future<void>? _inFlightCheck;

  /// Resolves once the current (or in-flight) GET /shifts/current completes.
  /// Safe to call multiple times — concurrent callers share one request.
  Future<void> check() async {
    if (_inFlightCheck != null) {
      await _inFlightCheck;
      return;
    }

    final future = _performCheck();
    _inFlightCheck = future;
    try {
      await future;
    } finally {
      if (identical(_inFlightCheck, future)) {
        _inFlightCheck = null;
      }
    }
  }

  Future<void> _performCheck() async {
    state = const ShiftGateState(status: ShiftGateStatus.checking);
    try {
      // See AppConfigController.ready: querying before the store selection
      // has loaded from secure storage would silently check store 'DEF'
      // instead of the real one and misreport a genuinely open shift as
      // closed — which is exactly what sends staff back through check-in
      // for no reason.
      await _ref.read(appConfigProvider.notifier).ready;
      final status = await _ref.read(shiftsRepositoryProvider).fetchCurrentShift();
      state = ShiftGateState(
        status: status.active ? ShiftGateStatus.open : ShiftGateStatus.closed,
        lastStatus: status,
      );
    } catch (_) {
      state = const ShiftGateState(status: ShiftGateStatus.unreachable);
    }
  }

  /// Called the moment check-in succeeds so the gate clears immediately,
  /// without waiting on another round trip to confirm it.
  void markOpen() {
    state = const ShiftGateState(status: ShiftGateStatus.open);
  }

  /// Called the moment checkout succeeds — closing the shop re-locks the
  /// app behind check-in again, same as a fresh login would, instead of
  /// leaving staff on a dashboard for a shift that's no longer open.
  void markClosed() {
    state = const ShiftGateState(status: ShiftGateStatus.closed);
  }

  /// Back to square one on logout, so the next login re-checks fresh.
  void reset() {
    state = const ShiftGateState(status: ShiftGateStatus.checking);
  }
}
