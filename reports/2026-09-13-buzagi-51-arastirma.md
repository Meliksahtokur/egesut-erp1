# W1 — 51 Nolu Buzağının Kaydı Neden Yok? (Salt-Okuma Araştırma)

**Tarih:** 2026-09-13 · **Worker:** buzagi-51-arastirma (glm) · **Erişim:** Supabase Management API, prod `zqnexqbdfvbhlxzelzju`, yalnız SELECT (script'te SELECT/WITH dışı ifade reddi çiti)
**Kaynak saha notları:** doğum `195 / 17.11.2025 / düve / 51 / +- anne 195`; tedavi `51-49-50-47-48-39-45-46-36-43-44 : (19-20-21.11.25) : enroflaksasin 3ml`

## Özet

**51'in kaydı yok değil — var, Aktif ve bugün bile aktif kullanılıyor.** Kopuk olan şey
anne bağı ve (kısmen) aşı geçmişi. Ölçülen zincir:

1. Canlı DB'de küpe `51` **tek** kayıt: `a67cd118-0b12-4f39-a26a-501187b945b9`, Dişi,
   düve, **Aktif**, doğum tarihi **2025-11-17** (saha notuyla birebir), devlet küpe
   `TR093215057`. 2026-05-09'da toplu içe aktarmayla girmiş; **`anne_id` NULL**.
2. `dogum` tablosunda 195→51 kaydı **VAR ve DOĞRU**: `577a2ecb`, tarih 2025-11-17,
   `yavru_kupe='51'`, `anne_id=195` (bac3b8f8). Tarih karışması (aa/gg) yok.
3. Kök neden: **2026-06-01 dogum geri-doldurması, anne-bağlı ikinci bir "51" kopyası
   yaratmış** (`982fbd16…`, INSERT snapshot'ında `anne_id=195`). Bu bağlı kopya
   silinmemiş — **"31"e dönüştürülmüş**: küpe 51→31, doğum 2025-11-17→2025-08-09,
   devlet küpe Tr093150354. **Dönüşümün niteliği izlerden ayırt edilemiyor** (temizlik
   mi, kupe yazım hatasının düzeltmesi mi — bkz. Kök neden 3); ölçülen: satır 06-21'de
   güncellenmiş, eski hali INSERT snapshot'ından okundu. Sonuç: (a) yaşayan 51 satırı
   annesiz kaldı, (b) 195'in pedigree'de görünen tek yavrusu **hayalet 31** oldu (iki
   doğum arası 3 ay — biyolojik olarak imkânsız), (c) 06-01 07:25'te bağlı kopyaya
   yazılan **4 aşı kaydı bugün 31'in aşısı görünüyor**. Sınır notu: 195→51 bağının
   bağımsız desteği yalnız saha notundaki "+- anne 195" işareti ve geri-doldurmada
   giren dogum satırı; DB'de başka doğrulayıcı yok.
4. Tamamlayıcı görünürlük faktörü: 51 artık **"Düve (Küçük)"** grubunda; "buzağı"
   listesinde arayan göremez. Enrofloksasin tedavisi (19-21.11.2025) **hiçbir** listedeki
   buzağıya girilmemiş — `uygulama_log` 2026-06'dan başlıyor; olay hiç sisteme girilmemiş.
5. Ölü kayıt senaryosu, canlı satır için elendi: `a67cd118` id'si için **tek**
   `HAYVAN_EKLENDI` var ve snapshot id canlı satırla eşleşiyor (silinip yeniden
   girilseydi ikinci INSERT + yeni id zorunluydu). Kupe düzeyinde ise iki INSERT
   görüldü — ikincisi (`982fbd16`) madde 3'teki dönüştürülen kopya. `hayvanlar`'da
   soft-delete yok, durum değerleri (Ölü/Satıldı/Kesildi) içinde 51 yok. **Sınırlar:**
   `islem_log` yalnız `AFTER INSERT` logluyor (migration `20260306000008:501`);
   `HAYVAN_GUNCELLENDI` tüm DB'de **0** — hayvan güncelleme/silme izi tutulmuyor.
   51 olayı tam da bu kör noktada çözüldü.
6. Yedekler (S5): günlük pg_dump artefaktları **90 gün** tutuluyor; en eski erişilebilir
   artefakt 2026-07-05 → 2025-11'i veya 2026-06-01 backfill anını içeren yedek **yok**
   (zaten silinmiş). Kalan yedekler bugünkü durumu (anne_id NULL) gösterir, yeni bilgi katmaz.

## Kanıt

Tüm sorgular prod `zqnexqbdfvbhlxzelzju`'ya Management API üzerinden çalıştıldı (yalnız
SELECT). `h.kupe norm` = `regexp_replace(trim(h.kupe_no),'^0+','')`.

### S1 — Küpe "51" araması (varyantlar dahil)

```sql
SELECT id, kupe_no, devlet_kupe, cinsiyet, kategori, durum, dogum_tarihi, anne_id,
       created_at::date, updated_at::date
FROM hayvanlar
WHERE trim(kupe_no)='51' OR regexp_replace(kupe_no,'^0+','')='51'
   OR kupe_no ~ '(^|[^0-9])51([^0-9]|$)' OR devlet_kupe ~ '(^|[^0-9])51([^0-9]|$)';
```

**1 satır** (tek kayıt; 051/boşluk/gömülü varyant yok):

| alan | değer |
|---|---|
| id | `a67cd118-0b12-4f39-a26a-501187b945b9` |
| kupe_no / devlet_kupe | `51` / `TR093215057` |
| cinsiyet / kategori | Dişi / duve |
| **durum** | **Aktif** (çıkış alanlarının üçü de NULL) |
| dogum_tarihi | **2025-11-17** |
| **anne_id** | **NULL** |
| created_at / updated_at | 2026-05-09 / 2026-06-02 |

- `hayvan_override` tablosunda 51: **0 satır**.
- 51'in güncel grubu/padoku (ölçüm: `SELECT kupe_no, grup, padok, kategori, notlar,
  etiketler, … FROM hayvanlar WHERE id='a67cd118…'` → 1 satır): **grup="Düve (Küçük)"**,
  **padok="Düve Padok (Küçük)"**, notlar NULL, etiketler boş.
- `hayvanlar`'da "isim/ad" kolonu yok (kimlik `kupe_no`); hayvanlar/dogum tablolarında
  `farm_id` kolonu yok (eski global şema — tek çiftlik verisi, tenant ayırtı söz konusu değil).
- Aynı pencerede canlı `cases`/tedavi hareketi: 51'e **bugün** (2026-09-13 05:28 UTC)
  vaka + 4 tedavi günü açılmış (`islem_log`, `VAKA_ACILDI`/`TEDAVI_GUN_EKLENDI`) — hayvan
  günlük kullanımda.

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
dogum_tarihi **2025-08-09**, `dogum` tablosunda 31'e dair **kayıt yok**. 195'e atfedilen iki
doğum arası 3 ay 8 gün → biyolojik olarak imkânsız; bağlardan biri yanlış (aşağıda hangisi).

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
-- uygulama_log: 11 buzağı için 2025-11-01..2025-12-05 → 0 satır
-- tedavi:      11 buzağı için tüm dönemler → 0 satır
SELECT to_char(date_trunc('month',tarih),'YYYY-MM') AS ay, count(*)
FROM uygulama_log GROUP BY 1 ORDER BY 1;
```

→ `uygulama_log` **2026-06'dan başlıyor** (42/40/23/15 kayıt aylık). **19-21.11.2025
enrofloksasin uygulaması 11 buzağıdan HİÇBİRİNE girilmemiş** — saha notu evrakta kalmış.
51 bu listede DB'de tedavi kaydıyla görünmüyor; kalan faaliyeti: 2 aşısı, 9 işlem, 11
görev kaydı — işlem ve görev sayıları listenin en yoğun üyesi (ölçüm: tablo-bazlı count
alt-sorguları → 51: uygulama=0, islem=9, gorev=11, asi=2).

### S4 — Audit / silme izleri

- **Soft-delete yok:** `hayvanlar` şemasında `deleted_at` yok; `durum` değerleri
  `Aktif/Ölü/Satıldı/Kesildi` (142/12/11/1). Bu değerlerin hiçbirinde 51 yok (51 = Aktif).
- **`islem_log` yalnız INSERT logluyor:** migration `20260306000008_blok1_backend.sql:501`
  → `CREATE TRIGGER trg_islem_hayvanlar AFTER INSERT ON public.hayvanlar`. Canlı
  `pg_get_functiondef('_islem_log_yaz()')` gövdesi `TG_OP` yalnız INSERT/UPDATE'i işliyor;
  canlı `tgtype=5`. **`HAYVAN_GUNCELLENDI` tüm DB'de 0 satır** — hayvan UPDATE/DELETE izi
  sistemde hiç tutulmuyor.
- **Silinip-yeniden-girilme, canlı satır için ELENDİ:** `a67cd118` id'si için **tek**
  `HAYVAN_EKLENDI` (2026-05-09 07:42:45 UTC, snapshot id = canlı satır). O id'nin
  silinip yeniden girilmiş olması için ikinci INSERT + farklı id zorunluydu. (Kupe
  düzeyindeki ikinci INSERT — `982fbd16` — aşağıda ayrıca inceleniyor.)
- **AMA: ikinci bir "51" yaratılmış ve sonra dönüştürülmüş** (kök neden, aşağıda):

```sql
SELECT ana_hayvan_id, snapshot->>'kupe_no' AS kupe, snapshot->>'dogum_tarihi' AS dogum,
       snapshot->>'anne_id' AS anne, tarih
FROM islem_log WHERE tip='HAYVAN_EKLENDI' AND snapshot->>'kupe_no'='51';
-- 2 satır:
-- a67cd118…  kupe=51  dogum=2025-11-17  anne=NULL  2026-05-09 07:42  (canlı: bugünkü 51)
-- 982fbd16…  kupe=51  dogum=2025-11-17  anne=bac3b8f8(=195)  2026-06-01 07:01
```

`982fbd16` bugün **canlı ama kupe_no=`31`**, dogum_tarihi=`2025-08-09`,
devlet_kupe=`Tr093150354`, `anne_id=bac3b8f8` **hâlâ üstünde**, `updated_at=2026-06-21`.
Son işlem izleri: `padok_degisim` 2026-06-03 ve 2026-06-21, `GRUP_PADOK_UYUMLAMA`
2026-07-17 (UPDATE/DELETE loglanmadığı için küpe değişikliğinin kendisi izsiz; zaman
`updated_at` + bu izlerle sınırlandırıldı: **06-01 ile en geç 07-17 arasında, büyük
olasılıkla 06-21**).

**Sistemin geneli için iki ölçüm:**
- `islem_log` INSERT'lerinde canlıda karşılığı olmayan hayvan: **313 satır** — giriş
  tarihine göre 308 (2026-05-09; ilk içe aktarma aynı gün ~5 kez koşmuş, kopyalar
  temizlenmiş) + 5 tekil (2026-05-16, 2026-06-01=kupe78, 2026-06-04, 2026-06-13,
  2026-06-20) — tümü hesaplı.
  Snapshot'ında `anne_id` taşıyan ölü kopya sayısı: **1** — beklenenin aksine 51 değil:
  **kupe 78** (`b315771e…`, 2026-06-01, anne 88449c15) bu kopya gerçekten **hard-delete**
  edilmiş; canlı 78 (`daaa2054…`) kendi bağını doğru taşıyor (anne 901). Yani aynı
  backfill iki vakada iki farklı elleme görmüş: 78'de doğru kopya silinmiş, 51'de bağlı
  kopya **başka hayvana dönüştürülmüş**.
- 51'in 06-01 07:25'te bağlı kopyaya yazılan **4 aşı kaydı** `vaccination_log`'da
  `animal_id=982fbd16` ile duruyor → backfill'in 51'e yazdığı anlaşılan aşı kayıtları bugün
  **31'in aşısı** olarak görünüyor. Yetim DEĞİL — hedef satır canlı. Yaşayan
  51'de 2 aşı var (2×2026-04-10, 2026-05-10'da girilmiş — backfill öncesi). Aşı
  tarihleri 2×2026-01-16 + 2×2026-02-15; dördü de backfill dakikasında (07:25:45)
  yazılmış — doğum geri-doldurma paketinin parçası.

