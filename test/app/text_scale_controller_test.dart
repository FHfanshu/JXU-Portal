import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jiaxing_university_portal/app/text_scale_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TextScaleController.instance.debugReset();
  });

  testWidgets('loads stored text scale factor during init', (tester) async {
    SharedPreferences.setMockInitialValues({'text_scale_factor': 0.85});

    await TextScaleController.instance.init();

    expect(TextScaleController.instance.textScaleFactor.value, 0.85);
  });

  testWidgets('persists selected text scale factor', (tester) async {
    await TextScaleController.instance.setTextScaleFactor(0.95);

    TextScaleController.instance.debugReset();
    await TextScaleController.instance.init();

    expect(TextScaleController.instance.textScaleFactor.value, 0.95);
  });

  testWidgets('caps oversized text scale factor at max threshold', (
    tester,
  ) async {
    await TextScaleController.instance.setTextScaleFactor(1.5);

    expect(
      TextScaleController.instance.textScaleFactor.value,
      TextScaleController.maxScaleFactor,
    );
  });

  testWidgets('app text scale scope adjusts system text scaling', (
    tester,
  ) async {
    double? scaledFontSize;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AppTextScaleScope(
            scaleFactor: 0.8,
            child: Builder(
              builder: (context) {
                scaledFontSize = MediaQuery.textScalerOf(context).scale(10);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );

    expect(scaledFontSize, closeTo(12.0, 0.001));
  });
}
