import 'dart:io';

import 'package:biomed_serv/providers/notification_provider.dart';
import 'package:biomed_serv/screens/api_settings_screen.dart';
import 'package:biomed_serv/screens/backup_screen.dart';
import 'package:biomed_serv/screens/company_setup_screen.dart';
import 'package:biomed_serv/screens/desktop_dispatch_board_screen.dart';
import 'package:biomed_serv/screens/customer_management_screen.dart';
import 'package:biomed_serv/screens/dashboard_screen_v2.dart';
import 'package:biomed_serv/screens/desktop_shell_screen.dart';
import 'package:biomed_serv/screens/desktop_sync_center_screen.dart';
import 'package:biomed_serv/screens/device_management_screen.dart';
import 'package:biomed_serv/screens/device_personel_management_screen.dart';
import 'package:biomed_serv/screens/excel_transfer_screen.dart';
import 'package:biomed_serv/screens/expense_management_screen.dart';
import 'package:biomed_serv/screens/fault_ticket_list_screen.dart';
import 'package:biomed_serv/screens/form_history_screen.dart';
import 'package:biomed_serv/screens/home_screen.dart';
import 'package:biomed_serv/screens/maintenance_template_management_screen.dart';
import 'package:biomed_serv/screens/mobile_daily_work_screen.dart';
import 'package:biomed_serv/screens/mobile_sync_screen.dart';
import 'package:biomed_serv/screens/notification_screen.dart';
import 'package:biomed_serv/screens/report_template_management_screen.dart';
import 'package:biomed_serv/screens/reports_screen.dart';
import 'package:biomed_serv/screens/search_screen.dart';
import 'package:biomed_serv/screens/service_form_screen.dart';
import 'package:biomed_serv/screens/stock_screen.dart';
import 'package:biomed_serv/screens/technical_assignment_screen.dart';
import 'package:biomed_serv/screens/technician_management_screen.dart';
import 'package:biomed_serv/screens/tender_management_screen.dart';
import 'package:biomed_serv/screens/tools_screen.dart';
import 'package:biomed_serv/services/app_ui_settings_service.dart';
import 'package:biomed_serv/services/lan_auto_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AppDrawer extends StatefulWidget {
  final bool embedded;
  final Type? activeScreenType;

  const AppDrawer({
    super.key,
    this.embedded = false,
    this.activeScreenType,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  bool _editMode = false;
  String _menuQuery = '';
  final TextEditingController _menuSearchController = TextEditingController();

  @override
  void dispose() {
    _menuSearchController.dispose();
    super.dispose();
  }

  List<_MenuGroup> get _groups => [
        _MenuGroup('quick', 'Hızlı Erişim', Icons.bolt, Colors.blue),
        _MenuGroup('field', 'Saha Operasyonları', Icons.work, Colors.indigo),
        _MenuGroup(
          'records',
          'Varlıklar ve Atamalar',
          Icons.account_tree,
          Colors.blueGrey,
        ),
        _MenuGroup(
            'reports', 'Raporlar ve Analiz', Icons.insights, Colors.green),
        _MenuGroup(
            'data', 'Veri ve Senkronizasyon', Icons.sync_alt, Colors.teal),
        _MenuGroup('admin', 'Yönetim ve Ayarlar', Icons.settings, Colors.grey),
      ];

  List<_MenuGroup> get _mobileGroups => [
        _MenuGroup('quick', 'Sık Kullanılan', Icons.bolt, Colors.blue),
        _MenuGroup('field', 'Saha İşlemleri', Icons.work, Colors.indigo),
        _MenuGroup('records', 'Kurum ve Varlıklar', Icons.hub, Colors.blueGrey),
        _MenuGroup(
            'reports', 'Raporlar ve Geçmiş', Icons.insights, Colors.teal),
        _MenuGroup('data', 'Araçlar ve Veri', Icons.sync_alt, Colors.blueGrey),
        _MenuGroup(
          'admin',
          'Hesabım ve Ayarlar',
          Icons.admin_panel_settings,
          Colors.indigo,
        ),
      ];

  List<_MenuEntry> get _entries => [
        _MenuEntry.home(),
        _MenuEntry.screen(
          id: 'search',
          groupId: 'quick',
          icon: Icons.search,
          title: 'Ara',
          color: Colors.orange,
          builder: (_) => const SearchScreen(),
        ),
        _MenuEntry.screen(
          id: 'tools',
          groupId: 'quick',
          icon: Icons.construction,
          title: 'Araçlar',
          color: Colors.teal,
          builder: (_) => const ToolsScreen(),
        ),
        _MenuEntry.screen(
          id: 'desktopSync',
          groupId: 'data',
          icon: Icons.hub,
          title: Platform.isWindows || Platform.isLinux || Platform.isMacOS
              ? 'Senkron Merkezi'
              : 'Merkeze Bağlan',
          color: Colors.green,
          builder: (context) {
            if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
              final pending =
                  context.read<LanAutoSyncService>().pendingAccessCount;
              return DesktopSyncCenterScreen(initialTab: pending > 0 ? 1 : 0);
            }
            return const MobileSyncScreen();
          },
          badgeBuilder: (context) {
            if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
              final autoSync = context.watch<LanAutoSyncService>();
              if (autoSync.isSyncing) return '...';
              if (autoSync.centerAccessApproved == false) return '!';
              if (autoSync.lastResult != null) return '✓';
              return null;
            }
            final pending =
                context.watch<LanAutoSyncService>().pendingAccessCount;
            return pending > 0 ? '$pending' : null;
          },
        ),
        _MenuEntry.screen(
          id: 'serviceForms',
          groupId: 'field',
          icon: Icons.description,
          title: 'Servis Formları',
          color: Colors.indigo,
          builder: (_) => const ServiceFormScreen(),
        ),
        _MenuEntry.screen(
          id: 'dispatch',
          groupId: 'field',
          icon: Icons.calendar_view_week,
          title: 'Günlük Planlama',
          color: Colors.deepPurple,
          builder: (_) =>
              Platform.isWindows || Platform.isLinux || Platform.isMacOS
                  ? const DesktopDispatchBoardScreen()
                  : const MobileDailyWorkScreen(),
        ),
        _MenuEntry.screen(
          id: 'formHistory',
          groupId: 'field',
          icon: Icons.history_edu,
          title: 'Form Geçmişi',
          color: Colors.teal,
          builder: (_) => const FormHistoryScreen(),
        ),
        _MenuEntry.screen(
          id: 'faultTickets',
          groupId: 'field',
          icon: Icons.build,
          title: 'Arıza Kayıtları',
          color: Colors.red,
          builder: (_) => const FaultTicketListScreen(),
        ),
        _MenuEntry.screen(
          id: 'customers',
          groupId: 'records',
          icon: Icons.business,
          title: 'Müşteri / Cari',
          color: Colors.orange,
          builder: (_) => const CustomerManagementScreen(),
        ),
        _MenuEntry.screen(
          id: 'devices',
          groupId: 'records',
          icon: Icons.devices,
          title: 'Cihaz Yönetimi',
          color: Colors.blue,
          builder: (_) => const DeviceManagementScreen(),
        ),
        _MenuEntry.screen(
          id: 'personnel',
          groupId: 'records',
          icon: Icons.people,
          title: 'Personel Yönetimi',
          color: Colors.deepPurple,
          builder: (_) => const DevicePersonelManagementScreen(),
        ),
        _MenuEntry.screen(
          id: 'assignments',
          groupId: 'records',
          icon: Icons.assignment_ind,
          title: 'Teknik Servis Atamaları',
          color: Colors.green,
          builder: (_) => const TechnicalAssignmentScreen(),
        ),
        _MenuEntry.screen(
          id: 'stock',
          groupId: 'records',
          icon: Icons.inventory_2,
          title: 'Stok Yönetimi',
          color: Colors.amber,
          builder: (_) => const StockScreen(),
        ),
        _MenuEntry.screen(
          id: 'tenders',
          groupId: 'records',
          icon: Icons.gavel,
          title: 'İhale Yönetimi',
          color: Colors.brown,
          builder: (_) => const TenderManagementScreen(),
        ),
        _MenuEntry.screen(
          id: 'maintenanceTemplates',
          groupId: 'records',
          icon: Icons.build_circle,
          title: 'Bakım Şablonları',
          color: Colors.cyan,
          builder: (_) => const MaintenanceTemplateManagementScreen(),
        ),
        _MenuEntry.screen(
          id: 'expenses',
          groupId: 'field',
          icon: Icons.receipt_long,
          title: 'Masraf Yönetimi',
          color: Colors.red,
          builder: (_) => const ExpenseManagementScreen(),
        ),
        _MenuEntry.screen(
          id: 'reports',
          groupId: 'reports',
          icon: Icons.assessment,
          title: 'Raporlar',
          color: Colors.green,
          builder: (_) => const ReportsScreen(),
        ),
        _MenuEntry.screen(
          id: 'excel',
          groupId: 'data',
          icon: Icons.table_view,
          title: 'Excel Aktarımı',
          color: Colors.green,
          builder: (_) => const ExcelTransferScreen(),
        ),
        _MenuEntry.screen(
          id: 'analytics',
          groupId: 'reports',
          icon: Icons.analytics,
          title: 'Analiz & Raporlama',
          color: Colors.purple,
          builder: (_) => const DashboardScreenV2(),
        ),
        _MenuEntry.screen(
          id: 'reportTemplates',
          groupId: 'reports',
          icon: Icons.description_outlined,
          title: 'Rapor Tasarımları',
          color: Colors.teal,
          builder: (_) => const ReportTemplateManagementScreen(),
        ),
        _MenuEntry.screen(
          id: 'technicians',
          groupId: 'admin',
          icon: Icons.person,
          title: Platform.isAndroid || Platform.isIOS
              ? 'Teknisyen Bilgilerim'
              : 'Teknisyen Yönetimi',
          color: Colors.blue,
          builder: (_) => const TechnicianManagementScreen(),
        ),
        _MenuEntry.screen(
          id: 'company',
          groupId: 'admin',
          icon: Icons.business,
          title: 'Firma Bilgileri',
          color: Colors.indigo,
          builder: (_) => const CompanySetupScreen(),
        ),
        _MenuEntry.screen(
          id: 'api',
          groupId: 'data',
          icon: Icons.api,
          title: 'Entegrasyon Ayarları',
          color: Colors.deepPurple,
          builder: (_) => const ApiSettingsScreen(),
        ),
        _MenuEntry.screen(
          id: 'backup',
          groupId: 'data',
          icon: Icons.backup,
          title: 'Yedekleme',
          color: Colors.green,
          builder: (_) => const BackupScreen(),
        ),
        _MenuEntry.screen(
          id: 'notifications',
          groupId: 'admin',
          icon: Icons.notifications,
          title: 'Bildirimler',
          color: Colors.orange,
          builder: (_) => const NotificationScreen(),
          badgeBuilder: (context) {
            final count = context.watch<NotificationProvider>().unreadCount;
            return count > 0 ? '$count' : null;
          },
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final isDesktopMenu =
        widget.embedded || MediaQuery.sizeOf(context).width >= 1180;
    final uiSettings = context.watch<AppUiSettingsService>();
    final entriesById = {for (final entry in _entries) entry.id: entry};
    final orderedIds = uiSettings.orderedMenuIds(entriesById.keys.toList());
    final orderedEntries = orderedIds
        .map((id) => entriesById[id])
        .whereType<_MenuEntry>()
        .where((entry) => entry.id != 'search')
        .where((entry) => isDesktopMenu || _isEntryVisibleOnMobile(entry))
        .where(
          (entry) => _matchesMenuQuery(
            uiSettings,
            entry,
            isDesktopMenu ? _groups : _mobileGroups,
            !isDesktopMenu,
          ),
        )
        .toList();

    final content = Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          _buildHeader(context, uiSettings),
          if (isDesktopMenu) _buildToolbar(context, uiSettings),
          _buildMenuSearch(context, isDesktopMenu: isDesktopMenu),
          Expanded(
            child: isDesktopMenu && _editMode && !uiSettings.menuLocked
                ? _buildEditableList(context, uiSettings, orderedEntries)
                : _buildLockedMenu(
                    context,
                    uiSettings,
                    orderedEntries,
                    groups: isDesktopMenu ? _groups : _mobileGroups,
                    mobileMode: !isDesktopMenu,
                  ),
          ),
        ],
      ),
    );

    if (widget.embedded) return content;
    return Drawer(child: content);
  }

  Widget _buildHeader(BuildContext context, AppUiSettingsService uiSettings) {
    return Container(
      color: const Color(0xFF102F3A),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/branding/biomed_servis_logo.png',
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(
                        Icons.medical_services,
                        color: Colors.white,
                        size: 27,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Biomed Servis',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Biyomedikal servis çalışma alanı',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
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

  Widget _buildToolbar(BuildContext context, AppUiSettingsService uiSettings) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Colors.blueGrey.shade100)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Tooltip(
                message: uiSettings.menuLocked ? 'Menu kilitli' : 'Menu acik',
                child: IconButton(
                  onPressed: () async {
                    await uiSettings.setMenuLocked(!uiSettings.menuLocked);
                    if (uiSettings.menuLocked && mounted) {
                      setState(() => _editMode = false);
                    }
                  },
                  icon: Icon(
                    uiSettings.menuLocked ? Icons.lock : Icons.lock_open,
                    color: uiSettings.menuLocked
                        ? Colors.blueGrey
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              Expanded(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.menu),
                      label: Text('Kullan'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.drag_indicator),
                      label: Text('Duzenle'),
                    ),
                  ],
                  selected: {_editMode && !uiSettings.menuLocked},
                  onSelectionChanged: uiSettings.menuLocked
                      ? null
                      : (value) => setState(() => _editMode = value.first),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Tema',
                icon: const Icon(Icons.palette_outlined),
                onSelected: uiSettings.setThemeId,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                      value: 'clinicalBlue', child: Text('Klinik Mavi')),
                  PopupMenuItem(value: 'emerald', child: Text('Zumrut')),
                  PopupMenuItem(value: 'graphite', child: Text('Grafit')),
                  PopupMenuItem(value: 'ruby', child: Text('Yakut')),
                  PopupMenuItem(value: 'amber', child: Text('Amber')),
                ],
              ),
            ],
          ),
          if (_editMode && !uiSettings.menuLocked)
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Surukle, grubunu sec, sonra kilitle.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton.icon(
                  onPressed: uiSettings.resetMenu,
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('Sifirla'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMenuSearch(
    BuildContext context, {
    required bool isDesktopMenu,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(12, isDesktopMenu ? 10 : 12, 12, 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Colors.blueGrey.withValues(alpha: 0.10)),
        ),
      ),
      child: TextField(
        controller: _menuSearchController,
        textInputAction: TextInputAction.search,
        onChanged: (value) => setState(() => _menuQuery = value),
        onSubmitted: (_) => _openGlobalSearch(context),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Menüde ara',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _menuQuery.trim().isEmpty
              ? IconButton(
                  tooltip: 'Genel arama',
                  icon: const Icon(Icons.open_in_new, size: 18),
                  onPressed: () => _openGlobalSearch(context),
                )
              : IconButton(
                  tooltip: 'Temizle',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _menuSearchController.clear();
                    setState(() => _menuQuery = '');
                  },
                ),
          filled: true,
          fillColor:
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.50),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blueGrey.shade100),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blueGrey.shade100),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        ),
      ),
    );
  }

  Widget _buildLockedMenu(
    BuildContext context,
    AppUiSettingsService uiSettings,
    List<_MenuEntry> orderedEntries, {
    required List<_MenuGroup> groups,
    required bool mobileMode,
  }) {
    if (orderedEntries.isEmpty && _menuQuery.trim().isNotEmpty) {
      return _buildNoMenuResults(context);
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (final group in groups)
          _buildGroup(
              context,
              group,
              _entriesForGroup(uiSettings, orderedEntries, group.id,
                  mobileMode: mobileMode),
              mobileMode: mobileMode),
      ],
    );
  }

  Widget _buildNoMenuResults(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 42, color: Colors.grey.shade500),
            const SizedBox(height: 10),
            Text(
              'Sonuc bulunamadi',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Farkli bir menu adi deneyebilir veya genel aramayi acabilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openGlobalSearch(context),
              icon: const Icon(Icons.search),
              label: const Text('Genel Arama'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroup(
    BuildContext context,
    _MenuGroup group,
    List<_MenuEntry> entries, {
    required bool mobileMode,
  }) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final hasActiveEntry =
        entries.any((entry) => _isEntryActive(context, entry));
    final hasMenuQuery = _menuQuery.trim().isNotEmpty;

    if (mobileMode) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Icon(group.icon, size: 17, color: group.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      group.title.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.blueGrey.shade700,
                      ),
                    ),
                  ),
                  Text(
                    '${entries.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.blueGrey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            for (final entry in entries)
              _buildMenuTile(
                context,
                entry,
                compact: true,
                mobileMode: true,
              ),
            Divider(height: 18, color: Colors.blueGrey.shade100),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: hasActiveEntry
              ? group.color.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasActiveEntry
                ? group.color.withValues(alpha: 0.24)
                : Colors.blueGrey.withValues(alpha: 0.08),
          ),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded:
                hasMenuQuery || group.id == 'quick' || hasActiveEntry,
            dense: mobileMode,
            tilePadding: EdgeInsets.symmetric(
              horizontal: mobileMode ? 14 : 16,
              vertical: mobileMode ? 0 : 2,
            ),
            childrenPadding: EdgeInsets.only(bottom: mobileMode ? 4 : 8),
            shape: const Border(),
            collapsedShape: const Border(),
            leading: _iconBox(group.icon, group.color),
            title: Text(
              group.title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: hasActiveEntry ? group.color : null,
              ),
            ),
            subtitle: mobileMode
                ? Text(
                    '${entries.length} islem',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : null,
            iconColor: group.color,
            collapsedIconColor: hasActiveEntry ? group.color : Colors.grey,
            children: [
              for (final entry in entries)
                _buildMenuTile(
                  context,
                  entry,
                  compact: mobileMode || group.id != 'quick',
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditableList(
    BuildContext context,
    AppUiSettingsService uiSettings,
    List<_MenuEntry> orderedEntries,
  ) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 18),
      itemCount: orderedEntries.length,
      onReorder: (oldIndex, newIndex) {
        final ids = orderedEntries.map((entry) => entry.id).toList();
        if (newIndex > oldIndex) newIndex -= 1;
        final item = ids.removeAt(oldIndex);
        ids.insert(newIndex, item);
        uiSettings.setMenuOrder(ids);
      },
      itemBuilder: (context, index) {
        final entry = orderedEntries[index];
        final activeGroupId = _desktopGroupFor(uiSettings, entry);
        return ListTile(
          key: ValueKey(entry.id),
          leading: _iconBox(entry.icon, entry.color, small: true),
          title: Text(entry.title, overflow: TextOverflow.ellipsis),
          subtitle: DropdownButton<String>(
            value: activeGroupId,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items: [
              for (final group in _groups)
                DropdownMenuItem(
                  value: group.id,
                  child: Text(group.title),
                ),
            ],
            onChanged: (value) {
              if (value != null) uiSettings.setMenuGroup(entry.id, value);
            },
          ),
          trailing: const Icon(Icons.drag_handle),
        );
      },
    );
  }

  List<_MenuEntry> _entriesForGroup(
    AppUiSettingsService uiSettings,
    List<_MenuEntry> entries,
    String groupId, {
    bool mobileMode = false,
  }) {
    return entries
        .where((entry) =>
            _effectiveGroupFor(uiSettings, entry, mobileMode) == groupId)
        .toList();
  }

  String _effectiveGroupFor(
    AppUiSettingsService uiSettings,
    _MenuEntry entry,
    bool mobileMode,
  ) {
    if (!mobileMode) return _desktopGroupFor(uiSettings, entry);
    switch (entry.id) {
      case 'home':
      case 'dispatch':
      case 'serviceForms':
      case 'faultTickets':
        return 'quick';
      case 'expenses':
        return 'field';
      case 'devices':
      case 'customers':
      case 'personnel':
      case 'assignments':
      case 'stock':
      case 'tenders':
      case 'maintenanceTemplates':
        return 'records';
      case 'reports':
      case 'formHistory':
      case 'analytics':
      case 'reportTemplates':
        return 'reports';
      case 'tools':
      case 'desktopSync':
      case 'excel':
      case 'backup':
        return 'data';
      case 'technicians':
      case 'company':
      case 'api':
      case 'notifications':
        return 'admin';
      default:
        return 'admin';
    }
  }

  String _desktopGroupFor(AppUiSettingsService uiSettings, _MenuEntry entry) {
    final requestedGroup = uiSettings.groupFor(entry.id, entry.groupId);
    final validGroupIds = _groups.map((group) => group.id).toSet();
    return validGroupIds.contains(requestedGroup)
        ? requestedGroup
        : entry.groupId;
  }

  bool _matchesMenuQuery(
    AppUiSettingsService uiSettings,
    _MenuEntry entry,
    List<_MenuGroup> groups,
    bool mobileMode,
  ) {
    final query = _normalizeMenuText(_menuQuery);
    if (query.isEmpty) return true;

    final groupId = _effectiveGroupFor(uiSettings, entry, mobileMode);
    String groupTitle = '';
    for (final group in groups) {
      if (group.id == groupId) {
        groupTitle = group.title;
        break;
      }
    }

    final haystack = [
      entry.title,
      groupTitle,
      entry.id,
    ].map(_normalizeMenuText).join(' ');
    return haystack.contains(query);
  }

  String _normalizeMenuText(String value) {
    var normalized = value.trim().toLowerCase();
    normalized = normalized
        .replaceAll('\u0131', 'i')
        .replaceAll('\u015f', 's')
        .replaceAll('\u011f', 'g')
        .replaceAll('\u00fc', 'u')
        .replaceAll('\u00f6', 'o')
        .replaceAll('\u00e7', 'c');
    return normalized.replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _isEntryVisibleOnMobile(_MenuEntry entry) {
    const allowedIds = {
      'home',
      'search',
      'tools',
      'desktopSync',
      'serviceForms',
      'dispatch',
      'formHistory',
      'faultTickets',
      'expenses',
      'devices',
      'customers',
      'personnel',
      'stock',
      'tenders',
      'maintenanceTemplates',
      'reports',
      'excel',
      'analytics',
      'reportTemplates',
      'technicians',
      'company',
      'backup',
      'notifications',
    };
    return allowedIds.contains(entry.id);
  }

  Widget _buildMenuTile(
    BuildContext context,
    _MenuEntry entry, {
    required bool compact,
    bool mobileMode = false,
  }) {
    final badge = entry.badgeBuilder?.call(context);
    final isActive = _isEntryActive(context, entry);
    final glowColor = entry.color;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: EdgeInsets.fromLTRB(mobileMode ? 0 : (compact ? 14 : 10),
          mobileMode ? 1 : 4, mobileMode ? 0 : 10, mobileMode ? 1 : 4),
      decoration: BoxDecoration(
        color:
            isActive ? glowColor.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(mobileMode ? 6 : 14),
        border: mobileMode
            ? Border(
                left: BorderSide(
                  color: isActive ? glowColor : Colors.transparent,
                  width: 3,
                ),
              )
            : Border.all(
                color: isActive
                    ? glowColor.withValues(alpha: 0.72)
                    : Colors.transparent,
                width: isActive ? 1.5 : 1,
              ),
        boxShadow: isActive && !mobileMode
            ? [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.22),
                  blurRadius: 18,
                  spreadRadius: 0.5,
                ),
              ]
            : const [],
      ),
      child: ListTile(
        dense: compact,
        visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
        minLeadingWidth: compact ? 28 : null,
        contentPadding: compact
            ? EdgeInsets.only(left: mobileMode ? 12 : 18, right: 12)
            : null,
        leading: compact
            ? Icon(entry.icon, color: entry.color, size: 20)
            : _iconBox(entry.icon, entry.color),
        title: Row(
          children: [
            Expanded(
              child: Text(
                entry.title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 14 : null,
                  fontWeight: isActive
                      ? FontWeight.w800
                      : (compact ? FontWeight.w500 : FontWeight.w600),
                  color: isActive ? glowColor : null,
                ),
              ),
            ),
            if (badge != null) _badge(badge),
          ],
        ),
        trailing: compact
            ? null
            : Icon(
                Icons.chevron_right,
                size: 20,
                color: isActive ? glowColor : Colors.grey.shade500,
              ),
        onTap: () => _openEntry(context, entry),
      ),
    );
  }

  bool _isEntryActive(BuildContext context, _MenuEntry entry) {
    if (entry.id == 'home') {
      return widget.activeScreenType == HomeScreen;
    }
    final builder = entry.builder;
    if (builder == null || widget.activeScreenType == null) return false;
    return builder(context).runtimeType == widget.activeScreenType;
  }

  Widget _iconBox(IconData icon, Color color, {bool small = false}) {
    return Container(
      width: small ? 36 : null,
      height: small ? 36 : null,
      padding: EdgeInsets.all(small ? 7 : 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: small ? 20 : 22),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _openEntry(BuildContext context, _MenuEntry entry) {
    if (entry.id == 'home') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
      return;
    }
    if (!widget.embedded && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    openDesktopAwareScreen(
      context,
      entry.builder!(context),
      replacement: widget.embedded || shouldUseDesktopShell(context),
    );
  }

  void _openGlobalSearch(BuildContext context) {
    if (!widget.embedded && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    openDesktopAwareScreen(
      context,
      const SearchScreen(),
      replacement: widget.embedded || shouldUseDesktopShell(context),
    );
  }
}

class _MenuGroup {
  final String id;
  final String title;
  final IconData icon;
  final Color color;

  const _MenuGroup(this.id, this.title, this.icon, this.color);
}

class _MenuEntry {
  final String id;
  final String groupId;
  final IconData icon;
  final String title;
  final Color color;
  final WidgetBuilder? builder;
  final String? Function(BuildContext context)? badgeBuilder;

  const _MenuEntry({
    required this.id,
    required this.groupId,
    required this.icon,
    required this.title,
    required this.color,
    this.builder,
    this.badgeBuilder,
  });

  factory _MenuEntry.home() {
    return const _MenuEntry(
      id: 'home',
      groupId: 'quick',
      icon: Icons.home,
      title: 'Ana Sayfa',
      color: Colors.blue,
    );
  }

  factory _MenuEntry.screen({
    required String id,
    required String groupId,
    required IconData icon,
    required String title,
    required Color color,
    required WidgetBuilder builder,
    String? Function(BuildContext context)? badgeBuilder,
  }) {
    return _MenuEntry(
      id: id,
      groupId: groupId,
      icon: icon,
      title: title,
      color: color,
      builder: builder,
      badgeBuilder: badgeBuilder,
    );
  }
}
