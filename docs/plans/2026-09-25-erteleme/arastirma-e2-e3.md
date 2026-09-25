# R-ARAŞTIRMA — E2 tip tespiti + E3 PG yolu (SALT-OKUNUR)

> ROL: R-ARAŞTIRMA (F1 paralel kulvar) · 2026-09-25 · Kalem: **E2 + E3 ön araştırması**
> Yöntem: demo psql (ref `vtzqjmazsvurxdeondmi` bağlantı anında doğrulandı), yalnız
> SELECT / pg_get_functiondef / information_schema — DB'ye HİÇ yazılmadı. Kod tarafı
> worktree `ovysch-feature-erteleme` @2facc31 üzerinden okundu.
> Dosya sahipliği: yalnız bu dosya.

---

## Bölüm E2 — tedavi-sonuç ertelenebilirlik (S4)

### E2/1 — gorev_log.gorev_tipi sözlüğü (demo, 2026-09-25)

[OBSERVED `SELECT coalesce(nullif(gorev_tipi,''),'<BOS>') AS tip, count(*), count(*) FILTER (WHERE tamamlandi) FROM gorev_log GROUP BY 1`]

| tip | n | tamamlanan | not |
|---|---|---|---|
| BESLEME | 940 | 863 | |
| TEDAVI_SEANS | 740 | 631 | tedavi/ovsync seans görevleri |
| TEDAVI_GUN | 485 | 433 | seans üst görevleri |
| VETERINER_KONTROL | 298 | 135 | 84'i `SESSIZ-<hayvan>` + 214 kaynaksız (hepsi "Sessiz hayvan" açıklamalı — eski gövde) |
| ILAC | 188 | 152 | neredeyse tamamı `DOGUM-<anne_id>` Presynch programı |
| BUZAGI_BAKIM | 168 | 161 | |
| ILERI_GEBE | 138 | 58 | `ILERI_GEBE-<asi_id>` + 1 MANUEL |
| GEBELIK_KONTROL | 122 | 29 | 88 `TOH-<tohumlama_id>` + 34 kaynaksız ("21./35. Gün" — eski gövde) |
| ILERI_GEBE_ASI | 83 | 39 | |
| PADOK_DEGISIM | 66 | 27 | |
| OVSYNC_BASLAT | 41 | 12 | hepsi `ACIK-DISI-<id>-<tarih>` (cron üretimi) |
| SUTTEN_KESME | 38 | 34 | |
| TOHUMLAMA_HAZIRLIK | 34 | 24 | |
| TOHUMLAMA_PLANLI | 32 | 20 | 32'nin TAMAMI `TEDAVI_SABLON_TOHUMLAMA:*` (şablon TAI); demo'da `PG_TOHUMLAMA:*` TAI YOK |
| DIGER | 22 | 13 | |
| ASI_RAPEL | 11 | 0 | |
| MUAYENE | 10 | 10 | tamamı kaynak=`MANUEL` (UI) |
| TEDAVI | 7 | 7 | tamamı kaynak=`MANUEL` (UI) |
| MANUEL | 4 | 2 | tamamı kaynak=`MANUEL` |
| ASI_PLANLI | 3 | 3 | MANUEL |
| **\<BOS\>** | 1 | 1 | kaynak=`DOGUM-…`, açıklama "25. Gün PGg" — ESKİ gövde kalıntısı; canlı dogum_kaydet artık ILAC yazıyor |

21 satır = 20 adlandırılmış tip + 1 boş. `pg_application_event` demo'da **BOŞ** (0 satır)
[OBSERVED] — yeni PG akışından henüz olay geçmemiş; E3 analizi gövde kanıtıyla yapılır.

### E2/2 — "tedavi sonucu / kontrol" temsilcisi: hangi tip?

**SONUÇ: "tedavi sonucu"nu temsil eden DEDİKE bir görev tipi YOK.** Rol dağılımı:

