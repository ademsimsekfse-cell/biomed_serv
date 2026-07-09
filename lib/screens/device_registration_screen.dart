import 'package:biomed_serv/models/customer.dart';
import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/models/device_module.dart';
import 'package:biomed_serv/models/device_personel.dart';
import 'package:biomed_serv/providers/customer_provider.dart';
import 'package:biomed_serv/providers/device_personel_provider.dart';
import 'package:biomed_serv/providers/device_provider.dart';
import 'package:biomed_serv/providers/notification_provider.dart';
import 'package:biomed_serv/screens/desktop_shell_screen.dart';
import 'package:biomed_serv/screens/device_module_management_screen.dart';
import 'package:biomed_serv/services/barcode_service.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:biomed_serv/services/device_category_suggestion_service.dart';
import 'package:biomed_serv/services/sound_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Cihaz Kayıt Ekranı V2
/// Kontrol Ünitesi checkbox, SOLD/RENT gösterimi, Modül ilişkisi
class DeviceRegistrationScreen extends StatefulWidget {
  final Device?
      parentControlModule; // Eğer bu bir modül ise, bağlı olduğu ana cihaz
  final bool isAddingModule; // Modül mü ekleniyor?

  const DeviceRegistrationScreen({
    super.key,
    this.parentControlModule,
    this.isAddingModule = false,
  });

  @override
  State<DeviceRegistrationScreen> createState() =>
      _DeviceRegistrationScreenState();
}

