import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jiaxing_university_portal/app/text_scale_controller.dart';
import 'package:jiaxing_university_portal/core/update/update_checker.dart';
import 'package:jiaxing_university_portal/core/update/update_service.dart';
import 'package:jiaxing_university_portal/features/settings/settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: '嘉兴大学-校园门户',
      packageName: 'test.package',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: 'test',
    );
    TextScaleController.instance.debugReset();
    UpdateService.instance.debugReset();
    UpdateChecker.instance.debugReset();
  });

  testWidgets('allows changing text scale from settings page', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
    await tester.pump();

    expect(find.text('应用字号'), findsOneWidget);
    expect(find.text('上限 120%'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('检查更新'), 300);
    expect(find.text('检查更新'), findsOneWidget);

    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged?.call(1.15);
    await tester.pump();

    expect(TextScaleController.instance.textScaleFactor.value, 1.15);
  });
}
