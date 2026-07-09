import 'package:biomed_serv/models/maintenance_template.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class MaintenanceTemplateProvider with ChangeNotifier {
  final DatabaseService _dbService;
  late Box<MaintenanceTemplate> _templateBox;

  List<MaintenanceTemplate> _templates = [];
  List<MaintenanceTemplate> get templates => _templates;

  MaintenanceTemplateProvider(this._dbService) {
    _templateBox = _dbService.maintenanceTemplatesBox;
    _loadTemplates();
  }

  void _loadTemplates() {
    _templates = _templateBox.values.toList();
    notifyListeners();
  }

  Future<void> addTemplate(MaintenanceTemplate template) async {
    await _templateBox.add(template);
    _loadTemplates();
  }

  Future<void> deleteTemplate(int key) async {
    await _templateBox.delete(key);
    _loadTemplates();
  }
}
