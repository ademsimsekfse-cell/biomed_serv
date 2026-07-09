import 'package:biomed_serv/models/fault_ticket.dart';
import 'package:biomed_serv/models/technician.dart';
import 'package:biomed_serv/providers/fault_ticket_provider.dart';
import 'package:biomed_serv/providers/technician_provider.dart';
import 'package:biomed_serv/screens/fault_ticket_detail_screen.dart';
import 'package:biomed_serv/screens/service_form_screen.dart';
import 'package:biomed_serv/services/lan_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class MobileDailyWorkScreen extends StatefulWidget {
  const MobileDailyWorkScreen({super.key});

  @override
  State<MobileDailyWorkScreen> createState() => _MobileDailyWorkScreenState();
}

class _MobileDailyWorkScreenState extends State<MobileDailyWorkScreen> {
  int _selectedTab = 0;
  bool _openOnly = true;
  final _dateFormat = DateFormat('dd.MM HH:mm');

  @override
  Widget build(BuildContext context) {
    final technician = context.watch<TechnicianProvider>().currentTechnician;
    final provider = context.watch<FaultTicketProvider>();

    final tickets = technician == null
        ? <FaultTicket>[]
        : _filterTickets(
            provider.tickets.where((ticket) {
              return _isAssignedToTechnician(ticket, technician);
            }).toList(),
          );

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gunluk Islerim'),
            Text(
              'Merkezden gelen planli saha isleri',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: technician == null
          ? _buildNoTechnicianState()
          : Column(
              children: [
                _buildTechnicianHeader(technician, provider),
                _buildFilterBar(),
                Expanded(
                  child: tickets.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: tickets.length,
                          itemBuilder: (context, index) {
                            return _buildTicketCard(tickets[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  List<FaultTicket> _filterTickets(List<FaultTicket> tickets) {
    final now = DateTime.now();
    return tickets.where((ticket) {
      if (_openOnly && !ticket.isOpen) return false;
      final target = ticket.scheduledAt ?? ticket.reportDateTime;
      switch (_selectedTab) {
        case 0:
          return DateUtils.isSameDay(target, now);
        case 1:
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final weekStart = DateTime(
            startOfWeek.year,
            startOfWeek.month,
            startOfWeek.day,
          );
          final weekEnd = weekStart.add(const Duration(days: 7));
          return !target.isBefore(weekStart) && target.isBefore(weekEnd);
        case 2:
          return ticket.status == TicketStatus.waitingPart;
        case 3:
          return ticket.isOpen;
        default:
          return true;
      }
    }).toList()
      ..sort((a, b) {
        final aDate = a.scheduledAt ?? a.reportDateTime;
        final bDate = b.scheduledAt ?? b.reportDateTime;
        return aDate.compareTo(bDate);
      });
  }

  bool _isAssignedToTechnician(FaultTicket ticket, Technician technician) {
    final accessId = LanSyncService.technicianAccessId(technician);
    final fullName = technician.fullName.trim().toLowerCase();
    final ticketName = (ticket.technicianName ?? '').trim().toLowerCase();

    if (ticket.assignedTechnicianId == accessId) return true;
    if (ticketName.isNotEmpty && ticketName == fullName) return true;
    if (ticket.technician?.key != null &&
        technician.key != null &&
        ticket.technician!.key == technician.key) {
      return true;
    }
    return false;
  }

  Widget _buildTechnicianHeader(
    Technician technician,
    FaultTicketProvider provider,
  ) {
    final assignedOpen = provider.tickets
        .where((ticket) =>
            ticket.isOpen && _isAssignedToTechnician(ticket, technician))
        .length;
    final todayCount = provider.tickets.where((ticket) {
      final target = ticket.scheduledAt ?? ticket.reportDateTime;
      return ticket.isOpen &&
          _isAssignedToTechnician(ticket, technician) &&
          DateUtils.isSameDay(target, DateTime.now());
    }).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            backgroundImage: technician.photoBytes == null
                ? null
                : MemoryImage(technician.photoBytes!),
            child: technician.photoBytes == null
                ? Text(
                    technician.fullName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  technician.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$todayCount bugun, $assignedOpen acik is',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.route_outlined, color: Colors.white, size: 28),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _tabChip('Bugun', 0),
                _tabChip('Bu Hafta', 1),
                _tabChip('Parca', 2),
                _tabChip('Tum Acik', 3),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: FilterChip(
              label: const Text('Sadece acik isler'),
              selected: _openOnly,
              onSelected: (value) => setState(() => _openOnly = value),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabChip(String label, int index) {
    final selected = _selectedTab == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _selectedTab = index),
      ),
    );
  }

  Widget _buildTicketCard(FaultTicket ticket) {
    final color = Color(ticket.statusColor);
    final target = ticket.scheduledAt ?? ticket.reportDateTime;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.16)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDetail(ticket),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      ticket.workflowStageText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ticket.ticketNumber,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                ticket.customer.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${ticket.device.name} (${ticket.device.serialNumber})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _miniChip(Icons.event_available, _dateFormat.format(target)),
                  _miniChip(Icons.priority_high, ticket.priorityText),
                  if (ticket.isOverdue)
                    _miniChip(
                      Icons.warning_amber_rounded,
                      'Takip gerekli',
                      color: Colors.red,
                    ),
                ],
              ),
              if (ticket.isOpen) ...[
                const SizedBox(height: 10),
                _buildQuickStatusActions(ticket),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openDetail(ticket),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('Detay'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _openServiceForm(ticket),
                      icon: const Icon(Icons.description_outlined, size: 18),
                      label: const Text('Servis'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStatusActions(FaultTicket ticket) {
    final buttons = <Widget>[];
    if (ticket.status == TicketStatus.pending) {
      buttons.add(
        _quickActionButton(
          icon: Icons.play_circle_outline,
          label: 'Sahadayim',
          color: const Color(0xFF1976D2),
          onTap: () => _startWork(ticket),
        ),
      );
    }
    if (ticket.status != TicketStatus.waitingPart &&
        ticket.status != TicketStatus.completed &&
        ticket.status != TicketStatus.cancelled) {
      buttons.add(
        _quickActionButton(
          icon: Icons.inventory_2_outlined,
          label: 'Parca Bekliyor',
          color: const Color(0xFF8E24AA),
          onTap: () => _setWaitingPart(ticket),
        ),
      );
    }
    if (ticket.status != TicketStatus.devicePassive &&
        ticket.status != TicketStatus.completed &&
        ticket.status != TicketStatus.cancelled) {
      buttons.add(
        _quickActionButton(
          icon: Icons.block_outlined,
          label: 'Cihaz Pasif',
          color: const Color(0xFFD32F2F),
          onTap: () => _setDevicePassive(ticket),
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: buttons,
    );
  }

  Widget _quickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        visualDensity: VisualDensity.compact,
        side: BorderSide(color: color.withValues(alpha: 0.26)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }

  Widget _miniChip(IconData icon, String label, {Color? color}) {
    final chipColor = color ?? Colors.blueGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoTechnicianState() {
    return _centerState(
      icon: Icons.person_off_outlined,
      title: 'Teknisyen kurulumu bulunamadi',
      subtitle: 'Gunluk islerin gorunmesi icin once teknisyen kurulumu gerekir.',
    );
  }

  Widget _buildEmptyState() {
    return _centerState(
      icon: Icons.check_circle_outline,
      title: 'Bu filtrede is yok',
      subtitle: 'Merkezden planlanan isler senkron sonrasi burada gorunur.',
    );
  }

  Widget _centerState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 78, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(FaultTicket ticket) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FaultTicketDetailScreen(ticket: ticket),
      ),
    );
  }

  Future<void> _startWork(FaultTicket ticket) async {
    final key = ticket.key;
    if (key is! int) return;
    final technicianName =
        context.read<TechnicianProvider>().currentTechnician?.fullName ?? '';
    await context.read<FaultTicketProvider>().startIntervention(
          key,
          technicianName,
        );
    if (!mounted) return;
    _showStatusMessage('Is sahada calisiliyor olarak guncellendi.');
  }

  Future<void> _setWaitingPart(FaultTicket ticket) async {
    final key = ticket.key;
    if (key is! int) return;
    await context.read<FaultTicketProvider>().setWaitingPart(key);
    if (!mounted) return;
    _showStatusMessage('Is parca bekliyor olarak isaretlendi.');
  }

  Future<void> _setDevicePassive(FaultTicket ticket) async {
    final key = ticket.key;
    if (key is! int) return;
    await context.read<FaultTicketProvider>().setDevicePassive(key);
    if (!mounted) return;
    _showStatusMessage('Cihaz pasif olarak isaretlendi.');
  }

  void _showStatusMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _openServiceForm(FaultTicket ticket) async {
    final key = ticket.key;
    if (key is int && ticket.status == TicketStatus.pending) {
      final technicianName =
          context.read<TechnicianProvider>().currentTechnician?.fullName ?? '';
      await context
          .read<FaultTicketProvider>()
          .startIntervention(key, technicianName);
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ServiceFormScreen(initialTicket: ticket),
      ),
    );
  }
}
