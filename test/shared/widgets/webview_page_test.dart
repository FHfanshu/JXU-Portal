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
}
