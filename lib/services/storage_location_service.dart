import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:biomed_serv/services/portable_runtime_service.dart';

class StorageLocationService extends ChangeNotifier {
  static const String prefsBoxName = 'app_preferences';
  static const String workspaceDirectoryKey = 'workspace_directory';
  static const String backupDirectoryKey = 'backup_directory';
  static const String storageConfiguredKey = 'storage_configured';
  static const String autoBackupEnabledKey = 'auto_backup_enabled';

  Box? _prefsBox;
  bool _initialized = false;
  String? _workspaceDirectory;
  String? _backupDirectory;
  bool _storageConfigured = false;
  bool _autoBackupEnabled = true;

  bool get initialized => _initialized;
  String? get workspaceDirectory => _workspaceDirectory;
  String? get backupDirectory => _backupDirectory;
  bool get storageConfigured => _storageConfigured;
  bool get autoBackupEnabled => _autoBackupEnabled;

  Future<void> init() async {
    if (_initialized) return;
    _prefsBox = await Hive.openBox(prefsBoxName);
    _workspaceDirectory = _prefsBox!.get(workspaceDirectoryKey) as String?;
    _backupDirectory = _prefsBox!.get(backupDirectoryKey) as String?;
    _storageConfigured = _prefsBox!.get(storageConfiguredKey) as bool? ?? false;
    _autoBackupEnabled = _prefsBox!.get(autoBackupEnabledKey) as bool? ?? true;
    _initialized = true;
    notifyListeners();
  }

  Future<String> defaultWorkspaceDirectory() async {
    return PortableRuntimeService().defaultWorkspacePath();
  }

  Future<String> effectiveWorkspaceDirectory() async {
    await init();
    final path = _workspaceDirectory ?? await defaultWorkspaceDirectory();
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  Future<String> effectiveBackupDirectory() async {
    await init();
    final path = _backupDirectory ??
        '${await effectiveWorkspaceDirectory()}${Platform.pathSeparator}Backups';
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  Future<String?> pickWorkspaceDirectory() {
    return FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Fejox BioServ calisma klasorunu secin',
    );
  }

  Future<void> configure({
    required String workspaceDirectory,
    required bool autoBackupEnabled,
  }) async {
    await init();
    final cleanPath = workspaceDirectory.trim().replaceAll('"', '');
    final workspace = Directory(cleanPath);
    if (!await workspace.exists()) {
      await workspace.create(recursive: true);
    }

    final backup =
        Directory('${workspace.path}${Platform.pathSeparator}Backups');
    if (!await backup.exists()) {
      await backup.create(recursive: true);
    }

    _workspaceDirectory = workspace.path;
    _backupDirectory = backup.path;
    _storageConfigured = true;
    _autoBackupEnabled = autoBackupEnabled;

    await _prefsBox!.put(workspaceDirectoryKey, _workspaceDirectory);
    await _prefsBox!.put(backupDirectoryKey, _backupDirectory);
    await _prefsBox!.put(storageConfiguredKey, true);
    await _prefsBox!.put(autoBackupEnabledKey, autoBackupEnabled);
    notifyListeners();
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    await init();
    _autoBackupEnabled = enabled;
    await _prefsBox!.put(autoBackupEnabledKey, enabled);
    notifyListeners();
  }
}
