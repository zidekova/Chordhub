import 'package:flutter_test/flutter_test.dart';

import 'package:chordhub/main.dart';

void main() {
  testWidgets('ChordHub renders initial screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ChordHubApp());

    expect(find.text('ChordHub'), findsOneWidget);
    expect(find.text('Vybrať priečinok'), findsWidgets);
  });
}
