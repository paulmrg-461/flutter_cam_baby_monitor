import 'package:flutter_test/flutter_test.dart';

import 'package:baby_monitor/app.dart';

void main() {
  testWidgets('App renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const BabyMonitorApp());
    await tester.pump();

    expect(find.text('Baby Monitor - Servidor'), findsOneWidget);
    expect(find.text('Baby Monitor - Cliente'), findsNothing);
  });
}
