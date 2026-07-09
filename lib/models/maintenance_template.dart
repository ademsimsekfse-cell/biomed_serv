import 'package:hive/hive.dart';
import './stock.dart';

part 'maintenance_template.g.dart';

@HiveType(typeId: 7) // Yeni ve benzersiz bir typeId
class MaintenanceTemplate extends HiveObject {
  @HiveField(0)
  late String name; // Şablon Adı (Örn: "X Marka Temel Bakım")

  @HiveField(1)
  String? group; // İlişkili Cihaz Grubu

  @HiveField(2)
  late List<String> actions; // Yapılacak standart işlemler

  @HiveField(3)
  late HiveList<Stock> requiredParts; // Gerekli standart parçalar

  MaintenanceTemplate({
    required this.name,
    this.group,
    required this.actions,
    required this.requiredParts,
  });
}
