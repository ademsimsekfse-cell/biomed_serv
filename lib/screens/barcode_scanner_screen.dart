import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as contacts;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  Barcode? _scannedBarcode;
  bool _isFlashOn = false;
  bool _isFrontCamera = false;
  String _scanHistory = '';

  // Barkod formatları açıklamaları
  final Map<String, String> _formatDescriptions = {
    'QR Code': 'QR Kod - URL, Kartvizit, WiFi, vb.',
    'EAN-13': 'EAN-13 - Ürün Barkodu (Avrupa)',
    'EAN-8': 'EAN-8 - Kısa Ürün Barkodu',
    'UPC-A': 'UPC-A - Ürün Barkodu (ABD)',
    'UPC-E': 'UPC-E - Kısa Ürün Barkodu',
    'CODE-128': 'CODE-128 - Lojistik/Endüstriyel',
    'CODE-39': 'CODE-39 - Askeri/Endüstriyel',
    'DATA_MATRIX': 'Data Matrix - Küçük parça etiketleri',
    'PDF-417': 'PDF-417 - Sürücü belgesi/kimlik',
    'AZTEC': 'Aztec - Ulaşım biletleri',
    'ITF': 'ITF-14 - Koli/paket barkodu',
    'CODABAR': 'Codabar - Kütüphane/banka',
  };

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    await Permission.camera.request();
  }

  void _onDetect(BarcodeCapture capture) {
    final barcode = capture.barcodes.firstOrNull;
    if (barcode != null && barcode.rawValue != null) {
      if (_scannedBarcode?.rawValue != barcode.rawValue) {
        setState(() {
          _scannedBarcode = barcode;
          _scanHistory = '${DateTime.now().toString().substring(11, 19)} - ${barcode.rawValue!}\n$_scanHistory';
        });
        _processBarcode(barcode);
      }
    }
  }

  void _processBarcode(Barcode barcode) {
    final String data = barcode.rawValue ?? '';
    final String format = barcode.format.name;

    // İçerik tipini tespit et
    final ContentType contentType = _detectContentType(data);

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => _buildResultSheet(data, format, contentType),
    );
  }

  ContentType _detectContentType(String data) {
    final lower = data.toLowerCase();

    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return ContentType.url;
    } else if (lower.startsWith('begin:vcard')) {
      return ContentType.vcard;
    } else if (lower.startsWith('geo:') || lower.startsWith('maps.google.com')) {
      return ContentType.location;
    } else if (lower.startsWith('tel:') || lower.startsWith('phone:')) {
      return ContentType.phone;
    } else if (lower.startsWith('mailto:')) {
      return ContentType.email;
    } else if (lower.startsWith('wifi:') || data.contains('WIFI:S:')) {
      return ContentType.wifi;
    } else if (lower.startsWith('sms:')) {
      return ContentType.sms;
    } else if (data.contains('@') && data.contains('.')) {
      return ContentType.emailSimple;
    } else if (RegExp(r'^\d{8,}$').hasMatch(data)) {
      return ContentType.product;
    } else {
      return ContentType.text;
    }
  }

  Widget _buildResultSheet(String data, String format, ContentType type) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getIconForType(type), color: _getColorForType(type), size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getTitleForType(type),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _formatDescriptions[format] ?? format,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              data,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Ne yapmak istiyorsunuz?',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          ..._buildActionButtons(data, type),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _scannedBarcode = null);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade300,
                foregroundColor: Colors.black,
              ),
              child: const Text('YENİDEN TARA'),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActionButtons(String data, ContentType type) {
    switch (type) {
      case ContentType.url:
        return [
          _buildActionButton(
            icon: Icons.open_in_browser,
            label: 'Tarayıcıda Aç',
            color: Colors.blue,
            onTap: () => _handleUrl(data),
          ),
          _buildActionButton(
            icon: Icons.copy,
            label: 'URL Kopyala',
            color: Colors.grey,
            onTap: () => _copyToClipboard(data),
          ),
          _buildActionButton(
            icon: Icons.share,
            label: 'Paylaş',
            color: Colors.green,
            onTap: () => Share.share(data),
          ),
        ];

      case ContentType.vcard:
        return [
          _buildActionButton(
            icon: Icons.contact_page,
            label: 'Rehbere Ekle',
            color: Colors.orange,
            onTap: () => _handleVCard(data),
          ),
          _buildActionButton(
            icon: Icons.copy,
            label: 'Kopyala',
            color: Colors.grey,
            onTap: () => _copyToClipboard(data),
          ),
          _buildActionButton(
            icon: Icons.share,
            label: 'Paylaş',
            color: Colors.green,
            onTap: () => Share.share(data),
          ),
        ];

      case ContentType.location:
        return [
          _buildActionButton(
            icon: Icons.map,
            label: 'Haritada Aç',
            color: Colors.red,
            onTap: () => _handleLocation(data),
          ),
          _buildActionButton(
            icon: Icons.navigation,
            label: 'Navigasyon Başlat',
            color: Colors.blue,
            onTap: () => _startNavigation(data),
          ),
          _buildActionButton(
            icon: Icons.copy,
            label: 'Kopyala',
            color: Colors.grey,
            onTap: () => _copyToClipboard(data),
          ),
        ];

      case ContentType.phone:
        return [
          _buildActionButton(
            icon: Icons.phone,
            label: 'Ara',
            color: Colors.green,
            onTap: () => _handlePhone(data),
          ),
          _buildActionButton(
            icon: Icons.contact_page,
            label: 'Rehbere Kaydet',
            color: Colors.orange,
            onTap: () => _saveContact(phone: data.replaceFirst(RegExp(r'^tel:'), '')),
          ),
          _buildActionButton(
            icon: Icons.message,
            label: 'SMS Gönder',
            color: Colors.blue,
            onTap: () => _sendSms(data.replaceFirst(RegExp(r'^tel:'), '')),
          ),
        ];

      case ContentType.email:
      case ContentType.emailSimple:
        return [
          _buildActionButton(
            icon: Icons.email,
            label: 'E-posta Gönder',
            color: Colors.blue,
            onTap: () => _handleEmail(data),
          ),
          _buildActionButton(
            icon: Icons.contact_page,
            label: 'Rehbere Kaydet',
            color: Colors.orange,
            onTap: () => _saveContact(email: data.replaceFirst(RegExp(r'^mailto:'), '')),
          ),
          _buildActionButton(
            icon: Icons.copy,
            label: 'Kopyala',
            color: Colors.grey,
            onTap: () => _copyToClipboard(data),
          ),
        ];

      case ContentType.wifi:
        return [
          _buildActionButton(
            icon: Icons.wifi,
            label: 'WiFi Ayarlarına Git',
            color: Colors.blue,
            onTap: () => _handleWifi(data),
          ),
          _buildActionButton(
            icon: Icons.copy,
            label: 'Şifreyi Kopyala',
            color: Colors.grey,
            onTap: () => _extractAndCopyWifiPassword(data),
          ),
        ];

      case ContentType.sms:
        return [
          _buildActionButton(
            icon: Icons.message,
            label: 'SMS Gönder',
            color: Colors.green,
            onTap: () => _handleSms(data),
          ),
          _buildActionButton(
            icon: Icons.copy,
            label: 'Kopyala',
            color: Colors.grey,
            onTap: () => _copyToClipboard(data),
          ),
        ];

      case ContentType.product:
        return [
          _buildActionButton(
            icon: Icons.search,
            label: 'Ürün Ara (Google)',
            color: Colors.blue,
            onTap: () => _searchProduct(data),
          ),
          _buildActionButton(
            icon: Icons.copy,
            label: 'Barkod Kopyala',
            color: Colors.grey,
            onTap: () => _copyToClipboard(data),
          ),
          _buildActionButton(
            icon: Icons.share,
            label: 'Paylaş',
            color: Colors.green,
            onTap: () => Share.share(data),
          ),
        ];

      default:
        return [
          _buildActionButton(
            icon: Icons.copy,
            label: 'Kopyala',
            color: Colors.blue,
            onTap: () => _copyToClipboard(data),
          ),
          _buildActionButton(
            icon: Icons.share,
            label: 'Paylaş',
            color: Colors.green,
            onTap: () => Share.share(data),
          ),
          _buildActionButton(
            icon: Icons.search,
            label: 'Ara',
            color: Colors.orange,
            onTap: () => _searchText(data),
          ),
        ];
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pop(context);
          onTap();
        },
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
    );
  }

  // Eylem metodları
  Future<void> _handleUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handleVCard(String vcard) async {
    try {
      final contact = _parseVCard(vcard);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Rehbere Eklensin mi?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (contact.name.isNotEmpty) Text('İsim: ${contact.name}'),
              if (contact.phone.isNotEmpty) Text('Telefon: ${contact.phone}'),
              if (contact.email.isNotEmpty) Text('E-posta: ${contact.email}'),
              if (contact.company.isNotEmpty) Text('Şirket: ${contact.company}'),
              if (contact.title.isNotEmpty) Text('Ünvan: ${contact.title}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İPTAL'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _saveContact(
                  name: contact.name,
                  phone: contact.phone,
                  email: contact.email,
                  company: contact.company,
                );
              },
              child: const Text('EKLE'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('VCard ayrıştırma hatası: $e'), backgroundColor: Colors.red),
      );
    }
  }

  VCardContact _parseVCard(String vcard) {
    String name = '';
    String phone = '';
    String email = '';
    String company = '';
    String title = '';

    final lines = LineSplitter.split(vcard);
    for (final line in lines) {
      if (line.startsWith('FN:')) {
        name = line.substring(3);
      } else if (line.startsWith('TEL')) {
        phone = line.split(':').last;
      } else if (line.startsWith('EMAIL')) {
        email = line.split(':').last;
      } else if (line.startsWith('ORG:')) {
        company = line.substring(4);
      } else if (line.startsWith('TITLE:')) {
        title = line.substring(6);
      }
    }

    return VCardContact(name, phone, email, company, title);
  }

  Future<void> _saveContact({
    String name = '',
    String phone = '',
    String email = '',
    String company = '',
  }) async {
    try {
      final newContact = contacts.Contact()
        ..name.first = name.isNotEmpty ? name : 'Bilinmeyen'
        ..phones = phone.isNotEmpty ? [contacts.Phone(phone)] : []
        ..emails = email.isNotEmpty ? [contacts.Email(email)] : []
        ..organizations = company.isNotEmpty ? [contacts.Organization(company: company)] : [];

      await contacts.FlutterContacts.insertContact(newContact);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kişi rehbere eklendi!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kişi ekleme hatası: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleLocation(String geo) async {
    String url = geo;
    if (geo.startsWith('geo:')) {
      final coords = geo.replaceFirst('geo:', '').split(',');
      if (coords.length >= 2) {
        url = 'https://www.google.com/maps/search/?api=1&query=${coords[0]},${coords[1]}';
      }
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _startNavigation(String geo) async {
    String url;
    if (geo.startsWith('geo:')) {
      final coords = geo.replaceFirst('geo:', '').split(',');
      if (coords.length >= 2) {
        url = 'google.navigation:q=${coords[0]},${coords[1]}';
      } else {
        return;
      }
    } else {
      return;
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Google Maps uygulaması yoksa web'de aç
      await _handleLocation(geo);
    }
  }

  Future<void> _handlePhone(String phone) async {
    final uri = Uri.parse(phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendSms(String phone) async {
    final uri = Uri.parse('sms:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _handleEmail(String email) async {
    final uri = Uri.parse(email.contains('mailto:') ? email : 'mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _handleWifi(String wifi) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('WiFi bağlantısı için Ayarlar > WiFi menüsünü kullanın'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _extractAndCopyWifiPassword(String wifi) {
    final regex = RegExp(r'P:([^;]+)');
    final match = regex.firstMatch(wifi);
    if (match != null) {
      _copyToClipboard(match.group(1) ?? '');
    }
  }

  Future<void> _handleSms(String sms) async {
    final uri = Uri.parse(sms);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _searchProduct(String barcode) async {
    final url = 'https://www.google.com/search?q=$barcode';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copyToClipboard(String text) {
    // Clipboard'a kopyalama işlemi
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Panoya kopyalandı!'), backgroundColor: Colors.green),
    );
  }

  Future<void> _searchText(String text) async {
    final url = 'https://www.google.com/search?q=${Uri.encodeComponent(text)}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  IconData _getIconForType(ContentType type) {
    switch (type) {
      case ContentType.url: return Icons.link;
      case ContentType.vcard: return Icons.contact_page;
      case ContentType.location: return Icons.location_on;
      case ContentType.phone: return Icons.phone;
      case ContentType.email:
      case ContentType.emailSimple: return Icons.email;
      case ContentType.wifi: return Icons.wifi;
      case ContentType.sms: return Icons.message;
      case ContentType.product: return Icons.shopping_cart;
      default: return Icons.qr_code;
    }
  }

  Color _getColorForType(ContentType type) {
    switch (type) {
      case ContentType.url: return Colors.blue;
      case ContentType.vcard: return Colors.orange;
      case ContentType.location: return Colors.red;
      case ContentType.phone: return Colors.green;
      case ContentType.email:
      case ContentType.emailSimple: return Colors.blue.shade700;
      case ContentType.wifi: return Colors.indigo;
      case ContentType.sms: return Colors.teal;
      case ContentType.product: return Colors.purple;
      default: return Colors.grey;
    }
  }

  String _getTitleForType(ContentType type) {
    switch (type) {
      case ContentType.url: return 'Web Linki (URL)';
      case ContentType.vcard: return 'Kartvizit (VCard)';
      case ContentType.location: return 'Konum/Adres';
      case ContentType.phone: return 'Telefon Numarası';
      case ContentType.email: return 'E-posta Adresi';
      case ContentType.emailSimple: return 'E-posta';
      case ContentType.wifi: return 'WiFi Ağı';
      case ContentType.sms: return 'SMS';
      case ContentType.product: return 'Ürün Barkodu';
      default: return 'Metin';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barkod Okuyucu'),
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () {
              setState(() => _isFlashOn = !_isFlashOn);
            },
          ),
          IconButton(
            icon: Icon(_isFrontCamera ? Icons.camera_front : Icons.camera_rear),
            onPressed: () {
              setState(() => _isFrontCamera = !_isFrontCamera);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: MobileScanner(
              onDetect: _onDetect,
              scanWindow: Rect.fromCenter(
                center: Offset(MediaQuery.of(context).size.width / 2, 200),
                width: 250,
                height: 250,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade100,
              child: Column(
                children: [
                  const Text(
                    'DESTEKLENEN FORMATLAR',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildFormatChip('QR Code'),
                      _buildFormatChip('EAN-13'),
                      _buildFormatChip('EAN-8'),
                      _buildFormatChip('UPC'),
                      _buildFormatChip('CODE-128'),
                      _buildFormatChip('CODE-39'),
                      _buildFormatChip('Data Matrix'),
                      _buildFormatChip('PDF-417'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_scanHistory.isNotEmpty) ...[
                    const Text(
                      'SON TARAMALAR',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          _scanHistory,
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatChip(String label) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 10)),
      backgroundColor: Colors.white,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

enum ContentType {
  url,
  vcard,
  location,
  phone,
  email,
  emailSimple,
  wifi,
  sms,
  product,
  text,
}

class VCardContact {
  final String name;
  final String phone;
  final String email;
  final String company;
  final String title;

  VCardContact(this.name, this.phone, this.email, this.company, this.title);
}
