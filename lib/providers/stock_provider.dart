import 'dart:async';

import 'package:biomed_serv/models/stock.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class StockProvider with ChangeNotifier {
  final DatabaseService _dbService;
  late Box<Stock> _stockBox;
  StreamSubscription<BoxEvent>? _stockSubscription;

  List<Stock> _stocks = [];
  List<Stock> get stocks => _stocks;

  StockProvider(this._dbService) {
    _stockBox = _dbService.stocksBox;
    _stockSubscription = _stockBox.watch().listen((_) => _loadStocks());
    _loadStocks();
  }

  // Stokları veritabanından yükle
  void _loadStocks() {
    _stocks = _stockBox.values.toList();
    notifyListeners();
  }

  // Yeni stok ekle
  Future<void> addStock(Stock stock) async {
    await _stockBox.add(stock);
    _loadStocks();
  }

  // Birden fazla stok ekle (YENİ)
  Future<void> addMultipleStocks(List<Stock> newStocks) async {
    await _stockBox.addAll(newStocks);
    _loadStocks();
  }

  // Stoğu güncelle
  Future<void> updateStock(int key, Stock stock) async {
    await _stockBox.put(key, stock);
    _loadStocks();
  }

  // Stoğu sil
  Future<void> deleteStock(int key) async {
    await _stockBox.delete(key);
    _loadStocks();
  }

  /// 🔻 Stok kullan (servis formundan parça eklendiğinde)
  /// ✅ NEGATİF STOK İZİNLİ - Sadece uyarı verir
  Future<bool> useStock(int stockKey, int quantity,
      {bool allowNegative = true}) async {
    try {
      final stock = _stockBox.get(stockKey);
      if (stock == null) return false;

      // Negatif stok kontrolü
      if (!allowNegative && stock.quantity < quantity) {
        return false;
      }

      // Stok miktarını azalt (negatife düşebilir)
      stock.quantity -= quantity;
      await _stockBox.put(stockKey, stock);

      // 🔔 Negatif stok uyarısı
      if (stock.quantity < 0) {
        debugPrint(
            '🚨 NEGATİF STOK: ${stock.name} - Eksik: ${stock.quantity.abs()} adet');
      }
      // Kritik stok uyarısı
      else if (stock.quantity <= stock.criticalStockThreshold) {
        debugPrint('⚠️ Kritik stok: ${stock.name} - Kalan: ${stock.quantity}');
      }

      _loadStocks();
      return true;
    } catch (e) {
      debugPrint('Stok düşme hatası: $e');
      return false;
    }
  }

  /// Stok miktarını artır (iade veya yeni giriş)
  Future<void> increaseStock(int stockKey, int quantity) async {
    try {
      final stock = _stockBox.get(stockKey);
      if (stock == null) return;

      stock.quantity += quantity;
      await _stockBox.put(stockKey, stock);
      _loadStocks();
    } catch (e) {
      debugPrint('Stok artırma hatası: $e');
    }
  }

  @override
  void dispose() {
    _stockSubscription?.cancel();
    super.dispose();
  }
}
