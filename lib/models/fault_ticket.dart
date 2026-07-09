import 'package:biomed_serv/models/customer.dart';
import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/models/technician.dart';
import 'package:hive/hive.dart';

part 'fault_ticket.g.dart';

@HiveType(typeId: 41)
enum TicketStatus {
  @HiveField(0)
  pending,
  @HiveField(1)
  inProgress,
  @HiveField(2)
  waitingPart,
  @HiveField(3)
  devicePassive,
  @HiveField(4)
  completed,
  @HiveField(5)
  cancelled,
}

@HiveType(typeId: 42)
enum TicketType {
  @HiveField(0)
  malfunction,
  @HiveField(1)
  installation,
  @HiveField(2)
  other,
}

@HiveType(typeId: 40)
class FaultTicket extends HiveObject {
  @HiveField(0)
  String ticketNumber;

  @HiveField(1)
  Customer customer;

  @HiveField(2)
  Device device;

  @HiveField(3)
  Technician? technician;

  @HiveField(4)
  DateTime reportDateTime;

  @HiveField(5)
  DateTime? startDateTime;

  @HiveField(6)
  DateTime? endDateTime;

  @HiveField(7)
  TicketType ticketType;

  @HiveField(8)
  String problemDescription;

  @HiveField(9)
  String? actionsTaken;

  @HiveField(10)
  TicketStatus status;

  @HiveField(11)
  String? finalStatus;

  @HiveField(12)
  String? technicianSignature;

  @HiveField(13)
  String? responsibleName;

  @HiveField(14)
  String? responsibleSignature;

  @HiveField(15)
  DateTime createdAt;

  @HiveField(16)
  DateTime? updatedAt;

  @HiveField(17)
  String? technicianName;

  @HiveField(18)
  String? serviceFormNumber;

  @HiveField(19)
  String? assignedTechnicianId;

  @HiveField(20)
  String? priority;

  @HiveField(21)
  DateTime? scheduledAt;

  FaultTicket({
    required this.ticketNumber,
    required this.customer,
    required this.device,
    this.technician,
    required this.reportDateTime,
    this.startDateTime,
    this.endDateTime,
    required this.ticketType,
    required this.problemDescription,
    this.actionsTaken,
    this.status = TicketStatus.pending,
    this.finalStatus,
    this.technicianSignature,
    this.responsibleName,
    this.responsibleSignature,
    required this.createdAt,
    this.updatedAt,
    this.technicianName,
    this.serviceFormNumber,
    this.assignedTechnicianId,
    this.priority = 'normal',
    this.scheduledAt,
  });

  static String generateTicketNumber() {
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final random = now.millisecondsSinceEpoch % 1000;
    return 'ARZ-$dateStr-${random.toString().padLeft(3, '0')}';
  }

  String get statusText {
    switch (status) {
      case TicketStatus.pending:
        return 'Beklemede';
      case TicketStatus.inProgress:
        return 'Devam Ediyor';
      case TicketStatus.waitingPart:
        return 'Parca Bekleniyor';
      case TicketStatus.devicePassive:
        return 'Cihaz Pasif';
      case TicketStatus.completed:
        return 'Tamamlandi';
      case TicketStatus.cancelled:
        return 'Iptal Edildi';
    }
  }

  String get ticketTypeText {
    switch (ticketType) {
      case TicketType.malfunction:
        return 'Ariza';
      case TicketType.installation:
        return 'Montaj';
      case TicketType.other:
        return 'Diger';
    }
  }

  String get priorityText {
    switch (priority) {
      case 'low':
        return 'Dusuk';
      case 'high':
        return 'Yuksek';
      case 'urgent':
        return 'Acil';
      case 'normal':
      default:
        return 'Normal';
    }
  }

  int get statusColor {
    switch (status) {
      case TicketStatus.pending:
        return 0xFFFFA726;
      case TicketStatus.inProgress:
        return 0xFF42A5F5;
      case TicketStatus.waitingPart:
        return 0xFFAB47BC;
      case TicketStatus.devicePassive:
        return 0xFFEF5350;
      case TicketStatus.completed:
        return 0xFF66BB6A;
      case TicketStatus.cancelled:
        return 0xFF78909C;
    }
  }

  bool get isCompleted => status == TicketStatus.completed;

  bool get isOpen =>
      status != TicketStatus.completed && status != TicketStatus.cancelled;

  bool get isScheduled =>
      scheduledAt != null && status == TicketStatus.pending;

  bool get isOverdue =>
      isOpen && scheduledAt != null && scheduledAt!.isBefore(DateTime.now());

  bool get hasServiceForm =>
      serviceFormNumber != null && serviceFormNumber!.trim().isNotEmpty;

  String get workflowStageText {
    if (status == TicketStatus.completed) return 'Tamamlandi';
    if (status == TicketStatus.cancelled) return 'Iptal edildi';
    if (status == TicketStatus.waitingPart) return 'Parca bekleniyor';
    if (status == TicketStatus.devicePassive) return 'Cihaz pasif';
    if (status == TicketStatus.inProgress) return 'Sahada';
    if (isScheduled) return 'Planlandi';
    return 'Beklemede';
  }
}
