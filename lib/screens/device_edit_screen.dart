import 'package:biomed_serv/models/customer.dart';
import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/models/device_personel.dart';
import 'package:biomed_serv/providers/customer_provider.dart';
import 'package:biomed_serv/providers/device_personel_provider.dart';
import 'package:biomed_serv/providers/device_provider.dart';
import 'package:biomed_serv/services/barcode_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class DeviceEditScreen extends StatefulWidget {
  final Device device;

  const DeviceEditScreen({
    super.key,
    required this.device,
  });

  @override
  State<DeviceEditScreen> createState() => _DeviceEditScreenState();
}

class _DeviceEditScreenState extends State<DeviceEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Controllers
  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _modelController;
  late final TextEditingController _serialNumberController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _groupController;
  late final TextEditingController _economicLifeController;

  // State
  Customer? _selectedCustomer;
  DevicePersonel? _selectedPersonel;
  DateTime? _productionDate;
  DateTime? _installationDate;

  @override
  void initState() {
    super.initState();
    // Mevcut değerleri yükle
    _nameController = TextEditingController(text: widget.device.name);
    _brandController = TextEditingController(text: widget.device.brand);
    _modelController = TextEditingController(text: widget.device.model);
    _serialNumberController =
        TextEditingController(text: widget.device.serialNumber);
    _barcodeController =
        TextEditingController(text: widget.device.barcode ?? '');
    _groupController = TextEditingController(text: widget.device.group ?? '');
    _economicLifeController = TextEditingController(
      text: widget.device.economicLife?.toString() ?? '',
    );
    _selectedCustomer = widget.device.customer as Customer?;
    _selectedPersonel = widget.device.responsiblePerson;
    _productionDate = widget.device.productionDate;
    _installationDate = widget.device.installationDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _serialNumberController.dispose();
    _barcodeController.dispose();
    _groupController.dispose();
    _economicLifeController.dispose();
    super.dispose();
  }

  Future<void> _saveDevice() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen tüm zorunlu alanları doldurun.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final deviceProvider =
          Provider.of<DeviceProvider>(context, listen: false);
      final personelProvider =
          Provider.of<DevicePersonelProvider>(context, listen: false);
      final selectedCustomer = _resolveCustomer(
        _selectedCustomer,
        context.read<CustomerProvider>().customers,
      );
      final selectedPersonel = _resolvePersonel(
        _selectedPersonel,
        personelProvider.personels,
        selectedCustomer,
      );
      final previousCustomerKey = widget.device.customer?.key;

      // Cihazı güncelle (mevcut değerleri koru + yeni değerler)
      final updatedDevice = Device(
        name: _nameController.text,
        brand: _brandController.text,
        model: _modelController.text,
        serialNumber: _serialNumberController.text,
        customer: selectedCustomer,
        responsiblePerson: selectedPersonel,
        barcode:
            _barcodeController.text.isEmpty ? null : _barcodeController.text,
        group: _groupController.text.isEmpty ? null : _groupController.text,
        productionDate: _productionDate,
        installationDate: _installationDate,
        economicLife: _economicLifeController.text.isEmpty
            ? null
            : int.tryParse(_economicLifeController.text),
        // Mevcut değerleri koru
        moduleType: widget.device.moduleType,
        ownershipStatus: widget.device.ownershipStatus,
        controlModule: widget.device.controlModule,
        serviceDuration: widget.device.serviceDuration,
        warrantyStartDate: widget.device.warrantyStartDate,
        warrantyEndDate: widget.device.warrantyEndDate,
        location: widget.device.location,
        deviceCategory: widget.device.deviceCategory,
      );

      if (selectedPersonel != null &&
          deviceProvider.hasResponsiblePersonConflict(
            personel: selectedPersonel,
            targetDevice: widget.device,
            targetCustomer: selectedCustomer,
          )) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Bu kullanıcı başka bir kurumdaki cihaza atanmış. Seri no bazlı atamada kurumlar karıştırılamaz.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (selectedPersonel != null &&
          selectedPersonel.customer == null &&
          selectedCustomer != null &&
          selectedPersonel.key is int) {
        selectedPersonel.customer = selectedCustomer;
        await personelProvider.updatePersonel(
          selectedPersonel.key as int,
          selectedPersonel,
        );
      }

      await deviceProvider.updateDevice(widget.device.key!, updatedDevice);

      if (mounted) {
        final chainSize = deviceProvider.chainSizeForDevice(updatedDevice);
        final customerChanged = previousCustomerKey != selectedCustomer?.key;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              customerChanged && chainSize > 1
                  ? 'Cihaz güncellendi. Bağlı $chainSize cihaz aynı kurumla eşitlendi.'
                  : 'Cihaz başarıyla güncellendi.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Güncelleme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Customer? _resolveCustomer(Customer? selected, List<Customer> customers) {
    if (selected == null) return null;

    for (final customer in customers) {
      if (selected.key != null && customer.key == selected.key) {
        return customer;
      }
    }

    final selectedName = selected.name.trim().toLowerCase();
    final selectedPhone = selected.phone.trim();
    for (final customer in customers) {
      if (customer.name.trim().toLowerCase() == selectedName &&
          (selectedPhone.isEmpty || customer.phone.trim() == selectedPhone)) {
        return customer;
      }
    }

    return null;
  }

  DevicePersonel? _resolvePersonel(
    DevicePersonel? selected,
    List<DevicePersonel> personels,
    Customer? selectedCustomer,
  ) {
    if (selected == null) return null;

    for (final personel in personels) {
      if (selected.key != null && personel.key == selected.key) {
        if (!_personelMatchesCustomer(personel, selectedCustomer)) return null;
        return personel;
      }
    }

    final selectedName = selected.fullName.trim().toLowerCase();
    final selectedPhone = selected.phone?.trim();
    final selectedEmail = selected.email?.trim().toLowerCase();
    for (final personel in personels) {
      final phoneMatches = selectedPhone == null ||
          selectedPhone.isEmpty ||
          personel.phone?.trim() == selectedPhone;
      final emailMatches = selectedEmail == null ||
          selectedEmail.isEmpty ||
          personel.email?.trim().toLowerCase() == selectedEmail;

      if (personel.fullName.trim().toLowerCase() == selectedName &&
          phoneMatches &&
          emailMatches &&
          _personelMatchesCustomer(personel, selectedCustomer)) {
        return personel;
      }
    }

    return null;
  }

  bool _personelMatchesCustomer(
    DevicePersonel personel,
    Customer? selectedCustomer,
  ) {
    if (selectedCustomer?.key == null) return false;
    final personelCustomerKey = personel.customer?.key;
    return personelCustomerKey == null ||
        personelCustomerKey == selectedCustomer!.key;
  }

  Widget _buildChainImpactCard(BuildContext context) {
    return Consumer<DeviceProvider>(
      builder: (context, deviceProvider, child) {
        final linkedDevices =
            deviceProvider.linkedDevicesForDevice(widget.device);
        final chainSize = linkedDevices.length;
        final currentCustomer = widget.device.customer as Customer?;
        final selectedCustomer = _selectedCustomer;
        final customerChanged = currentCustomer?.key != selectedCustomer?.key;
        final controlUnit = deviceProvider.controlUnitForDevice(widget.device);

        if (chainSize <= 1) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.devices, color: Colors.grey.shade700, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Bu cihaz bağımsız çalışır. Kurum değişikliği yalnızca bu kaydı etkiler.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: customerChanged ? Colors.amber.shade50 : Colors.teal.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: customerChanged
                  ? Colors.amber.shade200
                  : Colors.teal.shade100,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    customerChanged ? Icons.sync_alt : Icons.hub,
                    color: customerChanged
                        ? Colors.amber.shade800
                        : Colors.teal.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      customerChanged
                          ? 'Kaydettiğinizde kurum ataması bu zincirdeki $chainSize cihazı birlikte güncelleyecek.'
                          : 'Bu cihaz $chainSize parçalık bir zincire bağlı. Kurum ataması zincir genelinde birlikte tutulur.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: customerChanged
                            ? Colors.amber.shade900
                            : Colors.teal.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (controlUnit != null)
                Text(
                  'Ana ünite: ${controlUnit.name} / ${controlUnit.serialNumber}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: linkedDevices.take(6).map((linkedDevice) {
                  final isCurrent = linkedDevice.key == widget.device.key;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isCurrent
                            ? Theme.of(context)
                                .primaryColor
                                .withValues(alpha: 0.35)
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      '${linkedDevice.name}${isCurrent ? ' (bu kayıt)' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (linkedDevices.length > 6) ...[
                const SizedBox(height: 8),
                Text(
                  '+${linkedDevices.length - 6} bağlı cihaz daha var',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context, bool isProductionDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: (isProductionDate ? _productionDate : _installationDate) ??
          DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isProductionDate) {
          _productionDate = picked;
        } else {
          _installationDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cihaz Düzenle'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveDevice,
              tooltip: 'Kaydet',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Temel Bilgiler
                  _buildSectionTitle('Temel Bilgiler'),
                  Consumer<CustomerProvider>(
                    builder: (context, customerProvider, child) {
                      final selectedCustomer = _resolveCustomer(
                        _selectedCustomer,
                        customerProvider.customers,
                      );
                      return DropdownButtonFormField<Customer>(
                        isExpanded: true,
                        initialValue: selectedCustomer,
                        decoration: const InputDecoration(
                          labelText: 'Müşteri *',
                          prefixIcon: Icon(Icons.business),
                          border: OutlineInputBorder(),
                        ),
                        items:
                            customerProvider.customers.map((Customer customer) {
                          return DropdownMenuItem<Customer>(
                            value: customer,
                            child: Text(
                              customer.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (Customer? newValue) {
                          setState(() {
                            _selectedCustomer = newValue;
                            if (_selectedPersonel != null &&
                                !_personelMatchesCustomer(
                                  _selectedPersonel!,
                                  newValue,
                                )) {
                              _selectedPersonel = null;
                            }
                          });
                        },
                        validator: (v) =>
                            v == null ? 'Müşteri seçimi zorunludur' : null,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildChainImpactCard(context),
                  const SizedBox(height: 16),
                  // 👤 Sorumlu Personel Seçimi
                  Consumer<DevicePersonelProvider>(
                    builder: (context, personelProvider, child) {
                      final responsibleCustomer = _resolveCustomer(
                        _selectedCustomer,
                        context.watch<CustomerProvider>().customers,
                      );
                      final selectedPersonel = _resolvePersonel(
                        _selectedPersonel,
                        personelProvider.personels,
                        responsibleCustomer,
                      );
                      final eligiblePersonels = personelProvider.personels
                          .where(
                            (personel) =>
                                _personelMatchesCustomer(
                                  personel,
                                  responsibleCustomer,
                                ) ||
                                (selectedPersonel != null &&
                                    personel.key == selectedPersonel.key),
                          )
                          .toList();
                      return DropdownButtonFormField<DevicePersonel?>(
                        isExpanded: true,
                        initialValue: selectedPersonel,
                        decoration: InputDecoration(
                          labelText: 'Sorumlu Personel',
                          prefixIcon: Icon(Icons.person, color: Colors.orange),
                          border: OutlineInputBorder(),
                          helperText: widget.device.isProcessingModule
                              ? 'Bu modüle özel personel atayabilirsiniz'
                              : 'Cihaz sorumlusu seçin (opsiyonel)',
                        ),
                        items: [
                          DropdownMenuItem<DevicePersonel?>(
                            value: null,
                            child: Text(
                              'Personel Seçin (Opsiyonel)',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ),
                          ...eligiblePersonels.map((DevicePersonel personel) {
                            return DropdownMenuItem<DevicePersonel?>(
                              value: personel,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.deepPurple.shade100,
                                    child: Text(
                                      personel.fullName.isNotEmpty
                                          ? personel.fullName[0]
                                          : '?',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.deepPurple,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          personel.fullName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w500),
                                        ),
                                        if (personel.title != null)
                                          Text(
                                            personel.title!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                        onChanged: (DevicePersonel? newValue) {
                          setState(() => _selectedPersonel = newValue);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Cihaz Adı *',
                      prefixIcon: Icon(Icons.devices),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v!.isEmpty ? 'Cihaz adı zorunludur' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildResponsiveFields(
                    [
                      Expanded(
                        child: TextFormField(
                          controller: _brandController,
                          decoration: const InputDecoration(
                            labelText: 'Marka *',
                            prefixIcon: Icon(Icons.label),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              v!.isEmpty ? 'Marka zorunludur' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _modelController,
                          decoration: const InputDecoration(
                            labelText: 'Model *',
                            prefixIcon: Icon(Icons.category),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              v!.isEmpty ? 'Model zorunludur' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _serialNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Seri Numarası *',
                      prefixIcon: Icon(Icons.confirmation_number),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v!.isEmpty ? 'Seri numarası zorunludur' : null,
                  ),

                  const SizedBox(height: 24),
                  // Barkod
                  _buildSectionTitle('Barkod'),
                  TextFormField(
                    controller: _barcodeController,
                    decoration: InputDecoration(
                      labelText: 'Barkod',
                      prefixIcon: const Icon(Icons.qr_code),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: () async {
                          final barcode =
                              await BarcodeService().scanBarcode(context);
                          if (barcode.isNotEmpty) {
                            setState(() => _barcodeController.text = barcode);
                          }
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 24),
                  // Grup ve Ekonomik Ömür
                  _buildSectionTitle('Sınıflandırma'),
                  TextFormField(
                    controller: _groupController,
                    decoration: const InputDecoration(
                      labelText: 'Cihaz Grubu',
                      prefixIcon: Icon(Icons.folder),
                      hintText: 'Örn: Radyoloji, Laboratuvar vb.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _economicLifeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Ekonomik Ömür (Yıl)',
                      prefixIcon: Icon(Icons.timer),
                      hintText: 'Örn: 5',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 24),
                  // Tarihler
                  _buildSectionTitle('Tarihler'),
                  _buildResponsiveFields(
                    [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context, true),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Üretim Tarihi',
                              prefixIcon: Icon(Icons.calendar_today),
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              _productionDate != null
                                  ? dateFormat.format(_productionDate!)
                                  : 'Seçilmedi',
                              style: TextStyle(
                                color: _productionDate != null
                                    ? Colors.black
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context, false),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Kurulum Tarihi',
                              prefixIcon: Icon(Icons.install_mobile),
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              _installationDate != null
                                  ? dateFormat.format(_installationDate!)
                                  : 'Seçilmedi',
                              style: TextStyle(
                                color: _installationDate != null
                                    ? Colors.black
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  // Kaydet Butonu
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveDevice,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isSaving
                        ? 'Kaydediliyor...'
                        : 'DEĞİŞİKLİKLERİ KAYDET'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple,
        ),
      ),
    );
  }

  Widget _buildResponsiveFields(
    List<Widget> children, {
    double breakpoint = 680,
    double spacing = 16,
  }) {
    final fields = children
        .where((child) => child is! SizedBox)
        .map((child) => child is Expanded ? child.child : child)
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            children: [
              for (var i = 0; i < fields.length; i++) ...[
                fields[i],
                if (i != fields.length - 1) SizedBox(height: spacing),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < fields.length; i++) ...[
              Expanded(child: fields[i]),
              if (i != fields.length - 1) SizedBox(width: spacing),
            ],
          ],
        );
      },
    );
  }
}
