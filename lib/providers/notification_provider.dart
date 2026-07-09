import 'package:biomed_serv/models/notification.dart' as model;
import 'package:biomed_serv/services/database_service.dart';
import 'package:biomed_serv/services/notification_service.dart' as services;
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

// Model alias'ları
typedef AppNotification = model.AppNotification;
typedef NotificationType = model.NotificationType;
typedef NotificationPriority = model.NotificationPriority;
typedef Reminder = model.Reminder;

class NotificationProvider with ChangeNotifier {
  final DatabaseService _dbService;
  late Box<AppNotification> _notificationBox;
  late Box<Reminder> _reminderBox;

  List<AppNotification> _notifications = [];
  List<AppNotification> get notifications => _notifications;

  List<Reminder> _reminders = [];
  List<Reminder> get reminders => _reminders;

  // Okunmamış bildirim sayısı
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  // Aktif hatırlatıcı sayısı
  int get activeReminderCount => _reminders.where((r) => r.isActive).length;

  // Okunmamış bildirimler
  List<AppNotification> get unreadNotifications =>
      _notifications.where((n) => !n.isRead).toList();

  // Bugünkü hatırlatıcılar
  List<Reminder> get todayReminders {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _reminders.where((r) {
      if (!r.isActive) return false;
      final reminderDate = DateTime(
        r.reminderDate.year,
        r.reminderDate.month,
        r.reminderDate.day,
      );
      return reminderDate.isAtSameMomentAs(today) ||
          (r.isRepeating && r.nextOccurrence != null &&
           DateTime(r.nextOccurrence!.year, r.nextOccurrence!.month, r.nextOccurrence!.day)
               .isAtSameMomentAs(today));
    }).toList();
  }

  NotificationProvider(this._dbService) {
    _notificationBox = _dbService.notificationsBox;
    _reminderBox = _dbService.remindersBox;
    _loadData();
  }

  void _loadData() {
    _notifications = _notificationBox.values.toList();
    _reminders = _reminderBox.values.toList();

    // Tarihe göre sırala (en yeni en üstte)
    _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _reminders.sort((a, b) => a.reminderDate.compareTo(b.reminderDate));

    notifyListeners();
  }

  /// Yeni bildirim ekle
  Future<void> addNotification(AppNotification notification) async {
    final key = await _notificationBox.add(notification);
    
    // Yerel bildirim göster
    await services.LocalNotificationService.showNotification(
      id: key,
      title: notification.title,
      body: notification.message,
      payload: '${notification.type.name}_${notification.relatedEntityKey}',
      priority: _convertToServicePriority(notification.priority),
    );
    
    _loadData();
  }

  /// Bildirimi okundu olarak işaretle
  Future<void> markAsRead(int key) async {
    final notification = _notificationBox.get(key);
    if (notification != null) {
      notification.isRead = true;
      await _notificationBox.put(key, notification);
      _loadData();
    }
  }

  /// Tümünü okundu olarak işaretle
  Future<void> markAllAsRead() async {
    for (final notification in _notifications) {
      if (!notification.isRead && notification.key != null) {
        notification.isRead = true;
        await _notificationBox.put(notification.key!, notification);
      }
    }
    _loadData();
  }

  /// Bildirimi sil
  Future<void> deleteNotification(int key) async {
    await _notificationBox.delete(key);
    _loadData();
  }

  /// Hatırlatıcı ekle
  Future<void> addReminder(Reminder reminder) async {
    final key = await _reminderBox.add(reminder);
    
    // Yerel bildirim planla
    if (reminder.isActive) {
      await services.LocalNotificationService.scheduleNotification(
        id: key + 100000, // Hatırlatıcılar için farklı ID aralığı
        title: reminder.title,
        body: reminder.description ?? 'Hatırlatma zamanı geldi!',
        scheduledDate: reminder.reminderDate,
        repeat: reminder.isRepeating,
        repeatInterval: reminder.repeatInterval,
        priority: services.NotificationPriority.high,
      );
    }
    
    _loadData();
  }

  /// Hatırlatıcı güncelle
  Future<void> updateReminder(int key, Reminder reminder) async {
    await _reminderBox.put(key, reminder);
    _loadData();
  }

  /// Hatırlatıcı sil
  Future<void> deleteReminder(int key) async {
    await _reminderBox.delete(key);
    _loadData();
  }

  /// Hatırlatıcı durumunu değiştir (aktif/pasif)
  Future<void> toggleReminderStatus(int key) async {
    final reminder = _reminderBox.get(key);
    if (reminder != null) {
      reminder.isActive = !reminder.isActive;
      await _reminderBox.put(key, reminder);
      _loadData();
    }
  }

  /// Otomatik hatırlatıcılar oluştur (örn: garanti bitişi yaklaşan cihazlar)
  Future<void> createAutoReminders() async {
    final deviceBox = _dbService.devicesBox;
    final now = DateTime.now();

    for (final device in deviceBox.values) {
      // Garanti bitişi yaklaşan cihazlar (30 gün kala)
      if (device.warrantyEndDate != null) {
        final daysUntilExpiry = device.warrantyEndDate!.difference(now).inDays;
        if (daysUntilExpiry <= 30 && daysUntilExpiry > 0) {
          // Aynı cihaz için benzer bildirim var mı kontrol et
          final existingNotification = _notifications.any((n) =>
              n.type == NotificationType.warrantyExpiration &&
              n.relatedEntityKey == device.key &&
              n.createdAt.isAfter(now.subtract(const Duration(days: 7))));

          if (!existingNotification) {
            final notification = AppNotification(
              title: 'Garanti Süresi Doluyor',
              message:
                  '${device.name} (${device.brand} ${device.model}) cihazının garantisi $daysUntilExpiry gün içinde dolacak.',
              type: NotificationType.warrantyExpiration,
              priority: daysUntilExpiry <= 7
                  ? NotificationPriority.urgent
                  : NotificationPriority.high,
              relatedEntityType: 'device',
              relatedEntityKey: device.key,
            );
            final key = await _notificationBox.add(notification);
            
            // Acil durumdaysa hemen yerel bildirim göster
            if (daysUntilExpiry <= 7) {
              await services.LocalNotificationService.showNotification(
                id: key,
                title: notification.title,
                body: notification.message,
                priority: services.NotificationPriority.urgent,
                payload: 'warranty_${device.key}',
              );
            }
          }
        }
      }
    }

    _loadData();
  }

