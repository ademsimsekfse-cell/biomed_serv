import 'dart:convert';
import 'dart:io';

import 'package:biomed_serv/models/expense.dart';
import 'package:biomed_serv/models/technician.dart';
import 'package:biomed_serv/providers/expense_report_provider.dart';
import 'package:biomed_serv/providers/notification_provider.dart';
import 'package:biomed_serv/screens/pdf_preview_screen.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:biomed_serv/services/report_file_service.dart';
import 'package:biomed_serv/utils/turkish_text_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';

/// Masraf Rapor Ekranı
/// Seçili masrafları raporlar, PDF oluşturur ve paylaşır
class ExpenseReportScreen extends StatefulWidget {
  final List<int> expenseKeys;
  final VoidCallback? onReportCreated;

  const ExpenseReportScreen({
    super.key,
    required this.expenseKeys,
    this.onReportCreated,
  });

  @override
  State<ExpenseReportScreen> createState() => _ExpenseReportScreenState();
}

class _ExpenseReportScreenState extends State<ExpenseReportScreen> {
  final _notesController = TextEditingController();
  late SignatureController _signatureController;
  bool _isGenerating = false;
  File? _pdfFile;
  String? _generatedReportNumber;
  List<Expense> _expenses = [];
  double _totalAmount = 0;

