import 'dart:async';

import 'package:biomed_serv/models/expense.dart';
import 'package:biomed_serv/models/expense_report.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class ExpenseProvider with ChangeNotifier {
  final DatabaseService _dbService;
  late Box<Expense> _expenseBox;
  late Box<ExpenseReport> _reportBox;
  StreamSubscription<BoxEvent>? _expenseSubscription;
  StreamSubscription<BoxEvent>? _reportSubscription;

  List<Expense> _expenses = [];
  List<Expense> get expenses => _expenses;

  // Bekleyen masraflar (raporlanmamış)
  List<Expense> get pendingExpenses =>
      _expenses.where((e) => e.status == ExpenseStatus.pending).toList();

  // Raporlanmış masraflar
  List<Expense> get reportedExpenses =>
      _expenses.where((e) => e.status == ExpenseStatus.reported).toList();

  // Tahsil edilmiş masraflar
  List<Expense> get collectedExpenses =>
      _expenses.where((e) => e.status == ExpenseStatus.collected).toList();

  // Toplam bekleyen tutar
  double get totalPendingAmount =>
      pendingExpenses.fold(0, (sum, e) => sum + e.amount);

  // Toplam tahsil edilmemiş tutar (raporlanmış ama tahsil edilmemiş)
  double get totalUnCollectedAmount =>
      reportedExpenses.fold(0, (sum, e) => sum + e.amount);

  // Toplam tahsil edilmiş tutar
  double get totalCollectedAmount =>
      collectedExpenses.fold(0, (sum, e) => sum + e.amount);

  ExpenseProvider(this._dbService) {
    _expenseBox = _dbService.expensesBox;
    _reportBox = _dbService.expenseReportsBox;
    _expenseSubscription = _expenseBox.watch().listen((_) => _loadExpenses());
    _reportSubscription = _reportBox.watch().listen((_) => _loadExpenses());
    _loadExpenses();
  }

  void _loadExpenses() {
    _expenses = _expenseBox.values.toList();
    // Tarihe göre sırala (en yeni en üstte)
    _expenses.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  /// Yeni masraf ekle
  Future<void> addExpense(Expense expense) async {
    await _expenseBox.add(expense);
    _loadExpenses();
  }

  /// Masraf güncelle
  Future<void> updateExpense(int key, Expense expense) async {
    await _expenseBox.put(key, expense);
    _loadExpenses();
  }

  /// Masraf sil
  Future<void> deleteExpense(int key) async {
    await _expenseBox.delete(key);
    _loadExpenses();
  }

  /// Birden fazla masraf sil (raporlandıktan sonra)
  Future<void> deleteExpenses(List<int> keys) async {
    await _expenseBox.deleteAll(keys);
    _loadExpenses();
  }

  /// Masrafları raporla (durumunu değiştir)
  Future<void> reportExpenses(
    List<int> keys,
    String reportNumber,
  ) async {
    final now = DateTime.now();

    for (final key in keys) {
      final expense = _expenseBox.get(key);
      if (expense != null) {
        expense.status = ExpenseStatus.reported;
        expense.reportedAt = now;
        expense.reportNumber = reportNumber;
        await _expenseBox.put(key, expense);
      }
    }
    _loadExpenses();
  }

  /// Tahsilat kaydet
  Future<void> collectExpense(
    int key, {
    required CollectionType type,
    DateTime? date,
    String? note,
  }) async {
    final expense = _expenseBox.get(key);
    if (expense != null) {
      final wasReported = expense.status == ExpenseStatus.reported;
      expense.status = ExpenseStatus.collected;
      expense.collectionType = type;
      expense.collectionDate = date ?? DateTime.now();
      expense.collectionNote = note;
      await _expenseBox.put(key, expense);

      if (wasReported && expense.reportNumber != null) {
        await _syncLinkedReportCollection(expense, type, note);
      }

      _loadExpenses();
    }
  }

  Future<void> _syncLinkedReportCollection(
    Expense collectedExpense,
    CollectionType type,
    String? note,
  ) async {
    ExpenseReport? linkedReport;
    dynamic linkedReportKey;

    for (final key in _reportBox.keys) {
      final report = _reportBox.get(key);
      if (report?.reportNumber == collectedExpense.reportNumber) {
        linkedReport = report;
        linkedReportKey = key;
        break;
      }
    }

    if (linkedReport == null || linkedReportKey == null) return;

    var collectedTotal = 0.0;
    for (final expenseKey in linkedReport.expenseKeys) {
      final reportExpense = _expenseBox.get(expenseKey);
      if (reportExpense?.status == ExpenseStatus.collected) {
        collectedTotal += reportExpense!.amount;
      }
    }

    linkedReport.collectedAmount =
        collectedTotal.clamp(0, linkedReport.totalAmount).toDouble();
    linkedReport.isCollected = linkedReport.remainingAmount <= 0.01;
    linkedReport.collectionType = type;
    linkedReport.collectionDate = collectedExpense.collectionDate;
    linkedReport.collectionNote = note;

    await _reportBox.put(linkedReportKey, linkedReport);
  }

  /// Birden fazla masrafı toplu tahsil et
  Future<void> collectExpenses(
    List<int> keys, {
    required CollectionType type,
    String? note,
  }) async {
    final now = DateTime.now();

    for (final key in keys) {
      final expense = _expenseBox.get(key);
      if (expense != null && expense.status == ExpenseStatus.reported) {
        expense.status = ExpenseStatus.collected;
        expense.collectionType = type;
        expense.collectionDate = now;
        expense.collectionNote = note;
        await _expenseBox.put(key, expense);
      }
    }
    _loadExpenses();
  }

  /// Demo veri ekle
  Future<void> addDemoExpenses() async {
    if (_expenses.isNotEmpty) return;

    final demoExpenses = [
      Expense(
        date: DateTime.now().subtract(const Duration(days: 2)),
        description: 'Ankara servis yol masrafı',
        amount: 450.00,
        status: ExpenseStatus.pending,
      ),
      Expense(
        date: DateTime.now().subtract(const Duration(days: 3)),
        description: 'Otel konaklama - İstanbul',
        amount: 850.00,
        status: ExpenseStatus.pending,
      ),
      Expense(
        date: DateTime.now().subtract(const Duration(days: 5)),
        description: 'Yedek parça alımı',
        amount: 1250.50,
        status: ExpenseStatus.collected,
        collectionType: CollectionType.eft,
        collectionDate: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];

    for (final expense in demoExpenses) {
      await _expenseBox.add(expense);
    }
    _loadExpenses();
  }

  @override
  void dispose() {
    _expenseSubscription?.cancel();
    _reportSubscription?.cancel();
    super.dispose();
  }
}
