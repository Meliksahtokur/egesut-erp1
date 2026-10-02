VERDICT: KABUL

# Plan v7 — §10h H1–H8 re-review 5

Checkout: `ovsync-takip @ 40feed3`
Kapsam: yalnız §10h H1–H8 uygulaması, aktif artık çelişkiler ve bu turda açılan
kapsam-içi kritik kusur taraması. Salt-okuma; ürün kodu, migration, plan,
`.ss/`, DB, canlı ortam ve commit değiştirilmedi.

## (A) H1–H8 uygulama tablosu

| Karar | Hüküm | Plan v7 kanıtı ve bağımsız kontrol |
|---|---|---|
| H1 | **UYGULANDI** | `plan.md:6,192,326,421,424-428` eski-yol kilit eklerini geri alıyor, B9'a ayırıyor ve `start_first_service_protocol` düzeltmesini koruyor. P13'teki artık ifade B bölümünde ayrıca işaretlendi. |
| H2 | **UYGULANDI** | `plan.md:429,895` MK9-G tablosunu bilgi amaçlı/kabul dışı yapıyor ve eski-yol gözlemlerini B9'a yönlendiriyor. |
| H3 | **UYGULANDI** | `plan.md:299,391-392,447` tetikleyicinin hayvan kilidi almadığını, yeni yollarda hayvan → tohumlama → takip görevi yönünü yazıyor. Kaynak `20260923000005_ovsync_vaka_kapanis.sql:323-327,369-417` bayrak açık dalda hayvan kilidinin tohumlama INSERT'inden önce, kapalı dalda ise eski davranışın korunduğunu doğruluyor; yeni P3a tetikleyicisi için AB/BA kilidi planlanmıyor. |
| H4 | **KISMİ** | `plan.md:423,452` kilitsiz keşif → hayvan `FOR NO KEY UPDATE` → alt satır `FOR UPDATE` + yeniden doğrulama desenini verir; ancak `plan.md:299` bunu “hayvanlar ilk tablo erişimi” diye çelişkili yazar ve `plan.md:427` somut start düzeltmesinde alt görevi `FOR NO KEY UPDATE` yapar. C-1. |
| H5 | **KISMİ** | `plan.md:408,421-422,455` mevcut bulk/döngü-kilit davranışını koruyup onaysız satırı `TAKIP_ACIK` ile atlamayı ve onaylı alt küme retry'ını tarif ediyor. Fakat PG bulk'ın gerçek dönüş anahtarları `20260923000004_ovsync_pg_uygulama_kapisi.sql:516-534`, vaka bulk'ınki `20260906120000_vaka_toplu_ac.sql:735-738`; iki yol için ortak satır-sonucu alanı ve kesin payload şekli plan metninde kapanmıyor. C-2. |
| H6 | **UYGULANDI** | `plan.md:407,785` guard'ı yalnız tamamlama dalı ve iki muayene tipiyle sınırlar; `p_iptal=true` ile SUTTEN_KESME/padok dallarını korur ve üç-dal testi ister. Mevcut dallar `20260925000006_cila_t5_gorev_tamamla_p_iptal.sql:52-72,74-148` ile çaprazlandı. |
| H7 | **KISMİ** | `plan.md:299,455,783` N=30, beş çift, `lock_timeout='5s'`, `40P01`/`55P03` ve izinli sonuç kümesi şartlarını koyuyor; ancak küme “başarı veya belgelenmiş iş hatası ... vb.” biçiminde açık uçlu, çift başına sonlu kod/sonuç eşlemesi yok. C-3. |
| H8 | **UYGULANDI** | `plan.md:476,679` SQLSTATE kodunu `rpc()` hata dalında eşleyip otomatik retry'ı yasaklıyor. Mevcut doğru yer `js/api.js:71-96` (`if (error)` satırı güncel olarak :89; planın :93 locator'ı satır kaymış olsa da fonksiyon/branch doğrudur). |

Sayım: **5 UYGULANDI / 3 KISMİ / 0 UYGULANMADI**.

## (B) §10h ile çelişen aktif cümleler

Tarihsel v5/v6 sürüm notları bu bölüme alınmadı.

