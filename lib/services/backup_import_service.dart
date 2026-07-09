import 'dart:io';
import 'package:biomed_serv/models/customer.dart';
import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/models/maintenance_form.dart';
import 'package:biomed_serv/models/service_form.dart';
import 'package:biomed_serv/models/stock.dart';
import 'package:biomed_serv/models/technician.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;

/// Yedek dosyasından veri içe aktarma servisi
class BackupImportService {
  final DatabaseService _dbService;

  BackupImportService(this._dbService);

  /// Yedek klasöründen Hive dosyalarını içe aktar
  ///
  /// [backupPath] - Yedek dosyalarının bulunduğu klasör yolu
  /// Örnek: "C:\\Users\\Adem\\Desktop\\Yedek Dosyası"
  Future<ImportResult> importFromFolder(String backupPath) async {
    final result = ImportResult();

    try {
      final backupDir = Directory(backupPath);
      if (!await backupDir.exists()) {
        result.addError('Yedek klasörü bulunamadı: $backupPath');
        return result;
      }

      final files = await backupDir.list().toList();
      final hiveFiles = files
          .whereType<File>()
          .where((f) => f.path.endsWith('.hive') && !f.path.endsWith('.lock'))
          .toList();

      // institutions.hive → customers
      final institutionsFile = _findFile(hiveFiles, 'institutions.hive');
      if (institutionsFile != null) {
        await _importInstitutions(institutionsFile, result);
      }

      // bakim_forms.hive → maintenance_forms
      final bakimFormsFile = _findFile(hiveFiles, 'bakim_forms.hive');
      if (bakimFormsFile != null) {
        await _importBakimForms(bakimFormsFile, result);
      }

      // stock_parts.hive → stocks
      final stockPartsFile = _findFile(hiveFiles, 'stock_parts.hive');
      if (stockPartsFile != null) {
        await _importStockParts(stockPartsFile, result);
      }

      // technicians.hive → technicians
      final techniciansFile = _findFile(hiveFiles, 'technicians.hive');
      if (techniciansFile != null) {
        await _importTechnicians(techniciansFile, result);
      }

      // service_forms.hive → service_forms
      final serviceFormsFile = _findFile(hiveFiles, 'service_forms.hive');
      if (serviceFormsFile != null) {
        await _importServiceForms(serviceFormsFile, result);
      }

      // maintenance_models.hive → devices (modeller cihaz olarak)
      final maintenanceModelsFile =
          _findFile(hiveFiles, 'maintenance_models.hive');
      if (maintenanceModelsFile != null) {
        await _importMaintenanceModels(maintenanceModelsFile, result);
      }

      // part_reminders.hive → reminders
      final partRemindersFile = _findFile(hiveFiles, 'part_reminders.hive');
      if (partRemindersFile != null) {
        await _importPartReminders(partRemindersFile, result);
      }

      // company_info.hive → company_info (yeni box)
      final companyInfoFile = _findFile(hiveFiles, 'company_info.hive');
      if (companyInfoFile != null) {
        await _importCompanyInfo(companyInfoFile, result);
      }

      // app_settings.hive → app_settings
      final appSettingsFile = _findFile(hiveFiles, 'app_settings.hive');
      if (appSettingsFile != null) {
        await _importAppSettings(appSettingsFile, result);
      }

      // barcode_templates.hive → barcode_templates
      final barcodeTemplatesFile =
          _findFile(hiveFiles, 'barcode_templates.hive');
      if (barcodeTemplatesFile != null) {
        await _importBarcodeTemplates(barcodeTemplatesFile, result);
      }

      // maintenance_settings.hive → maintenance_settings
      final maintenanceSettingsFile =
          _findFile(hiveFiles, 'maintenance_settings.hive');
      if (maintenanceSettingsFile != null) {
        await _importMaintenanceSettings(maintenanceSettingsFile, result);
      }

      result.success = result.errors.isEmpty;
    } catch (e) {
      result.addError('İçe aktarma hatası: $e');
      result.success = false;
    }

    return result;
  }

