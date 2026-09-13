# W1 — 51 Nolu Buzağının Kaydı Neden Yok? (Salt-Okuma Araştırma, Rev 2)

**Tarih:** 2026-09-13 · **Worker:** buzagi-51-arastirma (glm) · **Erişim:** Supabase Management API, prod `zqnexqbdfvbhlxzelzju`, yalnız SELECT (script'te SELECT/WITH dışı ifade reddi çiti)
**Kaynak saha notları:** doğum `195 / 17.11.2025 / düve / 51 / +- anne 195`; tedavi `51-49-50-47-48-39-45-46-36-43-44 : (19-20-21.11.25) : enroflaksasin 3ml`
**Rev 2:** root denetimindeki iki kusur düzeltildi — S4'teki yanlış snapshot sayımı ve 06-21 zaman çıkarımı geri çekildi; kimlik zinciri 4019→51→31 olarak yeniden kuruldu.

## Özet

**51'in kaydı yok değil — var, Aktif ve bugün bile aktif kullanılıyor.** Kopuk olan şey
anne bağı ve (kısmen) aşı geçmişi. Ölçülen zincir:

1. Canlı DB'de küpe `51` **tek** kayıt: `a67cd118-0b12-4f39-a26a-501187b945b9`, Dişi,
   düve, **Aktif**, doğum tarihi **2025-11-17**, devlet küpe `TR093215057`
   (38/45/46'daki TR093215-052/055/056 serisiyle uyumlu). **`anne_id` NULL.**
   Kaydın kimlik geçmişi iki aşamalı: 2026-05-09'da **"4019"** olarak girildi (doğum,
   devlet küpe ve anne **boş**); 2026-06-02 14:01:16'da (124 hayvanı kapsayan toplu
   güncelleme) **51'e dönüştürüldü** — bu dönüşüm izsizdir (bkz. S4).
2. `dogum` tablosunda 195→51 kaydı **VAR ve DOĞRU**: `577a2ecb`, tarih 2025-11-17,
   `yavru_kupe='51'`, `anne_id=195` (bac3b8f8). Tarih karışması (aa/gg) yok.
3. Kök neden (düzeltilmiş zincir): **2026-06-01 07:01'de dogum geri-doldurması "51"
   kopyasını girdi** (`982fbd16…`, `anne_id=195`, doğum 2025-11-17 + dogum satırı +
   4 aşı) — o an kupe `51` boştu, **çift kayıt buradan doğmadı**. Çift kayıt
   **2026-06-02 14:01'de 4019→51 yeniden adlandırmasıyla doğdu**; sonrasında (zamanı
   ölçülemez) `982fbd16` **"31"e dönüştürüldü** (doğum 2025-08-09, devlet
   Tr093150354; `anne_id=195` üstünde kaldı) ve duplikat böyle çözüldü. Sonuç:
   (a) yaşayan 51 satırı annesiz kaldı, (b) 195'in pedigree'de görünen tek yavrusu
   **hayalet 31** oldu (iki doğum arası 3 ay — biyolojik olarak imkânsız), (c)
   06-01'de **51 için girilen 4 aşı kaydı bugün 31'in aşısı görünüyor**.
   **31'in kimliği gerçek görünüyor** (32=TR093150353 ile ardışık devlet küpesi;
   31/32'nin dogum kaydı yok) — **hatalı olan üstündeki anne-195 bağı**.
4. Tamamlayıcı görünürlük faktörü: 51 **"Düve (Küçük)"** grubunda; "buzağı"
   listesinde arayan göremez.
5. **Enrofloksasin (19-21.11.2025) hiç sisteme girilmemiş:** `uygulama_log`'da
   2026-06-04 öncesi **0 kayıt**; 11 buzağıdan hiçbirinde tedavi kaydı yok — saha
   notu evrakta kalmış.
6. Ölü kayıt senaryosu, id-sürekliliğiyle elendi: her iki satır da (a67cd118, 982fbd16)
   tek `HAYVAN_EKLENDI` taşıyor ve bugün canlı — silinme yok; **iki izsiz yeniden
   adlandırma var** (4019→51, 51→31). **Sınırlar:** `islem_log` yalnız `AFTER INSERT`
   logluyor (migration `20260306000008:501`); `HAYVAN_GUNCELLENDI` tüm DB'de **0** —
   hayvan güncelleme/silme izi tutulmuyor. Kimlik dönüşümleri tam da bu kör noktada
   çözüldü.
