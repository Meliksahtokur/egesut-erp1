# BUGS.md — Bilinen hata ve smell kayıtları

Kaynak: 2026-09-10 pedigree doküman review (dump HEAD `a3d8bc2`) + canlı PROD
salt-okunur imza/gövde ölçümü (root). Canlı şema otoritedir; tracked ground
truth rehberdir (bkz. SMELL-003).

Durum değerleri: `open` → `fixed-pending-deploy` (migration hazır, PROD'da
değil) → `verified` (canlıda ölçüldü).

---

## Bugs

### BUG-001 — `planli_tohumlama_kaydet` sperma stok düşümü yapmıyor [HIGH] [refuted — yanlış alarm, 2026-09-10]

- **Düzeltme kaydı (lead + W1, çift bağımsız kanıt):** canlı gövde koşulsuz
  `public.tohumlama_kaydet(...)`'e delege ediyor — düşüm delegasyonla
  gerçekleşiyor. İlk leksik ölçüm ("gövdede stok_hareket geçmiyor")
  delegasyonu göremedi. Kanıt: demo davranışsal probe (planli çağrı → 1
  `stok_hareket` satırı) + canlı gövde satırı. Fix gerekmez; çift düşümü
  önlemek için planli'ye düşüm EKLENMEDİ — sertleşmiş kuralı delegasyonla
  miras alır (M2, `20260910000002`). Rapor:
  `.claude/idle-reports/2026-09-10-ureme-bugfix.md`.

- **Kanıt (canlı, 2026-09-10):** `pg_get_functiondef` gövdesinde `stok_hareket`
  geçmiyor. Aynı ölçümde `tohumlama_kaydet` ve `tohumlama_tekrar_kaydet`
  düşürüyor. Canlı imzalar:
  - `tohumlama_kaydet(p_hayvan_id text, p_tarih date, p_sperma text, p_hekim_id text, p_irk_bilgisi text, p_ek_uygulamalar jsonb, p_vwp_override boolean)` — düşüyor
  - `tohumlama_tekrar_kaydet(text, date, text, text, text)` — düşüyor
  - `planli_tohumlama_kaydet(p_gorev_id uuid, ...)` — **düşmüyor**
- **Etki:** planlı tohumlama yoluyla yapılan aşımınlarda sperma stoğu düşmez;
  stok fiili miktarla sessizce ayrışır.
- **Fix yönü:** planli yoluna, diğer iki yolun (BUG-002 ile düzeltilmiş)
  eşleşme/düşüm kuralını uygula; üç yol tek kuralı kullansın.

### BUG-002 — sperma stok düşümü string eşleşmesi kırılgan [MEDIUM-HIGH] [fixed-pending-deploy]

- **Fix:** `20260910000002_sperma_eslesme_sertlestirme.sql` (helper
  `fn_sperma_stok_dus` M1'de final biçimiyle, boş/whitespace ad hiç düşürmez
  `^\s*$`, exact önce, substring fallback, kategori='Sperma', notlar içeriği
  canlıyla birebir; üç yol tek kural — planli delegasyonla). Testler:
  `tests/sql/sperma_stok_dus_test.sql` + `tests/sql/sperma_eslesme_test.sql`.
  Bağımsız review düzeltmeleri (B2..B8) işlendi. Rapor:
  `.claude/idle-reports/2026-09-10-ureme-bugfix.md`.

- **Kanıt (canlı):** `tohumlama_kaydet` ve `tohumlama_tekrar_kaydet`
  gövdelerinde:

  ```sql
  INSERT INTO public.stok_hareket (...)
  SELECT s.id, 'Tohumlama', 1, ... FROM public.stok s
  WHERE (s.urun_adi ILIKE '%' || p_sperma || '%' OR s.urun_adi = p_sperma)
    AND s.kategori = 'Sperma'
  LIMIT 1;
  ```

- **Belirtiler:**
  1. `p_sperma` boş string → `ILIKE '%%'` → **rastgele** bir Sperma satırından
     1 doz düşer (yanlış düşüm).
  2. Substring çapraz eşleşme: `Armada` gibi kısa ad, `... Armada ...` geçen
     başka ürüne de takılabilir.
  3. Eşleşme yoksa sessiz skip — stok düşmez, hiçbir uyarı/iz yok.
- **Fix yönü:** boş/whitespace sperma hiç düşürmez; exact `urun_adi` eşleşmesi
  substring'ten önce tercih edilir; kural üç yolda ortak tek implementasyonda
  yaşar. Stok eksiye düşebilir (serbest düşürme politikası, emsal
  `20260902000002`).

### BUG-003 — `gebelik_kaydet_manual` canlıda 42804 ile kırık [HIGH] [fixed-pending-deploy]

- **Fix:** `20260910000003_gebelik_kaydet_manual_42804_fix.sql` — gövdede
  `v_tohumlama_id text` ↔ `tohumlama.id uuid` uyuşmazlığı; 3 noktalık minimal
  tür düzeltmesi (canlı gövde ölçümüne dayalı). Red-first leadce bağımsız
  yeniden üretildi (SQLSTATE 42804). Test:
  `tests/sql/gebelik_kaydet_manual_test.sql`. Rapor:
  `.claude/idle-reports/2026-09-10-ureme-bugfix.md`.

