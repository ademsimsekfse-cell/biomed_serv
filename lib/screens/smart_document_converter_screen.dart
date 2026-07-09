import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

class SmartDocumentConverterScreen extends StatefulWidget {
  const SmartDocumentConverterScreen({super.key});

  @override
  State<SmartDocumentConverterScreen> createState() =>
      _SmartDocumentConverterScreenState();
}

class _SmartDocumentConverterScreenState
    extends State<SmartDocumentConverterScreen> {
  File? _selectedImage;
  String _extractedText = '';
  List<List<String>> _detectedTable = [];
  bool _isProcessing = false;
  String _selectedFormat = 'PDF';

  final List<String> _formats = ['PDF', 'Excel', 'Word'];

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    await Permission.camera.request();
    await Permission.storage.request();
  }

  Future<void> _captureImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _extractedText = '';
        _detectedTable = [];
      });
      await _processImage();
    }
  }

  Future<void> _pickFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _extractedText = '';
        _detectedTable = [];
      });
      await _processImage();
    }
  }

  Future<void> _processImage() async {
    if (_selectedImage == null) return;

    setState(() => _isProcessing = true);

    try {
      final inputImage = InputImage.fromFile(_selectedImage!);
      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);

      String fullText = '';
      List<List<String>> tableData = [];

      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          fullText += '${line.text}\n';

          // Tablo algılama - sayı ve ayırıcı içeren satırlar
          final List<String> cells = _detectTableCells(line.text);
          if (cells.length > 1) {
            tableData.add(cells);
          }
        }
      }

      await textRecognizer.close();

      if (mounted) {
        setState(() {
          _extractedText = fullText.trim();
          _detectedTable = tableData;
          _isProcessing = false;
        });

        if (_extractedText.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${_detectedTable.isNotEmpty ? "Tablo ve " : ""}metin algılandı!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('İşleme hatası: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<String> _detectTableCells(String text) {
    // Tablo hücrelerini algıla - virgül, noktalı virgül, tab veya boşlukla ayrılmış veriler
    final separators = RegExp(r'[,;\t|]+|\s{2,}');
    final cells = text
        .split(separators)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return cells.length > 1 ? cells : [];
  }

  Future<void> _convertAndShare() async {
    if (_extractedText.isEmpty && _detectedTable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Önce bir görüntü işlemelisiniz!'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      String filePath = '';

      switch (_selectedFormat) {
        case 'PDF':
          filePath = await _createPdf();
          break;
        case 'Excel':
          filePath = await _createExcel();
          break;
        case 'Word':
          filePath = await _createWord();
          break;
      }

      if (mounted) {
        setState(() => _isProcessing = false);
        _showShareOptions(filePath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Dönüştürme hatası: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<String> _createPdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Akıllı Belge Dönüştürücü',
                style:
                    pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Algılanan Metin:',
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Text(_extractedText, style: const pw.TextStyle(fontSize: 12)),
              if (_detectedTable.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text(
                  'Algılanan Tablo:',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Table.fromTextArray(
                  data: _detectedTable,
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  headerDecoration:
                      const pw.BoxDecoration(color: PdfColors.grey300),
                ),
              ],
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final pdfPath = '${output.path}/converted_$timestamp.pdf';
    final pdfFile = File(pdfPath);
    await pdfFile.writeAsBytes(await pdf.save());

    return pdfPath;
  }

  Future<String> _createExcel() async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Sheet1'];

    // Başlık ekle
    sheet.cell(CellIndex.indexByString('A1')).value =
        TextCellValue('Akıllı Belge Dönüştürücü - Çıktı');
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
    );

    int currentRow = 3;

    // Metni ekle
    if (_extractedText.isNotEmpty) {
      sheet.cell(CellIndex.indexByString('A$currentRow')).value =
          TextCellValue('Algılanan Metin:');
      sheet.cell(CellIndex.indexByString('A$currentRow')).cellStyle =
          CellStyle(bold: true);
      currentRow++;

      final lines = _extractedText.split('\n');
      for (final line in lines) {
        sheet.cell(CellIndex.indexByString('A$currentRow')).value =
            TextCellValue(line);
        currentRow++;
      }
      currentRow += 2;
    }

    // Tabloyu ekle
    if (_detectedTable.isNotEmpty) {
      sheet.cell(CellIndex.indexByString('A$currentRow')).value =
          TextCellValue('Algılanan Tablo:');
      sheet.cell(CellIndex.indexByString('A$currentRow')).cellStyle =
          CellStyle(bold: true);
      currentRow++;

      for (final row in _detectedTable) {
        for (int i = 0; i < row.length; i++) {
          final columnLetter = String.fromCharCode(65 + i);
          sheet
              .cell(CellIndex.indexByString('$columnLetter$currentRow'))
              .value = TextCellValue(row[i]);
        }
        currentRow++;
      }
    }

    // Sütun genişliklerini ayarla
    for (int i = 0; i < 10; i++) {
      sheet.setColumnWidth(i, 20);
    }

    final output = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final excelPath = '${output.path}/converted_$timestamp.xlsx';
    final excelFile = File(excelPath);
    await excelFile.writeAsBytes(excel.encode()!);

    return excelPath;
  }

  Future<String> _createWord() async {
    // Word (DOCX) oluşturma - HTML tabanlı basit bir yaklaşım
    final StringBuffer html = StringBuffer();
    html.write('''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Akıllı Belge Dönüştürücü</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 40px; }
    h1 { color: #333; }
    .section { margin: 20px 0; }
    .label { font-weight: bold; color: #666; }
    table { border-collapse: collapse; width: 100%; margin-top: 10px; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
    th { background-color: #f2f2f2; }
  </style>
</head>
<body>
  <h1>Akıllı Belge Dönüştürücü - Çıktı</h1>
''');

    if (_extractedText.isNotEmpty) {
      html.write('''
  <div class="section">
    <div class="label">Algılanan Metin:</div>
    <pre>${_extractedText.replaceAll('<', '&lt;').replaceAll('>', '&gt;')}</pre>
  </div>
''');
    }

    if (_detectedTable.isNotEmpty) {
      html.write('''
  <div class="section">
    <div class="label">Algılanan Tablo:</div>
    <table>
''');
      for (final row in _detectedTable) {
        html.write('      <tr>\n');
        for (final cell in row) {
          html.write(
              '        <td>${cell.replaceAll('<', '&lt;').replaceAll('>', '&gt;')}</td>\n');
        }
        html.write('      </tr>\n');
      }
      html.write('    </table>\n  </div>');
    }

    html.write('</body></html>');

    final output = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final docPath = '${output.path}/converted_$timestamp.html';
    final docFile = File(docPath);
    await docFile.writeAsString(html.toString());

    return docPath;
  }

  void _showShareOptions(String filePath) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_selectedFormat Paylaş',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.blue),
              title: const Text('Paylaş (WhatsApp, Mail, vb.)'),
              subtitle: const Text('Diğer uygulamalarla paylaş'),
              onTap: () {
                Navigator.pop(context);
                _shareFile(filePath);
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: Colors.green),
              title: const Text('WhatsApp\'tan Gönder'),
              onTap: () {
                Navigator.pop(context);
                _shareViaWhatsApp(filePath);
              },
            ),
            ListTile(
              leading: const Icon(Icons.email, color: Colors.orange),
              title: const Text('E-Posta ile Gönder'),
              onTap: () {
                Navigator.pop(context);
                _shareViaEmail(filePath);
              },
            ),
            ListTile(
              leading: const Icon(Icons.save_alt, color: Colors.purple),
              title: const Text('Telefona Kaydet'),
              subtitle: const Text('Download klasörüne kaydet'),
              onTap: () {
                Navigator.pop(context);
                _saveToDownloads(filePath);
              },
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareFile(String filePath) async {
    try {
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Akıllı Dönüştürücü Çıktısı',
        text: 'Belgeden dönüştürülen veriler ektedir.',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Paylaşım hatası: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _shareViaWhatsApp(String filePath) async {
    final uri = Uri.parse(
        'whatsapp://send?text=${Uri.encodeComponent('Belge dönüştürüldü!')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      await Future.delayed(const Duration(seconds: 1));
      await Share.shareXFiles([XFile(filePath)]);
    } else {
      await _shareFile(filePath);
    }
  }

  Future<void> _shareViaEmail(String filePath) async {
    final uri = Uri.parse(
        'mailto:?subject=Belge Çıktısı&body=Dönüştürülen belge ektedir.');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      await Future.delayed(const Duration(seconds: 1));
      await Share.shareXFiles([XFile(filePath)]);
    } else {
      await _shareFile(filePath);
    }
  }

  Future<void> _saveToDownloads(String filePath) async {
    try {
      final downloadsDir =
          Directory('/storage/emulated/0/Download/BiomedConverter');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final fileName = filePath.split('/').last;
      final newPath = '${downloadsDir.path}/$fileName';
      await File(filePath).copy(newPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Kaydedildi: $newPath'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Kaydetme hatası: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Akıllı Belge Dönüştürücü'),
        backgroundColor: Colors.indigo,
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Görüntü işleniyor...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Görüntü Seçim Butonları
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(Icons.camera_alt,
                              size: 48, color: Colors.indigo),
                          const SizedBox(height: 12),
                          const Text(
                            'Belge veya Ekran Fotoğrafı Çekin',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Metin, tablo ve veriler otomatik algılanacak',
                            style: TextStyle(color: Colors.grey.shade600),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _captureImage,
                                  icon: const Icon(Icons.camera),
                                  label: const Text('Kamera'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _pickFromGallery,
                                  icon: const Icon(Icons.photo_library),
                                  label: const Text('Galeri'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey.shade700,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Seçilen Görüntü Önizleme
                  if (_selectedImage != null) ...[
                    Card(
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                            child: Image.file(
                              _selectedImage!,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _selectedImage = null;
                                      _extractedText = '';
                                      _detectedTable = [];
                                    });
                                  },
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red),
                                  label: const Text('Temizle',
                                      style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Algılanan Veriler
                  if (_extractedText.isNotEmpty ||
                      _detectedTable.isNotEmpty) ...[
                    Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.check_circle,
                                    color: Colors.green.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Veriler Algılandı!',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_extractedText.isNotEmpty) ...[
                              Text(
                                'Metin (${_extractedText.length} karakter)',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _extractedText.length > 200
                                      ? '${_extractedText.substring(0, 200)}...'
                                      : _extractedText,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (_detectedTable.isNotEmpty) ...[
                              Text(
                                'Tablo (${_detectedTable.length} satır)',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: _detectedTable.take(3).map((row) {
                                    return Row(
                                      children: row.take(4).map((cell) {
                                        return Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            margin: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              cell,
                                              style:
                                                  const TextStyle(fontSize: 10),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Format Seçimi ve Dönüştürme
                  if (_extractedText.isNotEmpty ||
                      _detectedTable.isNotEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Dönüştürme Formatı',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: _formats.map((format) {
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    child: ChoiceChip(
                                      label: Text(format),
                                      selected: _selectedFormat == format,
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(
                                              () => _selectedFormat = format);
                                        }
                                      },
                                      selectedColor: Colors.indigo.shade100,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _convertAndShare,
                                icon: const Icon(Icons.transform),
                                label: Text(
                                    '$_selectedFormat\'e Dönüştür ve Paylaş'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