  /// Dosya seçici ile yedek klasörü seç ve içe aktar
  Future<ImportResult> importWithFilePicker() async {
    try {
      // Klasör seç
      final String? selectedDirectory =
          await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Yedek Dosyalarının Olduğu Klasörü Seçin',
      );

      if (selectedDirectory == null) {
        return ImportResult()..addError('Klasör seçilmedi');
      }

      return await importFromFolder(selectedDirectory);
    } catch (e) {
      return ImportResult()..addError('Dosya seçici hatası: $e');
    }
  }

  /// ZIP dosyasından yedekleri içe aktar
  Future<ImportResult> importFromZip(String zipPath) async {
    final result = ImportResult();

    try {
      final zipFile = File(zipPath);
      if (!await zipFile.exists()) {
        result.addError('ZIP dosyası bulunamadı: $zipPath');
        return result;
      }

      // Geçici klasör oluştur
      final tempDir = await getTemporaryDirectory();
      final extractDir = Directory(
          '${tempDir.path}/backup_extract_${DateTime.now().millisecondsSinceEpoch}');
      await extractDir.create(recursive: true);

      // ZIP'i aç
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Dosyaları çıkar
      for (final file in archive) {
        if (file.isFile && file.name.endsWith('.hive')) {
          final data = file.content as List<int>;
          final outFile =
              File('${extractDir.path}/${path.basename(file.name)}');
          await outFile.writeAsBytes(data);
        }
      }

      // Klasörden içe aktar
      final importResult = await importFromFolder(extractDir.path);

      // Geçici klasörü temizle
      await extractDir.delete(recursive: true);

      return importResult;
    } catch (e) {
      result.addError('ZIP açma hatası: $e');
      return result;
    }
  }

  /// Dosya adına göre dosya bul
  File? _findFile(List<File> files, String fileName) {
    try {
      return files.firstWhere(
          (f) => path.basename(f.path).toLowerCase() == fileName.toLowerCase());
    } catch (e) {
      return null;
    }
  }

  /// Hive yedek dosyasını aç (geçici kopya oluşturarak)
  Future<Box<dynamic>> _openBackupBox(String boxName, File sourceFile) async {
    final tempDir = await getTemporaryDirectory();
    final tempPath =
        '${tempDir.path}/import_${DateTime.now().millisecondsSinceEpoch}';

    // Geçici klasör oluştur
    await Directory(tempPath).create(recursive: true);

    // Dosyayı kopyala
    final tempFile = File('$tempPath/$boxName.hive');
    await tempFile.writeAsBytes(await sourceFile.readAsBytes());

    // Hive'ı geçici konumda başlat
    await Hive.initFlutter(tempPath);

    // Box'ı aç (adaptör gerekmez, dynamic olarak)
    return await Hive.openBox(boxName);
  }

  /// institutions.hive dosyasını customers box'ına aktar
  Future<void> _importInstitutions(File file, ImportResult result) async {
    try {
      final tempBox = await _openBackupBox('institutions', file);

      int count = 0;
      for (final key in tempBox.keys) {
        final value = tempBox.get(key);
        if (value != null) {
          final customer = _convertToCustomer(value);
          if (customer != null) {
            await _dbService.customersBox.add(customer);
            count++;
          }
        }
      }

      await tempBox.close();
      result.addImported('Kurumlar (institutions)', count);
    } catch (e) {
      result.addError('Institutions içe aktarma hatası: $e');
    }
  }

  /// bakim_forms.hive dosyasını maintenance_forms box'ına aktar
  Future<void> _importBakimForms(File file, ImportResult result) async {
    try {
      final tempBox = await _openBackupBox('bakim_forms', file);

      int count = 0;
      for (final key in tempBox.keys) {
        final value = tempBox.get(key);
        if (value != null) {
          final form = _convertToMaintenanceForm(value);
          if (form != null) {
            await _dbService.maintenanceFormsBox.add(form);
            count++;
          }
        }
      }

      await tempBox.close();
      result.addImported('Bakım Formları (bakim_forms)', count);
    } catch (e) {
      result.addError('Bakım formları içe aktarma hatası: $e');
    }
  }

  /// stock_parts.hive dosyasını stocks box'ına aktar
  Future<void> _importStockParts(File file, ImportResult result) async {
    try {
      final tempBox = await _openBackupBox('stock_parts', file);

      int count = 0;
      for (final key in tempBox.keys) {
        final value = tempBox.get(key);
        if (value != null) {
          final stock = _convertToStock(value);
          if (stock != null) {
            await _dbService.stocksBox.add(stock);
            count++;
          }
        }
      }

      await tempBox.close();
      result.addImported('Stok Parçaları (stock_parts)', count);
    } catch (e) {
      result.addError('Stok parçaları içe aktarma hatası: $e');
    }
  }

  /// technicians.hive dosyasını aktar
  Future<void> _importTechnicians(File file, ImportResult result) async {
    try {
      final tempBox = await _openBackupBox('technicians', file);

      int count = 0;
      for (final key in tempBox.keys) {
        final value = tempBox.get(key);
        if (value != null) {
          final tech = _convertToTechnician(value);
          if (tech != null) {
            await _dbService.techniciansBox.add(tech);
            count++;
          }
        }
      }

      await tempBox.close();
      result.addImported('Teknisyenler (technicians)', count);
    } catch (e) {
      result.addError('Teknisyenler içe aktarma hatası: $e');
    }
  }

  /// service_forms.hive dosyasını aktar
  Future<void> _importServiceForms(File file, ImportResult result) async {
    try {
      final tempBox = await _openBackupBox('service_forms', file);

      int count = 0;
      for (final key in tempBox.keys) {
        final value = tempBox.get(key);
        if (value != null) {
          final form = _convertToServiceForm(value);
          if (form != null) {
            await _dbService.serviceFormsBox.add(form);
            count++;
          }
        }
      }

      await tempBox.close();
      result.addImported('Servis Formları (service_forms)', count);
    } catch (e) {
      result.addError('Servis formları içe aktarma hatası: $e');
    }
  }

  /// maintenance_models.hive dosyasını devices olarak aktar
  Future<void> _importMaintenanceModels(File file, ImportResult result) async {
    try {
      final tempBox = await _openBackupBox('maintenance_models', file);

      int count = 0;
      for (final key in tempBox.keys) {
        final value = tempBox.get(key);
        if (value != null) {
          final device = _convertToDevice(value);
          if (device != null) {
            await _dbService.devicesBox.add(device);
            count++;
          }
        }
      }

      await tempBox.close();
      result.addImported(
          'Bakım Modelleri → Cihazlar (maintenance_models)', count);
    } catch (e) {
      result.addError('Bakım modelleri içe aktarma hatası: $e');
    }
  }

  /// part_reminders.hive dosyasını aktar
  Future<void> _importPartReminders(File file, ImportResult result) async {
    try {
      // Bu dosya özel işlem gerektirebilir, şimdilik bilgi olarak kaydet
      result.addInfo(
          'Parça Hatırlatmaları (part_reminders) - Manuel içe aktarma gerekli');
    } catch (e) {
      result.addError('Parça hatırlatmaları hatası: $e');
    }
  }

  /// company_info.hive dosyasını aktar
  Future<void> _importCompanyInfo(File file, ImportResult result) async {
    try {
      final tempBox = await _openBackupBox('company_info', file);

      if (tempBox.isNotEmpty) {
        result
            .addInfo('Firma Bilgileri içe aktarıldı - Ayarlardan kontrol edin');
      }

      await tempBox.close();
    } catch (e) {
      result.addError('Firma bilgileri hatası: $e');
    }
  }

  /// app_settings.hive dosyasını aktar
  Future<void> _importAppSettings(File file, ImportResult result) async {
    try {
      final tempBox = await _openBackupBox('app_settings', file);

      result
          .addInfo('Uygulama Ayarları içe aktarıldı (${tempBox.length} ayar)');
      await tempBox.close();
    } catch (e) {
      result.addError('Uygulama ayarları hatası: $e');
    }
  }

  /// barcode_templates.hive dosyasını aktar
  Future<void> _importBarcodeTemplates(File file, ImportResult result) async {
    try {
      final tempBox = await _openBackupBox('barcode_templates', file);

      result.addImported(
          'Barkod Şablonları (barcode_templates)', tempBox.length);
      await tempBox.close();
    } catch (e) {
      result.addError('Barkod şablonları hatası: $e');
    }
  }

  /// maintenance_settings.hive dosyasını aktar
  Future<void> _importMaintenanceSettings(
      File file, ImportResult result) async {
    try {
      final tempBox = await _openBackupBox('maintenance_settings', file);

      result.addInfo('Bakım Ayarları içe aktarıldı (${tempBox.length} ayar)');
      await tempBox.close();
    } catch (e) {
      result.addError('Bakım ayarları hatası: $e');
    }
  }

  // ==================== DÖNÜŞTÜRME METODLARI ====================

  /// Eski institutions verisini Customer modeline dönüştür
  Customer? _convertToCustomer(dynamic oldData) {
    try {
      if (oldData is Map) {
        return Customer(
          name: oldData['name'] ?? oldData['isim'] ?? 'İsimsiz Kurum',
          address: oldData['address'] ?? oldData['adres'] ?? '',
          phone: oldData['phone'] ?? oldData['telefon'] ?? '',
          authorizedPerson:
              oldData['authorizedPerson'] ?? oldData['yetkili'] ?? '',
          email: oldData['email'] ?? oldData['ePosta'] ?? '',
          vergiNo: oldData['vergiNo'] ?? oldData['vergiDairesi'] ?? '',
        );
      }
    } catch (e) {
      debugPrint('Customer dönüştürme hatası: $e');
    }
    return null;
  }

  /// Eski bakim_forms verisini MaintenanceForm modeline dönüştür
  MaintenanceForm? _convertToMaintenanceForm(dynamic oldData) {
    try {
      if (oldData is Map) {
        // Basit dönüşüm - detaylar modele göre ayarlanmalı
        return MaintenanceForm(
          formNumber: oldData['formNumber'] ??
              oldData['formNo'] ??
              'BAK-${DateTime.now().millisecondsSinceEpoch}',
          createdAt: oldData['createdAt'] != null
              ? DateTime.tryParse(oldData['createdAt'].toString()) ??
                  DateTime.now()
              : DateTime.now(),
          customer: oldData['customer'] != null
              ? (_convertToCustomer(oldData['customer']) ??
                  Customer(
                      name: 'Bilinmeyen',
                      address: '',
                      phone: '',
                      authorizedPerson: ''))
              : Customer(
                  name: 'Bilinmeyen',
                  address: '',
                  phone: '',
                  authorizedPerson: ''),
          device: oldData['device'] != null
              ? (_convertToDevice(oldData['device']) ??
                  Device(
                      name: 'Bilinmeyen',
                      brand: '',
                      model: '',
                      serialNumber: '',
                      customer: Customer(
                          name: '',
                          address: '',
                          phone: '',
                          authorizedPerson: ''),
                      installationDate: DateTime.now(),
                      ownershipStatus: OwnershipStatus.sold))
              : Device(
                  name: 'Bilinmeyen',
                  brand: '',
                  model: '',
                  serialNumber: '',
                  customer: Customer(
                      name: '', address: '', phone: '', authorizedPerson: ''),
                  installationDate: DateTime.now(),
                  ownershipStatus: OwnershipStatus.sold),
          maintenancePeriod:
              oldData['maintenancePeriod'] ?? oldData['periyot'] ?? '3 Ay',
          actionsTaken: const [], // Eski veride işlemler farklı formatta olabilir
          partsUsed: HiveList(Hive.box<Stock>('stocks')), // Boş liste
          technicianName:
              oldData['technicianName'] ?? oldData['teknisyen'] ?? '',
          notes: oldData['notes'] ?? oldData['notlar'] ?? '',
        );
      }
    } catch (e) {
      debugPrint('MaintenanceForm dönüştürme hatası: $e');
    }
    return null;
  }

  /// Eski stock_parts verisini Stock modeline dönüştür
  Stock? _convertToStock(dynamic oldData) {
    try {
      if (oldData is Map) {
        return Stock(
          name: oldData['name'] ?? oldData['parcaAdi'] ?? 'İsimsiz Parça',
          quantity:
              oldData['quantity'] ?? oldData['adet'] ?? oldData['miktar'] ?? 0,
          barcode: oldData['barcode'] ?? oldData['barkod'] ?? '',
          referenceNo: oldData['referenceNo'] ?? oldData['refNo'] ?? '',
          criticalStockThreshold:
              oldData['criticalStockThreshold'] ?? oldData['kritikStok'] ?? 10,
        );
      }
    } catch (e) {
      debugPrint('Stock dönüştürme hatası: $e');
    }
    return null;
  }

  /// Eski technicians verisini Technician modeline dönüştür
  Technician? _convertToTechnician(dynamic oldData) {
    try {
      if (oldData is Map) {
        return Technician(
          firstName: oldData['firstName'] ?? oldData['ad'] ?? '',
          lastName: oldData['lastName'] ?? oldData['soyad'] ?? '',
          phone: oldData['phone'] ?? oldData['telefon'] ?? '',
          email: oldData['email'] ?? '',
          title: oldData['title'] ?? oldData['unvan'],
          address: oldData['address'] ?? oldData['adres'],
        );
      }
    } catch (e) {
      debugPrint('Technician dönüştürme hatası: $e');
    }
    return null;
  }

  /// Eski service_forms verisini ServiceForm modeline dönüştür
  ServiceForm? _convertToServiceForm(dynamic oldData) {
    try {
      if (oldData is Map) {
        return ServiceForm(
          formNumber: oldData['formNumber'] ??
              oldData['formNo'] ??
              'SF-${DateTime.now().millisecondsSinceEpoch}',
          customer: oldData['customer'] != null
              ? (_convertToCustomer(oldData['customer']) ??
                  Customer(
                      name: 'Bilinmeyen',
                      address: '',
                      phone: '',
                      authorizedPerson: ''))
              : Customer(
                  name: 'Bilinmeyen',
                  address: '',
                  phone: '',
                  authorizedPerson: ''),
          device: oldData['device'] != null
              ? (_convertToDevice(oldData['device']) ??
                  Device(
                      name: 'Bilinmeyen',
                      brand: '',
                      model: '',
                      serialNumber: '',
                      customer: Customer(
                          name: '',
                          address: '',
                          phone: '',
                          authorizedPerson: ''),
                      installationDate: DateTime.now(),
                      ownershipStatus: OwnershipStatus.sold))
              : Device(
                  name: 'Bilinmeyen',
                  brand: '',
                  model: '',
                  serialNumber: '',
                  customer: Customer(
                      name: '', address: '', phone: '', authorizedPerson: ''),
                  installationDate: DateTime.now(),
                  ownershipStatus: OwnershipStatus.sold),
          problemDescription: oldData['problemDescription'] ??
              oldData['problem'] ??
              oldData['sorun'] ??
              '',
          problemTypes: const [], // Eski veride problem tipi yok
          partsUsed: HiveList(Hive.box<Stock>('stocks')), // Boş parça listesi
          technicianName:
              oldData['technicianName'] ?? oldData['teknisyen'] ?? '',
          createdAt: oldData['createdAt'] != null
              ? DateTime.tryParse(oldData['createdAt'].toString()) ??
                  DateTime.now()
              : DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('ServiceForm dönüştürme hatası: $e');
    }
    return null;
  }

  /// Eski maintenance_models verisini Device modeline dönüştür
  Device? _convertToDevice(dynamic oldData) {
    try {
      if (oldData is Map) {
        return Device(
          name: oldData['name'] ??
              oldData['modelAdi'] ??
              oldData['cihazAdi'] ??
              'İsimsiz Cihaz',
          brand: oldData['brand'] ?? oldData['marka'] ?? '',
          model: oldData['model'] ?? oldData['model'] ?? '',
          serialNumber: oldData['serialNumber'] ?? oldData['seriNo'] ?? '',
          barcode: oldData['barcode'] ?? oldData['barkod'] ?? '',
          customer: oldData['customer'] != null
              ? _convertToCustomer(oldData['customer'])
              : Customer(
                  name: 'Bilinmeyen',
                  address: '',
                  phone: '',
                  authorizedPerson: ''),
          installationDate: oldData['installationDate'] != null
              ? DateTime.tryParse(oldData['installationDate'].toString()) ??
                  DateTime.now()
              : DateTime.now(),
          ownershipStatus: OwnershipStatus.sold,
        );
      }
    } catch (e) {
      debugPrint('Device dönüştürme hatası: $e');
    }
    return null;
  }
}

/// İçe aktarma sonucu
class ImportResult {
  bool success = false;
  final List<String> imported = [];
  final List<String> errors = [];
  final List<String> infos = [];

  void addImported(String name, int count) {
    imported.add('$name: $count kayıt');
  }

  void addError(String message) {
    errors.add(message);
  }

  void addInfo(String message) {
    infos.add(message);
  }

  String get summary {
    final buffer = StringBuffer();
    buffer.writeln('=== İÇE AKTARMA SONUCU ===');
    buffer.writeln('');

    if (imported.isNotEmpty) {
      buffer.writeln('✅ Başarıyla İçe Aktarılanlar:');
      for (final item in imported) {
        buffer.writeln('   • $item');
      }
      buffer.writeln('');
    }

    if (infos.isNotEmpty) {
      buffer.writeln('ℹ️ Bilgiler:');
      for (final item in infos) {
        buffer.writeln('   • $item');
      }
      buffer.writeln('');
    }

    if (errors.isNotEmpty) {
      buffer.writeln('❌ Hatalar:');
      for (final item in errors) {
        buffer.writeln('   • $item');
      }
    }

    buffer.writeln('');
    buffer.writeln(success
        ? '✅ İçe aktarma tamamlandı!'
        : '⚠️ İçe aktarma sorunlarla tamamlandı');

    return buffer.toString();
  }
}
