⟦ss-sub model=opus effort=high rol=ss-worker-high iş=Görev ile Protokol Uyarıları senkron sorununun kök nedenini canlı DB kanıtıyla bul, fix yazma⟧
sonuc: TAMAM
job_id: j-20261030T181742Z-9487d5
BOYUT: bütçe 0 · gerçek 0 · bütçe içinde (salt-okuma teşhis; üretim kodu ve DB değişmedi)

## Özet

Ekrandaki 14 satırın **5'i yanlış alarm**, **8'i gerçek eksik** (görev de açık, uyarı da açık, tutarlı), **1'i görevsiz uyarı** (169).

Kök neden tek bir üreticide: **`gebelik_protokol_kontrol` görevleri `etken_kod` yazmadan açıyor.** Tarayıcı ve dinleyici yalnız `etken_kod` ile eşleştiği için görev ile uyarı iki yönde de birbirini görmüyor. Etkilenen hayvanlar 907, 906, 207. Üçünün de `Gebe` tohumlaması geriye dönük INSERT ile girilmiş.

Sistem genelinde kopuk değil: `etken_kod` dolu görevlerde iki yön de çalışıyor (kanıt: "İki yön" bölümü). Önceki fix'ler bu üreticiye dokunmadığı için sorun geri geldi.

## Gelen iş denetimi

- "14 hayvan" aslında **10 hayvan, 14 satır**. Canlı tarama 14 satırı birebir veriyor, ayrıca listede olmayan 008 kızgınlık satırı var (toplam 15 eksik, 21 kayıt).
- `vaccinations` tablosu prod'da yok; gerçek tablo `vaccination_log`.
- `b81829e` bu repoda çözülmüyor (`git log`: bilinmeyen revizyon). OBSERVED
- Bunların dışında bulgu yok.

## Satır bazlı tablo

Tarih: 2026-10-30. "Şimdi uygulansa" sütunu canlı gövdelerden akıl yürütmedir (INFERRED): prod'a yazma yasağı nedeniyle koşulmadı.

| Küpe | Uyarı (hedef) | Görev durumu | Uygulama kaydı | Neden "eksik" | Sınıf | Şimdi uygulansa |
|---|---|---|---|---|---|---|
| 906 | SC Ademin (10-12) | `4541a539` etken **NULL**, done 10-12 | yok | `g.etken_kod='ADEMIN'` eşleşmiyor | **YANLIŞ ALARM** | gerekmez |
| 906 | IM E Vit (10-17) | `7171656a` etken **NULL**, done 10-19 | yok | aynı | **YANLIŞ ALARM** | gerekmez |
| 207 | SC Ademin (10-24) | `95cb4fdd` etken **NULL**, done 10-25 | yok | aynı | **YANLIŞ ALARM** | gerekmez |
| 207 | IM E Vit (10-29) | `dfa6026f` etken **NULL**, done 10-29 | yok | aynı | **YANLIŞ ALARM** | gerekmez |
| 906 | Rota (09-22) | `20bd2c65` etken **NULL**, **açık**, 09-25'te açıldı | `vaccination_log c03e8db3` **09-02** (planlı görev `b266cb77`) | aşı ±7 gün penceresi dışında (20 gün önce); görev aşıdan sonra doğdu | **YANLIŞ ALARM** (aşı yapılmış) | iki taraf da düşmez, çifte doz riski |
| 207 | Rota (10-04) | `2fae7f56` etken **NULL**, açık | yok | kayıt yok | GERÇEK eksik + tuzak | **Uyarıdan:** görev açık kalır, uyarı kalır. **Görevden:** görev kapanır, uyarı kalır |
| 145 | Rota (10-16) | `e0f8c513` ROTA, açık, instance doğru | yok | kayıt yok | GERÇEK eksik | iki yön de düşer |
| 154 | Rota (10-15) | `9303c788` ROTA, açık, instance doğru | yok | kayıt yok | GERÇEK eksik | iki yön de düşer |
| 155 | Rota (10-05) | `2981ace7` ROTA, açık, instance doğru | yok | kayıt yok | GERÇEK eksik | iki yön de düşer |
| 191 | Rota (10-15) | `3d9bcf7a` ROTA, açık, instance doğru | yok | kayıt yok | GERÇEK eksik | iki yön de düşer |
| 201 | Rota (10-13) | `b4871997` ROTA, açık, instance doğru | yok | kayıt yok | GERÇEK eksik | iki yön de düşer |
| 903 | Rota (10-16) | `24c1afad` ROTA, açık, instance doğru | yok | kayıt yok | GERÇEK eksik | iki yön de düşer |
| 196 | Rota (10-20) | `e52fc207` ROTA, açık; instance eski gebelikte (baslangic 2025-03-05) | yok | kayıt yok; legacy yol | GERÇEK eksik | iki yön de düşer (legacy ±3) |
| 169 | 39. Gün PG (10-26) | **görev yok**; d2/d11/d25 done | PG kaydı yok | görev de kayıt da yok | **GÖREVSİZ uyarı** | Uygula 10-30 tarihli yazılır, pencere 10-29'da bitti: **uyarı kalır** |

