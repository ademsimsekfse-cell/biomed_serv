import 'dart:async';

import 'package:biomed_serv/models/service_form.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class ServiceFormProvider with ChangeNotifier {
  final DatabaseService _dbService;
  late Box<ServiceForm> _formBox;
  StreamSubscription<BoxEvent>? _formSubscription;

  List<ServiceForm> _forms = [];
  List<ServiceForm> get forms => _forms;

  ServiceFormProvider(this._dbService) {
    _formBox = _dbService.serviceFormsBox;
    _formSubscription = _formBox.watch().listen((_) => _loadForms());
    _loadForms();
  }

  void _loadForms() {
    _forms = _formBox.values.toList();
    notifyListeners();
  }

  Future<void> addForm(ServiceForm form) async {
    await _formBox.add(form);
    _loadForms();
  }

  Future<void> updateForm(ServiceForm form) async {
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
