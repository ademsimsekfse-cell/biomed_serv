import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';

/// Yerel Bildirim Servisi
class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Bildirim servisini başlat
  static Future<void> initialize() async {
    // Timezone verilerini yükle
    tz.initializeTimeZones();

    // Android ayarları
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS ayarları
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Genel ayarlar
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Başlat
    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
  }

  /// Bildirim kanalı oluştur (Android)
  static Future<void> createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'biomed_serv_channel', // Kanal ID
      'Biomed Servis Bildirimleri', // Kanal Adı
      description: 'Servis ve bakım bildirimleri için kullanılır',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Anlık bildirim göster
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    NotificationPriority priority = NotificationPriority.high,
  }) async {
    // Android detayları
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'biomed_serv_channel',
      'Biomed Servis Bildirimleri',
      channelDescription: 'Servis ve bakım bildirimleri için kullanılır',
      importance: _getImportance(priority),
      priority: _getPriority(priority),
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );

    // iOS detayları
    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      badgeNumber: 1,
    );

    // Genel detaylar
    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Zamanlanmış bildirim göster
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    NotificationPriority priority = NotificationPriority.high,
    bool repeat = false,
    String? repeatInterval, // daily, weekly, monthly
  }) async {
    // Android detayları
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'biomed_serv_channel',
      'Biomed Servis Bildirimleri',
      channelDescription: 'Servis ve bakım bildirimleri için kullanılır',
      importance: _getImportance(priority),
      priority: _getPriority(priority),
    );

    // iOS detayları
    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Zaman dilimi dönüşümü
    final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(
      scheduledDate,
      tz.local,
    );

    if (repeat && repeatInterval != null) {
      // Tekrarlayan bildirim
      await _scheduleRepeatingNotification(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzScheduledDate,
        details: details,
        payload: payload,
        repeatInterval: repeatInterval,
      );
    } else {
      // Tek seferlik bildirim
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    }
  }

  /// Tekrarlayan bildirim planla
  static Future<void> _scheduleRepeatingNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails details,
    String? payload,
    required String repeatInterval,
  }) async {
    switch (repeatInterval) {
      case 'daily':
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
          matchDateTimeComponents: DateTimeComponents.time,
        );
        break;
      case 'weekly':
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
        break;
      default:
        // Varsayılan: günlük
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
          matchDateTimeComponents: DateTimeComponents.time,
        );
    }
  }

  /// Tüm bildirimleri iptal et
  static Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  /// Belirli bir bildirimi iptal et
  static Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// Bekleyen tüm bildirimleri getir
  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notificationsPlugin.pendingNotificationRequests();
  }

  /// Bildirim tıklama callback'i
  static void _onNotificationTap(NotificationResponse response) {
    // Burada bildirim tıklandığında yapılacak işlemler
    // Örn: Navigator ile ilgili ekrana gitme
    debugPrint('Bildirim tıklandı: ${response.payload}');
  }

  /// Öncelik dönüşümü (Android)
  static Importance _getImportance(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Importance.low;
      case NotificationPriority.normal:
        return Importance.defaultImportance;
      case NotificationPriority.high:
        return Importance.high;
      case NotificationPriority.urgent:
        return Importance.max;
    }
  }

  /// Priority dönüşümü (Android)
  static Priority _getPriority(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Priority.low;
      case NotificationPriority.normal:
        return Priority.defaultPriority;
      case NotificationPriority.high:
        return Priority.high;
      case NotificationPriority.urgent:
        return Priority.max;
    }
  }

  /// Örnek bildirim göster (Test için)
  static Future<void> showTestNotification() async {
    await showNotification(
      id: 999,
      title: 'Test Bildirimi',
      body: 'Biomed Servis bildirim sistemi çalışıyor!',
      payload: 'test',
    );
  }
}

/// Bildirim önceliği enum
enum NotificationPriority {
  low,    // Düşük
  normal, // Normal
  high,   // Yüksek
  urgent, // Acil
}
