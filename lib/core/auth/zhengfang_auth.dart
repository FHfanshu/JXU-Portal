/// Stub implementation for open source release.
/// Real zhengfang authentication implementation is not included.
/// 
/// This file provides type definitions and stub implementations
/// to allow the UI code to compile without the actual auth logic.

enum ZhengfangMode {
  direct,
  webVpn,
}

sealed class LoginResult {}

class LoginSuccess extends LoginResult {}

class LoginFailure extends LoginResult {
  final String message;
  LoginFailure(this.message);
}

class CaptchaException implements Exception {
  final String message;
  CaptchaException(this.message);
  @override
  String toString() => message;
}

class WebVpnAlreadyAuthenticatedException implements Exception {
  WebVpnAlreadyAuthenticatedException();
  @override
  String toString() => 'WebVPN session already active';
}

sealed class WebVpnCasResult {}

class WebVpnCasSuccess extends WebVpnCasResult {}

class WebVpnCasFailure extends WebVpnCasResult {
  WebVpnCasFailure(this.message);
  final String message;
}

/// Stub service - authentication logic not included in open source
class ZhengfangAuth {
  ZhengfangAuth._();
  static final ZhengfangAuth instance = ZhengfangAuth._();

  ZhengfangMode _mode = ZhengfangMode.direct;
  ZhengfangMode get mode => _mode;

  bool _sessionActive = false;
  bool _webVpnSessionActive = false;
  String? currentStudentId;

  bool get isLoggedIn => _sessionActive;
  bool get isWebVpnLoggedIn => _webVpnSessionActive;

  String get _baseUrl => '';
  String get _loginPageUrl => '';
  String get _origin => '';

  String academicServiceUrl => '';
  
  String buildPortalUrl(String path, {Map<String, dynamic>? queryParameters}) {
    return path;
  }

  String resolvePortalUrl(String urlOrPath) => urlOrPath;
  String buildWebVpnProxyUrl(String rawUrl) => rawUrl;

  void setMode(ZhengfangMode mode) {
    _mode = mode;
  }

  void markWebVpnLoggedIn() {
    _webVpnSessionActive = true;
  }

  void markWebVpnLoggedOut() {
    _webVpnSessionActive = false;
  }

  void markLoggedIn() {
    _sessionActive = true;
  }

  Future<void> markLoggedOut() async {
    _sessionActive = false;
    currentStudentId = null;
  }

  Future<void> restoreSession() async {
    // Stub - not implemented
  }

  Future<void> logout() async {
    // Stub - not implemented
    await markLoggedOut();
  }

  Future<void> logoutWebVpn() async {
    // Stub - not implemented
    markWebVpnLoggedOut();
  }

  Future<Uint8List> fetchCaptcha() async {
    throw CaptchaException('Not implemented in open source version');
  }

  Future<LoginResult> login(
    String username,
    String password,
    String captcha,
  ) async {
    return LoginFailure('Not implemented in open source version');
  }

  Future<bool?> validateSession() async {
    return false;
  }

  Future<bool?> validateWebVpnProxySession(String targetUrl) async {
    return false;
  }

  Future<bool?> validateWebVpnTargetSession(String targetUrl) async {
    return false;
  }

  Future<bool?> ensureWebVpnGatewaySession({
    bool syncWebViewCookies = true,
  }) async {
    return false;
  }

  Future<Uint8List> fetchWebVpnCasCaptcha() async {
    throw CaptchaException('Not implemented in open source version');
  }

  Future<WebVpnCasResult> loginWebVpnCas(
    String username,
    String password,
    String captcha,
  ) async {
    return WebVpnCasFailure('Not implemented in open source version');
  }

  Future<void> syncCookiesToWebView() async {
    // Stub - not implemented
  }

  Future<void> syncWebVpnCookiesToWebView() async {
    // Stub - not implemented
  }

  Future<void> syncDirectCookiesToWebView() async {
    // Stub - not implemented
  }

  Future<Map<String, String>> buildWebViewHeaders(String targetUrl) async {
    return {};
  }

  @visibleForTesting
  String extractHiddenField(String html, String fieldName) => '';

  @visibleForTesting
  String extractCsrfFromHtml(String html) => '';

  @visibleForTesting
  bool isLoginSuccess(int? statusCode, String location, String html) => false;

  @visibleForTesting
  String extractLoginFailureMessage(String html) => '';

  @visibleForTesting
  String decodeHtmlEntities(String value) => value;

  @visibleForTesting
  void debugSetSession({required bool active, String? studentId}) {
    _sessionActive = active;
    currentStudentId = active ? studentId : null;
  }

  @visibleForTesting
  void debugReset() {
    _sessionActive = false;
    currentStudentId = null;
    _mode = ZhengfangMode.direct;
  }
}

// Stub helper functions
bool isZhengfangGatewayLoginUrl(String currentUrl) => false;
bool isZhengfangLoginEntryUrl(String currentUrl) => false;
bool isZhengfangAuthenticatedUrl(String currentUrl) => false;
bool looksLikeZhengfangLoginHtml(String html) => false;