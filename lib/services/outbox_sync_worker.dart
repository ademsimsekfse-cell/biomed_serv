import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:biomed_serv/services/sync_integration.dart';

class OutboxSyncWorker {
  final SyncIntegration integration;
  Timer? _timer;
  StreamSubscription<ConnectivityResult>? _sub;

  OutboxSyncWorker(this.integration);

  void start({Duration interval = const Duration(minutes: 1)}) {
    // Listen to connectivity changes
    _sub = Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        integration.processOutbox();
      }
    });

    // Periodic timer to ensure queue processed
    _timer = Timer.periodic(interval, (_) async {
      await integration.processOutbox();
    });
  }

  void stop() {
    _timer?.cancel();
    _sub?.cancel();
  }
}
