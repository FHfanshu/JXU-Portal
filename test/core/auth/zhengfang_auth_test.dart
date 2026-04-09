import 'package:flutter_test/flutter_test.dart';
import 'package:jiaxing_university_portal/core/auth/zhengfang_auth.dart';

void main() {
  tearDown(() {
    ZhengfangAuth.instance.setMode(ZhengfangMode.direct);
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
}
