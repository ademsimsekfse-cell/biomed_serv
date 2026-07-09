import 'package:biomed_serv/models/agent_notification.dart';
import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/models/stock.dart';
import 'package:biomed_serv/models/tender.dart';
import 'package:biomed_serv/providers/device_provider.dart';
import 'package:biomed_serv/providers/service_form_provider.dart';
import 'package:biomed_serv/providers/stock_provider.dart';
import 'package:biomed_serv/providers/tender_provider.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

class AgentProvider with ChangeNotifier {
  final StockProvider _stockProvider;
  final TenderProvider _tenderProvider;
  final DeviceProvider _deviceProvider;
  final ServiceFormProvider _serviceFormProvider; // YENİ

  List<AgentNotification> _notifications = [];
  List<AgentNotification> get notifications => _notifications;

  AgentProvider(this._stockProvider, this._tenderProvider, this._deviceProvider, this._serviceFormProvider) {
    // Tüm temel sağlayıcıları dinle
    _stockProvider.addListener(runAllChecks);
    _tenderProvider.addListener(runAllChecks);
    _deviceProvider.addListener(runAllChecks);
    _serviceFormProvider.addListener(runAllChecks); // YENİ
    
    // Başlangıçta kontrolleri bir kez çalıştır
    runAllChecks();
  }

  void runAllChecks() {
    List<AgentNotification> newNotifications = [];

    newNotifications.addAll(_checkCriticalStock());
    newNotifications.addAll(_checkTenderExpiry());
    newNotifications.addAll(_checkDevicePerformance()); // YENİ
    newNotifications.addAll(_checkDeviceEOL()); // YENİ

    // Bildirim listesini güncelle ve dinleyicileri haberdar et
    _notifications = newNotifications;
    notifyListeners();
  }

  // 1. Kritik Stok Uyarısı
  List<AgentNotification> _checkCriticalStock() {
    final stockAlerts = <AgentNotification>[];

    for (Stock stock in _stockProvider.stocks) {
      if (stock.quantity <= stock.criticalStockThreshold) {
        stockAlerts.add(AgentNotification(
          title: 'Kritik Stok Uyarısı',
          message: '${stock.name} stok seviyesi kritik eşik altına düştü (${stock.quantity} adet kaldı).',
          type: NotificationType.criticalStock,
          icon: Icons.warning_rounded,
          color: Colors.orange,
          relatedObjectKey: stock.key,
          routeName: '/stock',
        ));
      }
    }
    return stockAlerts;
  }

  // 2. İhale Bitiş Tarihi Uyarısı
  List<AgentNotification> _checkTenderExpiry() {
    final tenderAlerts = <AgentNotification>[];
    final now = DateTime.now();
    final warningDays = 30; // 30 gün kala uyarı ver

    for (Tender tender in _tenderProvider.tenders) {
      final daysUntilExpiry = tender.endDate.difference(now).inDays;
      if (daysUntilExpiry <= warningDays && daysUntilExpiry >= 0) {
        tenderAlerts.add(AgentNotification(
          title: 'İhale Süresi Doluyor',
          message: '"${tender.name}" ihalesi $daysUntilExpiry gün içinde sona erecek.',
          type: NotificationType.tenderExpiry,
          icon: Icons.access_time_filled,
          color: Colors.amber,
          relatedObjectKey: tender.key,
          routeName: '/tender',
        ));
      } else if (daysUntilExpiry < 0) {
        tenderAlerts.add(AgentNotification(
          title: 'İhale Süresi Doldu',
          message: '"${tender.name}" ihalesinin süresi doldu.',
          type: NotificationType.tenderExpiry,
          icon: Icons.timer_off,
          color: Colors.red,
          relatedObjectKey: tender.key,
          routeName: '/tender',
        ));
      }
        }
    return tenderAlerts;
  }

  // 3. Cihaz Performans Uyarısı (YENİ)
  List<AgentNotification> _checkDevicePerformance() {
    final performanceAlerts = <AgentNotification>[];
    const int failureThreshold = 3; // Eşik: 30 günde 3'ten fazla arıza
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    final recentFailureForms = _serviceFormProvider.forms.where((form) {
      return form.createdAt.isAfter(thirtyDaysAgo) && form.problemTypes.contains('Arıza');
    }).toList();

    final groupedByDevice = groupBy(
      recentFailureForms.where((form) => form.device.key != null).toList(),
      (form) => form.device.key,
    );

    groupedByDevice.forEach((deviceKey, forms) {
      if (forms.length >= failureThreshold) {
        final device = forms.first.device;
        performanceAlerts.add(AgentNotification(
          title: 'Düşük Cihaz Performansı',
          message: '${device.name} adlı cihaz için son 30 günde ${forms.length} arıza kaydı açıldı.',
          type: NotificationType.devicePerformance,
          icon: Icons.show_chart_rounded,
          color: Colors.red,
          relatedObjectKey: deviceKey,
          routeName: '/device', 
        ));
      }
    });
    return performanceAlerts;
  }

  // 4. Cihaz Ömrü Uyarısı (YENİ)
  List<AgentNotification> _checkDeviceEOL() {
    final eolAlerts = <AgentNotification>[];
    final now = DateTime.now();

    for (Device device in _deviceProvider.devices) {
      if (device.installationDate != null && device.economicLife != null) {
        final eolDate = device.installationDate!.add(Duration(days: device.economicLife! * 365));
        if (eolDate.isBefore(now)) {
           eolAlerts.add(AgentNotification(
            title: 'Cihaz Ömrü Doldu',
            message: '${device.name} adlı cihaz, ekonomik ömrünü tamamladı.',
            type: NotificationType.deviceEndOfLife,
            icon: Icons.hourglass_bottom_rounded,
            color: Colors.purple,
            relatedObjectKey: device.key,
            routeName: '/device',
          ));
        }
      }
    }
    return eolAlerts;
  }


  @override
  void dispose() {
    _stockProvider.removeListener(runAllChecks);
    _tenderProvider.removeListener(runAllChecks);
    _deviceProvider.removeListener(runAllChecks);
    _serviceFormProvider.removeListener(runAllChecks); // YENİ
    super.dispose();
  }
}
