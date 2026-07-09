import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../models/technician.dart';
import '../providers/technician_provider.dart';
import '../services/sound_service.dart';

class TechnicianSetupScreen extends StatefulWidget {
  final bool isFirstSetup;
  final VoidCallback? onSaveSuccess;
  final Technician? initialTechnician;
  final int? technicianIndex;

  const TechnicianSetupScreen({
    super.key,
    this.isFirstSetup = false,
    this.onSaveSuccess,
    this.initialTechnician,
    this.technicianIndex,
  });

  @override
  State<TechnicianSetupScreen> createState() => _TechnicianSetupScreenState();
}

class _TechnicianSetupScreenState extends State<TechnicianSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _titleController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  Uint8List? _photoBytes;

  bool _isLoading = false;
  bool get _isEditing => widget.initialTechnician != null;
  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    final technician = widget.initialTechnician;
    if (technician != null) {
      _firstNameController.text = technician.firstName;
      _lastNameController.text = technician.lastName;
      _titleController.text = technician.title ?? '';
      _phoneController.text = technician.phone ?? '';
      _emailController.text = technician.email ?? '';
      _photoBytes = technician.photoBytes;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _titleController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveTechnician() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final technician = Technician(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        title: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        photoBytes: _photoBytes,
        address: widget.initialTechnician?.address,
      );

      final provider = context.read<TechnicianProvider>();
      debugPrint('🔹 Provider: $provider');
      debugPrint('🔹 Box açık mı: ${provider.technicianBox != null}');

      if (_isEditing && widget.technicianIndex != null) {
        await provider.updateTechnician(widget.technicianIndex!, technician);
      } else if (_isMobile && provider.technicians.isNotEmpty) {
        await provider.updateTechnician(0, technician);
      } else {
        await provider.addTechnician(technician);
      }
      debugPrint('✅ Teknisyen DB\'ye kaydedildi');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? '✅ Teknisyen güncellendi' : '✅ Teknisyen kaydedildi',
            ),
            backgroundColor: Colors.green,
          ),
        );
        debugPrint(
            '🔹 mounted: true, callback: ${widget.onSaveSuccess != null}');

        // Callback'i 500ms sonra çalıştır UI render olsun diye
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            debugPrint('🔹 Callback çalışıyor...');
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);

    if (widget.isFirstSetup) {
      return Material(
        color: Colors.grey.shade50,
        child: content,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isFirstSetup
            ? 'Teknisyen Kaydı'
            : _isEditing
                ? 'Teknisyen Bilgileri'
                : 'Yeni Teknisyen'),
        backgroundColor: Colors.blue,
      ),
      body: content,
    );
  }

  Widget _buildContent(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight.isFinite
                  ? constraints.maxHeight - 46
                  : 0,
            ),
            child: Form(
              key: _formKey,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade400,
                              Colors.blue.shade700
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.person_add,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.isFirstSetup
                                        ? 'Hoş Geldiniz!'
                                        : _isEditing
                                            ? 'Bilgileri Düzenle'
                                            : 'Teknisyen Ekle',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.isFirstSetup
                                        ? 'Lütfen bilgilerinizi girin. Mobil uygulama bu teknisyen kimliğiyle çalışacak.'
                                        : _isEditing
                                            ? 'Bu bilgiler servis formlarında, raporlarda ve desktop onayında kullanılacak.'
                                            : 'Yeni teknisyen bilgilerini girin.',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.9),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                      _buildPhotoPicker(),
                      const SizedBox(height: 20),

                      // Ad
                      _buildTextField(
                        controller: _firstNameController,
                        label: 'Adı',
                        icon: Icons.person,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ad zorunludur';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Soyad
                      _buildTextField(
                        controller: _lastNameController,
                        label: 'Soyadı',
                        icon: Icons.person_outline,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Soyad zorunludur';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _titleController,
                        label: 'Unvan',
                        icon: Icons.badge,
                        hint: 'Biyomedikal Teknikeri, Servis Uzmanı...',
                      ),

                      const SizedBox(height: 16),

                      // Telefon + Rehber Butonu
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _phoneController,
                              label: 'Telefon',
                              icon: Icons.phone,
                              keyboardType: TextInputType.phone,
                              hint: '0 (5XX) XXX XX XX',
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 🎯 REHBER BUTONU
                          ElevatedButton.icon(
                            onPressed: () => _pickPhoneFromContacts(context),
                            icon: const Icon(Icons.contact_phone, size: 18),
                            label: const Text('Rehber'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade50,
                              foregroundColor: Colors.blue.shade700,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Email
                      _buildTextField(
                        controller: _emailController,
                        label: 'E-posta',
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                        hint: 'ornek@email.com',
                      ),

                      const SizedBox(height: 40),

                      // Kaydet Butonu
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _saveTechnician,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save),
                          label:
                              Text(_isLoading ? 'Kaydediliyor...' : 'Kaydet'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhotoPicker() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: Colors.blue.shade50,
              backgroundImage:
                  _photoBytes == null ? null : MemoryImage(_photoBytes!),
              child: _photoBytes == null
                  ? Icon(Icons.person, color: Colors.blue.shade700, size: 32)
                  : null,
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profil fotoğrafı',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Ana sayfa ve rapor kimliğinde kullanılır.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ],
              ),
            ),
            PopupMenuButton<ImageSource>(
              tooltip: 'Fotoğraf seç',
              onSelected: _pickPhoto,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: ImageSource.camera,
                  child: ListTile(
                    leading: Icon(Icons.photo_camera),
                    title: Text('Kamera'),
                  ),
                ),
                PopupMenuItem(
                  value: ImageSource.gallery,
                  child: ListTile(
                    leading: Icon(Icons.photo_library),
                    title: Text('Galeri'),
                  ),
                ),
              ],
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_a_photo,
                        size: 18, color: Colors.blue.shade700),
                    const SizedBox(width: 6),
                    Text(
                      _photoBytes == null ? 'Ekle' : 'Değiştir',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 78,
        maxWidth: 900,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() => _photoBytes = bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fotoğraf seçilemedi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.blue),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  /// 🎯 Rehberden telefon numarası seç - Güvenli versiyon
  Future<void> _pickPhoneFromContacts(BuildContext context) async {
    try {
      // 🛡️ Önce izin kontrolü
      var status = await Permission.contacts.status;

      if (status.isDenied || status.isRestricted) {
        status = await Permission.contacts.request();

        if (status.isDenied) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ Rehber erişimi için izin gerekli'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      if (status.isPermanentlyDenied) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '❌ İzin kalıcı olarak reddedildi. Ayarlardan izin verin.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // ✅ İzin var, rehberi aç
      final selectedContact = await FlutterContacts.openExternalPick();

      if (selectedContact != null && context.mounted) {
        // 🔊 Başarı sesi
        await SoundService().playSuccess();
        if (!context.mounted) return;

        // Ad soyad bilgilerini doldur (varsa)
        if (selectedContact.name.first.isNotEmpty) {
          _firstNameController.text = selectedContact.name.first;
        }
        if (selectedContact.name.last.isNotEmpty) {
          _lastNameController.text = selectedContact.name.last;
        }

        // Telefon numarasını doldur
        final phones = selectedContact.phones;
        if (phones.isNotEmpty) {
          final phone = phones.first.number;
          _phoneController.text = phone.replaceAll(RegExp(r'[^0-9+]'), '');
        }

        // E-posta varsa doldur
        final emails = selectedContact.emails;
        if (emails.isNotEmpty && _emailController.text.isEmpty) {
          _emailController.text = emails.first.address;
        }

        // Başarı bildirimi
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Kişi bilgileri dolduruldu'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('🚨 Rehber hatası: $e');
      debugPrint('🚨 Stack trace: $stackTrace');

      if (context.mounted) {
        await SoundService().playError();
        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Rehber erişim hatası: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
