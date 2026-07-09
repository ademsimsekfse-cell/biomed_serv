import 'package:hive/hive.dart';

part 'device_module.g.dart';

/// Modüler cihaz yapısı için ana-alt modül ilişkisi modeli
/// Bu model, bir kontrol modülüne bağlı tüm işlem modüllerini takip eder
@HiveType(typeId: 23)
class DeviceModule extends HiveObject {
  @HiveField(0)
  late HiveObject controlModule; // Ana kontrol modülü (Device)

  @HiveField(1)
  List<int> processingModuleKeys; // Bağlı işlem modüllerinin key'leri

  @HiveField(2)
  late DateTime createdAt; // Kayıt tarihi

  @HiveField(3)
  String? description; // Modül yapısı açıklaması

  DeviceModule({
    required this.controlModule,
    List<int>? processingModuleKeys,
    this.description,
  })  : processingModuleKeys = processingModuleKeys ?? [],
        createdAt = DateTime.now();

  /// Bağlı işlem modülü sayısı
  int get processingModuleCount => processingModuleKeys.length;

  /// İşlem modülü key ekle
  void addProcessingModuleKey(int key) {
    if (!processingModuleKeys.contains(key)) {
      processingModuleKeys.add(key);
    }
  }

  /// İşlem modülü key kaldır
  void removeProcessingModuleKey(int key) {
    processingModuleKeys.remove(key);
  }
}