Sayım: 5 yanlış alarm + 8 gerçek eksik (207 Rota dahil) + 1 görevsiz = 14.

"Gerçek eksik" DB'ye göredir: sahada yapılıp sisteme girilmemiş olabilir (UNKNOWN). Destekleyici kanıt: son 75 günün Rota stok hareketlerinde bu 8 küpe yok. OBSERVED. `903+` farklı hayvandır (devlet küpesi ayrı) ve Rota'sı 09-10'da yapılmış; 903 ile karıştırılmamalı.

Protokol_dismiss: bu 10 hayvanda hiç kayıt yok. OBSERVED

## Kök neden

### KN-1: üretici `etken_kod` yazmıyor (a ve b yönünün ortak nedeni) — CONFIRMED

- Canlı `gebelik_protokol_kontrol` gövdesinde Rota 1. doz, Ademin ve E Vitamini INSERT'lerinde `etken_kod`, `kaynak` ve `protokol_instance_id` yok. Aynı fonksiyonun 2. doz INSERT'i ise `ROTA_2DOZ` yazıyor.
- Çağıran: `js/ui.js:384` `ileriGebeKontrol`, İleri Gebeler bandındaki butondan (`js/ui.js:519`). Cron ve başka SQL çağıranı yok. `degisim_log` bu görevlerin web istemcisi oturumundan açıldığını gösteriyor.
- Neden yalnız 3 hayvan: normal yol `trg_tohumlama_gebe_gorev`, görevleri `etken_kod` ile önceden açar, ama yalnız **AFTER UPDATE** tetiklenir. 906'nın tohumlaması `mgmt-api` rolüyle doğrudan `Gebe` INSERT edilmiş (`degisim_log` 09-25 14:23). 907 (09-10 11:20) ve 207 (09-10 13:04) de geç oluşturulmuş; onların INSERT kaynağı `degisim_log`'da yok (UNKNOWN). Hepsinde önceden açılmış görev yok, görevleri buton açıyor.
- Ölçüm: aktif hayvanlarda 9 protokol görevi `etken_kod` NULL (907, 906, 207 × 3). `etken_kod`lı görevi eksik başka aktif gerçek hayvan yok (yalnız "Test inek 2"). MEASURED

### Yön (a): görev done, uyarı düşmüyor — CONFIRMED

Tarayıcının görev eşlemesi (`20261013000004:404-413`) `g.etken_kod = v_a.ek` ister. NULL görev hiç eşleşmez. Ek olarak `detayTamamla` (`js/ui.js:11820`) stok seçimini yalnız `etken_kod` doluysa açar; NULL görev düz `gorev_tamamla`ya düşer. Bu yüzden `uygulama_log` da oluşmaz (stok da düşmez) ve yedek eşleme de tutmaz.

Karşılaştırma, aynı adım aynı gün:
- 155 Ademin `7e5cd8fa`, etken `ADEMIN`, done 10-25 15:35: **uyarı düştü**.
- 207 Ademin `95cb4fdd`, etken NULL, done 10-25 15:07: **uyarı duruyor**.

### Yön (b): uyarıdan giriş, görev düşmüyor — CONFIRMED

`_protokolUygulaKaydet` (`js/ui.js:6267`) `hizli_uygulama` çağırır, o `uygulama_log` yazar, `trg_dinle_uygulama` `_gorev_dinle`yi çalıştırır. `_gorev_dinle` görevi yalnız `etken_kod = p_etken_kod` ile bulur; NULL görev kapanmaz.

Karşılaştırma:
- 907 Ademin: `uygulama_log 84b72b84` 09-30 16:43, uyarı düştü ama görev `b45b0f0d` açık kaldı; `kapatan_ref` boş, **9 gün sonra** 10-09'da elle kapandı.
- 169 Rota: `uygulama_log af186939` 08-18, görev `06ca9d10` aynı anda kapandı, `kapatan_ref` dolu.

### KN-2: görevsiz ya da eşleşmeyen geç uygulama pencereye sığmıyor — CONFIRMED

- Uygulama penceresi hedef ±3 (`20261013000004:426-434`), Rota aşı penceresi ±7 (`:416-424`). Üst sınır geçince kayıt uyarıyı düşürmez; yalnız `etken_kod`lı görev kapanışı kurtarır.
- `hizli_uygulama` `p_occurred_at`'ı `uygulama_log.tarih`e **yazmıyor** (kolon varsayılanı `CURRENT_DATE`). Uygula ekranındaki tarih alanına geçmiş tarih girilse de satır bugünün tarihiyle yazılır. Canlı gövde + kolon varsayılanı.
- 169 ve 207/906 Rota bu yüzden uygulansa da düşmez.

