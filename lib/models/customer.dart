import 'package:hive/hive.dart';

part 'customer.g.dart';

@HiveType(typeId: 1)
class Customer extends HiveObject {
  @HiveField(0)
  late String name;

  @HiveField(1)
  late String address;

  @HiveField(2)
  late String phone;

  @HiveField(3)
  late String authorizedPerson;

  @HiveField(4)
  String? email; // Email adresi

  @HiveField(5)
  String? vergiNo; // Vergi numarası

  @HiveField(6)
  bool isActive; // Aktif/Pasif durumu (varsayılan: true)

  // YENİ: Birim Amiri Bilgileri
  @HiveField(7)
  String? unitManagerName; // Birim Amiri Ad Soyad

  @HiveField(8)
  String? unitManagerPhone; // Birim Amiri Telefon

  // YENİ: Birim Sorumlusu Bilgileri
  @HiveField(9)
  String? unitResponsibleName; // Birim Sorumlusu Ad Soyad

  @HiveField(10)
  String? unitResponsiblePhone; // Birim Sorumlusu Telefon

  Customer({
    required this.name,
    required this.address,
    required this.phone,
    required this.authorizedPerson,
    this.email,
    this.vergiNo,
    this.isActive = true, // Varsayılan olarak aktif
    this.unitManagerName,
    this.unitManagerPhone,
    this.unitResponsibleName,
    this.unitResponsiblePhone,
  });
}
