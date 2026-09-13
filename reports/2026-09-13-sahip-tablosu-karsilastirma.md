# W5 — Sahibin Buzağı Tablosu ↔ Saha Defteri ↔ DB Karşılaştırması (salt-okuma)

Tarih: 2026-09-13 · Dal: `agent/dogum-tarih-denetimi` ·
Görev zarfı: `.ss/tasks/W5-sahip-tablosu-karsilastirma.md` · Öncül: W3 raporu (rev 2, `d2891d4`)

**Yöntem:** Üç kaynak canlı prod verisi üzerinden karşılaştırıldı: (1) sahibin
elektronik tablosu (W5 zarfı, birebir alındı), (2) saha defteri (W3 zarfı),
(3) DB — W3 çekimleri + bu turda `vaccination_log` (381 kayıt) ve buzağı tam
satırları. Analiz betiği: `reports/w3/w5_karsilastirma.py` (bu dalda).
DB'ye yazma yok, kod değişikliği yok.

## Özet

| Ölçüm | Değer |
|---|---|
| Tablo satırı | 47 (45 numaralı buzağı + xx + 2 numarasız 185/188 satırı) |
| **ÜÇÜ UYUMLU** | **22** — 32–52 arası tamamen + 74 |
| **DB=DEFTER≠TABLO** | **22** — 53'ten 73'e (74 hariç) + xx |
| **DB'DE YOK** | 2 (185, 188 → W3'te dolaylı tohumlama kanıtı var) |
| DB=TABLO≠DEFTER | 0 |
| ÜÇÜ FARKLI | 0 |
| Cinsiyet çelişkisi | 0 |
| Durum çelişkisi (tablo Canlı derken hayvan ölmüş) | 3 — buzağı 66, 70, 72 (DB=defter: Öldü) |
| Ölüm sebebi DB'de | **Hiçbiri** — tüm buzağıların `cikis_sebebi`/`cikis_tarihi` boş (37 "Tendon Kontraktürü", 63 "Gelişim Geriliği", xx "Erken Doğum" yalnız tabloda) |
| Tarih çelişkisinde gebelik penceresi kanıtı | Defter-DB'yi destekleyen **3** (66, 67, 69); tabloyu destekleyen **2** (68, 71 — ama annenin tohumlama kaydı da şüpheli); belirsiz **17** |
| Aşı kayıtlarının niteliği | Buzağı aşılarının **148/150'si 2026-06-01'de toplu üretilmiş**, tarihler DB doğumuna sabit **+60/+90 gün** → vaccination_log buzağı aralıkta **bağımsız tanık değil** |

**Ana sonuç:** Root ön karşılaştırması doğrulandı — 32–52 ve 74'te üç kaynak aynı;
**53–73 arasında sahibin tablosu defter ve DB'nin ikisinden de erken** (−2 ile
−33 gün, düzenli bir formülü yok; xx satırında tersine 12 gün geç). DB ile defter
22 çelişkili satırın **hepsinde** birbiriyle uyumlu. Hangi kaynağın doğru olduğu
sorusunda DB içi bağımsız kanıt yalnız gebelik penceresi sağlıyor ve sonuç
karışık (aşağıda satır satır) — **kesin hüküm sahibin teyidine muhtaç**.

## Üç yönlü karşılaştırma

Durum sütunu zarfın sınıflandırmasıdır. TABLO kolonu `tarih · cins · anne · durum`
şeklindedir; cins kodu D=düve/Dişi, E=erkek/Dana.

