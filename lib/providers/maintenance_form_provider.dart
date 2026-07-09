import 'dart:async';

import 'package:biomed_serv/models/maintenance_form.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class MaintenanceFormProvider with ChangeNotifier {
  final DatabaseService _dbService;
  late Box<MaintenanceForm> _formBox;
  StreamSubscription<BoxEvent>? _formSubscription;

  List<MaintenanceForm> _forms = [];
  List<MaintenanceForm> get forms => _forms;

  MaintenanceFormProvider(this._dbService) {
    _formBox = _dbService.maintenanceFormsBox;
    _formSubscription = _formBox.watch().listen((_) => _loadForms());
    _loadForms();
  }

  void _loadForms() {
    _forms = _formBox.values.toList();
    notifyListeners();
  }

  Future<void> addForm(MaintenanceForm form) async {
    await _formBox.add(form);
    _loadForms();
  }

  Future<void> updateForm(MaintenanceForm form) async {
    await form.save();
    _loadForms();
  }

  Future<void> deleteForm(int key) async {
    await _formBox.delete(key);
    _loadForms();
  }

  @override
  void dispose() {
    _formSubscription?.cancel();
    super.dispose();
  }
}
