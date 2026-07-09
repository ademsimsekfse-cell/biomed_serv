// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppNotificationAdapter extends TypeAdapter<AppNotification> {
  @override
  final int typeId = 37;

  @override
  AppNotification read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppNotification(
      title: fields[0] as String,
      message: fields[1] as String,
      type: fields[2] as NotificationType,
      priority: fields[3] as NotificationPriority,
      scheduledFor: fields[5] as DateTime?,
      relatedEntityType: fields[7] as String?,
      relatedEntityKey: fields[8] as int?,
      actionRoute: fields[9] as String?,
    )
      ..createdAt = fields[4] as DateTime
      ..isRead = fields[6] as bool;
  }

  @override
  void write(BinaryWriter writer, AppNotification obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.message)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.priority)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.scheduledFor)
      ..writeByte(6)
      ..write(obj.isRead)
      ..writeByte(7)
      ..write(obj.relatedEntityType)
      ..writeByte(8)
      ..write(obj.relatedEntityKey)
      ..writeByte(9)
      ..write(obj.actionRoute);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotificationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ReminderAdapter extends TypeAdapter<Reminder> {
  @override
  final int typeId = 38;

  @override
  Reminder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Reminder(
      title: fields[0] as String,
      reminderDate: fields[2] as DateTime,
      description: fields[1] as String?,
      isRepeating: fields[3] as bool,
      repeatInterval: fields[4] as String?,
      relatedEntityType: fields[6] as String?,
      relatedEntityKey: fields[7] as int?,
    )
      ..isActive = fields[5] as bool
      ..createdAt = fields[8] as DateTime;
  }

  @override
  void write(BinaryWriter writer, Reminder obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.description)
      ..writeByte(2)
      ..write(obj.reminderDate)
      ..writeByte(3)
      ..write(obj.isRepeating)
      ..writeByte(4)
      ..write(obj.repeatInterval)
      ..writeByte(5)
      ..write(obj.isActive)
      ..writeByte(6)
      ..write(obj.relatedEntityType)
      ..writeByte(7)
      ..write(obj.relatedEntityKey)
      ..writeByte(8)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class NotificationTypeAdapter extends TypeAdapter<NotificationType> {
  @override
  final int typeId = 35;

  @override
  NotificationType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return NotificationType.serviceReminder;
      case 1:
        return NotificationType.maintenanceReminder;
      case 2:
        return NotificationType.warrantyExpiration;
      case 3:
        return NotificationType.stockAlert;
      case 4:
        return NotificationType.taskAssignment;
      case 5:
        return NotificationType.general;
      case 6:
        return NotificationType.device;
      case 7:
        return NotificationType.expense;
      default:
        return NotificationType.serviceReminder;
    }
  }

  @override
  void write(BinaryWriter writer, NotificationType obj) {
    switch (obj) {
      case NotificationType.serviceReminder:
        writer.writeByte(0);
        break;
      case NotificationType.maintenanceReminder:
        writer.writeByte(1);
        break;
      case NotificationType.warrantyExpiration:
        writer.writeByte(2);
        break;
      case NotificationType.stockAlert:
        writer.writeByte(3);
        break;
      case NotificationType.taskAssignment:
        writer.writeByte(4);
        break;
      case NotificationType.general:
        writer.writeByte(5);
        break;
      case NotificationType.device:
        writer.writeByte(6);
        break;
      case NotificationType.expense:
        writer.writeByte(7);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class NotificationPriorityAdapter extends TypeAdapter<NotificationPriority> {
  @override
  final int typeId = 36;

  @override
  NotificationPriority read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return NotificationPriority.low;
      case 1:
        return NotificationPriority.medium;
      case 2:
        return NotificationPriority.high;
      case 3:
        return NotificationPriority.urgent;
      default:
        return NotificationPriority.low;
    }
  }

  @override
  void write(BinaryWriter writer, NotificationPriority obj) {
    switch (obj) {
      case NotificationPriority.low:
        writer.writeByte(0);
        break;
      case NotificationPriority.medium:
        writer.writeByte(1);
        break;
      case NotificationPriority.high:
        writer.writeByte(2);
        break;
      case NotificationPriority.urgent:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationPriorityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
