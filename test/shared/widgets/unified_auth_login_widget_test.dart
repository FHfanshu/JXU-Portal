import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiaxing_university_portal/core/auth/unified_auth.dart';
import 'package:jiaxing_university_portal/shared/widgets/unified_auth_login_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    UnifiedAuthService.instance.debugReset();
  });

  testWidgets('skips captcha when sessionPreflight returns true', (
    tester,
  ) async {
    var loginSucceeded = false;
    var captchaRequested = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UnifiedAuthLoginWidget(
            onLoginSuccess: () => loginSucceeded = true,
            loadSavedCredentials: () async => ('', ''),
            sessionPreflight: () async => true,
            captchaLoader: () async {
              captchaRequested = true;
              return Uint8List(0);
            },
          ),
        ),
      ),
    );

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (loginSucceeded) break;
    }

    expect(loginSucceeded, isTrue);
    expect(captchaRequested, isFalse);
  });

  testWidgets(
    'skips network call and captcha when isLoggedIn is already true',
    (tester) async {
      var loginSucceeded = false;
      var captchaRequested = false;
      var preflightCalled = false;

      UnifiedAuthService.instance.debugSetSession(
        active: true,
        account: '1234567890',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnifiedAuthLoginWidget(
              onLoginSuccess: () => loginSucceeded = true,
              loadSavedCredentials: () async => ('', ''),
              sessionPreflight: () async {
                preflightCalled = true;
                return true;
              },
              captchaLoader: () async {
                captchaRequested = true;
                return Uint8List(0);
              },
            ),
          ),
        ),
      );

      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (loginSucceeded) break;
      }

      expect(loginSucceeded, isTrue);
      expect(captchaRequested, isFalse);
      expect(preflightCalled, isFalse);
    },
  );

  testWidgets('hides title block when showHeader is false', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UnifiedAuthLoginWidget(
            onLoginSuccess: () {},
            showHeader: false,
            loadSavedCredentials: () async => ('', ''),
            sessionPreflight: () async => true,
          ),
        ),
      ),
    );

    expect(find.text('登录统一认证'), findsNothing);
    expect(find.text('账号为校园一卡通号'), findsNothing);
  });
}
