import 'package:biomed_serv/models/fault_ticket.dart';
import 'package:biomed_serv/providers/fault_ticket_provider.dart';
import 'package:biomed_serv/providers/technician_provider.dart';
import 'package:biomed_serv/screens/fault_ticket_detail_screen.dart';
import 'package:biomed_serv/services/lan_sync_service.dart';
import 'package:biomed_serv/services/technical_assignment_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class DesktopDispatchBoardScreen extends StatefulWidget {
  const DesktopDispatchBoardScreen({super.key});

  @override
  State<DesktopDispatchBoardScreen> createState() =>
      _DesktopDispatchBoardScreenState();
}

class _DesktopDispatchBoardScreenState extends State<DesktopDispatchBoardScreen> {
  _DispatchRange _range = _DispatchRange.today;
  _DispatchFocus _focus = _DispatchFocus.all;
  bool _openOnly = true;
  final _timeFormat = DateFormat('dd.MM HH:mm');

  @override
  Widget build(BuildContext context) {
    final faultProvider = context.watch<FaultTicketProvider>();
    final technicianProvider = context.watch<TechnicianProvider>();
    final assignmentService = context.watch<TechnicalAssignmentService>();

    final tickets = _filterTickets(
      faultProvider.tickets,
      assignmentService,
    );
    final grouped = _groupTickets(
      tickets: tickets,
      assignmentService: assignmentService,
    );
    final summary = _buildSummary(tickets, assignmentService);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gunluk Planlama'),
            Text(
              'Teknisyen yukunu ve planli isleri tek ekranda yonet.',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryGrid(summary),
          const SizedBox(height: 16),
          _buildFilterBar(technicianProvider.technicians.length),
          const SizedBox(height: 16),
          if (grouped.isEmpty)
            _buildEmptyState()
          else
            ...grouped.map((group) => _buildTechnicianLane(context, group)),
        ],
      ),
    );
  }

  List<FaultTicket> _filterTickets(
    List<FaultTicket> tickets,
    TechnicalAssignmentService assignmentService,
  ) {
    final now = DateTime.now();
    return tickets.where((ticket) {
      if (_openOnly && !ticket.isOpen) return false;

      switch (_focus) {
        case _DispatchFocus.all:
          break;
        case _DispatchFocus.urgent:
          if ((ticket.priority ?? 'normal') != 'urgent') return false;
          break;
        case _DispatchFocus.waitingPart:
          if (ticket.status != TicketStatus.waitingPart) return false;
          break;
        case _DispatchFocus.unassigned:
          if (_resolveTechnicianName(ticket, assignmentService) !=
              'Atama Bekliyor') {
            return false;
          }
          break;
        case _DispatchFocus.overdue:
          if (!ticket.isOverdue) return false;
          break;
      }

      switch (_range) {
        case _DispatchRange.today:
          final target = ticket.scheduledAt ?? ticket.reportDateTime;
          return DateUtils.isSameDay(target, now);
        case _DispatchRange.thisWeek:
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final endOfWeek = startOfWeek.add(const Duration(days: 7));
          final target = ticket.scheduledAt ?? ticket.reportDateTime;
          return !target.isBefore(
                DateTime(
                  startOfWeek.year,
                  startOfWeek.month,
                  startOfWeek.day,
                ),
              ) &&
              target.isBefore(
                DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day),
              );
        case _DispatchRange.allOpen:
          return _openOnly ? ticket.isOpen : true;
      }
    }).toList()
      ..sort((a, b) {
        final aDate = a.scheduledAt ?? a.reportDateTime;
        final bDate = b.scheduledAt ?? b.reportDateTime;
        return aDate.compareTo(bDate);
      });
  }

  List<_DispatchLane> _groupTickets({
    required List<FaultTicket> tickets,
    required TechnicalAssignmentService assignmentService,
  }) {
    final map = <String, List<FaultTicket>>{};
    final labels = <String, String>{};

    for (final ticket in tickets) {
      final technicianName = _resolveTechnicianName(ticket, assignmentService);
      map.putIfAbsent(technicianName, () => []).add(ticket);
      labels[technicianName] = technicianName;
    }

    final lanes = map.entries.map((entry) {
      final laneTickets = [...entry.value]
        ..sort((a, b) {
          final aDate = a.scheduledAt ?? a.reportDateTime;
          final bDate = b.scheduledAt ?? b.reportDateTime;
          return aDate.compareTo(bDate);
        });
      return _DispatchLane(
        technicianName: labels[entry.key] ?? entry.key,
        tickets: laneTickets,
      );
    }).toList()
      ..sort((a, b) {
        if (a.isUnassigned != b.isUnassigned) {
          return a.isUnassigned ? 1 : -1;
        }
        return b.tickets.length.compareTo(a.tickets.length);
      });

    return lanes;
  }

  String _resolveTechnicianName(
    FaultTicket ticket,
    TechnicalAssignmentService assignmentService,
  ) {
    if (ticket.technicianName != null && ticket.technicianName!.trim().isNotEmpty) {
      return ticket.technicianName!.trim();
    }
    if (ticket.technician != null) {
      return ticket.technician!.fullName;
    }
    final deviceAssignment = assignmentService.assignmentForDevice(ticket.device);
    if (deviceAssignment != null && deviceAssignment.technicianName.trim().isNotEmpty) {
      return deviceAssignment.technicianName.trim();
    }
    final customerAssignment = assignmentService.assignmentForCustomer(ticket.customer);
    if (customerAssignment != null &&
        customerAssignment.technicianName.trim().isNotEmpty) {
      return customerAssignment.technicianName.trim();
    }
    return 'Atama Bekliyor';
  }

  _DispatchSummary _buildSummary(
    List<FaultTicket> tickets,
    TechnicalAssignmentService assignmentService,
  ) {
    final overdue = tickets.where((ticket) => ticket.isOverdue).length;
    final planned = tickets.where((ticket) => ticket.isScheduled).length;
    final waitingPart =
        tickets.where((ticket) => ticket.status == TicketStatus.waitingPart).length;
    final unassigned = tickets
        .where((ticket) =>
            _resolveTechnicianName(ticket, assignmentService) ==
            'Atama Bekliyor')
        .length;

    return _DispatchSummary(
      total: tickets.length,
      planned: planned,
      overdue: overdue,
      waitingPart: waitingPart,
      unassigned: unassigned,
    );
  }

  Widget _buildSummaryGrid(_DispatchSummary summary) {
    final cards = [
      _DispatchSummaryCardData(
        label: 'Listelenen Is',
        value: summary.total,
        icon: Icons.assignment_outlined,
        color: const Color(0xFF1565C0),
      ),
      _DispatchSummaryCardData(
        label: 'Planli',
        value: summary.planned,
        icon: Icons.event_available_outlined,
        color: const Color(0xFF3949AB),
      ),
      _DispatchSummaryCardData(
        label: 'Geciken',
        value: summary.overdue,
        icon: Icons.alarm_on_outlined,
        color: const Color(0xFFC62828),
      ),
      _DispatchSummaryCardData(
        label: 'Parca Bekleyen',
        value: summary.waitingPart,
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFF8E24AA),
      ),
      _DispatchSummaryCardData(
        label: 'Atama Eksik',
        value: summary.unassigned,
        icon: Icons.person_off_outlined,
        color: const Color(0xFFEF6C00),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 1280
            ? 5
            : constraints.maxWidth >= 900
                ? 3
                : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: crossAxisCount >= 3 ? 2.1 : 1.9,
          ),
          itemBuilder: (context, index) {
            final item = cards[index];
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: item.color.withValues(alpha: 0.16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.icon, color: item.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.value.toString(),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: item.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterBar(int technicianCount) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.12)),
      ),
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'Plan araligi',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          ChoiceChip(
            label: const Text('Bugun'),
            selected: _range == _DispatchRange.today,
            onSelected: (_) => setState(() => _range = _DispatchRange.today),
          ),
          ChoiceChip(
            label: const Text('Bu Hafta'),
            selected: _range == _DispatchRange.thisWeek,
            onSelected: (_) => setState(() => _range = _DispatchRange.thisWeek),
          ),
          ChoiceChip(
            label: const Text('Tum Acik Isler'),
            selected: _range == _DispatchRange.allOpen,
            onSelected: (_) => setState(() => _range = _DispatchRange.allOpen),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Sadece acik olanlar'),
            selected: _openOnly,
            onSelected: (value) => setState(() => _openOnly = value),
          ),
          const SizedBox(width: 8),
          Text(
            '$technicianCount teknisyen gorunuyor',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Odak',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          ChoiceChip(
            label: const Text('Tumu'),
            selected: _focus == _DispatchFocus.all,
            onSelected: (_) => setState(() => _focus = _DispatchFocus.all),
          ),
          ChoiceChip(
            label: const Text('Acil'),
            selected: _focus == _DispatchFocus.urgent,
            onSelected: (_) => setState(() => _focus = _DispatchFocus.urgent),
          ),
          ChoiceChip(
            label: const Text('Parca Bekleyen'),
            selected: _focus == _DispatchFocus.waitingPart,
            onSelected: (_) =>
                setState(() => _focus = _DispatchFocus.waitingPart),
          ),
          ChoiceChip(
            label: const Text('Atama Eksik'),
            selected: _focus == _DispatchFocus.unassigned,
            onSelected: (_) =>
                setState(() => _focus = _DispatchFocus.unassigned),
          ),
          ChoiceChip(
            label: const Text('Geciken'),
            selected: _focus == _DispatchFocus.overdue,
            onSelected: (_) => setState(() => _focus = _DispatchFocus.overdue),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicianLane(BuildContext context, _DispatchLane lane) {
    final planned = lane.tickets.where((ticket) => ticket.isScheduled).length;
    final overdue = lane.tickets.where((ticket) => ticket.isOverdue).length;
    final waiting = lane.tickets
        .where((ticket) => ticket.status == TicketStatus.waitingPart)
        .length;

    final accent = lane.isUnassigned
        ? const Color(0xFFEF6C00)
        : const Color(0xFF1565C0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: accent.withValues(alpha: 0.14),
                  child: Icon(
                    lane.isUnassigned
                        ? Icons.person_off_outlined
                        : Icons.engineering_outlined,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lane.technicianName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _laneChip('Toplam ${lane.tickets.length}', accent),
                          _laneChip('Planli $planned', const Color(0xFF3949AB)),
                          _laneChip('Geciken $overdue', const Color(0xFFC62828)),
                          _laneChip('Parca $waiting', const Color(0xFF8E24AA)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: lane.tickets.map((ticket) {
                final targetTime = ticket.scheduledAt ?? ticket.reportDateTime;
                final stageColor = _statusColor(ticket.status);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: stageColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: stageColor.withValues(alpha: 0.12)),
                  ),
                  child: ListTile(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FaultTicketDetailScreen(ticket: ticket),
                        ),
                      );
                    },
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: stageColor.withValues(alpha: 0.14),
                      child: Icon(_statusIcon(ticket.status), color: stageColor),
                    ),
                    title: Text(
                      '${ticket.customer.name} - ${ticket.device.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${ticket.ticketNumber} â€¢ ${ticket.device.serialNumber}',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _laneChip(
                                _timeFormat.format(targetTime),
                                const Color(0xFF1565C0),
                              ),
                              _laneChip(ticket.workflowStageText, stageColor),
                              _laneChip(
                                ticket.priorityText,
                                _priorityColor(ticket.priority ?? 'normal'),
                              ),
                              if (ticket.hasServiceForm)
                                _laneChip(
                                  'Servise donustu',
                                  const Color(0xFF2E7D32),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    trailing: _buildTicketActions(ticket),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketActions(FaultTicket ticket) {
    return PopupMenuButton<_DispatchAction>(
      tooltip: 'Hizli islem',
      onSelected: (action) => _handleAction(action, ticket),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _DispatchAction.scheduleToday,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.today_outlined),
            title: Text('Bugune Al'),
          ),
        ),
        const PopupMenuItem(
          value: _DispatchAction.scheduleTomorrow,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.next_plan_outlined),
            title: Text('Yarina Ertele'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _DispatchAction.assignTechnician,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.engineering_outlined),
            title: Text('Teknisyen Degistir'),
          ),
        ),
        const PopupMenuItem(
          value: _DispatchAction.schedule,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.event_available_outlined),
            title: Text('Plan Tarihini Guncelle'),
          ),
        ),
        if (ticket.scheduledAt != null)
          const PopupMenuItem(
            value: _DispatchAction.clearSchedule,
            child: ListTile(
              dense: true,
              leading: Icon(Icons.event_busy_outlined),
              title: Text('Plan Tarihini Temizle'),
            ),
          ),
        const PopupMenuItem(
          value: _DispatchAction.priority,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.priority_high),
            title: Text('Onceligi Degistir'),
          ),
        ),
      ],
      child: const Icon(Icons.more_vert),
    );
  }

  Future<void> _handleAction(_DispatchAction action, FaultTicket ticket) async {
    switch (action) {
      case _DispatchAction.assignTechnician:
        await _showTechnicianPicker(ticket);
        break;
      case _DispatchAction.scheduleToday:
        await _quickSchedule(ticket, DateTime.now(), 'Is bugune alindi.');
        break;
      case _DispatchAction.scheduleTomorrow:
        await _quickSchedule(
          ticket,
          DateTime.now().add(const Duration(days: 1)),
          'Is yarina ertelendi.',
        );
        break;
      case _DispatchAction.schedule:
        await _showSchedulePicker(ticket);
        break;
      case _DispatchAction.clearSchedule:
        await _clearSchedule(ticket);
        break;
      case _DispatchAction.priority:
        await _showPriorityPicker(ticket);
        break;
    }
  }

  Future<void> _showTechnicianPicker(FaultTicket ticket) async {
    final provider = context.read<FaultTicketProvider>();
    final technicians = context.read<TechnicianProvider>().technicians;
    if (ticket.key is! int) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            children: [
              const Text(
                'Teknisyen Sec',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                '${ticket.customer.name} - ${ticket.device.name}',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_off_outlined)),
                title: const Text('Atamayi Kaldir'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await provider.clearTicketTechnician(ticket.key as int);
                  if (!mounted) return;
                  _showDone('Is emrindeki teknisyen atamasi kaldirildi.');
                },
              ),
              for (final technician in technicians)
                ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      technician.firstName.isNotEmpty
                          ? technician.firstName[0].toUpperCase()
                          : 'T',
                    ),
                  ),
                  title: Text(technician.fullName),
                  subtitle: Text(
                    technician.title?.trim().isNotEmpty == true
                        ? technician.title!
                        : 'Teknisyen',
                  ),
                  trailing: (ticket.technicianName ?? '').trim() ==
                          technician.fullName.trim()
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await provider.assignTechnicianToTicket(
                      ticket.key as int,
                      technician: technician,
                      technicianId:
                          LanSyncService.technicianAccessId(technician),
                    );
                    if (!mounted) return;
                    _showDone('Teknisyen atamasi guncellendi.');
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showSchedulePicker(FaultTicket ticket) async {
    if (ticket.key is! int) return;
    final provider = context.read<FaultTicketProvider>();
    final initial = ticket.scheduledAt ?? DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;

    final scheduledAt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    await provider.rescheduleTicket(ticket.key as int, scheduledAt);
    if (!mounted) return;
    _showDone('Plan tarihi guncellendi.');
  }

  Future<void> _quickSchedule(
    FaultTicket ticket,
    DateTime targetDate,
    String message,
  ) async {
    if (ticket.key is! int) return;
    final existing = ticket.scheduledAt;
    final scheduledAt = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      existing?.hour ?? 9,
      existing?.minute ?? 0,
    );

    await context.read<FaultTicketProvider>().rescheduleTicket(
          ticket.key as int,
          scheduledAt,
        );
    if (!mounted) return;
    _showDone(message);
  }

  Future<void> _clearSchedule(FaultTicket ticket) async {
    if (ticket.key is! int) return;
    await context.read<FaultTicketProvider>().rescheduleTicket(
          ticket.key as int,
          null,
        );
    if (!mounted) return;
    _showDone('Plan tarihi temizlendi.');
  }

  Future<void> _showPriorityPicker(FaultTicket ticket) async {
    if (ticket.key is! int) return;
    final provider = context.read<FaultTicketProvider>();
    final priorities = const {
      'low': 'Dusuk',
      'normal': 'Normal',
      'high': 'Yuksek',
      'urgent': 'Acil',
    };

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            children: [
              const Text(
                'Oncelik Sec',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              for (final entry in priorities.entries)
                ListTile(
                  leading: Icon(
                    Icons.priority_high,
                    color: _priorityColor(entry.key),
                  ),
                  title: Text(entry.value),
                  trailing: (ticket.priority ?? 'normal') == entry.key
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await provider.updateTicketPriority(
                      ticket.key as int,
                      entry.key,
                    );
                    if (!mounted) return;
                    _showDone('Oncelik guncellendi.');
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showDone(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _laneChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.calendar_view_day_outlined,
            size: 72,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 14),
          Text(
            'Bu filtreye uygun plan kaydi bulunmuyor.',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ariza kayitlarinda plan tarihi girildikce gunluk plan tahtasi dolacaktir.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(TicketStatus status) {
    switch (status) {
      case TicketStatus.pending:
        return const Color(0xFFFFA726);
      case TicketStatus.inProgress:
        return const Color(0xFF42A5F5);
      case TicketStatus.waitingPart:
        return const Color(0xFFAB47BC);
      case TicketStatus.devicePassive:
        return const Color(0xFFEF5350);
      case TicketStatus.completed:
        return const Color(0xFF66BB6A);
      case TicketStatus.cancelled:
        return const Color(0xFF78909C);
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return const Color(0xFFD32F2F);
      case 'high':
        return const Color(0xFFEF6C00);
      case 'low':
        return const Color(0xFF546E7A);
      case 'normal':
      default:
        return const Color(0xFF1976D2);
    }
  }

  IconData _statusIcon(TicketStatus status) {
    switch (status) {
      case TicketStatus.pending:
        return Icons.schedule;
      case TicketStatus.inProgress:
        return Icons.engineering;
      case TicketStatus.waitingPart:
        return Icons.inventory_2;
      case TicketStatus.devicePassive:
        return Icons.block;
      case TicketStatus.completed:
        return Icons.check_circle;
      case TicketStatus.cancelled:
        return Icons.cancel;
    }
  }
}

enum _DispatchRange {
  today,
  thisWeek,
  allOpen,
}

enum _DispatchFocus {
  all,
  urgent,
  waitingPart,
  unassigned,
  overdue,
}

enum _DispatchAction {
  assignTechnician,
  scheduleToday,
  scheduleTomorrow,
  schedule,
  clearSchedule,
  priority,
}

class _DispatchLane {
  final String technicianName;
  final List<FaultTicket> tickets;

  const _DispatchLane({
    required this.technicianName,
    required this.tickets,
  });

  bool get isUnassigned => technicianName == 'Atama Bekliyor';
}

class _DispatchSummary {
  final int total;
  final int planned;
  final int overdue;
  final int waitingPart;
  final int unassigned;

  const _DispatchSummary({
    required this.total,
    required this.planned,
    required this.overdue,
    required this.waitingPart,
    required this.unassigned,
  });
}

class _DispatchSummaryCardData {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _DispatchSummaryCardData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}
