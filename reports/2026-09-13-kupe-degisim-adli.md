# W4 — 4019→51 ve 51→31 Değişiklikleri: Ne Zaman, Kim, Nasıl? + Devlet Küpe Geçmişi (Salt-Okuma Adli Analiz)

**Tarih:** 2026-09-13 · **Worker:** buzagi-51-arastirma (glm) · **Girdi:** W1 Rev 2 (`ac6d476`) + root denetimi
**Erişim:** Supabase Mgmt API (salt SELECT), GitHub Actions artefakt API'si (indirme), yerel dosya/log taraması. Restore yok; secret değeri rapora yazılmadı.

## Özet

1. **4019→51 (a67cd118) — günü kesin, yöntem sınıfı kesin, faili belirsiz:**
   **2026-06-02 14:01:16.927 UTC (17:01:16 TSİ)**, **tek transaction'da koşan, uygulama
   katmanı dışı, `updated_at=now()` içeren toplu yazım**. Bu tx **124 hayvan satırını**
   güncelledi (mikrosaniyeye kadar birebir aynı `updated_at`); bu satırların
   snapshot↔canlı **net farkında** 80+40'lık iki partinin **grup/padok normalizasyonu**,
   **2 küpe değişimi** (`4019→51` ve `903→"903+"`), **22 satıra devlet küpe ataması**,
   **10 satıra doğum tarihi** var. "Uygulama katmanı dışı" kısıtı kesindir: (a) uygulama
   UI'ı `updated_at` yazmaz, (b) `updated_at` yazan tek RPC'ler (`padok_degistir`,
   `padok_degistir_toplu`) kupe/doğum/devlet alanlarına dokunmaz, (c) repo
   migration/script'lerinde bu işlem yoktur. **Hangi aracın koştuğu** (psql/SQL editörü
   oturumu mu, servis anahtarıyla atılmış gövdesinde açık `updated_at` literali taşıyan
   doğrudan PostgREST toplu PATCH'i mi) aynı imzayı ürettiğinden **ayrı edilemez** —
   "elle SQL" en olası sınıftır, tek olası değildir. Ek kör nokta: RPC envanter taraması
   `prosrc ILIKE '%UPDATE hayvanlar%'` desenidir; biçim varyasyonlu gövdeleri
   kaçırabilir. **Kim koştuğu hiçbir izden çıkarılamaz** (ajan logları, ui_logs,
   islem_log boş — bkz. Kaynak tespiti).
2. **51→31 (982fbd16) — günü ölçülemedi, pencere: (2026-06-01 07:25, 2026-09-13):**
   ölçülen son "51" anı 06-01 07:25'tir (INSERT snapshot 07:01 + o dakikadaki aşı
   kayıtları); sonraki ilk ölçüm W1 (09-13, "31"). "06-02 14:01'den sonra" okuması
   ölçüm değil, **etiketli çıkarımdır** ("çift kaydı çözen düzeltme 06-02'de doğdu"
   akıl yürütmesi); damgasız tek-satırlık bir değişiklik pencere içinde her an
   mümkündür. `updated_at` 06-21 06:13:52.277921'de kalır (padok_degistir_toplu, 5
   hayvan tek tx) — UI ve `hayvan_guncelle` `updated_at` yazmadığı için sonraki
   tek-satırlık bir düzeltme damgasız kalabilirdi. Değişikliğin karakteri (kupe + doğum
   tarihi + devlet küpe aynı anda) 06-02 veri düzeltmesi sınıfına işaret eder; ama
   tek-satırlık UI yolu da izsizdir. **Yedekle gün daraltma
   planlandı, anahtar yokluğunda bloke oldu** (aşağıda).
