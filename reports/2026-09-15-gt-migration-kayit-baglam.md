# D3 — GT + migration kayıt disiplini: bağlam toplaması ve belge önerisi (SALT OKUNUR)

Tarih: 2026-09-15 · Dal: `agent/gt-migration-kayit` · Worker ölçümü + belge önerisi (yapı değişikliği YOK)

**Kural uyumu:** Prod'a karşı yapılan tüm sorgular Mgmt API üzerinden
`BEGIN READ ONLY; SELECT …; ROLLBACK;` zarfındadır (sayımlar + `schema_migrations`
kayıt örnekleri + tablo sütun yapısı). `supabase/migrations/` altında hiçbir dosya
değiştirilmedi; GT dosyası yeniden üretilmedi; `schema_migrations`'a kayıt
eklenmedi. Token değeri hiçbir dosyaya/çıktıya yazılmadı. Prod satır verisi bu
rapora girmedi — yalnız şema adları, sayılar, dosya adları.
Ölçüm betikleri: `.ss/mgt-sayim.sh`, `.ss/mgt-kayit.sh`, `.ss/mgt-tablo-sutun.sh`,
`.ss/gt-tablo.py` (dalda, commit dışı).

**Varsayım (zarftan):** Öneriler, paralel Adım B'nin (L2 `20260913000001..04` +
L4 `20260914000001..04`) ve P3 kararını izleyen `#5` (`20260910000002`) uygulamasının
prod'a girdiği durum üzerinden yazılmıştır.

---

## 1. Özet

1. Repoda migration/GT için **kural eksikliği değil, adım eksikliği** var: sözleşme
   "migration commit ≠ deploy" der (contract.md:104), docs-update pre-commit'i zorunlu
   kılar (docs-update.md:14), GT için 2026-06-13'ten beri yazılı bir regen prosedürü
   durur (docs/2026-06-13-emir-raporu-ground-truth-regen.md). Ancak **uygulama
   anının adım listesi** (belge → yedek → uygula → kayıt → GT yenileme → doğrulama →
   merge) hiçbir belgede toplanmamıştır; kanal psql/Mgmt API'ye kayınca kayıt ve GT
   adımları kanalla birlikte kayboldu.
2. Ölçüm: **2026-05-31'e kadarki 124 migration dosyası 124/124 kayıtlı**;
   Haziran'dan bugüne eklenen **142 dosyanın 0'ı kayıtlı** (134 repo-dal dosyası +
   8 L2/L4 entegrasyon-dal dosyası). `schema_migrations` prod'da
   `20260531400000`'da donmuş (n=124); demo n=2.
3. GT'nin son gerçek içerik senkronu **2026-09-06** (vaka_toplu_ac serisi,
   `32f73b9`); 2026-09-01'deki denetim (`.claude/schema-snapshots/2026-09-01-gt-v5-audit.md`)
   22 imza sapması sayıp "GT v5 regen GEREKLİ" demişti — regen hiç yapılmadı.
   İsim düzeyinde **134 dosyadan 17'sinin nesneleri GT'de yok**; 2026-09-09 sonrası
   18 dosyanın tamamı GT dışı.
4. Canlı (ölçüm anı 2026-09-15, Adım B öncesi): 52 tablo / 212 fn / 13 view /
   33 trigger — GT: 40 CREATE TABLE / 184 fn / 15 view / 33 trigger. `surum_gizli`
   şeması ölçüm anında prod'da 0 (Adım B henüz ulaşmamış) — öneriler bunu
   "bitti" varsayarak yazıldı (zarf).
5. Öneri: yedi adımlı runbook (§7a), 142 sürüm için kayıt-batch SQL taslağı (§7b,
   koşulmaz), GT v5 regen prosedürü + kapsamı (§7c), kuralın üç belgeye yazılması
   (§7d, metin farkları dahil).

---

## 2. Süreç ne diyordu? (Bulgu 1)

