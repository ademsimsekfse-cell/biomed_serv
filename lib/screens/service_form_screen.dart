import 'dart:convert';
import 'dart:io';

import 'package:biomed_serv/models/customer.dart';
import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/models/fault_ticket.dart';
import 'package:biomed_serv/models/service_form.dart';
import 'package:biomed_serv/models/stock.dart';
import 'package:biomed_serv/providers/customer_provider.dart';
import 'package:biomed_serv/providers/device_provider.dart';
import 'package:biomed_serv/providers/fault_ticket_provider.dart';
import 'package:biomed_serv/providers/company_provider.dart';
import 'package:biomed_serv/providers/report_template_provider.dart';
import 'package:biomed_serv/providers/service_form_provider.dart';
import 'package:biomed_serv/providers/stock_provider.dart';
import 'package:biomed_serv/providers/technician_provider.dart';
import 'package:biomed_serv/screens/pdf_preview_screen.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:biomed_serv/services/pdf_service.dart';
import 'package:biomed_serv/services/technical_assignment_service.dart';
import 'package:biomed_serv/utils/turkish_text_formatter.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';

/// Servis Formu Ekrani
class ServiceFormScreen extends StatefulWidget {
  final Device? initialDevice;
  final Customer? initialInstitution;
  final FaultTicket? initialTicket;

  const ServiceFormScreen({
    super.key,
    this.initialDevice,
    this.initialInstitution,
    this.initialTicket,
  });

  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  static const Color _primaryColor = Color(0xFF274C77);
  static const Color _accentColor = Color(0xFF2A9D8F);
  static const Color _surfaceColor = Color(0xFFF6F8FB);

  final _formKey = GlobalKey<FormState>();
  final _pdfService = PdfService();
  bool _isLoading = false;

  // State
  Customer? _selectedInstitution;
  Device? _selectedDevice;
  final List<_UsedPart> _usedSpareParts = [];
  DateTime? _problemDateTime, _mudahaleDateTime, _cozumDateTime;
  final Set<String> _problemTypes = {};
  final Set<String> _actionsTaken = {};
  String? _resultStatus;
  final Set<String> _validationChecks = {};

  // Controllers
  final _serialLookupController = TextEditingController();
  final _problemDescController = TextEditingController();
  final _actionsController = TextEditingController();
  final _finalStatusController = TextEditingController();
  final _servisiYapanAdSoyadController = TextEditingController();
  final _musteriYetkilisiAdSoyadController = TextEditingController();
  final _techSignatureController =
      SignatureController(penStrokeWidth: 2, penColor: Colors.black);
  final _customerSignatureController =
      SignatureController(penStrokeWidth: 2, penColor: Colors.black);

  // Constants
  final List<String> _problemTypesList = [
    'Ariza',
    'Periyodik Bakim',
    'Montaj',
    'Egitim',
    'Kurulum',
    'Diger'
  ];
  final List<String> _actionsTakenList = ['Bilgi Verildi', 'Aciklama Yapildi'];
  final List<String> _resultStatuses = [
    'Cihaz Aktif',
    'Cihaz Pasif',
    'Parca Bekleniyor'
  ];
  final List<String> _validationChecksList = [
    'Gunluk Bakim Yapildi',
    'Kontrol Calismasi Yapildi',
    'Tekrarlanabilirlik Calisildi',
    'Hasta Calisildi',
    'Cihaz Aktif Teslim Edildi'
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _problemDateTime = now;
    _mudahaleDateTime = now;
    _cozumDateTime = now;
    _serialLookupController.addListener(_refreshFormStatus);
    _problemDescController.addListener(_refreshFormStatus);
    _finalStatusController.addListener(_refreshFormStatus);
    _techSignatureController.addListener(_refreshFormStatus);
    _customerSignatureController.addListener(_refreshFormStatus);

    // Baslangic degerleri
    if (widget.initialInstitution != null) {
      _selectedInstitution = widget.initialInstitution;
    }

    if (widget.initialTicket != null) {
      final ticket = widget.initialTicket!;
      _selectedInstitution = ticket.customer;
      _selectedDevice = ticket.device;
      _problemDateTime = ticket.reportDateTime;
      _mudahaleDateTime = ticket.startDateTime ?? now;
      _problemDescController.text = ticket.problemDescription;
      _musteriYetkilisiAdSoyadController.text =
          ticket.responsibleName ?? ticket.customer.authorizedPerson;
      _problemTypes.add(ticket.ticketTypeText);
      if (ticket.actionsTaken?.isNotEmpty == true) {
        _actionsController.text = ticket.actionsTaken!;
      }
      if (ticket.finalStatus?.isNotEmpty == true) {
        _finalStatusController.text = ticket.finalStatus!;
      }
    }

    if (widget.initialDevice != null) {
      _selectedDevice = widget.initialDevice;
      if (widget.initialDevice!.customer is Customer) {
        _selectedInstitution = widget.initialDevice!.customer as Customer;
      }
      if (_selectedInstitution != null) {
        _musteriYetkilisiAdSoyadController.text =
            _selectedInstitution!.authorizedPerson;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncSerialLookupWithSelection();
      _applySelectionPrefills(
        device: _selectedDevice,
        customer: _selectedInstitution,
      );
    });
  }

