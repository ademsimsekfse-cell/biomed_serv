import 'dart:convert';
import 'dart:io';
import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/models/maintenance_form.dart';
import 'package:biomed_serv/models/service_form.dart';
import 'package:biomed_serv/providers/company_provider.dart';
import 'package:biomed_serv/providers/maintenance_form_provider.dart';
import 'package:biomed_serv/providers/report_template_provider.dart';
import 'package:biomed_serv/providers/service_form_provider.dart';
import 'package:biomed_serv/providers/technician_provider.dart';
import 'package:biomed_serv/screens/pdf_preview_screen.dart';
import 'package:biomed_serv/services/pdf_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class DeviceServiceHistoryScreen extends StatelessWidget {
  final Device device;

  const DeviceServiceHistoryScreen({
    super.key,
    required this.device,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cihaz Servis Geçmişi'),
            Text(
              device.name,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: Consumer2<ServiceFormProvider, MaintenanceFormProvider>(
        builder: (context, serviceProvider, maintenanceProvider, child) {
          // Cihaza ait servis formlarını filtrele
          final serviceForms = serviceProvider.forms
              .where((form) => form.device.key == device.key)
              .toList();

          // Cihaza ait bakım formlarını filtrele
          final maintenanceForms = maintenanceProvider.forms
              .where((form) => form.device.key == device.key)
              .toList();

          // Tüm kayıtları birleştir ve tarihe göre sırala (yeniden eskiye)
          final allRecords = <HistoryRecord>[
            ...serviceForms.map((form) => HistoryRecord.fromServiceForm(form)),
            ...maintenanceForms
                .map((form) => HistoryRecord.fromMaintenanceForm(form)),
          ];

          allRecords.sort((a, b) => b.date.compareTo(a.date));

          if (allRecords.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bu cihaz için henüz kayıt bulunmamaktadır.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Servis veya bakım formu oluşturun.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: allRecords.length,
            itemBuilder: (context, index) {
              final record = allRecords[index];
              return _buildHistoryCard(context, record);
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, HistoryRecord record) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final bool isService = record.type == HistoryType.service;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 1,
      child: InkWell(
        onTap: () => _showDetails(context, record),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // İkon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isService ? Colors.red.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isService ? Icons.build : Icons.settings,
                  size: 22,
                  color:
                      isService ? Colors.red.shade700 : Colors.green.shade700,
                ),
              ),
              const SizedBox(width: 10),
              // Bilgiler
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Üst satır: Tip + Form No
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isService
                                ? Colors.red.shade100
                                : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isService ? 'SERVİS' : 'BAKIM',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isService
                                  ? Colors.red.shade700
                                  : Colors.green.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            record.formNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Alt satır: Tarih + Parça + Açıklama
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                        children: [
                          TextSpan(text: dateFormat.format(record.date)),
                          if (record.partsCount > 0) ...[
                            const TextSpan(text: ' • '),
                            TextSpan(text: '${record.partsCount} parça'),
                          ],
                          if (record.description != null &&
                              record.description!.isNotEmpty) ...[
                            const TextSpan(text: ' • '),
                            TextSpan(
                              text: record.description!,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontStyle: FontStyle.italic,
                              ),
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
              // Sağ: Popup Menu
              PopupMenuButton<String>(
                onSelected: (value) => _onMenuSelected(context, value, record),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(Icons.visibility, size: 18),
                        SizedBox(width: 8),
                        Text('Detaylar'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'pdf',
                    child: Row(
                      children: [
                        Icon(Icons.picture_as_pdf, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('PDF Göster'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onMenuSelected(
      BuildContext context, String value, HistoryRecord record) {
    switch (value) {
      case 'view':
        _showDetails(context, record);
        break;
      case 'pdf':
        _generatePdf(context, record);
        break;
    }
  }

  void _showDetails(BuildContext context, HistoryRecord record) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: record.type == HistoryType.service
                              ? Colors.red.shade100
                              : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          record.type == HistoryType.service
                              ? 'SERVİS FORMU'
                              : 'BAKIM FORMU',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: record.type == HistoryType.service
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('Form No', record.formNumber),
                  _buildDetailRow('Tarih', dateFormat.format(record.date)),
                  _buildDetailRow('Müşteri', record.customerName),
                  _buildDetailRow('Teknisyen', record.technicianName ?? '-'),
                  if (record is ServiceHistoryRecord) ...[
                    if (record.problemTypes.isNotEmpty)
                      _buildDetailRow(
                          'Sorun Tipleri', record.problemTypes.join(', ')),
                    if (record.finalStatus != null)
                      _buildDetailRow('Son Durum', record.finalStatus!),
                  ],
                  if (record is MaintenanceHistoryRecord) ...[
                    _buildDetailRow('Bakım Periyodu', record.maintenancePeriod),
                    if (record.actionsTaken.isNotEmpty)
                      _buildDetailRow(
                          'İşlemler', record.actionsTaken.join(', ')),
                  ],
                  if (record.description != null &&
                      record.description!.isNotEmpty)
                    _buildDetailRow('Açıklama', record.description!),
                  if (record.finalStatus != null &&
                      record.finalStatus!.isNotEmpty)
                    _buildDetailRow('Son Durum', record.finalStatus!),
                  const SizedBox(height: 16),
                  if (record.hasTechnicianSignature ||
                      record.hasCustomerSignature) ...[
                    const Text(
                      'İmzalar',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (record.hasTechnicianSignature)
                          Expanded(
                            child: Column(
                              children: [
                                Container(
                                  height: 80,
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Image.memory(
                                    base64Decode(record.technicianSignature!),
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Teknisyen',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        if (record.hasTechnicianSignature &&
                            record.hasCustomerSignature)
                          const SizedBox(width: 16),
                        if (record.hasCustomerSignature)
                          Expanded(
                            child: Column(
                              children: [
                                Container(
                                  height: 80,
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Image.memory(
                                    base64Decode(record.customerSignature!),
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Müşteri',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _generatePdf(context, record);
                      },
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('PDF GÖSTER'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePdf(BuildContext context, HistoryRecord record) async {
    final pdfService = PdfService();
    final reportTemplateProvider =
        Provider.of<ReportTemplateProvider>(context, listen: false);
    final companyProvider =
        Provider.of<CompanyProvider>(context, listen: false);
    final technicianProvider =
        Provider.of<TechnicianProvider>(context, listen: false);

    try {
      pdfService.setCompanyInfo(companyProvider.companyInfo);
      pdfService.setTechnician(technicianProvider.currentTechnician);
      if (record is ServiceHistoryRecord) {
        pdfService.setTemplate(reportTemplateProvider.defaultServiceTemplate);
        // ServiceForm'u bul ve PDF oluştur
        final serviceProvider =
            Provider.of<ServiceFormProvider>(context, listen: false);
        final form = serviceProvider.forms
            .firstWhere((f) => f.formNumber == record.formNumber);
        var pdfFile = form.pdfPath != null && form.pdfPath!.isNotEmpty
            ? File(form.pdfPath!)
            : await pdfService.generateServicePdf(form);
        if (!await pdfFile.exists()) {
          pdfFile = await pdfService.generateServicePdf(form);
        }
        form.pdfPath = pdfFile.path;
        await serviceProvider.updateForm(form);
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
              filePath: pdfFile.path,
              title: 'Servis Formu Önizleme',
              shareText: 'Servis Formu',
            ),
          ),
        );
      } else if (record is MaintenanceHistoryRecord) {
        pdfService
            .setTemplate(reportTemplateProvider.defaultMaintenanceTemplate);
        // MaintenanceForm'u bul ve PDF oluştur
        final maintenanceProvider =
            Provider.of<MaintenanceFormProvider>(context, listen: false);
        final form = maintenanceProvider.forms
            .firstWhere((f) => f.formNumber == record.formNumber);
        var pdfFile = form.pdfPath != null && form.pdfPath!.isNotEmpty
            ? File(form.pdfPath!)
            : await pdfService.generateMaintenancePdf(form);
        if (!await pdfFile.exists()) {
          pdfFile = await pdfService.generateMaintenancePdf(form);
        }
        form.pdfPath = pdfFile.path;
        await maintenanceProvider.updateForm(form);
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
              filePath: pdfFile.path,
              title: 'Bakım Formu Önizleme',
              shareText: 'Bakım Formu',
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF oluşturulurken hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Yardımcı sınıflar
enum HistoryType { service, maintenance }

abstract class HistoryRecord {
  final HistoryType type;
  final String formNumber;
  final DateTime date;
  final String customerName;
  final String? technicianName;
  final String? description;
  final String? finalStatus;
  final int partsCount;
  final String? technicianSignature;
  final String? customerSignature;

  bool get hasTechnicianSignature =>
      technicianSignature != null && technicianSignature!.isNotEmpty;
  bool get hasCustomerSignature =>
      customerSignature != null && customerSignature!.isNotEmpty;

  HistoryRecord({
    required this.type,
    required this.formNumber,
    required this.date,
    required this.customerName,
    this.technicianName,
    this.description,
    this.finalStatus,
    required this.partsCount,
    this.technicianSignature,
    this.customerSignature,
  });

  factory HistoryRecord.fromServiceForm(ServiceForm form) {
    return ServiceHistoryRecord(
      formNumber: form.formNumber,
      date: form.createdAt,
      customerName: form.customer.name,
      technicianName: form.technicianName,
      description: form.problemDescription,
      finalStatus: form.finalStatus,
      partsCount: form.partsUsed.length,
      technicianSignature: form.technicianSignature,
      customerSignature: form.customerSignature,
      problemTypes: form.problemTypes,
    );
  }

  factory HistoryRecord.fromMaintenanceForm(MaintenanceForm form) {
    return MaintenanceHistoryRecord(
      formNumber: form.formNumber,
      date: form.createdAt,
      customerName: form.customer.name,
      technicianName: form.technicianName,
      description: form.notes,
      finalStatus: form.finalStatus,
      partsCount: form.partsUsed.length,
      technicianSignature: form.technicianSignature,
      customerSignature: form.customerSignature,
      maintenancePeriod: form.maintenancePeriod,
      actionsTaken: form.actionsTaken,
    );
  }
}

class ServiceHistoryRecord extends HistoryRecord {
  final List<String> problemTypes;

  ServiceHistoryRecord({
    required super.formNumber,
    required super.date,
    required super.customerName,
    super.technicianName,
    super.description,
    super.finalStatus,
    required super.partsCount,
    super.technicianSignature,
    super.customerSignature,
    required this.problemTypes,
  }) : super(
          type: HistoryType.service,
        );
}

class MaintenanceHistoryRecord extends HistoryRecord {
  final String maintenancePeriod;
  final List<String> actionsTaken;

  MaintenanceHistoryRecord({
    required super.formNumber,
    required super.date,
    required super.customerName,
    super.technicianName,
    super.description,
    super.finalStatus,
    required super.partsCount,
    super.technicianSignature,
    super.customerSignature,
    required this.maintenancePeriod,
    required this.actionsTaken,
  }) : super(
          type: HistoryType.maintenance,
        );
}
