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

### BUG-TAILSCALE-DNS — Tailscale MagicDNS, Supabase proje alt alan adlarını negatif-cache'liyor [open]

**Tarih:** 2026-09-24 · **Bulgu yeri:** lokal geliştirme (http://localhost:8123)

**Belirti:** Demo projesi `vtzqjmazsvurxdeondmi.supabase.co` makineden
çözülemiyor (NXDOMAIN). Prod alt alanı çözülüyor. Tarayıcıda demo "bağlanamıyorum"
olarak görünüyordu; Chromium headless (DoH açık) sorunsuz bağlanıyordu — kod/sunucu sağlam.

**Kök neden:** Tailscale MagicDNS (`100.100.100.100`) systemd-resolved upstream'i;
başarısız bir çözümleme NXDOMAIN olarak cache'leniyor.

**Geçici çözüm (doğrulandı):** `resolvectl flush-caches`. Tarayıcıda "Güvenli DNS
kullan" (DoH) açık profil etkilenmez.

**Kalıcı çözüm adayları:** Tailscale DNS override kapat / upstream bypass /
per-link nameserver. Üretim (GitHub Pages) etkilenmez.

**Etki:** yalnızca lokal geliştirme/test kesintileri.

---

### BUG-SS-SHIM-FORKBOMB — `_realbin` shim'i ilk 1024 baytta tanıyamıyor → git/tmux shim kendini çağırıyor [open]

**Tarih:** 2026-09-25 · **Bulgu yeri:** mimar oturumu, `ss-lead-glm-high` tmux koltuğu açılışı · **Sahip:** tools-bank (`.superset/bin/`)
**İlgili:** 2026-09-21 S8 dersi (wake-tesisat fork bomb) — aynı ailenin tekrarı; konu defalarca araştırıldı.

**Belirti:** Codex'in başlattığı tmux sunucusunda (`tmux show-environment -g`'de `SS_*` yok) açılan koltuk
saniyeler içinde ölüyor; pane'de `bash: fork: Resource temporarily unavailable`. Pane scope'u
`tmux-spawn-<uuid>.scope` **3000/3000 pids** — 2999 × `bash …/.superset/bin/shim/git … config --get alias.config`.

**Kök neden [OBSERVED]:**
- `ss-role-common:188-206` `_realbin` bir adayı shim sayarken `head -c 1024 | grep SS_REAL_` kullanıyor.
- git shim'inde ilk `SS_REAL_` **1102. bayt**ta (K11-fix 303cde4d, 2026-09-22 başlığı uzattı); tmux shim'inde
  **2837. bayt**ta (aynı gizli bug); superset shim 918 (şimdilik içeride).
- `SS_REAL_GIT` boş ortamda `_realbin` shim'in kendisini "gerçek git" döndürür → `export SS_REAL_GIT=<shim>`
  → shim `real=$SS_REAL_GIT` ile kendini exec eder; alias çözümü (`shim/git:122`, `"$real" config --get alias.config`)
  sonsuz özyineleme.
- Ortamında `SS_REAL_GIT=/usr/bin/git` zaten olan oturumlar (ör. root claude) etkilenmez → hata ortam-bağımlı, gizli kalır.

**Geçici çözüm (uygulandı):** koltuğu `tmux new … -e SS_REAL_GIT=/usr/bin/git -e SS_REAL_TMUX=/usr/bin/tmux
-e SS_REAL_SUPERSET=/home/melik/.superset/bin/superset` ile açmak. Temizlik: `tmux kill-session` + sahipsiz kalan
süreçler için yalnız o pane scope'u `systemctl --user stop tmux-spawn-<uuid>.scope` (pkill/kill -9 değil).

