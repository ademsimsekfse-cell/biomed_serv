import 'dart:io';

import 'package:biomed_serv/services/database_service.dart';
import 'package:biomed_serv/services/lan_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('biomed_lan_test_');
    Hive.init(tempDirectory.path);
  });

  tearDown(() async {
    await Hive.close();
    await tempDirectory.delete(recursive: true);
  });

  test('desktop center answers the local health probe', () async {
    final service = LanSyncService(DatabaseService());
    final server = await service.startServer(port: 0);
    addTearDown(service.stopServer);

    final center = await service.probeCenter(
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
    );

    expect(center, isNotNull);
    expect(center!.appName, 'Biomed Servis');
    expect(center.port, server.port);
    expect(center.deviceId, isNotEmpty);
  });

  test('local health probe rejects a different service', () async {
    final fakeServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => fakeServer.close(force: true));
    fakeServer.listen((request) {
      request.response
        ..headers.contentType = ContentType.json
        ..write('{"ok":true,"app":"Biomed Servis"}')
        ..close();
    });

    final service = LanSyncService(DatabaseService());
    final center = await service.probeCenter(
      host: InternetAddress.loopbackIPv4.address,
      port: fakeServer.port,
    );

    expect(center, isNull);
  });
}