| # | TABLO | DEFTER | DB | Satır durumu | Not |
|---|---|---|---|---|---|
| 32 | 05.09.2025 · D · 156 · Canlı | 05.09.2025 · D · 156 | 2025-09-05 · D | **ÜÇÜ UYUMLU** | W3: dogum olayı yok, `anne_id` NULL (bkz. W3 satır 1) |
| — | 08.09.2025 · E · 185 · Canlı | (buzağısız) | — | **DB'DE YOK** | W3: dolaylı tohumlama kanıtı (+285g = 2025-09-08) |
| — | 08.09.2025 · D · 188 · Canlı | (buzağısız) | — | **DB'DE YOK** | W3: dolaylı tohumlama kanıtı (+270g = 2025-09-08) |
| 33 | 15.09.2025 · E · 1940-5621 · Satıldı | 15.09.2025 · E · 1940-5621 · ₺ | 2025-09-15 · E · Satıldı | **ÜÇÜ UYUMLU** | |
| 34 | 17.09.2025 · E · 145 · Satıldı | aynı | 2025-09-17 · E · Satıldı | **ÜÇÜ UYUMLU** | |
| 35 | 17.09.2025 · E · 177 · Satıldı | aynı | 2025-09-17 · E · Satıldı | **ÜÇÜ UYUMLU** | |
| 36 | 06.10.2025 · D · 142 · Canlı | aynı | 2025-10-06 · D | **ÜÇÜ UYUMLU** | |
| 37 | 08.10.2025 · D · 153 · Öldü (Tendon Kontraktürü) | 08.10.2025 · ex | 2025-10-08 · D · Öldü | **ÜÇÜ UYUMLU** | ölüm sebebi yalnız tabloda (DB boş) |
| 38 | 14.10.2025 · D · 182 · Canlı | aynı | 2025-10-14 · D | **ÜÇÜ UYUMLU** | |
| 39 | 19.10.2025 · E · 107 · Canlı | aynı | 2025-10-19 · E | **ÜÇÜ UYUMLU** | |
| 40 | 21.10.2025 · E · Küpesiz düve · Satıldı | aynı (Küpesiz düve) | 2025-10-21 · E · Satıldı | **ÜÇÜ UYUMLU** | anne adı üç kaynakta da serbest metin; DB'de `anne_id` NULL |
| 41 | 29.10.2025 · E · **8** · Satıldı | 29.10.2025 · **008** | 2025-10-29 · E · Satıldı | **ÜÇÜ UYUMLU** | "8" ↔ "008" aynı hayvan (normalize) |
| 42 | 02.11.2025 · E · 167 · Satıldı | aynı | 2025-11-02 · E · Satıldı | **ÜÇÜ UYUMLU** | |
| 43 | 03.11.2025 · E · 178 · Canlı | aynı | 2025-11-03 · E | **ÜÇÜ UYUMLU** | |
| 44 | 07.11.2025 · E · 162 · Canlı | aynı | 2025-11-07 · E | **ÜÇÜ UYUMLU** | W3 UY*: DB anne=904 ↔ defter 162 çelişkisi sürüyor (bkz. W3 satır 15) |
| 45 | 09.11.2025 · D · 197 · Canlı | aynı | 2025-11-09 · D | **ÜÇÜ UYUMLU** | |
| 46 | 13.11.2025 · D · 191 · Canlı | aynı | 2025-11-13 · D | **ÜÇÜ UYUMLU** | W3: 191 tohumlama aralığı 145g şüpheli |
| 47 | 13.11.2025 · E · 155 · Canlı | aynı | 2025-11-13 · E | **ÜÇÜ UYUMLU** | |
| 48 | 15.11.2025 · E · 5708 · Canlı | aynı | 2025-11-15 · E | **ÜÇÜ UYUMLU** | |
| 49 | 16.11.2025 · E · 2045 · Canlı | aynı | 2025-11-16 · E | **ÜÇÜ UYUMLU** | 2045 = 905 devlet kupe son-4 |
| 50 | 16.11.2025 · D · 179 · Öldü | aynı · ex | 2025-11-16 · D · Ölü | **ÜÇÜ UYUMLU** | |
| 51 | 17.11.2025 · D · 195 · Canlı | aynı | 2025-11-17 · D | **ÜÇÜ UYUMLU** | W3 R1: 195'e 100g arayla iki buzağı çakışması (31+51) sürüyor |
| 52 | 23.11.2025 · E · 181 · Öldü | aynı · ex | 2025-11-23 · E · Ölü | **ÜÇÜ UYUMLU** | |
| 53 | **24.11.2025** · E · 199 · Canlı · Alaca | 29.11.2025 · E | 2025-11-29 · E | **DB=DEFTER≠TABLO** | kanıt: belirsiz (her iki tarih pencerede, bkz. sonraki bölüm); ırk: tablo "Alaca" ↔ DB "Alaca Holstein" (aynı) |
| 54 | **28.11.2025** | 03.12.2025 | 2025-12-03 | **DB=DEFTER≠TABLO** | kanıt: belirsiz (283g vs 288g — ikisi de pencerede) |
| 55 | **01.12.2025** · D · 196 · Alaca | 04.12.2025 · D | 2025-12-04 · D | **DB=DEFTER≠TABLO** | belirsiz (271 vs 274); ırk Alaca=Alaca Holstein |
| 56 | **02.12.2025** · D · 101 · Red Holstein | 08.12.2025 | 2025-12-08 · D | **DB=DEFTER≠TABLO** | belirsiz (272 vs 278); ırk birebir ✓ |
| 57 | **02.12.2025** · D · 5638 · Öldü · Red Holstein | 09.12.2025 · ex | 2025-12-09 · D · Ölü | **DB=DEFTER≠TABLO** | belirsiz (275 vs 282); ırk ✓ |
| 58 | **05.12.2025** · E · Minik panda · Öldü | 12.12.2025 · ex | 2025-12-12 · E · Ölü | **DB=DEFTER≠TABLO** | kanıt yok (annenin tohumlama kaydı yok) |
| 59 | **09.12.2025** | 14.12.2025 | 2025-12-14 · E | **DB=DEFTER≠TABLO** | kanıt yok (5748'in tohumlama kaydı yok) |
| 60 | **12.12.2025** | 15.12.2025 | 2025-12-15 · E | **DB=DEFTER≠TABLO** | hiçbiri pencerede (319g/322g — annenin (904) tohumlama kaydı zaten W3'te şüpheli) |
| 61 | **12.12.2025** · D · 1956 | 18.12.2025 · D | 2025-12-18 · D | **DB=DEFTER≠TABLO** | belirsiz (270 vs 276) |
| 62 | **20.12.2025** · D · 154 · Alaca | 23.12.2025 · D | 2025-12-23 · D | **DB=DEFTER≠TABLO** | kanıt yok (154'ün tohumlama kaydı yok); ırk Alaca=Alaca Holstein |
| 63 | **21.12.2025** · D · 159 · Öldü (Gelişim Geriliği) · Alaca | 23.12.2025 · ex | 2025-12-23 · D · Ölü | **DB=DEFTER≠TABLO** | kanıt yok (159 DB'de yok); ölüm sebebi yalnız tabloda |
| 64 | **27.12.2025** | 12.01.2026 | 2026-01-12 · E | **DB=DEFTER≠TABLO** | belirsiz (267 vs 283 — ikisi de pencerede) |
| 65 | **31.12.2025** | 17.01.2026 | 2026-01-17 · E | **DB=DEFTER≠TABLO** | kanıt yok (161 DB'de yok) |
| 66 | **04.01.2026** · **Canlı** | 02.02.2026 · **ex** | 2026-02-02 · Ölü | **DB=DEFTER≠TABLO** | gebelik penceresi **defter-DB'yi destekliyor** (tablo 240g — biyolojik sınırın altında; DB 269g ✓). Durum: tablo Canlı derken hayvan ölmüş (defter: kronik pnömoni) |
| xx | **15.02.2026** (+12g) · Öldü (Erken Doğum) | 03.02.2026 · ex | 2026-02-03 (dogum olayı; hayvan kaydı yok) | **DB=DEFTER≠TABLO** | kanıt yok; tablo tek "tablo > defter" satırı |
| 67 | **03.01.2026** | 05.02.2026 | 2026-02-05 · E | **DB=DEFTER≠TABLO** | pencere **defter-DB'yi destekliyor** (tablo 244g — imkansız erken; DB 277g ✓) |
| 68 | **15.01.2026** | 06.02.2026 | 2026-02-06 · D | **DB=DEFTER≠TABLO** | pencere **tabloyu destekliyor** (tablo 289g ✓; DB 311g ✗ — W3'ün 176:311g şüphesi) AMA annenin tohumlama tarihi de doğrulanmamış → belirsiz, sahip teyidi |
| 69 | **17.01.2026** | 07.02.2026 | 2026-02-07 · D | **DB=DEFTER≠TABLO** | pencere **defter-DB'yi destekliyor** (tablo 250g — çok erken; DB 271g ✓) |
| 70 | **25.01.2026** · **Canlı** | 09.02.2026 · **ex** | 2026-02-09 · Ölü | **DB=DEFTER≠TABLO** | belirsiz (268 vs 283 — ikisi de pencerede). Durum: tablo Canlı, hayvan ölmüş |
| 71 | **04.02.2026** | 10.02.2026 | 2026-02-10 · E | **DB=DEFTER≠TABLO** | pencere **tabloyu destekliyor** (tablo 296g ✓; DB 302g ✗ — W3'ün 134:302g şüphesi) ama tohumlama kaydı doğrulanmamış → belirsiz |
| 72 | **06.02.2026** · **Canlı** | 15.02.2026 · **ex** (rota ishali) | 2026-02-15 · Ölü | **DB=DEFTER≠TABLO** | kanıt yok (175'in tohumlama kaydı yok). Durum: tablo Canlı, hayvan ölmüş |
| 73 | **09.02.2026** | 16.02.2026 | 2026-02-16 · E | **DB=DEFTER≠TABLO** | belirsiz (276 vs 283) |
| 74 | 19.02.2026 · D · 121 | aynı | 2026-02-19 · D | **ÜÇÜ UYUMLU** | çelişki dizisi burada kapanıyor |

*Tarih farkı deseni: tablo 53–73'te defterden −2 … −33 gün erken; sapma 64–69
arasında büyüyüp sonra kapanıyor; xx'te tersine tablo +12g geç. Düzenli bir
formül (ör. tohumlama+280) yok — bkz. aşağıda.*

## Tarih çelişkileri ve bağımsız kanıt (53+)

**Soru:** tablo mu, defter/DB mi doğru?

**Değerlendirilen bağımsız kanıt kaynakları ve sonuçları:**

1. **Annenin tohumlaması + gebelik süresi (≈260–300 gün):** tek kullanılabilir
   bağımsız kanıt. Satır satır sonucu yukarıdaki tabloda. Toplu: **defter-DB'yi
   destekleyen 3 satır** (66: tablo 240g, 67: 244g, 69: 250g — tablo tarihleri
   biyolojik olarak güçlükte imkansız erken doğum demek), **tabloyu destekleyen
   2 satır** (68: DB 311g, 71: DB 302g — ikisi de W3'ün "aralık şüpheli"
   bulgularıyla aynı inekler: 176 ve 134), **belirsiz 17 satır** (9'unda iki
   aday da pencerede, 60'ta hiçbiri değil, 7'sinde annenin tohumlama kaydı yok).
2. **`vaccination_log` aşı tarihleri — bağımsız DEĞİL:** 45 buzağın 150 aşı
   kaydından **148'i 2026-06-01'de (toplu içe aktarma günü) tek seferde
   üretilmiş**; tarihlerin DB doğumuna sapması **hepsinde sabit +60/+60/+90/+90
   gün** (51: +144; 32: kayıt yok). Yani aşı tarihleri DB'deki doğum tarihinden
   türetilmiş; hangi doğumun gerçek olduğunu ayrıştıramaz. (Dolaylı not: 51'in
   iki kaydı 2026-05-10'da elle girilmiş tek istisna.)
3. **Devlet küpe seri sırası — ayrımcı değil:** seride kayıt seyrek (8 buzağı)
   ve doğum sırasına değil — 31←…354 doğum 09.08, 32←…353 doğum 05.09 (ters);
   45←…056 / 46←…055 (ters). Kupilama muhtemelen ele geçme sırasına yapılmış.
4. **`uygulama_log`:** buzağı 31–74 aralığında **hiç kayıt yok** (120 kaydın
   tamamı diğer hayvanlar + test).
5. **`created_at`:** buzağı satırları iki toplu dalgada gelmiş (51 ve birkaçı
   2026-05-09; kalanı 2026-06-01) — giriş anını taşımaz.
6. **`islem_log`:** kapsamı 2026-05-09 sonrası; ilk kayıtların öncesine inmez.

**Yorum:** Kanıt çoğunlukla defter-DB yönünde ama iki istisna önemli: 68 ve 71'de
gebelik penceresi tabloyu destekliyor — çünkü W3'te zaten bu iki ineğin
(176, 134) DB/defter doğumu, tohumlama tarihine göre "çok geç" bulunmuştu. İki
olasılık ayırt edilemiyor: (a) tablo doğru, bu iki buzağın DB/defter doğum
tarihi geç yazılmış; (b) defter doğru, bu iki ineğin tohumlama tarihi erken
yazılmış. **Sahip teyidi olmadan hüküm yok.** 53–57, 61, 64, 70, 73'te ise
fark küçük (3–6 gün) ve pencere her iki tarihi de kabul ediyor — pratikte
hayvancılık açısından anlamsız fark, kayıt tutarlılığı açısından tablo
tarafı düzeltilmeli.

**Desen bulgusu:** tablo tarihlerinde düzenli bir formül yok (tohumlama+280,
doğum+X, muayene+Y desenlerinin hiçbiri 22 satırı açıklamıyor). xx satırının
tablo tarihinin (15.02) "erken doğum"dan 12 gün SONRA olması, tablodaki bu
satırın tahmini/planlanan tarihten yazıldığını düşündürüyor; 66'nın tablo
tarihinin (04.01) annenin tohumlamasının tam +240. günü olması da aynı şüphoyu
besliyor (tek satırlık tesadüf olabilir).

## Diğer farklar

| Konu | Tablo | Defter | DB | Değerlendirme |
|---|---|---|---|---|
| 40 annesi | Küpesiz düve | Küpesiz düve | `anne_id` NULL | Tablo=defter; DB anne bağlantısı yok (W3 düzeltme maddesi) |
| 41 annesi | 8 | 008 | 008 | Aynı hayvan (sıfır dolgulu) — çelişki yok |
| 58 annesi | Minik panda | Minik panda | `anne_id` NULL | Tablo=defter; DB bağlantı yok |
| 66 durumu | Canlı | ex (kronik pnömoni) | **Ölü** | Tablo güncel değil; DB=defter. Ölüm sebebi DB'de yok |
| 70 durumu | Canlı | ex | **Ölü** | Aynı; sebep defterde de yok |
| 72 durumu | Canlı | ex (rota ishali) | **Ölü** | Aynı; sebep yalnız defterde |
| 63 ölüm sebebi | Gelişim Geriliği | (yok) | boş | DB ölüm sebebi hiç tutmuyor (`cikis_sebebi` tüm buzağılar boş) |
| 37 ölüm sebebi | Tendon Kontraktürü | — | boş | Aynı şekilde yalnız tabloda |
| xx ölüm sebebi | Erken Doğum | erken doğum | boş | Yalnız tabloda |
| Irk | Alaca (53, 55, 62, 63) | — | **Alaca Holstein** | Uyumlu kabul edilebilir; tablo kısaltıyor |
| Irk | Red Holstein (56, 57) | — | Red Holstein | Birebir ✓ |
| Aşı (Q4) | +/++/+-/-/-- | — | bkz. aşağıda | **Korelasyon yok** (aşağıda) |

## Aşı kolonu (Q4) — DB karşılığı

- DB'de buzağı 31–74'ün aşılama kayıtları `vaccination_log`'da; aşılar
  **Coglavax + Vac-Sules Feedlot** (2 aşı, +60 ve +90. gün dozları).
- **148/150 kayıt 2026-06-01'de toplu üretilmiş** (tarih aralığı 2025-11-14 →
  2026-05-08, hepsi `created_at` = 2026-06-01). Kalan 2 kayıt 51'e ait ve
  2026-05-10'da elle girilmiş.
- Tablo sembolleriyle DB eşleşmesi: **32 boş ↔ DB 0 kayıt** ✓; **51 "+-" ↔ DB
  2 kayıt (eksik set)** (kısmen uyumlu); diğer **42 sembollü satırda DB hep
  4 kayıt** — tabloda "-" yazılı satırlar (37, 39–47, 52–58) dahil.
- **Sonuç:** vaccination_log buzağı aralıkta plan/protokolden türetilmiş
  kayıtlar taşıyor; sahibin tablodaki +/− sembollerinin (hangi doz gerçekten
  yapıldı) DB'de doğrulanabilir karşılığı **yok**. Eğer semboller gerçek
  uygulama ise, DB'deki otomatik kayıtlar yapılmamış aşıları "yapılmış"
  gösteriyor olabilir — bu bir **veri güvenilirliği riski** (uygulanan kayıt ile
  üretilen kayıt ayrımı), sahibin kararına sunulur.

## Kullanılan SQL

```sql
-- (1) Tablo çekimleri (W3'ten yeniden kullanım + bu turun yenileri)
SELECT * FROM vaccination_log ORDER BY created_at;                 -- 381
SELECT kupe_no, devlet_kupe, dogum_tarihi, cinsiyet, durum, cikis_sebebi,
       cikis_tarihi, irk, anne_id, created_at, id
FROM hayvanlar
WHERE kupe_no IN ('31','32',...,'74')                             -- 44 satır
ORDER BY CAST(kupe_no AS integer);
SELECT * FROM dogum; SELECT * FROM tohumlama;                      -- W3 çekimleri
SELECT * FROM kizginlik_log; SELECT * FROM uygulama_log;           -- W3 çekimleri

-- (2) Aşı tarihlerinin doğumdan sapması (protokol kanıtı)
SELECT h.kupe_no, vl.vaccination_date - h.dogum_tarihi ofs, count(*) n
FROM vaccination_log vl JOIN hayvanlar h ON h.id = vl.animal_id
WHERE h.kupe_no ~ '^[3-6][0-9]$' AND CAST(h.kupe_no AS integer) BETWEEN 31 AND 74
GROUP BY 1, 2 ORDER BY 1;                                          -- deseni: +60,+60,+90,+90

-- (3) Toplu üretim kanıtı
SELECT vl.created_at::date uretim, count(*) n,
       min(vl.vaccination_date) ilk_asi, max(vl.vaccination_date) son_asi
FROM vaccination_log vl JOIN hayvanlar h ON h.id = vl.animal_id
WHERE h.kupe_no ~ '^[3-6][0-9]$' AND CAST(h.kupe_no AS integer) BETWEEN 31 AND 74
GROUP BY 1 ORDER BY n DESC;                                        -- 148 @ 2026-06-01, 2 @ 2026-05-10

-- (4) Gebelik penceresi kanıtı (aday doğum X için: annenin son tohumlaması)
SELECT h.kupe_no anne, d.yavru_kupe, d.tarih db_dogum,
       t.tarih son_toh, d.tarih - t.tarih gebelik_gun
FROM dogum d
JOIN hayvanlar h ON h.id = d.anne_id
JOIN LATERAL (SELECT t2.tarih FROM tohumlama t2
              WHERE t2.hayvan_id = d.anne_id AND t2.tarih <= d.tarih
              ORDER BY t2.tarih DESC LIMIT 1) t ON true
WHERE (h.kupe_no ILIKE '%test%' OR d.yavru_kupe ILIKE '%test%') IS NOT TRUE
ORDER BY h.kupe_no;
-- 22 çelişkili satırın aday tarihleri (TABLO ve DB) bu sonucun gün farklarıyla
-- ayrı ayrı değerlendirildi (analiz betiği §gebelik_kanit).

-- (5) Ölüm sebebi/durum kontrolü
SELECT kupe_no, durum, cikis_sebebi, cikis_tarihi FROM hayvanlar
WHERE kupe_no IN ('37','50','52','57','58','63','66','70','72');   -- cikis_sebebi/tarihi: hepsi NULL
```

Üç yönlü eşleştirme, durum sınıflandırması ve kanıt değerlendirmesi
`reports/w3/w5_karsilastirma.py` içinde deterministik olarak koşuldu
(TABLO/DEFTER sabitleri zarflardan birebir; DB girdisi yukarıdaki çekimler).
