import 'package:biomed_serv/models/maintenance_template_v2.dart';
import 'package:biomed_serv/providers/maintenance_template_v2_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Bakım Şablonları Yönetim Ekranı
/// Cihaz modeline özel bakım şablonlarını listeleme, ekleme, düzenleme
class MaintenanceTemplateManagementScreen extends StatefulWidget {
  const MaintenanceTemplateManagementScreen({super.key});

  @override
  State<MaintenanceTemplateManagementScreen> createState() =>
      _MaintenanceTemplateManagementScreenState();
}

class _MaintenanceTemplateManagementScreenState
    extends State<MaintenanceTemplateManagementScreen> {
  String? _selectedModel;
  String? _selectedBrand;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bakım Şablonları Yönetimi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditTemplateDialog(),
            tooltip: 'Yeni Şablon',
          ),
        ],
      ),
      body: Consumer<MaintenanceTemplateV2Provider>(
        builder: (context, provider, child) {
          if (provider.templates.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.build_circle, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz bakım şablonu bulunmuyor.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showAddEditTemplateDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Şablon Oluştur'),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () async {
                      await provider.addDemoData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Demo veriler eklendi!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Örnek Verileri Yükle'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Filtreler
              _buildFilters(provider),
              // Şablon Listesi
              Expanded(
                child: _buildTemplateList(provider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilters(MaintenanceTemplateV2Provider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // Marka Filtresi
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _selectedBrand,
              decoration: const InputDecoration(
                labelText: 'Marka Filtrele',
                prefixIcon: Icon(Icons.business),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Tüm Markalar'),
                ),
                ...provider.uniqueDeviceBrands.map((brand) {
                  return DropdownMenuItem<String>(
                    value: brand,
                    child: Text(brand),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedBrand = value;
                  _selectedModel = null; // Model filtresini sıfırla
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          // Model Filtresi
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _selectedModel,
              decoration: const InputDecoration(
                labelText: 'Model Filtrele',
                prefixIcon: Icon(Icons.devices),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Tüm Modeller'),
                ),
                ...provider.uniqueDeviceModels.map((model) {
                  return DropdownMenuItem<String>(
                    value: model,
                    child: Text(model),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() => _selectedModel = value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateList(MaintenanceTemplateV2Provider provider) {
    var templates = provider.templates;

    // Filtreleme uygula
    if (_selectedBrand != null) {
      templates = templates
          .where((t) => t.deviceBrand == _selectedBrand)
          .toList();
    }
    if (_selectedModel != null) {
      templates = templates
          .where((t) => t.deviceModel == _selectedModel)
          .toList();
    }

    if (templates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_list, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Filtreye uygun şablon bulunamadı.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedBrand = null;
                  _selectedModel = null;
                });
              },
              child: const Text('Filtreleri Temizle'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final template = templates[index];
        return _buildTemplateCard(template, provider);
      },
    );
  }

  Widget _buildTemplateCard(
    MaintenanceTemplateV2 template,
    MaintenanceTemplateV2Provider provider,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: template.isActive ? Colors.green.shade100 : Colors.grey.shade200,
          child: Icon(
            Icons.build,
            color: template.isActive ? Colors.green.shade700 : Colors.grey,
          ),
        ),
        title: Text(
          template.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(template.fullDeviceDescription),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text(
                    template.periodDescription,
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: Colors.blue.shade50,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    '${template.lines.length} Adım',
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: Colors.orange.shade50,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ],
        ),
        children: [
          // Bakım Adımları
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bakım Adımları:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...template.lines.asMap().entries.map((entry) {
                  final index = entry.key;
                  final line = entry.value;
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: line.isRequired
                          ? Colors.red.shade100
                          : Colors.grey.shade200,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 10,
                          color: line.isRequired
                              ? Colors.red.shade700
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    title: Text(line.description),
                    subtitle: line.partName != null
                        ? Text(
                            'Parça: ${line.partName} (${line.partQuantity ?? 1} adet)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          )
                        : null,
                    trailing: line.isRequired
                        ? const Tooltip(
                            message: 'Zorunlu',
                            child: Icon(Icons.priority_high,
                                color: Colors.red, size: 16),
                          )
                        : null,
                  );
                }),
              ],
            ),
          ),
          // Butonlar
          OverflowBar(
            children: [
              TextButton.icon(
                onPressed: () => _showAddEditTemplateDialog(template: template),
                icon: const Icon(Icons.edit),
                label: const Text('Düzenle'),
              ),
              TextButton.icon(
                onPressed: () => _toggleTemplateStatus(template, provider),
                icon: Icon(template.isActive ? Icons.pause : Icons.play_arrow),
                label: Text(template.isActive ? 'Pasif Yap' : 'Aktif Yap'),
                style: TextButton.styleFrom(
                  foregroundColor:
                      template.isActive ? Colors.orange : Colors.green,
                ),
              ),
              TextButton.icon(
                onPressed: () => _deleteTemplate(template, provider),
                icon: const Icon(Icons.delete),
                label: const Text('Sil'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddEditTemplateDialog({MaintenanceTemplateV2? template}) {
    final isEditing = template != null;

    showDialog(
      context: context,
      builder: (ctx) => _TemplateEditDialog(
        template: template,
        onSave: (newTemplate) async {
          final provider =
              Provider.of<MaintenanceTemplateV2Provider>(context, listen: false);

          if (isEditing && template.key != null) {
            await provider.updateTemplate(template.key!, newTemplate);
          } else {
            await provider.addTemplate(newTemplate);
          }

          if (mounted) {
            Navigator.of(ctx).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    isEditing ? 'Şablon güncellendi!' : 'Yeni şablon oluşturuldu!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }

  void _toggleTemplateStatus(
    MaintenanceTemplateV2 template,
    MaintenanceTemplateV2Provider provider,
  ) {
    if (template.key == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(template.isActive ? 'Şablonu Pasif Yap' : 'Şablonu Aktif Yap'),
        content: Text(
          template.isActive
              ? '"${template.name}" şablonunu pasif yapmak istiyor musunuz? Pasif şablonlar bakım formlarında gösterilmeyecek.'
              : '"${template.name}" şablonunu aktif yapmak istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              await provider.toggleTemplateStatus(
                template.key!,
                !template.isActive,
              );
              if (mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      template.isActive
                          ? 'Şablon pasif yapıldı'
                          : 'Şablon aktif yapıldı',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
  }

  void _deleteTemplate(
    MaintenanceTemplateV2 template,
    MaintenanceTemplateV2Provider provider,
  ) {
    if (template.key == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Şablonu Sil'),
        content: Text('"${template.name}" şablonunu silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              await provider.deleteTemplate(template.key!);
              if (mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Şablon silindi'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}

/// Şablon Düzenleme Dialogu
class _TemplateEditDialog extends StatefulWidget {
  final MaintenanceTemplateV2? template;
  final Function(MaintenanceTemplateV2) onSave;

  const _TemplateEditDialog({
    this.template,
    required this.onSave,
  });

  @override
  State<_TemplateEditDialog> createState() => _TemplateEditDialogState();
}

class _TemplateEditDialogState extends State<_TemplateEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();

  MaintenancePeriodType _periodType = MaintenancePeriodType.monthly;
  int? _customPeriodDays;
  final List<MaintenanceTemplateLine> _lines = [];

  @override
  void initState() {
    super.initState();
    if (widget.template != null) {
      _nameController.text = widget.template!.name;
      _descriptionController.text = widget.template!.description ?? '';
      _brandController.text = widget.template!.deviceBrand ?? '';
      _modelController.text = widget.template!.deviceModel ?? '';
      _periodType = widget.template!.periodType;
      _customPeriodDays = widget.template!.customPeriodDays;
      _lines.addAll(widget.template!.lines);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  void _addLine() {
    showDialog(
      context: context,
      builder: (ctx) => _AddLineDialog(
        onAdd: (line) {
          setState(() => _lines.add(line));
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  void _editLine(int index) {
    showDialog(
      context: context,
      builder: (ctx) => _AddLineDialog(
        line: _lines[index],
        onAdd: (line) {
          setState(() => _lines[index] = line);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  void _removeLine(int index) {
    setState(() => _lines.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.template == null ? 'Yeni Bakım Şablonu' : 'Şablonu Düzenle'),
      content: SizedBox(
        width: 600,
        height: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Temel Bilgiler
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Şablon Adı *',
                    hintText: 'Örn: Chemtry C8000 Aylık Bakım',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Şablon adı zorunludur' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // Cihaz Bilgileri
                const Text(
                  'Cihaz Bilgileri',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _brandController,
                        decoration: const InputDecoration(
                          labelText: 'Marka',
                          hintText: 'Örn: Chemtry',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _modelController,
                        decoration: const InputDecoration(
                          labelText: 'Model',
                          hintText: 'Örn: C8000',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Periyot Seçimi
                const Text(
                  'Bakım Periyodu',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<MaintenancePeriodType>(
                  initialValue: _periodType,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: MaintenancePeriodType.values.map((type) {
                    String label;
                    switch (type) {
                      case MaintenancePeriodType.weekly:
                        label = 'Haftalık';
                        break;
                      case MaintenancePeriodType.monthly:
                        label = 'Aylık';
                        break;
                      case MaintenancePeriodType.quarterly:
                        label = '3 Aylık';
                        break;
                      case MaintenancePeriodType.biannual:
                        label = '6 Aylık';
                        break;
                      case MaintenancePeriodType.annual:
                        label = 'Yıllık';
                        break;
                      case MaintenancePeriodType.biennial:
                        label = '2 Yıllık';
                        break;
                      case MaintenancePeriodType.custom:
                        label = 'Özel (Gün olarak)';
                        break;
                    }
                    return DropdownMenuItem(
                      value: type,
                      child: Text(label),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _periodType = value!);
                  },
                ),
                if (_periodType == MaintenancePeriodType.custom) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: _customPeriodDays?.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Gün Sayısı',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      _customPeriodDays = int.tryParse(v);
                    },
                  ),
                ],
                const SizedBox(height: 16),

                // Bakım Adımları
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Bakım Adımları',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ElevatedButton.icon(
                      onPressed: _addLine,
                      icon: const Icon(Icons.add),
                      label: const Text('Adım Ekle'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_lines.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text('Henüz bakım adımı eklenmemiş'),
                    ),
                  )
                else
                  ..._lines.asMap().entries.map((entry) {
                    final index = entry.key;
                    final line = entry.value;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text('${index + 1}'),
                        ),
                        title: Text(line.description),
                        subtitle: line.partName != null
                            ? Text('Parça: ${line.partName}')
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (line.isRequired)
                              const Tooltip(
                                message: 'Zorunlu',
                                child: Icon(Icons.priority_high, color: Colors.red),
                              ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editLine(index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeLine(index),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate() && _lines.isNotEmpty) {
              final template = MaintenanceTemplateV2(
                name: _nameController.text,
                description: _descriptionController.text.isEmpty
                    ? null
                    : _descriptionController.text,
                deviceBrand: _brandController.text.isEmpty
                    ? null
                    : _brandController.text,
                deviceModel: _modelController.text.isEmpty
                    ? null
                    : _modelController.text,
                periodType: _periodType,
                customPeriodDays: _periodType == MaintenancePeriodType.custom
                    ? _customPeriodDays
                    : null,
                lines: List.from(_lines),
                isActive: true,
              );
              widget.onSave(template);
            } else if (_lines.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('En az bir bakım adımı eklemelisiniz!'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}

/// Bakım Adımı Ekleme/Düzenleme Dialogu
class _AddLineDialog extends StatefulWidget {
  final MaintenanceTemplateLine? line;
  final Function(MaintenanceTemplateLine) onAdd;

  const _AddLineDialog({
    this.line,
    required this.onAdd,
  });

  @override
  State<_AddLineDialog> createState() => _AddLineDialogState();
}

class _AddLineDialogState extends State<_AddLineDialog> {
  final _descController = TextEditingController();
  final _partNameController = TextEditingController();
  final _partQtyController = TextEditingController(text: '1');
  final _refController = TextEditingController();
  bool _isRequired = true;

  @override
  void initState() {
    super.initState();
    if (widget.line != null) {
      _descController.text = widget.line!.description;
      _isRequired = widget.line!.isRequired;
      _partNameController.text = widget.line!.partName ?? '';
      _partQtyController.text = (widget.line!.partQuantity ?? 1).toString();
      _refController.text = widget.line!.stockReferenceNo ?? '';
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _partNameController.dispose();
    _partQtyController.dispose();
    _refController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.line == null ? 'Bakım Adımı Ekle' : 'Bakım Adımını Düzenle'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Açıklama *',
                  hintText: 'Örn: Filtre temizliği',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Zorunlu Adım'),
                value: _isRequired,
                onChanged: (v) => setState(() => _isRequired = v),
              ),
              const Divider(),
              const Text(
                'Kullanılacak Parça (Opsiyonel)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _partNameController,
                decoration: const InputDecoration(
                  labelText: 'Parça Adı',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _partQtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Miktar',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _refController,
                decoration: const InputDecoration(
                  labelText: 'Stok Referans No',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_descController.text.trim().isNotEmpty) {
              final line = MaintenanceTemplateLine(
                description: _descController.text.trim(),
                isRequired: _isRequired,
                partName: _partNameController.text.trim().isEmpty
                    ? null
                    : _partNameController.text.trim(),
                partQuantity: int.tryParse(_partQtyController.text) ?? 1,
                stockReferenceNo: _refController.text.trim().isEmpty
                    ? null
                    : _refController.text.trim(),
              );
              widget.onAdd(line);
            }
          },
          child: Text(widget.line == null ? 'Ekle' : 'Güncelle'),
        ),
      ],
    );
  }
}
