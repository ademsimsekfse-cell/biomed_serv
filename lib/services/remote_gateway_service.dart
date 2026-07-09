import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

enum RemoteTransportMode {
  localPreferred,
  localOnly,
  remoteOnly,
}

class RemoteGatewaySettings {
  final bool enabled;
  final String baseUrl;
  final String centerToken;
  final String siteCode;
  final RemoteTransportMode mode;

  const RemoteGatewaySettings({
    required this.enabled,
    required this.baseUrl,
    required this.centerToken,
    required this.siteCode,
    required this.mode,
  });

  bool get isConfigured =>
      enabled && baseUrl.trim().isNotEmpty && siteCode.trim().isNotEmpty;
}

class RemoteGatewayHealth {
  final bool ok;
  final String message;
  final String? serverVersion;

  const RemoteGatewayHealth({
    required this.ok,
    required this.message,
    this.serverVersion,
  });
}

class RemotePairingRequest {
  final String id;
  final String deviceId;
  final String technicianId;
  final String technicianName;
  final String sourceDevice;
  final DateTime requestedAt;

  const RemotePairingRequest({
    required this.id,
    required this.deviceId,
    required this.technicianId,
    required this.technicianName,
    required this.sourceDevice,
    required this.requestedAt,
  });

  factory RemotePairingRequest.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] is Map
        ? Map<String, dynamic>.from(json['payload'] as Map)
        : const <String, dynamic>{};
    final technician = payload['technician'] is Map
        ? Map<String, dynamic>.from(payload['technician'] as Map)
        : const <String, dynamic>{};
    return RemotePairingRequest(
      id: json['id']?.toString() ?? '',
      deviceId:
          json['deviceId']?.toString() ?? payload['deviceId']?.toString() ?? '',
      technicianId: json['technicianId']?.toString() ??
          payload['technicianId']?.toString() ??
          '',
      technicianName: technician['fullName']?.toString() ??
          '${technician['firstName'] ?? ''} ${technician['lastName'] ?? ''}'
              .trim(),
      sourceDevice: payload['sourceDevice']?.toString() ?? 'Uzak mobil cihaz',
      requestedAt: DateTime.tryParse(json['requestedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class RemoteInboxItem {
  final int id;
  final String deviceId;
  final String technicianId;
  final Map<String, dynamic> bundle;

  const RemoteInboxItem({
    required this.id,
    required this.deviceId,
    required this.technicianId,
    required this.bundle,
  });

  factory RemoteInboxItem.fromJson(Map<String, dynamic> json) {
    return RemoteInboxItem(
      id: json['id'] as int? ?? 0,
      deviceId: json['deviceId']?.toString() ?? '',
      technicianId: json['technicianId']?.toString() ?? '',
      bundle: json['bundle'] is Map
          ? Map<String, dynamic>.from(json['bundle'] as Map)
          : const {},
    );
  }
}

class RemoteMobileSyncResponse {
  final int? outboundMessageId;
  final Map<String, dynamic>? outboundBundle;

  const RemoteMobileSyncResponse({
    this.outboundMessageId,
    this.outboundBundle,
  });
}

class RemoteGatewayService {
  static const String prefsBoxName = 'app_preferences';
  static const String enabledKey = 'api_enabled';
  static const String baseUrlKey = 'api_base_url';
  static const String centerTokenKey = 'api_key';
  static const String siteCodeKey = 'remote_site_code';
  static const String transportModeKey = 'remote_transport_mode';
  static const String deviceTokenKey = 'remote_device_token';
  static const String pairingRequestIdKey = 'remote_pairing_request_id';

  final http.Client _client;

  RemoteGatewayService({http.Client? client})
      : _client = client ?? http.Client();

  Future<RemoteGatewaySettings> loadSettings() async {
    final box = await Hive.openBox(prefsBoxName);
    final modeName = box.get(transportModeKey) as String?;
    return RemoteGatewaySettings(
      enabled: box.get(enabledKey) as bool? ?? false,
      baseUrl: box.get(baseUrlKey) as String? ?? '',
      centerToken: box.get(centerTokenKey) as String? ?? '',
      siteCode: box.get(siteCodeKey) as String? ?? '',
      mode: RemoteTransportMode.values.firstWhere(
        (mode) => mode.name == modeName,
        orElse: () => RemoteTransportMode.localPreferred,
      ),
    );
  }

  Future<void> saveSettings(RemoteGatewaySettings settings) async {
    final box = await Hive.openBox(prefsBoxName);
    await box.put(enabledKey, settings.enabled);
    await box.put(baseUrlKey, _normalizeBaseUrl(settings.baseUrl));
    await box.put(centerTokenKey, settings.centerToken.trim());
    await box.put(siteCodeKey, settings.siteCode.trim());
    await box.put(transportModeKey, settings.mode.name);
  }

  Future<RemoteGatewayHealth> testConnection(
    RemoteGatewaySettings settings,
  ) async {
    final validation = validateSettings(settings, requireCenterToken: false);
    if (validation != null) {
      return RemoteGatewayHealth(ok: false, message: validation);
    }

    try {
      final response = await _client
          .get(_uri(settings, '/health'))
          .timeout(const Duration(seconds: 10));
      final body = _jsonMap(response.bodyBytes);
      final protocol = body['protocol']?.toString();
      if (response.statusCode != 200 ||
          body['ok'] != true ||
          protocol != 'biomed-servis-remote-v1') {
        return RemoteGatewayHealth(
          ok: false,
          message:
              'Sunucu yanıt verdi ancak Biomed Remote Gateway doğrulanamadı.',
        );
      }
      return RemoteGatewayHealth(
        ok: true,
        message: 'Uzak merkez bağlantısı doğrulandı.',
        serverVersion: body['version']?.toString(),
      );
    } catch (e) {
      return RemoteGatewayHealth(
        ok: false,
        message: 'Uzak merkeze ulaşılamadı: $e',
      );
    }
  }

  String? validateSettings(
    RemoteGatewaySettings settings, {
    required bool requireCenterToken,
  }) {
    final rawUrl = settings.baseUrl.trim();
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'Geçerli bir Gateway URL adresi girin.';
    }
    if (uri.scheme.toLowerCase() != 'https' && !_isLocalAddress(uri.host)) {
      return 'Uzak merkez bağlantısı HTTPS kullanmalıdır.';
    }
    if (settings.siteCode.trim().length < 6) {
      return 'Site kodu en az 6 karakter olmalıdır.';
    }
    if (requireCenterToken && settings.centerToken.trim().length < 24) {
      return 'Desktop merkez anahtarı en az 24 karakter olmalıdır.';
    }
    return null;
  }

  Future<List<RemotePairingRequest>> pendingPairings(
    RemoteGatewaySettings settings,
  ) async {
    final response = await _client
        .get(
          _uri(settings, '/v1/center/pairings'),
          headers: _centerHeaders(settings),
        )
        .timeout(const Duration(seconds: 12));
    _requireSuccess(response);
    final body = _jsonMap(response.bodyBytes);
    return (body['items'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (item) => RemotePairingRequest.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<void> decidePairing(
    RemoteGatewaySettings settings, {
    required String requestId,
    required bool approve,
  }) async {
    final action = approve ? 'approve' : 'reject';
    final response = await _client
        .post(
          _uri(settings, '/v1/center/pairings/$requestId/$action'),
          headers: _centerHeaders(settings),
        )
        .timeout(const Duration(seconds: 12));
    _requireSuccess(response);
  }

  Future<String> requestMobilePairing(
    RemoteGatewaySettings settings,
    Map<String, dynamic> identityPayload,
  ) async {
    final response = await _client
        .post(
          _uri(settings, '/v1/pair/request'),
          headers: _jsonHeaders(),
          body: jsonEncode({
            ...identityPayload,
            'siteCode': settings.siteCode.trim(),
          }),
        )
        .timeout(const Duration(seconds: 12));
    _requireSuccess(response);
    final body = _jsonMap(response.bodyBytes);
    final requestId = body['requestId']?.toString() ?? '';
    if (requestId.isEmpty) {
      throw const FormatException('Gateway eşleşme numarası döndürmedi.');
    }
    final box = await Hive.openBox(prefsBoxName);
    await box.put(pairingRequestIdKey, requestId);
    return requestId;
  }

  Future<bool> refreshMobilePairing(
    RemoteGatewaySettings settings, {
    required String deviceId,
  }) async {
    final box = await Hive.openBox(prefsBoxName);
    final requestId = box.get(pairingRequestIdKey) as String?;
    if (requestId == null || requestId.isEmpty) return false;

    final uri = _uri(settings, '/v1/pair/status').replace(
      queryParameters: {
        'requestId': requestId,
        'deviceId': deviceId,
        'siteCode': settings.siteCode.trim(),
      },
    );
    final response =
        await _client.get(uri).timeout(const Duration(seconds: 12));
    _requireSuccess(response);
    final body = _jsonMap(response.bodyBytes);
    final token = body['deviceToken']?.toString();
    if (body['status'] == 'approved' && token != null && token.isNotEmpty) {
      await box.put(deviceTokenKey, token);
      return true;
    }
    if (body['status'] == 'rejected' || body['status'] == 'superseded') {
      await box.delete(pairingRequestIdKey);
    }
    return false;
  }

  Future<RemoteMobileSyncResponse> mobileSync(
    RemoteGatewaySettings settings,
    Map<String, dynamic> bundle,
  ) async {
    final box = await Hive.openBox(prefsBoxName);
    final deviceToken = box.get(deviceTokenKey) as String?;
    if (deviceToken == null || deviceToken.isEmpty) {
      throw StateError('Uzak merkez eşleşmesi henüz onaylanmadı.');
    }
    final response = await _client
        .post(
          _uri(settings, '/v1/mobile/sync'),
          headers: _deviceHeaders(deviceToken),
          body: jsonEncode({'bundle': bundle}),
        )
        .timeout(const Duration(seconds: 20));
    _requireSuccess(response);
    final body = _jsonMap(response.bodyBytes);
    final outbound = body['outboundBundle'];
    return RemoteMobileSyncResponse(
      outboundMessageId: body['outboundMessageId'] as int?,
      outboundBundle:
          outbound is Map ? Map<String, dynamic>.from(outbound) : null,
    );
  }

  Future<void> acknowledgeMobileOutbox(
    RemoteGatewaySettings settings,
    int messageId,
  ) async {
    final box = await Hive.openBox(prefsBoxName);
    final deviceToken = box.get(deviceTokenKey) as String?;
    if (deviceToken == null || deviceToken.isEmpty) {
      throw StateError('Uzak merkez eşleşmesi henüz onaylanmadı.');
    }
    final response = await _client
        .post(
          _uri(settings, '/v1/mobile/outbox/$messageId/ack'),
          headers: _deviceHeaders(deviceToken),
        )
        .timeout(const Duration(seconds: 12));
    _requireSuccess(response);
  }

  Future<List<RemoteInboxItem>> centerInbox(
    RemoteGatewaySettings settings,
  ) async {
    final response = await _client
        .get(
          _uri(settings, '/v1/center/inbox'),
          headers: _centerHeaders(settings),
        )
        .timeout(const Duration(seconds: 20));
    _requireSuccess(response);
    final body = _jsonMap(response.bodyBytes);
    return (body['items'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (item) => RemoteInboxItem.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<void> acknowledgeInbox(
    RemoteGatewaySettings settings,
    int messageId,
  ) async {
    final response = await _client
        .post(
          _uri(settings, '/v1/center/inbox/$messageId/ack'),
          headers: _centerHeaders(settings),
        )
        .timeout(const Duration(seconds: 12));
    _requireSuccess(response);
  }

  Future<void> pushCenterBundle(
    RemoteGatewaySettings settings, {
    required String deviceId,
    required Map<String, dynamic> bundle,
  }) async {
    final response = await _client
        .post(
          _uri(settings, '/v1/center/outbox'),
          headers: _centerHeaders(settings),
          body: jsonEncode({
            'deviceId': deviceId,
            'bundle': bundle,
          }),
        )
        .timeout(const Duration(seconds: 20));
    _requireSuccess(response);
  }

  Future<String?> storedDeviceToken() async {
    final box = await Hive.openBox(prefsBoxName);
    return box.get(deviceTokenKey) as String?;
  }

  Future<String?> storedPairingRequestId() async {
    final box = await Hive.openBox(prefsBoxName);
    return box.get(pairingRequestIdKey) as String?;
  }

  Future<void> clearMobilePairing() async {
    final box = await Hive.openBox(prefsBoxName);
    await box.delete(deviceTokenKey);
    await box.delete(pairingRequestIdKey);
  }

  Uri _uri(RemoteGatewaySettings settings, String path) {
    return Uri.parse('${_normalizeBaseUrl(settings.baseUrl)}$path');
  }

  Map<String, String> _jsonHeaders() => const {
        'content-type': 'application/json; charset=utf-8',
        'accept': 'application/json',
      };

  Map<String, String> _centerHeaders(RemoteGatewaySettings settings) => {
        ..._jsonHeaders(),
        'authorization': 'Bearer ${settings.centerToken.trim()}',
      };

  Map<String, String> _deviceHeaders(String token) => {
        ..._jsonHeaders(),
        'authorization': 'Bearer $token',
      };

  Map<String, dynamic> _jsonMap(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const FormatException('Gateway JSON nesnesi döndürmedi.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  void _requireSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String message = 'Gateway hatası: HTTP ${response.statusCode}';
    try {
      final body = _jsonMap(response.bodyBytes);
      message = body['error']?.toString() ?? message;
    } catch (_) {
      // HTTP durum kodu yeterli hata bilgisidir.
    }
    throw StateError(message);
  }

  String _normalizeBaseUrl(String value) {
    return value.trim().replaceFirst(RegExp(r'/+$'), '');
  }

  bool _isLocalAddress(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized.startsWith('192.168.') ||
        normalized.startsWith('10.') ||
        RegExp(r'^172\.(1[6-9]|2[0-9]|3[0-1])\.').hasMatch(normalized);
  }

  void close() {
    _client.close();
  }
}
