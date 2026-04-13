import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jiaxing_university_portal/app/text_scale_controller.dart';
import 'package:jiaxing_university_portal/features/settings/settings_page.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await resetTestEnvironment();
  });

  testWidgets('allows changing text scale from settings page', (tester) async {
    await pumpPage(tester, const SettingsPage());

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
