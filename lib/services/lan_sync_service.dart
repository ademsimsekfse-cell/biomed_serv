import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:biomed_serv/models/customer.dart';
import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/models/company_info.dart';
import 'package:biomed_serv/models/expense.dart';
import 'package:biomed_serv/models/expense_report.dart';
import 'package:biomed_serv/models/fault_ticket.dart';
import 'package:biomed_serv/models/maintenance_form.dart';
import 'package:biomed_serv/models/service_form.dart';
import 'package:biomed_serv/models/stock.dart';
import 'package:biomed_serv/models/technician.dart';
import 'package:biomed_serv/services/database_service.dart';
import 'package:biomed_serv/services/lan_device_identity_service.dart';
import 'package:biomed_serv/services/technical_assignment_service.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

class LanAccessRequest {
  final String technicianId;
  final String technicianName;
  final String? title;
  final String? phone;
  final String? email;
  final String sourceDevice;
  final String deviceId;
  final String? macAddress;
  final String? sourceIp;
  final DateTime requestedAt;

  const LanAccessRequest({
    required this.technicianId,
    required this.technicianName,
    this.title,
    this.phone,
    this.email,
    required this.sourceDevice,
    required this.deviceId,
    this.macAddress,
    this.sourceIp,
    required this.requestedAt,
  });

  String get accessKey =>
      deviceId == 'LEGACY' ? technicianId : '$technicianId::$deviceId';

  String get deviceIdentityLabel => macAddress ?? deviceId;

  Map<String, dynamic> toJson() => {
        'technicianId': technicianId,
        'technicianName': technicianName,
        'title': title,
        'phone': phone,
        'email': email,
        'sourceDevice': sourceDevice,
        'deviceId': deviceId,
        'macAddress': macAddress,
        'sourceIp': sourceIp,
        'requestedAt': requestedAt.toIso8601String(),
      };

  factory LanAccessRequest.fromJson(Map<String, dynamic> json) {
    return LanAccessRequest(
      technicianId: json['technicianId']?.toString() ?? '',
      technicianName: json['technicianName']?.toString() ?? 'Bilinmeyen',
      title: json['title']?.toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      sourceDevice: json['sourceDevice']?.toString() ?? 'Bilinmeyen cihaz',
      deviceId: json['deviceId']?.toString() ??
          json['macAddress']?.toString() ??
          'LEGACY',
      macAddress: json['macAddress']?.toString(),
      sourceIp: json['sourceIp']?.toString(),
      requestedAt: DateTime.tryParse(json['requestedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class LanDiscoveredCenter {
  final String host;
  final int port;
  final String appName;
  final String deviceName;
  final String? deviceId;
  final String? macAddress;
  final DateTime? serverTime;

  const LanDiscoveredCenter({
    required this.host,
    required this.port,
    required this.appName,
    required this.deviceName,
    this.deviceId,
    this.macAddress,
    this.serverTime,
  });
}

class LanSyncReviewItem {
  final String id;
  final String type;
  final String title;
  final String subtitle;
  final String? identifier;
  final String technicianName;
  final String sourceDevice;
  final DateTime importedAt;
  final bool reviewed;

  const LanSyncReviewItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    this.identifier,
    required this.technicianName,
    required this.sourceDevice,
    required this.importedAt,
    this.reviewed = false,
  });

  bool get isDevice => type == 'device';
  bool get isStock => type == 'stock';

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'subtitle': subtitle,
        'identifier': identifier,
        'technicianName': technicianName,
        'sourceDevice': sourceDevice,
        'importedAt': importedAt.toIso8601String(),
        'reviewed': reviewed,
      };

  factory LanSyncReviewItem.fromJson(Map<String, dynamic> json) {
    return LanSyncReviewItem(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'device',
      title: json['title']?.toString() ?? 'Yeni kayit',
      subtitle: json['subtitle']?.toString() ?? '',
      identifier: json['identifier']?.toString(),
      technicianName:
          json['technicianName']?.toString() ?? 'Bilinmeyen teknisyen',
      sourceDevice: json['sourceDevice']?.toString() ?? 'Bilinmeyen cihaz',
      importedAt: DateTime.tryParse(json['importedAt']?.toString() ?? '') ??
          DateTime.now(),
      reviewed: json['reviewed'] == true,
    );
  }

  LanSyncReviewItem copyWith({
    bool? reviewed,
  }) {
    return LanSyncReviewItem(
      id: id,
      type: type,
      title: title,
      subtitle: subtitle,
      identifier: identifier,
      technicianName: technicianName,
      sourceDevice: sourceDevice,
      importedAt: importedAt,
      reviewed: reviewed ?? this.reviewed,
    );
  }
}

class LanSyncResult {
  final int companyInfoAdded;
  final int customersAdded;
  final int devicesAdded;
  final int serviceFormsAdded;
  final int maintenanceFormsAdded;
  final int faultTicketsAdded;
  final int expensesAdded;
  final int expenseReportsAdded;
  final int stocksAdded;
  final int recordsUpdated;
  final int skipped;
  final List<String> warnings;

  const LanSyncResult({
    this.companyInfoAdded = 0,
    this.customersAdded = 0,
    this.devicesAdded = 0,
    this.serviceFormsAdded = 0,
    this.maintenanceFormsAdded = 0,
    this.faultTicketsAdded = 0,
    this.expensesAdded = 0,
    this.expenseReportsAdded = 0,
    this.stocksAdded = 0,
    this.recordsUpdated = 0,
    this.skipped = 0,
    this.warnings = const [],
  });

  int get totalAdded =>
      companyInfoAdded +
      customersAdded +
      devicesAdded +
      serviceFormsAdded +
      maintenanceFormsAdded +
      faultTicketsAdded +
      expensesAdded +
      expenseReportsAdded +
      stocksAdded;

  Map<String, dynamic> toJson() => {
        'companyInfoAdded': companyInfoAdded,
        'customersAdded': customersAdded,
        'devicesAdded': devicesAdded,
        'serviceFormsAdded': serviceFormsAdded,
        'maintenanceFormsAdded': maintenanceFormsAdded,
        'faultTicketsAdded': faultTicketsAdded,
        'expensesAdded': expensesAdded,
        'expenseReportsAdded': expenseReportsAdded,
        'stocksAdded': stocksAdded,
        'recordsUpdated': recordsUpdated,
        'skipped': skipped,
        'warnings': warnings,
      };

  factory LanSyncResult.fromJson(Map<String, dynamic> json) {
    return LanSyncResult(
      companyInfoAdded: json['companyInfoAdded'] as int? ?? 0,
      customersAdded: json['customersAdded'] as int? ?? 0,
      devicesAdded: json['devicesAdded'] as int? ?? 0,
      serviceFormsAdded: json['serviceFormsAdded'] as int? ?? 0,
      maintenanceFormsAdded: json['maintenanceFormsAdded'] as int? ?? 0,
      faultTicketsAdded: json['faultTicketsAdded'] as int? ?? 0,
      expensesAdded: json['expensesAdded'] as int? ?? 0,
      expenseReportsAdded: json['expenseReportsAdded'] as int? ?? 0,
      stocksAdded: json['stocksAdded'] as int? ?? 0,
      recordsUpdated: json['recordsUpdated'] as int? ?? 0,
      skipped: json['skipped'] as int? ?? 0,
      warnings: (json['warnings'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class LanSyncService {
  static const int defaultPort = 8787;
  static const int discoveryPort = 8788;
  static const String _discoveryRequest = 'BIOMED_SERVIS_DISCOVER_V1';
  static const String _discoveryProtocol = 'biomed-servis-center-v1';
  static const String healthProtocol = 'biomed-servis-local-api-v1';
  static const String _prefsBoxName = 'app_preferences';
  static const String _approvedAccessKey = 'lan_approved_technicians';
  static const String _pendingAccessKey = 'lan_pending_technicians';
  static const String _reviewItemsKey = 'lan_sync_review_items';
  static const String syncIncludeCompanyInfoKey =
      'lan_sync_include_company_info';
  static const String syncIncludeCustomersKey = 'lan_sync_include_customers';
  static const String syncIncludeDevicesKey = 'lan_sync_include_devices';
  static const String syncIncludeServiceFormsKey =
      'lan_sync_include_service_forms';
  static const String syncIncludeMaintenanceFormsKey =
      'lan_sync_include_maintenance_forms';
  static const String syncIncludeFaultTicketsKey =
      'lan_sync_include_fault_tickets';
  static const String syncIncludeExpensesKey = 'lan_sync_include_expenses';
  static const String syncIncludeStocksKey = 'lan_sync_include_stocks';
  static const String syncIncludeAssignmentsKey =
      'lan_sync_include_assignments';

  static const Map<String, bool> defaultSyncProfile = {
    syncIncludeCompanyInfoKey: true,
    syncIncludeCustomersKey: true,
    syncIncludeDevicesKey: true,
    syncIncludeServiceFormsKey: true,
    syncIncludeMaintenanceFormsKey: true,
    syncIncludeFaultTicketsKey: true,
    syncIncludeExpensesKey: true,
    syncIncludeStocksKey: true,
    syncIncludeAssignmentsKey: true,
  };

  static const String sendCompanyInfoKey = 'lan_send_company_info';
  static const String sendCustomersKey = 'lan_send_customers';
  static const String sendDevicesKey = 'lan_send_devices';
  static const String sendServiceFormsKey = 'lan_send_service_forms';
  static const String sendMaintenanceFormsKey = 'lan_send_maintenance_forms';
  static const String sendFaultTicketsKey = 'lan_send_fault_tickets';
  static const String sendExpensesKey = 'lan_send_expenses';
  static const String sendStocksKey = 'lan_send_stocks';
  static const String sendAssignmentsKey = 'lan_send_assignments';

  static const Map<String, bool> defaultOutboundProfile = {
    sendCompanyInfoKey: true,
    sendCustomersKey: true,
    sendDevicesKey: true,
    sendServiceFormsKey: true,
    sendMaintenanceFormsKey: true,
    sendFaultTicketsKey: true,
    sendExpensesKey: true,
    sendStocksKey: true,
    sendAssignmentsKey: true,
  };

  final DatabaseService _dbService;
  final LanDeviceIdentityService _deviceIdentityService;
  final void Function(LanSyncResult result)? onImport;
  final VoidCallback? onAccessRequest;
  HttpServer? _server;
  RawDatagramSocket? _discoverySocket;

  LanSyncService(
    this._dbService, {
    LanDeviceIdentityService? deviceIdentityService,
    this.onImport,
    this.onAccessRequest,
  }) : _deviceIdentityService =
            deviceIdentityService ?? LanDeviceIdentityService();

  bool get isServerRunning => _server != null;
  int? get activePort => _server?.port;

  Future<HttpServer> startServer({int port = defaultPort}) async {
    if (_server != null) return _server!;

    final server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      port,
    );
    _server = server;
    unawaited(_serve(server));
    if (server.port == defaultPort) {
      await _startDiscoveryResponder();
    }
    return server;
  }

  Future<void> stopServer() async {
    final server = _server;
    _server = null;
    _discoverySocket?.close();
    _discoverySocket = null;
    await server?.close(force: true);
  }

  Future<void> _startDiscoveryResponder() async {
    if (_discoverySocket != null) return;
    try {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reuseAddress: true,
      );
      _discoverySocket = socket;
      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        while (true) {
          final datagram = socket.receive();
          if (datagram == null) break;
          final request = utf8.decode(datagram.data, allowMalformed: true);
          if (request.trim() != _discoveryRequest) continue;
          unawaited(_replyToDiscovery(socket, datagram));
        }
      });
    } catch (e) {
      debugPrint('LAN discovery responder baslatilamadi: $e');
    }
  }

  Future<void> _replyToDiscovery(
    RawDatagramSocket socket,
    Datagram datagram,
  ) async {
    final identity = await _deviceIdentityService.resolve();
    final payload = jsonEncode({
      'protocol': _discoveryProtocol,
      'app': 'Biomed Servis',
      'host': identity.deviceName,
      'port': activePort ?? defaultPort,
      'deviceId': identity.deviceId,
      'macAddress': identity.macAddress,
      'time': DateTime.now().toIso8601String(),
    });
    socket.send(utf8.encode(payload), datagram.address, datagram.port);
  }

  Future<List<String>> localIpv4Addresses() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    return interfaces
        .expand((interface) => interface.addresses)
        .map((address) => address.address)
        .where((address) => !address.startsWith('169.254.'))
        .toSet()
        .toList()
      ..sort();
  }