  void _applySelectionPrefills({
    Device? device,
    Customer? customer,
  }) {
    final fallbackCustomer = customer ??
        (device?.customer is Customer ? device!.customer as Customer : null);

    if (fallbackCustomer != null) {
      _musteriYetkilisiAdSoyadController.text =
          fallbackCustomer.authorizedPerson;
    }

    final assignmentService =
        Provider.of<TechnicalAssignmentService>(context, listen: false);
    final assignedTechnician = device != null
        ? assignmentService.assignmentForDevice(device)
        : (fallbackCustomer != null
            ? assignmentService.assignmentForCustomer(fallbackCustomer)
            : null);

    final currentTechnician =
        Provider.of<TechnicianProvider>(context, listen: false)
            .currentTechnician;
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    final preferredTechnicianName = isDesktop
        ? assignedTechnician?.technicianName ??
            currentTechnician?.fullName ??
            ''
        : currentTechnician?.fullName ?? '';

    if (preferredTechnicianName.isNotEmpty) {
      _servisiYapanAdSoyadController.text = preferredTechnicianName;
    }
  }

  @override
  void dispose() {
    _serialLookupController.removeListener(_refreshFormStatus);
    _problemDescController.removeListener(_refreshFormStatus);
    _finalStatusController.removeListener(_refreshFormStatus);
    _techSignatureController.removeListener(_refreshFormStatus);
    _customerSignatureController.removeListener(_refreshFormStatus);
    _serialLookupController.dispose();
    _problemDescController.dispose();
    _actionsController.dispose();
    _finalStatusController.dispose();
    _servisiYapanAdSoyadController.dispose();
    _musteriYetkilisiAdSoyadController.dispose();
    _techSignatureController.dispose();
    _customerSignatureController.dispose();
    super.dispose();
  }

  void _refreshFormStatus() {
    if (mounted) setState(() {});
  }

  void _syncSerialLookupWithSelection() {
    final serial = _selectedDevice?.serialNumber.trim();
    if (serial != null &&
        serial.isNotEmpty &&
        _serialLookupController.text.trim() != serial) {
      _serialLookupController.text = serial;
    }
  }

  void _selectDeviceFromSerial(Device device, {bool updateSerialField = true}) {
    final customer =
        device.customer is Customer ? device.customer as Customer : null;
    setState(() {
      _selectedInstitution = customer;
      _selectedDevice = device;
    });
    if (updateSerialField &&
        _serialLookupController.text.trim() != device.serialNumber.trim()) {
      _serialLookupController.text = device.serialNumber;
    }
    _applySelectionPrefills(device: device, customer: customer);
  }

  void _handleSerialLookupChanged(String value, List<Device> devices) {
    final match = _findDeviceBySerial(devices, value);
    if (match == null || _sameDevice(match, _selectedDevice)) return;
    _selectDeviceFromSerial(match, updateSerialField: false);
  }

  void _addOrMergeUsedPart(_UsedPart candidate) {
    setState(() {
      final existingIndex = _usedSpareParts.indexWhere((part) {
        if (part.source != candidate.source) return false;
        if (part.source == _UsedPartSource.stock) {
          return part.stock.key == candidate.stock.key;
        }
        return part.stock.name.trim().toLowerCase() ==
                candidate.stock.name.trim().toLowerCase() &&
            (part.stock.referenceNo ?? '').trim().toLowerCase() ==
                (candidate.stock.referenceNo ?? '').trim().toLowerCase() &&
            (part.stock.barcode ?? '').trim().toLowerCase() ==
                (candidate.stock.barcode ?? '').trim().toLowerCase();
      });

      if (existingIndex >= 0) {
        final existing = _usedSpareParts[existingIndex];
        _usedSpareParts[existingIndex] = _UsedPart(
          stock: existing.stock,
          quantity: existing.quantity + candidate.quantity,
          source: existing.source,
        );
      } else {
        _usedSpareParts.add(candidate);
      }
    });
  }