7. Yedekler: günlük pg_dump artefaktları **90 gün** tutuluyor; en eski erişilebilir
   artefakt 2026-07-05 → 2025-11'i veya backfill anını içeren yedek **yok** (zaten
   silinmiş). Kalan yedekler bugünkü durumu (anne_id NULL) gösterir, yeni bilgi katmaz.

## Kanıt

Tüm sorgular prod `zqnexqbdfvbhlxzelzju`'ya Management API üzerinden çalıştırıldı
(yalnız SELECT). `norm-kupe` = `regexp_replace(trim(kupe_no),'^0+','')`.

### S1 — Küpe "51" araması (varyantlar dahil)

```sql
SELECT id, kupe_no, devlet_kupe, cinsiyet, kategori, durum, dogum_tarihi, anne_id,
       created_at::date, updated_at::date
FROM hayvanlar
WHERE trim(kupe_no)='51' OR regexp_replace(kupe_no,'^0+','')='51'
   OR kupe_no ~ '(^|[^0-9])51([^0-9]|$)' OR devlet_kupe ~ '(^|[^0-9])51([^0-9]|$)';
```

**1 satır** (tek canlı kayıt; 051/boşluk/gömülü varyant yok):

| alan | değer |
|---|---|
| id | `a67cd118-0b12-4f39-a26a-501187b945b9` |
| kupe_no / devlet_kupe | `51` / `TR093215057` |
| cinsiyet / kategori | Dişi / duve |
| **durum** | **Aktif** (çıkış alanlarının üçü de NULL) |
| dogum_tarihi | **2025-11-17** |
| **anne_id** | **NULL** |
| created_at / updated_at | 2026-05-09 / **2026-06-02 14:01:16.927** |

- `hayvan_override` tablosunda 51: **0 satır** (ölçüm: `SELECT * FROM hayvan_override
  WHERE trim(kupe_no)='51' OR kupe_no ~ '51'`).
- `hayvanlar`'da "isim/ad" kolonu yok (kimlik `kupe_no`); hayvanlar/dogum tablolarında
  `farm_id` kolonu yok (eski global şema — tek çiftlik verisi, tenant ayırtı söz konusu değil).
- Grup/padok (ölçüm: `SELECT kupe_no, grup, padok, kategori, notlar, etiketler, … FROM
  hayvanlar WHERE id='a67cd118…'` → 1 satır): **grup="Düve (Küçük)"**,
  **padok="Düve Padok (Küçük)"**, notlar NULL, etiketler boş.
- Devlet küpe serisi uyumu (ölçüm: norm-kupe 31/32/38/45/46 → 5 satır):
  38=`TR093215052`, 46=`TR093215055`, 45=`Tr093215056`, **51=`TR093215057`** — aynı seri;
  31=`Tr093150354`, 32=`TR093150353` (başka seri, ardışık çift).
- Canlı kullanım: 51'e **bugün** (2026-09-13 05:28 UTC) vaka + 4 tedavi günü açılmış
  (`islem_log`: `VAKA_ACILDI`/`TEDAVI_GUN_EKLENDI`×4).

### S2 — Anne 195'in doğum kayıtları

Anne adayı: `hayvanlar` norm-kupe `195` → **1 satır**: `bac3b8f8-43c3-4cf5-83ed-6e1073c16fec`,
Dişi, inek, Aktif.

```sql
SELECT id, anne_id, tarih, yavru_kupe, yavru_cins, dogum_tipi, created_at::date
FROM dogum
WHERE anne_id='bac3b8f8-43c3-4cf5-83ed-6e1073c16fec'
   OR yavru_kupe ~ '(^|[^0-9])51([^0-9]|$)';
```

**1 satır:**

| alan | değer |
|---|---|
| id | `577a2ecb-5bd3-4a69-a4e0-064ce4c142d0` |
| anne_id | `bac3b8f8…` (=195) |
| tarih | **2025-11-17** — saha notuyla birebir; **aa/gg karışması YOK** |
| yavru_kupe / yavru_cins / dogum_tipi | `51` / Dişi / Normal |
| created_at | 2026-06-01 (geri-doldurma) |

