import 'package:hive/hive.dart';
import 'dart:typed_data';

part 'company_info.g.dart';

@HiveType(typeId: 50)  // typeId 20'den değiştirildi - OwnershipStatus ile çakışma çözümü
class CompanyInfo extends HiveObject {
  @HiveField(0)
  String companyName;

  @HiveField(1)
  String? taxNumber;

  @HiveField(2)
  String? taxOffice;

  @HiveField(3)
  String? address;

  @HiveField(4)
  String? phone;

  @HiveField(5)
  String? email;

  @HiveField(6)
  String? website;

  @HiveField(7)
  Uint8List? logoBytes;

  @HiveField(8)
  double? logoWidth;

  @HiveField(9)
  double? logoHeight;

  CompanyInfo({
    required this.companyName,
    this.taxNumber,
    this.taxOffice,
    this.address,
    this.phone,
    this.email,
    this.website,
    this.logoBytes,
    this.logoWidth = 150.0,
    this.logoHeight = 150.0,
  });

  bool get hasLogo => logoBytes != null && logoBytes!.isNotEmpty;
}
