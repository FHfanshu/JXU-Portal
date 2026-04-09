import 'package:flutter_test/flutter_test.dart';
import 'package:jiaxing_university_portal/shared/widgets/webview_page.dart';

void main() {
  group('detectWebViewQuickFillKind', () {
    test('detects zhengfang login page', () {
      expect(
        detectWebViewQuickFillKind(
          'https://jwzx.zjxu.edu.cn/jwglxt/xtgl/login_slogin.html',
        ),
        WebViewQuickFillKind.zhengfang,
      );
    });

    test('detects unified auth login page', () {
      expect(
        detectWebViewQuickFillKind(
          'https://newca.zjxu.edu.cn/cas/login?service=test',
        ),
        WebViewQuickFillKind.unifiedAuth,
      );
    });

    test('ignores non-login pages', () {
      expect(
        detectWebViewQuickFillKind(
          'https://jwzx.zjxu.edu.cn/jwglxt/xtgl/index_initMenu.html?jsdm=xs',
        ),
        isNull,
      );
    });
  });

  group('isServiceHallHomeUrl', () {
    test('detects service hall homepage urls', () {
      expect(
        isServiceHallHomeUrl(
          'https://mobilehall.zjxu.edu.cn/mportal/start/index.html#/business/ydd/portal/home',
        ),
        isTrue,
      );
      expect(
        isServiceHallHomeUrl(
          'https://mobilehall.zjxu.edu.cn/mportal/start/index.html?t=1775743928213#//business/ydd/portal/home',
        ),
        isTrue,
      );
    });

    test('ignores non-home service hall urls', () {
      expect(
        isServiceHallHomeUrl(
          'https://mobilehall.zjxu.edu.cn/mportal/start/index.html#/business/ydd/wfw/id=ED8D7B51A2422411E0532602010A9D8D',
        ),
        isFalse,
      );
      expect(
        isServiceHallHomeUrl(
          'https://newca.zjxu.edu.cn/cas/login?service=https://mobilehall.zjxu.edu.cn',
        ),
        isFalse,
      );
    });
  });

  group('selectLoadedWebViewUrl', () {
    test('prefers controller url over reported url', () {
      expect(
        selectLoadedWebViewUrl(
          fallbackUrl:
              'https://mobilehall.zjxu.edu.cn/mportal/start/index.html#/business/ydd/portal/home',
          reportedUrl:
              'https://newca.zjxu.edu.cn/cas/login?service=https%3A%2F%2Flibapp.zjxu.edu.cn%2FInfo%2FThirdparty%2FssoFromDingDing',
          controllerUrl:
              'https://libapp.zjxu.edu.cn/Info/Thirdparty/ssoFromDingDing?ticket=ST-1',
        ),
        'https://libapp.zjxu.edu.cn/Info/Thirdparty/ssoFromDingDing?ticket=ST-1',
      );
    });

    test('falls back when controller url is unavailable', () {
      expect(
        selectLoadedWebViewUrl(
          fallbackUrl:
              'https://mobilehall.zjxu.edu.cn/mportal/start/index.html#/business/ydd/portal/home',
          reportedUrl:
              'https://newca.zjxu.edu.cn/cas/login?service=https%3A%2F%2Flibapp.zjxu.edu.cn%2FInfo%2FThirdparty%2FssoFromDingDing',
        ),
        'https://newca.zjxu.edu.cn/cas/login?service=https%3A%2F%2Flibapp.zjxu.edu.cn%2FInfo%2FThirdparty%2FssoFromDingDing',
      );
    });
  });
}
