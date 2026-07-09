// Hive platform helper - initialize Hive differently on Web vs native

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Call this at startup before using Hive boxes.
Future<void> ensureHiveInitialized({String? nativePath}) async {
  if (kIsWeb) {
    // On web, use Hive.initFlutter() which sets up IndexedDB backed storage.
    await Hive.initFlutter();
    return;
  }

  if (nativePath != null) {
    Hive.init(nativePath);
  } else {
    // Fallback to Hive.initFlutter which will also work on mobile/desktop if configured.
    await Hive.initFlutter();
  }
}
