import 'dart:io';
import 'dart:math';

import 'package:hive/hive.dart';

class LanDeviceIdentity {
  final String deviceId;
  final String deviceName;
  final String? macAddress;

  const LanDeviceIdentity({
    required this.deviceId,
    required this.deviceName,
    this.macAddress,
  });

  String get approvalIdentity => macAddress ?? deviceId;
}

class LanDeviceIdentityService {
  static const String _prefsBoxName = 'app_preferences';
  static const String _deviceIdKey = 'lan_stable_device_id';

  Future<LanDeviceIdentity> resolve() async {
    final prefs = await Hive.openBox(_prefsBoxName);
    var deviceId = prefs.get(_deviceIdKey) as String?;
    if (deviceId == null || deviceId.trim().isEmpty) {
      deviceId = _createDeviceId();
      await prefs.put(_deviceIdKey, deviceId);
    }

    return LanDeviceIdentity(
      deviceId: deviceId,
      deviceName: _deviceName(),
      macAddress: await _resolveMacAddress(),
    );
  }

  String _deviceName() {
    try {
      final hostname = Platform.localHostname.trim();
      return hostname.isEmpty ? 'Biomed Mobil' : hostname;
    } catch (_) {
      return Platform.isAndroid ? 'Biomed Mobil' : 'Biomed Desktop';
    }
  }

  String _createDeviceId() {
    final random = Random.secure();
    final suffix =
        List.generate(8, (_) => random.nextInt(16).toRadixString(16)).join();
    return 'BIO-${DateTime.now().microsecondsSinceEpoch}-$suffix';
  }

  Future<String?> _resolveMacAddress() async {
    if (Platform.isWindows) {
      try {
        final result = await Process.run(
          'getmac',
          const ['/FO', 'CSV', '/NH'],
          runInShell: true,
        );
        final match = RegExp(
          r'([0-9A-Fa-f]{2}[-:]){5}[0-9A-Fa-f]{2}',
        ).firstMatch(result.stdout.toString());
        final value = match?.group(0);
        if (_isUsableMac(value)) return _normalizeMac(value!);
      } catch (_) {
        // Stable device ID remains available when the OS hides the MAC.
      }
    }

    List<NetworkInterface> interfaces;
    try {
      interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.any,
      );
    } catch (_) {
      return null;
    }
    for (final interface in interfaces) {
      final candidates = <String>[
        if (Platform.isLinux || Platform.isAndroid)
          '/sys/class/net/${interface.name}/address',
      ];
      for (final path in candidates) {
        try {
          final value = (await File(path).readAsString()).trim();
          if (_isUsableMac(value)) return _normalizeMac(value);
        } catch (_) {
          // Android commonly blocks interface MAC access.
        }
      }
    }
    return null;
  }

  bool _isUsableMac(String? value) {
    if (value == null) return false;
    final normalized = _normalizeMac(value);
    return RegExp(r'^([0-9A-F]{2}:){5}[0-9A-F]{2}$').hasMatch(normalized) &&
        normalized != '00:00:00:00:00:00' &&
        normalized != '02:00:00:00:00:00';
  }

  String _normalizeMac(String value) {
    return value.trim().replaceAll('-', ':').toUpperCase();
  }
}
