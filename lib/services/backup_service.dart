import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../services/database_service.dart';
import '../services/storage_location_service.dart';

/// Yedekleme Servisi
class BackupService {
  BackupService(DatabaseService _);

  /// Tum veritabanini yedekle (ZIP olarak)
  Future<String> createFullBackup() async {
    try {
      // Izin kontrolu
      if (!await _requestStoragePermission()) {
        throw Exception('Depolama izni reddedildi');
      }

      // Yedekleme verisi topla
      final backupData = await _collectAllData();

      // JSON'a donustur
      final jsonData = jsonEncode(backupData);
      final bytes = utf8.encode(jsonData);

      // ZIP olarak sikistir
      final archive = Archive();
      final file = ArchiveFile('backup.json', bytes.length, bytes);
      archive.addFile(file);
      final zipBytes = ZipEncoder().encode(archive);

      // Dosyayi kaydet
      final backupDir = await _getBackupDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'biomed_backup_$timestamp.zip';
      final filePath = '$backupDir/$fileName';

      final outputFile = File(filePath);
      await outputFile.writeAsBytes(zipBytes!);

      // Otomatik yedeklemeyi guncelle
      await _updateLastBackupTime();

      return filePath;
    } catch (e) {
      throw Exception('Yedekleme hatasi: $e');
    }
  }

  /// Belirli kutulari yedekle
  Future<String> createSelectiveBackup({
    required List<String> boxNames,
  }) async {
    try {
      if (!await _requestStoragePermission()) {
        throw Exception('Depolama izni reddedildi');
      }

      final backupData = <String, dynamic>{};
      backupData['timestamp'] = DateTime.now().toIso8601String();
      backupData['version'] = '1.0';

      // Secili kutulari yedekle
      for (final boxName in boxNames) {
        // Kutu acik degilse ac
        final Box<dynamic> box;
        if (Hive.isBoxOpen(boxName)) {
          box = Hive.box(boxName);
        } else {
          box = await Hive.openBox(boxName);
        }

        final boxData = box
            .toMap()
            .map((k, v) => MapEntry(k.toString(), _convertToJson(v)));
        backupData[boxName] = boxData;
      }

      // JSON ve ZIP
      final jsonData = jsonEncode(backupData);
      final bytes = utf8.encode(jsonData);

      final archive = Archive();
      final file = ArchiveFile('selective_backup.json', bytes.length, bytes);
      archive.addFile(file);
      final zipBytes = ZipEncoder().encode(archive);

      // Kaydet
      final backupDir = await _getBackupDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'biomed_selective_$timestamp.zip';
      final filePath = '$backupDir/$fileName';

      await File(filePath).writeAsBytes(zipBytes!);
      return filePath;
    } catch (e) {
      throw Exception('Secici yedekleme hatasi: $e');
    }
  }

