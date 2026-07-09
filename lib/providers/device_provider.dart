import 'dart:async';

import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/models/device_personel.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class DeviceProvider with ChangeNotifier {
  final DatabaseService _dbService;
  late Box<Device> _deviceBox;
  StreamSubscription<BoxEvent>? _deviceSubscription;

  List<Device> _devices = [];
  List<Device> get devices => _devices;

  DeviceProvider(this._dbService) {
    _deviceBox = _dbService.devicesBox;
    _deviceSubscription = _deviceBox.watch().listen((_) => _loadDevices());
    _loadDevices();
  }

  @override
  void dispose() {
    _deviceSubscription?.cancel();
    super.dispose();
  }

  void _loadDevices() {
    _devices = _deviceBox.values.toList();
    notifyListeners();
  }

  /// 📱 Cihaz ekle ve bildirim gönder
  Future<Device> addDevice(Device device) async {
    _validateDeviceForSave(device);
    final key = await _deviceBox.add(device);
    await _syncCustomerAcrossChain(key, device.customer);
    _loadDevices();
    return device;
  }

  /// Cihaz ekle ve key döndür (Modül ilişkisi için)
  Future<int?> addDeviceAndReturnKey(Device device) async {
    _validateDeviceForSave(device);
    final key = await _deviceBox.add(device);
    await _syncCustomerAcrossChain(key, device.customer);
    _loadDevices();
    return key;
  }

  Future<void> updateDevice(int key, Device device) async {
    _validateDeviceForSave(device, excludeKey: key);
    await _deviceBox.put(key, device);
    await _syncCustomerAcrossChain(key, device.customer);
    _loadDevices();
  }

  Device? deviceWithSerial(String serialNumber, {int? excludeKey}) {
    final target = _normalizeSerial(serialNumber);
    if (target.isEmpty) return null;

    for (final device in _deviceBox.values) {
      if (excludeKey != null && _asIntKey(device.key) == excludeKey) continue;
      if (_normalizeSerial(device.serialNumber) == target) return device;
    }
    return null;
  }

  bool isSerialNumberAvailable(String serialNumber, {int? excludeKey}) {
    return deviceWithSerial(serialNumber, excludeKey: excludeKey) == null;
  }

  void _validateDeviceForSave(Device device, {int? excludeKey}) {
    if (device.name.trim().isEmpty) {
      throw const DeviceValidationException('Cihaz adi zorunludur.');
    }
    if (device.serialNumber.trim().isEmpty) {
      throw const DeviceValidationException('Seri numarasi zorunludur.');
    }

    final existing = deviceWithSerial(
      device.serialNumber,
      excludeKey: excludeKey ?? _asIntKey(device.key),
    );
    if (existing != null) {
      throw DeviceValidationException(
        '"${device.serialNumber}" seri numarasi zaten "${existing.name}" cihazinda kayitli.',
      );
    }

    final responsible = device.responsiblePerson;
    final deviceCustomerKey = device.customer?.key;
    if (responsible != null && deviceCustomerKey == null) {
      throw const DeviceValidationException(
        'Sorumlu personel atamak icin once kurum secilmelidir.',
      );
    }
    if (responsible != null &&
        responsible.customer == null &&
        device.customer != null) {
      responsible.customer = device.customer;
    }
    final responsibleCustomerKey = responsible?.customer?.key;
    if (responsibleCustomerKey != null &&
        deviceCustomerKey != null &&
        responsibleCustomerKey != deviceCustomerKey) {
      throw const DeviceValidationException(
        'Sorumlu personel yalnizca bagli oldugu kurumun cihazina atanabilir.',
      );
    }
  }

  bool hasResponsiblePersonConflict({
    required DevicePersonel personel,
    required Device targetDevice,
    required dynamic targetCustomer,
  }) {
    final targetCustomerKey = targetCustomer?.key;
    if (targetCustomerKey == null) return false;

    for (final device in _deviceBox.values) {
      if (device.key == targetDevice.key) continue;
      final responsible = device.responsiblePerson;
      if (responsible == null) continue;

      final samePerson = _isSameResponsiblePerson(responsible, personel);
      if (!samePerson) continue;

      final existingCustomerKey = device.customer?.key;
      if (existingCustomerKey != null &&
          existingCustomerKey != targetCustomerKey) {
        return true;
      }
    }
    return false;
  }

  /// 🔗 ZİNCİRLEME CİHAZ ATAMA
  /// Bir cihaz (kontrol ünitesi veya modül) bir cariye atanırsa,
  /// bağlı tüm cihazlara da aynı cari otomatik atanır
  Future<void> assignCustomerToDeviceChain(
      int deviceKey, dynamic customer) async {
    await _syncCustomerAcrossChain(deviceKey, customer);
    _loadDevices();
  }

  Future<void> _syncCustomerAcrossChain(int deviceKey, dynamic customer) async {
    final device = _deviceBox.get(deviceKey);
    if (device == null) return;

    final chainKeys = _resolveChainKeys(deviceKey, device);
    for (final key in chainKeys) {
      final chainDevice = _deviceBox.get(key);
      if (chainDevice == null) continue;
      chainDevice.customer = customer;
      final responsibleCustomerKey =
          chainDevice.responsiblePerson?.customer?.key;
      final targetCustomerKey = customer?.key;
      if (chainDevice.responsiblePerson != null &&
          (targetCustomerKey == null ||
              (responsibleCustomerKey != null &&
                  responsibleCustomerKey != targetCustomerKey))) {
        chainDevice.responsiblePerson = null;
      }
      await _deviceBox.put(key, chainDevice);
    }
  }

  Set<int> _resolveChainKeys(int deviceKey, Device device) {
    if (device.isStandalone) {
      return {deviceKey};
    }

    final rootKey = device.isProcessingModule
        ? _asIntKey(device.controlModule?.key) ?? deviceKey
        : deviceKey;

    final keys = <int>{rootKey};
    for (final linkedDevice in _deviceBox.values) {
      final linkedKey = _asIntKey(linkedDevice.key);
      if (linkedKey == null) continue;
      if (linkedKey == rootKey) continue;
      if (linkedDevice.isProcessingModule &&
          _asIntKey(linkedDevice.controlModule?.key) == rootKey) {
        keys.add(linkedKey);
      }
    }
    return keys;
  }

  int? _asIntKey(dynamic key) => key is int ? key : null;

  String _normalizeSerial(String value) => value.trim().toUpperCase();

  bool _isSameResponsiblePerson(
    DevicePersonel first,
    DevicePersonel second,
  ) {
    if (first.key != null && second.key != null) {
      return first.key == second.key;
    }

    final firstPhone = _normalizePhone(first.phone);
    final secondPhone = _normalizePhone(second.phone);
    if (firstPhone.isNotEmpty &&
        secondPhone.isNotEmpty &&
        firstPhone == secondPhone) {
      return true;
    }

    final firstEmail = _normalizeText(first.email);
    final secondEmail = _normalizeText(second.email);
    if (firstEmail.isNotEmpty &&
        secondEmail.isNotEmpty &&
        firstEmail == secondEmail) {
      return true;
    }

    final hasIdentifier = firstPhone.isNotEmpty ||
        secondPhone.isNotEmpty ||
        firstEmail.isNotEmpty ||
        secondEmail.isNotEmpty;
    if (hasIdentifier) return false;

    return _normalizeText(first.fullName) == _normalizeText(second.fullName);
  }

  String _normalizeText(String? value) => (value ?? '').trim().toLowerCase();

  String _normalizePhone(String? value) =>
      (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');

  Future<void> deleteDevice(int key) async {
    await _deviceBox.delete(key);
    _loadDevices();
  }

  int chainSizeForDevice(Device device) {
    final deviceKey = _asIntKey(device.key);
    if (deviceKey == null) return 1;
    return _resolveChainKeys(deviceKey, device).length;
  }

  List<Device> linkedDevicesForDevice(Device device) {
    final deviceKey = _asIntKey(device.key);
    if (deviceKey == null) return [device];

    final keys = _resolveChainKeys(deviceKey, device);
    final linked = _deviceBox.values.where((item) {
      final itemKey = _asIntKey(item.key);
      return itemKey != null && keys.contains(itemKey);
    }).toList();

    linked.sort((a, b) {
      final aKey = _asIntKey(a.key);
      final bKey = _asIntKey(b.key);
      final rootKey = rootKeyForDevice(device);

      if (aKey == rootKey) return -1;
      if (bKey == rootKey) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return linked.isEmpty ? [device] : linked;
  }

  int? rootKeyForDevice(Device device) {
    final deviceKey = _asIntKey(device.key);
    if (deviceKey == null) return null;
    if (device.isStandalone) return deviceKey;
    return device.isProcessingModule
        ? _asIntKey(device.controlModule?.key) ?? deviceKey
        : deviceKey;
  }

  Device? controlUnitForDevice(Device device) {
    final rootKey = rootKeyForDevice(device);
    if (rootKey == null) return null;
    return _deviceBox.get(rootKey);
  }
}

class DeviceValidationException implements Exception {
  final String message;

  const DeviceValidationException(this.message);

  @override
  String toString() => message;
}
