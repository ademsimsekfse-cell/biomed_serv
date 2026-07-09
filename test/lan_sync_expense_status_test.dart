import 'dart:io';

import 'package:biomed_serv/models/company_info.dart';
import 'package:biomed_serv/models/customer.dart';
import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/models/expense.dart';
import 'package:biomed_serv/models/expense_report.dart';
import 'package:biomed_serv/models/fault_ticket.dart';
import 'package:biomed_serv/models/maintenance_form.dart';
import 'package:biomed_serv/models/service_form.dart';
import 'package:biomed_serv/models/stock.dart';
import 'package:biomed_serv/models/technician.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:biomed_serv/services/lan_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late DatabaseService database;

  setUp(() async {
    tempDirectory =
        await Directory.systemTemp.createTemp('biomed_lan_expense_test_');
    Hive.init(tempDirectory.path);

    _registerAdapter(TechnicianAdapter());
    _registerAdapter(ExpenseStatusAdapter());
    _registerAdapter(CollectionTypeAdapter());
    _registerAdapter(ExpenseAdapter());
    _registerAdapter(ExpenseReportAdapter());

    await Hive.openBox<CompanyInfo>('company_info');
    await Hive.openBox<Technician>('technicians');
    await Hive.openBox<Customer>('customers');
    await Hive.openBox<Device>('devices');
    await Hive.openBox<ServiceForm>('service_forms');
    await Hive.openBox<MaintenanceForm>('maintenance_forms');
    await Hive.openBox<FaultTicket>('fault_tickets');
    await Hive.openBox<Expense>('expenses');
    await Hive.openBox<ExpenseReport>('expense_reports');
    await Hive.openBox<Stock>('stocks');

    database = DatabaseService();
  });

  tearDown(() async {
    await Hive.close();
    await tempDirectory.delete(recursive: true);
  });

  test('LAN import updates expense and report without creating duplicates',
      () async {
    final sync = LanSyncService(database);
    const createdAt = '2026-06-28T09:30:00.000';

    await sync.importBundle(
      _bundle(
        expenseStatus: 'pending',
        createdAt: createdAt,
      ),
      requireApproval: false,
    );
    expect(database.expensesBox.length, 1);
    expect(database.expensesBox.values.single.status, ExpenseStatus.pending);

    await sync.importBundle(
      _bundle(
        expenseStatus: 'reported',
        createdAt: createdAt,
        reportNumber: 'MASRAF-SYNC-001',
        collectedAmount: 0,
      ),
      requireApproval: false,
    );
    expect(database.expensesBox.length, 1);
    expect(database.expensesBox.values.single.status, ExpenseStatus.reported);
    expect(database.expenseReportsBox.length, 1);

    await sync.importBundle(
      _bundle(
        expenseStatus: 'collected',
        createdAt: createdAt,
        reportNumber: 'MASRAF-SYNC-001',
        collectedAmount: 250,
        isCollected: true,
      ),
      requireApproval: false,
    );
    expect(database.expensesBox.length, 1);
    expect(database.expensesBox.values.single.status, ExpenseStatus.collected);
    expect(database.expenseReportsBox.length, 1);
    expect(database.expenseReportsBox.values.single.isCollected, isTrue);
    expect(database.expenseReportsBox.values.single.collectedAmount, 250);
  });
}

Map<String, dynamic> _bundle({
  required String expenseStatus,
  required String createdAt,
  String? reportNumber,
  double collectedAmount = 0,
  bool isCollected = false,
}) {
  final collectionDate =
      expenseStatus == 'collected' ? '2026-06-28T12:00:00.000' : null;
  return {
    'protocol': 'fejox-bioserv-lan-sync',
    'version': 1,
    'sourceDevice': 'TEST-MOBILE',
    'technician': const {
      'firstName': 'Test',
      'lastName': 'Teknisyen',
      'fullName': 'Test Teknisyen',
      'phone': '05000000000',
      'email': 'test@example.com',
      'title': 'Teknisyen',
    },
    'companyInfo': null,
    'customers': const [],
    'devices': const [],
    'serviceForms': const [],
    'maintenanceForms': const [],
    'faultTickets': const [],
    'expenses': [
      {
        'date': '2026-06-28T08:00:00.000',
        'description': 'YOL MASRAFI',
        'amount': 250.0,
        'customerName': null,
        'deviceSerialNumber': null,
        'status': expenseStatus,
        'collectionType': expenseStatus == 'collected' ? 'eft' : null,
        'collectionDate': collectionDate,
        'collectionNote': expenseStatus == 'collected' ? 'TAM TAHSİLAT' : null,
        'createdAt': createdAt,
        'reportedAt': reportNumber == null ? null : '2026-06-28T10:00:00.000',
        'reportNumber': reportNumber,
      },
    ],
    'expenseReports': reportNumber == null
        ? const []
        : [
            {
              'reportNumber': reportNumber,
              'createdAt': '2026-06-28T10:00:00.000',
              'technician': const {
                'firstName': 'Test',
                'lastName': 'Teknisyen',
                'phone': '05000000000',
                'email': 'test@example.com',
                'title': 'Teknisyen',
              },
              'totalAmount': 250.0,
              'isCollected': isCollected,
              'collectionType': isCollected ? 'eft' : null,
              'collectionDate': collectionDate,
              'collectionNote': isCollected ? 'TAM TAHSİLAT' : null,
              'notes': null,
              'collectedAmount': collectedAmount,
            },
          ],
    'stocks': const [],
  };
}

void _registerAdapter<T>(TypeAdapter<T> adapter) {
  if (!Hive.isAdapterRegistered(adapter.typeId)) {
    Hive.registerAdapter(adapter);
  }
}
