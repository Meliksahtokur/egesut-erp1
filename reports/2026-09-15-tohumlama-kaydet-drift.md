# P3 — `tohumlama_kaydet` demo drift incelemesi (SALT OKUNUR)

Tarih: 2026-09-15 · Worker: glmf (`agent/tohumlama-drift` worktree) · Görev zarfı: `.ss/tasks/P3-tohumlama-kaydet-drift.md`

## 0. Sonuç (tek paragraf)

**Demo drift YOK.** Demo'daki `public.tohumlama_kaydet` ve `public.tohumlama_tekrar_kaydet`
gövdeleri, branch'teki `20260910000002_sperma_eslesme_sertlestirme.sql` (#5) dosyasının
bugünkü committed içeriğiyle **birebir aynı** (boşluk-normalize satır diff = 0/0).
P1 raporu §4.2'deki "demo'daki sürüm 36 dosyanın ve tüm migration geçmişinin hiçbir
sürümüyle eşleşmiyor (md5 e4ab00a63d)" uyarısı **yanlış alarmdır**: `e4ab00a63d`
zaten #5 dosyasının kendi md5'idir; P1'in teşhis aracı DO-blok içindeki `tohumlama_kaydet`
CREATE'ini ayrıştıramadığı için (bkz. §4) bu eşleşmeyi göremedi. Sahibin endişesi
("#5 prod'a uygulanırsa prod, demo'da test edilenden farklı sürüme geçer") **tersine
dönmüştür**: #5 uygulanırsa prod, demo'da 2026-09-10'da test edilmiş sürümün **birebir
aynısına** geçer. Öneri **A**dır (§6).

## 1. Yöntem ve yasaklara uyum

- Canlı gövdeler: Mgmt API `/database/query`, her istek `BEGIN READ ONLY; SELECT ...; ROLLBACK;`
  (P1 `probe.py` deseni) — `probe_fn.py`. Prod'a ve demo'ya **yazma yok**; token değerleri
  hiçbir çıktıya yazılmadı. Migration dosyaları **değiştirilmedi**.
- md5 iki varyantla raporlanır: `md5_all` = md5(boşluk-sil + küçük-harf) — P1 `diagnose.py`
  varyantı (P1 raporundaki e4ab00a63d/e144cf1f71 bu varyanttır); `md5_ws` =
  md5(boşluk-tekle) — P1 `verdict.py` varyantı. Satır diff'leri satır-içi boşluklar
  teklenecek şekilde üretildi.
- Çıkarım, P1'in statement bölücüsü kullanılmadan CREATE FUNCTION başlığına demirlenmiş
  dollar-quote (`$function$`) span aramasıyla yapıldı; P1 aracındaki arıza §4'te ayrıca
  belgelendi.

## 2. md5 tablosu (kanıt)

