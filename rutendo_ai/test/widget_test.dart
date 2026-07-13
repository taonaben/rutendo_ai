import 'package:flutter_test/flutter_test.dart';

import 'package:rutendo_ai/main.dart';

void main() {
  testWidgets('Risk engine demo renders core controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Start Capture'), findsOneWidget);
    expect(find.text('Replay Latest'), findsOneWidget);
    expect(find.text('Moving'), findsOneWidget);
    expect(find.textContaining('status=Idle'), findsOneWidget);
    expect(find.textContaining('risk=none'), findsOneWidget);

    await tester.tap(find.text('Start Capture'));
    await tester.pump();

    expect(
      find.textContaining('Capture unavailable on this platform'),
      findsOneWidget,
    );
  });
}