  @override
  void initState() {
    super.initState();
    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
    );
    _loadExpenses();
  }

  void _loadExpenses() {
    final expenseBox =
        Provider.of<DatabaseService>(context, listen: false).expensesBox;
    _expenses = [];
    _totalAmount = 0;

    for (final key in widget.expenseKeys) {
      final expense = expenseBox.get(key);
      if (expense != null) {
        _expenses.add(expense);
        _totalAmount += expense.amount;
      }
    }

    // Tarihe göre sırala
    _expenses.sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  void dispose() {
    _notesController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy');
    final amountFormat = NumberFormat('#,##0.00', 'tr_TR');
    final technicianBox =
        Provider.of<DatabaseService>(context, listen: false).techniciansBox;
    final technician = technicianBox.isNotEmpty ? technicianBox.getAt(0) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Masraf Raporu Oluştur'),
        actions: [
          if (_pdfFile != null)
            IconButton(
              icon: const Icon(Icons.visibility),
              onPressed: _openPdfPreview,
              tooltip: 'Önizle ve Paylaş',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rapor Bilgisi
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rapor Bilgisi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Rapor No:',
                        _generatedReportNumber ?? _nextReportNumber()),
                    _buildInfoRow(
                        'Oluşturma Tarihi:', dateFormat.format(DateTime.now())),
                    _buildInfoRow('Teknisyen:', technician?.fullName ?? '-'),
                    _buildInfoRow('Masraf Sayısı:', '${_expenses.length} adet'),
                    const Divider(),
                    _buildInfoRow(
                      'TOPLAM TUTAR:',
                      '${amountFormat.format(_totalAmount)} TL',
                      isBold: true,
                      valueColor: Colors.green,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Masraf Listesi
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Masraf Detayları',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._expenses.asMap().entries.map((entry) {
                      final index = entry.key + 1;
                      final expense = entry.value;
                      return _buildExpenseRow(
                        index,
                        expense,
                        dateFormat,
                        amountFormat,
                      );
                    }),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'GENEL TOPLAM:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${amountFormat.format(_totalAmount)} TL',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Notlar
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notlar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesController,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: const [
                        TurkishUpperCaseTextFormatter(),
                      ],
                      decoration: const InputDecoration(
                        hintText: 'Rapor için ek notlar...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // İmza
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Teknisyen İmzası',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _signatureController.clear(),
                          icon: const Icon(Icons.clear),
                          label: const Text('Temizle'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Signature(
                        controller: _signatureController,
                        height: 150,
                        backgroundColor: Colors.grey.shade100,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Butonlar
            if (_isGenerating)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('PDF oluşturuluyor...'),
                  ],
                ),
              )
            else if (_pdfFile == null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _generatePdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('PDF Oluştur ve Önizle'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              )
            else
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openPdfPreview,
                      icon: const Icon(Icons.visibility),
                      label: const Text('Önizle ve Paylaş'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _finalizeReport,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Raporu Tamamla'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseRow(
    int index,
    Expense expense,
    DateFormat dateFormat,
    NumberFormat amountFormat,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$index.',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      dateFormat.format(expense.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                if (expense.customer != null || expense.device != null)
                  Text(
                    '  → ${expense.relatedEntityName}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${amountFormat.format(expense.amount)} TL',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePdf() async {
    setState(() => _isGenerating = true);

    try {
      final technicianBox =
          Provider.of<DatabaseService>(context, listen: false).techniciansBox;
      final technician =
          technicianBox.isNotEmpty ? technicianBox.getAt(0) : null;
      final reportNumber = _generatedReportNumber ?? _nextReportNumber();
      _generatedReportNumber = reportNumber;

      final pdf = pw.Document();
      final font = pw.Font.ttf(
          await rootBundle.load("assets/fonts/OpenSans-Regular.ttf"));
      final boldFont =
          pw.Font.ttf(await rootBundle.load("assets/fonts/OpenSans-Bold.ttf"));

      // İmza
      String? signatureBase64;
      if (_signatureController.isNotEmpty) {
        final signatureImage = await _signatureController.toPngBytes();
        if (signatureImage != null) {
          signatureBase64 = base64Encode(signatureImage);
        }
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => _buildPdfContent(
            reportNumber,
            technician,
            signatureBase64,
            font,
            boldFont,
          ),
        ),
      );

      final fileName =
          'MASRAF_RAPORU_${reportNumber}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf';
      _pdfFile = await ReportFileService.savePdfBytes(
        await pdf.save(),
        fileName: fileName,
        category: 'Masraf',
      );

      if (!mounted) return;
      setState(() => _isGenerating = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF oluşturuldu. Önizleme açılıyor.'),
          backgroundColor: Colors.green,
        ),
      );
      await _openPdfPreview();
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF oluşturma hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  pw.Widget _buildPdfContent(
    String reportNumber,
    Technician? technician,
    String? signatureBase64,
    pw.Font font,
    pw.Font boldFont,
  ) {
    final dateFormat = DateFormat('dd.MM.yyyy');
    final amountFormat = NumberFormat('#,##0.00', 'tr_TR');
    final createdAt = DateTime.now();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
          child: _buildPdfTitleCard('Masraf Bildirim Formu', boldFont),
        ),
        pw.SizedBox(height: 14),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 7,
              child: _buildPdfInfoCard(
                title: 'Bildiren Teknisyen',
                font: font,
                boldFont: boldFont,
                rows: [
                  ['Ad Soyad', technician?.fullName ?? ''],
                  ['Telefon', technician?.phone ?? ''],
                  ['Unvan', technician?.title ?? ''],
                ],
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              flex: 4,
              child: _buildPdfInfoCard(
                title: 'Form Bilgisi',
                font: font,
                boldFont: boldFont,
                rows: [
                  ['Tarih', dateFormat.format(createdAt)],
                  ['Form No', reportNumber],
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 16),

        pw.Table(
          border: pw.TableBorder.all(color: PdfColor.fromHex('#D5DBE3')),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.3),
            1: const pw.FlexColumnWidth(3.2),
            2: const pw.FlexColumnWidth(2.2),
            3: const pw.FlexColumnWidth(2.2),
            4: const pw.FlexColumnWidth(1.4),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('#EEF4FA')),
              children: [
                _buildPdfTableHeader('Tarih', boldFont),
                _buildPdfTableHeader('Açıklama', boldFont),
                _buildPdfTableHeader('Kurum', boldFont),
                _buildPdfTableHeader('Cihaz', boldFont),
                _buildPdfTableHeader('Tutar', boldFont),
              ],
            ),
            ..._expenses.map((expense) {
              return pw.TableRow(
                children: [
                  _buildPdfTableCell(dateFormat.format(expense.date), font,
                      align: pw.TextAlign.center),
                  _buildPdfTableCell(_shorten(expense.description, 52), font),
                  _buildPdfTableCell(expense.customer?.name ?? '', font),
                  _buildPdfTableCell(
                    expense.device == null
                        ? ''
                        : '${expense.device!.name} ${expense.device!.serialNumber}'
                            .trim(),
                    font,
                  ),
                  _buildPdfTableCell(
                    amountFormat.format(expense.amount),
                    font,
                    align: pw.TextAlign.right,
                  ),
                ],
              );
            }),
          ],
        ),
        pw.SizedBox(height: 12),

        // Toplam
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F5F8FB'),
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColor.fromHex('#D5DBE3')),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text(
                'Toplam Tutar: ',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 10,
                  color: PdfColor.fromHex('#233447'),
                ),
              ),
              pw.Text(
                amountFormat.format(_totalAmount),
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 12,
                  color: PdfColor.fromHex('#233447'),
                ),
              ),
            ],
          ),
        ),

        // Notlar
        if (_notesController.text.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text(
            'Notlar:',
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 10,
              color: PdfColor.fromHex('#7F8C8D'),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            _notesController.text,
            style: pw.TextStyle(font: font, fontSize: 9),
          ),
        ],

        pw.Spacer(),

        _buildSignatureBlock(
          technicianName: technician?.fullName ?? '',
          signatureBase64: signatureBase64,
          font: font,
          boldFont: boldFont,
        ),
      ],
    );
  }

  String _nextReportNumber() {
    final box =
        Provider.of<DatabaseService>(context, listen: false).expenseReportsBox;
    final sequence = (box.length + 1).toString().padLeft(6, '0');
    return 'MBF-$sequence';
  }

  String _shorten(String value, int maxLength) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength - 1)}.';
  }

  pw.Widget _buildPdfTitleCard(String title, pw.Font boldFont) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 34, vertical: 10),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F7FAFC'),
        border: pw.Border.all(color: PdfColor.fromHex('#B8C7D9'), width: 0.8),
        borderRadius: pw.BorderRadius.circular(18),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          font: boldFont,
          fontSize: 18,
          color: PdfColor.fromHex('#233447'),
        ),
      ),
    );
  }

  pw.Widget _buildPdfInfoCard({
    required String title,
    required pw.Font font,
    required pw.Font boldFont,
    required List<List<String>> rows,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#FFFFFF'),
        border: pw.Border.all(color: PdfColor.fromHex('#D5DBE3'), width: 0.7),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 9,
              color: PdfColor.fromHex('#506275'),
            ),
          ),
          pw.SizedBox(height: 6),
          ...rows.map(
            (row) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 54,
                    child: pw.Text(
                      row[0],
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 8,
                        color: PdfColor.fromHex('#7A8794'),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      row[1],
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 8.5,
                        color: PdfColor.fromHex('#233447'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfTableHeader(String text, pw.Font boldFont) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: boldFont,
          fontSize: 9,
          color: PdfColor.fromHex('#233447'),
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildPdfTableCell(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 7.5),
        textAlign: align,
        maxLines: 2,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  pw.Widget _buildSignatureBlock({
    required String technicianName,
    required String? signatureBase64,
    required pw.Font font,
    required pw.Font boldFont,
  }) {
    pw.Widget signature = pw.SizedBox(height: 46);
    if (signatureBase64 != null) {
      signature = pw.Image(
        pw.MemoryImage(base64Decode(signatureBase64)),
        fit: pw.BoxFit.contain,
        height: 46,
      );
    }

    return pw.Align(
      alignment: pw.Alignment.centerLeft,
      child: pw.Container(
        width: 210,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColor.fromHex('#D5DBE3'), width: 0.7),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Ad Soyad',
              style: pw.TextStyle(
                font: font,
                fontSize: 7,
                color: PdfColor.fromHex('#7A8794'),
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              technicianName,
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 9,
                color: PdfColor.fromHex('#233447'),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'İmza',
              style: pw.TextStyle(
                font: font,
                fontSize: 7,
                color: PdfColor.fromHex('#7A8794'),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Container(
              height: 52,
              width: double.infinity,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                    color: PdfColor.fromHex('#E2E8F0'), width: 0.6),
              ),
              child: pw.Center(child: signature),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPdfPreview() async {
    if (_pdfFile == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(
          filePath: _pdfFile!.path,
          title: 'Masraf Raporu Önizleme',
          shareText: 'Masraf Raporu',
        ),
      ),
    );
  }

  Future<void> _finalizeReport() async {
    if (_pdfFile == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Raporu Tamamla'),
        content: const Text(
          'Rapor tamamlandığında:\n'
          '• Seçili masraflar tahsil bekliyor durumuna alınacak\n'
          '• Rapor geçmişine eklenecek\n'
          '• Tahsilat durumu "Bekliyor" olarak işaretlenecek\n\n'
          'Devam etmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Tamamla'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirmed == true) {
      try {
        final technicianBox =
            Provider.of<DatabaseService>(context, listen: false).techniciansBox;
        final technician =
            technicianBox.isNotEmpty ? technicianBox.getAt(0) : null;
        if (technician == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rapor icin teknisyen bilgisi bulunamadi.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final reportProvider =
            Provider.of<ExpenseReportProvider>(context, listen: false);
        final notificationProvider =
            Provider.of<NotificationProvider>(context, listen: false);

        // Raporu oluştur
        final report = await reportProvider.createReport(
          technician: technician,
          expenseKeys: widget.expenseKeys,
          reportNumber: _generatedReportNumber ?? _nextReportNumber(),
          notes: _notesController.text.isEmpty
              ? null
              : normalizeDescriptionText(_notesController.text),
        );

        // PDF yolunu kaydet
        await reportProvider.updatePdfPath(report.key!, _pdfFile!.path);

        // 💰 Tahsilat bildirimi oluştur (raporlanan masraflar için)
        if (_expenses.isNotEmpty) {
          await notificationProvider.createCollectionReminder(_expenses);
        }

        widget.onReportCreated?.call();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Rapor tamamlandı ve tahsil bekliyor ekranına alındı!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
