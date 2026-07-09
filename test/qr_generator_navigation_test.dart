import 'package:biomed_serv/screens/qr_generator_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('QR type buttons switch the visible form', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: QrGeneratorScreen()),
    );
    await tester.pump();

    expect(find.text('Kartvizit'), findsOneWidget);
    expect(find.text('Web Adresi'), findsOneWidget);

    await tester.tap(find.text('Web Adresi'));
    await tester.pumpAndSettle();

    expect(find.text('Web Sitesi veya Link'), findsOneWidget);
    expect(find.text('URL Adresi'), findsOneWidget);
  });
}
