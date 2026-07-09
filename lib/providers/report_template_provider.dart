import 'package:biomed_serv/models/report_template.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class ReportTemplateProvider with ChangeNotifier {
  final DatabaseService _dbService;
  late Box<ReportTemplate> _templateBox;

  List<ReportTemplate> _templates = [];
  List<ReportTemplate> get templates => _templates;

  // Aktif şablonlar
  List<ReportTemplate> get activeTemplates =>
      _templates.where((t) => t.isActive).toList();

  // Servis raporu şablonları
  List<ReportTemplate> get serviceTemplates =>
      _templates.where((t) => _isServiceTemplate(t)).toList();

  // Bakım raporu şablonları
  List<ReportTemplate> get maintenanceTemplates =>
      _templates.where((t) => _isMaintenanceTemplate(t)).toList();

  // Varsayılan servis şablonu
  ReportTemplate? get defaultServiceTemplate {
    return _templates.firstWhere(
      (t) => t.isDefault && _isServiceTemplate(t),
      orElse: () => ReportTemplate.defaultServiceTemplate(),
    );
  }

  // Varsayılan bakım şablonu
  ReportTemplate? get defaultMaintenanceTemplate {
    return _templates.firstWhere(
      (t) => t.isDefault && _isMaintenanceTemplate(t),
      orElse: () => ReportTemplate.defaultMaintenanceTemplate(),
    );
  }

  ReportTemplateProvider(this._dbService) {
    _templateBox = _dbService.reportTemplatesBox;
    _loadTemplates();
  }

  void _loadTemplates() {
    _templates = _templateBox.values.toList();
    notifyListeners();
  }

  /// Yeni şablon ekle
  Future<void> addTemplate(ReportTemplate template) async {
    await _templateBox.add(template);
    _loadTemplates();
  }

  /// Şablon güncelle
  Future<void> updateTemplate(int key, ReportTemplate template) async {
    template.updatedAt = DateTime.now();
    await _templateBox.put(key, template);
    _loadTemplates();
  }

  /// Şablon sil
  Future<void> deleteTemplate(int key) async {
    await _templateBox.delete(key);
    _loadTemplates();
  }

  /// Varsayılan şablonu değiştir
  Future<void> setDefaultTemplate(int key) async {
    final template = _templateBox.get(key);
    if (template == null) return;

    // Aynı tipteki diğer varsayılanları kaldır
    final isService = _isServiceTemplate(template);
    
    for (var t in _templates) {
      if (t.key != key && 
          t.isDefault && 
          _isServiceTemplate(t) == isService) {
        t.isDefault = false;
        await _templateBox.put(t.key!, t);
      }
    }

    // Yeni varsayılanı ayarla
    template.isDefault = true;
    await _templateBox.put(key, template);
    _loadTemplates();
  }

  /// Aktif/Pasif durumunu değiştir
  Future<void> toggleTemplateStatus(int key) async {
    final template = _templateBox.get(key);
    if (template != null) {
      template.isActive = !template.isActive;
      template.updatedAt = DateTime.now();
      await _templateBox.put(key, template);
      _loadTemplates();
    }
  }

  /// Şablonu kopyala (duplicate)
  Future<void> duplicateTemplate(int key) async {
    final original = _templateBox.get(key);
    if (original == null) return;

    final copy = ReportTemplate(
      name: '${original.name} (Kopya)',
      description: original.description,
      sections: original.sections.map((s) => ReportSection(
        type: s.type,
        isVisible: s.isVisible,
        order: s.order,
        title: s.title,
        isRequired: s.isRequired,
      )).toList(),
      isDefault: false,
      style: ReportStyle(
        primaryColor: original.style.primaryColor,
        secondaryColor: original.style.secondaryColor,
        accentColor: original.style.accentColor,
        fontFamily: original.style.fontFamily,
        companyName: original.style.companyName,
        showLogo: original.style.showLogo,
        logoPath: original.style.logoPath,
      ),
    );

    await _templateBox.add(copy);
    _loadTemplates();
  }

  /// Demo veri ekle (ilk kurulum için)
  Future<void> addDefaultTemplates() async {
    if (_templates.isNotEmpty) return;

    final serviceTemplate = ReportTemplate.defaultServiceTemplate();
    final maintenanceTemplate = ReportTemplate.defaultMaintenanceTemplate();

    await _templateBox.add(serviceTemplate);
    await _templateBox.add(maintenanceTemplate);
    _loadTemplates();
  }

  /// Servis şablonu mu kontrol et
  bool _isServiceTemplate(ReportTemplate template) {
    // ProblemDetails bölümü varsa servis şablonudur
    return template.sections.any((s) => 
        s.type == ReportSectionType.problemDetails && s.isVisible);
  }

  /// Bakım şablonu mu kontrol et
  bool _isMaintenanceTemplate(ReportTemplate template) {
    // MaintenancePeriod bölümü varsa bakım şablonudur
    return template.sections.any((s) => 
        s.type == ReportSectionType.maintenancePeriod && s.isVisible);
  }
}
