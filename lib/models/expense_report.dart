import 'package:hive/hive.dart';
import './expense.dart';
import './technician.dart';

part 'expense_report.g.dart';

/// Masraf raporu modeli
@HiveType(typeId: 34)
class ExpenseReport extends HiveObject {
  @HiveField(0)
  late String reportNumber; // Rapor numarası

  @HiveField(1)
  late DateTime createdAt; // Oluşturma tarihi

  @HiveField(2)
  Technician technician; // Teknisyen

  @HiveField(3)
  List<int> expenseKeys; // Masraf key listesi (ilişkiler için)

  @HiveField(4)
  double totalAmount; // Toplam tutar

  @HiveField(5)
  String? pdfPath; // PDF dosya yolu

  @HiveField(6)
  late bool isCollected; // Tahsil edildi mi?

  @HiveField(7)
  CollectionType? collectionType; // Tahsilat tipi

  @HiveField(8)
  DateTime? collectionDate; // Tahsilat tarihi

  @HiveField(9)
  String? collectionNote; // Tahsilat notu

  @HiveField(10)
  String? notes; // Genel notlar

  @HiveField(11)
  double collectedAmount;

  ExpenseReport({
    required this.reportNumber,
    required this.technician,
    required this.expenseKeys,
    required this.totalAmount,
    this.pdfPath,
    this.isCollected = false,
    this.collectionType,
    this.collectionDate,
    this.collectionNote,
    this.notes,
    this.collectedAmount = 0,
  }) : createdAt = DateTime.now();

  double get remainingAmount =>
      (totalAmount - collectedAmount).clamp(0, totalAmount).toDouble();

  /// Rapor numarası oluşturucu
  static String generateReportNumber() {
    final now = DateTime.now();
    return 'MASRAF-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecond.toString().padLeft(4, '0')}';
  }
}
