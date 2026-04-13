import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  ThemeMode themeMode = ThemeMode.system,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      themeMode: themeMode,
      home: Scaffold(body: child),
    ),
  );
  await tester.pump();
}

Future<void> pumpPage(
  WidgetTester tester,
  Widget child, {
  ThemeMode themeMode = ThemeMode.system,
}) async {
  await tester.pumpWidget(MaterialApp(themeMode: themeMode, home: child));
  await tester.pump();
}