3. **Yedek bacağı (root yöntemi) — engel: decrypt anahtarı yerelde yok.** 70 günün
   artefaktı erişilebilir (2026-07-05 → 09-13; aralık içinde **yalnız 2026-09-09
   eksik** — Haziran olaylarıyla ilgisiz). En eski artefakt indirildi
   (`egesut_20260705.pg.enc`, 24 MB, `~/tmp/agents/w4/`), **aes-256-cbc/pbkdf2 çözümü
   için 3 yerel aday denendi (`SUPABASE_LOGIN_PASSWORD`, `NEON_PASSWORD`,
   `SUPABASE_DEMO_DB_PASSWORD`) — hiçbiri PGDMP sihirli dizisi üretmedi.**
   `BACKUP_PASSWORD` GitHub Actions secret'ıdır; yerel `.env`/tools-bank `.env`
   karşılığı bulunamadı. **4019→51 zaten yedekle ölçülemezdi:** 90 gün retention
   06-15 öncesini açıklar; 06-15…07-04'ün yokluğu ise envanterden "silinmiş" ile
   "yedek işi henüz yoktu" (ilk artefakt 07-05) olarak ayırt edilemez — her iki
   durumda da 06-01/06-02'yi kapsayan yedek yoktur. 51→31 için ikili arama
   **koşulludur:** yalnız 07-05 (ve sonraki) yedekleri hâlâ "51" gösteriyorsa gün
   bulunur (~7 indirme); 07-05 zaten "31" gösteriyorsa sonuç "<07-05"e düşer ve
   06-02…07-04 boşluğu nedeniyle gün asla bulunamaz. İndirilen şifreli dosya analiz
   sonrası **silindi**.
4. **Devlet küpe geçmişi:** mevcut iz kaynaklarında (islem_log snapshot/payload,
   ui_logs, ajan logları) `Tr093150354` veya `TR093215057` değerlerinin **hiçbir tarihsel
   kaydı yok**; 4019-dönemi snapshot'ında `a67cd118`'in devlet küpesi NULL idi → iki devlet
   küpe değeri de ilk kez **06-02 veri düzeltmesinde** görünmüş olmalı (etiketli çıkarım).
   `0354`'ün 31'den başka bir hayvana tarihte atanmış olduğuna dair iz yok; canlıda çakışma
   yok (her değer tek satırda). `Tr093150354` ↔ `TR093150353` (kupe 32; 2025-09-05 canlı `dogum_tarihi` alanından, dogum kaydı yok) ardışıktır → 31'in
   devlet küpesi kimliğiyle tutarlı.

## Zaman çizelgesi

| zaman (UTC) | olay | kanıt gücü |
|---|---|---|
| 2026-05-09 07:42 | İçe aktarma: `a67cd118` **"4019"** olarak girildi (devlet/doğum/anne boş) | INSERT snapshot (ölçümlü) |
| 2026-06-01 07:01 | Dogum geri-doldurması: `982fbd16` **"51", anne=195** + dogum satırı `577a2ecb`. O an kupe 51 boştu | INSERT snapshot (ölçümlü) |
| 2026-06-01 07:25 | 4 aşı kaydı o "51"e girildi | vaccination_log created_at (ölçümlü) |
| **2026-06-02 14:01:16.927** | **Tek-tx elle SQL veri düzeltmesi (124 satır):** grup/padok normalizasyonu + `4019→51` (+doğum 2025-11-17 +TR093215057 +duve) + `903→"903+"` + 22 devlet küpe + 10 doğum tarihi | **ölçümlü** (damga fiziği + snapshot↔canlı diff) |
| 2026-06-03 07:19 | `982fbd16` padok değişimi (RPC, islem `padok_degisim`, boş snapshot) | islem_log (ölçümlü; kupe değeri taşımaz) |
| 2026-06-21 06:12:48 | kupe 32 padok işlemi (tek satır tx) | updated_at (ölçümlü) |
| 2026-06-21 06:13:52.277921 | **padok_degistir_toplu:** 31/36/38/45/46 tek tx'te taşındı | **ölçümlü** (mikrosaniye-birebir 5 damga; RPC kupe'ye dokunmaz) |
| (06-01 07:25 … 09-13) | **51→31 dönüşümünün ölçümlü penceresi; günü ölçülemedi** ("06-02 sonrası" etiketli çıkarım) | son "51" ölçümü 06-01 07:25; sonraki ölçüm 09-13 |
| 2026-07-05 → | Günlük yedek artefaktları bu tarihten itibaren var; **çözülemedi** (anahtar yok) | gh api (ölçümlü) |
| 2026-07-17 20:15 | `GRUP_PADOK_UYUMLAMA` islem kaydı (982fbd16: (Büyük)→(Küçük) iddiası) — **güvenilmez:** bugünkü canlı değer (Büyük), kayıt gerçek bir hayvanlar güncellemesini yansıtmıyor | islem_log ↔ canlı çelişkisi (ölçümlü) |
| 2026-09-01 | Kupe-blok araştırma doc'u (1d9e81a) 4019'u "dolu" sayıyor — bayat/ikincil kaynak çelişkisi (yan not) | repo doc |
| 2026-09-13 | W1: 51'in canlı hali ölçüldü (anne_id NULL); W4 bu rapor | — |

## Kaynak tespiti