| Fonksiyon | Kaynak | md5_all | md5_ws | karakter |
|---|---|---|---|---|
| tohumlama_kaydet | **(a)** `20260910000002` (#5 dosyası) | `e4ab00a63d` | `57c69264f4` | 7295 |
| tohumlama_kaydet | **(b)** `20260830000034` | `e144cf1f71` | `6982b7f7e4` | 7295 |
| tohumlama_kaydet | **(c)** demo canlı | **`e4ab00a63d`** = (a) | `57c69264f4` | 7295 |
| tohumlama_kaydet | **(d)** prod canlı | `e144cf1f71` = (b) | `6982b7f7e4` | 7295 |
| tohumlama_tekrar_kaydet | (a) `20260910000002` | `83fe917252` | `811a0b35c0` | 2107 |
| tohumlama_tekrar_kaydet | (c′) `20260722000004` (prod'un mevcut kaynağı) | `64dc7fc09a` | `f7b2d72ed7` | 2148 |
| tohumlama_tekrar_kaydet | demo canlı | **`83fe917252`** = (a) | `811a0b35c0` | 2107 |
| tohumlama_tekrar_kaydet | prod canlı | `64dc7fc09a` = (c′) | `f7b2d72ed7` | 2148 |

- Her iki fonksiyonun da **tek overload'ı** var (pg_proc taraması; demo ve prod'da aynı).
- `secdef = true`, `volatile`, dönen tip `jsonb` — iki ortamda aynı imza.

## 3. Diff özeti (satır diff, boşluk normalize — `diffs/` altında ham hâli)

| Karşılaştırma | fonksiyon | değişen satır | yorum |
|---|---|---|---|
| demo canlı ↔ (a) #5 dosyası | kaydet | **0** | demo = dosya, birebir |
| demo canlı ↔ (a) #5 dosyası | tekrar | **0** | demo = dosya, birebir |
| prod canlı ↔ (a) #5 dosyası | kaydet | 14 | #5'in prod'a uygulayacağı tek blok: stok düşümü (§5) |
| prod canlı ↔ (a) #5 dosyası | tekrar | 13 | aynı tek blok |
| prod canlı ↔ (c′) `20260722000004` | tekrar | 0 | prod tekrar = kaynağındaki tanım, drift yok |
| demo canlı ↔ prod canlı | kaydet / tekrar | 11 / 11 | aradaki tüm fark = aynı stok bloğu |
| (b) `20260830000034` ↔ (a) #5 | kaydet | 14 | a, b'nin üst revizyonu; fark aynı blok |

Yani: **demo, #5'in uygulandığı güncel dal durumu; prod, #5 öncesi durum.** İkisi de
kaynak dosyalarıyla birebir örtüşüyor — iki ortamda da *açıklanamayan* gövde yok.

## 4. P1 yanlış alarmının kök nedeni (araç hatası)

P1 `diagnose.py`'nin `ALL_VERSIONS` kayıt defteri canlıya sorulduğunda:

- `tohumlama_kaydet(text,date,text,text,text,jsonb,boolean)` için **8 sürüm kayıtlı,
  hiçbiri `20260910000002` değil** → canlı `e4ab00a63d` hiçbiriyle eşleşmedi → "MISMATCH".
- Buna karşılık aynı dosyadan **6 tipli artık bir kayıt düşmüş**
  (`(text,date,text,text,text,jsonb)`, n=1) — DO-blok içi ayrıştırıcı kaydet
  CREATE'ini **argüman listesinin ortasından** bölmüş.
- `tohumlama_tekrar_kaydet` aynı DO-blokta olmasına rağmen **doğru kaydedilmiş**
  (4 sürüm, `20260910000002:83fe917252` dahil) — bu yüzden P1 sadece kaydet'i
  "hiçbir sürümle eşleşmiyor" sanmış.

Kök neden: `parse_migrations.statements()`'in `$do$` bloğu içine indikten sonra
kullandığı statement bölme mantığı, iç içe `$function$` gövdeleri olan ilk CREATE'i
bütün olarak tanımıyor. (P1 aracına yapılacak fix bu görevin kapsamı dışındadır —
buraya not olarak işlendi.)

P1 raporunda bu yanlış alarmdan etkilenen hücreler: §3 tablosunda `20260910000002`
satırının demo kolonu (KISMİ → **CANLI** olmalı), §4.2 ilk madde ve "Karar noktası"
uyarısı, §5'teki 6. madde. Ayrıca `20260830000034` ve `20260830000010`'un demo-KISMİ
etiketleri "drift" değil **üst sürümle değiştirilme** durumudur (demo'daki kaydet, o
dosyalardaki tanımların yerine #5 ile geçti; beklendik zincir davranışı).

## 5. Demo'daki sürümün kaynağı (teşhis) ve davranış farkı

### 5.1 Köken

- `supabase_migrations.schema_migrations` dağıtım izi taşımıyor: demo'da yalnız 2 kayıt
  (max `20260706052550`), prod'da 124 kayıt (max `20260531400000`) — migrasyonlar bu
  projede elle (psql) uygulanıyor (`schema_migrations_demo.json` / `_prod.json`).
- Elle uygulama izi: `.claude/idle-reports/2026-09-10-ureme-bugfix.md`
  - satır 85-86: *"Kalıcı uygulanan (owner kuralı gereği serbest): **M1 (W1), M2 (lead),
    M3 (W3)** — şema değişikliği, test verisi değil."* (M2 = #5 dosyası)
  - satır 124-129 (W2b): *"Demo zinciri: M1b uygula → M2 uygula → M1b REPLAY →
    `fn_sperma_stok_dus` pg_proc sayısı = 1"*, *"İki fixture demo'da exit 0"*
  - satır 140-142: *"`M2c.dryrun.log` exit 0. Düzeltme sonrası demo yeniden uygulandı +
    fixture yeniden koşuldu (exit 0)."*
- Git arkeolojisi (`revizyonlar.json`): #5'in **tüm committed revizyonları** —
  `47c1ecd` (ilk, 2026-09-10) → `9659770` (W2b) → `96ada82` (final) → HEAD — kaydet'i
  hep `e4ab00a63d`, tekrar'ı hep `83fe917252` taşımıştır.
- **Sonuç:** Demo'daki sürüm dosyadan ne yeni, ne eski, ne ayrı bir dal — **dosyanın
  bugünkü committed içeriğinin kendisidir**; 2026-09-10'da G-20260910-UREME-STOK-BUGFIX
  işi sırasında lead tarafından test amacıyla demo'ya psql ile uygulandı (sahibin
  "demo'da migration uygulanabilir" ayakta kuralı). BUGS.md'deki durum notu da bunu
  doğrular: "BUG-002/003 **fixed-pending-deploy**" — yani prod deploy'u bekliyor.

### 5.2 Davranış farkı (insan dili) — #5 prod'a uygulanınca ne değişir?

İki fonksiyon arasındaki **tek** fark, stok düşümü bloğudur (diff 14/13 satırın tamamı
bu blok; VWP kuralları, hata mesajları, gebelik görevleri, otomatik boş — birebir aynı):

| Girdi / durum | Prod bugün (b / c′ sürümleri) | #5 sonrası (= demo) |
|---|---|---|
| `p_sperma` boş / whitespace / NULL | `ILIKE '%%'` her Sperma satırını eşler, `LIMIT 1` sırasız → **rastgele bir Sperma stoğundan 1 düşer** (BUG-002'nin kendisi) | helper boş adı **hiç düşürmez** |
| `p_sperma` gerçek ad | substring `ILIKE`, `ORDER BY` yok → eşleşen ilk fiziksel satır belirsiz; exact önceliği yok | **exact önce**, yoksa substring `ILIKE`; `kategori='Sperma'` filtresi helper'da tek yerde |
| Eşleşen stok yok | sessizce geçer (`INSERT...SELECT` 0 satır) | sessizce geçer (değişiklik yok) |
| Stok 0'ın altına iner | izinli | **izinli kalır** (emsal `20260902000002` davranışı korunur) |
| `stok_hareket.notlar` metni | aynen üretilir (kupe_no / deneme sayısı) | **birebir korunur** — sadece üretim yeri helper parametresi olur |
| `planli_tohumlama_kaydet` | kaydet'i içten çağırır | aynı kuralı **miras alır** (üçüncü yol da tek eşleşme kuralına bağlanır) |

## 6. Öneri: **A** — dosya sürümü doğru; #5 prod'a olduğu gibi uygulanır

Gerekçe:

1. Demo'daki sürüm bir hotfix değil, committed dosyanın kendisi → **B gereksiz**
   (yeni migration dosyasına gerek yok); "ikisi de eksik" de değil → **C gereksiz**.
2. Sahibin korktuğu senaryo —"#5 uygulanırsa prod, demo'da test edilenden farklı
   sürüme geçer"— kanıtlarla **gerçekleşmiyor**: uygulanınca prod, demo'da 2026-09-10
   kabul koşularından (K1-K6 fixture exit 0, root-gate F1-F5 ACL probu) geçmiş sürümün
   birebir aynıına kavuşuyor.
3. Dosyanın kendi içindeki tasarım kararları (DROP yok, tek DO bloğunda atomik,
   session-artığı yok) W2b review turunda (B2-B8) zaten sertleştirilmiş.

**Ön koşullar (P1 §3/§6 ile uyumlu):**

- **M1 (`20260910000001`) #5'ten ÖNCE uygulanmalı:** `fn_sperma_stok_dus` prod'da
  **yok** (P1 §3 satır 4). M1'siz #5, ilk `tohumlama_kaydet`/`tohumlama_tekrar_kaydet`
  çağrısında `42883 (undefined function)` üretir. P1 §3 sırası (M1=4., #5=5.) korunmalı.
- P1 §6'daki ön yedek planı (PITR kapalı — `pitr_enabled: false`, listelenebilir yedek
  yok) aynen geçerlidir; migration öncesi `pg_dump` zorunlu.
- P1 raporunun §3/§4.2/§5'indeki demo-KISMİ hücreleri bir sonraki rapor revizyonunda
  düzeltilmeli; `parse_migrations.statements()`'in DO-blok ayrıştırma arızası
  düzeltilmeli (P1 aracı bakımı — ayrı iş).

## 7. Kanıt dosyaları (`reports/2026-09-15-tohumlama-kaydet-drift/`)

- `probe_fn.py`, `probe_fn_queries.sql`, `probe_fn_demo.json`, `probe_fn_prod.json` —
  canlı gövde sondajı (BEGIN READ ONLY kanıtıyla)
- `schema_migrations_demo.json`, `schema_migrations_prod.json`,
  `schema_migrations_odzet.json` — migration kayıt tablosu sorguları (sayım özeti:
  demo n=2 max 20260706052550; prod n=124 max 20260531400000)
- `compare.py`, `md5_table.json`, `diff_summary.json` — 4 kaynak + md5'ler + diff üretimi
- `diffs/*.diff` — 8 ham diff (demo↔dosya=0 olan eşitlik kanıtları dahil)
- `rev_md5.py`, `revizyonlar.json` — #5'in 4 committed revizyonundaki gövde md5'leri