### S5 — GitHub yedekleri (indirme YAPILMADI)

`.github/workflows/db-backup.yml` (okundu): her gün 00:00 UTC pg_dump (session pooler,
Docker `postgres:17`, custom format + compress) → `openssl enc -aes-256-cbc -pbkdf2`
(`BACKUP_PASSWORD` secret) → Actions artefaktı `egesut-backup-<run_id>`,
**`retention-days: 90`**.

Ölçüm (salt-okunur, `gh api …/actions/artifacts`): en eski erişilebilir artefakt
**2026-07-05**. Yani (a) 2025-11'i ve (b) 2026-06-01 backfill anını içeren yedek
**artık yok**; kalanlar bugünkü NULL'u zaten gösterir. Sahip bir yedeği yine de açmak
isterse yol: `gh run list --workflow=db-backup.yml` → `gh run download <run-id>` →
`openssl enc -d -aes-256-cbc -pbkdf2 -pass pass:"$BACKUP_PASSWORD" -in egesut_YYYYMMDD.pg.enc -out dump.pg`
→ `pg_restore -f - dump.pg | grep -A2 'kupe_no'` (veya `pg_restore --list` + tablo
verisi). `BACKUP_PASSWORD` yalnız sahipte; bu araştırmada indirme/şifre çözümü
**yapılmadı** (görev kuralı).

