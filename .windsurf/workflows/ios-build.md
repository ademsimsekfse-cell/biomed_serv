---
description: iOS Build Workflow - iPhone ve iPad için iOS uygulaması derleme
---

# iOS Build Workflow

## Ön Koşullar

1. macOS işletim sistemi (Xcode gerektirir)
2. Xcode 14+ yüklü olmalı
3. CocoaPods yüklü olmalı (`sudo gem install cocoapods`)
4. Apple Developer hesabı (App Store yayını için)

## Build Adımları

### 1. Bağımlılıkları Yükle

```bash
flutter clean
flutter pub get
cd ios
pod install --repo-update
cd ..
```

// turbo
### 2. iOS Simulator'da Test Et

```bash
flutter run -d ios
```

### 3. iOS Build Oluştur

Debug Build:
```bash
flutter build ios --debug
```

Release Build:
```bash
flutter build ios --release
```

### 4. Archive Oluştur (App Store için)

```bash
flutter build ipa --release
```

veya Xcode ile:
```bash
open ios/Runner.xcworkspace
```

Xcode'da: Product → Archive

## iPad ve iPhone Universal Desteği

Bu proje zaten iPad ve iPhone destekli yapılandırılmıştır:
- `UISupportedInterfaceOrientations` tüm yönlendirmeleri destekler
- `UIRequiresFullScreen` NO olarak ayarlandı (iPad multitasking için)
- `TARGETED_DEVICE_FAMILY = 1,2` (iPhone ve iPad)

## Yayın Öncesi Kontrol Listesi

- [ ] App Store Connect'te uygulama kaydı oluşturuldu
- [ ] Bundle Identifier doğru ayarlandı (com.sirketadi.biomed-serv)
- [ ] App Icon tüm boyutlarda hazır (1024x1024 App Store, diğerleri)
- [ ] Launch Screen hazırlandı
- [ ] Gizlilik Politikası URL'si hazır
- [ ] Ekran görüntüleri iPhone ve iPad için hazırlandı
- [ ] TestFlight için beta test grubu oluşturuldu

## Sık Karşılaşılan Sorunlar

### 1. Pod Install Hatası
```bash
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
```

### 2. Xcode 15+ DT_TOOLCHAIN_DIR Hatası
Podfile'da otomatik düzeltme var. Manuel düzeltme:
```bash
cd ios
sed -i '' 's/DT_TOOLCHAIN_DIR/TOOLCHAIN_DIR/g' Pods/Target\ Support\ Files/*/xcconfig
```

### 3. Swift Sürüm Uyumsuzluğu
Podfile'da `SWIFT_VERSION = '5.0'` ayarlandı.

### 4. İmza ve Provisioning Profile
Xcode → Runner → Signing & Capabilities:
- Team seçimi yapın
- Automatically manage signing işaretli olsun

## İletişim ve Destek

Sorunlar için:
1. `flutter doctor -v` çıktısını kontrol edin
2. iOS build log'larını inceleyin
3. Apple Developer Forum ve Flutter GitHub issues kontrol edin
