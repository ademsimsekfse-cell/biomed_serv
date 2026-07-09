import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:biomed_serv/models/company_info.dart';
import 'package:biomed_serv/models/customer.dart';
import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/models/fault_ticket.dart';
import 'package:biomed_serv/models/maintenance_form.dart';
import 'package:biomed_serv/models/service_form.dart';
import 'package:biomed_serv/models/stock.dart';
import 'package:biomed_serv/models/technician.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:biomed_serv/services/storage_location_service.dart';
import 'package:biomed_serv/services/technical_assignment_service.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

class StructuredBackupService {
  StructuredBackupService(
    this._dbService, {
    StorageLocationService? storageLocationService,
  }) : _storageLocationService =
            storageLocationService ?? StorageLocationService();

  final DatabaseService _dbService;
  final StorageLocationService _storageLocationService;
  final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  Future<StructuredBackupResult> createZipBackup({
    String reason = 'Manuel yedek',
  }) async {
    final backupDir = await _storageLocationService.effectiveBackupDirectory();
    final createdAt = DateTime.now();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(createdAt);
    final fileName = 'fejox_bioserv_yedek_$stamp.zip';
    final filePath = '$backupDir${Platform.pathSeparator}$fileName';

    final tableSet = await _buildTables();
    final archive = Archive();

    final excelBytes = _buildExcel(tableSet);
    archive.addFile(ArchiveFile(
      'excel/fejox_bioserv_yedek_$stamp.xlsx',
      excelBytes.length,
      excelBytes,
    ));

    for (final table in tableSet.tables) {
      final csvText = const ListToCsvConverter().convert(table.rows);
      final csvBytes = utf8.encode(csvText);
      archive.addFile(
        ArchiveFile('csv/${table.fileName}.csv', csvBytes.length, csvBytes),
      );
    }

    final manifest = {
      'app': 'Fejox BioServ',
      'producer': 'Fejox',
      'createdAt': createdAt.toIso8601String(),
      'reason': reason,
      'format': 'zip+xlsx+csv',
      'tableCount': tableSet.tables.length,
      'recordCounts': {
        for (final table in tableSet.tables) table.fileName: table.dataCount,
      },
    };
    final manifestBytes =
        utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest));
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw Exception('ZIP yedek olusturulamadi');
    }

    await File(filePath).writeAsBytes(zipBytes, flush: true);
    await _markBackup(createdAt);
    return StructuredBackupResult(
      path: filePath,
      fileName: fileName,
      createdAt: createdAt,
      tableCount: tableSet.tables.length,
      recordCount:
          tableSet.tables.fold(0, (sum, table) => sum + table.dataCount),
    );
  }

  Future<_BackupTableSet> _buildTables() async {
    final assignments = TechnicalAssignmentService();
    await assignments.init();

    final tables = <_BackupTable>[
      _companyTable(_dbService.companyInfoBox.values.toList()),
      _technicianTable(_dbService.techniciansBox.values.toList()),
      _customerTable(_dbService.customersBox.values.toList()),
      _deviceTable(_dbService.devicesBox.values.toList()),
      _serviceFormTable(_dbService.serviceFormsBox.values.toList()),
      _maintenanceFormTable(_dbService.maintenanceFormsBox.values.toList()),
      _faultTicketTable(_dbService.faultTicketsBox.values.toList()),
      _stockTable(_dbService.stocksBox.values.toList()),
      _assignmentTable(assignments.allAssignments),
    ];

    return _BackupTableSet(tables);
  }

  List<int> _buildExcel(_BackupTableSet tableSet) {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', tableSet.tables.first.sheetName);

    for (final table in tableSet.tables) {
      final sheet = excel[table.sheetName];
      for (final row in table.rows) {
        sheet.appendRow(row.map((value) => TextCellValue(value)).toList());
      }
    }

    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('Excel yedek olusturulamadi');
    }
    return bytes;
  }

  _BackupTable _companyTable(List<CompanyInfo> companies) {
    final rows = [
      [
        'firma_adi',
        'vergi_no',
        'vergi_dairesi',
        'adres',
        'telefon',
        'eposta',
        'web',
      ],
      ...companies.map((company) => [
            company.companyName,
            company.taxNumber ?? '',
            company.taxOffice ?? '',
            company.address ?? '',
            company.phone ?? '',
            company.email ?? '',
            company.website ?? '',
          ]),
    ];
    return _BackupTable('Firma', 'firma', rows);
  }

  _BackupTable _technicianTable(List<Technician> technicians) {
    final rows = [
      ['ad', 'soyad', 'unvan', 'telefon', 'eposta', 'adres', 'erisim_kimligi'],
      ...technicians.map((tech) => [
            tech.firstName,
            tech.lastName,
            tech.title ?? '',
            tech.phone ?? '',
            tech.email ?? '',
            tech.address ?? '',
            '${tech.firstName}_${tech.lastName}_${tech.phone ?? tech.email ?? ''}',
          ]),
    ];
    return _BackupTable('Teknisyenler', 'teknisyenler', rows);
  }

  _BackupTable _customerTable(List<Customer> customers) {
    final rows = [
      [
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
      ],
      ...customers.map((customer) => [
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
          ]),
    ];
    return _BackupTable('Musteriler', 'musteriler', rows);
  }

  _BackupTable _deviceTable(List<Device> devices) {
    final rows = [
      [
        'cihaz_adi',
        'marka',
        'model',
        'seri_no',
        'musteri',
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
      ],
      ...devices.map((device) {
        final customer =
            device.customer is Customer ? device.customer as Customer : null;
        final control = device.controlModule is Device
            ? device.controlModule as Device
            : null;
        return [
          device.name,
          device.brand,
          device.model,
          device.serialNumber,
          customer?.name ?? '',
          _moduleType(device.moduleType),
          device.ownershipStatus == OwnershipStatus.rented
              ? 'KIRALIK'
              : 'SATIS',
          control?.serialNumber ?? '',
          _date(device.productionDate),
          _date(device.installationDate),
          device.economicLife?.toString() ?? '',
          device.group ?? '',
          device.barcode ?? '',
          device.serviceDuration?.toString() ?? '',
          _date(device.warrantyStartDate),
          _date(device.warrantyEndDate),
          device.location ?? '',
          device.deviceCategory ?? '',
        ];
      }),
    ];
    return _BackupTable('Cihazlar', 'cihazlar', rows);
  }

  _BackupTable _serviceFormTable(List<ServiceForm> forms) {
    final rows = [
      [
        'form_no',
        'tarih',
        'musteri',
        'cihaz',
        'seri_no',
        'problem',
        'yapilan_islem',
        'son_durum',
        'problem_tipleri',
        'sonuc',
        'ucret_durumu',
        'teknisyen',
        'musteri_yetkilisi',
        'kaynak_ariza_no',
        'toplam_ucret',
        'kdv_dahil_ucret',
      ],
      ...forms.map((form) => [
            form.formNumber,
            _dateTime(form.createdAt),
            form.customer.name,
            form.device.name,
            form.device.serialNumber,
            form.problemDescription ?? '',
            form.actionsTaken ?? '',
            form.finalStatus ?? '',
            form.problemTypes.join(' | '),
            form.resultStatus ?? '',
            form.feeStatus ?? '',
            form.technicianName ?? '',
            form.customerName ?? '',
            form.sourceTicketNumber ?? '',
            form.totalFee?.toStringAsFixed(2) ?? '',
            form.totalFeeWithVAT?.toStringAsFixed(2) ?? '',
          ]),
    ];
    return _BackupTable('ServisFormlari', 'servis_formlari', rows);
  }

  _BackupTable _maintenanceFormTable(List<MaintenanceForm> forms) {
    final rows = [
      [
        'form_no',
        'tarih',
        'musteri',
        'cihaz',
        'seri_no',
        'periyot',
        'islemler',
        'notlar',
        'son_durum',
        'teknisyen',
        'musteri_yetkilisi',
      ],
      ...forms.map((form) => [
            form.formNumber,
            _dateTime(form.createdAt),
            form.customer.name,
            form.device.name,
            form.device.serialNumber,
            form.maintenancePeriod,
            form.actionsTaken.join(' | '),
            form.notes ?? '',
            form.finalStatus ?? '',
            form.technicianName ?? '',
            form.customerName ?? '',
          ]),
    ];
    return _BackupTable('BakimFormlari', 'bakim_formlari', rows);
  }

  _BackupTable _faultTicketTable(List<FaultTicket> tickets) {
    final rows = [
      [
        'ariza_no',
        'bildirim_tarihi',
        'musteri',
        'cihaz',
        'seri_no',
        'tip',
        'oncelik',
        'durum',
        'planlanan_tarih',
        'atanan_teknisyen',
        'problem',
        'yapilan_islem',
        'son_durum',
        'servis_form_no',
      ],
      ...tickets.map((ticket) => [
            ticket.ticketNumber,
            _dateTime(ticket.reportDateTime),
            ticket.customer.name,
            ticket.device.name,
            ticket.device.serialNumber,
            ticket.ticketTypeText,
            ticket.priorityText,
            ticket.statusText,
            _dateTime(ticket.scheduledAt),
            ticket.technicianName ?? ticket.assignedTechnicianId ?? '',
            ticket.problemDescription,
            ticket.actionsTaken ?? '',
            ticket.finalStatus ?? '',
            ticket.serviceFormNumber ?? '',
          ]),
    ];
    return _BackupTable('ArizaKayitlari', 'ariza_kayitlari', rows);
  }

  _BackupTable _stockTable(List<Stock> stocks) {
    final rows = [
      ['parca_adi', 'miktar', 'barkod', 'referans_no', 'kritik_stok'],
      ...stocks.map((stock) => [
            stock.name,
            stock.quantity.toString(),
            stock.barcode ?? '',
            stock.referenceNo ?? '',
            stock.criticalStockThreshold.toString(),
          ]),
    ];
    return _BackupTable('Stoklar', 'stoklar', rows);
  }

  _BackupTable _assignmentTable(List<TechnicalAssignment> assignments) {
    final rows = [
      [
        'hedef_tipi',
        'hedef_kimligi',
        'hedef_adi',
        'teknisyen_kimligi',
        'teknisyen_adi',
        'not',
        'atanma_tarihi',
      ],
      ...assignments.map((assignment) => [
            assignment.targetType,
            assignment.targetId,
            assignment.targetName,
            assignment.technicianId,
            assignment.technicianName,
            assignment.note ?? '',
            _dateTime(assignment.assignedAt),
          ]),
    ];
    return _BackupTable('Atamalar', 'atamalar', rows);
  }

  Future<void> _markBackup(DateTime date) async {
    final prefs = await Hive.openBox(StorageLocationService.prefsBoxName);
    await prefs.put('last_backup', date.toIso8601String());
    await prefs.put('auto_backup_last', date.toIso8601String());
  }

  String _date(DateTime? value) {
    if (value == null) return '';
    return DateFormat('yyyy-MM-dd').format(value);
  }

  String _dateTime(DateTime? value) {
    if (value == null) return '';
    return _dateTimeFormat.format(value);
  }

  String _moduleType(DeviceModuleType type) {
    switch (type) {
      case DeviceModuleType.modularControl:
        return 'KONTROL';
      case DeviceModuleType.modularProcessing:
        return 'MODUL';
      case DeviceModuleType.standalone:
        return 'STANDALONE';
    }
  }
}

class StructuredBackupResult {
  final String path;
  final String fileName;
  final DateTime createdAt;
  final int tableCount;
  final int recordCount;

  const StructuredBackupResult({
    required this.path,
    required this.fileName,
    required this.createdAt,
    required this.tableCount,
    required this.recordCount,
  });
}

class _BackupTableSet {
  final List<_BackupTable> tables;

  const _BackupTableSet(this.tables);
}

class _BackupTable {
  final String sheetName;
  final String fileName;
  final List<List<String>> rows;

  const _BackupTable(this.sheetName, this.fileName, this.rows);

  int get dataCount => rows.isEmpty ? 0 : rows.length - 1;
}
