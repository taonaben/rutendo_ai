import 'package:flutter_test/flutter_test.dart';

import 'package:rutendo_ai/main.dart';

void main() {
  testWidgets('Risk engine demo shows camera and model integration status', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Rutendo AI Vision'), findsOneWidget);
    expect(find.text('Camera Preview'), findsOneWidget);
    expect(find.text('ONNX Model'), findsOneWidget);
    expect(find.text('Live Detection'), findsOneWidget);
    expect(find.text('Not active yet'), findsOneWidget);
    expect(find.text('Risk engine'), findsOneWidget);
    expect(find.text('Ready for real detections'), findsOneWidget);
  });
}
