import 'package:hive/hive.dart';

part 'notification.g.dart';

/// Bildirim tipi enum
@HiveType(typeId: 35)
enum NotificationType {
  @HiveField(0)
  serviceReminder, // Servis hatırlatması
  @HiveField(1)
  maintenanceReminder, // Bakım hatırlatması
  @HiveField(2)
  warrantyExpiration, // Garanti bitişi
  @HiveField(3)
  stockAlert, // Stok uyarısı
  @HiveField(4)
  taskAssignment, // Görev atama
  @HiveField(5)
  general, // Genel bildirim
  @HiveField(6)
  device, // Yeni cihaz kaydı
  @HiveField(7)
  expense, // Masraf tahsilatı
}

/// Bildirim önceliği enum
@HiveType(typeId: 36)
enum NotificationPriority {
  @HiveField(0)
  low, // Düşük
  @HiveField(1)
  medium, // Orta
  @HiveField(2)
  high, // Yüksek
  @HiveField(3)
  urgent, // Acil
}

/// Bildirim modeli
@HiveType(typeId: 37)
class AppNotification extends HiveObject {
  @HiveField(0)
  late String title; // Bildirim başlığı

  @HiveField(1)
  late String message; // Bildirim mesajı

  @HiveField(2)
  late NotificationType type; // Bildirim tipi

  @HiveField(3)
  late NotificationPriority priority; // Öncelik

  @HiveField(4)
  late DateTime createdAt; // Oluşturma tarihi

  @HiveField(5)
  DateTime? scheduledFor; // Planlanan tarih (hatırlatma için)

  @HiveField(6)
  bool isRead; // Okundu mu?

  @HiveField(7)
  String? relatedEntityType; // İlişkili entity tipi (cihaz, form vb.)

  @HiveField(8)
  int? relatedEntityKey; // İlişkili entity key

  @HiveField(9)
  String? actionRoute; // Tıklanınca yönlendirilecek route

  AppNotification({
    required this.title,
    required this.message,
    required this.type,
    this.priority = NotificationPriority.medium,
    this.scheduledFor,
    this.relatedEntityType,
    this.relatedEntityKey,
    this.actionRoute,
  })  : createdAt = DateTime.now(),
        isRead = false;

  /// Öncelik rengi
  int get priorityColor {
    switch (priority) {
      case NotificationPriority.low:
        return 0xFF9E9E9E; // Gri
      case NotificationPriority.medium:
        return 0xFF2196F3; // Mavi
      case NotificationPriority.high:
        return 0xFFFF9800; // Turuncu
      case NotificationPriority.urgent:
        return 0xFFF44336; // Kırmızı
    }
  }

  /// Tip ikonu
  String get typeIcon {
    switch (type) {
      case NotificationType.serviceReminder:
        return 'build';
      case NotificationType.maintenanceReminder:
        return 'handyman';
      case NotificationType.warrantyExpiration:
        return 'security';
      case NotificationType.stockAlert:
        return 'inventory_2';
      case NotificationType.taskAssignment:
        return 'assignment';
      case NotificationType.general:
        return 'notifications';
      case NotificationType.device:
        return 'devices';
      case NotificationType.expense:
        return 'payments';
    }
  }

  /// Tip metni
  String get typeText {
    switch (type) {
      case NotificationType.serviceReminder:
        return 'Servis Hatırlatması';
      case NotificationType.maintenanceReminder:
        return 'Bakım Hatırlatması';
      case NotificationType.warrantyExpiration:
        return 'Garanti Uyarısı';
      case NotificationType.stockAlert:
        return 'Stok Uyarısı';
      case NotificationType.taskAssignment:
        return 'Görev Atama';
      case NotificationType.general:
        return 'Genel';
      case NotificationType.device:
        return 'Cihaz Kaydı';
      case NotificationType.expense:
        return 'Masraf Tahsilatı';
    }
  }
}

/// Hatırlatıcı (Reminder) modeli
@HiveType(typeId: 38)
class Reminder extends HiveObject {
  @HiveField(0)
  late String title; // Hatırlatma başlığı

  @HiveField(1)
  String? description; // Açıklama

  @HiveField(2)
  late DateTime reminderDate; // Hatırlatma tarihi

  @HiveField(3)
  late bool isRepeating; // Tekrarlayan mı?

  @HiveField(4)
  String? repeatInterval; // Tekrar aralığı (daily, weekly, monthly)

  @HiveField(5)
  bool isActive; // Aktif mi?

  @HiveField(6)
  String? relatedEntityType; // İlişkili entity

  @HiveField(7)
  int? relatedEntityKey; // İlişkili entity key

  @HiveField(8)
  late DateTime createdAt;

  Reminder({
    required this.title,
    required this.reminderDate,
    this.description,
    this.isRepeating = false,
    this.repeatInterval,
    this.relatedEntityType,
    this.relatedEntityKey,
  })  : isActive = true,
        createdAt = DateTime.now();

  /// Sonraki hatırlatma tarihini hesapla
  DateTime? get nextOccurrence {
    if (!isActive) return null;
    if (!isRepeating) return reminderDate;

    final now = DateTime.now();
    if (reminderDate.isAfter(now)) return reminderDate;

    switch (repeatInterval) {
      case 'daily':
        return reminderDate.add(Duration(days: ((now.difference(reminderDate).inDays / 1).ceil())));
      case 'weekly':
        return reminderDate.add(Duration(days: ((now.difference(reminderDate).inDays / 7).ceil() * 7)));
      case 'monthly':
        var nextDate = reminderDate;
        while (nextDate.isBefore(now)) {
          nextDate = DateTime(nextDate.year, nextDate.month + 1, nextDate.day);
        }
        return nextDate;
      default:
        return reminderDate;
    }
  }
}
