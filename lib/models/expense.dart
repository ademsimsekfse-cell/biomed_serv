import 'package:hive/hive.dart';
import './customer.dart';
import './device.dart';

part 'expense.g.dart';

/// Masraf durum enumu
@HiveType(typeId: 31)
enum ExpenseStatus {
  @HiveField(0)
  pending, // Bekliyor (raporlanmamış)
  @HiveField(1)
  reported, // Raporlandı
  @HiveField(2)
  collected, // Tahsil edildi
}

/// Tahsilat tipi enumu
@HiveType(typeId: 32)
enum CollectionType {
  @HiveField(0)
  eft, // EFT/Havale
  @HiveField(1)
  cash, // Nakit
  @HiveField(2)
  offset, // Mahsup
}

/// Masraf modeli
@HiveType(typeId: 33)
class Expense extends HiveObject {
  @HiveField(0)
  late DateTime date; // Masraf tarihi

  @HiveField(1)
  late String description; // Açıklama

  @HiveField(2)
  double amount; // Tutar

  @HiveField(3)
  Customer? customer; // İlişkili kurum (opsiyonel)

  @HiveField(4)
  Device? device; // İlişkili cihaz (opsiyonel)

  @HiveField(5)
  late ExpenseStatus status; // Durum

  @HiveField(6)
  CollectionType? collectionType; // Tahsilat tipi (tahsil edildiyse)

  @HiveField(7)
  DateTime? collectionDate; // Tahsilat tarihi

  @HiveField(8)
  String? collectionNote; // Tahsilat notu

  @HiveField(9)
  late DateTime createdAt; // Kayıt tarihi

  @HiveField(10)
  DateTime? reportedAt; // Raporlama tarihi

  @HiveField(11)
  String? reportNumber; // Rapor numarası (raporlandıysa)

  Expense({
    required this.date,
    required this.description,
    required this.amount,
    this.customer,
    this.device,
    this.status = ExpenseStatus.pending,
    this.collectionType,
    this.collectionDate,
    this.collectionNote,
    this.reportedAt,
    this.reportNumber,
  }) : createdAt = DateTime.now();

  /// Bekleyen masraf mı?
  bool get isPending => status == ExpenseStatus.pending;

  /// Raporlanmış mı?
  bool get isReported => status == ExpenseStatus.reported;

  /// Tahsil edilmiş mi?
  bool get isCollected => status == ExpenseStatus.collected;

  /// İlişkili kurum/cihaz adı
  String get relatedEntityName {
    if (customer != null && device != null) {
      return '${customer!.name} • ${device!.name} / ${device!.serialNumber}';
    }
    if (customer != null) return customer!.name;
    if (device != null) return '${device!.name} / ${device!.serialNumber}';
    return '-';
  }

  /// Durum metni
  String get statusText {
    switch (status) {
      case ExpenseStatus.pending:
        return 'Raporlanmayı Bekliyor';
      case ExpenseStatus.reported:
        return 'Raporlandı';
      case ExpenseStatus.collected:
        return 'Tahsil Edildi';
    }
  }

  /// Durum rengi
  int get statusColor {
    switch (status) {
      case ExpenseStatus.pending:
        return 0xFFFF9800; // Turuncu
      case ExpenseStatus.reported:
        return 0xFF2196F3; // Mavi
      case ExpenseStatus.collected:
        return 0xFF4CAF50; // Yeşil
    }
  }
}
