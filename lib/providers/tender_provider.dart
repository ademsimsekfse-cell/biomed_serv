import 'package:biomed_serv/models/tender.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class TenderProvider with ChangeNotifier {
  final DatabaseService _dbService;
  late Box<Tender> _tenderBox;

  List<Tender> _tenders = [];
  List<Tender> get tenders => _tenders;

  TenderProvider(this._dbService) {
    _tenderBox = _dbService.tendersBox;
    _loadTenders();
  }

  void _loadTenders() {
    _tenders = _tenderBox.values.toList();
    notifyListeners();
  }

  Future<void> addTender(Tender tender) async {
    await _tenderBox.add(tender);
    _loadTenders();
  }

  Future<void> updateTender(int key, Tender tender) async {
    await _tenderBox.put(key, tender);
    _loadTenders();
  }

  Future<void> deleteTender(int key) async {
    await _tenderBox.delete(key);
    _loadTenders();
  }
}
