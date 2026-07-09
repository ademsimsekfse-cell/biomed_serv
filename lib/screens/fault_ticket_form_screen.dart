import 'dart:io';

import 'package:biomed_serv/models/customer.dart';
import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/models/fault_ticket.dart';
import 'package:biomed_serv/models/technician.dart';
import 'package:biomed_serv/providers/customer_provider.dart';
import 'package:biomed_serv/providers/device_provider.dart';
import 'package:biomed_serv/providers/fault_ticket_provider.dart';
import 'package:biomed_serv/providers/technician_provider.dart';
import 'package:biomed_serv/services/lan_sync_service.dart';
import 'package:biomed_serv/services/technical_assignment_service.dart';
import 'package:biomed_serv/utils/turkish_text_formatter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class FaultTicketFormScreen extends StatefulWidget {
  const FaultTicketFormScreen({super.key});

  @override
  State<FaultTicketFormScreen> createState() => _FaultTicketFormScreenState();
}

class _FaultTicketFormScreenState extends State<FaultTicketFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _problemDescController = TextEditingController();
  final _dateFormat = DateFormat('dd.MM.yyyy HH:mm');

  Customer? _selectedCustomer;
  Device? _selectedDevice;
  Technician? _selectedTechnician;
  TicketType _selectedType = TicketType.malfunction;
  String _selectedPriority = 'normal';
  DateTime _reportDateTime = DateTime.now();
  DateTime? _scheduledAt;

  bool _isLoading = false;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void dispose() {
    _problemDescController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Yeni Arıza Kaydı'),
            Text(
              'Arıza bildirim kaydı oluştur',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Bildirim Tarihi
            _buildSectionTitle('Bildirim Tarihi ve Saati'),
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today, color: Colors.blue),
                title: Text(_dateFormat.format(_reportDateTime)),
                trailing: const Icon(Icons.edit),
                onTap: _selectDateTime,
              ),
            ),
            const SizedBox(height: 16),

            // Kurum Seçimi
            _buildSectionTitle('Kurum Seçimi *'),
            _buildCustomerSelector(),
            const SizedBox(height: 16),

            // Cihaz Seçimi
            _buildSectionTitle('Cihaz Seçimi *'),
            _buildDeviceSelector(),
            const SizedBox(height: 16),

            if (_isDesktop) ...[
              _buildSectionTitle('Teknisyen Ataması'),
              _buildTechnicianSelector(),
              const SizedBox(height: 16),
            ],

            _buildSectionTitle('Öncelik ve Plan'),
            _buildPriorityAndSchedule(),
            const SizedBox(height: 16),

            // Arıza Tipi
            _buildSectionTitle('Arıza Tipi *'),
            _buildTicketTypeSelector(),
            const SizedBox(height: 16),

            // Problem Açıklaması
            _buildSectionTitle('Problem Açıklaması *'),
            TextFormField(
              controller: _problemDescController,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: const [TurkishUpperCaseTextFormatter()],
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Arıza/Montaj detaylarını yazın...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Problem açıklaması zorunludur';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Kaydet Butonu
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveTicket,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _isLoading ? 'Kaydediliyor...' : 'KAYIT ET',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildCustomerSelector() {
    return Consumer<CustomerProvider>(
      builder: (context, provider, child) {
        final customers = provider.customers;

        if (customers.isEmpty) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.warning, color: Colors.orange),
              title: const Text('Henüz kurum eklenmemiş'),
              subtitle: const Text('Önce müşteriler ekranından kurum ekleyin'),
              onTap: () {},
            ),
          );
        }

        return Column(
          children: customers.map((customer) {
            final isSelected = _selectedCustomer?.key == customer.key;
            return Card(
              margin: const EdgeInsets.only(bottom: 4),
              color: isSelected ? Colors.blue.shade50 : null,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isSelected ? Colors.blue : Colors.grey,
                  child: Icon(
                    Icons.business,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    size: 20,
                  ),
                ),
                title: Text(customer.name),
                subtitle: Text(
                  customer.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedCustomer = customer;
                    _selectedDevice = null; // Cihazı sıfırla
                  });
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildDeviceSelector() {
    if (_selectedCustomer == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.info, color: Colors.grey),
          title: Text(
            'Önce kurum seçin',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return Consumer<DeviceProvider>(
      builder: (context, provider, child) {
        final devices = provider.devices
            .where((d) => _sameCustomer(d.customer, _selectedCustomer!))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

        if (devices.isEmpty) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.warning, color: Colors.orange),
              title: const Text('Bu kuruma ait cihaz bulunamadı'),
              subtitle: const Text('Önce cihazlar ekranından cihaz ekleyin'),
            ),
          );
        }

        return Column(
          children: devices.map((device) {
            final isSelected = _selectedDevice?.key == device.key;
            final details = <String>[
              'Seri No: ${device.serialNumber}',
              'Kurum: ${_deviceCustomerName(device)}',
            ];
            final responsible = _deviceResponsibleText(device);
            if (responsible != null) {
              details.add('Sorumlu: $responsible');
            }
            return Card(
              margin: const EdgeInsets.only(bottom: 4),
              color: isSelected ? Colors.blue.shade50 : null,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isSelected ? Colors.blue : Colors.grey,
                  child: Icon(
                    Icons.devices,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    size: 20,
                  ),
                ),
                title: Text(device.name),
                subtitle: Text(details.join('\n')),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedDevice = device;
                    _selectedTechnician = _defaultTechnicianForDevice(device);
                  });
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  bool _sameCustomer(Object? candidate, Customer selected) {
    if (candidate == null) return false;
    if (identical(candidate, selected)) return true;

    if (candidate is Customer) {
      final selectedKey = selected.key;
      final candidateKey = candidate.key;
      if (selectedKey != null &&
          candidateKey != null &&
          selectedKey == candidateKey) {
        return true;
      }

      final sameName =
          _normalizeMatch(candidate.name) == _normalizeMatch(selected.name);
      final candidatePhone = _normalizeMatch(candidate.phone);
      final selectedPhone = _normalizeMatch(selected.phone);
      final samePhone = candidatePhone.isEmpty ||
          selectedPhone.isEmpty ||
          candidatePhone == selectedPhone;
      return sameName && samePhone;
    }

    return false;
  }

  String _deviceCustomerName(Device device) {
    final customer = device.customer;
    if (customer is Customer && customer.name.trim().isNotEmpty) {
      return customer.name;
    }
    return 'Kurum atanmadı';
  }

  String? _deviceResponsibleText(Device device) {
    final responsible = device.responsiblePerson;
    if (responsible == null || responsible.fullName.trim().isEmpty) {
      return null;
    }
    final title = responsible.title?.trim();
    if (title != null && title.isNotEmpty) {
      return '${responsible.fullName} - $title';
    }
    return responsible.fullName;
  }

  String _normalizeMatch(String? value) {
    return (value ?? '').toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Widget _buildTicketTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildTypeButton(
            'ARIZA',
            TicketType.malfunction,
            Icons.build,
            Colors.red,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildTypeButton(
            'MONTAJ',
            TicketType.installation,
            Icons.install_desktop,
            Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildTypeButton(
            'DİĞER',
            TicketType.other,
            Icons.more_horiz,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildTechnicianSelector() {
    return Consumer<TechnicianProvider>(
      builder: (context, provider, child) {
        final technicians = provider.technicians;
        if (technicians.isEmpty) {
          return const Card(
            child: ListTile(
              leading: Icon(Icons.person_off, color: Colors.orange),
              title: Text('Teknisyen bulunamadı'),
              subtitle: Text(
                  'Desktop merkezde önce teknisyen onayı veya kayıt gerekir.'),
            ),
          );
        }

        return DropdownButtonFormField<Technician>(
          initialValue: _selectedTechnician,
          decoration: const InputDecoration(
            labelText: 'Atanacak teknisyen',
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
          onChanged: (value) => setState(() => _selectedTechnician = value),
        );
      },
    );
  }

  Widget _buildPriorityAndSchedule() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedPriority,
          decoration: const InputDecoration(
            labelText: 'Öncelik',
            prefixIcon: Icon(Icons.priority_high),
          ),
          items: const [
            DropdownMenuItem(value: 'low', child: Text('Düşük')),
            DropdownMenuItem(value: 'normal', child: Text('Normal')),
            DropdownMenuItem(value: 'high', child: Text('Yüksek')),
            DropdownMenuItem(value: 'urgent', child: Text('Acil')),
          ],
          onChanged: (value) =>
              setState(() => _selectedPriority = value ?? 'normal'),
        ),
        if (_isDesktop) ...[
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_available, color: Colors.blue),
              title: Text(
                _scheduledAt == null
                    ? 'Plan zamanı seçilmedi'
                    : _dateFormat.format(_scheduledAt!),
              ),
              subtitle: const Text('Teknisyenin mobil görev listesine düşer'),
              trailing: const Icon(Icons.edit),
              onTap: _selectScheduledDateTime,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTypeButton(
    String label,
    TicketType type,
    IconData icon,
    Color color,
  ) {
    final isSelected = _selectedType == type;
    return InkWell(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color:
              isSelected ? color.withValues(alpha: 0.1) : Colors.grey.shade100,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? color : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _reportDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date == null) return;
    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_reportDateTime),
    );
    if (time == null) return;

    setState(() {
      _reportDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _selectScheduledDateTime() async {
    final initial = _scheduledAt ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;

    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _saveTicket() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCustomer == null) {
      _showError('Lütfen kurum seçin');
      return;
    }

    if (_selectedDevice == null) {
      _showError('Lütfen cihaz seçin');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final technicianProvider = Provider.of<TechnicianProvider>(
        context,
        listen: false,
      );
      final currentTechnician = technicianProvider.currentTechnician;
      final effectiveTechnician = _isDesktop
          ? (_selectedTechnician ?? currentTechnician)
          : currentTechnician;

      final ticket = FaultTicket(
        ticketNumber: FaultTicket.generateTicketNumber(),
        customer: _selectedCustomer!,
        device: _selectedDevice!,
        technician: effectiveTechnician,
        reportDateTime: _reportDateTime,
        ticketType: _selectedType,
        problemDescription:
            normalizeDescriptionText(_problemDescController.text),
        status: TicketStatus.pending,
        createdAt: DateTime.now(),
        technicianName: effectiveTechnician?.fullName,
        assignedTechnicianId: effectiveTechnician == null
            ? null
            : LanSyncService.technicianAccessId(effectiveTechnician),
        priority: _selectedPriority,
        scheduledAt: _scheduledAt,
      );

      await Provider.of<FaultTicketProvider>(context, listen: false)
          .addTicket(ticket);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Arıza kaydı oluşturuldu: ${ticket.ticketNumber}'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Kayıt oluşturulurken hata: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Technician? _defaultTechnicianForDevice(Device device) {
    if (!_isDesktop) {
      return context.read<TechnicianProvider>().currentTechnician;
    }
    final assignment =
        context.read<TechnicalAssignmentService>().assignmentForDevice(device);
    if (assignment == null) return null;
    final technicians = context.read<TechnicianProvider>().technicians;
    for (final technician in technicians) {
      if (LanSyncService.technicianAccessId(technician) ==
          assignment.technicianId) {
        return technician;
      }
    }
    return null;
  }
}
