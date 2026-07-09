import 'dart:convert';
import 'dart:io';
import 'package:biomed_serv/models/company_info.dart';
import 'package:biomed_serv/models/fault_ticket.dart';
import 'package:biomed_serv/models/maintenance_form.dart';
import 'package:biomed_serv/models/report_template.dart';
import 'package:biomed_serv/models/service_form.dart';
import 'package:biomed_serv/models/stock.dart';
import 'package:biomed_serv/models/technician.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:biomed_serv/services/pdf_share_service.dart';
import 'package:biomed_serv/services/report_file_service.dart';

class PdfService {
  // Kurumsal Renkler
  static const PdfColor _primaryColor = PdfColor.fromInt(0xFF0D47A1);
  static const PdfColor _lightBlue = PdfColor.fromInt(0xFFE3F2FD);
  static const PdfColor _borderColor = PdfColor.fromInt(0xFFBDBDBD);
  static const PdfColor _corporateBorder = PdfColor.fromInt(0xFF9AA6B2);
  static const PdfColor _corporateFill = PdfColor.fromInt(0xFFF6F8FA);
  static const PdfColor _corporateHeaderFill = PdfColor.fromInt(0xFFEFF3F7);
  static const PdfColor _corporateText = PdfColor.fromInt(0xFF26323F);
  static const double _cardRadius = 9.0;
  static const double _cardBorderWidth = 0.85;

  // Kompakt Font Boyutları
  static const double _labelSize = 8.0;
  static const double _valueSize = 9.0;

  // Aktif rapor şablonu (dışarıdan atanır)
  ReportTemplate? _template;
  CompanyInfo? _companyInfo;
  Technician? _technician;

  /// Rapor şablonunu ayarla
  void setTemplate(ReportTemplate? template) {
    _template = template;
  }

  /// Firma bilgilerini ayarla
  void setCompanyInfo(CompanyInfo? info) {
    _companyInfo = info;
  }

  /// Teknisyen bilgilerini ayarla
  void setTechnician(Technician? technician) {
    _technician = technician;
  }

  PdfColor get _templatePrimaryColor {
    if (_template != null) {
      return PdfColor.fromInt(_template!.style.primaryColor);
    }
    return _primaryColor;
  }

  String get _templateCompanyName {
    if (_companyInfo != null) {
      return _companyInfo!.companyName;
    }
    if (_template != null && _template!.style.companyName.isNotEmpty) {
      return _template!.style.companyName;
    }
    return 'FIRMA ADI';
  }

  Future<File> generateServicePdf(ServiceForm form) async {
    final fileName =
        'SERVİS_${form.formNumber}_${form.device.serialNumber}_${DateFormat('yyyy-MM-dd').format(form.createdAt)}.pdf';
    final pdfFile = await _generateTemplatePdf(
      fileName: fileName,
      category: 'Servis',
      title: "SERVİS FORMU",
      formNumber: form.formNumber,
      isService: true,
      contentBuilder: (font, boldFont) =>
          _buildServiceContent(form, font, boldFont),
    );
    // 🔊 PDF oluşturma sesi
    return pdfFile;
  }

  Future<void> generateAndShareServicePdf(ServiceForm form) async {
    final pdfFile = await generateServicePdf(form);
    await _sharePdf(pdfFile);
  }

  Future<File> generateMaintenancePdf(MaintenanceForm form) async {
    final fileName =
        'BAKIM_${form.formNumber}_${form.device.serialNumber}_${DateFormat('yyyy-MM-dd').format(form.createdAt)}.pdf';
    final pdfFile = await _generateTemplatePdf(
      fileName: fileName,
      category: 'Bakim',
      title: "PERİYODİK BAKIM FORMU",
      formNumber: form.formNumber,
      isService: false,
      contentBuilder: (font, boldFont) =>
          _buildMaintenanceContent(form, font, boldFont),
    );
    // 🔊 PDF oluşturma sesi
    return pdfFile;
  }

  Future<void> generateAndShareMaintenancePdf(MaintenanceForm form) async {
    final pdfFile = await generateMaintenancePdf(form);
    await _sharePdf(pdfFile);
  }

