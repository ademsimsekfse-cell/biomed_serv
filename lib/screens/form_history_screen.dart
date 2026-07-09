import 'dart:io';

import 'package:biomed_serv/models/customer.dart';
import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/models/maintenance_form.dart';
import 'package:biomed_serv/models/service_form.dart';
import 'package:biomed_serv/providers/company_provider.dart';
import 'package:biomed_serv/providers/customer_provider.dart';
import 'package:biomed_serv/providers/device_provider.dart';
import 'package:biomed_serv/providers/maintenance_form_provider.dart';
import 'package:biomed_serv/providers/report_template_provider.dart';
import 'package:biomed_serv/providers/service_form_provider.dart';
import 'package:biomed_serv/providers/technician_provider.dart';
import 'package:biomed_serv/screens/pdf_preview_screen.dart';
import 'package:biomed_serv/services/pdf_share_service.dart';
import 'package:biomed_serv/services/pdf_service.dart';
import 'package:excel/excel.dart' as excel;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

enum _FormHistoryTypeFilter { all, service, maintenance }

class FormHistoryScreen extends StatefulWidget {
  const FormHistoryScreen({super.key});

  @override
  State<FormHistoryScreen> createState() => _FormHistoryScreenState();
}

class _FormHistoryScreenState extends State<FormHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy');
  final DateFormat _dateTimeFormat = DateFormat('dd.MM.yyyy HH:mm');

  _FormHistoryTypeFilter _selectedType = _FormHistoryTypeFilter.all;
  Customer? _selectedCustomer;
  Device? _selectedDevice;
  DateTimeRange? _selectedDateRange;
  String? _openingFormNumber;
  String? _sharingFormNumber;
  bool _filtersExpanded = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialRange = _selectedDateRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day).subtract(
            const Duration(days: 30),
          ),
          end: DateTime(now.year, now.month, now.day),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: initialRange,
      helpText: 'Tarih Aralığı Seçin',
      saveText: 'Uygula',
    );

    if (picked != null && mounted) {
      setState(() => _selectedDateRange = picked);
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedType = _FormHistoryTypeFilter.all;
      _selectedCustomer = null;
      _selectedDevice = null;
      _selectedDateRange = null;
      _searchController.clear();
    });
  }

  PdfService _createConfiguredPdfService() {
    final pdfService = PdfService();
    final companyProvider =
        Provider.of<CompanyProvider>(context, listen: false);
    final technicianProvider =
        Provider.of<TechnicianProvider>(context, listen: false);

    pdfService.setCompanyInfo(companyProvider.companyInfo);
    pdfService.setTechnician(technicianProvider.currentTechnician);
    return pdfService;
  }

  Future<void> _openPreview(_FormHistoryEntry entry) async {
    setState(() => _openingFormNumber = entry.formNumber);
    final pdfService = _createConfiguredPdfService();
    final reportTemplateProvider =
        Provider.of<ReportTemplateProvider>(context, listen: false);

    try {
      pdfService.setTemplate(
        entry.type == _FormHistoryTypeFilter.service
            ? reportTemplateProvider.defaultServiceTemplate
            : reportTemplateProvider.defaultMaintenanceTemplate,
      );

      final pdfFile = await _resolvePdfFile(entry, pdfService);

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfPreviewScreen(
            filePath: pdfFile.path,
            title: entry.type == _FormHistoryTypeFilter.service
                ? 'Servis Formu Önizleme'
                : 'Bakım Formu Önizleme',
            shareText: entry.type == _FormHistoryTypeFilter.service
                ? 'Servis Formu'
                : 'Bakım Formu',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Form önizlemesi açılırken hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _openingFormNumber = null);
      }
    }
  }

  Future<void> _shareEntry(_FormHistoryEntry entry) async {
    if (_sharingFormNumber != null) return;
    setState(() => _sharingFormNumber = entry.formNumber);
    final pdfService = _createConfiguredPdfService();
    final reportTemplateProvider =
        Provider.of<ReportTemplateProvider>(context, listen: false);

    try {
      pdfService.setTemplate(
        entry.type == _FormHistoryTypeFilter.service
            ? reportTemplateProvider.defaultServiceTemplate
            : reportTemplateProvider.defaultMaintenanceTemplate,
      );

      final pdfFile = await _resolvePdfFile(entry, pdfService);

      if (!mounted) return;
      await PdfShareService.sharePdfFile(
        pdfFile.path,
        subject: entry.type == _FormHistoryTypeFilter.service
            ? 'Servis Formu'
            : 'Bakim Formu',
        shareText: entry.type == _FormHistoryTypeFilter.service
            ? 'Servis Formu'
            : 'Bakim Formu',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Form paylasilirken hata olustu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sharingFormNumber = null);
      }
    }
  }

  Future<File> _resolvePdfFile(
    _FormHistoryEntry entry,
    PdfService pdfService,
  ) async {
    if (entry.type == _FormHistoryTypeFilter.service) {
      final form = entry.serviceForm!;
      final currentPath = form.pdfPath;
      if (currentPath != null && currentPath.isNotEmpty) {
        final existingFile = File(currentPath);
        if (await existingFile.exists()) return existingFile;
      }

      final pdfFile = await pdfService.generateServicePdf(form);
      form.pdfPath = pdfFile.path;
      if (mounted) {
        await Provider.of<ServiceFormProvider>(context, listen: false)
            .updateForm(form);
      }
      return pdfFile;
    }

    final form = entry.maintenanceForm!;
    final currentPath = form.pdfPath;
    if (currentPath != null && currentPath.isNotEmpty) {
      final existingFile = File(currentPath);
      if (await existingFile.exists()) return existingFile;
    }

    final pdfFile = await pdfService.generateMaintenancePdf(form);
    form.pdfPath = pdfFile.path;
    if (mounted) {
      await Provider.of<MaintenanceFormProvider>(context, listen: false)
          .updateForm(form);
    }
    return pdfFile;
  }

  Future<void> _deleteEntry(_FormHistoryEntry entry) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Form kaydını sil'),
            content: Text(
              '${entry.formNumber} numaralı ${entry.type == _FormHistoryTypeFilter.service ? 'servis' : 'bakım'} formunu silmek istediğinize emin misiniz?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Sil'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    try {
      if (entry.type == _FormHistoryTypeFilter.service) {
        final provider =
            Provider.of<ServiceFormProvider>(context, listen: false);
        final key = entry.serviceForm?.key;
        if (key is int) {
          await provider.deleteForm(key);
        }
      } else {
        final provider =
            Provider.of<MaintenanceFormProvider>(context, listen: false);
        final key = entry.maintenanceForm?.key;
        if (key is int) {
          await provider.deleteForm(key);
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Form kaydı silindi.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Form silinirken hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportFilteredEntries(List<_FormHistoryEntry> entries) async {
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dışa aktarılacak form bulunamadı.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final workbook = excel.Excel.createExcel();
      final sheet = workbook['Form Geçmişi'];

      sheet.appendRow([
        excel.TextCellValue('Form No'),
        excel.TextCellValue('Tip'),
        excel.TextCellValue('Tarih'),
        excel.TextCellValue('Kurum'),
        excel.TextCellValue('Cihaz'),
        excel.TextCellValue('Seri No'),
        excel.TextCellValue('Cihaz Sorumlusu'),
        excel.TextCellValue('Musteri Yetkilisi'),
        excel.TextCellValue('Teknisyen'),
        excel.TextCellValue('Özet'),
      ]);

      for (final entry in entries) {
        sheet.appendRow([
          excel.TextCellValue(entry.formNumber),
          excel.TextCellValue(
            entry.type == _FormHistoryTypeFilter.service ? 'Servis' : 'Bakım',
          ),
          excel.TextCellValue(_dateTimeFormat.format(entry.createdAt)),
          excel.TextCellValue(entry.customerName),
          excel.TextCellValue(entry.deviceName),
          excel.TextCellValue(entry.serialNumber),
          excel.TextCellValue(entry.responsibleName ?? ''),
          excel.TextCellValue(entry.contactName ?? ''),
          excel.TextCellValue(entry.technicianName ?? ''),
          excel.TextCellValue(entry.summary ?? ''),
        ]);
      }

      final bytes = workbook.save();
      if (bytes == null) {
        throw Exception('Excel dosyası oluşturulamadı.');
      }

      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}\\form_gecmisi_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx',
      );
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Form Geçmişi Excel',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Excel dışa aktarma sırasında hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<_FormHistoryEntry> _buildFilteredEntries({
    required List<ServiceForm> serviceForms,
    required List<MaintenanceForm> maintenanceForms,
  }) {
    final entries = <_FormHistoryEntry>[
      ...serviceForms.map(_FormHistoryEntry.fromServiceForm),
      ...maintenanceForms.map(_FormHistoryEntry.fromMaintenanceForm),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final query = _searchController.text.trim().toLowerCase();
    final rangeStart = _selectedDateRange?.start;
    final rangeEnd = _selectedDateRange == null
        ? null
        : DateTime(
            _selectedDateRange!.end.year,
            _selectedDateRange!.end.month,
            _selectedDateRange!.end.day,
            23,
            59,
            59,
            999,
          );

    return entries.where((entry) {
      if (_selectedType == _FormHistoryTypeFilter.service &&
          entry.type != _FormHistoryTypeFilter.service) {
        return false;
      }
      if (_selectedType == _FormHistoryTypeFilter.maintenance &&
          entry.type != _FormHistoryTypeFilter.maintenance) {
        return false;
      }

      if (_selectedCustomer != null &&
          !_entryMatchesCustomer(entry, _selectedCustomer!)) {
        return false;
      }

      if (_selectedDevice != null &&
          !_entryMatchesDevice(entry, _selectedDevice!)) {
        return false;
      }

      if (rangeStart != null && entry.createdAt.isBefore(rangeStart)) {
        return false;
      }
      if (rangeEnd != null && entry.createdAt.isAfter(rangeEnd)) {
        return false;
      }

      if (query.isEmpty) return true;

      final haystack = [
        entry.formNumber,
        entry.customerName,
        entry.deviceName,
        entry.serialNumber,
        entry.responsibleName ?? '',
        entry.technicianName ?? '',
        entry.contactName ?? '',
        entry.summary ?? '',
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList();
  }

  bool _entryMatchesCustomer(_FormHistoryEntry entry, Customer customer) {
    if (entry.customerKey != null &&
        customer.key != null &&
        entry.customerKey == customer.key) {
      return true;
    }
    return _normalizeMatch(entry.customerName) ==
        _normalizeMatch(customer.name);
  }

  bool _entryMatchesDevice(_FormHistoryEntry entry, Device device) {
    if (entry.deviceKey != null &&
        device.key != null &&
        entry.deviceKey == device.key) {
      return true;
    }
    return _normalizeMatch(entry.serialNumber) ==
        _normalizeMatch(device.serialNumber);
  }

  bool _deviceBelongsToCustomer(Device device, Customer customer) {
    final assignedCustomer = device.customer;
    if (assignedCustomer is! Customer) return false;
    if (assignedCustomer.key != null &&
        customer.key != null &&
        assignedCustomer.key == customer.key) {
      return true;
    }
    return _normalizeMatch(assignedCustomer.name) ==
        _normalizeMatch(customer.name);
  }

  String _normalizeMatch(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _dateRangeLabel() {
    if (_selectedDateRange == null) {
      return 'Tarih aralığı seçin';
    }
    return '${_dateFormat.format(_selectedDateRange!.start)} - ${_dateFormat.format(_selectedDateRange!.end)}';
  }

  Widget _buildSummaryPill({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(_FormHistoryEntry entry) {
    final isBusy = _openingFormNumber == entry.formNumber;
    final isSharing = _sharingFormNumber == entry.formNumber;
    final isService = entry.type == _FormHistoryTypeFilter.service;
    final accent =
        isService ? const Color(0xFF315A80) : const Color(0xFF287C75);

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(7),
        side: BorderSide(color: Colors.blueGrey.shade100),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: isBusy ? null : () => _openPreview(entry),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 2, 7),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 44,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 9),
              Icon(
                isService
                    ? Icons.description_outlined
                    : Icons.fact_check_outlined,
                size: 22,
                color: accent,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.formNumber,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          _dateFormat.format(entry.createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${isService ? 'Servis' : 'Bakım'} • '
                      '${entry.customerName} • ${entry.deviceName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blueGrey.shade700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'SN: ${entry.serialNumber}'
                      '${entry.responsibleName?.isNotEmpty == true ? ' • Sorumlu: ${entry.responsibleName}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isBusy || isSharing)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                PopupMenuButton<String>(
                  tooltip: 'İşlemler',
                  onSelected: (value) {
                    if (value == 'preview') {
                      _openPreview(entry);
                    } else if (value == 'share') {
                      _shareEntry(entry);
                    } else if (value == 'delete') {
                      _deleteEntry(entry);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'preview', child: Text('Önizle')),
                    PopupMenuItem(value: 'share', child: Text('PDF Paylaş')),
                    PopupMenuItem(value: 'delete', child: Text('Sil')),
                  ],
                  icon: Icon(
                    Icons.more_vert,
                    color: Colors.blueGrey.shade400,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _compactFilterDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 19),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
    );
  }

  Widget _buildFilterFields(
    List<Customer> customers,
    List<Device> filteredDevices,
  ) {
    final fields = <Widget>[
      DropdownButtonFormField<_FormHistoryTypeFilter>(
        initialValue: _selectedType,
        isExpanded: true,
        decoration: _compactFilterDecoration(
          label: 'Form tipi',
          icon: Icons.tune,
        ),
        items: const [
          DropdownMenuItem(
            value: _FormHistoryTypeFilter.all,
            child: Text('Tüm formlar'),
          ),
          DropdownMenuItem(
            value: _FormHistoryTypeFilter.service,
            child: Text('Servis formları'),
          ),
          DropdownMenuItem(
            value: _FormHistoryTypeFilter.maintenance,
            child: Text('Bakım formları'),
          ),
        ],
        onChanged: (value) {
          if (value != null) setState(() => _selectedType = value);
        },
      ),
      DropdownButtonFormField<Customer>(
        initialValue: _selectedCustomer,
        isExpanded: true,
        decoration: _compactFilterDecoration(
          label: 'Kurum',
          icon: Icons.business_outlined,
        ),
        items: customers
            .map(
              (customer) => DropdownMenuItem<Customer>(
                value: customer,
                child: Text(customer.name, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: (value) => setState(() {
          _selectedCustomer = value;
          _selectedDevice = null;
        }),
      ),
      DropdownButtonFormField<Device>(
        initialValue: _selectedDevice,
        isExpanded: true,
        decoration: _compactFilterDecoration(
          label: 'Cihaz',
          icon: Icons.devices_outlined,
        ),
        items: filteredDevices
            .map(
              (device) => DropdownMenuItem<Device>(
                value: device,
                child: Text(
                  '${device.name} • ${device.serialNumber}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: (value) => setState(() => _selectedDevice = value),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 760) {
          return Row(
            children: [
              for (var index = 0; index < fields.length; index++) ...[
                Expanded(child: fields[index]),
                if (index != fields.length - 1) const SizedBox(width: 8),
              ],
            ],
          );
        }
        return Column(
          children: [
            for (var index = 0; index < fields.length; index++) ...[
              fields[index],
              if (index != fields.length - 1) const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }

  Widget _buildCompactFilters({
    required List<Customer> customers,
    required List<Device> filteredDevices,
    required int totalCount,
    required int serviceCount,
    required int maintenanceCount,
  }) {
    final hasFilters = _selectedType != _FormHistoryTypeFilter.all ||
        _selectedCustomer != null ||
        _selectedDevice != null ||
        _selectedDateRange != null ||
        _searchController.text.trim().isNotEmpty;

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(7),
        side: BorderSide(color: Colors.blueGrey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Form no, kurum, cihaz, seri no...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Aramayı temizle',
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close, size: 19),
                            ),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF7F9FB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Badge(
                  isLabelVisible: hasFilters,
                  smallSize: 7,
                  child: IconButton.filledTonal(
                    tooltip:
                        _filtersExpanded ? 'Filtreleri kapat' : 'Filtreler',
                    onPressed: () => setState(
                      () => _filtersExpanded = !_filtersExpanded,
                    ),
                    icon: Icon(
                      _filtersExpanded
                          ? Icons.filter_alt_off_outlined
                          : Icons.filter_alt_outlined,
                    ),
                  ),
                ),
              ],
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              crossFadeState: _filtersExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 9),
                child: Column(
                  children: [
                    _buildFilterFields(customers, filteredDevices),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDateRange,
                            icon: const Icon(
                              Icons.date_range_outlined,
                              size: 18,
                            ),
                            label: Text(
                              _dateRangeLabel(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          tooltip: 'Filtreleri temizle',
                          onPressed: hasFilters ? _clearFilters : null,
                          icon: const Icon(Icons.restart_alt),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _buildSummaryPill(
                    icon: Icons.inventory_2_outlined,
                    label: 'Toplam',
                    value: '$totalCount',
                    color: Colors.blueGrey,
                  ),
                  _buildSummaryPill(
                    icon: Icons.description_outlined,
                    label: 'Servis',
                    value: '$serviceCount',
                    color: const Color(0xFF315A80),
                  ),
                  _buildSummaryPill(
                    icon: Icons.fact_check_outlined,
                    label: 'Bakım',
                    value: '$maintenanceCount',
                    color: const Color(0xFF287C75),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final serviceForms = context.watch<ServiceFormProvider>().forms;
    final maintenanceForms = context.watch<MaintenanceFormProvider>().forms;
    final customers = [...context.watch<CustomerProvider>().customers]
      ..sort((a, b) => a.name.compareTo(b.name));
    final devices = [...context.watch<DeviceProvider>().devices]
      ..sort((a, b) => a.name.compareTo(b.name));

    final filteredDevices = devices
        .where(
          (device) =>
              _selectedCustomer == null ||
              _deviceBelongsToCustomer(device, _selectedCustomer!),
        )
        .toList();

    if (_selectedDevice != null &&
        !filteredDevices.any((device) => device.key == _selectedDevice!.key)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedDevice = null);
        }
      });
    }

    final filteredEntries = _buildFilteredEntries(
      serviceForms: serviceForms,
      maintenanceForms: maintenanceForms,
    );
    final filteredServiceCount = filteredEntries
        .where((entry) => entry.type == _FormHistoryTypeFilter.service)
        .length;
    final filteredMaintenanceCount = filteredEntries
        .where((entry) => entry.type == _FormHistoryTypeFilter.maintenance)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Form Geçmişi'),
        actions: [
          IconButton(
            tooltip: 'Excel olarak dışa aktar',
            onPressed: () => _exportFilteredEntries(filteredEntries),
            icon: const Icon(Icons.table_view_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: _buildCompactFilters(
              customers: customers,
              filteredDevices: filteredDevices,
              totalCount: filteredEntries.length,
              serviceCount: filteredServiceCount,
              maintenanceCount: filteredMaintenanceCount,
            ),
          ),
          Expanded(
            child: filteredEntries.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history_toggle_off,
                            size: 72,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Filtrelere uygun form bulunamadı.',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Filtreleri genişletin veya yeni bir servis/bakım formu oluşturun.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: filteredEntries.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: _buildHistoryCard(filteredEntries[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FormHistoryEntry {
  final _FormHistoryTypeFilter type;
  final String formNumber;
  final DateTime createdAt;
  final String customerName;
  final dynamic customerKey;
  final String deviceName;
  final dynamic deviceKey;
  final String serialNumber;
  final String? responsibleName;
  final String? technicianName;
  final String? contactName;
  final String? summary;
  final ServiceForm? serviceForm;
  final MaintenanceForm? maintenanceForm;

  const _FormHistoryEntry({
    required this.type,
    required this.formNumber,
    required this.createdAt,
    required this.customerName,
    required this.customerKey,
    required this.deviceName,
    required this.deviceKey,
    required this.serialNumber,
    this.responsibleName,
    this.technicianName,
    this.contactName,
    this.summary,
    this.serviceForm,
    this.maintenanceForm,
  });

  factory _FormHistoryEntry.fromServiceForm(ServiceForm form) {
    return _FormHistoryEntry(
      type: _FormHistoryTypeFilter.service,
      formNumber: form.formNumber,
      createdAt: form.createdAt,
      customerName: form.customer.name,
      customerKey: form.customer.key,
      deviceName: form.device.name,
      deviceKey: form.device.key,
      serialNumber: form.device.serialNumber,
      responsibleName: _firstNotBlank([
        form.device.responsiblePerson?.fullName,
        form.customerName,
        form.customer.authorizedPerson,
      ]),
      technicianName: form.technicianName,
      contactName: form.customerName,
      summary: form.problemDescription,
      serviceForm: form,
    );
  }

  factory _FormHistoryEntry.fromMaintenanceForm(MaintenanceForm form) {
    return _FormHistoryEntry(
      type: _FormHistoryTypeFilter.maintenance,
      formNumber: form.formNumber,
      createdAt: form.createdAt,
      customerName: form.customer.name,
      customerKey: form.customer.key,
      deviceName: form.device.name,
      deviceKey: form.device.key,
      serialNumber: form.device.serialNumber,
      responsibleName: _firstNotBlank([
        form.device.responsiblePerson?.fullName,
        form.customerName,
        form.customer.authorizedPerson,
      ]),
      technicianName: form.technicianName,
      contactName: form.customerName,
      summary: form.notes,
      maintenanceForm: form,
    );
  }

  static String? _firstNotBlank(Iterable<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }
}
