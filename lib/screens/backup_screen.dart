import 'package:biomed_serv/services/auto_backup_service.dart';
import 'package:biomed_serv/services/backup_service.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:biomed_serv/services/storage_location_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _isLoading = false;
  List<BackupInfo> _backups = [];
  BackupService? _backupService;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  void _initializeService() {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    _backupService = BackupService(dbService);
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    if (_backupService == null) return;

    setState(() => _isLoading = true);
    try {
      final backups = await _backupService!.getBackupHistory();
      if (!mounted) return;
      setState(() => _backups = backups);
    } catch (e) {
      debugPrint('Yedekler yuklenirken hata: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yedekleme ve Geri Yukleme'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadBackups,
              tooltip: 'Yenile',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBackupSection(),
                  const SizedBox(height: 24),
                  _buildManagedAutoBackupSection(),
                  const SizedBox(height: 24),
                  _buildBackupHistorySection(),
                ],
              ),
            ),
    );
  }

  Widget _buildBackupSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Yedekleme',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Verilerinizi yedekleyin veya disa aktarin.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _createFullBackup,
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('Excel/CSV ZIP'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showSelectiveBackupDialog,
                    icon: const Icon(Icons.filter_list),
                    label: const Text('Secici Yedekle'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _restoreFromFile,
                icon: const Icon(Icons.restore),
                label: const Text('Yedekten Geri Yukle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagedAutoBackupSection() {
    return Consumer2<AutoBackupService, StorageLocationService>(
      builder: (context, autoBackup, storage, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Otomatik Yedekleme',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Otomatik yedekleme'),
                  subtitle: const Text(
                    'Excel + CSV icerikli ZIP yedegi arka planda olusturulur.',
                  ),
                  value: autoBackup.enabled,
                  onChanged: (value) async {
                    await autoBackup.setEnabled(value);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: const Text('Yedekleme araligi'),
                  subtitle: Text('Her ${autoBackup.intervalHours} saatte bir'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.folder_open),
                  title: const Text('Yedek klasoru'),
                  subtitle: Text(
                    storage.backupDirectory ?? 'Kurulumda secilen klasor',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: autoBackup.isRunning ? null : _createFullBackup,
                    icon: autoBackup.isRunning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_circle_outline),
                    label: Text(
                      autoBackup.isRunning
                          ? 'Yedek hazirlaniyor...'
                          : 'Simdi Excel/CSV ZIP Yedekle',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackupHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Yedekleme Gecmisi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: _loadBackups,
              icon: const Icon(Icons.refresh),
              label: const Text('Yenile'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_backups.isEmpty)
          _buildEmptyState(
            icon: Icons.folder_open_outlined,
            title: 'Henuz yedek yok',
            subtitle: 'Yedekleme butonuna dokunarak yeni bir yedek olusturun.',
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _backups.length,
            itemBuilder: (context, index) => _buildBackupCard(_backups[index]),
          ),
      ],
    );
  }

  Widget _buildBackupCard(BackupInfo backup) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: backup.type == 'full'
              ? Colors.blue.shade100
              : Colors.orange.shade100,
          child: Icon(
            backup.type == 'full' ? Icons.backup : Icons.filter_list,
            color: backup.type == 'full' ? Colors.blue : Colors.orange,
          ),
        ),
        title: Text(backup.fileName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(backup.formattedDate),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.storage, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(backup.formattedSize),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _onBackupMenuSelected(value, backup),
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.share, size: 20),
                  SizedBox(width: 8),
                  Text('Paylas'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'restore',
              child: Row(
                children: [
                  Icon(Icons.restore, size: 20, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Geri Yukle'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Sil'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
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

  Future<void> _createFullBackup() async {
    if (_backupService == null) return;

    final autoBackup = context.read<AutoBackupService>();
    setState(() => _isLoading = true);
    try {
      final result =
          await autoBackup.createNow(reason: 'Manuel Excel/CSV ZIP yedek');
      final path = result.path;
      await _loadBackups();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Yedek olusturuldu: $path'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Paylas',
            onPressed: () => _shareBackup(path),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Yedekleme hatasi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSelectiveBackupDialog() {
    final selectedBoxes = <String>{};
    final availableBoxes = [
      'customers',
      'devices',
      'service_forms',
      'maintenance_forms',
      'stocks',
      'expenses',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Secici Yedekleme'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: availableBoxes
                  .map(
                    (boxName) => CheckboxListTile(
                      title: Text(_formatBoxName(boxName)),
                      value: selectedBoxes.contains(boxName),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            selectedBoxes.add(boxName);
                          } else {
                            selectedBoxes.remove(boxName);
                          }
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Iptal'),
            ),
            ElevatedButton(
              onPressed: selectedBoxes.isEmpty
                  ? null
                  : () async {
                      Navigator.of(ctx).pop();
                      await _createSelectiveBackup(selectedBoxes.toList());
                    },
              child: const Text('Yedekle'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createSelectiveBackup(List<String> boxes) async {
    if (_backupService == null) return;

    setState(() => _isLoading = true);
    try {
      await _backupService!.createSelectiveBackup(boxNames: boxes);
      await _loadBackups();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Secici yedek olusturuldu'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Yedekleme hatasi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _restoreFromFile() async {
    if (_backupService == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Geri Yukleme Uyarisi'),
        content: const Text(
          'Yedekten geri yukleme, mevcut verileri siler ve yedekteki verilerle degistirir.\n\nDevam etmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Geri Yukle'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await _backupService!.restoreFromPicker();
      await _loadBackups();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veriler basariyla geri yuklendi'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Geri yukleme hatasi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _shareBackup(String path) async {
    try {
      await Share.shareXFiles(
        [XFile(path)],
        text: 'Biomed Servis Yedek Dosyasi',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paylasma hatasi: $e')),
      );
    }
  }

  Future<void> _onBackupMenuSelected(String value, BackupInfo backup) async {
    switch (value) {
      case 'share':
        await _shareBackup(backup.path);
        break;
      case 'restore':
        await _restoreSpecificBackup(backup.path);
        break;
      case 'delete':
        await _deleteBackup(backup);
        break;
    }
  }

  Future<void> _restoreSpecificBackup(String path) async {
    if (_backupService == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Geri Yukleme'),
        content: const Text('Bu yedekten geri yuklemek istiyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Geri Yukle'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await _backupService!.restoreFromBackup(path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Geri yukleme tamamlandi'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Geri yukleme hatasi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteBackup(BackupInfo backup) async {
    if (_backupService == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yedek Sil'),
        content: Text('${backup.fileName} dosyasini silmek istiyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _backupService!.deleteBackup(backup.path);
      await _loadBackups();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yedek silindi'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Silme hatasi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatBoxName(String name) {
    switch (name) {
      case 'customers':
        return 'Musteriler';
      case 'devices':
        return 'Cihazlar';
      case 'service_forms':
        return 'Servis Formlari';
      case 'maintenance_forms':
        return 'Bakim Formlari';
      case 'stocks':
        return 'Stoklar';
      case 'expenses':
        return 'Masraflar';
      default:
        return name;
    }
  }
}