  Future<File> generateFaultTicketPdf(FaultTicket ticket) async {
    final fileName =
        'ARIZA_${ticket.ticketNumber}_${DateFormat('yyyy-MM-dd').format(ticket.createdAt)}.pdf';
    final pdfFile = await _generateTemplatePdf(
      fileName: fileName,
      category: 'Ariza',
      title: "ARIZA KAYIT VE MÜDAHALE FORMU",
      formNumber: ticket.ticketNumber,
      isService: true,
      contentBuilder: (font, boldFont) =>
          _buildFaultTicketContent(ticket, font, boldFont),
    );
    // 🔊 PDF oluşturma sesi
    return pdfFile;
  }

  Future<void> generateAndShareFaultTicketPdf(FaultTicket ticket) async {
    final pdfFile = await generateFaultTicketPdf(ticket);
    await _sharePdf(pdfFile);
  }

  List<pw.Widget> _buildServiceContent(
      ServiceForm form, pw.Font font, pw.Font bold) {
    final actionsParts = _splitLabeledContent(form.actionsTaken);
    final finalStatusParts = _splitLabeledContent(form.finalStatus);
    final selectedActions = _csvItems(_labeledValue(
      actionsParts,
      const ['Seçilen işlemler', 'Secilen islemler'],
    ));
    final actionDescription = _labeledValue(
          actionsParts,
          const ['Açıklama ve öneriler', 'Aciklama ve oneriler'],
        ) ??
        _plainWithoutLabels(form.actionsTaken);
    final resultStatus = _labeledValue(
      finalStatusParts,
      const ['Sonuç durumu', 'Sonuc durumu'],
    );
    final finalDescription = _labeledValue(
          finalStatusParts,
          const ['Son durum açıklaması', 'Son durum aciklamasi'],
        ) ??
        _plainWithoutLabels(form.finalStatus);
    final validationChecks = _csvItems(_labeledValue(
      finalStatusParts,
      const ['Doğrulama çalışmaları', 'Dogrulama calismalari'],
    ));
    final responsibleBox = _buildResponsibleInfoBox(
      form.device.responsiblePerson,
      fallbackName: null,
      font: font,
      bold: bold,
    );

    return [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              children: [
                _buildInfoBox(
                    "MÜŞTERİ BİLGİLERİ",
                    [
                      _row("Kurum:", form.customer.name, font, bold),
                      _row("Yetkili:", form.customer.authorizedPerson, font,
                          bold),
                      _row("Adres:", form.customer.address, font, bold),
                      _row("Tel:", form.customer.phone, font, bold),
                    ],
                    font,
                    bold),
                if (responsibleBox != null) ...[
                  pw.SizedBox(height: 6),
                  responsibleBox,
                ],
              ],
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              children: [
                _buildInfoBox(
                    "CİHAZ BİLGİLERİ",
                    [
                      _row("Cihaz:", form.device.name, font, bold),
                      _row("Seri No:", form.device.serialNumber, font, bold),
                      if (form.device.model.trim().isNotEmpty)
                        _row("Model:", form.device.model, font, bold),
                    ],
                    font,
                    bold),
                pw.SizedBox(height: 6),
                _buildInfoBox(
                    "SERVİS ZAMANLARI",
                    [
                      _row("Bildirim:", _formatDateTime(form.problemDateTime),
                          font, bold),
                      _row(
                          "Müdahale:",
                          _formatDateTime(form.interventionDateTime),
                          font,
                          bold),
                      _row("Bitiş:", _formatDateTime(form.solutionDateTime),
                          font, bold),
                    ],
                    font,
                    bold),
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 10),
      _buildChipTextSection(
        "PROBLEM DETAYLARI",
        chips: form.problemTypes,
        description: form.problemDescription,
        descriptionTitle: "Açıklama",
        font: font,
        bold: bold,
      ),
      pw.SizedBox(height: 10),
      _buildChipTextSection(
        "YAPILAN İŞLEMLER VE ÖNERİLER",
        chips: selectedActions,
        description: actionDescription,
        descriptionTitle: "Açıklama ve öneriler",
        font: font,
        bold: bold,
      ),
      pw.SizedBox(height: 10),
      _buildFinalStatusSection(
        title: "SON DURUM VE DOĞRULAMA ÇALIŞMALARI",
        resultStatus: resultStatus,
        description: finalDescription,
        checks: validationChecks,
        font: font,
        bold: bold,
      ),
      if (form.partsUsed.isNotEmpty) ...[
        pw.SizedBox(height: 10),
        _buildPartsTable(form.partsUsed.toList(), font, bold)
      ],
      pw.SizedBox(height: 10),
      _buildSignatureSection(
          "SERVİSİ YAPAN",
          form.technicianName,
          form.technicianSignature,
          "MÜŞTERİ YETKİLİSİ",
          form.customerName,
          form.customerSignature,
          font,
          bold),
    ];
  }

