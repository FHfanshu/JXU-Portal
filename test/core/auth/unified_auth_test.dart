import 'package:flutter_test/flutter_test.dart';
import 'package:jiaxing_university_portal/core/auth/unified_auth.dart';

void main() {
  group('Unified auth url classifiers', () {
    test('treats CAS login pages as unauthenticated entry pages', () {
      expect(
        isUnifiedAuthLoginEntryUrl(
          'https://newca.zjxu.edu.cn/cas/login?service=https://mobilehall.zjxu.edu.cn',
        ),
        isTrue,
      );
      expect(
        isUnifiedAuthLoginEntryUrl(
          '/cas/login?service=https://mobilehall.zjxu.edu.cn',
        ),
        isTrue,
      );
      expect(
        isUnifiedAuthAuthenticatedUrl(
          'https://newca.zjxu.edu.cn/cas/login?service=https://mobilehall.zjxu.edu.cn',
        ),
        isFalse,
      );
    });

    test('treats downstream service pages as authenticated destinations', () {
      expect(
        isUnifiedAuthAuthenticatedUrl(
          'https://mobilehall.zjxu.edu.cn/mportal/start/index.html#/business/ydd/portal/home',
        ),
        isTrue,
      );
      expect(
        isUnifiedAuthAuthenticatedUrl(
          'https://newca.zjxu.edu.cn/casClient/login/ydd?ticket=abc',
        ),
        isTrue,
      );
      expect(
        isUnifiedAuthAuthenticatedUrl(
          'https://libapp.zjxu.edu.cn/Info/Thirdparty/ssoFromDingDing?ticket=abc',
        ),
        isTrue,
      );
      expect(
        isUnifiedAuthAuthenticatedUrl('/casClient/login/ydd?ticket=abc'),
        isTrue,
      );
    });

    test('extracts downstream service url from CAS login pages', () {
      expect(
        extractUnifiedAuthServiceUrl(
          'https://newca.zjxu.edu.cn/cas/login?service=https%3A%2F%2Flibapp.zjxu.edu.cn%2FInfo%2FThirdparty%2FssoFromDingDing',
        ),
        'https://libapp.zjxu.edu.cn/Info/Thirdparty/ssoFromDingDing',
      );
      expect(
        extractUnifiedAuthServiceUrl(
          'https://newca.zjxu.edu.cn/cas/login?service=https%3A%2F%2Fnewca.zjxu.edu.cn%2FcasClient%2Flogin%2Fydd',
        ),
        'https://newca.zjxu.edu.cn/casClient/login/ydd',
      );
      expect(
        extractUnifiedAuthServiceUrl(
          'https://mobilehall.zjxu.edu.cn/mportal/start/index.html#/business/ydd/portal/home',
        ),
        isNull,
      );
    });
  });

  group('Unified auth login html detection', () {
    test('detects CAS login form markup', () {
      expect(
        looksLikeUnifiedAuthLoginHtml('''
          <html>
            <form id="fm1">
              <input type="hidden" name="lt" value="LT-1" />
              <input type="hidden" name="execution" value="e1s1" />
            </form>
          </html>
        '''),
        isTrue,
      );
    });

    test('ignores downstream service html', () {
      expect(
        looksLikeUnifiedAuthLoginHtml('<html><body>欢迎进入服务大厅</body></html>'),
        isFalse,
      );
    });
  });

  group('UnifiedAuthService session short-circuit', () {
    setUp(() {
      UnifiedAuthService.instance.debugReset();
    });

    test(
      'prepareLogin returns true immediately when session is active',
      () async {
        UnifiedAuthService.instance.debugSetSession(
          active: true,
          account: '1234567890',
        );
        expect(UnifiedAuthService.instance.isLoggedIn, isTrue);

        final result = await UnifiedAuthService.instance.prepareLogin();
        expect(result, isTrue);
      },
    );

    test('isLoggedIn is false after debugReset', () {
      expect(UnifiedAuthService.instance.isLoggedIn, isFalse);
    });

    test('debug session tracks account independently', () {
      UnifiedAuthService.instance.debugSetSession(
        active: true,
        account: '00213544',
      );

      expect(UnifiedAuthService.instance.isLoggedIn, isTrue);
      expect(UnifiedAuthService.instance.currentAccount, '00213544');

      UnifiedAuthService.instance.debugReset();

      expect(UnifiedAuthService.instance.isLoggedIn, isFalse);
      expect(UnifiedAuthService.instance.currentAccount, isNull);
    });
  });
}
