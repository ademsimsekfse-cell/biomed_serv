import 'dart:io';

import 'package:biomed_serv/models/customer.dart';
import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/models/maintenance_form.dart';
import 'package:biomed_serv/models/service_form.dart';
import 'package:biomed_serv/models/stock.dart';
import 'package:biomed_serv/services/pdf_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late Box<Stock> partsBox;

  setUpAll(() async {
    tempDirectory = await Directory.systemTemp.createTemp('biomed_pdf_test_');
    Hive.init(tempDirectory.path);
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(StockAdapter());
    }
    partsBox = await Hive.openBox<Stock>('pdf_test_parts');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tempDirectory.path,
    );
  });

  tearDownAll(() async {
    await partsBox.close();
    await Hive.close();
    await tempDirectory.delete(recursive: true);
  });

  test('long service report is archived as a non-empty PDF', () async {
    final part = Stock(
      name: 'Test yedek parça',
      quantity: 2,
      referenceNo: 'REF-2026',
      barcode: '869000000001',
      criticalStockThreshold: 1,
    );
    await partsBox.add(part);

    final customer = Customer(
      name: 'Test Sağlık Kurumu',
      address: 'Test Mahallesi, Uzun Kurum Adresi No: 10',
      phone: '0212 000 00 00',
      authorizedPerson: 'Kurum Yetkilisi',
    );
    final device = Device(
      name: 'Biyomedikal Test Cihazı',
      brand: 'Fejox',
      model: 'QA-2026',
      serialNumber: 'SN-PDF-001',
      customer: customer,
    );
    final repeatedDescription = List.filled(
      45,
      'Cihaz üzerinde ayrıntılı kontrol gerçekleştirildi ve ölçüm sonuçları '
      'kayıt altına alındı.',
    ).join(' ');
    final form = ServiceForm(
      formNumber: 'SRV-PDF-TEST',
      createdAt: DateTime(2026, 6, 21, 12, 30),
      customer: customer,
      device: device,
      problemDescription: repeatedDescription,
      actionsTaken: 'Secilen islemler: Kontrol, Kalibrasyon, Parca Degisimi\n'
          'Aciklama ve oneriler: $repeatedDescription',
      finalStatus: 'Sonuc durumu: Cihaz Aktif\n'
          'Son durum aciklamasi: Cihaz güvenli biçimde teslim edildi.\n'
          'Dogrulama calismalari: Kontrol Calismasi Yapildi, Hasta Calisildi',
      problemTypes: const ['Arıza', 'Kontrol'],
      problemDateTime: DateTime(2026, 6, 21, 10),
      interventionDateTime: DateTime(2026, 6, 21, 11),
      solutionDateTime: DateTime(2026, 6, 21, 12),
      partsUsed: HiveList<Stock>(partsBox, objects: [part]),
      technicianName: 'Test Teknisyeni',
      customerName: 'Kurum Yetkilisi',
    );

    final file = await PdfService().generateServicePdf(form);

    expect(await file.exists(), isTrue);
    expect(await file.length(), greaterThan(1000));
    expect(file.path, endsWith('.pdf'));
  });

  test('maintenance report with parts is archived as a non-empty PDF',
      () async {
    final part = Stock(
      name: 'Bakım filtresi',
      quantity: 1,
      referenceNo: 'BKM-REF-1',
      criticalStockThreshold: 1,
    );
    await partsBox.add(part);
    final customer = Customer(
      name: 'Bakım Test Kurumu',
      address: 'Test adresi',
      phone: '0312 000 00 00',
      authorizedPerson: 'Bakım Yetkilisi',
    );
    final device = Device(
      name: 'Bakım Test Cihazı',
      brand: 'Fejox',
      model: 'BKM-2026',
      serialNumber: 'SN-BKM-001',
      customer: customer,
    );
    final form = MaintenanceForm(
      formNumber: 'BKM-PDF-TEST',
      createdAt: DateTime(2026, 6, 21, 13),
      customer: customer,
      device: device,
      maintenancePeriod: '6 Ay',
      actionsTaken: const [
        'Genel kontrol',
        'Filtre değişimi',
        'Kalibrasyon',
      ],
      notes: List.filled(20, 'Bakım ölçümleri kayıt altına alındı.').join(' '),
      partsUsed: HiveList<Stock>(partsBox, objects: [part]),
      finalStatus: 'Cihaz aktif ve güvenli biçimde teslim edildi.',
      technicianName: 'Test Teknisyeni',
      customerName: 'Bakım Yetkilisi',
    );

    final file = await PdfService().generateMaintenancePdf(form);

    expect(await file.exists(), isTrue);
    expect(await file.length(), greaterThan(1000));
    expect(file.path, endsWith('.pdf'));
  });
}
