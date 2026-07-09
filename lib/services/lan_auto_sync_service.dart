import 'dart:async';
import 'dart:io';

import 'package:biomed_serv/services/database_service.dart';
import 'package:biomed_serv/services/lan_device_identity_service.dart';
import 'package:biomed_serv/services/lan_sync_service.dart';
import 'package:biomed_serv/services/notification_service.dart';
import 'package:biomed_serv/services/remote_gateway_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class LanAutoSyncService extends ChangeNotifier {
  static const String _prefsBoxName = 'app_preferences';
  static const String _autoSyncEnabledKey = 'lan_auto_sync_enabled';
  static const String _autoListenEnabledKey = 'lan_auto_listen_enabled';
  static const String _centerHostKey = 'lan_sync_center_host';
  static const String _centerDeviceIdKey = 'lan_sync_center_device_id';
  static const String _lastSyncAtKey = 'lan_last_sync_at';
  static const String _activityLogKey = 'lan_sync_activity_log';

  static const Duration _minimumSyncInterval = Duration(minutes: 5);
  static const Duration _periodicInterval = Duration(minutes: 3);

  final DatabaseService _dbService;
  final Connectivity _connectivity = Connectivity();
  final LanDeviceIdentityService _deviceIdentityService =
      LanDeviceIdentityService();
  late final LanSyncService _syncService;
  late final RemoteGatewayService _remoteGateway;

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _timer;
  Box? _prefsBox;

  bool _initialized = false;
  bool _autoSyncEnabled = false;
  bool _autoListenEnabled = true;
  bool _isSyncing = false;
  bool _isListening = false;
  bool _isStartingServer = false;
  bool _isDiscovering = false;
  bool _isCenterReachable = false;
  bool? _centerAccessApproved;
  bool _isRemoteReachable = false;
  String? _centerHost;
  String? _centerDeviceId;
  DateTime? _lastDiscoveryAt;
  DateTime? _lastSyncAt;
  String? _lastMessage;
  LanSyncResult? _lastResult;
  int _pendingAccessCount = 0;
  RemoteGatewaySettings _remoteSettings = const RemoteGatewaySettings(
    enabled: false,
    baseUrl: '',
    centerToken: '',
    siteCode: '',
    mode: RemoteTransportMode.localPreferred,
  );
  List<LanSyncActivity> _activities = const [];
  Map<String, bool> _syncProfile = Map<String, bool>.from(
    LanSyncService.defaultSyncProfile,
  );
  Map<String, bool> _outboundProfile = Map<String, bool>.from(
    LanSyncService.defaultOutboundProfile,
  );

  LanAutoSyncService(this._dbService) {
    _remoteGateway = RemoteGatewayService();
    _syncService = LanSyncService(
      _dbService,
      onImport: (result) {
        _lastResult = result;
        _lastMessage =
            'Mobil veri alındı. Eklenen: ${result.totalAdded}, güncellenen: ${result.recordsUpdated}, atlanan: ${result.skipped}.';
        unawaited(
          _appendActivity(
            'Mobil veri alındı. Eklenen ${result.totalAdded}, güncellenen ${result.recordsUpdated}, atlanan ${result.skipped}.',
            type: LanSyncActivityType.sync,
            severity: result.warnings.isEmpty
                ? LanSyncActivitySeverity.success
                : LanSyncActivitySeverity.warning,
            details: result.warnings,
          ),
        );
        notifyListeners();
      },
      onAccessRequest: () {
        _lastMessage = 'Yeni teknisyen baglanti onayi bekliyor.';
        unawaited(_refreshPendingAccessCount());
        unawaited(
          _appendActivity(
            'Yeni teknisyen baglanti onayi bekliyor.',
            type: LanSyncActivityType.access,
            severity: LanSyncActivitySeverity.warning,
          ),
        );
        notifyListeners();
      },
    );
  }

  bool get initialized => _initialized;
  bool get autoSyncEnabled => _autoSyncEnabled;
  bool get autoListenEnabled => _autoListenEnabled;
  bool get isSyncing => _isSyncing;
  bool get isDiscovering => _isDiscovering;
  bool get isListening => _isListening;
  bool get isCenterReachable => _isCenterReachable;
  bool? get centerAccessApproved => _centerAccessApproved;
  bool get isRemoteReachable => _isRemoteReachable;
  bool get remoteGatewayEnabled => _remoteSettings.isConfigured;
  RemoteTransportMode get transportMode => _remoteSettings.mode;
  String get remoteGatewayUrl => _remoteSettings.baseUrl;
  int get localApiPort => _syncService.activePort ?? LanSyncService.defaultPort;
  String? get centerHost => _centerHost;
  DateTime? get lastSyncAt => _lastSyncAt;
  String? get lastMessage => _lastMessage;
  LanSyncResult? get lastResult => _lastResult;
  int get pendingAccessCount => _pendingAccessCount;
  List<LanSyncActivity> get activities => List.unmodifiable(_activities);
  Map<String, bool> get syncProfile => Map.unmodifiable(_syncProfile);
  Map<String, bool> get outboundProfile => Map.unmodifiable(_outboundProfile);

  bool get isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  Future<void> init() async {
    if (_initialized) return;

    _prefsBox = await Hive.openBox(_prefsBoxName);
    _remoteSettings = await _remoteGateway.loadSettings();
    _autoSyncEnabled = _prefsBox!.get(_autoSyncEnabledKey) as bool? ?? true;
    _autoListenEnabled = true;
    _centerHost = _prefsBox!.get(_centerHostKey) as String?;
    _centerDeviceId = _prefsBox!.get(_centerDeviceIdKey) as String?;
    await _prefsBox!.put(_autoSyncEnabledKey, _autoSyncEnabled);
    if (isDesktop) {
      await _prefsBox!.put(_autoListenEnabledKey, true);
    }

    final lastSyncRaw = _prefsBox!.get(_lastSyncAtKey) as String?;
    _lastSyncAt = lastSyncRaw == null ? null : DateTime.tryParse(lastSyncRaw);
    final rawActivities =
        _prefsBox!.get(_activityLogKey) as List<dynamic>? ?? const [];
    _activities = rawActivities
        .whereType<Map>()
        .map(
            (item) => LanSyncActivity.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    _syncProfile = {
      for (final entry in LanSyncService.defaultSyncProfile.entries)
        entry.key: _prefsBox!.get(entry.key) as bool? ?? entry.value,
    };
    _outboundProfile = {
      for (final entry in LanSyncService.defaultOutboundProfile.entries)
        entry.key: _prefsBox!.get(entry.key) as bool? ?? entry.value,
    };
    await _refreshPendingAccessCount(notify: false);

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((_) {
      if (isDesktop) {
        unawaited(startCenterListening());
        unawaited(processRemoteCenter());
      } else {
        unawaited(triggerAutoSync(reason: 'Ag baglantisi degisti'));
      }
    });
    _timer = Timer.periodic(_periodicInterval, (_) {
      if (isDesktop) {
        unawaited(startCenterListening());
        unawaited(processRemoteCenter());
      } else {
        unawaited(triggerAutoSync(reason: 'Periyodik kontrol'));
      }
    });

    _initialized = true;
    notifyListeners();

    if (isDesktop) {
      await startCenterListening();
      unawaited(processRemoteCenter());
    } else {
      unawaited(triggerAutoSync(reason: 'Uygulama acildi'));
    }
  }

  Future<void> setCenterHost(String host) async {
    final cleanHost = host.trim();
    final nextHost = cleanHost.isEmpty ? null : cleanHost;
    if (_centerHost != nextHost) {
      _isCenterReachable = false;
      _centerAccessApproved = null;
    }
    _centerHost = nextHost;
    if (_centerHost == null) {
      await _prefsBox?.delete(_centerHostKey);
    } else {
      await _prefsBox?.put(_centerHostKey, _centerHost);
    }
    notifyListeners();
  }

  Future<void> setAutoSyncEnabled(bool enabled) async {
    _autoSyncEnabled = enabled;
    await _prefsBox?.put(_autoSyncEnabledKey, enabled);
    notifyListeners();
    if (enabled) {
      unawaited(triggerAutoSync(reason: 'Otomatik senkron acildi'));
    }
  }

  Future<void> setAutoListenEnabled(bool enabled) async {
    if (isDesktop && !enabled) {
      _autoListenEnabled = true;
      await _prefsBox?.put(_autoListenEnabledKey, true);
      _lastMessage = 'Desktop merkez servisi otomatik olarak etkin tutulur.';
      notifyListeners();
      return;
    }
    _autoListenEnabled = enabled;
    await _prefsBox?.put(_autoListenEnabledKey, enabled);
    notifyListeners();

    if (!isDesktop) return;
    if (enabled) {
      await startCenterListening();
    } else {
      await stopCenterListening();
    }
  }

  Future<void> setSyncProfileOption(String key, bool enabled) async {
    _syncProfile[key] = enabled;
    await _prefsBox?.put(key, enabled);
    notifyListeners();
  }

  Future<void> setOutboundProfileOption(String key, bool enabled) async {
    _outboundProfile[key] = enabled;
    await _prefsBox?.put(key, enabled);
    notifyListeners();
  }

  Future<void> reloadRemoteSettings() async {
    _remoteSettings = await _remoteGateway.loadSettings();
    _isRemoteReachable = false;
    await _refreshPendingAccessCount(notify: false);
    notifyListeners();
    if (isDesktop && _remoteSettings.isConfigured) {
      unawaited(processRemoteCenter());
    }
  }

  Future<void> startCenterListening() async {
    if (!isDesktop || _isListening || _isStartingServer) return;
    _isStartingServer = true;
    try {
      await _syncService.startServer();
      _isListening = true;
      _lastMessage = 'Desktop merkez dinlemede.';
      await _appendActivity(
        'Desktop merkez dinleme moduna gecti.',
        type: LanSyncActivityType.server,
        severity: LanSyncActivitySeverity.success,
      );
    } catch (e) {
      _isListening = false;
      _lastMessage = 'Desktop merkez baslatilamadi: $e';
      await _appendActivity(
        'Desktop merkez baslatilamadi: $e',
        type: LanSyncActivityType.server,
        severity: LanSyncActivitySeverity.error,
      );
    }
    _isStartingServer = false;
    notifyListeners();
  }

  Future<void> stopCenterListening() async {
    await _syncService.stopServer();
    _isListening = false;
    _lastMessage = 'Desktop merkez dinleme kapatildi.';
    await _appendActivity(
      'Desktop merkez dinleme kapatildi.',
      type: LanSyncActivityType.server,
      severity: LanSyncActivitySeverity.info,
    );
    notifyListeners();
  }

  Future<LanSyncResult?> triggerAutoSync({String reason = 'Manuel'}) async {
    if (!_initialized || isDesktop || !_autoSyncEnabled) {
      return null;
    }
    if (_isSyncing || !_isSyncDue()) return null;

    final connectivity = await _connectivity.checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      _lastMessage = 'Otomatik senkron bekliyor: baglanti yok.';
      notifyListeners();
      return null;
    }

    final canUseLocalNetwork = _canUseLocalNetwork(connectivity);
    if (!canUseLocalNetwork) {
      if (_remoteSettings.isConfigured &&
          _remoteSettings.mode != RemoteTransportMode.localOnly) {
        return syncRemoteNow(reason: reason);
      }
      _lastMessage =
          'Otomatik senkron Wi-Fi veya yerel ag baglantisi bekliyor.';
      notifyListeners();
      return null;
    }

    if (_remoteSettings.mode == RemoteTransportMode.remoteOnly) {
      return syncRemoteNow(reason: reason);
    }

    if (_centerHost == null) {
      final center = await discoverAndConfigureCenter();
      if (center == null) {
        if (_remoteSettings.mode == RemoteTransportMode.localPreferred &&
            _remoteSettings.isConfigured) {
          return syncRemoteNow(reason: reason);
        }
        return null;
      }
    }

    final sameNetwork = await _isSameLocalNetwork(_centerHost!);
    if (sameNetwork) {
      final localResult = await syncNow(reason: reason);
      if (localResult != null ||
          _remoteSettings.mode == RemoteTransportMode.localOnly) {
        return localResult;
      }
    }

    if (_remoteSettings.mode == RemoteTransportMode.localPreferred &&
        _remoteSettings.isConfigured) {
      return syncRemoteNow(reason: reason);
    }

    _lastMessage =
        'Otomatik senkron bekliyor: Desktop merkez aynı yerel ağda değil.';
    notifyListeners();
    return null;
  }

  bool _canUseLocalNetwork(ConnectivityResult connectivity) {
    return connectivity == ConnectivityResult.wifi ||
        connectivity == ConnectivityResult.ethernet ||
        connectivity == ConnectivityResult.vpn;
  }

  Future<LanDiscoveredCenter?> discoverAndConfigureCenter({
    bool force = false,
  }) async {
    if (isDesktop || _isDiscovering) return null;
    final lastDiscovery = _lastDiscoveryAt;
    if (!force &&
        lastDiscovery != null &&
        DateTime.now().difference(lastDiscovery) < const Duration(minutes: 1)) {
      return null;
    }

    _isDiscovering = true;
    _lastDiscoveryAt = DateTime.now();
    _lastMessage = 'Yerel agda Desktop merkez araniyor...';
    notifyListeners();
    try {
      final centers = await _syncService.discoverCenters();
      if (centers.isEmpty) {
        _isCenterReachable = false;
        _centerAccessApproved = null;
        _lastMessage =
            'Desktop merkez bulunamadi. Ayni Wi-Fi aginda oldugunuzu kontrol edin.';
        return null;
      }

      final rememberedId = _centerDeviceId;
      final center = rememberedId == null
          ? centers.first
          : centers.firstWhere(
              (item) => item.deviceId == rememberedId,
              orElse: () => centers.first,
            );
      await setCenterHost(center.host);
      _isCenterReachable = true;
      _centerDeviceId = center.deviceId;
      if (_centerDeviceId == null) {
        await _prefsBox?.delete(_centerDeviceIdKey);
      } else {
        await _prefsBox?.put(_centerDeviceIdKey, _centerDeviceId);
      }
      _lastMessage =
          '${center.deviceName} merkezi otomatik bulundu. Eslestirme kontrol ediliyor.';
      await _appendActivity(
        '${center.deviceName} merkezi otomatik bulundu (${center.host}).',
        type: LanSyncActivityType.server,
        severity: LanSyncActivitySeverity.success,
      );
      return center;
    } catch (e) {
      _isCenterReachable = false;
      _centerAccessApproved = null;
      _lastMessage = 'Merkez otomatik arama basarisiz: $e';
      return null;
    } finally {
      _isDiscovering = false;
      notifyListeners();
    }
  }

  Future<LanSyncResult?> syncNow({String reason = 'Manuel'}) async {
    final host = _centerHost;
    if (host == null || host.isEmpty) {
      _isCenterReachable = false;
      _centerAccessApproved = null;
      _lastMessage = 'Merkez IP adresi kayitli degil.';
      notifyListeners();
      return null;
    }

    _isSyncing = true;
    _lastMessage = '$reason: merkez ile senkron baslatildi.';
    await _appendActivity(
      '$reason: merkez ile senkron baslatildi.',
      type: LanSyncActivityType.sync,
      severity: LanSyncActivitySeverity.info,
    );
    notifyListeners();

    try {
      final result = await _syncService.sendBundle(
        host: host,
        profile: _outboundProfile,
      );
      _isCenterReachable = true;
      _centerAccessApproved = true;
      _lastResult = result;
      _lastSyncAt = DateTime.now();
      await _prefsBox?.put(_lastSyncAtKey, _lastSyncAt!.toIso8601String());
      _lastMessage =
          'Senkron tamamlandı. Eklenen: ${result.totalAdded}, güncellenen: ${result.recordsUpdated}, atlanan: ${result.skipped}.';
      await _appendActivity(
        'Senkron tamamlandı. Eklenen ${result.totalAdded}, güncellenen ${result.recordsUpdated}, atlanan ${result.skipped}.',
        type: LanSyncActivityType.sync,
        severity: result.warnings.isEmpty
            ? LanSyncActivitySeverity.success
            : LanSyncActivitySeverity.warning,
        details: result.warnings,
      );
      if (!isDesktop) {
        try {
          await LocalNotificationService.showNotification(
            id: 8787,
            title: 'Senkronizasyon tamamlandi',
            body:
                'Merkez ile veri aktarimi tamamlandi. ${result.totalAdded} yeni kayit alindi.',
            payload: 'lan_sync_complete',
          );
        } catch (e) {
          debugPrint('Senkron bildirimi gosterilemedi: $e');
        }
      }
      return result;
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('onay') || message.contains('bekliyor')) {
        _isCenterReachable = true;
        _centerAccessApproved = false;
        _lastMessage =
            'Eslestirme istegi gonderildi. Desktop merkez onayi bekleniyor.';
        await _appendActivity(
          'Eslestirme istegi gonderildi. Desktop merkez onayi bekleniyor.',
          type: LanSyncActivityType.access,
          severity: LanSyncActivitySeverity.warning,
        );
      } else {
        _isCenterReachable = false;
        _lastMessage = 'Senkron basarisiz: $e';
        await _appendActivity(
          'Senkron basarisiz: $e',
          type: LanSyncActivityType.sync,
          severity: LanSyncActivitySeverity.error,
        );
      }
      return null;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<LanSyncResult?> syncRemoteNow({String reason = 'Manuel'}) async {
    if (isDesktop) return null;
    final settings = _remoteSettings;
    final validation = _remoteGateway.validateSettings(
      settings,
      requireCenterToken: false,
    );
    if (!settings.isConfigured || validation != null) {
      _lastMessage = validation ?? 'Uzak merkez ayarları tamamlanmadı.';
      notifyListeners();
      return null;
    }
    if (_isSyncing) return null;

    _isSyncing = true;
    _lastMessage = '$reason: uzak merkez bağlantısı kuruluyor.';
    notifyListeners();
    try {
      final identity = await _deviceIdentityService.resolve();
      final bundle = await _syncService.buildSyncBundle(
        profile: _outboundProfile,
      );
      var deviceToken = await _remoteGateway.storedDeviceToken();

      if (deviceToken == null || deviceToken.isEmpty) {
        final requestId = await _remoteGateway.storedPairingRequestId();
        if (requestId == null || requestId.isEmpty) {
          await _remoteGateway.requestMobilePairing(settings, {
            'deviceId': identity.deviceId,
            'macAddress': identity.macAddress,
            'sourceDevice': identity.deviceName,
            'technicianId': bundle['technicianId'],
            'technician': bundle['technician'],
          });
          _isRemoteReachable = true;
          _lastMessage =
              'Uzak eşleşme isteği gönderildi. Desktop merkez onayı bekleniyor.';
          await _appendActivity(
            _lastMessage!,
            type: LanSyncActivityType.access,
            severity: LanSyncActivitySeverity.warning,
          );
          return null;
        }

        final approved = await _remoteGateway.refreshMobilePairing(
          settings,
          deviceId: identity.deviceId,
        );
        if (!approved) {
          _isRemoteReachable = true;
          _lastMessage =
              'Uzak merkez eşleşmesi Desktop tarafından onaylanmayı bekliyor.';
          return null;
        }
        deviceToken = await _remoteGateway.storedDeviceToken();
      }

      if (deviceToken == null || deviceToken.isEmpty) {
        _lastMessage = 'Uzak merkez cihaz anahtarı alınamadı.';
        return null;
      }

      final response = await _remoteGateway.mobileSync(settings, bundle);
      final result = response.outboundBundle == null
          ? const LanSyncResult()
          : await _syncService.importBundle(
              response.outboundBundle!,
              requireApproval: false,
            );
      final outboundMessageId = response.outboundMessageId;
      if (outboundMessageId != null) {
        await _remoteGateway.acknowledgeMobileOutbox(
          settings,
          outboundMessageId,
        );
      }
      _isRemoteReachable = true;
      _lastResult = result;
      _lastSyncAt = DateTime.now();
      await _prefsBox?.put(_lastSyncAtKey, _lastSyncAt!.toIso8601String());
      _lastMessage = response.outboundBundle == null
          ? 'Saha verileri uzak merkeze gönderildi. Merkez görev paketi bekleniyor.'
          : 'Uzak senkron tamamlandı. ${result.totalAdded} yeni, ${result.recordsUpdated} güncellenen kayıt alındı.';
      await _appendActivity(
        _lastMessage!,
        type: LanSyncActivityType.sync,
        severity: result.warnings.isEmpty
            ? LanSyncActivitySeverity.success
            : LanSyncActivitySeverity.warning,
        details: result.warnings,
      );
      try {
        await LocalNotificationService.showNotification(
          id: 8788,
          title: 'Uzak senkronizasyon tamamlandı',
          body: response.outboundBundle == null
              ? 'Saha verileri merkeze gönderildi.'
              : 'Merkez görevleri ve güncel kayıtlar cihaza alındı.',
          payload: 'remote_sync_complete',
        );
      } catch (e) {
        debugPrint('Uzak senkron bildirimi gösterilemedi: $e');
      }
      return result;
    } catch (e) {
      _isRemoteReachable = false;
      _lastMessage = 'Uzak merkez senkronu başarısız: $e';
      await _appendActivity(
        _lastMessage!,
        type: LanSyncActivityType.sync,
        severity: LanSyncActivitySeverity.error,
      );
      return null;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> resetRemotePairing() async {
    if (isDesktop) return;
    await _remoteGateway.clearMobilePairing();
    _isRemoteReachable = false;
    _lastMessage =
        'Uzak merkez eşleşmesi sıfırlandı. Yeni bağlantı isteği gönderebilirsiniz.';
    notifyListeners();
  }

  Future<LanSyncResult?> processRemoteCenter() async {
    if (!isDesktop || _isSyncing || !_remoteSettings.isConfigured) {
      return null;
    }
    final validation = _remoteGateway.validateSettings(
      _remoteSettings,
      requireCenterToken: true,
    );
    if (validation != null) {
      _isRemoteReachable = false;
      return null;
    }

    _isSyncing = true;
    notifyListeners();
    try {
      final health = await _remoteGateway.testConnection(_remoteSettings);
      if (!health.ok) {
        _isRemoteReachable = false;
        _lastMessage = health.message;
        return null;
      }
      _isRemoteReachable = true;
      final inbox = await _remoteGateway.centerInbox(_remoteSettings);
      var combined = const LanSyncResult();
      for (final item in inbox) {
        final imported = await _syncService.importBundle(
          item.bundle,
          requireApproval: false,
        );
        combined = _combineResults(combined, imported);
        final outbound = await _syncService.buildAssignedBundleForTechnician(
          item.technicianId,
        );
        await _remoteGateway.pushCenterBundle(
          _remoteSettings,
          deviceId: item.deviceId,
          bundle: outbound,
        );
        await _remoteGateway.acknowledgeInbox(_remoteSettings, item.id);
      }
      await _refreshPendingAccessCount(notify: false);
      if (inbox.isNotEmpty) {
        _lastResult = combined;
        _lastSyncAt = DateTime.now();
        await _prefsBox?.put(_lastSyncAtKey, _lastSyncAt!.toIso8601String());
        _lastMessage =
            '${inbox.length} uzak mobil paket işlendi; görev ve merkez verileri gönderim kuyruğuna alındı.';
        await _appendActivity(
          _lastMessage!,
          type: LanSyncActivityType.sync,
          severity: combined.warnings.isEmpty
              ? LanSyncActivitySeverity.success
              : LanSyncActivitySeverity.warning,
          details: combined.warnings,
        );
      }
      return combined;
    } catch (e) {
      _isRemoteReachable = false;
      _lastMessage = 'Uzak Gateway işlemi başarısız: $e';
      await _appendActivity(
        _lastMessage!,
        type: LanSyncActivityType.sync,
        severity: LanSyncActivitySeverity.error,
      );
      return null;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  LanSyncResult _combineResults(LanSyncResult first, LanSyncResult second) {
    return LanSyncResult(
      companyInfoAdded: first.companyInfoAdded + second.companyInfoAdded,
      customersAdded: first.customersAdded + second.customersAdded,
      devicesAdded: first.devicesAdded + second.devicesAdded,
      serviceFormsAdded: first.serviceFormsAdded + second.serviceFormsAdded,
      maintenanceFormsAdded:
          first.maintenanceFormsAdded + second.maintenanceFormsAdded,
      faultTicketsAdded: first.faultTicketsAdded + second.faultTicketsAdded,
      expensesAdded: first.expensesAdded + second.expensesAdded,
      expenseReportsAdded:
          first.expenseReportsAdded + second.expenseReportsAdded,
      stocksAdded: first.stocksAdded + second.stocksAdded,
      recordsUpdated: first.recordsUpdated + second.recordsUpdated,
      skipped: first.skipped + second.skipped,
      warnings: [...first.warnings, ...second.warnings],
    );
  }

  Future<bool> requestCenterAccess(String host) async {
    final cleanHost = host.trim();
    if (cleanHost.isEmpty) {
      _lastMessage = 'Merkez IP adresi gerekli.';
      notifyListeners();
      return false;
    }

    await setCenterHost(cleanHost);
    _lastMessage = 'Eslestirme istegi gonderiliyor...';
    await _appendActivity(
      'Eslestirme istegi gonderiliyor...',
      type: LanSyncActivityType.access,
      severity: LanSyncActivitySeverity.info,
    );
    notifyListeners();

    try {
      final approved = await _syncService.requestAccess(host: cleanHost);
      _isCenterReachable = true;
      _centerAccessApproved = approved;
      _lastMessage = approved
          ? 'Merkez bu teknisyeni onayladi. Veri aktarimi baslayabilir.'
          : 'Eslestirme istegi gonderildi. Desktop merkez onayi bekleniyor.';
      await _appendActivity(
        _lastMessage!,
        type: LanSyncActivityType.access,
        severity: approved
            ? LanSyncActivitySeverity.success
            : LanSyncActivitySeverity.warning,
      );
      notifyListeners();
      return approved;
    } catch (e) {
      _isCenterReachable = false;
      _centerAccessApproved = null;
      _lastMessage = 'Eslestirme basarisiz: $e';
      await _appendActivity(
        'Eslestirme basarisiz: $e',
        type: LanSyncActivityType.access,
        severity: LanSyncActivitySeverity.error,
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyCenterConnection() async {
    final host = _centerHost;
    if (host == null || host.isEmpty) {
      _isCenterReachable = false;
      _centerAccessApproved = null;
      _lastMessage = 'Merkez seçilmedi.';
      notifyListeners();
      return false;
    }

    _lastMessage = 'Merkez bağlantısı kontrol ediliyor...';
    notifyListeners();
    final center = await _syncService.probeCenter(host: host);
    _isCenterReachable = center != null;
    if (center == null) {
      _centerAccessApproved = null;
      _lastMessage =
          'Kayıtlı merkeze ulaşılamadı. Aynı Wi-Fi ağını ve Windows güvenlik duvarını kontrol edin.';
    } else {
      _centerDeviceId = center.deviceId;
      if (_centerDeviceId != null) {
        await _prefsBox?.put(_centerDeviceIdKey, _centerDeviceId);
      }
      _lastMessage = '${center.deviceName} merkezine bağlantı doğrulandı.';
    }
    notifyListeners();
    return _isCenterReachable;
  }

  Future<List<String>> localIpv4Addresses() {
    return _syncService.localIpv4Addresses();
  }

  Future<List<LanDiscoveredCenter>> discoverCenters() {
    return _syncService.discoverCenters();
  }

  Future<List<LanAccessRequest>> pendingAccessRequests() async {
    final local = await _syncService.pendingAccessRequests();
    if (!isDesktop || !_remoteSettings.isConfigured) return local;

    try {
      final remote = await _remoteGateway.pendingPairings(_remoteSettings);
      return [
        ...local,
        ...remote.map(
          (request) => LanAccessRequest(
            technicianId: request.technicianId,
            technicianName: request.technicianName,
            sourceDevice: '${request.sourceDevice} • Uzak Gateway',
            deviceId: 'REMOTE:${request.id}',
            sourceIp: 'HTTPS Gateway',
            requestedAt: request.requestedAt,
          ),
        ),
      ];
    } catch (_) {
      return local;
    }
  }

  Future<List<LanSyncReviewItem>> reviewItems({
    bool includeReviewed = false,
  }) {
    return _syncService.reviewItems(includeReviewed: includeReviewed);
  }

  Future<void> markReviewItemReviewed(String id) async {
    await _syncService.markReviewItemReviewed(id);
    _lastMessage = 'Yeni gelen kayit onerisi gozden gecirildi.';
    await _appendActivity(
      'Yeni gelen kayit onerisi gozden gecirildi.',
      type: LanSyncActivityType.review,
      severity: LanSyncActivitySeverity.info,
    );
    notifyListeners();
  }

  Future<void> clearReviewedItems() async {
    await _syncService.clearReviewedItems();
    _lastMessage = 'Gozden gecirilmis oneriler temizlendi.';
    await _appendActivity(
      'Gozden gecirilmis oneriler temizlendi.',
      type: LanSyncActivityType.review,
      severity: LanSyncActivitySeverity.info,
    );
    notifyListeners();
  }

  Future<void> approveAccess(String accessKey) async {
    final remoteRequestId = _remoteRequestId(accessKey);
    if (remoteRequestId == null) {
      await _syncService.approveAccess(accessKey);
    } else {
      final requests = await _remoteGateway.pendingPairings(_remoteSettings);
      final request = requests.firstWhere(
        (item) => item.id == remoteRequestId,
        orElse: () => throw StateError('Uzak eşleşme isteği bulunamadı.'),
      );
      await _remoteGateway.decidePairing(
        _remoteSettings,
        requestId: remoteRequestId,
        approve: true,
      );
      await _syncService.ensureTechnicianForAccessRequest(
        LanAccessRequest(
          technicianId: request.technicianId,
          technicianName: request.technicianName,
          sourceDevice: request.sourceDevice,
          deviceId: request.deviceId,
          requestedAt: request.requestedAt,
        ),
      );
    }
    await _refreshPendingAccessCount(notify: false);
    _lastMessage = 'Teknisyen erişimi onaylandı.';
    await _appendActivity(
      'Teknisyen erisimi onaylandi.',
      type: LanSyncActivityType.access,
      severity: LanSyncActivitySeverity.success,
    );
    notifyListeners();
  }

  Future<void> rejectAccess(String accessKey) async {
    final remoteRequestId = _remoteRequestId(accessKey);
    if (remoteRequestId == null) {
      await _syncService.rejectAccess(accessKey);
    } else {
      await _remoteGateway.decidePairing(
        _remoteSettings,
        requestId: remoteRequestId,
        approve: false,
      );
    }
    await _refreshPendingAccessCount(notify: false);
    _lastMessage = 'Teknisyen erişim isteği reddedildi.';
    await _appendActivity(
      'Teknisyen erisim istegi reddedildi.',
      type: LanSyncActivityType.access,
      severity: LanSyncActivitySeverity.warning,
    );
    notifyListeners();
  }

  Future<void> _refreshPendingAccessCount({bool notify = true}) async {
    _pendingAccessCount = (await pendingAccessRequests()).length;
    if (notify) notifyListeners();
  }

  String? _remoteRequestId(String accessKey) {
    const marker = '::REMOTE:';
    final markerIndex = accessKey.indexOf(marker);
    if (markerIndex < 0) return null;
    final value = accessKey.substring(markerIndex + marker.length).trim();
    return value.isEmpty ? null : value;
  }

  Future<void> clearActivities() async {
    _activities = const [];
    await _prefsBox?.put(_activityLogKey, const []);
    _lastMessage = 'Senkron gecmisi temizlendi.';
    notifyListeners();
  }

  Future<void> _appendActivity(
    String message, {
    required LanSyncActivityType type,
    required LanSyncActivitySeverity severity,
    List<String> details = const [],
  }) async {
    final updated = [
      LanSyncActivity(
        timestamp: DateTime.now(),
        message: message,
        type: type,
        severity: severity,
        details: details,
      ),
      ..._activities,
    ].take(40).toList();

    _activities = updated;
    await _prefsBox?.put(
      _activityLogKey,
      updated.map((item) => item.toJson()).toList(),
    );
  }

  bool _isSyncDue() {
    final lastSync = _lastSyncAt;
    if (lastSync == null) return true;
    return DateTime.now().difference(lastSync) >= _minimumSyncInterval;
  }

  Future<bool> _isSameLocalNetwork(String host) async {
    final hostParts = host.split('.');
    if (hostParts.length != 4) return true;

    final hostPrefix = hostParts.take(3).join('.');
    final localIps = await _syncService.localIpv4Addresses();
    return localIps.any((ip) => ip.split('.').take(3).join('.') == hostPrefix);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _connectivitySubscription?.cancel();
    _syncService.stopServer();
    _remoteGateway.close();
    super.dispose();
  }
}

enum LanSyncActivityType { server, sync, access, review }

enum LanSyncActivitySeverity { info, success, warning, error }

class LanSyncActivity {
  final DateTime timestamp;
  final String message;
  final LanSyncActivityType type;
  final LanSyncActivitySeverity severity;
  final List<String> details;

  const LanSyncActivity({
    required this.timestamp,
    required this.message,
    required this.type,
    required this.severity,
    this.details = const [],
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'message': message,
        'type': type.name,
        'severity': severity.name,
        'details': details,
      };

  factory LanSyncActivity.fromJson(Map<String, dynamic> json) {
    return LanSyncActivity(
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      message: json['message']?.toString() ?? '',
      type: LanSyncActivityType.values.firstWhere(
        (item) => item.name == json['type']?.toString(),
        orElse: () => LanSyncActivityType.sync,
      ),
      severity: LanSyncActivitySeverity.values.firstWhere(
        (item) => item.name == json['severity']?.toString(),
        orElse: () => LanSyncActivitySeverity.info,
      ),
      details: (json['details'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}