### KN-3: 169 neden görevsiz — CONFIRMED

`dogum_kaydet` 09-01 ile 09-23 arasında d11 üretiyordu (regresyon); `20260923000001` d39'u geri getirdi ama "Veri UPDATE YOK" dedi. Tarayıcı ise d39 arıyor. Bu aralıkta doğuran iki hayvan var: 008 (PG dismiss'li, sessiz) ve 169. MEASURED

### Daha önceki fix'ler neden tutmadı — CONFIRMED

| Fix | Ne yaptı | Neden yetmedi |
|---|---|---|
| `20260603000001` / `000005` | mevcut görevlere `etken_kod` backfill | tek seferlik, üretici düzelmedi |
| `234aaec` | dismiss, eşleşen açık görevi kapatır | yine `etken_kod` ile sorgular (`js/ui.js:6369-6374`) |
| `20261013000004` (K8) | `fn_dinle_uygulama` log tarafında NULL etken; tarayıcıda iptal | görev tarafındaki NULL'a dokunmadı |

K8 canlıda ve drift yok: `protokol_eksik_tara`, `gorev_tamamla`, `fn_dinle_uygulama` gövdeleri migration ile birebir aynı. MEASURED. Testleri (`tests/unit/protokol-senkron-cift-yon.test.js`) yalnız SQL metni kontrol ediyor, bu senaryoyu kapsamıyor. OBSERVED

## Gerçek olaylar

| Yön | Olay | Kanıt |
|---|---|---|
| a | 906 Ademin görevi 10-12 done, uyarı 18 gündür duruyor | `4541a539`, `degisim_log` 10-12 07:58 |
| a | 906 E Vit 10-19 done, uyarı duruyor | `7171656a` |
| a | 207 Ademin 10-25, E Vit 10-29 done, uyarı duruyor | `95cb4fdd`, `dfa6026f` |
| b | 907 Ademin uyguladı, görev 9 gün açık kaldı | `84b72b84` ve `b45b0f0d` |
| dismiss | 907 E Vit 10-03 ✕ edildi, görev 10-25'e kadar açık kaldı | dismiss `ef861259`, görev `a694c686` |
| b (INFERRED) | 907 Rota 09-11: 2 Hızlı Uygulama + 2 Geri Al + Aşı. Kullanıcı görevi kapatamayıp yolu değiştirmiş olabilir | yalnız `stok_hareket`; `degisim_log` o tarihte kayıt tutmuyor |

## Ek bulgular (bu 14 satırı açıklamıyor)

1. **Dismiss görevleri topluca iptal ediyor.** `_protokolDismiss` tarih bakmadan hayvanın o etkenli tüm açık görevlerini kapatıyor (`js/ui.js:6369-6377`). 181'de 09-30'da bir PG ✕ edildi; hedefi 10-23 ve 11-06 olan görevler de iptal oldu. 5708'de de aynısı (09-26). CONFIRMED
2. **Dismiss süresiz.** Anahtar `(hayvan, etken, protokol)`, tarih filtresi yok. Bir PG ✕, o hayvanın sonraki laktasyonları dahil tüm PG adımlarını susturur. CONFIRMED (gövde); gelecekteki etkisi INFERRED
3. **191'de erken kapanış.** Ademin `51a66c91` ve E Vit `4647be58`, hedeflerinden 153-158 gün önce 06-04'te kapalı. 11-04 ve 11-09 uyarıları **hiç çıkmayacak**. `_gorev_dinle`de tarih penceresi yok. MEASURED
4. **Tek instance.** `kaynak_ref='ILERI_GEBE-<hayvan>'` hayvan başına tek ve `baslangic` güncellenmiyor; 196'da 2025-03-05'te kalmış. Şimdilik legacy yol kurtarıyor. OBSERVED
5. **Rota uyarıdan girilince** `vaccination_log`a değil `uygulama_log`a yazılıyor (169, 181, 163 vb.). Tarayıcı ikisine de bakıyor, ama aşı geçmişinde görünmeyebilir. Aşı geçmişi ekranı bu işte okunmadı. INFERRED
6. `ileri_gebe_gorev_kontrol` da `etken_kod` yazmıyor ama çağıranı yok (atlas 0, pg_proc 0, cron 0): ölü kod. Domain §15'teki "sabit Rota protokolü" notu buna atıf yapıyor; canlı akışı tetikleyici ile `gebelik_protokol_kontrol` yürütüyor. Not güncellenmeli. MEASURED

## Minimal fix önerisi (yazılmadı)

