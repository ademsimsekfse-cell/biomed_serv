import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/sound_service.dart';

/// Rehberden kişi seçimi için widget
/// Telefon numarası alanı yanında rehber butonu içerir
class ContactPickerField extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final String label;
  final String? hintName;
  final String? hintPhone;
  final bool nameRequired;
  final bool phoneRequired;

  const ContactPickerField({
    super.key,
    required this.nameController,
    required this.phoneController,
    required this.label,
    this.hintName,
    this.hintPhone,
    this.nameRequired = false,
    this.phoneRequired = false,
  });

  @override
  State<ContactPickerField> createState() => _ContactPickerFieldState();
}

class _ContactPickerFieldState extends State<ContactPickerField> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık
        if (widget.label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        // Ad Soyad alanı
        TextFormField(
          controller: widget.nameController,
          decoration: InputDecoration(
            labelText: widget.nameRequired ? 'Ad Soyad *' : 'Ad Soyad',
            hintText: widget.hintName ?? 'Ad Soyad girin',
            prefixIcon: const Icon(Icons.person_outline),
            border: const OutlineInputBorder(),
          ),
          validator: widget.nameRequired
              ? (value) => value == null || value.trim().isEmpty
                  ? 'Ad soyad zorunludur'
                  : null
              : null,
        ),
        const SizedBox(height: 8),
        // Telefon alanı + Rehber butonu
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: widget.phoneController,
                decoration: InputDecoration(
                  labelText: widget.phoneRequired ? 'Telefon *' : 'Telefon',
                  hintText: widget.hintPhone ?? 'Telefon numarası',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: widget.phoneRequired
                    ? (value) => value == null || value.trim().isEmpty
                        ? 'Telefon zorunludur'
                        : null
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            // Rehber Butonu
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickFromContacts,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.contact_phone, size: 18),
              label: const Text('Rehber'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade50,
                foregroundColor: Colors.blue.shade700,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 🎯 Rehberden kişi seç - Güvenli versiyon
  Future<void> _pickFromContacts() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      // 🛡️ Önce izin kontrolü
      var status = await Permission.contacts.status;

      if (status.isDenied || status.isRestricted) {
        // İzin iste
        status = await Permission.contacts.request();

        if (status.isDenied) {
          // İzin reddedildi
          if (mounted) {
            _showError('Rehber erişimi için izin gerekli');
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      if (status.isPermanentlyDenied) {
        // Kalıcı reddedildi, ayarlara yönlendir
        if (mounted) {
          _showError('İzin kalıcı olarak reddedildi. Ayarlardan izin verin.');
        }
        setState(() => _isLoading = false);
        return;
      }

      // ✅ İzin var, rehberi aç
      final selectedContact = await FlutterContacts.openExternalPick();

      if (selectedContact != null && mounted) {
        // 🔊 Başarı sesi
        await SoundService().playSuccess();
        if (!mounted) return;

        // Ad soyad
        final displayName = selectedContact.displayName;
        if (displayName.isNotEmpty) {
          widget.nameController.text = displayName;
        }

        // Telefon numarası
        final phones = selectedContact.phones;
        if (phones.isNotEmpty) {
          final phone = phones.first.number;
          widget.phoneController.text =
              phone.replaceAll(RegExp(r'[^0-9+]'), '');
        }

        // Kullanıcıya bildir
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

      if (mounted) {
        _showError('Rehber erişim hatası: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    SoundService().playError();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $message'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Tamam',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }
}

// flutter_contacts kullanıldığı için eski Dialog kaldırıldı
// Direkt sistem rehberi açılır

// flutter_contacts paketi kendi UI'ını açtığı için
// Custom Dialog kaldırıldı - daha iyi performans ve uyumluluk
