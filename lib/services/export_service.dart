import 'dart:io';

import 'package:biomed_serv/models/stock.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class ExportService {
  Future<String?> exportStocksToCSV(List<Stock> stocks) async {
    final rows = <List<dynamic>>[
      ['name', 'quantity', 'barcode', 'referenceNo', 'criticalStockThreshold'],
      ...stocks.map(
        (stock) => [
          stock.name,
          stock.quantity,
          stock.barcode ?? '',
          stock.referenceNo ?? '',
          stock.criticalStockThreshold,
        ],
      ),
    ];

    return _saveCsvFile(
      rows: rows,
      suggestedName: 'stok_listesi.csv',
      dialogTitle: 'CSV Dosyasini Kaydet',
    );
  }

  Future<String?> exportStockTemplateCsv() async {
    final rows = <List<dynamic>>[
      ['name', 'quantity', 'barcode', 'referenceNo', 'criticalStockThreshold'],
      ['Ornek Stok Karti', 1, '8690000000000', 'REF-001', 5],
    ];

    return _saveCsvFile(
      rows: rows,
      suggestedName: 'stok_sablonu.csv',
      dialogTitle: 'Stok Sablonunu Kaydet',
    );
  }

  Future<String?> _saveCsvFile({
    required List<List<dynamic>> rows,
    required String suggestedName,
    required String dialogTitle,
  }) async {
    final csv = const ListToCsvConverter().convert(rows);

    try {
      final directory = await getTemporaryDirectory();
      final tempPath = '${directory.path}/$suggestedName';
      final tempFile = File(tempPath);
      await tempFile.writeAsString(csv);

      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (outputFile == null) {
        return null;
      }

      await tempFile.copy(outputFile);
      return outputFile;
    } catch (_) {
      return null;
    }
  }
}