**Kalıcı düzeltme yönü (shim'e dokunma kuralı K2 — sahip kararı):** tanıma bayt-penceresine bağlı olmamalı —
ör. her shim'in 2. satırına sabit işaret (`# SS_SHIM_MARKER`) ve `_realbin` bunu `head -n 3` ile arasın; ya da
aday `realpath`'i `…/.superset/bin/shim/` altındaysa ele. Ek savunma: shim `real` kendi `realpath`'ine eşitse
`exit 127` (fail-closed) — özyineleme tek adımda kesilir.

---

## Sahip P5 demo testi — 2026-09-25 (test/p5-demo 09d018d = cila 1abf3ee + erteleme E0)

Kaynak: sahibin `http://127.0.0.1:8090/index.html?demo` yürüyüşü. Kalemler cila dalında AÇIK;
"kalıcı kod fix'i" ile "mevcut veri temizliği" ayrı kalem olarak ele alınmalı.

### BUG-UREME-FILTRE-SIZINTI — Görevler › Üreme filtresine alakasız görevler giriyor [open]
**Belirti:** Üreme filtresinde saat grubu altında Ovsync seansı + Şablon TAI ile birlikte **008 · Metrit ·
Sefanel** tedavi seansı listeleniyor. Ovsync'li hastanın alakasız görevleri de geliyor ya da iki görev üst
üste çakışıyor. Buna karşılık **tohumlama ve ovsync görevlerinin çoğu Üreme'de GÖRÜNMÜYOR** (yalnız 1 tane).
**İlgili:** K7 (37e4069, `tests/unit/gorev-kat-filtre.test.js` PASS ama canlı davranış tutmuyor) — birim testin
fixture'ı gerçek veri şeklini temsil etmiyor olabilir. **Kabul:** demo'da Üreme = yalnız üreme görev tipleri
(TOHUMLAMA_PLANLI, OVSYNC_BASLAT, ovsync vakasının TEDAVI_GUN/SEANS'ı, muayene…); tedavi vakası seansı yok;
tüm açık üreme görevleri görünür (sayı SQL ile eşit).

### BUG-KISIR-BADGE-KART — Hayvan kartında 💲 Kısır rozeti görünmüyor [open]
**Belirti:** Liste satırında "💲 Kısır" var, hayvan detay kartında yok. **Kabul:** `kisir=true` hayvanın kartında rozet.

### BUG-KISIR-OVSYNC-HARDBLOCK — Kısır hayvanda ovsync açılışı her yoldan engellenmeli (DB + UI) [open]
**Sahip talimatı (tekrar):** "kısır hayvanda zaten ovsync açılması hem db hem frontend katmanlarında
hardblocklanmalı — söyledim ama yapılmamış". Cila K3/U2 yalnız OVSYNC_BASLAT üretimi + Başlat butonunu
kapattı. **Kapsam:** vaka açma/şablon uygulama (Ovsync şablonu elle seçilirse), `start_first_service_protocol`,
cron, toplu açma — DB'de tek noktada `RAISE` (fail-closed), UI'da seçenek gizli/kilitli.
**Veri olayı (prod, 2026-09-25):** 184/199/208 kısır hayvanlarda 24.09'da ovsync başlamıştı → mimar P1 ile
`_vaka_kapat(ERKEN_KAPANIS)` kapattı. **Kabul:** demo'da kısır hayvana ovsync vakası açma denemesi her yoldan
hata; UI'da seçenek yok.

### BUG-OVSYNC-SEANS-PANEL-GORUNUM — K8 ovsync seansları ana listeye monte edildi, sahip istemedi [open]
**Belirti:** Sabahki (öncesi) görünüm daha iyiydi; yeni hâlde liste üstte ama dikkat çekmiyor, ana listeye
gömülmüş. **Sahip:** "ben böyle bir şey istemedim". **Kabul:** sahiple görünüm kararı (önceki ayrı panel
geri mi, belirgin ayrı bölüm mü) → uygulama.

### DATA-906-GEBE-KAYDI-YOK — 906 sekiz aylık gebe ama sistemde hiç tohumlama kaydı yok [open]
**Durum (prod, 2026-09-25):** `durum=Aktif, kisir=false, tohumlama kaydı yok, açık görev yok`. Açık dişi
sayılıp cron'dan OVSYNC_BASLAT alabilir. **Aksiyon:** gebelik kaydı (tohumlama sonucu Gebe, ~8 ay önce) girilmeli.
