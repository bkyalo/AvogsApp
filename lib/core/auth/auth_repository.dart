import 'dart:convert';

import 'package:avogs/core/api/api_error_mapper.dart';
import 'package:avogs/core/api/api_exception.dart';
import 'package:avogs/core/auth/auth_models.dart';
import 'package:avogs/core/auth/biometric_service.dart';
import 'package:avogs/core/auth/pin_service.dart';
import 'package:avogs/core/config/app_config.dart';
import 'package:avogs/core/config/app_config_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _tokenKey = 'auth_token';
const _userKey = 'auth_user';
const _storesKey = 'allowed_stores';
const _biometricKey = 'biometric_enabled';

final authTokenProvider = StateProvider<String?>((ref) => null);

final pinServiceProvider = Provider<PinService>(
  (ref) => PinService(ref.watch(secureStorageProvider)),
);

final biometricServiceProvider = Provider<BiometricService>(
  (_) => BiometricService(),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repo = AuthRepository(
    storage: ref.watch(secureStorageProvider),
    pinService: ref.watch(pinServiceProvider),
    biometricService: ref.watch(biometricServiceProvider),
    readConfig: () => ref.read(appConfigProvider),
    onTokenChanged: (token) =>
        ref.read(authTokenProvider.notifier).state = token,
  );
  ref.onDispose(repo.dispose);
  return repo;
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});

/// Whether this device has a usable biometric sensor (enrolled + supported).
final canUseBiometricProvider = FutureProvider<bool>((ref) {
  return ref.watch(authRepositoryProvider).canUseBiometric();
});

class AuthRepository {
  AuthRepository({
    required FlutterSecureStorage storage,
    required PinService pinService,
    required BiometricService biometricService,
    required AppConfig Function() readConfig,
    required void Function(String? token) onTokenChanged,
  })  : _storage = storage,
        _pinService = pinService,
        _biometricService = biometricService,
        _readConfig = readConfig,
        _onTokenChanged = onTokenChanged;

  final FlutterSecureStorage _storage;
  final PinService _pinService;
  final BiometricService _biometricService;
  final AppConfig Function() _readConfig;
  final void Function(String? token) _onTokenChanged;

  String? _token;
  String? get token => _token;

  Future<AuthState> restoreSession() async {
    _token = await _storage.read(key: _tokenKey);
    _onTokenChanged(_token);

    if (_token == null) {
      return const AuthState(status: AuthStatus.unauthenticated);
    }

    final userJson = await _storage.read(key: _userKey);
    final storesJson = await _storage.read(key: _storesKey);
    final biometric = await _storage.read(key: _biometricKey);
    final hasPin = await _pinService.hasPin();

    if (userJson == null) {
      await clearSession();
      return const AuthState(status: AuthStatus.unauthenticated);
    }

    final user = AuthUser.fromJson(
      jsonDecode(userJson) as Map<String, dynamic>,
    );
    final stores = storesJson == null
        ? <String>[]
        : (jsonDecode(storesJson) as List<dynamic>).cast<String>();

    if (!hasPin) {
      return AuthState(
        status: AuthStatus.needsPinSetup,
        user: user,
        allowedStores: stores,
        biometricEnabled: biometric == 'true',
      );
    }

    return AuthState(
      status: AuthStatus.locked,
      user: user,
      allowedStores: stores,
      biometricEnabled: biometric == 'true',
    );
  }

