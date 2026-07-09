import 'package:biomed_serv/providers/customer_provider.dart';
import 'package:biomed_serv/providers/device_provider.dart';
import 'package:biomed_serv/services/excel_transfer_service.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

class ExcelTransferScreen extends StatefulWidget {
  const ExcelTransferScreen({super.key});

  @override
  State<ExcelTransferScreen> createState() => _ExcelTransferScreenState();
}

class _ExcelTransferScreenState extends State<ExcelTransferScreen> {
  static const Color _primaryColor = Color(0xFF274C77);
  static const Color _accentColor = Color(0xFF2A9D8F);
  static const Color _surfaceColor = Color(0xFFF6F8FB);

  final _service = ExcelTransferService();
  bool _isBusy = false;
  String? _lastExportPath;
  ExcelImportResult? _lastImportResult;

  @override
  Widget build(BuildContext context) {
    final customers = context.watch<CustomerProvider>().customers;
    final devices = context.watch<DeviceProvider>().devices;

    return Scaffold(
      backgroundColor: _surfaceColor,
      appBar: AppBar(
        title: const Text('Excel Aktarım Merkezi'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHero(customers.length, devices.length),
                  const SizedBox(height: 16),
                  _buildFormatCard(),
                  const SizedBox(height: 16),
                  _buildActionGrid(),
                  if (_isBusy) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                  if (_lastExportPath != null) ...[
                    const SizedBox(height: 16),
                    _buildExportResult(_lastExportPath!),
                  ],
                  if (_lastImportResult != null) ...[
                    const SizedBox(height: 16),
                    _buildImportResult(_lastImportResult!),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(int customerCount, int deviceCount) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: const Icon(Icons.table_chart, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cihaz ve Cari Excel Aktarımı',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$customerCount müşteri/cari • $deviceCount cihaz kayıtlı',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
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

  Widget _buildFormatCard() {
    return _buildSectionCard(
      icon: Icons.schema_outlined,
      title: 'Dosya Yapisi',
      subtitle:
          'Disa aktarimda hiyerarsik tam dosya veya sade cihaz listesi secilebilir.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoLine(
            icon: Icons.business,
            text:
                'Musteriler: ad, adres, telefon, yetkili, e-posta, vergi no ve birim sorumlulari.',
          ),
          const SizedBox(height: 8),
          _buildInfoLine(
            icon: Icons.devices,
            text:
                'Hiyerarsik aktarim: cihaz, cari, kontrol unitesi, bagli modul sayisi ve baglanti sayfasini korur.',
          ),
          const SizedBox(height: 8),
          _buildInfoLine(
            icon: Icons.sync_alt,
            text:
                'Basit cihaz import: sadece cihaz adi ve seri numarasi ile toplu kayit acar veya mevcut cihaz adini gunceller.',
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildFormatCardLegacy() {
    return _buildSectionCard(
      icon: Icons.schema_outlined,
      title: 'Dosya Yapısı',
      subtitle:
          'Dışa aktarılan dosyada Musteriler ve Cihazlar adlı iki ayrı sayfa bulunur.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoLine(
            icon: Icons.business,
            text:
                'Müşteriler: ad, adres, telefon, yetkili, e-posta, vergi no ve birim sorumluları.',
          ),
          const SizedBox(height: 8),
          _buildInfoLine(
            icon: Icons.devices,
            text:
                'Cihazlar: ad, marka, model, seri no, müşteri adı, modül tipi, sahiplik, garanti, lokasyon ve kategori.',
          ),
          const SizedBox(height: 8),
          _buildInfoLine(
            icon: Icons.sync_alt,
            text:
                'Import sırasında müşteriler ada göre, cihazlar seri numarasına göre güncellenir; yoksa yeni kayıt açılır.',
          ),
        ],
      ),
    );
  }

  Widget _buildActionGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        final cards = [
          _buildActionCard(
            icon: Icons.file_download_outlined,
            title: 'Excel Disa Aktar',
            subtitle:
                'Hiyerarsik tam dosya veya sadece cihaz adi/seri no listesi olustur.',
            color: _accentColor,
            onTap: _isBusy ? null : _exportExcel,
          ),
          _buildActionCard(
            icon: Icons.file_upload_outlined,
            title: 'Excel Ice Aktar',
            subtitle: 'Duzenlenmis Excel dosyasindan kayitlari ekle/guncelle.',
            color: Colors.orange,
            onTap: _isBusy ? null : _importExcelWithPreview,
          ),
          _buildActionCard(
            icon: Icons.playlist_add_check,
            title: 'Toplu Cihaz Ice Aktar',
            subtitle:
                'Cihaz adi ve seri no kolonlariyla hizli cihaz listesi yukle.',
            color: Colors.purple,
            onTap: _isBusy ? null : _importSimpleDevicesWithPreview,
          ),
        ];

        if (!isWide) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                cards[i],
              ],
            ],
          );
        }

        final cardWidth = (constraints.maxWidth - 24) / 3;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map((card) => SizedBox(width: cardWidth, child: card))
              .toList(),
        );
      },
    );
  }

  // ignore: unused_element
  Widget _buildActionGridLegacy() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        final cards = [
          _buildActionCard(
            icon: Icons.file_download_outlined,
            title: 'Excel Dışa Aktar',
            subtitle: 'Tüm müşteri ve cihaz kayıtlarını .xlsx olarak kaydet.',
            color: _accentColor,
            onTap: _isBusy ? null : _exportExcel,
          ),
          _buildActionCard(
            icon: Icons.file_upload_outlined,
            title: 'Excel İçe Aktar',
            subtitle: 'Düzenlenmiş Excel dosyasından kayıtları ekle/güncelle.',
            color: Colors.orange,
            onTap: _isBusy ? null : _importExcel,
          ),
        ];

        if (!isWide) {
          return Column(
            children: [
              cards[0],
              const SizedBox(height: 12),
              cards[1],
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
          ],
        );
      },
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExportResult(String path) {
    return _buildSectionCard(
      icon: Icons.check_circle_outline,
      title: 'Dışa Aktarım Tamamlandı',
      subtitle: path,
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => OpenFilex.open(path),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Dosyayı Aç'),
        ),
      ),
    );
  }

  Widget _buildImportResult(ExcelImportResult result) {
    if (result.cancelled) {
      return _buildSectionCard(
        icon: Icons.info_outline,
        title: 'İçe Aktarım İptal Edildi',
        subtitle: 'Dosya seçilmedi.',
        child: const SizedBox.shrink(),
      );
    }

    return _buildSectionCard(
      icon: Icons.task_alt,
      title: 'İçe Aktarım Özeti',
      subtitle: '${result.totalChanged} kayıt işlendi.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryWrap(result),
          if (result.warnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Uyarılar',
              style: TextStyle(
                color: Colors.orange.shade900,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            ...result.warnings.take(6).map(
                  (warning) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $warning',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            if (result.warnings.length > 6)
              Text(
                '+${result.warnings.length - 6} uyarı daha',
                style: TextStyle(color: Colors.orange.shade900),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryWrap(ExcelImportResult result) {
    final items = [
      ('Yeni Müşteri', result.addedCustomers, Colors.green),
      ('Güncellenen Müşteri', result.updatedCustomers, Colors.blue),
      ('Yeni Cihaz', result.addedDevices, Colors.teal),
      ('Güncellenen Cihaz', result.updatedDevices, Colors.purple),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: item.$3.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: item.$3.withValues(alpha: 0.22)),
              ),
              child: Text(
                '${item.$1}: ${item.$2}',
                style: TextStyle(
                  color: item.$3,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: _primaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (child is! SizedBox) ...[
              const SizedBox(height: 14),
              child,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoLine({
    required IconData icon,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: _accentColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey.shade700,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _exportExcel() async {
    final mode = await _selectExportMode();
    if (mode == null || !mounted) return;

    setState(() {
      _isBusy = true;
      _lastImportResult = null;
      _lastExportPath = null;
    });

    try {
      final path = await _service.exportCustomersAndDevices(
        customers: context.read<CustomerProvider>().customers,
        devices: context.read<DeviceProvider>().devices,
        mode: mode,
      );
      if (!mounted) return;
      setState(() => _lastExportPath = path);
      if (path != null) {
        _showSnack('Excel dosyasi olusturuldu.', Colors.green);
      }
    } catch (e) {
      if (mounted) _showSnack('Disa aktarim hatasi: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<DeviceExportMode?> _selectExportMode() {
    return showDialog<DeviceExportMode>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disa Aktarim Tipi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_tree_outlined),
              title: const Text('Hiyerarsik tam aktarim'),
              subtitle: const Text(
                'Cari, cihaz, kontrol unitesi, bagli modul sayisi ve baglantilar korunur.',
              ),
              onTap: () =>
                  Navigator.pop(context, DeviceExportMode.hierarchical),
            ),
            const Divider(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.format_list_bulleted),
              title: const Text('Basit cihaz listesi'),
              subtitle:
                  const Text('Sadece cihaz adi ve seri no disari aktarilir.'),
              onTap: () => Navigator.pop(context, DeviceExportMode.simple),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgec'),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Future<void> _exportExcelLegacy() async {
    setState(() {
      _isBusy = true;
      _lastImportResult = null;
      _lastExportPath = null;
    });

    try {
      final path = await _service.exportCustomersAndDevices(
        customers: context.read<CustomerProvider>().customers,
        devices: context.read<DeviceProvider>().devices,
      );
      if (!mounted) return;
      setState(() => _lastExportPath = path);
      if (path != null) {
        _showSnack('Excel dosyası oluşturuldu.', Colors.green);
      }
    } catch (e) {
      if (mounted) _showSnack('Dışa aktarım hatası: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // ignore: unused_element
  Future<void> _importExcel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excel İçe Aktar'),
        content: const Text(
          'Aynı müşteri adı veya cihaz seri numarası bulunursa kayıt güncellenir. Bulunmazsa yeni kayıt açılır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Devam Et'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isBusy = true;
      _lastImportResult = null;
      _lastExportPath = null;
    });

    try {
      final result = await _service.importCustomersAndDevices(
        customerProvider: context.read<CustomerProvider>(),
        deviceProvider: context.read<DeviceProvider>(),
      );
      if (!mounted) return;
      setState(() => _lastImportResult = result);
      if (!result.cancelled) {
        _showSnack('Excel içe aktarım tamamlandı.', Colors.green);
      }
    } catch (e) {
      if (mounted) _showSnack('İçe aktarım hatası: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // ignore: unused_element
  Future<void> _importSimpleDevices() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Toplu Cihaz Ice Aktar'),
        content: const Text(
          'Excel dosyasinda cihaz_adi ve seri_no kolonlari olmalidir. Seri no zaten varsa sadece cihaz adi guncellenir; mevcut kurum ve modul bilgileri korunur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgec'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Dosya Sec'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isBusy = true;
      _lastImportResult = null;
      _lastExportPath = null;
    });

    try {
      final result = await _service.importSimpleDevices(
        deviceProvider: context.read<DeviceProvider>(),
      );
      if (!mounted) return;
      setState(() => _lastImportResult = result);
      if (!result.cancelled) {
        _showSnack('Toplu cihaz ice aktarim tamamlandi.', Colors.green);
      }
    } catch (e) {
      if (mounted) _showSnack('Toplu cihaz import hatasi: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _importExcelWithPreview() async {
    setState(() {
      _isBusy = true;
      _lastImportResult = null;
      _lastExportPath = null;
    });

    try {
      final preview = await _service.previewCustomersAndDevicesImport(
        customerProvider: context.read<CustomerProvider>(),
        deviceProvider: context.read<DeviceProvider>(),
      );
      if (!mounted) return;
      setState(() => _isBusy = false);
      if (preview.cancelled) return;

      final confirmed = await _showImportPreviewDialog(preview);
      if (confirmed != true || !mounted) return;

      setState(() => _isBusy = true);
      final result = await _service.importCustomersAndDevicesFromPreview(
        preview: preview,
        customerProvider: context.read<CustomerProvider>(),
        deviceProvider: context.read<DeviceProvider>(),
      );
      if (!mounted) return;
      setState(() => _lastImportResult = result);
      if (!result.cancelled) {
        _showSnack('Excel ice aktarim tamamlandi.', Colors.green);
      }
    } catch (e) {
      if (mounted) _showSnack('Ice aktarim hatasi: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _importSimpleDevicesWithPreview() async {
    setState(() {
      _isBusy = true;
      _lastImportResult = null;
      _lastExportPath = null;
    });

    try {
      final preview = await _service.previewSimpleDevicesImport(
        deviceProvider: context.read<DeviceProvider>(),
      );
      if (!mounted) return;
      setState(() => _isBusy = false);
      if (preview.cancelled) return;

      final confirmed = await _showImportPreviewDialog(preview);
      if (confirmed != true || !mounted) return;

      setState(() => _isBusy = true);
      final result = await _service.importSimpleDevicesFromPreview(
        preview: preview,
        deviceProvider: context.read<DeviceProvider>(),
      );
      if (!mounted) return;
      setState(() => _lastImportResult = result);
      if (!result.cancelled) {
        _showSnack('Toplu cihaz ice aktarim tamamlandi.', Colors.green);
      }
    } catch (e) {
      if (mounted) _showSnack('Toplu cihaz import hatasi: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<bool?> _showImportPreviewDialog(ExcelImportPreview preview) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Onizleme'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preview.fileName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                _buildPreviewSummary(preview),
                if (preview.warnings.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Uyarilar',
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...preview.warnings.take(8).map(
                        (warning) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '- $warning',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  if (preview.warnings.length > 8)
                    Text(
                      '+${preview.warnings.length - 8} uyari daha',
                      style: TextStyle(color: Colors.orange.shade900),
                    ),
                ],
                if (!preview.hasWork) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Bu dosyada islenecek yeni veya guncellenecek kayit bulunamadi.',
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgec'),
          ),
          FilledButton.icon(
            onPressed:
                preview.hasWork ? () => Navigator.pop(context, true) : null,
            icon: const Icon(Icons.playlist_add_check),
            label: const Text('Uygula'),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSummary(ExcelImportPreview preview) {
    final items = [
      ('Yeni Musteri', preview.addedCustomers, Colors.green),
      ('Guncellenecek Musteri', preview.updatedCustomers, Colors.blue),
      ('Yeni Cihaz', preview.addedDevices, Colors.teal),
      ('Guncellenecek Cihaz', preview.updatedDevices, Colors.purple),
      ('Atlanacak Satir', preview.skippedRows, Colors.red),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .where((item) => item.$2 > 0)
          .map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: item.$3.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: item.$3.withValues(alpha: 0.22)),
              ),
              child: Text(
                '${item.$1}: ${item.$2}',
                style: TextStyle(
                  color: item.$3,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }
}