| tip | üretici | kanıt |
|---|---|---|
| VETERINER_KONTROL | `sessiz_hayvanlar_reconcile()` (DB cron/RPC): sessiz_gun≥50 + açık SESSIZ yok + 30g kullanıcı-tamamlaması yok + **aktif protocol_family vakası yok** → `kaynak='SESSIZ-<hayvan_id>'`, hedef bugün. 214 kaynaksız satır da aynı üreticinin eski gövdesi (kaynak yazmıyordu) | [CONFIRMED pg_get_functiondef `sessiz_hayvanlar_reconcile` gövde 581-613; kaynak dağılımı OBSERVED] |
| GEBELIK_KONTROL | `tohumlama_kaydet`: +21/+35 gün, `kaynak='TOH-<id>'`, protokol_instance bağlı; `gebelik_muayene_gorev_uret`: Bekliyor≥40g, `kaynak='GEBELIK-KONTROL-<id>'` | [CONFIRMED pg_get_functiondef tohumlama_kaydet 778-784; gebelik_muayene_gorev_uret 430-463] |
| MUAYENE, TEDAVI, MANUEL | UI "Görev Ekle" modalı — doğrudan `write('gorev_log', {kaynak:'MANUEL'})`; seçenekler index.html:1807-1811 | [CONFIRMED js/forms.js:3247-3252; index.html:1807-1811] |
| ILAC | `dogum_kaydet` Presynch programı: "2. Gün PG"(+2), "25. Gün PG"(+25), "39. Gün PG (Presynch-14)"(+39) `etken_kod='PG'`; "53. Gün E Vitamini" `etken_kod='E_VIT'`; `kaynak='DOGUM-<anne_id>'` | [CONFIRMED pg_get_functiondef dogum_kaydet 90-98] |
| ILAC_UYGULAMA | UI kategori sözlüğünde VAR (ui.js:54 `tedavi` kategorisi) ama demo'da **0 satır** | [CONFIRMED js/ui.js:53-57; OBSERVED sözlük] |

UI'da tip kategorileri: `muayene:['MUAYENE','GEBELIK_KONTROL','VETERINER_KONTROL']`,
`tedavi:['TEDAVI','ILAC_UYGULAMA','TEDAVI_GUN','TEDAVI_SEANS']` [CONFIRMED js/ui.js:53-57].

**E1 seed bağlantısı:** plan §3.1 matrisi VETERINER_KONTROL / MUAYENE / GEBELIK_KONTROL /
TEDAVI / ILAC / ILAC_UYGULAMA tiplerini zaten `ertelenebilir=t` içeriyor → E2 için YENİ tip
satırı gerekmez; E2'nin katkısı üretici kanıtıdır. ASI_HATIRLATMA da demo'da 0 satır
(matriste f işaretli — değişmez).

### E2/3 — S4 senaryosunun bugünkü sistemle uçtan uca adımları

Senaryo: *"planlı tohumlama günü PG yapılır, tedavi süresi 2-3 gün uzar."*

**(a) Planlı tohumlama günü bağımsız PG girişi → TAI PG+48'e** — MEVCUT, ÇALIŞIYOR:

1. UI hızlı ilaç uygulaması (`rpc('hizli_uygulama', …)`; çağrı noktaları js/ui.js:2600 — PG
   kapısı reaktif `p_pg_onay/p_pg_gerekce` tekrarı ile, js/ui.js:2774, js/ui.js:6827 —
   görev-tamamlama uygulaması `p_notlar:'Görev tamamlama'`).
2. `hizli_uygulama` → bayrak `_ovsync_pg_aktif()` (demo `protokol_ayar.ovsync_pg_kurallari_aktif=1`
   [OBSERVED]) → `_pg_kapi` (ürün PG mi: `_pg_urun_durumu` ürün→sınıf→farmakolojik_sinif_kodu
   zinciri; son tohumlama sonucuna göre karar) → `uygulama_log` INSERT →
   `_pg_olay_isle('HIZLI_UYGULAMA', <uygulama_log_id>, …)` [CONFIRMED hizli_uygulama gövde 49-76].
3. `_pg_olay_isle` → `pg_application_event` INSERT ((source_type,source_id) UNIQUE, çift olay
   korumalı) → `_pg_sonrasi_tohumlama(event)` [CONFIRMED _pg_olay_isle gövde 52-85].
