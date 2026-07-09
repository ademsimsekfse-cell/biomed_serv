import 'dart:io';

import 'package:biomed_serv/models/maintenance_form.dart';
import 'package:biomed_serv/models/service_form.dart';
import 'package:biomed_serv/providers/dashboard_provider.dart';
import 'package:biomed_serv/providers/expense_provider.dart';
import 'package:biomed_serv/providers/expense_report_provider.dart';
import 'package:biomed_serv/providers/fault_ticket_provider.dart';
import 'package:biomed_serv/providers/maintenance_form_provider.dart';
import 'package:biomed_serv/providers/notification_provider.dart';
import 'package:biomed_serv/providers/service_form_provider.dart';
import 'package:biomed_serv/providers/stock_provider.dart';
import 'package:biomed_serv/providers/technician_provider.dart';
import 'package:biomed_serv/screens/desktop_dispatch_board_screen.dart';
import 'package:biomed_serv/screens/desktop_shell_screen.dart';
import 'package:biomed_serv/screens/desktop_sync_center_screen.dart';
import 'package:biomed_serv/screens/device_management_screen.dart';
import 'package:biomed_serv/screens/expense_management_screen.dart';
import 'package:biomed_serv/screens/fault_ticket_list_screen.dart';
import 'package:biomed_serv/screens/form_history_screen.dart';
import 'package:biomed_serv/screens/notification_screen.dart';
import 'package:biomed_serv/screens/reports_screen.dart';
import 'package:biomed_serv/screens/stock_screen.dart';
import 'package:biomed_serv/services/lan_auto_sync_service.dart';
import 'package:biomed_serv/services/lan_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class DesktopOperationsDashboardScreen extends StatefulWidget {
  const DesktopOperationsDashboardScreen({super.key});

  @override
  State<DesktopOperationsDashboardScreen> createState() =>
      _DesktopOperationsDashboardScreenState();
}

