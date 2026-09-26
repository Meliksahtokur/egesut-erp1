# K10 — SONUÇ: demo'daki gecikmiş açık ovsync görevleri yarına ertelendi (talimat 2b)

> ROL: **K10-exec** · 2026-09-25 (~08:30 +03) · Kalem: **K10 / talimat 2b**
> DB: demo psql, ref `vtzqjmazsvurxdeondmi` bağlantı anında doğrulandı (PROD'a dokunulmadı).
> Girdi: `k10-envanter.md` (R-ARAŞTIRMA) + bu dosyanın §4-A talimatı.

## Kabul ölçütü — SAĞLANDI

Zarf K10: *"demo: hedef tarihi geçmiş açık ovsync görevi 0 (sorgu çıktısı kanıt) ya da engel
gerekçeli raporlandı"*. İlk yol alındı; erteleme **yapıldı** ve kabul sorgusu (envanter §4-C):

```
===KANIT_1_4C_gecikmis_acik_ovsync_0===   (COMMIT sonrası, 2026-09-25)
 gecikmis_acik_ovsync_gorevi
-----------------------------
                           0
```

Ölçüm öncesi aynı sorgu **16** döndürüyordu (8 vaka × TEDAVI_GUN+TEDAVI_SEANS, gün1 hedef
2026-09-24) — envanter §1.1 birebir doğrulandı.

## Ne yapıldı (tek transaction, probe-first)

Sıra: salt-okunur probe → **prova transaction (BEGIN…ROLLBACK, tüm kontroller PASS)** →
yedek `\copy` ×4 → gerçek uygulama (BEGIN…COMMIT). Betikler: `~/tmp/k10/k10_body.sql` +
`k10_apply.sql`; tam çıktı `~/tmp/k10/apply_log.txt`.

Kapsam: envanter §1.1'deki **8 case_id** (03b10e2a, aa786467, 25a638aa, bf9644c7, 1b5c2a83,
f90731be, b284807a, 1e9b93a9). Zincir **bütün olarak +2 gün** (Ovsynch-56 aralıkları korunur:
d0→d7 yine 7 gün), TAI'ler mevcut destekli RPC ile:

| Adım | Etki | Sonuç |
|---|---|---|
| U1 `treatment_days.treatment_date +2` (açık günler) | 32 satır | `UPDATE 32` |
| U2 `gorev_log.hedef_tarih +2` (açık TEDAVI_GUN+TEDAVI_SEANS) | 64 satır | `UPDATE 64` |
| U3 TEDAVI_GUN `aciklama->label` tarihi tazelendi | 32 satır | `UPDATE 32` |
| U4 `treatment_day_uygulamalar.planned_date +2` (uygulanmamış seanslar) | 32 satır | `UPDATE 32` |
| U5 `tohumlama_gorev_ertele(id,'2026-10-06','10:00')` ×8 | TAI 10-04→10-06 | 8/8 `ok:true`, `toplam_erteleme_gun:2`, `uyari:null` |
| U6 audit `islem_log` (`OVSYNC_ZINCIR_ERTELE_DEMO`) | 8 vaka | `INSERT 0 8` |

Yeni tarih düzeni (SON2/SON5 doğrulandı — 8 vakada ×8'er): gün1 **2026-09-26 (yarın)**,
gün2 10-03, gün3 10-04, gün4 10-05, TAI **10-06 10:00**. Etiketler `"Gun N tedavisi - 26.09.2026"`
biçiminde yeniden üretildi (SON4: uyusmayan_label=0). Yedekler: `~/tmp/k10/yedek_treatment_days.csv`
(32), `yedek_gorev_log_tedavi.csv` (64), `yedek_gorev_log_tai.csv` (8), `yedek_treatment_day_uygulamalar.csv`
(32) — geri alma için önceki değerler dahil.

## RPC yolu engeli (kanıtıyla, K11 bağlantısı)

`tohumlama_gorev_ertele` canlı gövdesi (pg_get_functiondef, demo) yalnız `TOHUMLAMA_PLANLI`
kabul eder:

```sql
IF v_g.gorev_tipi IS DISTINCT FROM 'TOHUMLAMA_PLANLI' THEN
  RAISE EXCEPTION 'GOREV_ERTELENEMEZ:%', jsonb_build_object(..., 'sebep', 'TIP_UYGUN_DEGIL', ...);
```

TEDAVI_GUN/TEDAVI_SEANS için kural-yolu erteleme RPC'si **yok** (BUG-ERTELEME-KURAL-GENEL);
tarih taşıyan tek RPC'nin (`add_treatment_day_with_sessions` update modu) üst görev
`hedef_tarih`'i güncellemediği envanter §3'te gösterildi. Bu yüzden tablo bakımı yoluna
gidildi; TAI'ler desteklenen RPC ile ertelendi (kendi `TOHUMLAMA_ERTELE` islem_log kaydını
yazdılar: 8 satır, KANIT_3). **Genel erteleme tasarımı K11'e bağlıdır**
(`plan-erteleme-genel.md`).

