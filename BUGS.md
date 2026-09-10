# BUGS.md — Bilinen hata ve smell kayıtları

Kaynak: 2026-09-10 pedigree doküman review (dump HEAD `a3d8bc2`) + canlı PROD
salt-okunur imza/gövde ölçümü (root). Canlı şema otoritedir; tracked ground
truth rehberdir (bkz. SMELL-003). Canlı ölçüm kanıtları:
`.claude/reviews/2026-09-10-live-probe-evidence.md` (sorgular + ham çıktılar).

Durum değerleri: `open` → `fixed-pending-deploy` (migration hazır, PROD'da
değil) → `verified` (canlıda ölçüldü).

---

## Bugs

### BUG-001 — `planli_tohumlama_kaydet` sperma stok düşümü yapmıyor [HIGH] [open]

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

### BUG-002 — sperma stok düşümü string eşleşmesi kırılgan [MEDIUM-HIGH] [open]

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

### BUG-003 — `gebelik_kaydet_manual` canlıda 42804 ile kırık [HIGH] [open]

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

**Durum (2026-09-10, Revizyon 2): KARŞILANDI** — DOC-001..006, repo içindeki
revize kopyalara işlendi (`.claude/specs/2026-09-10-pedigree-genetics-architecture.md`,
`.claude/plans/2026-09-10-pedigree-genetics-impl.md`). Kalıntılar: DOC-005
kapsam nüansı ve DOC-006'nın tracked-kapı eksiği aşağıda notludur; luna max
review turu (r1 FAIL → r2) bulgularıyla birlikte kapatıldı.

DOC-001: ~~`tohumlama.id` beklentisi düzeltilmeli~~ → **İŞLENDİ**: plan Task 0.2
artık beklenti yazmaz, canlıdan okur; bugünkü bilinen değer (text) kayıtlı.

DOC-002: ~~stok düşümü okuması hizalanmalı~~ → **İŞLENDİ**: spec §6.3 + plan
D4/Task 10 "düzeltilmiş kuralı semen_catalog.stock_id'ye taşı" olarak yazıldı.
*(r2 düzeltmesi: offline "kuyrukta zaten queueable" iddiası yanlıştı — formlar
offline'da kuyruğa girmeden reddediyor; v1 *_semen online-only, RPC_MAP'e
ekleme YOK.)*

DOC-003: ~~yüzey envanteri genişletilmeli~~ → **İŞLENDİ**: plan Task 11 üç
kaynağı (config/datalist/stok-select) + `geb-sperma`'yı kapsıyor; geb formunda
semen seçimi opsiyonel (mevcut davranış).

DOC-004: ~~RPC_MAP'e eklenmeli~~ → **DÜZELTİLDİ (tersine)**: ölçüm (r2) formların
offline'da kuyruk oluşturmadığını gösterdi; ekleme yapılmaz, v1 semen-aware
yollar online-only; RPC_TABLES↔RPC_MAP tutarlılık testi izleme aracı olarak kalır.

DOC-005: farm_id kolonlu ürün tablosu repoda henüz **sıfır** (`demo/02_demo_klonla.sql`'deki
demo-yardımcı `demo_klon_log` hariç — kapsam: canlı üretim şeması); pedigree
tabloları ilk uygulayıcı olacak. Plan "mevcut geçiş politikası" değil "contract
kuralının ilk uygulaması" demeli; farm_id ile başlayan index checklist maddesi.
→ *Karşılandı (plan Task 27) + kapsam nüansı eklendi.*

DOC-006: SQL test koşum ortamı plana bağlanmalı: `psql "$DATABASE_URL"`
(tests/sql deseni, tracked). Dikkat: `scripts/db-dry-run.sh` **tracked değil**
(owner-local; sabit `/tmp` log yazar) — P1 tooling maddesiyle tracked + TMPDIR
uyumlu hale getirilene kadar migration kabulü psql fixture'larıyladır.
CI otomasyonu kapsam dışı (repo test stratejisi: lokal yeter).
→ *Kısmen karşılandı (plan Task 27); tracked kapı P1 borcu.*

---

*Goal kaydı: `.harness/goals/2026/G-20260910-UREME-STOK-BUGFIX.md`
(BUG-001..003 fix zarfı; lead GLM + worker GLMF kolunda).*
