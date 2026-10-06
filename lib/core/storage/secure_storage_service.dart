import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:school_app/core/network/interceptors/auth_interceptor.dart';

/// Keys used in secure storage.
abstract final class _Keys {
  static const String accessToken = 'auth_token';
  static const String schoolSlug = 'school_slug';
  static const String tokenExpiresAt = 'token_expires_at';
}

/// Hardware-backed secure storage for authentication tokens and tenant context.
///
/// Android: EncryptedSharedPreferences.
/// iOS: Keychain.
/// Windows: DPAPI-encrypted file.
///
/// Implements [AuthTokenProvider] so the [AuthInterceptor] can read the token
/// transparently on every request.
class SecureStorageService implements AuthTokenProvider {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  // ── Token ─────────────────────────────────────────────────────────────────

  /// Persists the Bearer access token and its expiry.
  Future<void> saveToken(String token, {DateTime? expiresAt}) async {
    await _storage.write(key: _Keys.accessToken, value: token);
    if (expiresAt != null) {
      await _storage.write(
        key: _Keys.tokenExpiresAt,
        value: expiresAt.toIso8601String(),
      );
    }
  }

  /// Returns the stored Bearer token, or `null` if not present.
  @override
  Future<String?> getToken() => _storage.read(key: _Keys.accessToken);

  /// Returns the stored token expiry, or `null` if not stored.
  Future<DateTime?> getTokenExpiresAt() async {
    final raw = await _storage.read(key: _Keys.tokenExpiresAt);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  // ── School Slug ───────────────────────────────────────────────────────────

  /// Persists the school slug last used for login.
  Future<void> saveSchoolSlug(String slug) =>
      _storage.write(key: _Keys.schoolSlug, value: slug);

  /// Returns the cached school slug, or `null`.
  Future<String?> getSchoolSlug() => _storage.read(key: _Keys.schoolSlug);

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Removes the access token and expiry (used on logout).
  Future<void> clearToken() async {
    await _storage.delete(key: _Keys.accessToken);
    await _storage.delete(key: _Keys.tokenExpiresAt);
  }

  /// Removes all stored auth data (used on hard logout / forced 401).
  Future<void> clearAll() => _storage.deleteAll();
}