## Kök neden hipotezi

Ölçülen olgular + açıkça etiketlenmiş yorum:

1. **2026-05-09 — ilk toplu içe aktarma:** 85 hayvan girildi, **hiçbirinde `anne_id` yok**
   (tarih bazlı ölçüm: 2026-05-09 kayıtlarının 85/85'i annesiz). 51 bu partiden; anne
   verisi o noktada sisteme taşınmamış. Aynı gün import ~5 kez koşmuş (313 ölü kopyanın
   308'i bu tarihte) → mevcut-kayıt kontrolü olmayan bir içe aktarma aracı.
2. **2026-06-01 — dogum geri-doldurması:** 72 dogum kaydının 49'u bu gün girildi
   (`DOGUM_KAYDI` izleri tümü INSERT-yollu). Bu iş **`dogum_kaydet` RPC'sini BYPASS
   etti** — RPC'deki `Bu küpe zaten kayıtlı` guard'ı (canlı gövdede mevcut) direkt
   INSERT'le devre dışı kaldı; sonuç: mevcut `51`'e rağmen **anne-bağlı ikinci 51
   kopyası (982fbd16)** + dogum satırı + 4 aşı. [Olgular ölçümlü; "RPC bypass" yargısı
   guard'ın varlığı + dogum satırının RPC ile giremeyecek olması (o saatte 51 Aktif'ti)
   üzerine kurulu yorum.]
3. **2026-06-21 (±) — çift kayıt temizliği:** iki "51" görünce bağlı kopya silinmemiş,
   **"31"e dönüştürülmüş** (kupe + doğum tarihi + devlet küpe değişti; anne_id üstte
   kaldı). Ne silme ne birleştirme — **yeniden kullanım**. Bu adım bir kişinin kasıtlı
   hamlesi ya da (982fbd16 gerçekten 31 olarak girilmek istendiyseniz) backfill'deki
   kupe yazım hatasının 06-21'de düzeltilmesi olarak okunabilir; **iki okuma da mevcut
   veriyle ayırt edilemez** ve sonuç aynı: 51'in anne bağı hiçbir satıra işlenmedi,
   195'in pedigree'sine dogum kaydı olmayan hayalet bir 31 doğumu yerleşti.
4. **Görünürlük:** 51 bugün "Düve (Küçük)" grubunda ve "Düve Padok (Küçük)"te;
   satırın `updated_at`'ı 2026-06-02 (hangi alanın o gün değiştiği izsiz). "Buzağı"
   filtresiyle bakan sahipte de "51 yok" hissi bu yüzden güçlenebilir. Sahip hayvanı
   bugün tedavi ediyor (vaka 2026-09-13 05:28) — hayvan kaybı değil, **bağ/geçmiş kaybı**.

## Önerilen düzeltme (uygulamadan — owner emrine tabi)

1. **Veri düzeltimi (tek satırlık, öncelikli):** `a67cd118` (51) satırına
   `anne_id='bac3b8f8-43c3-4cf5-83ed-6e1073c16fec'` yaz (dogum kaydı 577a2ecb bunu
   zaten doğruluyor). Aynı işte 195'in tohumlama `d10537ba`'ya `buzagi_kupe='51'` +
   `dogum_tarihi='2025-11-17'` damgası (RPC'nin normalde yazdığı alanlar).
2. **Hayalet 31 bağının ayrıştırılması:** `982fbd16` (31, doğum 2025-08-09) → 195 bağı
   biyolojik olarak tutarsız (51 ile 3 ay arayla iki doğum imkânsız). 31'in gerçek annesi
   biliniyorsa yazılmalı; bilinmiyorsa `anne_id=NULL` yapıp dogum-olmayan doğumları
   (195: yalnız 1 dogum satırı var, o da 51) veri-kalitesi listesine eklemeli — P1'in
   bilinen "kupe31 maternal blocker" bulgusuyla aynı aile.
3. **Aşı geçmişi review'ı:** `vaccination_log`'da `animal_id=982fbd16` olan 4 kayıt
   (2026-06-01 07:25) backfill'in 51'e yazdığı aşı kayıtları; 31'e mi 51'e mi ait olduğu
   owner'la teyit edilip gerekirse `animal_id` toplu düzeltilmeli.
4. **Yapısal (ayrı iş olarak):**
   - İçe aktarma/backfill araçlarına **mevcut-kupe dedup'ı** ve "varsa anne_id'yi
     güncelle" yolu (bugünkü boşluk: `dogum_kaydet` guard'ı direkt INSERT'te hiç çalışmıyor).
   - `hayvanlar` için **UPDATE/DELETE izleme** (islem_log şu an INSERT-only,
     `20260306000008:501`) — bu olay tam da bu kör noktada çözüldü; `hayvan_guncelle`
     tipi RPC'lere açık `islem_log` yazımı da yeterli olur.
   - Aktifler arasında **kupe_no unique partial index** değerlendirmesi. Ön-ölçüm:
     `SELECT kupe_no, count(*) FROM hayvanlar GROUP BY kupe_no HAVING count(*)>1` →
     **0 satır** (bugün duplikat yok) — ama 982fbd16 vakası iki canlı 51'in bir arada
     yaşayabildiğini gösterdi; şemada guard yok.
5. **Ölçülmedi / kalan:** 06-21 küpe-düzenlemesinin kim/nasıl yapıldığı (UI mu/yol mu)
   hiçbir izlemeden çıkarılamaz (islem_log kör noktası + `ui_logs`'ta 982fbd16 geçen
   0 kayıt). Yedeklerle geçmiş doğrulaması 90-gün retention nedeniyle imkânsız (S5).


## Teslim review notu (şerit kuralı #1)

Teslimden önce builtin subagent (salt-okuma) review koşuldu — 7 bulgu. Bulgu 1-3
(Özet'in "tek HAYVAN_EKLENDI" mutlaklığı, `d10537ba` kanıt eksikliği, Özet'teki niyet
atfı) ve 4-7 (bozuk cümle, grup/padok kanıtı, duplikat ön-ölçüm SQL'i, 313 dağılımı)
rapora işlendi. Kalan bilinen sınırlar "Ölçülmedi / kalan" bölümünde beyanlı.
