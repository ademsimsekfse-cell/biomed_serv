import 'dart:io';

import 'package:biomed_serv/providers/technician_provider.dart';
import 'package:biomed_serv/screens/api_settings_screen.dart';
import 'package:biomed_serv/services/lan_auto_sync_service.dart';
import 'package:biomed_serv/services/lan_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class MobileSyncScreen extends StatefulWidget {
  const MobileSyncScreen({super.key});

  @override
  State<MobileSyncScreen> createState() => _MobileSyncScreenState();
}

class _MobileSyncScreenState extends State<MobileSyncScreen> {
  final TextEditingController _hostController = TextEditingController();

  bool _busy = false;
  bool _hostSeeded = false;
  List<LanDiscoveredCenter> _discoveredCenters = [];
  String? _statusMessage;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isDesktop) return;
      context
          .read<LanAutoSyncService>()
          .triggerAutoSync(reason: 'Senkron ekranı açıldı');
    });
  }

  bool _hasSelectedOutboundData(LanAutoSyncService autoSync) {
    return autoSync.outboundProfile.values.any((value) => value);
  }

  String _formatSyncTime(DateTime value) {
    return DateFormat('dd.MM.yyyy HH:mm').format(value);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final autoSync = context.watch<LanAutoSyncService>();
    if (!_hostSeeded && autoSync.centerHost != null) {
      _hostController.text = autoSync.centerHost!;
      _hostSeeded = true;
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  Future<bool> _ensureLocalNetworkPermission() async {
    return true;
  }

  Future<void> _discoverCenters() async {
    final autoSync = context.read<LanAutoSyncService>();
    if (!await _ensureLocalNetworkPermission()) return;
    if (!mounted) return;
    setState(() {
      _busy = true;
      _statusMessage = 'Yerel ağda Desktop merkez aranıyor...';
    });

    try {
      final centers = await autoSync.discoverCenters();
      if (!mounted) return;
      setState(() {
        _discoveredCenters = centers;
        _statusMessage = centers.isEmpty
            ? 'Aynı yerel ağda aktif merkez bulunamadı.'
            : '${centers.length} merkez bulundu. Bağlanmak istediğiniz merkezi seçin.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Merkez taramasi basarisiz: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _selectCenter(LanDiscoveredCenter center) {
    setState(() {
      _hostController.text = center.host;
      _statusMessage =
          '${center.deviceName} merkezi secildi. Once eslestirme istegi gönderelim.';
    });
  }

  Future<void> _connectToCenter(LanDiscoveredCenter center) async {
    _selectCenter(center);
    final approved = await _requestPairing();
    if (approved && mounted) {
      await _sendNow();
    }
  }

  Future<bool> _requestPairing() async {
    final autoSync = context.read<LanAutoSyncService>();
    final technicianProvider = context.read<TechnicianProvider>();
    if (!technicianProvider.hasTechnician) {
      setState(() {
        _statusMessage =
            'Senkron icin once teknisyen kurulumunu tamamlamalisin.';
      });
      return false;
    }
    if (!await _ensureLocalNetworkPermission()) return false;

    setState(() {
      _busy = true;
      _statusMessage = null;
    });

    try {
      var host = _hostController.text.trim();
      if (host.isEmpty) host = autoSync.centerHost ?? '';

      var reachable = false;
      if (host.isNotEmpty) {
        await autoSync.setCenterHost(host);
        reachable = await autoSync.verifyCenterConnection();
      }
      if (!reachable) {
        final center = await autoSync.discoverAndConfigureCenter(force: true);
        host = center?.host ?? '';
        if (center != null) _hostController.text = center.host;
      }
      if (host.isEmpty) {
        if (!mounted) return false;
        setState(() {
          _statusMessage =
              'Desktop merkez bulunamadı. Aynı Wi-Fi ağını ve Windows güvenlik duvarını kontrol edin.';
        });
        return false;
      }

      final approved = await autoSync.requestCenterAccess(host);
      if (!mounted) return false;
      setState(() {
        _statusMessage = approved
            ? 'Merkez bu cihazi tanidi. Artik veri gönderebilirsin.'
            : autoSync.lastMessage ??
                'Eslestirme istegi gönderildi. Desktop onayi bekleniyor.';
      });
      return approved;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _sendNow() async {
    final autoSync = context.read<LanAutoSyncService>();
    final technicianProvider = context.read<TechnicianProvider>();
    if (!technicianProvider.hasTechnician) {
      setState(() {
        _statusMessage =
            'Veri göndermeden önce teknisyen kurulumunu tamamlamalısınız.';
      });
      return;
    }
    if (!await _ensureLocalNetworkPermission()) return;
    if (!_hasSelectedOutboundData(autoSync)) {
      setState(() {
        _statusMessage =
            'Gönderim profili boş. En az bir veri tipi seçmelisiniz.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _statusMessage = null;
    });

    try {
      var host = _hostController.text.trim();
      if (host.isEmpty) host = autoSync.centerHost ?? '';

      var reachable = false;
      if (host.isNotEmpty) {
        await autoSync.setCenterHost(host);
        reachable = await autoSync.verifyCenterConnection();
      }
      if (!reachable) {
        final center = await autoSync.discoverAndConfigureCenter(force: true);
        host = center?.host ?? '';
        if (center != null) _hostController.text = center.host;
      }
      if (host.isEmpty) {
        if (!mounted) return;
        setState(() {
          _statusMessage =
              'Desktop merkez bulunamadı. Aynı Wi-Fi ağını ve Windows güvenlik duvarını kontrol edin.';
        });
        return;
      }

      await autoSync.setCenterHost(host);
      final result = await autoSync.syncNow(reason: 'Manuel gönderim');
      if (!mounted) return;
      setState(() {
        _statusMessage = result == null
            ? autoSync.lastMessage ?? 'Veri aktarımı tamamlanamadı.'
            : _resultHeadline(result);
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _syncRemoteNow() async {
    final autoSync = context.read<LanAutoSyncService>();
    final technicianProvider = context.read<TechnicianProvider>();
    if (!technicianProvider.hasTechnician) {
      setState(() {
        _statusMessage =
            'Uzak senkron için önce teknisyen kurulumunu tamamlayın.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      final result =
          await autoSync.syncRemoteNow(reason: 'Manuel uzak senkron');
      if (!mounted) return;
      setState(() {
        _statusMessage = result == null
            ? autoSync.lastMessage ?? 'Uzak senkron tamamlanamadı.'
            : _resultHeadline(result);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final autoSync = context.watch<LanAutoSyncService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isDesktop ? 'Mobil Bağlanti Testi' : 'Merkeze Bağlan'),
        backgroundColor: const Color(0xFF1565C0),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSyncOverviewCard(autoSync),
          const SizedBox(height: 12),
          _buildConnectionCard(autoSync),
          const SizedBox(height: 12),
          _buildOutboundProfileCard(autoSync),
          if (_statusMessage != null) ...[
            const SizedBox(height: 16),
            _buildStatusCard(_statusMessage!),
          ],
          if (autoSync.lastMessage != null) ...[
            const SizedBox(height: 16),
            if (autoSync.lastMessage != _statusMessage)
              _buildStatusCard(autoSync.lastMessage!),
          ],
          if (autoSync.lastResult != null) ...[
            const SizedBox(height: 16),
            _buildResultCard(autoSync.lastResult!),
          ],
        ],
      ),
    );
  }

  Widget _buildSyncOverviewCard(LanAutoSyncService autoSync) {
    final technicianReady = context.watch<TechnicianProvider>().hasTechnician;
    final connected =
        autoSync.isCenterReachable && autoSync.centerAccessApproved == true;
    final waitingApproval =
        autoSync.isCenterReachable && autoSync.centerAccessApproved == false;
    final selectedCount =
        autoSync.outboundProfile.values.where((value) => value).length;
    final statusColor = connected
        ? const Color(0xFF2E7D32)
        : waitingApproval
            ? const Color(0xFFB26A00)
            : const Color(0xFF546E7A);
    final statusTitle = autoSync.isSyncing
        ? 'Senkronizasyon sürüyor'
        : connected
            ? 'Merkeze bağlı'
            : waitingApproval
                ? 'Desktop onayı bekleniyor'
                : autoSync.isDiscovering
                    ? 'Yerel ağ taranıyor'
                    : 'Merkez bekleniyor';
    final statusSubtitle = connected
        ? 'Desktop verileri bu cihaza, mobil veriler merkeze aktarılabilir.'
        : waitingApproval
            ? 'Desktop ekranda gelen bağlantı isteğini onaylayın.'
            : 'Aynı Wi-Fi ağına girince otomatik arama yapılır.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  autoSync.isSyncing
                      ? Icons.sync
                      : connected
                          ? Icons.cloud_done_outlined
                          : waitingApproval
                              ? Icons.approval_outlined
                              : Icons.wifi_tethering,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusSubtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blueGrey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildOverviewChip(
                icon: Icons.badge_outlined,
                label: technicianReady ? 'Teknisyen hazır' : 'Teknisyen eksik',
                ok: technicianReady,
              ),
              _buildOverviewChip(
                icon: Icons.router_outlined,
                label: autoSync.centerHost == null
                    ? 'Merkez yok'
                    : '${autoSync.centerHost}:${autoSync.localApiPort}',
                ok: autoSync.centerHost != null,
              ),
              _buildOverviewChip(
                icon: autoSync.autoSyncEnabled
                    ? Icons.autorenew
                    : Icons.pause_circle_outline,
                label: autoSync.autoSyncEnabled
                    ? 'Otomatik açık'
                    : 'Otomatik kapalı',
                ok: autoSync.autoSyncEnabled,
              ),
              _buildOverviewChip(
                icon: Icons.upload_file_outlined,
                label: '$selectedCount veri tipi',
                ok: selectedCount > 0,
              ),
              if (autoSync.lastSyncAt != null)
                _buildOverviewChip(
                  icon: Icons.history,
                  label:
                      'Son: ${DateFormat('dd.MM HH:mm').format(autoSync.lastSyncAt!)}',
                  ok: true,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewChip({
    required IconData icon,
    required String label,
    required bool ok,
  }) {
    final color = ok ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard(LanAutoSyncService autoSync) {
    final isConnected =
        autoSync.isCenterReachable && autoSync.centerAccessApproved == true;
    final isPending =
        autoSync.isCenterReachable && autoSync.centerAccessApproved != true;
    final statusColor = isConnected
        ? Colors.green
        : isPending
            ? Colors.orange
            : Colors.blueGrey;
    final statusText = autoSync.isSyncing
        ? 'Merkez ile veri aktarımı devam ediyor...'
        : isConnected
            ? 'Merkeze bağlı. Veri aktarımı hazır.'
            : isPending
                ? 'Merkez bulundu. Desktop bağlantı onayı bekleniyor.'
                : autoSync.centerHost == null
                    ? 'Henüz bir Desktop merkeze bağlı değilsiniz.'
                    : 'Kayıtlı merkez var ancak bağlantı doğrulanamadı.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(
              icon: Icons.wifi_tethering,
              title: 'Merkez Bağlantısı',
              subtitle:
                  'Aynı ağdaki Desktop merkez otomatik bulunur ve veri aktarımı güvenli onayla başlar.',
              color: const Color(0xFF1565C0),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    autoSync.isSyncing
                        ? Icons.sync
                        : isConnected
                            ? Icons.cloud_done_outlined
                            : isPending
                                ? Icons.approval_outlined
                                : Icons.cloud_off_outlined,
                    color: statusColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isConnected ? 'Merkeze Bağlandı' : 'Merkez Durumu',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(statusText, style: const TextStyle(fontSize: 12)),
                        if (autoSync.centerHost != null)
                          Text(
                            '${autoSync.centerHost}:${autoSync.localApiPort}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blueGrey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _requestPairing,
                  icon: const Icon(Icons.link),
                  label: Text(
                    isConnected ? 'Bağlantıyı Yenile' : 'Merkeze Bağlan',
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _sendNow,
                  icon: const Icon(Icons.sync),
                  label: const Text('Senkronize Et'),
                ),
                if (autoSync.remoteGatewayEnabled)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _syncRemoteNow,
                    icon: const Icon(Icons.cloud_sync_outlined),
                    label: const Text('Uzak Senkron'),
                  ),
              ],
            ),
            if (_discoveredCenters.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildDiscoveredCentersCard(),
            ],
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: autoSync.autoSyncEnabled,
              onChanged: _busy ? null : autoSync.setAutoSyncEnabled,
              title: const Text('Aynı ağda otomatik senkronizasyon'),
              subtitle: Text(
                autoSync.lastSyncAt == null
                    ? 'Merkez bulunduğunda onay ve veri aktarımı kendiliğinden başlar.'
                    : 'Son senkron: ${_formatSyncTime(autoSync.lastSyncAt!)}',
              ),
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Gelişmiş bağlantı seçenekleri'),
              subtitle: const Text('Otomatik bulma çalışmazsa manuel bağlantı'),
              children: [
                TextField(
                  controller: _hostController,
                  decoration: const InputDecoration(
                    labelText: 'Merkez IP adresi',
                    hintText: 'Örn. 192.168.1.25',
                    prefixIcon: Icon(Icons.router),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _discoverCenters,
                      icon: const Icon(Icons.travel_explore),
                      label: const Text('Ağı Tara'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _busy ? null : _requestPairing,
                      icon: const Icon(Icons.link),
                      label: const Text('Eşleştirme İsteği'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ApiSettingsScreen(),
                                ),
                              );
                              if (context.mounted) {
                                await autoSync.reloadRemoteSettings();
                              }
                            },
                      icon: const Icon(Icons.cloud_outlined),
                      label: const Text('Uzak Merkez Ayarları'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutboundProfileCard(LanAutoSyncService autoSync) {
    final options = [
      (
        LanSyncService.sendDevicesKey,
        'Yeni cihazlari gönder',
        'Mobilde acilan yeni cihaz kayitlari merkeze aktarilsin.',
      ),
      (
        LanSyncService.sendServiceFormsKey,
        'Servis formlarini gönder',
        'Cihaza yapilan islemler merkezde servis gecmisine eklensin.',
      ),
      (
        LanSyncService.sendMaintenanceFormsKey,
        'Bakım formlarini gönder',
        'Bakım kayitlari merkezde cihaz yasamina eklensin.',
      ),
      (
        LanSyncService.sendFaultTicketsKey,
        'Ariza aksiyonlarini gönder',
        'Mobilde acilan veya guncellenen ariza aksiyonlari merkeze aksin.',
      ),
      (
        LanSyncService.sendExpensesKey,
        'Masraf ve raporlari gönder',
        'Masraf formlari teknisyen bazli hiyerarsi ile merkeze ulassin.',
      ),
      (
        LanSyncService.sendStocksKey,
        'Stok kartlarini gönder',
        'Mobilde tanimli stok kartlari merkezde de gorunsun.',
      ),
    ];
    final selectedOptions = options
        .where((option) => autoSync.outboundProfile[option.$1] ?? true)
        .map((option) => option.$2)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(
              icon: Icons.tune,
              title: 'Gönderim Profili',
              subtitle:
                  'Bu cihazdan merkeze hangi veri tiplerinin gidecegini sen belirlersin.',
              color: const Color(0xFF0F766E),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF0F766E).withValues(alpha: 0.14),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    selectedOptions.isEmpty
                        ? Icons.warning_amber_outlined
                        : Icons.inventory_2_outlined,
                    color:
                        selectedOptions.isEmpty ? Colors.orange : Colors.teal,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selectedOptions.isEmpty
                          ? 'Şu an merkeze gidecek veri tipi secili degil.'
                          : 'Gönderilecek: ${selectedOptions.join(', ')}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...options.map(
              (option) => SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: autoSync.outboundProfile[option.$1] ?? true,
                onChanged: (value) =>
                    autoSync.setOutboundProfileOption(option.$1, value),
                title: Text(option.$2),
                subtitle: Text(option.$3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoveredCentersCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.radar, color: Colors.indigo),
              SizedBox(width: 8),
              Text(
                'Bulunan Merkezler',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.indigo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._discoveredCenters.map(
            (center) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.shade100),
              ),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                leading: const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFFE8EAF6),
                  child: Icon(Icons.desktop_windows, color: Colors.indigo),
                ),
                title: Text(
                  center.deviceName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${center.host}:${center.port}\n'
                  '${center.appName}'
                  '${center.macAddress == null ? '' : ' • ${center.macAddress}'}',
                ),
                trailing: FilledButton.tonal(
                  onPressed: _busy ? null : () => _connectToCenter(center),
                  child: const Text('Bağlan'),
                ),
                onTap: _busy ? null : () => _connectToCenter(center),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String message) {
    final lower = message.toLowerCase();
    final isError = lower.contains('basarisiz') ||
        lower.contains('hatasi') ||
        lower.contains('gerekli');
    final isPending =
        lower.contains('bekleniyor') || lower.contains('gönderildi');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline
                  : isPending
                      ? Icons.hourglass_top
                      : Icons.check_circle_outline,
              color: isError
                  ? Colors.red
                  : isPending
                      ? Colors.orange
                      : Colors.green,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(LanSyncResult result) {
    final tone = _syncResultTone(result);
    final items = [
      ('Eklenen', result.totalAdded, Colors.green),
      ('Güncellenen', result.recordsUpdated, Colors.blue),
      ('Atlanan', result.skipped, Colors.orange),
      ('Cihaz', result.devicesAdded, Colors.blue),
      ('Servis', result.serviceFormsAdded, Colors.indigo),
      ('Bakım', result.maintenanceFormsAdded, Colors.teal),
      ('Masraf', result.expensesAdded + result.expenseReportsAdded, Colors.red),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(
              icon: tone.$1,
              title: 'Son Veri Ozeti',
              subtitle: _resultHeadline(result),
              color: tone.$2,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tone.$2.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tone.$2.withValues(alpha: 0.14)),
              ),
              child: Row(
                children: [
                  Icon(tone.$1, color: tone.$2),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _resultActionText(result),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: items
                  .map(
                    (item) => Chip(
                      avatar: CircleAvatar(
                        backgroundColor: item.$3.withValues(alpha: 0.14),
                        child: Text(
                          item.$2.toString(),
                          style: TextStyle(
                            color: item.$3,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      label: Text(item.$1),
                    ),
                  )
                  .toList(),
            ),
            if (result.warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Dikkat gerektirenler',
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              ...result.warnings.take(4).map(
                    (warning) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '- $warning',
                        style: TextStyle(color: Colors.orange.shade900),
                      ),
                    ),
                  ),
              if (result.warnings.length > 4)
                Text(
                  '+${result.warnings.length - 4} uyari daha var.',
                  style: TextStyle(color: Colors.orange.shade900),
                ),
            ],
          ],
        ),
      ),
    );
  }

  (IconData, Color) _syncResultTone(LanSyncResult result) {
    if (result.warnings.isNotEmpty) {
      return (Icons.warning_amber_outlined, Colors.orange);
    }
    if (result.totalAdded > 0 || result.recordsUpdated > 0) {
      return (Icons.check_circle_outline, Colors.green);
    }
    return (Icons.info_outline, Colors.blueGrey);
  }

  String _resultHeadline(LanSyncResult result) {
    if (result.totalAdded == 0 &&
        result.recordsUpdated == 0 &&
        result.skipped == 0) {
      return 'Senkron tamamlandi, aktarilacak yeni kayit bulunmadi.';
    }
    final parts = <String>[];
    if (result.totalAdded > 0) {
      parts.add('${result.totalAdded} kayit eklendi');
    }
    if (result.recordsUpdated > 0) {
      parts.add('${result.recordsUpdated} kayıt güncellendi');
    }
    if (result.skipped > 0) {
      parts.add('${result.skipped} kayit zaten vardi/atlandi');
    }
    if (result.warnings.isNotEmpty) {
      parts.add('${result.warnings.length} uyari var');
    }
    return 'Senkron tamamlandi: ${parts.join(', ')}.';
  }

  String _resultActionText(LanSyncResult result) {
    if (result.warnings.isNotEmpty) {
      return 'Aktarim tamamlandi ama asagidaki uyarilari kontrol etmek iyi olur.';
    }
    if (result.totalAdded > 0 || result.recordsUpdated > 0) {
      return 'Merkez ve mobil verileri birleştirildi. Yeni ve güncellenen kayıtlar ilgili ekranlarda görünür.';
    }
    if (result.skipped > 0) {
      return 'Yeni kayit eklenmedi; ayni kayitlar tekrar gönderilmemis oldu.';
    }
    return 'Her sey guncel gorunuyor.';
  }

  Widget _buildCardHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
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
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