- **F1 (kök neden):** `gebelik_protokol_kontrol`un 3 INSERT'ine `etken_kod` (`ROTA`, `ADEMIN`, `E_VIT`) eklenir. Canlı gövde taban alınır. a ve b yönünü aynı anda kapatır. Test metin değil davranış ölçmeli: etken'li görev done → tara düşer; `hizli_uygulama` → görev kapanır.
- **F2 (KN-2):** `hizli_uygulama`, `p_occurred_at` gelirse `uygulama_log.tarih`e yazsın. Tarayıcı üst sınırı ayrı karar ister: aynı etkenli adımlar (PG d2/d25/d39) açılırsa geç bir doz sonraki adımı da düşürür.
- **F3 (opsiyonel):** tetikleyici INSERT'te de çalışsın ya da geriye dönük `Gebe` girişi görevleri baştan açsın.
- **F4 (ayrı iş):** dismiss kapsamı tarihe bağlansın (ek bulgu 1-2). `_gorev_dinle`ye alt sınır (ek bulgu 3).

## Veri onarımı gerekiyor mu: evet, 9 görev

| Onarım | Satır | Sonuç |
|---|---|---|
| `etken_kod` backfill | 9 görev (907, 906, 207 × 3) | 906 ve 207'nin Ademin + E Vit uyarıları düşer (4 satır). Hedefleri tarayıcı hedefiyle birebir aynı, legacy yol eşleşir (INFERRED, yazılmadı) |
| 906 Rota `20bd2c65` kapat | aynı 9'un içinde | `kapatan_ref=vaccination_log:c03e8db3`. **Doğrudan UPDATE ile**; `gorev_tamamla` kullanılmamalı, görevde `stok_id`+`miktar` var, K8 köprüsü sahte `uygulama_log` ve stok düşümü yazar |

Backfill sonrası: 5 yanlış alarmın 5'i kapanır. 207 Rota açık kalır ama artık normal çalışır. 8 gerçek eksik sahada uygulanmalı ya da yapıldıysa girilmeli.

## Sahip kararı gerekenler

Bu teşhisi bloke etmiyor; fix ve onarım brief'i için.

SORU: 906'nın 09-02 Rota dozu (hedeften 20 gün önce) geçerli sayılıp açık görev kapatılsın mı · seçenekler: kapat / yeniden aşıla · önerim: kapat (aksi çifte doz).
SORU: 169 d39 PG uyarısı ne olsun (d11'i almış, d39 görevi hiç açılmadı) · seçenekler: uygula / ✕ / F2 sonrası uygula · önerim: sahip klinik karar versin; bugün uygulanırsa uyarı F2 olmadan düşmez, PG ayrıca +48 s TAI açar.
SORU: 191'in 06-04'te kapanmış Ademin ve E Vit görevleri yeniden açılsın mı · seçenekler: aç / bırak · önerim: aç, yoksa 11-04 ve 11-09 uyarıları çıkmaz.

## Kanıt ve yöntem

- Canlı sorgular yalnız SELECT; `protokol_eksik_tara` gövdesi salt okuma olduğu doğrulandıktan sonra çağrıldı. `protokol_orphan_temizle` ve `protokol_gorev_bol` çağrılmadı. Prod'a yazma yok.
- SQL ve ham çıktılar: `~/tmp/t2/` (`a` tara gövdesi, `b` yardımcı gövdeler, `e` tara sonucu, `h*` satır kanıtı, `i*` üreticiler, `k*` ölçümler, `m*` ve `n*` olay zaman çizelgeleri).
- Kod keşfi: atlas (taze, HEAD `5d3f6a3`). gitnexus kullanılmadı; analyze koşulmadı (kod yazılmadı).
- `m5` çıktısındaki `acik_null` sütunu hayvan bazlıdır, adım bazlı değil; satır kanıtı olarak kullanılmadı.
- Görünmeyen: 09-2x öncesi `degisim_log` kaydı yok, 907/207 tohumlama INSERT kaynağı bu yüzden UNKNOWN. UI tarayıcıda koşulmadı.

**Yan etki, kendi hatam:** ilk sorgu betiğim göreli yol yüzünden `~/egesut-erp1/` altında 4 boş `*.sql.json` dosyası bıraktı. Boş olduklarını doğrulayıp yalnız onları sildim; ana checkout'ta başka değişiklik yapmadım.

## Kırıntılar

- measurement: 14 satır = 5 yanlış alarm + 8 gerçek eksik + 1 görevsiz (kanıt: `~/tmp/t2/`).
- gate (silent-success): `gebelik_protokol_kontrol` `etken_kod`suz görev üretiyor; görev ile uyarı sessizce kopuyor.
- open_item: 3 sahip kararı (906 Rota, 169 PG, 191 erken kapanış), F1-F4 fix brief'i.
