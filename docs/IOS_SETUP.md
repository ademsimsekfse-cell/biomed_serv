# iOS Yapılandırma Kılavuzu

## 📱 iOS Destek Özeti

Uygulamanız artık **iPhone ve iPad** için tam destekle hazırlandı! 

### ✅ Tamamlanan Yapılandırmalar

#### 1. Info.plist - İzinler ve Ayarlar
- ✅ **Kamera Erişimi** - Barkod/QR tarama, belge tarama
- ✅ **Fotoğraf Galerisi** - Logo yükleme, belge ekleme
- ✅ **Rehber Erişimi** - Müşteri yetkilisi ekleme
- ✅ **Konum Erişimi** - Servis kayıtları için konum
- ✅ **Bildirimler** - Bakım hatırlatmaları
- ✅ **Arka Plan Modu** - fetch ve remote-notification
- ✅ **HTTP Bağlantıları** - NSAllowsArbitraryLoads ayarı
- ✅ **iPad Multitasking** - UIRequiresFullScreen: NO
- ✅ **Tüm Yönlendirmeler** - Portrait, Landscape (iPhone/iPad)

#### 2. Podfile - Bağımlılıklar
- ✅ iOS 13.0+ desteği
- ✅ iPhone ve iPad Universal (TARGETED_DEVICE_FAMILY = 1,2)
- ✅ Swift 5.0 desteği
- ✅ Xcode 15+ uyumluluğu (DT_TOOLCHAIN_DIR düzeltmesi)
- ✅ CocoaPods otomatik yapılandırma

#### 3. AppDelegate.swift
- ✅ Bildirim izinleri isteme
- ✅ UNUserNotificationCenterDelegate implementasyonu
- ✅ Ön planda bildirim gösterimi (iOS 14+ banner desteği)
- ✅ Bildirim tıklama işleme

#### 4. Runner.entitlements
- ✅ iCloud Key-Value Store
- ✅ App Groups (Widget/Watch desteği için)
- ✅ Keychain Sharing
- ✅ WiFi Bilgisi Erişimi

#### 5. Diğer Yapılandırmalar
- ✅ LaunchScreen.storyboard - iPhone/iPad uyumlu
- ✅ iOS Build Workflow (.windsurf/workflows/ios-build.md)

---

## 🚀 iOS Build Talimatları

### Ön Koşullar (macOS Gereklidir!)

