import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jiaxing_university_portal/shared/widgets/login_shell.dart';

void main() {
  testWidgets('provides material ancestor for embedded text fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginShell(
          title: '登录',
          description: '说明',
          child: Padding(padding: EdgeInsets.all(24), child: TextField()),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget);
  });
}
