import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/customer.dart';
import '../services/database_service.dart';
import '../utils/app_exception.dart';
import '../utils/app_logger.dart';

/// Rapor Dışa Aktarma Servisi
class ReportExportService {
  final DatabaseService _dbService;

  ReportExportService(this._dbService);

  /// Servis formlarını Excel olarak dışa aktar
  Future<String> exportServiceFormsToExcel({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    AppLogger.info('Servis formları Excel export başlatılıyor',
        tag: 'ExportService');

    try {
      // Tarih aralığı validasyonu
      if (startDate != null && endDate != null && startDate.isAfter(endDate)) {
        throw ValidationException(
          message: 'Başlangıç tarihi bitiş tarihinden sonra olamaz',
          code: 'INVALID_DATE_RANGE',
        );
      }

      final excel = Excel.createExcel();
      final sheet = excel['Servis Formları'];

      // Başlıklar
      final headers = [
        'Form No',
        'Tarih',
        'Kurum',
        'Cihaz',
        'Marka',
        'Model',
        'Seri No',
        'Sorumlu Personel',
        'Problem',
        'Yapılan İşlem',
        'Parçalar',
        'Teknisyen',
        'Durum',
      ];
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

      // Veriler
      final forms = _dbService.serviceFormsBox.values;
      int exportedCount = 0;

      for (final form in forms) {
        try {
          final date = form.createdAt;

          // Tarih filtresi
          if (startDate != null && date.isBefore(startDate)) continue;
          if (endDate != null && date.isAfter(endDate)) continue;

          final customer = form.customer.name;
          final device = form.device;
          final deviceName = device.name;
          final brand = device.brand;
          final model = device.model;
          final serial = device.serialNumber;

          final parts = form.partsUsed
              .map((p) => '${p.name} (${p.quantity} adet)')
              .join(', ');

          sheet.appendRow([
            TextCellValue(form.formNumber),
            TextCellValue(DateFormat('dd.MM.yyyy').format(date)),
            TextCellValue(customer),
            TextCellValue(deviceName),
            TextCellValue(brand),
            TextCellValue(model),
            TextCellValue(serial),
            TextCellValue(device.responsiblePerson?.fullName ?? ''),
            TextCellValue(form.problemDescription ?? ''),
            TextCellValue(form.actionsTaken ?? ''),
            TextCellValue(parts),
            TextCellValue(form.technicianName ?? ''),
            TextCellValue(
                form.solutionDateTime != null ? 'Tamamlandı' : 'Devam Ediyor'),
          ]);

          exportedCount++;
        } catch (e) {
          AppLogger.warning('Servis formu satırı dışa aktarılırken hata: $e',
              tag: 'ExportService');
          continue;
        }
      }

      if (exportedCount == 0) {
        AppLogger.warning('Dışa aktarılacak servis formu bulunamadı',
            tag: 'ExportService');
      } else {
        AppLogger.info('$exportedCount servis formu Excel\'e aktarıldı',
            tag: 'ExportService');
      }

      // Kaydet
      return await _saveExcelFile(excel, 'servis_raporu');
    } on ExportException {
      rethrow;
    } on ValidationException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Servis formları Excel export hatası',
        tag: 'ExportService',
        exception: e,
        stackTrace: stackTrace,
      );
      throw ExportException(
        message: 'Servis formları Excel\'e aktarılırken bir hata oluştu',
        code: 'SERVICE_EXPORT_ERROR',
        originalException: e,
      );
    }
  }

  /// Bakım formlarını Excel olarak dışa aktar
  Future<String> exportMaintenanceFormsToExcel({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    AppLogger.info('Bakım formları Excel export başlatılıyor',
        tag: 'ExportService');

    try {
      // Tarih aralığı validasyonu
      if (startDate != null && endDate != null && startDate.isAfter(endDate)) {
        throw ValidationException(
          message: 'Başlangıç tarihi bitiş tarihinden sonra olamaz',
          code: 'INVALID_DATE_RANGE',
        );
      }

      final excel = Excel.createExcel();
      final sheet = excel['Bakım Formları'];

      // Başlıklar
      final headers = [
        'Form No',
        'Tarih',
        'Kurum',
        'Cihaz',
        'Marka',
        'Model',
        'Seri No',
        'Sorumlu Personel',
        'Bakım Periyodu',
        'Yapılan İşlemler',
        'Kullanılan Parçalar',
        'Notlar',
        'Teknisyen',
      ];
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

      // Veriler
      final forms = _dbService.maintenanceFormsBox.values;
      int exportedCount = 0;

      for (final form in forms) {
        try {
          final date = form.createdAt;

          if (startDate != null && date.isBefore(startDate)) continue;
          if (endDate != null && date.isAfter(endDate)) continue;

          final customer = form.customer.name;
          final device = form.device;

          final parts = form.partsUsed
              .map((p) => '${p.name} (${p.quantity} adet)')
              .join(', ');

          sheet.appendRow([
            TextCellValue(form.formNumber),
            TextCellValue(DateFormat('dd.MM.yyyy').format(date)),
            TextCellValue(customer),
            TextCellValue(device.name),
            TextCellValue(device.brand),
            TextCellValue(device.model),
            TextCellValue(device.serialNumber),
            TextCellValue(device.responsiblePerson?.fullName ?? ''),
            TextCellValue(form.maintenancePeriod),
            TextCellValue(form.actionsTaken.join(', ')),
            TextCellValue(parts),
            TextCellValue(form.notes ?? ''),
            TextCellValue(form.technicianName ?? ''),
          ]);

          exportedCount++;
        } catch (e) {
          AppLogger.warning('Bakım formu satırı dışa aktarılırken hata: $e',
              tag: 'ExportService');
          continue;
        }
      }

      if (exportedCount == 0) {
        AppLogger.warning('Dışa aktarılacak bakım formu bulunamadı',
            tag: 'ExportService');
      } else {
        AppLogger.info('$exportedCount bakım formu Excel\'e aktarıldı',
            tag: 'ExportService');
      }

      return await _saveExcelFile(excel, 'bakim_raporu');
    } on ExportException {
      rethrow;
    } on ValidationException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Bakım formları Excel export hatası',
        tag: 'ExportService',
        exception: e,
        stackTrace: stackTrace,
      );
      throw ExportException(
        message: 'Bakım formları Excel\'e aktarılırken bir hata oluştu',
        code: 'MAINTENANCE_EXPORT_ERROR',
        originalException: e,
      );
    }
  }

  /// Stok raporunu Excel olarak dışa aktar
  Future<String> exportStockReportToExcel() async {
    AppLogger.info('Stok raporu Excel export başlatılıyor',
        tag: 'ExportService');

    try {
      final excel = Excel.createExcel();
      final sheet = excel['Stok Raporu'];

      // Başlıklar
      final headers = [
        'Parça Adı',
        'Barkod',
        'Referans No',
        'Mevcut Miktar',
        'Kritik Eşik',
        'Durum',
      ];
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

      // Veriler
      final stocks = _dbService.stocksBox.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      for (final stock in stocks) {
        try {
          final isCritical = stock.quantity <= stock.criticalStockThreshold;

          sheet.appendRow([
            TextCellValue(stock.name),
            TextCellValue(stock.barcode ?? ''),
            TextCellValue(stock.referenceNo ?? ''),
            IntCellValue(stock.quantity),
            IntCellValue(stock.criticalStockThreshold),
            TextCellValue(isCritical ? 'KRİTİK' : 'Yeterli'),
          ]);
        } catch (e) {
          AppLogger.warning('Stok satırı işlenirken hata: $e',
              tag: 'ExportService');
          continue;
        }
      }

      // Kritik stoklar için ayrı sayfa
      final criticalSheet = excel['Kritik Stoklar'];
      criticalSheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

      final criticalStocks =
          stocks.where((s) => s.quantity <= s.criticalStockThreshold).toList();

      for (final stock in criticalStocks) {
        try {
          criticalSheet.appendRow([
            TextCellValue(stock.name),
            TextCellValue(stock.barcode ?? ''),
            TextCellValue(stock.referenceNo ?? ''),
            IntCellValue(stock.quantity),
            IntCellValue(stock.criticalStockThreshold),
            TextCellValue('KRİTİK'),
          ]);
        } catch (e) {
          AppLogger.warning('Kritik stok satırı işlenirken hata: $e',
              tag: 'ExportService');
          continue;
        }
      }

      AppLogger.info(
          'Stok raporu başarıyla oluşturuldu (${stocks.length} ürün)',
          tag: 'ExportService');
      return await _saveExcelFile(excel, 'stok_raporu');
    } catch (e, stackTrace) {
      AppLogger.error(
        'Stok raporu Excel export hatası',
        tag: 'ExportService',
        exception: e,
        stackTrace: stackTrace,
      );
      throw ExportException(
        message: 'Stok raporu Excel\'e aktarılırken bir hata oluştu',
        code: 'STOCK_EXPORT_ERROR',
        originalException: e,
      );
    }
  }

  /// Cihaz listesini Excel olarak dışa aktar
  Future<String> exportDevicesToExcel() async {
    AppLogger.info('Cihaz listesi Excel export başlatılıyor',
        tag: 'ExportService');

    try {
      final excel = Excel.createExcel();
      final sheet = excel['Cihaz Listesi'];

      // Başlıklar
      final headers = [
        'Cihaz Adı',
        'Marka',
        'Model',
        'Seri No',
        'Sorumlu Personel',
        'Barkod',
        'Kurum',
        'Grup',
        'Garanti Bitiş',
        'Garanti Durumu',
      ];
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

      // Veriler
      final devices = _dbService.devicesBox.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      for (final device in devices) {
        try {
          final now = DateTime.now();
          final warrantyStatus = device.warrantyEndDate != null
              ? (device.warrantyEndDate!.isAfter(now)
                  ? 'Aktif'
                  : 'Süresi Doldu')
              : 'Belirsiz';

          // Customer name'i güvenli şekilde al
          String customerName = '';
          if (device.customer != null && device.customer is Customer) {
            customerName = (device.customer as Customer).name;
          }

          sheet.appendRow([
            TextCellValue(device.name),
            TextCellValue(device.brand),
            TextCellValue(device.model),
            TextCellValue(device.serialNumber),
            TextCellValue(device.responsiblePerson?.fullName ?? ''),
            TextCellValue(device.barcode ?? ''),
            TextCellValue(customerName),
            TextCellValue(device.group ?? ''),
            TextCellValue(device.warrantyEndDate != null
                ? DateFormat('dd.MM.yyyy').format(device.warrantyEndDate!)
                : ''),
            TextCellValue(warrantyStatus),
          ]);
        } catch (e) {
          AppLogger.warning('Cihaz satırı işlenirken hata: $e',
              tag: 'ExportService');
          continue;
        }
      }

      AppLogger.info(
          'Cihaz listesi başarıyla oluşturuldu (${devices.length} cihaz)',
          tag: 'ExportService');
      return await _saveExcelFile(excel, 'cihaz_listesi');
    } catch (e, stackTrace) {
      AppLogger.error(
        'Cihaz listesi Excel export hatası',
        tag: 'ExportService',
        exception: e,
        stackTrace: stackTrace,
      );
      throw ExportException(
        message: 'Cihaz listesi Excel\'e aktarılırken bir hata oluştu',
        code: 'DEVICE_EXPORT_ERROR',
        originalException: e,
      );
    }
  }

  /// Masraf raporunu Excel olarak dışa aktar
  Future<String> exportExpensesToExcel() async {
    AppLogger.info('Masraf raporu Excel export başlatılıyor',
        tag: 'ExportService');

    try {
      final excel = Excel.createExcel();
      final sheet = excel['Masraf Raporu'];

      // Başlıklar
      final headers = [
        'Tarih',
        'Açıklama',
        'Tutar (₺)',
        'Kurum',
        'Cihaz',
        'Durum',
        'Tahsilat Tipi',
        'Tahsilat Tarihi',
      ];
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

      // Veriler
      final expenses = _dbService.expensesBox.values.toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      double totalAmount = 0;
      for (final expense in expenses) {
        try {
          totalAmount += expense.amount;

          sheet.appendRow([
            TextCellValue(DateFormat('dd.MM.yyyy').format(expense.date)),
            TextCellValue(expense.description),
            DoubleCellValue(expense.amount),
            TextCellValue(expense.customer?.name ?? ''),
            TextCellValue(expense.device?.name ?? ''),
            TextCellValue(expense.status.toString().split('.').last),
            TextCellValue(
                expense.collectionType?.toString().split('.').last ?? ''),
            TextCellValue(expense.collectionDate != null
                ? DateFormat('dd.MM.yyyy').format(expense.collectionDate!)
                : ''),
          ]);
        } catch (e) {
          AppLogger.warning('Masraf satırı işlenirken hata: $e',
              tag: 'ExportService');
          continue;
        }
      }

      // Toplam satır
      sheet.appendRow([]);
      sheet.appendRow([
        TextCellValue(''),
        TextCellValue('GENEL TOPLAM:'),
        DoubleCellValue(totalAmount),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
      ]);

      AppLogger.info(
          'Masraf raporu başarıyla oluşturuldu (${expenses.length} masraf, toplam: ₺${totalAmount.toStringAsFixed(2)})',
          tag: 'ExportService');
      return await _saveExcelFile(excel, 'masraf_raporu');
    } catch (e, stackTrace) {
      AppLogger.error(
        'Masraf raporu Excel export hatası',
        tag: 'ExportService',
        exception: e,
        stackTrace: stackTrace,
      );
      throw ExportException(
        message: 'Masraf raporu Excel\'e aktarılırken bir hata oluştu',
        code: 'EXPENSE_EXPORT_ERROR',
        originalException: e,
      );
    }
  }

  /// CSV formatında dışa aktar
  Future<String> exportToCsv({
    required String reportType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    AppLogger.info('CSV export başlatılıyor: $reportType',
        tag: 'ExportService');

    try {
      List<List<String>> csvData = [];

      switch (reportType) {
        case 'service':
          csvData = await _generateServiceFormsCsv(startDate, endDate);
          break;
        case 'maintenance':
          csvData = await _generateMaintenanceFormsCsv(startDate, endDate);
          break;
        case 'stock':
          csvData = await _generateStockCsv();
          break;
        case 'devices':
          csvData = await _generateDevicesCsv();
          break;
        default:
          throw ValidationException(
            message: 'Bilinmeyen rapor tipi: $reportType',
            code: 'INVALID_REPORT_TYPE',
          );
      }

      if (csvData.isEmpty) {
        throw ExportException(
          message: 'Dışa aktarılacak veri bulunamadı',
          code: 'NO_DATA_TO_EXPORT',
        );
      }

      final csv = const ListToCsvConverter().convert(csvData);
      final fileName =
          '${reportType}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');

      await file.writeAsString(csv, encoding: utf8);

      AppLogger.info(
          'CSV export başarıyla tamamlandı: $fileName (${csvData.length} satır)',
          tag: 'ExportService');
      return file.path;
    } on ValidationException {
      rethrow;
    } on ExportException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error(
        'CSV export hatası',
        tag: 'ExportService',
        exception: e,
        stackTrace: stackTrace,
      );
      throw ExportException(
        message: 'CSV dışa aktarma sırasında bir hata oluştu',
        code: 'CSV_EXPORT_ERROR',
        originalException: e,
      );
    }
  }

  /// Dosyayı paylaş
  Future<void> shareFile(String filePath, {String? subject}) async {
    AppLogger.info('Dosya paylaşılıyor: $filePath', tag: 'ExportService');

    try {
      final file = File(filePath);

      if (!await file.exists()) {
        throw FileException(
          message: 'Paylaşılacak dosya bulunamadı: $filePath',
          code: 'FILE_NOT_FOUND',
        );
      }

      await Share.shareXFiles(
        [XFile(filePath)],
        text: subject ?? 'Rapor',
      );

      AppLogger.info('Dosya başarıyla paylaşıldı', tag: 'ExportService');
    } on FileException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Dosya paylaşma hatası',
        tag: 'ExportService',
        exception: e,
        stackTrace: stackTrace,
      );
      throw FileException(
        message: 'Dosya paylaşılırken bir hata oluştu',
        code: 'SHARE_ERROR',
        originalException: e,
      );
    }
  }

  // ========== PRIVATE METHODS ==========

  Future<String> _saveExcelFile(Excel excel, String baseFileName) async {
    try {
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = '${baseFileName}_$timestamp.xlsx';

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');

      final bytes = excel.encode();
      if (bytes == null) {
        throw ExportException(
          message: 'Excel dosyası oluşturulamadı',
          code: 'EXCEL_ENCODING_ERROR',
        );
      }

      await file.writeAsBytes(bytes);
      AppLogger.info('Excel dosyası kaydedildi: $fileName',
          tag: 'ExportService');

      return file.path;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Excel dosyası kaydetme hatası',
        tag: 'ExportService',
        exception: e,
        stackTrace: stackTrace,
      );
      throw ExportException(
        message: 'Excel dosyası kaydedilirken bir hata oluştu',
        code: 'FILE_SAVE_ERROR',
        originalException: e,
      );
    }
  }

  Future<List<List<String>>> _generateServiceFormsCsv(
    DateTime? startDate,
    DateTime? endDate,
  ) async {
    final data = <List<String>>[];

    // Başlıklar
    data.add([
      'Form No',
      'Tarih',
      'Kurum',
      'Cihaz',
      'Marka',
      'Model',
      'Sorumlu Personel',
      'Problem',
      'İşlem',
      'Teknisyen',
      'Durum'
    ]);

    final forms = _dbService.serviceFormsBox.values;
    for (final form in forms) {
      final date = form.createdAt;
      if (startDate != null && date.isBefore(startDate)) continue;
      if (endDate != null && date.isAfter(endDate)) continue;

      data.add([
        form.formNumber,
        DateFormat('dd.MM.yyyy').format(date),
        form.customer.name,
        form.device.name,
        form.device.brand,
        form.device.model,
        form.device.responsiblePerson?.fullName ?? '',
        form.problemDescription ?? '',
        form.actionsTaken ?? '',
        form.technicianName ?? '',
        form.solutionDateTime != null ? 'Tamamlandı' : 'Devam Ediyor',
      ]);
    }

    return data;
  }

  Future<List<List<String>>> _generateMaintenanceFormsCsv(
    DateTime? startDate,
    DateTime? endDate,
  ) async {
    final data = <List<String>>[];

    data.add([
      'Form No',
      'Tarih',
      'Kurum',
      'Cihaz',
      'Seri No',
      'Sorumlu Personel',
      'Bakım Periyodu',
      'İşlemler',
      'Teknisyen'
    ]);

    final forms = _dbService.maintenanceFormsBox.values;
    for (final form in forms) {
      final date = form.createdAt;
      if (startDate != null && date.isBefore(startDate)) continue;
      if (endDate != null && date.isAfter(endDate)) continue;

      data.add([
        form.formNumber,
        DateFormat('dd.MM.yyyy').format(date),
        form.customer.name,
        form.device.name,
        form.device.serialNumber,
        form.device.responsiblePerson?.fullName ?? '',
        form.maintenancePeriod,
        form.actionsTaken.join(', '),
        form.technicianName ?? '',
      ]);
    }

    return data;
  }

  Future<List<List<String>>> _generateStockCsv() async {
    final data = <List<String>>[];

    data.add([
      'Parça Adı',
      'Barkod',
      'Referans No',
      'Miktar',
      'Kritik Eşik',
      'Durum'
    ]);

    final stocks = _dbService.stocksBox.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    for (final stock in stocks) {
      final isCritical = stock.quantity <= stock.criticalStockThreshold;

      data.add([
        stock.name,
        stock.barcode ?? '',
        stock.referenceNo ?? '',
        stock.quantity.toString(),
        stock.criticalStockThreshold.toString(),
        isCritical ? 'KRİTİK' : 'Yeterli',
      ]);
    }

    return data;
  }

  Future<List<List<String>>> _generateDevicesCsv() async {
    final data = <List<String>>[];

    data.add([
      'Cihaz Adı',
      'Marka',
      'Model',
      'Seri No',
      'Sorumlu Personel',
      'Kurum',
      'Garanti Durumu',
      'Durum'
    ]);

    final devices = _dbService.devicesBox.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    for (final device in devices) {
      final now = DateTime.now();
      final warrantyStatus = device.warrantyEndDate != null
          ? (device.warrantyEndDate!.isAfter(now) ? 'Aktif' : 'Süresi Doldu')
          : 'Belirsiz';

      // Customer name'i güvenli şekilde al
      String customerName = '';
      if (device.customer != null && device.customer is Customer) {
        customerName = (device.customer as Customer).name;
      }

      data.add([
        device.name,
        device.brand,
        device.model,
        device.serialNumber,
        device.responsiblePerson?.fullName ?? '',
        customerName,
        warrantyStatus,
        device.ownershipStatus.toString().split('.').last,
      ]);
    }

    return data;
  }
}