  Future<void> _saveAndShareForm() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackbar('Lutfen * ile isaretli zorunlu alanlari doldurun.');
      return;
    }

    final technicianProvider =
        Provider.of<TechnicianProvider>(context, listen: false);
    final serviceFormProvider =
        Provider.of<ServiceFormProvider>(context, listen: false);
    final faultTicketProvider =
        Provider.of<FaultTicketProvider>(context, listen: false);
    final reportTemplateProvider =
        Provider.of<ReportTemplateProvider>(context, listen: false);
    final companyProvider =
        Provider.of<CompanyProvider>(context, listen: false);
    final technician = technicianProvider.currentTechnician;

    if (_selectedInstitution == null ||
        _selectedDevice == null ||
        technician == null) {
      _showErrorSnackbar("Kurum, Cihaz veya Teknisyen bilgisi eksik.");
      return;
    }

    // Imza kontrolu
    final techSignBytes = await _techSignatureController.toPngBytes();
    final custSignBytes = await _customerSignatureController.toPngBytes();
    if (!mounted) return;

    if (techSignBytes == null || techSignBytes.isEmpty) {
      _showErrorSnackbar('Teknisyen imzasi zorunludur.');
      return;
    }
    if (custSignBytes == null || custSignBytes.isEmpty) {
      _showErrorSnackbar('Musteri imzasi zorunludur.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Stok islemleri
      final stockProvider = Provider.of<StockProvider>(context, listen: false);
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final partSnapshotsBox = dbService.serviceFormPartsBox;
      final savedParts = HiveList<Stock>(partSnapshotsBox);

      for (final part in _usedSpareParts) {
        final stock = part.stock;
        final usedPartSnapshot = Stock(
          name: stock.name,
          quantity: part.quantity,
          barcode: stock.barcode,
          referenceNo: stock.referenceNo,
          criticalStockThreshold: stock.criticalStockThreshold,
        );

        await partSnapshotsBox.add(usedPartSnapshot);
        savedParts.add(usedPartSnapshot);
      }

      // Form olustur
      final actionsTakenText = _composeActionsTakenText();
      final finalStatusText = _composeFinalStatusText();
      final newForm = ServiceForm(
        formNumber:
            "SRV-${DateTime.now().microsecondsSinceEpoch.toString().substring(8)}",
        createdAt: DateTime.now(),
        customer: _selectedInstitution!,
        device: _selectedDevice!,
        problemDescription:
            normalizeDescriptionText(_problemDescController.text).isEmpty
                ? null
                : normalizeDescriptionText(_problemDescController.text),
        actionsTaken: actionsTakenText,
        finalStatus: finalStatusText,
        problemTypes: _problemTypes.toList(),
        resultStatus: _resultStatus,
        problemDateTime: _problemDateTime,
        interventionDateTime: _mudahaleDateTime,
        solutionDateTime: _cozumDateTime,
        partsUsed: savedParts,
        technicianSignature: base64Encode(techSignBytes),
        customerSignature: base64Encode(custSignBytes),
        technicianName: _servisiYapanAdSoyadController.text.isEmpty
            ? null
            : _servisiYapanAdSoyadController.text,
        customerName: _musteriYetkilisiAdSoyadController.text.isEmpty
            ? null
            : _musteriYetkilisiAdSoyadController.text,
        sourceTicketNumber: widget.initialTicket?.ticketNumber,
      );

      _pdfService.setTemplate(reportTemplateProvider.defaultServiceTemplate);
      _pdfService.setCompanyInfo(companyProvider.companyInfo);
      _pdfService.setTechnician(technician);

      // PDF olustur ve paylasmadan once onizleme ac
      final pdfFile = await _pdfService.generateServicePdf(newForm);
      if (!await pdfFile.exists() || await pdfFile.length() == 0) {
        throw Exception('Servis formu PDF dosyası oluşturulamadı.');
      }
      newForm.pdfPath = pdfFile.path;
      await serviceFormProvider.addForm(newForm);

      for (final part in _usedSpareParts) {
        final stockKey = part.stock.key;
        if (part.source == _UsedPartSource.stock && stockKey is int) {
          await stockProvider.useStock(stockKey, part.quantity);
        }
      }

      final sourceTicketKey = widget.initialTicket?.key;
      if (sourceTicketKey is int) {
        try {
          await faultTicketProvider.completeTicket(
            sourceTicketKey,
            actionsTaken: actionsTakenText ?? 'Servis formu ile tamamlandi.',
            finalStatus: finalStatusText ?? 'Servis formu ile tamamlandi.',
            technicianSignature: base64Encode(techSignBytes),
            responsibleName: _musteriYetkilisiAdSoyadController.text.trim(),
            responsibleSignature: base64Encode(custSignBytes),
            serviceFormNumber: newForm.formNumber,
          );
        } catch (error) {
          debugPrint('Arıza kaydı servis formuna bağlanamadı: $error');
        }
      }

      if (!mounted) return;
      _showSuccessSnackbar('Form ve PDF arşive kaydedildi.');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
              filePath: pdfFile.path,
              title: 'Servis Formu Onizleme',
              shareText: 'Servis Formu',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Form veya PDF kaydedilemedi: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _composeActionsTakenText() {
    final lines = <String>[];
    if (_actionsTaken.isNotEmpty) {
      lines.add('Secilen islemler: ${_actionsTaken.join(', ')}');
    }

    final note = _actionsController.text.trim();
    if (note.isNotEmpty) {
      lines.add(
        'Aciklama ve oneriler: ${normalizeDescriptionText(note)}',
      );
    }

    return lines.isEmpty ? null : lines.join('\n');
  }

  String? _composeFinalStatusText() {
    final lines = <String>[];
    if (_resultStatus != null && _resultStatus!.trim().isNotEmpty) {
      lines.add('Sonuc durumu: $_resultStatus');
    }

    final note = _finalStatusController.text.trim();
    if (note.isNotEmpty) {
      lines.add(
        'Son durum aciklamasi: ${normalizeDescriptionText(note)}',
      );
    }

    if (_validationChecks.isNotEmpty) {
      lines.add('Dogrulama calismalari: ${_validationChecks.join(', ')}');
    }

    return lines.isEmpty ? null : lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Servis Formu'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.green.shade600],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.shade400.withValues(alpha: 0.4),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.save_alt, color: Colors.white),
              onPressed: _saveAndShareForm,
              tooltip: 'Kaydet ve Paylas',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('PDF Olusturuluyor...'),
                ],
              ),
            )
          : Container(
              color: _surfaceColor,
              child: SafeArea(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 920),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildServiceHeroHeader(),
                            const SizedBox(height: 12),
                            _buildCompletionStrip(),
                            const SizedBox(height: 16),
                            _buildPremiumSection(
                              icon: Icons.apartment,
                              title: 'Musteri ve Cihaz',
                              subtitle:
                                  'Servisin bagli oldugu kurum ve cihaz secimi.',
                              child: _buildCustomerInfoCardContent(),
                            ),
                            const SizedBox(height: 16),
                            _buildPremiumSection(
                              icon: Icons.schedule,
                              title: 'Servis Zamanlari',
                              subtitle:
                                  'Bildirim, mudahale ve cozum zamanlarini kaydedin.',
                              child: _buildServiceTimeCardContent(),
                            ),
                            const SizedBox(height: 16),
                            _buildPremiumSection(
                              icon: Icons.report_problem_outlined,
                              title: 'Problem Detaylari',
                              subtitle: 'Problem tipi ve teknik aciklama.',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildSelectionGroup(
                                    title: "Problem Tipi",
                                    items: _problemTypesList,
                                    selectedItems: _problemTypes,
                                    onItemSelected: (item) => setState(() =>
                                        _problemTypes.contains(item)
                                            ? _problemTypes.remove(item)
                                            : _problemTypes.add(item)),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _problemDescController,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    inputFormatters: const [
                                      TurkishUpperCaseTextFormatter(),
                                    ],
                                    decoration: _inputDecoration(
                                      label: 'Problem Aciklamasi *',
                                      icon: Icons.notes,
                                    ),
                                    maxLines: 3,
                                    validator: (v) => v!.isEmpty
                                        ? 'Bu alan zorunludur'
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildPremiumSection(
                              icon: Icons.handyman_outlined,
                              title: 'Yapilan Islemler',
                              subtitle:
                                  'Uygulanan islem, oneri ve teknik notlar.',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildSelectionGroup(
                                    items: _actionsTakenList,
                                    selectedItems: _actionsTaken,
                                    onItemSelected: (item) => setState(() =>
                                        _actionsTaken.contains(item)
                                            ? _actionsTaken.remove(item)
                                            : _actionsTaken.add(item)),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _actionsController,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    inputFormatters: const [
                                      TurkishUpperCaseTextFormatter(),
                                    ],
                                    decoration: _inputDecoration(
                                      label: 'Ek Aciklamalar ve Oneriler',
                                      icon: Icons.edit_note,
                                    ),
                                    maxLines: 3,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildPremiumSection(
                              icon: Icons.inventory_2_outlined,
                              title: 'Kullanilan Parcalar',
                              subtitle:
                                  'Stoktan kullanilan parcalar ve kalan adetler.',
                              child: _buildUsedPartsSection(),
                            ),
                            const SizedBox(height: 16),
                            _buildPremiumSection(
                              icon: Icons.fact_check_outlined,
                              title: 'Sonuc ve Dogrulama',
                              subtitle:
                                  'Teslim durumu, son not ve kontrol calismalari.',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildSelectionGroup(
                                    items: _resultStatuses,
                                    singleSelection: true,
                                    currentSelection: _resultStatus,
                                    onItemSelected: (item) =>
                                        setState(() => _resultStatus = item),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _finalStatusController,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    inputFormatters: const [
                                      TurkishUpperCaseTextFormatter(),
                                    ],
                                    decoration: _inputDecoration(
                                      label: 'Son Durum Aciklamasi',
                                      icon: Icons.task_alt,
                                    ),
                                    maxLines: 2,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildValidationChecks(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildPremiumSection(
                              icon: Icons.draw_outlined,
                              title: 'Imzalar',
                              subtitle: 'Teknisyen ve musteri onayi.',
                              child: Column(
                                children: [
                                  _buildSignatureArea(
                                    context,
                                    "Servisi Yapan",
                                    _techSignatureController,
                                    _servisiYapanAdSoyadController,
                                    false,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildSignatureArea(
                                    context,
                                    "Musteri Yetkilisi",
                                    _customerSignatureController,
                                    _musteriYetkilisiAdSoyadController,
                                    true,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 54,
                              child: FilledButton.icon(
                                icon: const Icon(Icons.picture_as_pdf),
                                label: const Text('Kaydet ve PDF Paylas'),
                                onPressed: _saveAndShareForm,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildServiceHeroHeader() {
    final deviceLabel = _selectedDevice == null
        ? 'Cihaz secilmedi'
        : '${_selectedDevice!.name} - ${_selectedDevice!.serialNumber}';

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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: const Icon(Icons.medical_services_outlined,
                color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Yeni Servis Formu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  deviceLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

  Widget _buildCompletionStrip() {
    final items = [
      _FormStepStatus(
        label: 'Kurum',
        isDone: _selectedInstitution != null,
        icon: Icons.apartment,
      ),
      _FormStepStatus(
        label: 'Cihaz',
        isDone: _selectedDevice != null,
        icon: Icons.devices,
      ),
      _FormStepStatus(
        label: 'Problem',
        isDone: _problemDescController.text.trim().isNotEmpty,
        icon: Icons.report_problem_outlined,
      ),
      _FormStepStatus(
        label: 'Sonuc',
        isDone: _resultStatus != null ||
            _finalStatusController.text.trim().isNotEmpty,
        icon: Icons.fact_check_outlined,
      ),
      _FormStepStatus(
        label: 'Imzalar',
        isDone: _techSignatureController.isNotEmpty &&
            _customerSignatureController.isNotEmpty,
        icon: Icons.draw_outlined,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items
            .map(
              (item) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: item.isDone
                      ? _accentColor.withValues(alpha: 0.10)
                      : _surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: item.isDone
                        ? _accentColor.withValues(alpha: 0.35)
                        : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.isDone ? Icons.check_circle : item.icon,
                      size: 16,
                      color: item.isDone ? _accentColor : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color:
                            item.isDone ? _accentColor : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildPremiumSection({
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
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: _accentColor, size: 21),
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
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon, color: _primaryColor),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _primaryColor, width: 2),
      ),
      filled: true,
      fillColor: _surfaceColor,
    );
  }

  bool _sameCustomer(Customer? a, Customer? b) {
    if (a == null || b == null) return false;
    if (a.key != null && b.key != null) return a.key == b.key;
    return a.name.trim().toLowerCase() == b.name.trim().toLowerCase() &&
        a.phone.trim() == b.phone.trim();
  }

  bool _sameDevice(Device? a, Device? b) {
    if (a == null || b == null) return false;
    if (a.key != null && b.key != null) return a.key == b.key;
    return a.serialNumber.trim().toLowerCase() ==
            b.serialNumber.trim().toLowerCase() &&
        a.name.trim().toLowerCase() == b.name.trim().toLowerCase();
  }

  Device? _findDeviceBySerial(List<Device> devices, String serial) {
    final normalized = serial.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final device in devices) {
      if (device.serialNumber.trim().toLowerCase() == normalized) {
        return device;
      }
    }
    return null;
  }

  List<Device> _serialLookupSuggestions(List<Device> devices, String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.length < 2) return const [];
    final matches = devices.where((device) {
      return device.serialNumber.trim().toLowerCase().contains(normalized) ||
          device.name.trim().toLowerCase().contains(normalized) ||
          device.model.trim().toLowerCase().contains(normalized);
    }).toList();
    matches.sort(
      (a, b) => a.serialNumber.length.compareTo(b.serialNumber.length),
    );
    return matches.take(4).toList();
  }

  Customer? _resolveCustomer(Customer? selected, List<Customer> customers) {
    if (selected == null) return null;
    for (final customer in customers) {
      if (_sameCustomer(selected, customer)) return customer;
    }
    return null;
  }

  Device? _resolveDevice(Device? selected, List<Device> devices) {
    if (selected == null) return null;
    for (final device in devices) {
      if (_sameDevice(selected, device)) return device;
    }
    return null;
  }

  List<Device> _devicesForCustomer(
    List<Device> devices,
    Customer selectedCustomer,
  ) {
    return devices.where((device) {
      final customer = device.customer;
      return customer is Customer && _sameCustomer(customer, selectedCustomer);
    }).toList();
  }

  Widget _buildInlineNotice({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color.withValues(alpha: 0.95),
                fontSize: 12,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationChecks() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dogrulama Calismalari',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          ..._validationChecksList.map(
            (check) => CheckboxListTile(
              title: Text(check),
              value: _validationChecks.contains(check),
              onChanged: (val) => setState(() => val == true
                  ? _validationChecks.add(check)
                  : _validationChecks.remove(check)),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSerialLookupCard(List<Device> devices) {
    final query = _serialLookupController.text.trim();
    final exactMatch = _findDeviceBySerial(devices, query);
    final suggestions = _serialLookupSuggestions(devices, query)
        .where((device) => !_sameDevice(device, exactMatch))
        .toList();
    final selectedCustomer = _selectedInstitution ??
        (_selectedDevice?.customer is Customer
            ? _selectedDevice!.customer as Customer
            : null);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _accentColor.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _serialLookupController,
            textCapitalization: TextCapitalization.characters,
            decoration: _inputDecoration(
              label: 'Seri No ile hizli bul',
              icon: Icons.qr_code_2,
            ).copyWith(
              helperText:
                  'Seri no yazinca kurum, cihaz ve sorumlu bilgisi otomatik dolar.',
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Temizle',
                      onPressed: () {
                        setState(() {
                          _serialLookupController.clear();
                        });
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
            onChanged: (value) => _handleSerialLookupChanged(value, devices),
          ),
          if (_selectedDevice != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _accentColor.withValues(alpha: 0.18)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.check_circle_outline,
                        color: _accentColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_selectedDevice!.name} - ${_selectedDevice!.serialNumber}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selectedCustomer == null
                              ? 'Kurum atanmamis'
                              : selectedCustomer.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.blueGrey.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else if (query.isNotEmpty && exactMatch == null) ...[
            const SizedBox(height: 10),
            _buildInlineNotice(
              icon: Icons.search_off,
              color: Colors.orange,
              text: 'Bu seri no ile kayitli cihaz bulunamadi.',
            ),
          ],
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: suggestions
                  .map(
                    (device) => ActionChip(
                      avatar: const Icon(Icons.devices, size: 16),
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: Text(
                          '${device.serialNumber} - ${device.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      onPressed: () => _selectDeviceFromSerial(device),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomerInfoCardContent() {
    return Consumer2<CustomerProvider, DeviceProvider>(
      builder: (context, customerProvider, deviceProvider, child) {
        final selectedInstitution = _resolveCustomer(
          _selectedInstitution,
          customerProvider.customers,
        );
        final institutionDevices = selectedInstitution == null
            ? <Device>[]
            : _devicesForCustomer(deviceProvider.devices, selectedInstitution);
        final selectedDevice =
            _resolveDevice(_selectedDevice, institutionDevices);
        final responsible = selectedDevice?.responsiblePerson;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSerialLookupCard(deviceProvider.devices),
            const SizedBox(height: 16),
            DropdownButtonFormField<Customer>(
              initialValue: selectedInstitution,
              isExpanded: true,
              items: customerProvider.customers
                  .map(
                    (inst) => DropdownMenuItem(
                      value: inst,
                      child: Text(inst.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedInstitution = val;
                  _selectedDevice = null;
                  _applySelectionPrefills(customer: val);
                });
                _serialLookupController.clear();
              },
              decoration: _inputDecoration(
                label: 'Kurum Secin *',
                icon: Icons.apartment,
              ),
              validator: (v) => v == null ? 'Kurum secimi zorunludur.' : null,
            ),
            if (selectedInstitution != null) ...[
              const SizedBox(height: 16),
              if (institutionDevices.isEmpty)
                _buildInlineNotice(
                  icon: Icons.devices_other,
                  color: Colors.orange,
                  text:
                      'Secili kuruma bagli cihaz bulunamadi. Servis formu icin once cihaza kurum atamasi yapilmali.',
                )
              else
                DropdownButtonFormField<Device>(
                  initialValue: selectedDevice,
                  isExpanded: true,
                  items: institutionDevices
                      .map(
                        (dev) => DropdownMenuItem(
                          value: dev,
                          child: Text(
                            '${dev.name} - ${dev.brand} ${dev.model} - Seri: ${dev.serialNumber}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedDevice = val;
                      _applySelectionPrefills(
                        device: val,
                        customer: selectedInstitution,
                      );
                    });
                    _serialLookupController.text = val?.serialNumber ?? '';
                  },
                  decoration: _inputDecoration(
                    label: 'Cihaz Secin *',
                    icon: Icons.devices,
                  ),
                  validator: (v) =>
                      v == null ? 'Cihaz secimi zorunludur.' : null,
                ),
            ],
            if (responsible != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_pin,
                        color: Colors.orange.shade700, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Cihaz Sorumlusu",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                  fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(responsible.fullName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          if (responsible.title?.trim().isNotEmpty == true)
                            Text(
                              responsible.title!.trim(),
                              style: TextStyle(
                                color: Colors.orange.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (responsible.phone?.trim().isNotEmpty == true)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                responsible.phone!.trim(),
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildServiceTimeCardContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        final pickers = [
          _buildDateTimePicker(
            label: 'Problem Bildirim',
            dateTime: _problemDateTime,
            onChanged: (d) => setState(() => _problemDateTime = d),
          ),
          _buildDateTimePicker(
            label: 'Mudahale',
            dateTime: _mudahaleDateTime,
            onChanged: (d) => setState(() => _mudahaleDateTime = d),
          ),
          _buildDateTimePicker(
            label: 'Cozum',
            dateTime: _cozumDateTime,
            onChanged: (d) => setState(() => _cozumDateTime = d),
          ),
        ];

        if (!isWide) {
          return Column(children: pickers);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: pickers[0]),
            const SizedBox(width: 10),
            Expanded(child: pickers[1]),
            const SizedBox(width: 10),
            Expanded(child: pickers[2]),
          ],
        );
      },
    );
  }

  Widget _buildUsedPartsSection() {
    return Consumer<StockProvider>(
      builder: (context, stockProvider, child) {
        final stocks = stockProvider.stocks;
        final syncedStockCount = stocks.length;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blueGrey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blueGrey.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_done_outlined,
                        color: Colors.blueGrey.shade700),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        syncedStockCount == 0
                            ? 'Merkezden tanimli stok karti henuz yok. Dilersen disaridan parca ekleyebilirsin.'
                            : '$syncedStockCount stok karti kullanima hazir. Merkezden gelen kartlar burada listelenir.',
                        style: TextStyle(
                          color: Colors.blueGrey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_usedSpareParts.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          color: Colors.blueGrey.shade500),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Bu servis icin henuz parca eklenmedi.',
                          style: TextStyle(color: Colors.blueGrey.shade700),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._usedSpareParts.map((part) => _buildUsedPartTile(part)),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: stocks.isEmpty
                        ? null
                        : () => _showAddPartSheet(stockProvider),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: Text(
                      stocks.isEmpty ? 'Stok karti yok' : 'Stoktan Parca Ekle',
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _showAddExternalPartSheet,
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: const Text('Disaridan Parca Ekle'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUsedPartTile(_UsedPart part) {
    final stock = part.stock;
    final isExternal = part.source == _UsedPartSource.external;
    final stockLeft = isExternal ? null : stock.quantity - part.quantity;
    final isCritical = !isExternal &&
        stockLeft != null &&
        stockLeft <= stock.criticalStockThreshold;
    final meta = [
      if ((stock.referenceNo ?? '').trim().isNotEmpty)
        'Ref: ${stock.referenceNo}',
      if ((stock.barcode ?? '').trim().isNotEmpty) 'Kod: ${stock.barcode}',
    ].join(' - ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isExternal
              ? Colors.blueGrey.shade200
              : (isCritical ? Colors.orange.shade200 : Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isExternal
                ? Colors.indigo.shade50
                : (isCritical ? Colors.orange.shade100 : Colors.green.shade100),
            child: Icon(
              isExternal
                  ? Icons.shopping_bag_outlined
                  : (isCritical ? Icons.warning_amber : Icons.check),
              color: isExternal
                  ? Colors.indigo
                  : (isCritical ? Colors.orange.shade800 : Colors.green),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        stock.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (isExternal)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Dis kaynak',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.indigo,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isExternal
                      ? 'Kullanilan: ${part.quantity}'
                      : 'Kullanilan: ${part.quantity} - Kalan: $stockLeft',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Parcayi cikar',
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _usedSpareParts.remove(part)),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddPartSheet(StockProvider stockProvider) async {
    Stock? selectedStock;
    final quantityController = TextEditingController(text: '1');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Stoktan Parca Ekle',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Stock>(
                    initialValue: selectedStock,
                    isExpanded: true,
                    items: stockProvider.stocks
                        .map(
                          (stock) => DropdownMenuItem(
                            value: stock,
                            child: Text(
                              '${stock.name} - Stok: ${stock.quantity}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setSheetState(() => selectedStock = value),
                    decoration: const InputDecoration(
                      labelText: 'Stok parcasi',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Kullanilan adet',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      final quantity =
                          int.tryParse(quantityController.text.trim()) ?? 0;
                      if (selectedStock == null || quantity <= 0) {
                        _showErrorSnackbar('Parca ve adet secimi gerekli.');
                        return;
                      }

                      _addOrMergeUsedPart(
                        _UsedPart(
                          stock: selectedStock!,
                          quantity: quantity,
                          source: _UsedPartSource.stock,
                        ),
                      );

                      Navigator.pop(sheetContext);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Forma Ekle'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    quantityController.dispose();
  }

  Future<void> _showAddExternalPartSheet() async {
    final nameController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final referenceController = TextEditingController();
    final barcodeController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Disaridan Parca Ekle',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Parca adi',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Kullanilan adet',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: referenceController,
                decoration: const InputDecoration(
                  labelText: 'Referans / Parca No (opsiyonel)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: barcodeController,
                decoration: const InputDecoration(
                  labelText: 'Barkod / Kod (opsiyonel)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () {
                  final name = nameController.text.trim();
                  final quantity =
                      int.tryParse(quantityController.text.trim()) ?? 0;
                  if (name.isEmpty || quantity <= 0) {
                    _showErrorSnackbar('Parca adi ve adet gerekli.');
                    return;
                  }

                  final externalPart = Stock(
                    name: name,
                    quantity: quantity,
                    barcode: barcodeController.text.trim().isEmpty
                        ? null
                        : barcodeController.text.trim(),
                    referenceNo: referenceController.text.trim().isEmpty
                        ? null
                        : referenceController.text.trim(),
                    criticalStockThreshold: 0,
                  );

                  _addOrMergeUsedPart(
                    _UsedPart(
                      stock: externalPart,
                      quantity: quantity,
                      source: _UsedPartSource.external,
                    ),
                  );

                  Navigator.pop(sheetContext);
                },
                icon: const Icon(Icons.add_box_outlined),
                label: const Text('Forma Ekle'),
              ),
            ],
          ),
        );
      },
    );

    nameController.dispose();
    quantityController.dispose();
    referenceController.dispose();
    barcodeController.dispose();
  }

  Widget _buildSelectionGroup(
      {String? title,
      required List<String> items,
      Set<String>? selectedItems,
      String? currentSelection,
      bool singleSelection = false,
      required Function(String) onItemSelected}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, color: Colors.black54)),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((item) {
            final bool isSelected = singleSelection
                ? currentSelection == item
                : selectedItems!.contains(item);
            return Container(
              margin: const EdgeInsets.only(bottom: 2),
              child: ChoiceChip(
                label: Text(
                  item,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color:
                        isSelected ? const Color(0xFF1565C0) : Colors.black87,
                  ),
                ),
                selected: isSelected,
                showCheckmark: true,
                checkmarkColor: const Color(0xFF0F766E),
                onSelected: (_) => onItemSelected(item),
                selectedColor: const Color(0xFFE3F2FD),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF64B5F6)
                        : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                elevation: isSelected ? 3 : 1,
                shadowColor: isSelected
                    ? const Color(0xFF64B5F6).withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDateTimePicker(
      {required String label,
      required DateTime? dateTime,
      required Function(DateTime) onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () async {
          final now = DateTime.now();
          final date = await showDatePicker(
            context: context,
            initialDate: dateTime ?? now,
            firstDate: now.subtract(const Duration(days: 365)),
            lastDate: now.add(const Duration(days: 365)),
          );
          if (date == null) return;
          if (!mounted) return;
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(dateTime ?? now),
          );
          if (time == null) return;
          onChanged(DateTime(
              date.year, date.month, date.day, time.hour, time.minute));
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            suffixIcon: const Icon(Icons.calendar_today, size: 20),
          ),
          child: Text(
            dateTime != null
                ? DateFormat('dd/MM/yyyy HH:mm').format(dateTime)
                : 'Tarih ve Saat Seciniz',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildSignatureArea(
      BuildContext context,
      String title,
      SignatureController controller,
      TextEditingController nameController,
      bool isCustomer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextFormField(
          controller: nameController,
          readOnly: !isCustomer,
          decoration: const InputDecoration(
            hintText: 'Ad Soyad',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Signature(
            controller: controller,
            backgroundColor: Colors.grey.shade50,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            child: const Text("Temizle"),
            onPressed: () => controller.clear(),
          ),
        ),
      ],
    );
  }

  void _showErrorSnackbar(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red));

  void _showSuccessSnackbar(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green));
}

enum _UsedPartSource { stock, external }

class _UsedPart {
  final Stock stock;
  final int quantity;
  final _UsedPartSource source;

  const _UsedPart({
    required this.stock,
    required this.quantity,
    required this.source,
  });
}

class _FormStepStatus {
  final String label;
  final bool isDone;
  final IconData icon;

  const _FormStepStatus({
    required this.label,
    required this.isDone,
    required this.icon,
  });
}

/// Akilli Parca Onerisi Modeli
class SmartPartSuggestion {
  final String name;
  final String partNumber;
  final String reason;

  SmartPartSuggestion({
    required this.name,
    required this.partNumber,
    required this.reason,
  });

  @override
  bool operator ==(Object other) =>
      other is SmartPartSuggestion && other.partNumber == partNumber;

  @override
  int get hashCode => partNumber.hashCode;
}
