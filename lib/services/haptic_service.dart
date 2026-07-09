import 'package:flutter/services.dart';

/// 🎯 Haptic Feedback Servisi
/// Kullanıcı etkileşimlerinde fiziksel titreşim geri bildirimi sağlar
class HapticService {
  static final HapticService _instance = HapticService._internal();
  factory HapticService() => _instance;
  HapticService._internal();

  /// ✅ Başarılı işlem - Hafif titreşim
  Future<void> success() async {
    await HapticFeedback.lightImpact();
  }

  /// ❌ Hata - Güçlü titreşim
  Future<void> error() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 50));
    await HapticFeedback.heavyImpact();
  }

  /// ⚠️ Uyarı - Orta titreşim
  Future<void> warning() async {
    await HapticFeedback.mediumImpact();
  }

  /// 🔔 Bildirim - Selection titreşimi
  Future<void> notification() async {
    await HapticFeedback.selectionClick();
  }

  /// 📳 Vibrate - Uzun titreşim
  Future<void> vibrate() async {
    await HapticFeedback.vibrate();
  }

  /// 👆 Button tıklama - Selection
  Future<void> buttonPress() async {
    await HapticFeedback.selectionClick();
  }

  /// 📋 Liste kaydırma - Hafif
  Future<void> scroll() async {
    await HapticFeedback.lightImpact();
  }

  /// 🎯 Önemli olay - Medium + Light pattern
  Future<void> important() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 30));
    await HapticFeedback.lightImpact();
  }
}
