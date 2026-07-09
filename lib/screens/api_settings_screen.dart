import 'dart:io';

import 'package:biomed_serv/services/lan_auto_sync_service.dart';
import 'package:biomed_serv/services/lan_sync_service.dart';
import 'package:biomed_serv/services/remote_gateway_service.dart';
import 'package:biomed_serv/services/windows_firewall_service.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

class ApiSettingsScreen extends StatefulWidget {
  const ApiSettingsScreen({super.key});

  @override
  State<ApiSettingsScreen> createState() => _ApiSettingsScreenState();
}

class _ApiSettingsScreenState extends State<ApiSettingsScreen> {
  static const _boxName = 'app_preferences';
  static const _apiEnabledKey = 'api_enabled';
  static const _apiBaseUrlKey = 'api_base_url';
  static const _apiKeyKey = 'api_key';
  static const _apiTimeoutKey = 'api_timeout_seconds';
  static const _apiAutoRetryKey = 'api_auto_retry';

  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _siteCodeController = TextEditingController();
  final _timeoutController = TextEditingController(text: '30');

  bool _enabled = false;
  bool _autoRetry = true;
  bool _loading = true;
  bool _busy = false;
  bool _firewallBusy = false;
  List<String> _localIps = [];
  WindowsFirewallStatus? _firewallStatus;
  RemoteGatewayHealth? _remoteHealth;
  RemoteTransportMode _transportMode = RemoteTransportMode.localPreferred;
  final WindowsFirewallService _firewallService = WindowsFirewallService();
  final RemoteGatewayService _remoteGatewayService = RemoteGatewayService();

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLocalIps();
      _refreshFirewallStatus();
    });
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _siteCodeController.dispose();
    _timeoutController.dispose();
    _remoteGatewayService.close();
    super.dispose();
  }

  Future<void> _load() async {
    final box = await Hive.openBox(_boxName);
    if (!mounted) return;
    setState(() {
      _enabled = box.get(_apiEnabledKey) as bool? ?? false;
      _baseUrlController.text = box.get(_apiBaseUrlKey) as String? ?? '';
      _apiKeyController.text = box.get(_apiKeyKey) as String? ?? '';
      _siteCodeController.text =
          box.get(RemoteGatewayService.siteCodeKey) as String? ?? '';
      final modeName =
          box.get(RemoteGatewayService.transportModeKey) as String?;
      _transportMode = RemoteTransportMode.values.firstWhere(
        (mode) => mode.name == modeName,
        orElse: () => RemoteTransportMode.localPreferred,
      );
      _timeoutController.text =
          (box.get(_apiTimeoutKey) as int? ?? 30).toString();
      _autoRetry = box.get(_apiAutoRetryKey) as bool? ?? true;
      _loading = false;
    });
  }

  Future<void> _loadLocalIps() async {
    final ips = await context.read<LanAutoSyncService>().localIpv4Addresses();
    if (!mounted) return;
    setState(() => _localIps = ips);
  }

  Future<void> _retryLocalApi(LanAutoSyncService localApi) async {
    setState(() => _busy = true);
    try {
      await localApi.startCenterListening();
      await _loadLocalIps();
      await _refreshFirewallStatus();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshFirewallStatus() async {
    if (!_isDesktop) return;
    if (mounted) setState(() => _firewallBusy = true);
    final status = await _firewallService.inspect();
    if (!mounted) return;
    setState(() {
      _firewallStatus = status;
      _firewallBusy = false;
    });
  }

  Future<void> _configureFirewall() async {
    setState(() => _firewallBusy = true);
    final configured = await _firewallService.configureWithElevation();
    final status = await _firewallService.inspect();
    if (!mounted) return;
    setState(() {
      _firewallStatus = status;
      _firewallBusy = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          configured && status.tcpRuleEnabled && status.udpRuleEnabled
              ? 'Windows Güvenlik Duvarı izinleri hazır.'
              : 'İzin eklenemedi. Yönetici onayını veya manuel komutları kontrol edin.',
        ),
        backgroundColor: configured ? Colors.green : Colors.orange.shade800,
      ),
    );
  }

  Future<void> _save() async {
    final remoteSettings = _currentRemoteSettings();
    if (_enabled) {
      final validation = _remoteGatewayService.validateSettings(
        remoteSettings,
        requireCenterToken: _isDesktop,
      );
      if (validation != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(validation), backgroundColor: Colors.orange),
        );
        return;
      }
    }

    final box = await Hive.openBox(_boxName);
    final timeout = int.tryParse(_timeoutController.text.trim()) ?? 30;
    await box.put(_apiEnabledKey, _enabled);
    await box.put(_apiBaseUrlKey, _baseUrlController.text.trim());
    await box.put(_apiKeyKey, _apiKeyController.text.trim());
    await box.put(_apiTimeoutKey, timeout);
    await box.put(_apiAutoRetryKey, _autoRetry);
    await _remoteGatewayService.saveSettings(remoteSettings);
    if (!mounted) return;
    await context.read<LanAutoSyncService>().reloadRemoteSettings();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bağlantı ayarları kaydedildi'),
        backgroundColor: Colors.green,
      ),
    );
  }

  RemoteGatewaySettings _currentRemoteSettings() {
    return RemoteGatewaySettings(
      enabled: _enabled,
      baseUrl: _baseUrlController.text.trim(),
      centerToken: _apiKeyController.text.trim(),
      siteCode: _siteCodeController.text.trim(),
      mode: _transportMode,
    );
  }

  Future<void> _testRemoteGateway() async {
    setState(() {
      _busy = true;
      _remoteHealth = null;
    });
    final health = await _remoteGatewayService.testConnection(
      _currentRemoteSettings(),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _remoteHealth = health;
    });
  }

  Future<void> _resetMobilePairing() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Uzak eşleşme sıfırlansın mı?'),
        content: const Text(
          'Bu cihazın uzak merkez anahtarı silinir. Sonraki bağlantıda Desktop merkezden yeniden onay gerekir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sıfırla'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<LanAutoSyncService>().resetRemotePairing();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Uzak merkez eşleşmesi sıfırlandı.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localApi = context.watch<LanAutoSyncService>();

    if (!_isDesktop) {
      return Scaffold(
        appBar: AppBar(title: const Text('Uzak Merkez Ayarları')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [_buildWebApiCard()],
              ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entegrasyon Ayarları'),
        backgroundColor: const Color(0xFF1565C0),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHero(localApi),
                const SizedBox(height: 16),
                _buildLocalApiCard(localApi),
                const SizedBox(height: 16),
                _buildFirewallCard(),
                const SizedBox(height: 16),
                _buildWebApiCard(),
              ],
            ),
    );
  }

  Widget _buildHero(LanAutoSyncService localApi) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.api, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Local API Merkezi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  localApi.isListening
                      ? 'Bu cihaz yerel agda veri alisverisine hazir.'
                      : 'Desktop acildiginda local API otomatik baslatilabilir.',
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.3,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalApiCard(LanAutoSyncService localApi) {
    final port = localApi.localApiPort;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(
              icon: Icons.lan,
              title: 'Local API',
              subtitle:
                  'Mobil cihazlar ayni yerel agdayken bu API uzerinden desktop merkeze baglanir.',
              color: const Color(0xFF0F766E),
            ),
            const SizedBox(height: 14),
            _buildStatusStrip(localApi),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _busy || localApi.isListening
                      ? null
                      : () => _retryLocalApi(localApi),
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    localApi.isListening
                        ? 'Merkez Otomatik Çalışıyor'
                        : 'Yeniden Dene',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _loadLocalIps,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Adresleri Yenile'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.autorenew),
              title: Text('Otomatik merkez servisi'),
              subtitle: Text(
                'Desktop açıldığında başlar ve ağ değişikliklerinde kendini yeniden hazırlar.',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Port: $port',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (_localIps.isEmpty)
              Text(
                'Yerel IP bulunamadi. Ag baglantisini kontrol edin.',
                style: TextStyle(color: Colors.orange.shade800),
              )
            else
              ..._localIps.map(
                (ip) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: SelectableText(
                    'http://$ip:$port/health',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Senkron endpointleri: /api/access-request ve /api/sync',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusStrip(LanAutoSyncService localApi) {
    final color = localApi.isListening ? Colors.green : Colors.orange;
    final text =
        localApi.isListening ? 'Local API calisiyor' : 'Local API su an kapali';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade100),
      ),
      child: Row(
        children: [
          Icon(
            localApi.isListening ? Icons.check_circle : Icons.info_outline,
            color: color.shade700,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color.shade900,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirewallCard() {
    final status = _firewallStatus;
    final ready = status?.isReady == true;

    Widget statusChip({
      required String label,
      required bool ok,
      required IconData icon,
    }) {
      final color = ok ? Colors.green : Colors.orange;
      return Chip(
        avatar: Icon(icon, size: 17, color: color.shade700),
        label: Text(label),
        backgroundColor: color.shade50,
        side: BorderSide(color: color.shade100),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(
              icon: Icons.security_outlined,
              title: 'Windows Ağ İzinleri',
              subtitle:
                  'Yerel API ve otomatik merkez keşfi yalnızca yerel alt ağdan erişilebilir.',
              color: ready ? Colors.green : Colors.orange,
            ),
            const SizedBox(height: 14),
            if (_firewallBusy && status == null)
              const LinearProgressIndicator()
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  statusChip(
                    label: 'API ${LanSyncService.defaultPort}/TCP',
                    ok: status?.tcpRuleEnabled == true,
                    icon: Icons.lan_outlined,
                  ),
                  statusChip(
                    label: 'Keşif ${LanSyncService.discoveryPort}/UDP',
                    ok: status?.udpRuleEnabled == true,
                    icon: Icons.radar,
                  ),
                  statusChip(
                    label: 'Local API yanıtı',
                    ok: status?.localApiResponding == true,
                    icon: Icons.health_and_safety_outlined,
                  ),
                ],
              ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _firewallBusy ? null : _configureFirewall,
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: const Text('Firewall İzni Ver'),
                ),
                OutlinedButton.icon(
                  onPressed: _firewallBusy ? null : _refreshFirewallStatus,
                  icon: const Icon(Icons.network_check),
                  label: const Text('Bağlantıyı Test Et'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Manuel firewall komutları'),
              subtitle: const Text(
                'Otomatik yönetici onayı kullanılamazsa Komut İstemi’nde çalıştırın.',
              ),
              children: [
                SelectableText(
                  'netsh advfirewall firewall add rule '
                  'name="${WindowsFirewallService.tcpRuleName}" '
                  'dir=in action=allow protocol=TCP '
                  'localport=${LanSyncService.defaultPort} '
                  'remoteip=localsubnet profile=any '
                  'program="${Platform.resolvedExecutable}" enable=yes',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 10),
                SelectableText(
                  'netsh advfirewall firewall add rule '
                  'name="${WindowsFirewallService.udpRuleName}" '
                  'dir=in action=allow protocol=UDP '
                  'localport=${LanSyncService.discoveryPort} '
                  'remoteip=localsubnet profile=any '
                  'program="${Platform.resolvedExecutable}" enable=yes',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebApiCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Uzak Biomed Gateway'),
              subtitle: const Text(
                'Yerel ağ dışında Desktop merkez ile mobil cihazlar arasında güvenli mesaj kuyruğu.',
              ),
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blueGrey.withValues(alpha: 0.16),
                ),
              ),
              child: const Text(
                'FTP yalnızca gateway dosyalarını sunucuya yükler. Hosting hesabında PHP 8.1, PDO SQLite ve HTTPS desteği bulunmalıdır.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _baseUrlController,
              enabled: _enabled,
              decoration: const InputDecoration(
                labelText: 'Gateway URL',
                hintText: 'https://servis.firmaniz.com/biomed',
                prefixIcon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _siteCodeController,
              enabled: _enabled,
              decoration: const InputDecoration(
                labelText: 'Kurum / Site Kodu',
                prefixIcon: Icon(Icons.apartment_outlined),
              ),
            ),
            if (_isDesktop) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _apiKeyController,
                enabled: _enabled,
                decoration: const InputDecoration(
                  labelText: 'Desktop Merkez Anahtarı',
                  helperText: 'Bu anahtar mobil cihazlara verilmez.',
                  prefixIcon: Icon(Icons.key),
                ),
                obscureText: true,
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<RemoteTransportMode>(
              initialValue: _transportMode,
              decoration: const InputDecoration(
                labelText: 'Bağlantı Önceliği',
                prefixIcon: Icon(Icons.route_outlined),
              ),
              items: const [
                DropdownMenuItem(
                  value: RemoteTransportMode.localPreferred,
                  child: Text('Önce yerel ağ, olmazsa uzak merkez'),
                ),
                DropdownMenuItem(
                  value: RemoteTransportMode.localOnly,
                  child: Text('Yalnızca yerel ağ'),
                ),
                DropdownMenuItem(
                  value: RemoteTransportMode.remoteOnly,
                  child: Text('Yalnızca uzak merkez'),
                ),
              ],
              onChanged: _enabled
                  ? (value) {
                      if (value != null) {
                        setState(() => _transportMode = value);
                      }
                    }
                  : null,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _timeoutController,
              enabled: _enabled,
              decoration: const InputDecoration(
                labelText: 'Zaman Asimi',
                suffixText: 'sn',
                prefixIcon: Icon(Icons.timer),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hata halinde tekrar dene'),
              value: _autoRetry,
              onChanged: _enabled
                  ? (value) => setState(() => _autoRetry = value)
                  : null,
            ),
            if (_remoteHealth != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _remoteHealth!.ok
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _remoteHealth!.ok
                          ? Icons.cloud_done_outlined
                          : Icons.cloud_off_outlined,
                      color: _remoteHealth!.ok
                          ? Colors.green.shade700
                          : Colors.orange.shade800,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_remoteHealth!.message)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: !_enabled || _busy ? null : _testRemoteGateway,
                  icon: const Icon(Icons.network_check),
                  label: const Text('Gateway’i Test Et'),
                ),
                FilledButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Ayarları Kaydet'),
                ),
                if (!_isDesktop)
                  TextButton.icon(
                    onPressed: _busy ? null : _resetMobilePairing,
                    icon: const Icon(Icons.link_off),
                    label: const Text('Eşleşmeyi Sıfırla'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
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
