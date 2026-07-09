import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';
import 'package:hive/hive.dart';
import 'package:biomed_serv/models/customer.dart';
import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/models/maintenance_form.dart';
import 'package:biomed_serv/models/maintenance_template.dart';
import 'package:biomed_serv/models/maintenance_template_v2.dart';
import 'package:biomed_serv/models/stock.dart';
import 'package:biomed_serv/providers/company_provider.dart';
import 'package:biomed_serv/providers/customer_provider.dart';
import 'package:biomed_serv/providers/device_provider.dart';
import 'package:biomed_serv/providers/maintenance_form_provider.dart';
import 'package:biomed_serv/providers/maintenance_template_provider.dart';
import 'package:biomed_serv/providers/maintenance_template_v2_provider.dart';
import 'package:biomed_serv/providers/report_template_provider.dart';
import 'package:biomed_serv/providers/stock_provider.dart';
import 'package:biomed_serv/providers/technician_provider.dart';
import 'package:biomed_serv/screens/pdf_preview_screen.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:biomed_serv/services/pdf_service.dart';
import 'package:biomed_serv/utils/turkish_text_formatter.dart';
import 'package:biomed_serv/services/technical_assignment_service.dart';

class MaintenanceFormScreen extends StatefulWidget {
  final Device? preselectedDevice;

  const MaintenanceFormScreen({super.key, this.preselectedDevice});

  @override
  State<MaintenanceFormScreen> createState() => _MaintenanceFormScreenState();
}

