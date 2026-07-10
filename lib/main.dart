@@
-import 'package:biomed_serv/services/portable_runtime_service.dart';
+import 'package:biomed_serv/services/portable_runtime_service.dart';
+import 'package:biomed_serv/services/hive_platform_helper.dart';
@@
-    // HIVE BAÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂLAT - Windows/desktop tarafÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃ�[...]
-    final hivePath = await PortableRuntimeService().hiveDirectoryPath();
-    Hive.init(hivePath);
+    // HIVE INIT - use platform-aware helper so web uses IndexedDB
+    final hivePath = await PortableRuntimeService().hiveDirectoryPath();
+    await ensureHiveInitialized(nativePath: hivePath);
@@
-    // NOT: Hive.initFlutter() main.dart'ta çağrıldı, burada tekrar çağırmayın!
+    // NOT: Hive.init/ensureHiveInitialized() çağrısı main.dart'ta yapıldı, burada tekrar çağırmayın!
