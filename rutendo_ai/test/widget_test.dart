import 'package:flutter_test/flutter_test.dart';

import 'package:rutendo_ai/main.dart';

void main() {
  testWidgets('Risk engine demo updates when a scenario is selected', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Risk Engine Demo'), findsOneWidget);
    expect(find.text('Object'), findsOneWidget);
    expect(find.text('chair'), findsOneWidget);
    expect(find.text('Severity'), findsOneWidget);
    expect(find.text('high'), findsOneWidget);

    await tester.tap(find.text('Far bench'));
    await tester.pump();

    expect(find.text('No alert'), findsOneWidget);
    expect(find.text('none'), findsNWidgets(2));
  });
}
