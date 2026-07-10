// Example integration helpers for enqueueing changes and processing outbox.

import 'package:biomed_serv/services/sync_service.dart';
import 'package:biomed_serv/services/outbox_service.dart';

class SyncIntegration {
  final SyncService syncService;
  final OutboxService outbox = OutboxService();
  final String clientId;

  SyncIntegration({required this.syncService, required this.clientId});

  Future<void> enqueueEntityChange(String entityType, String? entityId, String opType, Map<String, dynamic> data) async {
    final change = {
      'entity_type': entityType,
      'entity_id': entityId,
      'op_type': opType,
      'data': data,
      'client_ts': DateTime.now().toUtc().toIso8601String(),
    };
    await outbox.addChange(change);
  }

  Future<void> processOutbox({String? lastServerTs}) async {
    final resp = await outbox.processQueue(syncService, clientId: clientId, lastKnownServerTs: lastServerTs);
    // handle resp: applied/conflicts etc.
    // For now, simply print or log
    // print('Sync result: $resp');
  }
}
