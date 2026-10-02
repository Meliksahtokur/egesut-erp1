# W2 — Ovsync vakalarının veri modeli: PROD canlı şema (salt-okuma araştırma)

Tarih: 2026-09-28 · Dal: ovsync-takip @ c9122fd · Yazar: W2 araştırma koltuğu
Amaç: tek ekranlık ovsync protokol takip sistemi için mevcut PROD veri modelini ve sorgu/alan açıklarını çıkarmak.

## 0. Metod ve kanıt sınırları

- **Bağlantı:** tools-bank MCP `supabase_query` → PostgREST `https://zqnexqbdfvbhlxzelzju.supabase.co` (PROD).
  Proje ref kanıtı: `[CONFIRMED /home/melik/egesut-erp1/.env:7]` (`SB_PROJECT_REF=zqnexqbdfvbhlxzelzju`; demo ayrı: `.env:10` → `vtzqjmazsvurxdeondmi`).
  Tool yolu: `[CONFIRMED /home/melik/tools-bank/mcp_server/server.py:309,1147]`. Salt-SELECT; hiçbir yazma/RPC çağrısı yapılmadı; Demo DB'ye dokunulmadı.
- **Kısıt:** `information_schema.tables/columns` PostgREST schema cache'inde olmadığından sorgulanamadı
  (`[OBSERVED] supabase_query(table=information_schema.tables) → PGRST205 "Could not find the table"`).
  `count` aggregate çalışıyor (`select=count`), ama `select=kolon,count` GROUP BY otomatikleşmediği için
  gruplu dağılım sorguları 42803 verdi (aşağıda notlandı). Bu yüzden:
  - Kolon listeleri: `select=* &limit=1` dönen JSON anahtarlarından **[OBSERVED]** — kolon adları canlı kanıttır.
  - Veri tipleri / nullable / default: JSON değerlerden **[INFERRED]** olarak etiketlenir; PostgREST bu meta'yı vermez.
  - Var/yok testi: PGRST205/42703 hatası = nesne/kolon **yok** kanıtı **[OBSERVED]**.
- Migration dosyaları (`supabase/migrations/`, worktree) yalnız bağlam; canlı şema kanıtı değildir. Çelişki görülürse raporlanır.
- Tüm sayımlar ≤ LIMIT'li; sürü verisi dökülmedi.

## 1. Tablo/view envanteri (ovsync takibiyle ilgili 17 nesne)

### 1.1 Tablolar — kolon listeleri [OBSERVED: `select=* &limit=1`]

**`cases`** — vaka ana kaydı (toplam 144 satır `[OBSERVED: cases select=count]`)
- Kolonlar: `id uuid PK, animal_id text/uuid, disease_id uuid, start_date date, status text
  ('active'|'closed'), notes text, created_at timestamptz, closed_at timestamptz, plan_notu text,
  source_template_id uuid, protocol_family text, protocol_snapshot jsonb, close_reason text`
- `animal_id` değerleri UUID formatında `[INFERRED değerden]`.
- Ovsync kolonlarının canlıda oluşu: migration `20260923000002_ovsync_pg_sema.sql:335-338` bağlam
  `[CONFIRMED supabase/migrations/20260923000002_ovsync_pg_sema.sql:335-338]` + boş-örnek satırda kolonların
  mevcut oluşu `[OBSERVED: cases select=* limit 1]` (protocol_family/protocol_snapshot/close_reason NULL).
- `status` CHECK kısıtı görünemez (information_schema yok) — gözlenen değerler yalnız `active`/`closed`
  `[INFERRED: sayım sorguları]`.

**`treatment_days`** — protokol gün satırları
- Kolonlar: `id uuid PK, case_id uuid→cases, day_no int, treatment_date date, notes text, created_at
  timestamptz, treatment_time time (null'lu), tamamlandi boolean, tamamlanma_tarihi timestamptz,
  tamamlanma_notu text, planned_time time, seans_sayisi int (null'lu)` `[OBSERVED]`

**`treatment_day_uygulamalar`** — gün içi ilaç seansları/kalemleri
- Kolonlar: `id uuid PK, treatment_day_id uuid→treatment_days, case_id uuid→cases (denormalize),
  planned_time time, planned_date date, stok_id uuid, drug_product_id uuid, dose numeric, unit text,
  route text, uygulama_tamamlandi_at timestamptz, uygulayan text, uygulama_notu text,
  gerceklesme_saati text/time, uyulanmadi boolean, iptal_nedeni text, created_at, updated_at` `[OBSERVED]`

