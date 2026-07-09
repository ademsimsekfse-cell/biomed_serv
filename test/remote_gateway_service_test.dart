import 'dart:convert';

import 'package:biomed_serv/services/remote_gateway_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const settings = RemoteGatewaySettings(
    enabled: true,
    baseUrl: 'https://servis.example.com/biomed',
    centerToken: '',
    siteCode: 'MERKEZ01',
    mode: RemoteTransportMode.localPreferred,
  );

  test('accepts only a healthy Biomed remote gateway', () async {
    final service = RemoteGatewayService(
      client: MockClient((request) async {
        expect(request.url.path, '/biomed/health');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'ok': true,
              'protocol': 'biomed-servis-remote-v1',
              'version': '1',
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(service.close);

    final health = await service.testConnection(settings);

    expect(health.ok, isTrue);
    expect(health.serverVersion, '1');
  });

  test('rejects a reachable server using the wrong protocol', () async {
    final service = RemoteGatewayService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'ok': true, 'protocol': 'another-service'}),
          200,
        ),
      ),
    );
    addTearDown(service.close);

    final health = await service.testConnection(settings);

    expect(health.ok, isFalse);
    expect(health.message, contains('doğrulanamadı'));
  });

  test('requires HTTPS for an internet gateway', () {
    final service = RemoteGatewayService();
    addTearDown(service.close);

    final error = service.validateSettings(
      const RemoteGatewaySettings(
        enabled: true,
        baseUrl: 'http://servis.example.com/biomed',
        centerToken: '',
        siteCode: 'MERKEZ01',
        mode: RemoteTransportMode.remoteOnly,
      ),
      requireCenterToken: false,
    );

    expect(error, contains('HTTPS'));
  });
}
