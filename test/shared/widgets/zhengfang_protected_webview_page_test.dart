import 'package:flutter_test/flutter_test.dart';
import 'package:jiaxing_university_portal/shared/widgets/zhengfang_protected_webview_page.dart';

void main() {
  group('isZhengfangLoginUrl', () {
    test('matches direct and webvpn login pages', () {
      expect(
        isZhengfangLoginUrl(
          'https://jwzx.zjxu.edu.cn/jwglxt/xtgl/login_slogin.html',
        ),
        isTrue,
      );
      expect(
        isZhengfangLoginUrl(
          'https://webvpn.zjxu.edu.cn/http/portal/jwglxt/xtgl/login_slogin.html',
        ),
        isTrue,
      );
      expect(isZhengfangLoginUrl('https://webvpn.zjxu.edu.cn/login'), isTrue);
    });

    test('ignores non-login pages', () {
      expect(
        isZhengfangLoginUrl(
          'https://jwzx.zjxu.edu.cn/jwglxt/xtgl/index_initMenu.html?jsdm=xs',
        ),
        isFalse,
      );
      expect(isZhengfangLoginUrl(''), isFalse);
    });
  });
}