class _DeviceRegistrationScreenState extends State<DeviceRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Controllers - Temel Bilgiler
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _serialNumberController = TextEditingController();

  // Controllers - Ek Bilgiler
  final _barcodeController = TextEditingController();
  final _locationController = TextEditingController();
  final _deviceCategoryController = TextEditingController();
  final _economicLifeController =
      TextEditingController(); // Ekonomik Ömür (Yıl)
  final _categorySuggestionService = DeviceCategorySuggestionService();

  // Personel Controllers
  final _personelFirstNameController = TextEditingController();
  final _personelLastNameController = TextEditingController();
  final _personelPhoneController = TextEditingController();
  final _personelEmailController = TextEditingController();
  final _personelTitleController = TextEditingController();

  // === YENİ STATE ALANLARI ===
  // Normal kayıtta varsayılan SOLO/STANDALONE cihazdır.
  late DeviceModuleType _selectedModuleType;

  // Sahiplik Durumu - SOLD/RENT
  OwnershipStatus _ownershipStatus = OwnershipStatus.sold;

  // Tarihler
  DateTime? _productionDate;
  DateTime? _installationDate;
  DateTime? _warrantyStartDate;
  DateTime? _warrantyEndDate;

  // Diğer
  Customer? _selectedCustomer;
  bool _hasResponsiblePerson = false;
  DevicePersonel? _selectedExistingPerson;

  // 🎯 AKILLI ÖNERİ LİSTELERİ
  List<String> _deviceNameSuggestions = [];
  List<String> _brandSuggestions = [];
  List<String> _modelSuggestions = [];
  List<String> _deviceCategorySuggestions = [];
  List<DeviceCategorySuggestion> _smartCategorySuggestions = [];

  @override
  void initState() {
    super.initState();
    _selectedModuleType = widget.isAddingModule
        ? DeviceModuleType.modularProcessing
        : DeviceModuleType.standalone;
    if (widget.isAddingModule &&
        widget.parentControlModule?.customer is Customer) {
      _selectedCustomer = widget.parentControlModule!.customer as Customer;
    }
    _nameController.addListener(_refreshCategorySuggestions);
    _brandController.addListener(_refreshCategorySuggestions);
    _modelController.addListener(_refreshCategorySuggestions);
    _serialNumberController.addListener(_refreshCategorySuggestions);

    // 🎯 Akıllı önerileri yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSuggestions();
    });
  }

  // 🎯 Mevcut cihazlardan öneri listelerini oluştur
  Future<void> _loadSuggestions() async {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    final devices = deviceProvider.devices;
    final categories =
        await _categorySuggestionService.knownCategories(devices);

    if (!mounted) return;
    setState(() {
      _deviceNameSuggestions = devices.map((d) => d.name).toSet().toList()
        ..sort();
      _brandSuggestions = devices
          .map((d) => d.brand)
          .where((b) => b.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      _modelSuggestions = devices
          .map((d) => d.model)
          .where((m) => m.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      _deviceCategorySuggestions = categories;
    });
    _refreshCategorySuggestions();
  }

  void _refreshCategorySuggestions() {
    if (!mounted) return;
    final devices = context.read<DeviceProvider>().devices;
    final suggestions = _categorySuggestionService.suggest(
      devices: devices,
      name: _nameController.text,
      brand: _brandController.text,
      model: _modelController.text,
      serialNumber: _serialNumberController.text,
    );
    if (_sameCategorySuggestions(_smartCategorySuggestions, suggestions)) {
      return;
    }
    setState(() => _smartCategorySuggestions = suggestions);
  }

  bool _sameCategorySuggestions(
    List<DeviceCategorySuggestion> first,
    List<DeviceCategorySuggestion> second,
  ) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index].category != second[index].category ||
          first[index].score != second[index].score) {
        return false;
      }
    }
    return true;
  }

  void _selectResponsiblePerson(DevicePersonel? personel) {
    setState(() {
      _selectedExistingPerson = personel;
      if (personel == null) return;
      _personelFirstNameController.text = personel.firstName;
      _personelLastNameController.text = personel.lastName;
      _personelPhoneController.text = personel.phone ?? '';
      _personelEmailController.text = personel.email ?? '';
      _personelTitleController.text = personel.title ?? '';
    });
  }

  void _clearResponsibleSelection() {
    _selectedExistingPerson = null;
    _personelFirstNameController.clear();
    _personelLastNameController.clear();
    _personelPhoneController.clear();
    _personelEmailController.clear();
    _personelTitleController.clear();
  }

  // 🎯 Öneri gösteren TextField builder
  Widget _buildLockedCustomerCard(Customer customer) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F2F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF78AAA6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Color(0xFF287C75)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kurum kontrol unitesinden otomatik alinir',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF205F5A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  customer.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF173F52),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required List<String> suggestions,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool required = false,
  }) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return suggestions;
        }
        return suggestions.where((s) =>
            s.toLowerCase().contains(textEditingValue.text.toLowerCase()));
      },
      onSelected: (String selection) {
        controller.text = selection;
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        // Controller senkronizasyonu
        if (textController.text != controller.text) {
          textController.text = controller.text;
        }

        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          textCapitalization:
              TextCapitalization.words, // 🎯 Her kelime başı büyük
          decoration: InputDecoration(
            labelText: required ? '$label *' : label,
            prefixIcon: Icon(icon),
            border: const OutlineInputBorder(),
            suffixIcon: suggestions.isNotEmpty
                ? const Icon(Icons.arrow_drop_down, color: Colors.grey)
                : null,
          ),
          validator: validator,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: (value) {
            controller.text = value;
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: MediaQuery.of(context).size.width - 64,
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(option),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSmartCategoryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF1565C0).withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: Color(0xFF1565C0)),
              SizedBox(width: 8),
              Text(
                'Akıllı kategori önerisi',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _smartCategorySuggestions.map((suggestion) {
              return ActionChip(
                avatar: const Icon(Icons.check, size: 16),
                label: Text('${suggestion.category} • ${suggestion.reason}'),
                onPressed: () {
                  _deviceCategoryController.text = suggestion.category;
                  if (!_deviceCategorySuggestions.any(
                    (item) =>
                        item.toLowerCase() == suggestion.category.toLowerCase(),
                  )) {
                    setState(() {
                      _deviceCategorySuggestions.add(suggestion.category);
                      _deviceCategorySuggestions.sort();
                    });
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _serialNumberController.dispose();
    _barcodeController.dispose();
    _locationController.dispose();
    _deviceCategoryController.dispose();
    _economicLifeController.dispose();
    _personelFirstNameController.dispose();
    _personelLastNameController.dispose();
    _personelPhoneController.dispose();
    _personelEmailController.dispose();
    _personelTitleController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, DateTime? currentDate,
      Function(DateTime) onSelected) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: currentDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      onSelected(picked);
    }
  }

  String _normalizeSerial(String value) => value.trim().toUpperCase();

  Future<void> _saveDevice() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) {
      // 🔊 Hata sesi
      await SoundService().playError();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lütfen zorunlu alanları doldurun.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final existingDevice = context
        .read<DeviceProvider>()
        .deviceWithSerial(_normalizeSerial(_serialNumberController.text));
    if (existingDevice != null) {
      await SoundService().playError();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Bu seri no zaten "${existingDevice.name}" cihazinda kayitli.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final deviceProvider =
          Provider.of<DeviceProvider>(context, listen: false);
      final personelProvider =
          Provider.of<DevicePersonelProvider>(context, listen: false);
      final notificationProvider =
          Provider.of<NotificationProvider>(context, listen: false);

      // Personel oluştur (eğer varsa)
      final draftModuleType = widget.isAddingModule
          ? DeviceModuleType.modularProcessing
          : _selectedModuleType;
      final targetCustomer = widget.isAddingModule
          ? (widget.parentControlModule?.customer ?? _selectedCustomer)
          : _selectedCustomer;

      DevicePersonel? personel;
      if (_hasResponsiblePerson) {
        if (targetCustomer == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Sorumlu personel atamak için önce kurum seçilmelidir.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        if (_personelFirstNameController.text.trim().isNotEmpty &&
            _personelLastNameController.text.trim().isNotEmpty) {
          final draftPersonel = DevicePersonel(
            firstName: _personelFirstNameController.text.trim(),
            lastName: _personelLastNameController.text.trim(),
            phone: _personelPhoneController.text.trim().isEmpty
                ? null
                : _personelPhoneController.text.trim(),
            email: _personelEmailController.text.trim().isEmpty
                ? null
                : _personelEmailController.text.trim(),
            title: _personelTitleController.text.trim().isEmpty
                ? null
                : _personelTitleController.text.trim(),
            assignedDate: DateTime.now(),
            customer: targetCustomer,
          );

          personel = personelProvider.findMatchingPersonel(
                firstName: draftPersonel.firstName,
                lastName: draftPersonel.lastName,
                phone: draftPersonel.phone,
                email: draftPersonel.email,
                customer: targetCustomer,
              ) ??
              draftPersonel;

          final draftDevice = Device(
            name: _nameController.text.trim(),
            brand: _brandController.text.trim(),
            model: _modelController.text.trim(),
            serialNumber: _normalizeSerial(_serialNumberController.text),
            customer: targetCustomer,
            moduleType: draftModuleType,
            ownershipStatus: _ownershipStatus,
            controlModule: draftModuleType == DeviceModuleType.modularProcessing
                ? widget.parentControlModule
                : null,
            responsiblePerson: personel,
          );

          if (deviceProvider.hasResponsiblePersonConflict(
            personel: personel,
            targetDevice: draftDevice,
            targetCustomer: targetCustomer,
          )) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Bu kullanici baska bir kurumdaki cihaza atanmis. Seri no bazli atamada kurumlar karistirilamaz.',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }

          personel = await personelProvider.ensurePersonel(draftPersonel);
        }
      }

      // === MODÜL TİPİNİ BELİRLE ===
      final moduleType = widget.isAddingModule
          ? DeviceModuleType.modularProcessing
          : _selectedModuleType;
      final isControlUnit = moduleType == DeviceModuleType.modularControl;

      // Cihaz oluştur - TRIM uygula
      final device = Device(
        name: _nameController.text.trim(),
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        serialNumber: _normalizeSerial(_serialNumberController.text),
        customer: targetCustomer,
        barcode: _barcodeController.text.trim().isEmpty
            ? null
            : _barcodeController.text.trim(),
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        deviceCategory: _deviceCategoryController.text.trim().isEmpty
            ? null
            : _deviceCategoryController.text.trim(),
        moduleType: moduleType,
        ownershipStatus: _ownershipStatus,
        productionDate: isControlUnit ? null : _productionDate,
        installationDate: _installationDate,
        economicLife: isControlUnit
            ? null
            : int.tryParse(_economicLifeController.text.trim()),
        warrantyStartDate: _warrantyStartDate,
        warrantyEndDate: _warrantyEndDate,
        responsiblePerson: personel,
        controlModule: moduleType == DeviceModuleType.modularProcessing
            ? widget.parentControlModule
            : null,
      );

      final savedDeviceKey = await deviceProvider.addDeviceAndReturnKey(device);
      await _categorySuggestionService.rememberCategory(
        _deviceCategoryController.text,
      );

      // Eğer bu bir kontrol ünitesi ise, DeviceModule kaydı oluştur
      if (isControlUnit && savedDeviceKey != null) {
        final deviceModule = DeviceModule(
          controlModule: device,
          description: '${device.name} kontrol ünitesi',
        );
        await dbService.deviceModulesBox.add(deviceModule);
      }

      // 🔵 Bildirim gönder (yeni cihaz kaydı)
      if (mounted && savedDeviceKey != null) {
        await notificationProvider.createDeviceNotification(
            device, savedDeviceKey);
      }

      // 🔊 Başarı sesi
      await SoundService().playSaveSuccess();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${_nameController.text.trim()} başarıyla kaydedildi.'),
            backgroundColor: Colors.green,
          ),
        );

        // Eğer ana modül kaydedildiyse, modül yönetimi ekranına yönlendir
        if (isControlUnit && savedDeviceKey != null) {
          final savedDevice =
              deviceProvider.devices.firstWhere((d) => d.key == savedDeviceKey);
          openDesktopAwareScreen(
            context,
            DeviceModuleManagementScreen(controlDevice: savedDevice),
            replacement: true,
          );
        } else {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kayıt hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool get _isControlUnit =>
      _selectedModuleType == DeviceModuleType.modularControl;

  /// Detaylı alanlar gösterilmeli mi? (Kontrol ünitesi değilse)
  bool get _showDetailedFields => !_isControlUnit;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isAddingModule
            ? 'Modül Ekle: ${widget.parentControlModule?.name}'
            : 'Yeni Cihaz Kaydı'),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // === BAŞLIK ===
                  if (widget.isAddingModule)
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.info, color: Colors.blue),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Bu modül "${widget.parentControlModule?.name}" kontrol ünitesine bağlanacak.',
                                style: const TextStyle(color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (widget.isAddingModule) const SizedBox(height: 16),

                  // === CİHAZ TİPİ ===
                  if (!widget.isAddingModule) ...[
                    _buildSectionTitle('Cihaz Tipi'),
                    _buildDeviceTypeSelector(),
                    const SizedBox(height: 16),
                  ] else ...[
                    _buildLockedModuleInfo(),
                    const SizedBox(height: 16),
                  ],

                  // === SAHİPLİK DURUMU - SOLD/RENT ===
                  _buildSectionTitle('Sahiplik Durumu'),
                  _buildOwnershipSelector(),

                  const SizedBox(height: 16),

                  // === TEMEL BİLGİLER ===
                  _buildSectionTitle('Temel Bilgiler'),

                  // 🎯 CİHAZ ADI - Akıllı Öneri
                  _buildSuggestionField(
                    controller: _nameController,
                    label: 'Cihaz Adı',
                    icon: Icons.devices,
                    suggestions: _deviceNameSuggestions,
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Cihaz adı zorunludur' : null,
                    required: true,
                  ),
                  const SizedBox(height: 12),

                  _buildResponsiveFields(
                    [
                      // 🎯 MARKA - Akıllı Öneri
                      _buildSuggestionField(
                        controller: _brandController,
                        label: 'Marka',
                        icon: Icons.label,
                        suggestions: _brandSuggestions,
                        validator: (v) =>
                            v!.trim().isEmpty ? 'Marka zorunludur' : null,
                        required: true,
                      ),
                      // 🎯 MODEL - Akıllı Öneri
                      _buildSuggestionField(
                        controller: _modelController,
                        label: 'Model',
                        icon: Icons.category,
                        suggestions: _modelSuggestions,
                        validator: (v) =>
                            v!.trim().isEmpty ? 'Model zorunludur' : null,
                        required: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Seri Numarası - Büyük Harf Otomatik
                  TextFormField(
                    controller: _serialNumberController,
                    textCapitalization:
                        TextCapitalization.characters, // 🎯 Tümü büyük harf
                    decoration: const InputDecoration(
                      labelText: 'Seri Numarası *',
                      prefixIcon: Icon(Icons.confirmation_number),
                      border: OutlineInputBorder(),
                    ),
                    inputFormatters: [_UpperCaseTextFormatter()],
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Seri numarası zorunludur' : null,
                  ),

                  const SizedBox(height: 16),

                  // === ÜRETİM TARİHİ + KULLANIM SÜRESİ (Kontrol ünitesi değilse) ===
                  if (_showDetailedFields) ...[
                    _buildSectionTitle('Üretim ve Kullanım Süresi'),
                    _buildResponsiveFields(
                      [
                        Expanded(
                          child: InkWell(
                            onTap: () =>
                                _selectDate(context, _productionDate, (date) {
                              setState(() => _productionDate = date);
                            }),
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _economicLifeController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Kullanım Süresi (Yıl)',
                              prefixIcon: Icon(Icons.timer),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // === KURULUM VE GARANTİ ===
                  _buildSectionTitle('Kurulum ve Garanti'),
                  _buildResponsiveFields(
                    [
                      Expanded(
                        child: InkWell(
                          onTap: () =>
                              _selectDate(context, _installationDate, (date) {
                            setState(() => _installationDate = date);
                          }),
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
                  const SizedBox(height: 12),
                  _buildResponsiveFields(
                    [
                      Expanded(
                        child: InkWell(
                          onTap: () =>
                              _selectDate(context, _warrantyStartDate, (date) {
                            setState(() => _warrantyStartDate = date);
                          }),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Garanti Başlangıç',
                              prefixIcon: Icon(Icons.security),
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              _warrantyStartDate != null
                                  ? dateFormat.format(_warrantyStartDate!)
                                  : 'Seçilmedi',
                              style: TextStyle(
                                color: _warrantyStartDate != null
                                    ? Colors.black
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () =>
                              _selectDate(context, _warrantyEndDate, (date) {
                            setState(() => _warrantyEndDate = date);
                          }),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Garanti Bitiş',
                              prefixIcon: Icon(Icons.event_busy),
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              _warrantyEndDate != null
                                  ? dateFormat.format(_warrantyEndDate!)
                                  : 'Seçilmedi',
                              style: TextStyle(
                                color: _warrantyEndDate != null
                                    ? Colors.black
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // === BARKOD ===
                  _buildSectionTitle('Barkod'),
                  TextFormField(
                    controller: _barcodeController,
                    textCapitalization:
                        TextCapitalization.characters, // 🎯 Tümü büyük harf
                    decoration: InputDecoration(
                      labelText: 'Barkod',
                      prefixIcon: const Icon(Icons.qr_code),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.qr_code_scanner,
                            color: Colors.deepPurple),
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

                  const SizedBox(height: 16),

                  // === KURUM ATAMA (Opsiyonel) ===
                  _buildSectionTitle('Kurum Atama (Opsiyonel)'),
                  Consumer<CustomerProvider>(
                    builder: (context, customerProvider, child) {
                      if (widget.isAddingModule &&
                          widget.parentControlModule?.customer is Customer) {
                        return _buildLockedCustomerCard(
                          widget.parentControlModule!.customer as Customer,
                        );
                      }
                      return DropdownButtonFormField<Customer>(
                        isExpanded: true,
                        initialValue: _selectedCustomer,
                        decoration: const InputDecoration(
                          labelText: 'Kurum/Müşteri',
                          prefixIcon: Icon(Icons.business),
                          hintText: 'Kurum seçin (opsiyonel)',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<Customer>(
                            value: null,
                            child: Text('Kurum atama (daha sonra yapılacak)'),
                          ),
                          ...customerProvider.customers
                              .map((Customer customer) {
                            return DropdownMenuItem<Customer>(
                              value: customer,
                              child: Text(
                                customer.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: (Customer? newValue) {
                          setState(() {
                            if (_selectedCustomer?.key != newValue?.key) {
                              _clearResponsibleSelection();
                            }
                            _selectedCustomer = newValue;
                          });
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // === EK BİLGİLER ===
                  _buildSectionTitle('Ek Bilgiler'),
                  _buildSuggestionField(
                    controller: _deviceCategoryController,
                    label: 'Cihaz Kategorisi',
                    icon: Icons.folder,
                    suggestions: _deviceCategorySuggestions,
                  ),
                  if (_smartCategorySuggestions.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildSmartCategoryCard(),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _locationController,
                    textCapitalization:
                        TextCapitalization.words, // 🎯 Her kelime başı büyük
                    decoration: const InputDecoration(
                      labelText: 'Fiziksel Lokasyon',
                      prefixIcon: Icon(Icons.location_on),
                      hintText: 'Örn: 3. Kat, Oda 305',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // === SORUMLU PERSONEL ===
                  _buildSectionTitle('Sorumlu Personel'),
                  SwitchListTile(
                    title: const Text('Sorumlu personel ata'),
                    subtitle: const Text('Cihaz için sorumlu kişi belirle'),
                    value: _hasResponsiblePerson,
                    onChanged: (value) {
                      setState(() => _hasResponsiblePerson = value);
                    },
                  ),
                  if (_hasResponsiblePerson) ...[
                    const SizedBox(height: 12),
                    Consumer<DevicePersonelProvider>(
                      builder: (context, personelProvider, child) {
                        final targetCustomer = widget.isAddingModule
                            ? widget.parentControlModule?.customer
                            : _selectedCustomer;
                        final people = personelProvider
                            .availablePersonelsForCustomer(targetCustomer);
                        if (targetCustomer == null) {
                          return const Card(
                            child: ListTile(
                              leading: Icon(Icons.info_outline),
                              title: Text('Önce kurum seçin'),
                              subtitle: Text(
                                'Sorumlu personel yalnızca bağlı olduğu kurumun cihazına atanabilir.',
                              ),
                            ),
                          );
                        }
                        return DropdownButtonFormField<DevicePersonel>(
                          isExpanded: true,
                          initialValue: people.any(
                            (item) => item.key == _selectedExistingPerson?.key,
                          )
                              ? _selectedExistingPerson
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Kurum personelinden seç',
                            prefixIcon: Icon(Icons.badge_outlined),
                            border: OutlineInputBorder(),
                          ),
                          items: people
                              .map(
                                (personel) => DropdownMenuItem<DevicePersonel>(
                                  value: personel,
                                  child: Text(
                                    '${personel.fullName}${personel.title?.isNotEmpty == true ? ' • ${personel.title}' : ''}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _selectResponsiblePerson,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildResponsiveFields(
                      [
                        Expanded(
                          child: TextFormField(
                            controller: _personelFirstNameController,
                            textCapitalization: TextCapitalization
                                .words, // 🎯 Her kelime başı büyük
                            decoration: const InputDecoration(
                              labelText: 'İsim *',
                              prefixIcon: Icon(Icons.person),
                              border: OutlineInputBorder(),
                            ),
                            validator: _hasResponsiblePerson
                                ? (v) => v!.isEmpty ? 'İsim zorunludur' : null
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _personelLastNameController,
                            textCapitalization: TextCapitalization
                                .words, // 🎯 Her kelime başı büyük
                            decoration: const InputDecoration(
                              labelText: 'Soyisim *',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                            ),
                            validator: _hasResponsiblePerson
                                ? (v) =>
                                    v!.isEmpty ? 'Soyisim zorunludur' : null
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _personelPhoneController,
                      decoration: const InputDecoration(
                        labelText: 'Telefon',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _personelEmailController,
                      decoration: const InputDecoration(
                        labelText: 'E-posta',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _personelTitleController,
                      textCapitalization:
                          TextCapitalization.words, // 🎯 Her kelime başı büyük
                      decoration: const InputDecoration(
                        labelText: 'Unvan/Departman',
                        prefixIcon: Icon(Icons.work),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // === KAYDET BUTONU ===
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveDevice,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label:
                          Text(_isSaving ? 'Kaydediliyor...' : 'CİHAZI KAYDET'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
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
      padding: const EdgeInsets.only(bottom: 12, top: 8),
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
    double spacing = 12,
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

  Widget _buildOwnershipSelector() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final soldOption = _buildOwnershipOption(
          status: OwnershipStatus.sold,
          icon: Icons.verified,
          color: Colors.green,
          title: 'SOLD',
          subtitle: 'Satılmış cihaz',
        );
        final rentedOption = _buildOwnershipOption(
          status: OwnershipStatus.rented,
          icon: Icons.cached,
          color: Colors.orange,
          title: 'RENT',
          subtitle: 'Kiralık cihaz',
        );

        if (constraints.maxWidth < 420) {
          return Column(
            children: [
              soldOption,
              const SizedBox(height: 10),
              rentedOption,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: soldOption),
            const SizedBox(width: 10),
            Expanded(child: rentedOption),
          ],
        );
      },
    );
  }

  Widget _buildOwnershipOption({
    required OwnershipStatus status,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _ownershipStatus == status;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        setState(() => _ownershipStatus = status);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.09) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isSelected ? color : Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? color : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceTypeSelector() {
    return Column(
      children: [
        _buildDeviceTypeOption(
          type: DeviceModuleType.standalone,
          icon: Icons.devices_other,
          color: Colors.teal,
          title: 'Bağımsız Cihaz (SOLO / STANDALONE)',
          subtitle:
              'Kontrol ünitesi olmayan, tek başına çalışan cihazlar için. Ad, model, seri no ve tüm detaylar normal şekilde kaydedilir.',
        ),
        const SizedBox(height: 10),
        _buildDeviceTypeOption(
          type: DeviceModuleType.modularControl,
          icon: Icons.account_tree,
          color: Colors.deepPurple,
          title: 'Kontrol Ünitesi',
          subtitle:
              'Alt modülleri taşıyan ana cihazlar için. Kayıttan sonra bu üniteye modül eklenebilir.',
        ),
        if (_isControlUnit) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Kontrol ünitesi seçildi. Bu cihaz ana modül olarak kaydedilecek; üretim tarihi ve ekonomik ömür alanları gizlenir.',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDeviceTypeOption({
    required DeviceModuleType type,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedModuleType == type;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        setState(() => _selectedModuleType = type);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.09) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isSelected ? color : Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? color : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedModuleInfo() {
    final controlName =
        widget.parentControlModule?.name ?? 'seçili kontrol ünitesi';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.memory, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bağlı Modül',
                  style: TextStyle(
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bu kayıt "$controlName" kontrol ünitesine bağlı alt modül olarak oluşturulacak.',
                  style: TextStyle(
                    color: Colors.blue.shade800,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
