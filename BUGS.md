# BUGS.md — Bilinen hata ve smell kayıtları

Kaynak: 2026-09-10 pedigree doküman review (dump HEAD `a3d8bc2`) + canlı PROD
salt-okunur imza/gövde ölçümü (root). Canlı şema otoritedir; tracked ground
truth rehberdir (bkz. SMELL-003). Canlı ölçüm kanıtları:
`.claude/reviews/2026-09-10-live-probe-evidence.md` (sorgular + ham çıktılar).

Durum değerleri: `open` → `fixed-pending-deploy` (migration hazır, PROD'da
değil) → `verified` (canlıda ölçüldü).

---

## Bugs

### BUG-001 — `planli_tohumlama_kaydet` sperma stok düşümü yapmıyor [REFUTED — yanlış alarm]

- **Düzeltme (2026-09-10, üç bağımsız kanıt):** ilk teşhis kötüldü. (1) Canlı
  `planli_tohumlama_kaydet` gövdesi koşulsuz `tohumlama_kaydet`'e delege eder —
  düşüm delegasyonla gerçekleşir (G-UREME-STOK-BUGFIX teslimi: davranışsal
  probe, planli çağrısı 1 stok_hareket satırı üretti); (2) tracked
  `20260730000001:477-496` delegasyon satırını içerir; (3) ilk canlı
  lexical probu (gövdede `stok_hareket` aramak) delegasyonu göremedi —
  ölçüm sınırlamasıydı (kanıt S1 düzeltme notu).
- **Sonuç:** planli yoluna ayrı düşüm EKLENMEZ (çift düşüm olur); sertleşmiş
  kuralı (BUG-002 fix'i) delegasyonla miras alır.

### BUG-002 — sperma stok düşümü string eşleşmesi kırılgan [MEDIUM-HIGH] [fixed-pending-deploy — idle/ureme-stok-bugfix dalında, merge/deploy bekliyor]

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

### BUG-003 — `gebelik_kaydet_manual` canlıda 42804 ile kırık [HIGH] [fixed-pending-deploy — idle/ureme-stok-bugfix dalında (3 noktalık uuid fix + kırmızı-önce kanıt), merge/deploy bekliyor]

- **Kanıt:** canlı imza `(p_hayvan_id text, p_tarih date, p_sperma text)`; PROD
  çağrıda SQL 42804 (text id → uuid kolon uyuşmazlığı, gövde içi). 🤰 Gebelik
  Ekle modalı canlıda kullanılamıyor. Bilinen workaround: tohumlama +
  islem_log doğrudan INSERT.
- **Fix yönü:** gövdedeki text→uuid uyuşmazlığı düzeltilir; demo DB'de
  kırmızı-önce (reproduce) → fix → yeşil. PROD deploy ayrı kapıdır (owner).

### BUG-004 — `gebelik_protokol_kontrol` Rota 1. doz görevini `etken_kod`'suz yazıyor [MEDIUM-HIGH] [data-fix uygulandı (907 vakası, 2026-09-11); durable migration owner kapısında]

- **Kanıt (canlı gövde, 2026-09-11 root pg_get_functiondef):** ILERI_GEBE_ASI
  '💉 Rota-Corona Aşısı (1. doz)' INSERT'i kolon listesinde `etken_kod` yok;
  2. doz (düve) kolonunda `'ROTA_2DOZ'` var. Kapanış tetikleyicisi
  `_gorev_dinle` `etken_kod = p_etken_kod` eşitliğiyle eşleşir → damgasız
  görev hiçbir hızlı uygulama/uygulama_log yoluyla kapanamaz. Ademin/E Vit
  INSERT'leri de damgasız.
- **Belirti (907 vakası, 2026-09-11):** görev kapandı SANILDI ama açık kaldı
  (Görevler + protokol uyarısı sinyal verdi); hızlı uygulama çift-tıkla 2 kez
  yazıldı (15 sn arayla; RPC+UI dedup yoktu). Teşhis:
  `.claude/idle-reports/2026-09-11-rota-907-tezhis.md`.
- **Uygulanan PROD veri düzeltimi (root, owner talimatı, 2026-09-11):** Seçenek
  A — 2× `hizli_uygulama_geri_al` (çift giriş geri alındı, stok iade +10) +
  `ileri_gebe_asi_tamamla` (görev id ile kapatıldı, vaccination_log'a kanonik
  5 ml IM kayıt + stok −5; rapel yok — inek). Sonuç: tek kayıt, stok 2→7,
  scanner 907 uyarısı bitti. UI çift-gönderim guard'ı main'de (3 handler + 6
  test).
- **Durable fix (BEKLİYOR — owner):** üretici INSERT'lere `etken_kod`
  ('ROTA'/'ADEMIN'/'E_VIT') + damgasız açık görevlere backfill (şablon teşhis
  raporu §5). RPC-side hızlı uygulama dedup ayrı tasarım kararı.

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

### SMELL-003 — Ground truth ↔ canlı ayrışmaları (2 örnek)

Örnek 1: tracked GT'de `tohumlama_kaydet` tanımı (satır 10858–10924, 66 satır)
stok düşümü **içermiyor**; canlıda **var** (gorev_log + stok düşümü + ek
uygulama döngüsü). Örnek 2 (2026-09-10 kanıt S4): GT `tohumlama.id`'yi text
gösteriyor (GT:116), canlı **uuid**; `created_at` GT tablo tanımında yok,
canlıda mevcut. GT rehberdir, canlı otoritedir; bugfix + pedigree
deploy'larından sonra GT yeniden üretilmelidir (root kapısı).

### SMELL-004 — `tests/sql` koşumu manuel

Tek örnek (`hayvan_grup_padok_sync_test.sql`), `psql "$DATABASE_URL"` ile elle
koşuluyor; otomatik kapı yok. Kabul için süreç disiplinine beleniyor —
otomasyon kararı ayrı iş.

---

## Pedigree doküman düzeltmeleri (İndirilenler'deki spec/plana yansıtılacak)

**Durum (2026-09-10, Revizyon 2 + review turları): KARŞILANDI** — DOC-001..006
repo içindeki revize kopyalara işlendi; luna max turları (r1-r4) bulgularıyla
iteratif kapatıldı. Tek zamanlanmış teslim: DOC-006'nın tracked dry-run kapısı
**Task 1.7'de P1 ile teslim edilir** (plan maddesi olarak taahhüt edildi —
açık eksiklik değil, planlı iş).

DOC-001: ~~`tohumlama.id` beklentisi düzeltilmeli~~ → **İŞLENDİ + canlı düzeltmesi**:
plan Task 0.2 beklenti yazmaz, canlıdan okur. Canlı ölçüm (kanıt S4):
`tohumlama.id` **uuid**, `created_at` timestamptz mevcut — GT'nin text/eksik
gösterimi drift örneği #2'dir (SMELL-003).

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
→ *İŞLENDİ — tracked kapı plan maddesi Task 1.7 olarak P1 ile teslim edilir
(zamanlanmış iş; açık eksiklik değil).*

---

*Goal kaydı: `.harness/goals/2026/G-20260910-UREME-STOK-BUGFIX.md`
(BUG-001..003 fix zarfı; lead GLM + worker GLMF kolunda).*