## Envanterden sapmalar (exec kararları — kırıntıya işlendi)

1. **ILIKE yerine 8 case_id ile daraltma.** Envanter §4-A'nın `d.name ILIKE '%ovsync%' AND
   c.status='active'` filtresi probe'da **9 vaka / 35 gün / 70 görev** ve günler için **47
   satır** yakalıyordu (beklenti 8/32/64'tü): (a) `c065e94e` bugün koşan, gecikmesi olmayan
   bir protokol (gün1 09-18'de tamamlanmış, açık gün2 = 09-25 bugün, TAI 09-28); (b)
   19febaa1/37b98c0c/f72f320c vakalarının tüm görevleri kapalı (gün satırları açık ama açık
   görev yok). ILIKE'le süpürmek bu dört vakayı kapsam dışı kaydırırdı. Dar kapsam, envanterin
   kendi beklenen 32/64/8 sayılarını birebir üretti.
2. **TEDAVI_GUN etiket tazeleme (U3).** UI görev metnini `aciklama` JSON'undaki `label`'dan
   okur (js/ui.js:726, 835, 1350) ve etikete gün tarihi gömülüdür ("Gun 1 tedavisi - 24.09.2026").
   Süpürme sonrası bayat kalmasın diye yalnız biçim-eşleşen etiketler yeniden üretildi.
3. **`treatment_day_uygulamalar.planned_date +2` (U4).** Seans (uygulama) satırları planlı
   tarih taşır; envanter bu tabloyu içermiyordu. 32 satırın hiçbiri uygulanmamıştı
   (`uygulama_tamamlandi_at` NULL ×32) — kaydırma temiz.
4. **`islem_log.durum`** NOT NULL ama `'aktif'` default'u varmış — envanterin INSERT'i
   olduğu gibi geçerli çıktı (ek aksiyon gerekmedi; kayıt notu).

## Kapsam dışı kalanlar (bilinçli, envanter §1.2 ile uyumlu)

- **Ovsync dışı** gecikmiş açık tedavi görevleri: TEDAVI_GUN ×4, TEDAVI_SEANS ×5 (küpe 008
  vb. sıradan tedavi vakaları — KANIT_4). K10 tanımı gereği kapsam dışı.
- `c065e94e` (bugün koşan Ovsync protokolü): gecikmiş açık görevi yok; TAI 09-28.
- 19febaa1/37b98c0c/f72f320c: açık görevi olmayan (tümü kapanmış) ovsync vakaları — gün
  satırları 09-24'te duruyor ama açık görev olmadığından kabul sorgusuna girmezler (KANIT_5).
- OVSYNC_BASLAT 29 açık hepsi ileri tarihli; TOHUMLAMA_PLANLI gecikmiş 0.

## Sahip kapısı

"Yarına ertele" **zincir bütün olarak +2 gün** varsayımıyla uygulandı (R-ARAŞTIRMA'nın
assumption kırıntısı üzerine; Ovsynch-56 aralıklarının korunması için). Sahip yalnız gecikmiş
gün1'in kaymasını isteseydi (envanter §4-B alternatifi) d0→d7 aralığı 7→6 güne düşerdi —
tıbbi protokol bozulurdu; tercih açıkça kendisine aittir. Yedekler sayesinde geri alma/kısmi
kaydırma mümkün.

## Kanıt zinciri özeti

- Probe (salt-okunur): 16 gecikmiş/8 vaka; ILIKE sapması; RPC gövdesi; trigger kolon-listeleri
  (`trg_gorev_asip_iade` yalnız `UPDATE OF iptal`, `trg_gorev_parent_kapandi` yalnız
  `UPDATE OF tamamlandi,iptal` → tarih UPDATE'leri tetiklemez).
- Prova: BEGIN…ROLLBACK, tüm ON/SON kontroller PASS, rollback sonrası 4-C=16 (değişmemiş).
- Uygulama: COMMIT sonrası 4-C=**0**; vaka özeti 8/8 gun1=09-26, gun4=10-05, TAI=10-06;
  audit 8+8; tam log `~/tmp/k10/apply_log.txt`.