  Future<LoginResponse> login({
    required String identifier,
    required String password,
  }) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    try {
      final response = await dio.post<Map<String, dynamic>>(
        '${_readConfig().baseUrl}/auth/login',
        data: {'identifier': identifier, 'password': password},
      );
      final data = response.data;
      if (data == null) {
        throw ApiException(message: 'Empty login response');
      }
      return LoginResponse.fromJson(data);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<void> persistLogin(LoginResponse response) async {
    _token = response.token;
    _onTokenChanged(_token);
    await _storage.write(key: _tokenKey, value: response.token);
    await _storage.write(
      key: _userKey,
      value: jsonEncode({
        'id': response.user.id,
        'login': response.user.login,
        'name': response.user.name,
        'role_id': response.user.roleId,
      }),
    );
    await _storage.write(
      key: _storesKey,
      value: jsonEncode(response.allowedStores),
    );
  }

  Future<void> setPin(String pin) => _pinService.setPin(pin);

  Future<bool> verifyPin(String pin) => _pinService.verifyPin(pin);

  Future<bool> tryBiometricUnlock() async {
    final enabled = await _storage.read(key: _biometricKey);
    if (enabled != 'true') return false;
    return _biometricService.authenticate(
      reason: 'Unlock AVO\'Gs',
    );
  }

  Future<bool> canUseBiometric() => _biometricService.canCheckBiometrics();

  /// Prompts the sensor once — used to confirm biometrics actually work
  /// before trusting them as an unlock method.
  Future<bool> confirmBiometric() => _biometricService.authenticate(
        reason: "Confirm biometric unlock for AVO'Gs",
      );

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: _biometricKey,
      value: enabled ? 'true' : 'false',
    );
  }

  Future<bool> isBiometricEnabled() async {
    return (await _storage.read(key: _biometricKey)) == 'true';
  }

  Future<void> logout() async {
    if (_token != null) {
      try {
        await Dio(
          BaseOptions(
            headers: {
              'Authorization': 'Bearer $_token',
              'Content-Type': 'application/json',
            },
          ),
        ).post<void>('${_readConfig().baseUrl}/auth/logout');
      } catch (_) {
        // Best effort server logout.
      }
    }
    await clearSession();
  }

  Future<void> clearSession() async {
    _token = null;
    _onTokenChanged(null);
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    await _storage.delete(key: _storesKey);
    await _storage.delete(key: _biometricKey);
    await _pinService.clearPin();
  }

  Future<void> handleUnauthorized() => clearSession();

  void dispose() {}
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(const AuthState()) {
    bootstrap();
  }

  final AuthRepository _repository;

  Future<void> bootstrap() async {
    state = await _repository.restoreSession();
  }

  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(clearError: true);
    try {
      final response = await _repository.login(
        identifier: identifier,
        password: password,
      );
      await _repository.persistLogin(response);
      state = AuthState(
        status: AuthStatus.needsPinSetup,
        user: response.user,
        allowedStores: response.allowedStores,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e.message,
      );
    }
  }

  Future<void> completePinSetup(String pin, {bool enableBiometric = false}) async {
    await _repository.setPin(pin);
    var biometricEnabled = false;
    if (enableBiometric) {
      final confirmed = await _repository.confirmBiometric();
      if (confirmed) {
        await _repository.setBiometricEnabled(true);
        biometricEnabled = true;
      }
    }
    state = state.copyWith(
      status: AuthStatus.authenticated,
      biometricEnabled: biometricEnabled,
      clearError: true,
    );
  }

  Future<bool> unlockWithPin(String pin) async {
    final ok = await _repository.verifyPin(pin);
    if (ok) {
      state = state.copyWith(status: AuthStatus.authenticated, clearError: true);
    } else {
      state = state.copyWith(errorMessage: 'Incorrect PIN');
    }
    return ok;
  }

  Future<bool> unlockWithBiometric() async {
    final ok = await _repository.tryBiometricUnlock();
    if (ok) {
      state = state.copyWith(status: AuthStatus.authenticated, clearError: true);
    }
    return ok;
  }

  /// Turns biometric unlock on/off from Settings. Enabling requires one
  /// successful biometric confirmation so a broken/unenrolled sensor can't
  /// be trusted as the unlock method. Returns false if confirmation failed.
  Future<bool> setBiometricEnabled(bool enabled) async {
    if (enabled) {
      final ok = await _repository.confirmBiometric();
      if (!ok) return false;
    }
    await _repository.setBiometricEnabled(enabled);
    state = state.copyWith(biometricEnabled: enabled);
    return true;
  }

  /// Locks the app behind PIN entry without discarding the session (token,
  /// user, allowed stores) — used after closing a shift, so whoever closed
  /// up just re-enters the PIN next time instead of being logged out
  /// entirely like a real logout would.
  void lock() {
    state = state.copyWith(status: AuthStatus.locked, clearError: true);
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}
