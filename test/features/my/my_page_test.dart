import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jiaxing_university_portal/core/auth/unified_auth.dart';
import 'package:jiaxing_university_portal/core/auth/zhengfang_auth.dart';
import 'package:jiaxing_university_portal/features/my/my_page.dart';
import 'package:jiaxing_university_portal/features/schedule/schedule_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    UnifiedAuthService.instance.debugReset();
    ZhengfangAuth.instance.debugReset();
    await ScheduleService.instance.debugClearCache();
  });

  tearDown(() {
    UnifiedAuthService.instance.debugReset();
    ZhengfangAuth.instance.debugReset();
  });

  testWidgets(
    'shows logged out when restored unified auth session is invalid',
    (tester) async {
      UnifiedAuthService.instance.debugSetSession(
        active: true,
        account: '2025001',
      );
      UnifiedAuthService.instance.debugSessionValidator = (_) async => false;

      await tester.pumpWidget(const MaterialApp(home: MyPage()));
      await tester.pump();
      await tester.pump();

      expect(find.text('统一认证（含一卡通）'), findsOneWidget);
      expect(find.text('已登录'), findsNothing);
      expect(find.text('未登录'), findsOneWidget);
    },
  );

  testWidgets('keeps logged in state when unified auth session validates', (
    tester,
  ) async {
    UnifiedAuthService.instance.debugSetSession(
      active: true,
      account: '2025001',
    );
    UnifiedAuthService.instance.debugSessionValidator = (_) async => true;

    await tester.pumpWidget(const MaterialApp(home: MyPage()));
    await tester.pump();
    await tester.pump();

    expect(find.text('统一认证（含一卡通）'), findsOneWidget);
    expect(find.text('已登录'), findsOneWidget);
  });
}
