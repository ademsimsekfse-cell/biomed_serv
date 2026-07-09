import 'package:biomed_serv/services/backup_import_service.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Yedek dosyalarından veri içe aktarma ekranı
class BackupImportScreen extends StatefulWidget {
  const BackupImportScreen({super.key});

  @override
  State<BackupImportScreen> createState() => _BackupImportScreenState();
}

class _BackupImportScreenState extends State<BackupImportScreen> {
  bool _isLoading = false;
  String? _selectedPath;
  ImportResult? _lastResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yedek Veri İçe Aktar'),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bilgi Kartı
            _buildInfoCard(),
            const SizedBox(height: 20),

            // Dosya Seçim Butonları
            _buildSelectionSection(),
            const SizedBox(height: 20),

            // Seçilen Yol
            if (_selectedPath != null) ...[
              _buildSelectedPathCard(),
              const SizedBox(height: 20),
            ],

            // İçe Aktar Butonu
            if (_selectedPath != null && !_isLoading) _buildImportButton(),

            // Yükleniyor
            if (_isLoading) ...[
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Veriler içe aktarılıyor...'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Sonuç
            if (_lastResult != null && !_isLoading) ...[
              _buildResultCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  'Yedek İçe Aktarma',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Eski uygulamanızın yedek dosyalarını (.hive) seçerek mevcut uygulamaya aktarabilirsiniz.',
            ),
            const SizedBox(height: 8),
            Text(
              'Desteklenen dosyalar:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildFileChip('institutions.hive', 'Kurumlar'),
                _buildFileChip('bakim_forms.hive', 'Bakım Formları'),
                _buildFileChip('stock_parts.hive', 'Stok Parçaları'),
                _buildFileChip('technicians.hive', 'Teknisyenler'),
                _buildFileChip('service_forms.hive', 'Servis Formları'),
                _buildFileChip('maintenance_models.hive', 'Cihazlar'),
                _buildFileChip('company_info.hive', 'Firma Bilgileri'),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber,
                      color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'UYARI: İçe aktarma işlemi mevcut verileri silmez, yeni kayıtlar ekler. Önemli verilerinizin yedeğini aldığınızdan emin olun.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileChip(String file, String description) {
    return Chip(
      label: Text('$file → $description'),
      backgroundColor: Colors.white,
      side: BorderSide(color: Colors.orange.shade200),
      labelStyle: const TextStyle(fontSize: 11),
    );
  }

  Widget _buildSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Yedek Dosyalarının Konumu',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _selectFolder,
                icon: const Icon(Icons.folder_open),
                label: const Text('Klasör Seç'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _selectZipFile,
                icon: const Icon(Icons.folder_zip),
                label: const Text('ZIP Dosyası Seç'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectedPathCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              _selectedPath!.endsWith('.zip') ? Icons.folder_zip : Icons.folder,
              color: Colors.blue,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedPath!.endsWith('.zip') ? 'ZIP Dosyası' : 'Klasör',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _selectedPath!,
                    style: const TextStyle(fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _selectedPath = null),
              icon: const Icon(Icons.clear),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _importData,
        icon: const Icon(Icons.download),
        label: const Text(
          'VERİLERİ İÇE AKTAR',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final result = _lastResult!;

    return Card(
      color: result.success ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  result.success ? Icons.check_circle : Icons.warning,
                  color: result.success ? Colors.green : Colors.orange,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  result.success
                      ? 'İçe Aktarma Başarılı'
                      : 'İçe Aktarma Tamamlandı',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: result.success
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (result.imported.isNotEmpty) ...[
              Text(
                'İçe Aktarılan Kayıtlar:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              ...result.imported.map((item) => Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.check,
                            size: 16, color: Colors.green.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(item,
                                style: const TextStyle(fontSize: 13))),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
            ],
            if (result.infos.isNotEmpty) ...[
              Text(
                'Bilgiler:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              ...result.infos.map((item) => Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: Colors.blue.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(item,
                                style: const TextStyle(fontSize: 13))),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
            ],
            if (result.errors.isNotEmpty) ...[
              Text(
                'Hatalar:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 8),
              ...result.errors.map((item) => Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            size: 16, color: Colors.red.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(item,
                                style: const TextStyle(fontSize: 13))),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _selectFolder() async {
    // Burada file_picker kullanılacak
    // Şimdilik bir text field gösterelim
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yedek Klasör Yolu'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: r'Örn: C:	empackup',
            labelText: 'Klasör Yolu',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _selectedPath = result);
    }
  }

  Future<void> _selectZipFile() async {
    // ZIP dosyası seçimi
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ZIP Dosya Yolu'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: r'Örn: C:	empackup.zip',
            labelText: 'ZIP Dosya Yolu',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _selectedPath = result);
    }
  }

  Future<void> _importData() async {
    if (_selectedPath == null) return;

    setState(() {
      _isLoading = true;
      _lastResult = null;
    });

    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final importService = BackupImportService(dbService);

      ImportResult result;

      if (_selectedPath!.toLowerCase().endsWith('.zip')) {
        result = await importService.importFromZip(_selectedPath!);
      } else {
        result = await importService.importFromFolder(_selectedPath!);
      }

      setState(() {
        _lastResult = result;
        _isLoading = false;
      });

      // Başarılıysa snackbar göster
      if (result.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${result.imported.length} kayıt başarıyla içe aktarıldı!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _lastResult = ImportResult()..addError('Beklenmeyen hata: $e');
        _isLoading = false;
      });
    }
  }
}
