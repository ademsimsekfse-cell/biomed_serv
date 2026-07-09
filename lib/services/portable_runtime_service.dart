import 'dart:io';

import 'package:path_provider/path_provider.dart';

class PortableRuntimeService {
  static const String dataFolderName = 'FejoxBioServ_Data';
  static const String setupGuideFileName = 'FejoxBioServ_SetupWizard.txt';

  Future<Directory> dataDirectory() async {
    final portableRoot = await _portableRootDirectory();
    final portableData = Directory(
        '${portableRoot.path}${Platform.pathSeparator}$dataFolderName');

    if (await _canUseDirectory(portableData)) {
      await _ensureSetupGuide(portableData);
      return portableData;
    }

    final documents = await getApplicationDocumentsDirectory();
    final fallback =
        Directory('${documents.path}${Platform.pathSeparator}$dataFolderName');
    await fallback.create(recursive: true);
    await _ensureSetupGuide(fallback);
    return fallback;
  }

  Future<String> hiveDirectoryPath() async {
    final data = await dataDirectory();
    final hive = Directory('${data.path}${Platform.pathSeparator}Hive');
    if (!await hive.exists()) {
      await hive.create(recursive: true);
    }
    return hive.path;
  }

  Future<String> defaultWorkspacePath() async {
    final data = await dataDirectory();
    final workspace =
        Directory('${data.path}${Platform.pathSeparator}Workspace');
    if (!await workspace.exists()) {
      await workspace.create(recursive: true);
    }
    return workspace.path;
  }

  Future<Directory> _portableRootDirectory() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return File(Platform.resolvedExecutable).parent;
    }
    return getApplicationDocumentsDirectory();
  }

  Future<bool> _canUseDirectory(Directory directory) async {
    try {
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final probe =
          File('${directory.path}${Platform.pathSeparator}.write_test');
      await probe.writeAsString(DateTime.now().toIso8601String(), flush: true);
      if (await probe.exists()) {
        await probe.delete();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureSetupGuide(Directory dataDirectory) async {
    final guide = File(
      '${dataDirectory.path}${Platform.pathSeparator}$setupGuideFileName',
    );
    if (await guide.exists()) return;

    await guide.writeAsString('''
Fejox BioServ Portable SetupWizard

Bu klasor Fejox BioServ'in tasinabilir veri alanidir.

Klasorler:
- Hive: Uygulamanin yerel veritabani
- Workspace: Kurulumda onerilen calisma alani
- Workspace\\Backups: Excel/CSV ZIP yedekleri

USB kullanimi:
1. Fejox BioServ uygulama klasorunu komple USB diske kopyalayin.
2. Uygulamayi USB uzerindeki .exe dosyasindan calistirin.
3. FejoxBioServ_Data klasorunu silmeyin; veriler burada tasinir.

Not: Uygulama klasoru yazilabilir degilse veri alani kullanici Belgeler klasorune tasinir.
''', flush: true);
  }
}
