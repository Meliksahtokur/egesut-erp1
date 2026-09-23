# Ovsync / PG / Tohumlama — SPEC (DB kontratları, R3)

Tarih: 2026-09-23 · Yazan: mimar koltuğu · Baz: R2 + sahip kararları 2026-09-23 (aşağıda §0)
Kanonik kaynak: canlı prod `pg_get_functiondef` (2026-09-23). Migration geçmişi ve
ground_truth **şema kanıtı değildir**; her fonksiyon canlı gövde üstüne yazılır.

Madde numaraları (S-x) PLAN DRIFT KAPISI'dır: her migration/task bir S numarasına
bağlanır; her maddenin kabul ölçütü (KÖ) yazılıdır.

---

## 0. Sahip kararları (R2'yi bağlayıcı biçimde değiştirir)

| # | Karar | R2'ye etkisi |
|---|---|---|
| SK1 | **Her gerçek PG uygulaması** (protokol içi dahil) +48 saatte `TOHUMLAMA_PLANLI` açar — **yalnız** +48s anı VWP (son doğum/abort + 55 gün) sonrasındaysa. | K1 genişler; R1 T13/UREME_KONTROL düşer. Doğum protokolünün 2/25/39. gün PG'leri VWP içinde → görev açmaz. |
| SK2 | Hayvanın açık planlı tohumlaması varsa (şablonun TAI'si dahil) **PG+48s onun yerine geçer**; son PG kazanır. | Ovsync-56 + çift PG şablonunda: 8. gün PG → 10. gün 10:00; 9. gün PG → 11. gün 10:00 = şablonun TAI'si. |
| SK3 | Erteleme **yeni** `tohumlama_gorev_ertele` RPC'siyle. `hayvan_tohumlama_ertele` (ay bazlı, hayvan seviyesi, göreve dokunmaz) değişmez. | K1 "mevcut RPC" iddiası düzeltildi. |
| SK4 | D50 zinciri başlayınca doğum protokolünün 58. gün `DIGER` kızgınlık takibi iptal; 53. gün E-vit kalır. | Yeni. |
| SK5 | Gebe onayında "rota" **yok**; tetik yalnız doğum ve abort olayı. | K2'nin rota kısmı düşer. |

Mimar kararları (sahip itiraz edebilir, varsayılan olarak uygulanır):

- MK1 Saat pencereleri kapalı aralık: `[09:00,12:00]`, `[18:00,21:00]` Europe/Istanbul. Dışarıdaki an → bir sonraki pencerenin başı (12:00–18:00 arası → 18:00; 21:00 sonrası → ertesi gün 09:00; 09:00 öncesi → aynı gün 09:00). Asla erkene çekilmez.
- MK2 Erteleme sınırı yok; ilk hedeften 7 günü aşan erteleme RPC sonucunda `uyari='ERTELEME_7_GUN_ASILDI'` döner (T27).
- MK3 **Gebelik otoritesi = hayvanın son tohumlamasının `sonuc` değeri** (`tarih DESC, created_at DESC`). `hayvanlar.tohumlama_durumu` kapı kararında kullanılmaz. Gerekçe [OBSERVED canlı 2026-09-23]: son sonucu `Doğum Yaptı` olan 13 aktif inek `tohumlama_durumu='gebe'/'Gebe'` taşıyor; bu kolona bakan kapı doğum sonrası PG'leri yanlışlıkla bloklar.
- MK4 `bulk_ilac` için `uygulama_log` standardizasyonu **yapılmaz**; PG kapsamı `pg_application_event` kaydıyla sağlanır (source_type=`TOPLU_ILAC`). R2 §2'nin "zorunlu ön iş"i bu kayıtla karşılanır.
- MK5 Tüm yeni davranış tek bayrağın arkasındadır (S-1). Bayrak kapalıyken migration'lar mevcut davranışı **bit bit** korur.
- MK6 Bloklanan tekil uygulama `RAISE` ile durur (eski frontend `ok:false`'u başarı sanabilir; gürültülü hata > sessiz yanlış). Bu yüzden tekil yolda `PG_APPLICATION_BLOCKED` audit'i yazılamaz (rollback); toplu yolda satır bazında raporlanır.

---

## S-1 Özellik bayrağı

- `protokol_ayar` satırı: `anahtar='ovsync_pg_kurallari_aktif'`, `deger=0`, `birim='bool'`, `min_deger=0`, `max_deger=1`, açıklama. `ON CONFLICT (anahtar) DO NOTHING`.
- `public._ovsync_pg_aktif() RETURNS boolean STABLE` → `COALESCE((SELECT deger FROM protokol_ayar WHERE anahtar='ovsync_pg_kurallari_aktif') = 1, false)`.
- Açma: mevcut `protokol_ayar_guncelle` RPC'si ya da tek UPDATE; **frontend yayınlandıktan sonra**, sahip kapısı.

KÖ: bayrak 0 iken S-4…S-9 fonksiyonları eski gövdelerle aynı yan etkiyi üretir (aynı tablolara aynı satırlar); yeni tablo/kolonlara yalnız S-3 metadata damgası yazılır.

## S-2 Katalog: PG kimliği ve sistem etken maddeleri

Şema:
- `drug_classes.farmakolojik_sinif_kodu text NULL CHECK (farmakolojik_sinif_kodu IN ('PGF2A','GNRH','OKSITOSIN','PROGESTERON'))`
- `drug_classes.sistem boolean NOT NULL DEFAULT false`

Backfill (active_ingredient ILIKE, sayı NOTICE ile basılır):
- Dinoprost, Kloprostenol sodyum → `PGF2A`; Gonadorelin, Buserelin asetat → `GNRH`; Oksitosin → `OKSITOSIN`; Progesteron → `PROGESTERON`; bu altı satır `sistem=true`.
- Kloprostenol `etken_kod` NULL → `'PG'` (görev dinleyicisi `_gorev_dinle` ile tutarlılık; bugün ILIKE fallback'iyle zaten PG).

Koruma:
- `BEFORE UPDATE OR DELETE` trigger `trg_drug_classes_sistem_koru` → `OLD.sistem` ise DELETE reddi; UPDATE'te `class_name, active_ingredient, etken_kod, farmakolojik_sinif_kodu, sistem` değişirse reddi. Hata: `SISTEM_ETKEN_MADDE: <active_ingredient> sistem kaydıdır, değiştirilemez/silinemez`. Bakım kaçışı: `current_setting('egesut.katalog_bakim', true) = 'on'`.
- `drug_class_ekle` yeni parametre `p_farmakolojik_sinif_kodu text DEFAULT NULL` (eski imza DROP). NULL ise aynı `group_name + class_name` altındaki kodlu satırdan kodu miras alır ("kategoriden alır"). Böylece "Prostaglandinler" altına eklenen yeni madde otomatik `PGF2A` olur.
- Ürün doz alanları (R2 "Enzaprost ≠ Dalmazin ml"): `drug_products.concentration/std_dose*` mevcut → **SQL yok**.

`_pg_urun_durumu(p_stok_id text, p_drug_product_id uuid DEFAULT NULL) RETURNS text STABLE` → `'PG' | 'DEGIL' | 'BELIRSIZ'`:
1. Ürün = `p_drug_product_id` ya da `stok.drug_product_id`. Zincir çözülür ve sınıf `PGF2A` → `PG`.
2. `_etken_kod_bul(p_stok_id, NULL) = 'PG'` → `PG` (üst küme; yalnız etken_kod'a dayanmaz, ona **ek**tir).
3. Ürün bağı yok ve stok adı `~* '(prostag|dinopros|kloprost|cloprost|enzaprost|dalmazin|estrumate|lutalyse|\mpgs?\M)'` → `BELIRSIZ`.
4. Stok bulunamadı ve ürün verilmedi → `BELIRSIZ`. Diğer → `DEGIL`.

KÖ: Dalmazin (dinoprost) ve PGs (alke) (kloprostenol, etken_kod NULL'dan PG'ye) → `PG` (T11). Sistem satırında `drug_class_guncelle`/`sil` ve doğrudan UPDATE/DELETE açık hata (T23). Canlıda ürün bağı NULL olan PG adlı stok yok [OBSERVED] → bugün `BELIRSIZ` üreten stok 0.

## S-3 Vaka provenance

Şema:
- `tedavi_sablonu.protokol_ailesi text NULL CHECK (protokol_ailesi ~ '^[A-Z][A-Z0-9_]*$')`; "Ovsynch" adlı şablon(lar) → `'OVSYNC'` (canlı: `a152f7fe…`, "Sağmal inek: Ovsynch-56 + çift PGs"). 0 satırsa WARNING.
- `cases.source_template_id uuid NULL REFERENCES tedavi_sablonu(id) ON DELETE SET NULL`, `cases.protocol_family text NULL`, `cases.protocol_snapshot jsonb NULL`, `cases.close_reason text NULL CHECK (close_reason IN ('ERKEN_KAPANIS','TOHUMLAMA'))`.
- `tedavi_sablon_uygula`: `cases.source_template_id IS NULL` ise `source_template_id`, `protocol_family`, `protocol_snapshot = {sablon_id, ad, protokol_ailesi, tohumlama_plani, kalemler[], uygulama_at, baslangic}` yazar. Bayraktan bağımsızdır (salt metadata).

Backfill:
- Hastalığı yalnız **tek** `protokol_ailesi` dolu şablona eşlenen (`sablon_hastalik_eslem`) aktif ve kapalı vakalar → `protocol_family` o aile. Kaynaktan (`TEDAVI_SABLON_TOHUMLAMA:<case>:<sablon>`, MANUEL hariç) çözülebiliyorsa `source_template_id`. Snapshot backfill edilmez (NULL). Canlı beklenti: "Ovsync Protokol" hastalığında 11 aktif ve 7 kapalı vaka `OVSYNC` olur.
- Eşlemesi belirsiz vaka `protocol_family NULL` kalır (= UNKNOWN, otomatik kapanmaz, T03).

KÖ: yeni şablon uygulaması provenance yazar; ikinci şablon uygulaması ilkini ezmez; Mastit vakası `protocol_family NULL` (T02).

## S-4 PG gerçekleşme kaydı ve güvenlik kapısı

Tablo `pg_application_event`:
```
id uuid PK DEFAULT gen_random_uuid()
farm_id uuid NOT NULL DEFAULT '400b9107-a85e-4126-af2c-fd7fe73fb68e'
source_type text NOT NULL CHECK IN ('HIZLI_UYGULAMA','TEDAVI_SEANS','TOPLU_ILAC')
source_id text NOT NULL
hayvan_id text NOT NULL REFERENCES hayvanlar(id)
stok_id text NULL, drug_product_id uuid NULL
occurred_at timestamptz NOT NULL
karar text NOT NULL CHECK IN ('ALLOW','ACK_PENDING')
ack_tohumlama_id text NULL, ack_gerekce text NULL
gorev_sonuc text NULL CHECK IN ('OLUSTU','VWP_ICINDE','UYGUNSUZ','KAPALI')
gorev_sonuc_detay text NULL
tohumlama_gorev_id uuid NULL
geri_alindi_at timestamptz NULL
created_at timestamptz NOT NULL DEFAULT now()
UNIQUE (source_type, source_id)
INDEX (farm_id, hayvan_id, occurred_at DESC)
```
RLS açık, `allow_all USING(true) WITH CHECK(true)` (pedigree kalıbı); `REVOKE ALL FROM anon, authenticated`; `GRANT SELECT TO authenticated`. Yazma yalnız SECURITY DEFINER fonksiyonlarla.

`_pg_kapi(p_hayvan_id text, p_stok_id text, p_drug_product_id uuid, p_onay boolean) RETURNS jsonb` (iç yardımcı):
- Bayrak kapalı → `{karar:'KAPALI'}`.
- `_pg_urun_durumu` `DEGIL` → `{karar:'ALLOW', pg:false}`; `BELIRSIZ` → `BLOCK_CATALOG_UNRESOLVED`.
- `hayvanlar` satırı `FOR UPDATE` (TOCTOU, T10).
- Son tohumlama (MK3): `Gebe` → `BLOCK_PREGNANT`; `Bekliyor` → onay yoksa `REQUIRE_ACK_PENDING`, varsa `ACK_PENDING`; diğer → `ALLOW`. Yaş sınırı yok (T09).
- Dönüş: `{karar, pg:true, tohumlama_id, tohumlama_tarihi, sperma, deneme_no, gun}`.

`pg_uyari_kontrol(p_hayvan_ids text[], p_stok_id text) RETURNS jsonb` (RPC, authenticated, salt-okuma, **kilitsiz** önizleme): `{pg:'PG'|'DEGIL'|'BELIRSIZ', hayvanlar:[{hayvan_id, kupe_no, karar, tohumlama_id, tohumlama_tarihi, sperma, deneme_no, gun}]}`. Bayraktan bağımsız çalışır (UI önizleme).

`_pg_olay_isle(p_source_type, p_source_id, p_hayvan_id, p_stok_id, p_drug_product_id, p_occurred_at, p_kapi jsonb, p_gerekce text) RETURNS uuid` (iç):
- Yalnız `p_kapi.pg = true` ve karar ∈ {ALLOW, ACK_PENDING} iken çalışır.
- Event INSERT `ON CONFLICT (source_type,source_id) DO NOTHING`. Çakışırsa türev iş yok (T15).
- `ACK_PENDING` ise onaylanan tohumlamanın `kaynak='TOH-<id>'` açık `GEBELIK_KONTROL` görevleri `iptal=true, tamamlandi=true, kapatan_ref='PG_ONAY:<event>'` olur; islem_log `PG_APPLICATION_ACKNOWLEDGED` (payload: event, tohumlama, gerekçe, iptal edilen görev sayısı). Tohumlama `Bekliyor` kalır.
- Ardından S-5 `_pg_sonrasi_tohumlama(event_id)`.

Tekil yol hataları (MK6), `RAISE EXCEPTION` mesaj biçimi: `PG_KAPI:<KOD>:<json detay>`. KOD ∈ `BLOCK_PREGNANT | REQUIRE_ACK_PENDING | BLOCK_CATALOG_UNRESOLVED`.

Uygulama yolları (bayrak kapalıyken gövde davranışı değişmez):

| Yol | Değişiklik |
|---|---|
| `hizli_uygulama` | + `p_pg_onay boolean DEFAULT false`, `p_pg_gerekce text DEFAULT NULL` (eski 6'lı imza DROP). INSERT'ten önce kapı; uygulama_log INSERT'inden sonra `_pg_olay_isle('HIZLI_UYGULAMA', uygulama_log.id, …, now())`. |
| `seans_tamamla` | + aynı iki parametre (eski imza DROP). Yalnız `p_uygulanmadi=false` iken kapı ve event; hayvan = `cases.animal_id`; ilaç = `treatment_day_uygulamalar.stok_id/drug_product_id`; `occurred_at=now()`; source_id = seans id. Blok ise RAISE (seans açık kalır; kullanıcı "uygulanmadı" işaretleyebilir). |
| `bulk_ilac` | + `p_pg_onaylar text[] DEFAULT '{}'` (onaylanan hayvan id'leri), `p_pg_gerekce text DEFAULT NULL` (eski imza DROP). Hayvan başına kapı; blok ya da onaysız hayvan **atlanır**, yazma yapılmaz; stok düşümü yalnız uygulanan hayvan sayısıyla. Dönüş mevcut anahtarlarını korur, ek olarak `applied[] / blocked[] / requires_ack[]`. Event source_id = hayvan başına yazılan islem_log id'si. |
| `hizli_uygulama_geri_al` | Event varsa `geri_alindi_at=now()`; event'in açık `PG_TOHUMLAMA` görevi `iptal`; yerine geçtiği görev **canlanmaz** → islem_log `PG_CYCLE_REVIEW_REQUIRED`. |
| Planlama (`tedavi_sablon_uygula`, `drug_administrations` INSERT) | Event **yok** (T12). |

KÖ: T06, T07, T08, T09, T10, T11, T12, T15. Bayrak kapalı → dört yol eski davranış.

## S-5 PG sonrası +48s tohumlama görevi (SK1, SK2)

`_tohumlama_pencere(p_ts timestamptz) RETURNS timestamptz IMMUTABLE` → MK1.

`_pg_sonrasi_tohumlama(p_event_id uuid) RETURNS void` (iç):
1. `t := _tohumlama_pencere(occurred_at + interval '48 hours')`; yerel tarih/saat Europe/Istanbul.
2. VWP tabanı = `GREATEST(max(dogum.tarih), max(tohumlama.abort_tarihi WHERE sonuc='Abort'))`. Taban varsa ve `t::date < taban + 55` → `gorev_sonuc='VWP_ICINDE'`, görev yok. (55 = `tohumlama_kaydet`'teki sabit; ikisi aynı kalmalı.)
3. `_tohumlama_gorev_uygunluk(hayvan, t::date)` NULL değilse → `UYGUNSUZ` + detay, görev yok.
4. Hayvanın **tüm** açık `TOHUMLAMA_PLANLI` görevleri (şablon TAI, önceki PG görevi) `iptal=true, tamamlandi=true, kapatan_ref='PG_YERINE:<event>'` olur (SK2).
5. INSERT `gorev_log`: `gorev_tipi='TOHUMLAMA_PLANLI'`, `hedef_tarih`, `hedef_saat`, `kaynak='PG_TOHUMLAMA:<event_id>'`, `aciklama='PG sonrası tohumlama — PG sonrası östrus değişkendir; kızgınlık görülmezse ertele/değerlendir.'`
6. Event'e `gorev_sonuc='OLUSTU'`, `tohumlama_gorev_id`; islem_log `PG_TOHUMLAMA_GOREVI` (payload: event, görev, yerine geçilen görev id'leri, hedef).

Gerçek tohumlama mevcut `planli_tohumlama_kaydet(p_gorev_id…)` ile yapılır (görev tipi değişmedi).

KÖ: T13' (yeniden tanım: protokolsüz PG, D50+ → tek `TOHUMLAMA_PLANLI`, +48s pencereye yuvarlı); T14' (Ovsync 8. gün PG → şablon TAI iptal, 10. gün 10:00 görev; 9. gün PG → o da iptal, 11. gün 10:00); T16 (iki PG → iki event, tek açık görev = sonuncusu); T26; doğum protokolünün 2/25/39. gün PG'si → `VWP_ICINDE`, görev yok.

## S-6 Görev erteleme (SK3)

`tohumlama_gorev_ertele(p_gorev_id uuid, p_yeni_tarih date, p_yeni_saat time DEFAULT NULL) RETURNS jsonb` (RPC, authenticated, bayraktan bağımsız):
- Görev `FOR UPDATE`; açık `TOHUMLAMA_PLANLI` olmalı. Aksi halde `GOREV_ERTELENEMEZ`.
- `p_yeni_tarih < bugün (Europe/Istanbul)` → `GECMIS_TARIH`.
- Saat NULL ise eski `hedef_saat`, o da NULL ise 09:00. `_tohumlama_pencere` ile yuvarlanır.
- `ilk_hedef_tarih` = bu görevin en eski `TOHUMLAMA_ERTELE` log payload'ındaki `eski_tarih`, yoksa mevcut hedef.
- UPDATE hedef; islem_log `TOHUMLAMA_ERTELE` (payload: gorev_id, eski_tarih, eski_saat, yeni_tarih, yeni_saat, ilk_hedef_tarih). Bu tip gecmis.js'te zaten etiketli.
- Dönüş: `{ok, gorev_id, hedef_tarih, hedef_saat, ilk_hedef_tarih, toplam_erteleme_gun, uyari}`; `toplam > 7` → `uyari='ERTELEME_7_GUN_ASILDI'` (MK2).

KÖ: T26 (+2 gün → pencere içinde, log var), T27.

## S-7 Tohumlama ile senkronizasyon vakası kapanışı

`_vaka_kapat(p_case_id uuid, p_close_reason text, p_not text, p_ref jsonb) RETURNS jsonb` (iç): `close_case_with_remaining` gövdesinin tamamı buraya taşınır:
- `iptal_nedeni`: `ERKEN_KAPANIS` → mevcut metin (`'Vaka erken kapatildi[: not]'`); `TOHUMLAMA` → `'Tohumlama ile sonlandırıldı'`.
- `cases.close_reason` set edilir.
- Tek audit: `ERKEN_KAPANIS` → `CASE_CLOSED_EARLY` (mevcut snapshot aynen); `TOHUMLAMA` → `CASE_CLOSED_BY_TOHUMLAMA` (payload: case_id, tohumlama_id, close_reason, iptal_seans, iptal_gorev, gerceklesen_seans, closed_at). İkisi asla birlikte yazılmaz (T21).
- Gerçekleşmiş seanslar ve stokları dokunulmaz, yalnız açık olanlar iade edilir (mevcut `drug_admin:<id>` eşleşmesi).
- Dönüş: `{case_id, iptal_seans, iptal_gorev, gerceklesen_seans, stok_iade}`.

`close_case_with_remaining(p_case_id, p_not)` imzası ve davranışı **aynen** korunur; `_vaka_kapat(…,'ERKEN_KAPANIS',…)` sarmalayıcısıdır.

`tohumlama_kaydet` (bayrak açıkken, INSERT ve mevcut adımlardan sonra, aynı transaction):
- Hayvanın `status='active' AND protocol_family IS NOT NULL AND start_date <= p_tarih` vakaları `FOR UPDATE` → `_vaka_kapat(…,'TOHUMLAMA', NULL, {tohumlama_id})`.
- Hayvanın açık `OVSYNC_BASLAT` görevleri (S-8) → `iptal=true, tamamlandi=true, kapatan_ref='ILK_TOH_MUAF:TOHUMLAMA'` (T20).
- Dönüşe additive `kapatilan_senkronizasyon_vakalari: [{case_id, iptal_seans, iptal_gorev}]` eklenir; mevcut anahtarlar korunur.
- `planli_tohumlama_kaydet` değişmez: sonucu içteki çağrıdan olduğu gibi döndürür; yalnız dönüş anahtarlarının geçtiği doğrulanır (T04).

KÖ: T01, T02, T03, T04, T05, T21, T22 (`tohumlama_geri_al` kapanmış vakayı ve seansları canlandırmaz; mevcut davranış, değişiklik yok).

## S-8 İlk tohumlama zinciri (doğum/abort → D50 Ovsync → D60 TAI)

Doğum ya da abort anında **görev** kurulur; vaka, seanslar ve stok **D50'de** kurulur. Planlama anında stok düşüldüğü için 50 gün önceden vaka açmak stoğu erken düşürür.

`_ilk_tohumlama_rota_kur(p_hayvan_id text, p_olay_tarihi date, p_kaynak_ref text) RETURNS uuid` (iç):
- Bayrak kapalı → NULL.
- Hayvanın başka açık `OVSYNC_BASLAT` görevleri `iptal`, `kapatan_ref='ILK_TOH_YENI_OLAY'`.
- `protokol_instance(hayvan_id, tip='UREME', alttip='ILK_TOHUMLAMA', kaynak_ref=p_kaynak_ref, baslangic=p_olay_tarihi, durum=<mevcut açık değer>)` `ON CONFLICT (kaynak_ref) DO NOTHING`. Eklenmediyse NULL döner (idempotent; ikiz doğum T19, cron/refresh yarışı T18).
- `gorev_log`: `gorev_tipi='OVSYNC_BASLAT'`, `hedef_tarih = p_olay_tarihi + 50`, `hedef_saat='10:00'`, `kaynak=p_kaynak_ref`, `protokol_instance_id`, `aciklama='D50: Ovsynch-56 başlat (ilk tohumlama hedefi D60)'`.
- islem_log `FIRST_SERVICE_ROUTE_CREATED`.

Anahtarlar: doğum `ILK-TOH-DOGUM-<dogum.olay_id>`; abort `ILK-TOH-ABORT-<tohumlama_id>`.

Bağlantılar:
- `dogum_kaydet`: yalnız `v_anne_yan_etki` dalında `_ilk_tohumlama_rota_kur(anne, p_tarih, 'ILK-TOH-DOGUM-'||olay_id)`. **Taban = S-10 sonrası gövde.**
- `tohumlama_abort` (3 argümanlı): başarılı abort sonrası `_ilk_tohumlama_rota_kur(hayvan, p_abort_tarihi, 'ILK-TOH-ABORT-'||p_tohumlama_id)`. D50 sayacı abort **gerçekleşme** tarihinden başlar (K2).

`start_first_service_protocol(p_gorev_id uuid) RETURNS jsonb` (RPC, authenticated):
- Bayrak kapalı → `OZELLIK_KAPALI` hatası.
- Görev `FOR UPDATE`; açık `OVSYNC_BASLAT` olmalı; zaten kapalıysa `{ok:true, zaten:true}`.
- Otomatik muafiyetler (K4'ün koruduğu tek set) → görev iptal, `kapatan_ref='ILK_TOH_MUAF:<neden>'`, instance iptal, islem_log `FIRST_SERVICE_SKIPPED`, dönüş `{ok:true, atlandi:<neden>}`:
  - `AKTIF_DEGIL`: hayvan Aktif değil
  - `TOHUMLAMA_VAR`: olay tarihinden bu yana tohumlama var
  - `GEBE`: son tohumlama Gebe
  - `AKTIF_SENKRONIZASYON`: aktif `protocol_family` vakası var
- Başlangıç `s := GREATEST(hedef_tarih, bugün)`.
- Şablon: `protokol_ailesi='OVSYNC' AND aktif` tam bir satır olmalı (aksi `OVSYNC_SABLON_BELIRSIZ`); hastalık: o şablonun `sablon_hastalik_eslem`'deki tek hastalığı olmalı (aksi `OVSYNC_HASTALIK_BELIRSIZ`).
- Sırayla ve tek transaction'da: `_vaka_ac_tek(hayvan, disease, 'İlk tohumlama zinciri (D50)', s)` → `tedavi_sablon_uygula(case, sablon, s)` (S-3 provenance'ı damgalar) → `tedavi_sablon_tohumlama_gorev_ekle(case, sablon, s)`. Biri hata dönerse RAISE (yarım zincir yok). Üç RPC'lik frontend zinciri kopyalanmaz; tek atomik RPC budur.
- SK4: `kaynak='DOGUM-'||hayvan`, `gorev_tipi='DIGER'`, `aciklama ILIKE '%kızgınlık takibi%'`, açık, `hedef_tarih BETWEEN olay+50 AND olay+70` → iptal, `kapatan_ref='ILK_TOH_D58_IPTAL'`. 53. gün E-vit'e dokunulmaz.
- Görev `tamamlandi=true, kapatan_ref='case:<id>'`; islem_log `FIRST_SERVICE_PROTOCOL_STARTED` (payload: case, sablon, başlangıç, TAI görevi, iptal edilen D58).
- Dönüş: `{ok, case_id, tohumlama_gorev_id, baslangic, d58_iptal}`.

`ilk_tohumlama_zamanlayici() RETURNS jsonb` (authenticated + cron; idempotent):
- Bayrak kapalı → `{ok:true, atlandi:'KAPALI'}`.
- `hedef_tarih <= bugün` olan açık `OVSYNC_BASLAT` görevleri, en fazla 200 adet, her biri `BEGIN … EXCEPTION` blokuyla izole edilerek `start_first_service_protocol`'e verilir.
- Özet islem_log `FIRST_SERVICE_CRON` (baslatilan, atlanan, hatalar[]); hata sayısı > 0 ise dönüşte `ok:false`.
- pg_cron: `ilk-tohumlama-ovsync-baslat` `'0 4 * * *'` (07:00 İstanbul). Önce aynı adlı job unschedule edilir; `pg_cron` yoksa NOTICE (20260622000001 kalıbı).

KÖ: T18, T19, T20, T28' (gebe onayı → görev YOK; doğum → OVSYNC_BASLAT D50), T29 (abort → aynı kapı, D50 abort tarihinden), T31 (uygunsuz hayvanda da görev kurulur; elle iptal mevcut görev iptal yolunun islem_log'una düşer).

## S-9 Mevcut sapma düzeltmeleri (bu işin önkoşulu)

- `tohumlama_abort(text, text)` 2 argümanlı overload **DROP** (canlıda `42725 not unique` [OBSERVED]; eski gövde görev/instance temizliği yapmıyor). Önce `js/` çağrıları doğrulanır; hepsi 3 argümanlı ya da isimli olmalı.
- `abort_kaydet`: `js/` çağrısı yoksa `REVOKE EXECUTE … FROM authenticated` (15 Eylül'deki genel GRANT ile tekrar açılmıştı; görev temizliği yapmayan eski yol). Çağrı varsa DROP etme, raporla.
- `tohumlama_sonuc_bos`: canlı 2 argümanlı imza (`'Boş'`) kanonik. Repo'da SQL değişikliği yok; K3 "[Boş ata]" frontend'de bunu çağırır.

## S-10 D11 → D39 düzeltmesi (R2 §0, ilk migration)

- Canlı `dogum_kaydet` gövdesinde tek değişiklik: `'11. Gün PG', p_tarih + 11` satırı → 39. gün; açıklama metni `protokol_eksik_tara`'nın beklediği biçimle aynı olmalı (`39. Gün PG (Presynch-14 senkron)` ya da tarayıcının eşleştiği alan).
- Veri: açık tek D11 görevi (hedef 2026-09-28) **taşınmaz** (T25: sessiz tarih kaydırması yok). Raporlanır; sahip isterse ayrı UPDATE.
- Regresyon kökü: `20260901000001_ikiz_dogum_olay_id.sql` eski gövdeden kopyalandı. Kalıcı koruma: kabul betiğinde "dogum_kaydet gövdesi `+ 11` içermez, `+ 39` içerir" assert'i.

KÖ: yeni doğum → 2/25/39. gün PG; `protokol_eksik_tara` yeni doğumda eksik PG raporlamaz.

---

## R3.1 — Bağımsız inceleme sonrası kararlar (2026-09-23, FIX-FIRST → düzeltildi)

- MK7 **PG anı:** `hizli_uygulama(…, p_occurred_at timestamptz DEFAULT NULL)`. NULL ise `now()`; gelecekte 5 dakikadan ileri ya da 7 günden eski değer `PG_ZAMAN_GECERSIZ` hatası verir. Seansta `LEAST(now(), planned_date + planned_time [Europe/Istanbul])`, toplu uygulamada `now()`. Gerekçe: kaydın geç girilmesi Ovsync TAI'sini bir gün kaydırıyordu.
- MK8 **Temizlik bayraktan bağımsız:** yalnız yeni iş *yaratan* adımlar bayrak arkasındadır. İptal ve geri alma adımları (açık `OVSYNC_BASLAT` ve `ILK_TOHUMLAMA` instance iptali, PG geri alma) her zaman çalışır. Bayrak hiç açılmadıysa 0 satır etkiler, MK5 bozulmaz.
- MK9 **Kilit sırası:** hayvan (`FOR NO KEY UPDATE`) → vaka/seans → görev. Bayrak açıkken `tohumlama_kaydet` ve `seans_tamamla` hayvanı ilk olarak kilitler. `bulk_ilac` hayvan id'lerini sıralı kilitler.
- MK10 **PG geri alma trigger'da:** `uygulama_log` üzerinde AFTER DELETE trigger'ı `_trg_uygulama_log_pg_geri_al` iki yolu da kapsar: UI'nin `degisim_geri_al` çağrısı ve `hizli_uygulama_geri_al`. Trigger event'i işaretler, PG görevini iptal eder, `PG_ONAY:` ile iptal edilmiş `GEBELIK_KONTROL` görevlerini (tohumlama hâlâ Bekliyor ise) geri açar, gerekiyorsa `PG_CYCLE_REVIEW_REQUIRED` yazar.
- `close_case_with_remaining`: `close_reason='TOHUMLAMA'` olan vakada no-op (T21 korunur).
- `tedavi_sablon_uygula`: `protocol_family` NULL ise sonraki şablonun ailesiyle doldurulur.
- `start_first_service_protocol`: hayvandaki açık `PG_TOHUMLAMA` görevlerini iptal eder (`ILK_TOH_PROTOKOL_YERINE`), böylece tek açık TAI kartı kalır.
- `_pg_urun_durumu(NULL, NULL)` → `DEGIL` (ilaçsız seans PG değildir; prod'da 0/599 [OBSERVED 2026-09-23]).
- `tohumlama_gorev_ertele`: geçmiş kontrolü tam zamanla yapılır (bugünün geçmiş saati de reddedilir).
- `pg_uyari_kontrol`: bilinmeyen hayvan için `karar='HAYVAN_BULUNAMADI'` satırı döner, önizlemenin tamamı düşmez.
- Prod ölçümü: `tohumlama.sonuc` NULL 0, `tarih` NULL 0 [OBSERVED 2026-09-23]. Tanımsız sonuç için fail-closed davranış korunur.

## R3.2 — Sahip kararları 2026-09-24: açık dişi kuralı ve geçiş (UYGULANMADI — sıradaki iş)

Hedef **0 gün kaybı**: postpartum inek ~60. günde, düve ~13 aylıkken tohumlanır.

- **SK6 Gün sayımı** (doğumun ertesi günü 1. gündür):
  - İnekte Ovsync başlangıcı = son doğum/abort tarihi **+ 51 gün**. S-8'deki `+50` ve SPEC'teki "D50" ifadeleri bu değerle değişir. TAI, şablon gereği başlangıç + 10 gün (10:00).
  - Düvede Ovsync başlangıcı = `hayvanlar.dogum_tarihi + 12 ay + 21 gün`, aynı şablonla ("Sağmal inek: Ovsynch-56 + çift PGs").
- **SK7 Açık dişi kuralı** (tek tanım: `_acik_disi_ovsync_hedef(p_hayvan_id) RETURNS date`, uygun değilse NULL):
  - Uygunluk: hayvan Aktif ve Dişi; son tohumlama (MK3 sıralaması) Gebe ya da Bekliyor değil; aktif `protocol_family` vakası yok; açık `OVSYNC_BASLAT` görevi yok.
  - Kural tarihi: doğum/abort geçmişi varsa `GREATEST(son doğum, son abort) + 51`; yoksa (düve) `dogum_tarihi + 12 ay + 21 gün`. `dogum_tarihi` NULL olan düvede kural tarihi NULL olur ve görev açılmaz; bu durum taramada raporlanır.
  - Hedef = `GREATEST(kural tarihi, bugün [Europe/Istanbul])` (MK11): geç kalan ya da Boş çıkan hayvan bekletilmez.
  - Boş çıkan inek/düve dahildir.
  - S-8'deki `TOHUMLAMA_VAR` muafiyeti **kalkar**. Başlatma anındaki muafiyetler: `AKTIF_DEGIL`, `GEBE`, `BEKLIYOR`, `AKTIF_SENKRONIZASYON`.
- **SK8 Tetikler.** Birincil tetik olaydır: görev olay anında, hedef tarihi belli olarak açılır. Cron yalnız yedektir.
  - `dogum_kaydet`: anne → +51. **Dişi buzağı → düve kuralı** (hedef ≈ 12a21g sonra).
  - `tohumlama_abort`: +51 (abort tarihinden).
  - `tohumlama_sonuc_bos`: `_acik_disi_ovsync_hedef` ile görev.
  - Düve/dişi hayvan kaydı (`hayvan_ekle`, iki overload; canlı gövdeye bak): uygunsa görev.
  - `ilk_tohumlama_zamanlayici` (cron 07:00, yedek) iki iş yapar:
    - (a) Açık dişi taraması: görevi eksik her uygun hayvana görev açar (sayaç + üst sınır).
    - (b) Hedefi gelen görevleri başlatır.
  - Bugünkü geriye dönük doldurma, taramanın bayrak açılırken yapılan ilk koşumudur.
  - İdempotency anahtarları: `ILK-TOH-DOGUM-<olay_id>`, `ILK-TOH-ABORT-<tohumlama_id>`, `ACIK-DISI-<hayvan_id>-<kural tarihi>`. Bunlar `protokol_instance.kaynak_ref` UNIQUE'i üzerinden çalışır.
- **SK9 Uyarı:** `OVSYNC_BASLAT` görevi `hedef_tarih − 2 gün`den itibaren **protokol uyarıları ekranında** görünür. DB tarafında görev olay anında zaten var; gösterim frontend işidir. `protokol_eksik_tara` ya da ekranın veri kaynağı buna göre genişletilir (PLAN.md).
- **SK10 Geçiş** (tek seferlik, prod uygulamasıyla birlikte, bayraktan bağımsız):
  - (a) Başlangıcından sonra tohumlanmış, açık seansı olmayan aktif Ovsync vakaları (2026-09-24 ölçümü: 10 vaka, 13 Eylül başlangıçlı) `_vaka_kapat(…,'TOHUMLAMA',…, {tohumlama_id: <başlangıç sonrası ilk tohumlama>})` ile kapatılır. Stok ve seans etkisi yoktur.
  - (b) Açık seansı olan vaka (küpe 002, 18 Eylül) kendi akışında devam eder.
- Kabul testine eklenecekler:
  - Doğum → hedef +51.
  - Dişi buzağı → düve hedefi.
  - Boş sonucu → görev (hedef bugün ya da kural tarihi).
  - Tarama idempotent (iki koşum, tek görev).
  - `dogum_tarihi` NULL düve raporlanır.
  - Geçiş (a) tek audit yazar.
  - Gebe/Bekliyor hayvana görev açılmaz.

## Kapsam dışı (açık kalemler, sahibe)

1. `hayvanlar.tohumlama_durumu` veri tutarsızlığı (13 doğum sonrası inek `gebe`; `gebe`/`Gebe`, `bos`/`Boş` harf karışıklığı) ve `dogum_kaydet`'in bu kolonu sıfırlamaması. MK3 kapıyı bundan bağımsız kıldı; temizlik ayrı iş.
2. `bulk_ilac` stok çift düşüm şüphesi (`stok.baslangic_miktar` UPDATE + `stok_hareket`). S-4 değişikliği mevcut düşüm biçimini korur, düzeltmez.
3. `vaka_toplu_ac` ile açılmış 10 Ovsync vakasında şablon id'si kurtarılamaz; `protocol_family` hastalıktan gelir, `source_template_id` NULL kalır.
4. Frontend (PLAN.md): K3 modalı ("Boş ata"), erteleme modalı, `OVSYNC_BASLAT` kart tipi ve [Başlat] (`start_first_service_protocol`), toplu sonuç modalı (`applied/blocked/requires_ack`), `PG_KAPI:`/`PG_ZAMAN_GECERSIZ`/`SISTEM_ETKEN_MADDE`/`KATALOG_SINIF_KODU_KILITLI` hata ayrıştırma (`getUserMessage` bugün tanımadığı her hatayı jenerik metne çeviriyor), `hizli_uygulama`'ya `p_occurred_at` alanı, `js/api.js` pull haritası (`bulk_ilac` ve `tohumlama_abort` → `gorev_log`; `tohumlama_kaydet` → `cases` + seanslar), `drug_class` toplu düzenlemede sistem satırına gelince yarım kalma.
5. Seans tamamlamanın geri alınması ve toplu uygulama (`TOPLU_ILAC`) geri alması PG event'ini işaretlemez (bugün `TOPLU_ILAC` için geri alma yolu yok; seans geri alma yolu ayrıca ele alınmalı).
6. `tohumlama_abort` parametresinin `DEFAULT CURRENT_DATE`'i UTC'dir (canlı davranış). İstanbul saatiyle 00:00–03:00 arası girilen abort bir önceki güne yazılır.

## Migration sırası (PLAN.md'nin DB bölümü)

| Dosya | S | Bağımlılık |
|---|---|---|
| `20260923000001_dogum_kaydet_pg_d39_geri.sql` | S-10 | canlı gövde |
| `20260923000002_ovsync_pg_sema.sql` | S-1, S-2 şema+backfill+koruma, S-3 şema+backfill, S-4 tablo | — |
| `20260923000003_ovsync_pg_yardimcilar.sql` | S-2 `_pg_urun_durumu`, S-4 `_pg_kapi`/`pg_uyari_kontrol`/`_pg_olay_isle`, S-5, S-6 | 000002 |
| `20260923000004_ovsync_pg_uygulama_kapisi.sql` | S-4 yollar | 000003 |
| `20260923000005_ovsync_vaka_kapanis.sql` | S-3 `tedavi_sablon_uygula`, S-7 | 000002, 000003 |
| `20260923000006_ilk_tohumlama_zinciri.sql` | S-8, S-9 | 000001, 000003, 000005 |
| `supabase/tests/ovsync_pg_kabul.sql` | T-matrisi, `BEGIN … ROLLBACK` | hepsi |

Her dosya: iç transaction deyimi yok; SECURITY DEFINER + `SET search_path = public, pg_temp`; yeni ya da yeniden yaratılan her fonksiyonda `REVOKE ALL … FROM PUBLIC, anon`; RPC'ler `GRANT EXECUTE … TO authenticated`; `_` önekli iç yardımcılar authenticated'a verilmez; imza değişen dosyanın sonunda `NOTIFY pgrst, 'reload schema'`.

Uygulama sırası: yerel dry-run → demo (sahip kapısı) → prod bayrak **kapalı** (sahip kapısı) → frontend → bayrak açık.
