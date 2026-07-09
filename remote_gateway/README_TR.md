# Biomed Remote Gateway

Bu paket, Desktop merkez ile mobil teknisyenler aynı yerel ağda değilken
şifreli bir mesaj kuyruğu sağlar. Gateway karar vermez; eşleşme onayı, veri
birleştirme ve görev üretme yetkisi Desktop uygulamasında kalır.

## Gereksinimler

- PHP 8.1 veya üzeri
- PDO SQLite eklentisi
- HTTPS sertifikası
- `mod_rewrite` veya eşdeğer yönlendirme desteği
- Veritabanı klasörüne PHP yazma izni

FTP yalnızca bu dosyaları sunucuya yüklemek için kullanılabilir. Statik HTML
hosting, FTP depolama alanı veya yalnızca dosya sunan CDN üzerinde API çalışmaz.

## Kurulum

1. `config.example.php` dosyasını `config.php` adıyla çoğaltın.
2. `center_token` için en az 32 karakter rastgele bir değer üretin.
3. `site_code` için kuruma özel, tahmin edilmesi zor bir kod belirleyin.
4. `database_path` değerini mümkünse `public_html` dışındaki bir klasöre verin.
5. `public` klasörünün içeriğini alan adındaki gateway klasörüne yükleyin.
6. Web sunucusunun belge kökünü `public` klasörüne yönlendirin.
7. Tarayıcıda `https://alanadiniz/.../health` adresini açın.

Beklenen yanıt:

```json
{"ok":true,"protocol":"biomed-servis-remote-v1","version":"1.0.0"}
```

## Güvenlik

- Canlı kullanımda `require_https` değerini kapatmayın.
- Desktop merkez anahtarını mobil cihazlara vermeyin.
- Mobil cihazlar eşleşme sonrası ayrı bir cihaz anahtarı alır.
- `config.php` ve SQLite veritabanını web kökü dışında saklayın.
- Hosting yedekleme ve erişim kayıtlarını düzenli kontrol edin.
- Sağlık/servis verileri için kurumunuzun KVKK saklama politikasını uygulayın.

## Endpoint Özeti

- `GET /health`
- `POST /v1/pair/request`
- `GET /v1/pair/status`
- `GET /v1/center/pairings`
- `POST /v1/center/pairings/{id}/approve`
- `POST /v1/center/pairings/{id}/reject`
- `POST /v1/mobile/sync`
- `POST /v1/mobile/outbox/{id}/ack`
- `GET /v1/center/inbox`
- `POST /v1/center/inbox/{id}/ack`
- `POST /v1/center/outbox`
