# Rapor — G-20260910-UREME-STOK-BUGFIX (lead teslimi)

Dal: `idle/ureme-stok-bugfix` · Base: `38c3b07` (main ucu; goal `base_sha`
a3d8bc2 = base'in ebeveyni — dal ff ile main ucuna alındı, kayıp yok)
· Tarih: 2026-09-10 · Lead: GLM (ureme-bugfix workspace) · Kol: 3× GLMF
worker (W1/W2/W3) + 1× Codex review (gpt-5.6-luna max)

## Başlık bulgular

1. **BUG-001 YANLIŞ ALARM (refuted).** Goal'in "canlı planli düşüm yapmıyor"
   önkabulu yanlıştı: canlı `planli_tohumlama_kaydet` gövdesi koşulsuz
   `public.tohumlama_kaydet(...)`'e delege ediyor (gövde satırı:
   `v_result:=public.tohumlama_kaydet(...)`); düşüm delegasyonla gerçekleşiyor.
   Root'un leksik probu (gövdede `stok_hareket` aramak) delegasyonu göremedi.
   Kanıt: W1 demo davranışsal probe (planli çağrı → 1 stok_hareket satırı) +
   lead bağımsız canlı gövde okuması. Sonuç: planli'ye düşüm EKLENMEDİ
   (eklenseydi M2 sonrası çift düşüm); sertleşmiş kuralı delegasyonla miras
   alıyor.
2. **BUG-002 fixed** — üç yol tek kuralda (`fn_sperma_stok_dus`), boş ad hiç
   düşürmez, exact önce, notlar içeriği (kupe_no / "Tekrar Aşım N. deneme")
   canlıyla birebir korunur.
3. **BUG-003 fixed** — `gebelik_kaydet_manual` gövdesinde `v_tohumlama_id text`
   ↔ `tohumlama.id uuid` uyuşmazlığı; 3 noktalık minimal tür düzeltmesi
   (canlı `tohumlama.id` uuid — bağımsız doğrulandı).

## Teslintteki artefaktlar (dalda)

| Dosya | Yazar | İçerik |
|---|---|---|
| `supabase/migrations/20260910000001_planli_tohumlama_sperma_dus.sql` | W1 + W2b | `fn_sperma_stok_dus(p_sperma, p_notlar DEFAULT NULL)` helper FİNAL biçimi: boş/whitespace (`^\s*$`) hiç düşürmez, exact önce, substring fallback, notlar içeriği canlıyla birebir; DROP yok, CREATE OR REPLACE |
| `supabase/migrations/20260910000002_sperma_eslesme_sertlestirme.sql` | W2 + W2b + lead | iki CREATE tek `DO` bloğunda (atomik, dry-run uyumlu): `tohumlama_kaydet` + `tohumlama_tekrar_kaydet` inline INSERT → `PERFORM fn_sperma_stok_dus(...)` (notlar birebir); DROP yok, SET yok |
| `supabase/migrations/20260910000003_gebelik_kaydet_manual_42804_fix.sql` | W3 | gebelik gövdesi text→uuid düzeltmesi (3 nokta) |
| `tests/sql/sperma_stok_dus_test.sql` | W1 + W2b | helper davranışı K1-K5 + tab/newline/CR vakaları |
| `tests/sql/sperma_eslesme_test.sql` | W2 + W2b | üç yol uçtan uca K1-K6 (çift-düşüm guard; mutant-taramaya dayanıklı seed sırası) |
| `tests/sql/gebelik_kaydet_manual_test.sql` | W3 | çağrı + guard + iki tabloya yazım testi |

**Tasarım evrimi (2 tur):** W2 ilk teslimde helper'ı M2 içinde
DROP+CREATE ile `p_notlar DEFAULT NULL` imzasına taşıdı (gerekçe ölçümlü:
canlı notlar içeriği kupe_no/"Tekrar Aşım N. deneme" taşıyor — sabit notlar
denetim izini kaybettirirdi; W1 tesliminin yakalanmamış kusuru). Bağımsız
review bu DROP tabanlı yapıda 4 kusur buldu (aşağıda B2-B5); lead kararıyla
helper FİNAL hali M1'e taşındı, M2 saf rewiring oldu — DROP/SET tamamen
kalktı, M2 kendi içinde BEGIN/COMMIT ile atomik.

## Kabul koşuları — komut ve çıktılar

1. **planli düşümü** — goal'in "(before the fix: no change)" önkabulu REFUTED
   (başlık bulgu 1); fix sonrası uçtan uca: W2 fixture K5 (planli çağrısı →
   tam 1 düşüm, exact satır korunur — çift düşüm guard). Komut (lead koşumu):
   `psql "$DATABASE_URL" -f tests/sql/sperma_eslesme_test.sql` → `BEGIN/DO/ROLLBACK`, exit 0.
2. **Boş sperma üç yolda satır üretmez** — aynı fixture K1 (kaydet) + K3
   (tekrar) + K5 (planli/delegasyon): exit 0.
3. **Exact öncelik** — W1 fixture K2 + W2 fixture K2/K4 (superstring satırına
   sıçrama yok): exit 0.
