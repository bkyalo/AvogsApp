import 'dart:async';

import 'package:avogs/core/config/app_config.dart';
import 'package:avogs/core/config/app_environment.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _envKey = 'app_environment';
const _storeKey = 'selected_store_code';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

final appConfigProvider =
    StateNotifierProvider<AppConfigController, AppConfig>(
  (ref) => AppConfigController(ref.watch(secureStorageProvider)),
);

class AppConfigController extends StateNotifier<AppConfig> {
  AppConfigController(this._storage)
      : super(AppConfig(environment: kDefaultEnvironment)) {
    _load();
  }

  final FlutterSecureStorage _storage;
  final Completer<void> _ready = Completer<void>();

  /// Resolves once the persisted store selection has actually been read
  /// from secure storage. Anything that decides "is a shift open" based on
  /// [AppConfig.selectedStoreCode] should await this first — reading state
  /// before this completes returns null (not-yet-loaded, not "no store"),
  /// which silently falls back to querying the wrong ('DEF') store and
  /// wrongly reports no shift open for whatever store the user actually
  /// has selected.
  Future<void> get ready => _ready.future;

  Future<void> _load() async {
    final envName = await _storage.read(key: _envKey);
    final store = await _storage.read(key: _storeKey);
    final environment = AppEnvironment.values.firstWhere(
      (e) => e.name == envName,
      orElse: () => kDefaultEnvironment,
    );
    state = AppConfig(
      environment: environment,
      selectedStoreCode: store,
    );
    if (!_ready.isCompleted) _ready.complete();
  }

  Future<void> setEnvironment(AppEnvironment environment) async {
    await _storage.write(key: _envKey, value: environment.name);
    state = state.copyWith(environment: environment);
  }

  Future<void> setStore(String? storeCode) async {
    if (storeCode == null) {
      await _storage.delete(key: _storeKey);
      state = state.copyWith(clearStore: true);
      return;
    }
    await _storage.write(key: _storeKey, value: storeCode);
    state = state.copyWith(selectedStoreCode: storeCode);
  }
}
