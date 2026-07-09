import 'package:biomed_serv/models/report_template.dart';
import 'package:biomed_serv/providers/company_provider.dart';
import 'package:biomed_serv/providers/report_template_provider.dart';
import 'package:biomed_serv/providers/technician_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';

/// Rapor Tasarım Yönetim Ekranı
/// Kullanıcının gönderdiği tasarıma göre rapor şablonlarını yönetme
class ReportTemplateManagementScreen extends StatelessWidget {
  const ReportTemplateManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rapor Tasarım Yönetimi'),
            Text(
              'Firma, Teknisyen ve Görünüm şeklini ayarlayın',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.preview),
            onPressed: () => _showGlobalPreview(context),
            tooltip: 'Genel Önizleme',
          ),
        ],
      ),
      body: Consumer<ReportTemplateProvider>(
        builder: (context, provider, child) {
          if (provider.templates.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.description_outlined,
                      size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz rapor şablonu bulunmuyor.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await provider.addDefaultTemplates();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Varsayılan şablonlar eklendi!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Varsayılan Şablonları Ekle'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.templates.length,
            itemBuilder: (context, index) {
              final template = provider.templates[index];
              return _buildTemplateCard(context, template, provider);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTemplateDialog(context),
        tooltip: 'Yeni Rapor Şablonu',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTemplateCard(
    BuildContext context,
    ReportTemplate template,
    ReportTemplateProvider provider,
  ) {
    final isService = template.sections.any(
        (s) => s.type == ReportSectionType.problemDetails && s.isVisible);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: template.isDefault ? 4 : 2,
      shape: template.isDefault
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.green, width: 2),
            )
          : null,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isService ? Colors.blue.shade100 : Colors.green.shade100,
          child: Icon(
            isService ? Icons.build : Icons.handyman,
            color: isService ? Colors.blue.shade700 : Colors.green.shade700,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                template.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (template.isDefault)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Varsayılan',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${template.visibleSections.length} bölüm görünür',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            Text(
              'Renk: #${template.style.primaryColor.toRadixString(16).substring(2).toUpperCase()}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
        children: [
          // Önizleme
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Görünür Bölümler:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: template.visibleSections.map((section) {
                    return Chip(
                      label: Text(
                        template.getSectionTitle(section.type),
                        style: const TextStyle(fontSize: 11),
                      ),
                      backgroundColor: Colors.blue.shade50,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          // Butonlar
          OverflowBar(
            children: [
              TextButton.icon(
                onPressed: () => _showEditTemplateDialog(context, template),
                icon: const Icon(Icons.edit),
                label: const Text('Düzenle'),
              ),
              TextButton.icon(
                onPressed: () => _showPreviewDialog(context, template),
                icon: const Icon(Icons.preview),
                label: const Text('Önizle'),
              ),
              if (!template.isDefault)
                TextButton.icon(
                  onPressed: () => _setDefaultTemplate(context, template, provider),
                  icon: const Icon(Icons.star),
                  label: const Text('Varsayılan Yap'),
                  style: TextButton.styleFrom(foregroundColor: Colors.orange),
                ),
              TextButton.icon(
                onPressed: () => _duplicateTemplate(context, template, provider),
                icon: const Icon(Icons.copy),
                label: const Text('Kopyala'),
              ),
              TextButton.icon(
                onPressed: () => _deleteTemplate(context, template, provider),
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

  void _showAddTemplateDialog(BuildContext context) {
    _showEditTemplateDialog(context, null);
  }

  void _showEditTemplateDialog(BuildContext context, ReportTemplate? template) {
    final isEditing = template != null;
    
    showDialog(
      context: context,
      builder: (ctx) => _TemplateEditDialog(
        template: template,
        onSave: (newTemplate) async {
          final provider = Provider.of<ReportTemplateProvider>(context, listen: false);
          
          if (isEditing && template.key != null) {
            await provider.updateTemplate(template.key!, newTemplate);
          } else {
            await provider.addTemplate(newTemplate);
          }

          Navigator.of(ctx).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEditing ? 'Şablon güncellendi!' : 'Yeni şablon oluşturuldu!'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  void _setDefaultTemplate(
    BuildContext context,
    ReportTemplate template,
    ReportTemplateProvider provider,
  ) {
    if (template.key == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Varsayılan Şablon Yap'),
        content: Text('"${template.name}" şablonunu varsayılan yapmak istiyor musunuz? Bu tipteki diğer şablonlar varsayılan olmaktan çıkarılacak.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              await provider.setDefaultTemplate(template.key!);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Varsayılan şablon güncellendi'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
  }

  void _duplicateTemplate(
    BuildContext context,
    ReportTemplate template,
    ReportTemplateProvider provider,
  ) {
    if (template.key == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Şablonu Kopyala'),
        content: Text('"${template.name}" şablonunun bir kopyasını oluşturmak istiyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              await provider.duplicateTemplate(template.key!);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Şablon kopyalandı'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Kopyala'),
          ),
        ],
      ),
    );
  }

  void _deleteTemplate(
    BuildContext context,
    ReportTemplate template,
    ReportTemplateProvider provider,
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
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Şablon silindi'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _showPreviewDialog(BuildContext context, ReportTemplate template) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('"${template.name}" Önizleme'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Renk önizleme
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(template.style.primaryColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    template.style.companyName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Bölümler
                const Text(
                  'Görünecek Bölümler:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...template.visibleSections.map((section) => ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text(template.getSectionTitle(section.type)),
                  dense: true,
                )),
                const Divider(),
                // Gizli bölümler
                if (template.sections.any((s) => !s.isVisible)) ...[
                  const Text(
                    'Gizli Bölümler:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...template.sections
                      .where((s) => !s.isVisible)
                      .map((section) => ListTile(
                            leading: const Icon(Icons.cancel, color: Colors.grey),
                            title: Text(
                              template.getSectionTitle(section.type),
                              style: const TextStyle(color: Colors.grey),
                            ),
                            dense: true,
                          )),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  void _showGlobalPreview(BuildContext context) {
    final companyProvider = context.read<CompanyProvider>();
    final technicianProvider = context.read<TechnicianProvider>();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rapor Veri Kaynakları'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Firma Bilgileri Önizleme
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.business, color: Colors.indigo.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Firma Bilgileri',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade700,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    if (companyProvider.hasCompanyInfo) ...[
                      Text('Ad: ${companyProvider.companyInfo!.companyName}'),
                      if (companyProvider.companyInfo!.phone != null)
                        Text('Tel: ${companyProvider.companyInfo!.phone}'),
                      if (companyProvider.companyInfo!.email != null)
                        Text('E-posta: ${companyProvider.companyInfo!.email}'),
                      if (companyProvider.hasLogo)
                        Row(
                          children: [
                            const Icon(Icons.image, size: 16, color: Colors.green),
                            const SizedBox(width: 4),
                            Text(
                              'Logo yüklü (${companyProvider.companyInfo!.logoWidth?.toInt()}px)',
                              style: const TextStyle(color: Colors.green),
                            ),
                          ],
                        ),
                    ] else
                      Text(
                        'Firma bilgisi henüz girilmemiş!\nAyarlar > Firma Bilgileri menüsünden ekleyin.',
                        style: TextStyle(color: Colors.orange.shade700),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Teknisyen Bilgileri Önizleme
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Teknisyen Bilgileri',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    if (technicianProvider.hasTechnician) ...[
                      Text('Ad Soyad: ${technicianProvider.currentTechnician?.fullName ?? "-"}'),
                      if (technicianProvider.currentTechnician?.phone != null)
                        Text('Tel: ${technicianProvider.currentTechnician!.phone}'),
                      if (technicianProvider.currentTechnician?.email != null)
                        Text('E-posta: ${technicianProvider.currentTechnician!.email}'),
                      Text('Toplam: ${technicianProvider.technicians.length} teknisyen'),
                    ] else
                      Text(
                        'Teknisyen kaydı bulunmamaktadır!\nAyarlar > Teknisyen Yönetimi menüsünden ekleyin.',
                        style: TextStyle(color: Colors.orange.shade700),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }
}

/// Şablon Düzenleme Dialogu
class _TemplateEditDialog extends StatefulWidget {
  final ReportTemplate? template;
  final Function(ReportTemplate) onSave;

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
  final _companyController = TextEditingController();
  
  late List<ReportSection> _sections;
  late Color _primaryColor;
  late Color _accentColor;
  late ReportLayoutType _layoutType;
  late LogoPosition _logoPosition;
  late bool _showTechnician;
  late bool _showCompanyDetails;
  late bool _showLogo;

  @override
  void initState() {
    super.initState();
    if (widget.template != null) {
      _nameController.text = widget.template!.name;
      _companyController.text = widget.template!.style.companyName;
      _sections = widget.template!.sections.map((s) => ReportSection(
        type: s.type,
        isVisible: s.isVisible,
        order: s.order,
        title: s.title,
        isRequired: s.isRequired,
      )).toList();
      _primaryColor = Color(widget.template!.style.primaryColor);
      _accentColor = Color(widget.template!.style.accentColor);
      _layoutType = widget.template!.layoutType;
      _logoPosition = widget.template!.style.logoPosition;
      _showTechnician = widget.template!.style.showTechnician;
      _showCompanyDetails = widget.template!.style.showCompanyDetails;
      _showLogo = widget.template!.style.showLogo;
    } else {
      _sections = _getDefaultSections();
      _primaryColor = const Color(0xFF2C3E50);
      _accentColor = const Color(0xFF3498DB);
      _layoutType = ReportLayoutType.classic;
      _logoPosition = LogoPosition.top;
      _showTechnician = true;
      _showCompanyDetails = true;
      _showLogo = true;
    }
  }

  List<ReportSection> _getDefaultSections() {
    return [
      ReportSection(type: ReportSectionType.companyHeader, isVisible: true, order: 0),
      ReportSection(type: ReportSectionType.formNumber, isVisible: true, order: 1),
      ReportSection(type: ReportSectionType.customerDetail, isVisible: true, order: 2, title: 'Customer Detail'),
      ReportSection(type: ReportSectionType.deviceInfo, isVisible: true, order: 3, title: 'Device Info'),
      ReportSection(type: ReportSectionType.serviceTimes, isVisible: true, order: 4, title: 'Service Times'),
      ReportSection(type: ReportSectionType.problemDetails, isVisible: true, order: 5, title: 'Problem Details'),
      ReportSection(type: ReportSectionType.actionsTaken, isVisible: true, order: 6, title: 'Actions and Recommendations'),
      ReportSection(type: ReportSectionType.finalStatus, isVisible: true, order: 7, title: 'Final Status'),
      ReportSection(type: ReportSectionType.spareParts, isVisible: true, order: 8, title: 'Spare Parts'),
      ReportSection(type: ReportSectionType.signatures, isVisible: true, order: 9, title: 'Serviced By / Customer Approval'),
      ReportSection(type: ReportSectionType.technicianInfo, isVisible: true, order: 10, title: 'Technician Info'),
    ];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.template == null ? 'Yeni Rapor Şablonu' : 'Şablonu Düzenle'),
      content: SizedBox(
        width: 600,
        height: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Temel Bilgiler
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Şablon Adı *',
                    hintText: 'Örn: Standart Servis Raporu',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Şablon adı zorunludur' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _companyController,
                  decoration: const InputDecoration(
                    labelText: 'Şirket Adı',
                    hintText: 'Rapor başlığında görünecek',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Rapor Görünüm Şekli (Layout)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rapor Görünüm Şekli',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildLayoutChip(ReportLayoutType.classic, 'Klasik', Icons.description),
                          _buildLayoutChip(ReportLayoutType.modern, 'Modern', Icons.auto_awesome),
                          _buildLayoutChip(ReportLayoutType.minimal, 'Minimal', Icons.minimize),
                          _buildLayoutChip(ReportLayoutType.professional, 'Profesyonel', Icons.business),
                          _buildLayoutChip(ReportLayoutType.compact, 'Kompakt', Icons.compress),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Logo Pozisyonu',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildLogoPositionChip(LogoPosition.top, 'Üst'),
                          _buildLogoPositionChip(LogoPosition.left, 'Sol'),
                          _buildLogoPositionChip(LogoPosition.right, 'Sağ'),
                          _buildLogoPositionChip(LogoPosition.center, 'Orta'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Göster/Gizle seçenekleri
                      Row(
                        children: [
                          Expanded(
                            child: _buildToggleChip(
                              'Firma Detayları',
                              _showCompanyDetails,
                              (v) => setState(() => _showCompanyDetails = v),
                              Icons.business,
                            ),
                          ),
                          Expanded(
                            child: _buildToggleChip(
                              'Teknisyen',
                              _showTechnician,
                              (v) => setState(() => _showTechnician = v),
                              Icons.person,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildToggleChip(
                        'Logo Göster',
                        _showLogo,
                        (v) => setState(() => _showLogo = v),
                        Icons.image,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Renk Seçimi
                const Text(
                  'Renk Şeması',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildColorPicker(
                        'Ana Renk',
                        _primaryColor,
                        (color) => setState(() => _primaryColor = color),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildColorPicker(
                        'Vurgu Rengi',
                        _accentColor,
                        (color) => setState(() => _accentColor = color),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Bölümler
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Görünecek Bölümler',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          for (var s in _sections) {
                            s.isVisible = true;
                          }
                        });
                      },
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Tümünü Seç'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._sections.asMap().entries.map((entry) {
                  final index = entry.key;
                  final section = entry.value;
                  return _buildSectionTile(section, index);
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
            if (_formKey.currentState!.validate()) {
              // En az bir bölüm seçili mi kontrol et
              if (!_sections.any((s) => s.isVisible)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('En azından bir bölüm seçilmelidir!'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final template = ReportTemplate(
                name: _nameController.text,
                sections: _sections,
                isDefault: widget.template?.isDefault ?? false,
                layoutType: _layoutType,
                style: ReportStyle(
                  primaryColor: _primaryColor.value,
                  accentColor: _accentColor.value,
                  companyName: _companyController.text.isEmpty
                      ? 'COMPANY NAME'
                      : _companyController.text,
                  logoPosition: _logoPosition,
                  showTechnician: _showTechnician,
                  showCompanyDetails: _showCompanyDetails,
                  showLogo: _showLogo,
                ),
              );
              widget.onSave(template);
            }
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }

  Widget _buildColorPicker(String label, Color color, Function(Color) onColorChanged) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('$label Seç'),
            content: SingleChildScrollView(
              child: ColorPicker(
                pickerColor: color,
                onColorChanged: onColorChanged,
                pickerAreaHeightPercent: 0.8,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Tamam'),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget _buildLayoutChip(ReportLayoutType type, String label, IconData icon) {
    final isSelected = _layoutType == type;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: ChoiceChip(
        selected: isSelected,
        onSelected: (selected) {
          if (selected) setState(() => _layoutType = type);
        },
        avatar: Icon(icon, size: 18, color: isSelected ? const Color(0xFF1565C0) : Colors.grey.shade600),
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF1565C0) : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selectedColor: const Color(0xFFE3F2FD),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? const Color(0xFF64B5F6) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        elevation: isSelected ? 3 : 1,
        shadowColor: isSelected ? const Color(0xFF64B5F6).withOpacity(0.3) : Colors.grey.withOpacity(0.2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
    );
  }

  Widget _buildLogoPositionChip(LogoPosition position, String label) {
    final isSelected = _logoPosition == position;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: ChoiceChip(
        selected: isSelected,
        onSelected: (selected) {
          if (selected) setState(() => _logoPosition = position);
        },
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF1565C0) : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
        selectedColor: const Color(0xFFE3F2FD),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? const Color(0xFF64B5F6) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        elevation: isSelected ? 3 : 1,
        shadowColor: isSelected ? const Color(0xFF64B5F6).withOpacity(0.3) : Colors.grey.withOpacity(0.2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
    );
  }

  Widget _buildToggleChip(String label, bool value, Function(bool) onChanged, IconData icon) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: value ? const Color(0xFFE3F2FD) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value ? const Color(0xFF64B5F6) : Colors.grey.shade300,
            width: value ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: value ? const Color(0xFF64B5F6).withOpacity(0.2) : Colors.grey.withOpacity(0.1),
              blurRadius: value ? 4 : 2,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: value ? const Color(0xFF1565C0) : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: value ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
                color: value ? const Color(0xFF1565C0) : Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              value ? Icons.check_circle : Icons.circle_outlined,
              size: 16,
              color: value ? Colors.green : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTile(ReportSection section, int index) {
    final defaultTitle = _getDefaultTitle(section.type);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Checkbox(
          value: section.isVisible,
          onChanged: (v) {
            setState(() => section.isVisible = v ?? false);
          },
        ),
        title: Text(
          section.title ?? defaultTitle,
          style: TextStyle(
            fontWeight: section.isVisible ? FontWeight.bold : FontWeight.normal,
            color: section.isVisible ? Colors.black : Colors.grey,
          ),
        ),
        subtitle: Text(
          defaultTitle,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Yukarı taşı
            IconButton(
              icon: const Icon(Icons.arrow_upward, size: 20),
              onPressed: index > 0
                  ? () {
                      setState(() {
                        final temp = _sections[index];
                        _sections[index] = _sections[index - 1];
                        _sections[index - 1] = temp;
                        // Sıra numaralarını güncelle
                        for (int i = 0; i < _sections.length; i++) {
                          _sections[i].order = i;
                        }
                      });
                    }
                  : null,
            ),
            // Aşağı taşı
            IconButton(
              icon: const Icon(Icons.arrow_downward, size: 20),
              onPressed: index < _sections.length - 1
                  ? () {
                      setState(() {
                        final temp = _sections[index];
                        _sections[index] = _sections[index + 1];
                        _sections[index + 1] = temp;
                        // Sıra numaralarını güncelle
                        for (int i = 0; i < _sections.length; i++) {
                          _sections[i].order = i;
                        }
                      });
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  String _getDefaultTitle(ReportSectionType type) {
    switch (type) {
      case ReportSectionType.companyHeader:
        return 'Şirket Bilgileri';
      case ReportSectionType.formNumber:
        return 'Form Numarası';
      case ReportSectionType.customerDetail:
        return 'Müşteri Detayı';
      case ReportSectionType.deviceInfo:
        return 'Cihaz Bilgileri';
      case ReportSectionType.serviceTimes:
        return 'Servis Zamanları';
      case ReportSectionType.problemDetails:
        return 'Problem Detayları';
      case ReportSectionType.actionsTaken:
        return 'Yapılan İşlemler';
      case ReportSectionType.finalStatus:
        return 'Final Durum';
      case ReportSectionType.spareParts:
        return 'Kullanılan Parçalar';
      case ReportSectionType.signatures:
        return 'İmzalar';
      case ReportSectionType.maintenancePeriod:
        return 'Bakım Periyodu';
      case ReportSectionType.notes:
        return 'Notlar ve Öneriler';
      case ReportSectionType.technicianInfo:
        return 'Teknisyen Bilgileri';
    }
  }
}
