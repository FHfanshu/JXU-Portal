import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jiaxing_university_portal/core/auth/zhengfang_auth.dart';
import 'package:jiaxing_university_portal/core/network/dio_client.dart';
import 'package:jiaxing_university_portal/core/network/network_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ZhengfangAuth auth;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    NetworkSettings.instance.debugReset();
    DioClient.instance.debugReset();
    DioClient.instance.debugCookieDirectoryPathProvider = (folderName) async {
      final dir = await Directory.systemTemp.createTemp('zhengfang_auth_test_');
      return '${dir.path}/$folderName/';
    };
    auth = ZhengfangAuth.instance;
  });

  tearDown(() {
    auth.setMode(ZhengfangMode.direct);
    auth.debugReset();
    DioClient.instance.debugReset();
    NetworkSettings.instance.debugReset();
  });

  group('extractCsrfFromHtml', () {
    test('extracts csrftoken from id-anchored input', () {
      const html =
          '<input type="hidden" id="csrftoken" name="csrftoken" value="abc123def" />';
      expect(auth.extractCsrfFromHtml(html), 'abc123def');
    });

    test('extracts csrftoken from name-anchored input', () {
      const html =
          '<input type="hidden" name="csrftoken" value="xyz789" id="csrftoken" />';
      expect(auth.extractCsrfFromHtml(html), 'xyz789');
    });

    test('extracts csrftoken with single quotes', () {
      const html =
          "<input type='hidden' name='csrftoken' value='single_quote_val' />";
      expect(auth.extractCsrfFromHtml(html), 'single_quote_val');
    });

    test('returns empty string when csrftoken is absent', () {
      const html = '<html><body>No CSRF here</body></html>';
      expect(auth.extractCsrfFromHtml(html), '');
    });
  });

  group('isLoginSuccess', () {
    test('returns true for redirect to authenticated page', () {
      expect(
        auth.isLoginSuccess(
          302,
          '/jwglxt/xtgl/index_initMenu.html?jsdm=xs',
          '',
        ),
        isTrue,
      );
    });

    test('returns false for redirect back to login page', () {
      expect(
        auth.isLoginSuccess(302, '/jwglxt/xtgl/login_slogin.html', ''),
        isFalse,
      );
    });

    test('returns false for returned login page html', () {
      const loginHtml =
          '<form action="/jwglxt/xtgl/login_slogin.html"><input id="yhm" /><input id="mm" /></form>';
      expect(auth.isLoginSuccess(200, '', loginHtml), isFalse);
    });

    test('returns true for returned authenticated html', () {
      const authenticatedHtml = '<html>/xtgl/index_initMenu.html</html>';
      expect(auth.isLoginSuccess(200, '', authenticatedHtml), isTrue);
    });
  });

  group('extractLoginFailureMessage', () {
    test('extracts message from tips element', () {
      const html = '<div id="tips">用户名或密码错误</div>';
      expect(auth.extractLoginFailureMessage(html), '用户名或密码错误');
    });

    test('returns captcha fallback when html mentions 验证码', () {
      const html = '<html><body>验证码输入错误</body></html>';
      expect(auth.extractLoginFailureMessage(html), '验证码错误或已过期，请刷新后重试');
    });

    test('prefers tips content over generic captcha fallback', () {
      const html = '<span id="tips">验证码已失效，请刷新</span><div>验证码</div>';
      expect(auth.extractLoginFailureMessage(html), '验证码已失效，请刷新');
    });

    test('strips nested html tags inside tips element', () {
      const html = '<span id="tips"><font color="red">请输入验证码</font></span>';
      expect(auth.extractLoginFailureMessage(html), '请输入验证码');
    });
  });

  group('extractHiddenField', () {
    test('extracts execution field from hidden input', () {
      const html =
          '<input type="hidden" name="execution" value="e1s1-abc123" />';
      expect(auth.extractHiddenField(html, 'execution'), 'e1s1-abc123');
    });

    test('returns empty string when hidden field is absent', () {
      expect(auth.extractHiddenField('<html></html>', 'execution'), '');
    });
  });

  group('decodeHtmlEntities', () {
    test('decodes common HTML entities', () {
      expect(auth.decodeHtmlEntities('&lt;script&gt;'), '<script>');
      expect(auth.decodeHtmlEntities('&quot;hello&quot;'), '"hello"');
      expect(auth.decodeHtmlEntities('a&nbsp;b'), 'a b');
      expect(auth.decodeHtmlEntities('&#39;text&#39;'), "'text'");
      expect(auth.decodeHtmlEntities('a &amp; b'), 'a & b');
    });
  });

  group('login flow regression', () {
    test('does not logout before submitting the login form', () async {
      await DioClient.instance.ensureInitialized();
      auth.setMode(ZhengfangMode.direct);

      final adapter = _RecordingZhengfangAdapter();
      DioClient.instance.dio.httpClientAdapter = adapter;

      final result = await auth.login('2024001', 'password123', '2468');

      expect(result, isA<LoginSuccess>());
      expect(auth.isLoggedIn, isTrue);
      expect(auth.currentStudentId, '2024001');
      expect(adapter.logoutCount, 0);
      expect(
        adapter.requestLog,
        equals([
          'GET /jwglxt/xtgl/login_slogin.html',
          'GET /jwglxt/xtgl/login_getPublicKey.html',
          'POST /jwglxt/xtgl/login_slogin.html',
        ]),
      );
    });

    test('surfaces captcha failure from login response html', () async {
      await DioClient.instance.ensureInitialized();
      auth.setMode(ZhengfangMode.direct);

      final adapter = _RecordingZhengfangAdapter(forceCaptchaFailure: true);
      DioClient.instance.dio.httpClientAdapter = adapter;

      final result = await auth.login('2024001', 'password123', '2468');

      expect(result, isA<LoginFailure>());
      expect((result as LoginFailure).message, '验证码错误或已过期');
      expect(adapter.logoutCount, 0);
      expect(adapter.requestLog.last, 'POST /jwglxt/xtgl/login_slogin.html');
    });
  });
}

