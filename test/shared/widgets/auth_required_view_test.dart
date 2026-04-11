import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jiaxing_university_portal/shared/widgets/auth_required_view.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('renders auth prompt and triggers action button', (tester) async {
    var actionTapped = 0;

    await pumpApp(
      tester,
      AuthRequiredView(
        title: '登录后继续',
        message: '请先完成认证',
        buttonLabel: '立即登录',
        onAction: () => actionTapped++,
        icon: Icons.school_outlined,
      ),
    );

    expect(find.text('登录后继续'), findsOneWidget);
    expect(find.text('请先完成认证'), findsOneWidget);
    expect(find.text('立即登录'), findsOneWidget);
    expect(find.byIcon(Icons.school_outlined), findsOneWidget);

    await tester.tap(find.text('立即登录'));
    await tester.pump();

    expect(actionTapped, 1);
  });
}
