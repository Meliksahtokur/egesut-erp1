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

### DATA-906-GEBE-KAYDI-YOK — 906 sekiz aylık gebe ama sistemde hiç tohumlama kaydı yok [fixed 2026-09-25 — mimar, gebelik_kaydet_manual 2026-01-25 starred]
**Durum (prod, 2026-09-25):** `durum=Aktif, kisir=false, tohumlama kaydı yok, açık görev yok`. Açık dişi
sayılıp cron'dan OVSYNC_BASLAT alabilir. **Aksiyon:** gebelik kaydı (tohumlama sonucu Gebe, ~8 ay önce) girilmeli.

---

## Borçlar — sahip P5b demo testi, 2026-09-25 akşam (test/p5b-demo 3a77456)

Sahip kararı: bu gece yeni tur yok; aşağıdakiler borç. Her biri ayrı kalem, kabul ölçütü sahibin cümlesiyle.

### DEBT-PG-VWP-SESSIZ — PG VWP penceresine düşerse TAI oluşmuyor, bildirim yok [open]
`_pg_sonrasi_tohumlama` (erteleme DONE sahip kapısı #2): PG olayı VWP_ICINDE/UYGUNSUZ → TAI yok + bildirim yok (sessiz kırılma). **Kabul:** kullanıcıya görünür uyarı/bildirim.

### DEBT-TEDAVI-TAI-SENKRON — Tedavi uzayınca TAI kendiliğinden kaymıyor [open]
Erteleme DONE #3. Şu an elle erteleme gerekiyor. **Kabul:** tedavi günü eklenince/kaydırılınca bağlı TAI da kayar (ya da kullanıcıya sorulur).

### DEBT-BASLAT-IPTAL-INSTANCE — Başlatma görevi iptalinde protokol_instance açık kalıyor [open]
Erteleme DONE #5 (ön-var). **Kabul:** görev iptali instance'ı da kapatır.

### DEBT-ERTELE-SHEET-BOYUT — Erteleme penceresi geniş ekran açılıyor, tedavi planı ebatında olmalı [open]
**Sahip:** "ertelemenin wide screen değil tedavi plan ebatlarında olması lazım". **Kabul:** erteleme sheet'i tedavi planı sheet'iyle aynı boyut/yerleşim.

### DEBT-ERTELE-CIFT-YOL — Görev ertelemesi iki ayrı yoldan yapılıyor; takvim düzenleme ekranının altında açılıyor [open]
**Sahip:** "görev erteleme çift fonksiyon ile yapılıyor — düzenleme butonu ve listedeki erteleme butonu; görev düzenle üzerinden gidilen takvim garip davranıyor, düzenleme ekranının altında açılıyor; var olan şeyi tekrar yapmışız — ikisini birleştirip fixleyelim". **Kabul:** tek erteleme akışı (tek RPC `gorev_ertele` + tek sheet); düzenleme ekranındaki tarih değişikliği aynı akışa yönlenir; takvim üstte/doğru katmanda açılır.

### DEBT-OVSYNC-ERKEN-BASLAT — Başlat, kural gününden haftalar önce basılabiliyor → gelecek tarihli aktif vaka [fixed 2026-09-26 — p5b-fix K4: UI hedef−2 penceresi + RPC OVSYNC_ERKEN (20260926000002), demo 008/169 temizlendi; UI testi p5c R11/R13 PASS; prod'da]
**Belirti (demo):** 11 ay 11 günlük düve 38 (R093215052) "Ovsync Protokol · 04.11.2026 · Aktif"; demo'da 5 vaka (188, 110, 008, 38, 169) bugün açılmış, başlangıçları 06.10–07.11. **Prod: 0** (ölçüldü 2026-09-25). **Kök:** `start_first_service_protocol` hedef/kural günü > bugün ise reddetmiyor (başlangıcı GREATEST(hedef, bugün) yapıp açıyor); 000019 kapısı yalnız görev ÜRETİMİNDE. **Kabul:** DB'de başlatma yalnız kural günü − 2 gün penceresinde (erken → `atlandi:ERKEN`/hata); UI'da Başlat butonu pencere dışında gizli; demo'daki 5 erken vaka temizlenir.

### DEBT-HIZLI-PG-KAPI-UI — Hızlı Uygulama ile PG: onay penceresi yerine "hata" [fixed 2026-09-26 — p5b-fix K3: hayvan detay Hızlı Uygulama _pgKapiHata zincirine bağlandı; ön-var (main'de de vardı); UI testi p5c R10 PASS]
**Sahip:** "173'e hızlı uygulama ile PG yaptım hata verdi". **Ölçüm (demo, BEGIN…ROLLBACK):** sunucu `PG_KAPI:REQUIRE_ACK_PENDING` döndürüyor (173, 57 gün önce tohumlanmış, sonuç Bekliyor) — bu KASITLI kapı; UI `_pgKapiHata` (ui.js:1088) mesajın `^PG_KAPI:` ile BAŞLAMASINI bekliyor. Onay penceresi açılmadıysa mesaj bir katmanda önek almış olabilir (api.js rpc hata yolu `main`'e göre değişti: `data.mesaj || data.error`). **Kabul:** Bekliyor/gebe hayvana PG → onay penceresi (Boş ata ve uygula / vazgeç); main'de davranış karşılaştırması (regresyon mu ön-var mı).

### DEBT-PG-TAI-SAAT — Test inek 3: PG sonrası TAI +48s yerine ~+59s (28.09 09:00) [open — doğrulanmalı]
**Sahip:** "48 değil 72 saat sonra görev oluşturması — saatten kaynaklı da olabilir". Muhtemel neden `_tohumlama_pencere` yuvarlaması (akşam PG → +48s gece → ertesi sabah penceresine). **Kabul:** kural belgelensin; sahip isterse yuvarlama yönü (önceki akşam / sonraki sabah) ayarı. Ayrıca sahip: "var olan planlı tohumlama PG'ye göre yeniden tarihlensin" — E3 vakayı kapatıp yeni TAI açıyor; sonuç aynı, sahip kabul etti.

### BUG-ERTELEME-KURAL-GENEL — tohumlama_gorev_ertele yalnız tohumlama görevlerini kabul ediyor; erteleme kuralları genel değil [open / borç]

**Tarih:** 2026-09-24 · **Kaynak:** ovsync cila turu araştırması (reports/plans/ovsync-cila-plan-2.md §5A)

**Durum:** `tohumlama_gorev_ertele(uuid, date, time)` yalnız `TOHUMLAMA_PLANLI` kabul eder
(`TIP_UYGUN_DEGIL`, 20260923000003_ovsync_pg_yardimcilar.sql:L540/L562). Tohumlama-dışı görevlerin
ertelenmesi tek noktadan kurallı değil.

**Sahip kararı (2026-09-24):** bu turda tam fix BEKLESİN. Hedef tasarım kaydedildi: hibrit, ağırlık DB'de —
kurallar `gorev_ertele_kural` tablosunda (protokol_ayar deseni), pencere/geçmiş-tarih kontrolü RPC gövdesinde,
JS kopyası YASAK.

### BUG-KUYRUK-SHEMA-VERSIYONU — IndexedDB _queue eski-alanlı kayıtları yeni şemaya sessiz gönderiyor (Plan 5 T9) [open / borç]

**Tarih:** 2026-09-24 · **Kanıt:** js/api.js:110, 175-181, 536-566 · **Kaynak:** ovsync-cila-plan-5.md

**Durum:** Offline kuyruğundaki kayıtlar form-unun o anki alanlarıyla saklanıyor; form şeması değişince
eski kayıtlar uyumsuz alanlarla sunucuya gider → sessiz hata.

**Sahip kararı (2026-09-24):** bu turda tam fix YOK — borç kaydı + ucuz ikame (kuyruğa dead-letter
görünür uyarısı) yeterli.

### NOT-KISIR-GEBE-OTORITE — Bir hayvan hem kısır hem "gebe" kayıtlı (demo: küpe 184) [open / acil değil]

**Tarih:** 2026-09-24 · **Sahip notu:** Gebe hayvan kısır atanamamalıydı (öyle ayarlanmıştı); değilse de
önemli değil — insanlar gebe hayvanı kısır atanmaz, yalnız agent temizlik betikleri yanlışlıkla yapabilir.
Kısır temizlik dry-run'ında bu vakalar listelenip sahip onayından geçecek (plan-1 S2). Acil iş değil, kalsın.

### BUG-DBVAL-BORC — db-validate baseline borçları: PK kurmuyor + pg_cron yok + C2 text-PK seeder bozuk [open / borç]

**Tarih:** 2026-09-25 · **Kaynak:** ovsync-cila spec-s2 §11 / `reports/db-validation-ddf69fa0.md` (final migration SHA ddf69fa0… — review-fix search_path sonrası; ilk tur raporu bf06b2aa)

**Durum:** db-validation kapısının izole baseline'ında üç aracı borç:
1. Baseline PK/unique'ları yeniden kurmuyor → migration'daki `ON CONFLICT (anahtar)` patlar
   (çözüm deseni: PK-bağımsız update-önce/insert-eksikse — S2 migration §1).
2. Baseline'da pg_cron yok → `cron.schedule` pg_cron-koruyan DO bloğu ister (S2 migration §9).
3. C2 sentetik seeder text-PK tablolarda bozuk SQL üretir (`INSERT ... VALUES ()` syntax error)
   → C2 INCONCLUSIVE kalır; boşluk manuel fonksiyonel testlerle dolduruldu (spec-s2 §6 T-a…T-m)
   ve S2 apply-sonrası DEMO kabul setiyle (A1-A8) çapraz-kanıtlandı.

**Etki:** kapı bu üç durumda INCONCLUSIVE döner; her migration bunları kendince aşmak zorunda.
S2'de aşıldı: C1 PASS (tüm alt-kriterler), genel INCONCLUSIVE yalnız bu bilinen borçlardan.

### BUG-S2-REVIEW-TEMIZLIK — S2 final-review temizlik borçları (bilinçli devir) [open / borç]

**Tarih:** 2026-09-25 · **Kaynak:** S2 son review kapısı (8 bulgudan fix edilmeyen 3'ü — #6/#7/#8 fix edildi, #1/#2 teslim raporunda sahibe sunuldu)

1. **reuse:** `gebelik_muayene_listele`/`_uret` son-tohumlama seçimini inline tutuyor
   (ORDER BY tarih DESC, created_at DESC LIMIT 1); mevcut `public._son_tohumlama`
   (20260923000003:L66) tek-tanım yerine geçebilirdi. Fonksiyonel test+demo kabulü
   bu gövdeyle kanıtlandığından bu turda DEĞİŞMEDİ; birleşik temizlik migration'ında
   yardımcıya geçiş yapılmalı.
2. **verim:** ui.js loadDash/_showSessizList içinde sessiz+muayene fetch'leri sıralı
   await; Promise.all ile paralelleşebilirdi. Çevre loadDash zaten sıralı await
   deseniyle yazılı — tutarlık için korundu; sayfa-yükleme toplam iyileştirmesi
   ayrı bir verim turuna bırakıldı.
3. **sadeleşme:** `_dashBands` 15 konumsal parametre; drift riski bir kez yaşandı
   (F1/F2 — test yorumu belgeliyor). options-objesi yapısal çözüm ama imza
   değişimi S1'in bölgelerine de dokunur; tek-kulvar refactor olarak planlanmalı.

**Etki:** işlevsel etkisi yok; kod-kalitesi devri. #1 (v_eligible any-Bekliyor vs
en-yeni-kayıt otoritesi) ve #2 (50+ metni ↔ prod DB 55 eşiği penceresi) sahibin
kararına/bilgisine sunuldu — teslim raporuna bakınız.

### NOT-TEST-TRIAJ-S2 — 3 birim-test kırmızısı pre-existing; bu dalın regreyonu değil [open / triaj]

**Tarih:** 2026-09-25 · **Kaynak:** S2 final review 2. tur (sapma-12/14; kanıt: worktree koşumu
1089/1092, HEAD baseline arşiv koşumu 1086/1089 — aynı 3 fail)

1. `tests/unit/vaka-toplu-ac.test.js:2574` ve `:2594` — bc-tarih takvim "gelecek güne tık" ve
   "ay ‹/› Ekim 2026" sayfalama testleri ay-bağlı kırılgan (bugüne-göre tasarım, tarihe-sabit
   değil — W20 dili). Bacf648 baseline'ında da aynı ikisi düşer.
2. `tests/unit/degisiklikler-etiketler.test.js` LUNA-3 — canlı DEMO'da etiket-haritası olmayan
   7 kolon: `cases.close_reason`, `cases.protocol_family`, `cases.protocol_snapshot`,
   `cases.source_template_id`, `drug_classes.farmakolojik_sinif_kodu`, `drug_classes.sistem`,
   `tedavi_sablonu.protokol_ailesi`. Kolonlar 20260923000005/06 + 2026092400000x ovsync
   vaka-kapanış ailesinden; `git diff bacf648..HEAD` içinde 0 geçiş (CONFIRMED grep).
   Fix vektörü: `js/degisiklikler/etiketler.js` haritasına 7 Türkçe etiket eklenmesi —
   S2 kapsamı dışında, ayrı tur.

**Etki:** teslimi engellemez; regresyon-SIFIR kanıtı sapma-12 karşılaştırmasındadır.

### BUG-SESSIZ-GEBE-SON-KAYIT — v_eligible 'Gebe hariç' any-record; muayene RPC'si son-kayıt otoritesi (hizalama borcu) [open / borç]

**Tarih:** 2026-09-25 · **Kaynak:** S2 son-review ORTA bulgusunun onarımı sırasında belirlendi (20260925000003)

`v_eligible`'ın `NOT EXISTS (sonuc='Gebe')` filtresi HERHANGİ bir Gebe kaydına bakar;
`gebelik_muayene_listele/_uret` yalnız SON tohumlamaya bakar (ORDER BY tarih DESC,
created_at DESC LIMIT 1). Son tohumlaması Boş/Doğum Yaptı ama geçmişte Gebe kaydı olan
hayvan iki akış arasında tutarsız eleme yaşar (demo vakası 'Test inek 3' — onarım
20260925000003 ile Bekliyor bacağı son-kayıta bağlandı; Gebe bacağı bilinçli DOKUNULMADI:
ön-existing ana-davranışı, tek-başına kapsam kararıdır). Fix vektörü: Gebe filtresini de
son-kayıt alt-sorgusuna bağlamak — sahibin "kapsam yalnız Boş+durumu-bilinmeyen" kararıyla
hizalanır, ama vaka kapanış/geri-alım akışlarında Gebe-yeniden-açılma senaryoları önce
ölçülmelidir.

**Etki:** sessiz havuzunda muhafazakâr-eksik (hayvan görülmeyebilir); yanlış-görev üretmez.

### NOT-SESSIZ-VIEW-LISTELE-ASIMETRI — v_eligible WHERE'i, son_event=NULL dalında sessiz_gun>=50'den geniş [open / bilgi]

**Tarih:** 2026-09-25 · **Kaynak:** onarım sonrası canlı demo gözlemi (kupe '31': v_eligible'da VAR,
sessiz_gun=15 — listele/reconcile/stat hediyeleri COALESCE(sessiz_gun,9999)>=50 ile eler, OBSERVED)

v_eligible'ın WHERE'i yalnız `son_event.tarih < bugün-50 VEYA son_event IS NULL` şartını taşır;
son-event'siz hayvan dogum_tarihi-temelli küçük sessiz_gun ile view'a girer. TÜM canlı tüketiciler
(sessiz_hayvanlar_listele, sessiz_hayvanlar_reconcile, stat_suru_ozet) kendi sessiz_gun>=50
guard'ını taşıdığından davranış sızıntısı YOK; yalnız view adı ile WHERE'in vaadi arasındaki
boşluk kayıt altına alındı. Fix vektörü: view'a `AND COALESCE(sessiz_gun,9999) >= 50` eklenmesi
(tek nokta; tüketici guard'ları sadeleşebilir).

### BUG-XSS-OPENDET-KALAN — ui.js'te escAttr'sız inline openDet argümanları (ana-gövde geneli) [open / borç]

**Tarih:** 2026-09-25 · **Kaynak:** S2 final review DÜŞÜK bulgusu + onarım

Sessiz-ailesi iki satır (bant + sheet) onarımda escAttr'e hizalandı (2026-09-25,
js/ui.js). Kalan escAttr'sız inline `openDet('...')` noktaları: js/ui.js:178 (aşı
bandı), ~:308 (ileri-gebe bandı), ~:1616 (hayvan kartı tık), ~:2947-2957 (pedigree),
~:3840-3841 (geçmiş noktaları). Tümü DB-uuid argüman taşıdığından pratik risk düşük;
ana-gövdeye yayılmış tek-tur XSS hizalaması ayrı hardening turu olarak planlanmalı
(S2'deki escAttr disiplini referans).

**Etki:** hayvan_id kaynakları DB-uuid; istismar yolu yok bilinen veride — hijyen borcu.

### BUG-SESSIZ-SON-TOHUMLAMA-INLINE — son-tohumlama seçimi 3. inline kopya (view dâhil) [open / borç]

**Tarih:** 2026-09-25 · **Kaynak:** son review kapısı (BİLGİ bulgusu)

`ORDER BY tarih DESC NULLS LAST, created_at DESC NULLS LAST LIMIT 1` desenini artık ÜÇ yer
inline taşıyor: `v_eligible` (20260925000003 — onarım fix'i), `gebelik_muayene_listele/_uret`
(20260925000002). Mevcut `public._son_tohumlama(hayvan_id)` (20260923000003) tek-tanım yerine
geçebilir; view için `COALESCE((SELECT sonuc FROM public._son_tohumlama(h.id)), '')` formu
yeterli. Birleşik temizlik migration'ında dört kullanım tek yardımcıya bağlanmalı (davranış-eş;
bu turda dokunulmadı — BUG-S2-REVIEW-TEMIZLIK #1'in kapsamını genişletir).

### BUG-UREME-SEKMESI-FILTRE — Görevler'de "Üreme" sekmesi görevleri filtrelemiyor, "gösterilecek görev yok" veriyor [open]

**Tarih:** 2026-09-25 · **Bulgu yeri:** sahibin demo yürüyüşü (http://127.0.0.1:8123/?demo)

**Belirti:** Görevler ekranında Üreme sekmesine basınca üreme görevleri
(OVSYNC_BASLAT, TOHUMLAMA_PLANLI vb.) listelenmiyor; "gösterilecek görev yok"
diyor. Görevler ana listede var (canlı demo DB: OVSYNC_BASLAT 29 açık, 
TOHUMLAMA_PLANLI 9 açık).

**Muhtemel yön:** js/ui.js görev-sekme filtresi yeni ovsync/görev tiplerini
üreme kategorisine eşlemiyor ya da sekme filtre koşulu yeni tip adlarıyla
uyumsuz.

---

### BUG-PROTOKOL-OVSYNC-AYRIK — Ovsync protokol görevleri protokol panelinde görünmüyor, yalnız Görevler'de görünüyor [open]

**Tarih:** 2026-09-25 · **Bulgu yeri:** sahibin demo yürüyüşü

**Belirti:** Sahibin ekran dökümünde ovsync protokol görevleri (Gün 1/4,
Buserin 2.5ml · IM, 7 hayvan — 28/31/122/144/149/168/186/Test inek 3, tümü
"⚠ 20sa 36dk gecikti") YALNIZ Görevler listesinde; Protokol Uyarıları
panelinde yok. Panelde yalnız DOGUM_PROTOKOL (117/002/122/186/188) ve
ILERI_GEBE_PROTOKOL satırları var — Protokol Uyarıları başlığındaki ovsync
grubu ayrı "Düve (Büyük) 2 / Sağmal 6" bloklarında duruyor.

**Sahip notu:** "protokolde ovsync görevleri yok sadece görevlerde var."
Panel↔Görevler arasında ovsync zincirlerinin dağılımı tasarımsal olarak
gözden geçirilmeli (sahip fix istemedi — tespit kaydı, başka agent'e
devredilecek).

**Ek gözlem (aynı dökümden):** 7 ovsync görevi "20sa 36dk gecikti" aynı
damgayla — 24.09.2026 10:00 hedefi, gün-1 seansları uygulanmamış. zincir
ilerlemesi bekliyor.

---

## Mimar dal incelemesi — 2026-09-25 (ovysch-feature-cila-turu @1f01e8b)

Kaynak rapor: `reports/2026-09-25-cila-dal-inceleme-mimar.md` (ana checkout, gitignore'lu).
6 salt-okunur kulvar + mimar nokta-kontrolü; prod incelenmedi, Playwright koşulmadı.

### BUG-CILA-000008-ESIK-GERI-DONUS — sessiz reconcile eşiği 50→55'e geri döndü [open]

**Tarih:** 2026-09-25 · **Bulgu yeri:** mimar dal incelemesi · **Önem:** YÜKSEK (merge öncesi şart)

000008 `sessiz_hayvanlar_reconcile`'ı 20260625000020 gövdesinden yeniden yazdı; 000002'nin 50 günlük
eşiği üret/kapat bacaklarında 55 oldu (000008:34,73 vs 000002:107,140). listele/stat/v_eligible 50'de.
KAPAT bacağı 50–54 gün aralığındaki meşru SESSIZ görevleri `sessiz-noteligible` ile iptal eder.
000008 başlığındaki "önceki gövde 20260625000020" yanlış (önceki = 000002). Demo canlı gövde 55 [OBSERVED].
**Yön:** 000009 ile eşik 50 + başlık düzeltmesi; sapma ledger'ına kayıt.

---

### BUG-CILA-DEMO-000007-UYGULANMADI — T1 muafiyeti kayıtlı ama canlı değil [open]

**Tarih:** 2026-09-25 · **Bulgu yeri:** mimar dal incelemesi · **Önem:** YÜKSEK

Demo schema_migrations 000007'yi gösteriyor; canlı `_acik_disi_hedef_ic` 000001 gövdesinde, `senkron`
filtresi (000007:126-135) yok [OBSERVED prosrc]. pg_proc xmin sırası 000001'in 000006'dan sonra yeniden
koşulup T1'i ezdiğine işaret ediyor [INFERRED]. Demo'daki 8 cila kaydının hepsinde `statements` NULL
(elle girilmiş); 20260923/24 serisinin kaydı yok ama nesneleri canlı — demo migration geçmişi yetkili değil.
**Yön:** demo'da 000007 yeniden uygulanmalı; prod uygulamasında her dosyadan sonra gövde imzası doğrulanmalı.

---

### BUG-CILA-KISIR-DOGUM-ABORT-KANCA — doğum/abort yolu kısır guard'ını atlıyor [open]

**Tarih:** 2026-09-25 · **Bulgu yeri:** mimar dal incelemesi · **Önem:** ORTA

`dogum_kaydet` ve `tohumlama_abort` → `_ilk_tohumlama_rota_kur` → `_ovsync_baslat_gorev_kur` zincirinde
kisir/Aktif/Dişi kontrolü yok [OBSERVED demo prosrc]. Kısır inek doğum/abort yaparsa OVSYNC_BASLAT açılır
(M2 + UI kilidi başlatmayı engeller, görev/uyarı kirliliği kalır). 000001:17-19 "olay kancaları bu
gövdeden beslenir" yorumu bu iki kanca için yanlış; spec-s1 hedef 1 "tüm olay kancaları" diyor.
184/199 "Doğum Yaptı", 208 son kaydı Abort → senaryo gerçekçi.
Ek (DÜŞÜK): `ilk_tohumlama_zamanlayici` dry-run `baslatilacaklar` listesi kısır filtresi taşımıyor
(000001:350-361); 184/199/208 kısır vakaları hâlâ `status='active'` (spec-s1 §305 kapatılacak diyor).

---

### BUG-CILA-PROTOCOL-FAMILY-BOS — ovsync vakalarında cases.protocol_family hiç dolmuyor [open]

**Tarih:** 2026-09-25 · **Bulgu yeri:** mimar dal incelemesi · **Önem:** YÜKSEK

Demo'da 12 aktif Ovsync vakasının 0'ında dolu [OBSERVED]. Buna dayanan guard'lar ölü:
`start_first_service_protocol` AKTIF_SENKRONIZASYON kontrolü, 000008 reconcile guard'ı, ureme_temizlik R1
(168/186 stale SESSIZ çapalarının temizlenmemesiyle ilişkili). BUG-PROTOKOL-OVSYNC-AYRIK'ın doğal filtre
anahtarı da bu alan. Main'den (ovsync-pg) gelen kök; bu dal üzerine guard kurdu.

---

### BUG-CILA-000004-SEARCH-PATH-TIRNAK — search_path tek var-olmayan şemaya kilitli [open]

**Tarih:** 2026-09-25 · **Bulgu yeri:** mimar dal incelemesi · **Önem:** ORTA

000004:27-28 `SET search_path = 'public, pg_temp'` → "public, pg_temp" adlı tek şema; sertleştirme
etkisiz (demo proconfig tırnaklı, `current_schemas`={pg_catalog}) [OBSERVED]. 25-26'daki "semantik aynı"
notu yanlış. **Yön:** tırnaksız `public, pg_temp`. Aynı turda 000006 `gorev_tamamla(text,text,boolean)`'a
search_path eklenmeli (proconfig NULL).

---

### BUG-CILA-000005-GRANT — tek-seferlik temizlik RPC'si authenticated'a açık [open]

**Tarih:** 2026-09-25 · **Bulgu yeri:** mimar dal incelemesi · **Önem:** ORTA

`ureme_temizlik_reconcile` başlığı "tek-seferlik DEMO aracı, prod'a uygulanmaz" (000005:4) ama
migrations/ altında ve `authenticated`'a GRANT'li (000005:185-186), rol koruması yok; tek REST çağrısıyla
`p_dry_run=false` toplu iptal, her çağrıda o an kurala uyanları yeniden kapatır.
**Yön:** GRANT service_role'e daraltılmalı ya da koşum sonrası DROP; prod'a gidip gitmeyeceği sahip kararı.

---

### BUG-CILA-MIGRATION-TRANSACTION — cila migration'larında transaction disiplini tutarsız [open]

**Tarih:** 2026-09-25 · **Bulgu yeri:** mimar dal incelemesi · **Önem:** DÜŞÜK (dağıtım riski)

000001/000006/000007/000008 BEGIN/COMMIT taşımıyor (autocommit'te 000006'da CREATE ile REVOKE arası yeni
imza anlık PUBLIC-EXECUTE'lu; yarıda kalırsa iki overload → 42725); 000002/3/4/5 kendi BEGIN/COMMIT'ini
taşıyor → `psql -1` toplu koşumda iç COMMIT tek-transaction'ı bozar. Prod'a dosya dosya uygulanmalı.

---

### BUG-CILA-FLUSH-PENDING-YARIS — flushPendingDone eşzamanlılık/kayıp [open]

**Tarih:** 2026-09-25 · **Bulgu yeri:** mimar dal incelemesi · **Önem:** ORTA (bu dalın davranış farkı)

js/ui.js:601-616: başta kopya, sonda liste temizlenip kopyadan geri yükleniyor → dönüş sürerken eklenen
tamamlamalar silinir; kilit yok, loadTasks (ui.js:631) + app.js:81 aynı işlemleri iki kez gönderebilir;
kalıcı hatalı işlem her loadTasks'ta yeniden denenip toast basar.
Ek (DÜŞÜK): ui.js:316,324,1753,1754,2005,2069 `onclick="openDet('${escAttr(x)}')"` — escAttr JS-string
bağlamını kaçırmaz; yön `data-*` + `this.dataset`.

---

### BORC-CILA-KARSILANMAYAN — talimatname maddeleri karşılanmadı [open]

**Tarih:** 2026-09-25 · **Bulgu yeri:** mimar dal incelemesi (talimat: yurutme-haritasi-ss-research-2026-09-23.md)

- (2b) Aktif ovsync görevlerini yarına erteleme yapılmadı — spec-s3:23'te "bugün hedefli OVSYNC_BASLAT"a
  daraltılıp "moot" ilan edildi (sayım PROD kanalından).
- (2c) Genel erteleme (tohumlama/aşı/tedavi + UI) borçta; BUGS.md:191'deki "sahip kararı"nın kaydı sentez
  §9'da bulunamadı [UNKNOWN].
- (3d) OVSYNC_SABLON_BELIRSIZ kök nedeni hiçbir spec'e girmedi; demo'daki aktif şablon sayısı ölçülmedi
  (spec-s4 B24 ölçümü tools-bank=PROD kanalından).
- (3c) Düve eşikleri tutarsız: ovsync 12a21g, sessiz akışı 13 ay; yardım metni düveyi açıklamıyor.
- T9 "dead-letter görünür uyarısı" ikamesi yapılmadı. Kayıtsız sapmalar: 000008, 000004, 000003 (R7 sahip
  onayı şartı), a4807db (plan D2 2-arg imzayı korumayı öngörüyordu).

---

### KÖK NEDEN — BUG-UREME-SEKMESI-FILTRE ve BUG-PROTOKOL-OVSYNC-AYRIK (mimar, 2026-09-25)

İkisi de bu dalın regresyonu DEĞİL; main'de de var (ovsync-pg / fe5f91d ile gelen tasarım eksiği).

**BUG-UREME-SEKMESI-FILTRE:** (1) Görevler varsayılan "Bugün" filtresiyle açılır (index.html:692); tarih
süzmesi kategoriden önce (ui.js:696-705). Açık 29 OVSYNC_BASLAT (10-06→) + 9 TOHUMLAMA_PLANLI (09-28→10-04)
hepsi ileri tarihli → yalnız "Bekleyen"de görünür. (2) Başlamış zincir tedavi vakası (hastalık "Ovsync
Protokol", kategori "Üreme") + TEDAVI_SEANS/TEDAVI_GUN üretir; bu tipler `tedavi` kategorisinde (ui.js:56)
→ gecikmiş Buserin seansları Tedavi sekmesinde. **Yön:** Üreme eşlemesi vaka hastalık kategorisine göre de
yapılmalı + planlı üreme görevleri için ASI_PLANLI'deki 7-gün penceresi gibi istisna (ui.js:696).

**BUG-PROTOKOL-OVSYNC-AYRIK:** Panel yalnız `protokol_eksik_tara` (DOGUM/ILERI_GEBE/KIZGINLIK) +
`ovsync_baslat_uyarilari` (yalnız açık OVSYNC_BASLAT, hedef−2g) okur (ui.js:1851-1905; rozet 425-440).
Başlat'tan sonra zincir TEDAVI_SEANS olur → iki kaynağın dışına düşer. `bildirimKontrol` `!g.parent_id`
ile seansları eler, gecikme kolu yok, `hedef_saat` okumaz (ui.js:10553,10560).
**Yön:** aktif Üreme vakalarının gecikmiş/yaklaşan seanslarını dönen 3. kaynak → panel + `_rozetTopla`;
bildirimKontrol parent_id'li seansları ve gecikmeyi kapsamalı. Bkz. BUG-CILA-PROTOCOL-FAMILY-BOS.

---

### BUG-OFFLINE-UNCHECK-TAMAMLA (pre_existing — 2026-09-25 ultrareview bulgusu, düzeltilmedi — bilinçli erteleme)

Offline iken bir alt-görevin check'inin kaldırılması (tamamlandi:false PATCH) kuyruğa ayrı kayıt olarak
girer; reconnect'te dataTrafficTekGonder gorev_log PATCH'lerini gorev_tamamla RPC'sine yönlendirir ve
buildRpcParams 'gorev_tamamla' dalı (js/ui.js:9686-9688) yalnız data.id/data.padok/data.iptal okur —
data.tamamlandi okumaz. SQL gorev_tamamla
(supabase/migrations/20260925000006_cila_t5_gorev_tamamla_p_iptal.sql) koşulsuz tamamlandi=true yazar
(p_iptal hariç). Sonuç: offline check→un-check yapan kullanıcının son eylemi sunucuda
kalıcı 'tamamlandı' olarak replay edilir.

Kanıt satırları: js/ui.js:1435 (toggleSub write PATCH), js/ui.js:1503 (toggleSubDet),
js/api.js:175-182 (queueOp dedup yok), js/ui.js:9505 (RPC_MAP), js/ui.js:9686-9688 (buildRpcParams),
20260925000006 (SQL taraf).
Kaynak rapor: /home/melik/.herdr/worktrees/egesut-erp1/review-cila-kod/reports/2026-09-25-ultrareview-cila-kod.md
Not: js/ui.js satır numaraları 2026-09-25 HEAD'ine göredir; U2 refactoringi (commit f6cc0bb) sonrası ~6 satır kayabilir.
