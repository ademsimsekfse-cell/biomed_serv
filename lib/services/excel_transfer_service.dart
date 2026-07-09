import 'dart:io';

import 'package:biomed_serv/models/customer.dart';
import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/providers/customer_provider.dart';
import 'package:biomed_serv/providers/device_provider.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

enum DeviceExportMode {
  hierarchical,
  simple,
}

enum ExcelImportKind {
  customersAndDevices,
  simpleDevices,
}

class ExcelTransferService {
  static const customerSheet = 'Musteriler';
  static const deviceSheet = 'Cihazlar';
  static const simpleDeviceSheet = 'Basit_Cihaz_Listesi';
  static const deviceRelationSheet = 'Cihaz_Baglantilari';

  static const customerHeaders = [
    'musteri_adi',
    'adres',
    'telefon',
    'yetkili_kisi',
    'eposta',
    'vergi_no',
    'aktif',
    'birim_amiri',
    'birim_amiri_tel',
    'birim_sorumlusu',
    'birim_sorumlusu_tel',
  ];

  static const deviceHeaders = [
    'cihaz_adi',
    'marka',
    'model',
    'seri_no',
    'musteri_adi',
    'modul_tipi',
    'sahiplik',
    'kontrol_unitesi_seri_no',
    'uretim_tarihi',
    'kurulum_tarihi',
    'ekonomik_omur_yil',
    'grup',
    'barkod',
    'hizmet_suresi_ay',
    'garanti_baslangic',
    'garanti_bitis',
    'lokasyon',
    'kategori',
  ];

  static const hierarchyDeviceHeaders = [
    ...deviceHeaders,
    'ana_sistem_adi',
    'ana_sistem_seri_no',
    'bagli_modul_sayisi',
    'hiyerarsi_seviyesi',
  ];

  static const simpleDeviceHeaders = [
    'cihaz_adi',
    'seri_no',
  ];

  static const deviceRelationHeaders = [
    'ana_cihaz_adi',
    'ana_cihaz_seri_no',
    'bagli_cihaz_adi',
    'bagli_cihaz_seri_no',
    'musteri_adi',
    'bagli_modul_sayisi',
  ];

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  Future<String?> exportCustomersAndDevices({
    required List<Customer> customers,
    required List<Device> devices,
    DeviceExportMode mode = DeviceExportMode.hierarchical,
  }) async {
    final excel = Excel.createExcel();

    if (mode == DeviceExportMode.simple) {
      excel.rename('Sheet1', simpleDeviceSheet);
      _writeSimpleDevices(excel[simpleDeviceSheet], devices);
    } else {
      excel.rename('Sheet1', customerSheet);
      _writeCustomers(excel[customerSheet], customers);
      _writeDevices(excel[deviceSheet], devices);
      _writeDeviceRelations(excel[deviceRelationSheet], devices);
    }

    final fileBytes = excel.save();
    if (fileBytes == null) return null;

    final now = DateTime.now();
    final modeName =
        mode == DeviceExportMode.simple ? 'cihaz_basit' : 'hiyerarsik';
    final fileName =
        'biomed_serv_${modeName}_${DateFormat('yyyyMMdd_HHmm').format(now)}.xlsx';

    var outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Excel Dosyasını Kaydet',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (outputFile == null) return null;
    if (!outputFile.toLowerCase().endsWith('.xlsx')) {
      outputFile = '$outputFile.xlsx';
    }

    await File(outputFile).writeAsBytes(fileBytes, flush: true);
    return outputFile;
  }

