import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'haptic_service.dart';

/// 🔊 Ses Efektleri Servisi
/// 
/// Uygulama genelinde ses efektleri için kullanılır.
/// Başarı, hata, bildirim ve işlem sesleri için farklı sesler çalar.
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _initialized = false;
  bool _soundEnabled = true;

  /// Ses efektleri etkin mi?
  bool get soundEnabled => _soundEnabled;

  /// Servisi başlat
  Future<void> initialize() async {
    if (_initialized) return;
    
    debugPrint('🔊 SoundService başlatılıyor...');
    
    // Audio player ayarları
    await _audioPlayer.setVolume(1.0);
    await _audioPlayer.setReleaseMode(ReleaseMode.release);
    
    _initialized = true;
    debugPrint('✅ SoundService başlatıldı');
  }

  /// Ses efektlerini aç/kapat
  void toggleSound() {
    _soundEnabled = !_soundEnabled;
    debugPrint('🔊 Ses efektleri: ${_soundEnabled ? 'AÇIK' : 'KAPALI'}');
  }

  /// 🔊 Başarı sesi çal + haptic
  Future<void> playSuccess() async {
    // 📳 Haptic feedback
    await HapticService().success();
    
    if (!_soundEnabled || !_initialized) return;
    
    try {
      // Yüksek tonlu, kısa başarı sesi
      await _audioPlayer.play(AssetSource('sounds/success.wav'));
      debugPrint('🔊 Başarı sesi çalındı');
    } catch (e) {
      debugPrint('🚨 Ses çalma hatası: $e');
      // Hata durumunda sistem sesi kullan
      await _playSystemSound(SoundType.success);
    }
  }

  /// 🔊 Hata sesi çal + haptic
  Future<void> playError() async {
    // 📳 Haptic feedback - çift titreşim
    await HapticService().error();
    
    if (!_soundEnabled || !_initialized) return;
    
    try {
      // Düşük tonlu, kısa hata sesi
      await _audioPlayer.play(AssetSource('sounds/buzz.wav'));
      debugPrint('🔊 Hata sesi çalındı');
    } catch (e) {
      debugPrint('🚨 Ses çalma hatası: $e');
      // Hata durumunda sistem sesi kullan
      await _playSystemSound(SoundType.error);
    }
  }

  /// 🔊 Bildirim sesi çal + haptic
  Future<void> playNotification() async {
    // 📳 Haptic feedback
    await HapticService().notification();
    
    if (!_soundEnabled || !_initialized) return;
    
    try {
      // Orta tonlu bildirim sesi
      await _audioPlayer.play(AssetSource('sounds/notification.wav'));
      debugPrint('🔊 Bildirim sesi çalındı');
    } catch (e) {
      debugPrint('🚨 Ses çalma hatası: $e');
      await _playSystemSound(SoundType.notification);
    }
  }

  /// 🔊 PDF/Rapor oluşturma sesi çal
  Future<void> playPdfGenerated() async {
    if (!_soundEnabled || !_initialized) return;
    
    try {
      // Kağıt/ yazıcı sesi
      await _audioPlayer.play(AssetSource('sounds/paperscroll.wav'));
      debugPrint('🔊 PDF sesi çalındı');
    } catch (e) {
      debugPrint('🚨 Ses çalma hatası: $e');
      await _playSystemSound(SoundType.success);
    }
  }

  /// 🔊 Tarama/ Barkod sesi çal + haptic
  Future<void> playScan() async {
    // 📳 Haptic feedback - scan
    await HapticService().notification();
    
    if (!_soundEnabled || !_initialized) return;
    
    try {
      // Kısa bip sesi
      await _audioPlayer.play(AssetSource('sounds/beep.wav'));
      debugPrint('🔊 Tarama sesi çalındı');
    } catch (e) {
      debugPrint('🚨 Ses çalma hatası: $e');
    }
  }

  /// 🔊 Tıklama sesi çal + haptic
  Future<void> playClick() async {
    // 📳 Haptic feedback - button press
    await HapticService().buttonPress();
    
    if (!_soundEnabled || !_initialized) return;
    
    try {
      // Çok kısa tıklama sesi
      await _audioPlayer.play(AssetSource('sounds/click.wav'));
    } catch (e) {
      // Tıklama sessiz olabilir
    }
  }

  /// 🔊 Kayıt başarılı sesi çal + haptic
  Future<void> playSaveSuccess() async {
    // 📳 Haptic feedback - önemli işlem
    await HapticService().important();
    
    if (!_soundEnabled || !_initialized) return;
    
    try {
      await _audioPlayer.play(AssetSource('sounds/success.wav'));
      debugPrint('🔊 Kayıt başarılı sesi çalındı');
    } catch (e) {
      debugPrint('🚨 Ses çalma hatası: $e');
      await _playSystemSound(SoundType.success);
    }
  }

  /// 🔊 Silme/iptal sesi çal
  Future<void> playDelete() async {
    if (!_soundEnabled || !_initialized) return;
    
    try {
      await _audioPlayer.play(AssetSource('sounds/buzz.wav'));
      debugPrint('🔊 Silme sesi çalındı');
    } catch (e) {
      debugPrint('🚨 Ses çalma hatası: $e');
    }
  }

  /// Sistem sesi çal (yedek olarak)
  Future<void> _playSystemSound(SoundType type) async {
    // Platforma özgü sistem sesleri burada çalınabilir
    // Şimdilik sadece log
    debugPrint('🔊 Sistem sesi: $type');
  }

  /// Servisi kapat
  Future<void> dispose() async {
    await _audioPlayer.dispose();
    _initialized = false;
    debugPrint('🔊 SoundService kapatıldı');
  }
}

/// Ses türleri
enum SoundType {
  success,
  error,
  notification,
  click,
  scan,
}