| Belge | Yer | Ne diyor |
|---|---|---|
| `.harness/contract.md` | :98-100 | DB objesi/migration değişmeden önce repository pre-check + blast radius incelemesi |
| `.harness/contract.md` | :101-103 | Live schema tek otorite; migration/snapshot/rpc-reference **yardımcı** referans, bayat olabilir |
| `.harness/contract.md` | :104 | "A migration file in Git is not evidence of deployment." |
| `.harness/contract.md` | :105-106 | Canlı DB yazma ayrı sahip talimatı ister; DROP/RENAME/TRUNCATE ayrı final onay ister |
| `.harness/acceptance.md` | :50-57 | commit gate: kayıt-sız (receipt-less) commit reddedilir |
| `.harness/acceptance.md` | :61-72 | push ≠ deploy ≠ DB mutation; "A migration commit inside the range is not evidence of deployment." (:66, :70) |
| `.harness/docs-update.md` | :14 | pre-commit checkpoint: "code or governance changes committed without tests and diff-routed documentation evaluation" |
| `.harness/docs-update.md` | :37-40 | "RPC/migration changes require live-schema, RPC reference, domain, deploy-boundary, and test evaluation." |
| `.harness/references/rpc-reference.md` | :8-17 | "Gövde niyeti için: `supabase/migrations/` (kanonik sırada son kazanan) — GT bazı imzalarda canlıdan ESKİDİR" → gt-v5-audit referansı |
| `AGENTS.md` | Project shape | "supabase/migrations/: migration history, not live-schema proof" |
| `docs/2026-06-13-emir-raporu-ground-truth-regen.md` | §2-§7 | GT regen prosedürü: tek yazıcı, önce yedek (`backup/…PRE-REGEN.sql`), yalnız public, doğrulama kapısı (fn sayısı birebir), Yöntem A (pg_dump) / B (katalog dump) |
| `scripts/ground-truth-audit.sh` | — | Canlı ↔ GT envanter karşılaştırma aracı (tablo/view/fn/trigger; altyapı tablolarını hariç tutar) — **hazır ama prosese bağlanmamış** |
| `scripts/db-dry-run.sh` | — | Migration'ı Neon şema aynasında BEGIN/ROLLBACK ile canlıya dokunmadan deneme aracı |
| `.harness/goals/2026/G-20260906-TOPLU-VAKA.md` | :24, :316-324 | Pratiğin iyi örneği: GT sync goal write_manifest'ta; GT eksikleri canlı probe ile çözüldü |

**Boşluk (kuralın cevaplamadığı sorular):**
- Migration **uygulama kanalı** tanımlı değil: supabase CLI `db push` mu, psql mi,
  Mgmt API mi? Her kanal farklı kayıt davranışı taşır (§5).
- `schema_migrations` kaydı hiçbir belgede adım değil.
- GT yenileme, uygulama akışının bir adımı değil; yalnız izole regen emri (2026-06-13)
  ve goal bazlı "GT sync" alışkanlığı var (bu alışkanlık da zorunlu değil — §3'te
  17 dosyalık kanıt).
- "Belge önce, merge sonra" ifadesi kelimesi kelimesine hiçbir yerde geçmiyor;
  en yakın karşılığı docs-update pre-commit (belge değerlendirmesi commit anında)
  — bu da DB tarafına taşınmamış.

## 3. Nerede işletilmedi? (Bulgu 2)

### 3.1 GT senkron zaman çizelgesi (git kanıtı)

