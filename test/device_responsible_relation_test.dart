import 'dart:io';

import 'package:biomed_serv/models/customer.dart';
import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/models/device_personel.dart';
import 'package:biomed_serv/providers/device_personel_provider.dart';
import 'package:biomed_serv/providers/device_provider.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late DeviceProvider provider;
  late Box<Customer> customers;
  late Box<DevicePersonel> people;

  setUp(() async {
    tempDirectory =
        await Directory.systemTemp.createTemp('biomed_device_relation_test_');
    Hive.init(tempDirectory.path);
    _registerAdapter(CustomerAdapter());
    _registerAdapter(OwnershipStatusAdapter());
    _registerAdapter(DeviceModuleTypeAdapter());
    _registerAdapter(DevicePersonelAdapter());
    _registerAdapter(DeviceAdapter());

    customers = await Hive.openBox<Customer>('customers');
    people = await Hive.openBox<DevicePersonel>('device_personels');
    await Hive.openBox<Device>('devices');
    provider = DeviceProvider(DatabaseService());
  });

  tearDown(() async {
    provider.dispose();
    await Hive.close();
    await tempDirectory.delete(recursive: true);
  });

  test('same name with a different phone is not treated as the same person',
      () async {
    final firstCustomer = _customer('A Kurumu');
    final secondCustomer = _customer('B Kurumu');
    await customers.addAll([firstCustomer, secondCustomer]);

    final firstPerson = DevicePersonel(
      firstName: 'Ali',
      lastName: 'Yılmaz',
      phone: '0500 111 22 33',
      customer: firstCustomer,
    );
    await people.add(firstPerson);
    await provider.addDevice(
      Device(
        name: 'Cihaz A',
        brand: 'Marka',
        model: 'Model',
        serialNumber: 'SN-A',
        customer: firstCustomer,
        responsiblePerson: firstPerson,
      ),
    );

    final differentPerson = DevicePersonel(
      firstName: 'Ali',
      lastName: 'Yılmaz',
      phone: '0500 999 88 77',
      customer: secondCustomer,
    );
    final target = Device(
      name: 'Cihaz B',
      brand: 'Marka',
      model: 'Model',
      serialNumber: 'SN-B',
      customer: secondCustomer,
    );

    expect(
      provider.hasResponsiblePersonConflict(
        personel: differentPerson,
        targetDevice: target,
        targetCustomer: secondCustomer,
      ),
      isFalse,
    );
  });

  test('removing institution clears the responsible person', () async {
    final customer = _customer('A Kurumu');
    await customers.add(customer);
    final person = DevicePersonel(
      firstName: 'Ayşe',
      lastName: 'Kaya',
      phone: '0500 123 45 67',
      customer: customer,
    );
    await people.add(person);
    final device = await provider.addDevice(
      Device(
        name: 'Cihaz',
        brand: 'Marka',
        model: 'Model',
        serialNumber: 'SN-C',
        customer: customer,
        responsiblePerson: person,
      ),
    );

    await provider.assignCustomerToDeviceChain(device.key as int, null);

    expect(provider.devices.single.customer, isNull);
    expect(provider.devices.single.responsiblePerson, isNull);
  });

  test('assigning a control unit to an institution moves linked modules',
      () async {
    final customer = _customer('A Kurumu');
    await customers.add(customer);

    final control = await provider.addDevice(
      Device(
        name: 'Kontrol',
        brand: 'Marka',
        model: 'Model',
        serialNumber: 'CTRL-1',
        moduleType: DeviceModuleType.modularControl,
      ),
    );
    await provider.addDevice(
      Device(
        name: 'Modul',
        brand: 'Marka',
        model: 'Model',
        serialNumber: 'MOD-1',
        moduleType: DeviceModuleType.modularProcessing,
        controlModule: control,
      ),
    );

    await provider.assignCustomerToDeviceChain(control.key as int, customer);

    expect(provider.devices, hasLength(2));
    for (final device in provider.devices) {
      expect((device.customer as Customer?)?.key, customer.key);
    }
  });

  test('personel list allows unassigned people but excludes other institutions',
      () async {
    final firstCustomer = _customer('A Kurumu');
    final secondCustomer = _customer('B Kurumu');
    await customers.addAll([firstCustomer, secondCustomer]);

    final assignedToFirst = DevicePersonel(
      firstName: 'Ali',
      lastName: 'Kaya',
      customer: firstCustomer,
    );
    final assignedToSecond = DevicePersonel(
      firstName: 'Ayse',
      lastName: 'Demir',
      customer: secondCustomer,
    );
    final unassigned = DevicePersonel(
      firstName: 'Veli',
      lastName: 'Bos',
    );
    await people.addAll([assignedToFirst, assignedToSecond, unassigned]);

    final personelProvider = DevicePersonelProvider(DatabaseService());
    final available =
        personelProvider.availablePersonelsForCustomer(firstCustomer);

    expect(available.map((person) => person.fullName), contains('Ali Kaya'));
    expect(available.map((person) => person.fullName), contains('Veli Bos'));
    expect(
      available.map((person) => person.fullName),
      isNot(contains('Ayse Demir')),
    );
  });

  test('personel cannot be assigned to a device in another institution',
      () async {
    final firstCustomer = _customer('A Kurumu');
    final secondCustomer = _customer('B Kurumu');
    await customers.addAll([firstCustomer, secondCustomer]);

    final person = DevicePersonel(
      firstName: 'Selim',
      lastName: 'Usta',
      customer: firstCustomer,
    );

    expect(
      () => provider.addDevice(
        Device(
          name: 'Yanlis Cihaz',
          brand: 'Marka',
          model: 'Model',
          serialNumber: 'SN-WRONG',
          customer: secondCustomer,
          responsiblePerson: person,
        ),
      ),
      throwsA(isA<DeviceValidationException>()),
    );
  });
}

Customer _customer(String name) {
  return Customer(
    name: name,
    address: 'Adres',
    phone: '0500 000 00 00',
    authorizedPerson: 'Yetkili',
  );
}

void _registerAdapter<T>(TypeAdapter<T> adapter) {
  if (!Hive.isAdapterRegistered(adapter.typeId)) {
    Hive.registerAdapter(adapter);
  }
}
