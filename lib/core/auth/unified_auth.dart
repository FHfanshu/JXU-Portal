/// Stub implementation for open source release.
/// Real unified authentication implementation is not included.
/// 
/// This file provides type definitions and stub implementations
/// to allow the UI code to compile without the actual auth logic.

sealed class UnifiedAuthLoginResult {}

class UnifiedAuthLoginSuccess extends UnifiedAuthLoginResult {}

class UnifiedAuthLoginFailure extends UnifiedAuthLoginResult {
  UnifiedAuthLoginFailure(this.message);
  final String message;
}

class UnifiedAuthCaptchaException implements Exception {
  UnifiedAuthCaptchaException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Stub service - authentication logic not included in open source
class UnifiedAuthService {
  UnifiedAuthService._();
  static final UnifiedAuthService instance = UnifiedAuthService._();

  bool get isLoggedIn => false;
  String? currentAccount;

  Future<bool> prepareLogin({String serviceUrl = ''}) async {
    // Stub - not implemented
    return false;
  }

  Future<bool?> validateSession({
    String serviceUrl = '',
    bool syncWebViewCookies = true,
  }) async {
    // Stub - not implemented
    return false;
  }

  Future<Uint8List> fetchCaptcha({String serviceUrl = ''}) async {
    // Stub - not implemented
    throw UnifiedAuthCaptchaException('Not implemented in open source version');
  }

  Future<UnifiedAuthLoginResult> login(
    String username,
    String password,
    String captcha, {
    String serviceUrl = '',
  }) async {
    // Stub - not implemented
    return UnifiedAuthLoginFailure('Not implemented in open source version');
  }

  Future<void> syncCookiesToWebView() async {
    // Stub - not implemented
  }

  Future<void> markLoggedOut() async {
    // Stub - not implemented
  }

  Future<void> restoreSession({bool syncWebViewCookies = true}) async {
    // Stub - not implemented
  }
}

// Stub helper functions
bool isUnifiedAuthLoginEntryUrl(String currentUrl) => false;
bool urlHasCasTicket(String location) => false;
bool isUnifiedAuthAuthenticatedUrl(String currentUrl) => false;
String? extractUnifiedAuthServiceUrl(String currentUrl) => null;
bool looksLikeUnifiedAuthLoginHtml(String html) => false;