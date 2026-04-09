import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CredentialStore {
  CredentialStore._();
  static final CredentialStore instance = CredentialStore._();

  static const _storage = FlutterSecureStorage();
  static const _keyUsername = 'zjxu_username';
  static const _keyPassword = 'zjxu_password';
  static const _keyUnifiedUsername = 'zjxu_unified_username';
  static const _keyUnifiedPassword = 'zjxu_unified_password';

  // Session metadata keys
  static const _keyZfStudentId = 'zjxu_zf_student_id';
  static const _keyZfSessionActive = 'zjxu_zf_session_active';
  static const _keyUaAccount = 'zjxu_ua_account';
  static const _keyUaSessionActive = 'zjxu_ua_session_active';

  Future<void> saveCredentials(String username, String password) async {
    await _writePair(_keyUsername, username, _keyPassword, password);
  }

  Future<(String, String)?> loadCredentials() async {
    return _readPair(_keyUsername, _keyPassword);
  }

  Future<void> clearCredentials() async {
    await _clearPair(_keyUsername, _keyPassword);
  }

  Future<void> saveUnifiedAuthCredentials(
    String username,
    String password,
  ) async {
    await _writePair(
      _keyUnifiedUsername,
      username,
      _keyUnifiedPassword,
      password,
    );
  }

  Future<(String, String)?> loadUnifiedAuthCredentials() async {
    return _readPair(_keyUnifiedUsername, _keyUnifiedPassword);
  }

  Future<void> clearUnifiedAuthCredentials() async {
    await _clearPair(_keyUnifiedUsername, _keyUnifiedPassword);
  }

  // ── Zhengfang session persistence ──────────────────────────────────────────

  Future<void> saveZhengfangSession(String studentId) async {
    await _storage.write(key: _keyZfStudentId, value: studentId);
    await _storage.write(key: _keyZfSessionActive, value: '1');
  }

  Future<String?> loadZhengfangSession() async {
    final active = await _storage.read(key: _keyZfSessionActive);
    if (active != '1') return null;
    return _storage.read(key: _keyZfStudentId);
  }

  Future<void> clearZhengfangSession() async {
    await _storage.delete(key: _keyZfStudentId);
    await _storage.delete(key: _keyZfSessionActive);
  }

  // ── Unified Auth session persistence ───────────────────────────────────────

  Future<void> saveUnifiedAuthSession(String account) async {
    await _storage.write(key: _keyUaAccount, value: account);
    await _storage.write(key: _keyUaSessionActive, value: '1');
  }

  Future<String?> loadUnifiedAuthSession() async {
    final active = await _storage.read(key: _keyUaSessionActive);
    if (active != '1') return null;
    return _storage.read(key: _keyUaAccount);
  }

  Future<void> clearUnifiedAuthSession() async {
    await _storage.delete(key: _keyUaAccount);
    await _storage.delete(key: _keyUaSessionActive);
  }

  Future<void> _writePair(
    String usernameKey,
    String username,
    String passwordKey,
    String password,
  ) async {
    await _storage.write(key: usernameKey, value: username);
    await _storage.write(key: passwordKey, value: password);
  }

  Future<(String, String)?> _readPair(
    String usernameKey,
    String passwordKey,
  ) async {
    final username = await _storage.read(key: usernameKey);
    final password = await _storage.read(key: passwordKey);
    if (username == null || password == null) return null;
    return (username, password);
  }

  Future<void> _clearPair(String usernameKey, String passwordKey) async {
    await _storage.delete(key: usernameKey);
    await _storage.delete(key: passwordKey);
  }
}
