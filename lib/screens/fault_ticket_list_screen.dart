import 'package:biomed_serv/models/fault_ticket.dart';
import 'package:biomed_serv/providers/fault_ticket_provider.dart';
import 'package:biomed_serv/screens/fault_ticket_detail_screen.dart';
import 'package:biomed_serv/screens/fault_ticket_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class FaultTicketListScreen extends StatefulWidget {
  final int initialTab;

  const FaultTicketListScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<FaultTicketListScreen> createState() => _FaultTicketListScreenState();
}

class _FaultTicketListScreenState extends State<FaultTicketListScreen> {
  late int _selectedTab;
  final _compactDateFormat = DateFormat('dd.MM HH:mm');

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ariza Kayitlari'),
            Text(
              'Is emri akisini tek ekranda yonet.',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () => _showStats(context),
            tooltip: 'Aylik ozet',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<FaultTicketProvider>().refresh();
            },
            tooltip: 'Listeyi yenile',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Consumer<FaultTicketProvider>(
            builder: (context, provider, child) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Row(
                  children: [
                    _buildTabChip('Açık', provider.openTickets.length, 0),
                    _buildTabChip(
                        'Bekleyen', provider.pendingTickets.length, 1),
                    _buildTabChip(
                      'Müdahalede',
                      provider.interventionTickets.length,
                      2,
                    ),
                    _buildTabChip(
                      'Planlı',
                      provider.scheduledTickets.length,
                      3,
                    ),
                    _buildTabChip(
                      'Tamamlanan',
                      provider.completedTickets.length,
                      4,
                    ),
                    _buildTabChip(
                      'İptal',
                      provider.cancelledTickets.length,
                      5,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      body: Consumer<FaultTicketProvider>(
        builder: (context, provider, child) {
          final tickets = _getTicketsForTab(provider);

          return Column(
            children: [
              _buildSummaryStrip(provider),
              Expanded(
                child: tickets.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: tickets.length,
                        itemBuilder: (context, index) {
                          final ticket = tickets[index];
                          return _buildTicketCard(ticket);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFFEF5350), Color(0xFFC62828)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFC62828).withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _navigateToNewTicket(context),
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'Yeni Ariza Kaydi',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryStrip(FaultTicketProvider provider) {
    final cards = [
      _SummaryCardData(
        label: 'Planli',
        value: provider.scheduledTickets.length,
        color: const Color(0xFF5C6BC0),
        icon: Icons.event_available_outlined,
      ),
      _SummaryCardData(
        label: 'Sahada',
        value: provider.inProgressTickets.length,
        color: const Color(0xFF1E88E5),
        icon: Icons.engineering_outlined,
      ),
      _SummaryCardData(
        label: 'Parca Bekliyor',
        value: provider.waitingPartTickets.length,
        color: const Color(0xFF8E24AA),
        icon: Icons.inventory_2_outlined,
      ),
      _SummaryCardData(
        label: 'Geciken Acik Is',
        value: provider.overdueOpenTicketsCount,
        color: const Color(0xFFE53935),
        icon: Icons.warning_amber_rounded,
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 2),
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cards.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: compact ? 2 : 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: compact ? 2.6 : 2.4,
            ),
            itemBuilder: (context, index) {
              final item = cards[index];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: item.color.withValues(alpha: 0.22),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.value.toString(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
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
      ),
    );
  }

  Widget _buildTabChip(String label, int count, int index) {
    final isSelected = _selectedTab == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          '$label ($count)',
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF0D47A1) : Colors.black87,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() => _selectedTab = index);
          }
        },
        selectedColor: const Color(0xFFE3F2FD),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isSelected ? const Color(0xFF64B5F6) : Colors.grey.shade300,
            width: isSelected ? 1.8 : 1,
          ),
        ),
      ),
    );
  }

  List<FaultTicket> _getTicketsForTab(FaultTicketProvider provider) {
    switch (_selectedTab) {
      case 0:
        return provider.openTickets;
      case 1:
        return provider.pendingTickets;
      case 2:
        return provider.interventionTickets;
      case 3:
        return provider.scheduledTickets;
      case 4:
        return provider.completedTickets;
      case 5:
        return provider.cancelledTickets;
      default:
        return provider.openTickets;
    }
  }