1. `plan.md:299` “hayvanlar ... **İLK tablo erişimi**” derken `plan.md:423` alt-satır kimliğinden **kilitsiz keşif** zorunlu kılar; child kimliği verilen girişlerde bu iki cümle aynı anda uygulanamaz.
2. `plan.md:387` `hizli_uygulama`/`seans_tamamla`/`bulk_ilac` gövde değişikliği olmadığını söylerken `plan.md:408,413-415` aynı RPC'lere yeni preflight ve imza parametresi ekliyor; :387 ifadesi “`_pg_olay_isle` ve tablo tetikleyicisi gövdesi değişmez” diye daraltılmalı.
3. `plan.md:717` ground-truth değişiklik listesinde “`tohumlama_sonuc_bos` üzerinden çekirdek kullanımı” ifadesini tutarken aynı maddede legacy `tohumlama_sonuc_bos` yeniden tanımının listeden çıktığını söylüyor; liste yeni sarmal Boş çekirdeğini açıkça adlandırmalı.

## (C) Bu turda açılan yeni bulgular

1. **ÖNEMLİ — H4 / P2b-P3b kilit sözleşmesi.** Kanıt: `plan.md:299,423,427`; önerilen düzeltme: tek normatif sıra olarak “child'dan kilitsiz keşif → hayvan `FOR NO KEY UPDATE` → child `FOR UPDATE` + yeniden doğrulama” yazılmalı ve start yolundaki `FOR NO KEY UPDATE` ya `FOR UPDATE` yapılmalı ya da H4'ün bilinçli istisnası olarak gerekçelendirilmelidir.
2. **ÖNEMLİ — H5 / P3b-P10 satır sonucu sözleşmesi.** Kanıt: `plan.md:408,421-422,455` ile mevcut `bulk_ilac` dönüşü `20260923000004_ovsync_pg_uygulama_kapisi.sql:516-534` ve `vaka_toplu_ac` dönüşü `20260906120000_vaka_toplu_ac.sql:735-738` farklı şekillerdedir; önerilen düzeltme: her iki RPC için `TAKIP_ACIK` satırının kesin alanını, onaylı/atlanmış/error kümelerini ve retry'da `p_animal_ids` eşlemesini tek bir makine-okunur sözleşme olarak yazın.
3. **ÖNEMLİ — H7 / P2b-P3b T-72b oracle'ı.** Kanıt: `plan.md:299,455,783` izinli sonuçları `TOH_SONUCLU`, `TAKIP_ACIK`, `GIRIS_CIFT_ANLAMLI` örnekleri ve “vb.” ile bırakıyor; önerilen düzeltme: beş çiftin her biri için sonlu `{başarı | izinli_hata_kodu}` kümesini, bilinmeyen/timeout sonuçlarının reddini ve tur rapor formatını açıkça tanımlayın.

Yeni bulgu sayısı: **3 (0 KRİTİK, 3 ÖNEMLİ, 0 KÜÇÜK)**. §10h H9 gereği önemli bulgular tek başına DÜZELTME verdict'i doğurmaz; uygulama öncesi sözleşme cila notlarıdır.

## (D) B9 notu

**B9 — kapsam dışı:** eski `gorev_tamamla` SUTTEN_KESME/padok sırası, `hizli_uygulama_geri_al` çok-satır zinciri, ham REST yazıcıları, legacy `tohumlama_sonuc_bos` ve genel `gorev_tamamla` kilit grafiği yalnız `plan.md:895`'teki backlog notudur; bu turda yeniden bulgu/verdict gerekçesi yapılmadı.

## Sınırlar ve doğrulama

- İnceleme plan v7 gövdesi, §10h otoritesi, domain-rules §14 ve §18.13–18.17, güncel kaynak migration/JS akışları ve mevcut dirty checkout korunarak yapıldı.
- Ürün testi, migration apply, canlı şema sorgusu, DB yazması, commit ve `.ss/` yazımı yapılmadı; bu rapor ürün PASS/deployment kanıtı değildir.
- Rapor kapsamı dışındaki mevcut değişiklikler korunmuştur.