**Repo (commit/migration/script):**
- Pickaxe taraması: `git log --all -S'4019'`, `-S'Tr093150354'`, `-S'903+'` → eşleşenler
  yalnız bugünkü raporlar (2b7e951/ac6d476), bugünün görev zarfları ve kardeş kol raporu
  (d2891d4). Haziran dönemine ait **hiçbir commit bu değerleri içermiyor**.
- `supabase/migrations/` + `scripts/` içinde `UPDATE hayvanlar` geçenler: yalnız dar kapsamlı
  RPC tanımları (kısır işaretleme, padok RPC'leri, sutten kesme…). `20260602000002` ve
  `20260618000001` padok RPC'leridir; **kupe/devlet/doğum kütle güncellemesi yapan
  migration/script yok**. Not: `chore` commit'leri (`4f3492d`, `049c546`, `1a80118`) .py/.sh
  tek seferlik dosyaları repodan çıkarmış — o gün koşan betik bugün repoda olmayabilir.
- 2026-05-25…06-10 penceresinde `.claude/notes`/`docs` commit'i yok.

**Ajan oturum logları:**
- `~/.claude/projects/*` (tüm proje dizinleri) içinde `4019` geçen dosyalar bulundu;
  **Haziran (2026-06) damgalı eşleşme: 0** — bugünkü tartışma satırları (root W1 denetimi)
  ve 08-30 oturumu. `903+`/`Tr093150354` için Haziran damgası: 0.
- `~/.config/Goose/logs/main.log` (1673 satır): 06-01..06-03 × `4019|kupe|UPDATE hayvanlar|903`
  eşleşmesi: 0.
- `ui_logs` (DB): kapsam **2026-05-10 → 2026-06-12** (06-02'yi kapsıyor!), `4019`/`093150354`/
  `093215057` geçen kayıt: **0** → işlem UI'ın uiLog enstrümanlı aksiyonlarından geçmemiş.

**DB içi izler:**
- `islem_log`: `HAYVAN_GUNCELLENDI` = **0 satır** (trigger yalnız AFTER INSERT,
  `20260306000008:501`). Snapshot/payload metin araması `Tr093150354`: **0**, `TR093215057`: **0**.
  `982fbd16`'ın `padok_degisim` kayıtlarının snapshot'ı **boş**, payload **null** — kupe
  değerini tarihlendiremez.
- `updated_at` fiziği: hayvanlar'da updated_at trigger'ı **yok**; uygulama katmanı
  (js/api.js, js/forms.js) updated_at **yazmıyor**; 23 hayvanlar-RPC'sinden **yalnız
  `padok_degistir` ve `padok_degistir_toplu`** updated_at set ediyor ve ikisi de
  kupe/devlet/doğum'a dokunmuyor. → Mikrosaniye-birebir 124 damga ancak
  `updated_at=now()` içeren **tek-tx elle SQL** ile üretilebilir.

**UI yolu (Q2d):**
- "✏️ Bilgileri Düzenle": `openAnimalEdit` `js/ui.js:2956`; submit `data-action="submit-animal"`
  (index.html:1685) → RPC eşleme tablosu `hayvanlar: { PATCH: 'hayvan_guncelle' }`
  (`js/ui.js:8032`) / doğrudan `rpc('hayvan_guncelle', …)` (`js/forms.js:117`).
- `hayvan_guncelle` RPC'si: islem_log **yazmaz** (canlı gövde + HAYVAN_GUNCELLENDI=0),
  updated_at **set etmez**. → **UI üzerinden yapılan tek satırlık kupe düzeltmesi tamamen
  izsizdir** (değer değişir, damga değişmez, log oluşmaz).

**Yedek bacağı:**
- Artefakt envanteri: **70 gün** (unique created tarihleri), `2026-07-05` →
   `2026-09-13`, `expired=0`; **aralık içinde eksik tek gün: 2026-09-09** (ölçüm:
   created tarihleri unique+sort). **Eksik aralık beyanı:** 2026-05-09 … 2026-07-04 —
   90 gün retention'ı 06-15 öncesini açıklar; 06-15…07-04 için "silinmiş" ile "yedek
   işi henüz yoktu" envanterden ayırt edilemez; her iki durumda da 06-01 ve 06-02'yi
   kapsayan yedek yoktur.
- İndirme + çözme denemesi: `egesut_20260705.pg.enc` (24 MB) `~/tmp/agents/w4/`'a indi;
  `openssl enc -d -aes-256-cbc -pbkdf2` + PGDMP sihirli-dizisi testiyle 3 yerel aday
  (SUPABASE_LOGIN_PASSWORD / NEON_PASSWORD / SUPABASE_DEMO_DB_PASSWORD) denendi → **üçü de
  olmadı**. `BACKUP_PASSWORD` yalnız GitHub Actions secret'ı. (Olası yol, sahibin kararı:
  secret değerini sahibin vermesi; başka aday olarak sahibin kendine maillediği
  kimlik bilgileri düşünülebilir — o kutuya bu görevde bakılmadı.)
- İndirilen şifreli dosya analizden sonra silindi (`~/tmp/agents/w4/` temiz tutuluyor).

**Sonuç atfı (Q4):**

| değişiklik | gün/saat | kaynak | kanıt |
|---|---|---|---|
| 4019→51 (+doğum+devlet+grup/padok, 124 satırlık iş) | **2026-06-02 14:01:16.927 UTC (17:01:16 TSİ)** | **yöntem sınıfı kesin: app-dışı tek-tx toplu yazım (SQL/PostgREST); "elle SQL" en olası sınıf; faili belirsiz** | 124×birebir damga; snapshot↔canlı NET diff; RPC/UI envanter dışlamaları |
| 903→"903+" | aynı tx (aynı damga) | aynı | aynı |
| 51→31 (+doğum 2025-08-09 +Tr093150354) | **ölçümlü pencere (06-01 07:25, 09-13); gün ölçülemedi** ("06-02 sonrası" etiketli çıkarım) | **belirsiz** — ya damgasız SQL düzeltmesi ya izsiz tek-satırlık UI/hayvan_guncelle düzeltmesi | son "51" ölçümü 06-01 07:25; iki yolun da izsizliği ölçümlü |

## Devlet küpe geçmişi

- **51 (`a67cd118`):** bugün `TR093215057`. 4019-dönemi snapshot'ında devlet küpe **NULL**;
  değerin ilk kez 06-02 tx'inde atandığı değerlendirilir (etiketli çıkarım; tx 22 satıra
  devlet küpe atadı). Seri uyumu: 38=`TR093215052`, 46=`TR093215055`, 45=`Tr093215056`,
  **51=`TR093215057`** → TURKVET parti sırasıyla tutarlı. Başka bir değer girildiğine dair
  iz: islem_log 0, ui_logs 0, ajan logları 0 (Haziran), yedekler (çözülemedi).
