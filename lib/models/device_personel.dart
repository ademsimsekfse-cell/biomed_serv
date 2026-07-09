import 'package:hive/hive.dart';

part 'device_personel.g.dart';

/// Cihaza atanmış sorumlu personel modeli
@HiveType(typeId: 22)
class DevicePersonel extends HiveObject {
  @HiveField(0)
  late String firstName; // İsim

  @HiveField(1)
  late String lastName; // Soyisim

  @HiveField(2)
  String? phone; // Telefon

  @HiveField(3)
  String? email; // E-posta

  @HiveField(4)
  String? title; // Unvan/Departman (opsiyonel)

  @HiveField(5)
  DateTime? assignedDate; // Atanma tarihi

  @HiveField(6)
  HiveObject? customer; // Bağlı olduğu kurum/cari

  DevicePersonel({
    required this.firstName,
    required this.lastName,
    this.phone,
    this.email,
    this.title,
    this.assignedDate,
    this.customer,
  });

  /// Tam ad döndürür
  String get fullName => '$firstName $lastName';

  @override
  String toString() {
    return fullName;
  }
}