class _DesktopOperationsDashboardScreenState
    extends State<DesktopOperationsDashboardScreen> {
  LanSyncActivityType? _activityTypeFilter;
  LanSyncActivitySeverity? _activitySeverityFilter;

  Future<_AsyncOpsData> _loadAsyncData(LanAutoSyncService autoSync) async {
    final accessRequests = await autoSync.pendingAccessRequests();
    final reviewItems = await autoSync.reviewItems();
    return _AsyncOpsData(
      pendingAccessRequests: accessRequests.length,
      pendingReviewItems: reviewItems.where((item) => !item.reviewed).length,
    );
  }

  void _open(BuildContext context, Widget screen) {
    openDesktopAwareScreen(context, screen, replacement: false);
  }

  List<LanSyncActivity> _filteredActivities(LanAutoSyncService autoSync) {
    return autoSync.activities.where((activity) {
      final typeMatches =
          _activityTypeFilter == null || activity.type == _activityTypeFilter;
      final severityMatches = _activitySeverityFilter == null ||
          activity.severity == _activitySeverityFilter;
      return typeMatches && severityMatches;
    }).toList();
  }

  Future<void> _clearActivities(LanAutoSyncService autoSync) async {
    await autoSync.clearActivities();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Son hareketler listesi temizlendi.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _exportActivities(LanAutoSyncService autoSync) async {
    final activities = _filteredActivities(autoSync);
    if (activities.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aktarilacak kayit bulunmuyor.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final buffer = StringBuffer()
      ..writeln('timestamp,type,severity,message,details');
    for (final activity in activities) {
      final details = activity.details.join(' | ').replaceAll('"', '""');
      final message = activity.message.replaceAll('"', '""');
      buffer.writeln(
        '"${activity.timestamp.toIso8601String()}","${activity.type.name}","${activity.severity.name}","$message","$details"',
      );
    }

    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}\\sync_gecmisi_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv',
    );
    await file.writeAsString(buffer.toString(), flush: true);

    if (!mounted) return;
    await Share.shareXFiles(
      [
        XFile(
          file.path,
          mimeType: 'text/csv',
          name: file.uri.pathSegments.last,
        ),
      ],
      subject: 'Son Hareketler',
      text: 'Son Hareketler',
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final faultProvider = context.watch<FaultTicketProvider>();
    final expenseProvider = context.watch<ExpenseProvider>();
    final expenseReportProvider = context.watch<ExpenseReportProvider>();
    final serviceProvider = context.watch<ServiceFormProvider>();
    final maintenanceProvider = context.watch<MaintenanceFormProvider>();
    final stockProvider = context.watch<StockProvider>();
    final technicianProvider = context.watch<TechnicianProvider>();
    final notificationProvider = context.watch<NotificationProvider>();
    final autoSync = context.watch<LanAutoSyncService>();

    final recentServiceForms = [...serviceProvider.forms]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final recentMaintenanceForms = [...maintenanceProvider.forms]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHero(
            context,
            autoSync,
            technicianProvider,
            notificationProvider,
          ),
          const SizedBox(height: 16),
          FutureBuilder<_AsyncOpsData>(
            future: _loadAsyncData(autoSync),
            builder: (context, snapshot) {
              final asyncData = snapshot.data ?? const _AsyncOpsData();
              return _buildTodayGuide(
                context,
                asyncData,
                faultProvider,
                expenseReportProvider,
                stockProvider,
              );
            },
          ),
          const SizedBox(height: 16),
          FutureBuilder<_AsyncOpsData>(
            future: _loadAsyncData(autoSync),
            builder: (context, snapshot) {
              final asyncData = snapshot.data ?? const _AsyncOpsData();
              return _buildTopMetrics(
                context,
                dashboard: dashboard,
                faultProvider: faultProvider,
                expenseProvider: expenseProvider,
                expenseReportProvider: expenseReportProvider,
                asyncData: asyncData,
              );
            },
          ),
          const SizedBox(height: 16),
          _buildDecisionCenter(
            context,
            autoSync,
            faultProvider,
            stockProvider,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1100;
              if (!wide) {
                return Column(
                  children: [
                    _buildQuickActions(context, autoSync),
                    const SizedBox(height: 16),
                    _buildWorkQueues(
                      context,
                      autoSync,
                      faultProvider,
                      expenseProvider,
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: _buildQuickActions(context, autoSync),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: _buildWorkQueues(
                      context,
                      autoSync,
                      faultProvider,
                      expenseProvider,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _buildSyncActivityPanel(autoSync),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1100;
              if (!wide) {
                return Column(
                  children: [
                    _buildRecentFormsPanel(
                      context,
                      recentServiceForms,
                      recentMaintenanceForms,
                    ),
                    const SizedBox(height: 16),
                    _buildTechnicianLoadPanel(
                      context,
                      technicianProvider,
                      serviceProvider,
                      maintenanceProvider,
                      expenseReportProvider,
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: _buildRecentFormsPanel(
                      context,
                      recentServiceForms,
                      recentMaintenanceForms,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: _buildTechnicianLoadPanel(
                      context,
                      technicianProvider,
                      serviceProvider,
                      maintenanceProvider,
                      expenseReportProvider,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSyncActivityPanel(LanAutoSyncService autoSync) {
    final activities = _filteredActivities(autoSync).take(12).toList();

    return _sectionCard(
      title: 'Son Hareketler',
      subtitle: 'Merkezde neler oldugunu kisa ve net sekilde gor.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Tum Basliklar'),
                selected: _activityTypeFilter == null,
                onSelected: (_) => setState(() => _activityTypeFilter = null),
              ),
              for (final type in LanSyncActivityType.values)
                ChoiceChip(
                  label: Text(_activityTypeLabel(type)),
                  selected: _activityTypeFilter == type,
                  onSelected: (_) => setState(() => _activityTypeFilter = type),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Tum Durumlar'),
                selected: _activitySeverityFilter == null,
                onSelected: (_) =>
                    setState(() => _activitySeverityFilter = null),
              ),
              for (final severity in LanSyncActivitySeverity.values)
                ChoiceChip(
                  label: Text(_activitySeverityLabel(severity)),
                  selected: _activitySeverityFilter == severity,
                  onSelected: (_) =>
                      setState(() => _activitySeverityFilter = severity),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: activities.isEmpty
                    ? null
                    : () => _exportActivities(autoSync),
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Listeyi Aktar'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: autoSync.activities.isEmpty
                    ? null
                    : () => _clearActivities(autoSync),
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Listeyi Temizle'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (activities.isEmpty)
            _emptyPanel(
              icon: Icons.filter_alt_off_outlined,
              title: 'Filtreye uygun kayit yok',
              subtitle:
                  'Farkli bir baslik veya durum secerek listeyi genisletebilirsin.',
            )
          else
            ...activities.map((activity) {
              final accent = _activityColor(activity.severity);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: accent.withValues(alpha: 0.14),
                          child: Icon(
                            _activityIcon(activity),
                            size: 17,
                            color: accent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            activity.message,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          DateFormat('dd.MM HH:mm').format(activity.timestamp),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_activityTypeLabel(activity.type)} / ${_activitySeverityLabel(activity.severity)}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (activity.details.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...activity.details.take(3).map(
                            (detail) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '- $detail',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTodayGuide(
    BuildContext context,
    _AsyncOpsData asyncData,
    FaultTicketProvider faultProvider,
    ExpenseReportProvider expenseReportProvider,
    StockProvider stockProvider,
  ) {
    final todayScheduledCount = faultProvider.scheduledTickets
        .where(
            (ticket) => DateUtils.isSameDay(ticket.scheduledAt, DateTime.now()))
        .length;
    final suggestions = <_GuideStep>[
      if (faultProvider.overdueOpenTicketsCount > 0)
        _GuideStep(
          title: 'Geciken acik isler var',
          description:
              '${faultProvider.overdueOpenTicketsCount} is emri takip bekliyor.',
          icon: Icons.alarm_on_outlined,
          color: const Color(0xFFC62828),
          onTap: () => _open(context, const DesktopDispatchBoardScreen()),
        ),
      if (todayScheduledCount > 0)
        _GuideStep(
          title: 'Bugun planli ziyaretler var',
          description:
              '$todayScheduledCount is emri bugun sahaya cikmayi bekliyor.',
          icon: Icons.event_available_outlined,
          color: const Color(0xFF3949AB),
          onTap: () => _open(context, const DesktopDispatchBoardScreen()),
        ),
      if (asyncData.pendingAccessRequests > 0)
        _GuideStep(
          title: 'Baglanti bekleyen teknisyenler var',
          description:
              '${asyncData.pendingAccessRequests} teknisyen baglanti izni bekliyor.',
          icon: Icons.verified_user_outlined,
          color: const Color(0xFF6A1B9A),
          onTap: () => _open(
            context,
            const DesktopSyncCenterScreen(initialTab: 1),
          ),
        ),
      if (faultProvider.waitingPartTickets.isNotEmpty)
        _GuideStep(
          title: 'Parca bekleyen isler var',
          description:
              '${faultProvider.waitingPartTickets.length} ariza parcayi bekliyor.',
          icon: Icons.build_circle_outlined,
          color: const Color(0xFFC62828),
          onTap: () =>
              _open(context, const FaultTicketListScreen(initialTab: 4)),
        ),
      if (expenseReportProvider.uncollectedReports.isNotEmpty)
        _GuideStep(
          title: 'Tahsil bekleyen raporlar var',
          description:
              '${expenseReportProvider.uncollectedReports.length} rapor kapanmayi bekliyor.',
          icon: Icons.receipt_long,
          color: const Color(0xFF2E7D32),
          onTap: () => _open(context, const ExpenseManagementScreen()),
        ),
      if (stockProvider.stocks.any(
        (stock) => stock.quantity <= stock.criticalStockThreshold,
      ))
        _GuideStep(
          title: 'Kritik stoklari kontrol et',
          description: 'Stokta azalan urunler var, siparis gerekebilir.',
          icon: Icons.warning_amber_outlined,
          color: const Color(0xFFEF6C00),
          onTap: () => _open(context, const StockScreen()),
        ),
    ];

    return _sectionCard(
      title: 'Bugun Ne Yapalim?',
      subtitle: suggestions.isEmpty
          ? 'Her sey sakin gorunuyor. Istersen kayitlari veya raporlari kontrol edebilirsin.'
          : 'Oncelikli isleri tek tek gorelim.',
      accent: const Color(0xFF0F766E),
      child: suggestions.isEmpty
          ? _emptyPanel(
              icon: Icons.check_circle_outline,
              title: 'Acil bir is gorunmuyor',
              subtitle: 'Sistem su an duzenli ilerliyor.',
              color: Colors.green,
            )
          : Column(
              children: suggestions.take(3).map((step) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: step.color.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: step.color.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: step.color.withValues(alpha: 0.14),
                        child: Icon(step.icon, color: step.color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              step.description,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: step.onTap,
                        child: const Text('Ac'),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildHero(
    BuildContext context,
    LanAutoSyncService autoSync,
    TechnicianProvider technicianProvider,
    NotificationProvider notificationProvider,
  ) {
    final statusColor = autoSync.isListening
        ? const Color(0xFF1B5E20)
        : const Color(0xFFB26A00);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.apartment, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Merkez Operasyon Paneli',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Servis, bakim, masraf, cihaz ve teknisyen akislarini tek merkezden yonet.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                FutureBuilder<_AsyncOpsData>(
                  future: _loadAsyncData(autoSync),
                  builder: (context, snapshot) {
                    final asyncData = snapshot.data ?? const _AsyncOpsData();
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _heroActionChip(
                          icon: autoSync.isListening
                              ? Icons.cloud_done
                              : Icons.cloud_off,
                          text: autoSync.isListening
                              ? 'Merkez aktif • :${autoSync.localApiPort}'
                              : 'Merkezi yeniden başlat',
                          background: statusColor.withValues(alpha: 0.18),
                          onTap: () => _open(
                            context,
                            const DesktopSyncCenterScreen(),
                          ),
                        ),
                        _heroChip(
                          icon: Icons.people_alt_outlined,
                          text:
                              '${technicianProvider.technicians.length} teknisyen',
                          background: Colors.white.withValues(alpha: 0.14),
                        ),
                        if (autoSync.lastSyncAt != null)
                          _heroChip(
                            icon: Icons.schedule,
                            text:
                                "Son akis ${DateFormat('dd.MM HH:mm').format(autoSync.lastSyncAt!)}",
                            background: Colors.white.withValues(alpha: 0.14),
                          ),
                        if (asyncData.pendingAccessRequests > 0)
                          _heroActionChip(
                            icon: Icons.verified_user_outlined,
                            text:
                                '${asyncData.pendingAccessRequests} onay bekliyor',
                            background:
                                const Color(0xFF6A1B9A).withValues(alpha: 0.22),
                            onTap: () => _open(
                              context,
                              const DesktopSyncCenterScreen(initialTab: 1),
                            ),
                          ),
                        if (asyncData.pendingReviewItems > 0)
                          _heroActionChip(
                            icon: Icons.fact_check_outlined,
                            text:
                                '${asyncData.pendingReviewItems} kayit bekliyor',
                            background:
                                const Color(0xFF00897B).withValues(alpha: 0.22),
                            onTap: () => _open(
                              context,
                              const DesktopSyncCenterScreen(initialTab: 2),
                            ),
                          ),
                        if (notificationProvider.unreadCount > 0)
                          _heroActionChip(
                            icon: Icons.notifications_active_outlined,
                            text:
                                '${notificationProvider.unreadCount} bildirim',
                            background:
                                const Color(0xFFEF6C00).withValues(alpha: 0.22),
                            onTap: () => _open(
                              context,
                              const NotificationScreen(),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroChip({
    required IconData icon,
    required String text,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroActionChip({
    required IconData icon,
    required String text,
    required Color background,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: _heroChip(
          icon: icon,
          text: text,
          background: background,
        ),
      ),
    );
  }

  Widget _buildTopMetrics(
    BuildContext context, {
    required DashboardProvider dashboard,
    required FaultTicketProvider faultProvider,
    required ExpenseProvider expenseProvider,
    required ExpenseReportProvider expenseReportProvider,
    required _AsyncOpsData asyncData,
  }) {
    final todayScheduledCount = faultProvider.scheduledTickets
        .where(
            (ticket) => DateUtils.isSameDay(ticket.scheduledAt, DateTime.now()))
        .length;
    final items = [
      _MetricCardData(
        title: 'Toplam cihaz',
        value: dashboard.totalDevices.toString(),
        subtitle:
            '${dashboard.totalServices + dashboard.totalMaintenances} toplam form',
        icon: Icons.devices_other,
        color: const Color(0xFF1565C0),
        onTap: () => _open(context, const DeviceManagementScreen()),
      ),
      _MetricCardData(
        title: 'Acik is emri',
        value: faultProvider.openTickets.length.toString(),
        subtitle:
            '${faultProvider.pendingTickets.length} beklemede, ${faultProvider.overdueOpenTicketsCount} geciken is',
        icon: Icons.build_circle_outlined,
        color: const Color(0xFFC62828),
        onTap: () => _open(context, const DesktopDispatchBoardScreen()),
      ),
      _MetricCardData(
        title: 'Planli ziyaret',
        value: faultProvider.scheduledTickets.length.toString(),
        subtitle: '$todayScheduledCount is bugun planli',
        icon: Icons.event_available_outlined,
        color: const Color(0xFF3949AB),
        onTap: () => _open(context, const DesktopDispatchBoardScreen()),
      ),
      _MetricCardData(
        title: 'Bekleyen tahsilat',
        value: expenseReportProvider.uncollectedReports.length.toString(),
        subtitle: NumberFormat('#,##0.00', 'tr_TR')
            .format(expenseReportProvider.totalUncollectedAmount),
        icon: Icons.receipt_long,
        color: const Color(0xFF2E7D32),
        onTap: () => _open(context, const ExpenseManagementScreen()),
      ),
      _MetricCardData(
        title: 'Bekleyen masraf girisi',
        value: expenseProvider.pendingExpenses.length.toString(),
        subtitle: NumberFormat('#,##0.00', 'tr_TR')
            .format(expenseProvider.totalPendingAmount),
        icon: Icons.payments_outlined,
        color: const Color(0xFFEF6C00),
        onTap: () => _open(context, const ExpenseManagementScreen()),
      ),
      _MetricCardData(
        title: 'Baglanti onayi',
        value: asyncData.pendingAccessRequests.toString(),
        subtitle: '${asyncData.pendingReviewItems} karar bekleyen kayit',
        icon: Icons.verified_user_outlined,
        color: const Color(0xFF6A1B9A),
        onTap: () => _open(
          context,
          const DesktopSyncCenterScreen(initialTab: 1),
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 1280
            ? 6
            : constraints.maxWidth >= 920
                ? 3
                : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: crossAxisCount >= 3 ? 1.8 : 1.55,
          ),
          itemBuilder: (context, index) => _buildMetricCard(items[index]),
        );
      },
    );
  }

  Widget _buildMetricCard(_MetricCardData item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: item.color.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon, color: item.color),
                  ),
                  const Spacer(),
                  Text(
                    item.value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: item.color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.subtitle,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Detaya git',
                    style: TextStyle(
                      color: item.color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward, size: 16, color: item.color),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, LanAutoSyncService autoSync) {
    final actions = [
      _QuickActionData(
        title: 'Baglantilar',
        subtitle: 'Mobil cihazlar ve veri akisini yonet',
        icon: Icons.hub,
        color: const Color(0xFF0F766E),
        onTap: () => _open(context, const DesktopSyncCenterScreen()),
      ),
      _QuickActionData(
        title: 'Gunluk Plan',
        subtitle: 'Teknisyen bazli plan ve sahadaki yuk dagilimi',
        icon: Icons.calendar_view_week,
        color: const Color(0xFF5E35B1),
        onTap: () => _open(context, const DesktopDispatchBoardScreen()),
      ),
      _QuickActionData(
        title: 'Ariza Kayitlari',
        subtitle: 'Planli, bekleyen ve sahadaki isleri yonet',
        icon: Icons.build,
        color: const Color(0xFFC62828),
        onTap: () => _open(context, const FaultTicketListScreen(initialTab: 0)),
      ),
      _QuickActionData(
        title: 'Masraflar',
        subtitle: 'Bekleyen masraflari ve tahsilati yonet',
        icon: Icons.receipt_long,
        color: const Color(0xFF2E7D32),
        onTap: () => _open(context, const ExpenseManagementScreen()),
      ),
      _QuickActionData(
        title: 'Cihazlar',
        subtitle: 'Kayit, atama ve iliski kontrolu',
        icon: Icons.devices,
        color: const Color(0xFF1565C0),
        onTap: () => _open(context, const DeviceManagementScreen()),
      ),
      _QuickActionData(
        title: 'Formlar',
        subtitle: 'Servis ve bakim kayitlarini ac',
        icon: Icons.history_edu,
        color: const Color(0xFF6A1B9A),
        onTap: () => _open(context, const FormHistoryScreen()),
      ),
      _QuickActionData(
        title: 'Raporlar',
        subtitle: 'Listeleri disa aktar veya incele',
        icon: Icons.assessment,
        color: const Color(0xFFEF6C00),
        onTap: () => _open(context, const ReportsScreen()),
      ),
    ];

    return _sectionCard(
      title: 'Sik Kullanilanlar',
      subtitle: autoSync.isListening
          ? 'Merkez aktif. Onemli operasyonlara tek tikla ulas.'
          : 'Merkezi baslatmak icin once senkron paneline girip dinlemeyi ac.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth >= 760 ? 3 : 2;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.55,
            ),
            itemBuilder: (context, index) {
              final action = actions[index];
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: action.onTap,
                child: Ink(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: action.color.withValues(alpha: 0.16)),
                    color: action.color.withValues(alpha: 0.06),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: action.color.withValues(alpha: 0.14),
                        child: Icon(action.icon, color: action.color),
                      ),
                      const Spacer(),
                      Text(
                        action.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        action.subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDecisionCenter(
    BuildContext context,
    LanAutoSyncService autoSync,
    FaultTicketProvider faultProvider,
    StockProvider stockProvider,
  ) {
    final lowStockCount = stockProvider.stocks
        .where((stock) => stock.quantity <= stock.criticalStockThreshold)
        .length;
    final waitingPartCount = faultProvider.waitingPartTickets.length;
    final overdueCount = faultProvider.overdueOpenTicketsCount;
    final todayScheduledCount = faultProvider.scheduledTickets
        .where(
            (ticket) => DateUtils.isSameDay(ticket.scheduledAt, DateTime.now()))
        .length;

    return FutureBuilder<List<LanSyncReviewItem>>(
      future: autoSync.reviewItems(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <LanSyncReviewItem>[];
        final pendingItems = items.where((item) => !item.reviewed).toList();
        final stockReviews = pendingItems.where((item) => item.isStock).length;
        final deviceReviews =
            pendingItems.where((item) => item.isDevice).length;

        return _sectionCard(
          title: 'Oncelikli Isler',
          subtitle:
              'Bugun dikkat edilmesi gereken basliklari sirayla gosterir.',
          child: Column(
            children: [
              _decisionRow(
                label: 'Yeni cihazlari yerlerine bagla',
                value: deviceReviews,
                accent: const Color(0xFF1565C0),
                icon: Icons.devices_other,
                helper:
                    'Yeni gelen cihazlar icin kurum ve teknisyen secimini tamamla.',
                onTap: () => _open(context, const DesktopSyncCenterScreen()),
              ),
              _decisionRow(
                label: 'Yeni stok kartlarini kontrol et',
                value: stockReviews,
                accent: const Color(0xFF00897B),
                icon: Icons.inventory_2,
                helper: 'Ayni urunler varsa tek kartta birlestir.',
                onTap: () => _open(context, const DesktopSyncCenterScreen()),
              ),
              _decisionRow(
                label: 'Bugun planli ziyaretleri ac',
                value: todayScheduledCount,
                accent: const Color(0xFF3949AB),
                icon: Icons.event_available_outlined,
                helper:
                    'Bugun sahaya cikacak isleri once planli listede sirala.',
                onTap: () => _open(context, const DesktopDispatchBoardScreen()),
              ),
              _decisionRow(
                label: 'Geciken acik isleri toparla',
                value: overdueCount,
                accent: const Color(0xFFC62828),
                icon: Icons.alarm_on_outlined,
                helper:
                    'Plan tarihi gecmis is emirlerini once ele almak iyi olur.',
                onTap: () => _open(context, const DesktopDispatchBoardScreen()),
              ),
              _decisionRow(
                label: 'Parca bekleyen arizalar',
                value: waitingPartCount,
                accent: const Color(0xFFC62828),
                icon: Icons.build_circle_outlined,
                helper: 'Parca bekleyen isleri gecikmeden gozden gecir.',
                onTap: () => _open(
                  context,
                  const FaultTicketListScreen(initialTab: 4),
                ),
              ),
              _decisionRow(
                label: 'Azalan stoklar',
                value: lowStockCount,
                accent: const Color(0xFFEF6C00),
                icon: Icons.warning_amber_outlined,
                helper: 'Azalan urunleri tamamlamak icin stok ekranina gec.',
                onTap: () => _open(context, const StockScreen()),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _decisionRow({
    required String label,
    required int value,
    required Color accent,
    required IconData icon,
    required String helper,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: accent.withValues(alpha: 0.14),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        helper,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  value.toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward,
                  color: accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkQueues(
    BuildContext context,
    LanAutoSyncService autoSync,
    FaultTicketProvider faultProvider,
    ExpenseProvider expenseProvider,
  ) {
    final todayScheduledCount = faultProvider.scheduledTickets
        .where(
            (ticket) => DateUtils.isSameDay(ticket.scheduledAt, DateTime.now()))
        .length;
    return _sectionCard(
      title: 'Bekleyen Isler',
      subtitle: 'Sirada hangi islerin oldugunu kolayca gor.',
      child: FutureBuilder<_AsyncOpsData>(
        future: _loadAsyncData(autoSync),
        builder: (context, snapshot) {
          final asyncData = snapshot.data ?? const _AsyncOpsData();
          final queues = [
            _QueueData(
              label: 'Bugun planli is',
              value: todayScheduledCount,
              accent: const Color(0xFF3949AB),
              icon: Icons.event_available_outlined,
              helper: 'Gun icinde sahaya cikacak isler',
              onTap: () => _open(context, const DesktopDispatchBoardScreen()),
            ),
            _QueueData(
              label: 'Geciken acik is',
              value: faultProvider.overdueOpenTicketsCount,
              accent: const Color(0xFFC62828),
              icon: Icons.alarm_on_outlined,
              helper: 'Plan tarihi gecmis acik is emirleri',
              onTap: () => _open(context, const DesktopDispatchBoardScreen()),
            ),
            _QueueData(
              label: 'Teknisyen onayi',
              value: asyncData.pendingAccessRequests,
              accent: const Color(0xFF6A1B9A),
              icon: Icons.verified_user_outlined,
              helper: 'Merkeze baglanmak icin onay bekleyenler',
              onTap: () => _open(
                context,
                const DesktopSyncCenterScreen(initialTab: 1),
              ),
            ),
            _QueueData(
              label: 'Inceleme kaydi',
              value: asyncData.pendingReviewItems,
              accent: const Color(0xFF00897B),
              icon: Icons.fact_check_outlined,
              helper: 'Kontrol ve karar bekleyen yeni kayitlar',
              onTap: () => _open(
                context,
                const DesktopSyncCenterScreen(initialTab: 2),
              ),
            ),
            _QueueData(
              label: 'Acik ariza',
              value: faultProvider.openTickets.length,
              accent: const Color(0xFFC62828),
              icon: Icons.build_circle_outlined,
              helper: 'Beklemede, sahada veya parca bekleyen isler',
              onTap: () => _open(
                context,
                const FaultTicketListScreen(initialTab: 0),
              ),
            ),
            _QueueData(
              label: 'Bekleyen masraf',
              value: expenseProvider.pendingExpenses.length,
              accent: const Color(0xFFEF6C00),
              icon: Icons.payments_outlined,
              helper: 'Raporlanmamis veya kapanmamis giderler',
              onTap: () => _open(context, const ExpenseManagementScreen()),
            ),
          ];

          return Column(
            children: [
              for (final queue in queues)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: queue.onTap,
                      borderRadius: BorderRadius.circular(12),
                      child: Ink(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: queue.accent.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: queue.accent.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  queue.accent.withValues(alpha: 0.14),
                              child: Icon(queue.icon, color: queue.accent),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    queue.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    queue.helper,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              queue.value.toString(),
                              style: TextStyle(
                                color: queue.accent,
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward,
                              size: 18,
                              color: queue.accent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRecentFormsPanel(
    BuildContext context,
    List<ServiceForm> recentServiceForms,
    List<MaintenanceForm> recentMaintenanceForms,
  ) {
    final items = <_RecentFormRow>[
      ...recentServiceForms.take(4).map(
            (form) => _RecentFormRow(
              type: 'Servis',
              formNumber: form.formNumber,
              customerName: form.customer.name,
              deviceName: form.device.name,
              technicianName: form.technicianName ?? '-',
              createdAt: form.createdAt,
              accent: const Color(0xFF1565C0),
            ),
          ),
      ...recentMaintenanceForms.take(4).map(
            (form) => _RecentFormRow(
              type: 'Bakim',
              formNumber: form.formNumber,
              customerName: form.customer.name,
              deviceName: form.device.name,
              technicianName: form.technicianName ?? '-',
              createdAt: form.createdAt,
              accent: const Color(0xFF2E7D32),
            ),
          ),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return _sectionCard(
      title: 'Son Kayitlar',
      subtitle: 'En yeni servis ve bakim kayitlari burada listelenir.',
      accent: const Color(0xFF1565C0),
      child: items.isEmpty
          ? _emptyPanel(
              icon: Icons.receipt_long_outlined,
              title: 'Henuz form hareketi yok',
              subtitle:
                  'Ilk servis veya bakim kaydi olustugunda burada gorunecek.',
            )
          : Column(
              children: items.take(6).map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 46,
                        decoration: BoxDecoration(
                          color: item.accent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: item.accent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    item.type,
                                    style: TextStyle(
                                      color: item.accent,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.formNumber,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${item.customerName} / ${item.deviceName}',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.technicianName} / ${DateFormat('dd.MM.yyyy HH:mm').format(item.createdAt)}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildTechnicianLoadPanel(
    BuildContext context,
    TechnicianProvider technicianProvider,
    ServiceFormProvider serviceProvider,
    MaintenanceFormProvider maintenanceProvider,
    ExpenseReportProvider expenseReportProvider,
  ) {
    final rows = technicianProvider.technicians.map((technician) {
      final name = technician.fullName.trim();
      final serviceCount = serviceProvider.forms
          .where((form) => (form.technicianName ?? '').trim() == name)
          .length;
      final maintenanceCount = maintenanceProvider.forms
          .where((form) => (form.technicianName ?? '').trim() == name)
          .length;
      final reportCount = expenseReportProvider.reports
          .where((report) => report.technician.fullName.trim() == name)
          .length;
      return _TechnicianLoadRow(
        name: name,
        title: technician.title ?? '-',
        serviceCount: serviceCount,
        maintenanceCount: maintenanceCount,
        expenseReportCount: reportCount,
      );
    }).toList()
      ..sort((a, b) {
        final aTotal =
            a.serviceCount + a.maintenanceCount + a.expenseReportCount;
        final bTotal =
            b.serviceCount + b.maintenanceCount + b.expenseReportCount;
        return bTotal.compareTo(aTotal);
      });

    return _sectionCard(
      title: 'Teknisyen Ozeti',
      subtitle: 'Kimin ne kadar isi oldugunu kolayca takip et.',
      accent: const Color(0xFF475569),
      child: rows.isEmpty
          ? _emptyPanel(
              icon: Icons.engineering_outlined,
              title: 'Kayitli teknisyen bulunmuyor',
              subtitle:
                  'Teknisyen kartlari olustugunda bu alan otomatik dolar.',
            )
          : Column(
              children: rows.take(6).map((row) {
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showTechnicianDetailSheet(
                    context,
                    row,
                    serviceProvider,
                    maintenanceProvider,
                    expenseReportProvider,
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                row.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.open_in_new,
                              size: 16,
                              color: Colors.grey.shade500,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          row.title,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _tinyStatChip('Servis', row.serviceCount,
                                const Color(0xFF1565C0)),
                            _tinyStatChip('Bakim', row.maintenanceCount,
                                const Color(0xFF2E7D32)),
                            _tinyStatChip('Masraf', row.expenseReportCount,
                                const Color(0xFFEF6C00)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Color _activityColor(LanSyncActivitySeverity severity) {
    switch (severity) {
      case LanSyncActivitySeverity.success:
        return const Color(0xFF2E7D32);
      case LanSyncActivitySeverity.warning:
        return const Color(0xFFEF6C00);
      case LanSyncActivitySeverity.error:
        return const Color(0xFFC62828);
      case LanSyncActivitySeverity.info:
        return const Color(0xFF1565C0);
    }
  }

  String _activityTypeLabel(LanSyncActivityType type) {
    switch (type) {
      case LanSyncActivityType.server:
        return 'Server';
      case LanSyncActivityType.sync:
        return 'Senkron';
      case LanSyncActivityType.access:
        return 'Erisim';
      case LanSyncActivityType.review:
        return 'Inceleme';
    }
  }

  String _activitySeverityLabel(LanSyncActivitySeverity severity) {
    switch (severity) {
      case LanSyncActivitySeverity.info:
        return 'Bilgi';
      case LanSyncActivitySeverity.success:
        return 'Basarili';
      case LanSyncActivitySeverity.warning:
        return 'Uyari';
      case LanSyncActivitySeverity.error:
        return 'Hata';
    }
  }

  IconData _activityIcon(LanSyncActivity activity) {
    switch (activity.type) {
      case LanSyncActivityType.server:
        return Icons.cloud_outlined;
      case LanSyncActivityType.access:
        return Icons.verified_user_outlined;
      case LanSyncActivityType.review:
        return Icons.fact_check_outlined;
      case LanSyncActivityType.sync:
        return Icons.sync;
    }
  }

  Widget _tinyStatChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Future<void> _showTechnicianDetailSheet(
    BuildContext context,
    _TechnicianLoadRow row,
    ServiceFormProvider serviceProvider,
    MaintenanceFormProvider maintenanceProvider,
    ExpenseReportProvider expenseReportProvider,
  ) async {
    final recentServices = serviceProvider.forms
        .where((form) => (form.technicianName ?? '').trim() == row.name)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final recentMaintenances = maintenanceProvider.forms
        .where((form) => (form.technicianName ?? '').trim() == row.name)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final recentReports = expenseReportProvider.reports
        .where((report) => report.technician.fullName.trim() == row.name)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(18),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            row.title,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _tinyStatChip(
                        'Servis', row.serviceCount, const Color(0xFF1565C0)),
                    _tinyStatChip(
                        'Bakim', row.maintenanceCount, const Color(0xFF2E7D32)),
                    _tinyStatChip('Masraf', row.expenseReportCount,
                        const Color(0xFFEF6C00)),
                  ],
                ),
                const SizedBox(height: 18),
                _detailListSection(
                  'Son Servisler',
                  recentServices.take(4).map((form) {
                    return '${form.formNumber} / ${form.customer.name} / ${DateFormat('dd.MM.yyyy').format(form.createdAt)}';
                  }).toList(),
                ),
                const SizedBox(height: 14),
                _detailListSection(
                  'Son Bakimlar',
                  recentMaintenances.take(4).map((form) {
                    return '${form.formNumber} / ${form.customer.name} / ${DateFormat('dd.MM.yyyy').format(form.createdAt)}';
                  }).toList(),
                ),
                const SizedBox(height: 14),
                _detailListSection(
                  'Masraf Raporlari',
                  recentReports.take(4).map((report) {
                    return '${report.reportNumber} / ${NumberFormat('#,##0.00', 'tr_TR').format(report.totalAmount)} / ${report.isCollected ? 'Tahsil edildi' : 'Tahsil bekliyor'}';
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailListSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text(
            'Kayit bulunmuyor.',
            style: TextStyle(color: Colors.grey.shade600),
          )
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '- $item',
                style: TextStyle(color: Colors.grey.shade800),
              ),
            ),
          ),
      ],
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
    Color? accent,
  }) {
    final panelAccent = accent ?? const Color(0xFF1565C0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: panelAccent.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 4,
            decoration: BoxDecoration(
              color: panelAccent.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: panelAccent.withValues(alpha: 0.22),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: panelAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.dashboard_customize_outlined,
                  color: panelAccent,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _emptyPanel({
    required IconData icon,
    required String title,
    required String subtitle,
    Color color = const Color(0xFF1565C0),
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AsyncOpsData {
  final int pendingAccessRequests;
  final int pendingReviewItems;

  const _AsyncOpsData({
    this.pendingAccessRequests = 0,
    this.pendingReviewItems = 0,
  });
}

class _MetricCardData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MetricCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _QuickActionData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _QueueData {
  final String label;
  final String helper;
  final int value;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;

  const _QueueData({
    required this.label,
    required this.helper,
    required this.value,
    required this.accent,
    required this.icon,
    required this.onTap,
  });
}

class _RecentFormRow {
  final String type;
  final String formNumber;
  final String customerName;
  final String deviceName;
  final String technicianName;
  final DateTime createdAt;
  final Color accent;

  const _RecentFormRow({
    required this.type,
    required this.formNumber,
    required this.customerName,
    required this.deviceName,
    required this.technicianName,
    required this.createdAt,
    required this.accent,
  });
}

class _TechnicianLoadRow {
  final String name;
  final String title;
  final int serviceCount;
  final int maintenanceCount;
  final int expenseReportCount;

  const _TechnicianLoadRow({
    required this.name,
    required this.title,
    required this.serviceCount,
    required this.maintenanceCount,
    required this.expenseReportCount,
  });
}

class _GuideStep {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _GuideStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
