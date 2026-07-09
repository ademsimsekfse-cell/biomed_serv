import 'dart:io';

import 'package:biomed_serv/models/customer.dart';
import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/models/device_personel.dart';
import 'package:biomed_serv/models/fault_ticket.dart';
import 'package:biomed_serv/models/maintenance_form.dart';
import 'package:biomed_serv/models/service_form.dart';
import 'package:biomed_serv/providers/company_provider.dart';
import 'package:biomed_serv/providers/device_personel_provider.dart';
import 'package:biomed_serv/providers/device_provider.dart';
import 'package:biomed_serv/providers/fault_ticket_provider.dart';
import 'package:biomed_serv/providers/maintenance_form_provider.dart';
import 'package:biomed_serv/providers/report_template_provider.dart';
import 'package:biomed_serv/providers/service_form_provider.dart';
import 'package:biomed_serv/providers/technician_provider.dart';
import 'package:biomed_serv/screens/device_edit_screen.dart';
import 'package:biomed_serv/screens/device_module_management_screen.dart';
import 'package:biomed_serv/screens/device_registration_screen.dart';
import 'package:biomed_serv/screens/pdf_preview_screen.dart';
import 'package:biomed_serv/screens/service_form_screen.dart';
import 'package:biomed_serv/screens/maintenance_form_screen.dart';
import 'package:biomed_serv/services/pdf_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Cihaz Detay Ekrani
/// Cihaz bilgileri, bagli kurum, servis gecmisi ve sorumlu personel
class DeviceDetailScreen extends StatelessWidget {
  final Device device;