| Tarih | Commit | Ne yaptı |
|---|---|---|
| 2026-06-13 | (emir raporu) | GT regen prosedürü yazıldı (Pi'ye emir); tam regen kayıtları git'te izlenemiyor (idle-reports gitignore'da) |
| 2026-06-25/26 | `fa4d6c8`, `659e4a0`, `aec2146` | GT **parçalı onarım** + reconcile (dogum gövde, 6 tablo, view, 10 fn, gorev_log objeleri) |
| 2026-07-17/18 | `5c3bfd0`, `88ece42` | padok sync + "reconcile ground truth inventory" |
| 2026-07-22 | `85a6762` | tohumlama_son_kayit GT ile |
| 2026-09-01 | — | gt-v5-audit: **22 sapma, "GT v5 regen GEREKLİ"** — regen yapılmadı |
| 2026-09-01 | `3f1e57f` | ikiz doğum GT sync |
| 2026-09-06 | `9a89e15` → `32f73b9` (5 commit) | vaka_toplu_ac serisi + GT sync — **GT'nin son değişimi** |
| 2026-09-09 → bugün | — | **18 dosya GT'siz** (dozaj, sperma, buzagi, pedigree, L2/L4) |

### 3.2 GT'de nesnesi olmayan migration dosyaları (isim düzeyi, `gt-tablo.py`)

Kapsam: `supabase/migrations/20260[6-9]*.sql` = 134 dosya (benim dal). 117'sinin
tüm fn/tablo/view adları GT'de var; **17'sinde en az bir nesne GT'de yok:**

| Dosya | fn | tablo | view | GT'de olan | Not |
|---|--:|--:|--:|--:|---|
| `20260621000001_agent_threads` | 0 | 2 | 0 | 0/2 | agent altyapı — audit script de INFRA sayıp hariç tutuyor (bilinçli olabilir) |
| `20260621000004_agent_prune_cron` | 1 | 0 | 0 | 0/1 | aynı (INFRA fn) |
| `20260622000001_agent_plans` | 1 | 1 | 0 | 1/2 | aynı (INFRA tablo) |
| `20260722000002_sablon_planli_tohumlama` | 3 | 0 | 0 | 1/3 | eksik |
| `20260722000003_planli_tohumlama_bagimsiz_event` | 2 | 0 | 0 | 0/2 | eksik |
| `20260730000001_sablon_tohumlama_opsiyonel_ve_yasam_dongusu` | 6 | 0 | 0 | 4/6 | eksik |
| `20260730000002_vaka_tohumlama_ekle` | 3 | 0 | 0 | 0/3 | gt-v5-audit #11'de de "GT'de YOK" |
| `20260831000003_tablo_guard_triggerlari` | 3 | 0 | 0 | 0/3 | gt-v5-audit #1-3'te de "GT'de YOK"; prod'da KISMİ→Adım A ile CANLI |
| `20260902000003_asi_planli_gorev` | 4 | 0 | 0 | 1/4 | eksik |
| `20260902000004_asi_toplu_gorev` | 2 | 0 | 0 | 0/2 | eksik |
| `20260909000001_sablon_aktif_vakaya_uygula` | 2 | 0 | 0 | 1/2 | eksik |
| `20260909110000_dozaj_helper_min_max_rpc` | 2 | 0 | 0 | 0/2 | Adım A ile prod CANLI, GT yok |
| `20260910000001_planli_tohumlama_sperma_dus` | 1 | 0 | 0 | 0/1 | Adım A ile prod CANLI, GT yok |
| `20260911000001_dogum_buzagi_id_foundation` | 2 | 0 | 0 | 1/2 | kolon/FK yok; GT'deki `v_buzagi_id` eski dogum_kaydet gövdesinin lokal değişkeni (bayat sürüm işareti) |
| `20260911000002_pedigree_foundation` | 8 | 4 | 0 | 0/12 | Adım A ile prod CANLI, GT yok |
| `20260911000003_pedigree_farm_backfill` | 3 | 0 | 0 | 0/3 | aynı |
| `20260911000004_pedigree_projection_rpc` | 2 | 0 | 0 | 0/2 | aynı |

Ek olarak (benim dalda dosyası olmayan, entegrasyon dalında): L2 `20260913000001..04`
ve L4 `20260914000001..04` = 8 dosya — GT'de `degisim_log`, `surum_gizli`,
`_islem_log_degisim_txid`, `sahip_sifresi_ayarla` **hiçbiri yok** (0 eşleşme).

Yöntem notu: sayım `CREATE FUNCTION/PROCEDURE/TABLE/VIEW <şema>.<ad>` adlarını
dosyadan çıkarıp GT metninde aynı desende arar (isim varlığı; **gövde eşitliği
iddiası değildir** — gövde sapmaları gt-v5-audit'in 22 satırlık tablosundadır ve
o tablo da regen bekliyor).

### 3.3 Prod uygulama izi (P1 + bugünkü işler)

Kaynaklar: `reports/2026-09-15-prod-migration-olcum.md` (P1, entegrasyon dalı),
`reports/2026-09-15-prod-adim-a.md` (Adım A), `reports/2026-09-15-prod-5-tohumlama.md`,
`reports/2026-09-15-tohumlama-kaydet-drift.md` §5.1.

| Zaman | Ne oldu | Kayıt (schema_migrations) |
|---|---|---|
| ≤ 2026-05-31 | 124 migration dosyası uygulandı (Mart `20260303000001`'den itibaren) | **124/124 kayıtlı** (kayıt örnekleri dosya adlarıyla aynı formatta; GT dosyası kayıt değil, o 125. dosyadır) |
| 2026-06 → 2026-09-08 | 126 dosya elle (psql) uygulandı; kanıt: P1 ölçümü (20260902000001'e kadar CANLI), drift raporu §5.1 "migrasyonlar bu projede elle (psql) uygulanıyor" | **0 kayıt** |
| 2026-09-15 Adım A | 9 dosya (P1'deki KISMİ/EKSİK'lerin tamamı, `#5` hariç) Mgmt API `BEGIN; dosya; COMMIT;` ile uygulandı | **0 kayıt** (raporun kendisi de adım listesinde kayıt içermiyor) |
| 2026-09-15 #5 | P3 kararıyla beklemede → (varsayım: Adım B ile uygulanacak) | 0 kayıt (varsayım sonrası: eklenecek) |
| 2026-09-15 Adım B (paralel) | L2 4 + L4 4 dosya prod'a uygulanıyor (varsayım: tamam) | 0 kayıt |

**Net:** kayıt disiplini 2026-05-31'e kadar bir araçla (kayıtlar repo dosya
adlarıyla birebir aynı formatta: `YYYYMMDDNNNNNN`) işletiliyordu; Haziran'dan
itibaren uygulama kanalı elle/psql/Mgmt API'ye geçti ve **kayıt + GT yenileme
adımları kanalla birlikte düşmedi — hiçbir belgede adım olmadığı için hiç
duyulmadı.**

## 4. GT nasıl üretiliyor? (Bulgu 3)

- **Yazılı prosedür:** `docs/2026-06-13-emir-raporu-ground-truth-regen.md`
  (Yöntem A: pg_dump şema-only; Yöntem B: katalog sorgularıyla birleştirme;
  §6 doğrulama kapısı: canlı fn sayımı ↔ dosya sayımı birebir; yedek kuralı:
  `backup/99999999999999_ground_truth.PRE-REGEN.sql`).
- **Denetim aracı (hazır):** `scripts/ground-truth-audit.sh` — canlı envanter
  (tablo/view/fn/trigger) ↔ GT karşılaştırması; altyapı tablolarını
  (`agent_*`, `chat`, `code_embeddings`, `entity_graph`, `goose_embeddings`,
  `memory_notes`, `tasks`, `_regen_fndefs` + 4 INFRA fn) kapsam dışı bırakır.
- **Kuru-deneme aracı (hazır):** `scripts/db-dry-run.sh` — migration'ı Neon
  aynasında BEGIN/ROLLBACK ile dener (42703/42P01/… hata kodları).
- **Son içerik değişimi:** `32f73b9` (2026-09-06). Dosya başlığındaki
  `Tarih: 2026-05-13` **bayat** — başlık regen'lerde güncellenmiyor (ayrı bulgu:
  GT'ye bakıp tarih okuyan biri yanılır).
- **Son tam regen:** kayıtla doğrulanamıyor. Başlık 2026-05-13; 2026-06-13 regen
  emri verildi; sonraki GT commit'leri parçalı onarım/reconcile/elle sync. En net
  kanıt: gt-v5-audit (2026-09-01) "GT **regen edilmedi** — bu dosya yalnız
  denetim tablosudur" + 22 sapma + "GT v5 regen GEREKLİ (denetimli oturum)".
- **Canlı fark (ölçüm anı 2026-09-15, Adım B öncesi, salt okunur):**

| Ölçü | Canlı | GT dosyası | Fark |
|---|--:|--:|---|
| tablo (public, BASE TABLE) | 52 | 40 | canlıda +12 (pedigree 4, agent altyapı ~7, GT'de olmayan diğerleri) |
| fonksiyon+prosedür (public) | 212 | 184 | canlıda +28 (pedigree 13, dozaj 2, sperma helper 1, guard 3, agent, …) |
| view | 13 | 15 | GT'de +2 bayat view |
| trigger (non-internal) | 33 | 33 | eşit |
| `surum_gizli` şeması | 0 (Adım B henüz yok) | GT kapsamı dışı | L2 sonrası kararı gerek (§7c) |
| `schema_migrations` | n=124, max `20260531400000` | — | donuk |

GT yapısı: dosya `…99999999999999_ground_truth.sql`, 11.992 satır, başlığı
"REFERANS, CALISTIRMAYIN"; `supabase/migrations/backup/` içinde tek önceki sürüm
(`20260610000001_bug064…WRONG-11param-v1.sql` — migration revizyon arşivi).
Dikkat: dosya migration dizininde durduğu için **supabase CLI `db push`
kullanılırsa GT'yi de uygulamaya kalkar** (§7b notu).

## 5. Kayıt tablosu: araç, durma nedeni, kayıtsız-CANLI liste (Bulgu 4)

- **Yapı (canlı, salt okunur):** `supabase_migrations.schema_migrations(version text
  NOT NULL, statements text[] NULL, name text NULL, created_by text NULL,
  idempotency_key text NULL, rollback text[] NULL)` — Supabase CLI'ın kendi tablosu.
- **Hangi araçla doldu:** ≤2026-05-31 kayıtlar repo dosya adlarıyla birebir aynı
  formatta (`20260303000001…20260531400000`); bu, kayıtların bir CLI/araç
  (supabase CLI `db push` uyumlu) akışından geldiğini gösterir. Sonraki uygulama
  kanalı psql (drift raporu §5.1 kanıtı) ve bugün Mgmt API (Adım A) — ikisi de
  tabloya yazmaz.
- **Neden durdu (2026-05-31 sonrası):** uygulama kanalının CLI'dan elle psql'e
  geçmesi + kayıt adımının hiçbir belgede olmaması (§2 boşluk). Supabase CLI'nın
  `db push`'ı bu repo'da artık kullanılamaz durumda da: 142 uygulanmış sürüm
  kayıtsız olduğu için CLI bunları "uygulanmamış" görür ve yeniden çalıştırmaya
  kalkar; ayrıca GT dosyası aynı dizinde (§4 notu).
- **Kayıtsız ama CANLI olacak dosyalar (önerinin hedef listesi = §7b):**
  - P1 seti (20260830..20260914, 36 dosya): Adım A sonrası 26 CANLI + `#5` (Adım B ile)
    + L2/L4 8 dosya (Adım B) → varsayım dahil 36/36 CANLI olacak.
  - Haziran–Ağustos (20260601..20260828): 98 dosya — kanıt: P1 teşhisi (ör.
    `gebelik_kaydet_manual` prod'da `20260605000002` sürümü CANLI), drift raporu §5.1
    ("prod 36-dosya setinin 20260902000001'e kadar olan kısmını fiilen almış"),
    ve 124→124 dönem ayrımı. Bu aralık için dosya-başı CANLI kanıtı tek tek
    ölçülmedi (kapsam dışıydı) — §7b adım 1'de tek seferlik probe önerilir.
  - Toplam önerilen kayıt: **142 sürüm** (134 benim-dal dosyası + 8 L2/L4;
    `20260902000001` dahil — N/A-uygulamalı ama CANLI).

## 6. Kök neden

1. **Kanal dağıldı, adım listesi yoktu.** Uygulama CLI → psql → Mgmt API'ye
   üç kez değişti; her değişimde kayıt ve GT adımları kanala bağlıydı ama
   belgelenmemişti, bu yüzden hiçbir değişim onları taşımadı.
2. **"Bitti" tanımı dar.** Sözleşmenin kabul kapıları commit/push düzeyinde
   güçlü (acceptance.md) ama DB tarafını "push ≠ deploy" ile sınırlandırıp
   deploy sonrası kanıtı (kayıt + GT) tanımlamıyor; raporlar da "CANLI"yı
   doğrulayınca işi bitmiş saydı.
3. **GT'nin rol çatışması bakımı düşürdü.** "Live schema tek otorite" kuralı
   doğru; ama yan etkisi GT'nin "artık otorite değil → bakmaya değer değil"
   okunması oldu. GT'nin gerçek rolü — sıfırdan kurulum referansı + RPC imza
   kaynağı + drift dedektörü — hiçbir belgede yazılı değil (rpc-reference.md:8-17
   ve gt-v5-audit bunu fiilen kullanıyor).
4. **Araçlar prosese bağlanmamış.** `ground-truth-audit.sh` ve `db-dry-run.sh`
   hazır ama hiçbir adım listesi onları çağırmıyor; `veri-eslesme-kontrol.py hepsi`
   (P6) yalnız veri düzeyini kapsıyor.

## 7. Öneri (yalnız belge — hiçbiri koşulmadı)

### (a) Migration uygulama runbook'u

Yeni dosya: `.harness/runbooks/db-migration.md`. Adım sırası (her adımın kanıtı
rapora yazılır; ilk hata önceki adıma döndürür):

| # | Adım | Kanıt | Araç |
|---|---|---|---|
| 1 | **Belge önce:** migration dosyası + gerekçe + geri dönüş notu commit'e hazır; goal/rapor bağlantısı | dosya + diff | — |
| 2 | **Yedek:** etkilenen tabloların satır bazlı yedeği (repo dışına, Adım A yöntemi); yüksek riskli (DROP/RENAME) işlerde şema tanımları da | yedek dizini + manifest sha256 | Mgmt API SELECT |
| 3 | **Kuru koşu:** migration aynada BEGIN/ROLLBACK ile denenir; 42703/42P01/42710 kodları sıfır | betik çıktısı | `scripts/db-dry-run.sh` |
| 4 | **Uygula:** `BEGIN; <dosya>; COMMIT;` tek transaction (Mgmt API); dosyanın kendi BEGIN/COMMIT'i varsa betik durur | ham yanıt | Adım A yöntemi |
| 5 | **Kayıt:** aynı oturumda `schema_migrations` INSERT (§7b şablonu); kayıt yoksa uygulama "bitti" sayılmaz | SELECT ile okunan satır | Mgmt API |
| 6 | **GT yenileme:** bu migration'ın eklediği/değiştirdiği objeler GT'ye eklenir (ya da tam regen §7c); başlıktaki Tarih alanı güncellenir | GT diff + commit | emir raporu §5-6 |
| 7 | **Doğrulama + merge:** `scripts/ground-truth-audit.sh` (şema) + `scripts/veri-eslesme-kontrol.py hepsi` (veri) + kritik fn için gövde md5 probe (P1 yöntemi) → rapor → merge | betik çıktıları | — |

Kural: **4-5 ve 6 ayrılmaz üçlüdür** — uygulayan oturum, kaydı ve GT senkronunu
aynı teslimde getirir; getiremiyorsa raporda açık "bakiye" olarak listeler.

### (b) Mevcut kayıt açığını kapatma planı (SQL taslağı — KOŞULMAZ)

Sıra: (1) Haziran–Ağustos aralığı için tek seferlik CANLI probe (P1 yöntemi) →
(2) hedef listeyi dosya adlarından üret → (3) tek batch INSERT, tek transaction →
(4) sayım doğrulaması (`SELECT count(*)` = beklenen; `max(version)` = `20260914000004`).

Hedef liste: `supabase/migrations/20260601000001…20260914000004` aralığındaki
**142 dosya** (benim dal 134 + L2/L4 8; GT dosyası hariç; `backup/` hariç).
Adım B + `#5` prod'a girmeden bu kayıt eklenmez (kayıt, "uygulandı" demektir).

```sql
-- TASLAK — koşulmaz. Üretici (repo kökünde):
--   ls supabase/migrations/202606*.sql supabase/migrations/202607*.sql \
--      supabase/migrations/202608*.sql supabase/migrations/202609*.sql \
--   | her ad için: (version = adın ilk 14 karakteri, name = dosya adı)
BEGIN;
INSERT INTO supabase_migrations.schema_migrations
  (version, name, statements, created_by, idempotency_key, rollback)
VALUES
  ('20260601000001', '20260601000001_buzagi_toplu_giris.sql', NULL,
   'root:elle-kayit-2026-09-15 (P1+AdimA+AdimB kanıtlı)', NULL, NULL),
  -- … 142 satır (ls'den üretilir) …
  ('20260914000004', '20260914000004_l4_stok_uyari_txid.sql', NULL,
   'root:elle-kayit-2026-09-15 (P1+AdimA+AdimB kanıtlı)', NULL, NULL);
-- doğrulama
SELECT count(*) FROM supabase_migrations.schema_migrations;   -- beklenen 124+142=266
SELECT max(version) FROM supabase_migrations.schema_migrations; -- 20260914000004
ROLLBACK; -- taslak; gerçek koşuda ROLLBACK yerine COMMIT
```

Notlar:
- `statements=NULL` geçerli (sütun NULLable); CLI ileride `db push` yaparken
  yalnız `version`a bakar, içerik karşılaştırmaz. İstenirse `statements` daha
  sonra dosya içeriklerinden doldurulabilir — zorunlu değil.
- `20260902000001_asi_stok_backfill.sql` (P1: N/A-DML, prod'da uygulanmış) da
  listeye dahildir — kayıt "çalıştırıldı" anlamındadır, tekrar çalıştırma değildir.
- Demo (n=2) ayrı karardır: demo prod'a girmeyen işlerin test ortamı olduğundan
  demo kayıtlarının nasıl tutulacağı (ör. yalnız gerçekten demo'ya uygulananlar)
  sahibin kararı; bu rapor önermez.
- Risk notu: kayıt eklendikten sonra supabase CLI `db push` bu sürümleri
  "uygulanmış" sayar — istenen davranış bu. Ancak GT dosyası dizinden
  çıkarılmadan/isimlendirilmeden CLI akışı yeniden devreye alınmamalı
  (`99999999999999` sürümü push'a girer). Uzun vade: GT'yi
  `supabase/reference/` gibi migration dışı bir yola taşımak değerlendirilmeli
  (karar sahibin).

### (c) GT yenileme prosedürü ve ilk yenilemenin kapsamı

**Prosedür** (mevcut emir raporunu geçerli sayar + üç ek):
1. `docs/2026-06-13-emir-raporu-ground-truth-regen.md` §2-§6 aynen: tek yazıcı,
   önce `backup/99999999999999_ground_truth.PRE-REGEN.sql` yedeği, Yöntem A
   (pg_dump; bugün Adım A'nın kanıtladığı pooler erkeşimi var) tercih,
   doğrulama kapısı geçilmeden "bitti" yok.
2. **Ek 1 — kapsam:** `public` + `surum_gizli` (L2 gizli şeması artık canlı;
   fn gövdeleri zaten repoda `20260913000002` içinde — yeni ifşa yok). Altyapı
   tabloları/fn'leri `ground-truth-audit.sh` INFRA listesiyle hariç kalır.
   (İhtiyatlı alternatif: yalnız `public` tutup `surum_gizli`'yi ayrı bir
   `…_ground_truth_gizli.sql`'e koymak — karar sahibin.)
3. **Ek 2 — başlık disiplini:** dosya başlığındaki `Tarih:` üretim tarihiyle
   güncellenir; `Üretim:` satırı yöntem + ölçüm anı yazar (2026-06-13 emrindeki
   başlık şablonu zaten bunu ister — uygulanmamıştı).
4. **Ek 3 — prosese bağlama:** regen sonrası `ground-truth-audit.sh` sıfır fark
   vermeden teslim yok; gt-v5-audit'in 22 sapması ("regen GEREKLİ" işaretli)
   tek tek kapalı sayılır.

**Zamanlama:** ilk regen **Adım B + `#5` prod'a girdikten ve §7b kayıtları
eklendikten sonra** yapılmalı; aksi halde GT anında bayatlar ve aynı açığın
içinde yeni bir katman oluşur. Regenden önce kayıt eklemek de mantıklıdır:
kayıt tablosu "hangi sürümler uygulandı"yı sabitler, regen "canlı neye
benziyor"u dondurur — sıra: kayıt → regen.

**İlk yenilemenin beklenen kapanışı:** canlı sayım (52T/212F+AdımB fn/13V/33Trg
+ `surum_gizli`) ↔ GT sayımları birebir; 17 dosyalık eksik liste (§3.2) boşalır;
bayat 2 view GT'den düşer.

### (d) Kuralın yazılacağı belgeler (önerilen metin farkları olarak)

1. **`.harness/contract.md`** — "EgeSut product invariants" listesine, mevcut
   `:104` satırının ("A migration file in Git is not evidence of deployment.")
   hemen arkasına:

   ```diff
   - A migration file in Git is not evidence of deployment.
   +- A migration file in Git is not evidence of deployment.
   +- A migration is deployed only through the DB runbook
   +  (`.harness/runbooks/db-migration.md`): documentation first, then backup,
   +  apply, `schema_migrations` record, ground-truth refresh, verification,
   +  merge. An applied migration without a record or a current ground truth
   +  is an incomplete deployment and must be reported as a balance.
   ```

2. **`.harness/acceptance.md`** — "Deploy and DB" bölümüne (`:70-72` sonrası):

   ```diff
    Push is not deploy. A migration commit is not a DB mutation. Live
    deployment, DB writes, and destructive actions each require their own
    explicit gate and evidence from the owning environment.
   +  Deployment evidence includes the `schema_migrations` record for the
   +  applied version and the ground-truth refresh step from the DB runbook.
   ```

3. **YENİ `.harness/runbooks/db-migration.md`** — §7a tablosunun tam metni
   (adımlar, kanıtlar, araçlar, "4-5-6 ayrılmaz üçlü" kuralı).

4. **`.harness/docs-update.md`** — "Surface names" tablosuna iki satır
   (migration değişikliği değerlendirme listesine kayıt ve GT'yi ekler):

   ```diff
   | `deploy_boundary` | the report's deploy record; push is not deploy |
   +| `migration_registry` | `schema_migrations` record evidence for applied versions |
   +| `ground_truth` | `supabase/migrations/99999999999999_ground_truth.sql` refresh state |
   ```

   ve `:38` satırındaki zorunlu yüzey listesine bu ikisinin eklenmesi.

5. (Opsiyonel) `docs/2026-06-13-emir-raporu-ground-truth-regen.md` başına bir
   "üstüne yazılmıştır" notu: "Bu emrin §2-§6 prosedürü
   `.harness/runbooks/db-migration.md` adım 6'sına bağlanmıştır; dosya
   tarihsel kalır." — emir raporunun runbook'a referansı olur.

---

## 8. Sınırlar — ne yapamadım / doğrulayamadım

1. **Adım B tamamlanma durumu canlıda doğrulanmadı:** ölçüm anımda `surum_gizli`
   şeması prod'da 0 idi (Adım B henüz ulaşmamış). Öneriler zarf varsayımıyla
   (Adım B + `#5` bitti) yazıldı; kayıt-batch (§7b) koşulmadan önce canlının
   son durumu tek seferlik probe ile teyit edilmelidir.
2. **Haziran–Ağustos aralığının dosya-başı CANLI kanıtı tek tek ölçülmedi**
   (P1 yalnız 20260830+ setini ölçtü). Aralık için toplu kanıt: P1 teşhis satırları
   + 124/124 ↔ 0/142 dönem ayrımı; §7b adım 1'de tek seferlik tam probe önerildi.
3. **2026-06-13 regen emrinin gerçekleşip gerçekleşmediği kayıtla kanıtlanamadı**
   (idle-reports gitignore'da); §4'teki timeline git'te izlenebilen commit'lerle
   sınırlıdır.
4. Demo `schema_migrations` (n=2) için öneri üretilmedi — karar sahibin (§7b notu).
5. GT içerme sayımı isim düzeyindedir; gövde düzeyi sapma envanteri gt-v5-audit'in
   (2026-09-01) 22 satırlık tablosudur ve bu rapor onu yeniden ölçmedi.

## 9. Öneri dışı hiçbir eylem alınmadı

Bu teslimde: `supabase/migrations/` ve GT dosyası değişmedi; prod/demo'ya yazma
yok; `schema_migrations`'a kayıt yok. Değişen tek izlenen dosya bu rapordur
(`reports/`, `git add -f` ile). Ölçüm betikleri `.ss/` altında dalda kalır
(commit dışı).
