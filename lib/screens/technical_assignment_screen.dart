import 'package:biomed_serv/models/customer.dart';
import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/models/technician.dart';
import 'package:biomed_serv/providers/customer_provider.dart';
import 'package:biomed_serv/providers/device_provider.dart';
import 'package:biomed_serv/providers/technician_provider.dart';
import 'package:biomed_serv/services/technical_assignment_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TechnicalAssignmentScreen extends StatefulWidget {
  const TechnicalAssignmentScreen({super.key});

  @override
  State<TechnicalAssignmentScreen> createState() =>
      _TechnicalAssignmentScreenState();
}

class _TechnicalAssignmentScreenState extends State<TechnicalAssignmentScreen> {
  Customer? _selectedCustomer;
  Device? _selectedDevice;
  Technician? _selectedTechnician;
  bool _deviceLevel = true;
  bool _applyToLinkedDevices = true;

  @override
  void initState() {
    super.initState();
    final technicianProvider = context.read<TechnicianProvider>();
    Future.microtask(technicianProvider.init);
  }

  @override
  Widget build(BuildContext context) {
    final assignmentService = context.watch<TechnicalAssignmentService>();
    final customers = context.watch<CustomerProvider>().customers;
    final devices = context.watch<DeviceProvider>().devices;
    final technicians = context.watch<TechnicianProvider>().technicians;
    final filteredDevices = devices
        .where((device) =>
            _selectedCustomer == null ||
            device.customer?.key == _selectedCustomer!.key)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teknik Servis Atamaları'),
        backgroundColor: const Color(0xFF0F766E),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHero(),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.business),
                        label: Text('Cari'),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.devices),
                        label: Text('Cihaz'),
                      ),
                    ],
                    selected: {_deviceLevel},
                    onSelectionChanged: (value) {
                      setState(() {
                        _deviceLevel = value.first;
                        _applyToLinkedDevices = true;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<Customer>(
                    initialValue: _selectedCustomer,
                    decoration: const InputDecoration(
                      labelText: 'Cari / Kurum',
                      prefixIcon: Icon(Icons.business),
                    ),
                    items: customers
                        .map(
                          (customer) => DropdownMenuItem(
                            value: customer,
                            child: Text(customer.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCustomer = value;
                        _selectedDevice = null;
                      });
                    },
                  ),
                  if (_deviceLevel) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Device>(
                      initialValue: _selectedDevice,
                      decoration: const InputDecoration(
                        labelText: 'Cihaz',
                        prefixIcon: Icon(Icons.devices),
                        helperText:
                            'Cihazlar kurum ve seri no bilgisiyle listelenir.',
                      ),
                      items: filteredDevices
                          .map(
                            (device) => DropdownMenuItem(
                              value: device,
                              child: _buildDeviceOption(device),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() {
                        _selectedDevice = value;
                        _applyToLinkedDevices = true;
                      }),
                    ),
                    if (_selectedCustomer != null &&
                        filteredDevices.isEmpty) ...[
                      const SizedBox(height: 8),
                      _buildWarningLine(
                        'Bu kuruma bagli cihaz bulunamadi. Once cihaz kaydinda kurum atamasi yapilmalidir.',
                      ),
                    ],
                    if (_selectedDevice != null) ...[
                      const SizedBox(height: 10),
                      _buildLinkedDeviceAssignmentCard(_selectedDevice!),
                    ],
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Technician>(
                    initialValue: _selectedTechnician,
                    decoration: const InputDecoration(
                      labelText: 'Sorumlu teknisyen',
                      prefixIcon: Icon(Icons.engineering),
                    ),
                    items: technicians
                        .map(
                          (technician) => DropdownMenuItem(
                            value: technician,
                            child: Text(technician.fullName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedTechnician = value),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saveAssignment,
                    icon: const Icon(Icons.assignment_ind),
                    label: const Text('Teknik Servis Ata'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildAssignmentList(
            title: 'Cihaz Atamaları',
            assignments: assignmentService.deviceAssignments,
            onDelete: (assignment) =>
                assignmentService.removeDeviceAssignment(assignment.targetId),
          ),
          const SizedBox(height: 12),
          _buildAssignmentList(
            title: 'Cari Varsayılan Atamaları',
            assignments: assignmentService.customerAssignments,
            onDelete: (assignment) =>
                assignmentService.removeCustomerAssignment(assignment.targetId),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.assignment_ind, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Cari veya cihaz bazında sorumlu teknik servisi belirle.',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceOption(Device device) {
    final customer =
        device.customer is Customer ? device.customer as Customer : null;
    final customerName = customer?.name ?? 'Kurum atanmamis';
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Text(
        '${device.name} | Seri: ${device.serialNumber} | $customerName',
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildWarningLine(String message) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade800, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.orange.shade900,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedDeviceAssignmentCard(Device selectedDevice) {
    return Consumer<DeviceProvider>(
      builder: (context, deviceProvider, child) {
        final linkedDevices =
            deviceProvider.linkedDevicesForDevice(selectedDevice);
        if (linkedDevices.length <= 1) {
          return _buildWarningLine(
            'Bu cihaz bagimsiz calisiyor. Atama yalnizca secili cihaza uygulanir.',
          );
        }

        final controlUnit = deviceProvider.controlUnitForDevice(selectedDevice);
        final linkedNames = linkedDevices
            .map((device) => '${device.name} / ${device.serialNumber}')
            .take(4)
            .join('\n');

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.teal.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.hub_outlined, color: Colors.teal.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Moduler cihaz ailesi algilandi',
                      style: TextStyle(
                        color: Colors.teal.shade900,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Kontrol unitesi: ${controlUnit?.name ?? selectedDevice.name}\n$linkedNames',
                style: TextStyle(
                  color: Colors.teal.shade900,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              if (linkedDevices.length > 4)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    '+${linkedDevices.length - 4} bagli cihaz daha',
                    style: TextStyle(
                      color: Colors.teal.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _applyToLinkedDevices,
                onChanged: (value) =>
                    setState(() => _applyToLinkedDevices = value),
                title: const Text('Atamayi bagli cihazlara da uygula'),
                subtitle: const Text(
                  'Kontrol unitesi ve alt moduller ayni teknik servis sorumlusunu miras alir.',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAssignmentList({
    required String title,
    required List<TechnicalAssignment> assignments,
    required Future<void> Function(TechnicalAssignment assignment) onDelete,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            if (assignments.isEmpty)
              Text(
                'Henüz atama yok.',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              ...assignments.map(
                (assignment) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.verified_user_outlined),
                  title: Text(assignment.targetName),
                  subtitle: Text('Sorumlu: ${assignment.technicianName}'),
                  trailing: IconButton(
                    tooltip: 'Atamayı kaldır',
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => onDelete(assignment),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAssignment() async {
    final technician = _selectedTechnician;
    if (technician == null) {
      _showMessage('Lütfen teknisyen seçin.', Colors.red);
      return;
    }

    final service = context.read<TechnicalAssignmentService>();
    if (_deviceLevel) {
      final device = _selectedDevice;
      if (device == null) {
        _showMessage('Lütfen cihaz seçin.', Colors.red);
        return;
      }
      final deviceProvider = context.read<DeviceProvider>();
      final linkedDevices = _applyToLinkedDevices
          ? deviceProvider.linkedDevicesForDevice(device)
          : <Device>[device];
      for (final linkedDevice in linkedDevices) {
        await service.assignDevice(
            device: linkedDevice, technician: technician);
      }
      _showMessage(
        linkedDevices.length > 1
            ? '${linkedDevices.length} bagli cihaz icin teknik servis atamasi kaydedildi.'
            : 'Teknik servis ataması kaydedildi.',
        Colors.green,
      );
      return;
    } else {
      final customer = _selectedCustomer;
      if (customer == null) {
        _showMessage('Lütfen cari seçin.', Colors.red);
        return;
      }
      await service.assignCustomer(customer: customer, technician: technician);
    }

    _showMessage('Teknik servis ataması kaydedildi.', Colors.green);
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }
}
