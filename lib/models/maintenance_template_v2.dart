import 'package:hive/hive.dart';

part 'maintenance_template_v2.g.dart';

/// Bakım şablonu satır modeli
/// Her bir bakım adımı/parçası için
@HiveType(typeId: 24)
class MaintenanceTemplateLine {
  @HiveField(0)
  late String description; // Bakım açıklaması (örn: "Filtre temizliği")

  @HiveField(1)
  bool isRequired; // Zorunlu mu?

  @HiveField(2)
  String? partName; // Kullanılacak parça adı (opsiyonel)

  @HiveField(3)
  int? partQuantity; // Parça miktarı (opsiyonel)

  @HiveField(4)
  String? stockReferenceNo; // Stok referans no (varsa)

  MaintenanceTemplateLine({
    required this.description,
    this.isRequired = true,
    this.partName,
    this.partQuantity,
    this.stockReferenceNo,
  });
}

/// Bakım periyot tipi enum
@HiveType(typeId: 25)
enum MaintenancePeriodType {
  @HiveField(0)
  weekly, // Haftalık
  @HiveField(1)
  monthly, // Aylık
  @HiveField(2)
  quarterly, // 3 Aylık
  @HiveField(3)
  biannual, // 6 Aylık
  @HiveField(4)
  annual, // Yıllık
  @HiveField(5)
  biennial, // 2 Yıllık
  @HiveField(6)
  custom, // Özel (gün olarak)
}

/// Gelişmiş Bakım Şablonu Modeli (Cihaz Modeline Özel)
@HiveType(typeId: 26)
class MaintenanceTemplateV2 extends HiveObject {
  @HiveField(0)
  late String name; // Şablon adı (örn: "Chemtry C8000 Bakımı")

  @HiveField(1)
  String? description; // Şablon açıklaması

  @HiveField(2)
  String? deviceModel; // Hangi cihaz modeli için? (örn: "Chemtry C8000")

  @HiveField(3)
  String? deviceBrand; // Cihaz markası (örn: "Siemens")

  @HiveField(4)
  MaintenancePeriodType periodType; // Periyot tipi

  @HiveField(5)
  int? customPeriodDays; // Özel periyot gün sayısı

  @HiveField(6)
  List<MaintenanceTemplateLine> lines; // Bakım satırları

  @HiveField(7)
  late DateTime createdAt;

  @HiveField(8)
  late DateTime updatedAt;

  @HiveField(9)
  bool isActive; // Aktif mi?

  MaintenanceTemplateV2({
    required this.name,
    this.description,
    this.deviceModel,
    this.deviceBrand,
    this.periodType = MaintenancePeriodType.monthly,
    this.customPeriodDays,
    List<MaintenanceTemplateLine>? lines,
    this.isActive = true,
  })  : lines = lines ?? [],
        createdAt = DateTime.now(),
        updatedAt = DateTime.now();

  /// Periyot açıklaması
  String get periodDescription {
    switch (periodType) {
      case MaintenancePeriodType.weekly:
        return 'Haftalık';
      case MaintenancePeriodType.monthly:
        return 'Aylık';
      case MaintenancePeriodType.quarterly:
        return '3 Aylık';
      case MaintenancePeriodType.biannual:
        return '6 Aylık';
      case MaintenancePeriodType.annual:
        return 'Yıllık';
      case MaintenancePeriodType.biennial:
        return '2 Yıllık';
      case MaintenancePeriodType.custom:
        return customPeriodDays != null ? '$customPeriodDays Günde Bir' : 'Özel';
    }
  }

  /// Cihaz modeli tanımlı mı?
  bool get hasDeviceModel => deviceModel != null && deviceModel!.isNotEmpty;

  /// Tam cihaz tanımı
  String get fullDeviceDescription {
    if (deviceBrand != null && deviceModel != null) {
      return '$deviceBrand $deviceModel';
    } else if (deviceModel != null) {
      return deviceModel!;
    } else if (deviceBrand != null) {
      return deviceBrand!;
    }
    return 'Genel Şablon';
  }

  /// Bir sonraki bakım tarihini hesapla
  DateTime calculateNextMaintenance(DateTime lastMaintenanceDate) {
    switch (periodType) {
      case MaintenancePeriodType.weekly:
        return lastMaintenanceDate.add(const Duration(days: 7));
      case MaintenancePeriodType.monthly:
        return DateTime(
          lastMaintenanceDate.year,
          lastMaintenanceDate.month + 1,
          lastMaintenanceDate.day,
        );
      case MaintenancePeriodType.quarterly:
        return DateTime(
          lastMaintenanceDate.year,
          lastMaintenanceDate.month + 3,
          lastMaintenanceDate.day,
        );
      case MaintenancePeriodType.biannual:
        return DateTime(
          lastMaintenanceDate.year,
          lastMaintenanceDate.month + 6,
          lastMaintenanceDate.day,
        );
      case MaintenancePeriodType.annual:
        return DateTime(
          lastMaintenanceDate.year + 1,
          lastMaintenanceDate.month,
          lastMaintenanceDate.day,
        );
      case MaintenancePeriodType.biennial:
        return DateTime(
          lastMaintenanceDate.year + 2,
          lastMaintenanceDate.month,
          lastMaintenanceDate.day,
        );
      case MaintenancePeriodType.custom:
        return lastMaintenanceDate.add(
          Duration(days: customPeriodDays ?? 30),
        );
    }
  }

  @override
  String toString() {
    return '$name ($fullDeviceDescription) - $periodDescription';
  }
}
