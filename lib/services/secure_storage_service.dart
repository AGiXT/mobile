import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Centralizes encrypted key-value storage so sensitive data never falls back
/// to plain SharedPreferences.
class SecureStorageService {
  SecureStorageService._internal();

  static final SecureStorageService _instance =
      SecureStorageService._internal();

  factory SecureStorageService() => _instance;

  static const AndroidOptions _primaryAndroidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
    sharedPreferencesName: 'agixt_secure_storage',
    preferencesKeyPrefix: 'agixt_',
  );

  static const AndroidOptions _fallbackAndroidOptions = AndroidOptions(
    encryptedSharedPreferences: false,
    sharedPreferencesName: 'agixt_secure_storage_legacy',
    preferencesKeyPrefix: 'agixt_',
  );

  static const IOSOptions _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _useFallbackAndroidOptions = false;

  AndroidOptions get _activeAndroidOptions => _useFallbackAndroidOptions
      ? _fallbackAndroidOptions
      : _primaryAndroidOptions;

  bool _shouldFallback(Object error) {
    if (error is! PlatformException) {
      return false;
    }

    final details = '${error.code} ${error.message}'.toLowerCase();
    return details.contains('encryptedsharedpreferences') ||
        details.contains('android keystore') ||
        details.contains('not supported');
  }

  Future<T> _guardedAndroidCall<T>(
      Future<T> Function(AndroidOptions) action) async {
    try {
      return await action(_activeAndroidOptions);
    } catch (error) {
      if (_useFallbackAndroidOptions || !_shouldFallback(error)) {
        rethrow;
      }

      debugPrint(
        'SecureStorage falling back to non-encrypted Android preferences due to: $error',
      );
      _useFallbackAndroidOptions = true;
      return await action(_activeAndroidOptions);
    }
  }

  Future<void> write({required String key, required String value}) async {
    try {
      await _guardedAndroidCall(
        (options) => _storage.write(
          key: key,
          value: value,
          aOptions: options,
          iOptions: _iosOptions,
        ),
      );
    } catch (error) {
      debugPrint('SecureStorage write error for key "$key": $error');
      rethrow;
    }
  }

  Future<String?> read({required String key}) async {
    try {
      return await _guardedAndroidCall(
        (options) => _storage.read(
          key: key,
          aOptions: options,
          iOptions: _iosOptions,
        ),
      );
    } catch (error) {
      debugPrint('SecureStorage read error for key "$key": $error');
      return null;
    }
  }

  Future<void> delete({required String key}) async {
    try {
      await _guardedAndroidCall(
        (options) => _storage.delete(
          key: key,
          aOptions: options,
          iOptions: _iosOptions,
        ),
      );
    } catch (error) {
      debugPrint('SecureStorage delete error for key "$key": $error');
    }
  }

  Future<bool> containsKey({required String key}) async {
    try {
      return await _guardedAndroidCall(
        (options) => _storage.containsKey(
          key: key,
          aOptions: options,
          iOptions: _iosOptions,
        ),
      );
    } catch (error) {
      debugPrint('SecureStorage containsKey error for key "$key": $error');
      return false;
    }
  }

  Future<void> deleteAll({Iterable<String>? keys}) async {
    if (keys == null) {
      try {
        await _guardedAndroidCall(
          (options) => _storage.deleteAll(
            aOptions: options,
            iOptions: _iosOptions,
          ),
        );
      } catch (error) {
        debugPrint('SecureStorage deleteAll error: $error');
      }
      return;
    }

    for (final key in keys) {
      await delete(key: key);
    }
  }
}