4. `_pg_sonrasi_tohumlama`: hedef = occurred_at+48s → `_tohumlama_pencere` yuvarlaması →
   dakika kesme; VWP-55g ve `_tohumlama_gorev_uygunluk` kontrolleri; sonra **açık
   TOHUMLAMA_PLANLI'lerin tamamı `kapatan_ref='PG_YERINE:<event>'` ile iptal** (şablon TAI dahil)
   + **yeni TOHUMLAMA_PLANLI** `kaynak='PG_TOHUMLAMA:<event>'`, açıklaması "PG sonrası
   tohumlama — … ertele/değerlendir." [CONFIRMED _pg_sonrasi_tohumlama gövde 126-185].
5. **Vaka KAPANMAZ** — gövdede cases/protokol_instance yazması yok [CONFIRMED].

Alternatif bağımsız yol: `bulk_ilac` → `_pg_olay_isle('TOPLU_ILAC', <islem_log_id>)`
[CONFIRMED bulk_ilac gövde 361-363; UI js/forms.js:3846].

**(b) Tedavi süresi uzar (aktif vakanın kalan günleri)** — EKSİK, E0'a bağımlı:

- `vaka_kalan_gunleri_kaydir` demo pg_proc'da **YOK** [OBSERVED `proname LIKE '%kalan%kaydir%'` 0
  satır] — E0 kulvarının kırmızı-önkoşul probu ile tutarlı.
