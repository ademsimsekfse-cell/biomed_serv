import 'dart:async';

import 'package:biomed_serv/services/database_service.dart';
import 'package:biomed_serv/services/storage_location_service.dart';
import 'package:biomed_serv/services/structured_backup_service.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class AutoBackupService extends ChangeNotifier {
  AutoBackupService(this._dbService);

  static const String _prefsBoxName = StorageLocationService.prefsBoxName;
  static const String _enabledKey = StorageLocationService.autoBackupEnabledKey;
  static const String _intervalHoursKey = 'auto_backup_interval_hours';
  static const String _lastBackupKey = 'auto_backup_last';

  final DatabaseService _dbService;
  Timer? _timer;
  Box? _prefsBox;
  bool _initialized = false;
  bool _enabled = true;
  bool _isRunning = false;
  String? _lastError;
  DateTime? _lastBackupAt;
  int _intervalHours = 24;

  bool get initialized => _initialized;
  bool get enabled => _enabled;
  bool get isRunning => _isRunning;
  String? get lastError => _lastError;
  DateTime? get lastBackupAt => _lastBackupAt;
  int get intervalHours => _intervalHours;

  Future<void> init() async {
    if (_initialized) return;
    _prefsBox = await Hive.openBox(_prefsBoxName);
    _enabled = _prefsBox!.get(_enabledKey) as bool? ?? true;
    _intervalHours = _prefsBox!.get(_intervalHoursKey) as int? ?? 24;
    final last = _prefsBox!.get(_lastBackupKey) as String?;
    _lastBackupAt = last == null ? null : DateTime.tryParse(last);

    _timer = Timer.periodic(const Duration(minutes: 30), (_) {
      unawaited(runIfDue(reason: 'Otomatik periyodik yedek'));
    });

    _initialized = true;
    notifyListeners();
    unawaited(runIfDue(reason: 'Uygulama acilis kontrolu'));
  }

  Future<void> setEnabled(bool enabled) async {
    await _ensureInit();
    _enabled = enabled;
    await _prefsBox!.put(_enabledKey, enabled);
    notifyListeners();
  }

  Future<void> setIntervalHours(int hours) async {
    await _ensureInit();
    _intervalHours = hours.clamp(1, 168);
    await _prefsBox!.put(_intervalHoursKey, _intervalHours);
    notifyListeners();
  }

  Future<StructuredBackupResult?> runIfDue({required String reason}) async {
    await _ensureInit();
    if (!_enabled || _isRunning) return null;

    final storageConfigured =
        _prefsBox!.get(StorageLocationService.storageConfiguredKey) as bool? ??
            false;
    if (!storageConfigured) return null;

    if (_lastBackupAt != null) {
      final next = _lastBackupAt!.add(Duration(hours: _intervalHours));
      if (DateTime.now().isBefore(next)) return null;
    }

    return createNow(reason: reason);
  }

  Future<StructuredBackupResult> createNow(
      {String reason = 'Manuel yedek'}) async {
    await _ensureInit();
    _isRunning = true;
    _lastError = null;
    notifyListeners();

    try {
      final service = StructuredBackupService(_dbService);
      final result = await service.createZipBackup(reason: reason);
      _lastBackupAt = result.createdAt;
      await _prefsBox!.put(_lastBackupKey, result.createdAt.toIso8601String());
      return result;
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    } finally {
      _isRunning = false;
      notifyListeners();
    }
  }

  Future<void> _ensureInit() async {
    if (!_initialized) {
      await init();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
