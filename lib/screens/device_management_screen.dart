import 'package:biomed_serv/models/customer.dart';
import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/providers/device_provider.dart';
import 'package:biomed_serv/screens/desktop_shell_screen.dart';
import 'package:biomed_serv/screens/device_detail_screen.dart';
import 'package:biomed_serv/screens/device_edit_screen.dart';
import 'package:biomed_serv/screens/device_registration_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Cihaz Yönetimi - Ağaç Yapısı
/// Kontrol üniteleri expandable, modüller iç içe görünür
class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  // Hangi kontrol ünitelerinin expanded olduğunu tutar
  final Set<int> _expandedControlUnits = {};

  // Filtreleme state'leri
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterType = 'Tümü'; // Tümü, KontrolÜnitesi, Modül, Bağımsız
  String _filterStatus = 'Tümü'; // Tümü, SOLD, RENT
  _DeviceListViewMode _viewMode = _DeviceListViewMode.tree;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cihaz Yönetimi'),
      ),
      body: Consumer<DeviceProvider>(
        builder: (context, provider, child) {
          if (provider.devices.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.devices_other,
                        size: 72, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'Henüz cihaz eklenmemiş',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'SOLO/STANDALONE cihaz veya modüler sistem kontrol ünitesi ekleyerek başlayabilirsiniz.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        openDesktopAwareScreen(
                          context,
                          const DeviceRegistrationScreen(),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Cihaz Ekle'),
                    ),
                  ],
                ),
              ),
            );
          }

          // === FİLTRELEME ===
          final filteredDevices = _filterDevices(provider.devices);

          // Cihazları kategorilere ayır (filtrelenmiş)
          final controlUnits =
              filteredDevices.where((d) => d.isControlModule).toList();
          final standaloneDevices =
              filteredDevices.where((d) => d.isStandalone).toList();
          final orphanedModules = filteredDevices.where((d) {
            return d.isProcessingModule && d.controlModule == null;
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(8),
            children: [
              // === ARAMA VE FİLTRELEME ALANI ===
              _buildFilterSection(),
              _buildInventorySummary(provider.devices, filteredDevices),
              if (filteredDevices.isEmpty)
                _buildNoResultCard()
              else if (_viewMode == _DeviceListViewMode.list) ...[
                _buildSectionHeader(
                  icon: Icons.view_list,
                  color: Colors.indigo,
                  title: 'Liste Görünümü',
                  subtitle: 'Her cihaz kendi kartında, bağlantı bilgisiyle',
                  count: filteredDevices.length,
                ),
                ...filteredDevices.map(
                  (device) => _buildFlatDeviceCard(
                    context,
                    device,
                    provider.devices,
                  ),
                ),
              ] else ...[
                // === KONTROL ÜNİTELERİ (Expandable) ===
                if (controlUnits.isNotEmpty) ...[
                  _buildSectionHeader(
                    icon: Icons.account_tree,
                    color: Colors.deepPurple,
                    title: 'Kontrol Üniteleri',
                    count: controlUnits.length,
                  ),
                  ...controlUnits.map((controlUnit) => _buildControlUnitCard(
                        context,
                        controlUnit,
                        provider.devices
                            .where(
                                (d) => d.controlModule?.key == controlUnit.key)
                            .toList(),
                        filteredDevices,
                      )),
                  const SizedBox(height: 16),
                ],

                // === BAĞIMSIZ CİHAZLAR ===
                if (standaloneDevices.isNotEmpty) ...[
                  _buildSectionHeader(
                    icon: Icons.devices,
                    color: Colors.grey,
                    title: 'Bağımsız Cihazlar',
                    count: standaloneDevices.length,
                  ),
                  ...standaloneDevices.map(
                      (device) => _buildStandaloneDeviceCard(context, device)),
                  const SizedBox(height: 16),
                ],

                // === BAĞIMSIZ MODÜLLER (Kontrol ünitesi olmayan) ===
                if (orphanedModules.isNotEmpty) ...[
                  _buildSectionHeader(
                    icon: Icons.memory,
                    color: Colors.orange,
                    title: 'Bağımsız Modüller',
                    subtitle: 'Kontrol ünitesine atanmamış',
                    count: orphanedModules.length,
                  ),
                  ...orphanedModules.map(
                      (module) => _buildOrphanedModuleCard(context, module)),
                ],
              ],
            ],
          );
        },
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF64B5F6), Color(0xFF1565C0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1565C0).withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            openDesktopAwareScreen(
              context,
              const DeviceRegistrationScreen(),
            );
          },
          tooltip: 'Yeni Cihaz Ekle',
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildInventorySummary(List<Device> allDevices, List<Device> shown) {
    final controlCount = allDevices.where((d) => d.isControlModule).length;
    final moduleCount = allDevices.where((d) => d.isProcessingModule).length;
    final standaloneCount = allDevices.where((d) => d.isStandalone).length;
    final assignedCount =
        allDevices.where((d) => d.customer?.key != null).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildSummaryChip(
              icon: Icons.inventory_2_outlined,
              label: 'Gösterilen',
              value: '${shown.length}/${allDevices.length}',
              color: Colors.indigo,
            ),
            _buildSummaryChip(
              icon: Icons.account_tree_outlined,
              label: 'Kontrol',
              value: '$controlCount',
              color: Colors.deepPurple,
            ),
            _buildSummaryChip(
              icon: Icons.memory_outlined,
              label: 'Modül',
              value: '$moduleCount',
              color: Colors.blue,
            ),
            _buildSummaryChip(
              icon: Icons.devices_other_outlined,
              label: 'Solo',
              value: '$standaloneCount',
              color: Colors.blueGrey,
            ),
            _buildSummaryChip(
              icon: Icons.business_outlined,
              label: 'Kurumda',
              value: '$assignedCount',
              color: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultCard() {
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Sonuç bulunamadı',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Arama metnini veya filtreleri sadeleştirerek tekrar deneyin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  /// Bölüm başlığı
  Widget _buildSectionHeader({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    required int count,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (subtitle != null)
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Kontrol Ünitesi Expandable Card - Kompakt Tasarım
  Widget _buildControlUnitCard(
    BuildContext context,
    Device controlUnit,
    List<Device> modules,
    List<Device> filteredDevices,
  ) {
    final shouldAutoExpand = _searchQuery.isNotEmpty;
    final isExpanded =
        shouldAutoExpand || _expandedControlUnits.contains(controlUnit.key);
    final hasModules = modules.isNotEmpty;
    final controlUnitMatches = _deviceMatchesSearch(controlUnit, _searchQuery);
    final visibleModules = shouldAutoExpand && !controlUnitMatches
        ? modules
            .where(
              (module) =>
                  filteredDevices.any((device) => device.key == module.key) ||
                  _deviceMatchesSearch(module, _searchQuery),
            )
            .toList()
        : modules;
    final chainSize =
        context.read<DeviceProvider>().chainSizeForDevice(controlUnit);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isExpanded ? const Color(0xFF287C75) : const Color(0xFFB8C8CF),
          width: isExpanded ? 1.6 : 1,
        ),
      ),
      child: Column(
        children: [
          // === KONTROL ÜNİTESİ HEADER - Kompakt ===
          InkWell(
            onTap: hasModules
                ? () {
                    setState(() {
                      if (isExpanded) {
                        _expandedControlUnits.remove(controlUnit.key);
                      } else {
                        _expandedControlUnits.add(controlUnit.key!);
                      }
                    });
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // İkon
                  Container(
                    width: 4,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF287C75),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildCompactIcon(controlUnit, const Color(0xFF287C75)),
                  const SizedBox(width: 10),
                  // Bilgiler - Yan Yana
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'KONTROL ÜNİTESİ',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF287C75),
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Üst satır: İsim + Badge
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                controlUnit.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF173F52),
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildSystemBadge(
                              label: '$chainSize cihaz',
                              color: const Color(0xFF287C75),
                            ),
                            const SizedBox(width: 6),
                            _buildMiniBadge(controlUnit.ownershipStatus),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Alt satır: Detaylar yan yana
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${controlUnit.brand} ${controlUnit.model} • ${_serialLabel(controlUnit)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasModules) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE7F2F1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${modules.length} alt modül',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF205F5A),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _buildInfoPill(
                              icon: Icons.business,
                              text: _customerName(controlUnit),
                              color: Colors.green,
                            ),
                            _buildInfoPill(
                              icon: Icons.person,
                              text: _responsibleName(controlUnit),
                              color: Colors.orange,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Sağ: Butonlar
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasModules)
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            color: const Color(0xFF287C75),
                            size: 24,
                          ),
                        ),
                      _buildCompactActionButtons(context, controlUnit),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (!hasModules)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: OutlinedButton.icon(
                onPressed: () {
                  openDesktopAwareScreen(
                    context,
                    DeviceRegistrationScreen(
                      parentControlModule: controlUnit,
                      isAddingModule: true,
                    ),
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Bu Üniteye Modül Ekle'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF287C75),
                  side: const BorderSide(color: Color(0xFF78AAA6)),
                ),
              ),
            ),

          // === BAĞLI MODÜLLER (Expanded) ===
          if (isExpanded && hasModules)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Column(
                children: [
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF7FAFB),
                      border: Border(
                        left: BorderSide(
                          color: Color(0xFF78AAA6),
                          width: 2,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.account_tree_outlined,
                              size: 16,
                              color: Color(0xFF287C75),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Bu kontrol ünitesine bağlı modüller',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF205F5A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Modül Listesi (iç içe)
                        ...visibleModules
                            .map((module) => _buildModuleItem(context, module)),
                        const SizedBox(height: 8),
                        // Modül Ekle Butonu
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              openDesktopAwareScreen(
                                context,
                                DeviceRegistrationScreen(
                                  parentControlModule: controlUnit,
                                  isAddingModule: true,
                                ),
                              );
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Bu Üniteye Modül Ekle'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF287C75),
                              side: const BorderSide(
                                color: Color(0xFF78AAA6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Modül Item (Kontrol ünitesi içinde) - Kompakt
  Widget _buildModuleItem(BuildContext context, Device module) {
    final customerName = (module.customer as Customer?)?.name;

    return Card(
      margin: const EdgeInsets.only(left: 8, bottom: 4),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: Color(0xFFD8E3E7)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          openDesktopAwareScreen(
            context,
            DeviceDetailScreen(device: module),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              // İkon
              const SizedBox(
                width: 24,
                height: 26,
                child: Icon(
                  Icons.subdirectory_arrow_right,
                  size: 18,
                  color: Color(0xFF287C75),
                ),
              ),
              const SizedBox(width: 8),
              // Bilgiler - Yan Yana
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Üst satır: İsim + Badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            module.name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildSystemBadge(
                          label: 'Bağlı',
                          color: Colors.teal,
                        ),
                        const SizedBox(width: 6),
                        _buildMiniBadge(module.ownershipStatus),
                      ],
                    ),
                    const SizedBox(height: 1),
                    // Alt satır: Marka/Model • Seri • Cari
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade600),
                        children: [
                          TextSpan(text: '${module.brand} ${module.model}'),
                          const TextSpan(text: ' • '),
                          TextSpan(text: _serialLabel(module)),
                          if (customerName != null) ...[
                            const TextSpan(text: ' • '),
                            TextSpan(
                              text: customerName,
                              style: TextStyle(color: Colors.green.shade700),
                            ),
                          ],
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              // Sağ: Mini butonlar
              _buildMicroActionButtons(context, module),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlatDeviceCard(
    BuildContext context,
    Device device,
    List<Device> allDevices,
  ) {
    final controlUnit = _controlUnitForDevice(device, allDevices);
    final typeColor = _deviceTypeColor(device);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: typeColor.withValues(alpha: 0.22)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          openDesktopAwareScreen(
            context,
            DeviceDetailScreen(device: device),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildCompactIcon(device, typeColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                device.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildSystemBadge(
                              label: _deviceTypeLabel(device),
                              color: typeColor,
                            ),
                            const SizedBox(width: 6),
                            _buildMiniBadge(device.ownershipStatus),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${device.brand} ${device.model}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildCompactActionButtons(context, device),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildInfoPill(
                    icon: Icons.tag,
                    text: _serialLabel(device),
                    color: Colors.indigo,
                  ),
                  _buildInfoPill(
                    icon: Icons.business,
                    text: _customerName(device),
                    color: Colors.green,
                  ),
                  _buildInfoPill(
                    icon: Icons.person,
                    text: _responsibleName(device),
                    color: Colors.orange,
                  ),
                  if (device.location?.trim().isNotEmpty == true)
                    _buildInfoPill(
                      icon: Icons.location_on_outlined,
                      text: device.location!.trim(),
                      color: Colors.blueGrey,
                    ),
                ],
              ),
              if (device.isProcessingModule) ...[
                const SizedBox(height: 10),
                _buildControlUnitContext(controlUnit),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlUnitContext(Device? controlUnit) {
    final hasControl = controlUnit != null;
    final color = hasControl ? Colors.deepPurple : Colors.orange;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(
            hasControl ? Icons.account_tree_outlined : Icons.warning_amber,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasControl
                  ? 'Bağlı kontrol ünitesi: ${controlUnit.name} • ${_serialLabel(controlUnit)}'
                  : 'Bu modül henüz bir kontrol ünitesine bağlı değil.',
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
    );
  }

  /// Bağımsız Cihaz Card - Kompakt
  Widget _buildStandaloneDeviceCard(BuildContext context, Device device) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          openDesktopAwareScreen(
            context,
            DeviceDetailScreen(device: device),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // İkon
              _buildCompactIcon(device, Colors.grey),
              const SizedBox(width: 10),
              // Bilgiler
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Üst satır: İsim + Badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            device.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildSystemBadge(
                          label: 'SOLO',
                          color: Colors.blueGrey,
                        ),
                        const SizedBox(width: 6),
                        _buildMiniBadge(device.ownershipStatus),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Alt satır: Detaylar
                    Text(
                      '${device.brand} ${device.model} • ${_serialLabel(device)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildInfoPill(
                          icon: Icons.business,
                          text: _customerName(device),
                          color: Colors.green,
                        ),
                        _buildInfoPill(
                          icon: Icons.person,
                          text: _responsibleName(device),
                          color: Colors.orange,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Sağ: Butonlar
              _buildCompactActionButtons(context, device),
            ],
          ),
        ),
      ),
    );
  }

  /// Bağımsız Modül Card (Kontrol ünitesi olmayan) - Kompakt
  Widget _buildOrphanedModuleCard(BuildContext context, Device module) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: Colors.orange.shade50,
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          openDesktopAwareScreen(
            context,
            DeviceDetailScreen(device: module),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // İkon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    Icon(Icons.memory, size: 20, color: Colors.orange.shade700),
              ),
              const SizedBox(width: 10),
              // Bilgiler
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            module.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildSystemBadge(
                          label: 'Bağ Kopuk',
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 6),
                        _buildMiniBadge(module.ownershipStatus),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${module.brand} ${module.model} • ${_serialLabel(module)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Kontrol Ünitesi Yok',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Sağ: Butonlar
              _buildCompactActionButtons(context, module),
            ],
          ),
        ),
      ),
    );
  }

  String _customerName(Device device) {
    final customer = device.customer;
    return customer is Customer ? customer.name : 'Kurum atanmamış';
  }

  String _responsibleName(Device device) {
    final responsible = device.responsiblePerson;
    if (responsible == null) return 'Sorumlu yok';
    return responsible.fullName.trim().isEmpty
        ? 'Sorumlu yok'
        : responsible.fullName;
  }

  String _serialLabel(Device device) => 'SN ${device.serialNumber}';

  Device? _controlUnitForDevice(Device device, List<Device> allDevices) {
    if (!device.isProcessingModule) return null;
    final controlKey = device.controlModule?.key;
    if (controlKey == null) return null;
    for (final candidate in allDevices) {
      if (candidate.key == controlKey) return candidate;
    }
    final linked = device.controlModule;
    return linked is Device ? linked : null;
  }

  String _deviceTypeLabel(Device device) {
    if (device.isControlModule) return 'Kontrol';
    if (device.isProcessingModule) return 'Modül';
    return 'Solo';
  }

  Color _deviceTypeColor(Device device) {
    if (device.isControlModule) return Colors.deepPurple;
    if (device.isProcessingModule) return Colors.blue;
    return Colors.blueGrey;
  }

  Widget _buildInfoPill({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // FİLTRELEME METODLARI
  // =====================================================

  /// Arama ve filtreleme UI
  Widget _buildFilterSection() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: Colors.blueGrey.shade700, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Cihazları Bul ve Süz',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Arama Alanı
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Seri no, cihaz, marka, cari veya sorumlu ara...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
            const SizedBox(height: 12),
            // Filtre Dropdownları
            Row(
              children: [
                // Tip Filtresi
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _filterType,
                    decoration: const InputDecoration(
                      labelText: 'Cihaz Tipi',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: ['Tümü', 'Kontrol Ünitesi', 'Modül', 'Bağımsız']
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type,
                                  style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _filterType = value;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Status Filtresi
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _filterStatus,
                    decoration: const InputDecoration(
                      labelText: 'Sahiplik',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: ['Tümü', 'SOLD', 'RENT']
                        .map((status) => DropdownMenuItem(
                              value: status,
                              child: Text(status,
                                  style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _filterStatus = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<_DeviceListViewMode>(
              segments: const [
                ButtonSegment(
                  value: _DeviceListViewMode.tree,
                  icon: Icon(Icons.account_tree_outlined),
                  label: Text('Ağaç'),
                ),
                ButtonSegment(
                  value: _DeviceListViewMode.list,
                  icon: Icon(Icons.view_list_outlined),
                  label: Text('Liste'),
                ),
              ],
              selected: {_viewMode},
              onSelectionChanged: (selection) {
                setState(() => _viewMode = selection.first);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Cihazları filtrele
  List<Device> _filterDevices(List<Device> devices) {
    return devices.where((device) {
      // 1. Arama filtresi
      if (_searchQuery.isNotEmpty) {
        final matchesDevice = _deviceMatchesSearch(device, _searchQuery);

        // 🔍 BAĞLI MODÜLLERİ DE ARA
        bool matchesConnectedModules = false;
        if (device.isControlModule) {
          // Bu kontrol ünitesine bağlı tüm modülleri bul
          final connectedModules = devices.where((d) =>
              d.isProcessingModule && d.controlModule?.key == device.key);

          // Bağlı modüllerden herhangi biri arama ile eşleşiyor mu?
          for (final module in connectedModules) {
            if (_deviceMatchesSearch(module, _searchQuery)) {
              matchesConnectedModules = true;
              break;
            }
          }
        }

        if (!matchesDevice && !matchesConnectedModules) {
          return false;
        }
      }

      // 2. Tip filtresi
      if (_filterType != 'Tümü') {
        switch (_filterType) {
          case 'Kontrol Ünitesi':
            if (!device.isControlModule) return false;
            break;
          case 'Modül':
            if (!device.isProcessingModule) return false;
            break;
          case 'Bağımsız':
            if (!device.isStandalone) return false;
            break;
        }
      }

      // 3. Status filtresi
      if (_filterStatus != 'Tümü') {
        final targetStatus = _filterStatus == 'SOLD'
            ? OwnershipStatus.sold
            : OwnershipStatus.rented;
        if (device.ownershipStatus != targetStatus) return false;
      }

      return true;
    }).toList();
  }

  bool _deviceMatchesSearch(Device device, String query) {
    if (query.trim().isEmpty) return true;
    final normalizedQuery = query.toLowerCase();
    final customerName =
        device.customer is Customer ? (device.customer as Customer).name : '';
    final responsibleName = device.responsiblePerson?.fullName ?? '';
    final searchable = [
      device.serialNumber,
      device.name,
      device.brand,
      device.model,
      customerName,
      responsibleName,
      device.location ?? '',
      device.deviceCategory ?? '',
    ].join(' ').toLowerCase();
    return searchable.contains(normalizedQuery);
  }

  // =====================================================
  // KOMPAKT TASARIM YARDIMCI WIDGETLARI
  // =====================================================

  /// Kompakt İkon
  Widget _buildCompactIcon(Device device, Color color) {
    IconData iconData;
    if (device.isControlModule) {
      iconData = Icons.account_tree;
    } else if (device.isProcessingModule) {
      iconData = Icons.memory;
    } else {
      iconData = Icons.devices;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        iconData,
        color: color,
        size: 24,
      ),
    );
  }

  /// Mini Badge (SOLD/RENT)
  Widget _buildMiniBadge(OwnershipStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: status == OwnershipStatus.sold
            ? Colors.green.shade100
            : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status == OwnershipStatus.sold ? 'SOLD' : 'RENT',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: status == OwnershipStatus.sold
              ? Colors.green.shade700
              : Colors.orange.shade700,
        ),
      ),
    );
  }

  Widget _buildSystemBadge({
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  /// Kompakt Aksiyon Butonları (Detay, Düzenle, Sil)
  Widget _buildCompactActionButtons(BuildContext context, Device device) {
    final isCompact = MediaQuery.sizeOf(context).width < 520;

    if (isCompact) {
      return PopupMenuButton<String>(
        tooltip: 'İşlemler',
        icon: Icon(Icons.more_vert, color: Colors.grey.shade700),
        onSelected: (value) {
          if (value == 'detail') {
            openDesktopAwareScreen(
              context,
              DeviceDetailScreen(device: device),
            );
          } else if (value == 'edit') {
            openDesktopAwareScreen(
              context,
              DeviceEditScreen(device: device),
            );
          } else if (value == 'delete') {
            _confirmDeleteDevice(context, device);
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'detail',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.visibility),
              title: Text('Detay'),
            ),
          ),
          PopupMenuItem(
            value: 'edit',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.edit),
              title: Text('Düzenle'),
            ),
          ),
          PopupMenuDivider(),
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Sil'),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.visibility, color: Colors.green.shade600, size: 20),
          onPressed: () {
            openDesktopAwareScreen(
              context,
              DeviceDetailScreen(device: device),
            );
          },
          tooltip: 'Detay',
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: const EdgeInsets.all(4),
        ),
        IconButton(
          icon: Icon(Icons.edit, color: Colors.blue.shade600, size: 20),
          onPressed: () {
            openDesktopAwareScreen(
              context,
              DeviceEditScreen(device: device),
            );
          },
          tooltip: 'Düzenle',
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: const EdgeInsets.all(4),
        ),
        IconButton(
          icon: Icon(Icons.delete, color: Colors.red.shade400, size: 20),
          onPressed: () {
            _confirmDeleteDevice(context, device);
          },
          tooltip: 'Sil',
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: const EdgeInsets.all(4),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteDevice(BuildContext context, Device device) async {
    final provider = context.read<DeviceProvider>();
    final linkedDevices = provider.linkedDevicesForDevice(device);
    final isProtectedControlUnit =
        device.isControlModule && linkedDevices.length > 1;

    if (isProtectedControlUnit) {
      final moduleCount = linkedDevices.length - 1;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bu kontrol unitesine bagli $moduleCount modul var. Once modulleri silin veya iliskiyi duzenleyin.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cihazi Sil'),
        content: Text(
          '"${device.name}" adli cihazi silmek istediginizden emin misiniz?',
        ),
        actions: [
          TextButton(
            child: const Text('Iptal'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            child: const Text('Sil'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final key = device.key;
    if (key is! int) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cihaz anahtari okunamadi, silme tamamlanamadi.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await provider.deleteDevice(key);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${device.name} silindi.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Mikro Aksiyon Butonları (Modüller için)
  Widget _buildMicroActionButtons(BuildContext context, Device device) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.visibility, color: Colors.green.shade600, size: 18),
          onPressed: () {
            openDesktopAwareScreen(
              context,
              DeviceDetailScreen(device: device),
            );
          },
          tooltip: 'Detay',
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          padding: const EdgeInsets.all(2),
        ),
        IconButton(
          icon: Icon(Icons.edit, color: Colors.blue.shade600, size: 18),
          onPressed: () {
            openDesktopAwareScreen(
              context,
              DeviceEditScreen(device: device),
            );
          },
          tooltip: 'Düzenle',
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          padding: const EdgeInsets.all(2),
        ),
      ],
    );
  }
}

enum _DeviceListViewMode { tree, list }
