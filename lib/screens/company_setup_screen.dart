import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../models/company_info.dart';
import '../providers/company_provider.dart';
import '../services/sound_service.dart';
import '../widgets/address_autocomplete_field.dart';

class CompanySetupScreen extends StatefulWidget {
  final bool isFirstSetup;
  final VoidCallback? onSaveSuccess;

  const CompanySetupScreen({
    super.key,
    this.isFirstSetup = false,
    this.onSaveSuccess,
  });

  @override
  State<CompanySetupScreen> createState() => _CompanySetupScreenState();
}

class _CompanySetupScreenState extends State<CompanySetupScreen> {
  static const Color _primaryColor = Color(0xFF274C77);
  static const Color _accentColor = Color(0xFF2A9D8F);
  static const Color _surfaceColor = Color(0xFFF6F8FB);

  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _taxOfficeController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();

  Uint8List? _logoBytes;
  double _logoWidth = 150;
  double _logoHeight = 150;
  bool _isLoading = false;

  @override
  void dispose() {
    _companyNameController.dispose();
    _taxNumberController.dispose();
    _taxOfficeController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await File(pickedFile.path).readAsBytes();
        setState(() {
          _logoBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logo seçilemedi: $e')),
        );
      }
    }
  }

  void _removeLogo() {
    setState(() {
      _logoBytes = null;
    });
  }

  Future<void> _saveCompanyInfo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final companyInfo = CompanyInfo(
        companyName: _companyNameController.text.trim(),
        taxNumber: _taxNumberController.text.trim().isEmpty
            ? null
            : _taxNumberController.text.trim(),
        taxOffice: _taxOfficeController.text.trim().isEmpty
            ? null
            : _taxOfficeController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        website: _websiteController.text.trim().isEmpty
            ? null
            : _websiteController.text.trim(),
        logoBytes: _logoBytes,
        logoWidth: _logoWidth,
        logoHeight: _logoHeight,
      );

      final companyProvider = context.read<CompanyProvider>();
      await companyProvider.saveCompanyInfo(companyInfo);
      debugPrint('✅ Firma bilgileri kaydedildi');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Firma bilgileri kaydedildi'),
            backgroundColor: Colors.green,
          ),
        );

        // Callback'i 500ms sonra çalıştır UI render olsun diye
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            debugPrint('🔹 CompanySetupScreen callback çalışıyor...');
            if (widget.onSaveSuccess != null) {
              debugPrint('✅ onSaveSuccess çağrılıyor');
              widget.onSaveSuccess!();
            } else if (widget.isFirstSetup) {
              debugPrint('✅ pop(true) çağrılıyor');
              Navigator.of(context).pop(true);
            } else {
              debugPrint('✅ pop() çağrılıyor');
              Navigator.of(context).pop();
            }
          }
        });
      }
    } catch (e, stack) {
      debugPrint('🚨 HATA: $e');
      debugPrint('📍 Stack: $stack');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Hata: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyProvider = context.watch<CompanyProvider>();
    final existingInfo = companyProvider.companyInfo;

    // Mevcut bilgileri yükle (düzenleme modu)
    if (existingInfo != null &&
        _companyNameController.text.isEmpty &&
        !widget.isFirstSetup) {
      _companyNameController.text = existingInfo.companyName;
      _taxNumberController.text = existingInfo.taxNumber ?? '';
      _taxOfficeController.text = existingInfo.taxOffice ?? '';
      _addressController.text = existingInfo.address ?? '';
      _phoneController.text = existingInfo.phone ?? '';
      _emailController.text = existingInfo.email ?? '';
      _websiteController.text = existingInfo.website ?? '';
      if (_logoBytes == null && existingInfo.logoBytes != null) {
        _logoBytes = existingInfo.logoBytes;
        _logoWidth = existingInfo.logoWidth ?? 150;
        _logoHeight = existingInfo.logoHeight ?? 150;
      }
    }

    return Scaffold(
      backgroundColor: _surfaceColor,
      appBar: AppBar(
        title: Text(widget.isFirstSetup ? 'Firma Kurulumu' : 'Firma Düzenle'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeroHeader(),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      icon: Icons.image_outlined,
                      title: 'Logo ve Rapor Kimliği',
                      subtitle: 'Servis formlarında görünecek kurumsal imza.',
                      child: _buildLogoSection(),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      icon: Icons.business_center_outlined,
                      title: 'Resmi Bilgiler',
                      subtitle: 'Firma adı ve vergi bilgileri.',
                      child: Column(
                        children: [
                          _buildTextField(
                            controller: _companyNameController,
                            label: 'Firma Adı *',
                            icon: Icons.business,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Firma adı zorunludur';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildResponsivePair(
                            first: _buildTextField(
                              controller: _taxNumberController,
                              label: 'Vergi No',
                              icon: Icons.numbers,
                              keyboardType: TextInputType.number,
                            ),
                            second: _buildTextField(
                              controller: _taxOfficeController,
                              label: 'Vergi Dairesi',
                              icon: Icons.account_balance,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      icon: Icons.location_on_outlined,
                      title: 'Adres ve İletişim',
                      subtitle:
                          'Teknik servis çıktıları için standart iletişim bilgileri.',
                      child: Column(
                        children: [
                          AddressAutocompleteField(
                            controller: _addressController,
                            label: 'Adres',
                            hint: 'Sokak, Mahalle veya Kurum adı yazın...',
                            maxLines: 3,
                            required: widget.isFirstSetup,
                            validator: widget.isFirstSetup
                                ? (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Adres zorunludur';
                                    }
                                    return null;
                                  }
                                : null,
                          ),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final phoneField = _buildTextField(
                                controller: _phoneController,
                                label: widget.isFirstSetup
                                    ? 'Telefon *'
                                    : 'Telefon',
                                icon: Icons.phone,
                                keyboardType: TextInputType.phone,
                                validator: widget.isFirstSetup
                                    ? (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Telefon zorunludur';
                                        }
                                        return null;
                                      }
                                    : null,
                              );
                              if (constraints.maxWidth < 520) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    phoneField,
                                    const SizedBox(height: 10),
                                    _buildContactButton(),
                                  ],
                                );
                              }

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: phoneField),
                                  const SizedBox(width: 10),
                                  _buildContactButton(),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildResponsivePair(
                            first: _buildTextField(
                              controller: _emailController,
                              label: 'E-posta',
                              icon: Icons.email,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            second: _buildTextField(
                              controller: _websiteController,
                              label: 'Website',
                              icon: Icons.language,
                              keyboardType: TextInputType.url,
                              hint: 'www.ornek.com',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _saveCompanyInfo,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(
                            _isLoading ? 'Kaydediliyor...' : 'Firmayı Kaydet'),
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
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.16),
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
            child: const Icon(Icons.domain_verification, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isFirstSetup
                      ? 'Firma profilini tamamla'
                      : 'Firma profilini güncelle',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bu bilgiler servis formlarında, raporlarda ve PDF çıktılarında standart kimlik olarak kullanılır.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 13,
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

  Widget _buildSectionCard({
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

  Widget _buildResponsivePair({
    required Widget first,
    required Widget second,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            children: [
              first,
              const SizedBox(height: 12),
              second,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  Widget _buildContactButton() {
    return SizedBox(
      height: 56,
      child: OutlinedButton.icon(
        onPressed: _pickContactInfo,
        icon: const Icon(Icons.contact_phone, size: 18),
        label: const Text('Rehber'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _primaryColor,
          side: BorderSide(color: _primaryColor.withValues(alpha: 0.35)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
      ),
    );
  }

  Future<void> _pickContactInfo() async {
    try {
      var status = await Permission.contacts.status;

      if (status.isDenied || status.isRestricted) {
        status = await Permission.contacts.request();
        if (!mounted) return;
        if (status.isDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rehber izni gerekli')),
          );
          return;
        }
      }

      if (status.isPermanentlyDenied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rehber izni kalıcı olarak reddedildi')),
        );
        return;
      }

      final contact = await FlutterContacts.openExternalPick();
      if (!mounted) return;
      if (contact != null) {
        await SoundService().playSuccess();

        if (contact.phones.isNotEmpty) {
          _phoneController.text =
              contact.phones.first.number.replaceAll(RegExp(r'[^0-9+]'), '');
        }
        if (contact.emails.isNotEmpty && _emailController.text.isEmpty) {
          _emailController.text = contact.emails.first.address;
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('İletişim bilgileri dolduruldu'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Rehber hatası: $e');
      await SoundService().playError();
    }
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        if (_logoBytes != null)
          Column(
            children: [
              Container(
                width: _logoWidth,
                height: _logoHeight,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    _logoBytes!,
                    width: _logoWidth,
                    height: _logoHeight,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Boyut Slider
              Row(
                children: [
                  const Text('Boyut:', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: _logoWidth,
                      min: 50,
                      max: 300,
                      divisions: 25,
                      label: '${_logoWidth.round()}px',
                      onChanged: (value) {
                        setState(() {
                          _logoWidth = value;
                          _logoHeight = value;
                        });
                      },
                    ),
                  ),
                  Text('${_logoWidth.round()}px',
                      style: const TextStyle(fontSize: 12)),
                ],
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _pickLogo,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Değiştir'),
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: _removeLogo,
                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                    label: const Text('Kaldır',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          )
        else
          Column(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate,
                      size: 40,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Logo Ekle',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _pickLogo,
                icon: const Icon(Icons.upload),
                label: const Text('Logo Seç'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'PNG, JPG veya JPEG (Max 2MB)',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: _primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
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
      ),
    );
  }
}
