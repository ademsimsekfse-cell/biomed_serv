import 'dart:io';

import 'package:biomed_serv/models/customer.dart';
import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/models/fault_ticket.dart';
import 'package:biomed_serv/providers/fault_ticket_provider.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late FaultTicketProvider provider;

  setUp(() async {
    tempDirectory =
        await Directory.systemTemp.createTemp('biomed_fault_filter_test_');
    Hive.init(tempDirectory.path);
    _registerAdapter(CustomerAdapter());
    _registerAdapter(OwnershipStatusAdapter());
    _registerAdapter(DeviceModuleTypeAdapter());
    _registerAdapter(DeviceAdapter());
    _registerAdapter(TicketStatusAdapter());
    _registerAdapter(TicketTypeAdapter());
    _registerAdapter(FaultTicketAdapter());
    await Hive.openBox<FaultTicket>('fault_tickets');
    provider = FaultTicketProvider(DatabaseService());
  });

  tearDown(() async {
    provider.dispose();
    await Hive.close();
    await tempDirectory.delete(recursive: true);
  });

  test('open and intervention views exclude completed records', () async {
    for (final status in TicketStatus.values) {
      await provider.addTicket(_ticket(status));
    }

    expect(
      provider.openTickets.map((ticket) => ticket.status),
      containsAll([
        TicketStatus.pending,
        TicketStatus.inProgress,
        TicketStatus.waitingPart,
        TicketStatus.devicePassive,
      ]),
    );
    expect(
      provider.openTickets.map((ticket) => ticket.status),
      isNot(contains(TicketStatus.completed)),
    );
    expect(
      provider.interventionTickets.map((ticket) => ticket.status).toSet(),
      {
        TicketStatus.inProgress,
        TicketStatus.waitingPart,
        TicketStatus.devicePassive,
      },
    );
  });
}

FaultTicket _ticket(TicketStatus status) {
  final customer = Customer(
    name: 'Kurum',
    address: 'Adres',
    phone: '0500',
    authorizedPerson: 'Yetkili',
  );
  final device = Device(
    name: 'Cihaz',
    brand: 'Marka',
    model: 'Model',
    serialNumber: 'SN-${status.name}',
    customer: customer,
  );
  return FaultTicket(
    ticketNumber: 'ARZ-${status.name}',
    customer: customer,
    device: device,
    reportDateTime: DateTime(2026, 6, 30),
    ticketType: TicketType.malfunction,
    problemDescription: 'TEST',
    status: status,
    createdAt: DateTime(2026, 6, 30),
  );
}

void _registerAdapter<T>(TypeAdapter<T> adapter) {
  if (!Hive.isAdapterRegistered(adapter.typeId)) {
    Hive.registerAdapter(adapter);
  }
}