Korelasyon — 195'in tohumlama geçmişi (ölçüm: `SELECT id, tarih, sonuc, buzagi_kupe,
dogum_tarihi FROM tohumlama WHERE hayvan_id='bac3b8f8…' ORDER BY tarih` → **5 satır**):

| tarih | sonuc | buzagi_kupe / dogum_tarihi |
|---|---|---|
| 2024-11-18 | Boş | NULL / NULL |
| **2025-02-09 (`d10537ba…`)** | **'Doğum Yaptı'** | **NULL / NULL — damgalanmamış** |
| 2026-03-20 | Boş | NULL / NULL |
| 2026-05-01 | Boş | NULL / NULL |
| 2026-05-22 | Gebe | NULL / NULL |

Canlı `dogum_kaydet` doğumda `buzagi_kupe`+`dogum_tarihi` yazıyor; burada NULL —
geri-doldurma bu yan etkiyi de üretmemiş. 2025-02-09 + ~283 günlük gebelik ≈ 2025-11-19 ✓.

**195'in pedigree'de görünen yavrusu ise başka:** `hayvanlar`'da `anne_id=bac3b8f8` taşıyan
**tek** canlı satır `982fbd16-51d8-422d-8bbe-235bb023f22b` — şu an **kupe_no `31`**,
dogum_tarihi **2025-08-09**; `dogum` tablosunda 31'e dair **kayıt yok** (ölçüm:
`SELECT … FROM dogum WHERE trim(yavru_kupe) IN ('31','32')` → **0 satır**). 195'e
atfedilen iki doğum arası 3 ay 8 gün → biyolojik olarak imkânsız; bağlardan biri yanlış
(aşağıda hangisi).

### S3 — Listedeki 11 buzağı ve tedavi kayıtları

```sql
SELECT kupe_no, cinsiyet, durum, dogum_tarihi,
       (anne_id IS NOT NULL) AS anneye_bagli, created_at::date
FROM hayvanlar
WHERE regexp_replace(trim(kupe_no),'^0+','') IN
      ('51','49','50','47','48','39','45','46','36','43','44');
