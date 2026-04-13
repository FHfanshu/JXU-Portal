import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jiaxing_university_portal/shared/widgets/balance_card.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('toggles obscured balance and triggers actions', (tester) async {
    var tapped = 0;
    await pumpApp(
      tester,
      BalanceCard(
        balance: 23.5,
        yesterdaySpent: 5.2,
        onPaymentTap: () => tapped++,
      ),
    );

    expect(find.text('23.50'), findsOneWidget);
    expect(find.text('昨日消费 ¥5.20'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pump();
    expect(find.text('****'), findsOneWidget);

    await tester.tap(find.text('付款码'));
    expect(tapped, 1);
  });
}
