import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/technician.dart';
import '../providers/technician_provider.dart';
import 'technician_setup_screen.dart';

class TechnicianManagementScreen extends StatelessWidget {
  const TechnicianManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final technicianProvider = context.watch<TechnicianProvider>();
    final allTechnicians = technicianProvider.technicians;
    final isMobile = Platform.isAndroid || Platform.isIOS;
    final technicians = isMobile
        ? <Technician>[
            if (technicianProvider.currentTechnician != null)
              technicianProvider.currentTechnician!
            else if (allTechnicians.isNotEmpty)
              allTechnicians.first,
          ]
        : allTechnicians;
    final canAddTechnician = !isMobile || allTechnicians.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(isMobile ? 'Teknisyen Bilgileri' : 'Teknisyen Yönetimi'),
        backgroundColor: Colors.blue,
        actions: [
          if (canAddTechnician)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const TechnicianSetupScreen()),
              ),
            ),
        ],
      ),
      body: technicians.isEmpty
          ? _buildEmptyState(context)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: technicians.length,
              itemBuilder: (context, index) {
                final technician = technicians[index];
                final technicianIndex = allTechnicians.indexWhere(
                  (item) => item.key == technician.key,
                );
                final isCurrent =
                    technicianProvider.currentTechnician?.key == technician.key;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: isCurrent ? 4 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isCurrent
                        ? const BorderSide(color: Colors.blue, width: 2)
                        : BorderSide.none,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor:
                          isCurrent ? Colors.blue : Colors.grey.shade300,
                      radius: 28,
                      child: Text(
                        technician.firstName[0].toUpperCase(),
                        style: TextStyle(
                          color:
                              isCurrent ? Colors.white : Colors.grey.shade700,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            technician.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (isCurrent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Aktif',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (technician.phone != null &&
                            technician.phone!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.phone,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  technician.phone!,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (technician.email != null &&
                            technician.email!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.email,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  technician.email!,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        switch (value) {
                          case 'edit':
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TechnicianSetupScreen(
                                  initialTechnician: technician,
                                  technicianIndex: technicianIndex,
                                ),
                              ),
                            );
                            break;
                          case 'set_current':
                            await technicianProvider
                                .setCurrentTechnician(technician);
                            break;
                          case 'delete':
                            _showDeleteDialog(
                              context,
                              technician,
                              technicianIndex,
                            );
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Düzenle'),
                            ],
                          ),
                        ),
                        if (!isMobile && !isCurrent)
                          const PopupMenuItem(
                            value: 'set_current',
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green),
                                SizedBox(width: 8),
                                Text('Varsayılan Yap'),
                              ],
                            ),
                          ),
                        if (!isMobile)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Sil'),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: canAddTechnician
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF42A5F5), Color(0xFF1565C0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const TechnicianSetupScreen()),
                ),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Teknisyen Ekle',
                    style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
            )
          : FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TechnicianSetupScreen(
                    initialTechnician: technicians.first,
                    technicianIndex: allTechnicians.indexWhere(
                      (item) => item.key == technicians.first.key,
                    ),
                  ),
                ),
              ),
              icon: const Icon(Icons.edit),
              label: const Text('Bilgileri Düzenle'),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_outline,
              size: 64,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Henüz Teknisyen Yok',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'İlk teknisyeni ekleyerek başlayın',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const TechnicianSetupScreen()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Teknisyen Ekle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(
      BuildContext context, Technician technician, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Teknisyen Sil'),
        content: Text('${technician.fullName} silinecek. Emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<TechnicianProvider>().deleteTechnician(index);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}
