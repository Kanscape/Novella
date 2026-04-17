import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecretStorageKeys {
  static const authToken = 'auth_token';
  static const refreshToken = 'refresh_token';
  static const githubAccessToken = 'github_access_token';
  static const syncGistId = 'sync_gist_id';
  static const syncPassword = 'sync_password';
}

class SecretStorageFallbackRequiredException implements Exception {
  const SecretStorageFallbackRequiredException();

  @override
  String toString() => '需要用户确认后才能回退到 SharedPreferences';
}

class SecretStorageService {
  SecretStorageService._internal();

  static final SecretStorageService _instance =
      SecretStorageService._internal();
  factory SecretStorageService() => _instance;

  static const _secureStorage = FlutterSecureStorage();
  static const _fallbackApprovedKey = 'secure_storage_fallback_approved';
  static const _probeKey = '__secret_storage_probe__';
  static const _managedKeys = <String>{
    SecretStorageKeys.authToken,
    SecretStorageKeys.refreshToken,
    SecretStorageKeys.githubAccessToken,
    SecretStorageKeys.syncGistId,
    SecretStorageKeys.syncPassword,
  };

  final Logger _logger = Logger('SecretStorageService');

  bool? _secureAvailable;
  Object? _lastSecureError;
  Future<bool>? _probeFuture;

  Object? get lastSecureError => _lastSecureError;

  Future<bool> isSecureStorageAvailable({bool forceRefresh = false}) async {
    if (!forceRefresh && _secureAvailable != null) {
      return _secureAvailable!;
    }
    final inFlight = _probeFuture;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _probeSecureStorage();
    _probeFuture = future;
    try {
      return await future;
    } finally {
      _probeFuture = null;
    }
  }

  Future<bool> _probeSecureStorage() async {
    try {
      await _secureStorage.write(key: _probeKey, value: 'ok');
      final readBack = await _secureStorage.read(key: _probeKey);
      await _secureStorage.delete(key: _probeKey);
      final available = readBack == 'ok';
      _secureAvailable = available;
      _lastSecureError = available ? null : StateError('SecureStorage 校验失败');
      if (!available) {
        _logger.warning('SecureStorage probe failed: read back mismatch');
      }
      return available;
    } catch (e) {
      _secureAvailable = false;
      _lastSecureError = e;
      _logger.warning('SecureStorage probe failed: $e');
      return false;
    }
  }

  Future<bool> isFallbackApproved() async {
    final prefs = await SharedPreferences.getInstance();
    final approved = prefs.getBool(_fallbackApprovedKey) ?? false;
    if (approved) {
      return true;
    }

    for (final key in _managedKeys) {
      final value = prefs.getString(key);
      if (value != null && value.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  Future<void> approveFallback() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_fallbackApprovedKey, true);
  }

  Future<String?> read(String key) async {
    final secureAvailable = await isSecureStorageAvailable();
    if (secureAvailable) {
      try {
        final secureValue = await _secureStorage.read(key: key);
        if (secureValue != null && secureValue.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          if (prefs.getString(key) != null) {
            await prefs.remove(key);
          }
          return secureValue;
        }
      } catch (e) {
        _markSecureUnavailable(e);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final fallbackValue = prefs.getString(key);
    if (fallbackValue == null || fallbackValue.isEmpty) {
      return fallbackValue;
    }

    if (secureAvailable) {
      try {
        await _secureStorage.write(key: key, value: fallbackValue);
        await prefs.remove(key);
        _logger.info('Migrated $key from SharedPreferences to SecureStorage');
      } catch (e) {
        _markSecureUnavailable(e);
        return fallbackValue;
      }

      return fallbackValue;
    }

    return fallbackValue;
  }

  Future<void> write(String key, String value) async {
    if (value.isEmpty) {
      await delete(key);
      return;
    }

    final secureAvailable = await isSecureStorageAvailable();
    if (secureAvailable) {
      try {
        await _secureStorage.write(key: key, value: value);
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(key);
        return;
      } catch (e) {
        _markSecureUnavailable(e);
      }
    }

    if (!await isFallbackApproved()) {
      throw const SecretStorageFallbackRequiredException();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
    _logger.warning('Stored $key in SharedPreferences fallback');
  }

  Future<void> delete(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      _logger.warning('Failed to delete $key from SecureStorage: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  Future<void> deleteMany(Iterable<String> keys) async {
    for (final key in keys) {
      await delete(key);
    }
  }

  void _markSecureUnavailable(Object error) {
    _secureAvailable = false;
    _lastSecureError = error;
    _logger.warning('SecureStorage write failed, fallback required: $error');
  }
}