  const DeviceDetailScreen({
    super.key,
    required this.device,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy');
    final customer = device.customer as Customer?;
    final personel = device.responsiblePerson;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(device.name),
              Text(
                '${device.brand} ${device.model}',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.normal),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DeviceEditScreen(device: device),
                  ),
                );
              },
              tooltip: 'Duzenle',
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.info), text: 'Bilgiler'),
              Tab(icon: Icon(Icons.timeline), text: 'Yasam'),
              Tab(icon: Icon(Icons.build), text: 'Servis Gecmisi'),
              Tab(icon: Icon(Icons.history), text: 'Bakim Gecmisi'),
            ],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: Cihaz Bilgileri
            _buildInfoTab(context, customer, personel, dateFormat),
            // TAB 2: Yasam Gecmisi
            _buildLifecycleTab(context),
            // TAB 3: Servis Gecmisi
            _buildServiceHistoryTab(context),
            // TAB 4: Bakim Gecmisi
            _buildMaintenanceHistoryTab(context),
          ],
        ),
        floatingActionButton: SpeedDial(
          icon: Icons.add,
          children: [
            SpeedDialChild(
              child: const Icon(Icons.build),
              label: 'Yeni Servis Formu',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ServiceFormScreen(initialDevice: device),
                  ),
                );
              },
            ),
            SpeedDialChild(
              child: const Icon(Icons.handyman),
              label: 'Yeni Bakim Formu',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        MaintenanceFormScreen(preselectedDevice: device),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTab(
    BuildContext context,
    Customer? customer,
    DevicePersonel? personel,
    DateFormat dateFormat,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === CIHAZ KARTI ===
          _buildSectionCard(
            title: 'Cihaz Bilgileri',
            icon: Icons.devices,
            color: Colors.blue,
            children: [
              _buildInfoRow('Cihaz Adi', device.name),
              _buildInfoRow('Marka', device.brand),
              _buildInfoRow('Model', device.model),
              _buildInfoRow('Seri No', device.serialNumber),
              if (device.barcode != null)
                _buildInfoRow('Barkod', device.barcode!),
              if (device.deviceCategory != null)
                _buildInfoRow('Kategori', device.deviceCategory!),
              if (device.location != null)
                _buildInfoRow('Lokasyon', device.location!),
              const Divider(),
              _buildInfoRow(
                'Modul Tipi',
                device.isControlModule
                    ? 'Kontrol Modulu (Ana)'
                    : device.isProcessingModule
                        ? 'Islem Modulu (Alt)'
                        : 'Standalone (Tekli)',
              ),
              _buildInfoRow(
                'Sahiplik',
                device.ownershipStatus == OwnershipStatus.sold
                    ? 'SOLD (Satilmis)'
                    : 'RENT (Kiralik)',
              ),
            ],
          ),

          const SizedBox(height: 16),

          _buildSystemRelationsCard(context),

          const SizedBox(height: 16),

          // === KONTROL UNITESI - MODUL YONETIMI ===
          if (device.isControlModule)
            _buildSectionCard(
              title: 'Modul Yonetimi',
              icon: Icons.account_tree,
              color: Colors.deepPurple,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.deepPurple.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Bu cihaz bir Kontrol Unitesidir.',
                              style: TextStyle(
                                color: Colors.deepPurple.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DeviceRegistrationScreen(
                                  parentControlModule: device,
                                  isAddingModule: true,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('MODUL EKLE'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          // Modul yonetimi ekranina git
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  DeviceModuleManagementScreen(
                                      controlDevice: device),
                            ),
                          );
                        },
                        icon: const Icon(Icons.manage_search),
                        label: const Text('Modulleri Yonet'),
                      ),
                    ],
                  ),
                ),
              ],
            ),

          if (device.isControlModule) const SizedBox(height: 16),

          // === KURUM KARTI ===
          _buildSectionCard(
            title: 'Bagli Kurum',
            icon: Icons.business,
            color: Colors.green,
            children: [
              if (customer != null) ...[
                _buildInfoRow('Kurum Adi', customer.name),
                _buildInfoRow('Adres', customer.address),
                _buildInfoRow('Telefon', customer.phone),
                if (customer.authorizedPerson.isNotEmpty)
                  _buildInfoRow('Yetkili Kisi', customer.authorizedPerson),
                if (customer.email != null)
                  _buildInfoRow('E-posta', customer.email!),
                if (customer.vergiNo != null)
                  _buildInfoRow('Vergi No', customer.vergiNo!),
              ] else
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'Henuz bir kuruma atanmamis',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // === SORUMLU PERSONEL KARTI ===
          _buildSectionCard(
            title: 'Sorumlu Personel',
            icon: Icons.person,
            color: Colors.orange,
            action: IconButton(
              icon: const Icon(Icons.edit, color: Colors.orange, size: 20),
              onPressed: () => _showPersonelPicker(context),
              tooltip: 'Personel Degistir',
            ),
            children: [
              if (personel != null) ...[
                _buildInfoRow('Ad Soyad', personel.fullName),
                if (personel.title != null)
                  _buildInfoRow('Unvan', personel.title!),
                if (personel.phone != null)
                  _buildInfoRow('Telefon', personel.phone!),
                if (personel.email != null)
                  _buildInfoRow('E-posta', personel.email!),
                if (personel.assignedDate != null)
                  _buildInfoRow(
                    'Atanma Tarihi',
                    dateFormat.format(personel.assignedDate!),
                  ),
                // Ayri atama bilgisi (moduller icin)
                if (device.isProcessingModule)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Bu module ayri personel atanmistir.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ] else
                Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'Henuz sorumlu personel atanmamis',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showPersonelPicker(context),
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Personel Ata'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: BorderSide(color: Colors.orange.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          const SizedBox(height: 16),

          // === GARANTI KARTI ===
          if (device.warrantyStartDate != null ||
              device.warrantyEndDate != null)
            _buildSectionCard(
              title: 'Garanti Bilgileri',
              icon: Icons.security,
              color: Colors.purple,
              children: [
                if (device.warrantyStartDate != null)
                  _buildInfoRow(
                    'Baslangic',
                    dateFormat.format(device.warrantyStartDate!),
                  ),
                if (device.warrantyEndDate != null)
                  _buildInfoRow(
                    'Bitis',
                    dateFormat.format(device.warrantyEndDate!),
                  ),
                if (device.warrantyEndDate != null)
                  _buildInfoRow(
                    'Durum',
                    device.warrantyEndDate!.isAfter(DateTime.now())
                        ? 'Aktif'
                        : 'Sona Ermis',
                  ),
              ],
            ),

          const SizedBox(height: 16),

          // === TARIH KARTI (Kontrol modulu degilse) ===
          if (device.showDetailedFields) ...[
            _buildSectionCard(
              title: 'Tarih Bilgileri',
              icon: Icons.calendar_today,
              color: Colors.teal,
              children: [
                if (device.productionDate != null)
                  _buildInfoRow(
                    'Uretim Tarihi',
                    dateFormat.format(device.productionDate!),
                  ),
                if (device.installationDate != null)
                  _buildInfoRow(
                    'Kurulum Tarihi',
                    dateFormat.format(device.installationDate!),
                  ),
                if (device.serviceDuration != null)
                  _buildInfoRow(
                    'Hizmet Suresi',
                    '${device.serviceDuration} ay',
                  ),
                if (device.economicLife != null)
                  _buildInfoRow(
                    'Ekonomik Omur',
                    '${device.economicLife} yil',
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // === MODUL BILGISI ===
          if (device.controlModule != null)
            _buildSectionCard(
              title: 'Bagli Oldugu Ana Modul',
              icon: Icons.account_tree,
              color: Colors.indigo,
              children: [
                FutureBuilder(
                  future: _loadControlModule(context),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      final controlMod = snapshot.data!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Ad', controlMod.name),
                          _buildInfoRow('Marka/Model',
                              '${controlMod.brand} ${controlMod.model}'),
                          _buildInfoRow('Seri No', controlMod.serialNumber),
                        ],
                      );
                    }
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  },
                ),
              ],
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSystemRelationsCard(BuildContext context) {
    return Consumer<DeviceProvider>(
      builder: (context, deviceProvider, child) {
        final linkedDevices = _linkedDevices(deviceProvider.devices);
        final moduleCount =
            linkedDevices.where((item) => item.key != device.key).length;
        final controlUnit = linkedDevices.firstWhere(
          (item) => item.isControlModule,
          orElse: () => device,
        );

        return _buildSectionCard(
          title: 'Sistem Iliskileri',
          icon: Icons.hub,
          color: Colors.teal,
          children: [
            _buildInfoRow(
              'Zincir Durumu',
              device.isStandalone
                  ? 'Bagimsiz / tekil cihaz'
                  : '${linkedDevices.length} bagli cihaz ayni sistemde',
            ),
            _buildInfoRow(
              'Ana Unite',
              device.isStandalone
                  ? 'Yok'
                  : '${controlUnit.name} / ${controlUnit.serialNumber}',
            ),
            if (!device.isStandalone)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.teal.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.isControlModule
                          ? 'Bu kontrol unitesine bagli moduller'
                          : 'Bu cihaz ile birlikte hareket eden baglantilar',
                      style: TextStyle(
                        color: Colors.teal.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...linkedDevices.map(
                      (linkedDevice) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              linkedDevice.key == device.key
                                  ? Icons.radio_button_checked
                                  : linkedDevice.isControlModule
                                      ? Icons.settings_input_component
                                      : Icons.memory,
                              size: 16,
                              color: Colors.teal.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${linkedDevice.name} • ${linkedDevice.serialNumber}'
                                '${linkedDevice.key == device.key ? ' (mevcut cihaz)' : ''}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (moduleCount > 0) const SizedBox(height: 6),
                    Text(
                      'Kurum atamasi zincirde otomatik esitlenir.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.teal.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  List<Device> _linkedDevices(List<Device> devices) {
    if (device.key == null) {
      return [device];
    }

    if (device.isStandalone) {
      return [device];
    }

    final rootKey = _chainRootKey(device);
    final linked = devices.where((candidate) {
      if (candidate.key == rootKey) return true;
      return candidate.isProcessingModule &&
          candidate.controlModule?.key == rootKey;
    }).toList();

    linked.sort((a, b) {
      if (a.key == rootKey) return -1;
      if (b.key == rootKey) return 1;
      return a.name.compareTo(b.name);
    });

    return linked.isEmpty ? [device] : linked;
  }

  dynamic _chainRootKey(Device target) {
    if (target.isProcessingModule && target.controlModule?.key != null) {
      return target.controlModule!.key;
    }
    return target.key;
  }

  Widget _buildServiceHistoryTab(BuildContext context) {
    return Consumer<ServiceFormProvider>(
      builder: (context, serviceProvider, child) {
        final serviceForms = serviceProvider.forms
            .where((form) => form.device.key == device.key)
            .toList();

        serviceForms.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (serviceForms.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.build_outlined,
                    size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'Henuz servis kaydi bulunmuyor.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: serviceForms.length,
          itemBuilder: (context, index) {
            final form = serviceForms[index];
            return _buildServiceCard(context, form);
          },
        );
      },
    );
  }

  Widget _buildLifecycleTab(BuildContext context) {
    return Consumer3<ServiceFormProvider, MaintenanceFormProvider,
        FaultTicketProvider>(
      builder: (context, serviceProvider, maintenanceProvider, ticketProvider,
          child) {
        final serviceForms = serviceProvider.forms
            .where((form) => form.device.key == device.key)
            .toList();
        final maintenanceForms = maintenanceProvider.forms
            .where((form) => form.device.key == device.key)
            .toList();
        final tickets = ticketProvider.tickets
            .where((ticket) => ticket.device.key == device.key)
            .toList();

        serviceForms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        maintenanceForms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        tickets.sort((a, b) => b.reportDateTime.compareTo(a.reportDateTime));

        final entries =
            _buildLifecycleEntries(serviceForms, maintenanceForms, tickets);
        final totalParts = serviceForms.fold<int>(
              0,
              (sum, form) => sum + form.partsUsed.length,
            ) +
            maintenanceForms.fold<int>(
              0,
              (sum, form) => sum + form.partsUsed.length,
            );
        final lastActivity = entries.isEmpty ? null : entries.first.date;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildLifecycleSummary(
              serviceCount: serviceForms.length,
              maintenanceCount: maintenanceForms.length,
              ticketCount: tickets.length,
              partsCount: totalParts,
              lastActivity: lastActivity,
            ),
            const SizedBox(height: 16),
            if (entries.isEmpty)
              _buildLifecycleEmptyState()
            else
              ...entries.asMap().entries.map(
                    (entry) => _buildTimelineEntry(
                      entry.value,
                      isLast: entry.key == entries.length - 1,
                    ),
                  ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  List<_DeviceTimelineEntry> _buildLifecycleEntries(
    List<ServiceForm> serviceForms,
    List<MaintenanceForm> maintenanceForms,
    List<FaultTicket> tickets,
  ) {
    final entries = <_DeviceTimelineEntry>[];

    for (final ticket in tickets) {
      entries.add(
        _DeviceTimelineEntry(
          date: ticket.reportDateTime,
          title: 'Ariza Talebi #${ticket.ticketNumber}',
          subtitle: '${ticket.ticketTypeText} • ${ticket.statusText}',
          detail: ticket.serviceFormNumber == null
              ? ticket.problemDescription
              : '${ticket.problemDescription}\nServis formu: ${ticket.serviceFormNumber}',
          icon: _getTicketTimelineIcon(ticket.status),
          color: Color(ticket.statusColor),
          trailing: ticket.serviceFormNumber == null ? null : 'Servise donustu',
        ),
      );
    }

    for (final form in serviceForms) {
      entries.add(
        _DeviceTimelineEntry(
          date: form.createdAt,
          title: 'Servis Formu #${form.formNumber}',
          subtitle: form.problemTypes.isEmpty
              ? 'Servis kaydi olusturuldu'
              : form.problemTypes.join(', '),
          detail: form.sourceTicketNumber == null
              ? (form.problemDescription ?? form.actionsTaken)
              : '${form.problemDescription ?? form.actionsTaken ?? ''}\nKaynak talep: ${form.sourceTicketNumber}',
          icon: Icons.build,
          color: Colors.red,
          trailing: form.partsUsed.isNotEmpty
              ? '${form.partsUsed.length} parca'
              : form.resultStatus,
        ),
      );
    }

    for (final form in maintenanceForms) {
      entries.add(
        _DeviceTimelineEntry(
          date: form.createdAt,
          title: 'Bakim Formu #${form.formNumber}',
          subtitle: 'Periyot: ${form.maintenancePeriod}',
          detail: form.actionsTaken.isNotEmpty
              ? form.actionsTaken.join(', ')
              : form.notes,
          icon: Icons.handyman,
          color: Colors.green,
          trailing: form.partsUsed.isNotEmpty
              ? '${form.partsUsed.length} parca'
              : null,
        ),
      );
    }

    if (device.installationDate != null) {
      entries.add(
        _DeviceTimelineEntry(
          date: device.installationDate!,
          title: 'Kurulum',
          subtitle: 'Cihaz kurulum tarihi',
          detail: (device.customer as Customer?)?.name,
          icon: Icons.install_mobile,
          color: Colors.blue,
        ),
      );
    }

    if (device.warrantyStartDate != null) {
      entries.add(
        _DeviceTimelineEntry(
          date: device.warrantyStartDate!,
          title: 'Garanti Baslangici',
          subtitle: 'Garanti sureci basladi',
          detail: device.warrantyEndDate == null
              ? null
              : 'Bitis: ${DateFormat('dd.MM.yyyy').format(device.warrantyEndDate!)}',
          icon: Icons.verified_user,
          color: Colors.purple,
        ),
      );
    }

    if (device.productionDate != null) {
      entries.add(
        _DeviceTimelineEntry(
          date: device.productionDate!,
          title: 'Uretim',
          subtitle: 'Cihaz uretim tarihi',
          detail: '${device.brand} ${device.model}',
          icon: Icons.precision_manufacturing,
          color: Colors.teal,
        ),
      );
    }

    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  Widget _buildLifecycleSummary({
    required int serviceCount,
    required int maintenanceCount,
    required int ticketCount,
    required int partsCount,
    required DateTime? lastActivity,
  }) {
    final dateFormat = DateFormat('dd.MM.yyyy');

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        final cards = [
          _buildMetricTile(
            label: 'Servis',
            value: '$serviceCount',
            icon: Icons.build,
            color: Colors.red,
          ),
          _buildMetricTile(
            label: 'Bakim',
            value: '$maintenanceCount',
            icon: Icons.handyman,
            color: Colors.green,
          ),
          _buildMetricTile(
            label: 'Talep',
            value: '$ticketCount',
            icon: Icons.assignment,
            color: Colors.purple,
          ),
          _buildMetricTile(
            label: 'Parca',
            value: '$partsCount',
            icon: Icons.inventory_2,
            color: Colors.orange,
          ),
          _buildMetricTile(
            label: 'Son Islem',
            value: lastActivity == null ? '-' : dateFormat.format(lastActivity),
            icon: Icons.event_available,
            color: Colors.blue,
          ),
        ];

        if (!isWide) {
          return Column(
            children: [
              Row(children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 8),
                Expanded(child: cards[1])
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: cards[2]),
                const SizedBox(width: 8),
                Expanded(child: cards[3])
              ]),
              const SizedBox(height: 8),
              cards[4],
            ],
          );
        }

        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i != cards.length - 1) const SizedBox(width: 10),
            ],
          ],
        );
      },
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineEntry(
    _DeviceTimelineEntry entry, {
    required bool isLast,
  }) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 42,
            child: Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: entry.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: entry.color.withValues(alpha: 0.35)),
                  ),
                  child: Icon(entry.icon, color: entry.color, size: 18),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: Colors.grey.shade200,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          entry.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (entry.trailing != null) ...[
                        const SizedBox(width: 8),
                        _buildTimelineBadge(entry.trailing!, entry.color),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateFormat.format(entry.date),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    entry.subtitle,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (entry.detail != null &&
                      entry.detail!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      entry.detail!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: Colors.grey.shade700, height: 1.25),
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

  Widget _buildTimelineBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildLifecycleEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.timeline, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'Henuz yasam kaydi yok',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Servis, bakim, kurulum ve garanti hareketleri burada tek akista gorunecek.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  IconData _getTicketTimelineIcon(TicketStatus status) {
    switch (status) {
      case TicketStatus.pending:
        return Icons.schedule;
      case TicketStatus.inProgress:
        return Icons.engineering;
      case TicketStatus.waitingPart:
        return Icons.inventory_2;
      case TicketStatus.devicePassive:
        return Icons.block;
      case TicketStatus.completed:
        return Icons.check_circle;
      case TicketStatus.cancelled:
        return Icons.cancel;
    }
  }

  Widget _buildMaintenanceHistoryTab(BuildContext context) {
    return Consumer<MaintenanceFormProvider>(
      builder: (context, maintenanceProvider, child) {
        final maintenanceForms = maintenanceProvider.forms
            .where((form) => form.device.key == device.key)
            .toList();

        maintenanceForms.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (maintenanceForms.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.handyman_outlined,
                    size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'Henuz bakim kaydi bulunmuyor.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: maintenanceForms.length,
          itemBuilder: (context, index) {
            final form = maintenanceForms[index];
            return _buildMaintenanceCard(context, form);
          },
        );
      },
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
    Widget? action,
  }) {
    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                if (action != null) action,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context, ServiceForm form) {
    final dateFormat = DateFormat('dd.MM.yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red.shade100,
          child: Icon(Icons.build, color: Colors.red.shade700, size: 20),
        ),
        title: Text('Servis #${form.formNumber}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(dateFormat.format(form.createdAt)),
                const SizedBox(width: 12),
                if (form.problemDateTime != null)
                  Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
                if (form.problemDateTime != null)
                  Text(DateFormat('HH:mm').format(form.problemDateTime!)),
              ],
            ),
            if (form.problemDescription != null) ...[
              const SizedBox(height: 4),
              Text(
                form.problemDescription!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
            if (form.partsUsed.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.inventory_2,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    '${form.partsUsed.length} parca kullanildi',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ],
        ),
        onTap: () => _openServiceFormPreview(context, form),
      ),
    );
  }

  Widget _buildMaintenanceCard(BuildContext context, MaintenanceForm form) {
    final dateFormat = DateFormat('dd.MM.yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: Icon(Icons.handyman, color: Colors.green.shade700, size: 20),
        ),
        title: Text('Bakim #${form.formNumber}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(dateFormat.format(form.createdAt)),
              ],
            ),
            if (form.actionsTaken.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                form.actionsTaken.join(', '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
            if (form.partsUsed.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.inventory_2,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    '${form.partsUsed.length} parca kullanildi',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ],
        ),
        onTap: () => _openMaintenanceFormPreview(context, form),
      ),
    );
  }

  Future<void> _openServiceFormPreview(
    BuildContext context,
    ServiceForm form,
  ) async {
    final pdfService = PdfService();
    final reportTemplateProvider =
        Provider.of<ReportTemplateProvider>(context, listen: false);
    final companyProvider =
        Provider.of<CompanyProvider>(context, listen: false);
    final technicianProvider =
        Provider.of<TechnicianProvider>(context, listen: false);
    final serviceFormProvider =
        Provider.of<ServiceFormProvider>(context, listen: false);

    try {
      pdfService.setCompanyInfo(companyProvider.companyInfo);
      pdfService.setTechnician(technicianProvider.currentTechnician);
      pdfService.setTemplate(reportTemplateProvider.defaultServiceTemplate);
      var pdfFile = form.pdfPath != null && form.pdfPath!.isNotEmpty
          ? File(form.pdfPath!)
          : await pdfService.generateServicePdf(form);
      if (!await pdfFile.exists()) {
        pdfFile = await pdfService.generateServicePdf(form);
      }
      form.pdfPath = pdfFile.path;
      await serviceFormProvider.updateForm(form);
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfPreviewScreen(
            filePath: pdfFile.path,
            title: 'Servis Formu Onizleme',
            shareText: 'Servis Formu',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Servis formu acilirken hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openMaintenanceFormPreview(
    BuildContext context,
    MaintenanceForm form,
  ) async {
    final pdfService = PdfService();
    final reportTemplateProvider =
        Provider.of<ReportTemplateProvider>(context, listen: false);
    final companyProvider =
        Provider.of<CompanyProvider>(context, listen: false);
    final technicianProvider =
        Provider.of<TechnicianProvider>(context, listen: false);
    final maintenanceFormProvider =
        Provider.of<MaintenanceFormProvider>(context, listen: false);

    try {
      pdfService.setCompanyInfo(companyProvider.companyInfo);
      pdfService.setTechnician(technicianProvider.currentTechnician);
      pdfService.setTemplate(reportTemplateProvider.defaultMaintenanceTemplate);
      var pdfFile = form.pdfPath != null && form.pdfPath!.isNotEmpty
          ? File(form.pdfPath!)
          : await pdfService.generateMaintenancePdf(form);
      if (!await pdfFile.exists()) {
        pdfFile = await pdfService.generateMaintenancePdf(form);
      }
      form.pdfPath = pdfFile.path;
      await maintenanceFormProvider.updateForm(form);
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfPreviewScreen(
            filePath: pdfFile.path,
            title: 'Bakim Formu Onizleme',
            shareText: 'Bakim Formu',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bakim formu acilirken hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Device?> _loadControlModule(BuildContext context) async {
    if (device.controlModule == null) return null;
    // HiveObject lazy loading cozumu
    final controlModule = device.controlModule;
    if (controlModule is Device) {
      return controlModule;
    }
    return null;
  }

  /// Personel secim dialogu (ayri ayri atama)
  void _showPersonelPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Consumer<DevicePersonelProvider>(
          builder: (context, personelProvider, child) {
            final personels = personelProvider.personels;

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.manage_accounts, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text('Sorumlu Personel Sec'),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    // Bilgi metni
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info,
                              size: 16, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              device.isProcessingModule
                                  ? 'Bu module ozel personel atayabilirsiniz.'
                                  : 'Bu cihaza sorumlu personel atayin.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Personel Listesi
                    Expanded(
                      child: personels.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.people_outline,
                                      size: 48, color: Colors.grey.shade300),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Henuz personel kaydi yok.\nPersonel yonetimi ekleyin.',
                                    textAlign: TextAlign.center,
                                    style:
                                        TextStyle(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount:
                                  personels.length + 1, // +1 for "clear" option
                              itemBuilder: (context, index) {
                                // Ilk secenek: Personel kaldir
                                if (index == 0) {
                                  return Card(
                                    margin: EdgeInsets.only(bottom: 8),
                                    color: device.responsiblePerson == null
                                        ? Colors.red.shade50
                                        : null,
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.red.shade100,
                                        child: Icon(Icons.person_off,
                                            color: Colors.red),
                                      ),
                                      title: Text(
                                        'Personel Atamasini Kaldir',
                                        style: TextStyle(
                                          fontWeight:
                                              device.responsiblePerson == null
                                                  ? FontWeight.bold
                                                  : null,
                                        ),
                                      ),
                                      subtitle:
                                          Text('Cihazda personel olmayacak'),
                                      selected:
                                          device.responsiblePerson == null,
                                      onTap: () async {
                                        final navigator = Navigator.of(ctx);
                                        await _assignPersonel(context, null);
                                        navigator.pop();
                                      },
                                    ),
                                  );
                                }

                                final personel = personels[index - 1];
                                final isSelected =
                                    device.responsiblePerson?.key ==
                                        personel.key;

                                return Card(
                                  margin: EdgeInsets.only(bottom: 8),
                                  color:
                                      isSelected ? Colors.orange.shade50 : null,
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isSelected
                                          ? Colors.orange.shade200
                                          : Colors.deepPurple.shade100,
                                      child: Text(
                                        personel.fullName.isNotEmpty
                                            ? personel.fullName[0]
                                            : '?',
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.orange.shade800
                                              : Colors.deepPurple,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      personel.fullName,
                                      style: TextStyle(
                                        fontWeight:
                                            isSelected ? FontWeight.bold : null,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (personel.title != null)
                                          Text(personel.title!,
                                              style: TextStyle(fontSize: 12)),
                                        if (personel.phone != null)
                                          Text('Tel: ${personel.phone}',
                                              style: TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                    selected: isSelected,
                                    onTap: () async {
                                      final navigator = Navigator.of(ctx);
                                      await _assignPersonel(context, personel);
                                      navigator.pop();
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Iptal'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Personel atama (sadece bu cihaz icin)
  Future<void> _assignPersonel(
    BuildContext context,
    DevicePersonel? personel,
  ) async {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final targetCustomer = device.customer;

    try {
      // Sadece bu cihazin personelini guncelle (zincirleme degil)
      if (personel != null &&
          deviceProvider.hasResponsiblePersonConflict(
            personel: personel,
            targetDevice: device,
            targetCustomer: targetCustomer,
          )) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Bu kullanici baska bir kurumdaki cihaza atanmis. Seri no bazli atamada kurumlar karistirilamaz.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      device.responsiblePerson = personel;
      await deviceProvider.updateDevice(device.key!, device);

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            personel != null
                ? '${personel.fullName} atandi'
                : 'Personel atamasi kaldirildi',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Atama hatasi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// Speed Dial Widget (FAB Menusu)
class SpeedDial extends StatelessWidget {
  final IconData icon;
  final List<SpeedDialChild> children;

  const SpeedDial({
    super.key,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Yeni Islem',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ...children.map((child) => ListTile(
                      leading: IconTheme(
                        data: IconThemeData(
                          color: Theme.of(context).primaryColor,
                        ),
                        child: child.child,
                      ),
                      title: Text(child.label),
                      onTap: () {
                        Navigator.pop(context);
                        child.onTap?.call();
                      },
                    )),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
      child: Icon(icon),
    );
  }
}

class SpeedDialChild {
  final Widget child;
  final String label;
  final VoidCallback? onTap;

  SpeedDialChild({
    required this.child,
    required this.label,
    this.onTap,
  });
}

class _DeviceTimelineEntry {
  final DateTime date;
  final String title;
  final String subtitle;
  final String? detail;
  final IconData icon;
  final Color color;
  final String? trailing;

  const _DeviceTimelineEntry({
    required this.date,
    required this.title,
    required this.subtitle,
    this.detail,
    required this.icon,
    required this.color,
    this.trailing,
  });
}