class _MaintenanceFormScreenState extends State<MaintenanceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pdfService = PdfService();
  bool _isSaving = false;

  // State
  Customer? _selectedCustomer;
  Device? _selectedDevice;
  String? _selectedMaintenancePeriod;
  MaintenanceTemplate? _selectedTemplate;
  MaintenanceTemplateV2? _selectedV2Template;
  List<String> _selectedActions = [];
  List<Stock> _usedParts = [];
  List<MaintenanceTemplate> _filteredTemplates = [];
  List<MaintenanceTemplateV2> _matchingV2Templates = [];

  // Controllers
  final _serialLookupController = TextEditingController();
  final _notesController = TextEditingController();
  final _finalStatusController = TextEditingController();
  final _technicianNameController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _techSignatureController =
      SignatureController(penStrokeWidth: 2, penColor: Colors.black);
  final _customerSignatureController =
      SignatureController(penStrokeWidth: 2, penColor: Colors.black);

  // Constants
  final List<String> _maintenancePeriods = [
    '3 Ay',
    '6 Ay',
    '1 Yıl',
    'İsteğe Bağlı'
  ];
  final List<String> _availableActions = [
    'Genel Fiziksel Kontrol',
    'Genel Temizlik',
    'Filtre Değişimi/Temizliği',
    'Kalibrasyon Kontrolü',
    'Yazılım Güncelleme',
    'Aksesuar Kontrolü'
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _serialLookupController.dispose();
    _notesController.dispose();
    _finalStatusController.dispose();
    _technicianNameController.dispose();
    _customerNameController.dispose();
    _techSignatureController.dispose();
    _customerSignatureController.dispose();
    super.dispose();
  }

  void _initializeData() {
    if (widget.preselectedDevice != null) {
      _selectedDevice = widget.preselectedDevice;
      _serialLookupController.text = widget.preselectedDevice!.serialNumber;
      if (widget.preselectedDevice!.customer is Customer) {
        _selectedCustomer = widget.preselectedDevice!.customer as Customer?;
        if (_selectedCustomer != null) {
          _customerNameController.text = _selectedCustomer!.authorizedPerson;
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final templateProvider =
            Provider.of<MaintenanceTemplateProvider>(context, listen: false);
        _onDeviceSelected(_selectedDevice, templateProvider.templates);
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applySelectionPrefills(
        device: _selectedDevice,
        customer: _selectedCustomer,
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
      _customerNameController.text = fallbackCustomer.authorizedPerson;
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
      _technicianNameController.text = preferredTechnicianName;
    }
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

  void _selectDeviceFromSerial(Device device, {bool updateSerialField = true}) {
    final customer =
        device.customer is Customer ? device.customer as Customer : null;
    final templates =
        Provider.of<MaintenanceTemplateProvider>(context, listen: false)
            .templates;

    setState(() {
      _selectedCustomer = customer;
    });
    if (updateSerialField &&
        _serialLookupController.text.trim() != device.serialNumber.trim()) {
      _serialLookupController.text = device.serialNumber;
    }
    _onDeviceSelected(device, templates);
  }

  void _handleSerialLookupChanged(String value, List<Device> devices) {
    final match = _findDeviceBySerial(devices, value);
    if (match == null || _sameDevice(match, _selectedDevice)) return;
    _selectDeviceFromSerial(match, updateSerialField: false);
  }

  void _onDeviceSelected(
      Device? device, List<MaintenanceTemplate> allTemplates) {
    setState(() {
      _selectedDevice = device;
      _selectedTemplate = null;
      _selectedV2Template = null;
      _selectedActions.clear();
      _usedParts.clear();
      _matchingV2Templates = [];

      if (device != null) {
        if (device.group != null && device.group!.isNotEmpty) {
          _filteredTemplates =
              allTemplates.where((t) => t.group == device.group).toList();
        } else {
          _filteredTemplates = allTemplates
              .where((t) => t.group == null || t.group!.isEmpty)
              .toList();
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _matchV2Templates(device);
        });
      } else {
        _filteredTemplates = [];
      }

      _applySelectionPrefills(
        device: device,
        customer: _selectedCustomer,
      );
    });
  }

  void _matchV2Templates(Device device) {
    final v2Provider =
        Provider.of<MaintenanceTemplateV2Provider>(context, listen: false);
    final allV2Templates = v2Provider.activeTemplates;

    setState(() {
      _matchingV2Templates = allV2Templates.where((template) {
        final brandMatch = template.deviceBrand == null ||
            template.deviceBrand!.isEmpty ||
            template.deviceBrand!.toLowerCase() == device.brand.toLowerCase();
        final modelMatch = template.deviceModel == null ||
            template.deviceModel!.isEmpty ||
            device.model
                .toLowerCase()
                .contains(template.deviceModel!.toLowerCase());
        return brandMatch && modelMatch;
      }).toList()
        ..sort(
          (a, b) => _templateMatchScore(b, device)
              .compareTo(_templateMatchScore(a, device)),
        );
    });
  }

  int _templateMatchScore(MaintenanceTemplateV2 template, Device device) {
    var score = 0;
    final brand = device.brand.trim().toLowerCase();
    final model = device.model.trim().toLowerCase();
    final templateBrand = template.deviceBrand?.trim().toLowerCase() ?? '';
    final templateModel = template.deviceModel?.trim().toLowerCase() ?? '';

    if (templateBrand.isNotEmpty && templateBrand == brand) score += 4;
    if (templateModel.isNotEmpty && templateModel == model) score += 6;
    if (templateModel.isNotEmpty && model.contains(templateModel)) score += 3;
    if (templateBrand.isEmpty && templateModel.isEmpty) score += 1;
    return score;
  }

  bool _sameV2Template(
    MaintenanceTemplateV2? a,
    MaintenanceTemplateV2? b,
  ) {
    if (a == null || b == null) return false;
    if (a.key != null && b.key != null) return a.key == b.key;
    return identical(a, b);
  }

  void _onV2TemplateSelected(MaintenanceTemplateV2? template) {
    setState(() {
      _selectedV2Template = template;
      if (template != null) {
        _selectedActions = template.lines
            .where((line) => line.description.isNotEmpty)
            .map((line) => line.description)
            .toList();
        _usedParts = template.lines
            .where((line) => line.partName != null && line.partName!.isNotEmpty)
            .map((line) => Stock(
                  name: line.partName!,
                  quantity: line.partQuantity ?? 1,
                  barcode: line.stockReferenceNo,
                  criticalStockThreshold: 5,
                ))
            .toList();
        _selectedMaintenancePeriod = _convertPeriodType(template.periodType);
      } else {
        _selectedActions.clear();
        _usedParts.clear();
      }
    });
  }

  String _convertPeriodType(MaintenancePeriodType type) {
    switch (type) {
      case MaintenancePeriodType.weekly:
        return '1 Hafta';
      case MaintenancePeriodType.monthly:
        return '1 Ay';
      case MaintenancePeriodType.quarterly:
        return '3 Ay';
      case MaintenancePeriodType.biannual:
        return '6 Ay';
      case MaintenancePeriodType.annual:
        return '1 Yıl';
      case MaintenancePeriodType.biennial:
        return '2 Yıl';
      case MaintenancePeriodType.custom:
        return 'İsteğe Bağlı';
    }
  }

  void _onTemplateSelected(MaintenanceTemplate? template) {
    setState(() {
      _selectedTemplate = template;
      _selectedV2Template = null;
      if (template != null) {
        _selectedActions = List.from(template.actions);
        _usedParts = template.requiredParts
            .map((p) => Stock(
                  name: p.name,
                  quantity: p.quantity,
                  criticalStockThreshold: p.criticalStockThreshold,
                  barcode: p.barcode,
                  referenceNo: p.referenceNo,
                ))
            .toList();
      } else {
        _selectedActions.clear();
        _usedParts.clear();
      }
    });
  }

  void _showV2TemplateSelector() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cihaz Modeline Özel Şablonlar'),
        content: SizedBox(
          width: double.maxFinite,
          child: _matchingV2Templates.isEmpty
              ? const Text('Bu cihaz için özel şablon bulunmuyor.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _matchingV2Templates.length,
                  itemBuilder: (context, index) {
                    final template = _matchingV2Templates[index];
                    return ListTile(
                      leading:
                          const Icon(Icons.build_circle, color: Colors.purple),
                      title: Text(template.name),
                      subtitle: Text(
                        '${template.lines.length} adım • ${_convertPeriodType(template.periodType)}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                      trailing: _sameV2Template(_selectedV2Template, template)
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                      onTap: () {
                        _onV2TemplateSelected(template);
                        Navigator.of(ctx).pop();
                        _showSuccessSnackbar(
                            '"${template.name}" şablonu uygulandı');
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAndShareForm() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackbar('Lütfen tüm zorunlu alanları doldurun.');
      return;
    }
    if (_selectedActions.isEmpty) {
      _showErrorSnackbar('En az bir bakım işlemi seçmelisiniz.');
      return;
    }

    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final stockProvider = Provider.of<StockProvider>(context, listen: false);
    final maintenanceFormProvider =
        Provider.of<MaintenanceFormProvider>(context, listen: false);
    final reportTemplateProvider =
        Provider.of<ReportTemplateProvider>(context, listen: false);
    final companyProvider =
        Provider.of<CompanyProvider>(context, listen: false);
    final technicianProvider =
        Provider.of<TechnicianProvider>(context, listen: false);

    final techSignBytes = await _techSignatureController.toPngBytes();
    final custSignBytes = await _customerSignatureController.toPngBytes();

    if (techSignBytes == null || techSignBytes.isEmpty) {
      _showErrorSnackbar('Teknisyen imzası zorunludur.');
      return;
    }
    if (custSignBytes == null || custSignBytes.isEmpty) {
      _showErrorSnackbar('Müşteri imzası zorunludur.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final partSnapshotsBox = dbService.serviceFormPartsBox;
      final savedParts = HiveList<Stock>(partSnapshotsBox);

      for (final part in _usedParts) {
        final snapshot = Stock(
          name: part.name,
          quantity: part.quantity,
          barcode: part.barcode,
          referenceNo: part.referenceNo,
          criticalStockThreshold: part.criticalStockThreshold,
        );
        await partSnapshotsBox.add(snapshot);
        savedParts.add(snapshot);
      }

      final newForm = MaintenanceForm(
        formNumber:
            'BKM-${DateTime.now().microsecondsSinceEpoch.toString().substring(8)}',
        createdAt: DateTime.now(),
        customer: _selectedCustomer!,
        device: _selectedDevice!,
        maintenancePeriod: _selectedMaintenancePeriod!,
        actionsTaken: _selectedActions,
        notes: normalizeDescriptionText(_notesController.text),
        partsUsed: savedParts,
        finalStatus: normalizeDescriptionText(_finalStatusController.text),
        technicianSignature: base64Encode(techSignBytes),
        customerSignature: base64Encode(custSignBytes),
        technicianName: _technicianNameController.text,
        customerName: _customerNameController.text,
      );

      // 📱 PDF oluştur ve paylaş (Rapor şablonu, firma ve teknisyen bilgileriyle)
      // PDF servisine şablon ve bilgileri ayarla
      _pdfService
          .setTemplate(reportTemplateProvider.defaultMaintenanceTemplate);
      _pdfService.setCompanyInfo(companyProvider.companyInfo);
      _pdfService.setTechnician(technicianProvider.currentTechnician);

      final pdfFile = await _pdfService.generateMaintenancePdf(newForm);
      if (!await pdfFile.exists() || await pdfFile.length() == 0) {
        throw Exception('Bakım formu PDF dosyası oluşturulamadı.');
      }
      newForm.pdfPath = pdfFile.path;
      await maintenanceFormProvider.addForm(newForm);

      for (final part in _usedParts) {
        final stockKey = part.key;
        if (stockKey is int) {
          await stockProvider.useStock(
            stockKey,
            part.quantity,
            allowNegative: false,
          );
        }
      }

      if (!mounted) return;
      _showSuccessSnackbar('Bakım formu ve PDF arşive kaydedildi.');

      if (mounted) {
        Navigator.of(context).pushReplacement(
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
      _showErrorSnackbar('Bir hata oluştu: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardDecoration = BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.deepPurple.shade300, width: 1.5),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Bakım Formu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _saveAndShareForm,
            tooltip: 'Kaydet ve Paylaş',
          ),
        ],
      ),
      body: _isSaving
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('PDF Oluşturuluyor...'),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(10, 16, 10, 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCustomCard(
                      title: 'Müşteri ve Cihaz Bilgileri',
                      decoration: cardDecoration,
                      child: _buildCustomerInfoCard(),
                    ),
                    const SizedBox(height: 16),
                    _buildCustomCard(
                      title: 'Bakım Detayları',
                      decoration: cardDecoration,
                      child: _buildMaintenanceDetailsCard(),
                    ),
                    const SizedBox(height: 16),
                    _buildCustomCard(
                      title: 'Kullanılan Malzemeler',
                      decoration: cardDecoration,
                      child: _buildPartsCard(),
                    ),
                    const SizedBox(height: 16),
                    _buildCustomCard(
                      title: 'Son Durum ve Doğrulama',
                      decoration: cardDecoration,
                      child: _buildStatusCard(),
                    ),
                    const SizedBox(height: 16),
                    _buildCustomCard(
                      title: 'İmzalar',
                      decoration: cardDecoration,
                      child: _buildSignaturesCard(),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('KAYDET VE PDF PAYLAŞ'),
                      onPressed: _saveAndShareForm,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.deepPurple.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCustomCard({
    required String title,
    required BoxDecoration decoration,
    required Widget child,
  }) {
    return Container(
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(13),
                topRight: Radius.circular(13),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.deepPurple.shade100),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                color: Colors.deepPurple.shade900,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
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
    final selectedCustomer = _selectedCustomer ??
        (_selectedDevice?.customer is Customer
            ? _selectedDevice!.customer as Customer
            : null);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _serialLookupController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Seri No ile hizli bul',
              helperText:
                  'Seri no yazinca kurum, cihaz ve uygun bakim sablonlari hazirlanir.',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.qr_code_2),
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
            onChanged: (value) => _handleSerialLookupChanged(
              value,
              devices,
            ),
          ),
          if (_selectedDevice != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_selectedDevice!.name} - ${_selectedDevice!.serialNumber}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
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
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
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
            Row(
              children: [
                Icon(Icons.search_off, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Bu seri no ile kayitli cihaz bulunamadi.'),
                ),
              ],
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

  Widget _buildCustomerInfoCard() {
    return Consumer2<CustomerProvider, DeviceProvider>(
      builder: (context, customerProvider, deviceProvider, child) {
        return Column(
          children: [
            _buildSerialLookupCard(deviceProvider.devices),
            const SizedBox(height: 16),
            DropdownButtonFormField<Customer>(
              initialValue: _selectedCustomer,
              items: customerProvider.customers
                  .map((inst) => DropdownMenuItem(
                        value: inst,
                        child: Text(inst.name),
                      ))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedCustomer = val;
                  _selectedDevice = null;
                  _serialLookupController.clear();
                  _onDeviceSelected(
                    null,
                    Provider.of<MaintenanceTemplateProvider>(context,
                            listen: false)
                        .templates,
                  );
                  _applySelectionPrefills(customer: val);
                });
              },
              decoration: const InputDecoration(
                labelText: 'Kurum Seçin *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              validator: (v) => v == null ? 'Kurum seçimi zorunludur.' : null,
            ),
            if (_selectedCustomer != null) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<Device>(
                initialValue: _selectedDevice,
                items: deviceProvider.devices
                    .where((d) =>
                        (d.customer as Customer?)?.key ==
                        _selectedCustomer?.key)
                    .map((dev) => DropdownMenuItem(
                          value: dev,
                          child: Text(dev.name),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    _serialLookupController.text = val.serialNumber;
                  }
                  _onDeviceSelected(
                    val,
                    Provider.of<MaintenanceTemplateProvider>(context,
                            listen: false)
                        .templates,
                  );
                },
                decoration: const InputDecoration(
                  labelText: 'Cihaz Seçin *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.devices_other),
                ),
                validator: (v) => v == null ? 'Cihaz seçimi zorunludur.' : null,
              ),
              if (_selectedDevice?.responsiblePerson != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange.shade200),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_pin,
                          color: Colors.orange.shade700, size: 34),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cihaz Sorumlusu',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedDevice!.responsiblePerson!.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (_selectedDevice!.responsiblePerson!.title
                                    ?.trim()
                                    .isNotEmpty ==
                                true)
                              Text(
                                _selectedDevice!.responsiblePerson!.title!
                                    .trim(),
                                style: TextStyle(
                                  color: Colors.orange.shade900,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (_selectedDevice!.responsiblePerson!.phone
                                    ?.trim()
                                    .isNotEmpty ==
                                true)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  _selectedDevice!.responsiblePerson!.phone!
                                      .trim(),
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
          ],
        );
      },
    );
  }

  Widget _buildMaintenanceDetailsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedDevice != null) ...[
          // V2 Şablon Seçimi
          if (_matchingV2Templates.isNotEmpty) ...[
            _buildSmartTemplatePanel(),
            const SizedBox(height: 16),
          ],
          // Genel Şablon Seçimi
          DropdownButtonFormField<MaintenanceTemplate>(
            initialValue: _selectedTemplate,
            items: _filteredTemplates
                .map((model) => DropdownMenuItem(
                      value: model,
                      child: Text(model.name),
                    ))
                .toList(),
            onChanged: _onTemplateSelected,
            decoration: InputDecoration(
              labelText: 'Genel Bakım Şablonu Seç',
              border: const OutlineInputBorder(),
              prefixIcon:
                  Icon(Icons.auto_fix_high, color: Colors.purple.shade400),
            ),
            hint: const Text('Cihaz grubuna uygun şablon'),
          ),
          const SizedBox(height: 16),
        ],
        // Bakım Periyodu
        DropdownButtonFormField<String>(
          initialValue: _selectedMaintenancePeriod,
          items: _maintenancePeriods
              .map((tur) => DropdownMenuItem(value: tur, child: Text(tur)))
              .toList(),
          onChanged: (val) => setState(() => _selectedMaintenancePeriod = val),
          decoration: const InputDecoration(
            labelText: 'Bakım Periyodu *',
            border: OutlineInputBorder(),
          ),
          validator: (v) => v == null ? 'Bakım periyodu zorunludur.' : null,
        ),
        const SizedBox(height: 16),
        // Yapılan İşlemler
        const Text(
          'Yapılan İşlemler *',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(4),
          ),
          height: 200,
          child: ListView.builder(
            itemCount: _availableActions.length,
            itemBuilder: (context, index) {
              final action = _availableActions[index];
              return CheckboxListTile(
                title: Text(action),
                value: _selectedActions.contains(action),
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      _selectedActions.add(action);
                    } else {
                      _selectedActions.remove(action);
                    }
                  });
                },
                dense: true,
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // Notlar
        TextFormField(
          controller: _notesController,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: const [TurkishUpperCaseTextFormatter()],
          decoration: const InputDecoration(
            labelText: 'Ekstra Notlar / Açıklamalar',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildSmartTemplatePanel() {
    final recommended = _matchingV2Templates.first;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.purple.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Uygun Bakim Sablonlari',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade900,
                  ),
                ),
              ),
              if (_selectedV2Template != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Uygulandi',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_matchingV2Templates.length} sablon bulundu. En uygun olan kartta one alindi.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _matchingV2Templates.take(3).map((template) {
              return _buildTemplateSuggestionCard(
                template,
                isRecommended: _sameV2Template(template, recommended),
              );
            }).toList(),
          ),
          if (_matchingV2Templates.length > 3) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _showV2TemplateSelector,
                icon: const Icon(Icons.view_list),
                label: const Text('Tum sablonlari goster'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTemplateSuggestionCard(
    MaintenanceTemplateV2 template, {
    required bool isRecommended,
  }) {
    final selected = _sameV2Template(_selectedV2Template, template);
    final borderColor = selected
        ? Colors.green.shade400
        : isRecommended
            ? Colors.purple.shade300
            : Colors.purple.shade100;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        _onV2TemplateSelected(template);
        _showSuccessSnackbar('"${template.name}" sablonu uygulandi');
      },
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: selected ? 1.6 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  selected ? Icons.check_circle : Icons.build_circle_outlined,
                  color: selected ? Colors.green.shade600 : Colors.purple,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    template.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (isRecommended)
                  _miniTemplateChip('Onerilen', Colors.deepPurple),
                _miniTemplateChip(
                  '${template.lines.length} adim',
                  Colors.blueGrey,
                ),
                _miniTemplateChip(
                  _convertPeriodType(template.periodType),
                  Colors.teal,
                ),
              ],
            ),
            if (template.description?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                template.description!.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.blueGrey.shade700,
                  fontSize: 12,
                  height: 1.25,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniTemplateChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildPartsCard() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Stoktan Ekle'),
            onPressed: _showAddPartDialog,
            style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
          ),
        ),
        _usedParts.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Malzeme eklenmedi.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _usedParts.length,
                itemBuilder: (context, index) {
                  final part = _usedParts[index];
                  return Card(
                    margin: const EdgeInsets.only(top: 8),
                    color: Colors.deepPurple.shade50,
                    child: ListTile(
                      leading: const Icon(Icons.build),
                      title: Text(part.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${part.quantity} Adet'),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () =>
                                setState(() => _usedParts.removeAt(index)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildStatusCard() {
    return TextFormField(
      controller: _finalStatusController,
      textCapitalization: TextCapitalization.characters,
      inputFormatters: const [TurkishUpperCaseTextFormatter()],
      decoration: const InputDecoration(
        labelText: 'Cihazın Son Durumu ve Doğrulama Çalışmaları',
        border: OutlineInputBorder(),
        hintText: 'Örn: Kontrol çalışmaları yapıldı, cihaz aktif.',
      ),
      maxLines: 3,
    );
  }

  Widget _buildSignaturesCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final technicianSignature = _buildSignatureArea(
          context,
          'Servisi Yapan',
          _techSignatureController,
          _technicianNameController,
          false,
        );
        final customerSignature = _buildSignatureArea(
          context,
          'Musteri Yetkilisi',
          _customerSignatureController,
          _customerNameController,
          true,
        );

        if (constraints.maxWidth < 620) {
          return Column(
            children: [
              technicianSignature,
              const SizedBox(height: 16),
              customerSignature,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: technicianSignature),
            const SizedBox(width: 16),
            Expanded(child: customerSignature),
          ],
        );
      },
    );
  }

  Widget _buildSignatureArea(
    BuildContext context,
    String title,
    SignatureController controller,
    TextEditingController nameController,
    bool isCustomer,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: nameController,
          readOnly: !isCustomer,
          decoration: const InputDecoration(
            labelText: 'Ad Soyad',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 100,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Signature(
              controller: controller,
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            child: const Text(
              'Sil',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
            onPressed: () => controller.clear(),
          ),
        ),
      ],
    );
  }

  void _showAddPartDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Stoktan Malzeme Ekle'),
          content: Consumer<StockProvider>(
            builder: (context, stockProvider, child) {
              if (stockProvider.stocks.isEmpty) {
                return const Text(
                    'Stokta malzeme bulunmuyor. Önce stok ekleyin.');
              }
              return SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: stockProvider.stocks.length,
                  itemBuilder: (context, index) {
                    final stock = stockProvider.stocks[index];
                    final isAlreadyAdded =
                        _usedParts.any((p) => p.name == stock.name);
                    return ListTile(
                      title: Text(stock.name),
                      subtitle: Text('Mevcut: ${stock.quantity} adet'),
                      trailing: isAlreadyAdded
                          ? const Icon(Icons.check, color: Colors.green)
                          : const Icon(Icons.add),
                      enabled: !isAlreadyAdded && stock.quantity > 0,
                      onTap: isAlreadyAdded || stock.quantity <= 0
                          ? null
                          : () {
                              Navigator.of(ctx).pop();
                              _showQuantityDialog(stock);
                            },
                    );
                  },
                ),
              );
            },
          ),
          actions: [
            TextButton(
              child: const Text('Kapat'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        );
      },
    );
  }

  void _showQuantityDialog(Stock part) {
    final quantityController = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('${part.name} - Miktar Girin'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Mevcut stok: ${part.quantity} adet'),
              const SizedBox(height: 16),
              TextFormField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Kullanılan Miktar',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('İptal'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ElevatedButton(
              child: const Text('Ekle'),
              onPressed: () {
                final qty = int.tryParse(quantityController.text) ?? 0;
                if (qty > 0 && qty <= part.quantity) {
                  setState(() {
                    _usedParts.add(Stock(
                      name: part.name,
                      quantity: qty,
                      barcode: part.barcode,
                      referenceNo: part.referenceNo,
                      criticalStockThreshold: part.criticalStockThreshold,
                    ));
                  });
                  Navigator.of(ctx).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }
}
