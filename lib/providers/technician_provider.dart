import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/technician.dart';

class TechnicianProvider extends ChangeNotifier {
  static const String _boxName = 'technicians';

  Box<Technician>? _technicianBox;
  StreamSubscription<BoxEvent>? _technicianSubscription;
  Technician? _currentTechnician;
  List<Technician> _technicians = [];

  Technician? get currentTechnician => _currentTechnician;
  List<Technician> get technicians => List.unmodifiable(_technicians);
  bool get hasTechnician => _technicians.isNotEmpty;
  Box<Technician>? get technicianBox => _technicianBox;

  Future<void> init() async {
    if (Hive.isBoxOpen(_boxName)) {
      _technicianBox = Hive.box<Technician>(_boxName);
    } else {
      await _waitForBoxOpen(maxWait: const Duration(seconds: 3));
    }

    _refreshFromBox(notify: false);
    await _technicianSubscription?.cancel();
    _technicianSubscription =
        _technicianBox?.watch().listen((_) => _refreshFromBox());
    notifyListeners();
  }

  Future<void> _waitForBoxOpen({required Duration maxWait}) async {
    const checkInterval = Duration(milliseconds: 100);
    var elapsed = Duration.zero;
    while (elapsed < maxWait) {
      if (Hive.isBoxOpen(_boxName)) {
        _technicianBox = Hive.box<Technician>(_boxName);
        return;
      }
      await Future<void>.delayed(checkInterval);
      elapsed += checkInterval;
    }
    throw TimeoutException(
      'Teknisyen veritabani ${maxWait.inSeconds} saniyede acilamadi.',
    );
  }

  Future<Box<Technician>> _ensureBox() async {
    final existing = _technicianBox;
    if (existing != null && existing.isOpen) return existing;
    _technicianBox = Hive.isBoxOpen(_boxName)
        ? Hive.box<Technician>(_boxName)
        : await Hive.openBox<Technician>(_boxName);
    await _technicianSubscription?.cancel();
    _technicianSubscription =
        _technicianBox!.watch().listen((_) => _refreshFromBox());
    return _technicianBox!;
  }

  Future<void> addTechnician(Technician technician) async {
    final box = await _ensureBox();
    await box.add(technician);
    _refreshFromBox();
  }

  Future<void> updateTechnician(int index, Technician technician) async {
    final box = await _ensureBox();
    if (index < 0 || index >= box.length) {
      throw RangeError.index(index, box.values, 'index');
    }
    await box.putAt(index, technician);
    _refreshFromBox();
  }

  Future<void> deleteTechnician(int index) async {
    final box = await _ensureBox();
    if (index < 0 || index >= _technicians.length) {
      throw RangeError.index(index, _technicians, 'index');
    }
    final technician = _technicians[index];
    final deletingCurrent = technician.key == _currentTechnician?.key;
    await box.delete(technician.key);
    if (deletingCurrent) _currentTechnician = null;
    _refreshFromBox();
  }

  Future<void> setCurrentTechnician(Technician technician) async {
    _currentTechnician = technician;
    notifyListeners();
  }

  Technician? getTechnicianByKey(int key) {
    for (final technician in _technicians) {
      if (technician.key == key) return technician;
    }
    return null;
  }

  void _refreshFromBox({bool notify = true}) {
    final currentKey = _currentTechnician?.key;
    _technicians = _technicianBox?.values.toList() ?? [];
    _currentTechnician =
        currentKey == null ? null : getTechnicianByKey(currentKey);
    _currentTechnician ??= _technicians.isNotEmpty ? _technicians.first : null;
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    _technicianSubscription?.cancel();
    super.dispose();
  }
}
