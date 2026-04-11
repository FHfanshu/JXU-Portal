import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jiaxing_university_portal/features/library/library_page.dart';
import 'package:jiaxing_university_portal/shared/widgets/unified_auth_protected_webview_page.dart';

void main() {
  testWidgets('library page uses dedicated unified auth entry', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LibraryPage()));

    final page = tester.widget<UnifiedAuthProtectedWebViewPage>(
      find.byType(UnifiedAuthProtectedWebViewPage),
    );

    expect(page.title, '图书馆');
    expect(
      page.url,
      'https://libapp.zjxu.edu.cn/Info/Thirdparty/ssoFromDingDing',
    );
    expect(
      page.serviceUrl,
      'https://libapp.zjxu.edu.cn/Info/Thirdparty/ssoFromDingDing',
    );
    expect(page.loginDescription, '统一认证登录后可直接进入图书馆，必要时自动补齐 WebVPN 会话');
    expect(page.showWebViewBottomBackButton, isTrue);
  });
}