4. **gebelik kırmızı→yeşil** —
   - Kırmızı (lead bağımsız yeniden üretim, canlı kırık gövde demo'da
     BEGIN/ROLLBACK içinde): `NOTICE: RED-YAKALANDI SQLSTATE=42804 MSG=column
     "id" is of type uuid but expression is of type text` (PROD hatasıyla
     aynı sınıf/metin). Script: lead `verify/red_repro.sql` (kanıt
     kırıntısı `verify/red_repro.sql + psql ciktisi`).
   - Yeşil: `psql "$DATABASE_URL" -f tests/sql/gebelik_kaydet_manual_test.sql`
     → PASS×3 (çağrı + tohumlama/islem_log satırları + guard reddi), ROLLBACK, exit 0.
5. **Dry-run (Neon aynası)** — `bash /home/melik/egesut-erp1/scripts/db-dry-run.sh
   <migration>` final dosyalarla: M1 exit 0 (`M1b.dryrun.log`), M2 exit 0
   (`M2c.dryrun.log`), M3 exit 0 (`M3.dryrun.log`). (Script ana checkout'ta
   untracked — bkz. açık kalemler.)
6. **Unit** — `npm run test:unit` → 736 pass / 1 fail; tek kırmızı
   `tests/unit/gecmis-pipeline.test.js` (_gmGroupHtml 'DÜN' assert) **main'de
   de aynı şekilde kırmızı** (base 38c3b07'de leadçe ölçüldü) — bu görevden
   kaynaklı YENİ kırmızı yok.
7. **BUGS.md durumları** — bu commit ile: BUG-001 `[refuted]`, BUG-002/003
   `[fixed-pending-deploy]`.

## Canlı doğrulamalar (salt-okunur, Mgmt API)

- `planli_tohumlama_kaydet` gövdesi: koşulsuz delegasyon satırı teyit.
- `tohumlama.id` veri tipi: `uuid` (GT'deki `text` bilinen drift, SMELL-003).
- Canlı `tohumlama_kaydet` stok INSERT'i tam 5 kolon
  `(stok_id, tur, miktar, notlar, iptal)` — helper aynı şekil.
- İki legacy gövdenin M2 kopyalarıyla unified diff'i: yalnız INSERT→PERFORM
  hankleri (notlar dahil birebir).

## Demo DB durumlandırması

- Kalıcı uygulanan (owner kuralı gereği serbest): M1 (W1), M2 (lead), M3 (W3)
  — şema değişikliği, test verisi değil.
- Kalıcı test satırı: YOK — tüm fixture'lar BEGIN/ROLLBACK; W3 temizlik
  sağlaması `__TEST_GEBELIK_MANUEL% = 0` (üç tablo), W1/W2 fixture'ları
  transaction-içi seed.
- Lead doğrulama araçları: `~/tmp/agents/lead-ureme-stok/verify/` (dalda değil,
  makinede): M1/M2/M3.sql kopyaları, dry-run logları, red_repro.sql,
  canlı gövde dökümleri.

## Bağımsız review (Codex, gpt-5.6-luna max; farklı CLI + model — terminal altbilgisinden teyitli)

Oturum: ws `3f0ca24e`, dal `idle/ureme-stok-bugfix-r2` commit `807282a`
(merge EDİLMEDİ; bulgular `.review-findings.md` olarak dalından okundu).
Girdi: zarf + `git diff 38c3b07..HEAD` (yazar özeti yok). Review davranışsal
doğrulama da yaptı (demo'da mutant/probe koşuları, PROD salt-okunur gövde
ölçümleri, gövdeleri INSERT'e geri-çevirip canlıyla birebir eşleme).

**Bulgular ve çözümleri (9 bulgu):**

| # | Sınıf | Bulgu (özet) | Çözüm |
|---|---|---|---|
| B1 | doc-drift | BUGS.md hâlâ `[open]` (kabul 7 literal FAIL) | By-design: durum düzenlemesi tek yazıcı (lead) final commit'inde — bu commit'te işlendi |
| B2 | race-lifecycle | M1-replay M2 sonrası çift overload → 42725 (demo'da ölçüldü) | W2b: helper final imzası M1'e taşındı; DROP kaldırıldı; replay kısıtı: demo'da M1 üst üste 2× → `pg_proc` sayısı 1 (leadçe ölçüldü) |
| B3 | ACL/owner | DROP FUNCTION eski ACL/owner'ı siler (grant kaybı demo'da ölçüldü) | W2b: DROP tamamen kalktı — yalnız CREATE OR REPLACE |
| B4 | silent-success | `SET client_min_messages=WARNING` oturuma sızıyor (demo'da SHOW ile ölçüldü) | W2b: satır tamamen kaldırıldı |
| B5 | race-lifecycle | M2 dosyası autocommit adımlarıyla kısmi şema bırakabilir | W2b: M2 `BEGIN;...COMMIT;` ile kendi içinde atomik |
| B6 | doğruluk | `btrim` tab/newline kırpmez — `E'\t'` sperma 1 düşüm üretti (demo'da ölçüldü) | W2b: guard `p_sperma ~ '^\s*$'`; fixture'a tab/newline/CR vakaları eklendi |
| B7 | doc-drift | fixture başlığındaki çalıştırma yolu bayat | W2b: yorum düzeltildi |
| B8 | fake-arm | fixture seed sırası exact-precedence mutantını gizleyebilir | W2b: superstring seed'i önce + tekil adlı İlaç negatifi |
| B9 | doc-drift | goal `base_sha` alanı (a3d8bc2) gerçek review range'inden (38c3b07) farklı | Root kalemi — açık kalem 5b (aşağıda) |

Review'in kabul yargıları: 1-4 PASS (4'ün pre-fix kısmı INCONCLUSIVE'di —
lead `red_repro.sql` ile kapattı: canlı kırık gövdeden `SQLSTATE=42804` demo'da
yeniden üretildi); 5 INCONCLUSIVE (review oturumunda Neon yanıtsız — lead
dry-run'ları aşağıda, üçü exit 0); 6 FAIL (tek kırmızı `gecmis-pipeline` —
base'te de kırmızı, leadçe ölçüldü; yeni kırmızı yok); 7 FAIL → bu commit ile
kapanır (BUGS.md). Düzeltme turu W2b'ye tek turda döndü; doğrulaması mekanik
kapılarla yapıldı (ikinci review turu açılmadı — hata sınıfı değişmedi).

## W2b düzeltme turu — lead doğrulama kanıtları

- `grep -cE "DROP FUNCTION" 2026091000000{1,2}_*.sql` → 0, 0; `grep -c client_min_messages M2` → 0.
- Demo zinciri: M1b uygula → M2 uygula → M1b REPLAY → `fn_sperma_stok_dus`
  pg_proc sayısı = **1** (B2 kapanışının ölçümü).
- İki fixture demo'da exit 0 (tab/newline vakaları dahil).
- `npm run test:unit` → 736/737 (base kalıbı).
- Dry-run (Neon): M1/M2/M3 final → exit 0 ×3 (loglar
  `~/tmp/agents/lead-ureme-stok/verify/`).

**Lead inline düzeltmesi (dar iş istisnası, W2b tesliminden sonra):** W2b'nin
M2'si dosya içi `BEGIN;...COMMIT;` ile atomikleşmişti; lead dry-run kapısı bu
haliyle KIRMIZI yakaladı — `db-dry-run.sh` dosyayı kendi `BEGIN; -f -c
ROLLBACK` sarmasıyla koştuğu için içteki BEGIN/COMMIT 25001/25P01 üretiyor ve
içteki COMMIT dıştaki transaction'ı kapatıyordu (`M2b.dryrun.log`). Çözüm
(lead, ~10 satır): iki CREATE tek **DO bloğuna** alındı — tek statement olarak
hem tek başına atomik (B5 korunur) hem dry-run sarmasıyla uyumlu
(`M2c.dryrun.log` exit 0). Düzeltme sonrası demo yeniden uygulandı + fixture
yeniden koşuldu (exit 0).

## Açık kalemler (root)

1. `scripts/db-dry-run.sh` (+ `refresh_lsp_schema.sh`) repoya commit edilmemiş
   (ana checkout'ta untracked) — kabul kapısı fresh clone'da üretilemez.
2. Ana repo kökünde adı literal `"$WATCHDOG_PID_FILE"` olan dosya main'de
   commit'li (cd092d1, gwen bootstrap quoting hatası) — workerlar bilinçli
   olarak dokunmadı.
3. Boş dallar `idle/ureme-stok-bugfix-r` (silinen kırık review workspace'i)
   ve teslim worker dalları (`-1`, `-2`, `-2b`, `-3`, `-r2`) — dal silme
   yetkisi root'undur; hepsi lead dalına merge edildi.
4. `gecmis-pipeline.test.js` 'DÜN' kırmızısı main'de ön-koşullu (görevdışı).
5. GT (`99999999999999_ground_truth.sql`) yeniden üretimi root'un post-deploy
   kapısı (goal gereği kapsam dışı); yeni drift örnekleri: `tohumlama.id`
   uuid≠text, gebelik gövdesi, tohumlama gövdeleri (stok düşümlü).
   5b. Goal dosyasının `base_sha: a3d8bc2` alanı gerçek tabanla (38c3b07,
   ff ile alınan main ucu) senkronlanmalı (review B9).
6. İlk review workspace'i (b288c384) host kaydına düşmedi ve silindi —
   Superset host'unda create-race araştırması root'a ait (ikinci deneme
   sağlıklı çalıştı).

## Kırıntı zinciri

`.crumbs/ureme-bugfix.jsonl` (ana checkout) — gate/decision/measurement
satırları: gelen iş denetimi (env-mismatch + doc-drift), dağıtım planı,
BUG-001 refutasyonu (ss-ask a312e754 / ss-answer 398ff5c7), dalga-1 teslim
gate'i, W2 sapma gate'i, red-first yeniden üretim, review dispatch retry.
