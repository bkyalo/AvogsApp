import 'dart:typed_data';

import 'package:avogs/core/api/api_client.dart';
import 'package:avogs/core/config/app_config_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final shiftsRepositoryProvider = Provider<ShiftsRepository>((ref) {
  return ShiftsRepository(
    api: ref.watch(apiClientProvider),
    storeCode: ref.watch(appConfigProvider).selectedStoreCode,
  );
});

/// GET /shifts/current — confirmed shape:
/// { "active": false, "shift_id": null, "shift": "morning", "store": "DEF",
///   "opened_at": null, "expected": { "avocado": 100, "till": 2000, "float": 500 } }
/// `shift` is autodetected from server time when no shift is open, or the
/// open shift's key (for resume/close) when one is.
class ShiftStatus {
  const ShiftStatus({
    required this.active,
    required this.shiftId,
    required this.shift,
    required this.store,
    required this.openedAt,
    required this.expected,
  });

  factory ShiftStatus.fromJson(Map<String, dynamic> json) {
    return ShiftStatus(
      active: json['active'] as bool? ?? false,
      shiftId: _asIntOrNull(json['shift_id']),
      shift: json['shift'] as String? ?? 'morning',
      store: json['store'] as String? ?? '',
      openedAt: json['opened_at'] as String?,
      expected: (json['expected'] as Map<String, dynamic>?) ?? const {},
    );
  }

  final bool active;
  final int? shiftId;
  final String shift;
  final String store;
  final String? openedAt;
  final Map<String, dynamic> expected;

  double get expectedTill => _asDouble(expected['till']);
  double get expectedFloat => _asDouble(expected['float']);
}

/// GET /shifts/definitions — confirmed shape:
/// [{ "key": "morning", "name": "Morning Shift", "start": "07:00", "end": "14:00" }, ...]
/// For a manual picker's display names/hours; autodetect doesn't use these.
class ShiftDefinition {
  const ShiftDefinition({
    required this.key,
    required this.name,
    required this.start,
    required this.end,
  });

  factory ShiftDefinition.fromJson(Map<String, dynamic> json) {
    return ShiftDefinition(
      key: json['key'] as String? ?? '',
      name: json['name'] as String? ?? '',
      start: json['start'] as String? ?? '',
      end: json['end'] as String? ?? '',
    );
  }

  final String key;
  final String name;
  final String start;
  final String end;
}

class CheckinStockCount {
  const CheckinStockCount({
    required this.stockId,
    required this.name,
    required this.expectedQty,
  });

  factory CheckinStockCount.fromJson(Map<String, dynamic> json) {
    return CheckinStockCount(
      stockId: json['stock_id'] as String? ?? '',
      name: json['name'] as String? ??
          json['description'] as String? ??
          json['stock_id'] as String? ??
          '',
      expectedQty: _asDouble(json['expected_qty']),
    );
  }

  final String stockId;
  final String name;
  final double expectedQty;
}

class CheckinCashDefaults {
  const CheckinCashDefaults({required this.till, required this.floatAmount});

  static const zero = CheckinCashDefaults(till: 0, floatAmount: 0);

  final double till;
  final double floatAmount;
}

class PhotoSlotSpec {
  const PhotoSlotSpec({required this.key, required this.label});

  final String key;
  final String label;
}

/// The three slots named in the final check-in payload spec. Used whenever
/// the prefill response doesn't return its own photo_slots list.
const defaultPhotoSlots = [
  PhotoSlotSpec(key: 'shop_opening', label: 'Shop Opening'),
  PhotoSlotSpec(key: 'juice_station', label: 'Juice Station'),
  PhotoSlotSpec(key: 'arrangement', label: 'Arrangement'),
];

/// GET /shifts/checkin/prefill — confirmed fields: shift, checklist_mode,
/// checklist.title (source of truth for copy/checklist text). The exact
/// placement of the stock list, expected cash, and photo slots inside this
/// response wasn't given in the spec beyond "stock list, expected cash,
/// photo slots" — [_extractCash]/[_extractStockCounts]/[_extractPhotoSlots]
/// check the most likely locations (top-level, then nested under
/// "checklist") and fall back to sane defaults so the wizard still works
/// either way. Tighten these once the full response is confirmed.
class CheckinPrefill {
  const CheckinPrefill({
    required this.shift,
    required this.checklistMode,
    required this.checklistTitle,
    required this.cash,
    required this.stockCounts,
    required this.photoSlots,
  });

  factory CheckinPrefill.fromJson(Map<String, dynamic> json) {
    final checklist = json['checklist'] as Map<String, dynamic>? ?? const {};
    return CheckinPrefill(
      shift: json['shift'] as String? ?? 'morning',
      checklistMode: json['checklist_mode'] as String? ?? '',
      checklistTitle: checklist['title'] as String? ?? '',
      cash: _extractCash(json, checklist),
      stockCounts: _extractStockCounts(json, checklist),
      photoSlots: _extractPhotoSlots(json, checklist),
    );
  }

  final String shift;
  final String checklistMode;
  final String checklistTitle;
  final CheckinCashDefaults cash;
  final List<CheckinStockCount> stockCounts;
  final List<PhotoSlotSpec> photoSlots;
}

