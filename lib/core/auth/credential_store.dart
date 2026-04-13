/// Stub implementation for open source release.
/// Real credential storage implementation is not included.
class CredentialStore {
  CredentialStore._();
  static final CredentialStore instance = CredentialStore._();

  Future<void> saveCredentials(String username, String password) async {
    // Stub - not implemented in open source version
  }

  Future<(String, String)?> loadCredentials() async {
    // Stub - not implemented in open source version
    return null;
  }

  Future<void> clearCredentials() async {
    // Stub - not implemented in open source version
  }

  Future<void> saveUnifiedAuthCredentials(
    String username,
    String password,
  ) async {
    // Stub - not implemented in open source version
  }

  Future<(String, String)?> loadUnifiedAuthCredentials() async {
    // Stub - not implemented in open source version
    return null;
  }

  Future<void> clearUnifiedAuthCredentials() async {
    // Stub - not implemented in open source version
  }

  Future<void> saveZhengfangSession(String studentId) async {
    // Stub - not implemented in open source version
  }

  Future<String?> loadZhengfangSession() async {
    // Stub - not implemented in open source version
    return null;
  }

  Future<void> clearZhengfangSession() async {
    // Stub - not implemented in open source version
  }

  Future<void> saveUnifiedAuthSession(String account) async {
    // Stub - not implemented in open source version
  }

  Future<String?> loadUnifiedAuthSession() async {
    // Stub - not implemented in open source version
    return null;
  }

  Future<void> clearUnifiedAuthSession() async {
    // Stub - not implemented in open source version
  }
}