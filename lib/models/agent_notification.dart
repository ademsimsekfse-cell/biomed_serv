import 'package:flutter/material.dart';

enum NotificationType {
  criticalStock,
  devicePerformance,
  tenderExpiry,
  deviceEndOfLife
}

class AgentNotification {
  final String title;
  final String message;
  final NotificationType type;
  final IconData icon;
  final Color color;
  final dynamic relatedObjectKey; // İlgili nesnenin anahtarı (key)
  final String routeName; // Gidilecek ekranın rotası

  AgentNotification({
    required this.title,
    required this.message,
    required this.type,
    required this.icon,
    required this.color,
    this.relatedObjectKey,
    required this.routeName,
  });
}