- **Kanıt:** canlı imza `(p_hayvan_id text, p_tarih date, p_sperma text)`; PROD
  çağrıda SQL 42804 (text id → uuid kolon uyuşmazlığı, gövde içi). 🤰 Gebelik
  Ekle modalı canlıda kullanılamıyor. Bilinen workaround: tohumlama +
  islem_log doğrudan INSERT.
- **Fix yönü:** gövdedeki text→uuid uyuşmazlığı düzeltilir; demo DB'de
  kırmızı-önce (reproduce) → fix → yeşil. PROD deploy ayrı kapıdır (owner).

---

## Smells (kayıt altında — araştırma/karar bekliyor, fix şimdi değil)

### SMELL-001 — Sperma girişi üç kaynaklı, free-text kimlik hâlâ açık

`js/config.js` `SPERMA_LISTESI` sabiti + `js/app.js` `buildSpermaList`
(tohumlama geçmişinden datalist) + `js/ui.js` stok seçicileri
(`getSpermaStok` ~7436, `trSpermaModStok` 7452) + `geb-sperma` serbest alan.
Pedigree semen_catalog planı (Task 11) kapatana kadar yeni free-text kimlik
üretilebilir. Pedigree implementasyonundan önce ayrı karara gerek yok.

### SMELL-002 — `RPC_TABLES` ↔ offline `RPC_MAP` senkron değil

`js/api.js:293` `RPC_TABLES` ile `js/ui.js:8006` `RPC_MAP` ayrı yerlerde;
yeni RPC birine eklenip diğerine eklenmezse offline kuyruk sessizce legacy
yola düşer. Pedigree planı Task 10'da zorunlu madde olmalı; genel tutarlılık
testi (`api.test.js`) araştırılabilir.

### SMELL-003 — Ground truth ↔ canlı `tohumlama_kaydet` gövde ayrışması

Tracked GT (`99999999999999_ground_truth.sql`, tohumlama_kaydet tanımı
satır 10858–10924, 66 satır) gövdesinde stok düşümü **yok**; canlıda **var**
(gorev_log + stok düşümü + ek uygulama döngüsü içeren daha uzun gövde).
GT rehberdir, canlı otoritedir; bugfix deploy'undan sonra GT yeniden
üretilmelidir (root kapısı). Bugünkü pedrigree planı (Task 0.2) "yeni drift"
arıyor — mevcut drift örneği olarak bu kayıt referans alınmalı.

### SMELL-004 — `tests/sql` koşumu manuel

Tek örnek (`hayvan_grup_padok_sync_test.sql`), `psql "$DATABASE_URL"` ile elle
koşuluyor; otomatik kapı yok. Kabul için süreç disiplinine beleniyor —
otomasyon kararı ayrı iş.

---

## Pedigree doküman düzeltmeleri (İndirilenler'deki spec/plana yansıtılacak)

DOC-001: `tohumlama.id` **text** (GT:116), uuid değil — plan Task 0.2 beklenti
değeri düzeltilmeli (ya da beklenti yazılmayıp canlıdan okunmalı).

DOC-002: Stok düşümü okuması revize: canlıda `tohumlama_kaydet` **düşürüyor**
(ILIKE desenli), `planli_tohumlama_kaydet` düşürmüyor (BUG-001). Spec §6.3
"mevcut stok düşümü" ifadesi ve plan Task 10 madde 5, BUG-001/002
fix'leriyle hizalanmalı ("korumak" değil "düzeltipi semen_catalog.stock_id'ye
taşımak").

DOC-003: `buildSpermaList` (app.js:399) stok değil geçmiş+config datalist'i;
stok seçicileri ui.js'te. Plan Task 11 yüzey envanteri üç kaynağı +
`geb-sperma`'yı kapsamalı.

DOC-004: Offline replay `RPC_MAP`'e yeni `*_semen` RPC'leri eklenmelidir —
opsiyonel değil (tohumlama zaten kuyrukta).

DOC-005: farm_id kolonlu tablo repoda henüz **sıfır**; pedigree tabloları ilk
uygulayıcı olacak. Plan "mevcut geçiş politikası" değil "contract kuralının
ilk uygulaması" demeli; farm_id ile başlayan index checklist maddesi.

DOC-006: SQL test koşum ortamı plana bağlanmalı: `psql "$DATABASE_URL"`
(tests/sql deseni) + `scripts/db-dry-run.sh` (Neon ayna). Lokal Postgres yok;
CI otomasyonu kapsam dışı (repo test stratejisi: lokal yeter).

---

*Goal kaydı: `.harness/goals/2026/G-20260910-UREME-STOK-BUGFIX.md`
(BUG-001..003 fix zarfı; lead GLM + worker GLMF kolunda).*
