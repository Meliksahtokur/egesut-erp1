# W5 — Sahibin Buzağı Tablosu ↔ Saha Defteri ↔ DB Karşılaştırması (salt-okuma)

Tarih: 2026-09-13 (rev. 2 — root denetimi 5 madde işlendi) · Dal: `agent/dogum-tarih-denetimi` ·
Görev zarfı: `.ss/tasks/W5-sahip-tablosu-karsilastirma.md` · Öncül: W3 raporu (rev 2, `d2891d4`) · v1: `2f95289`

**Yöntem:** Üç kaynak canlı prod verisi üzerinden karşılaştırıldı: (1) sahibin
elektronik tablosu (W5 zarfı, birebir alındı), (2) saha defteri (W3 zarfı),
(3) DB — W3 çekimleri + `vaccination_log` (buzağı aralığı 170 kayıt) ve buzağı
tam satırları. Analiz betiği: `reports/w3/w5_karsilastirma.py` (bu dalda; anne
eşlemesi devlet kupe son-4 dahil). DB'ye yazma yok, kod değişikliği yok.

**Rev. 2 değişiklikleri (root denetimi):** (1) satır sayımı 47→46 düzeltildi;
(2) aşı kayıt sayıları tam kapsam sorgusuyla düzeltildi (170 = 168 + 2; son aşı
2026-05-20) ve sorgu eklendi; (3) anne karşılaştırması üçlü değerlendirmeye
girdi — ayrı sütun + 44/60 anne karışması ayrı madde; (4) ırk iki yönlü
karşılaştırma (54 Norveç, 58–61 Red Holstein, 55 `yavru_irk` küçük harf);
(5) 66'nın gebelik kanıtına "tanık zayıf" notu (tüm tohumlama kayıtları toplu
giriş; 189'un 2025-04-13 "Boş" kaydı senaryosu).

## Özet

| Ölçüm | Değer |
|---|---|
| **Tablo satırı** | **46** (43 numaralı buzağı + 2 numarasız 185/188 satırı + xx) |
| **ÜÇÜ UYUMLU (tarih)** | **22** — 32–52 arası tamamen + 74 |
| **DB=DEFTER≠TABLO (tarih)** | **22** — 53'ten 73'e (74 hariç) + xx |
| **DB'DE YOK** | 2 (185, 188 → W3'te dolaylı tohumlama kanıtı var) |
| DB=TABLO≠DEFTER / ÜÇÜ FARKLI | 0 / 0 |
| **Anne (T/L ↔ DB):** ✓ birebir | 29 satır |
| Anne: ✓ devlet kupe son-4 ile | 3 — 33 (1940-5621=5621), 49 (2045=905), 61 (1956=903) |
| Anne: DB'de bağlantı yok (`anne_id` NULL) | 11 — 32, 35, 39, 40, 50, 58, 59, 60, 63, 65, xx (185/188'in anneleri de DB'de yok) |
| Anne: **çelişki** | 1 — buzağı 44: DB anne=**904**, tablo/defter=**162**; ve buzağı 60'ın tablo annesi **7125** = 904'ün devlet kupe son-4'ü → **44/60 anne karışması** (ayrı madde, aşağıda) |
| Cinsiyet çelişkisi | 0 |
| Durum çelişkisi (tablo Canlı derken hayvan ölmüş) | 3 — buzağı 66, 70, 72 (DB=defter: Öldü) |
| Ölüm sebebi DB'de | **Hiçbiri** — tüm buzağıların `cikis_sebebi`/`cikis_tarihi` boş (37 "Tendon Kontraktürü", 63 "Gelişim Geriliği", xx "Erken Doğum" yalnız tabloda) |
| Tarih çelişkisinde gebelik penceresi kanıtı | Defter-DB'yi destekleyen **3** (66, 67, 69 — **tanık zayıf**, bkz. aşağıda); tabloyu destekleyen **2** (68, 71 — annenin tohumlama kaydı da şüpheli); belirsiz **17** |
| Buzağı aşı kayıtları | **170 = 168 (42 hayvan, 2026-06-01 toplu üretim) + 2 (kupe 51, 2026-05-10 elle)**; ilk aşı 2025-11-14, **son aşı 2026-05-20**; tarihler DB doğumuna sabit **+60/+90 gün** → **bağımsız tanık değil** |
| Aşı kolonu ↔ DB | Korelasyon yok (32 boş↔0 ✓, 51 "+-"↔2 kısmen; diğer 42 sembollü satırda DB hep 4 kayıt) |