**`gorev_log`** — görev zinciri (ovsync'in motoru)
- Kolonlar: `id uuid PK, hayvan_id text/uuid, gorev_tipi text (CHECK yok — serbest metin), aciklama text
  (TEDAVI_GUN/SEANS'ta JSON gömülü!), hedef_tarih date, tamamlandi boolean, tamamlanma_tarihi
  timestamptz, padok_hedef, stok_id uuid, miktar, stok_dusuldu boolean, kaynak text, created_at
  timestamptz, parent_id uuid→gorev_log (zincir), iptal boolean, hekim_id, ref_tohumlama_id
  uuid→tohumlama, etken_kod text, kapatan_ref text, protokol_instance_id uuid→protokol_instance,
  seans_admin_id uuid→treatment_day_uygulamalar, hedef_saat time` `[OBSERVED]`
- Ovsync görev tipleri canlıda görülenler: `OVSYNC_BASLAT`, `TEDAVI_GUN`, `TEDAVI_SEANS`,
  `TOHUMLAMA_PLANLI`, `GEBELIK_KONTROL` `[OBSERVED: gorev_log filtre sorguları]`.

**`protokol_instance`** — protokol yaşam-döngüsü kapsülü
- Kolonlar: `id uuid PK, hayvan_id, tip text, alttip text, kaynak_ref text, baslangic date, durum text,
  kapandi_at timestamptz, kapandi_sebep text, created_at timestamptz` `[OBSERVED]`
- Gözlenen değer evreni: `tip ∈ {UREME, BAKIM}`; `alttip ∈ {DOGUM, GEBELIK, TOHUMLAMA, ILK_TOHUMLAMA,
  BESLEME, BUZAGI, SUTTEN_KESME}`; `durum ∈ {aktif, tamamlandi, iptal}` `[OBSERVED: select=tip,alttip,durum
  limit 100 — tam dağılım değil, değer kümesi]`. OVSYNC-kuralı instance'ı: `UREME/ILK_TOHUMLAMA`,
  canlıda **1** adet `[OBSERVED: alttip=eq.ILK_TOHUMLAMA select=count → 1]`.

**`protokol_ayar`** — eşik/bayrak tablosu
- Kolonlar: `anahtar text PK-benzeri, deger numeric, birim text, min_deger, max_deger, aciklama text,
  guncellendi timestamptz` `[OBSERVED: limit 100 → 11 satır]`
- Ovsync-critical anahtarlar `[OBSERVED aynen]`:
  - `ovsync_pg_kurallari_aktif = 1` (bool, min 0 max 1, "PG kapısı, PG+48s tohumlama görevi, tohumlama ile
    senkronizasyon vakası kapanışı, D50 ilk tohumlama zinciri"; guncellendi 2026-09-23) — **PROD'da AÇIK**.
  - `sessiz_tohumlama_muafiyet_gun = 40` (guncellendi 2026-09-26 — p5b erteleme turu izi).
  - diğerleri: sutten_kesme_gun 60, sutten_kesme_erken_uyari 40, sutten_kesme_gecikme_gun 75,
    besleme_baslangic_gun 260, kuru_donem_gun 210, ileri_gebe_asi1_gun 240, ileri_gebe_asi2_gun 261,
    ileri_gebe_ademin_gun 260, ileri_gebe_evit_gun 265.

**`pg_application_event`** — PG uygulama karar günlüğü (ovsync'de doğan tek "olay" tablosu)
- Kolonlar: `id uuid PK, farm_id uuid (400b9107-... = REAL_FARM_ID), source_type text
  ('TEDAVI_SEANS'|'HIZLI_UYGULAMA'), source_id uuid, hayvan_id, stok_id, drug_product_id, occurred_at
  timestamptz, karar text ('ALLOW'), ack_tohumlama_id, ack_gerekce text, gorev_sonuc text ('OLUSTU'),
  gorev_sonuc_detay text, tohumlama_gorev_id uuid→gorev_log (üretilen TAI), geri_alindi_at timestamptz,
  created_at` `[OBSERVED limit 5]`
- Tablo 3 satır (hepsi ALLOW/OLUSTU) `[OBSERVED: select=karar,gorev_sonuc limit 100 → 3 satır]`.
  `UYGUNSUZ` kararı (domain-rules §18.6) canlıda henüz örneklenmemiş — değer evreni **bilinmiyor** (fail-closed).

**`islem_log`** — işlem günlüğü
- Kolonlar: `id uuid PK, tip text, ana_hayvan_id, tarih timestamptz, kullanici_notu, durum text
  ('aktif'|'geri_alindi'), geri_alma_tarihi, snapshot jsonb, ref_id, ref_tablo text, payload jsonb,
  degisim_txid bigint (null'lu)` `[OBSERVED limit 1]`
- Ovsync-relevant tip değerleri (ref_tablo='cases' örnekleminden) `[OBSERVED limit 10 order tarih.desc]`:
  `VAKA_ACILDI`, `FIRST_SERVICE_PROTOCOL_STARTED` (payload: kaynak, case_id, gorev_id, sablon_id,
  disease_id, seans_sayisi, tohumlama_gorev_id, baslangic, olay_tarihi, pg_gorev_iptal[], d58_iptal[]),
  `CASE_CLOSED_EARLY`, `VAKA_KAYDIR` (payload: gun, tai, case_id, tasinan_gorev, tasinan_seans,
  tasinan_gun_satiri, tasinan_uygulama_satiri, eski/yeni ilk-son tarih).

**`hayvanlar`** — hayvan ana kaydı
- Kolonlar: `id uuid PK, kupe_no, cins, irk, dogum_tarihi date, dogum_kg, kesim_kg, grup, padok text,
  durum text ('Aktif'|'Ölü'|'Satıldı'|'Kesildi'|'Kayıp'), cikis_*, created_at, cinsiyet ('Dişi'/'Erkek'),
  anne_id, baba_bilgi, canli_agirlik, boy, renk, ayirici_ozellik, devlet_kupe, kategori ('inek'/'düve'
  vb.), suttten_kesme_tarihi, tohumlama_onay_tarihi, tohumlama_durumu, cikis_tipi, notlar, abort_sayisi
  int, padok_id uuid, kisir boolean, etiketler jsonb, updated_at, genc_anne` `[OBSERVED limit 1]`
- Sayım: `cinsiyet='Dişi' AND durum='Aktif'` → **115** `[OBSERVED: count, URL-encode'lu filtre]`

**`tohumlama`** — tohumlama kaydı (durum makinesi)
- Kolonlar: `id uuid PK, hayvan_id, tarih date, sperma text, irk_bilgisi, tohumlayan, kontrol_tarihi,
  sonuc text ('Bekliyor'|'Gebe'|'Boş'|'Doğum Yaptı'|'Abort'), deneme_no int, created_at, hekim_id,
  dogum_tarihi, buzagi_kupe, abort_notlar, deneme_sayisi, denemeler jsonb, ek_uygulamalar jsonb,
  **case_id uuid→cases**, vwp_override boolean, gerceklesme_at timestamptz, abort_tarihi date` `[OBSERVED]`
- **`case_id` PROD verisinde tamamen boş**: `tohumlama?case_id=not.is.null` → 0 satır
  `[OBSERVED]` — vaka→tohumlama bağlantısı şemada VAR, canlı veride hiç kullanılmamış.

**`diseases`** — hastalık kataloğu
- Kolonlar: `id uuid PK, name text, category text, created_at` `[OBSERVED]`
- Ovsync tanımı TEK kayıt: `id=c346e115-35ff-4430-92b8-874c505d857e, name='Ovsync Protokol',
  category='Üreme'` `[OBSERVED: name=ilike.*vsync*]`. Tüm OVSYNC vakaları bu disease_id'ye bağlı.

**`tedavi_sablonu` + `tedavi_sablonu_kalem`** — şablon ve gün kalemleri
- `tedavi_sablonu` ovsync şablonu canlı: `id=a152f7fe-e1d5-4de4-8157-344f1bffbaf7,
  ad='Sağmal inek: Ovsynch-56 + çift PGs', protokol_ailesi='OVSYNC',
  tohumlama_plani={gun_ofset:10, planned_time:'10:00'}` `[OBSERVED: protokol_ailesi=not.is.null]`
- `tedavi_sablonu_kalem` (4 kalem) `[OBSERVED: sablon_id=eq.a152f7fe...]`:
  `gun_no 1 (10:00, GnRH-stok 1e7ad1d5/drug c2f9f08f, 2.5ml IM), gun_no 8 (10:00, PG-stok
  86bb424c/drug ef49ec29, 2ml), gun_no 9 (10:00, PG, 2ml), gun_no 10 (18:00, GnRH, 2.5ml)`.
  Kolonlar: `id, sablon_id, gun_no, planned_time, stok_id, drug_product_id, dose, unit, route, created_at`.

**`gorev_ertele_kural`** — erteleme kural tablosu (JS'e tip listesi yazılmaz — domain-rules §18.10)
- Kolonlar: `gorev_tipi text, ertelenebilir boolean, pencere_kurali text, max_erteleme_gun,
  asimi_uyari_gun int, zincir_tetikler jsonb, guncellendi` `[OBSERVED: 22 satır]`
- Ovsync satırları `[OBSERVED]`: `OVSYNC_BASLAT` ertelenebilir=true, pencere_kurali='tohumlama',
  zincir_tetikler `{tai_ofset_gun: 10}`; `TOHUMLAMA_PLANLI` pencere_kurali='tohumlama';
  **`TEDAVI_GUN` ve `TEDAVI_SEANS` ertelenebilir=false** (fail-closed, §18.10 ile tutarlı).

### 1.2 View'lar

**`hayvan_durum_view`** — takip için EN ZENGİN hayvan-merkezli yüzey `[OBSERVED: select=* limit 1]`
- Kolonlar: kimlik (id, kupe_no, devlet_kupe, irk, cinsiyet, dogum_tarihi, grup, padok_id, padok, durum,
  anne_id, kategori, tohumlama_durumu, kisir, abort_sayisi, etiketler…) + **hesap alanları**:
  `yas_gun int, tohumlama_esik_gun int, toh_id, toh_tarih, sperma, toh_sonuc, toh_gun,
  aktif_hastalik_sayisi int, hesap_kategori text, tohumlama_bildirisi_gerekli boolean,
  suttten_kesme_bildirisi_gerekli boolean, dogum_yaklasti boolean, dogum_gecikme_gun int,
  tohumlama_durumu_hesap text, repeat_breed_active boolean, repeat_breed_past boolean,
  repeat_breed_count int`
- **Protokol alanı YOK**: vaka/protocol_family/gün bilgisi taşımıyor. Kolon adı testi:
  `hayvan_durum_view?hayvan_id=eq.…` → 42703 "column hayvan_durum_view.hayvan_id does not exist" —
  hayvan kimlik kolonu `id` (hayvanlar gibi) `[OBSERVED hata mesajı]`.

**`v_eligible`** — sessiz/uygun dişi listesi `[OBSERVED: select=* limit 2]`
- Kolonlar: `id, kupe_no, grup, padok, son_dogum_tarihi, dogum_gun, son_aktivite_tarihi, sessiz_gun`
- Protokol/vaka bilgisi YOK; yalnız sessiz-sayaç yüzeyi.

**`v_ureme_dongusu`** — tohumlama döngü geçmişi `[OBSERVED: select=* limit 3]`
- Kolonlar: `hayvan_id, padok, durum, kategori, cycle_no, baslangic, bitis, deneme_sayisi, sonuc,
  gebe_sperma, son_sperma`. Bir OVSYNC aktif hayvanı (b670f888) için 0 satır döndü —
  ilk tohumlama öncesi düveler bu view'da görünmüyor `[OBSERVED: hayvan_id=eq.b670f888 → []]`.

### 1.3 Aranan ama bu araştırmada sorgulanmayan/bulunamayan

- `protokol_dismiss`, `uygulama_log`, `dogum`, `kizginlik_log`: rpc-reference/migration'larda aday; bu turda
  sorgulanmadı (ovsync gün-takip zincirinde doğrudan rolü yok — gerekirse ayrı tur).
- `cozulmemis_kizginlik_view`, `tedavi_view`, `ileri_gebe_view` vb. diğer view'lar: sorgulanmadı (kapsam
  ovsync takibiyle sınırlı). **Bilinmiyor** olarak işaretlenir; varsayım YOK.

## 2. Vaka/zincir/tedavi-gün yapısı (bir ovsync vaka ömrünün şemadaki temsili)

### 2.1 Doğum öncesi: kural günü görevi

1. `gorev_log`'a `OVSYNC_BASLAT` görevi düşer: `kaynak='ACIK-DISI-<hayvan_id>-<hedef_tarih>'`,
   `aciklama='Ovsynch-56 başlat (ilk tohumlama hedefi +10 gün)'`, `parent_id=NULL`,
   **`protokol_instance_id` dolu** `[OBSERVED: gorev_tipi=eq.OVSYNC_BASLAT limit 10]`.
2. Görev yaratılırken `protokol_instance (tip=UREME, alttip=ILK_TOHUMLAMA)` açılır; instance
   `kaynak_ref` = görevin kaynak metniyle aynı `[OBSERVED: protokol_instance id=3d5c4f61...]`.
3. PROD'da **30 açık OVSYNC_BASLAT** görevi var (hedefler 2026-10-09 … 2027-04-09 — düve kural günleri)
   `[OBSERVED: tamamlandi=false&iptal=false count-by-limit-100 → 30]`.

### 2.2 Başlatma: görev → vaka

4. `OVSYNC_BASLAT` tamamlandığında `start_first_service_protocol` (RPC) açar: `cases` satırı
   (protocol_family='OVSYNC', source_template_id=şablon, disease_id=Ovsync Protokol) + 4
   `treatment_days` + 4 `treatment_day_uygulamalar` + görevler + **d10 TAI** (TOHUMLAMA_PLANLI).
   Kanıt: `islem_log FIRST_SERVICE_PROTOCOL_STARTED` payload'ı tüm bu id'leri taşır
   `[OBSERVED: islem_log ref_tablo=eq.cases limit 10; payload örneği 22b64b3b vakası]`.
5. Instance kapanır: `protokol_instance.kapandi_sebep='case:<case_id>'` — vaka bağlantısı **metinsel**
   `[OBSERVED: 3d5c4f61 → kapandi_sebep='case:51adfd85-f0cd-4de4-92f2-4b807f7634ad']`. FK yok.

### 2.3 Protokol günleri: vaka → gün → seans → görev

6. `cases.start_date` (ör. 2026-09-27) = şablon 1. günü. `treatment_days` satırları
   `day_no 1..4`, `treatment_date = start_date + (0, 7, 8, 9)` (Ovsynch-56: d0 GnRH, d7 PG, d8 PG,
   d9 GnRH+TAI), `planned_time 10:00/10:00/10:00/18:00` `[OBSERVED: treatment_days case_id=eq.51adfd85]`.
   - **Nüans (fail-closed):** şablon `gun_no 1,8,9,10` iken vaka `day_no 1,2,3,4` yazılmış — day_no'nun
     şablon gun_no'sunu mu yoksa sıra numarasını mı taşıdığı canlıdan kanıtlanamadı (2 vakada ikisi de
     +0/+7/+8/+9 tarih desenine oturdu). `INFERRED: day_no = şablon sırası (sıkıştırılmış)`.
7. Her güne karşılık görevler: `gorev_log(gorev_tipi='TEDAVI_GUN')` — **`aciklama` alanı JSON string**:
   `{"label": "Gun 3 tedavisi - 26.09.2026", "day_id": "<treatment_days.id>", "gun_no": 3,
   "planned_time": "10:00:00", "seans_sayisi": 1}` `[OBSERVED: hayvan 17a7040c TEDAVI_GUN sorgusu]`.
   - `day_id` **dedike kolon DEĞİL**, JSON string içinde. Vaka id'si de görevde kolon olarak yok.
   - Gün görevleri `parent_id` ile **zincir**: gün1 parent NULL, gün2.parent=gün1, gün3.parent=gün2,
     gün4.parent=gün3 `[OBSERVED: aynı sorguda parent_id'ler]`.
8. Her günün seans görevleri: `gorev_tipi='TEDAVI_SEANS'`, aciklama JSON'da `day_id` **ve** `admin_id`
   (→ treatment_day_uygulamalar.id) `[OBSERVED: hayvan ba865063 TEDAVI_SEANS satırları]`.
   `gorev_log.seans_admin_id` kolonu da aynı bağlantıyı taşıyabilir (örnekte NULL; dolu örnek
   görülmedi — **bilinmiyor**).
9. Uygulama fiili: `treatment_day_uygulamalar.uygulama_tamamlandi_at + gerceklesme_saati + uyulanmadi +
   iptal_nedeni` `[OBSERVED: case 51adfd85 — d1 uygulandı 09-27 06:41; d2/d3/d4 planlı]`.
   Gün kapanışı: `treatment_days.tamamlandi + tamamlanma_tarihi` `[OBSERVED]`.
10. TAI görevi: `gorev_log(gorev_tipi='TOHUMLAMA_PLANLI')` — **vaka bağlantısı `kaynak` metninde**:
    `kaynak='TEDAVI_SABLON_TOHUMLAMA:<case_id>:<sablon_id>'`, `hedef_saat='10:00:00'`
    `[OBSERVED: 12 açık TAI — 11'i bu örüntüde, hedefleri 2026-10-07]`.
    PG kaynaklı TAI: `kaynak='PG_TOHUMLAMA:<pg_application_event.id>'` `[OBSERVED]`. FK yok.
11. PG uygulanınca `pg_application_event` satırı düşer: `source_type='TEDAVI_SEANS'|'HIZLI_UYGULAMA'`,
    `karar='ALLOW'`, `gorev_sonuc='OLUSTU'`, `tohumlama_gorev_id`=üretilen TAI görevi
    `[OBSERVED limit 5]`. Örnek canlı akış (hayvan 17a7040c): şablon TAI'ı (fa42f344) `tamamlandi=true +
    iptal=true` iken PG-TAI (82df084d, hedef 2026-09-28) açık — "son PG kazanır" kuralının (§18.6) canlı
    izi `[OBSERVED: hayvan 17a7040c TOHUMLAMA_PLANLI sorgusu]`.

### 2.4 Sonlanma

12. `cases.close_reason` gözlenen değerler: `TOHUMLAMA` (gerçek PG/TAI sonrası tohumlama),
    `PG` (bağımsız PG), `ERKEN_KAPANIS` (erken kapatma), `IPTAL` (protokol_iptal), `NULL`
    (close_reason öncesi eski kayıtlar) `[OBSERVED: protocol_family=eq.OVSYNC 35 satır]`.
13. `protokol_iptal` akışı: vaka `close_reason='IPTAL'` + ilgili görevler `iptal=true`; iptal izi
    **görevin `kaynak` alanına** yazılır: `kaynak='PROTOKOL-IPTAL-<case_id>'`
    `[OBSERVED: hayvan ba865063 OVSYNC_BASLAT + TOHUMLAMA_PLANLI satırları]`. `kapatan_ref='protokol_iptal'`
    araması 0 satır — kapatan_ref bu akışta kullanılmıyor `[OBSERVED]`.
14. `close_case_with_remaining` → `close_reason='ERKEN_KAPANIS'` + `islem_log CASE_CLOSED_EARLY`
    `[OBSERVED: islem_log]`.
15. TOHUMLAMA ile kapanan vakada tohumlama kaydı **vaka'ya case_id ile bağlanmıyor** (§1.1 `tohumlama`
    — case_id tamamen boş); iz yalnız zaman-aşimiyle `islem_log` + tohumlama tarihli GEBELIK_KONTROL
    görevlerinde (`kaynak='TOH-<tohumlama_id>'`, 21/35 gün) `[OBSERVED: hayvan ba865063]`.

### 2.5 Örnek zincir — id referanslarıyla (hayvan 17a7040c / b670f888)

| Adım | Tablo.id | Not |
|---|---|---|
| Vaka | cases `c065e94e-fe97-4844-962c-28348cac4cdc` | active, start 2026-09-18, şablon a152f7fe |
| Gün 1 | treatment_days `9d06d276...` (day_no 1, 09-18, tamamlandi) | görev `84b29044` (day_id JSON) |
| Gün 2 | treatment_days `efd7a815...` (09-25) | görev `58debec8`, parent=gün1 görevi |
| Gün 3 | treatment_days `69ba3c46...` (09-26) | görev `49c18454`, parent=gün2 görevi |
| Gün 4 | treatment_days `18afa9e9...` (09-27, 18:00) | görev `c03f3c64`, parent=gün3 görevi |
| PG olayı | pg_application_event `ba6b24f4/9745e316` (source TEDAVI_SEANS) | tohumlama_gorev_id dec2cbc9/82df084d |
| TAI | gorev_log `82df084d` TOHUMLAMA_PLANLI (PG_TOHUMLAMA:9745e316, hedef 09-28) | **açık** |
| Şablon TAI | gorev_log `fa42f344` (TEDAVI_SABLON_TOHUMLAMA:c065e94e:…) | tamamlandi+iptal (PG ile geçildi) |
| Tohumlama | tohumlama: hayvan 17a7040c için kayıt YOK | henüz girilmemiş |
| Başlatma örneği | protokol_instance `3d5c4f61` (ILK_TOHUMLAMA, tamamlandi, kapandi_sebep 'case:51adfd85') | b670f888 |

## 3. Durum ve sonlanma alanları — ovsync veri dağılımı [OBSERVED]

- `cases` toplam **144**; `status='active'` **30**; `protocol_family='OVSYNC'` **35** satır
  (hepsi listelendi, limit 50 altında) `[OBSERVED: count + protocol_family=eq.OVSYNC]`.
- OVSYNC 35'in dağılımı:
  - `active`: **12** (start 09-18 … 09-27)
  - `closed` + `close_reason='TOHUMLAMA'`: **10** (hepsi `closed_at=2026-09-23T22:39:57.09802` — tek
    anda toplu kapanış izi; start 2026-09-13 kohortu → p5b senkron kapanış turu)
  - `closed` + `close_reason='PG'`: **1**
  - `closed` + `close_reason='ERKEN_KAPANIS'`: **4**
  - `closed` + `close_reason='IPTAL'`: **1**
  - `closed` + `close_reason=NULL`: **7** (2026-07-22/09-13 açılışlı eski vakalar — kolon eklenmeden
    kapananlar; takip ekranında "eski/kararsız sonlanma" grubu olarak ele alınmalı)
- Vaka başına gün sayısı: OVSYNC vakalarında canlı örneklerde **4 gün** (3 farklı vaka: c065e94e,
  51adfd85 + ba865063'ün vaka günleri) `[OBSERVED]`. Tablo-genel "vaka başına gün dağılımı"
  çıkarılamadı: PostgREST'te `select=case_id,count` 42803 (GROUP BY otomatikleşmiyor)
  `[OBSERVED hata]` — bu sayım ya view ya client-side olmalı.
- Geciken açık TEDAVI_GUN (`tamamlandi=false & iptal=false & hedef_tarih<2026-09-28`): **4** satır
  `[OBSERVED limit 100]`.
- Açık TOHUMLAMA_PLANLI: **12** (11 şablon-TAI + 1 PG-TAI) `[OBSERVED limit 30]`.
- Açık OVSYNC_BASLAT: **30** `[OBSERVED]`. ILK_TOHUMLAMA instance: **1** (tamamlandi) `[OBSERVED]`.
- `protokol_ayar.ovsync_pg_kurallari_aktif = 1` (açık) `[OBSERVED]`.
- `pg_application_event`: 3 satır, hepsi ALLOW/OLUSTU; `UYGUNSUZ`/diğer karar değerleri henüz
  örneklenmemiş **[bilinmiyor]** `[OBSERVED select=karar,gorev_sonuc limit 100 → 3]`.

## 4. Takip ekranı ihtiyaç açıkları (tek ekran ovsync takibi için)

Ekranın ihtiyaçları: (a) hangi hayvan hangi protokol gününde, (b) bekleyen/geciken görev,
(c) sonlanma durumu. Her maddeye kanıt:

**A1 — "Gün ↔ görev" bağı dedicated kolonsuz, JSON string içinde.**
`treatment_days.id` yalnız `gorev_log.aciklama` JSON'undaki `day_id` ile bulunuyor; `gun_no`,
`planned_time` de orada. Tek ekran listesi için vaka başına gün satırlarını görev bilinciyle eşlemek
client-side JSON parse demek. Kanıt: `[OBSERVED gorev_log.aciklama örnekleri]`; day_id kolonu
görünmedi `[OBSERVED select=*]`. → Ekran için view ya da day_id/gun_no kolonları gerekecek.

**A2 — Görevde case_id yok; vaka bağlantısı yalnız `kaynak` metninde.**
TEDAVI_GUN görevinden vaka'ya ulaşmanın yolu: aciklama.day_id → treatment_days.case_id (2-hop).
TAI görevlerinde vaka id'si `kaynak='TEDAVI_SABLON_TOHUMLAMA:<case_id>:<sablon_id>'` string parçası;
`kapatan_ref` ve `ref_tohumlama_id` bu bağı taşımıyor `[OBSERVED]`. "Bu vakanın tüm görevleri" tek
WHERE ile çekilemez.

**A3 — vaka→tohumlama FK'sı şemada var, veride hiç kullanılmıyor.**
`tohumlama.case_id` 0 dolu satır `[OBSERVED]`; 10 TOHUMLAMA-kapanış vakasında tohumlama izi vaka
satırında YOK. "Bu vaka hangi tohumlamayla kapandı" sorusu şemadan cevaplanamıyor; islem_log
zaman-eşleşmesi gerekir. Takip ekranı "sonlanma → sonuç tohumlama" kolonu için açık.

**A4 — Hayvan-merkezli hazır view protokol bilgisini taşımıyor.**
`hayvan_durum_view` zengin (yas_gun, toh_sonuc, aktif_hastalik_sayisi, repeat_breed_*, kisir,
tohumlama_esik_gun) ama protocol_family/aktif vaka/gün ilerlemesi YOK `[OBSERVED kolon listesi]`;
`v_eligible` yalnız sessiz-sayaç `[OBSERVED]`; `v_ureme_dongusu` geçmiş döngü + düveleri kapsamıyor
`[OBSERVED b670f888 → 0 satır]`. "Hangi hayvan hangi günde" için tek-sorgu yüzey yok →
3-4 tablo join'i gerektiğinden PostgREST üstünde panel ya da view tasarıma konu olmalı.

**A5 — Sonlanma sonrası "kural günü bekleyenler" ayrı sorgu.**
Övysnc başlatılmamış 30 dişi `OVSYNC_BASLAT` görevi olarak ayrı evrende (`gorev_log`, hedefleri
2027'ye uzanan) `[OBSERVED]`. Ekranın "ilk tohumlama bekleyenler" bölümü için bu görevler +
`hayvan_durum_view`'dan kural-günü çapası (dogum_tarihi/abort) birleştirilmeli; tek hazır alan yok.
`gorev_ertele_kural.OVSYNC_BASLAT.zincir_tetikler.tai_ofset_gun=10` ertelemede TAI'ın nasıl kayacağını
söylüyor `[OBSERVED]` — ekran erteleme sonrası yeni hedefi görevden okumalı.

**A6 — `tamamlandi=true` + `iptal=true` çift bayrak durumu.**
İptal edilen/override edilen görevlerde iki bayrak birden dolu (fa42f344, 7b560cf8, 838ee37f)
`[OBSERVED]`. Takip ekranında "kapandı" ile "iptal edildi" ayrımı her liste için `(tamamlandi, iptal)`
ikilisiyle yorumlanmalı; tek `durum` kolonu yok (fail-closed: iptal-gerçekleşmiş mi, iptal-sonrası-tamam
mi ayrımı veriden doğrulanmalı).

**A7 — Eski OVSYNC vakaları close_reason'suz.**
7 kapalı vakada `close_reason=NULL` `[OBSERVED]` — "sonlanma durumu" kolonu NULL güvenli olmalı
(bilinmeyen/eski olarak sınıflanmalı).

**A8 — Gruplu sayım yok (PostgREST aggregate kısıtı).**
`select=kolon,count` 42803; yalnız `select=count` çalışıyor `[OBSERVED]`. Panel toplamları
(gün progressed, geciken sayısı, protokol aşaması dağılımı) client-side ya da yeni view/RPC ister.

**A9 — `cases.animal_id` tipi belirsiz (text görünümünde UUID).**
`hayvanlar.id` uuid, `cases.animal_id` JSON'da string-UUID `[OBSERVED/INFERRED]`; join yazarken
tip dönüşümü doğrulanmalı (information_schema erişilemedi; default/nullable meta'sı da bu sebeple
yok — tüm kolon meta'ları raporda INFERRED düzeyinde).

**A10 — day_no şablon gun_no eşlemesi kanıtsız.**
Şablon `gun_no 1,8,9,10` vs vaka `day_no 1,2,3,4` `[OBSERVED iki taraf da]`. Ekran "Gün 8/PG" gibi
şablon-gerçek etiketi basacaksa eşleme kuralını RPC gövdesinden (`start_first_service_protocol`)
doğrulatmak gerekir; canlı veriden çıkarılamaz (INFERRED: sıra-sıkıştırma).

## 5. Kaynak dosyalar

- Rapor: `/home/melik/egesut-erp1/runs/2026-09-28-ovsync-takip/w2-veri-modeli-raporu.md` (bu dosya)
- Zorunlu okuma: `.harness/references/domain-rules.md` (§8, §12, §18), `.harness/references/rpc-reference.md`
- Bağlam migration'ları (canlı kanıt DEĞİL): `20260923000002_ovsync_pg_sema.sql`, `20260923000003..6`,
  `20260925000013_ovsync_protocol_family.sql`, `20260925100003..6`, `20260926000002..3`
- Tüm PROD erişimi: tools-bank `supabase_query` (salt-SELECT; PostgREST /rest/v1, service_role key)
