import 'package:biomed_serv/services/lan_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('access approval key separates technician installations', () {
    final first = LanAccessRequest(
      technicianId: 'TECH-1',
      technicianName: 'Adem Usta',
      sourceDevice: 'Telefon A',
      deviceId: 'BIO-A',
      macAddress: 'AA:BB:CC:DD:EE:01',
      sourceIp: '192.168.1.20',
      requestedAt: DateTime(2026, 6, 28),
    );
    final second = LanAccessRequest(
      technicianId: 'TECH-1',
      technicianName: 'Adem Usta',
      sourceDevice: 'Telefon B',
      deviceId: 'BIO-B',
      requestedAt: DateTime(2026, 6, 28),
    );

    expect(first.accessKey, 'TECH-1::BIO-A');
    expect(second.accessKey, 'TECH-1::BIO-B');
    expect(first.accessKey, isNot(second.accessKey));
    expect(first.deviceIdentityLabel, 'AA:BB:CC:DD:EE:01');
  });

  test('legacy access request remains compatible', () {
    final request = LanAccessRequest.fromJson({
      'technicianId': 'TECH-OLD',
      'technicianName': 'Eski Teknisyen',
      'sourceDevice': 'Eski Telefon',
      'requestedAt': '2026-06-28T10:00:00.000',
    });

    expect(request.deviceId, 'LEGACY');
    expect(request.accessKey, 'TECH-OLD');
  });
}
