# Fejox BioServ Audit Notes - 2026-05-10

## Audit Lens

- Google Play kalitesi
- saha teknisyeni ergonomisi
- veri butunlugu
- senkron guvenilirligi
- erisilebilir ve tamamlanmis akislari koruma

## Priority Buckets

### P0 - Must Fix First

- Kullaniciya gorunen bozuk karakterler ve yarim yerellestirme
- Senkron akisinin canli cift cihaz testi ve hata gunlukleri
- Form, stok, rapor, cihaz gibi ana modullerde buton var ama akisin tam bitmedigi durumlar
- Teknik servis ve cihaz iliskilerinde veri butunlugu kirabilecek akislari yeniden test etme

### P1 - Product Quality

- Cihaz, cari, rapor ve yedek ekranlarinda metin dili birligi
- Tum export/import akislari icin onizleme, bos sablon ve sonuc geri bildirimi
- Form gecmisi, cihaz gecmisi ve masraf akislarinda ayni davranis standardi
- Drawer ve tools icinde desktop/mobile ayrimlarinin her girdide tutarli olmasi

### P2 - Release Readiness

- Deprecated API temizligi
- BuildContext async gap duzeltmeleri
- Kullanilmayan import, dead code, eski helper ve sahte UI parcalarinin temizlenmesi
- Kod tabaninda kalan debug print ve notlarin kapatilmasi

## Confirmed Findings

1. Ekranlarda hala genis capli mojibake / karakter bozulmasi var.
2. Analiz temiz degil; su an cok sayida warning/info birikmis durumda.
3. Eski veya yari aktif ekran parcalari hala duruyor:
   - backup_screen.dart icinde kullanilmayan eski otomatik yedek bolumu
   - column_mapping_screen.dart icinde yorumla birakilmis import akisi notu ve printler
4. Store kalitesi acisindan metin birligi zayif:
   - ayni kavram farkli yerlerde farkli yaziliyor
   - Turkce karakterler bazen bozuk, bazen ASCII, bazen dogru
5. Senkron tarafi daha iyi ama hala tam operasyonel kabul testi gerekiyor:
   - eslestirme
   - onay
   - outbound sync
   - assigned bundle import
   - review queue
6. Kod tabaninda bakim borcu birikmis:
   - withOpacity
   - deprecated form/value kullanimlari
   - async context uyarilari

## Execution Order

1. Yuksek trafikli ekranlarda gorunen metinleri temizle
2. Kullanici aksiyonunun bosa dustugu yerleri kapat
3. Sync akisini iki cihaz senaryosunda test et
4. Veri butunlugu akislari icin cihaz-form-masraf zincirini tekrar dogrula
5. Son dalgada teknik borcu kademeli azalt

## Started In This Wave

- CSV sutun eslestirme ekranini temizleme
- Yedek ekranini sadeleştirme ve sahte otomatik yedek parcasini kaldirma