1. **macOS** işletim sistemi
2. **Xcode 14+** (App Store'dan indirilebilir)
3. **CocoaPods**:
   ```bash
   sudo gem install cocoapods
   ```
4. **Apple Developer Hesabı** (App Store için gerekli)

### Build Adımları

#### 1. Proje Hazırlama
```bash
cd /path/to/biomed_serv
flutter clean
flutter pub get
cd ios
pod install --repo-update
cd ..
```

#### 2. Simulator'da Test
```bash
flutter run -d ios
```

#### 3. Release Build
```bash
flutter build ios --release
```

#### 4. App Store Archive
```bash
flutter build ipa --release
```

veya Xcode ile açın:
```bash
open ios/Runner.xcworkspace
```
Xcode → Product → Archive

---

## 📐 Tablet ve Telefon Desteği

### iPhone Desteği
- ✅ Tüm iPhone modelleri (iPhone 6s ve üzeri)
- ✅ iOS 13.0+
- ✅ Portrait ve Landscape yönlendirmeler
- ✅ Notch/Dynamic Island desteği

### iPad Desteği
- ✅ Tüm iPad modelleri
- ✅ iPadOS 13.0+
- ✅ Split View (Çoklu görev) desteği
- ✅ Slide Over desteği
- ✅ Tüm yönlendirmeler (Portrait, Landscape, Upside Down)

### Responsive Tasarım
Flutter'ın otomatik responsive yapısı ile:
- ✅ Tablet için geniş ekran optimizasyonu
- ✅ Telefon için kompakt tasarım
- ✅ Klavye açıldığında otomatik düzenleme
- ✅ SafeArea desteği (Notch/Dynamic Island)

---

## 🔐 Gerekli İzin Açıklamaları (Türkçe)

| İzin | Açıklama |
|------|----------|
| **Kamera** | Cihaz barkod okuma, QR kod tarama ve belge tarama işlemleri için kamera erişimi gereklidir. |
| **Fotoğraf Galerisi** | Logo yükleme, belge ekleme ve galeriden görsel seçme işlemleri için fotoğraf galerisi erişimi gereklidir. |
| **Rehber** | Müşteri yetkilisi ekleme ve telefon rehberinden kişi seçme işlemleri için kişiler erişimi gereklidir. |
| **Konum** | Servis ve bakım kayıtlarında konum bilgisi eklemek için konum erişimi gereklidir. |
| **Bildirimler** | Bakım hatırlatmaları ve görev bildirimleri için yerel bildirim kullanımı gereklidir. |

---

## 🛠️ Sık Karşılaşılan Sorunlar ve Çözümleri

### 1. CocoaPods Hataları

**Sorun**: Pod install hatası
```bash
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
cd ..
```

### 2. Xcode Build Hataları

**Sorun**: DT_TOOLCHAIN_DIR hatası (Xcode 15+)
```bash
cd ios
sed -i '' 's/DT_TOOLCHAIN_DIR/TOOLCHAIN_DIR/g' Pods/Target\ Support\ Files/*/xcconfig
```

### 3. İmza Hataları

**Sorun**: Signing/profile hatası
- Xcode açın: `open ios/Runner.xcworkspace`
- Runner seçin → Signing & Capabilities
- Team seçin
- Automatically manage signing işaretleyin

### 4. Deployment Target Uyumsuzluğu

**Sorun**: Minimum iOS sürümü hatası
- Podfile'da `platform :ios, '13.0'` ayarlandı
- Xcode'da Deployment Target: iOS 13.0

---

## 📱 App Store Yayın Kontrol Listesi

### Yayın Öncesi
- [ ] Apple Developer Program üyeliği ($99/yıl)
- [ ] App Store Connect'te uygulama kaydı
- [ ] Bundle Identifier benzersiz ve doğru
- [ ] App Icon tüm boyutlarda (1024x1024 App Store)
- [ ] Ekran görüntüleri (iPhone 6.7", 6.5", 5.5", iPad 12.9", 11")
- [ ] Açıklama, anahtar kelimeler, destek URL'si
- [ ] Gizlilik Politikası URL'si
- [ ] TestFlight beta testi tamamlandı

### Gerekli App Store Bilgileri
- **Uygulama Adı**: Biomed Serv
- **Bundle ID**: `com.sirketadi.biomed-serv` (değiştirin)
- **Versiyon**: 1.0.0 (pubspec.yaml'dan alınır)
- **Kategori**: Business / Productivity
- **Yaş Sınırı**: 4+

---

## 🆘 Yardım ve Destek

Sorun yaşarsanız:

1. **Flutter Doctor**:
   ```bash
   flutter doctor -v
   ```

2. **iOS Build Log**:
   ```bash
   flutter build ios --verbose
   ```

3. **Xcode Log**:
   - Xcode açın
   - Window → Devices and Simulators
   - Cihaz seçin → Open Console

4. **Dokümantasyon**:
   - [Flutter iOS Deployment](https://docs.flutter.dev/deployment/ios)
   - [Apple Developer Documentation](https://developer.apple.com/documentation/)

---

## 📂 Yapılandırılan Dosyalar

```
ios/
├── Podfile                                    → Bağımlılık yönetimi
├── Runner/
│   ├── Info.plist                            → İzinler ve ayarlar
│   ├── AppDelegate.swift                     → Uygulama başlatma
│   ├── Runner.entitlements                   → Özellik yetkilendirmeleri
│   └── Base.lproj/
│       └── LaunchScreen.storyboard           → Başlangıç ekranı
└── Runner.xcodeproj/
    └── project.pbxproj                       → Xcode projesi

.windsurf/workflows/
└── ios-build.md                              → Build talimatları

docs/
└── IOS_SETUP.md                              → Bu doküman
```

---

## ✨ Sonuç

Uygulamanız şimdi **iOS 13.0+** sürümlerinde **iPhone ve iPad** için tam destekle hazır! 

- ✅ Universal App (iPhone + iPad)
- ✅ Tablet optimizasyonu (Split View, Multitasking)
- ✅ Tüm gerekli izinler yapılandırıldı
- ✅ Bildirim sistemi hazır
- ✅ App Store yayını için hazırlandı

**Not**: iOS build'i **sadece macOS** üzerinde yapılabilir. Windows/Linux üzerinde test amaçlı çalıştırılamaz.
