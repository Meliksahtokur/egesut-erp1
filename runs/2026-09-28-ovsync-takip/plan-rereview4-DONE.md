SONUÇ: KISMI
VERDICT: DÜZELTME

Salt-okuma plan v6 re-review tamamlandı. Checkout: `40feed3`.
Ürün kodu, migration, plan, `.ss/`, DB ve canlı ortam değiştirilmedi; test,
migration apply ve canlı sorgu çalıştırılmadı. Sahip talimatı gereği yazılan tek
çıktı bu DONE dosyasıdır; `plan-rereview4.md` yazılmadı.

## (A) rereview3 kalemlerinin kapanışı

- C3: **KISMİ** — MK9 dili eklendi; ancak gerçek grafik hâlâ tüm yazıcıları ve
  bazı çok-satırlı yardımcı zincirlerini kapsamıyor.
- C4: **KAPANDI** — `kizginlik_vaka_ac` için tanıdan bağımsız sunucu kapısı,
  onaylı aynı-transaction kapanış ve authenticated REST negatif testi tarifli.
- C5: **KAPANDI** — eski imza DROP/ACL, gerçek yanıt kaydı ve `PGRST202`/404
  beklentisi ayrı assertion'larla tarifli.

Sayım: **2 KAPANDI / 1 KISMİ / 0 AÇIK**.

## (B) rereview3 KISMİ satırlarının kapanışı

- D5: **KISMİ** — hayvan-önce yön genişledi; bayrak-kapalı eski yollar,
  tetikleyici sırası ve eksik yazıcılar kapanmadı.
- Önceki #9: **KISMİ** — muteks ve prova kapsamı genişledi; T-72b ölçüm oracle'ı
  ve gerçek graph kapsamı hâlâ eksik.
- Önceki #16: **KAPANDI** — `kizginlik_vaka_ac` kapı envanterine ve sunucu
  negatif testine bağlandı.
- #16 kapı listesi: **KAPANDI** — UI çağrı noktası ile yedi RPC listesi hizalı.

Sayım: **2 KAPANDI / 2 KISMİ / 0 AÇIK**.

## (C) v6 yeni bulguları

1. **KRİTİK — MK9-K/T bayrak-kapalı deadlock.** Plan, takip kapanışını
   `AFTER INSERT ON tohumlama` ve bayraktan bağımsız tarif ediyor
   (`plan.md:383-389`); aynı graph bayrak kapalı `tohumlama_kaydet` için hayvan
   muteksi yok, önceki `tohumlama` satırı `FOR UPDATE` diyor
   (`plan.md:429`, `20260923000005:323-327,369-375,417-444`). Sarmalın
   `hayvan → tohumlama` sırası (`plan.md:296`) ile yeni AFTER-trigger'ın
   `tohumlama → hayvan` yolu AB/BA döngü üretebilir. Bayrak açık/kapalı ayrı
   provası ve parent kilidini INSERT'ten önce alan tasarım gerekir.

2. **KRİTİK — MK9-G graph eksik/yanlış güvenli hücreler.** `gorev_tamamla`
   satırı yalnız padok kolunu düzeltir (`plan.md:404,437`), fakat mevcut
   `SUTTEN_KESME` kolu görevi önce kilitleyip helper üzerinden hayvanı güncelliyor
   (`20260925000006:39-70`, `20260620000003:18-50`; padok trigger'ı
   `20260717000001:148-153`). `hizli_uygulama_geri_al` da tek-satır güvenli
   değildir: kendisi ve geri-al trigger'ı birden fazla `gorev_log` satırını
   `array_agg`/`ANY` ile güncelleyebilir (`20260923000004:602-611,652-717`),
   ancak graph `plan.md:441` bunu tek satır sayıyor. Ayrıca repo doğrudan SQL/REST
   bypass yazıcılarını açıkça kabul ediyor (`20260831000003:3-6`,
   `20260925000018:7-14`); bunlar graph'ta yok. Tüm helper, trigger ve raw REST
   yolları ayrı hücre ve hükümle envantere alınmalı.

