import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinService {
  PinService(this._storage);

  final FlutterSecureStorage _storage;

  static const pinHashKey = 'pin_hash';
  static const pinLength = 4;

  Future<bool> hasPin() async {
    final hash = await _storage.read(key: pinHashKey);
    return hash != null && hash.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    _validatePin(pin);
    await _storage.write(key: pinHashKey, value: _hashPin(pin));
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: pinHashKey);
    if (stored == null) return false;
    return stored == _hashPin(pin);
  }

  Future<void> clearPin() => _storage.delete(key: pinHashKey);

  void _validatePin(String pin) {
    if (pin.length != pinLength || int.tryParse(pin) == null) {
      throw ArgumentError('PIN must be $pinLength digits');
    }
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode('avogs:$pin');
    return sha256.convert(bytes).toString();
  }
}
