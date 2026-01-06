// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:app_targhe/main.dart';

void main() {
  testWidgets('App shows title', (WidgetTester tester) async {
    await tester.pumpWidget(const AppTarghe());

    // Simula il completamento del caricamento impostando isLoading=false nello stato
    final state = tester.state(find.byType(HomePage)) as dynamic;
    state.setState(() => state.isLoading = false);
    await tester.pump();

    expect(find.text('Gestione Targhe'), findsOneWidget);
  });
}
