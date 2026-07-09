import 'package:biomed_serv/models/customer.dart';
import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/models/technician.dart';
import 'package:biomed_serv/services/lan_sync_service.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class TechnicalAssignment {
  final String targetType; // customer / device
  final String targetId;
  final String targetName;
  final String technicianId;
  final String technicianName;
  final String? note;
  final DateTime assignedAt;

  const TechnicalAssignment({
    required this.targetType,
    required this.targetId,
    required this.targetName,
    required this.technicianId,
    required this.technicianName,
    this.note,
    required this.assignedAt,
  });

  Map<String, dynamic> toJson() => {
        'targetType': targetType,
        'targetId': targetId,
        'targetName': targetName,
        'technicianId': technicianId,
        'technicianName': technicianName,
        'note': note,
        'assignedAt': assignedAt.toIso8601String(),
      };

  factory TechnicalAssignment.fromJson(Map<String, dynamic> json) {
    return TechnicalAssignment(
      targetType: json['targetType']?.toString() ?? 'device',
      targetId: json['targetId']?.toString() ?? '',
      targetName: json['targetName']?.toString() ?? '',
      technicianId: json['technicianId']?.toString() ?? '',
      technicianName: json['technicianName']?.toString() ?? '',
      note: json['note']?.toString(),
      assignedAt: DateTime.tryParse(json['assignedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class TechnicalAssignmentService extends ChangeNotifier {
  static const String prefsBoxName = 'app_preferences';
  static const String customerAssignmentsKey = 'technical_customer_assignments';
  static const String deviceAssignmentsKey = 'technical_device_assignments';

  Box? _prefsBox;
  Map<String, TechnicalAssignment> _customerAssignments = {};
  Map<String, TechnicalAssignment> _deviceAssignments = {};

  List<TechnicalAssignment> get customerAssignments =>
      _customerAssignments.values.toList()
        ..sort((a, b) => a.targetName.compareTo(b.targetName));

  List<TechnicalAssignment> get deviceAssignments =>
      _deviceAssignments.values.toList()
        ..sort((a, b) => a.targetName.compareTo(b.targetName));

  List<TechnicalAssignment> get allAssignments => [
        ...customerAssignments,
        ...deviceAssignments,
      ];

  TechnicalAssignmentService() {
    init();
  }

  Future<void> init() async {
    _prefsBox = await Hive.openBox(prefsBoxName);
    _load();
  }

  Future<void> assignCustomer({
    required Customer customer,
    required Technician technician,
    String? note,
  }) async {
    final customerId = _customerAssignmentId(customer);
    final assignment = TechnicalAssignment(
      targetType: 'customer',
      targetId: customerId,
      targetName: customer.name,
      technicianId: LanSyncService.technicianAccessId(technician),
      technicianName: technician.fullName,
      note: note,
      assignedAt: DateTime.now(),
    );
    _customerAssignments[assignment.targetId] = assignment;
    await _persist();
  }

  Future<void> assignDevice({
    required Device device,
    required Technician technician,
    String? note,
  }) async {
    final deviceId = _deviceAssignmentId(device);
    final assignment = TechnicalAssignment(
      targetType: 'device',
      targetId: deviceId,
      targetName: '${device.name} (${device.serialNumber})',
      technicianId: LanSyncService.technicianAccessId(technician),
      technicianName: technician.fullName,
      note: note,
      assignedAt: DateTime.now(),
    );
    _deviceAssignments[assignment.targetId] = assignment;
    await _persist();
  }

  Future<void> removeCustomerAssignment(String customerName) async {
    _customerAssignments.remove(customerName);
    await _persist();
  }

  Future<void> removeDeviceAssignment(String serialNumber) async {
    _deviceAssignments.remove(_normalizeSerial(serialNumber));
    await _persist();
  }

  TechnicalAssignment? assignmentForCustomer(Customer customer) {
    final assignment = _customerAssignments[_customerAssignmentId(customer)];
    if (assignment != null) return assignment;
    return _customerAssignments[customer.name];
  }

  TechnicalAssignment? assignmentForDevice(Device device) {
    final explicit = _deviceAssignments[_deviceAssignmentId(device)] ??
        _deviceAssignments[device.serialNumber] ??
        _legacyDeviceAssignmentFor(device.serialNumber);
    if (explicit != null) return explicit;
    final customer = device.customer;
    if (customer is Customer) return assignmentForCustomer(customer);
    return null;
  }

  Map<String, dynamic> exportJson() => {
        'customers': _customerAssignments
            .map((key, value) => MapEntry(key, value.toJson())),
        'devices': _deviceAssignments
            .map((key, value) => MapEntry(key, value.toJson())),
      };

  Future<void> importJson(Map<String, dynamic> json) async {
    final customers = _mapOfMaps(json['customers']);
    final devices = _mapOfMaps(json['devices']);
    for (final entry in customers.entries) {
      _customerAssignments[entry.key] =
          TechnicalAssignment.fromJson(entry.value);
    }
    for (final entry in devices.entries) {
      _deviceAssignments[entry.key] = TechnicalAssignment.fromJson(entry.value);
    }
    await _persist();
  }

  void _load() {
    _customerAssignments =
        _mapOfMaps(_prefsBox?.get(customerAssignmentsKey)).map(
      (key, value) => MapEntry(key, TechnicalAssignment.fromJson(value)),
    );
    _deviceAssignments = _mapOfMaps(_prefsBox?.get(deviceAssignmentsKey)).map(
      (key, value) => MapEntry(key, TechnicalAssignment.fromJson(value)),
    );
    notifyListeners();
  }

  Future<void> _persist() async {
    await _prefsBox?.put(
      customerAssignmentsKey,
      _customerAssignments.map((key, value) => MapEntry(key, value.toJson())),
    );
    await _prefsBox?.put(
      deviceAssignmentsKey,
      _deviceAssignments.map((key, value) => MapEntry(key, value.toJson())),
    );
    notifyListeners();
  }

  Map<String, Map<String, dynamic>> _mapOfMaps(dynamic value) {
    if (value is! Map) return {};
    return value.map(
      (key, value) => MapEntry(
        key.toString(),
        value is Map
            ? value.map((k, v) => MapEntry(k.toString(), v))
            : <String, dynamic>{},
      ),
    );
  }

  String _customerAssignmentId(Customer customer) {
    final key = customer.key;
    if (key != null) {
      return 'customer_${key.toString()}';
    }
    return customer.name.trim();
  }

  String _deviceAssignmentId(Device device) {
    return _normalizeSerial(device.serialNumber);
  }

  TechnicalAssignment? _legacyDeviceAssignmentFor(String serialNumber) {
    final target = _normalizeSerial(serialNumber);
    for (final entry in _deviceAssignments.entries) {
      if (_normalizeSerial(entry.key) == target) return entry.value;
    }
    return null;
  }

  String _normalizeSerial(String serialNumber) {
    return serialNumber.trim().toUpperCase();
  }
}
