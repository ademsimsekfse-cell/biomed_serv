import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:biomed_serv/services/sync_service.dart';

class OutboxService {
  static final OutboxService _instance = OutboxService._internal();
  factory OutboxService() => _instance;
  OutboxService._internal();

  late Box _box;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _box = await Hive.openBox('outbox');
    _initialized = true;
  }

  Future<void> addChange(Map<String, dynamic> change) async {
    await init();
    final id = DateTime.now().toIso8601String() + '-' + (_box.length + 1).toString();
    await _box.put(id, change);
  }

  Future<List<Map<String, dynamic>>> pendingChanges() async {
    await init();
    return _box.keys.map((k) => Map<String, dynamic>.from(_box.get(k))).toList();
  }

  Future<void> clearProcessed(List<String> keys) async {
    await init();
    for (final k in keys) {
      await _box.delete(k);
    }
  }

  /// Process queue by pushing to server via SyncService.
  /// Returns applied server response.
  Future<Map<String, dynamic>> processQueue(SyncService sync,
      {required String clientId, String? lastKnownServerTs}) async {
    await init();
    final entries = <Map<String, dynamic>>[];
    final keys = <String>[];
    for (final key in _box.keys) {
      final value = _box.get(key);
      if (value is Map) {
        entries.add({...value, 'local_op_id': key});
        keys.add(key.toString());
      }
    }

    if (entries.isEmpty) return {'applied': []};

    final resp = await sync.pushChanges(entries, clientId, lastKnownServerTs);

    // If applied, remove processed ops from outbox by matching local_op_id
    final applied = resp['applied'] as List<dynamic>?;
    if (applied != null && applied.isNotEmpty) {
      final processedKeys = <String>[];
      for (final a in applied) {
        final localId = a['local_op_id'];
        if (localId != null) processedKeys.add(localId.toString());
      }
      await clearProcessed(processedKeys);
    }

    return resp;
  }
}
