import 'package:hive/hive.dart';
import './device_personel.dart';

part 'device.g.dart';

/// Cihaz sahiplik durumu enum
@HiveType(typeId: 20)
enum OwnershipStatus {
  @HiveField(0)
  sold, // Satılmış
  @HiveField(1)
  rented, // Kiralık
}

/// Cihaz modül tipi enum
@HiveType(typeId: 21)
enum DeviceModuleType {
  @HiveField(0)
  standalone, // Tekli cihaz
  @HiveField(1)
  modularControl, // Modüler - Kontrol Modülü (Ana)
  @HiveField(2)
  modularProcessing, // Modüler - İşlem Modülü (Alt)
}

@HiveType(typeId: 2)
class Device extends HiveObject {
  @HiveField(0)
  late String name;

  @HiveField(1)
  late String brand;

  @HiveField(2)
  late String model;

  @HiveField(3)
  late String serialNumber;

  @HiveField(4)
  HiveObject? customer; // Bağlı olduğu kurum

  @HiveField(5)
  HiveObject? tender; // Ait olduğu ihale (opsiyonel)

  @HiveField(6)
  DateTime? productionDate; // Üretim Tarihi (Kontrol modülü değilse)

  @HiveField(7)
  DateTime? installationDate; // Kurulum Tarihi (opsiyonel)

  @HiveField(8)
  int? economicLife; // Ekonomik Ömür (Kontrol modülü değilse)

  @HiveField(9)
  String? group; // Cihaz Grubu (Bakım Şablonları için)

  @HiveField(10)
  String? barcode; // Barkod

  // YENİ ALANLAR
  @HiveField(11)
  DeviceModuleType moduleType; // Standalone / Kontrol / İşlem

  @HiveField(12)
  OwnershipStatus ownershipStatus; // Satılmış / Kiralık

  @HiveField(13)
  HiveObject? controlModule; // Bağlı olduğu ana kontrol modülü (İşlem modülleri için)

  @HiveField(14)
  int? serviceDuration; // Hizmet süresi (ay olarak, Kontrol modülü değilse)

  @HiveField(15)
  DevicePersonel? responsiblePerson; // Sorumlu personel

  @HiveField(16)
  DateTime? warrantyStartDate; // Garanti başlangıç

  @HiveField(17)
  DateTime? warrantyEndDate; // Garanti bitiş

  @HiveField(18)
  String? location; // Fiziksel lokasyon (oda, kat, bölüm)

  @HiveField(19)
  String? deviceCategory; // Cihaz kategorisi (Radyoloji, Laboratuvar, vb.)

  Device({
    required this.name,
    required this.brand,
    required this.model,
    required this.serialNumber,
    this.customer,
    this.tender,
    this.productionDate,
    this.installationDate,
    this.economicLife,
    this.group,
    this.barcode,
    this.moduleType = DeviceModuleType.standalone, // Varsayılan standalone
    this.ownershipStatus = OwnershipStatus.sold, // Varsayılan satılmış
    this.controlModule, // İşlem modülleri için
    this.serviceDuration,
    this.responsiblePerson,
    this.warrantyStartDate,
    this.warrantyEndDate,
    this.location,
    this.deviceCategory,
  });

  /// Bu cihaz kontrol modülü mü?
  bool get isControlModule => moduleType == DeviceModuleType.modularControl;

  /// Bu cihaz işlem modülü mü?
  bool get isProcessingModule => moduleType == DeviceModuleType.modularProcessing;

  /// Bu cihaz standalone mı?
  bool get isStandalone => moduleType == DeviceModuleType.standalone;

  /// Detaylı alanlar gösterilmeli mi? (Kontrol modülü değilse)
  bool get showDetailedFields => !isControlModule;
}