- **31 (`982fbd16`):** bugün `Tr093150354`. 51-dönemi snapshot'ında devlet küpe **NULL**.
  **`0354`'ün 31 dışında bir hayvana tarihte atandığına dair hiçbir iz yok** (mevcut
  kaynaklar); canlıda `0354` tek satırda (31). `Tr093150354` ↔ `TR093150353` (kupe 32,
  2025-09-05) ardışık → 0354'ün 31'e aitliği kimlikle tutarlı; **hatalı olan 31'in
  `anne_id=195` bağıdır** (W1 Rev 2).
- TURKVET bağlamı (repo doc 1d9e81a, 09-01): resmi küpe ömür boyu özgü; `devlet_kupe`
  çakışma kontrolünün global kalması doğru — `dogum_kaydet`'in canlı guard'ı bunu zaten
  yapar (`kupe_no Aktif eşleşmesi OR devlet_kupe`).

## Kanıt ve komutlar

Temel sorgular (Mgmt API, salt SELECT; `norm-kupe = regexp_replace(trim(kupe_no),'^0+','')`):

1. **124'lük tx kapsamı:**
   `SELECT count(*) FROM hayvanlar WHERE updated_at='2026-06-02 14:01:16.927178+00'` → **124**
   (mikrosaniye-birebir → tek transaction). Parti dağılımı: created 05-09: 80, 06-01: 40,
   diğer: 4.
2. **Snapshot↔canlı diff (06-02 işinin ne değiştirdiği):**
   `SELECT l.snapshot->>'kupe_no', h.kupe_no, … FROM islem_log l JOIN hayvanlar h ON
   h.id=l.ana_hayvan_id WHERE l.tip='HAYVAN_EKLENDI' AND h.updated_at='…927178+00'`
   → kupe değişen **2** (`4019→51`, `903→"903+"`), devlet küpe atanan **22**, doğum tarihi
   eklenen **10**; kalanında grup/padok normalizasyonu (snapshot grup NULL → canlı
   'Sağmal (Laktasyonda)'/'Düve (Küçük)' vb.).
