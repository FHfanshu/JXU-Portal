import 'package:flutter_test/flutter_test.dart';
import 'package:jiaxing_university_portal/core/auth/zhengfang_auth.dart';

void main() {
  tearDown(() {
    ZhengfangAuth.instance.setMode(ZhengfangMode.direct);
    ZhengfangAuth.instance.debugReset();
  });

  group('ZhengfangAuth portal urls', () {
    test('builds direct portal urls in direct mode', () {
      ZhengfangAuth.instance.setMode(ZhengfangMode.direct);

      expect(
        ZhengfangAuth.instance.buildPortalUrl(
          '/xtgl/index_initMenu.html',
          queryParameters: {'jsdm': 'xs'},
        ),
        'https://jwzx.zjxu.edu.cn/jwglxt/xtgl/index_initMenu.html?jsdm=xs',
      );
    });

    test('builds webvpn portal urls in webvpn mode', () {
      ZhengfangAuth.instance.setMode(ZhengfangMode.webVpn);

      expect(
        ZhengfangAuth.instance.buildPortalUrl(
          '/xtgl/index_initMenu.html',
          queryParameters: {'jsdm': 'xs'},
        ),
        'https://webvpn.zjxu.edu.cn/http/77726476706e69737468656265737421fae05b84692a62486b468ca88d1b203b/jwglxt/xtgl/index_initMenu.html?jsdm=xs',
      );
    });

    test('rewrites direct jwglxt urls to webvpn urls in webvpn mode', () {
      ZhengfangAuth.instance.setMode(ZhengfangMode.webVpn);

      expect(
        ZhengfangAuth.instance.resolvePortalUrl(
          'https://jwzx.zjxu.edu.cn/jwglxt/xtgl/index_initMenu.html?jsdm=xs',
        ),
        ZhengfangAuth.instance.academicServiceUrl,
      );
    });

    test('builds generic webvpn proxy urls for external services', () {
      expect(
        ZhengfangAuth.instance.buildWebVpnProxyUrl(
          'https://twdekt.zjxu.edu.cn/dekt/wx/index?_WXFTL=0',
        ),
        'https://webvpn.zjxu.edu.cn/https/77726476706e69737468656265737421e4e045992c24264a74109ce29d51367bc8e6/dekt/wx/index?_WXFTL=0',
      );
      expect(
        ZhengfangAuth.instance.buildWebVpnProxyUrl(
          'https://libapp.zjxu.edu.cn/Info/Thirdparty/ssoFromDingDing',
        ),
        'https://webvpn.zjxu.edu.cn/https/77726476706e69737468656265737421fcfe439d3720264a74109ce29d51367b2b47/Info/Thirdparty/ssoFromDingDing',
      );
    });
  });

  group('zhengfang auth url classifiers', () {
    test('treats webvpn gateway login as unauthenticated entry', () {
      expect(
        isZhengfangLoginEntryUrl('https://webvpn.zjxu.edu.cn/login'),
        isTrue,
      );
      expect(
        isZhengfangAuthenticatedUrl('https://webvpn.zjxu.edu.cn/login'),
        isFalse,
      );
    });

    test('treats index pages as authenticated destinations', () {
      expect(
        isZhengfangAuthenticatedUrl(
          'https://webvpn.zjxu.edu.cn/http/portal/jwglxt/xtgl/index_initMenu.html?jsdm=xs',
        ),
        isTrue,
      );
    });
  });

  group('zhengfang auth html classifiers', () {
    test('recognizes the real login form html', () {
      const loginHtml = '''
<title>教学管理信息服务平台</title>
<form action="/jwglxt/xtgl/login_slogin.html" method="post">
  <input type="hidden" id="csrftoken" name="csrftoken" value="token" />
  <h5>用户登录</h5>
  <input type="text" class="form-control" name="yhm" id="yhm" />
  <input type="text" class="form-control" name="mm" id="mm" />
  <input name="yzm" type="text" id="yzm" class="form-control" />
  <button type="button" id="dl">登 录</button>
</form>
<script src="/jwglxt/js/globalweb/login/login.js"></script>
''';

      expect(looksLikeZhengfangLoginHtml(loginHtml), isTrue);
    });

    test('does not treat authenticated home html as login page', () {
      const authenticatedHtml = '''
<title>教学管理信息服务平台</title>
<div>欢迎使用嘉兴大学教学综合服务平台</div>
<a href="/jwglxt/xtgl/index_initMenu.html?jsdm=xs">首页</a>
<script>window.user = { name: '测试同学' };</script>
''';

      expect(looksLikeZhengfangLoginHtml(authenticatedHtml), isFalse);
    });
  });

  group('zhengfang auth login result parsing', () {
    test('accepts relative redirect target as authenticated result', () {
      expect(
        isZhengfangAuthenticatedUrl('/jwglxt/xtgl/index_initMenu.html?jsdm=xs'),
        isTrue,
      );
    });

    test('does not treat relative login entry as authenticated result', () {
      expect(
        isZhengfangLoginEntryUrl('/jwglxt/xtgl/login_slogin.html'),
        isTrue,
      );
      expect(
        isZhengfangAuthenticatedUrl('/jwglxt/xtgl/login_slogin.html'),
        isFalse,
      );
    });
  });
}
