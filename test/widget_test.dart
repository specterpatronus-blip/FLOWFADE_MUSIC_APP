import 'package:flutter_test/flutter_test.dart';

import 'package:flowfade/main.dart';

void main() {
  testWidgets('Flowfade boots into the library shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const FlowfadeApp());
    await tester.pump();

    expect(find.text('Library'), findsOneWidget);
  });
}