  Future<ExcelImportResult> importCustomersAndDevices({
    required CustomerProvider customerProvider,
    required DeviceProvider deviceProvider,
  }) async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Excel Dosyası Seç',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (picked == null || picked.files.isEmpty) {
      return ExcelImportResult.cancelled();
    }

    final bytes = picked.files.single.bytes ??
        await File(picked.files.single.path!).readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    final result = ExcelImportResult();
    await _importCustomers(
      excel: excel,
      customerProvider: customerProvider,
      result: result,
    );
    await _importDevices(
      excel: excel,
      customerProvider: customerProvider,
      deviceProvider: deviceProvider,
      result: result,
    );

    return result;
  }

  Future<ExcelImportResult> importSimpleDevices({
    required DeviceProvider deviceProvider,
  }) async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Basit Cihaz Excel Dosyasi Sec',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (picked == null || picked.files.isEmpty) {
      return ExcelImportResult.cancelled();
    }

    final bytes = picked.files.single.bytes ??
        await File(picked.files.single.path!).readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    final result = ExcelImportResult();
    await _importSimpleDevices(
      excel: excel,
      deviceProvider: deviceProvider,
      result: result,
    );
    return result;
  }

  Future<ExcelImportPreview> previewCustomersAndDevicesImport({
    required CustomerProvider customerProvider,
    required DeviceProvider deviceProvider,
  }) async {
    final picked = await _pickExcelFile('Excel Dosyasi Sec');
    if (picked == null) return ExcelImportPreview.cancelled();

    final excel = Excel.decodeBytes(picked.bytes);
    final preview = ExcelImportPreview(
      kind: ExcelImportKind.customersAndDevices,
      fileName: picked.fileName,
      bytes: picked.bytes,
    );
    _previewCustomers(
      excel: excel,
      customerProvider: customerProvider,
      preview: preview,
    );
    _previewDevices(
      excel: excel,
      customerProvider: customerProvider,
      deviceProvider: deviceProvider,
      preview: preview,
    );
    return preview;
  }

  Future<ExcelImportPreview> previewSimpleDevicesImport({
    required DeviceProvider deviceProvider,
  }) async {
    final picked = await _pickExcelFile('Basit Cihaz Excel Dosyasi Sec');
    if (picked == null) return ExcelImportPreview.cancelled();

    final excel = Excel.decodeBytes(picked.bytes);
    final preview = ExcelImportPreview(
      kind: ExcelImportKind.simpleDevices,
      fileName: picked.fileName,
      bytes: picked.bytes,
    );
    _previewSimpleDevices(
      excel: excel,
      deviceProvider: deviceProvider,
      preview: preview,
    );
    return preview;
  }

  Future<ExcelImportResult> importCustomersAndDevicesFromPreview({
    required ExcelImportPreview preview,
    required CustomerProvider customerProvider,
    required DeviceProvider deviceProvider,
  }) async {
    if (preview.cancelled) return ExcelImportResult.cancelled();
    final excel = Excel.decodeBytes(preview.bytes);

    final result = ExcelImportResult();
    await _importCustomers(
      excel: excel,
      customerProvider: customerProvider,
      result: result,
    );
    await _importDevices(
      excel: excel,
      customerProvider: customerProvider,
      deviceProvider: deviceProvider,
      result: result,
    );
    return result;
  }

  Future<ExcelImportResult> importSimpleDevicesFromPreview({
    required ExcelImportPreview preview,
    required DeviceProvider deviceProvider,
  }) async {
    if (preview.cancelled) return ExcelImportResult.cancelled();
    final excel = Excel.decodeBytes(preview.bytes);

    final result = ExcelImportResult();
    await _importSimpleDevices(
      excel: excel,
      deviceProvider: deviceProvider,
      result: result,
    );
    return result;
  }

  void _writeCustomers(Sheet sheet, List<Customer> customers) {
    sheet.appendRow(_cells(customerHeaders));
    for (final customer in customers) {
      sheet.appendRow(_cells([
        customer.name,
        customer.address,
        customer.phone,
        customer.authorizedPerson,
        customer.email ?? '',
        customer.vergiNo ?? '',
        customer.isActive ? 'EVET' : 'HAYIR',
        customer.unitManagerName ?? '',
        customer.unitManagerPhone ?? '',
        customer.unitResponsibleName ?? '',
        customer.unitResponsiblePhone ?? '',
      ]));
    }
  }

  void _writeDevices(Sheet sheet, List<Device> devices) {
    sheet.appendRow(_cells(hierarchyDeviceHeaders));
    for (final device in _sortDevicesForHierarchy(devices)) {
      final customer =
          device.customer is Customer ? device.customer as Customer : null;
      final controlModule = device.controlModule is Device
          ? device.controlModule as Device
          : null;
      final rootDevice = _rootDeviceFor(device, devices);
      final linkedCount = _linkedModulesFor(rootDevice, devices).length;
      final hierarchyLevel = device.isProcessingModule ? '1' : '0';

      sheet.appendRow(_cells([
        device.name,
        device.brand,
        device.model,
        device.serialNumber,
        customer?.name ?? '',
        _moduleTypeToText(device.moduleType),
        device.ownershipStatus == OwnershipStatus.sold ? 'SOLD' : 'RENT',
        controlModule?.serialNumber ?? '',
        _formatDate(device.productionDate),
        _formatDate(device.installationDate),
        device.economicLife?.toString() ?? '',
        device.group ?? '',
        device.barcode ?? '',
        device.serviceDuration?.toString() ?? '',
        _formatDate(device.warrantyStartDate),
        _formatDate(device.warrantyEndDate),
        device.location ?? '',
        device.deviceCategory ?? '',
        rootDevice.name,
        rootDevice.serialNumber,
        linkedCount.toString(),
        hierarchyLevel,
      ]));
    }
  }

  void _writeSimpleDevices(Sheet sheet, List<Device> devices) {
    sheet.appendRow(_cells(simpleDeviceHeaders));
    for (final device in _sortDevicesForHierarchy(devices)) {
      sheet.appendRow(_cells([
        device.name,
        device.serialNumber,
      ]));
    }
  }

  void _writeDeviceRelations(Sheet sheet, List<Device> devices) {
    sheet.appendRow(_cells(deviceRelationHeaders));
    final roots = devices.where((device) => device.isControlModule).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    for (final root in roots) {
      final customer =
          root.customer is Customer ? root.customer as Customer : null;
      final linkedModules = _linkedModulesFor(root, devices);
      for (final linked in linkedModules) {
        sheet.appendRow(_cells([
          root.name,
          root.serialNumber,
          linked.name,
          linked.serialNumber,
          customer?.name ?? '',
          linkedModules.length.toString(),
        ]));
      }
    }
  }

  Future<_PickedExcelFile?> _pickExcelFile(String dialogTitle) async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: dialogTitle,
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (picked == null || picked.files.isEmpty) return null;
    final file = picked.files.single;
    final bytes = file.bytes ?? await File(file.path!).readAsBytes();
    return _PickedExcelFile(fileName: file.name, bytes: bytes);
  }

  void _previewCustomers({
    required Excel excel,
    required CustomerProvider customerProvider,
    required ExcelImportPreview preview,
  }) {
    final sheet = excel.tables[customerSheet];
    if (sheet == null || sheet.rows.length < 2) {
      preview.warnings.add('$customerSheet sayfasi bulunamadi veya bos.');
      return;
    }

    final headers = _headers(sheet.rows.first);
    final knownNames = customerProvider.customers
        .map((customer) => _normalizeText(customer.name))
        .toSet();

    for (var rowIndex = 1; rowIndex < sheet.rows.length; rowIndex++) {
      final row = _rowMap(headers, sheet.rows[rowIndex]);
      if (_isBlankRow(row)) continue;

      final name = _value(row, 'musteri_adi');
      if (name.isEmpty) {
        preview.skippedRows++;
        preview.warnings
            .add('${rowIndex + 1}. satir atlandi: musteri adi bos.');
        continue;
      }

      final normalized = _normalizeText(name);
      if (knownNames.contains(normalized)) {
        preview.updatedCustomers++;
      } else {
        preview.addedCustomers++;
        knownNames.add(normalized);
      }
    }
  }

  void _previewDevices({
    required Excel excel,
    required CustomerProvider customerProvider,
    required DeviceProvider deviceProvider,
    required ExcelImportPreview preview,
  }) {
    final sheet = excel.tables[deviceSheet];
    if (sheet == null || sheet.rows.length < 2) {
      preview.warnings.add('$deviceSheet sayfasi bulunamadi veya bos.');
      return;
    }

    final headers = _headers(sheet.rows.first);
    final knownSerials = deviceProvider.devices
        .map((device) => _normalizeText(device.serialNumber))
        .toSet();
    final customerNames = customerProvider.customers
        .map((customer) => _normalizeText(customer.name))
        .toSet();

    for (var rowIndex = 1; rowIndex < sheet.rows.length; rowIndex++) {
      final row = _rowMap(headers, sheet.rows[rowIndex]);
      if (_isBlankRow(row)) continue;

      final serialNumber = _value(row, 'seri_no');
      final name = _value(row, 'cihaz_adi');
      if (serialNumber.isEmpty || name.isEmpty) {
        preview.skippedRows++;
        preview.warnings.add(
          '${rowIndex + 1}. satir atlandi: cihaz adi ve seri no zorunlu.',
        );
        continue;
      }

      final customerName = _value(row, 'musteri_adi');
      if (customerName.isNotEmpty &&
          !customerNames.contains(_normalizeText(customerName))) {
        preview.warnings.add(
          '$serialNumber seri numarali cihaz icin "$customerName" musterisi bulunamadi.',
        );
      }

      final controlSerial = _value(row, 'kontrol_unitesi_seri_no');
      if (controlSerial.isNotEmpty &&
          !knownSerials.contains(_normalizeText(controlSerial))) {
        preview.warnings.add(
          '$serialNumber cihazi icin "$controlSerial" kontrol unitesi bulunamadi.',
        );
      }

      final normalized = _normalizeText(serialNumber);
      if (knownSerials.contains(normalized)) {
        preview.updatedDevices++;
      } else {
        preview.addedDevices++;
        knownSerials.add(normalized);
      }
    }
  }

  void _previewSimpleDevices({
    required Excel excel,
    required DeviceProvider deviceProvider,
    required ExcelImportPreview preview,
  }) {
    final sheet = excel.tables[simpleDeviceSheet] ??
        excel.tables[deviceSheet] ??
        (excel.tables.isNotEmpty ? excel.tables.values.first : null);

    if (sheet == null || sheet.rows.length < 2) {
      preview.warnings.add('Cihaz listesi sayfasi bulunamadi veya bos.');
      return;
    }

    final headers = _headers(sheet.rows.first);
    final knownSerials = deviceProvider.devices
        .map((device) => _normalizeText(device.serialNumber))
        .toSet();

    for (var rowIndex = 1; rowIndex < sheet.rows.length; rowIndex++) {
      final row = _rowMap(headers, sheet.rows[rowIndex]);
      if (_isBlankRow(row)) continue;

      final name = _firstValue(row, const [
        'cihaz_adi',
        'cihaz adı',
        'cihaz adi',
        'ad',
        'isim',
        'name',
      ]);
      final serialNumber = _firstValue(row, const [
        'seri_no',
        'seri no',
        'seri numarasi',
        'seri numarası',
        'serial',
        'serial_number',
      ]);

      if (name.isEmpty || serialNumber.isEmpty) {
        preview.skippedRows++;
        preview.warnings.add(
          '${rowIndex + 1}. satir atlandi: cihaz adi ve seri no zorunlu.',
        );
        continue;
      }

      final normalized = _normalizeText(serialNumber);
      if (knownSerials.contains(normalized)) {
        preview.updatedDevices++;
      } else {
        preview.addedDevices++;
        knownSerials.add(normalized);
      }
    }
  }

  Future<void> _importCustomers({
    required Excel excel,
    required CustomerProvider customerProvider,
    required ExcelImportResult result,
  }) async {
    final sheet = excel.tables[customerSheet];
    if (sheet == null || sheet.rows.length < 2) {
      result.warnings.add('$customerSheet sayfası bulunamadı veya boş.');
      return;
    }

    final headers = _headers(sheet.rows.first);
    for (var rowIndex = 1; rowIndex < sheet.rows.length; rowIndex++) {
      final row = _rowMap(headers, sheet.rows[rowIndex]);
      final name = _value(row, 'musteri_adi');
      if (name.isEmpty) continue;

      final customer = Customer(
        name: name,
        address: _value(row, 'adres'),
        phone: _value(row, 'telefon'),
        authorizedPerson: _value(row, 'yetkili_kisi'),
        email: _nullable(row, 'eposta'),
        vergiNo: _nullable(row, 'vergi_no'),
        isActive: _parseBool(_value(row, 'aktif'), defaultValue: true),
        unitManagerName: _nullable(row, 'birim_amiri'),
        unitManagerPhone: _nullable(row, 'birim_amiri_tel'),
        unitResponsibleName: _nullable(row, 'birim_sorumlusu'),
        unitResponsiblePhone: _nullable(row, 'birim_sorumlusu_tel'),
      );

      final existing = _findCustomerByName(customerProvider.customers, name);
      if (existing?.key is int) {
        await customerProvider.updateCustomer(existing!.key as int, customer);
        result.updatedCustomers++;
      } else {
        await customerProvider.addCustomer(customer);
        result.addedCustomers++;
      }
    }
  }

  Future<void> _importDevices({
    required Excel excel,
    required CustomerProvider customerProvider,
    required DeviceProvider deviceProvider,
    required ExcelImportResult result,
  }) async {
    final sheet = excel.tables[deviceSheet];
    if (sheet == null || sheet.rows.length < 2) {
      result.warnings.add('$deviceSheet sayfası bulunamadı veya boş.');
      return;
    }

    final headers = _headers(sheet.rows.first);
    for (var rowIndex = 1; rowIndex < sheet.rows.length; rowIndex++) {
      final row = _rowMap(headers, sheet.rows[rowIndex]);
      final serialNumber = _value(row, 'seri_no');
      final name = _value(row, 'cihaz_adi');
      if (serialNumber.isEmpty || name.isEmpty) continue;

      final existing =
          _findDeviceBySerial(deviceProvider.devices, serialNumber);
      final customerName = _value(row, 'musteri_adi');
      final customer =
          _findCustomerByName(customerProvider.customers, customerName);
      if (customerName.isNotEmpty && customer == null) {
        result.warnings.add(
          '$serialNumber seri numaralı cihaz için "$customerName" müşterisi bulunamadı.',
        );
      }

      final controlSerial = _value(row, 'kontrol_unitesi_seri_no');
      final controlModule =
          _findDeviceBySerial(deviceProvider.devices, controlSerial);
      if (controlSerial.isNotEmpty && controlModule == null) {
        result.warnings.add(
          '$serialNumber cihazı için "$controlSerial" kontrol ünitesi bulunamadı.',
        );
      }

      final device = Device(
        name: name,
        brand: _value(row, 'marka'),
        model: _value(row, 'model'),
        serialNumber: serialNumber,
        customer: customer,
        tender: existing?.tender,
        productionDate: _parseDate(_value(row, 'uretim_tarihi')),
        installationDate: _parseDate(_value(row, 'kurulum_tarihi')),
        economicLife: _parseInt(_value(row, 'ekonomik_omur_yil')),
        group: _nullable(row, 'grup'),
        barcode: _nullable(row, 'barkod'),
        moduleType: _parseModuleType(_value(row, 'modul_tipi')),
        ownershipStatus: _parseOwnership(_value(row, 'sahiplik')),
        controlModule: controlModule,
        serviceDuration: _parseInt(_value(row, 'hizmet_suresi_ay')),
        responsiblePerson: existing?.responsiblePerson,
        warrantyStartDate: _parseDate(_value(row, 'garanti_baslangic')),
        warrantyEndDate: _parseDate(_value(row, 'garanti_bitis')),
        location: _nullable(row, 'lokasyon'),
        deviceCategory: _nullable(row, 'kategori'),
      );

      if (existing?.key is int) {
        await deviceProvider.updateDevice(existing!.key as int, device);
        result.updatedDevices++;
      } else {
        await deviceProvider.addDevice(device);
        result.addedDevices++;
      }
    }
  }

  Future<void> _importSimpleDevices({
    required Excel excel,
    required DeviceProvider deviceProvider,
    required ExcelImportResult result,
  }) async {
    final sheet = excel.tables[simpleDeviceSheet] ??
        excel.tables[deviceSheet] ??
        (excel.tables.isNotEmpty ? excel.tables.values.first : null);

    if (sheet == null || sheet.rows.length < 2) {
      result.warnings.add('Cihaz listesi sayfasi bulunamadi veya bos.');
      return;
    }

    final headers = _headers(sheet.rows.first);
    for (var rowIndex = 1; rowIndex < sheet.rows.length; rowIndex++) {
      final row = _rowMap(headers, sheet.rows[rowIndex]);
      final name = _firstValue(row, const [
        'cihaz_adi',
        'cihaz adı',
        'cihaz adi',
        'ad',
        'isim',
        'name',
      ]);
      final serialNumber = _firstValue(row, const [
        'seri_no',
        'seri no',
        'seri numarasi',
        'seri numarası',
        'serial',
        'serial_number',
      ]);

      if (name.isEmpty && serialNumber.isEmpty) continue;
      if (name.isEmpty || serialNumber.isEmpty) {
        result.warnings.add(
          '${rowIndex + 1}. satir atlandi: cihaz adi ve seri no zorunlu.',
        );
        continue;
      }

      final existing =
          _findDeviceBySerial(deviceProvider.devices, serialNumber);
      if (existing?.key is int) {
        existing!.name = name;
        existing.serialNumber = serialNumber;
        await deviceProvider.updateDevice(existing.key as int, existing);
        result.updatedDevices++;
      } else {
        await deviceProvider.addDevice(
          Device(
            name: name,
            brand: '',
            model: '',
            serialNumber: serialNumber,
          ),
        );
        result.addedDevices++;
      }
    }
  }

  List<CellValue> _cells(List<String> values) {
    return values.map((value) => TextCellValue(value)).toList();
  }

  List<String> _headers(List<Data?> row) {
    return row.map(_cellText).map((value) => value.trim()).toList();
  }

  Map<String, String> _rowMap(List<String> headers, List<Data?> row) {
    final map = <String, String>{};
    for (var i = 0; i < headers.length; i++) {
      final value = i < row.length ? _cellText(row[i]).trim() : '';
      final header = headers[i];
      map[header] = value;
      map[_normalizeHeader(header)] = value;
    }
    return map;
  }

  String _cellText(Data? data) {
    final value = data?.value;
    return switch (value) {
      null => '',
      TextCellValue() => value.value.text ?? '',
      IntCellValue() => value.value.toString(),
      DoubleCellValue() => value.value.toString(),
      BoolCellValue() => value.value ? 'EVET' : 'HAYIR',
      DateCellValue() => _dateFormat.format(
          DateTime(value.year, value.month, value.day),
        ),
      DateTimeCellValue() => _dateFormat.format(
          DateTime(
            value.year,
            value.month,
            value.day,
            value.hour,
            value.minute,
            value.second,
          ),
        ),
      TimeCellValue() => '${value.hour}:${value.minute}:${value.second}',
      FormulaCellValue() => value.formula,
    };
  }

  String _value(Map<String, String> row, String key) =>
      (row[key] ?? row[_normalizeHeader(key)] ?? '').trim();

  String _firstValue(Map<String, String> row, List<String> keys) {
    for (final key in keys) {
      final value = _value(row, key);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _normalizeHeader(String value) {
    var normalized = value.trim().toLowerCase();
    normalized = normalized
        .replaceAll('\u0131', 'i')
        .replaceAll('\u015f', 's')
        .replaceAll('\u011f', 'g')
        .replaceAll('\u00fc', 'u')
        .replaceAll('\u00f6', 'o')
        .replaceAll('\u00e7', 'c');
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return normalized.replaceAll(RegExp(r'_+'), '_').replaceAll(
          RegExp(r'^_|_$'),
          '',
        );
  }

  bool _isBlankRow(Map<String, String> row) {
    return row.values.every((value) => value.trim().isEmpty);
  }

  String _normalizeText(String value) => value.trim().toLowerCase();

  String? _nullable(Map<String, String> row, String key) {
    final value = _value(row, key);
    return value.isEmpty ? null : value;
  }

  String _formatDate(DateTime? date) {
    return date == null ? '' : _dateFormat.format(date);
  }

  List<Device> _sortDevicesForHierarchy(List<Device> devices) {
    final sorted = [...devices];
    sorted.sort((a, b) {
      final aRoot = _rootDeviceFor(a, devices);
      final bRoot = _rootDeviceFor(b, devices);
      final rootCompare =
          aRoot.name.toLowerCase().compareTo(bRoot.name.toLowerCase());
      if (rootCompare != 0) return rootCompare;
      if (!a.isProcessingModule && b.isProcessingModule) return -1;
      if (a.isProcessingModule && !b.isProcessingModule) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return sorted;
  }

  Device _rootDeviceFor(Device device, List<Device> devices) {
    if (!device.isProcessingModule) return device;
    final controlModule = device.controlModule;
    if (controlModule is Device) {
      return _findDeviceBySerial(devices, controlModule.serialNumber) ??
          controlModule;
    }
    return device;
  }

  List<Device> _linkedModulesFor(Device root, List<Device> devices) {
    final linked = devices
        .where(
          (device) =>
              device.isProcessingModule &&
              _sameDeviceReference(device.controlModule, root),
        )
        .toList();
    linked.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return linked;
  }

  bool _sameDeviceReference(Object? candidate, Device device) {
    if (candidate is! Device) return false;
    final candidateKey = candidate.key;
    final deviceKey = device.key;
    if (candidateKey != null && deviceKey != null) {
      return candidateKey == deviceKey;
    }
    return candidate.serialNumber.trim().toLowerCase() ==
        device.serialNumber.trim().toLowerCase();
  }

  DateTime? _parseDate(String value) {
    if (value.trim().isEmpty) return null;
    return DateTime.tryParse(value.trim());
  }

  int? _parseInt(String value) {
    if (value.trim().isEmpty) return null;
    return int.tryParse(value.trim());
  }

  bool _parseBool(String value, {required bool defaultValue}) {
    final normalized = value.trim().toUpperCase();
    if (['EVET', 'TRUE', '1', 'AKTIF', 'AKTİF'].contains(normalized)) {
      return true;
    }
    if (['HAYIR', 'FALSE', '0', 'PASIF', 'PASİF'].contains(normalized)) {
      return false;
    }
    return defaultValue;
  }

  String _moduleTypeToText(DeviceModuleType type) {
    switch (type) {
      case DeviceModuleType.standalone:
        return 'STANDALONE';
      case DeviceModuleType.modularControl:
        return 'KONTROL';
      case DeviceModuleType.modularProcessing:
        return 'MODUL';
    }
  }

  DeviceModuleType _parseModuleType(String value) {
    final normalized = value.trim().toUpperCase();
    if (['KONTROL', 'CONTROL', 'MODULARCONTROL'].contains(normalized)) {
      return DeviceModuleType.modularControl;
    }
    if (['MODUL', 'MODÜL', 'MODULE', 'PROCESSING', 'MODULARPROCESSING']
        .contains(normalized)) {
      return DeviceModuleType.modularProcessing;
    }
    return DeviceModuleType.standalone;
  }

  OwnershipStatus _parseOwnership(String value) {
    final normalized = value.trim().toUpperCase();
    if (['RENT', 'KIRALIK', 'KİRALIK'].contains(normalized)) {
      return OwnershipStatus.rented;
    }
    return OwnershipStatus.sold;
  }

  Customer? _findCustomerByName(List<Customer> customers, String name) {
    if (name.trim().isEmpty) return null;
    final target = name.trim().toLowerCase();
    for (final customer in customers) {
      if (customer.name.trim().toLowerCase() == target) return customer;
    }
    return null;
  }

  Device? _findDeviceBySerial(List<Device> devices, String serialNumber) {
    if (serialNumber.trim().isEmpty) return null;
    final target = serialNumber.trim().toLowerCase();
    for (final device in devices) {
      if (device.serialNumber.trim().toLowerCase() == target) return device;
    }
    return null;
  }
}

class _PickedExcelFile {
  final String fileName;
  final List<int> bytes;

  const _PickedExcelFile({
    required this.fileName,
    required this.bytes,
  });
}

class ExcelImportPreview {
  final bool cancelled;
  final ExcelImportKind kind;
  final String fileName;
  final List<int> bytes;
  int addedCustomers;
  int updatedCustomers;
  int addedDevices;
  int updatedDevices;
  int skippedRows;
  final List<String> warnings;

  ExcelImportPreview({
    this.cancelled = false,
    required this.kind,
    required this.fileName,
    required this.bytes,
    this.addedCustomers = 0,
    this.updatedCustomers = 0,
    this.addedDevices = 0,
    this.updatedDevices = 0,
    this.skippedRows = 0,
    List<String>? warnings,
  }) : warnings = warnings ?? [];

  ExcelImportPreview.cancelled()
      : cancelled = true,
        kind = ExcelImportKind.customersAndDevices,
        fileName = '',
        bytes = const [],
        addedCustomers = 0,
        updatedCustomers = 0,
        addedDevices = 0,
        updatedDevices = 0,
        skippedRows = 0,
        warnings = const [];

  int get totalChanged =>
      addedCustomers + updatedCustomers + addedDevices + updatedDevices;

  bool get hasWork => totalChanged > 0;
}

class ExcelImportResult {
  final bool cancelled;
  int addedCustomers;
  int updatedCustomers;
  int addedDevices;
  int updatedDevices;
  final List<String> warnings;

  ExcelImportResult({
    this.cancelled = false,
    this.addedCustomers = 0,
    this.updatedCustomers = 0,
    this.addedDevices = 0,
    this.updatedDevices = 0,
    List<String>? warnings,
  }) : warnings = warnings ?? [];

  ExcelImportResult.cancelled()
      : cancelled = true,
        addedCustomers = 0,
        updatedCustomers = 0,
        addedDevices = 0,
        updatedDevices = 0,
        warnings = const [];

  int get totalChanged =>
      addedCustomers + updatedCustomers + addedDevices + updatedDevices;
}