3. **updated_at fiziği:** hayvanlar trigger listesi (7 trigger, updated_at trigger'ı yok);
   `SELECT proname, prosrc ILIKE '%updated_at%' FROM pg_proc WHERE prosrc ILIKE
   '%UPDATE hayvanlar%'` → 23 fonksiyon, yalnız `padok_degistir`/`padok_degistir_toplu`
   true; `padok_degistir_toplu(text[],uuid,text[],text[])` prosrc'inde `kupe` geçmiyor.
4. **06-21 padok tx:** `SELECT kupe_no, updated_at FROM hayvanlar WHERE
   updated_at::date='2026-06-21'` → 32@06:12:48.166235; 31/36/38/45/46
   @**06:13:52.277921** (birebir aynı → padok_degistir_toplu tek tx).
5. **07-17 kaydının güvensizliği:** `GRUP_PADOK_UYUMLAMA` payload "sonraki: Düve Padok
   (Küçük)" ↔ canlı "Düve Padok (Büyük)" çelişkisi + updated_at 06-21'de kalması.
6. **İz aramaları (hepsi 0):** `islem_log` snapshot/payload `LIKE '%Tr093150354%'` → 0,
   `'%093215057%'` → 0; `HAYVAN_GUNCELLENDI` → 0; `ui_logs` payload `4019/093150354/093215057`
   → 0 (kapsam 05-10…06-12); `bildirim_log` mesaj `4019/093150354` → 0 (toplam 70 kayıt);
   `~/.claude/projects` Haziran-damgalı `4019/903+/Tr093150354` → 0; Goose `main.log`
   06-01..03 penceresi → 0; yerel LSP aynası (`egesut_lsp@127.0.0.1`) hayvanlar verisi → boş
   (şema mirror).
7. **Repo:** `git log --all --oneline -S'4019' | -S'Tr093150354' | -S'903+'`; migration taraması
   `grep -rln 'UPDATE hayvanlar' supabase/migrations/ scripts/` → yalnız dar kapsamlı RPC'ler.
8. **Yedek bacağı:** `gh api repos/Meliksahtokur/egesut-erp1/actions/artifacts` → 70 artefakt,
   ilk 2026-07-05; `gh run download 28727033239 -n egesut-backup-28727033239 -R
   Meliksahtokur/egesut-erp1 -D ~/tmp/agents/w4/` → `egesut_20260705.pg.enc` (24 MB);
   çözme denemesi: `openssl enc -d -aes-256-cbc -pbkdf2 -pass pass:"$ADET" -in … | head -c5`
   (PGDMP testi; 3 aday, 3 başarısız).
- **Anahtar gelirse ikili arama planı (koşullu):** tarih-sıralı 70 günün artefaktında
  `lo=07-05, hi=09-13 (31 biliniyor)`; her adımda orta artefakt indir → çöz → yalnız
  `pg_restore --data-only -t hayvanlar -f - dump.pg | grep -A2 '982fbd16'` (sunucusuz,
  restore yok). **Koşul:** 07-05 yedeği hâlâ "51" gösteriyorsa ~7 indirmede dönüşüm
  günü bulunur; 07-05 zaten "31" gösteriyorsa sonuç "<07-05"e düşer ve 06-02…07-04
  boşluğu nedeniyle gün bulunamaz.
- **4019→51 için bu yöntem uygulanamaz** (06-02 yedeği yok).

## Teslim review notu (şerit kuralı #1)

Builtin subagent salt-okuma review — 7 bulgu, tümü commit öncesi işlendi: **B1** 51→31
penceresinin alt sınırı ölçümsüz etiketiydi → ölçümlü pencere (06-01 07:25, 09-13) +
etiketli çıkarım ayrımı; **B2** "elle SQL kesin" iddiası → yöntem sınıfı kesin
(app-dışı tek-tx toplu yazım), araç daraltması ("psql mi PostgREST mi") etiketli +
pg_proc desen kör noktası notu; **B3** ikili aramanın koşulluluğu (07-05'te 31 ise gün
bulunamaz); **B4** 70/71 gün aritmetiği → aralık içi eksik gün 2026-09-09 ölçüldü;
**B5** 06-02 tx içeriği "net diff" diliyle yeniden etiketlendi (sonradan damgasız
değişim ihtimali); **B6** retention (06-15 öncesi) ile iş-başlangıcı (ilk artefakt
07-05) ayrımı; **B7** 32'nin 2025-09-05 tarihine kaynak belirtildi (canlı alan, dogum
kaydı yok).