  /// 🔵 Yeni cihaz kaydı bildirimi
  Future<void> createDeviceNotification(dynamic device, int? deviceKey) async {
    final deviceName = device.name ?? 'Yeni cihaz';
    final deviceBrand = device.brand ?? '';
    
    final notification = AppNotification(
      title: '✅ Yeni Cihaz Kaydedildi',
      message: '$deviceBrand $deviceName başarıyla kaydedildi.',
      type: NotificationType.device,
      priority: NotificationPriority.medium,
      relatedEntityType: 'device',
      relatedEntityKey: deviceKey,
    );
    
    await addNotification(notification);
  }

  /// 🔴 Bakım zamanı bildirimi
  Future<void> createMaintenanceReminder(dynamic device, {int daysLeft = 0}) async {
    final deviceName = device.name ?? 'Cihaz';
    
    String message;
    NotificationPriority priority;
    
    if (daysLeft <= 0) {
      message = '$deviceName bakımı GECİKTİ! Hemen yapılmalı.';
      priority = NotificationPriority.urgent;
    } else if (daysLeft <= 3) {
      message = '$deviceName bakımı $daysLeft gün içinde yapılmalı.';
      priority = NotificationPriority.high;
    } else {
      message = '$deviceName bakımı yaklaşıyor ($daysLeft gün kaldı).';
      priority = NotificationPriority.medium;
    }
    
    final notification = AppNotification(
      title: daysLeft <= 0 ? '⚠️ Bakım GECİKTİ' : '🔧 Bakım Zamanı Geldi',
      message: message,
      type: NotificationType.maintenanceReminder,
      priority: priority,
      relatedEntityType: 'device',
      relatedEntityKey: device.key,
    );
    
    await addNotification(notification);
  }

  /// 💰 Tahsilat beklentisi bildirimi
  Future<void> createCollectionReminder(List<dynamic> expenses) async {
    if (expenses.isEmpty) return;
    
    final totalAmount = expenses.fold<double>(
      0, 
      (sum, e) => sum + (e.amount ?? 0),
    );
    
    final notification = AppNotification(
      title: '💰 Tahsilat Beklentisi',
      message: '${expenses.length} adet raporlanmış masraf tahsil edilmedi. '
               'Toplam: ₺${totalAmount.toStringAsFixed(2)}',
      type: NotificationType.expense,
      priority: NotificationPriority.high,
    );
    
    await addNotification(notification);
  }

  /// 🔔 Stok uyarısı bildirimi
  Future<void> createStockAlert(dynamic stockItem, int remaining) async {
    final itemName = stockItem.name ?? 'Ürün';
    
    final notification = AppNotification(
      title: '📦 Stok Uyarısı',
      message: '$itemName stoğu kritik seviyede! (Kalan: $remaining adet)',
      type: NotificationType.stockAlert,
      priority: NotificationPriority.urgent,
      relatedEntityType: 'stock',
      relatedEntityKey: stockItem.key,
    );
    
    await addNotification(notification);
  }

  /// Demo bildirimler ekle
  Future<void> addDemoNotifications() async {
    if (_notifications.isNotEmpty) return;

    final demoNotifications = [
      AppNotification(
        title: 'Bakım Zamanı',
        message: 'Chemtry C8000 cihazının periyodik bakımı yapılmalı.',
        type: NotificationType.maintenanceReminder,
        priority: NotificationPriority.high,
      ),
      AppNotification(
        title: 'Stok Uyarısı',
        message: 'Filtre stoğu kritik seviyeye düştü (5 adet kaldı).',
        type: NotificationType.stockAlert,
        priority: NotificationPriority.urgent,
      ),
      AppNotification(
        title: 'Yeni Görev',
        message: 'Ankara için servis randevusu planlandı.',
        type: NotificationType.taskAssignment,
        priority: NotificationPriority.medium,
      ),
    ];

    for (final notification in demoNotifications) {
      await _notificationBox.add(notification);
    }

    // Demo hatırlatıcılar
    final demoReminders = [
      Reminder(
        title: 'Haftalık Rapor',
        description: 'Haftalık servis raporunu hazırla',
        reminderDate: DateTime.now().add(const Duration(days: 1)),
        isRepeating: true,
        repeatInterval: 'weekly',
      ),
      Reminder(
        title: 'Stok Sayımı',
        description: 'Aylık stok sayımı yapılacak',
        reminderDate: DateTime.now().add(const Duration(days: 3)),
      ),
    ];

    for (final reminder in demoReminders) {
      await _reminderBox.add(reminder);
    }

    _loadData();
  }

  /// Bildirim önceliğini servis önceliğine dönüştür
  services.NotificationPriority _convertToServicePriority(model.NotificationPriority priority) {
    switch (priority) {
          case model.NotificationPriority.low:
        return services.NotificationPriority.low;
      case model.NotificationPriority.medium:
        return services.NotificationPriority.normal;
      case model.NotificationPriority.high:
        return services.NotificationPriority.high;
      case model.NotificationPriority.urgent:
        return services.NotificationPriority.urgent;
    }
  }
}
