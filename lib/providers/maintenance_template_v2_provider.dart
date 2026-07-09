import 'package:biomed_serv/models/maintenance_template_v2.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class MaintenanceTemplateV2Provider with ChangeNotifier {
  final DatabaseService _dbService;
  late Box<MaintenanceTemplateV2> _templateBox;

  List<MaintenanceTemplateV2> _templates = [];
  List<MaintenanceTemplateV2> get templates => _templates;

  // Aktif şablonlar (isActive = true)
  List<MaintenanceTemplateV2> get activeTemplates =>
      _templates.where((t) => t.isActive).toList();

  // Cihaz modeline göre filtreleme
  List<MaintenanceTemplateV2> getTemplatesByDeviceModel(String model) {
    return _templates
        .where((t) => t.deviceModel?.toLowerCase() == model.toLowerCase())
        .toList();
  }

  // Cihaz markasına göre filtreleme
  List<MaintenanceTemplateV2> getTemplatesByDeviceBrand(String brand) {
    return _templates
        .where((t) => t.deviceBrand?.toLowerCase() == brand.toLowerCase())
        .toList();
  }

  // Benzersiz cihaz modelleri listesi
  List<String> get uniqueDeviceModels {
    final models = _templates
        .where((t) => t.deviceModel != null && t.deviceModel!.isNotEmpty)
        .map((t) => t.deviceModel!)
        .toSet()
        .toList();
    models.sort();
    return models;
  }

  // Benzersiz cihaz markaları listesi
  List<String> get uniqueDeviceBrands {
    final brands = _templates
        .where((t) => t.deviceBrand != null && t.deviceBrand!.isNotEmpty)
        .map((t) => t.deviceBrand!)
        .toSet()
        .toList();
    brands.sort();
    return brands;
  }

  MaintenanceTemplateV2Provider(this._dbService) {
    _templateBox = _dbService.maintenanceTemplatesV2Box;
    _loadTemplates();
  }

  void _loadTemplates() {
    _templates = _templateBox.values.toList();
    notifyListeners();
  }

  /// Yeni şablon ekle
  Future<void> addTemplate(MaintenanceTemplateV2 template) async {
    await _templateBox.add(template);
    _loadTemplates();
  }

  /// Şablon güncelle
  Future<void> updateTemplate(int key, MaintenanceTemplateV2 template) async {
    template.updatedAt = DateTime.now();
    await _templateBox.put(key, template);
    _loadTemplates();
  }

  /// Şablon sil (veya pasif yap)
  Future<void> deleteTemplate(int key) async {
    await _templateBox.delete(key);
    _loadTemplates();
  }

  /// Şablonu pasif/aktif yap
  Future<void> toggleTemplateStatus(int key, bool isActive) async {
    final template = _templateBox.get(key);
    if (template != null) {
      template.isActive = isActive;
      template.updatedAt = DateTime.now();
      await _templateBox.put(key, template);
      _loadTemplates();
    }
  }

  /// Demo veri ekle (örnek Chemtry C8000 şablonu)
  Future<void> addDemoData() async {
    if (_templates.isNotEmpty) return; // Zaten veri var

    // Chemtry C8000 için aylık bakım şablonu
    final chemtryMonthly = MaintenanceTemplateV2(
      name: 'Chemtry C8000 Aylık Bakım',
      description: 'Chemtry C8000 analizörü için aylık periyodik bakım şablonu',
      deviceBrand: 'Chemtry',
      deviceModel: 'C8000',
      periodType: MaintenancePeriodType.monthly,
      lines: [
        MaintenanceTemplateLine(
          description: 'Filtre kontrolü ve temizliği',
          isRequired: true,
        ),
        MaintenanceTemplateLine(
          description: 'Optik sensör temizliği',
          isRequired: true,
        ),
        MaintenanceTemplateLine(
          description: 'Kalibrasyon kontrolü',
          isRequired: true,
        ),
        MaintenanceTemplateLine(
          description: 'Reaktif seviye kontrolü',
          isRequired: true,
          partName: 'Reaktif C8000-R1',
          partQuantity: 1,
        ),
        MaintenanceTemplateLine(
          description: 'Yıkama solüsyonu değişimi',
          isRequired: false,
          partName: 'Wash Solution',
          partQuantity: 2,
        ),
      ],
    );

    // Chemtry C8000 için 3 aylık bakım şablonu
    final chemtryQuarterly = MaintenanceTemplateV2(
      name: 'Chemtry C8000 3 Aylık Bakım',
      description: 'Chemtry C8000 analizörü için 3 aylık detaylı bakım şablonu',
      deviceBrand: 'Chemtry',
      deviceModel: 'C8000',
      periodType: MaintenancePeriodType.quarterly,
      lines: [
        MaintenanceTemplateLine(
          description: 'Tüm filtrelerin değişimi',
          isRequired: true,
          partName: 'Filtre Set C8000',
          partQuantity: 1,
        ),
        MaintenanceTemplateLine(
          description: 'Peristaltik pompa boru kontrolü',
          isRequired: true,
        ),
        MaintenanceTemplateLine(
          description: 'Işık kaynağı kontrolü ve kalibrasyon',
          isRequired: true,
        ),
        MaintenanceTemplateLine(
          description: 'Tam sistem kalibrasyonu',
          isRequired: true,
        ),
      ],
    );

    // Genel haftalık bakım şablonu
    final generalWeekly = MaintenanceTemplateV2(
      name: 'Genel Haftalık Bakım',
      description: 'Tüm laboratuvar cihazları için haftalık bakım kontrol listesi',
      periodType: MaintenancePeriodType.weekly,
      lines: [
        MaintenanceTemplateLine(
          description: 'Cihaz yüzey temizliği',
          isRequired: true,
        ),
        MaintenanceTemplateLine(
          description: 'Kağıt ve sarf malzeme kontrolü',
          isRequired: true,
        ),
        MaintenanceTemplateLine(
          description: 'Çalışma ortamı ısı/nem kontrolü',
          isRequired: false,
        ),
      ],
    );

    await _templateBox.add(chemtryMonthly);
    await _templateBox.add(chemtryQuarterly);
    await _templateBox.add(generalWeekly);
    _loadTemplates();
  }
}
