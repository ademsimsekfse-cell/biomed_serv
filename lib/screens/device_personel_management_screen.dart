import 'package:biomed_serv/models/customer.dart';
import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/models/device_personel.dart';
import 'package:biomed_serv/providers/customer_provider.dart';
import 'package:biomed_serv/providers/device_personel_provider.dart';
import 'package:biomed_serv/providers/device_provider.dart';
import 'package:biomed_serv/services/sound_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

/// ğŸ¯ Sorumlu Personel YÃ¶netim EkranÄ± - GeliÅŸtirilmiÅŸ
/// - Personele atanan cihazlar
/// - BaÄŸlÄ± kurumlar
/// - Filtreleme sekmeleri
class DevicePersonelManagementScreen extends StatefulWidget {
  const DevicePersonelManagementScreen({super.key});

  @override
  State<DevicePersonelManagementScreen> createState() =>
      _DevicePersonelManagementScreenState();
}

class _DevicePersonelManagementScreenState
    extends State<DevicePersonelManagementScreen> {
  int _currentTabIndex = 0;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sorumlu Personel YÃ¶netimi'),
          elevation: 0,
          bottom: TabBar(
            onTap: (index) => setState(() => _currentTabIndex = index),
            tabs: const [
              Tab(
                icon: Icon(Icons.people, size: 22),
                text: 'Personel',
              ),
              Tab(
                icon: Icon(Icons.devices, size: 22),
                text: 'Cihazlar',
              ),
              Tab(
                icon: Icon(Icons.business, size: 22),
                text: 'Kurumlar',
              ),
            ],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorWeight: 3,
            indicatorColor: Colors.white,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        body: Column(
          children: [
            // ğŸ” Arama AlanÄ±
            _buildSearchBar(),
            // ğŸ“‹ Tab Ä°Ã§erikleri
            Expanded(
              child: TabBarView(
                children: [
                  _buildPersonelTab(),
                  _buildDevicesTab(),
                  _buildCustomersTab(),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: _currentTabIndex == 0
            ? Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepPurple.shade500,
                      Colors.deepPurple.shade700
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.shade400.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: FloatingActionButton.extended(
                  onPressed: () => _showAddEditPersonelDialog(context),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  icon: const Icon(Icons.person_add, color: Colors.white),
                  label: const Text(
                    'Personel Ekle',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  // ğŸ” Arama BarÄ±
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.deepPurple.shade100),
        ),
      ),
      child: TextField(
        onChanged: (value) =>
            setState(() => _searchQuery = value.toLowerCase()),
        decoration: InputDecoration(
          hintText: _currentTabIndex == 0
              ? 'Personel ara...'
              : _currentTabIndex == 1
                  ? 'Cihaz ara...'
                  : 'Kurum ara...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  // ğŸ‘¥ PERSONEL SEKMESÄ°
  Widget _buildPersonelTab() {
    return Consumer<DevicePersonelProvider>(
      builder: (context, provider, child) {
        if (provider.personels.isEmpty) {
          return _buildEmptyState(
            icon: Icons.people_outline,
            title: 'HenÃ¼z personel yok',
            subtitle: 'Yeni personel eklemek iÃ§in + butonuna tÄ±klayÄ±n',
          );
        }

        // Filtrele
        final filteredPersonels = _searchQuery.isEmpty
            ? provider.personels
            : provider.personels.where((p) {
                return p.fullName.toLowerCase().contains(_searchQuery) ||
                    (p.phone?.toLowerCase().contains(_searchQuery) ?? false) ||
                    (p.email?.toLowerCase().contains(_searchQuery) ?? false) ||
                    (p.title?.toLowerCase().contains(_searchQuery) ?? false);
              }).toList();

        if (filteredPersonels.isEmpty) {
          return _buildEmptyState(
            icon: Icons.search_off,
            title: 'SonuÃ§ bulunamadÄ±',
            subtitle: 'FarklÄ± bir arama terimi deneyin',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredPersonels.length,
          itemBuilder: (context, index) {
            final personel = filteredPersonels[index];
            return _buildPersonelCard(context, personel);
          },
        );
      },
    );
  }

  // ğŸ”§ CÄ°HAZLAR SEKMESÄ°
  Widget _buildDevicesTab() {
    return Consumer3<DevicePersonelProvider, DeviceProvider, CustomerProvider>(
      builder:
          (context, personelProvider, deviceProvider, customerProvider, child) {
        final personels = personelProvider.personels;

        if (personels.isEmpty) {
          return _buildEmptyState(
            icon: Icons.devices_other,
            title: 'Ã–nce personel ekleyin',
            subtitle: 'Cihaz atamalarÄ± iÃ§in personel gereklidir',
          );
        }

        // TÃ¼m cihazlarÄ± ve personel iliÅŸkilerini topla
        final List<Map<String, dynamic>> personelDevices = [];

        for (final personel in personels) {
          // Bu personele atanan cihazlarÄ± bul
          final devices = deviceProvider.devices.where((d) {
            return _isDeviceAssignedToPersonel(d, personel);
          }).toList();

          for (final device in devices) {
            final customer = device.customer is Customer
                ? device.customer as Customer
                : null;

            // Arama filtresi
            if (_searchQuery.isNotEmpty) {
              final searchLower = _searchQuery.toLowerCase();
              if (!device.name.toLowerCase().contains(searchLower) &&
                  !device.brand.toLowerCase().contains(searchLower) &&
                  !device.model.toLowerCase().contains(searchLower) &&
                  !personel.fullName.toLowerCase().contains(searchLower) &&
                  !(customer?.name.toLowerCase().contains(searchLower) ??
                      false)) {
                continue;
              }
            }

            personelDevices.add({
              'device': device,
              'personel': personel,
              'customer': customer,
            });
          }
        }

        if (personelDevices.isEmpty) {
          return _buildEmptyState(
            icon: Icons.phonelink_erase,
            title: 'AtanmÄ±ÅŸ cihaz yok',
            subtitle: 'HenÃ¼z personele cihaz atanmamÄ±ÅŸ',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: personelDevices.length,
          itemBuilder: (context, index) {
            final data = personelDevices[index];
            return _buildPersonelDeviceCard(
              context,
              data['device'] as Device,
              data['personel'] as DevicePersonel,
              data['customer'] as Customer?,
            );
          },
        );
      },
    );
  }

  // ğŸ¢ KURUMLAR SEKMESÄ°
  Widget _buildCustomersTab() {
    return Consumer3<DevicePersonelProvider, DeviceProvider, CustomerProvider>(
      builder:
          (context, personelProvider, deviceProvider, customerProvider, child) {
        final personels = personelProvider.personels;

        if (personels.isEmpty) {
          return _buildEmptyState(
            icon: Icons.business,
            title: 'Ã–nce personel ekleyin',
            subtitle: 'Kurum iliÅŸkileri iÃ§in personel gereklidir',
          );
        }

        // Personel-Kurum iliÅŸkilerini topla
        final Map<Customer, List<Map<String, dynamic>>> customerPersonelMap =
            {};

        for (final personel in personels) {
          // Bu personele atanan cihazlarÄ± bul
          final devices = deviceProvider.devices.where((d) {
            return _isDeviceAssignedToPersonel(d, personel);
          }).toList();

          for (final device in devices) {
            final customer = device.customer is Customer
                ? device.customer as Customer
                : null;
            if (customer == null) continue;

            // Arama filtresi
            if (_searchQuery.isNotEmpty) {
              final searchLower = _searchQuery.toLowerCase();
              if (!customer.name.toLowerCase().contains(searchLower) &&
                  !(customer.address?.toLowerCase().contains(searchLower) ??
                      false) &&
                  !personel.fullName.toLowerCase().contains(searchLower)) {
                continue;
              }
            }

            if (!customerPersonelMap.containsKey(customer)) {
              customerPersonelMap[customer] = [];
            }

            // AynÄ± personel-kurum iliÅŸkisini tekrar ekleme
            final existing = customerPersonelMap[customer]!.any(
              (p) => (p['personel'] as DevicePersonel).key == personel.key,
            );

            if (!existing) {
              customerPersonelMap[customer]!.add({
                'personel': personel,
                'device': device,
              });
            }
          }
        }

        if (customerPersonelMap.isEmpty) {
          return _buildEmptyState(
            icon: Icons.business_center,
            title: 'BaÄŸlÄ± kurum yok',
            subtitle:
                'HenÃ¼z personelin atanmÄ±ÅŸ cihazlarÄ± olan bir kurum yok',
          );
        }

        final customers = customerPersonelMap.keys.toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: customers.length,
          itemBuilder: (context, index) {
            final customer = customers[index];
            final personelList = customerPersonelMap[customer]!;
            return _buildCustomerPersonelCard(context, customer, personelList);
          },
        );
      },
    );
  }

  bool _isDeviceAssignedToPersonel(Device device, DevicePersonel personel) {
    final responsible = device.responsiblePerson;
    if (responsible == null) return false;

    if (responsible.key != null && personel.key != null) {
      return responsible.key == personel.key;
    }

    final sameName = responsible.fullName.trim().toLowerCase() ==
        personel.fullName.trim().toLowerCase();
    if (!sameName) return false;

    final responsiblePhone = responsible.phone?.trim();
    final personelPhone = personel.phone?.trim();
    if (responsiblePhone != null &&
        responsiblePhone.isNotEmpty &&
        personelPhone != null &&
        personelPhone.isNotEmpty &&
        responsiblePhone != personelPhone) {
      return false;
    }

    final responsibleEmail = responsible.email?.trim().toLowerCase();
    final personelEmail = personel.email?.trim().toLowerCase();
    if (responsibleEmail != null &&
        responsibleEmail.isNotEmpty &&
        personelEmail != null &&
        personelEmail.isNotEmpty &&
        responsibleEmail != personelEmail) {
      return false;
    }

    return true;
  }

  // ğŸ¨ BoÅŸ Durum Widget'Ä±
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.deepPurple.shade100,
                    Colors.deepPurple.shade200,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.shade200.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 60,
                color: Colors.deepPurple.shade700,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Personel KartÄ± - Kompakt
  Widget _buildPersonelCard(BuildContext context, DevicePersonel personel) {
    final dateFormat = DateFormat('dd.MM.yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 1,
      child: InkWell(
        onTap: () => _showPersonelDetails(context, personel),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    personel.fullName.isNotEmpty
                        ? personel.fullName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: Colors.deepPurple.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Bilgiler
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ãœst satÄ±r: Ä°sim + Ãœnvan
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            personel.fullName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (personel.title != null &&
                            personel.title!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              personel.title!,
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Alt satÄ±r: Telefon + Email + Tarih
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                        children: [
                          if (personel.phone?.isNotEmpty == true)
                            TextSpan(text: personel.phone),
                          if (personel.email?.isNotEmpty == true) ...[
                            if (personel.phone?.isNotEmpty == true)
                              const TextSpan(text: ' â€¢ '),
                            TextSpan(text: personel.email),
                          ],
                          if (personel.assignedDate != null) ...[
                            if (personel.phone?.isNotEmpty == true ||
                                personel.email?.isNotEmpty == true)
                              const TextSpan(text: ' â€¢ '),
                            TextSpan(
                                text:
                                    dateFormat.format(personel.assignedDate!)),
                          ],
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              // SaÄŸ: Butonlar
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon:
                        Icon(Icons.edit, color: Colors.blue.shade600, size: 20),
                    onPressed: () =>
                        _showAddEditPersonelDialog(context, personel: personel),
                    tooltip: 'DÃ¼zenle',
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: const EdgeInsets.all(4),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete,
                        color: Colors.red.shade400, size: 20),
                    onPressed: () =>
                        _showDeleteConfirmDialog(context, personel),
                    tooltip: 'Sil',
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: const EdgeInsets.all(4),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ğŸ”§ Personel-Cihaz KartÄ±
  Widget _buildPersonelDeviceCard(
    BuildContext context,
    Device device,
    DevicePersonel personel,
    Customer? customer,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ãœst satÄ±r: Cihaz adÄ± + Ä°kon
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade200, Colors.blue.shade300],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      const Icon(Icons.devices, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
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
              ],
            ),
            const SizedBox(height: 14),
            // Alt satÄ±r: Personel ve Kurum
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Personel
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.person,
                            size: 16, color: Colors.deepPurple.shade600),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            personel.fullName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.deepPurple.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Kurum
                  if (customer != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.business,
                              size: 16, color: Colors.green.shade600),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              customer.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ğŸ¢ Kurum-Personel KartÄ±
  Widget _buildCustomerPersonelCard(
    BuildContext context,
    Customer customer,
    List<Map<String, dynamic>> personelList,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.green.shade100, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade100.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kurum BaÅŸlÄ±ÄŸÄ±
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade50, Colors.green.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.shade200.withOpacity(0.5),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.business,
                      color: Colors.green.shade700, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                      if (customer.address?.isNotEmpty ?? false)
                        Text(
                          customer.address!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Text(
                    '${personelList.length} Personel',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Personel Listesi
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: personelList.map((data) {
                final personel = data['personel'] as DevicePersonel;
                final device = data['device'] as Device;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            personel.fullName.isNotEmpty
                                ? personel.fullName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: Colors.deepPurple.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              personel.fullName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              device.name,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (personel.phone?.isNotEmpty ?? false)
                        IconButton(
                          icon: Icon(Icons.phone,
                              size: 18, color: Colors.blue.shade600),
                          onPressed: () {
                            // Telefon et
                          },
                          constraints:
                              const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Personel Detay Dialog - GELÄ°ÅTÄ°RÄ°LMÄ°Å (Cihazlar ve Kurumlar ile)
  void _showPersonelDetails(BuildContext context, DevicePersonel personel) {
    showDialog(
      context: context,
      builder: (ctx) => Consumer2<DeviceProvider, CustomerProvider>(
        builder: (context, deviceProvider, customerProvider, child) {
          // Personele atanan cihazlarÄ± bul
          final personelDevices = deviceProvider.devices.where((d) {
            return _isDeviceAssignedToPersonel(d, personel);
          }).toList();

          // BaÄŸlÄ± kurumlarÄ± bul
          final Set<Customer> connectedCustomers = {};
          for (final device in personelDevices) {
            if (device.customer is Customer) {
              connectedCustomers.add(device.customer as Customer);
            }
          }

          return AlertDialog(
            title: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.deepPurple.shade300,
                        Colors.deepPurple.shade500
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      personel.fullName.isNotEmpty
                          ? personel.fullName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        personel.fullName,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (personel.title?.isNotEmpty ?? false)
                        Text(
                          personel.title!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ä°letiÅŸim Bilgileri
                  if (personel.phone?.isNotEmpty ?? false)
                    _buildInfoRow(Icons.phone, 'Telefon', personel.phone!),
                  if (personel.email?.isNotEmpty ?? false)
                    _buildInfoRow(Icons.email, 'E-Posta', personel.email!),
                  if (personel.assignedDate != null)
                    _buildInfoRow(
                        Icons.calendar_today,
                        'KayÄ±t Tarihi',
                        DateFormat('dd.MM.yyyy')
                            .format(personel.assignedDate!)),
                  const Divider(height: 24),

                  // Atanan Cihazlar
                  Row(
                    children: [
                      Icon(Icons.devices,
                          color: Colors.blue.shade600, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Atanan Cihazlar (${personelDevices.length})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (personelDevices.isEmpty)
                    Text(
                      'HenÃ¼z cihaz atanmamÄ±ÅŸ',
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic),
                    )
                  else
                    ...personelDevices.map((device) => Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.devices_other,
                                  size: 18, color: Colors.blue.shade600),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      device.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      '${device.brand} ${device.model}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              if (device.customer is Customer)
                                Chip(
                                  label: Text(
                                    (device.customer as Customer).name,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                  backgroundColor: Colors.green.shade100,
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                            ],
                          ),
                        )),
                  const Divider(height: 24),

                  // BaÄŸlÄ± Kurumlar
                  Row(
                    children: [
                      Icon(Icons.business,
                          color: Colors.green.shade600, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'BaÄŸlÄ± Kurumlar (${connectedCustomers.length})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (connectedCustomers.isEmpty)
                    Text(
                      'HenÃ¼z baÄŸlÄ± kurum yok',
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic),
                    )
                  else
                    ...connectedCustomers.map((customer) => Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.shade100),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.business,
                                  size: 18, color: Colors.green.shade600),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  customer.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        )),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: const Text('DÃ¼zenle'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _showAddEditPersonelDialog(context, personel: personel);
                },
              ),
              ElevatedButton(
                child: const Text('Kapat'),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Bilgi satÄ±rÄ±
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
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
                Text(
                  value,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Silme onay dialogu
  void _showDeleteConfirmDialog(BuildContext context, DevicePersonel personel) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Personeli Sil'),
        content: Text(
            '"${personel.fullName}" adlÄ± personeli silmek istediÄŸinizden emin misiniz?'),
        actions: [
          TextButton(
            child: const Text('Ä°ptal'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
            onPressed: () {
              context
                  .read<DevicePersonelProvider>()
                  .deletePersonel(personel.key!);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${personel.fullName} silindi'),
                  backgroundColor: Colors.red,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Ekle/DÃ¼zenle Dialog
  void _showAddEditPersonelDialog(BuildContext context,
      {DevicePersonel? personel}) {
    final isEditing = personel != null;
    final formKey = GlobalKey<FormState>();
    Customer? selectedCustomer =
        personel?.customer is Customer ? personel!.customer as Customer : null;

    // Controller'lar
    final firstNameController =
        TextEditingController(text: personel?.firstName ?? '');
    final lastNameController =
        TextEditingController(text: personel?.lastName ?? '');
    final phoneController = TextEditingController(text: personel?.phone ?? '');
    final emailController = TextEditingController(text: personel?.email ?? '');
    final titleController = TextEditingController(text: personel?.title ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                isEditing ? Icons.edit : Icons.person_add,
                color: Colors.deepPurple,
              ),
              const SizedBox(width: 8),
              Text(isEditing ? 'Personel DÃ¼zenle' : 'Yeni Personel Ekle'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Consumer<CustomerProvider>(
                      builder: (context, customerProvider, child) {
                        Customer? selectedValue;
                        for (final customer in customerProvider.customers) {
                          if (customer.key == selectedCustomer?.key) {
                            selectedValue = customer;
                            break;
                          }
                        }

                        return DropdownButtonFormField<Customer>(
                          isExpanded: true,
                          initialValue: selectedValue,
                          decoration: const InputDecoration(
                            labelText: 'Bagli Cari / Kurum *',
                            prefixIcon: Icon(Icons.business),
                          ),
                          items: customerProvider.customers.map((customer) {
                            return DropdownMenuItem<Customer>(
                              value: customer,
                              child: Text(
                                customer.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() => selectedCustomer = value);
                          },
                          validator: (value) =>
                              value == null ? 'Kurum secimi zorunludur' : null,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    // Ä°sim
                    TextFormField(
                      controller: firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'Ä°sim *',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (v) => v!.isEmpty ? 'Ä°sim zorunludur' : null,
                    ),
                    const SizedBox(height: 12),
                    // Soyisim
                    TextFormField(
                      controller: lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Soyisim *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) =>
                          v!.isEmpty ? 'Soyisim zorunludur' : null,
                    ),
                    const SizedBox(height: 12),
                    // Unvan
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Unvan/Departman',
                        prefixIcon: Icon(Icons.work_outline),
                      ),
                    ),
                    const Divider(height: 32),
                    // Ä°letiÅŸim Bilgileri
                    Row(
                      children: [
                        Icon(Icons.contact_phone,
                            size: 18, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Ä°letiÅŸim Bilgileri',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // ğŸ¯ TELEFON + REHBER
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Telefon',
                              prefixIcon: Icon(Icons.phone),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              // ğŸ›¡ï¸ Ä°zin kontrolÃ¼
                              var status = await Permission.contacts.status;

                              if (status.isDenied || status.isRestricted) {
                                status = await Permission.contacts.request();
                                if (status.isDenied) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('âŒ Rehber izni gerekli')),
                                  );
                                  return;
                                }
                              }

                              if (status.isPermanentlyDenied) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'âŒ Ä°zin kalÄ±cÄ± reddedildi')),
                                );
                                return;
                              }

                              final contact =
                                  await FlutterContacts.openExternalPick();
                              if (contact != null) {
                                await SoundService().playSuccess();

                                if (contact.phones.isNotEmpty) {
                                  phoneController.text = contact
                                      .phones.first.number
                                      .replaceAll(RegExp(r'[^0-9+]'), '');
                                }
                                if (contact.name.first.isNotEmpty &&
                                    firstNameController.text.isEmpty) {
                                  firstNameController.text = contact.name.first;
                                }
                                if (contact.name.last.isNotEmpty &&
                                    lastNameController.text.isEmpty) {
                                  lastNameController.text = contact.name.last;
                                }
                                if (contact.emails.isNotEmpty &&
                                    emailController.text.isEmpty) {
                                  emailController.text =
                                      contact.emails.first.address;
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('âœ… KiÅŸi bilgileri dolduruldu'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              debugPrint('Rehber hatasÄ±: $e');
                              await SoundService().playError();
                            }
                          },
                          icon: const Icon(Icons.contact_phone, size: 18),
                          label: const Text('Rehber'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple.shade50,
                            foregroundColor: Colors.deepPurple,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // E-posta
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'E-Posta',
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Ä°ptal'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ElevatedButton.icon(
              icon: Icon(isEditing ? Icons.save : Icons.add),
              label: Text(isEditing ? 'Kaydet' : 'Ekle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final customer = selectedCustomer;
                  if (customer == null) return;
                  final assignedDifferentCustomer = isEditing
                      ? context.read<DeviceProvider>().devices.any((device) {
                          if (!_isDeviceAssignedToPersonel(device, personel!)) {
                            return false;
                          }
                          return device.customer?.key != customer.key;
                        })
                      : false;

                  if (assignedDifferentCustomer) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Bu personel farklı kurum cihazlarına bağlı. Kurum değişikliği için önce cihaz atamalarını düzenleyin.',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final newPersonel = DevicePersonel(
                    firstName: firstNameController.text,
                    lastName: lastNameController.text,
                    phone: phoneController.text.isEmpty
                        ? null
                        : phoneController.text,
                    email: emailController.text.isEmpty
                        ? null
                        : emailController.text,
                    title: titleController.text.isEmpty
                        ? null
                        : titleController.text,
                    assignedDate:
                        isEditing ? personel!.assignedDate : DateTime.now(),
                    customer: customer,
                  );

                  final provider = context.read<DevicePersonelProvider>();

                  if (isEditing && personel.key != null) {
                    provider.updatePersonel(personel.key as int, newPersonel);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Personel gÃ¼ncellendi'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    provider.addPersonel(newPersonel);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Personel eklendi'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                  Navigator.of(ctx).pop();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
