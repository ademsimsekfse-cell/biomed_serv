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
        await Directory.systemTemp.createTemp('biomed_fault_merge_test_');
    Hive.init(tempDirectory.path);

    _registerAdapter(CustomerAdapter());
    _registerAdapter(DeviceAdapter());
    _registerAdapter(DeviceModuleTypeAdapter());
    _registerAdapter(OwnershipStatusAdapter());
    _registerAdapter(TicketStatusAdapter());
    _registerAdapter(TicketTypeAdapter());
    _registerAdapter(FaultTicketAdapter());

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

  test('newer desktop assignment updates the existing mobile ticket', () async {
    final sync = LanSyncService(database);

    final firstResult = await sync.importBundle(
      _bundle(
        updatedAt: '2026-07-06T08:00:00.000',
        status: 'pending',
        assignedTechnicianId: null,
      ),
      requireApproval: false,
    );
    expect(firstResult.faultTicketsAdded, 1);
    expect(database.faultTicketsBox.length, 1);

    final updateResult = await sync.importBundle(
      _bundle(
        updatedAt: '2026-07-06T10:00:00.000',
        status: 'inProgress',
        assignedTechnicianId: 'TECH-ADA-001',
      ),
      requireApproval: false,
    );

    final ticket = database.faultTicketsBox.values.single;
    expect(database.faultTicketsBox.length, 1);
    expect(updateResult.recordsUpdated, 1);
    expect(ticket.status, TicketStatus.inProgress);
    expect(ticket.assignedTechnicianId, 'TECH-ADA-001');
    expect(ticket.technicianName, 'Ada Teknisyen');
    expect(ticket.priority, 'urgent');
  });
}

Map<String, dynamic> _bundle({
  required String updatedAt,
  required String status,
  required String? assignedTechnicianId,
}) {
  return {
    'protocol': 'fejox-bioserv-lan-sync',
    'version': 1,
    'sourceDevice': 'TEST-DESKTOP',
    'technician': null,
    'companyInfo': null,
    'customers': [
      {
        'name': 'Test Hastanesi',
        'address': 'Ankara',
        'phone': '03120000000',
        'authorizedPerson': 'Test Sorumlu',
      },
    ],
    'devices': [
      {
        'name': 'Hasta Basi Monitoru',
        'brand': 'Test',
        'model': 'M1',
        'serialNumber': 'SN-100',
        'customerName': 'Test Hastanesi',
        'moduleType': 'standalone',
        'ownershipStatus': 'sold',
      },
    ],
    'serviceForms': const [],
    'maintenanceForms': const [],
    'faultTickets': [
      {
        'ticketNumber': 'ARZ-TEST-001',
        'customerName': 'Test Hastanesi',
        'deviceSerialNumber': 'SN-100',
        'technicianName': assignedTechnicianId == null ? null : 'Ada Teknisyen',
        'reportDateTime': '2026-07-06T07:30:00.000',
        'ticketType': 'malfunction',
        'problemDescription': 'Ekran acilmiyor',
        'status': status,
        'createdAt': '2026-07-06T07:30:00.000',
        'updatedAt': updatedAt,
        'assignedTechnicianId': assignedTechnicianId,
        'priority': assignedTechnicianId == null ? 'normal' : 'urgent',
      },
    ],
    'expenses': const [],
    'expenseReports': const [],
    'stocks': const [],
  };
}

void _registerAdapter<T>(TypeAdapter<T> adapter) {
  if (!Hive.isAdapterRegistered(adapter.typeId)) {
    Hive.registerAdapter(adapter);
  }
}
