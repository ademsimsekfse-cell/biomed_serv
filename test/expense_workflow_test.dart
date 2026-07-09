import 'dart:io';

import 'package:biomed_serv/models/customer.dart';
import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/models/expense.dart';
import 'package:biomed_serv/models/expense_report.dart';
import 'package:biomed_serv/models/technician.dart';
import 'package:biomed_serv/providers/expense_provider.dart';
import 'package:biomed_serv/providers/expense_report_provider.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late ExpenseProvider expenseProvider;
  late ExpenseReportProvider reportProvider;

  setUp(() async {
    tempDirectory =
        await Directory.systemTemp.createTemp('biomed_expense_test_');
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
  });

  tearDown(() async {
    expenseProvider.dispose();
    reportProvider.dispose();
    await Hive.close();
    await tempDirectory.delete(recursive: true);
  });

  test('expense advances from pending to reported and collected', () async {
    final expense = Expense(
      date: DateTime(2026, 6, 28),
      description: 'YOL MASRAFI',
      amount: 100,
    );
    await expenseProvider.addExpense(expense);
    final expenseKey = expense.key as int;

    final technician = Technician(
      firstName: 'Test',
      lastName: 'Teknisyen',
    );
    final report = await reportProvider.createReport(
      technician: technician,
      expenseKeys: [expenseKey],
      reportNumber: 'MASRAF-TEST-001',
    );

    expect(expenseProvider.pendingExpenses, isEmpty);
    expect(
        expenseProvider.reportedExpenses.single.status, ExpenseStatus.reported);
    expect(reportProvider.uncollectedReports.single.reportNumber,
        'MASRAF-TEST-001');
    expect(reportProvider.getReportExpenses(report).single.key, expenseKey);

    await reportProvider.collectReport(
      report.key as int,
      type: CollectionType.eft,
      amount: 40,
    );

    expect(reportProvider.uncollectedReports.single.collectedAmount, 40);
    expect(reportProvider.uncollectedReports.single.remainingAmount, 60);
    expect(
        expenseProvider.reportedExpenses.single.status, ExpenseStatus.reported);

    await reportProvider.collectReport(
      report.key as int,
      type: CollectionType.cash,
      amount: 60,
    );

    expect(reportProvider.uncollectedReports, isEmpty);
    expect(reportProvider.collectedReports.single.isCollected, isTrue);
    expect(expenseProvider.reportedExpenses, isEmpty);
    expect(expenseProvider.collectedExpenses.single.status,
        ExpenseStatus.collected);
  });

  test('cancelling a report returns its expenses to pending', () async {
    final expense = Expense(
      date: DateTime(2026, 7, 5),
      description: 'YEDEK PARÇA',
      amount: 320,
    );
    await expenseProvider.addExpense(expense);

    final report = await reportProvider.createReport(
      technician: Technician(firstName: 'Test', lastName: 'Teknisyen'),
      expenseKeys: [expense.key as int],
      reportNumber: 'MASRAF-TEST-002',
    );

    expect(expenseProvider.pendingExpenses, isEmpty);
    expect(reportProvider.uncollectedReports, hasLength(1));

    await reportProvider.deleteReport(report.key as int);

    expect(reportProvider.reports, isEmpty);
    expect(expenseProvider.pendingExpenses, hasLength(1));
    expect(
        expenseProvider.pendingExpenses.single.status, ExpenseStatus.pending);
    expect(expenseProvider.pendingExpenses.single.reportNumber, isNull);
  });
}

void _registerAdapter<T>(TypeAdapter<T> adapter) {
  if (!Hive.isAdapterRegistered(adapter.typeId)) {
    Hive.registerAdapter(adapter);
  }
}
