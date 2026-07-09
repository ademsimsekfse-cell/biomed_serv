import 'dart:io';

import 'package:biomed_serv/main.dart';
import 'package:biomed_serv/providers/technician_provider.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = Directory.systemTemp.createTempSync('biomed_serv_test_');
    Hive.init(tempDir.path);
    await initializeDateFormatting('tr_TR', null);
    await DatabaseService.initDatabase();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('app starts without the legacy counter shell', (tester) async {
    final previousErrorBuilder = ErrorWidget.builder;
    addTearDown(() {
      ErrorWidget.builder = previousErrorBuilder;
    });

    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('first setup technician form renders input fields',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => TechnicianProvider()..init(),
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 760,
              child: FirstSetupTechnicianStep(onSaved: _noop),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(TextFormField), findsNWidgets(6));
    expect(find.text('Kaydet'), findsOneWidget);
  });

  testWidgets('mobile setup wizard skips the desktop storage step',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        Provider<DatabaseService>.value(
          value: DatabaseService(),
          child: const MaterialApp(home: SetupWizardScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Yedek'), findsOneWidget);
      expect(find.text('Klasör'), findsNothing);
      expect(find.text('Teknisyen'), findsOneWidget);
      expect(find.text('Firma'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('desktop setup wizard keeps the storage step', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(
        Provider<DatabaseService>.value(
          value: DatabaseService(),
          child: const MaterialApp(home: SetupWizardScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Klasör'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void _noop() {}
