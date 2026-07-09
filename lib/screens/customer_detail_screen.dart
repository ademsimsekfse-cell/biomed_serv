import 'package:biomed_serv/models/customer.dart';
import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/providers/device_provider.dart';
import 'package:biomed_serv/screens/device_detail_screen.dart';
import 'package:biomed_serv/screens/customer_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Müşteri Detay Ekranı
/// Müşteri bilgileri ve bağlı cihazları gösterir
class CustomerDetailScreen extends StatelessWidget {
  final Customer customer;

  const CustomerDetailScreen({
    super.key,
    required this.customer,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(customer.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                // Müşteri düzenleme - CustomerManagementScreen'e yönlendir
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CustomerManagementScreen(),
                  ),
                );
              },
              tooltip: 'Düzenle',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.business), text: 'Bilgiler'),
              Tab(icon: Icon(Icons.devices), text: 'Cihazlar'),
            ],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        body: TabBarView(
          children: [
            _buildInfoTab(context),
            _buildDevicesTab(context),
          ],
        ),
        floatingActionButton: _buildModernActionButtons(context),
      ),
    );
  }

  /// 📋 Bilgiler Tab'ı
  Widget _buildInfoTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === BAŞLIK KARTI ===
          _buildHeaderCard(context),
          const SizedBox(height: 16),

          // === İLETİŞİM KARTI ===
          _buildContactCard(context),
          const SizedBox(height: 16),

          // === BİRİM AMİRİ KARTI ===
          if (customer.unitManagerName != null &&
              customer.unitManagerName!.isNotEmpty)
            _buildUnitManagerCard(context),
          if (customer.unitManagerName != null) const SizedBox(height: 16),

          // === BİRİM SORUMLUSU KARTI ===
          if (customer.unitResponsibleName != null &&
              customer.unitResponsibleName!.isNotEmpty)
            _buildUnitResponsibleCard(context),
          if (customer.unitResponsibleName != null) const SizedBox(height: 16),

          // === EK BİLGİLER ===
          _buildAdditionalInfoCard(context),
        ],
      ),
    );
  }

  /// 🏢 Başlık Kartı
  Widget _buildHeaderCard(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: Colors.blue.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.blue.shade50,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.blue.shade100,
                    child: Icon(
                      Icons.business,
                      size: 40,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: customer.isActive
                                ? Colors.green.shade100
                                : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            customer.isActive ? '🟢 Aktif' : '🔴 Pasif',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: customer.isActive
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              // Hızlı istatistikler
              Consumer<DeviceProvider>(
                builder: (context, deviceProvider, child) {
                  final customerDevices = deviceProvider.devices
                      .where((d) => (d.customer as Customer?)?.key == customer.key)
                      .toList();

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem(
                        icon: Icons.devices,
                        value: '${customerDevices.length}',
                        label: 'Cihaz',
                        color: Colors.blue,
                      ),
                      _buildStatItem(
                        icon: Icons.check_circle,
                        value: '${customerDevices.where((d) => d.isControlModule).length}',
                        label: 'Kontrol Ünitesi',
                        color: Colors.purple,
                      ),
                      _buildStatItem(
                        icon: Icons.memory,
                        value: '${customerDevices.where((d) => d.isProcessingModule).length}',
                        label: 'Modül',
                        color: Colors.orange,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 📊 İstatistik Item
  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  /// 📞 İletişim Kartı
  Widget _buildContactCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.contact_phone, color: Colors.teal.shade700),
                const SizedBox(width: 8),
                Text(
                  'İletişim Bilgileri',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildContactRow(
              icon: Icons.location_on,
              label: 'Adres',
              value: customer.address,
              onTap: () => _copyToClipboard(context, customer.address),
            ),
            const SizedBox(height: 12),
            _buildContactRow(
              icon: Icons.phone,
              label: 'Telefon',
              value: customer.phone,
              onTap: () => _callPhone(context, customer.phone),
              actionIcon: Icons.call,
              actionColor: Colors.green,
            ),
            const SizedBox(height: 12),
            _buildContactRow(
              icon: Icons.person,
              label: 'Yetkili Kişi',
              value: customer.authorizedPerson,
            ),
            if (customer.email != null && customer.email!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildContactRow(
                icon: Icons.email,
                label: 'E-Posta',
                value: customer.email!,
                onTap: () => _sendEmail(context, customer.email!),
                actionIcon: Icons.send,
                actionColor: Colors.blue,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 📞 İletişim Satırı
  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
    IconData? actionIcon,
    Color? actionColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (actionIcon != null)
              Icon(
                actionIcon,
                size: 20,
                color: actionColor ?? Colors.grey,
              ),
          ],
        ),
      ),
    );
  }

  /// 👔 Birim Amiri Kartı
  Widget _buildUnitManagerCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.purple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.manage_accounts, color: Colors.purple.shade700),
                const SizedBox(width: 8),
                Text(
                  'Birim Amiri',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              customer.unitManagerName!,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (customer.unitManagerPhone != null &&
                customer.unitManagerPhone!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: InkWell(
                  onTap: () => _callPhone(context, customer.unitManagerPhone!),
                  child: Row(
                    children: [
                      Icon(
                        Icons.phone,
                        size: 18,
                        color: Colors.purple.shade600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        customer.unitManagerPhone!,
                        style: TextStyle(
                          color: Colors.purple.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.call,
                        size: 16,
                        color: Colors.green,
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

  /// 👨‍💼 Birim Sorumlusu Kartı
  Widget _buildUnitResponsibleCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.supervisor_account, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  'Birim Sorumlusu',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              customer.unitResponsibleName!,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (customer.unitResponsiblePhone != null &&
                customer.unitResponsiblePhone!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: InkWell(
                  onTap: () => _callPhone(context, customer.unitResponsiblePhone!),
                  child: Row(
                    children: [
                      Icon(
                        Icons.phone,
                        size: 18,
                        color: Colors.orange.shade600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        customer.unitResponsiblePhone!,
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.call,
                        size: 16,
                        color: Colors.green,
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

  /// 📎 Ek Bilgiler Kartı
  Widget _buildAdditionalInfoCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Text(
                  'Ek Bilgiler',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (customer.vergiNo != null && customer.vergiNo!.isNotEmpty)
              _buildInfoRow(
                icon: Icons.numbers,
                label: 'Vergi Numarası',
                value: customer.vergiNo!,
              ),
            _buildInfoRow(
              icon: Icons.calendar_today,
              label: 'Kayıt Tarihi',
              value: DateFormat('dd.MM.yyyy').format(DateTime.now()),
            ),
          ],
        ),
      ),
    );
  }

  /// ℹ️ Bilgi Satırı
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 📱 Cihazlar Tab'ı
  Widget _buildDevicesTab(BuildContext context) {
    return Consumer<DeviceProvider>(
      builder: (context, deviceProvider, child) {
        final customerDevices = deviceProvider.devices
            .where((d) => (d.customer as Customer?)?.key == customer.key)
            .toList();

        if (customerDevices.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.devices_other,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'Bu müşteriye ait cihaz bulunmuyor.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    // Cihaz ekleme ekranına git
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Cihaz Ekle'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: customerDevices.length,
          itemBuilder: (context, index) {
            final device = customerDevices[index];
            return _buildDeviceCard(context, device);
          },
        );
      },
    );
  }

  /// 🔧 Cihaz Kartı
  Widget _buildDeviceCard(BuildContext context, Device device) {
    IconData deviceIcon;
    Color deviceColor;
    String deviceType;

    if (device.isControlModule) {
      deviceIcon = Icons.account_tree;
      deviceColor = Colors.deepPurple;
      deviceType = 'Kontrol Ünitesi';
    } else if (device.isProcessingModule) {
      deviceIcon = Icons.memory;
      deviceColor = Colors.orange;
      deviceType = 'Modül';
    } else {
      deviceIcon = Icons.devices;
      deviceColor = Colors.blue;
      deviceType = 'Bağımsız Cihaz';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DeviceDetailScreen(device: device),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: deviceColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(deviceIcon, color: deviceColor, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${device.brand} ${device.model}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: device.ownershipStatus == OwnershipStatus.sold
                          ? Colors.green.shade100
                          : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      device.ownershipStatus == OwnershipStatus.sold
                          ? 'SOLD'
                          : 'RENT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: device.ownershipStatus == OwnershipStatus.sold
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.confirmation_number,
                        size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      'Seri: ${device.serialNumber}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.label_outline,
                      size: 14, color: deviceColor),
                  const SizedBox(width: 6),
                  Text(
                    deviceType,
                    style: TextStyle(
                      fontSize: 12,
                      color: deviceColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ⚡ Modern Hızlı Eylem Butonları - BELİRGİN RENKLER
  Widget _buildModernActionButtons(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 📧 E-posta Butonu - CANLI MAVİ
          if (customer.email?.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Etiket
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.shade400.withOpacity(0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Text(
                      'E-posta',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Buton
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.shade400.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: FloatingActionButton.small(
                      heroTag: 'email',
                      onPressed: () => _sendEmail(context, customer.email!),
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      child: const Icon(Icons.email),
                    ),
                  ),
                ],
              ),
            ),
          // 📞 Telefon Butonu - CANLI YEŞİL
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Etiket
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.shade400.withOpacity(0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Text(
                  'Ara',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Buton
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.shade400.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: FloatingActionButton(
                  heroTag: 'call',
                  onPressed: () => _callPhone(context, customer.phone),
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  child: const Icon(Icons.phone, size: 28),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 📞 Telefon Ara
  Future<void> _callPhone(BuildContext context, String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _copyToClipboard(context, phone);
    }
  }

  /// 📧 E-posta Gönder
  Future<void> _sendEmail(BuildContext context, String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _copyToClipboard(context, email);
    }
  }

  /// 📋 Panoya Kopyala
  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📋 $text kopyalandı'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
