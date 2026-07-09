import 'package:hive/hive.dart';
import './customer.dart';
import './device.dart';
import './stock.dart';

part 'service_form.g.dart';

@HiveType(typeId: 5)
class ServiceForm extends HiveObject {
  @HiveField(0)
  late String formNumber;

  @HiveField(1)
  late DateTime createdAt;

  @HiveField(2)
  late Customer customer;

  @HiveField(3)
  late Device device;

  @HiveField(4)
  String? problemDescription;

  @HiveField(5)
  String? actionsTaken;

  @HiveField(6)
  String? finalStatus;

  @HiveField(7)
  List<String> problemTypes;

  @HiveField(8)
  String? resultStatus;

  @HiveField(9)
  String? feeStatus;

  @HiveField(10)
  DateTime? problemDateTime;

  @HiveField(11)
  DateTime? interventionDateTime;

  @HiveField(12)
  DateTime? solutionDateTime;

  @HiveField(13)
  int? travelHours;

  @HiveField(14)
  int? repairHours;

  @HiveField(15)
  int? trainingHours;

  @HiveField(16)
  int? assemblyHours;

  @HiveField(17)
  int? modificationHours;

  @HiveField(18)
  double? totalFee;

  @HiveField(19)
  double? totalFeeWithVAT;

  @HiveField(20)
  late HiveList<Stock> partsUsed;

  @HiveField(21)
  String? technicianSignature; // Base64 encoded image

  @HiveField(22)
  String? customerSignature; // Base64 encoded image

  @HiveField(23)
  String? technicianName;

  @HiveField(24)
  String? customerName;

  @HiveField(25)
  String? sourceTicketNumber;

  @HiveField(26)
  String? pdfPath;

  ServiceForm({
    required this.formNumber,
    required this.createdAt,
    required this.customer,
    required this.device,
    this.problemDescription,
    this.actionsTaken,
    this.finalStatus,
    required this.problemTypes,
    this.resultStatus,
    this.feeStatus,
    this.problemDateTime,
    this.interventionDateTime,
    this.solutionDateTime,
    this.travelHours,
    this.repairHours,
    this.trainingHours,
    this.assemblyHours,
    this.modificationHours,
    this.totalFee,
    this.totalFeeWithVAT,
    required this.partsUsed,
    this.technicianSignature,
    this.customerSignature,
    this.technicianName,
    this.customerName,
    this.sourceTicketNumber,
    this.pdfPath,
  });
}