- S2 gereği TEDAVI_GUN/TEDAVI_SEANS tekil ertelenemez; mevcut araçlar yetersiz:
  `update_treatment_session` yalnız saat/doz; `add_treatment_day_with_sessions` update modu tek
  günü taşır ama üst TEDAVI_GUN görevini bayat bırakır (E5'in düzelttiği) ve zincirin diğer
  günlerine dokunmaz [CONFIRMED K10 envanter §3].
- Yani S4(b) = mevcut PG akışı (a) + **E0 RPC** kombinasyonu; E0 teslim edilmeden senaryo uçtan
  uca koşamaz.

**(c) Yeni TAI'ye kadar tedavi bitmezse:** hiçbir otomatik mekanizma yok.

- TAI görevi (kaynak `PG_TOHUMLAMA:*`) açık kalır, tarih geçince gecikmiş listelenir.
- Tek mevcut çare: `tohumlama_gorev_ertele` (TOHUMLAMA_PLANLI destekli) ile manuel öteleme.
- Tedavi açıkken tohumlama YAPILABİLİR: `tohumlama_kaydet` aktif `protocol_family`'li vakaları
  kapatır ama `protocol_family NULL` (Mastit vb.) vakalara dokunmaz; tedavi-engeli yok
  [CONFIRMED tohumlama_kaydet gövde 824-846].
- Süt kalıntı süresi uygulama bazlı hesaplanır (sut-kalinti kuralları), TAI'yi DB'de engellemez.
- TAI uygulanınca +21/+35 GEBELIK_KONTROL otomatik üretilir [CONFIRMED tohumlama_kaydet 778-784].

### E2 — senaryodaki EKSİK parçalar (somut liste)

1. **E0 RPC yok** (demo'da) — S4'ün "tedavi 2-3 gün uzar" adımının tek mekanik yolu; tam bağımlılık.
2. **Tedavi-sonuç dedike tip yok** — mevcut kontrol tipleriyle temsil ediliyor (E2/2); E1 seed'ine
   eklenecek YENİ tip gerekmiyor, mevcut matris yeterli.
3. **PG olayı VWP/UYGUNSUZ yererse TAI hiç oluşmaz** — `gorev_sonuc='VWP_ICINDE'/'UYGUNSUZ'`
   sadece pg_application_event'e yazılır; kullanıcıya görev/bildirim düşmez, senaryo sessizce
   kırılır [CONFIRMED _pg_sonrasi_tohumlama 136-151].
4. **Tedavi bitişi ↔ TAI senkronu yok** (c) — otomatik öteleme yok, manuel tohumlama_gorev_ertele var.
5. **Bağımsız PG vaka kapatmıyor** — S3'ün PG tarafı henüz implement değil (E3 kapsamı);
   `_vaka_kapat` enumu `('ERKEN_KAPANIS','TOHUMLAMA')` — 'PG' YOK [CONFIRMED _vaka_kapat gövde 83].
6. (Kenar not) ILAC "25. Gün PG" hatırlatma görevi görev-tamamlama-uygulamasıyla kapanıyorsa
   `hizli_uygulama`'dan geçer → E3 ayrımında "bağımsız" sayılır (aşağıda E3/3-kenar).

---

## Bölüm E3 — protokolün kendi PG seansı vs bağımsız PG girişi (S3)

### E3/1 — gövdeler ve çağıranlar [OBSERVED pg_get_functiondef + pg_trigger]

`_pg_olay_isle(p_source_type text, …)` kaynak kısıtı (gövde satır 39-43):

```
p_source_type NOT IN ('HIZLI_UYGULAMA', 'TEDAVI_SEANS', 'TOPLU_ILAC') → GECERSIZ_OLAY_PARAMETRESI
```

`_pg_sonrasi_tohumlama`'yı yalnız `_pg_olay_isle` çağırır (gövde 84).

**`_pg_olay_isle` çağıranları** (prokind='f', tanım taraması — tamamı public şema):

| çağıran RPC | source_type | source_id | UI |
|---|---|---|---|
| `hizli_uygulama` | 'HIZLI_UYGULAMA' | uygulama_log id | js/ui.js:2600, 2774, 6827 |
| `seans_tamamla` | 'TEDAVI_SEANS' | seans_admin_id (treatment_day_uygulamalar.id) | js/api.js:684 (seans kapatma modalı) |
| `bulk_ilac` | 'TOPLU_ILAC' | islem_log id (hayvan başına) | js/forms.js:3846 |

**Trigger:** PG ile ilgili tek trigger `trg_uygulama_log_pg_geri_al` (AFTER DELETE ON
uygulama_log → `_trg_uygulama_log_pg_geri_al`) — geri-ALMA yolu, yeni olay ÜRETMEZ; yalnız
`source_type='HIZLI_UYGULAMA'` eventlerini geri alır [CONFIRMED pg_get_triggerdef + gövde].
**Cron:** demo'da `cron.job` yok (extension kurulu değil) [OBSERVED]; prod cron'u
`start_first_service_protocol` (OVSYNC_BASLAT üretimi) — `_pg_olay_isle`'ye değmez [zarf mimar
keşfi + start_first_service_protocol tanımında _pg_olay_isle geçmiyor, OBSERVED tarama 0 satır].

### E3/2 — protokol içi seans tamamlama zinciri

- TEDAVI_SEANS görevi `seans_tamamla(p_seans_admin_id, p_uygulanmadi, p_not, p_pg_onay,
  p_pg_gerekce)` ile kapanır; gorev_log kapatma `WHERE seans_admin_id = …` ile
  [CONFIRMED seans_tamamla gövde 222-225].
- **Uygulandı yolunda (p_uygulanmadi=false) bayrak açıksa: `_pg_kapi` + PG ise
  `_pg_olay_isle('TEDAVI_SEANS', p_seans_admin_id, …)`** [CONFIRMED seans_tamamla gövde
  186-218] — yani **protokolün KENDİ PG seansı _pg_olay_isle'yi TETİKLİYOR** (UNKNOWWN'dan
  CONFIRMED'a geçti). PG olmayan ilaçta `_pg_olay_isle` karar=ALLOW+pg=false ile no-op.
  occurred_at = LEAST(now, planlanan an) — geç kayıt TAI'yi ileri kaydırmaz.
- Bağımsız giriş (UI'dan hayvana doğrudan PG): `hizli_uygulama` (HIZLI_UYGULAMA) veya
  `bulk_ilac` (TOPLU_ILAC) — vaka/seans bağlantısı YOK.
- Kaynak/parent ayrımı: seans yolunda `source_id → treatment_day_uygulamalar.case_id →
  cases.animal_id` zinciri çözülür (seans_tamamla bunu zaten yapıyor, gövde 137-145);
  bağımsız girişte kaynak yok — uygulama_log/islem_log'a bağlı, case'id içermez
  [CONFIRMED hizli_uygulama/bulk_ilac gövdelerinde cases erişimi yok].

### E3/3 — VERDICT: **IMPLEMENT**

Ayrım mekanizması net, kolon bazında kanıtlı:

**Birincil ayırıcı: `pg_application_event.source_type`.**

- `source_type IN ('HIZLI_UYGULAMA','TOPLU_ILAC')` → **bağımsız** → aktif protokol vakasını
  kapat (`_vaka_kapat(...,'PG')` — enuma 'PG' eklenmeli; mevcut gövde yalnız
  `('ERKEN_KAPANIS','TOHUMLAMA')` kabul ediyor [CONFIRMED _vaka_kapat gövde 83]).
- `source_type = 'TEDAVI_SEANS'` → seansın `case_id`'si (source_id üzerinden) ile hayvanın
  aktif protokol vakası karşılaştırılır: **aynı vaka → protokolün kendi PG'si → KAPATMA**;
  farklı vaka → bağımsız say (mikro-tasarım kararı, aşağıda assumption).

**Uygulama notları (I-DB için):**

1. `_vaka_kapat` yeniden tanımı CANLI demo gövdesinden başlamalı (000008 tuzağı); 'PG' dalı
   için audit tipi (örn. `CASE_CLOSED_BY_PG`) + `close_reason='PG'`; stok iade/seans iptal
   adımları zaten generic.
2. Sıra: vaka kapatma, `_pg_sonrasi_tohumlama` bittikten SONRA çağrılmalı — şablon TAI o ana
   kadar `PG_YERINE` ile çoktan kapalı olur; `_vaka_kapat` 5b (kaynak öneki
   `TEDAVI_SABLON_TOHUMLAMA:<case>:%`) no-op düşer, çift yazma olmaz [CONFIRMED _vaka_kapat
   gövde 180-188]. **PG+48 TAI (`kaynak='PG_TOHUMLAMA:<event>'`) 5b filtresine takılmaz → yaşar**
   (S3 kabul ölçütü "PG+48 TAI yaşar" böyle karşılanır).
3. Kapatma yalnız `protocol_family IS NOT NULL` aktif vakaya uygulanmalı (tohumlama_kaydet
   S-7 deseni, gövde 827-835); Mastit vb. protocol_family NULL vakalar dokunulmaz.
4. `geri_al` uyumu: bağımsız PG geri alınırsa (`trg_uygulama_log_pg_geri_al`) kapatılan vakanın
   geri açılması MEVCUT DEĞİL — trigger vaka açmaz; bu E3 kapsamında karar ister (öneri: v1'de
   geri almada vaka kapalı kalır, rapor notu — sahip kapısına listelenir).
5. **Kenar durum:** ILAC "25. Gün PG" hatırlatması görev-tamamlama-uygulamasıyla kapanırsa
   `hizli_uygulama`'dan geçtiği için "bağımsız" sınıflanır → aktif ovsync vakasını kapatır.
   Tıbbi olarak tutarlı (protokolle çakışan PG); bilinçli davranış olarak dokümante edilmeli.
6. **Assumption (kırıntıya işlendi):** `TEDAVI_SEANS` PG olayı hayvanın aktif protokol vakasından
   FARKLI bir vakadan geliyorsa bağımsız sayılır (vaka kapatılır). Sahip tersini isterse
   yalnız karşılaştırma koşulu değişir — mekanizma aynı.

**Kanıt tablosu özeti:** protokol-içi tetikleme [CONFIRMED seans_tamamla:214-218], bağımsız
yollar [CONFIRMED hizli_uygulama:73-76, bulk_ilac:361-363], ayırıcı kolon
[CONFIRMED pg_application_event şeması + _pg_olay_isle:39-43 kısıtı], vaka kapatmama
[CONFIRMED _pg_sonrasi_tohumlama gövdesinde cases yazması yok].

---

## Kırıntı özeti

Kararlar `/home/melik/egesut-erp1/.crumbs/erteleme-genel.jsonl`'ye `role:"worker"`,
`session:"erteleme-genel/r-arastirma-e2e3"` etiketiyle işlendi: E3=IMPLEMENT kararı, E2 tip
tablosu ölçümü, E0-yok + _vaka_kapat-enum-eksik açık kalemleri, TEDAVI_SEANS-farklı-vaka
assumption'ı.