  List<pw.Widget> _buildMaintenanceContent(
      MaintenanceForm form, pw.Font font, pw.Font bold) {
    final responsibleBox = _buildResponsibleInfoBox(
      form.device.responsiblePerson,
      fallbackName: null,
      font: font,
      bold: bold,
    );

    return [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 5,
            child: pw.Column(
              children: [
                _buildInfoBox(
                    "MÜŞTERİ BİLGİLERİ",
                    [
                      _row("Kurum:", form.customer.name, font, bold),
                      _row("Yetkili:", form.customer.authorizedPerson, font,
                          bold),
                      _row("Adres:", form.customer.address, font, bold),
                    ],
                    font,
                    bold),
                if (responsibleBox != null) ...[
                  pw.SizedBox(height: 6),
                  responsibleBox,
                ],
              ],
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
              flex: 4,
              child: _buildInfoBox(
                  "CİHAZ VE BAKIM BİLGİLERİ",
                  [
                    _row("Cihaz:", form.device.name, font, bold),
                    _row("Seri No:", form.device.serialNumber, font, bold),
                    _row("Periyot:", form.maintenancePeriod, font, bold),
                    _row("Tarih:", _formatDate(form.createdAt), font, bold),
                  ],
                  font,
                  bold)),
        ],
      ),
      pw.SizedBox(height: 10),
      _buildChipTextSection(
        "YAPILAN KONTROL VE BAKIM İŞLEMLERİ",
        chips: form.actionsTaken,
        description: form.notes,
        descriptionTitle: "Açıklama",
        font: font,
        bold: bold,
      ),
      if (form.partsUsed.isNotEmpty) ...[
        pw.SizedBox(height: 10),
        _buildPartsTable(form.partsUsed.toList(), font, bold),
      ],
      if (form.finalStatus != null && form.finalStatus!.trim().isNotEmpty) ...[
        pw.SizedBox(height: 10),
        _buildFinalStatusSection(
          title: "CİHAZIN SON DURUMU VE DOĞRULAMA ÇALIŞMALARI",
          resultStatus: null,
          description: form.finalStatus,
          checks: const [],
          font: font,
          bold: bold,
        ),
      ],
      _buildSignatureSection(
          "BAKIMI YAPAN",
          form.technicianName,
          form.technicianSignature,
          "MÜŞTERİ ONAYI",
          form.customerName,
          form.customerSignature,
          font,
          bold),
    ];
  }

  List<pw.Widget> _buildFaultTicketContent(
      FaultTicket ticket, pw.Font font, pw.Font bold) {
    return [
      // Arıza Tipi ve Durum
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: _lightBlue,
          border: pw.Border.all(color: _templatePrimaryColor, width: 0.5),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              "TİP: ${ticket.ticketTypeText.toUpperCase()}",
              style: pw.TextStyle(
                  font: bold, fontSize: 10, color: _templatePrimaryColor),
            ),
            pw.Text(
              "DURUM: ${ticket.statusText.toUpperCase()}",
              style: pw.TextStyle(
                  font: bold, fontSize: 10, color: _templatePrimaryColor),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 10),

      // Müşteri ve Cihaz bilgileri
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
              flex: 5,
              child: _buildInfoBox(
                  "MÜŞTERİ BİLGİLERİ",
                  [
                    _row("Kurum:", ticket.customer.name, font, bold),
                    if (ticket.customer.authorizedPerson.isNotEmpty)
                      _row("Yetkili:", ticket.customer.authorizedPerson, font,
                          bold),
                    if (ticket.customer.address.isNotEmpty)
                      _row("Adres:", ticket.customer.address, font, bold),
                    if (ticket.customer.phone.isNotEmpty)
                      _row("Tel:", ticket.customer.phone, font, bold),
                  ],
                  font,
                  bold)),
          pw.SizedBox(width: 10),
          pw.Expanded(
              flex: 4,
              child: _buildInfoBox(
                  "CİHAZ BİLGİLERİ",
                  [
                    _row("Cihaz:", ticket.device.name, font, bold),
                    _row("Seri No:", ticket.device.serialNumber, font, bold),
                    if (ticket.device.model.trim().isNotEmpty)
                      _row("Model:", ticket.device.model, font, bold),
                    _row("Bildirim:", _formatDateTime(ticket.reportDateTime),
                        font, bold),
                  ],
                  font,
                  bold)),
        ],
      ),
      pw.SizedBox(height: 10),

      // Problem Açıklaması
      _buildDynamicTextBox(
          "PROBLEM AÇIKLAMASI", ticket.problemDescription, font, bold,
          minHeight: 60),
      pw.SizedBox(height: 10),

      // Yapılan İşlemler (Eğer tamamlandıysa)
      if (ticket.actionsTaken != null && ticket.actionsTaken!.isNotEmpty) ...[
        _buildDynamicTextBox("ARIZA TESPİTİ VE YAPILAN İŞLEMLER",
            ticket.actionsTaken, font, bold,
            minHeight: 80),
        pw.SizedBox(height: 10),
      ],

      // Cihaz Son Durumu
      if (ticket.finalStatus != null && ticket.finalStatus!.isNotEmpty) ...[
        _buildDynamicTextBox(
            "CİHAZIN SON DURUMU", ticket.finalStatus, font, bold,
            minHeight: 40),
        pw.SizedBox(height: 10),
      ],

      // Tarih bilgileri
      if (ticket.startDateTime != null || ticket.endDateTime != null) ...[
        _buildInfoBox(
            "MÜDAHALE ZAMAN ÇİZELGESİ",
            [
              if (ticket.startDateTime != null)
                _row("Başlangıç:", _formatDateTime(ticket.startDateTime), font,
                    bold),
              if (ticket.endDateTime != null)
                _row("Bitiş:", _formatDateTime(ticket.endDateTime), font, bold),
              if (ticket.startDateTime != null && ticket.endDateTime != null)
                _row(
                    "Süre:",
                    "${_calculateDuration(ticket.startDateTime!, ticket.endDateTime!)} dk",
                    font,
                    bold),
            ],
            font,
            bold),
        pw.SizedBox(height: 10),
      ],

      // İmzalar
      _buildSignatureSection(
        "MÜDAHALE EDEN TEKNİSYEN",
        ticket.technicianName,
        ticket.technicianSignature,
        "BİRİM SORUMLUSU",
        ticket.responsibleName,
        ticket.responsibleSignature,
        font,
        bold,
      ),
    ];
  }

  Future<File> _generateTemplatePdf({
    required String fileName,
    required String category,
    required String title,
    required String formNumber,
    required bool isService,
    required List<pw.Widget> Function(pw.Font, pw.Font) contentBuilder,
  }) async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load("assets/fonts/OpenSans-Regular.ttf");
    final boldFontData =
        await rootBundle.load("assets/fonts/OpenSans-Bold.ttf");
    final font = pw.Font.ttf(fontData);
    final boldFont = pw.Font.ttf(boldFontData);

    // Şablondan başlık rengi al
    final titleColor = _templatePrimaryColor;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 25, vertical: 20),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        _templateCompanyName,
                        style: pw.TextStyle(
                            font: boldFont, fontSize: 14, color: titleColor),
                      ),
                      pw.Text(
                        "Tel: ${_companyInfo?.phone ?? '-'} | ${_companyInfo?.email ?? '-'}",
                        style: pw.TextStyle(
                            font: font, fontSize: 8, color: PdfColors.grey700),
                      ),
                      if (_technician?.fullName.isNotEmpty == true)
                        pw.Text(
                          "Teknisyen: ${_technician!.fullName}",
                          style: pw.TextStyle(
                              font: font,
                              fontSize: 8,
                              color: PdfColors.grey700),
                        ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      title,
                      style: pw.TextStyle(
                          font: boldFont, fontSize: 16, color: titleColor),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: pw.BoxDecoration(
                        border:
                            pw.Border.all(color: PdfColors.grey600, width: 0.5),
                      ),
                      child: pw.Text(
                        "NO: $formNumber",
                        style: pw.TextStyle(font: boldFont, fontSize: 9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.Divider(color: titleColor, thickness: 1),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => pw.Column(
          children: [
            pw.Divider(color: PdfColors.grey400, thickness: 0.5),
            pw.Text(
              "Bu belge dijital olarak oluşturulmuştur.  "
              "Sayfa ${context.pageNumber}/${context.pagesCount}",
              style: pw.TextStyle(
                  font: font, fontSize: 6, color: PdfColors.grey500),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
        build: (context) => contentBuilder(font, boldFont),
      ),
    );
    return _savePdf(pdf, fileName, category: category);
  }

  String _calculateDuration(DateTime start, DateTime end) {
    final diff = end.difference(start);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (hours > 0) {
      return "$hours sa ${minutes.toString().padLeft(2, '0')}";
    }
    return "$minutes";
  }

  // Yardımcı widget metodları
  pw.Widget _buildInfoBox(
      String title, List<pw.Widget> rows, pw.Font font, pw.Font bold,
      {PdfColor boxColor = _corporateHeaderFill,
      PdfColor titleColor = _corporateText}) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: _corporateBorder, width: _cardBorderWidth),
        borderRadius: pw.BorderRadius.circular(_cardRadius),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 7),
            decoration: pw.BoxDecoration(
              color: boxColor,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(_cardRadius),
                topRight: pw.Radius.circular(_cardRadius),
              ),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(font: bold, fontSize: 7.5, color: titleColor),
            ),
          ),
          pw.Divider(
            height: 0,
            thickness: _cardBorderWidth,
            color: _corporateBorder,
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(7),
            child: pw.Column(children: rows),
          ),
        ],
      ),
    );
  }

  pw.Widget _row(String label, String? val, pw.Font font, pw.Font bold,
      {int maxLines = 2}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 50,
            child: pw.Text(label,
                style: pw.TextStyle(
                    font: bold, fontSize: _labelSize, color: _corporateText)),
          ),
          pw.Expanded(
            child: pw.Text(
              val?.trim().isNotEmpty == true ? val!.trim() : '-',
              style: pw.TextStyle(font: font, fontSize: _valueSize),
              maxLines: maxLines,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildContentCard(String title, pw.Widget child, pw.Font bold,
      {PdfColor borderColor = _corporateBorder}) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: borderColor, width: _cardBorderWidth),
        borderRadius: pw.BorderRadius.circular(_cardRadius),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 7),
            decoration: pw.BoxDecoration(
              color: _corporateHeaderFill,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(_cardRadius),
                topRight: pw.Radius.circular(_cardRadius),
              ),
            ),
            child: pw.Text(title,
                style: pw.TextStyle(
                    font: bold, fontSize: 8.2, color: _corporateText)),
          ),
          pw.Divider(height: 0, thickness: 0.75, color: borderColor),
          pw.Padding(padding: const pw.EdgeInsets.all(7), child: child),
        ],
      ),
    );
  }

  pw.Widget _buildChipTextSection(
    String title, {
    required List<String> chips,
    required String? description,
    required String descriptionTitle,
    required pw.Font font,
    required pw.Font bold,
  }) {
    final visibleChips =
        chips.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final hasDescription = description?.trim().isNotEmpty == true;

    return _buildContentCard(
      title,
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (visibleChips.isNotEmpty)
            _buildChipWrap(visibleChips, font, bold)
          else
            pw.Text('-', style: pw.TextStyle(font: font, fontSize: _valueSize)),
          pw.SizedBox(height: 6),
          _buildDescriptionBox(
            descriptionTitle,
            hasDescription ? description!.trim() : '-',
            font,
            bold,
          ),
        ],
      ),
      bold,
    );
  }

  pw.Widget _buildFinalStatusSection({
    required String title,
    required String? resultStatus,
    required String? description,
    required List<String> checks,
    required pw.Font font,
    required pw.Font bold,
  }) {
    final cleanChecks =
        checks.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final cleanResult = resultStatus?.trim();
    final cleanDescription = description?.trim();

    return _buildContentCard(
      title,
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (cleanResult != null && cleanResult.isNotEmpty) ...[
            _buildChipWrap([cleanResult], font, bold),
            pw.SizedBox(height: 6),
          ],
          _buildDescriptionBox(
            'Açıklama',
            cleanDescription?.isNotEmpty == true ? cleanDescription! : '-',
            font,
            bold,
          ),
          if (cleanChecks.isNotEmpty) ...[
            pw.SizedBox(height: 7),
            pw.Column(
              children: cleanChecks
                  .map((item) => _buildCheckRow(item, font, bold))
                  .toList(),
            ),
          ],
        ],
      ),
      bold,
    );
  }

  pw.Widget _buildChipWrap(List<String> items, pw.Font font, pw.Font bold) {
    return pw.Wrap(
      spacing: 4,
      runSpacing: 4,
      children: items
          .map(
            (item) => pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: pw.BoxDecoration(
                color: _corporateFill,
                border: pw.Border.all(color: _corporateBorder, width: 0.7),
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Text(
                item,
                style: pw.TextStyle(
                    font: bold, fontSize: 7.4, color: _corporateText),
              ),
            ),
          )
          .toList(),
    );
  }

  pw.Widget _buildDescriptionBox(
      String title, String text, pw.Font font, pw.Font bold) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(7),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: _corporateBorder, width: 0.65),
        borderRadius: pw.BorderRadius.circular(_cardRadius),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(
                  font: bold, fontSize: 7.4, color: _corporateText)),
          pw.SizedBox(height: 3),
          pw.Text(text,
              style: pw.TextStyle(font: font, fontSize: _valueSize),
              maxLines: 6),
        ],
      ),
    );
  }

  pw.Widget _buildCheckRow(String item, pw.Font font, pw.Font bold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 9,
            height: 9,
            margin: const pw.EdgeInsets.only(top: 1.5, right: 6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _corporateText, width: 0.8),
            ),
            child: pw.Center(
              child: pw.Text('√',
                  style: pw.TextStyle(
                      font: bold, fontSize: 7, color: _corporateText)),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              item,
              style: pw.TextStyle(
                  font: bold, fontSize: 8.4, color: _corporateText),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPartsTable(List<Stock> parts, pw.Font font, pw.Font bold) {
    return pw.Table(
      border: pw.TableBorder.all(color: _corporateBorder, width: 0.65),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _corporateHeaderFill),
          children: ["Malzeme / Parça Adı", "Miktar", "Referans", "Barkod"]
              .map((t) => pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Text(t,
                      style: pw.TextStyle(font: bold, fontSize: 7),
                      textAlign: pw.TextAlign.center)))
              .toList(),
        ),
        ...parts.map((p) => pw.TableRow(
              children: [
                pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Text(p.name.trim().isEmpty ? '-' : p.name.trim(),
                        style: pw.TextStyle(font: font, fontSize: 7))),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Text(p.quantity.toString(),
                        style: pw.TextStyle(font: font, fontSize: 7),
                        textAlign: pw.TextAlign.center)),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Text(
                        p.referenceNo?.trim().isNotEmpty == true
                            ? p.referenceNo!.trim()
                            : '-',
                        style: pw.TextStyle(font: font, fontSize: 7),
                        textAlign: pw.TextAlign.center)),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Text(
                        p.barcode?.trim().isNotEmpty == true
                            ? p.barcode!.trim()
                            : '-',
                        style: pw.TextStyle(font: font, fontSize: 7),
                        textAlign: pw.TextAlign.center)),
              ],
            )),
      ],
    );
  }

  pw.Widget _buildDynamicTextBox(
      String title, String? content, pw.Font font, pw.Font bold,
      {double minHeight = 30}) {
    final text = content ?? '-';
    return pw.Container(
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _borderColor, width: 0.5),
          borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
              width: double.infinity,
              padding:
                  const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              color: _lightBlue,
              child: pw.Text(title,
                  style: pw.TextStyle(
                      font: bold, fontSize: 7, color: _primaryColor))),
          pw.Container(
              width: double.infinity,
              constraints: pw.BoxConstraints(minHeight: minHeight),
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(text,
                  style: pw.TextStyle(font: font, fontSize: _valueSize))),
        ],
      ),
    );
  }

  // Yardımcı formatlama metodları
  Map<String, String> _splitLabeledContent(String? content) {
    final result = <String, String>{};
    if (content == null || content.trim().isEmpty) return result;

    for (final line in content.split('\n')) {
      final index = line.indexOf(':');
      if (index <= 0) continue;
      final key = line.substring(0, index).trim();
      final value = line.substring(index + 1).trim();
      if (key.isNotEmpty && value.isNotEmpty) {
        result[key] = value;
      }
    }
    return result;
  }

  String? _plainWithoutLabels(String? content) {
    if (content == null || content.trim().isEmpty) return null;
    final lines = content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.contains(':'))
        .toList();
    return lines.isEmpty ? null : lines.join('\n');
  }

  String? _labeledValue(Map<String, String> parts, List<String> labels) {
    for (final label in labels) {
      final exact = parts[label];
      if (exact != null && exact.trim().isNotEmpty) return exact.trim();
    }

    final normalizedLabels = labels.map(_normalizeLabel).toSet();
    for (final entry in parts.entries) {
      if (normalizedLabels.contains(_normalizeLabel(entry.key)) &&
          entry.value.trim().isNotEmpty) {
        return entry.value.trim();
      }
    }
    return null;
  }

  pw.Widget? _buildResponsibleInfoBox(
    Object? responsible, {
    required String? fallbackName,
    required pw.Font font,
    required pw.Font bold,
  }) {
    final name = _firstFilled([
      _responsibleName(responsible),
      fallbackName,
    ]);
    final title = _responsibleTitle(responsible);
    final phone = _responsiblePhone(responsible);
    final email = _responsibleEmail(responsible);

    if ([name, title, phone, email].every((value) => value == null)) {
      return null;
    }

    return _buildInfoBox(
      "CİHAZ SORUMLUSU",
      [
        _row("Adı:", name ?? '-', font, bold),
        if (title != null) _row("Unvan:", title, font, bold),
        if (phone != null) _row("Tel:", phone, font, bold),
        if (email != null) _row("E-posta:", email, font, bold),
      ],
      font,
      bold,
    );
  }

  String? _responsibleName(Object? responsible) {
    try {
      return _cleanText((responsible as dynamic).fullName as String?);
    } catch (_) {
      return null;
    }
  }

  String? _responsibleTitle(Object? responsible) {
    try {
      return _cleanText((responsible as dynamic).title as String?);
    } catch (_) {
      return null;
    }
  }

  String? _responsiblePhone(Object? responsible) {
    try {
      return _cleanText((responsible as dynamic).phone as String?);
    } catch (_) {
      return null;
    }
  }

  String? _responsibleEmail(Object? responsible) {
    try {
      return _cleanText((responsible as dynamic).email as String?);
    } catch (_) {
      return null;
    }
  }

  String? _firstFilled(List<String?> values) {
    for (final value in values) {
      final cleaned = _cleanText(value);
      if (cleaned != null) return cleaned;
    }
    return null;
  }

  String? _cleanText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String _normalizeLabel(String value) {
    return value
        .toLowerCase()
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('i̇', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _csvItems(String? content) {
    if (content == null || content.trim().isEmpty) return const [];
    return content
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _formatDate(DateTime? dt) =>
      dt == null ? '-' : DateFormat('dd.MM.yyyy').format(dt);
  String _formatDateTime(DateTime? dt) =>
      dt == null ? '-' : DateFormat('dd.MM.yyyy HH:mm').format(dt);

  Future<File> _savePdf(
    pw.Document pdf,
    String fileName, {
    required String category,
  }) async {
    return ReportFileService.savePdfBytes(
      await pdf.save(),
      fileName: fileName,
      category: category,
    );
  }

  Future<void> _sharePdf(File file) async {
    await PdfShareService.sharePdfFile(
      file.path,
      subject: 'Form PDF',
      shareText: 'Form PDF',
    );
  }

  pw.Widget _buildSignatureSection(String t1, String? n1, String? p1, String t2,
      String? n2, String? p2, pw.Font font, pw.Font bold) {
    return pw.Container(
      height: 70,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _corporateBorder, width: _cardBorderWidth),
        borderRadius: pw.BorderRadius.circular(_cardRadius),
      ),
      child: pw.Row(children: [
        _sigBox(t1, n1, p1, font, bold),
        pw.VerticalDivider(width: 1, color: _corporateBorder),
        _sigBox(t2, n2, p2, font, bold)
      ]),
    );
  }

  pw.Widget _sigBox(String title, String? name, String? signatureBase64,
      pw.Font font, pw.Font bold) {
    pw.Widget imageWidget = pw.SizedBox(height: 30);
    if (signatureBase64 != null) {
      try {
        final image =
            pw.MemoryImage(Uint8List.fromList(base64Decode(signatureBase64)));
        imageWidget = pw.Image(image, fit: pw.BoxFit.contain);
      } catch (e) {
        debugPrint("PDF imza oluşturma hatası: $e");
      }
    }
    return pw.Expanded(
        child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
          pw.Text(title, style: pw.TextStyle(font: bold, fontSize: 8)),
          pw.Container(height: 35, child: imageWidget),
          pw.Text(name ?? '', style: pw.TextStyle(font: font, fontSize: 7))
        ]));
  }
}
