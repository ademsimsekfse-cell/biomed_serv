import 'dart:io';
import 'package:biomed_serv/models/stock.dart';
import 'package:csv/csv.dart';
import 'dart:convert';

class ImportService {

  // Verilen CSV dosyasını okur ve başlıkları döndürür
  Future<List<String>> getHeaders(String filePath) async {
    final file = File(filePath);
    final csvString = await file.readAsString(encoding: utf8); // Encoding belirttik
    final rowsAsListOfValues = const CsvToListConverter().convert(csvString);
    if (rowsAsListOfValues.isNotEmpty) {
      return rowsAsListOfValues.first.map((e) => e.toString()).toList();
    }
    return [];
  }

  // Stok verilerini içe aktarır
  Future<List<Stock>> importStocksFromCSV(
    String filePath, 
    Map<String, String?> columnMapping
  ) async {
    final List<Stock> importedStocks = [];
    final file = File(filePath);
    final csvString = await file.readAsString(encoding: utf8);
    final rowsAsListOfValues = const CsvToListConverter().convert(csvString);

    if (rowsAsListOfValues.length < 2) { // Başlık + en az bir veri satırı olmalı
      return [];
    }

    final headers = rowsAsListOfValues.first.map((e) => e.toString()).toList();
    final dataRows = rowsAsListOfValues.sublist(1);

    // Haritayı tersine çevir: CSV Başlığı -> Bizim Alan Adı
    final Map<String, String> reverseMapping = {};
    columnMapping.forEach((key, value) { 
      if (value != null) {
        reverseMapping[value] = key;
      }
    });

    for (var row in dataRows) {
      final Map<String, dynamic> stockData = {};
      for (int i = 0; i < headers.length; i++) {
        final header = headers[i];
        if (reverseMapping.containsKey(header)) {
          final fieldName = reverseMapping[header]!;
          stockData[fieldName] = row[i];
        }
      }

      // Gerekli alanların varlığından emin ol ve Stock nesnesi oluştur
      if (stockData.containsKey('name') && stockData.containsKey('quantity')) {
        try {
          importedStocks.add(Stock(
            name: stockData['name'].toString(),
            quantity: int.parse(stockData['quantity'].toString()),
            barcode: stockData['barcode']?.toString(),
            referenceNo: stockData['referenceNo']?.toString(),
            criticalStockThreshold: int.tryParse(stockData['criticalStockThreshold']?.toString() ?? '10') ?? 10,
          ));
        } catch (e) {
          print('Satır dönüştürme hatası: $row - Hata: $e');
        }
      }
    }
    return importedStocks;
  }
}
