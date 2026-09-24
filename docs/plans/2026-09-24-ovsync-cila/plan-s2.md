# PLAN S2 — Sessiz sınıflandırma: eşik 55→50, kapsam Boş+bilinmeyen, Bekliyor ≥40g gebelik muayenesi + izole vurgulu liste

> **Tarih:** 2026-09-24 · **Dal:** `ovysch-feature-cila-turu` · **SPEC:** `docs/plans/2026-09-24-ovsync-cila/spec-s2.md` (v1.1 — onarım turu bulguları F1-F8 spec §12'de; bu plana işlenenler: 3b/3f param-sayısı, Adım 1.4 grep beklentileri, Adım 0.2/6 analyze yolu, Adım 0/2/5 canlı beklenenler, **KANAL KURALI F7**)
> **KANAL KURALI (bağlayıcı — S1 fafdda1 + S5 R3/B3 ile aynı kural, F7):** tools-bank `supabase_*` MCP araçları **PROD**'a bağlı (ref `zqnexqbdfvbhlxzelzju` — CONFIRMED `~/tools-bank/mcp_server/server.py` + `js/api.js:23-24`). DEMO ref `vtzqjmazsvurxdeondmi`; demo okuma/apply kanalı: `/home/melik/egesut-erp1/.env` → `SUPABASE_DEMO_REF` + `SUPABASE_DEMO_PAT` ile Mgmt API `POST /v1/projects/$SUPABASE_DEMO_REF/database/query` veya demo pooler psql. tools-bank kanalı bu planda HİÇBİR adımda kullanılmaz — okuma dâhil. v1.0'daki "supabase_migrate demo'ya bakar" cümlesi YANLIŞTI (Adım 2.1'i PROD-apply riski taşıyordu — onarım turunda düzeltildi).
> **Bant:** Prod'a PUSH/MERGE YOK. Demo DB yazımı sahibin 2026-09-24 onayıyla SERBEST ("demo dbye yazılabilir"). Commitler yalnız bu dala, her anlamlı adımdan sonra.
> **Tek-yazıcı zarf (SPEC §4):** `supabase/migrations/<MIG>_sessiz_siniflandirma.sql` (YENİ), `js/ui.js` (6 lokal nokta), `index.html` (damga), `tests/unit/ui-pure.test.js` (expose + 3 test), `BUGS.md` (borç APPEND), `reports/plans/ovsync-cila-s2-kanit.md` (kanıt zarfı — gitignore'da, `git add -f` gerekirse). Zarf-dışı dosyaya yazma YOK (Son review kapısında zarf karşılaştırması yapılır — zarf-dışı dosya = RED).
> **Dokunulmazlar (SPEC §4):** `js/api.js`, `js/forms.js`, `js/state.js`, `js/config.js`, mevcut migration dosyaları, `tohumlama_kaydet`/MK3/ovsync zincirleri, 188 çift zinciri (KASITLI), kısır zincir temizliği (S1'in işi), T9/erteleme-geneli (BORÇ).
> **Eşzamanlılık (10 agent):** (1) Migration numarası tek-atama — Adım 1 başında `ls supabase/migrations/ | grep '^20260925'` ile boş numara seçilir ve plan boyunca `MIG` olarak sabitlenir (SPEC `20260925000001` der ama Plan S1 AYNI numarayı alıyor — CONFIRMED `plan-s1.md` Adım 1; bu plan hedefi `20260925000002` yapar, sapma tablosu kayıt 1). (2) `js/ui.js` bu turun paylaşımlı tek-yazıcı dosyasıdır; S1'in bölgeleri (:L1162-1166, :L1840-1843) ile S2'nin bölgeleri (:L270, :L311-320 arası, :L396-398, :L411, :L1687-1707, :L2683) AYRILMIŞTIR — satır bölgesi dışına taşma YOK; commit'ten önce `git diff --cached -- js/ui.js` ile yalnız S2 bölgelerinin stage'de olduğu doğrulanır, başka bölge de stage'deyse ENGEL raporuyla commit'i beklet. (3) `BUGS.md` APPEND-only; başka kulvarın bloklarını silme/düzenleme YOK.
> **Kanıt etiketleri:** CONFIRMED (dosya:satır) / OBSERVED (canlı komut-sorgu, 2026-09-24) / INFERRED / UNKNOWN.
> **Kesintisiz koşum ilkesi (sahibin isteği):** her adımın kapısı yeşilse durma; bir kapı kırmızıysa o adımı düzelt ve yalnız çözemediğin kısmı "ENGEL:" diye raporla, kalan adımlara devam et. İş bitince SON review kapısından geç (Adım 6) — sahibin açık şartı.

---

## Adım haritası ve bağımlılıklar

| Adım | İş | Bağımlılık | Çıkış kapısı |
|---|---|---|---|
| 0 | Ön-kontrol + canlı gövde ölçümü + ÖNCE sayaçları | — | 4 çapa imzası canlıda bulundu; sayaç tablosu `~/tmp/s2-once-sayac.sql.out` |
| 1 | Migration dosyası (taslaktan byte-birebir) + final db-validate | 0 | C1 PASS (INCONCLUSIVE yalnız bilinen B/C2 borçları) → commit A |
| 2 | DEMO apply + kabul A1-A8 + reconcile onaylı koşumu | 1 | A1/A5/A6/A8 zorunlu-PASS; kanıt zarfına yazıldı (commit yok) |
| 3 | UI: ui.js 6 nokta + unit test (_dashBands expose) + damga | 2 (RPC demo'da canlı olsun) | `test:unit` yeşil + `detect_changes` → commit B |
| 4 | BUGS.md borç kaydı (kapı-aracı borçları) | 3 | APPEND doğrulandı → commit C |
| 5 | Self-check + teslim paketi (dry-run listesi + sahibin yürüyüş checklist'i) | 1-4 | zarf-dışı dosya YOK; ölçü raporu tamam |
| 6 | **SON review kapısı** + kapanış | 5 | review zarf karşılaştırması PASS; gitnexus re-analyze; LSP kapalı |

**Toplam beklenen commit:** 3 (A: migration, B: UI, C: BUGS.md) — DEMO apply DB işlemidir, commit içermez.

---

## Adım 0 — Ön-kontrol, canlı gövde ölçümü, ÖNCE sayaçları (yazma yok)

**Dosya:** yazma yok; dökümler `~/tmp/` altına (`/tmp` yazma YOK — tmpfs kuralı).

1. `git status --short` → ön-existing kirli dosyalar: `BUGS.md` (diğer kulvarların borç kayıtları — OBSERVED: BUG-ERTELEME-KURAL-GENEL, BUG-KUYRUK-SHEMA-VERSIYONU, NOT-KISIR-GEBE-OTORITE zaten eklenmiş; DOKUNMA). Bu plan boyunca stage disiplini: yalnız `git add <kendi dosyan>`, sonra `git diff --cached --stat` ile doğrula (memory kuralı: "git add <dosya> yeterli değil").
2. GitNexus indeks kuralı: `list_repos` ile indeks HEAD'e eş mi bak; değilse analyze çalıştır. **YOL KURALI (S4 onarım turuyla hizalı — F6):** kayıtlı indeks ana checkout'a (`/home/melik/egesut-erp1`, branch `main`, `d6a41c0` — 2026-09-24 yeniden OBSERVED) bağlıdır; analyze'i ana checkout yolunda koşarsan **main dalını** indeksler, bu dalın ucunu değil. Analyze'i **bu worktree yolunda** (`/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-cila-turu`) koştur ki indeks dal ucunu alsın (S1 kulvarıyla çift analyze idempotent, kabul). Not: indeks worktree'yi kapsamaz (SPEC §11 OBSERVED) — impact'ler ana checkout bazlıdır; gerçek pre-check LSP ile yapılır (Adım 3).
3. `code-change-precheck` skill'ini yükle; sözleşmesini uygula (iş bitince LSP kapanır — Adım 6).
4. **Canlı gövde ölçümü** (DEMO kanalı — yukarıdaki KANAL KURALI; tools-bank `supabase_*` araçları KULLANILMAZ, onarım turunda bu kanalla yapılan ölçümler PROD okumasıydı — F7. Yazmalar yalnız `SELECT public.<rpc>()` biçimindeki onaylı RPC koşumlarıdır; düz UPDATE/DELETE YOK):

```sql
SELECT pg_get_viewdef('public.v_eligible'::regclass, true);
SELECT proname, pg_get_functiondef(oid) FROM pg_proc
 WHERE pronamespace = 'public'::regnamespace
   AND proname IN ('sessiz_hayvanlar_listele','sessiz_hayvanlar_reconcile','stat_suru_ozet');
SELECT jobname, schedule, command FROM cron.job ORDER BY jobname;  -- DİKKAT: demo'da pg_cron YOK olabilir (spec-s3 K18 OBSERVED 23:15: pg_extension boş, cron şeması yok) — "relation does not exist" hatası ENGEL DEĞİLDİR, kaydedilir ve devam edilir
```

   Çıktıyı `~/tmp/s2-canli-govdeler.sql.out`'a yaz; çapa imzalarını ara (CONFIRMED repo çapaları):
   - `v_eligible`: `sonuc = 'Gebe'` NOT EXISTS VAR, **`Bekliyor` NOT EXISTS YOK**, eşik `55` VAR, `GREATEST(0,` düve fallback VAR, `durum = 'Aktif'` VAR (baz `20260831000002_duve_sessiz_13ay.sql:L31-35`);
   - `sessiz_hayvanlar_listele`: imza `p_min_gun integer DEFAULT 55` (son tanım);
   - `sessiz_hayvanlar_reconcile`: `>= 55` İKİ yerde (üret `20260625000020:L19` karşılığı + guard `:L52` karşılığı), `kapatan_ref = 'sessiz-noteligible'`, 30-gün cooldown; cron'da `sessiz-reconcile-daily` / `0 5 * * *`;
   - `stat_suru_ozet`: `e.sessiz_gun >= 55` (COALESCE'siz — Z11 tutarsızlığının kaynağı).
   Çapa tutmazsa (canlı repo'dan farklıysa) DURMA: spec §10 UNKNOWN protokolü — canlı gövdeyi baz al, taslaktaki delta'yı (Bekliyor-NOT-EXISTS + 50 + COALESCE) o gövdeye uygula, farkı rapora yaz. Bekliyor-NOT-EXISTS'in canlıda ZATEN var olması tur iptali sayılır (biri uygulamış) → ENGEL raporu ver, Adım 1'e geçme.
5. **ÖNCE sayaçları** (teslim özetinin "öncesi" kolonu; çıktı `~/tmp/s2-once-sayac.out`):

```sql
SELECT jsonb_array_length(public.sessiz_hayvanlar_listele()) AS sessiz_liste_once;         -- beklenti 11 (Z9 — ama PROD gözlemi, F7; DEMO ölçümü esastır)
SELECT (public.stat_suru_ozet()->'hayvan'->>'sessiz')       AS sessiz_stat_once;          -- beklenti 9 (Z11 — PROD gözlemi, F7)
SELECT count(DISTINCT t.hayvan_id) AS muayene_populasyonu_kaba                              -- beklenti 5, filtreli 3 (Z13 v1.1 — PROD gözlemi, F7; DEMO'da ölçülür)
  FROM tohumlama t JOIN hayvanlar h ON h.id = t.hayvan_id
 WHERE t.sonuc = 'Bekliyor' AND t.tarih <= CURRENT_DATE - 40
   AND h.cinsiyet = 'Dişi' AND h.durum = 'Aktif' AND COALESCE(h.kisir, false) = false;
SELECT h.kupe_no, g.kaynak FROM gorev_log g JOIN hayvanlar h ON h.id = g.hayvan_id          -- 173/186/168 açık SESSIZ kanıtı (Z10)
 WHERE g.kaynak LIKE 'SESSIZ-%' AND g.tamamlandi = false AND g.iptal = false
   AND h.kupe_no IN ('173','186','168');
```

   173'ün son-tohumlama `Bekliyor` kanıtı: `SELECT h.kupe_no, t.tarih, t.sonuc FROM tohumlama t JOIN hayvanlar h ON h.id=t.hayvan_id WHERE h.kupe_no='173' AND t.sonuc='Bekliyor' ORDER BY t.tarih DESC LIMIT 1;` (Z10: 2026-07-30, `ce96ca6d` — onarım turunda canlı yeniden OBSERVED; bekleyen-gün bugün 56).

**Doğrulama:** çapa imzaları bulundu/fark belgelendi; sayaçlar kaydedildi. **Commit yok.**

---

## Adım 1 — Migration dosyası: `supabase/migrations/<MIG>_sessiz_siniflandirma.sql` (YENİ)

1. **Numara ataması (eşzamanlılık):** `ls supabase/migrations/ | grep '^20260925'` → hedef `20260925000002` (Plan S1 `...000001`'i alıyor — CONFIRMED plan-s1.md Adım 1). Doluysa ilk boş `20260925NNNNNN`'u al; seçilen numarayı plan boyunca `MIG` değişkeni gibi kullan (Adım 2/5/rollback referansları).
2. **Byte-birebir kopya (SPEC §4-2: "İçerik = (1) dosyası"):**
   ```bash
   cp docs/plans/2026-09-24-ovsync-cila/taslak-s2-migration.sql \
      supabase/migrations/20260925000002_sessiz_siniflandirma.sql
   diff docs/plans/2026-09-24-ovsync-cila/taslak-s2-migration.sql \
        supabase/migrations/20260925000002_sessiz_siniflandirma.sql   # boş çıktı ZORUNLU
   ```
   Byte-birebir kural SPEC §6'daki izole-DB fonksiyonel test kanıtını (T-a…T-m, hepsi PASS) bu final dosyaya taşır — dosyada herhangi bir elle değişiklik YAPILMAZ; değişiklik gerekirse ÖNCE taslakta düzelt, db-validate + fonksiyonel yeniden koşum, sonra kopyala.
3. **Kapı — final db-validate (db-validation kapısı: apply'dan ÖNCE finalde):**
   ```bash
   bash scripts/db-validate.sh supabase/migrations/20260925000002_sessiz_siniflandirma.sql
   ```
   Zorunlu: **C1 PASS**. Genel sonuç INCONCLUSIVE olabilir — yalnızca SPEC §6'daki bilinen borçlardan (`B.sema-uyum` statik çözümleyici, `C2` text-PK seeder); rapor `reports/db-validation-<sha8>.md` linkini kanıt zarfına yaz. FAIL ise hata düzelt (taslakta) → 2. adımdan itibaren tekrar.
4. **Hızlı içerik kontrolleri** (beklenenler onarım turunda taslak üzerinde gerçek koşumla doğrulandı — F4: v1.0'daki "COALESCE=2" ve "'>= 50' view'i sayar" yorumları hatalıydı):
   ```bash
   grep -c "sonuc = 'Bekliyor'" supabase/migrations/20260925000002_sessiz_siniflandirma.sql   # 6 (>= 3: v_eligible + _listele + _uret + yorumlar)
   grep -c '>= 50' supabase/migrations/20260925000002_sessiz_siniflandirma.sql                # 3 (reconcile üret+guard 2 + stat 1; view eşiği '< (CURRENT_DATE - 50)' bu kalıba GIRMEZ)
   grep -c 'CURRENT_DATE - 50' supabase/migrations/20260925000002_sessiz_siniflandirma.sql    # >= 1 (view 50-eşiğinin kendi kontrolü)
   grep -ci 'grant.*anon\|to anon' supabase/migrations/20260925000002_sessiz_siniflandirma.sql # 0 (anon kuralı; REVOKE satırları eşleşmez)
   grep -c '10 5 \* \* \*' supabase/migrations/20260925000002_sessiz_siniflandirma.sql        # 1
   grep -c "COALESCE(e.sessiz_gun, 9999) >= 50" supabase/migrations/20260925000002_sessiz_siniflandirma.sql  # 1 (yalnız stat — D5; listele'de eşik parametreli '>= p_min_gun'dur, sabit-50 COALESCE DEĞİL)
   ```
5. **Commit A** (yalnız migration dosyası; `git add` ile):
   ```
   feat(db): S2 sessiz siniflandirma — esik 55→50, Bekliyor tam hariç, gebelik muayenesi RPC+cron, stat hizalaması

   Co-Authored-By: Claude Code <noreply@anthropic.com>
   ```

**Not (SPEC §8 sapması):** spec apply sonrası ikinci bir "commit (yalnız migration dosyası)" der; dosya Adım 1'den sonra DEĞİŞMEDİĞİ için tek commit A yeterlidir — sapma tablosu kayıt 3.

---

## Adım 2 — DEMO apply + kabul doğrulama A1-A8 + onaylı reconcile koşumu

**Sıra disiplini:** final db-validate yeşildir (Adım 1) → apply.

1. **Apply (DEMO — sahibin onayıyla):** dosyanın TAM içeriğini DEMO kanalına uygula: `POST /v1/projects/$SUPABASE_DEMO_REF/database/query` gövdesinde `{"query": "<tam migration SQL>"}` (Mgmt API; `.env` → `SUPABASE_DEMO_PAT`) veya demo pooler psql. Dosya BEGIN/COMMIT içerir; tek seferde gönder. **UYARI (onarım turu F7):** tools-bank `supabase_migrate` KULLANILMAZ — o kanal PROD'a bağlıdır (ref `zqnexqbdfvbhlxzelzju`); v1.0'ın "bu kanal demo'ya bakar" cümlesi yanlıştı ve PROD-apply riski taşıyordu (S1 fafdda1 + S5 R3/B3 ile aynı kural). Kanal adını kanıt zarfına yaz.
2. **Apply doğrulama (salt-SELECT, aynı DEMO kanalı):**
   ```sql
   SELECT count(*) AS yeni_rpc
     FROM pg_proc WHERE pronamespace = 'public'::regnamespace
       AND proname IN ('gebelik_muayene_listele','gebelik_muayene_gorev_uret');   -- beklenen 2
   SELECT position('sonuc = ''Bekliyor''' in pg_get_viewdef('public.v_eligible'::regclass, true)) > 0 AS bekliyor_haric_ok,
          position('CURRENT_DATE - 50'            in pg_get_viewdef('public.v_eligible'::regclass, true)) > 0 AS esik50_ok;
   ```
   Beklenen: `yeni_rpc=2`, `bekliyor_haric_ok=true`, `esik50_ok=true`.
3. **Kabul seti (SPEC §7-A; sıra ÖNEMLİ — A4 reconcile koşumunu A1/A2'den SONRA koş; gerçek üretim `dry_run=false` MANUEL ÇAĞRILMAZ — sapma tablosu kayıt 4):**
   - **A1 — sessiz listesinde Bekliyor sıfır; 173 listede YOK:**
     ```sql
     SELECT count(*) AS bekliyorlu_sessiz
       FROM jsonb_array_elements(public.sessiz_hayvanlar_listele()) s
      WHERE EXISTS (SELECT 1 FROM tohumlama t
                     WHERE t.hayvan_id = (s->>'hayvan_id')::text AND t.sonuc = 'Bekliyor'
                       AND t.id = (SELECT t2.id FROM tohumlama t2 WHERE t2.hayvan_id = t.hayvan_id
                                   ORDER BY t2.tarih DESC NULLS LAST, t2.created_at DESC NULLS LAST LIMIT 1));  -- ZORUNLU 0
     SELECT count(*) AS kupe173_listede
       FROM jsonb_array_elements(public.sessiz_hayvanlar_listele()) s WHERE s->>'kupe_no' = '173';              -- ZORUNLU 0
     SELECT jsonb_array_length(public.sessiz_hayvanlar_listele()) AS sessiz_sonra;                              -- öncesi 11; beklenen ≈ 9 (180+173 çıkar — son tohumlamaları Bekliyor; 9999 ikilisi kalır; F3)
     ```
   - **A2 — muayene listesi:**
     ```sql
     SELECT m->>'kupe_no' kupe, m->>'bekliyor_gun' gun, (m->>'acik_gorev_var')::text acik
       FROM jsonb_array_elements(public.gebelik_muayene_listele()) m ORDER BY (m->>'bekliyor_gun')::int DESC;
     SELECT count(*) AS genc40 FROM jsonb_array_elements(public.gebelik_muayene_listele()) m
      WHERE (m->>'bekliyor_gun')::int < 40;   -- ZORUNLU 0
     ```
     Zorunlu: kupe 173 LİSTEDE (`bekliyor_gun` ≈ 56-57 — Z10 tarihinden, 2026-07-30; PROD gözleminde bugün 56 — F7); `acik_gorev_var` her satırda boolean.
   - **A3 — dry-run raporu (Mgmt query endpoint süperuser bağlamı — SPEC D6'nın "psql/MCP service_role bağlamı" gereğini karşılar):**
     ```sql
     SELECT public.gebelik_muayene_gorev_uret(true);
     ```
     `dry_run=true`, `esik_gun=40`, `adet`+`liste` tam kupe listesiyle kanıt zarfına kopyalanır. **`false` argümanıyla koşum YOK** — gerçek üretim gece 05:10 cron'undadır (S9 onay kapısı; T-e/T-f davranışı izole DB'de zaten kanıtlı).
   - **A4 — onaylı reconcile koşumu (demo yazımı sahibin onaylı — SPEC §7-A4 açıkça ister):**
     ```sql
     SELECT public.sessiz_hayvanlar_reconcile();          -- {uretilen, kapatilan, zaman} → zarfa
     SELECT h.kupe_no, g.kaynak, g.iptal, g.kapatan_ref
       FROM gorev_log g JOIN hayvanlar h ON h.id = g.hayvan_id
      WHERE g.kaynak LIKE 'SESSIZ-%' AND g.tamamlandi = false AND g.iptal = false
        AND h.kupe_no IN ('173','186','168');              -- ZORUNLU 0 satır (hepsi kapandı)
     SELECT count(*) AS bekliyorlu_acik_sessiz_gorev
       FROM gorev_log g JOIN hayvanlar h ON h.id = g.hayvan_id
      WHERE g.gorev_tipi = 'VETERINER_KONTROL' AND g.kaynak LIKE 'SESSIZ-%'
        AND g.tamamlandi = false AND g.iptal = false
        AND EXISTS (SELECT 1 FROM tohumlama t WHERE t.hayvan_id = g.hayvan_id AND t.sonuc = 'Bekliyor'
                      AND t.id = (SELECT t2.id FROM tohumlama t2 WHERE t2.hayvan_id = t.hayvan_id
                                  ORDER BY t2.tarih DESC NULLS LAST, t2.created_at DESC NULLS LAST LIMIT 1));  -- ZORUNLU 0
     ```
     Beklenen: `kapatilan ≥ 3` (173/186/168'in açık görevleri; Adım 0 öncesi ölçümüyle karşılaştır), `uretilen` yalnız gerçek 50+ sessizler için (raporla). İkinci koşum idempotent (T-h): `SELECT public.sessiz_hayvanlar_reconcile();` → `0/0` beklenir — koş ve kaydet.
   - **A5 — stat ↔ listele eşitliği (ZORUNLU eşitlik, D5):**
     ```sql
     SELECT (public.stat_suru_ozet()->'hayvan'->>'sessiz') AS stat_s,
            jsonb_array_length(public.sessiz_hayvanlar_listele()) AS liste_s;
     ```
   - **A6 — v_eligible temizliği (ZORUNLU 0):**
     ```sql
     SELECT count(*) FROM v_eligible e
      WHERE EXISTS (SELECT 1 FROM tohumlama t WHERE t.hayvan_id = e.id AND t.sonuc = 'Bekliyor');
     ```
   - **A7 — cron:**
     ```sql
     SELECT jobname, schedule, command FROM cron.job WHERE jobname = 'gebelik-muayene-daily';
     ```
     Zorunlu: **pg_cron kuruluysa** 1 satır, `10 5 * * *`, `SELECT public.gebelik_muayene_gorev_uret(false)`. **pg_cron demo'da YOKSA (spec-s3 K18 OBSERVED 23:15: `pg_extension` boş, `cron` şeması yok — sorgu "relation does not exist" verir):** A7 ZORUNLU-PASS DEĞİLDİR — D4'ün pg_cron-koruyan DO bloğu kurulumu sessizce atlamıştır (migration apply yine başarılıdır); sonuç "cron-yok" olarak kanıt zarfına yazılır ve gerçek üretim PROD'a taşıma öncesi cron.schedule'ı sahibin ayrı adımı olur (kesintisizlik kuralı; ENGEL raporu YOK). Ertesi-sabah koşum doğrulaması (görevlerin üretimi + dry-run tutarlılığı) ajanın bekleme süresini aşar → teslim zarfına İZLEME NOTU olarak yazılır (cron kendisi üretir; A3 listesiyle sahibin yürüyüşünde karşılaştırılır; demo'da pg_cron yoksa üretim vektörü elle `gebelik_muayene_gorev_uret(false)` sahibin onaylı koşumudur — spec-s3 E-1 nüansıyla aynı).
   - **A8 — ACL (Z14):**
     ```sql
     SELECT has_function_privilege('anon','public.gebelik_muayene_gorev_uret(boolean)','EXECUTE') AS anon_uret,      -- ZORUNLU false
            has_function_privilege('anon','public.gebelik_muayene_listele()','EXECUTE')          AS anon_listele,   -- ZORUNLU false
            has_function_privilege('authenticated','public.gebelik_muayene_listele()','EXECUTE') AS auth_listele,   -- ZORUNLU true
            has_function_privilege('authenticated','public.gebelik_muayene_gorev_uret(boolean)','EXECUTE') AS auth_uret; -- ZORUNLU false
     ```
4. **Kanıt zarfını başlat:** `reports/plans/ovsync-cila-s2-kanit.md` — öncesi/sonrası sayaç tablosu (sessiz 11→X, stat 9→X, muayene ~Y), A1-A8 ham çıktıları (tarih + kanal), apply kanalı, A3 dry-run kupe listesi, ENGEL varsa notları.
5. Apply hatası olursa: hatayı taslakta düzelt → db-validate → yeniden commit → yeniden apply; çözülmezse yapabildiğin kadarını tamamla, "ENGEL:" diye raporla (UI DB'siz de güvenli: `muayeneList` fetch'i catch ile boş düşer, bant çizilmez).

**Commit yok** (DB işlemi; kanıt zarfı gitignore'da).

---

## Adım 3 — UI: `js/ui.js` 6 lokal nokta + unit test + `index.html` damgası

**Pre-check kapıları (SPEC §7-C2):**
- `git status --short js/ui.js` → kirliyse (başka kulvar WIP'i) kendi bölgelerine DOKUNABİLİRSİN ama commit bekletme kuralı aşağıda; temizse normal.
- LSP `findReferences` `_dashBands` (js/ui.js:270) → tanım dışı çağrı yalnız `loadDash` (:L411) OLMALI; `grep -n '_dashBands\|_showSessizList\|_sessizGrupla\|55+ gündür' js/ui.js` → nokta listesi: :L270, :L313, :L398, :L411, :L1689, :L1701, :L2683. Beklenmedik bir ek nokta varsa LSP çıktısını rapora ekle ve ona göre zarfı genişletmeden yalnız §4 noktalarına dokun.

### 3a — (c) fetch: :L396-398 bloğunun HEMEN ARDINA ekle

```js
    // 🔬 Gebelik muayenesi listesi (S2) — band, sessiz bandının hemen üstünde
    let muayeneList=[];
    try{ const ml=await rpc('gebelik_muayene_listele',{}); if(ml&&ml.length) muayeneList=ml; }catch(e){/* sessiz — RPC henüz yoksa bantsız devam */}
```

### 3b — (a)+(b) imza ve çağrı

- **:L270** `function _dashBands(negStk,late,todayT,births60,nearBirth,critStk,stock,ileriGebeler,aMap,yakAsi,yakTakviye,ddMap,sessizList,sutBuzagiHtml){` → sonuna **15. parametre** (mevcut 14 parametrenin sonuna — onarım turu F1): `...,sutBuzagiHtml,muayeneList){`
- **:L411** `_dashBands(negStk,late,todayT,births60D,nearBirth,critStk,stock,ileriGebeler,aMap,yakAsi,yakTakviye,_ddMap,sessizList,sutBuzagiBandi)` → sonuna `,muayeneList`.

### 3c — (d) muayene bandı: :L311 `if(sutBuzagiHtml) h+=sutBuzagiHtml;` satırından SONRA, :L312 `if((sessizList||[]).length){` satırından ÖNCE araya ekle

```js
  // S2: 🔬 Gebelik Muayenesi Bekleyenler — sessiz bandının HEMEN ÜSTÜNDE izole kırmızı bant
  if((muayeneList||[]).length){
    const mTitle=`<span style="display:flex;align-items:center;gap:8px;width:100%">🔬 Gebelik Muayenesi Bekleyenler (${muayeneList.length})<button onclick="_showSessizList()" style="font-size:.65rem;font-weight:700;padding:3px 9px;border-radius:6px;border:1px solid var(--red2);background:rgba(192,50,26,.1);color:var(--red2);cursor:pointer;white-space:nowrap;margin-left:auto">Tümünü Gör →</button></span>`;
    h+=band('red',mTitle,
      muayeneList.slice(0,8).map(m=>`<div class="arow" onclick="openDet('${escAttr(m.hayvan_id)}')"><div class="arow-left"><div class="arow-id">${esc(m.kupe_no||'?')}<span style="font-size:.6rem;opacity:.6;margin-left:6px">${esc(m.grup||'')}</span></div><div class="arow-sub">${m.bekliyor_gun}. gün Bekliyor · Son tohumlama: ${esc(m.son_tohumlama_tarihi||'—')}</div></div><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M9 18l6-6-6-6"/></svg></div>`).join(''));
  }
```

(Buton `_showSessizList` sheet'ini açar; sheet'in en üstünde aynı muayene bölümü görünür — 3e.)

### 3d — (e) `_showSessizList` :L1687-1704 — ÜÇ parça

1. **:L1689-1690** yerine:
   ```js
       const list=await rpc('sessiz_hayvanlar_listele',{});
       // S2: muayene listesi — sheet'in en üstündeki izole bölümün verisi
       let muayene=[];
       try{ const ml=await rpc('gebelik_muayene_listele',{}); if(ml&&ml.length) muayene=ml; }catch(e){/* sessiz */}
       if((!list||!list.length)&&!muayene.length){toast('Sessiz hayvan yok');return;}
   ```
2. **:L1700** `const rows=_sessizGrupla(list).map(...).join('');` yerine (muayene bölümü en üstte, `_sessizGrupla` İMZASI DEĞİŞMEZ):
   ```js
       const mRow=m=>`<div class="arow" onclick="_sessizSheetGizle();openDet('${escAttr(m.hayvan_id)}')" style="cursor:pointer"><div class="arow-left"><div class="arow-id">${esc(m.kupe_no||'?')}<span style="font-size:.6rem;opacity:.6;margin-left:6px">${esc(m.grup||'')}</span></div><div class="arow-sub">${m.bekliyor_gun}. gün Bekliyor · Son tohumlama: ${esc(m.son_tohumlama_tarihi||'—')}</div></div><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M9 18l6-6-6-6"/></svg></div>`;
       const muayeneRows=muayene.length?`<div style="font-size:.68rem;font-weight:800;color:var(--red2);margin:12px 0 4px;letter-spacing:.02em">🔬 Gebelik Muayenesi Bekleyenler · ${muayene.length}</div>${muayene.map(mRow).join('')}`:'';
       const rows=muayeneRows+_sessizGrupla(list||[]).map(g=>`<div style="font-size:.68rem;font-weight:800;color:var(--ink3);margin:12px 0 4px;letter-spacing:.02em">${esc(g.grup)} · ${g.items.length}</div>${g.items.map(row).join('')}`).join('');
   ```
3. **:L1701** başlıkta `${list.length}` → `${(list||[]).length}` VE alt-metin `55+ gündür kızgınlık/tohumlama kaydı yok` → `50+ gündür kızgınlık/tohumlama kaydı yok`.

### 3e — (f) stat bölümü :L2683

`55+ gündür tohumlama/kızgınlık kaydı yok` → `50+ gündür tohumlama/kızgınlık kaydı yok` (yalnız metin; sayaç mantığı yok).

### 3f — Unit test: `tests/unit/ui-pure.test.js`

- **expose:** :L26-29 `expose: ['_katTipMap', 'OZEL_ALT_TIPLER']` → `expose: ['_katTipMap', 'OZEL_ALT_TIPLER', '_dashBands']`; :L33-34 destructure listesine `_dashBands` ekle.
- **mevcut `_sessizGrupla` testleri (:L493+) AYNEN KALIR** — imza değişmedi (SPEC D7).
- **dosya SONUNA yeni blok** (SPEC §7-B2: sıralama + kenar davranışı; RPC DESC sıralı döndüğü için band içi ek sort YOK — girdi sırası korunur):
  ```js
  // ════════════════════════════════════════════════════════════════════════════
  // S2 — 🔬 muayene bandı (_dashBands 15. parametre muayeneList — F1; RPC bekliyor_gun DESC döner)
  // ÇAĞRI DISİPLİNİ (F2): 15 argüman — 13:sessizList, 14:sutBuzagiHtml, 15:muayeneList.
  // Fazladan argüman JS'te sessizce DÜŞER: v1.0'daki 16-argümanlı çağrılarda liste verisi
  // 16. pozisyona kayıp test 2 KIRMIZI patlıyordu.
  // ════════════════════════════════════════════════════════════════════════════
  test('S2: muayeneList boş/null → 🔬 bandı YOK', () => {
    const h = _dashBands(0,[],[],[],[],0,[],[],{},[],[],{},[], null, null);
    assert.ok(!h.includes('🔬'), 'muayene bandı çizilmemeli');
  });
  test('S2: muayeneList dolu → 🔬 bant + sayaç; satırlar girdi (RPC DESC) sırasıyla', () => {
    const m = [
      {hayvan_id:'m2', kupe_no:'2', grup:'Sağmal', bekliyor_gun:56, son_tohumlama_tarihi:'2026-07-30'},
      {hayvan_id:'m1', kupe_no:'1', grup:'Sağmal', bekliyor_gun:45, son_tohumlama_tarihi:'2026-08-10'},
    ];
    const h = _dashBands(0,[],[],[],[],0,[],[],{},[],[],{},[], null, m);
    assert.ok(h.includes('🔬 Gebelik Muayenesi Bekleyenler (2)'), 'başlık + sayaç');
    assert.ok(h.indexOf('56. gün') < h.indexOf('45. gün'), 'RPC DESC sırası korunmalı');
  });
  test('S2: 🔬 bandı ❗ Sessiz Hayvanlar bandından ÖNCE (izole üst bant)', () => {
    const s = [{hayvan_id:'s1', kupe_no:'9', grup:'Sağmal', sessiz_gun:70, son_aktivite:null}];
    const m = [{hayvan_id:'m1', kupe_no:'2', grup:'Sağmal', bekliyor_gun:45, son_tohumlama_tarihi:'2026-08-10'}];
    const h = _dashBands(0,[],[],[],[],0,[],[],{},[],[],{},[], s, '', m);
    assert.ok(h.indexOf('🔬') < h.indexOf('❗ Sessiz Hayvanlar'), 'muayene önce');
  });
  ```

### 3g — Damga: `index.html`

`?v=` tek-değer kuralı (CONFIRMED :L11+:L2326-2335, 26 geçek). Hedef değer `20260925-01` (Plan S1 ile AYNI hedef):
```bash
if grep -q '?v=20260925-01' index.html; then echo "damga zaten güncel (S1 bump etmiş) — sed yok";
else sed -i 's/?v=20260924-01/?v=20260925-01/g' index.html; fi
grep -c '?v=20260925-01' index.html   # 26 beklenir
grep -c '?v=20260924-01' index.html   # 0 beklenir
```

### Kapılar ve commit B

- `node --test tests/unit/` veya `NODE_PATH=/home/melik/egesut-erp1/node_modules npm run test:unit` (worktree'de node_modules yok — memory kuralı) → tamamen yeşil; `_sessizGrupla` mevcut testleri hiç bozulmadan geçer. Kırılan test S2 bölgesiyle ilgisizse incele; S2 bölgelerinden kırıldıysa 3b-3f'yi gözden geçir.
- `gitnexus detect_changes` (bu worktree; unstaged) → kapsamda `js/ui.js`, `index.html`, `tests/unit/ui-pure.test.js` görünmeli; beklenmedik süreç etkilenmesi yok.
- Stage disiplini: `git add js/ui.js index.html tests/unit/ui-pure.test.js` → `git diff --cached -- js/ui.js` ile **yalnız S2 bölgeleri** (:L270-271, :L311-321 arası, :L396-402 arası, :L411, :L1687-1707, :L2683) stage'de OLMALI; başka kulvarın bölgesi (:L1162-1166/:L1840-1843 vb.) da stage'deyse commit'i beklet → ENGEL raporu (o kulvarın commit'ini geç).
- **Commit B:**
  ```
  feat(ui): S2 gebelik muayenesi izole bant + sheet bölümü, sessiz eşik metni 50+ , _dashBands muayeneList

  Co-Authored-By: Claude Code <noreply@anthropic.com>
  ```

---

## Adım 4 — `BUGS.md` borç kaydı (SPEC §4-6)

Dosya sonuna YALNIZ APPEND (başka kulvarların bloklarını silme/düzenleme YASAK — eşzamanlılık kuralı; mevcut kirli diff başka kulvarların kayıtlarıdır):

```markdown

### BUG-DBVAL-BORC — db-validate baseline borçları: PK kurmuyor + pg_cron yok + C2 text-PK seeder bozuk [open / borç]

**Tarih:** 2026-09-24 · **Kaynak:** ovsync-cila spec-s2 §11 / `reports/db-validation-e3025b23.md`

**Durum:** db-validation kapısının izole baseline'ında üç aracı borç:
1. Baseline PK/unique'ları yeniden kurmuyor → migration'daki `ON CONFLICT (anahtar)` patlar
   (çözüm deseni: PK-bağımsız update-önce/insert-eksikse — S2 migration §1).
2. Baseline'da pg_cron yok → `cron.schedule` pg_cron-koruyan DO bloğu ister (S2 migration §9).
3. C2 sentetik seeder text-PK tablolarda bozuk SQL üretir (`INSERT ... VALUES ()` syntax error)
   → C2 INCONCLUSIVE kalır; boşluk manuel fonksiyonel testlerle dolduruldu (spec-s2 §6 T-a…T-m).

**Etki:** kapı bu üç durumda INCONCLUSIVE döner; her migration bunları kendince aşmak zorunda.
```

**Commit C:**
```
docs(bugs): S2 db-validate kapı borçları kaydı (baseline PK, pg_cron, C2 seeder)

Co-Authored-By: Claude Code <noreply@anthropic.com>
```

---

## Adım 5 — Self-check + teslim paketi

1. `git log --oneline main..HEAD` → A/B/C commit'leri; `git status --short` → yalnız ön-existing kirli dosyalar (kendi yazmadıkların). `git diff --stat main..HEAD` → yalnız zarf dosyaları: yeni migration, `js/ui.js`, `index.html`, `tests/unit/ui-pure.test.js`, `BUGS.md`. Başka dosya görünüyorsa DUR ve raporla.
2. `npm run test:unit` ikinci teyit (damga sonrası) + `gitnexus detect_changes` temiz.
3. **Ölçü raporu** (teslim özeti içine): sessiz liste öncesi (Adım 0 DEMO ölçümü; PROD gözlemi 11 — F7) → SONRA (A1 `sessiz_sonra`; beklenen ≈9), sessiz stat öncesi (PROD gözlemi 9) → SONRA (A5; D5 hizalamasıyla eşit olmalı), muayene popülasyonu A3 `adet` (PROD gözlemi filtreli 3: 180/173/902 — F7), reconcile `kapatilan`/`uretilen`. Öncesi değerler Adım 0 DEMO kanalı çıktısından.
4. **Teslim tanımı (sahibin isteği: "direkt demo testte hazır"):** migration DEMO'da canlı + A1-A8 kanıtlı; UI dalda commit'li + unit yeşil; sahibin yürüyüşü hazır: worktree kökünde `npm run serve:local` → http://127.0.0.1:8080. **Sahip yürüyüş checklist'i (SPEC §7-B3-5 — ajan browser koşmaz):**
   - Dashboard'da `🔬 Gebelik Muayenesi Bekleyenler (N)` bandı `❗ Sessiz Hayvanlar` bandının TAM ÜSTÜNDE, kırmızı; satır metni "N. gün Bekliyor · Son tohumlama: …"; "Tümünü Gör" sheet'i açar;
   - Sheet'te en üstte `🔬 Gebelik Muayenesi Bekleyenler · N` bölümü; altında gruplar "50+ gündür" alt-metniyle; "Hiç kayıt yok" en altta (bb4ea92 kuralı);
   - Stat kartında sessiz bölüm "50+ gündür tohumlama/kızgınlık kaydı yok";
   - Ertesi sabah 05:10 cron koşumunda 🔬 görevler görünür ve A3 dry-run listesiyle tutarlıdır (izleme notu).
5. Kanıt zarfını tamamla (`reports/plans/ovsync-cila-s2-kanit.md`): Adım 0 sayaçları, A1-A8 çıktıları, dry-run kupe listesi, test:unit özeti, commit A/B/C SHA'ları, sapma tablosu (aşağıda), rollback referansı. (reports/ gitignore'da — teslimde `git add -f` gerekirse sahibe sor.)

---

## Adım 6 — SON review kapısı (sahibin açık şartı) + kapanış

Implementer kendi kendini onaylamaz — **review ayrı bir koşumdur** (built-in code-review ajanı / `code-review` skill'i, effort high; ya da sahibin atadığı ayrı ajan).

**Review girdileri (review koşumuna verilecek paket):**
1. Commit aralığı `main..HEAD` (A+B+C);
2. `docs/plans/2026-09-24-ovsync-cila/spec-s2.md` + bu plan;
3. `reports/plans/ovsync-cila-s2-kanit.md`;
4. Bilinen sapmalar tablosu (aşağıda) + ENGEL notları (varsa);
5. Rollback senaryosu (aşağıda).

**Zarf karşılaştırması (SPEC §7-C4, RED kuralı):** `git diff --stat main..HEAD` dosya listesi §4 zarfıyla birebir karşılaştırılır — zarf-dışı dosya (özellikle `js/api.js`/`forms.js`/`state.js`/`config.js`, mevcut migration'lar, ovsync zincir fonksiyonları) görünürsa review RED; fix + ilgili kapının (db-validate / test:unit) yeniden koşumu + yeni commit + review tekrarı.

**Bulguların işlenmesi:** kritik bulgu → fix (zarf içinde), kapıları yeniden koş, commit, review'ı tekrar aç. Ruh-bulgu (nitelik önerisi) → sahibe not.

**Kapanış işlemleri:** `gitnexus analyze` **bu worktree yolunda** koşturulur (`/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-cila-turu` — ana checkout yolunda koşum main'i indeksler, dal ucunu değil; F6; S1 kulvarıyla çift analyze kabul); LSP kapat (`code-change-precheck` sözleşmesi); demo cron ertesi-sabah izleme notu teslim özetinde kalsın.

---

## Rollback (SPEC §9 somut hali — YALNIZ gerektiğinde, SAHİP ONAYIYLA; önceden diske yazma)

1. **Önce UI:** `git revert <commit B>` (`?v=` damgası tek-değer kuralıyla beraber döner; gerekirse damgayı `20260925-01`'e zorla).
2. **DB:** tek script, tek transaction — spec-s2 §9'daki SQL bloğunun aynen kendisi (cron unschedule pg_cron-koruyan DO; `DROP FUNCTION IF EXISTS public.gebelik_muayene_gorev_uret(boolean)` + `..._listele()`; açık `GEBELIK-KONTROL-*` görevlerine `iptal=true, kapatan_ref='s2-geri-al'`; seed DELETE; dört değişen nesnenin eski gövdeleri — `v_eligible` = `20260831000002_duve_sessiz_13ay.sql:L4-35`, `sessiz_hayvanlar_listele` = `20260531400000_sessiz_hayvan_yas_filtresi.sql:L42-54` (default 55), `sessiz_hayvanlar_reconcile` = `20260625000020_sessiz_reconcile.sql:L5-58`, `stat_suru_ozet` = `20260625000030_stat_suru_ozet_readonly.sql:L4-136`; eski dosyalardaki `TO anon` GRANT satırları KOPYALANMAZ; sonunda `NOTIFY pgrst, 'reload schema';`). Dosya adı gerektiğinde `supabase/migrations/<yeni-boş-numara>_sessiz_siniflandirma_geri_al.sql`; db-validate koşulmadan apply edilmez.
3. **Doğrulama (geri-al sonrası):** A1 sorgularının tersi — `sessiz_hayvanlar_listele()` eski kümeye döner (adet = öncesi 11), `gebelik_muayene_listele()` "function does not exist".

---

## Bilinen sapmalar ve spec-notları (review'a sunulur)

| # | Sapma/not | Gerekçe |
|---|---|---|
| 1 | Migration hedef numarası `20260925000002` (SPEC §4 `20260925000001` der) | Plan S1 AYNI numarayı alıyor — CONFIRMED plan-s1.md Adım 1; eşzamanlı 10-agent disiplini tek-atama ister; Adım 1'de dinamik doğrulama korunur |
| 2 | Demo apply kanalı = Mgmt API query endpoint (`SUPABASE_DEMO_REF`+`SUPABASE_DEMO_PAT`) veya demo pooler psql — **tools-bank `supabase_migrate` KULLANILMAZ** (SPEC §8 "psql" der) | **Onarım turu F7:** tools-bank kanalı PROD'a bağlıdır (CONFIRMED `server.py` ref `zqnexqbdfvbhlxzelzju`; S1 fafdda1 + S5 R3/B3 ile aynı kural); v1.0'daki bu satır "tools-bank demo'ya bakar" diyordu — PROD-apply riski taşıyordu, iptal edildi |
| 3 | Tek commit A migration için (SPEC §8 apply-sonrası ikinci commit der) | Dosya apply'da değişmediği için ikinci commit içi boş olur; commit A tek kanıt noktası |
| 4 | `gebelik_muayene_gorev_uret(false)` MANUEL koşulmaz; gerçek üretim gece cron'unda | S9 "dry-run liste onaylı koşum" kapısı + D6 (_uret authenticated'a kapalı); A7 sabah-koşumu izleme notuna bağlandı (ajan bekleyemez) |
| 5 | Muayene sıralama saf-test'i `_dashBands` expose ile (SPEC §7-B2 "yardımcı eklenirse" der) | Yeni yardımcı YOK — RPC DESC sıralı döner, band girdi sırasını korur (SPEC §5-7 ORDER BY); expose+3 test B2'nin ruhusunu karşılar, `_sessizGrupla` imzası değişmez (D7) |
| 6 | Muayene satır/lindelerde `escAttr(m.hayvan_id)` ekstra kaçırma (sessiz bandı esc'siz UUID kullanıyor) | Güvenlik review disiplini (7-Critical XSS dersi); RPC UUID döndürür → davranış farkı yok, sadece savunma |
| 7 | `_showSessizList` boş-sessiz+dolu-muayene durumunda sheet açar | SPEC D7 "sheet'inde en üstte ayrı bölüm" şartının gereği; toast yalnız ikisi de boşken |
| 8 | `_dashBands` 14 mevcut parametre → `muayeneList` **15.** parametre; 3f test çağrıları 15 argüman | Onarım turu F1+F2: v1.0'daki "16. parametre" off-by-one'ydı; test 1-2'nin 16-argümanlı çağrıları test 2'yi kıracaktı (liste verisi 16. pozisyonda discard) — CONFIRMED `js/ui.js:270` sayımı |
| 9 | Adım 1.4 grep beklentileri: `'>= 50'`=3 (reconcile 2 + stat 1), `COALESCE(…)>=50`=1 (yalnız stat), ek kontrol `CURRENT_DATE - 50`>=1 (view) | Onarım turu F4: v1.0 beklenenleri (2 ve "view sayılır") taslak gerçek koşumuyla uyumsuzdu — CONFIRMED taslak grep 6/3/0/1/1 |
| 10 | Spec Z8-Z13 + bu planın "beklenti" sayaçları **PROD gözlemidir** (tools-bank kanalı); DEMO gerçek değerleri Adım 0'da DEMO kanalından ölçülür, sapma kanıt zarfına yazılır | Onarım turu F7 — bu turda PROD'dan okunan değerler: sessiz 11, stat 9, açık GK 45, muayene kaba 5/filtreli 3 (180/173/902), 173 tohumlama `ce96ca6d` 2026-07-30; yazma yapılmadı (salt-SELECT + readonly RPC + BEGIN/ROLLBACK probe) |

## ENGEL özeti (onarım turu sonrası)

Çözülmemiş engel YOK. Onarım turunda kapanan iki kritik kalem: **(1) KANAL KURALI (F7)** — v1.0'ın "tools-bank `supabase_migrate` demo'ya bakar" cümlesi yanlıştı (kanal PROD'a bağlı — CONFIRMED `server.py`); Adım 0/2 artık DEMO kanalını (Mgmt query endpoint / demo psql) emreder; bu hata uygulanmış olsaydı migration PROD'a yazılacaktı. **(2) Param/grep sapmaları (F1/F2/F4)** — 15. parametre düzeltmesi + 15-argümanlı test çağrıları + gerçek grep beklentileri işlendi. Bilinen borçlar (db-validate B.sema-uyum statik çözümleyici, C2 text-PK seeder, baseline PK/pg_cron eksikliği) Adım 1 deseniyle aşıldı ve Adım 4'te BUGS.md'ye kaydediliyor (SPEC §11 ile uyumlu). Eşzamanlılık riskleri (migration numarası çakışması, ui.js paylaşımlı tek-yazıcı, BUGS.md APPEND-only) Adım 1/3/4 kapılarında çözüldü; analyze worktree-yol kuralı Adım 0.2/6'da (F6).
