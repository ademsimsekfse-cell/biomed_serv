import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:ui' as ui;

class QrGeneratorScreen extends StatefulWidget {
  const QrGeneratorScreen({super.key});

  @override
  State<QrGeneratorScreen> createState() => _QrGeneratorScreenState();
}

class _QrGeneratorScreenState extends State<QrGeneratorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey _qrKey = GlobalKey();
  String _generatedData = '';
  String _currentType = 'VCard';

  // VCard Controllers
  final _vcFirstName = TextEditingController();
  final _vcLastName = TextEditingController();
  final _vcPhone = TextEditingController();
  final _vcEmail = TextEditingController();
  final _vcCompany = TextEditingController();
  final _vcTitle = TextEditingController();
  final _vcAddress = TextEditingController();
  final _vcWebsite = TextEditingController();
  final _vcLinkedIn = TextEditingController();
  final _vcTwitter = TextEditingController();

  // URL Controller
  final _urlController = TextEditingController();

  // Location Controllers
  final _locLatitude = TextEditingController();
  final _locLongitude = TextEditingController();
  final _locAddress = TextEditingController();
  final _locName = TextEditingController();

  // WiFi Controllers
  final _wifiSsid = TextEditingController();
  final _wifiPassword = TextEditingController();
  String _wifiSecurity = 'WPA';

  // Phone Controller
  final _phoneController = TextEditingController();

  // Email Controllers
  final _emailAddress = TextEditingController();
  final _emailSubject = TextEditingController();
  final _emailBody = TextEditingController();

  // Text Controller
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentType = [
          'VCard',
          'URL',
          'Konum',
          'WiFi',
          'Telefon',
          'E-posta'
        ][_tabController.index];
        _generatedData = '';
      });
    });
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      await Permission.storage.request();
    } catch (_) {
      // Desktop and widget-test environments may not expose storage permission.
    }
  }

  void _generateQR() {
    String data = '';

    switch (_tabController.index) {
      case 0: // VCard
        data = _generateVCard();
        break;
      case 1: // URL
        data = _urlController.text.trim();
        if (!data.startsWith('http://') && !data.startsWith('https://')) {
          data = 'https://$data';
        }
        break;
      case 2: // Location
        data = _generateLocation();
        break;
      case 3: // WiFi
        data = _generateWiFi();
        break;
      case 4: // Phone
        data = 'tel:${_phoneController.text.trim()}';
        break;
      case 5: // Email
        data = _generateEmail();
        break;
    }

    if (data.isNotEmpty) {
      setState(() => _generatedData = data);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Lütfen gerekli alanları doldurun!'),
            backgroundColor: Colors.orange),
      );
    }
  }

  String _generateVCard() {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCARD');
    buffer.writeln('VERSION:3.0');
    buffer.writeln('FN:${_vcFirstName.text} ${_vcLastName.text}');
    buffer.writeln('N:${_vcLastName.text};${_vcFirstName.text};;;');

    if (_vcPhone.text.isNotEmpty) {
      buffer.writeln('TEL;TYPE=CELL:${_vcPhone.text}');
    }
    if (_vcEmail.text.isNotEmpty) {
      buffer.writeln('EMAIL;TYPE=WORK:${_vcEmail.text}');
    }
    if (_vcCompany.text.isNotEmpty) {
      buffer.writeln('ORG:${_vcCompany.text}');
    }
    if (_vcTitle.text.isNotEmpty) {
      buffer.writeln('TITLE:${_vcTitle.text}');
    }
    if (_vcAddress.text.isNotEmpty) {
      buffer.writeln('ADR;TYPE=WORK:;;${_vcAddress.text};;;;');
    }
    if (_vcWebsite.text.isNotEmpty) {
      buffer.writeln('URL:${_vcWebsite.text}');
    }
    if (_vcLinkedIn.text.isNotEmpty) {
      buffer.writeln('X-SOCIALPROFILE;TYPE=LINKEDIN:${_vcLinkedIn.text}');
    }
    if (_vcTwitter.text.isNotEmpty) {
      buffer.writeln('X-SOCIALPROFILE;TYPE=TWITTER:${_vcTwitter.text}');
    }

    buffer.writeln('END:VCARD');
    return buffer.toString();
  }

  String _generateLocation() {
    if (_locLatitude.text.isNotEmpty && _locLongitude.text.isNotEmpty) {
      return 'geo:${_locLatitude.text},${_locLongitude.text}?q=${_locLatitude.text},${_locLongitude.text}(${_locName.text.isNotEmpty ? _locName.text : 'Konum'})';
    } else if (_locAddress.text.isNotEmpty) {
      return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(_locAddress.text)}';
    }
    return '';
  }

  String _generateWiFi() {
    return 'WIFI:T:$_wifiSecurity;S:${_wifiSsid.text};P:${_wifiPassword.text};;';
  }

  String _generateEmail() {
    final subject = Uri.encodeComponent(_emailSubject.text);
    final body = Uri.encodeComponent(_emailBody.text);
    return 'mailto:${_emailAddress.text}?subject=$subject&body=$body';
  }

  Future<void> _saveQR() async {
    if (_generatedData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Önce QR kod oluşturun!'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      final directory = Directory('/storage/emulated/0/Download/BiomedQR');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath =
          '${directory.path}/qr_${_currentType.toLowerCase()}_$timestamp.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('QR kod kaydedildi: $filePath'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Kaydetme hatası: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _shareQR() async {
    if (_generatedData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Önce QR kod oluşturun!'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        // Sadece metni paylaş
        await Share.share(_generatedData, subject: 'QR Kod Verisi');
        return;
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${tempDir.path}/qr_share_$timestamp.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(filePath)],
        text: '$_currentType QR Kodu',
        subject: 'QR Kod Paylaşımı',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Paylaşım hatası: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _copyData() {
    if (_generatedData.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _generatedData));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veri panoya kopyalandı!'),
            backgroundColor: Colors.green),
      );
    }
  }

  void _selectQrType(int index) {
    if (_tabController.index == index) return;
    _tabController.animateTo(index);
  }

  Widget _buildTypeSelector() {
    const items = [
      (label: 'Kartvizit', icon: Icons.contact_page_outlined),
      (label: 'Web Adresi', icon: Icons.link),
      (label: 'Konum', icon: Icons.location_on_outlined),
      (label: 'Wi-Fi', icon: Icons.wifi),
      (label: 'Telefon', icon: Icons.phone_outlined),
      (label: 'E-posta', icon: Icons.email_outlined),
    ];

    return Material(
      color: const Color(0xFFF7F9FB),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 390 ? 2 : 3;
            final itemWidth =
                (constraints.maxWidth - ((columns - 1) * 8)) / columns;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(items.length, (index) {
                final item = items[index];
                final selected = _tabController.index == index;
                return SizedBox(
                  width: itemWidth,
                  height: 58,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _selectQrType(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color:
                            selected ? const Color(0xFFE7F0F8) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF245B78)
                              : const Color(0xFFD8E0E6),
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            item.icon,
                            size: 20,
                            color: selected
                                ? const Color(0xFF245B78)
                                : Colors.blueGrey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: selected
                                    ? const Color(0xFF173F52)
                                    : Colors.blueGrey.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Oluşturucu'),
      ),
      body: Column(
        children: [
          _buildTypeSelector(),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildVCardTab(),
                _buildUrlTab(),
                _buildLocationTab(),
                _buildWiFiTab(),
                _buildPhoneTab(),
                _buildEmailTab(),
              ],
            ),
          ),
          // QR Önizleme
          if (_generatedData.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade100,
              child: Column(
                children: [
                  const Text(
                    'QR KOD ÖNİZLEME',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: RepaintBoundary(
                      key: _qrKey,
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(12),
                        child: QrImageView(
                          data: _generatedData,
                          version: QrVersions.auto,
                          size: 200,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _saveQR,
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Kaydet'),
                      ),
                      FilledButton.icon(
                        onPressed: _shareQR,
                        icon: const Icon(Icons.share),
                        label: const Text('Paylaş'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _copyData,
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Kopyala'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _generateQR,
        icon: const Icon(Icons.qr_code),
        label: const Text('QR Oluştur'),
      ),
    );
  }

  Widget _buildVCardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Kurumsal/Bireysel Kartvizit Oluştur',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(_vcFirstName, 'Ad', Icons.person),
              ),
              const SizedBox(width: 12),
              Expanded(
                child:
                    _buildTextField(_vcLastName, 'Soyad', Icons.person_outline),
              ),
            ],
          ),
          _buildTextField(_vcPhone, 'Telefon', Icons.phone,
              keyboardType: TextInputType.phone),
          _buildTextField(_vcEmail, 'E-posta', Icons.email,
              keyboardType: TextInputType.emailAddress),
          _buildTextField(_vcCompany, 'Şirket', Icons.business),
          _buildTextField(_vcTitle, 'Ünvan/Pozisyon', Icons.work),
          _buildTextField(_vcAddress, 'Adres', Icons.location_on, maxLines: 2),
          _buildTextField(_vcWebsite, 'Web Sitesi', Icons.language,
              hint: 'https://www.ornek.com'),
          _buildTextField(_vcLinkedIn, 'LinkedIn', Icons.linked_camera,
              hint: 'linkedin.com/in/kullanici'),
          _buildTextField(_vcTwitter, 'Twitter/X', Icons.alternate_email,
              hint: '@kullaniciadi'),
        ],
      ),
    );
  }

  Widget _buildUrlTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Icon(Icons.link, size: 48, color: Colors.blue),
          const SizedBox(height: 16),
          const Text(
            'Web Sitesi veya Link',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'QR kodu tarayan kullanıcı doğrudan siteye yönlendirilecek',
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildTextField(
            _urlController,
            'URL Adresi',
            Icons.language,
            hint: 'https://www.ornek.com veya www.ornek.com',
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Icon(Icons.location_on, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Konum veya Adres',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'QR kodu tarayan kullanıcı haritada konumu görebilir',
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  _locLatitude,
                  'Enlem (Lat)',
                  Icons.explore,
                  hint: '41.0082',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  _locLongitude,
                  'Boylam (Long)',
                  Icons.explore_outlined,
                  hint: '28.9784',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          _buildTextField(_locName, 'Konum Adı', Icons.place,
              hint: 'İstanbul, Taksim'),
          const Divider(height: 32),
          Text(
            'VEYA',
            style: TextStyle(
                color: Colors.grey.shade600, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _locAddress,
            'Adres Tarifi',
            Icons.home,
            hint: 'Tam adres yazın...',
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildWiFiTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Icon(Icons.wifi, size: 48, color: Colors.indigo),
          const SizedBox(height: 16),
          const Text(
            'WiFi Ağı Bilgileri',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'QR kodu tarayan kullanıcı otomatik bağlanabilir',
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildTextField(_wifiSsid, 'Ağ Adı (SSID)', Icons.wifi),
          _buildTextField(_wifiPassword, 'Şifre', Icons.lock,
              obscureText: true),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _wifiSecurity,
            decoration: const InputDecoration(
              labelText: 'Güvenlik Tipi',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.security),
            ),
            items: ['WPA', 'WEP', 'nopass'].map((value) {
              return DropdownMenuItem(
                value: value,
                child: Text(value == 'nopass' ? 'Şifresiz' : value),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _wifiSecurity = value!);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Icon(Icons.phone, size: 48, color: Colors.green),
          const SizedBox(height: 16),
          const Text(
            'Telefon Numarası',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'QR kodu tarayan kullanıcı doğrudan arama yapabilir',
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildTextField(
            _phoneController,
            'Telefon Numarası',
            Icons.phone,
            hint: '+90 555 123 4567',
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  Widget _buildEmailTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Icon(Icons.email, size: 48, color: Colors.orange),
          const SizedBox(height: 16),
          const Text(
            'E-posta Şablonu',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'QR kodu tarayan kullanıcı hazır e-posta açabilir',
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildTextField(
            _emailAddress,
            'Alıcı E-posta',
            Icons.email,
            keyboardType: TextInputType.emailAddress,
          ),
          _buildTextField(_emailSubject, 'Konu', Icons.subject),
          _buildTextField(_emailBody, 'Mesaj', Icons.message, maxLines: 4),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool obscureText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon),
        ),
        keyboardType: keyboardType,
        maxLines: maxLines,
        obscureText: obscureText,
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _vcFirstName.dispose();
    _vcLastName.dispose();
    _vcPhone.dispose();
    _vcEmail.dispose();
    _vcCompany.dispose();
    _vcTitle.dispose();
    _vcAddress.dispose();
    _vcWebsite.dispose();
    _vcLinkedIn.dispose();
    _vcTwitter.dispose();
    _urlController.dispose();
    _locLatitude.dispose();
    _locLongitude.dispose();
    _locAddress.dispose();
    _locName.dispose();
    _wifiSsid.dispose();
    _wifiPassword.dispose();
    _phoneController.dispose();
    _emailAddress.dispose();
    _emailSubject.dispose();
    _emailBody.dispose();
    _textController.dispose();
    super.dispose();
  }
}