class _RecordingZhengfangAdapter implements HttpClientAdapter {
  _RecordingZhengfangAdapter({this.forceCaptchaFailure = false});

  static const _modulus =
      '18vI4XcZMDybHwuQYgp+fxR8kAgAQWPnKFNLVDoTopVtDgtb1PlyJAmV85T1TVUmTVCGqw1adAmVgdDm3MaAO+CrS6bsfywyqMqT8yTNadF79hkFqf3DW0PUCWk59/vfc8QRnPyJBAIN6pNmukJxdL2Z4WLuQ4e63VivUoacFeE=';
  static const _exponent = 'AQAB';
  static const _loginPageHtml =
      '<html><input type="hidden" id="csrftoken" name="csrftoken" value="csrf-token-123" /></html>';

  final bool forceCaptchaFailure;
  final List<String> requestLog = <String>[];
  int logoutCount = 0;
  bool _sessionValid = true;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    requestLog.add('${options.method} $path');

    if (path.endsWith('/xtgl/login_slogin.html') && options.method == 'GET') {
      return ResponseBody.fromString(
        _loginPageHtml,
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['text/html; charset=utf-8'],
        },
      );
    }

    if (path.endsWith('/xtgl/login_getPublicKey.html')) {
      return ResponseBody.fromString(
        jsonEncode(<String, String>{
          'modulus': _modulus,
          'exponent': _exponent,
        }),
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['application/json'],
        },
      );
    }

    if (path.endsWith('/xtgl/login_logoutAccount.html')) {
      logoutCount += 1;
      _sessionValid = false;
      return ResponseBody.fromString('', 200);
    }

    if (path.endsWith('/xtgl/login_slogin.html') && options.method == 'POST') {
      if (!_sessionValid || forceCaptchaFailure) {
        return ResponseBody.fromString(
          '<html><div id="tips">验证码错误或已过期</div></html>',
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>['text/html; charset=utf-8'],
          },
        );
      }

      return ResponseBody.fromString(
        '',
        302,
        isRedirect: true,
        headers: <String, List<String>>{
          'location': <String>['/jwglxt/xtgl/index_initMenu.html?jsdm=xs'],
        },
      );
    }

    throw UnsupportedError(
      'Unhandled request: ${options.method} ${options.uri}',
    );
  }

  @override
  void close({bool force = false}) {}
}