  Widget _buildEmptyState() {
    final messages = [
      'Bu sekmede gosterilecek is emri bulunmuyor.',
      'Yeni bir ariza kaydi olusturabilir ya da ustteki sekmeleri kontrol edebilirsin.',
    ];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_late_outlined,
              size: 82,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              messages.first,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              messages.last,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketCard(FaultTicket ticket) {
    final statusColor = Color(ticket.statusColor);
    final scheduledLabel = ticket.scheduledAt == null
        ? null
        : 'Plan: ${_compactDateFormat.format(ticket.scheduledAt!)}';
    final showOverdue =
        ticket.isOverdue && ticket.status != TicketStatus.completed;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: () => _navigateToDetail(context, ticket),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _infoBadge(
                    ticket.ticketNumber,
                    Colors.blue.shade50,
                    Colors.blue.shade800,
                  ),
                  const SizedBox(width: 8),
                  _infoBadge(
                    ticket.ticketTypeText,
                    _getTicketTypeColor(ticket.ticketType)
                        .withValues(alpha: 0.1),
                    _getTicketTypeColor(ticket.ticketType),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getStatusIcon(ticket.status),
                            size: 14, color: statusColor),
                        const SizedBox(width: 6),
                        Text(
                          ticket.workflowStageText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.business, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ticket.customer.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(Icons.devices_outlined,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${ticket.device.name} (${ticket.device.serialNumber})',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _metaChip(
                    icon: Icons.schedule_outlined,
                    text:
                        'Bildirim ${_compactDateFormat.format(ticket.reportDateTime)}',
                  ),
                  if (scheduledLabel != null)
                    _metaChip(
                      icon: Icons.event_available_outlined,
                      text: scheduledLabel,
                      accent: const Color(0xFF5C6BC0),
                    ),
                  if (ticket.technicianName != null &&
                      ticket.technicianName!.trim().isNotEmpty)
                    _metaChip(
                      icon: Icons.person_outline,
                      text: ticket.technicianName!,
                    ),
                  _metaChip(
                    icon: Icons.priority_high,
                    text: ticket.priorityText,
                    accent: _priorityColor(ticket.priority ?? 'normal'),
                  ),
                  if (ticket.hasServiceForm)
                    _metaChip(
                      icon: Icons.description_outlined,
                      text: 'Servise donustu',
                      accent: const Color(0xFF2E7D32),
                    ),
                  if (showOverdue)
                    _metaChip(
                      icon: Icons.warning_amber_rounded,
                      text: 'Takip gerekli',
                      accent: const Color(0xFFC62828),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoBadge(String text, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }

  Widget _metaChip({
    required IconData icon,
    required String text,
    Color? accent,
  }) {
    final baseColor = accent ?? Colors.grey.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: (accent ?? Colors.grey).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border:
            Border.all(color: (accent ?? Colors.grey).withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: baseColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: baseColor,
            ),
          ),
        ],
      ),
    );
  }

  Color _getTicketTypeColor(TicketType type) {
    switch (type) {
      case TicketType.malfunction:
        return Colors.red;
      case TicketType.installation:
        return Colors.green;
      case TicketType.other:
        return Colors.orange;
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

  IconData _getStatusIcon(TicketStatus status) {
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

  void _navigateToNewTicket(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FaultTicketFormScreen(),
      ),
    );
  }

  void _navigateToDetail(BuildContext context, FaultTicket ticket) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaultTicketDetailScreen(ticket: ticket),
      ),
    );
  }

  void _showStats(BuildContext context) {
    final provider = context.read<FaultTicketProvider>();
    final stats = provider.monthlyStats;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aylik Is Emri Ozeti'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatRow(
                'Toplam Kayit', stats['total'] ?? 0, Colors.blue.shade700),
            _buildStatRow(
                'Planli', stats['scheduled'] ?? 0, const Color(0xFF5C6BC0)),
            _buildStatRow(
                'Tamamlanan', stats['completed'] ?? 0, Colors.green.shade700),
            _buildStatRow(
                'Bekleyen', stats['pending'] ?? 0, Colors.orange.shade700),
            _buildStatRow(
                'Sahada', stats['inProgress'] ?? 0, Colors.blue.shade700),
            _buildStatRow('Parca Bekleyen', stats['waitingPart'] ?? 0,
                Colors.purple.shade700),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              value.toString(),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCardData {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _SummaryCardData({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
}