CheckinCashDefaults _extractCash(
  Map<String, dynamic> json,
  Map<String, dynamic> checklist,
) {
  final raw = json['cash'] ?? json['expected'] ?? checklist['cash'];
  if (raw is Map<String, dynamic>) {
    return CheckinCashDefaults(
      till: _asDouble(raw['till'] ?? raw['expected_till']),
      floatAmount: _asDouble(raw['float'] ?? raw['expected_float'] ?? raw['flt']),
    );
  }
  return CheckinCashDefaults.zero;
}

List<CheckinStockCount> _extractStockCounts(
  Map<String, dynamic> json,
  Map<String, dynamic> checklist,
) {
  final raw = json['stock_items'] ??
      json['stock_counts'] ??
      checklist['stock_items'] ??
      checklist['stock_counts'] ??
      json['stock'];
  if (raw is List) {
    return raw
        .whereType<Map<String, dynamic>>()
        .map(CheckinStockCount.fromJson)
        .toList();
  }
  return const [];
}

List<PhotoSlotSpec> _extractPhotoSlots(
  Map<String, dynamic> json,
  Map<String, dynamic> checklist,
) {
  final raw = json['photo_slots'] ?? checklist['photo_slots'];
  if (raw is List && raw.isNotEmpty) {
    return raw.whereType<Map<String, dynamic>>().map((s) {
      return PhotoSlotSpec(
        key: s['key'] as String? ?? '',
        label: s['label'] as String? ?? s['key'] as String? ?? '',
      );
    }).toList();
  }
  return defaultPhotoSlots;
}

/// GET /shifts/checkout/prefill — UNCONFIRMED. No spec was given for this
/// endpoint; it's assumed to mirror /shifts/checkin/prefill symmetrically
/// (same store/shift query params, same "expected stock/cash to reconcile
/// against" shape), so it reuses [_extractCash]/[_extractStockCounts].
/// Tighten or correct once the real contract is confirmed.
class CheckoutPrefill {
  const CheckoutPrefill({
    required this.shift,
    required this.cash,
    required this.stockCounts,
  });

  factory CheckoutPrefill.fromJson(Map<String, dynamic> json) {
    final checklist = json['checklist'] as Map<String, dynamic>? ?? const {};
    return CheckoutPrefill(
      shift: json['shift'] as String? ?? 'morning',
      cash: _extractCash(json, checklist),
      stockCounts: _extractStockCounts(json, checklist),
    );
  }

  final String shift;
  final CheckinCashDefaults cash;
  final List<CheckinStockCount> stockCounts;
}

/// POST /uploads response: { "upload_id": "upl_...", "url": "http://..." }
class UploadResult {
  const UploadResult({required this.uploadId, required this.url});

  factory UploadResult.fromJson(Map<String, dynamic> json) {
    return UploadResult(
      uploadId: json['upload_id'] as String? ?? '',
      url: json['url'] as String? ?? '',
    );
  }

  final String uploadId;
  final String url;
}

/// GET /shifts/{id}/checkin — read back a saved check-in later (e.g. from
/// a history detail view). Kept as a raw map for now since no screen
/// consumes it yet; wire a typed model once that UI exists.
class ShiftCheckinRecord {
  const ShiftCheckinRecord({required this.raw});

  factory ShiftCheckinRecord.fromJson(Map<String, dynamic> json) {
    return ShiftCheckinRecord(raw: json);
  }

  final Map<String, dynamic> raw;
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

int? _asIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

class ShiftsRepository {
  ShiftsRepository({required ApiClient api, required String? storeCode})
      : _api = api,
        _storeCode = storeCode;

  final ApiClient _api;
  final String? _storeCode;

  String get _store =>
      (_storeCode == null || _storeCode!.isEmpty) ? 'DEF' : _storeCode!;

  Future<ShiftStatus> fetchCurrentShift() async {
    final data = await _api.getJson(
      '/shifts/current',
      queryParameters: {'store': _store},
    );
    return ShiftStatus.fromJson(data);
  }

  Future<List<ShiftDefinition>> fetchShiftDefinitions() async {
    final data = await _api.getJsonList('/shifts/definitions');
    return data
        .whereType<Map<String, dynamic>>()
        .map(ShiftDefinition.fromJson)
        .toList();
  }

  /// Omit [shift] to autodetect (server default based on time of day);
  /// pass it to force a specific shift, e.g. when staff flips the manual
  /// override toggle.
  Future<CheckinPrefill> fetchCheckinPrefill({String? shift}) async {
    final query = <String, dynamic>{'store': _store};
    if (shift != null) query['shift'] = shift;
    final data = await _api.getJson(
      '/shifts/checkin/prefill',
      queryParameters: query,
    );
    return CheckinPrefill.fromJson(data);
  }

  /// Omit [shift] to autodetect (the currently open shift); pass it to force
  /// a specific one. UNCONFIRMED endpoint — see [CheckoutPrefill].
  Future<CheckoutPrefill> fetchCheckoutPrefill({String? shift}) async {
    final query = <String, dynamic>{'store': _store};
    if (shift != null) query['shift'] = shift;
    final data = await _api.getJson(
      '/shifts/checkout/prefill',
      queryParameters: query,
    );
    return CheckoutPrefill.fromJson(data);
  }

  Future<UploadResult> uploadPhoto(Uint8List bytes, {required String filename}) async {
    final data = await _api.uploadBytes(
      '/uploads',
      bytes: bytes,
      filename: filename,
    );
    return UploadResult.fromJson(data);
  }

  Future<ShiftCheckinRecord> fetchCheckinById(int id) async {
    final data = await _api.getJson('/shifts/$id/checkin');
    return ShiftCheckinRecord.fromJson(data);
  }
}
