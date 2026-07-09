import 'package:biomed_serv/models/agent_notification.dart';
import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/models/technician.dart';
import 'package:biomed_serv/providers/agent_provider.dart';
import 'package:biomed_serv/providers/device_provider.dart';
import 'package:biomed_serv/providers/expense_provider.dart';
import 'package:biomed_serv/providers/fault_ticket_provider.dart';
import 'package:biomed_serv/providers/notification_provider.dart';
import 'package:biomed_serv/providers/service_form_provider.dart';
import 'package:biomed_serv/providers/stock_provider.dart';
import 'package:biomed_serv/screens/desktop_operations_dashboard_screen.dart';
import 'package:biomed_serv/screens/expense_management_screen.dart';
import 'package:biomed_serv/screens/fault_ticket_list_screen.dart';
import 'package:biomed_serv/screens/form_history_screen.dart';
import 'package:biomed_serv/screens/notification_screen.dart';
import 'package:biomed_serv/screens/device_detail_screen.dart';
import 'package:biomed_serv/screens/device_management_screen.dart';
import 'package:biomed_serv/screens/device_parts_history_screen.dart';
import 'package:biomed_serv/screens/device_service_history_screen.dart';
import 'package:biomed_serv/screens/document_scanner_screen.dart';
import 'package:biomed_serv/screens/maintenance_form_screen.dart';
import 'package:biomed_serv/screens/mobile_daily_work_screen.dart';
import 'package:biomed_serv/screens/mobile_sync_screen.dart';
import 'package:biomed_serv/screens/qr_generator_screen.dart';
import 'package:biomed_serv/screens/service_form_screen.dart';
import 'package:biomed_serv/screens/smart_document_converter_screen.dart';
import 'package:biomed_serv/screens/stock_screen.dart';
import 'package:biomed_serv/screens/tender_management_screen.dart';
import 'package:biomed_serv/screens/tools_screen.dart';
import 'package:biomed_serv/screens/unit_converter_screen.dart';
import 'package:biomed_serv/services/app_ui_settings_service.dart';
import 'package:biomed_serv/services/barcode_service.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:biomed_serv/services/lan_auto_sync_service.dart';
import 'package:biomed_serv/services/sound_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/offline_indicator.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _showDeviceActions(BuildContext context, Device device) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('Yeni Servis Formu Oluştur'),
              onTap: () {
                Navigator.pop(ctx); // Bottom sheet'i kapat
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            ServiceFormScreen(initialDevice: device)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.build),
              title: const Text('Yeni Bakım Formu Oluştur'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            MaintenanceFormScreen(preselectedDevice: device)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Cihaz Bilgileri'),
              subtitle: const Text('Kurum, sorumlu, teknisyen ve geçmiş'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DeviceDetailScreen(device: device),
                    ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Cihaz Servis Geçmişi'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          DeviceServiceHistoryScreen(device: device),
                    ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text('Cihaz Parça Geçmişi'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          DevicePartsHistoryScreen(device: device),
                    ));
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _scanAndAct(BuildContext context) async {
    final barcode = await BarcodeService().scanBarcode(context);
    if (!context.mounted) return;
    if (barcode.isEmpty) {
      // Hata sesi - tarama iptal/edilemedi
      await SoundService().playError();
      return;
    }

    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    try {
      final device =
          deviceProvider.devices.firstWhere((d) => d.barcode == barcode);
      // Başarılı tarama sesi
      await SoundService().playScan();
      if (!context.mounted) return;
      _showDeviceActions(context, device);
    } catch (e) {
      if (!context.mounted) return;
      // Hata sesi - cihaz bulunamadı
      await SoundService().playError();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('"$barcode" barkoduna sahip bir cihaz bulunamadı.'),
            backgroundColor: Colors.red),
      );
    }
  }

  // ... (Diğer metotlar aynı)
  Widget _getScreenFromRoute(String routeName, {dynamic arguments}) {
    switch (routeName) {
      case '/stock':
        return const StockScreen();
      case '/tender':
        return const TenderManagementScreen();
      case '/device':
        return const DeviceManagementScreen();
      default:
        return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final Technician? technician = dbService.techniciansBox.values.isNotEmpty
        ? dbService.techniciansBox.values.first
        : null;
    final isDesktopLayout = MediaQuery.sizeOf(context).width >= 1180;

    return Scaffold(
      appBar: AppBar(
        title: Text(isDesktopLayout ? 'Merkez Operasyon' : 'Ana Sayfa'),
        actions: [
          // Bildirimler İkonu - Badge ile
          Consumer<NotificationProvider>(
            builder: (context, provider, child) {
              return Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined,
                          color: Colors.white),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NotificationScreen(),
                          ),
                        );
                      },
                    ),
                    if (provider.unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            provider.unreadCount > 99
                                ? '99+'
                                : '${provider.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          // Offline göstergesi
          const OfflineBadge(),
        ],
      ),
      drawer: isDesktopLayout ? null : const AppDrawer(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (isDesktopLayout) {
            return Row(
              children: [
                Container(
                  width: 310,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      right: BorderSide(color: Colors.blueGrey.shade100),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 14,
                        offset: const Offset(4, 0),
                      ),
                    ],
                  ),
                  child: const AppDrawer(embedded: true),
                ),
                const Expanded(child: DesktopOperationsDashboardScreen()),
              ],
            );
          }

          final content = SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hoş Geldiniz Kartı
                  _buildTechnicianGreetingCard(technician),
                  const SizedBox(height: 10),
                  _buildMobileSyncStatus(context),
                  const SizedBox(height: 12),
                  _buildTodayFocusStrip(context),
                  const SizedBox(height: 16),
                  _buildQuickScanButton(context),
                  const SizedBox(height: 20),
                  _buildSectionHeader(
                    icon: Icons.flash_on,
                    title: 'Saha İşlemleri',
                    subtitle: 'Sık kullanılan işlemler',
                  ),
                  const SizedBox(height: 12),
                  _buildQuickActions(context, isDesktopLayout),
                  const SizedBox(height: 16),
                  _buildToolsShortcutCard(context),
                  const SizedBox(height: 20),

                  // 1. Akıllı Asistan (ÜSTTE)
                  _buildSectionHeader(
                    icon: Icons.smart_toy,
                    title: 'Akıllı Asistan',
                    subtitle: 'Önemli bildirimler',
                  ),
                  const SizedBox(height: 16),
                  Consumer<AgentProvider>(
                      builder: (context, agentProvider, child) {
                    if (agentProvider.notifications.isEmpty) {
                      return const SizedBox(
                          height: 100,
                          child: Center(
                              child: Text('Şu an için yeni bildirim yok.')));
                    }
                    return SizedBox(
                        height: 100,
                        child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: agentProvider.notifications.length,
                            itemBuilder: (context, index) {
                              final notification =
                                  agentProvider.notifications[index];
                              return _buildAgentCard(context, notification);
                            }));
                  }),
                  const SizedBox(height: 20),

                  // 2. Hızlı Bakış (ORTADA)
                  _buildSectionHeader(
                    icon: Icons.dashboard,
                    title: 'Hızlı Bakış',
                    subtitle: 'Özet istatistikler',
                  ),
                  const SizedBox(height: 12),
                  _buildDashboardStats(context),
                  const SizedBox(height: 20),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
          if (!isDesktopLayout) return content;
          return Row(
            children: [
              Container(
                width: 310,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    right: BorderSide(color: Colors.blueGrey.shade100),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(4, 0),
                    ),
                  ],
                ),
                child: const AppDrawer(embedded: true),
              ),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTodayFocusStrip(BuildContext context) {
    return Consumer3<FaultTicketProvider, ServiceFormProvider, ExpenseProvider>(
      builder: (context, faultProvider, formProvider, expenseProvider, _) {
        final today = DateTime.now();
        final todaysForms = formProvider.forms.where((form) {
          final created = form.createdAt;
          return created.year == today.year &&
              created.month == today.month &&
              created.day == today.day;
        }).length;

        return Row(
          children: [
            Expanded(
              child: _buildFocusPill(
                context,
                icon: Icons.build_circle_outlined,
                label: 'Açık',
                value: faultProvider.openTickets.length.toString(),
                color: Colors.red,
                screen: const FaultTicketListScreen(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildFocusPill(
                context,
                icon: Icons.history_edu,
                label: 'Bugün',
                value: todaysForms.toString(),
                color: Colors.teal,
                screen: const FormHistoryScreen(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildFocusPill(
                context,
                icon: Icons.payments_outlined,
                label: 'Tahsil',
                value: expenseProvider.reportedExpenses.length.toString(),
                color: Colors.purple,
                screen: const ExpenseManagementScreen(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFocusPill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Widget screen,
  }) {
    return Material(
      color: color.withValues(alpha: 0.08),
      shape: StadiumBorder(
        side: BorderSide(color: color.withValues(alpha: 0.18)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '$label $value',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickScanButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await SoundService().playClick();
          if (!context.mounted) return;
          _scanAndAct(context);
        },
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F766E), Color(0xFF1565C0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1565C0).withValues(alpha: 0.22),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Hızlı Tara',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Cihaz QR/Barkod okut, servis işlemini başlat',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileSyncStatus(BuildContext context) {
    return Consumer<LanAutoSyncService>(
      builder: (context, autoSync, _) {
        final connected =
            autoSync.isCenterReachable && autoSync.centerAccessApproved == true;
        final waitingApproval = autoSync.isCenterReachable &&
            autoSync.centerAccessApproved == false;
        final color = connected
            ? const Color(0xFF2E7D32)
            : waitingApproval
                ? const Color(0xFFB26A00)
                : const Color(0xFF546E7A);
        final title = autoSync.isSyncing
            ? 'Merkez ile senkronize ediliyor'
            : connected
                ? 'Merkeze bağlı'
                : waitingApproval
                    ? 'Merkez onayı bekleniyor'
                    : 'Merkez bağlantısı yok';
        final subtitle = connected
            ? autoSync.lastSyncAt == null
                ? '${autoSync.centerHost}:${autoSync.localApiPort}'
                : 'Son senkron: ${DateFormat('dd.MM HH:mm').format(autoSync.lastSyncAt!)}'
            : autoSync.centerHost == null
                ? 'Aynı ağdaki Desktop merkeze bağlanın'
                : '${autoSync.centerHost}:${autoSync.localApiPort}';

        return Material(
          color: color.withValues(alpha: 0.07),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7),
            side: BorderSide(color: color.withValues(alpha: 0.22)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(7),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MobileSyncScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(11, 8, 7, 8),
              child: Row(
                children: [
                  if (autoSync.isSyncing)
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: color,
                      ),
                    )
                  else
                    Icon(
                      connected
                          ? Icons.cloud_done_outlined
                          : waitingApproval
                              ? Icons.approval_outlined
                              : Icons.cloud_off_outlined,
                      color: color,
                      size: 23,
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blueGrey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton.icon(
                    onPressed: autoSync.isSyncing
                        ? null
                        : () async {
                            if (!connected) {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const MobileSyncScreen(),
                                ),
                              );
                              return;
                            }
                            final result = await autoSync.syncNow(
                              reason: 'Ana sayfa',
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result == null
                                      ? autoSync.lastMessage ??
                                          'Senkronizasyon tamamlanamadı.'
                                      : 'Senkronizasyon tamamlandı.',
                                ),
                              ),
                            );
                          },
                    icon: Icon(
                      connected ? Icons.sync : Icons.link,
                      size: 17,
                    ),
                    label: Text(connected ? 'Senkronize Et' : 'Bağlan'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildToolsShortcutCard(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(7),
        side: BorderSide(color: Colors.blueGrey.withValues(alpha: 0.16)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ToolsScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F4F2),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Icon(
                      Icons.construction,
                      size: 19,
                      color: Colors.teal.shade800,
                    ),
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'Araçlar',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildToolChip(
                    context,
                    icon: Icons.document_scanner,
                    label: 'Belge Tarayıcı',
                    screen: const DocumentScannerScreen(),
                  ),
                  _buildToolChip(
                    context,
                    icon: Icons.table_chart,
                    label: 'Akıllı Dönüştürücü',
                    screen: const SmartDocumentConverterScreen(),
                  ),
                  _buildToolChip(
                    context,
                    icon: Icons.qr_code,
                    label: 'QR Oluşturucu',
                    screen: const QrGeneratorScreen(),
                  ),
                  _buildToolChip(
                    context,
                    icon: Icons.calculate,
                    label: 'Hesaplayıcı',
                    screen: const UnitConverterScreen(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Widget screen,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: const Color(0xFF176B63)),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      visualDensity: VisualDensity.compact,
      backgroundColor: const Color(0xFFF7FBFA),
      side: BorderSide(color: Colors.teal.withValues(alpha: 0.18)),
      shape: const StadiumBorder(),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => screen),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isDesktopLayout) {
    final uiSettings = context.watch<AppUiSettingsService>();
    final actions = _quickActionItems(context);
    final byId = {for (final action in actions) action.id: action};
    final orderedIds = uiSettings.orderedQuickActionIds(byId.keys.toList());
    final orderedActions =
        orderedIds.map((id) => byId[id]).whereType<_QuickActionItem>().toList();
    final editable = isDesktopLayout && !uiSettings.menuLocked;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isDesktopLayout)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(
                  editable ? Icons.drag_indicator : Icons.lock,
                  size: 18,
                  color: editable
                      ? Theme.of(context).colorScheme.primary
                      : Colors.blueGrey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    editable
                        ? 'Menü kilidi açık: hızlı işlem kartlarını sürükleyerek sırala.'
                        : 'Hızlı işlem sırası menü kilidi açılınca düzenlenebilir.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (editable)
                  TextButton.icon(
                    onPressed: uiSettings.resetQuickActions,
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: const Text('Sıfırla'),
                  ),
              ],
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktopGrid = constraints.maxWidth >= 760;
            final isWide = constraints.maxWidth >= 560;
            return GridView.count(
              shrinkWrap: true,
              crossAxisCount: isDesktopGrid ? 4 : (isWide ? 3 : 2),
              crossAxisSpacing: 9,
              mainAxisSpacing: 9,
              childAspectRatio: isDesktopGrid ? 3.35 : (isWide ? 3.0 : 2.45),
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final action in orderedActions)
                  _buildQuickActionDropTarget(
                    context,
                    action: action,
                    orderedIds: orderedActions.map((item) => item.id).toList(),
                    editable: editable,
                    uiSettings: uiSettings,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickActionDropTarget(
    BuildContext context, {
    required _QuickActionItem action,
    required List<String> orderedIds,
    required bool editable,
    required AppUiSettingsService uiSettings,
  }) {
    final card = Stack(
      children: [
        Positioned.fill(
          child: _buildModernActionButton(
            context,
            title: action.title,
            subtitle: action.subtitle,
            icon: action.icon,
            gradient: action.gradient,
            onTap: editable ? () {} : action.onTap,
          ),
        ),
        if (editable)
          Positioned(
            top: 6,
            right: 8,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: action.gradient.first.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.drag_handle,
                color: action.gradient.first,
                size: 17,
              ),
            ),
          ),
      ],
    );

    if (!editable) return card;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != action.id,
      onAcceptWithDetails: (details) {
        _moveQuickAction(
          uiSettings,
          orderedIds,
          draggedId: details.data,
          targetId: action.id,
        );
      },
      builder: (context, candidateData, rejectedData) {
        final highlighted = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: highlighted ? const EdgeInsets.all(3) : EdgeInsets.zero,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: highlighted
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : null,
          ),
          child: LongPressDraggable<String>(
            data: action.id,
            feedback: SizedBox(
              width: 230,
              height: 68,
              child: Material(
                color: Colors.transparent,
                child: Opacity(opacity: 0.9, child: card),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.35, child: card),
            child: card,
          ),
        );
      },
    );
  }

  void _moveQuickAction(
    AppUiSettingsService uiSettings,
    List<String> ids, {
    required String draggedId,
    required String targetId,
  }) {
    final from = ids.indexOf(draggedId);
    final to = ids.indexOf(targetId);
    if (from < 0 || to < 0 || from == to) return;
    final next = [...ids];
    final item = next.removeAt(from);
    next.insert(to, item);
    uiSettings.setQuickActionOrder(next);
  }

  List<_QuickActionItem> _quickActionItems(BuildContext context) {
    return [
      _QuickActionItem(
        id: 'serviceForm',
        title: 'Servis Formu',
        subtitle: 'Yeni kayıt',
        icon: Icons.description,
        gradient: const [Color(0xFFf093fb), Color(0xFFf5576c)],
        onTap: () async {
          await SoundService().playClick();
          if (!context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ServiceFormScreen()),
          );
        },
      ),
      _QuickActionItem(
        id: 'maintenanceForm',
        title: 'Bakım Formu',
        subtitle: 'Periyodik bakım',
        icon: Icons.build,
        gradient: const [Color(0xFF4facfe), Color(0xFF00f2fe)],
        onTap: () async {
          await SoundService().playClick();
          if (!context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MaintenanceFormScreen(),
            ),
          );
        },
      ),
      _QuickActionItem(
        id: 'dailyWork',
        title: 'Günlük İşler',
        subtitle: 'Merkez planları',
        icon: Icons.calendar_view_day,
        gradient: const [Color(0xFF667eea), Color(0xFF764ba2)],
        onTap: () async {
          await SoundService().playClick();
          if (!context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MobileDailyWorkScreen(),
            ),
          );
        },
      ),
      _QuickActionItem(
        id: 'expense',
        title: 'Masraf',
        subtitle: 'Gider ve tahsilat',
        icon: Icons.account_balance_wallet,
        gradient: const [Color(0xFFfa709a), Color(0xFFfee140)],
        onTap: () async {
          await SoundService().playClick();
          if (!context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ExpenseManagementScreen(),
            ),
          );
        },
      ),
    ];
  }

  Widget _buildTechnicianGreetingCard(Technician? technician) {
    final now = DateTime.now();
    final hour = now.hour;
    var greeting = 'İyi Günler';
    if (hour < 12) {
      greeting = 'Günaydın';
    } else if (hour < 18) {
      greeting = 'İyi Öğlenler';
    } else {
      greeting = 'İyi Akşamlar';
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blueGrey.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 23,
              backgroundColor: Colors.blue.shade50,
              backgroundImage: technician?.photoBytes == null
                  ? null
                  : MemoryImage(technician!.photoBytes!),
              child: technician?.photoBytes == null
                  ? Text(
                      (technician?.fullName ?? 'K')
                          .substring(0, 1)
                          .toUpperCase(),
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$greeting, ${technician?.fullName ?? 'Kullanıcı'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('dd MMMM yyyy', 'tr_TR').format(now),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.wb_sunny, color: Colors.orange, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardStats(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hızlı Bakış',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        // DASHBOARD - Canlı Özet Kartlar
        Consumer5<DeviceProvider, StockProvider, ServiceFormProvider,
            FaultTicketProvider, ExpenseProvider>(
          builder: (context, deviceProvider, stockProvider, serviceProvider,
              faultProvider, expenseProvider, child) {
            final lowStockCount = stockProvider.stocks
                .where((i) => i.quantity <= i.criticalStockThreshold)
                .length;
            final pendingFaults = faultProvider.openTickets.length;
            final unCollectedAmount = expenseProvider.totalUnCollectedAmount;
            final reportedCount = expenseProvider.reportedExpenses.length;

            final currencyFormat = NumberFormat.currency(
                locale: 'tr_TR', symbol: 'TL', decimalDigits: 0);

            return LayoutBuilder(
              builder: (context, constraints) {
                final isDesktopGrid = constraints.maxWidth >= 760;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: isDesktopGrid ? 4 : 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: isDesktopGrid ? 2.15 : 1.6,
                  children: [
                    // CİHAZLAR
                    _buildStatCard(
                      'Cihazlar',
                      deviceProvider.devices.length.toString(),
                      Icons.devices,
                      Colors.blue,
                      () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const DeviceManagementScreen())),
                    ),
                    // BEKLEYEN ARIZA
                    _buildStatCard(
                      'Açık Arıza',
                      pendingFaults.toString(),
                      Icons.build,
                      Colors.red,
                      () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const FaultTicketListScreen())),
                      badge:
                          pendingFaults > 0 ? pendingFaults.toString() : null,
                    ),
                    // KRİTİK STOK
                    _buildStatCard(
                      'Kritik Stok',
                      lowStockCount.toString(),
                      Icons.warning,
                      Colors.orange,
                      () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const StockScreen())),
                      badge:
                          lowStockCount > 0 ? lowStockCount.toString() : null,
                    ),
                    // TAHSİL BEKLİYOR (YENİ!)
                    _buildStatCard(
                      'Tahsil Bekliyor',
                      unCollectedAmount > 0
                          ? currencyFormat.format(unCollectedAmount)
                          : '0',
                      Icons.payments,
                      Colors.purple,
                      () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const ExpenseManagementScreen())),
                      badge:
                          reportedCount > 0 ? reportedCount.toString() : null,
                      isCurrency: true,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color,
      VoidCallback onTap,
      {String? badge, bool isCurrency = false}) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.1), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              if (badge != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // YENİ: Bölüm başlığı widget'ı
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.blue, Colors.purple],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // YENİ: KÜÇÜK Modern aksiyon butonu
  Widget _buildModernActionButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    final accent = gradient.first;
    return Material(
      color: accent.withValues(alpha: 0.07),
      shape: StadiumBorder(
        side: BorderSide(color: accent.withValues(alpha: 0.22)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.16)),
                ),
                child: Icon(icon, color: accent, size: 19),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF26343D),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.blueGrey.shade600,
                        fontSize: 10,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // GÜNCELLENDİ: Agent Card - daha modern
  Widget _buildAgentCard(BuildContext context, AgentNotification notification) {
    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 4,
        shadowColor: notification.color.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => _getScreenFromRoute(
                  notification.routeName,
                  arguments: notification.relatedObjectKey,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  notification.color.withValues(alpha: 0.1),
                  Colors.white,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: notification.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        notification.icon,
                        color: notification.color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        notification.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Text(
                    notification.message,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      height: 1.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 3,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.arrow_forward,
                      size: 14,
                      color: notification.color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Detaylar',
                      style: TextStyle(
                        fontSize: 11,
                        color: notification.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _QuickActionItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });
}
