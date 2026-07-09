import 'dart:async';

import 'package:biomed_serv/models/technician.dart';
import 'package:biomed_serv/models/fault_ticket.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class FaultTicketProvider with ChangeNotifier {
  final DatabaseService _dbService;
  late Box<FaultTicket> _ticketBox;
  StreamSubscription<BoxEvent>? _ticketSubscription;

  List<FaultTicket> _tickets = [];
  List<FaultTicket> get tickets => _tickets;

  // AÃ§Ä±k kayÄ±tlar (Beklemede + Devam Ediyor + ParÃ§a Bekleniyor + Cihaz Pasif)
  List<FaultTicket> get openTickets => _tickets.where((t) => t.isOpen).toList()
    ..sort((a, b) => b.reportDateTime.compareTo(a.reportDateTime));

  // Bekleyen kayÄ±tlar (HenÃ¼z mÃ¼dahale edilmemiÅŸ)
  List<FaultTicket> get pendingTickets =>
      _tickets.where((t) => t.status == TicketStatus.pending).toList()
        ..sort((a, b) => b.reportDateTime.compareTo(a.reportDateTime));

  // Planli kayitlar (servis zamani atanmis)
  List<FaultTicket> get scheduledTickets =>
      _tickets.where((t) => t.isScheduled).toList()
        ..sort((a, b) {
          final aDate = a.scheduledAt ?? a.reportDateTime;
          final bDate = b.scheduledAt ?? b.reportDateTime;
          return aDate.compareTo(bDate);
        });

  // Devam eden kayÄ±tlar
  List<FaultTicket> get inProgressTickets =>
      _tickets.where((t) => t.status == TicketStatus.inProgress).toList()
        ..sort((a, b) => b.reportDateTime.compareTo(a.reportDateTime));

  List<FaultTicket> get interventionTickets => _tickets
      .where(
        (ticket) =>
            ticket.status == TicketStatus.inProgress ||
            ticket.status == TicketStatus.waitingPart ||
            ticket.status == TicketStatus.devicePassive,
      )
      .toList()
    ..sort((a, b) => b.reportDateTime.compareTo(a.reportDateTime));

  // ParÃ§a bekleyen kayÄ±tlar
  List<FaultTicket> get waitingPartTickets =>
      _tickets.where((t) => t.status == TicketStatus.waitingPart).toList()
        ..sort((a, b) => b.reportDateTime.compareTo(a.reportDateTime));

  // TamamlanmÄ±ÅŸ kayÄ±tlar
  List<FaultTicket> get completedTickets =>
      _tickets.where((t) => t.status == TicketStatus.completed).toList()
        ..sort((a, b) => b.reportDateTime.compareTo(a.reportDateTime));

  // Ä°ptal edilmiÅŸ kayÄ±tlar
  List<FaultTicket> get cancelledTickets =>
      _tickets.where((t) => t.status == TicketStatus.cancelled).toList()
        ..sort((a, b) => b.reportDateTime.compareTo(a.reportDateTime));

  // AylÄ±k istatistikler
  Map<String, int> get monthlyStats {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    return {
      'total': _tickets.where((t) => t.createdAt.isAfter(startOfMonth)).length,
      'completed': _tickets
          .where((t) =>
              t.status == TicketStatus.completed &&
              t.endDateTime != null &&
              t.endDateTime!.isAfter(startOfMonth))
          .length,
      'scheduled': scheduledTickets.length,
      'pending': pendingTickets.length,
      'inProgress': inProgressTickets.length,
      'waitingPart': waitingPartTickets.length,
    };
  }

  int get overdueOpenTicketsCount => _tickets.where((t) => t.isOverdue).length;

  FaultTicketProvider(this._dbService) {
    _ticketBox = _dbService.faultTicketsBox;
    _ticketSubscription = _ticketBox.watch().listen((_) => _loadTickets());
    _loadTickets();
  }

  @override
  void dispose() {
    _ticketSubscription?.cancel();
    super.dispose();
  }

  void _loadTickets() {
    _tickets = _ticketBox.values.toList();
    notifyListeners();
  }

  /// Yeni arÄ±za kaydÄ± ekle
  Future<void> addTicket(FaultTicket ticket) async {
    await _ticketBox.add(ticket);
    _loadTickets();
  }

  /// ArÄ±za kaydÄ± gÃ¼ncelle
  Future<void> updateTicket(int key, FaultTicket ticket) async {
    ticket.updatedAt = DateTime.now();
    await _ticketBox.put(key, ticket);
    _loadTickets();
  }

  /// ArÄ±za kaydÄ± sil
  Future<void> deleteTicket(int key) async {
    await _ticketBox.delete(key);
    _loadTickets();
  }

  /// Durum deÄŸiÅŸtir
  Future<void> updateStatus(int key, TicketStatus newStatus) async {
    final ticket = _ticketBox.get(key);
    if (ticket == null) return;

    ticket.status = newStatus;

    // Duruma gÃ¶re tarih gÃ¼ncelle
    if (newStatus == TicketStatus.inProgress && ticket.startDateTime == null) {
      ticket.startDateTime = DateTime.now();
    }
    if (newStatus == TicketStatus.completed) {
      ticket.endDateTime = DateTime.now();
    }

    ticket.updatedAt = DateTime.now();
    await _ticketBox.put(key, ticket);
    _loadTickets();
  }

  /// MÃ¼dahale baÅŸlat (Devam Ediyor yap)
  Future<void> startIntervention(int key, String technicianName) async {
    final ticket = _ticketBox.get(key);
    if (ticket == null) return;

    ticket.status = TicketStatus.inProgress;
    ticket.startDateTime = DateTime.now();
    ticket.technicianName = technicianName;
    ticket.updatedAt = DateTime.now();

    await _ticketBox.put(key, ticket);
    _loadTickets();
  }

  Future<void> assignTechnicianToTicket(
    int key, {
    required Technician technician,
    String? technicianId,
  }) async {
    final ticket = _ticketBox.get(key);
    if (ticket == null) return;

    ticket.technician = technician;
    ticket.technicianName = technician.fullName;
    ticket.assignedTechnicianId =
        technicianId ?? technician.key?.toString() ?? '';
    ticket.updatedAt = DateTime.now();

    await _ticketBox.put(key, ticket);
    _loadTickets();
  }

  Future<void> clearTicketTechnician(int key) async {
    final ticket = _ticketBox.get(key);
    if (ticket == null) return;

    ticket.technician = null;
    ticket.technicianName = null;
    ticket.assignedTechnicianId = null;
    ticket.updatedAt = DateTime.now();

    await _ticketBox.put(key, ticket);
    _loadTickets();
  }

  Future<void> rescheduleTicket(int key, DateTime? scheduledAt) async {
    final ticket = _ticketBox.get(key);
    if (ticket == null) return;

    ticket.scheduledAt = scheduledAt;
    ticket.updatedAt = DateTime.now();

    await _ticketBox.put(key, ticket);
    _loadTickets();
  }

  Future<void> updateTicketPriority(int key, String priority) async {
    final ticket = _ticketBox.get(key);
    if (ticket == null) return;

    ticket.priority = priority;
    ticket.updatedAt = DateTime.now();

    await _ticketBox.put(key, ticket);
    _loadTickets();
  }

  /// ParÃ§a bekleme durumuna geÃ§
  Future<void> setWaitingPart(int key) async {
    await updateStatus(key, TicketStatus.waitingPart);
  }

  /// Cihaz pasif yap
  Future<void> setDevicePassive(int key) async {
    await updateStatus(key, TicketStatus.devicePassive);
  }

  /// Tamamla
  Future<void> completeTicket(
    int key, {
    required String actionsTaken,
    required String finalStatus,
    required String technicianSignature,
    required String responsibleName,
    required String responsibleSignature,
    String? serviceFormNumber,
  }) async {
    final ticket = _ticketBox.get(key);
    if (ticket == null) return;

    ticket.status = TicketStatus.completed;
    ticket.actionsTaken = actionsTaken;
    ticket.finalStatus = finalStatus;
    ticket.technicianSignature = technicianSignature;
    ticket.responsibleName = responsibleName;
    ticket.responsibleSignature = responsibleSignature;
    ticket.serviceFormNumber = serviceFormNumber;
    ticket.endDateTime = DateTime.now();
    ticket.updatedAt = DateTime.now();

    await _ticketBox.put(key, ticket);
    _loadTickets();
  }

  /// Ä°ptal et
  Future<void> cancelTicket(int key, {String? reason}) async {
    final ticket = _ticketBox.get(key);
    if (ticket == null) return;

    ticket.status = TicketStatus.cancelled;
    if (reason != null) {
      ticket.finalStatus = 'Ä°ptal Sebebi: $reason';
    }
    ticket.updatedAt = DateTime.now();

    await _ticketBox.put(key, ticket);
    _loadTickets();
  }

  /// ID'ye gÃ¶re arÄ±za kaydÄ± bul
  FaultTicket? getTicketByKey(int key) {
    return _ticketBox.get(key);
  }

  /// TÃ¼m kayÄ±tlarÄ± yeniden yÃ¼kle
  Future<void> refresh() async {
    _loadTickets();
  }
}