**Ana sonuç:** Root ön karşılaştırması doğrulandı — 32–52 ve 74'te üç kaynak
tarih olarak aynı; **53–73 arasında sahibin tablosu defter ve DB'nin ikisinden
de erken** (−2 ile −33 gün, düzenli bir formülü yok; xx satırında tersine 12 gün
geç). DB ile defter 22 çelişkili satırın **hepsinde** birbiriyle uyumlu. Tarih
dışında asıl boşluk anne bağlantılarında: 43 DB'li satırın yalnız 32'sinde
(29 ✓ + 3 son-4) anne üç kaynakta doğrulanabilir; 11'inde DB bağlantısı hiç
yok, 1'inde (44) açık çelişki var. Tarih hangi kaynağın doğru olduğu sorusunda
DB içi bağımsız kanıt yalnız gebelik penceresi ve sonuç karışık — kesin hüküm
sahibin teyidine muhtaç.

## Üç yönlü karşılaştırma

TABLO kolonu `tarih · cins · anne · durum`; **Anne** sütunu tablo/defter
anne bilgisinin DB ile eşleşmesini gösterir (✓ = birebir, ✓ son4 = devlet kupe
son-4 eşleşmesi, NULL = DB'de anne bağlantısı yok, ✗ = çelişki). Durum sınıfı
tarihe göredir; anne ve durum farkları Not'ta.

| # | TABLO | DEFTER | DB | Anne | Satır durumu | Not |
|---|---|---|---|---|---|---|
| 32 | 05.09.2025 · D · 156 · Canlı | 05.09.2025 · D · 156 | 2025-09-05 · D | NULL | **ÜÇÜ UYUMLU** | W3: dogum olayı yok, `anne_id` NULL (bkz. W3 satır 1) |
| — | 08.09.2025 · E · 185 · Canlı | (buzağısız) | — | — | **DB'DE YOK** | W3: dolaylı tohumlama kanıtı (+285g = 2025-09-08) |
| — | 08.09.2025 · D · 188 · Canlı | (buzağısız) | — | — | **DB'DE YOK** | W3: dolaylı tohumlama kanıtı (+270g = 2025-09-08) |
| 33 | 15.09.2025 · E · 1940-5621 · Satıldı | aynı | 2025-09-15 · E · Satıldı | ✓ son4 | **ÜÇÜ UYUMLU** | "1940-5621" = 5621'in devlet kupe son-4 (TR354341940) + kupe |
| 34 | 17.09.2025 · E · 145 · Satıldı | aynı | 2025-09-17 · E · Satıldı | ✓ | **ÜÇÜ UYUMLU** | |
| 35 | 17.09.2025 · E · 177 · Satıldı | aynı | 2025-09-17 · E · Satıldı | NULL | **ÜÇÜ UYUMLU** | 177 DB'de yok; `anne_id` NULL |
| 36 | 06.10.2025 · D · 142 · Canlı | aynı | 2025-10-06 · D | ✓ | **ÜÇÜ UYUMLU** | |
| 37 | 08.10.2025 · D · 153 · Öldü (Tendon Kontraktürü) | 08.10.2025 · ex | 2025-10-08 · D · Öldü | ✓ | **ÜÇÜ UYUMLU** | ölüm sebebi yalnız tabloda (DB boş) |
| 38 | 14.10.2025 · D · 182 · Canlı | aynı | 2025-10-14 · D | ✓ | **ÜÇÜ UYUMLU** | |
| 39 | 19.10.2025 · E · 107 · Canlı | aynı | 2025-10-19 · E | NULL | **ÜÇÜ UYUMLU** | 107 DB'de yok; `anne_id` NULL |
| 40 | 21.10.2025 · E · Küpesiz düve · Satıldı | aynı (Küpesiz düve) | 2025-10-21 · E · Satıldı | NULL | **ÜÇÜ UYUMLU** | anne adı üç kaynakta da serbest metin; DB `anne_id` NULL |
| 41 | 29.10.2025 · E · **8** · Satıldı | 29.10.2025 · **008** | 2025-10-29 · E · Satıldı | ✓ | **ÜÇÜ UYUMLU** | "8" ↔ "008" aynı hayvan (normalize) |
| 42 | 02.11.2025 · E · 167 · Satıldı | aynı | 2025-11-02 · E · Satıldı | ✓ | **ÜÇÜ UYUMLU** | |
| 43 | 03.11.2025 · E · 178 · Canlı | aynı | 2025-11-03 · E | ✓ | **ÜÇÜ UYUMLU** | |
| 44 | 07.11.2025 · E · **162** · Canlı | aynı | 2025-11-07 · E | **✗ 904≠162** | **ÜÇÜ UYUMLU** | **ANNE KARIŞMASI** (ayrı madde, aşağıda): DB anne=904; 904'ün devlet kupe son-4 (7125) tabloda buzağı 60'ın annesi |
| 45 | 09.11.2025 · D · 197 · Canlı | aynı | 2025-11-09 · D | ✓ | **ÜÇÜ UYUMLU** | |
| 46 | 13.11.2025 · D · 191 · Canlı | aynı | 2025-11-13 · D | ✓ | **ÜÇÜ UYUMLU** | W3: 191 tohumlama aralığı 145g şüpheli |
| 47 | 13.11.2025 · E · 155 · Canlı | aynı | 2025-11-13 · E | ✓ | **ÜÇÜ UYUMLU** | |
| 48 | 15.11.2025 · E · 5708 · Canlı | aynı | 2025-11-15 · E | ✓ | **ÜÇÜ UYUMLU** | |
| 49 | 16.11.2025 · E · 2045 · Canlı | aynı | 2025-11-16 · E | ✓ son4 | **ÜÇÜ UYUMLU** | 2045 = 905 devlet kupe son-4 (TR354342045) |
| 50 | 16.11.2025 · D · 179 · Öldü | aynı · ex | 2025-11-16 · D · Ölü | NULL | **ÜÇÜ UYUMLU** | 179 DB'de yok; `anne_id` NULL |
| 51 | 17.11.2025 · D · 195 · Canlı | aynı | 2025-11-17 · D | ✓ | **ÜÇÜ UYUMLU** | W3 R1: 195'e 100g arayla iki buzağı çakışması (31+51) sürüyor |
| 52 | 23.11.2025 · E · 181 · Öldü | aynı · ex | 2025-11-23 · E · Ölü | ✓ | **ÜÇÜ UYUMLU** | |
| 53 | **24.11.2025** · E · 199 · Canlı · Alaca | 29.11.2025 · E | 2025-11-29 · E | ✓ | **DB=DEFTER≠TABLO** | kanıt: belirsiz (her iki tarih pencerede); ırk: tablo "Alaca" ↔ DB "Alaca Holstein" |
| 54 | **28.11.2025** | 03.12.2025 | 2025-12-03 · E | ✓ | **DB=DEFTER≠TABLO** | belirsiz (283g vs 288g); **ırk: DB=Norveç, tabloda boş** |
| 55 | **01.12.2025** · D · 196 · Alaca | 04.12.2025 · D | 2025-12-04 · D | ✓ | **DB=DEFTER≠TABLO** | belirsiz (271 vs 274); mükerrer dogum kaydının birinde `yavru_irk` küçük harf: "alaca holstein" |
| 56 | **02.12.2025** · D · 101 · Red Holstein | 08.12.2025 | 2025-12-08 · D | ✓ | **DB=DEFTER≠TABLO** | belirsiz (272 vs 278); ırk ✓ |
| 57 | **02.12.2025** · D · 5638 · Öldü · Red Holstein | 09.12.2025 · ex | 2025-12-09 · D · Ölü | ✓ | **DB=DEFTER≠TABLO** | belirsiz (275 vs 282); ırk ✓ |
| 58 | **05.12.2025** · E · Minik panda · Öldü | 12.12.2025 · ex | 2025-12-12 · E · Ölü | NULL | **DB=DEFTER≠TABLO** | kanıt yok (annenin tohumlama kaydı yok); **ırk: DB=Red Holstein, tabloda boş** |
| 59 | **09.12.2025** | 14.12.2025 | 2025-12-14 · E | NULL | **DB=DEFTER≠TABLO** | kanıt yok (5748'in tohumlama kaydı yok); **ırk: DB=Red Holstein, tabloda boş** |
| 60 | **12.12.2025** · **7125** | 15.12.2025 · **7125** | 2025-12-15 · E | NULL (7125=904 son4) | **DB=DEFTER≠TABLO** | hiçbiri pencerede (319g/322g — annenin kaydı zaten W3'te şüpheli); **anne karışması**, bkz. aşağıda; **ırk: DB=Red Holstein, tabloda boş** |
| 61 | **12.12.2025** · D · **1956** | 18.12.2025 · D | 2025-12-18 · D | ✓ son4 | **DB=DEFTER≠TABLO** | 1956 = 903'ün devlet kupe son-4 (TR354341956), DB anne=903 ile uyumlu; belirsiz (270 vs 276); **ırk: DB=Red Holstein, tabloda boş** |
| 62 | **20.12.2025** · D · 154 · Alaca | 23.12.2025 · D | 2025-12-23 · D | ✓ | **DB=DEFTER≠TABLO** | kanıt yok (154'ün tohumlama kaydı yok); ırk Alaca=Alaca Holstein |
| 63 | **21.12.2025** · D · 159 · Öldü (Gelişim Geriliği) · Alaca | 23.12.2025 · ex | 2025-12-23 · D · Ölü | NULL | **DB=DEFTER≠TABLO** | 159 DB'de yok; ölüm sebebi yalnız tabloda |
| 64 | **27.12.2025** | 12.01.2026 | 2026-01-12 · E | ✓ | **DB=DEFTER≠TABLO** | belirsiz (267 vs 283 — ikisi de pencerede) |
| 65 | **31.12.2025** | 17.01.2026 | 2026-01-17 · E | NULL | **DB=DEFTER≠TABLO** | 161 DB'de yok; kanıt yok |
| 66 | **04.01.2026** · **Canlı** | 02.02.2026 · **ex** | 2026-02-02 · Ölü | ✓ | **DB=DEFTER≠TABLO** | gebelik penceresi defter-DB yönünde ama **tanık zayıf** (bkz. sonraki bölüm). Durum: tablo Canlı, hayvan ölmüş (defter: kronik pnömoni) |
| xx | **15.02.2026** (+12g) · Öldü (Erken Doğum) | 03.02.2026 · ex | 2026-02-03 (dogum olayı; hayvan kaydı yok) | NULL | **DB=DEFTER≠TABLO** | 106 DB'de yok; tablo tek "tablo > defter" satırı |
| 67 | **03.01.2026** | 05.02.2026 | 2026-02-05 · E | ✓ | **DB=DEFTER≠TABLO** | pencere defter-DB yönünde (tablo 244g — çok erken; DB 277g ✓), tanık zayıf |
| 68 | **15.01.2026** | 06.02.2026 | 2026-02-06 · D | ✓ | **DB=DEFTER≠TABLO** | pencere tabloyu destekliyor (289g ✓; DB 311g ✗ — W3'ün 176:311g şüphesi) ama annenin tohumlama tarihi de doğrulanmamış → belirsiz |
| 69 | **17.01.2026** | 07.02.2026 | 2026-02-07 · D | ✓ | **DB=DEFTER≠TABLO** | pencere defter-DB yönünde (tablo 250g; DB 271g ✓), tanık zayıf |
| 70 | **25.01.2026** · **Canlı** | 09.02.2026 · **ex** | 2026-02-09 · Ölü | ✓ | **DB=DEFTER≠TABLO** | belirsiz (268 vs 283). Durum: tablo Canlı, hayvan ölmüş |
| 71 | **04.02.2026** | 10.02.2026 | 2026-02-10 · E | ✓ | **DB=DEFTER≠TABLO** | pencere tabloyu destekliyor (296g ✓; DB 302g ✗ — W3'ün 134:302g şüphesi) ama tohumlama kaydı doğrulanmamış → belirsiz |
| 72 | **06.02.2026** · **Canlı** | 15.02.2026 · **ex** (rota ishali) | 2026-02-15 · Ölü | NULL | **DB=DEFTER≠TABLO** | 175'in tohumlama kaydı yok. Durum: tablo Canlı, hayvan ölmüş |
| 73 | **09.02.2026** | 16.02.2026 | 2026-02-16 · E | ✓ | **DB=DEFTER≠TABLO** | belirsiz (276 vs 283) |
| 74 | 19.02.2026 · D · 121 | aynı | 2026-02-19 · D | ✓ | **ÜÇÜ UYUMLU** | çelişki dizisi burada kapanıyor |

*Tarih farkı deseni: tablo 53–73'te defterden −2 … −33 gün erken; sapma 64–69
arasında büyüyüp sonra kapanıyor; xx'te tersine tablo +12g geç. Düzenli bir
formül (ör. tohumlama+280) yok.*

## Tarih çelişkileri ve bağımsız kanıt (53+)

**Soru:** tablo mu, defter/DB mi doğru?

**Değerlendirilen bağımsız kanıt kaynakları ve sonuçları:**

1. **Annenin tohumlaması + gebelik süresi (≈260–300 gün):** tek kullanılabilir
   bağımsız kanıt — ama **zayıf tanık**: annelerin tüm tohumlama kayıtları
   2026-05-09'da toplu girilmiş (yani bu tarihler de defterden anahtarlanmış;
   kendi başlarına bağımsız doğrulama içermiyor). Satır satır sonuç:
   - **Defter-DB yönünde 3 satır:** 66 (tablo 240g — biyolojik sınırın altında),
     67 (244g), 69 (250g). **66 için ek zayıflık:** annesi 189'un
     **2025-04-13 "Boş"** tohumlama kaydı da var — o kayıt yanlışsa (gerçek
     tohumlama oysa) tablo tarihi 2026-01-04 → **266 gün, pencerede** olur.
     Yani 66'nın "defter-DB destekli" hükmü kesin değil.
   - **Tablo yönünde 2 satır:** 68 (DB 311g ✗, tablo 289g ✓), 71 (DB 302g ✗,
     tablo 296g ✓) — ikisi de W3'ün "aralık şüpheli" inekleri (176, 134);
     (a) tablo doğru doğum geç yazılmış, ya da (b) defter doğru tohumlama
     erken yazılmış — ayırt edilemiyor.
   - **Belirsiz 17 satır:** 53, 54, 55, 56, 57, 61, 64, 70, 73 (iki aday da
     pencerede), 60 (hiçbiri pencerede — annenin kaydı zaten şüpheli),
     58, 59, 62, 72, 65, xx, 63 (annenin tohumlama kaydı yok / anne DB'de yok).
2. **`vaccination_log` aşı tarihleri — bağımsız DEĞİL:** buzağı aralığında
   **170 kayıt**: **168'i 42 hayvan için 2026-06-01'de toplu üretilmiş**, 2'si
   kupe 51'e ait ve 2026-05-10'da elle girilmiş. Aşı tarih aralığı
   2025-11-14 → **2026-05-20**; DB doğumuna sapma hepsinde sabit
   **+60/+60/+90/+90 gün** (51: +144; 32: kayıt yok). Aşı tarihleri DB'deki
   doğum tarihinden türetilmiş; hangi doğumun gerçek olduğunu ayrıştıramaz.
3. **Devlet küpe seri sırası — ayrımcı değil:** seride kayıt seyrek (8 buzağı)
   ve doğum sırasına değil — 31←…354 (doğum 09.08), 32←…353 (doğum 05.09)
   ters; 45←…056 / 46←…055 ters. Kupilama muhtemelen ele geçme sırasına.
4. **`uygulama_log`:** buzağı 31–74 aralığında **hiç kayıt yok**.
5. **`created_at`:** buzağı satırları iki toplu dalgada (2026-05-09 ve
   2026-06-01) — giriş anını taşımaz.
6. **`islem_log`:** kapsamı 2026-05-09 sonrası; ilk kayıtların öncesine inmez.

**Yorum:** Kanıt çoğunlukla defter-DB yönünde ama zayıf: 66/67/69'daki
"imkansız erken" hükmü tohumlama kayıtlarının doğruluğuna bağlı (hepsi toplu
giriş), 68/71'de pencere tabloyu destekliyor. **Sahip teyidi olmadan hüküm
yok.** 53–57, 61, 64, 70, 73'te fark küçük (3–6 gün) ve pencere her iki
tarihi de kabul ediyor — hayvancılık uygulaması açısından anlamsız fark,
kayıt tutarlılığı açısından tablo tarafı düzeltilmeli.

**44/60 anne karışması (ayrı madde):** Buzağı 44'ün DB annesi **904** (tablo/
defter: **162** — DB'de yok); buzağı 60'ın tablo/defter annesi **7125** —
904'ün devlet kupe son-4'ü (TR092757125). Yani 904'e 38 gün arayla iki doğum
biniyor (07.11 ve 15.12) — biyolojik olarak imkansız. İki okuma: (a) DB
doğruysa 162 hatalı ve 7125=904 doğru → 60'ın annesi 904, 44'ün DB ataması
doğru ama defterle çelişiyor; (b) defter doğruysa 44'ün annesi 162 (DB'ye
eklenmeli) ve 60'ın "7125"i farklı bir ineğin küpesi olmalı. Sahip teyidi
gerekli; W3 düzeltme listesindeki madde ile aynı konu.

## Diğer farklar

| Konu | Tablo | Defter | DB | Değerlendirme |
|---|---|---|---|---|
| 40 annesi | Küpesiz düve | Küpesiz düve | `anne_id` NULL | Tablo=defter; DB anne bağlantısı yok |
| 41 annesi | 8 | 008 | 008 | Aynı hayvan (sıfır dolgulu) — çelişki yok |
| 58 annesi | Minik panda | Minik panda | `anne_id` NULL | Tablo=defter; DB bağlantı yok |
| **44/60 annesi** | 162 / 7125 | 162 / 7125 | **904 / NULL** | **Anne karışması** — ayrı madde (yukarıda) |
| 61 annesi | 1956 | 1956 | 903 | 1956 = 903'ün devlet kupe son-4 → uyumlu |
| 66 durumu | Canlı | ex (kronik pnömoni) | **Ölü** | Tablo güncel değil; DB=defter. Ölüm sebebi DB'de yok |
| 70 durumu | Canlı | ex | **Ölü** | Aynı; sebep defterde de yok |
| 72 durumu | Canlı | ex (rota ishali) | **Ölü** | Aynı; sebep yalnız defterde |
| 63 ölüm sebebi | Gelişim Geriliği | (yok) | boş | DB ölüm sebebi hiç tutmuyor (`cikis_sebebi` tüm buzağılar boş) |
| 37 ölüm sebebi | Tendon Kontraktürü | — | boş | Yalnız tabloda |
| xx ölüm sebebi | Erken Doğum | erken doğum | boş | Yalnız tabloda |
| **54 ırkı** | (boş) | — | **Norveç** | DB'de var, tabloda yok |
| **58–61 ırkı** | (boş) | — | **Red Holstein** (58, 59, 60, 61) | DB'de var, tabloda yok |
| Irk | Alaca (53, 55, 62, 63) | — | Alaca Holstein | Uyumlu; tablo kısaltıyor |
| Irk | Red Holstein (56, 57) | — | Red Holstein | Birebir ✓ |
| 55 doğum ırkı | — | — | `dogum.yavru_irk` = **"alaca holstein"** (küçük harf; mükerrer 55 kaydından biri) | Yazım tutarsızlığı; `hayvanlar.irk` = "Alaca Holstein" |
| Aşı (Q4) | +/++/+-/-/-- | — | bkz. aşağıda | **Korelasyon yok** (aşağıda) |

## Aşı kolonu (Q4) — DB karşılığı

- DB'de buzağı 31–74 aralığında **170 aşılama kaydı** var; aşılar
  **Coglavax + Vac-Sules Feedlot** (2 aşı, +60 ve +90. gün dozları).
  Dağılım: **168 kayıt / 42 hayvan, `created_at` = 2026-06-01 (toplu üretim)**;
  **2 kayıt / kupe 51, `created_at` = 2026-05-10 (elle)**. Aşı tarihi aralığı
  2025-11-14 → **2026-05-20**.
- Aşı tarihlerinin DB doğumuna sapması: hepsinde **+60/+60/+90/+90** (51:
  +144/+144; 32: kayıt yok) → kayıtlar DB'deki doğum tarihinden
  **türetilmiş**, gerçek uygulama kanıtı değil.
- Tablo sembolleriyle DB eşleşmesi: **32 boş ↔ DB 0 kayıt** ✓; **51 "+-" ↔ DB
  2 kayıt (eksik set)** (kısmen uyumlu); diğer **42 sembollü satırda DB hep
  4 kayıt** — tabloda "-" yazılı satırlar (37, 39–47, 52–58) dahil.
- **Sonuç:** vaccination_log buzağı aralıkta plan/protokolden türetilmiş
  kayıtlar taşıyor; sahibin tablodaki +/− sembollerinin (hangi doz gerçekten
  yapıldı) DB'de doğrulanabilir karşılığı **yok**. Eğer semboller gerçek
  uygulama ise, DB'deki otomatik kayıtlar yapılmamış aşıları "yapılmış"
  gösteriyor olabilir — veri güvenilirliği riski, sahibin kararına sunulur.

## Kullanılan SQL

```sql
-- (1) Tablo çekimleri (W3'ten yeniden kullanım + bu turun yenileri)
SELECT * FROM vaccination_log ORDER BY created_at;                 -- 381
SELECT kupe_no, devlet_kupe, dogum_tarihi, cinsiyet, durum, cikis_sebebi,
       cikis_tarihi, irk, anne_id, created_at, id
FROM hayvanlar
WHERE kupe_no IN ('31','32','33','34','35','36','37','38','39','40','41','42',
                  '43','44','45','46','47','48','49','50','51','52','53','54',
                  '55','56','57','58','59','60','61','62','63','64','65','66',
                  '67','68','69','70','71','72','73','74')         -- 44 satır
ORDER BY CAST(kupe_no AS integer);
SELECT * FROM dogum; SELECT * FROM tohumlama;                      -- W3 çekimleri
SELECT * FROM kizginlik_log; SELECT * FROM uygulama_log;           -- W3 çekimleri

-- (2) Aşı tarihlerinin doğumdan sapması (protokol kanıtı)
SELECT h.kupe_no, vl.vaccination_date - h.dogum_tarihi ofs, count(*) n
FROM vaccination_log vl JOIN hayvanlar h ON h.id = vl.animal_id
WHERE h.kupe_no ~ '^[0-9]+$' AND CAST(h.kupe_no AS integer) BETWEEN 31 AND 74
GROUP BY 1, 2 ORDER BY 1;                                          -- deseni: +60,+60,+90,+90

-- (3) Toplu üretim kanıtı (tam kapsam; v1'deki sorgu regex'i 70-74'ü atlıyordu)
SELECT vl.created_at::date uretim, count(*) n,
       count(DISTINCT vl.animal_id) hayvan,
       min(vl.vaccination_date) ilk_asi, max(vl.vaccination_date) son_asi
FROM vaccination_log vl JOIN hayvanlar h ON h.id = vl.animal_id
WHERE h.kupe_no ~ '^[0-9]+$' AND CAST(h.kupe_no AS integer) BETWEEN 31 AND 74
GROUP BY 1 ORDER BY 1;
-- → 2026-05-10: 2 kayıt / 1 hayvan (kupe 51), 2026-04-10
-- → 2026-06-01: 168 kayıt / 42 hayvan, 2025-11-14 → 2026-05-20   (toplam 170)

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

-- (6) anne_id NULL olan doğumlar (anne karşılaştırmasının DB tarafı)
SELECT yavru_kupe FROM dogum
WHERE anne_id IS NULL AND yavru_kupe IS NOT NULL
ORDER BY yavru_kupe;   -- 35,39,40,50,55(mükerrer),58,59,60,63,65,xx

-- (7) Irk iki yönlü (tablo boş ama DB dolu dahil; 55 küçük harf dahil)
SELECT h.kupe_no, h.irk, d.yavru_irk
FROM hayvanlar h LEFT JOIN dogum d ON d.yavru_kupe = h.kupe_no
WHERE h.kupe_no IN ('53','54','55','56','57','58','59','60','61','62','63')
ORDER BY h.kupe_no;
-- → 54: Norveç; 58-61: Red Holstein; 55'in mükerrer dogum kaydından birinde
--   yavru_irk = 'alaca holstein' (küçük harf)

-- (8) 66 kanıtının zayıflığı: 189'un tüm tohumlama kayıtları (giriş tarihiyle)
SELECT h.kupe_no, t.tarih, t.sonuc, t.created_at::date giris
FROM tohumlama t JOIN hayvanlar h ON h.id = t.hayvan_id
WHERE h.kupe_no = '189' ORDER BY t.tarih;
-- → 2024-12-28 Boş / 2025-04-13 Boş / 2025-05-09 Doğum Yaptı / ... ;
--   2026-05-09'a kadar HEPSİ toplu giriş (yalnız 2026-07-27 'Gebe' canlı giriş)
```

Üç yönlü eşleştirme, anne işaretlemesi, durum sınıflandırması ve kanıt
değerlendirmesi `reports/w3/w5_karsilastirma.py` içinde deterministik olarak
koşuldu (TABLO/DEFTER sabitleri zarflardan birebir; DB girdisi yukarıdaki
çekimler; anne eşlemesi devlet kupe son-4 dahil).