  Future<List<LanDiscoveredCenter>> discoverCenters({
    int port = defaultPort,
    Duration timeout = const Duration(milliseconds: 700),
  }) async {
    final localIps = await localIpv4Addresses();
    if (localIps.isEmpty) return const [];

    final broadcastCenters = await _discoverCentersByBroadcast(
      localIps: localIps,
      expectedPort: port,
      timeout: timeout,
    );
    if (broadcastCenters.isNotEmpty) return broadcastCenters;

    final candidates = <String>{};
    const priorityHosts = [1, 2, 10, 20, 25, 50, 100, 150, 200, 250, 254];
    for (final ip in localIps) {
      final parts = ip.split('.');
      if (parts.length != 4) continue;
      final prefix = parts.take(3).join('.');
      for (final suffix in priorityHosts) {
        final candidate = '$prefix.$suffix';
        if (candidate != ip) candidates.add(candidate);
      }
      for (var i = 1; i <= 254; i++) {
        final candidate = '$prefix.$i';
        if (candidate != ip) candidates.add(candidate);
      }
    }

    final client = HttpClient()
      ..connectionTimeout = timeout
      ..idleTimeout = const Duration(seconds: 2);
    try {
      final hosts = candidates.toList();
      const batchSize = 24;
      for (var start = 0; start < hosts.length; start += batchSize) {
        final end =
            start + batchSize < hosts.length ? start + batchSize : hosts.length;
        final results = await Future.wait(
          hosts.sublist(start, end).map(
                (host) => _probeCenterWithClient(
                  client,
                  host: host,
                  port: port,
                  timeout: timeout,
                ),
              ),
        );
        final centers = results.whereType<LanDiscoveredCenter>().toList();
        if (centers.isNotEmpty) {
          centers.sort((a, b) => a.host.compareTo(b.host));
          return centers;
        }
      }
      return const [];
    } finally {
      client.close(force: true);
    }
  }

  Future<List<LanDiscoveredCenter>> _discoverCentersByBroadcast({
    required List<String> localIps,
    required int expectedPort,
    required Duration timeout,
  }) async {
    RawDatagramSocket? socket;
    StreamSubscription<RawSocketEvent>? subscription;
    final hints = <String, int>{};
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      subscription = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        while (true) {
          final datagram = socket!.receive();
          if (datagram == null) break;
          try {
            final decoded = jsonDecode(utf8.decode(datagram.data));
            if (decoded is! Map ||
                decoded['protocol']?.toString() != _discoveryProtocol) {
              continue;
            }
            final centerPort =
                int.tryParse(decoded['port']?.toString() ?? '') ?? expectedPort;
            hints[datagram.address.address] = centerPort;
          } catch (_) {
            // Ağdaki ilgisiz UDP paketleri yok sayılır.
          }
        }
      });

      final request = utf8.encode(_discoveryRequest);
      final broadcastTargets = <String>{'255.255.255.255'};
      for (final ip in localIps) {
        final parts = ip.split('.');
        if (parts.length == 4) {
          broadcastTargets.add('${parts.take(3).join('.')}.255');
        }
      }
      for (final target in broadcastTargets) {
        socket.send(
          request,
          InternetAddress(target, type: InternetAddressType.IPv4),
          discoveryPort,
        );
      }

      await Future<void>.delayed(const Duration(milliseconds: 1300));
      if (hints.isEmpty) return const [];

