import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/models/device_module.dart';
import 'package:biomed_serv/providers/device_provider.dart';
import 'package:biomed_serv/screens/device_detail_screen.dart';
import 'package:biomed_serv/screens/device_registration_screen.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Cihaz Modül Yönetimi Ekranı
/// Kontrol ünitesine bağlı modülleri listeler ve yönetir
class DeviceModuleManagementScreen extends StatefulWidget {
  final Device controlDevice;

  const DeviceModuleManagementScreen({
    super.key,
    required this.controlDevice,
  });

  @override
  State<DeviceModuleManagementScreen> createState() => _DeviceModuleManagementScreenState();
}

class _DeviceModuleManagementScreenState extends State<DeviceModuleManagementScreen> {
  List<Device> _modules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadModules();
  }

  Future<void> _loadModules() async {
    setState(() => _isLoading = true);
    
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    
    // Kontrol ünitesinin anahtarını bul
    final controlDeviceKey = widget.controlDevice.key;
    
    if (controlDeviceKey == null) {
      setState(() => _isLoading = false);
      return;
    }
    
    // Bu kontrol ünitesine bağlı tüm cihazları bul
    final connectedModules = deviceProvider.devices.where((device) {
      return device.controlModule?.key == controlDeviceKey;
    }).toList();
    
    setState(() {
      _modules = connectedModules;
      _isLoading = false;
    });
  }

  Future<void> _removeModule(Device module) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modül Kaldır'),
        content: Text('${module.name} modülünü bu kontrol ünitesinden kaldırmak istiyor musunuz?\n\nCihaz silinmeyecek, sadece bağlantısı kaldırılacak.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İPTAL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('KALDIR'),
          ),
        ],
      ),
    );

    if (confirmed == true && module.key != null) {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      
      // Modülün kontrol modül referansını kaldır
      module.controlModule = null;
      module.moduleType = DeviceModuleType.standalone;
      
      await dbService.devicesBox.put(module.key!, module);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${module.name} kontrol ünitesinden kaldırıldı.'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadModules();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Modül Yönetimi'),
            Text(
              widget.controlDevice.name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DeviceRegistrationScreen(
                    parentControlModule: widget.controlDevice,
                    isAddingModule: true,
                  ),
                ),
              ).then((_) => _loadModules());
            },
            tooltip: 'Yeni Modül Ekle',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _modules.isEmpty
              ? _buildEmptyState()
              : _buildModuleList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz Modül Yok',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bu kontrol ünitesine bağlı modül bulunmuyor.',
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DeviceRegistrationScreen(
                    parentControlModule: widget.controlDevice,
                    isAddingModule: true,
                  ),
                ),
              ).then((_) => _loadModules());
            },
            icon: const Icon(Icons.add),
            label: const Text('MODÜL EKLE'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _modules.length,
      itemBuilder: (context, index) {
        final module = _modules[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.memory,
                color: Colors.blue.shade700,
              ),
            ),
            title: Text(
              module.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${module.brand} ${module.model}'),
                Text('Seri: ${module.serialNumber}'),
              ],
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'view':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DeviceDetailScreen(device: module),
                      ),
                    );
                    break;
                  case 'remove':
                    _removeModule(module);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(Icons.visibility, size: 20),
                      SizedBox(width: 8),
                      Text('Detay Göster'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(Icons.link_off, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Bağlantıyı Kaldır', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DeviceDetailScreen(device: module),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
