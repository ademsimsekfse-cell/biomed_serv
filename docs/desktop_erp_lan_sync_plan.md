# Fejox BioServ Desktop ERP ve LAN Senkron Görev Listesi

## Ürün Hedefi

Fejox BioServ Desktop, aynı yerel ağa bağlı teknisyen mobil cihazlarından gelen saha verilerini merkezde toplayan ERP görünümlü kontrol paneli olacak. Öncelik; servis formları, bakım formları, arıza kayıtları, cihaz geçmişleri, müşteri/cari ve cihaz ana kartlarının güvenli biçimde birleşmesidir.

## Faz 1 - Sağlam Senkron Omurgası

- Desktop uygulamada "Merkez Senkron" ekranı oluştur.
- Desktop tarafında yerel ağdan veri kabul eden mini HTTP sunucusu başlat/durdur.
- Mobil tarafta seçilen desktop IP adresine veri paketi gönderme altyapısı kur.
- İlk senkron kapsamını şu verilerle sınırla:
  - Müşteriler / cariler
  - Cihazlar
  - Servis formları
  - Bakım formları
  - Arıza kayıtları
- Merge kuralları:
  - Müşteri: kurum adı ile eşleştir, yoksa ekle.
  - Cihaz: seri numarası ile eşleştir, yoksa ekle.
  - Servis formu: form numarası ile eşleştir, yoksa ekle.
  - Bakım formu: form numarası ile eşleştir, yoksa ekle.
  - Arıza kaydı: arıza numarası ile eşleştir, yoksa ekle.
- Her senkron sonucunda eklenen, atlanan ve hatalı kayıt sayılarını göster.

## Faz 2 - ERP Dashboard

- Desktop ana görünümü ERP düzenine taşı:
  - Sol modül navigasyonu
  - Üst özet şeridi
  - Açık arızalar
  - Bugünkü servis hareketleri
  - Kritik stoklar
  - Tahsil/masraf özetleri
  - Cihaz yaşam döngüsü sinyalleri
- Teknisyen bazlı performans kartları ekle:
  - Toplam servis
  - Ortalama çözüm süresi
  - Açık iş sayısı
  - İmzasız/eksik form sayısı

## Faz 3 - Otomatik LAN Akışı

- Desktop merkez cihaz kendi IP/port bilgisini QR olarak göstersin.
- Mobil cihaz QR okutarak merkeze bağlansın.
- Mobil uygulama aynı ağı gördüğünde periyodik olarak bekleyen kayıtları göndersin.
- Bağlantı yoksa kuyrukta tutsun, ağ gelince tekrar denesin.
- Desktop aynı kaydı tekrar alırsa çoğaltmasın.

## Faz 4 - Veri Güvenliği ve Denetim

- Her senkron paketine kaynak cihaz, teknisyen, paket zamanı ve uygulama sürümü ekle.
- Desktop tarafında senkron geçmişi tut.
- Çakışma ekranı ekle:
  - Aynı seri numaralı cihazda farklı müşteri
  - Aynı form numarasında farklı içerik
  - Eksik müşteri/cihaz referansı
- Yedek alınmadan toplu import yapılmasını engelle.

## Faz 5 - Kurumsal Yaygınlaştırma

- Merkez veri dışa aktarma: Excel, PDF, ZIP yedek.
- Desktop çoklu filtreler:
  - Kurum
  - Cihaz
  - Teknisyen
  - Tarih aralığı
  - Arıza/servis/bakım türü
- Rol bazlı kullanım:
  - Yönetici
  - Servis sorumlusu
  - Teknisyen
  - Muhasebe/raporlama

## İlk Kod Etabı

Bu etapta hedef, ürünün LAN senkron temelini güvenli biçimde başlatmaktır:

- `LanSyncService` eklenecek.
- Desktop merkez sunucu başlatma/durdurma yapılacak.
- Mobil/desktop veri paketi oluşturabilecek.
- Desktop alınan paketi müşteri, cihaz, servis, bakım ve arıza kayıtlarına merge edebilecek.
- `DesktopSyncCenterScreen` ile ERP tarzı merkez ekranın ilk versiyonu eklenecek.

## Oto Senkron Davranışı

- Desktop uygulama açıldığında, ayar açıksa merkez dinleme otomatik başlar.
- Mobil cihazda merkez IP bir kez kaydedildikten sonra otomatik senkron açılabilir.
- Mobil cihaz Wi-Fi/local ağ değişimini dinler.
- Mobil cihaz, kayıtlı merkez IP ile kendi IP adresi aynı yerel subnet içindeyse veri göndermeyi dener.
- Mobil cihaz tek teknisyen kimliğiyle çalışır; teknisyen bilgileri ilk kurulumdan sonra düzenlenebilir.
- Mobil cihaz senkron öncesi desktop merkeze teknisyen erişim isteği gönderir.
- Desktop merkez onay vermeden mobil cihazdan veri kabul etmez.
- Desktop Merkez Senkron ekranı bekleyen teknisyenleri onaylama/reddetme alanı sunar.
- Aynı kayıtlar form numarası, arıza numarası, cihaz seri numarası ve müşteri adına göre tekrar eklenmez.
- Tekrarlı yük bindirmemek için otomatik gönderimler arasında minimum bekleme uygulanır.