3. **KRİTİK — `vaka_toplu_ac` yalnız retry'ı kilitliyor.** Planın kilit maddesi
   yalnız `p_takip_onaylar` dolu onaylı retry'a `ORDER BY id` uyguluyor
   (`plan.md:418-419`); graph ve mevcut normal döngü ise kilitsiz, çok-satırlı ve
   girdi sırasına bağlı (`plan.md:435`, `20260906120000:488-523`). Retry'da
   onaysız satırların atlanması da PG bulk kadar açık tarif edilmemiş. İlk çağrı,
   retry kümesi, kilit kümesi ve dönüş sözleşmesi ayrıştırılmadan MK9 kapanmış
   sayılamaz.

4. **ÖNEMLİ — giriş NKU tarifleri uygulanabilirlik/revalidation açısından eksik.**
   `tohumlama_sonuc_bos` önce child `tohumlama` satırını okuyup sonra hayvanı
   kontrol ediyor (`20260924000001:520-536`); `kizginlik_vaka_ac` da önce
   `kizginlik_log` okuyor, sonra cases/tohumlama yazıyor
   (`20260526000002:27-62`). Plan yalnız “gövde girişinde hayvan NKU” diyor
   (`plan.md:323,448`); kilitsiz keşif → hayvan NKU → child `FOR UPDATE` ve
   yeniden doğrulama, ayrıca mevcut hata/idempotency dönüşlerinin korunması
   açık değil.

5. **ÖNEMLİ — MK9-P/T-72b ölçülebilir değil.** `plan.md:296,445,451,777`
   “deadlock üretmez; biri bekler sonra döner” diyor, fakat iki-session barrier,
   bounded timeout, SQLSTATE `40P01`/başarı-red oracle'ı, beklenen süre ve
   madde-öncesi kırmızı checkout tanımı yok. Kırmızı→yeşil iddiası bu haliyle
   yeniden üretilebilir kabul ölçütü değil.

6. **ÖNEMLİ — bulk kilit süresi ve seçili küme sözleşmesi açık değil.** Mevcut
   `bulk_ilac` bayrak açıkken tüm `p_animal_ids` hayvanlarını kilitleyip işlem
   döngüsü ve stok güncellemesi boyunca tutuyor (`20260923000004:402-495,497-513`);
   plan ise yalnız onaylı kimliklerin kilitlenip uygulanacağını söylüyor
   (`plan.md:405,647`). Retry'nin gerçekten yalnız seçili kümeyi kilitlemesi,
   lock lifetime ve büyük toplu çağrı sınırı tanımlanmalı.

7. **ÖNEMLİ — `gorev_tamamla` dönüş sözleşmesi korunmamış.** Mevcut T5
   `p_iptal=true` yolu başarılı iptal + audit döndürüyor
   (`20260925000006:52-63`; UI kullanımı `js/ui.js:1821-1844`). Yeni guard
   (`plan.md:404`) muayene tiplerinde bu dal için istisna tanımlamıyor; ayrıca
   hayvan kilidini görev kilidinden önce alma yöntemi için start'taki gibi
   kilitsiz keşif/relock/revalidation tarifi yok. `MUAYENE_SONUC_GEREKLI`,
   `p_iptal` ve `SUTTEN_KESME` dalları ayrı davranış testleriyle sabitlenmeli.

Yeni bulgu sayısı: **7 (3 KRİTİK, 4 ÖNEMLİ)**.

## Sınırlar

`pg_application_event` üzerinde mevcut migration'larda trigger olmadığı
checkout'tan doğrulandı (`20260923000002:471-517`); ilk-trigger notu bu tablo için
yeterli, fakat `tohumlama` üzerindeki mevcut AFTER trigger'ları için yeterli
değil. Raw PostgREST rol ACL'si canlı şema sorgulanmadı; bu nedenle doğrudan
REST erişimi ayrıca **UNMEASURED**, graph kapanışı ise PASS değildir.

Yeni SPEC/domain sorusu açılmadı. Plan v6 bu bulgular giderilmeden **KABUL**
değildir.
