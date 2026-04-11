import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jiaxing_university_portal/core/update/update_model.dart';
import 'package:jiaxing_university_portal/shared/widgets/update_dialog.dart';

void main() {
  testWidgets('renders release metadata and fallback changelog text', (
    tester,
  ) async {
    final release = AppRelease(
      version: '0.2.3',
      changelog: '',
      downloadUrl: '',
      releaseUrl: 'https://example.com/release',
      publishedAt: DateTime(2026, 4, 11, 9, 30),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showUpdateDialog(context, release),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('发现新版本 v0.2.3'), findsOneWidget);
    expect(find.text('发布时间：2026-04-11 09:30'), findsOneWidget);
    expect(find.text('暂无更新说明'), findsOneWidget);
    expect(find.text('查看版本'), findsOneWidget);
  });
}
