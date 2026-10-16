import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SessionStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) async {
    final secured = await _storage.read(key: key);
    if (secured != null && secured.trim().isNotEmpty) {
      await _removeLegacyValue(key);
      return secured;
    }

    final preferences = await SharedPreferences.getInstance();
    final legacy = preferences.getString(key);
    if (legacy == null || legacy.trim().isEmpty) {
      await preferences.remove(key);
      return null;
    }

    // Remove o valor antigo somente depois da gravacao criptografada.
    await _storage.write(key: key, value: legacy);
    await preferences.remove(key);
    return legacy;
  }

  @override
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
    await _removeLegacyValue(key);
  }

  @override
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
    await _removeLegacyValue(key);
  }

  Future<void> _removeLegacyValue(String key) async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.containsKey(key)) await preferences.remove(key);
  }
}

class MemorySessionStorage implements SessionStorage {
  MemorySessionStorage([Map<String, String>? initialValues])
    : _values = {...?initialValues};

  final Map<String, String> _values;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}
