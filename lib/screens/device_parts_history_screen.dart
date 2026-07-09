import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/providers/maintenance_form_provider.dart';
import 'package:biomed_serv/providers/service_form_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class DevicePartsHistoryScreen extends StatelessWidget {
  final Device device;

  const DevicePartsHistoryScreen({
    super.key,
    required this.device,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cihaz Parça Geçmişi'),
            Text(
              device.name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: Consumer2<ServiceFormProvider, MaintenanceFormProvider>(
        builder: (context, serviceProvider, maintenanceProvider, child) {
          // Tüm kullanılan parçaları topla
          final List<PartUsageRecord> partUsages = [];

          // Servis formlarından parçaları çek
          for (var form in serviceProvider.forms) {
            if (form.device.key == device.key) {
              for (var part in form.partsUsed) {
                partUsages.add(PartUsageRecord(
                  partName: part.name,
                  quantity: part.quantity,
                  date: form.createdAt,
                  formNumber: form.formNumber,
                  formType: 'Servis',
                  technicianName: form.technicianName,
                  referenceNo: part.referenceNo,
                  barcode: part.barcode,
                ));
              }
            }
          }

          // Bakım formlarından parçaları çek
          for (var form in maintenanceProvider.forms) {
            if (form.device.key == device.key) {
              for (var part in form.partsUsed) {
                partUsages.add(PartUsageRecord(
                  partName: part.name,
                  quantity: part.quantity,
                  date: form.createdAt,
                  formNumber: form.formNumber,
                  formType: 'Bakım',
                  technicianName: form.technicianName,
                  referenceNo: part.referenceNo,
                  barcode: part.barcode,
                ));
              }
            }
          }

          // Tarihe göre sırala (yeniden eskiye)
          partUsages.sort((a, b) => b.date.compareTo(a.date));

          // Parça istatistiklerini hesapla
          final stats = _calculateStats(partUsages);

          if (partUsages.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bu cihaz için henüz parça kullanımı bulunmamaktadır.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // İstatistik Kartları
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildStatCard(
                      'Toplam Parça',
                      stats.totalParts.toString(),
                      Icons.inventory,
                      Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      'Toplam Adet',
                      stats.totalQuantity.toString(),
                      Icons.format_list_numbered,
                      Colors.green,
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      'Farklı Parça',
                      stats.uniqueParts.toString(),
                      Icons.category,
                      Colors.orange,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Parça Listesi
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: partUsages.length,
                  itemBuilder: (context, index) {
                    final usage = partUsages[index];
                    return _buildPartUsageCard(context, usage);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartUsageCard(BuildContext context, PartUsageRecord usage) {
    final dateFormat = DateFormat('dd.MM.yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: usage.formType == 'Servis'
              ? Colors.red.shade100
              : Colors.green.shade100,
          child: Text(
            usage.quantity.toString(),
            style: TextStyle(
              color: usage.formType == 'Servis'
                  ? Colors.red.shade700
                  : Colors.green.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          usage.partName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(dateFormat.format(usage.date)),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: usage.formType == 'Servis'
                        ? Colors.red.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    usage.formType,
                    style: TextStyle(
                      fontSize: 10,
                      color: usage.formType == 'Servis'
                          ? Colors.red.shade700
                          : Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
            if (usage.technicianName != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.person, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    usage.technicianName!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
            if (usage.referenceNo != null || usage.barcode != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  if (usage.referenceNo != null) ...[
                    Icon(Icons.numbers, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      'Ref: ${usage.referenceNo}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  if (usage.barcode != null) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.qr_code, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      usage.barcode!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
        trailing: Text(
          '#${usage.formNumber.split('-').last}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
      ),
    );
  }

  PartStats _calculateStats(List<PartUsageRecord> usages) {
    final uniquePartNames = usages.map((u) => u.partName).toSet();
    final totalQuantity = usages.fold<int>(0, (sum, u) => sum + u.quantity);

    return PartStats(
      totalParts: usages.length,
      totalQuantity: totalQuantity,
      uniqueParts: uniquePartNames.length,
    );
  }
}

class PartUsageRecord {
  final String partName;
  final int quantity;
  final DateTime date;
  final String formNumber;
  final String formType;
  final String? technicianName;
  final String? referenceNo;
  final String? barcode;

  PartUsageRecord({
    required this.partName,
    required this.quantity,
    required this.date,
    required this.formNumber,
    required this.formType,
    this.technicianName,
    this.referenceNo,
    this.barcode,
  });
}

class PartStats {
  final int totalParts;
  final int totalQuantity;
  final int uniqueParts;

  PartStats({
    required this.totalParts,
    required this.totalQuantity,
    required this.uniqueParts,
  });
}
