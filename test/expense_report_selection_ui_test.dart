import 'dart:io';

import 'package:biomed_serv/models/customer.dart';
import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/models/expense.dart';
import 'package:biomed_serv/models/expense_report.dart';
import 'package:biomed_serv/models/technician.dart';
import 'package:biomed_serv/providers/expense_provider.dart';
import 'package:biomed_serv/providers/expense_report_provider.dart';
import 'package:biomed_serv/screens/expense_management_screen.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late ExpenseProvider expenseProvider;
  late ExpenseReportProvider reportProvider;

  setUp(() async {
    tempDirectory =
        await Directory.systemTemp.createTemp('biomed_expense_ui_test_');
    Hive.init(tempDirectory.path);
    _registerAdapter(TechnicianAdapter());
    _registerAdapter(CustomerAdapter());
    _registerAdapter(OwnershipStatusAdapter());
    _registerAdapter(DeviceModuleTypeAdapter());
    _registerAdapter(DeviceAdapter());
    _registerAdapter(ExpenseStatusAdapter());
    _registerAdapter(CollectionTypeAdapter());
    _registerAdapter(ExpenseAdapter());
    _registerAdapter(ExpenseReportAdapter());
    await Hive.openBox<Expense>('expenses');
    await Hive.openBox<ExpenseReport>('expense_reports');

    final database = DatabaseService();
    expenseProvider = ExpenseProvider(database);
    reportProvider = ExpenseReportProvider(database);
    final expense = Expense(
      date: DateTime(2026, 6, 30),
      description: 'YOL MASRAFI',
      amount: 250,
    );
    await expenseProvider.addExpense(expense);
    await reportProvider.createReport(
      technician: Technician(firstName: 'Test', lastName: 'Teknisyen'),
      expenseKeys: [expense.key as int],
      reportNumber: 'MASRAF-UI-001',
    );
    await expenseProvider.addExpense(
      Expense(
        date: DateTime(2026, 7, 5),
        description: 'PARÇA MASRAFI',
        amount: 175,
      ),
    );
  });

  tearDown(() async {
    expenseProvider.dispose();
    reportProvider.dispose();
    await Hive.close();
    await tempDirectory.delete(recursive: true);
  });

  testWidgets('long press selects an uncollected report', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: expenseProvider),
          ChangeNotifierProvider.value(value: reportProvider),
        ],
        child: const MaterialApp(home: ExpenseManagementScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rapora Ekle'), findsOneWidget);
    expect(find.text('Düzenle'), findsOneWidget);
    expect(find.text('Sil'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Raporlanan (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Tahsil Et'), findsOneWidget);
    expect(find.text('İptal Et'), findsOneWidget);

    await tester.longPress(find.text('MASRAF-UI-001'));
    await tester.pumpAndSettle();

    expect(find.text('1 rapor seçildi'), findsOneWidget);
    expect(find.text('Tahsil Et'), findsWidgets);
    expect(find.text('İptal Et'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

void _registerAdapter<T>(TypeAdapter<T> adapter) {
  if (!Hive.isAdapterRegistered(adapter.typeId)) {
    Hive.registerAdapter(adapter);
  }
}