```

**11 satır — 11/11 kayıtlı:**

| kupe | durum | dogum_tarihi | anneye_bagli | dogum.anne_id |
|---|---|---|---|---|
| 36 | Aktif | 2025-10-06 | ✓ | ✓ (142) |
| 39 | Aktif | 2025-10-19 | ✗ | **NULL** (notlarda anne bilinmiyordu) |
| 43 | Aktif | 2025-11-03 | ✓ | ✓ (178) |
| 44 | Aktif | 2025-11-07 | ✓ | ✓ (904) |
| 45 | Aktif | 2025-11-09 | ✓ | ✓ (197) |
| 46 | Aktif | 2025-11-13 | ✓ | ✓ (191) |
| 47 | Aktif | 2025-11-13 | ✓ | ✓ (155) |
| 48 | Aktif | 2025-11-15 | ✓ | ✓ (5708) |
| 49 | Aktif | 2025-11-16 | ✓ | ✓ (905) |
| 50 | **Ölü** | 2025-11-16 | ✗ | **NULL** |
| **51** | **Aktif** | **2025-11-17** | **✗** | **✓ VAR (195) — ama hayvanlar satırına işlenmemiş** |

Tedavi tarafı:

```sql
-- 11 buzağı × uygulama_log (2025-11-01..2025-12-05) → 0 satır
-- 11 buzağı × tedavi (tüm dönemler)            → 0 satır
SELECT min(tarih) AS ilk, count(*) FILTER (WHERE tarih < '2026-06-01') AS oncesi
FROM uygulama_log;
-- → ilk=2026-06-04, oncesi=0
-- Aylık dağılım: 2026-06:42, 2026-07:40, 2026-08:23, 2026-09:15
```

**Enrofloksasin (19-21.11.2025) hiç sisteme girilmemiş:** `uygulama_log`'da
2026-06-04 öncesi **0 kayıt**; sistem kaydı tamamen 2026-06'dan sonra başlıyor. 11
buzağıdan hiçbirinde — 51 dahil — bu olaya ait kayıt yok; saha notu evrakta kalmış.
51'in DB'deki faaliyeti: 2 aşısı, 9 işlem, 11 görev kaydı — işlem ve görev sayıları
listenin en yoğun üyesi (ölçüm: tablo-bazlı count alt-sorguları → 51: uygulama=0,
islem=9, gorev=11, asi=2).

### S4 — Audit / silme izleri ve kimlik dönüşümleri (Rev 2'de yeniden kuruldu)

- **Soft-delete yok:** `hayvanlar` şemasında `deleted_at` yok; `durum` değerleri
  `Aktif/Ölü/Satıldı/Kesildi` (142/12/11/1). Bu değerlerin hiçbirinde 51 yok (51 = Aktif).
- **`islem_log` yalnız INSERT logluyor:** migration `20260306000008_blok1_backend.sql:501`
  → `CREATE TRIGGER trg_islem_hayvanlar AFTER INSERT ON public.hayvanlar`. Canlı
  `pg_get_functiondef('_islem_log_yaz()')` gövdesi `TG_OP` yalnız INSERT/UPDATE'i işliyor;
  canlı `tgtype=5`. **`HAYVAN_GUNCELLENDI` tüm DB'de 0 satır** (ölçüm: `SELECT count(*)
  FROM islem_log WHERE tip='HAYVAN_GUNCELLENDI'`) — hayvan UPDATE/DELETE izi sistemde
  hiç tutulmuyor.
- **Her iki satır da silinmemiş (id-sürekliliği):** `a67cd118` için **tek** `HAYVAN_EKLENDI`
  (2026-05-09 07:42:45 UTC), `982fbd16` için **tek** `HAYVAN_EKLENDI` (2026-06-01 07:01:28
  UTC); silinip yeniden girilme id + snapshot-id eşleşmesiyle dışlandı (yeni giriş
  yeni id üretirdi; her iki id bugün canlı).

**Kimlik dönüşümleri — INSERT snapshot'ları (ölçüm: `SELECT tarih, snapshot FROM
islem_log WHERE tip='HAYVAN_EKLENDI' AND ana_hayvan_id=…`):**

| satır | girildiği gibi (snapshot) | bugünkü hali |
|---|---|---|
| `a67cd118` (05-09 07:42) | **kupe_no=`4019`**, devlet_kupe=NULL, dogum_tarihi=NULL, anne_id=NULL, cinsiyet=NULL, kategori=duve, padok="Düve-Kuru Padok" | kupe_no=`51`, TR093215057, 2025-11-17, Dişi, düve, "Düve (Küçük)" |
| `982fbd16` (06-01 07:01) | **kupe_no=`51`**, dogum_tarihi=2025-11-17, **anne_id=195**, devlet_kupe=NULL, grup="Düve (Küçük)", padok=P1 | kupe_no=`31`, Tr093150354, 2025-08-09, anne_id=195 (üstünde kaldı) |

Sayım düzeltmesi (Rev 1 hatası): `snapshot->>'kupe_no'='51'` filtresi **1 satır**
döndürür — yalnız `982fbd16`. `a67cd118`'in snapshot'ı `4019`'dur.

**İki izsiz yeniden adlandırma:**

1. **4019→51** (`a67cd118`): `updated_at=2026-06-02 14:01:16.927`. Aynı dakika damgası
   **124 hayvanda** (ölçüm: `SELECT count(*) FROM hayvanlar WHERE
   to_char(updated_at,'HH24:MI:SS')='14:01:16' AND updated_at::date='2026-06-02'`) →
   **toplu güncelleme**. Bu adımla satır, backfill'in 06-01'de girdiği "51" ile
   **çakışan ikinci bir 51 oldu** (doğum 2025-11-17 + TR093215057 verileri de o gün bu
   satıra işlendi).
2. **51→31** (`982fbd16`): kupe + doğum tarihi (2025-11-17→2025-08-09) + devlet küpe
   (→Tr093150354) değişti; `anne_id=195` üstünde kaldı. **Değişim zamanı ölçülemez**
   (UPDATE izi yok). Alt sınır: 2026-06-02 14:01 (çift kaydın doğuşundan sonra).
   **`updated_at=2026-06-21 06:13:52` kupe değişimi olarak yorumlanamaz** — o damga
   31/36/38/45/46'da ortaktır ve padok toplu işlemine aittir (Rev 1'deki çıkarım geri
   çekildi). En geç üst sınır izi: `GRUP_PADOK_UYUMLAMA` 2026-07-17 20:15 (satır o gün
   canlı ve işleniyordu).

**31/32 kimlik analizi (ölçüm: norm-kupe 31/32 → 2 satır + dogum → 0 satır):**

| kupe | devlet_kupe | dogum_tarihi | anne_id | dogum kaydı |
|---|---|---|---|---|
| 32 | TR093150353 | 2025-09-05 | **NULL** | yok |
| 31 | **Tr093150354** (32 ile **ardışık**) | 2025-08-09 | **195 — tutarsız** | yok |

Ardışık devlet küpeleri → 31 büyük olasılıkla **gerçek bir buzağı**; üzerindeki
**anne-195 bağı** hatalı/artık (dönüşüm artığı). 32'nin annesi de DB'de bağsız
(sahip bilgisine göre 156 — hayvan 156 canlı ve Aktif, ama 32 ile aralarında ne
`anne_id` ne dogum kaydı var) — aynı kayıp-sınıfının ikinci örneği.

**Sistemin geneli için ölçümler:**
- `islem_log` INSERT'lerinde canlıda karşılığı olmayan hayvan: **313 satır** — giriş
  tarihine göre 308 (2026-05-09; ilk içe aktarma aynı gün ~5 kez koşmuş, kopyalar
  temizlenmiş) + 5 tekil (2026-05-16, 2026-06-01=kupe78, 2026-06-04, 2026-06-13,
  2026-06-20) — tümü hesaplı. Snapshot'ında `anne_id` taşıyan ölü kopya: **1** — kupe
  78 (`b315771e…`, 06-01, anne 88449c15), gerçek **hard-delete**; canlı 78
  (`daaa2054…`) bağını doğru taşıyor (anne 901). Aynı backfill iki vakada iki farklı
  elleme görmüş: 78'de doğru kopya silinmiş, 51'de kopya başka hayvana dönüştürülmüş.
- **Aşı kayıtları yetim DEĞİL:** `vaccination_log`'da `animal_id=982fbd16` olan 4 kayıt
  (2×2026-01-16 + 2×2026-02-15, dördü de 2026-06-01 07:25:45'te — backfill dakikası)
  **51 için girilmişti** (o an `982fbd16` "51" idi); bugün hedef satır canlı olduğu
  için **31'in aşısı olarak görünüyorlar**. Yaşayan 51'de 2 aşı var (2×2026-04-10,
  2026-05-10'da girilmiş — backfill öncesi).

### S5 — GitHub yedekleri (indirme YAPILMADI)

`.github/workflows/db-backup.yml` (okundu): her gün 00:00 UTC pg_dump (session pooler,
Docker `postgres:17`, custom format + compress) → `openssl enc -aes-256-cbc -pbkdf2`
(`BACKUP_PASSWORD` secret) → Actions artefaktı `egesut-backup-<run_id>`,
**`retention-days: 90`**.

Ölçüm (salt-okunur, `gh api …/actions/artifacts`): en eski erişilebilir artefakt
**2026-07-05**. Yani (a) 2025-11'i ve (b) 2026-06-01 backfill anını içeren yedek
**artık yok**; kalanlar bugünkü durumu (anne_id NULL) zaten gösterir. Sahip bir yedeği
yine de açmak isterse yol: `gh run list --workflow=db-backup.yml` → `gh run download
<run-id>` → `openssl enc -d -aes-256-cbc -pbkdf2 -pass pass:"$BACKUP_PASSWORD" -in
egesut_YYYYMMDD.pg.enc -out dump.pg` → `pg_restore -f - dump.pg | grep -A2 'kupe_no'`.
`BACKUP_PASSWORD` yalnız sahipte; bu araştırmada indirme/şifre çözümü **yapılmadı**
(görev kuralı).

## Kök neden hipotezi

Ölçülen olgular + açıkça etiketlenmiş yorum — düzeltilmiş zaman çizelgesi:

| zaman (UTC) | olay | kanıt |
|---|---|---|
| 2026-05-09 07:42 | Toplu içe aktarma: satır **"4019"** olarak girdi (doğum/devlet/anne boş; ~85 hayvanlık partinin koşularından biri; kopyalar temizlendi) | INSERT snapshot |
| 2026-06-01 07:01 | Dogum geri-doldurması: **"51"** girildi (`982fbd16`, anne=195) + dogum satırı `577a2ecb`. O an kupe 51 **boştu — çift kayıt buradan doğmadı** | INSERT snapshot; S2 |
| 2026-06-01 07:25 | 4 aşı kaydı bu "51"e girildi | vaccination_log created_at |
| 2026-06-02 14:01:16 | **Toplu güncelleme (124 hayvan):** `a67cd118` 4019→51 (+doğum 2025-11-17 +TR093215057 +duve) → **iki canlı "51"** | updated_at + 124'lük ortak damga |
| 06-02 sonrası, zaman ölçülemez | `982fbd16` **51→31** + doğum→2025-08-09 + devlet→Tr093150354 → duplikat çözüldü; **anne=195 üstünde kaldı** | snapshot ↔ canlı farkı |
| 2026-06-21 06:13:52 | Padok toplu işlemi (31/36/38/45/46 ortak damga) — kupe değişimiyle ilişkilendirilemez | islem_log `padok_degisim` |

[Yorum, etiketli] 06-02 adımı büyük olasılıkla "4019 satırı aslında buzağı 51'dir"
düzeltmesiydi; yapan, 06-01'de backfill'in girdiği "51"i görmemiş → çift kayıt.
06-02+ adımı çifti "31'e çevirerek" çözmüş; ama 195→51 anne bağı, dogum satırı ve 4
aşı `982fbd16`'da (31'de) hapsolmuş, `a67cd118`'e (bugünkü 51) hiç işlenmemiş.
**İki dönüşümün faili/yolu/yöntemi hiçbir izlemeden çıkarılamaz** (islem_log kör
noktası + `ui_logs`'ta ilgili id geçen 0 kayıt).

## Önerilen düzeltme (salt öneri — uygulama owner emrine tabi)

1. **Anne bağının 51'e yazılması:** `a67cd118` (51) satırına
   `anne_id='bac3b8f8-43c3-4cf5-83ed-6e1073c16fec'` (dogum kaydı `577a2ecb` destekli;
   bağımsız doğrulama yalnız saha notundaki "+- anne 195"). Aynı işte tohumlama
   `d10537ba`'ya `buzagi_kupe='51'` + `dogum_tarihi='2025-11-17'` damgası.
2. **Hatalı anne bağının 31'den ayrılması:** `982fbd16` (31) satırından
   `anne_id=195` kaldırılmalı (31 kimliği gerçek görünüyor; iki doğum 3 ay arayla
   imkânsız). 31'in gerçek annesi biliniyorsa o yazılmalı; bilinmiyorsa NULL. Aynı
   işte 32'nin anne bağı (sahip bilgisine göre 156) kurulabilir — aynı kayıp sınıfı.
3. **Aşı sahipliği teyidi:** `animal_id=982fbd16` üzerindeki 4 kayıt (06-01'de 51 için
   girildi) 51'e (`a67cd118`) taşınmalı mı — owner teyidiyle `animal_id` düzeltmesi.
4. **Yapısal (ayrı iş olarak):**
   - Toplu güncelleme/içe aktarma araçlarında **kupe çakışma kontrolü** (06-02 vakası:
     4019→51 ataması o gün girilmiş "51"i görmedi) + mevcut-kupe "güncelle" yolu.
   - `hayvanlar` için **UPDATE/DELETE izleme** (islem_log şu an INSERT-only,
     `20260306000008:501`) veya güncelleme yapan RPC'lere açık `islem_log` yazımı —
     bu olay tam da bu kör noktada çözüldü.
   - Aktifler arasında **kupe_no unique partial index** değerlendirmesi (ön-ölçüm:
     `SELECT kupe_no, count(*) FROM hayvanlar GROUP BY kupe_no HAVING count(*)>1` →
     **0 satır** — bugün duplikat yok ama 06-02 14:01'den 51→31 dönüşümüne kadar iki
     canlı "51" yaşadığı ölçüldü).
5. **Ölçülmedi / kalan:** 51→31 dönüşümünün zamanı, faili ve yöntemi (iz yok);
   "4019" kimliğinin gerçekten başka bir hayvan mı yoksa boş yer tutucu mu olduğu
   (bugün canlıda 4019 yok — ölçüm); yedekle geçmiş doğrulaması (90 gün retention — S5).

## Teslim review notu (şerit kuralı #1)

- **Tur 1 — builtin subagent (salt-okuma):** 7 bulgu; tümü commit öncesi rapora
  işlendi (Özet mutlaklıkları, `d10537ba` kanıtı, niyet atfı, bozuk cümle, grup
  kanıtı, duplikat ön-ölçümü, 313 dağılımı).
- **Tur 2 — root denetimi (2b7e951):** düzeltme isteği — (1) S4'teki yanlış snapshot
  sayımı: `snapshot->>'kupe_no'='51'` 1 satır döndürür, `a67cd118` "4019" olarak
  girilmiş → kimlik zinciri 4019→51→31 olarak yeniden kuruldu; (2) 06-21 zaman
  çıkarımı geri çekildi (ortak padok damgası); (3) 31/32 kimlik analizi eklendi (31
  gerçek, hatalı olan anne-195 bağı); (4) aşı kayıtlarının "51 için girildiği" açıkça
  yazıldı; (5) enrofloksasinin hiç girilmediği net ifadleyle yazıldı. Tüm düzeltmeler
  yeniden ölçümle (R1-R7 sorguları) doğrulanarak bu Rev 2'ye işlendi; öneriler salt
  öneri olarak tutuldu.
