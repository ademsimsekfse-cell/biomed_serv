import 'dart:async';

import 'package:biomed_serv/models/expense.dart';
import 'package:biomed_serv/models/expense_report.dart';
import 'package:biomed_serv/models/technician.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class ExpenseReportProvider with ChangeNotifier {
  final DatabaseService _dbService;
  late Box<ExpenseReport> _reportBox;
  late Box<Expense> _expenseBox;
  StreamSubscription<BoxEvent>? _reportSubscription;
  StreamSubscription<BoxEvent>? _expenseSubscription;

  List<ExpenseReport> _reports = [];
  List<ExpenseReport> get reports => _reports;

  // Tahsil edilmemiş raporlar
  List<ExpenseReport> get uncollectedReports =>
      _reports.where((r) => !r.isCollected).toList();

  // Tahsil edilmiş raporlar
  List<ExpenseReport> get collectedReports =>
      _reports.where((r) => r.isCollected).toList();

  // Toplam rapor sayısı
  int get totalReports => _reports.length;

  // Toplam tahsil edilmemiş tutar
  double get totalUncollectedAmount =>
      uncollectedReports.fold(0, (sum, r) => sum + r.remainingAmount);

  // Toplam tahsil edilmiş tutar
  double get totalCollectedAmount =>
      collectedReports.fold(0, (sum, r) => sum + r.totalAmount);

  ExpenseReportProvider(this._dbService) {
    _reportBox = _dbService.expenseReportsBox;
    _expenseBox = _dbService.expensesBox;
    _reportSubscription = _reportBox.watch().listen((_) => _loadReports());
    _expenseSubscription = _expenseBox.watch().listen((_) => _loadReports());
    _loadReports();
  }

  void _loadReports() {
    _reports = _reportBox.values.toList();
    _reconcileReportsWithExpenses();
    // Tarihe göre sırala (en yeni en üstte)
    _reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
  }

  void _reconcileReportsWithExpenses() {
    for (final report in _reports) {
      var collectedTotal = 0.0;
      CollectionType? latestCollectionType;
      DateTime? latestCollectionDate;
      String? latestCollectionNote;

      for (final expenseKey in report.expenseKeys) {
        final expense = _expenseBox.get(expenseKey);
        if (expense?.status == ExpenseStatus.collected) {
          collectedTotal += expense!.amount;
          latestCollectionType = expense.collectionType ?? latestCollectionType;
          latestCollectionDate = expense.collectionDate ?? latestCollectionDate;
          latestCollectionNote = expense.collectionNote ?? latestCollectionNote;
        }
      }

      final recordedCollected =
          report.collectedAmount.clamp(0, report.totalAmount).toDouble();
      final normalizedCollected =
          collectedTotal.clamp(0, report.totalAmount).toDouble() >
                  recordedCollected
              ? collectedTotal.clamp(0, report.totalAmount).toDouble()
              : recordedCollected;
      final shouldBeCollected = report.totalAmount > 0 &&
          report.totalAmount - normalizedCollected <= 0.01;

      if (report.collectedAmount != normalizedCollected ||
          report.isCollected != shouldBeCollected) {
        report.collectedAmount = normalizedCollected;
        report.isCollected = shouldBeCollected;
        if (latestCollectionType != null) {
          report.collectionType = latestCollectionType;
          report.collectionDate = latestCollectionDate;
          report.collectionNote = latestCollectionNote;
        }
        report.save();
      }
    }
  }

  /// Yeni rapor oluştur
  Future<ExpenseReport> createReport({
    required Technician technician,
    required List<int> expenseKeys,
    String? reportNumber,
    String? notes,
  }) async {
    // Rapor numarası oluştur
    final resolvedReportNumber =
        reportNumber ?? ExpenseReport.generateReportNumber();

    // Toplam tutarı hesapla
    double totalAmount = 0;
    for (final key in expenseKeys) {
      final expense = _expenseBox.get(key);
      if (expense != null) {
        totalAmount += expense.amount;
      }
    }

    // Rapor oluştur
    final report = ExpenseReport(
      reportNumber: resolvedReportNumber,
      technician: technician,
      expenseKeys: expenseKeys,
      totalAmount: totalAmount,
      notes: notes,
    );

    // Kaydet
    await _reportBox.add(report);

    // Masrafları raporla (durumunu güncelle)
    final now = DateTime.now();
    for (final key in expenseKeys) {
      final expense = _expenseBox.get(key);
      if (expense != null) {
        expense.status = ExpenseStatus.reported;
        expense.reportedAt = now;
        expense.reportNumber = resolvedReportNumber;
        await _expenseBox.put(key, expense);
      }
    }

    _loadReports();
    return report;
  }

  /// Raporu sil (masrafları geri yükle)
  Future<void> deleteReport(int key) async {
    final report = _reportBox.get(key);
    if (report == null) return;

    // Masrafları geri "bekliyor" durumuna al
    for (final expenseKey in report.expenseKeys) {
      final expense = _expenseBox.get(expenseKey);
      if (expense != null) {
        expense.status = ExpenseStatus.pending;
        expense.reportedAt = null;
        expense.reportNumber = null;
        await _expenseBox.put(expenseKey, expense);
      }
    }

    // Raporu sil
    await _reportBox.delete(key);
    _loadReports();
  }

  /// Tahsilat kaydet
  Future<void> collectReport(
    int key, {
    required CollectionType type,
    required double amount,
    String? note,
  }) async {
    final report = _reportBox.get(key);
    if (report == null) return;

    final now = DateTime.now();

    // Raporu güncelle
    report.collectedAmount =
        (report.collectedAmount + amount).clamp(0, report.totalAmount);
    report.isCollected = report.remainingAmount <= 0.01;
    report.collectionType = type;
    report.collectionDate = now;
    report.collectionNote = note;
    await _reportBox.put(key, report);

    if (report.isCollected) {
      // İlgili masrafları da güncelle
      for (final expenseKey in report.expenseKeys) {
        final expense = _expenseBox.get(expenseKey);
        if (expense != null) {
          expense.status = ExpenseStatus.collected;
          expense.collectionType = type;
          expense.collectionDate = now;
          expense.collectionNote = note;
          await _expenseBox.put(expenseKey, expense);
        }
      }
    }

    _loadReports();
  }

  /// PDF yolunu kaydet
  Future<void> updatePdfPath(int key, String pdfPath) async {
    final report = _reportBox.get(key);
    if (report != null) {
      report.pdfPath = pdfPath;
      await _reportBox.put(key, report);
      _loadReports();
    }
  }

  /// Raporun masraflarını getir
  List<Expense> getReportExpenses(ExpenseReport report) {
    final expenses = <Expense>[];
    for (final key in report.expenseKeys) {
      final expense = _expenseBox.get(key);
      if (expense != null) {
        expenses.add(expense);
      }
    }
    // Tarihe göre sırala
    expenses.sort((a, b) => a.date.compareTo(b.date));
    return expenses;
  }

  @override
  void dispose() {
    _reportSubscription?.cancel();
    _expenseSubscription?.cancel();
    super.dispose();
  }
}
