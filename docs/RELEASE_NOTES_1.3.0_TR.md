# Biomed Servis 1.3.0

## Merkez ve mobil senkronizasyon

- Desktop uygulamasi yerel API merkezi olarak otomatik baslar.
- Mobil uygulama merkezi UDP 8788 ile otomatik bulur; gerekirse yerel IP taramasina gecer.
- Veri aktarimi TCP 8787 uzerinden onayli teknisyen eslesmesiyle yapilir.
- Bekleyen eslesmeler Desktop menusu ve Senkron Merkezi ekraninda rozetle gorunur.
- Merkezde atanan kurum, cihaz ve ariza gorevleri mobil cihaza aktarilir.
- Mobilde tamamlanan islemler, formlar, masraflar ve durum degisiklikleri merkeze doner.
- Senkron sonrasi cihaz, cari, teknisyen, firma ve ariza ekranlari canli yenilenir.

## Internet uzerinden baglanti

- PHP 8.1, PDO SQLite ve HTTPS destekli Biomed Remote Gateway paketi eklendi.
- Yerel ag tercihli, yalnizca yerel veya yalnizca uzak baglanti secilebilir.
- Uzak eslesmeler de Desktop onay kuyrugunda gorunur.
- Mobil gorev paketleri kaydedildikten sonra teslim onayi verir; baglanti kesilirse veri kaybolmaz.

## Windows kurulumu

- Sabit AppId sayesinde yeni surumler mevcut kurulumun uzerine guncellenir.
- Installer TCP 8787 ve UDP 8788 izinlerini yalnizca yerel alt ag icin ekler.
- Ayarlar ekranindan guvenlik duvari izinleri eklenebilir ve yerel API test edilebilir.

## Surum

- Uygulama surumu: 1.3.0
- Android build: 6