  /// Yedekten geri yukle
  Future<void> restoreFromBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Yedek dosyasi bulunamadi');
      }

      // ZIP'i ac
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // JSON dosyasini bul ve oku
      String? jsonContent;
      var hasStructuredManifest = false;
      for (final file in archive) {
        if (file.name == 'manifest.json') {
          hasStructuredManifest = true;
          continue;
        }
        if (file.name == 'backup.json' ||
            file.name == 'selective_backup.json') {
          jsonContent = utf8.decode(file.content as List<int>);
          break;
        }
      }

      if (jsonContent == null) {
        if (hasStructuredManifest) {
          throw Exception(
            'Bu dosya Excel/CSV arsiv yedegi. Geri yukleme icin klasik JSON yedegi secin veya Excel ice aktarma ekranini kullanin.',
          );
        }
        throw Exception('Yedek dosyasinda JSON verisi bulunamadi');
      }

      // JSON'dan veriyi al
      final backupData = jsonDecode(jsonContent) as Map<String, dynamic>;

      // Veriyi geri yukle
      await _restoreData(backupData);
    } catch (e) {
      throw Exception('Geri yukleme hatasi: $e');
    }
  }

  /// Dosya secici ile yedek yukle
  Future<void> restoreFromPicker() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'json'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        await restoreFromBackup(result.files.single.path!);
      }
    } catch (e) {
      throw Exception('Dosya secme hatasi: $e');
    }
  }

  /// Yedegi paylas (WhatsApp, Email, vb.)
  Future<void> shareBackup(String filePath) async {
    try {
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Biomed Servis Yedek Dosyasi',
      );
    } catch (e) {
      throw Exception('Paylasma hatasi: $e');
    }
  }

  /// Otomatik yedekleme ayarlari
  Future<void> configureAutoBackup({
    required bool enabled,
    int intervalDays = 7,
  }) async {
    final prefs = await _getPrefsBox();
    await prefs.put('auto_backup_enabled', enabled);
    await prefs.put('auto_backup_interval', intervalDays);
    await prefs.put('auto_backup_last', DateTime.now().toIso8601String());
  }

  /// Otomatik yedekleme kontrolu
  Future<bool> shouldAutoBackup() async {
    final prefs = await _getPrefsBox();
    final enabled = prefs.get('auto_backup_enabled') as bool? ?? false;

    if (!enabled) return false;

    final lastBackup = prefs.get('auto_backup_last') as String?;
    if (lastBackup == null) return true;

    final lastDate = DateTime.parse(lastBackup);
    final interval = prefs.get('auto_backup_interval') as int? ?? 7;
    final nextBackup = lastDate.add(Duration(days: interval));

    return DateTime.now().isAfter(nextBackup);
  }

  /// Yedekleme gecmisini getir
  Future<List<BackupInfo>> getBackupHistory() async {
    try {
      final backupDir = await _getBackupDirectory();
      final dir = Directory(backupDir);

      if (!await dir.exists()) return [];

      final files = await dir
          .list()
          .where((f) => f is File && f.path.endsWith('.zip'))
          .toList();

      return files.map((f) {
        final stat = (f as File).statSync();
        final fileName = f.path.split('/').last;

        // Dosya adindan tarih cikar
        DateTime? backupDate;
        try {
          final match =
              RegExp(r'biomed_(\w+)_(\d{8})_(\d{6})').firstMatch(fileName);
          if (match != null) {
            backupDate = DateFormat('yyyyMMdd_HHmmss')
                .parse('${match.group(2)}_${match.group(3)}');
          }
        } catch (_) {}

        return BackupInfo(
          path: f.path,
          fileName: fileName,
          size: stat.size,
          createdAt: backupDate ?? stat.modified,
          type: fileName.contains('selective') ? 'selective' : 'full',
        );
      }).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      return [];
    }
  }

  /// Yedek sil
  Future<void> deleteBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw Exception('Silme hatasi: $e');
    }
  }

  // ========== PRIVATE METHODS ==========

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      // Android 11+ icin ozel izin gerekli
      if (await Permission.storage.request().isGranted) {
        return true;
      }
      return await Permission.manageExternalStorage.request().isGranted;
    }
    return true;
  }

  Future<String> _getBackupDirectory() async {
    final storage = StorageLocationService();
    final selectedPath = await storage.effectiveBackupDirectory();
    final selectedDir = Directory(selectedPath);
    if (!await selectedDir.exists()) {
      await selectedDir.create(recursive: true);
    }
    return selectedDir.path;
  }

  Future<Box> _getPrefsBox() async {
    return await Hive.openBox('app_preferences');
  }

  Future<Map<String, dynamic>> _collectAllData() async {
    final data = <String, dynamic>{};

    data['timestamp'] = DateTime.now().toIso8601String();
    data['version'] = '1.0';
    data['app_name'] = 'Biomed Servis';

    // Tum kutulari yedekle
    final boxNames = [
      'customers',
      'devices',
      'service_forms',
      'service_form_parts',
      'maintenance_forms',
      'stocks',
      'tenders',
      'technicians',
      'agents',
      'maintenance_templates',
      'maintenance_templates_v2',
      'report_templates',
      'expenses',
      'expense_reports',
      'notifications',
      'reminders',
      'device_personels',
    ];

    for (final boxName in boxNames) {
      try {
        // Kutu acik degilse ac
        final Box<dynamic> box;
        if (Hive.isBoxOpen(boxName)) {
          box = Hive.box(boxName);
        } else {
          box = await Hive.openBox(boxName);
        }

        final boxData = box
            .toMap()
            .map((k, v) => MapEntry(k.toString(), _convertToJson(v)));
        data[boxName] = boxData;
      } catch (e) {
        debugPrint('Kutu yedeklenirken hata: $boxName - $e');
      }
    }

    return data;
  }

  dynamic _convertToJson(dynamic value) {
    if (value == null) return null;

    // DateTime kontrolu
    if (value is DateTime) {
      return value.toIso8601String();
    }

    // Liste kontrolu
    if (value is List) {
      return value.map((e) => _convertToJson(e)).toList();
    }

    // Map kontrolu
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _convertToJson(v)));
    }

    // HiveObject veya diger nesneler icin string temsili
    if (value is HiveObject) {
      // HiveObject'i dogrudan JSON'a ceviremeyiz,
      // bu yuzden box'tan ham veri olarak kalir
      return null;
    }

    return value;
  }

  Future<void> _restoreData(Map<String, dynamic> backupData) async {
    // Her kutuyu temizle ve yeni veriyi yukle
    final boxNames = backupData.keys
        .where((k) => !['timestamp', 'version', 'app_name'].contains(k));

    for (final boxName in boxNames) {
      try {
        final box = await Hive.openBox(boxName);
        await box.clear();

        final boxData = backupData[boxName] as Map<String, dynamic>?;
        if (boxData != null) {
          for (final entry in boxData.entries) {
            final key = int.tryParse(entry.key) ?? entry.key;
            await box.put(key, entry.value);
          }
        }
      } catch (e) {
        debugPrint('Kutu geri yuklenirken hata: $boxName - $e');
      }
    }
  }

  Future<void> _updateLastBackupTime() async {
    final prefs = await _getPrefsBox();
    await prefs.put('last_backup', DateTime.now().toIso8601String());
  }
}

/// Yedek bilgisi
class BackupInfo {
  final String path;
  final String fileName;
  final int size;
  final DateTime createdAt;
  final String type;

  BackupInfo({
    required this.path,
    required this.fileName,
    required this.size,
    required this.createdAt,
    required this.type,
  });

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedDate {
    return DateFormat('dd.MM.yyyy HH:mm').format(createdAt);
  }
}
