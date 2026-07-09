import 'dart:io';

import 'package:biomed_serv/screens/pdf_preview_screen.dart';
import 'package:biomed_serv/services/report_file_service.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';

class DocumentScannerScreen extends StatefulWidget {
  const DocumentScannerScreen({super.key});

  @override
  State<DocumentScannerScreen> createState() => _DocumentScannerScreenState();
}

class _DocumentScannerScreenState extends State<DocumentScannerScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final List<_DocumentPage> _pages = [];
  bool _isProcessing = false;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    if (_isDesktop) return;
    await Permission.camera.request();
    await Permission.storage.request();
  }

  Future<void> _scanDocument() async {
    if (_isDesktop) {
      await _addDesktopImages();
      return;
    }

    await _runBusy(() async {
      final pictures = await CunningDocumentScanner.getPictures(
            noOfPages: 20,
            isGalleryImportAllowed: true,
          ) ??
          <String>[];

      if (!mounted || pictures.isEmpty) return;
      setState(() {
        _pages.addAll(
          pictures.map(
            (path) => _DocumentPage(
              path: path,
              source: _DocumentPageSource.scanner,
            ),
          ),
        );
      });
    }, errorPrefix: 'Tarama hatası');
  }

  Future<void> _addCameraPhoto() async {
    if (_isDesktop) {
      await _addDesktopImages();
      return;
    }

    await _pickSingleImage(
      ImageSource.camera,
      source: _DocumentPageSource.camera,
      errorPrefix: 'Fotoğraf çekme hatası',
    );
  }

  Future<void> _addGalleryImages() async {
    if (_isDesktop) {
      await _addDesktopImages();
      return;
    }

    await _runBusy(() async {
      final images = await _imagePicker.pickMultiImage(imageQuality: 92);
      if (!mounted || images.isEmpty) return;
      setState(() {
        _pages.addAll(
          images.map(
            (image) => _DocumentPage(
              path: image.path,
              source: _DocumentPageSource.gallery,
            ),
          ),
        );
      });
    }, errorPrefix: 'Galeri ekleme hatası');
  }

  Future<void> _addDesktopImages() async {
    await _runBusy(() async {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png'],
        dialogTitle: 'PDF içine eklenecek görselleri seçin',
      );

      final files = result?.files
              .map((file) => file.path)
              .whereType<String>()
              .where((path) => path.trim().isNotEmpty)
              .toList() ??
          <String>[];

      if (!mounted || files.isEmpty) return;
      setState(() {
        _pages.addAll(
          files.map(
            (path) => _DocumentPage(
              path: path,
              source: _DocumentPageSource.file,
            ),
          ),
        );
      });
    }, errorPrefix: 'Görsel ekleme hatası');
  }

  Future<void> _pickSingleImage(
    ImageSource imageSource, {
    required _DocumentPageSource source,
    required String errorPrefix,
  }) async {
    await _runBusy(() async {
      final image = await _imagePicker.pickImage(
        source: imageSource,
        imageQuality: 92,
      );
      if (!mounted || image == null) return;
      setState(() {
        _pages.add(_DocumentPage(path: image.path, source: source));
      });
    }, errorPrefix: errorPrefix);
  }

  Future<void> _createPdf() async {
    if (_pages.isEmpty) {
      _showSnack('Önce belge veya görsel ekleyin.', Colors.orange);
      return;
    }

    await _runBusy(() async {
      final pdf = pw.Document();
      var addedPages = 0;

      for (final page in _pages) {
        final imageFile = File(page.path);
        if (!await imageFile.exists()) continue;

        final imageBytes = await imageFile.readAsBytes();
        final image = pw.MemoryImage(imageBytes);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(18),
            build: (_) => pw.Center(
              child: pw.Image(image, fit: pw.BoxFit.contain),
            ),
          ),
        );
        addedPages++;
      }

      if (addedPages == 0) {
        throw Exception('PDF için okunabilir görsel bulunamadı.');
      }

      final timestamp = DateTime.now();
      final fileName =
          'BELGE_PAKETI_${timestamp.year}${_two(timestamp.month)}${_two(timestamp.day)}_${_two(timestamp.hour)}${_two(timestamp.minute)}_${addedPages}_sayfa.pdf';
      final pdfFile = await ReportFileService.savePdfBytes(
        await pdf.save(),
        fileName: fileName,
        category: 'Belgeler',
      );

      if (!mounted) return;
      _showSnack('PDF arşive kaydedildi. Önizleme açılıyor.', Colors.green);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfPreviewScreen(
            filePath: pdfFile.path,
            title: 'Belge Paketi Önizleme',
            shareText: 'Belge Paketi PDF',
          ),
        ),
      );
    }, errorPrefix: 'PDF oluşturma hatası');
  }

  Future<void> _runBusy(
    Future<void> Function() action, {
    required String errorPrefix,
  }) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await action();
    } catch (e) {
      if (mounted) _showSnack('$errorPrefix: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _removePage(int index) {
    setState(() => _pages.removeAt(index));
  }

  void _movePage(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final page = _pages.removeAt(oldIndex);
      _pages.insert(newIndex, page);
    });
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final hasPages = _pages.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isDesktop ? 'Belge Paketi' : 'Belge Tarayıcı'),
        actions: [
          if (hasPages)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => setState(_pages.clear),
              tooltip: 'Tümünü Temizle',
            ),
        ],
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('İşleniyor...'),
                ],
              ),
            )
          : hasPages
              ? _buildPageList()
              : _buildEmptyState(context),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: _buildActionBar(hasPages),
        ),
      ),
    );
  }

  Widget _buildActionBar(bool hasPages) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasPages) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _createPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: Text('${_pages.length} Sayfalı PDF Oluştur'),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (_isDesktop)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addDesktopImages,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(hasPages ? 'Görsel Dosyası Ekle' : 'Görsel Seç'),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _scanDocument,
                  icon: const Icon(Icons.document_scanner),
                  label: Text(hasPages ? 'Tara' : 'Belge Tara'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _addCameraPhoto,
                icon: const Icon(Icons.photo_camera),
                tooltip: 'Fotoğraf çek',
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _addGalleryImages,
                icon: const Icon(Icons.photo_library),
                tooltip: 'Galeriden ekle',
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isDesktop
                    ? Icons.add_photo_alternate_outlined
                    : Icons.document_scanner_outlined,
                size: 76,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _isDesktop
                  ? 'Görsellerden Çok Sayfalı PDF'
                  : 'Çok Sayfalı PDF Hazırla',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              _isDesktop
                  ? 'Servis talep formu, parça fotoğrafı ve işlem görsellerini bilgisayardan seçip tek PDF içinde toplayabilirsiniz.'
                  : 'Servis talep formu, değişen parça fotoğrafı ve yapılan işlem görsellerini aynı PDF içinde toplayabilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: _isDesktop
                  ? [
                      FilledButton.icon(
                        onPressed: _addDesktopImages,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: const Text('Görsel Seç'),
                      ),
                    ]
                  : [
                      FilledButton.icon(
                        onPressed: _scanDocument,
                        icon: const Icon(Icons.document_scanner),
                        label: const Text('Belge Tara'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _addCameraPhoto,
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('Fotoğraf Çek'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _addGalleryImages,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Galeriden Ekle'),
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageList() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_pages.length} sayfa eklendi. Sayfaları sürükleyerek sıralayın, gereksiz olanları kaldırın.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            itemCount: _pages.length,
            onReorder: _movePage,
            itemBuilder: (context, index) {
              final page = _pages[index];
              return _DocumentPageCard(
                key: ValueKey('${page.path}-$index'),
                page: page,
                pageNumber: index + 1,
                onDelete: () => _removePage(index),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DocumentPageCard extends StatelessWidget {
  final _DocumentPage page;
  final int pageNumber;
  final VoidCallback onDelete;

  const _DocumentPageCard({
    super.key,
    required this.page,
    required this.pageNumber,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Image.file(
              File(page.path),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: scheme.errorContainer,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: scheme.onErrorContainer,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  child: Text('$pageNumber'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    page.source.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.drag_handle),
                  tooltip: 'Sıralamak için sürükleyin',
                  onPressed: null,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Sayfayı kaldır',
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentPage {
  final String path;
  final _DocumentPageSource source;

  const _DocumentPage({
    required this.path,
    required this.source,
  });
}

enum _DocumentPageSource {
  scanner('Taranmış belge'),
  camera('Kamera fotoğrafı'),
  gallery('Galeri görseli'),
  file('Bilgisayar görseli');

  final String label;

  const _DocumentPageSource(this.label);
}
