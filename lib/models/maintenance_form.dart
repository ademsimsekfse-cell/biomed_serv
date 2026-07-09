import 'package:hive/hive.dart';
import './device.dart';
import './stock.dart';
import './customer.dart';

part 'maintenance_form.g.dart';

@HiveType(typeId: 6)
class MaintenanceForm extends HiveObject {
  @HiveField(0)
  late String formNumber;

  @HiveField(1)
  late DateTime createdAt;

  @HiveField(2)
  late Customer customer;

  @HiveField(3)
  late Device device;

  @HiveField(4)
  late String maintenancePeriod; // Bakım Periyodu (örn: "3 Ay")

  @HiveField(5)
  late List<String> actionsTaken; // Seçilen işlemler

  @HiveField(6)
  String? notes; // Ekstra notlar

  @HiveField(7)
  late HiveList<Stock> partsUsed; // Kullanılan tüm parçalar

  @HiveField(8)
  String? finalStatus; // Cihazın son durumu

  @HiveField(9)
  String? technicianSignature; // Base64 encoded image

  @HiveField(10)
  String? customerSignature; // Base64 encoded image

  @HiveField(11)
  String? technicianName;

  @HiveField(12)
  String? customerName;

  @HiveField(13)
  String? pdfPath;

  MaintenanceForm({
    required this.formNumber,
    required this.createdAt,
    required this.customer,
    required this.device,
    required this.maintenancePeriod,
    required this.actionsTaken,
    this.notes,
    required this.partsUsed,
    this.finalStatus,
    this.technicianSignature,
    this.customerSignature,
    this.technicianName,
    this.customerName,
    this.pdfPath,
  });
}