      final client = HttpClient()
        ..connectionTimeout = timeout
        ..idleTimeout = const Duration(seconds: 2);
      try {
        final verified = await Future.wait(
          hints.entries.map(
            (entry) => _probeCenterWithClient(
              client,
              host: entry.key,
              port: entry.value,
              timeout: timeout,
            ),
          ),
        );
        final result = verified.whereType<LanDiscoveredCenter>().toList()
          ..sort((a, b) => a.host.compareTo(b.host));
        return result;
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      return const [];
    } finally {
      await subscription?.cancel();
      socket?.close();
    }
  }

  Future<LanDiscoveredCenter?> probeCenter({
    required String host,
    int port = defaultPort,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..idleTimeout = timeout;
    try {
      return await _probeCenterWithClient(
        client,
        host: host,
        port: port,
        timeout: timeout,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<LanDiscoveredCenter?> _probeCenterWithClient(
    HttpClient client, {
    required String host,
    required int port,
    required Duration timeout,
  }) async {
    try {
      final request = await client
          .getUrl(Uri.parse('http://$host:$port/health'))
          .timeout(timeout);
      final response = await request.close().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) return null;

      final content = await utf8.decoder.bind(response).join();
      final payload = jsonDecode(content);
      if (payload is! Map) return null;
      if (payload['ok'] != true ||
          payload['protocol']?.toString() != healthProtocol) {
        return null;
      }

      return LanDiscoveredCenter(
        host: host,
        port: int.tryParse(payload['port']?.toString() ?? '') ?? port,
        appName: payload['app']?.toString() ?? 'Biomed Servis',
        deviceName: payload['host']?.toString() ?? host,
        deviceId: payload['deviceId']?.toString(),
        macAddress: payload['macAddress']?.toString(),
        serverTime: DateTime.tryParse(payload['time']?.toString() ?? ''),
      );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, bool>> syncProfile() async {
    final prefs = await _prefsBox();
    return {
      for (final entry in defaultSyncProfile.entries)
        entry.key: prefs.get(entry.key) as bool? ?? entry.value,
    };
  }

  Future<Map<String, bool>> outboundProfile() async {
    final prefs = await _prefsBox();
    return {
      for (final entry in defaultOutboundProfile.entries)
        entry.key: prefs.get(entry.key) as bool? ?? entry.value,
    };
  }

  Future<Map<String, dynamic>> buildSyncBundle({
    Map<String, bool>? profile,
  }) async {
    final identity = await _deviceIdentityService.resolve();
    final technician = _primaryTechnician;
    final companyInfo = _dbService.companyInfoBox.values.isNotEmpty
        ? _dbService.companyInfoBox.values.first
        : null;
    final resolvedProfile = profile ?? await outboundProfile();

    return {
      'protocol': 'fejox-bioserv-lan-sync',
      'version': 1,
      'sourceDevice': identity.deviceName,
      'deviceId': identity.deviceId,
      'macAddress': identity.macAddress,
      'generatedAt': DateTime.now().toIso8601String(),
      'technicianId':
          technician == null ? null : technicianAccessId(technician),
      'technician': technician == null ? null : _technicianToJson(technician),
      'companyInfo':
          resolvedProfile[sendCompanyInfoKey] == true && companyInfo != null
              ? _companyInfoToJson(companyInfo)
              : null,
      'customers': resolvedProfile[sendCustomersKey] == true
          ? _dbService.customersBox.values.map(_customerToJson).toList()
          : const [],
      'devices': resolvedProfile[sendDevicesKey] == true
          ? _dbService.devicesBox.values.map(_deviceToJson).toList()
          : const [],
      'serviceForms': resolvedProfile[sendServiceFormsKey] == true
          ? _dbService.serviceFormsBox.values.map(_serviceFormToJson).toList()
          : const [],
      'maintenanceForms': resolvedProfile[sendMaintenanceFormsKey] == true
          ? _dbService.maintenanceFormsBox.values
              .map(_maintenanceFormToJson)
              .toList()
          : const [],
      'faultTickets': resolvedProfile[sendFaultTicketsKey] == true
          ? _dbService.faultTicketsBox.values.map(_faultTicketToJson).toList()
          : const [],
      'expenses': resolvedProfile[sendExpensesKey] == true
          ? _dbService.expensesBox.values.map(_expenseToJson).toList()
          : const [],
      'expenseReports': resolvedProfile[sendExpensesKey] == true
          ? _dbService.expenseReportsBox.values
              .map(_expenseReportToJson)
              .toList()
          : const [],
      'stocks': resolvedProfile[sendStocksKey] == true
          ? _dbService.stocksBox.values.map(_stockToJson).toList()
          : const [],
      'technicalAssignments':
          _isDesktop && resolvedProfile[sendAssignmentsKey] == true
              ? await _exportTechnicalAssignments()
              : const {'customers': {}, 'devices': {}},
    };
  }

  Future<LanSyncResult> sendBundle({
    required String host,
    int port = defaultPort,
    Map<String, bool>? profile,
  }) async {
    _requirePrimaryTechnician();
    final resolvedProfile = profile ?? await outboundProfile();
    if (!resolvedProfile.values.any((value) => value)) {
      throw Exception(
        'Gonderim profili bos. Senkron icin en az bir veri tipi secilmeli.',
      );
    }
    final access = await requestAccess(host: host, port: port);
    if (!access) {
      throw Exception(
        'Desktop merkez teknisyen erisimini henuz onaylamadi.',
      );
    }

    final bundle = await buildSyncBundle(profile: resolvedProfile);
    final uri = Uri.parse('http://$host:$port/api/sync');
    final response = await http
        .post(
          uri,
          headers: {'content-type': 'application/json; charset=utf-8'},
          body: jsonEncode(bundle),
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Merkez yaniti basarisiz: ${response.statusCode}');
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes));
    final outboundBundle = body['outboundBundle'];
    if (outboundBundle is Map<String, dynamic>) {
      await importBundle(outboundBundle, requireApproval: false);
    } else if (outboundBundle is Map) {
      await importBundle(
        outboundBundle.map((key, value) => MapEntry(key.toString(), value)),
        requireApproval: false,
      );
    }
    return LanSyncResult.fromJson(body['result'] as Map<String, dynamic>);
  }

  Future<LanSyncResult> importBundle(
    Map<String, dynamic> bundle, {
    bool requireApproval = true,
  }) async {
    if (bundle['protocol'] != 'fejox-bioserv-lan-sync') {
      throw Exception('Bu dosya Fejox BioServ LAN senkron paketi degil.');
    }
    if (requireApproval && !await isBundleTechnicianApproved(bundle)) {
      await registerPendingAccess(bundle);
      throw Exception('Teknisyen desktop merkezde onay bekliyor.');
    }

    var customersAdded = 0;
    var devicesAdded = 0;
    var serviceFormsAdded = 0;
    var maintenanceFormsAdded = 0;
    var faultTicketsAdded = 0;
    var companyInfoAdded = 0;
    var expensesAdded = 0;
    var expenseReportsAdded = 0;
    var stocksAdded = 0;
    var recordsUpdated = 0;
    var skipped = 0;
    final warnings = <String>[];
    final reviewItems = <LanSyncReviewItem>[];
    final technicianName = _bundleTechnicianName(bundle);
    final sourceDevice =
        bundle['sourceDevice']?.toString() ?? Platform.localHostname;

    final companyInfoMap = bundle['companyInfo'];
    if (companyInfoMap is Map && _dbService.companyInfoBox.isEmpty) {
      final mapped = companyInfoMap.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      await _dbService.companyInfoBox.add(_companyInfoFromJson(mapped));
      companyInfoAdded++;
    }

    for (final item in _listOfMaps(bundle['customers'])) {
      final name = _string(item['name']);
      if (name.isEmpty) {
        skipped++;
        warnings.add('Isimsiz musteri kaydi atlandi.');
        continue;
      }
      if (_findCustomer(name) != null) {
        skipped++;
        continue;
      }
      await _dbService.customersBox.add(_customerFromJson(item));
      customersAdded++;
    }

    for (final item in _listOfMaps(bundle['devices'])) {
      final serialNumber = _string(item['serialNumber']);
      if (serialNumber.isEmpty) {
        skipped++;
        warnings.add('Seri numarasi olmayan cihaz kaydi atlandi.');
        continue;
      }
      if (_findDevice(serialNumber) != null) {
        skipped++;
        continue;
      }
      final importedDevice = _deviceFromJson(item);
      await _dbService.devicesBox.add(importedDevice);
      devicesAdded++;
      reviewItems.add(
        LanSyncReviewItem(
          id: 'device:$serialNumber:${DateTime.now().microsecondsSinceEpoch}',
          type: 'device',
          title: importedDevice.name,
          subtitle: [
            importedDevice.brand,
            importedDevice.model,
            if (item['customerName'] != null) item['customerName'].toString(),
          ].where((part) => part.trim().isNotEmpty).join(' - '),
          identifier: serialNumber,
          technicianName: technicianName,
          sourceDevice: sourceDevice,
          importedAt: DateTime.now(),
        ),
      );
    }

    for (final item in _listOfMaps(bundle['serviceForms'])) {
      final formNumber = _string(item['formNumber']);
      if (formNumber.isEmpty || _findServiceForm(formNumber) != null) {
        skipped++;
        continue;
      }
      final form = await _serviceFormFromJson(item, warnings);
      if (form == null) {
        skipped++;
        continue;
      }
      await _dbService.serviceFormsBox.add(form);
      serviceFormsAdded++;
    }

    for (final item in _listOfMaps(bundle['maintenanceForms'])) {
      final formNumber = _string(item['formNumber']);
      if (formNumber.isEmpty || _findMaintenanceForm(formNumber) != null) {
        skipped++;
        continue;
      }
      final form = await _maintenanceFormFromJson(item, warnings);
      if (form == null) {
        skipped++;
        continue;
      }
      await _dbService.maintenanceFormsBox.add(form);
      maintenanceFormsAdded++;
    }

    for (final item in _listOfMaps(bundle['faultTickets'])) {
      final ticketNumber = _string(item['ticketNumber']);
      if (ticketNumber.isEmpty) {
        skipped++;
        continue;
      }
      final existingTicket = _findFaultTicket(ticketNumber);
      if (existingTicket != null) {
        final updated = await _mergeFaultTicket(
          existingTicket,
          item,
          warnings,
        );
        if (updated) {
          recordsUpdated++;
        } else {
          skipped++;
        }
        continue;
      }
      final ticket = _faultTicketFromJson(item, warnings);
      if (ticket == null) {
        skipped++;
        continue;
      }
      await _dbService.faultTicketsBox.add(ticket);
      faultTicketsAdded++;
    }

    for (final item in _listOfMaps(bundle['expenses'])) {
      final existingExpense = _findExpense(item);
      if (existingExpense != null) {
        await _mergeExpense(existingExpense, item);
        skipped++;
        continue;
      }
      final expense = _expenseFromJson(item);
      await _dbService.expensesBox.add(expense);
      expensesAdded++;
    }

    for (final item in _listOfMaps(bundle['expenseReports'])) {
      final reportNumber = _string(item['reportNumber']);
      if (reportNumber.isEmpty) {
        skipped++;
        continue;
      }
      final existingReport = _findExpenseReport(reportNumber);
      if (existingReport != null) {
        await _mergeExpenseReport(existingReport, item, warnings);
        skipped++;
        continue;
      }
      final report = await _expenseReportFromJson(item, warnings);
      if (report == null) {
        skipped++;
        continue;
      }
      await _dbService.expenseReportsBox.add(report);
      expenseReportsAdded++;
    }

    for (final item in _listOfMaps(bundle['stocks'])) {
      if (_findStock(item) != null) {
        skipped++;
        continue;
      }
      final stock = _stockFromJson(item);
      await _dbService.stocksBox.add(stock);
      stocksAdded++;
      reviewItems.add(
        LanSyncReviewItem(
          id: 'stock:${stock.name}:${DateTime.now().microsecondsSinceEpoch}',
          type: 'stock',
          title: stock.name,
          subtitle: [
            if ((stock.barcode ?? '').trim().isNotEmpty)
              'Barkod ${stock.barcode}',
            if ((stock.referenceNo ?? '').trim().isNotEmpty)
              'Ref ${stock.referenceNo}',
            'Adet ${stock.quantity}',
          ].join(' - '),
          identifier: stock.barcode ?? stock.referenceNo ?? stock.name,
          technicianName: technicianName,
          sourceDevice: sourceDevice,
          importedAt: DateTime.now(),
        ),
      );
    }

    final assignments = bundle['technicalAssignments'];
    if (assignments is Map) {
      await _importTechnicalAssignments(
        assignments.map((key, value) => MapEntry(key.toString(), value)),
      );
    }

    if (reviewItems.isNotEmpty) {
      await _appendReviewItems(reviewItems);
    }

    return LanSyncResult(
      companyInfoAdded: companyInfoAdded,
      customersAdded: customersAdded,
      devicesAdded: devicesAdded,
      serviceFormsAdded: serviceFormsAdded,
      maintenanceFormsAdded: maintenanceFormsAdded,
      faultTicketsAdded: faultTicketsAdded,
      expensesAdded: expensesAdded,
      expenseReportsAdded: expenseReportsAdded,
      stocksAdded: stocksAdded,
      recordsUpdated: recordsUpdated,
      skipped: skipped,
      warnings: warnings,
    );
  }

  Future<Map<String, dynamic>> buildAssignedBundleForTechnician(
    String technicianId,
  ) async {
    final identity = await _deviceIdentityService.resolve();
    final profile = await syncProfile();
    final allAssignments = await _exportTechnicalAssignments();
    final assignmentMap = _assignmentMapForTechnician(
      allAssignments,
      technicianId,
    );
    final assignedDeviceSerials =
        (assignmentMap['devices'] as Map).keys.map((e) => e.toString()).toSet();
    final assignedCustomerNames = (assignmentMap['customers'] as Map)
        .keys
        .map((e) => e.toString())
        .toSet();
    final assignedTechnician =
        _dbService.techniciansBox.values.cast<Technician?>().firstWhere(
              (technician) =>
                  technician != null &&
                  technicianAccessId(technician) == technicianId,
              orElse: () => null,
            );
    final companyInfo = _dbService.companyInfoBox.values.isNotEmpty
        ? _dbService.companyInfoBox.values.first
        : null;

    final tickets = _dbService.faultTicketsBox.values.where((ticket) {
      return ticket.assignedTechnicianId == technicianId ||
          assignedDeviceSerials.contains(ticket.device.serialNumber) ||
          assignedCustomerNames.contains(ticket.customer.name);
    }).toList();

    final devices = <Device>{};
    final customers = <Customer>{};
    for (final ticket in tickets) {
      _addDeviceFamily(devices, customers, ticket.device);
      customers.add(ticket.customer);
    }
    for (final device in _dbService.devicesBox.values) {
      final customer = device.customer;
      if (assignedDeviceSerials.contains(device.serialNumber) ||
          (customer is Customer &&
              assignedCustomerNames.contains(customer.name))) {
        _addDeviceFamily(devices, customers, device);
        if (customer is Customer) customers.add(customer);
      }
    }

    final assignedTicketNumbers =
        tickets.map((ticket) => ticket.ticketNumber).toSet();

    final serviceForms = _dbService.serviceFormsBox.values.where((form) {
      return assignedDeviceSerials.contains(form.device.serialNumber) ||
          assignedCustomerNames.contains(form.customer.name) ||
          (form.sourceTicketNumber != null &&
              assignedTicketNumbers.contains(form.sourceTicketNumber));
    }).toList();

    final maintenanceForms =
        _dbService.maintenanceFormsBox.values.where((form) {
      return assignedDeviceSerials.contains(form.device.serialNumber) ||
          assignedCustomerNames.contains(form.customer.name);
    }).toList();

    final expenseReports = _dbService.expenseReportsBox.values.where((report) {
      final sameTechnician =
          technicianAccessId(report.technician) == technicianId;
      if (sameTechnician) return true;

      final linkedExpenses = report.expenseKeys
          .map((key) => _dbService.expensesBox.get(key))
          .whereType<Expense>();
      return linkedExpenses.any((expense) {
        return assignedDeviceSerials.contains(expense.device?.serialNumber) ||
            assignedCustomerNames.contains(expense.customer?.name);
      });
    }).toList();

    final reportNumbers =
        expenseReports.map((report) => report.reportNumber).toSet();
    final expenses = _dbService.expensesBox.values.where((expense) {
      return reportNumbers.contains(expense.reportNumber) ||
          assignedDeviceSerials.contains(expense.device?.serialNumber) ||
          assignedCustomerNames.contains(expense.customer?.name);
    }).toList();

    return {
      'protocol': 'fejox-bioserv-lan-sync',
      'version': 1,
      'sourceDevice': identity.deviceName,
      'deviceId': identity.deviceId,
      'macAddress': identity.macAddress,
      'generatedAt': DateTime.now().toIso8601String(),
      'technicianId': technicianId,
      'technician': assignedTechnician == null
          ? null
          : _technicianToJson(assignedTechnician),
      'companyInfo':
          profile[syncIncludeCompanyInfoKey] == true && companyInfo != null
              ? _companyInfoToJson(companyInfo)
              : null,
      'customers': profile[syncIncludeCustomersKey] == true
          ? customers.map(_customerToJson).toList()
          : const [],
      'devices': profile[syncIncludeDevicesKey] == true
          ? devices.map(_deviceToJson).toList()
          : const [],
      'serviceForms': profile[syncIncludeServiceFormsKey] == true
          ? serviceForms.map(_serviceFormToJson).toList()
          : const [],
      'maintenanceForms': profile[syncIncludeMaintenanceFormsKey] == true
          ? maintenanceForms.map(_maintenanceFormToJson).toList()
          : const [],
      'faultTickets': profile[syncIncludeFaultTicketsKey] == true
          ? tickets.map(_faultTicketToJson).toList()
          : const [],
      'expenses': profile[syncIncludeExpensesKey] == true
          ? expenses.map(_expenseToJson).toList()
          : const [],
      'expenseReports': profile[syncIncludeExpensesKey] == true
          ? expenseReports.map(_expenseReportToJson).toList()
          : const [],
      'stocks': profile[syncIncludeStocksKey] == true
          ? _dbService.stocksBox.values.map(_stockToJson).toList()
          : const [],
      'technicalAssignments': profile[syncIncludeAssignmentsKey] == true
          ? assignmentMap
          : const {'customers': {}, 'devices': {}},
    };
  }

  Future<bool> requestAccess({
    required String host,
    int port = defaultPort,
  }) async {
    _requirePrimaryTechnician();
    final bundle = await buildSyncBundle();
    final uri = Uri.parse('http://$host:$port/api/access-request');
    final response = await http
        .post(
          uri,
          headers: {'content-type': 'application/json; charset=utf-8'},
          body: jsonEncode({
            'protocol': 'fejox-bioserv-lan-sync',
            'technicianId': bundle['technicianId'],
            'technician': bundle['technician'],
            'sourceDevice': bundle['sourceDevice'],
            'deviceId': bundle['deviceId'],
            'macAddress': bundle['macAddress'],
            'requestedAt': DateTime.now().toIso8601String(),
          }),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == HttpStatus.forbidden) return false;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Erisim istegi basarisiz: ${response.statusCode}');
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes));
    return body['approved'] == true;
  }

  Future<bool> isBundleTechnicianApproved(Map<String, dynamic> bundle) async {
    final technicianId = bundle['technicianId']?.toString();
    if (technicianId == null || technicianId.isEmpty) return false;
    return isTechnicianApproved(
      technicianId,
      deviceId:
          bundle['deviceId']?.toString() ?? bundle['macAddress']?.toString(),
    );
  }

  Future<bool> isTechnicianApproved(
    String technicianId, {
    String? deviceId,
  }) async {
    final prefs = await _prefsBox();
    final approved = _stringMap(prefs.get(_approvedAccessKey));
    final accessKey = _approvalKey(technicianId, deviceId);
    return approved.containsKey(accessKey);
  }

  Future<List<LanAccessRequest>> pendingAccessRequests() async {
    final prefs = await _prefsBox();
    final pending = _stringMap(prefs.get(_pendingAccessKey));
    final approved = _stringMap(prefs.get(_approvedAccessKey));
    return pending.entries
        .where((entry) => !approved.containsKey(entry.key))
        .map((entry) => LanAccessRequest.fromJson(
              Map<String, dynamic>.from(entry.value as Map),
            ))
        .toList()
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
  }

  Future<void> approveAccess(String accessKey) async {
    final prefs = await _prefsBox();
    final pending = _stringMap(prefs.get(_pendingAccessKey));
    final approved = _stringMap(prefs.get(_approvedAccessKey));
    final request = pending[accessKey];
    if (request != null) {
      approved[accessKey] = request;
      pending.remove(accessKey);
      await prefs.put(_approvedAccessKey, approved);
      await prefs.put(_pendingAccessKey, pending);
      await _ensureTechnicianExists(
        LanAccessRequest.fromJson(
          Map<String, dynamic>.from(request as Map),
        ),
      );
    }
  }

  Future<void> rejectAccess(String accessKey) async {
    final prefs = await _prefsBox();
    final pending = _stringMap(prefs.get(_pendingAccessKey));
    pending.remove(accessKey);
    await prefs.put(_pendingAccessKey, pending);
  }

  Future<void> ensureTechnicianForAccessRequest(
    LanAccessRequest request,
  ) {
    return _ensureTechnicianExists(request);
  }

  Future<List<LanSyncReviewItem>> reviewItems({
    bool includeReviewed = false,
  }) async {
    final prefs = await _prefsBox();
    final raw = prefs.get(_reviewItemsKey) as List<dynamic>? ?? const [];
    final items = raw
        .whereType<Map>()
        .map(
          (item) => LanSyncReviewItem.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .where((item) => includeReviewed || !item.reviewed)
        .toList()
      ..sort((a, b) => b.importedAt.compareTo(a.importedAt));
    return items;
  }

  Future<void> markReviewItemReviewed(String id) async {
    final prefs = await _prefsBox();
    final raw = prefs.get(_reviewItemsKey) as List<dynamic>? ?? const [];
    final updated = raw.whereType<Map>().map((item) {
      final mapped = item.map((key, value) => MapEntry(key.toString(), value));
      final reviewItem = LanSyncReviewItem.fromJson(mapped);
      return (reviewItem.id == id
              ? reviewItem.copyWith(reviewed: true)
              : reviewItem)
          .toJson();
    }).toList();
    await prefs.put(_reviewItemsKey, updated);
  }

  Future<void> clearReviewedItems() async {
    final prefs = await _prefsBox();
    final raw = prefs.get(_reviewItemsKey) as List<dynamic>? ?? const [];
    final updated = raw
        .whereType<Map>()
        .map(
          (item) => LanSyncReviewItem.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .where((item) => !item.reviewed)
        .map((item) => item.toJson())
        .toList();
    await prefs.put(_reviewItemsKey, updated);
  }

  Future<void> registerPendingAccess(Map<String, dynamic> bundle) async {
    final request = _accessRequestFromPayload(bundle);
    if (request == null) return;
    if (await isTechnicianApproved(
      request.technicianId,
      deviceId: request.deviceId,
    )) {
      return;
    }

    final prefs = await _prefsBox();
    final pending = _stringMap(prefs.get(_pendingAccessKey));
    pending[request.accessKey] = request.toJson();
    await prefs.put(_pendingAccessKey, pending);
    onAccessRequest?.call();
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      try {
        await _handleRequest(request);
      } catch (e, stack) {
        debugPrint('LAN sync request error: $e');
        debugPrint('$stack');
        _writeJson(request.response, HttpStatus.internalServerError, {
          'ok': false,
          'error': e.toString(),
        });
      }
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    _addCorsHeaders(request.response);

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    if (request.method == 'GET' && request.uri.path == '/health') {
      final identity = await _deviceIdentityService.resolve();
      _writeJson(request.response, HttpStatus.ok, {
        'ok': true,
        'protocol': healthProtocol,
        'app': 'Biomed Servis',
        'host': identity.deviceName,
        'port': activePort ?? defaultPort,
        'deviceId': identity.deviceId,
        'macAddress': identity.macAddress,
        'time': DateTime.now().toIso8601String(),
      });
      return;
    }

    if (request.method == 'POST' && request.uri.path == '/api/access-request') {
      final content = await utf8.decoder.bind(request).join();
      final payload = jsonDecode(content) as Map<String, dynamic>;
      payload['sourceIp'] = request.connectionInfo?.remoteAddress.address;
      await registerPendingAccess(payload);
      final technicianId = payload['technicianId']?.toString() ?? '';
      final approved = await isTechnicianApproved(
        technicianId,
        deviceId: payload['deviceId']?.toString() ??
            payload['macAddress']?.toString(),
      );
      _writeJson(
        request.response,
        approved ? HttpStatus.ok : HttpStatus.forbidden,
        {
          'ok': approved,
          'approved': approved,
          'message': approved
              ? 'Teknisyen onayli.'
              : 'Teknisyen desktop merkezde onay bekliyor.',
        },
      );
      return;
    }

    if (request.method == 'POST' && request.uri.path == '/api/sync') {
      final content = await utf8.decoder.bind(request).join();
      final payload = jsonDecode(content) as Map<String, dynamic>;
      final result = await importBundle(payload);
      final technicianId = payload['technicianId']?.toString();
      final outboundBundle = technicianId == null || technicianId.isEmpty
          ? null
          : await buildAssignedBundleForTechnician(technicianId);
      onImport?.call(result);
      _writeJson(request.response, HttpStatus.ok, {
        'ok': true,
        'result': result.toJson(),
        'outboundBundle': outboundBundle,
      });
      return;
    }

    _writeJson(request.response, HttpStatus.notFound, {
      'ok': false,
      'error': 'Endpoint bulunamadi.',
    });
  }

  void _addCorsHeaders(HttpResponse response) {
    response.headers.set('access-control-allow-origin', '*');
    response.headers.set('access-control-allow-methods', 'GET, POST, OPTIONS');
    response.headers.set('access-control-allow-headers', 'content-type');
  }

  void _writeJson(
    HttpResponse response,
    int statusCode,
    Map<String, dynamic> body,
  ) {
    response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    unawaited(response.close());
  }

  Map<String, dynamic> _technicianToJson(Technician technician) => {
        'firstName': technician.firstName,
        'lastName': technician.lastName,
        'fullName': technician.fullName,
        'phone': technician.phone,
        'email': technician.email,
        'title': technician.title,
        'address': technician.address,
      };

  Map<String, dynamic> _companyInfoToJson(CompanyInfo companyInfo) => {
        'companyName': companyInfo.companyName,
        'taxNumber': companyInfo.taxNumber,
        'taxOffice': companyInfo.taxOffice,
        'address': companyInfo.address,
        'phone': companyInfo.phone,
        'email': companyInfo.email,
        'website': companyInfo.website,
      };

  String _bundleTechnicianName(Map<String, dynamic> bundle) {
    final technicianMap = bundle['technician'];
    if (technicianMap is! Map) return 'Bilinmeyen teknisyen';
    final fullName = technicianMap['fullName']?.toString().trim() ?? '';
    if (fullName.isNotEmpty) return fullName;
    final firstName = technicianMap['firstName']?.toString().trim() ?? '';
    final lastName = technicianMap['lastName']?.toString().trim() ?? '';
    final fallback = '$firstName $lastName'.trim();
    return fallback.isEmpty ? 'Bilinmeyen teknisyen' : fallback;
  }

  Future<void> _appendReviewItems(List<LanSyncReviewItem> items) async {
    final prefs = await _prefsBox();
    final existing = await reviewItems(includeReviewed: true);
    final merged = [...items, ...existing]
        .fold<Map<String, LanSyncReviewItem>>({}, (map, item) {
          final key = '${item.type}:${item.identifier ?? item.title}';
          map[key] = item;
          return map;
        })
        .values
        .toList()
      ..sort((a, b) => b.importedAt.compareTo(a.importedAt));
    final capped = merged.take(60).map((item) => item.toJson()).toList();
    await prefs.put(_reviewItemsKey, capped);
  }

  LanAccessRequest? _accessRequestFromPayload(Map<String, dynamic> payload) {
    final technicianMap = payload['technician'];
    if (technicianMap is! Map) return null;
    final technicianId = payload['technicianId']?.toString() ??
        technicianAccessIdFromFields(
          firstName: technicianMap['firstName']?.toString() ?? '',
          lastName: technicianMap['lastName']?.toString() ?? '',
          phone: technicianMap['phone']?.toString(),
          email: technicianMap['email']?.toString(),
        );
    if (technicianId.isEmpty) return null;
    return LanAccessRequest(
      technicianId: technicianId,
      technicianName: technicianMap['fullName']?.toString() ??
          '${technicianMap['firstName'] ?? ''} ${technicianMap['lastName'] ?? ''}'
              .trim(),
      title: technicianMap['title']?.toString(),
      phone: technicianMap['phone']?.toString(),
      email: technicianMap['email']?.toString(),
      sourceDevice:
          payload['sourceDevice']?.toString() ?? Platform.localHostname,
      deviceId: payload['deviceId']?.toString() ??
          payload['macAddress']?.toString() ??
          'LEGACY',
      macAddress: payload['macAddress']?.toString(),
      sourceIp: payload['sourceIp']?.toString(),
      requestedAt:
          DateTime.tryParse(payload['requestedAt']?.toString() ?? '') ??
              DateTime.now(),
    );
  }

  String _approvalKey(String technicianId, String? deviceId) {
    final cleanDeviceId = deviceId?.trim() ?? '';
    if (cleanDeviceId.isEmpty || cleanDeviceId == 'LEGACY') {
      return technicianId;
    }
    return '$technicianId::$cleanDeviceId';
  }

  Map<String, dynamic> _customerToJson(Customer customer) => {
        'name': customer.name,
        'address': customer.address,
        'phone': customer.phone,
        'authorizedPerson': customer.authorizedPerson,
        'email': customer.email,
        'vergiNo': customer.vergiNo,
        'isActive': customer.isActive,
        'unitManagerName': customer.unitManagerName,
        'unitManagerPhone': customer.unitManagerPhone,
        'unitResponsibleName': customer.unitResponsibleName,
        'unitResponsiblePhone': customer.unitResponsiblePhone,
      };

  Map<String, dynamic> _deviceToJson(Device device) => {
        'name': device.name,
        'brand': device.brand,
        'model': device.model,
        'serialNumber': device.serialNumber,
        'customerName': (device.customer is Customer)
            ? (device.customer! as Customer).name
            : null,
        'productionDate': _dateToJson(device.productionDate),
        'installationDate': _dateToJson(device.installationDate),
        'economicLife': device.economicLife,
        'group': device.group,
        'barcode': device.barcode,
        'moduleType': device.moduleType.name,
        'ownershipStatus': device.ownershipStatus.name,
        'controlSerialNumber': (device.controlModule is Device)
            ? (device.controlModule! as Device).serialNumber
            : null,
        'serviceDuration': device.serviceDuration,
        'warrantyStartDate': _dateToJson(device.warrantyStartDate),
        'warrantyEndDate': _dateToJson(device.warrantyEndDate),
        'location': device.location,
        'deviceCategory': device.deviceCategory,
      };

  void _addDeviceFamily(
    Set<Device> devices,
    Set<Customer> customers,
    Device device,
  ) {
    final root = _rootDeviceFor(device);
    final rootSerial = root.serialNumber.trim().toLowerCase();

    void add(Device item) {
      devices.add(item);
      final customer = item.customer;
      if (customer is Customer) {
        customers.add(customer);
      }
    }

    add(root);

    for (final candidate in _dbService.devicesBox.values) {
      if (identical(candidate, root)) continue;
      final control = candidate.controlModule;
      if (candidate.isProcessingModule &&
          control is Device &&
          control.serialNumber.trim().toLowerCase() == rootSerial) {
        add(candidate);
      }
    }
  }

  Device _rootDeviceFor(Device device) {
    if (device.isProcessingModule && device.controlModule is Device) {
      return device.controlModule! as Device;
    }
    return device;
  }

  Map<String, dynamic> _serviceFormToJson(ServiceForm form) => {
        'formNumber': form.formNumber,
        'createdAt': form.createdAt.toIso8601String(),
        'customerName': form.customer.name,
        'deviceSerialNumber': form.device.serialNumber,
        'problemDescription': form.problemDescription,
        'actionsTaken': form.actionsTaken,
        'finalStatus': form.finalStatus,
        'problemTypes': form.problemTypes,
        'resultStatus': form.resultStatus,
        'feeStatus': form.feeStatus,
        'problemDateTime': _dateToJson(form.problemDateTime),
        'interventionDateTime': _dateToJson(form.interventionDateTime),
        'solutionDateTime': _dateToJson(form.solutionDateTime),
        'travelHours': form.travelHours,
        'repairHours': form.repairHours,
        'trainingHours': form.trainingHours,
        'assemblyHours': form.assemblyHours,
        'modificationHours': form.modificationHours,
        'totalFee': form.totalFee,
        'totalFeeWithVAT': form.totalFeeWithVAT,
        'technicianSignature': form.technicianSignature,
        'customerSignature': form.customerSignature,
        'technicianName': form.technicianName,
        'customerDisplayName': form.customerName,
        'sourceTicketNumber': form.sourceTicketNumber,
        'partsUsed': form.partsUsed.map(_stockToJson).toList(),
      };

  Map<String, dynamic> _maintenanceFormToJson(MaintenanceForm form) => {
        'formNumber': form.formNumber,
        'createdAt': form.createdAt.toIso8601String(),
        'customerName': form.customer.name,
        'deviceSerialNumber': form.device.serialNumber,
        'maintenancePeriod': form.maintenancePeriod,
        'actionsTaken': form.actionsTaken,
        'notes': form.notes,
        'finalStatus': form.finalStatus,
        'technicianSignature': form.technicianSignature,
        'customerSignature': form.customerSignature,
        'technicianName': form.technicianName,
        'customerDisplayName': form.customerName,
        'partsUsed': form.partsUsed.map(_stockToJson).toList(),
      };

  Map<String, dynamic> _faultTicketToJson(FaultTicket ticket) => {
        'ticketNumber': ticket.ticketNumber,
        'customerName': ticket.customer.name,
        'deviceSerialNumber': ticket.device.serialNumber,
        'technicianName': ticket.technicianName ?? ticket.technician?.fullName,
        'reportDateTime': ticket.reportDateTime.toIso8601String(),
        'startDateTime': _dateToJson(ticket.startDateTime),
        'endDateTime': _dateToJson(ticket.endDateTime),
        'ticketType': ticket.ticketType.name,
        'problemDescription': ticket.problemDescription,
        'actionsTaken': ticket.actionsTaken,
        'status': ticket.status.name,
        'finalStatus': ticket.finalStatus,
        'technicianSignature': ticket.technicianSignature,
        'responsibleName': ticket.responsibleName,
        'responsibleSignature': ticket.responsibleSignature,
        'createdAt': ticket.createdAt.toIso8601String(),
        'updatedAt': _dateToJson(ticket.updatedAt),
        'serviceFormNumber': ticket.serviceFormNumber,
        'assignedTechnicianId': ticket.assignedTechnicianId,
        'priority': ticket.priority,
        'scheduledAt': _dateToJson(ticket.scheduledAt),
      };

  Map<String, dynamic> _expenseToJson(Expense expense) => {
        'date': expense.date.toIso8601String(),
        'description': expense.description,
        'amount': expense.amount,
        'customerName': expense.customer?.name,
        'deviceSerialNumber': expense.device?.serialNumber,
        'status': expense.status.name,
        'collectionType': expense.collectionType?.name,
        'collectionDate': _dateToJson(expense.collectionDate),
        'collectionNote': expense.collectionNote,
        'createdAt': expense.createdAt.toIso8601String(),
        'reportedAt': _dateToJson(expense.reportedAt),
        'reportNumber': expense.reportNumber,
      };

  Map<String, dynamic> _expenseReportToJson(ExpenseReport report) => {
        'reportNumber': report.reportNumber,
        'createdAt': report.createdAt.toIso8601String(),
        'technician': _technicianToJson(report.technician),
        'totalAmount': report.totalAmount,
        'isCollected': report.isCollected,
        'collectionType': report.collectionType?.name,
        'collectionDate': _dateToJson(report.collectionDate),
        'collectionNote': report.collectionNote,
        'notes': report.notes,
        'collectedAmount': report.collectedAmount,
      };

  Map<String, dynamic> _stockToJson(Stock stock) => {
        'name': stock.name,
        'quantity': stock.quantity,
        'barcode': stock.barcode,
        'referenceNo': stock.referenceNo,
        'criticalStockThreshold': stock.criticalStockThreshold,
      };

  Stock _stockFromJson(Map<String, dynamic> json) => Stock(
        name: _string(json['name']),
        quantity: json['quantity'] as int? ?? 0,
        barcode: _nullableString(json['barcode']),
        referenceNo: _nullableString(json['referenceNo']),
        criticalStockThreshold: json['criticalStockThreshold'] as int? ?? 10,
      );

  Customer _customerFromJson(Map<String, dynamic> json) => Customer(
        name: _string(json['name']),
        address: _string(json['address']),
        phone: _string(json['phone']),
        authorizedPerson: _string(json['authorizedPerson']),
        email: _nullableString(json['email']),
        vergiNo: _nullableString(json['vergiNo']),
        isActive: json['isActive'] as bool? ?? true,
        unitManagerName: _nullableString(json['unitManagerName']),
        unitManagerPhone: _nullableString(json['unitManagerPhone']),
        unitResponsibleName: _nullableString(json['unitResponsibleName']),
        unitResponsiblePhone: _nullableString(json['unitResponsiblePhone']),
      );

  CompanyInfo _companyInfoFromJson(Map<String, dynamic> json) => CompanyInfo(
        companyName: _string(json['companyName']),
        taxNumber: _nullableString(json['taxNumber']),
        taxOffice: _nullableString(json['taxOffice']),
        address: _nullableString(json['address']),
        phone: _nullableString(json['phone']),
        email: _nullableString(json['email']),
        website: _nullableString(json['website']),
      );

  Device _deviceFromJson(Map<String, dynamic> json) {
    final controlSerialNumber = _nullableString(json['controlSerialNumber']);
    return Device(
      name: _string(json['name']),
      brand: _string(json['brand']),
      model: _string(json['model']),
      serialNumber: _string(json['serialNumber']),
      customer: _findCustomer(_string(json['customerName'])),
      productionDate: _dateFromJson(json['productionDate']),
      installationDate: _dateFromJson(json['installationDate']),
      economicLife: json['economicLife'] as int?,
      group: _nullableString(json['group']),
      barcode: _nullableString(json['barcode']),
      moduleType: _deviceModuleTypeFromName(_string(json['moduleType'])),
      ownershipStatus:
          _ownershipStatusFromName(_string(json['ownershipStatus'])),
      controlModule:
          controlSerialNumber == null ? null : _findDevice(controlSerialNumber),
      serviceDuration: json['serviceDuration'] as int?,
      warrantyStartDate: _dateFromJson(json['warrantyStartDate']),
      warrantyEndDate: _dateFromJson(json['warrantyEndDate']),
      location: _nullableString(json['location']),
      deviceCategory: _nullableString(json['deviceCategory']),
    );
  }

  Future<ServiceForm?> _serviceFormFromJson(
    Map<String, dynamic> json,
    List<String> warnings,
  ) async {
    final customer = _findCustomer(_string(json['customerName']));
    final device = _findDevice(_string(json['deviceSerialNumber']));
    if (customer == null || device == null) {
      warnings.add(
          'Servis formu ${json['formNumber']} icin musteri/cihaz bulunamadi.');
      return null;
    }

    return ServiceForm(
      formNumber: _string(json['formNumber']),
      createdAt: _dateFromJson(json['createdAt']) ?? DateTime.now(),
      customer: customer,
      device: device,
      problemDescription: _nullableString(json['problemDescription']),
      actionsTaken: _nullableString(json['actionsTaken']),
      finalStatus: _nullableString(json['finalStatus']),
      problemTypes: _listOfStrings(json['problemTypes']),
      resultStatus: _nullableString(json['resultStatus']),
      feeStatus: _nullableString(json['feeStatus']),
      problemDateTime: _dateFromJson(json['problemDateTime']),
      interventionDateTime: _dateFromJson(json['interventionDateTime']),
      solutionDateTime: _dateFromJson(json['solutionDateTime']),
      travelHours: json['travelHours'] as int?,
      repairHours: json['repairHours'] as int?,
      trainingHours: json['trainingHours'] as int?,
      assemblyHours: json['assemblyHours'] as int?,
      modificationHours: json['modificationHours'] as int?,
      totalFee: _doubleFromJson(json['totalFee']),
      totalFeeWithVAT: _doubleFromJson(json['totalFeeWithVAT']),
      partsUsed: await _partsFromJson(json['partsUsed']),
      technicianSignature: _nullableString(json['technicianSignature']),
      customerSignature: _nullableString(json['customerSignature']),
      technicianName: _nullableString(json['technicianName']),
      customerName: _nullableString(json['customerDisplayName']),
      sourceTicketNumber: _nullableString(json['sourceTicketNumber']),
    );
  }

  Future<MaintenanceForm?> _maintenanceFormFromJson(
    Map<String, dynamic> json,
    List<String> warnings,
  ) async {
    final customer = _findCustomer(_string(json['customerName']));
    final device = _findDevice(_string(json['deviceSerialNumber']));
    if (customer == null || device == null) {
      warnings.add(
          'Bakim formu ${json['formNumber']} icin musteri/cihaz bulunamadi.');
      return null;
    }

    return MaintenanceForm(
      formNumber: _string(json['formNumber']),
      createdAt: _dateFromJson(json['createdAt']) ?? DateTime.now(),
      customer: customer,
      device: device,
      maintenancePeriod: _string(json['maintenancePeriod']),
      actionsTaken: _listOfStrings(json['actionsTaken']),
      notes: _nullableString(json['notes']),
      partsUsed: await _partsFromJson(json['partsUsed']),
      finalStatus: _nullableString(json['finalStatus']),
      technicianSignature: _nullableString(json['technicianSignature']),
      customerSignature: _nullableString(json['customerSignature']),
      technicianName: _nullableString(json['technicianName']),
      customerName: _nullableString(json['customerDisplayName']),
    );
  }

  FaultTicket? _faultTicketFromJson(
    Map<String, dynamic> json,
    List<String> warnings,
  ) {
    final customer = _findCustomer(_string(json['customerName']));
    final device = _findDevice(_string(json['deviceSerialNumber']));
    if (customer == null || device == null) {
      warnings.add(
          'Ariza kaydi ${json['ticketNumber']} icin musteri/cihaz bulunamadi.');
      return null;
    }

    return FaultTicket(
      ticketNumber: _string(json['ticketNumber']),
      customer: customer,
      device: device,
      reportDateTime: _dateFromJson(json['reportDateTime']) ?? DateTime.now(),
      startDateTime: _dateFromJson(json['startDateTime']),
      endDateTime: _dateFromJson(json['endDateTime']),
      ticketType: _ticketTypeFromName(_string(json['ticketType'])),
      problemDescription: _string(json['problemDescription']),
      actionsTaken: _nullableString(json['actionsTaken']),
      status: _ticketStatusFromName(_string(json['status'])),
      finalStatus: _nullableString(json['finalStatus']),
      technicianSignature: _nullableString(json['technicianSignature']),
      responsibleName: _nullableString(json['responsibleName']),
      responsibleSignature: _nullableString(json['responsibleSignature']),
      createdAt: _dateFromJson(json['createdAt']) ?? DateTime.now(),
      updatedAt: _dateFromJson(json['updatedAt']),
      technicianName: _nullableString(json['technicianName']),
      serviceFormNumber: _nullableString(json['serviceFormNumber']),
      assignedTechnicianId: _nullableString(json['assignedTechnicianId']),
      priority: _nullableString(json['priority']) ?? 'normal',
      scheduledAt: _dateFromJson(json['scheduledAt']),
    );
  }

  Future<bool> _mergeFaultTicket(
    FaultTicket existing,
    Map<String, dynamic> json,
    List<String> warnings,
  ) async {
    final incomingUpdatedAt =
        _dateFromJson(json['updatedAt']) ?? _dateFromJson(json['createdAt']);
    final existingUpdatedAt = existing.updatedAt ?? existing.createdAt;
    if (incomingUpdatedAt == null ||
        !incomingUpdatedAt.isAfter(existingUpdatedAt)) {
      return false;
    }

    final customer = _findCustomer(_string(json['customerName']));
    final device = _findDevice(_string(json['deviceSerialNumber']));
    if (customer == null || device == null) {
      warnings.add(
        'Arıza kaydı ${existing.ticketNumber} güncellenemedi: kurum veya cihaz bulunamadı.',
      );
      return false;
    }

    existing
      ..customer = customer
      ..device = device
      ..reportDateTime =
          _dateFromJson(json['reportDateTime']) ?? existing.reportDateTime
      ..startDateTime = _dateFromJson(json['startDateTime'])
      ..endDateTime = _dateFromJson(json['endDateTime'])
      ..ticketType = _ticketTypeFromName(_string(json['ticketType']))
      ..problemDescription = _string(json['problemDescription'])
      ..actionsTaken = _nullableString(json['actionsTaken'])
      ..status = _ticketStatusFromName(_string(json['status']))
      ..finalStatus = _nullableString(json['finalStatus'])
      ..technicianSignature = _nullableString(json['technicianSignature'])
      ..responsibleName = _nullableString(json['responsibleName'])
      ..responsibleSignature = _nullableString(json['responsibleSignature'])
      ..updatedAt = incomingUpdatedAt
      ..technicianName = _nullableString(json['technicianName'])
      ..serviceFormNumber = _nullableString(json['serviceFormNumber'])
      ..assignedTechnicianId = _nullableString(json['assignedTechnicianId'])
      ..priority = _nullableString(json['priority']) ?? 'normal'
      ..scheduledAt = _dateFromJson(json['scheduledAt']);
    await existing.save();
    return true;
  }

  Expense _expenseFromJson(Map<String, dynamic> json) {
    return Expense(
      date: _dateFromJson(json['date']) ?? DateTime.now(),
      description: _string(json['description']),
      amount: _doubleFromJson(json['amount']) ?? 0,
      customer: _findCustomer(_string(json['customerName'])),
      device: _findDevice(_string(json['deviceSerialNumber'])),
      status: _expenseStatusFromName(_string(json['status'])),
      collectionType:
          _collectionTypeFromName(_nullableString(json['collectionType'])),
      collectionDate: _dateFromJson(json['collectionDate']),
      collectionNote: _nullableString(json['collectionNote']),
      reportedAt: _dateFromJson(json['reportedAt']),
      reportNumber: _nullableString(json['reportNumber']),
    )..createdAt = _dateFromJson(json['createdAt']) ?? DateTime.now();
  }

  Future<ExpenseReport?> _expenseReportFromJson(
    Map<String, dynamic> json,
    List<String> warnings,
  ) async {
    final reportNumber = _string(json['reportNumber']);
    if (reportNumber.isEmpty) return null;

    final technicianMap = json['technician'];
    if (technicianMap is! Map) {
      warnings.add('Masraf raporu $reportNumber icin teknisyen bilgisi yok.');
      return null;
    }

    final technician = await _ensureTechnicianFromJson(
      technicianMap.map((key, value) => MapEntry(key.toString(), value)),
    );

    final expenseKeys = _dbService.expensesBox.keys
        .whereType<int>()
        .where((key) =>
            _dbService.expensesBox.get(key)?.reportNumber == reportNumber)
        .toList();

    return ExpenseReport(
      reportNumber: reportNumber,
      technician: technician,
      expenseKeys: expenseKeys,
      totalAmount: _doubleFromJson(json['totalAmount']) ?? 0,
      isCollected: json['isCollected'] as bool? ?? false,
      collectionType:
          _collectionTypeFromName(_nullableString(json['collectionType'])),
      collectionDate: _dateFromJson(json['collectionDate']),
      collectionNote: _nullableString(json['collectionNote']),
      notes: _nullableString(json['notes']),
      collectedAmount: _doubleFromJson(json['collectedAmount']) ?? 0,
    )..createdAt = _dateFromJson(json['createdAt']) ?? DateTime.now();
  }

  Future<HiveList<Stock>> _partsFromJson(dynamic value) async {
    final parts = HiveList<Stock>(_dbService.serviceFormPartsBox);
    for (final item in _listOfMaps(value)) {
      final stock = Stock(
        name: _string(item['name']),
        quantity: item['quantity'] as int? ?? 1,
        barcode: _nullableString(item['barcode']),
        referenceNo: _nullableString(item['referenceNo']),
        criticalStockThreshold: item['criticalStockThreshold'] as int? ?? 10,
      );
      await _dbService.serviceFormPartsBox.add(stock);
      parts.add(stock);
    }
    return parts;
  }

  Customer? _findCustomer(String name) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final customer in _dbService.customersBox.values) {
      if (customer.name.trim().toLowerCase() == normalized) return customer;
    }
    return null;
  }

  Device? _findDevice(String serialNumber) {
    final normalized = serialNumber.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final device in _dbService.devicesBox.values) {
      if (device.serialNumber.trim().toLowerCase() == normalized) {
        return device;
      }
    }
    return null;
  }

  ServiceForm? _findServiceForm(String formNumber) {
    final normalized = formNumber.trim().toLowerCase();
    for (final form in _dbService.serviceFormsBox.values) {
      if (form.formNumber.trim().toLowerCase() == normalized) return form;
    }
    return null;
  }

  MaintenanceForm? _findMaintenanceForm(String formNumber) {
    final normalized = formNumber.trim().toLowerCase();
    for (final form in _dbService.maintenanceFormsBox.values) {
      if (form.formNumber.trim().toLowerCase() == normalized) return form;
    }
    return null;
  }

  FaultTicket? _findFaultTicket(String ticketNumber) {
    final normalized = ticketNumber.trim().toLowerCase();
    for (final ticket in _dbService.faultTicketsBox.values) {
      if (ticket.ticketNumber.trim().toLowerCase() == normalized) return ticket;
    }
    return null;
  }

  Expense? _findExpense(Map<String, dynamic> json) {
    final description = _string(json['description']).toLowerCase();
    final createdAt = _dateFromJson(json['createdAt']);
    final amount = _doubleFromJson(json['amount']) ?? 0;

    for (final expense in _dbService.expensesBox.values) {
      final sameCreatedAt = createdAt == null || expense.createdAt == createdAt;
      if (expense.description.trim().toLowerCase() == description &&
          expense.amount == amount &&
          sameCreatedAt) {
        return expense;
      }
    }
    return null;
  }

  Future<void> _mergeExpense(
    Expense existing,
    Map<String, dynamic> json,
  ) async {
    final incoming = _expenseFromJson(json);
    if (_expenseStatusRank(incoming.status) <
        _expenseStatusRank(existing.status)) {
      return;
    }

    existing.date = incoming.date;
    existing.description = incoming.description;
    existing.amount = incoming.amount;
    existing.customer = incoming.customer ?? existing.customer;
    existing.device = incoming.device ?? existing.device;
    existing.status = incoming.status;
    existing.reportedAt = incoming.reportedAt ?? existing.reportedAt;
    existing.reportNumber = incoming.reportNumber ?? existing.reportNumber;
    existing.collectionType =
        incoming.collectionType ?? existing.collectionType;
    existing.collectionDate =
        incoming.collectionDate ?? existing.collectionDate;
    existing.collectionNote =
        incoming.collectionNote ?? existing.collectionNote;

    final key = existing.key;
    if (key != null) {
      await _dbService.expensesBox.put(key, existing);
    }
  }

  Future<void> _mergeExpenseReport(
    ExpenseReport existing,
    Map<String, dynamic> json,
    List<String> warnings,
  ) async {
    final incoming = await _expenseReportFromJson(json, warnings);
    if (incoming == null) return;

    existing.expenseKeys = incoming.expenseKeys;
    existing.totalAmount = incoming.totalAmount;
    existing.notes = incoming.notes ?? existing.notes;

    final incomingIsNewer = incoming.isCollected ||
        incoming.collectedAmount >= existing.collectedAmount;
    if (incomingIsNewer) {
      existing.collectedAmount = incoming.collectedAmount;
      existing.isCollected = incoming.isCollected;
      existing.collectionType =
          incoming.collectionType ?? existing.collectionType;
      existing.collectionDate =
          incoming.collectionDate ?? existing.collectionDate;
      existing.collectionNote =
          incoming.collectionNote ?? existing.collectionNote;
    }

    final key = existing.key;
    if (key != null) {
      await _dbService.expenseReportsBox.put(key, existing);
    }
  }

  int _expenseStatusRank(ExpenseStatus status) {
    switch (status) {
      case ExpenseStatus.pending:
        return 0;
      case ExpenseStatus.reported:
        return 1;
      case ExpenseStatus.collected:
        return 2;
    }
  }

  ExpenseReport? _findExpenseReport(String reportNumber) {
    final normalized = reportNumber.trim().toLowerCase();
    for (final report in _dbService.expenseReportsBox.values) {
      if (report.reportNumber.trim().toLowerCase() == normalized) return report;
    }
    return null;
  }

  Stock? _findStock(Map<String, dynamic> json) {
    final barcode = _nullableString(json['barcode']);
    final referenceNo = _nullableString(json['referenceNo']);
    final name = _string(json['name']).trim().toLowerCase();

    for (final stock in _dbService.stocksBox.values) {
      if (barcode != null &&
          stock.barcode != null &&
          stock.barcode!.trim() == barcode) {
        return stock;
      }
      if (referenceNo != null &&
          stock.referenceNo != null &&
          stock.referenceNo!.trim() == referenceNo) {
        return stock;
      }
      if (name.isNotEmpty && stock.name.trim().toLowerCase() == name) {
        return stock;
      }
    }
    return null;
  }

  DeviceModuleType _deviceModuleTypeFromName(String name) {
    return DeviceModuleType.values.firstWhere(
      (value) => value.name == name,
      orElse: () => DeviceModuleType.standalone,
    );
  }

  OwnershipStatus _ownershipStatusFromName(String name) {
    return OwnershipStatus.values.firstWhere(
      (value) => value.name == name,
      orElse: () => OwnershipStatus.sold,
    );
  }

  ExpenseStatus _expenseStatusFromName(String name) {
    return ExpenseStatus.values.firstWhere(
      (value) => value.name == name,
      orElse: () => ExpenseStatus.pending,
    );
  }

  CollectionType? _collectionTypeFromName(String? name) {
    if (name == null || name.isEmpty) return null;
    for (final value in CollectionType.values) {
      if (value.name == name) return value;
    }
    return null;
  }

  TicketType _ticketTypeFromName(String name) {
    return TicketType.values.firstWhere(
      (value) => value.name == name,
      orElse: () => TicketType.malfunction,
    );
  }

  TicketStatus _ticketStatusFromName(String name) {
    return TicketStatus.values.firstWhere(
      (value) => value.name == name,
      orElse: () => TicketStatus.pending,
    );
  }

  String _string(dynamic value) => value?.toString().trim() ?? '';

  String? _nullableString(dynamic value) {
    final text = _string(value);
    return text.isEmpty ? null : text;
  }

  String? _dateToJson(DateTime? value) => value?.toIso8601String();

  DateTime? _dateFromJson(dynamic value) {
    final text = _nullableString(value);
    return text == null ? null : DateTime.tryParse(text);
  }

  double? _doubleFromJson(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  List<Map<String, dynamic>> _listOfMaps(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map(
            (item) => item.map((key, value) => MapEntry(key.toString(), value)))
        .toList();
  }

  List<String> _listOfStrings(dynamic value) {
    if (value is! List) return [];
    return value.map((item) => item.toString()).toList();
  }

  Future<Map<String, dynamic>> _exportTechnicalAssignments() async {
    final prefs = await _prefsBox();
    return {
      'customers': _stringMap(
        prefs.get(TechnicalAssignmentService.customerAssignmentsKey),
      ),
      'devices': _stringMap(
        prefs.get(TechnicalAssignmentService.deviceAssignmentsKey),
      ),
    };
  }

  Future<void> _importTechnicalAssignments(Map<String, dynamic> json) async {
    final prefs = await _prefsBox();
    final currentCustomers = _stringMap(
      prefs.get(TechnicalAssignmentService.customerAssignmentsKey),
    );
    final currentDevices = _stringMap(
      prefs.get(TechnicalAssignmentService.deviceAssignmentsKey),
    );
    currentCustomers.addAll(_stringMap(json['customers']));
    currentDevices.addAll(_stringMap(json['devices']));
    await prefs.put(
      TechnicalAssignmentService.customerAssignmentsKey,
      currentCustomers,
    );
    await prefs.put(
      TechnicalAssignmentService.deviceAssignmentsKey,
      currentDevices,
    );
  }

  Map<String, dynamic> _assignmentMapForTechnician(
    Map<String, dynamic> assignments,
    String technicianId,
  ) {
    Map<String, dynamic> filter(dynamic value) {
      final source = _stringMap(value);
      return Map.fromEntries(
        source.entries.where((entry) {
          final item = entry.value;
          return item is Map && item['technicianId'] == technicianId;
        }),
      );
    }

    return {
      'customers': filter(assignments['customers']),
      'devices': filter(assignments['devices']),
    };
  }

  Future<void> _ensureTechnicianExists(LanAccessRequest request) async {
    final exists = _dbService.techniciansBox.values.any(
      (technician) => technicianAccessId(technician) == request.technicianId,
    );
    if (exists) return;

    final parts = request.technicianName.trim().split(RegExp(r'\s+'));
    final firstName = parts.isEmpty ? 'Teknisyen' : parts.first;
    final lastName = parts.length <= 1 ? '' : parts.skip(1).join(' ');
    await _dbService.techniciansBox.add(
      Technician(
        firstName: firstName,
        lastName: lastName,
        title: request.title,
        phone: request.phone,
        email: request.email,
      ),
    );
  }

  Future<Technician> _ensureTechnicianFromJson(
    Map<String, dynamic> technicianJson,
  ) async {
    final firstName = _string(technicianJson['firstName']);
    final lastName = _string(technicianJson['lastName']);
    final phone = _nullableString(technicianJson['phone']);
    final email = _nullableString(technicianJson['email']);
    final title = _nullableString(technicianJson['title']);
    final address = _nullableString(technicianJson['address']);

    final accessId = technicianAccessIdFromFields(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      email: email,
    );

    for (final technician in _dbService.techniciansBox.values) {
      if (technicianAccessId(technician) == accessId) {
        return technician;
      }
    }

    final technician = Technician(
      firstName: firstName.isEmpty ? 'Teknisyen' : firstName,
      lastName: lastName,
      phone: phone,
      email: email,
      title: title,
      address: address,
    );
    await _dbService.techniciansBox.add(technician);
    return technician;
  }

  Technician? get _primaryTechnician =>
      _dbService.techniciansBox.values.isNotEmpty
          ? _dbService.techniciansBox.values.first
          : null;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  void _requirePrimaryTechnician() {
    if (_primaryTechnician != null) return;
    throw Exception(
      'Senkron icin once mobil teknisyen kurulumu tamamlanmali.',
    );
  }

  Future<Box> _prefsBox() async {
    if (Hive.isBoxOpen(_prefsBoxName)) return Hive.box(_prefsBoxName);
    return Hive.openBox(_prefsBoxName);
  }

  Map<String, dynamic> _stringMap(dynamic value) {
    if (value is! Map) return <String, dynamic>{};
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static String technicianAccessId(Technician technician) {
    return technicianAccessIdFromFields(
      firstName: technician.firstName,
      lastName: technician.lastName,
      phone: technician.phone,
      email: technician.email,
    );
  }

  static String technicianAccessIdFromFields({
    required String firstName,
    required String lastName,
    String? phone,
    String? email,
  }) {
    final identity = [
      firstName.trim().toLowerCase(),
      lastName.trim().toLowerCase(),
      (phone ?? '').replaceAll(RegExp(r'\s+'), ''),
      (email ?? '').trim().toLowerCase(),
    ].join('|');
    return base64Url.encode(utf8.encode(identity)).replaceAll('=', '');
  }
}
