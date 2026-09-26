# PLAN S1 — Kısır hayvan Ovsync bloğu (implementasyon planı)

> **Tarih:** 2026-09-24 · **Dal:** `ovysch-feature-cila-turu` · **SPEC:** `docs/plans/2026-09-24-ovsync-cila/spec-s1.md`
> **Plan sürümü:** 1.1 (onarım turu — iki geçiş: R1-R6 repo çapaları, R7-R10 kanal/yapı/şema doğrulaması; bkz. son "Onarım turu kaydı" bölümü)
> **KANAL KURALI (bağlayıcı):** tools-bank `supabase_*` MCP araçları **PROD**'a bağlı (ref `zqnexqbdfvbhlxzelzju` — CONFIRMED `~/tools-bank/mcp_server/server.py:307-312` + `js/api.js:23-24`). Bu plandaki TÜM demo okuma/apply adımları demo kanalını kullanır: `/home/melik/egesut-erp1/.env` → `SUPABASE_DEMO_REF` (`vtzqjmazsvurxdeondmi`) + `SUPABASE_DEMO_PAT` ile Mgmt API `POST /v1/projects/$SUPABASE_DEMO_REF/database/query` (kalıcı; saatlik `~/tmp/*token*` dosyalarına bağımlı DEĞİL) veya demo pooler psql. Prod'a yalnız SELECT ile bilinçli karşılaştırma hariç hiçbir kanıtta kullanılmaz (R7-R10).
> **Bant:** Prod'a PUSH/MERGE YOK. Demo DB yazımı sahibin 2026-09-24 onayıyla SERBEST. Commitler yalnız bu dala.
> **Tek-yazıcı zarf:** `supabase/migrations/20260925000001_ovsync_kisir_blok.sql` (YENİ), `supabase/tests/ovsync_pg_kabul.sql` (APPEND), `js/ui.js` (iki lokal nokta), `index.html` (damga). Zarf-dışı dosyaya yazma YOK.
> **Eşzamanlılık (10 agent):** migration numarası tek-atama (Adım 1 başında `ls` ile doğrulanır); `js/ui.js` bu turun tek-yazıcı dosyasıdır — Plan 3'ün ui.js kulvarı Adım 4'ün commit'inden önce başlamaz.
> **Kanıt etiketleri:** CONFIRMED (dosya:satır) / OBSERVED / INFERRED / UNKNOWN.
> **Kesintisiz koşum ilkesi:** her adımın kapısı yeşilse durma; bir kapı kırmızıysa o adımı düzelt ve yalnız çözemediğin kısmı "ENGEL:" diye raporla, kalan adımlara devam et.

## Adım haritası ve bağımlılıklar

| Adım | İş | Bağımlılık | Çıkış kapısı |
|---|---|---|---|
| 0 | Ön-kontrol + canlı gövde ölçümü | — | 4 gövde repo çapalarıyla birebir |
| 1 | Migration dosyası (M1+M2+M3+U1) | 0 | `db-validate.sh` taslakta PASS → commit A |
| 2 | Kabul blokları S1-T1…T7 + izole koşum | 1 | `OZET: N1 PASS`, N1 = N0 + 19 → commit B |
| 3 | Demo apply + T8-T10 salt-okunur doğrulama | 2 + final db-validate | 3/3 NULL, 0 kisir açık görevli, dry-run temiz |
| 4 | UI kilidi (ui.js iki nokta + damga) | 3 (RPC alanı hazır olsun) | `detect_changes` + `test:unit` yeşil → commit C |
| 5 | Tam-dogrulama taraması | 1-4 | self-check listesi tam |
| 6 | Teslim paketi + son review kapısı | 5 | review zarfı hazır, gitnexus re-analyze |

---

## Adım 0 — Ön-kontrol ve canlı gövde ölçümü (kapı: `code-change-precheck` + gitnexus)

**Dosya:** yazma yok (yalnız ölçüm; dökümler `~/tmp/` altına — `/tmp` yazma YOK, tmpfs kuralı).

1. `git status --short` → yalnız ön-existing `BUGS.md` kirli; commit'lerde **stage disiplini**: yalnız `git add <belirli dosya>`, sonra `git diff --cached --stat` ile doğrula (BUGS.md'yi süpürme).
2. GitNexus indeksi bayat (OBSERVED 2026-09-24: `list_repos` → egesut-erp1, 4 commit geride, main checkout). Kural gereği: `gitnexus analyze /home/melik/egesut-erp1` çalıştır; sonra impact'ler:
   - `start_first_service_protocol` (upstream) → beklenen arayanlar: `ilk_tohumlama_zamanlayici` (SQL, 20260924000002:L206) + `js/ui.js:1176` (`ovsyncBaslat` rpc çağrısı — `js/forms.js`'te arayan YOK; `js/api.js:320` yalnız RPC→tablo etki haritası);
   - `ovsync_baslat_uyarilari` (upstream) → beklenen: `js/ui.js` protokol paneli;
   - `_acik_disi_hedef_ic` / `_acik_disi_ovsync_hedef` (upstream) → beklenen: `_acik_disi_gorev_kur`, zamanlayıcı;
   - `_ovsyncBaslatBtnHtml` (upstream) → beklenen: `renderTask` (:L1259) + `tests/unit/ovsync-pg-ui.test.js`.
   Beklenmedik bir arayan çıkarsa DUR ve raporla (zarf genişletmesi gerekir).
3. `code-change-precheck` skill'ini yükle ve sözleşmesini uygula (iş bitince LSP kapanır — Adım 6).
4. **Canlı gövde ölçümü** (DEMO kanalı — BAĞLAYICI KANAL KURALI: tools-bank `supabase_*` araçları PROD'a bakar, ref `zqnexqbdfvbhlxzelzju` — CONFIRMED `~/tools-bank/mcp_server/server.py` `SB_URL`/`SB_PROJECT` satırları + `js/api.js:23-24` (PROD_URL/DEMO_URL). DEMO ref: `vtzqjmazsvurxdeondmi`. Bu turdaki TÜM demo ölçüm/apply DEMO kanalından: `curl -X POST https://api.supabase.com/v1/projects/$SUPABASE_DEMO_REF/database/query` (`.env` → `SUPABASE_DEMO_REF`+`SUPABASE_DEMO_PAT`) veya demo pooler psql. tools-bank kanalı bu turda HİÇBİR adımda kullanılmaz — okuma dâhil (spec §13/V8)) — bu kanalla asla UPDATE/DELETE gönderme:

```sql
SELECT proname, pg_get_functiondef(oid)
  FROM pg_proc
 WHERE pronamespace = 'public'::regnamespace
   AND proname IN ('_acik_disi_hedef_ic','start_first_service_protocol',
                   'ilk_tohumlama_zamanlayici','ovsync_baslat_uyarilari');
```

   Çıktıyı `~/tmp/s1-canli-govdeler.sql`'e yaz; her gövdede şu çapa imzalarını ara (CONFIRMED repo çapaları):
   - `_acik_disi_hedef_ic`: `SELECT durum, cinsiyet INTO v_h` (kisir YOK — diff öncesi zemin), `20260924000002:L21-68` ile birebir;
   - `start_first_service_protocol`: `v_neden := 'AKTIF_DEGIL'` ELSIF zinciri, KISIR YOK (`20260924000001:L662-851`);
   - `ilk_tohumlama_zamanlayici`: dry dal `_acik_disi_hedef_ic` çağrısı, `kisir` YOK (`20260924000002:L99-301`);
   - `ovsync_baslat_uyarilari`: `kategori, COALESCE(h.kategori, h.grup)` + `kisir` alanı YOK (`20260924000001:L1089-1126`).
   İmzalardan biri tutmazsa (canlı repo'dan farklıysa) DURMA: canlı gövdeyi esas al, diff'leri ona uygula, farkı çıktıda belirt.

**Doğrulama:** 4/4 çapa imzası canlıda bulundu (veya fark belgelendi). **Commit yok.**

---

## Adım 1 — Migration dosyası: `supabase/migrations/20260925000001_ovsync_kisir_blok.sql` (YENİ)

**Ön koşul:** `ls supabase/migrations/ | grep 20260925` → boş (OBSERVED 2026-09-24: en son `20260924000002`). Doluysa bir sonraki boş `20260925NNNNNN` numarasını al ve plan boyunca o adı kullan.

**Dosya iskeleti** (SPEC §6.5; başlıkta amaç/otorite/ROLLBACK yorumu; sonunda `NOTIFY pgrst, 'reload schema';`; anon GRANT YOK):

```sql
-- ============================================================================
-- Migration: 20260925000001_ovsync_kisir_blok
-- SPEC: docs/plans/2026-09-24-ovsync-cila/spec-s1.md
-- Amaç: kisir=true hayvanda ovsync üretim/başlatma bloğu (M1 uygunluk + M2
--       Başlat muafiyeti + M3 dry-run rapor doğruluğu + U1 RPC kisir alanı).
-- Kapsam: yalnız bu dört fonksiyon; şema/privilej değişikliği yok; anon GRANT yok.
-- ROLLBACK: dört gövdenin kisir-öncesi halleri repo migration'larında
--   (_ic → 20260924000002:L21-68; start → 20260924000001:L662-851;
--    zamanlayıcı → 20260924000002:L99-301; uyarılar → 20260924000001:L1089-1126).
-- ============================================================================
-- <M1> <M2> <M3> <U1>  (aşağıda)
NOTIFY pgrst, 'reload schema';
-- EOF 20260925000001
```

### M1 — `_acik_disi_hedef_ic` (tam gövde: `20260924000002:L21-68` kopyası + 2 diff)

Tam `CREATE OR REPLACE FUNCTION public._acik_disi_hedef_ic(p_hayvan_id text) … $fn$` bloğunu `20260924000002:L21-68`'den kopyala, sonra:

- **DIFF 1 — :L33 satırını değiştir:**
  - ESKİ: `  SELECT durum, cinsiyet INTO v_h FROM public.hayvanlar WHERE id = p_hayvan_id;`
  - YENİ:
    ```sql
      SELECT durum, cinsiyet, COALESCE(kisir, false) AS kisir
        INTO v_h FROM public.hayvanlar WHERE id = p_hayvan_id;
    ```
- **DIFF 2 — :L34-36'daki Aktif/Dişi `IF…END IF;` bloğunun HEMEN ARDINA ekle:**
  ```sql
    IF v_h.kisir THEN
      RETURN NULL;
    END IF;
    ```

- **COMMENT güncelle (:L70-71 yerine):**
  ```sql
  COMMENT ON FUNCTION public._acik_disi_hedef_ic(text) IS
    'R3.2 SK7 bayrak-yoksayan uygunluk (yalnız dry-run önizleme; iş yaratmaz). Muaf: kısır, Aktif değil/Dişi değil, Gebe/Bekliyor, aktif senkronizasyon vakası, açık OVSYNC_BASLAT, tabansız.';
  ```
- **ACL aynen korunur:** `REVOKE ALL ON FUNCTION public._acik_disi_hedef_ic(text) FROM PUBLIC, anon, authenticated;`

### M2 — `start_first_service_protocol` (tam gövde: `20260924000001:L662-845` kopyası + 1 diff)

- **DIFF — :L712 ile :L713 ARASINA** (yani `v_neden := 'AKTIF_DEGIL';` satırından sonra, `ELSE`'den önce) ELSIF ekle:
  ```sql
    ELSIF COALESCE(v_h.kisir, false) THEN
      v_neden := 'KISIR';
  ```
  Zincir sonrası sıra: `AKTIF_DEGIL → KISIR → (ELSE) MK3 GEBE/BEKLIYOR/AKTIF_SENKRONIZASYON` (SPEC §4.2 — KISIR GEBE'den ÖNCE; sırayı T6 kilitler). :L714-729 MK3 bloğu AYNEN KORUNUR. **Yapı notu (onarım turu):** canlı blok düz ELSIF zinciri DEĞİL — `IF AKTIF_DEGIL THEN … ELSE <iç-IF MK3, :L719-728> END IF`; mekanik, `ELSE` satırını `ELSIF COALESCE(v_h.kisir,false) THEN v_neden := 'KISIR'; ELSE` biçiminde BÖLMEKTİR (MK3 iç-IF'i ELSE içinde kalır — spec §6.2 "Canlı yapı notu"). `SELECT * INTO v_h … FOR UPDATE` (:L710) DEĞİŞMEZ — `kisir` zaten `v_h`'te taşınır. Muafiyet kapanış yolu (:L731-744) DEĞİŞMEZ — `kapatan_ref='ILK_TOH_MUAF:KISIR'`, instance `iptal`, `FIRST_SERVICE_SKIPPED`, dönüş `{ok:true, atlandi:'KISIR', gorev_id}` otomatik gelir.
- **COMMENT güncelle (:L847-848):** muafiyet listesine `KISIR` ekle: `'… Muafiyetler: AKTIF_DEGIL/KISIR/GEBE/BEKLIYOR/AKTIF_SENKRONIZASYON (TOHUMLAMA_VAR kalktı, SK7; KISIR S1).'` (davranışsız, dokümantasyon doğruluğu)
- **ACL aynen (:L850-851):** `REVOKE ALL … FROM PUBLIC, anon; GRANT EXECUTE … TO authenticated, service_role;`

### M3 — `ilk_tohumlama_zamanlayici` (tam gövde: `20260924000002:L99-295` kopyası + 2 diff)

- **`DROP FUNCTION IF EXISTS public.ilk_tohumlama_zamanlayici();` satırını (:L97) KOPYALAMA** — yeni migration DROP İÇERMEZ; imza korunur (`p_dry_run boolean DEFAULT false`) → pg_cron `select public.ilk_tohumlama_zamanlayici()` çağrısı kesilmez (INFERRED).
- **DIFF A — dry-run tarama SELECT'i (:L132):**
  - ESKİ: `       WHERE h.durum = 'Aktif' AND h.cinsiyet = 'Dişi'`
  - YENİ:
    ```sql
       WHERE h.durum = 'Aktif' AND h.cinsiyet = 'Dişi'
         AND NOT COALESCE(h.kisir, false)
    ```
- **DIFF B — gerçek-dal `duve_tabansiz` sayacı (:L264):**
  - ESKİ: `   WHERE h.durum = 'Aktif' AND h.cinsiyet = 'Dişi'`
  - YENİ:
    ```sql
       WHERE h.durum = 'Aktif' AND h.cinsiyet = 'Dişi'
         AND NOT COALESCE(h.kisir, false)
    ```
- **Bilinçli kapsam notu (spec §6.3):** gerçek-dal TARAMA SELECT'i (:L238-241) filtrelenmez — orada davranışı `_acik_disi_ovsync_hedef→_ic` NULL'u taşır (kısıra görev açılmaz); yalnız gerçek-koşum `taranan` sayacı kısırları saymaya devam eder (audit istatistiği, davranış değil). Sapma DEĞİL, spec kararı.
- **COMMENT (:L297-298) aynen; ACL aynen (:L300-301):** `REVOKE ALL … FROM PUBLIC, anon; GRANT EXECUTE … TO authenticated, service_role;`

### U1 — `ovsync_baslat_uyarilari` (SPEC §6.4'ün TAM gövdesini kullan)

SPEC §6.4'teki gövde repo'daki canlı gövdenin (`20260924000001:L1089-1126`) birebir kopyası + tek satırdır — olduğu gibi kopyala. Tek diff (referans): `'kategori', COALESCE(h.kategori, h.grup),` satırından sonra
```sql
               'kisir', COALESCE(h.kisir, false),
```
COMMENT: `'… S1: kisir alanı eklendi (UI kilidi için). Salt-okuma.'`; ACL aynen: `REVOKE ALL … FROM PUBLIC, anon; GRANT EXECUTE … TO authenticated, service_role;`

### Kapı ve commit

- **Kapı (taslak db-validate):** `bash scripts/db-validate.sh supabase/migrations/20260925000001_ovsync_kisir_blok.sql` → çıkış 0, `ERROR` yok. DML/UNIQUE/FK içermediğinden data-mode gerekmez (aracın `auto` kararı). FAIL ise hatayı düzelt, yeniden koş.
- **Doğrulama:** `grep -c 'CREATE OR REPLACE FUNCTION' <dosya>` = 4; `grep -ci kisir <dosya>` ≥ 5; `grep -i 'TO anon\|GRANT.*anon ' <dosya>` → eşleşme YOK (anon kuralı).
- **Commit A:**
  ```
  feat(db): S1 kısır ovsync bloğu (M1 uygunluk + M2 Başlat muafiyeti + M3 dry-run filtresi + U1 kisir alanı)

  Co-Authored-By: Claude Code <noreply@anthropic.com>
  ```

---

## Adım 2 — Kabul blokları: `supabase/tests/ovsync_pg_kabul.sql` (APPEND) + izole koşum

**İSİM UYARISI (spec'ten isim sapması, gerekçeli):** spec §5 "R32-11 blokları" der ama `R32-11` etiketi dosyada ZATEN VAR (CONFIRMED `supabase/tests/ovsync_pg_kabul.sql:L1682-1696` — "dry-run BAYRAK KAPALIYKEN de adayları SAYAR" bloğu). Yeni bloklar **`S1-T1`…`S1-T6`** etiketini kullanır (T7 ayrı blok değildir — mevcut blokların koşumudur); APPEND noktası: son blok (`R32-10`/SK10, `PASS R32-10/SK10 …` NOTICE'ı :L1749, `END $t$;` :L1750) ile `-- ÖZET` ayıracı (:L1754) ARASI. Yalnız ekleme; mevcut hiçbir satır değişmez.

**Sözleşme (K15, README):** betik migration uygulamaz, BEGIN/ROLLBACK taşırmaz; her test DO bloğu; `pg_temp.kb_ok(koşul, etiket, beklenen, gerçek)` — FAIL ilk exception'da koşumu durdurur; sonda `OZET: N PASS`.

### 2a — Kabul DB'sini taze kur + baseline koşum (T7 kanıtı)

```bash
# DB var mı / taze kur (build.sh DB'yi DROP+CREATE eder — temiz zemin):
psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -tAc 'SELECT 1' 2>/dev/null \
  || (cd scripts/kabul-db && ./build.sh)          # ağ yoksa: KABUL_OFFLINE=1 ./build.sh

# BASELINE: zincir YENİ migration DAHİL, test dosyası henüz bloksuz → N0'ı not et:
( echo 'BEGIN;';
  cat supabase/migrations/20260923000001_dogum_kaydet_pg_d39_geri.sql \
      supabase/migrations/20260923000002_ovsync_pg_sema.sql \
      supabase/migrations/20260923000003_ovsync_pg_yardimcilar.sql \
      supabase/migrations/20260923000004_ovsync_pg_uygulama_kapisi.sql \
      supabase/migrations/20260923000005_ovsync_vaka_kapanis.sql \
      supabase/migrations/20260923000006_ilk_tohumlama_zinciri.sql \
      supabase/migrations/20260924000001_ovsync_pg_r32_acik_disi.sql \
      supabase/migrations/20260924000002_dryrun_bayrak_bagimsiz.sql \
      supabase/migrations/20260925000001_ovsync_kisir_blok.sql \
      supabase/tests/ovsync_pg_kabul.sql;
  echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -v ON_ERROR_STOP=1 2>&1 \
  | tee ~/tmp/s1-kabul-baseline.log | tail -3
```

(NOT: README'deki zincir `2026092300000{1..6}` ile sınırlı ve bayat — R32 blokları 09-24 migrasyonlarını gerektirir; README spec zarfında dokunulmayacaklar listesinde olduğundan YENİLENMEZ, bu düzeltilmiş zincir kullanılır.)

**Kabul şeması notu (onarım turu):** `build.sh` kabul şemasını **canlı PROD public şemasının VERİSİZ kopyasından** kurar (CONFIRMED `scripts/kabul-db/build.sh:2,51` — `SB_PROJECT_REF` öntanımlı prod ref). S1 bloklarının elle INSERT'leri bu şemada güvenli: `hayvanlar`'da default'suz NOT NULL tek kolon `id` (OBSERVED demo `information_schema`, 2026-09-24 — demo prod klonu; S1-T5'in `dogum_tarihi`'siz INSERT'i geçerli); `gorev_log`/`tohumlama`'da zorunlu kolon yok; `cases(animal_id,disease_id)`/`islem_log(tip,snapshot)`/`protokol_ayar(anahtar,deger)` zorunluları yalnız okunan/UPDATE'lenen tablolar.

**Beklenen:** `KABUL TAMAM: tüm testler PASS` + `OZET: N0 PASS`. Bir FAIL çıkarsa: yeni migration'ın mevcut blokları kırdığı demektir → Adım 1'e dön (muhtemel aday: R32-5 `duve_tabansiz ≥ 1` ve R32-11 `acilacaklar` üyeliği — ikisi de kisir=false fixture kullandığından kırılmamalı; kırılırsa DIFF'leri gözden geçir).

### 2b — S1-T1…T7 bloklarını APPEND et

Aşağıdaki altı DO bloğunu aynen ekle (ÖZET ayıracından önce; S1-T7 ayrı blok değildir — bkz. 2b sonu):

**Bayrak devri (önemli):** S1 blokları `ovsync_pg_kurallari_aktif = 1` devralır — R32-11 bloğunun son UPDATE'i :L1695'te `deger = 1` yapar (CONFIRMED `supabase/tests/ovsync_pg_kabul.sql:L1688/L1695`; kolon `numeric` — CONFIRMED `20260620000001_protokol_ayar.sql:L6`, mevcut deseni :L428). S1-T1 ek olarak kendisi de bayrağı 1'e çeker; S1-T2/T3/T4/T6'nın `start_first_service_protocol` çağrıları bu sayede `OZELLIK_KAPALI` fırlatmaz (CONFIRMED `20260924000001:L687-690`).

```sql
-- ════════════════════════════════════════════════════════════════════════════
-- S1 — Kısır hayvan Ovsync bloğu (SPEC: docs/plans/2026-09-24-ovsync-cila/spec-s1.md §8)
-- Migration: 20260925000001_ovsync_kisir_blok
-- ════════════════════════════════════════════════════════════════════════════

-- S1-T1 (D1): kisir=true → üç üretim kanalı bloke
DO $t$
DECLARE v_a text; v_gid uuid; v_n int;
BEGIN
  UPDATE public.protokol_ayar SET deger = 1 WHERE anahtar = 'ovsync_pg_kurallari_aktif';  -- bayrak açıkken de blok
  v_a := pg_temp.kb_hayvan(800, 'Aktif', true);
  PERFORM pg_temp.kb_ok(public._acik_disi_hedef_ic(v_a) IS NULL, 'S1-T1', 'kisir: _acik_disi_hedef_ic NULL', NULL);
  PERFORM pg_temp.kb_ok(public._acik_disi_ovsync_hedef(v_a) IS NULL, 'S1-T1', 'kisir: _acik_disi_ovsync_hedef NULL (bayrak 1)', NULL);
  v_gid := public._acik_disi_gorev_kur(v_a);
  PERFORM pg_temp.kb_ok(v_gid IS NULL, 'S1-T1', 'kisir: _acik_disi_gorev_kur NULL', NULL);
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE hayvan_id = v_a AND gorev_tipi = 'OVSYNC_BASLAT';
  PERFORM pg_temp.kb_ok(v_n = 0, 'S1-T1', 'kisir: OVSYNC_BASLAT üretilmedi', v_n::text);
  RAISE NOTICE 'PASS S1-T1: kisir üretim bloğu (ic/hedef/kur NULL, görev 0)';
END $t$;

-- S1-T2 (D2): elle kurulmuş açık görev → Başlat atlanır, zincir açılmaz (instance'sız — R32-9 adabı)
DO $t$
DECLARE v_a text; v_gid uuid; v_r jsonb; v_n int;
BEGIN
  v_a := pg_temp.kb_hayvan(800, 'Aktif', true);
  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, hedef_saat, tamamlandi, iptal, kaynak)
  VALUES (gen_random_uuid(), v_a, 'OVSYNC_BASLAT', 'S1-T2 elle kurulmuş', CURRENT_DATE, '10:00', false, false, pg_temp.kb_id('ILK-TOH-KB'))
  RETURNING id INTO v_gid;
  v_r := public.start_first_service_protocol(v_gid);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND v_r->>'atlandi' = 'KISIR', 'S1-T2', 'atlandi=KISIR', v_r::text);
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE id = v_gid AND iptal AND tamamlandi AND kapatan_ref = 'ILK_TOH_MUAF:KISIR';
  PERFORM pg_temp.kb_ok(v_n = 1, 'S1-T2', 'görev iptal+tamamlandı, ILK_TOH_MUAF:KISIR', v_n::text);
  SELECT count(*) INTO v_n FROM public.cases WHERE animal_id = v_a AND protocol_family = 'OVSYNC';
  PERFORM pg_temp.kb_ok(v_n = 0, 'S1-T2', 'vaka açılmadı', v_n::text);
  SELECT count(*) INTO v_n FROM public.islem_log WHERE tip = 'FIRST_SERVICE_SKIPPED' AND ref_id = v_gid::text AND payload->>'neden' = 'KISIR';
  PERFORM pg_temp.kb_ok(v_n = 1, 'S1-T2', 'FIRST_SERVICE_SKIPPED audit (neden=KISIR)', v_n::text);
  RAISE NOTICE 'PASS S1-T2: Başlat kısırdı atlar, zincir yok, audit var';
END $t$;

-- S1-T3 (D4): işaret kaldırılınca normal kurala döner (fail-closed DEĞİL)
DO $t$
DECLARE v_a text; v_gid uuid; v_n int;
BEGIN
  v_a := pg_temp.kb_hayvan(800, 'Aktif', true);
  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, hedef_saat, tamamlandi, iptal, kaynak)
  VALUES (gen_random_uuid(), v_a, 'OVSYNC_BASLAT', 'S1-T3 ön-kapatma', CURRENT_DATE, '10:00', false, false, pg_temp.kb_id('ILK-TOH-KB'))
  RETURNING id INTO v_gid;
  PERFORM pg_temp.kb_ok((public.start_first_service_protocol(v_gid)->>'atlandi') = 'KISIR', 'S1-T3', 'ön-koşul: kisir iken atlandı', NULL);
  UPDATE public.hayvanlar SET kisir = false WHERE id = v_a;
  PERFORM pg_temp.kb_ok(public._acik_disi_gorev_kur(v_a) IS NOT NULL, 'S1-T3', 'kisir=false → görev AÇILIR', NULL);
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE hayvan_id = v_a AND gorev_tipi = 'OVSYNC_BASLAT' AND NOT iptal AND kaynak LIKE 'ACIK-DISI-%';
  PERFORM pg_temp.kb_ok(v_n = 1, 'S1-T3', 'açık-dişi görevi kuruldu', v_n::text);
  RAISE NOTICE 'PASS S1-T3: işaret kaldırılınca normal kurala dönüş';
END $t$;

-- S1-T4 (D3 veri zemini): RPC kisir alanı + açık-görev filtresi davranışı korunur
DO $t$
DECLARE v_a text; v_gid uuid; v_r jsonb; v_n int;
BEGIN
  v_a := pg_temp.kb_hayvan(800, 'Aktif', true);
  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, hedef_saat, tamamlandi, iptal, kaynak)
  VALUES (gen_random_uuid(), v_a, 'OVSYNC_BASLAT', 'S1-T4 pencere-içi', CURRENT_DATE, '10:00', false, false, pg_temp.kb_id('ILK-TOH-KB'))
  RETURNING id INTO v_gid;
  v_r := public.ovsync_baslat_uyarilari();
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_r->'uyarilar') e
   WHERE e->>'gorev_id' = v_gid::text AND jsonb_typeof(e->'kisir') = 'boolean' AND (e->>'kisir')::boolean;
  PERFORM pg_temp.kb_ok(v_n = 1, 'S1-T4', 'kisir hayvan listede, kisir boolean=true', v_n::text);
  UPDATE public.gorev_log SET iptal = true, tamamlandi = true WHERE id = v_gid;   -- elle kapatma yolu
  v_r := public.ovsync_baslat_uyarilari();
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_r->'uyarilar') e WHERE e->>'gorev_id' = v_gid::text;
  PERFORM pg_temp.kb_ok(v_n = 0, 'S1-T4', 'kapalı görev listeden düşer (filtre değişmedi)', v_n::text);
  RAISE NOTICE 'PASS S1-T4: RPC kisir alanı + pencere filtresi';
END $t$;

-- S1-T5 (D5): dry-run raporu kısırı yanlış kategoriye yazmaz (delta yöntemi)
DO $t$
DECLARE v_z1 jsonb; v_z2 jsonb; v_norm text; v_kisir_tabanli text; v_n int;
BEGIN
  v_z1 := public.ilk_tohumlama_zamanlayici(p_dry_run := true);          -- ÖNCE
  v_norm        := pg_temp.kb_hayvan(800, 'Aktif', false);              -- kontrol: aday
  v_kisir_tabanli := pg_temp.kb_hayvan(800, 'Aktif', true);             -- kisir + tabanlı (acilacaklar adayı OLAMAZ)
  INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, durum, irk, kisir)   -- kisir + tabansız (duve_tabansiz adayı OLAMAZ)
  VALUES (pg_temp.kb_id('KB'), pg_temp.kb_id('KB'), 'Dişi', 'Aktif', 'Holstein', true);
  v_z2 := public.ilk_tohumlama_zamanlayici(p_dry_run := true);          -- SONRA
  PERFORM pg_temp.kb_ok((v_z2->>'taranan')::int = (v_z1->>'taranan')::int + 1,
    'S1-T5', 'taranan yalnız +1 (kisir hayvanlar sayılmaz — DIFF A)', (v_z1->>'taranan') || ' -> ' || (v_z2->>'taranan'));
  PERFORM pg_temp.kb_ok((v_z2->>'duve_tabansiz')::int = (v_z1->>'duve_tabansiz')::int,
    'S1-T5', 'duve_tabansiz değişmedi (kisir+tabansız sayılmaz — DIFF A filtreli taraması; dry-run sayacı dry döngüde 20260924000002:L137-153''te hesaplanır, DIFF B gerçek-dal sayacıdır :L262-277)', (v_z1->>'duve_tabansiz') || ' -> ' || (v_z2->>'duve_tabansiz'));
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_z2->'acilacaklar') e WHERE e->>'hayvan_id' = v_kisir_tabanli;
  PERFORM pg_temp.kb_ok(v_n = 0, 'S1-T5', 'kisir+tabanlı acilacaklar''da YOK', v_n::text);
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_z2->'acilacaklar') e WHERE e->>'hayvan_id' = v_norm;
  PERFORM pg_temp.kb_ok(v_n = 1, 'S1-T5', 'kontrol (kisir=false) acilacaklar''da VAR', v_n::text);
  RAISE NOTICE 'PASS S1-T5: dry-run kısırdı hiçbir sayaca/ listeye yazmaz';
END $t$;

-- S1-T6 (D2/§4.2): kisir + son tohumlama Gebe → atlandi=KISIR (GEBE değil; sıra kilitlenir)
DO $t$
DECLARE v_a text; v_gid uuid; v_r jsonb; v_n int;
BEGIN
  v_a := pg_temp.kb_hayvan(800, 'Aktif', true);
  INSERT INTO public.tohumlama (hayvan_id, tarih, sonuc, sperma) VALUES (v_a, CURRENT_DATE - 100, 'Gebe', 'KB-SP');
  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, hedef_saat, tamamlandi, iptal, kaynak)
  VALUES (gen_random_uuid(), v_a, 'OVSYNC_BASLAT', 'S1-T6 çelişki', CURRENT_DATE, '10:00', false, false, pg_temp.kb_id('ILK-TOH-KB'))
  RETURNING id INTO v_gid;
  v_r := public.start_first_service_protocol(v_gid);
  PERFORM pg_temp.kb_ok((v_r->>'ok')::boolean AND v_r->>'atlandi' = 'KISIR', 'S1-T6', 'atlandi=KISIR (GEBE değil)', v_r::text);
  SELECT count(*) INTO v_n FROM public.gorev_log WHERE id = v_gid AND kapatan_ref = 'ILK_TOH_MUAF:KISIR';
  PERFORM pg_temp.kb_ok(v_n = 1, 'S1-T6', 'kapatan_ref ILK_TOH_MUAF:KISIR', v_n::text);
  RAISE NOTICE 'PASS S1-T6: KISIR muafiyeti GEBE''den önce';
END $t$;
```

(S1-T7 ayrı blok DEĞİLDİR: mevcut tüm blokların 2a/2c koşumlarında PASS olması T7'nin kendisidir — `OZET` sayacı bunu taşır.)

### 2c — İzole koşum

2a'daki zincir komutunu AYNI şekilde tekrar çalıştır → `~/tmp/s1-kabul.log`. **Kapı:**
- `KABUL TAMAM: tüm testler PASS`;
- `OZET: N1 PASS` ve **N1 = N0 + 19** (S1-T1: 4 + S1-T2: 4 + S1-T3: 3 + S1-T4: 2 + S1-T5: 4 + S1-T6: 2 = 19 kb_ok çağrısı — beklenen fark TAM 19; sayaç farkını log'dan doğrula, uyuşmazsa blokları satır satır say ve raporu buna göre ver).
- Tek FAIL → ilgili bloğu düzelt, yeniden koş (sarmalayıcı ROLLBACK attığından DB kirli kalmaz).

**Commit B:**
```
test(db): S1 kabul blokları (S1-T1..T6) — izole koşum PASS

Co-Authored-By: Claude Code <noreply@anthropic.com>
```

---

## Adım 3 — Demo apply + T8-T10 salt-okunur doğrulama

**Sıra disiplini:** ÖNCE final db-validate, SONRA apply (db-validation kapısı: "apply etmeden ÖNCE finalde").

1. `bash scripts/db-validate.sh supabase/migrations/20260925000001_ovsync_kisir_blok.sql` → çıkış 0 (final dosyada; Adım 1'den beri dosya değişmediyse tekrarı formel).
2. **Apply (DEMO — sahibin onayıyla):** dosyanın TAM içeriğini DEMO kanalına uygula: `POST /v1/projects/$SUPABASE_DEMO_REF/database/query` gövdesinde `{"query": "<tam migration SQL>"}` (Mgmt API; `SUPABASE_DEMO_PAT`). **UYARI (onarım turu):** tools-bank `supabase_migrate` KULLANILMAZ — o kanal PROD'a yazar (CONFIRMED server.py `SB_PROJECT= zqnexqbdfvbhlxzelzju`); v1.0'daki "bu kanal demo'ya bakar" cümlesi YANLIŞTI ve Adım 3'ü PROD-apply riski taşıyordu.
3. **Apply doğrulama (salt-SELECT, aynı DEMO kanalı):**
   ```sql
   SELECT proname,
          position('IF v_h.kisir'      in pg_get_functiondef(oid)) > 0 AS m1_ok,
          position('KISIR'             in pg_get_functiondef(oid)) > 0 AS m2_ok
     FROM pg_proc WHERE pronamespace='public'::regnamespace
       AND proname IN ('_acik_disi_hedef_ic','start_first_service_protocol');
   SELECT position('AND NOT COALESCE(h.kisir, false)' in pg_get_functiondef(oid)) > 0 AS m3_ok
     FROM pg_proc WHERE proname='ilk_tohumlama_zamanlayici' AND pronamespace='public'::regnamespace;
   SELECT position('''kisir'', COALESCE(h.kisir, false)' in pg_get_functiondef(oid)) > 0 AS u1_ok
     FROM pg_proc WHERE proname='ovsync_baslat_uyarilari' AND pronamespace='public'::regnamespace;
   ```
   Beklenen: m1_ok, m2_ok, m3_ok, u1_ok hepsi `true`.
4. **T8 (spec §8):** 184/199/208:
   ```sql
   SELECT h.kupe_no,
          public._acik_disi_ovsync_hedef(h.id) AS hedef,
          public._acik_disi_hedef_ic(h.id)     AS ic
     FROM public.hayvanlar h WHERE h.kupe_no IN ('184','199','208');
   ```
   Beklenen 3/3 satır `NULL|NULL`. Ardından görev-sayısı no-op kanıtı:
   ```sql
   SELECT count(*) FROM public.gorev_log
    WHERE hayvan_id IN (SELECT id FROM public.hayvanlar WHERE kupe_no IN ('184','199','208'))
      AND gorev_tipi='OVSYNC_BASLAT';                       -- ÖNCE
   SELECT public._acik_disi_gorev_kur(h.id) FROM public.hayvanlar h
    WHERE h.kupe_no IN ('184','199','208');                 -- 3x NULL beklenir (M1 ile no-op)
   -- SONRA: ilk sorgu tekrar → sayı DEĞİŞMEZ (0 görev yazıldı kanıtı)
   ```
5. **T9:** açık görevli kısır sayısı:
   ```sql
   SELECT count(*) FILTER (WHERE COALESCE(h.kisir,false)) AS kisir_acik_gorevli, count(*) AS acik_toplam
     FROM public.gorev_log g JOIN public.hayvanlar h ON h.id = g.hayvan_id
    WHERE g.gorev_tipi='OVSYNC_BASLAT'
      AND COALESCE(g.tamamlandi,false)=false AND COALESCE(g.iptal,false)=false;
   ```
   Beklenen: `kisir_acik_gorevli=0` (tek şart); `acik_toplam` tarih-bağımlı sabit DEĞİLDİR — OBSERVED 2026-09-24 DEMO'da 29 (v1.0'daki "31" tools-bank kanalından yanlışlıkla PROD ölçümüydü — K12'nin 1.1 düzeltmesi). `ovsync_baslat_uyarilari`'ni DEMO kanalından `SELECT public.ovsync_baslat_uyarilari();` ile çağır → `uyarilar[].kisir` anahtarı hepsinde boolean ve `false`.
6. **T10:** DEMO kanalından `SELECT public.ilk_tohumlama_zamanlayici(true);` (salt-okuma dal; tools-bank `supabase_rpc` KULLANILMAZ — PROD'a gider) → `acilacaklar[]` içinde kupe 184/199/208 YOK; `taranan`/`duve_tabansiz` değerlerini kaydet (Adım 6 zarfına kanıt).
7. Sorun yoksa UI'ya geç (Adım 4). Apply hatası olursa: hatayı düzelt (dosya + commit), db-validate, yeniden apply — engel çıkarsa "ENGEL:" diye raporla ve UI'ya devam et (UI, DB'siz de güvenli: `u.kisir`/`_h.kisir` gelmezse normal buton çizilir, DB muafiyeti M2 zaten korur).

**Commit yok** (DB işlemi; kanıtlar Adım 6 zarfına).

---

## Adım 4 — UI: `js/ui.js` iki lokal nokta + `index.html` damgası

### 4a — `_ovsyncBaslatBtnHtml` (:L1162-1166, görev kartı)

Fonksiyonun TAMAMINI şununla değiştir (Başlat/✕ stilleri :L1164-1165'ten aynen):

```js
// P3/P4: OVSYNC_BASLAT kart butonları — [Başlat] atomik RPC, [İptal] mevcut PATCH yolu
// S1: kisir hayvanda Başlat YOK, kilitli rozet VAR; ✕ her durumda çizilir.
function _ovsyncBaslatBtnHtml(t){
  if(t.gorev_tipi!=='OVSYNC_BASLAT'||t.tamamlandi||t.iptal) return '';
  const _h=(typeof getState==='function'?getState('animals'):[]).find(a=>a.id===t.hayvan_id);
  const _ipt=`<button data-g="${escAttr(t.id)}" onclick="event.stopPropagation();ovsyncIptal(this.dataset.g)" style="font-size:.65rem;padding:4px 8px;border-radius:8px;border:1px solid #999;background:transparent;color:#999;cursor:pointer">✕</button>`;
  if(_h&&_h.kisir) return `<span style="font-size:.62rem;font-weight:700;color:var(--amber)">💲 Kısır işaretli — başlatılamaz</span>${_ipt}`;
  return `<button data-g="${escAttr(t.id)}" onclick="event.stopPropagation();ovsyncBaslat(this.dataset.g)" style="font-size:.65rem;font-weight:700;padding:4px 10px;border-radius:8px;border:1px solid var(--green);background:rgba(78,154,42,.12);color:var(--green);cursor:pointer">▶ Başlat</button>${_ipt}`;
}
```

**ZORUNLU SAPMA — spec §7.1'e göre gerekçeli düzeltme:** spec'in sketch'i `getState('animals')`'ı korumasız çağırır; ama `tests/unit/ovsync-pg-ui.test.js:1-16` sandbox'ı yalnız `js/ui.js`'i yükler ve extras'a `getState` KOYMAZ (CONFIRMED `tests/unit/support/loadModule.js` + test :L40-45'in korumasız çağrısı) → sketch'in aynısı T14'ü (unit yeşil) KIRAR (`ReferenceError: getState is not defined`). `typeof getState==='function'` koruması: tarayıcıda her zaman 'function' (state.js:92 global tanım — davranış değişmez), sandbox'ta `[]`'a düşer → mevcut testler aynen geçer. Zarf-pure çözüm: unit test dosyası DOKUNULMADAN T14 sağlanır. (Kisir-bağlantı yolunun unit kapsamı Plan 3'ün ui.js kulvarına borç notu — BUGS.md'ye yazılmaz, spec §5 gereği.)

### 4b — `_ovSatir` buton hücresi (:L1840-1843, protokol uyarı paneli)

Yalnız buton hücresi `<div style="display:flex;gap:6px;align-items:center">…</div>` (:L1840-1843) şununla değiştir (mevcut stiller :L1841-1842'den aynen; satırın geri kalanı :L1834-1839 dokunulmaz):

```js
        <div style="display:flex;gap:6px;align-items:center">
          ${u.kisir
            ? `<span style="font-size:.62rem;font-weight:700;color:var(--amber)">💲 Kısır işaretli — üreme planı yok</span>
               <button data-g="${escAttr(u.gorev_id)}" onclick="ovsyncIptal(this.dataset.g)" style="font-size:.65rem;padding:4px 8px;border-radius:8px;border:1px solid #999;background:transparent;color:#999;cursor:pointer">✕</button>`
            : `<button data-g="${escAttr(u.gorev_id)}" onclick="ovsyncBaslat(this.dataset.g)" style="font-size:.65rem;font-weight:700;padding:4px 10px;border-radius:8px;border:1px solid var(--green);background:rgba(78,154,42,.12);color:var(--green);cursor:pointer">▶ Başlat</button>
               <button data-g="${escAttr(u.gorev_id)}" onclick="ovsyncIptal(this.dataset.g)" style="font-size:.65rem;padding:4px 8px;border-radius:8px;border:1px solid #999;background:transparent;color:#999;cursor:pointer">✕</button>`}
        </div>
```

(`u.kisir` Adım 3'te apply edilen U1'den gelir — sıralama bu yüzden DB önce. RPC alanı yoksa `u.kisir` undefined → normal buton: güvenli düşme, M2 DB muafiyeti yine korur. `--amber` değişkeni var — CONFIRMED `index.html:24`. `ovsyncBaslat` :L1177'deki `atlandi` toast'u ve `ovsyncIptal` :L1190-1199 DEĞİŞMEZ; hayvan kartı :L1597 ve kısır rozet :L1588 DEĞİŞMEZ — U3 doğrulaması Adım 5'te.)

### 4c — Damga: `index.html`

Spec §5 "tek satır" der; ancak `?v=` damgası TEK-DEĞER kuralı taşır (26 script tag'inde aynı değer — CONFIRMED `grep -c '?v=20260924-01' index.html` = 26; önceki bump `fe5f91d` da TÜM satırları değiştirdi). Tek değer bozulmasın diye TÜM geçekler güncellenir:

```bash
sed -i 's/?v=20260924-01/?v=20260925-01/g' index.html
grep -c '?v=20260925-01' index.html   # 26 beklenir
grep -c '?v=20260924-01' index.html   # 0 beklenir
```

### Kapılar ve commit

- `gitnexus detect_changes` (bu worktree; kapsamda ui.js + index.html görünmeli) → beklenmedik süreç etkilenmesi yok.
- `npm run test:unit` (T14) → tamamen yeşil; node_modules worktree'de yoksa: `NODE_PATH=/home/melik/egesut-erp1/node_modules npm run test:unit`. Kırmızı test varsa ve 4a korumasıyla ilgili DEĞİLSE incele; 4a ile kırılıyorsa bu planın sapma notunu tekrar oku.
- **Commit C (ui.js tek-yazıcı serbest bırakılır — Plan 3 bu commit'ten sonra başlayabilir):**
  ```
  feat(ui): S1 kısırdı Başlat kilidi (görev kartı + protokol paneli) + ?v=20260925-01

  Co-Authored-By: Claude Code <noreply@anthropic.com>
  ```

---

## Adım 5 — Tam-dogrulama taraması (self-check, yazma yok)

1. `git log --oneline main..HEAD` → A, B, C commit'leri; `git status --short` → yalnız ön-existing `BUGS.md`.
2. `git diff --stat main..HEAD` → yalnız zarf dosyaları: yeni migration, `supabase/tests/ovsync_pg_kabul.sql`, `js/ui.js`, `index.html`. Başkası görünüyorsa DUR ve raporla.
3. Kabul zincirini SON kez koş (2c komutu) → `OZET: N1 PASS` teyidi (tutarlılık).
4. Demo'da 188 çift zincir dokunulmazlık kontrolü (sahip kararı, K12; DEMO kanalından): açık `OVSYNC_BASLAT`, `kupe_no=188` hedef `2026-10-06` hâlâ açık (OBSERVED 2026-09-24: görev `bcd5fe9d…`, `kisir=false`); `cases`'te 188'in aktif zinciri değişmedi.
5. U3 çelişkisizlik (kod taraması): `grep -n 'ovsyncBaslat' js/ui.js` → yalnız :L1164-çevresi (4a), :L1841-çevresi (4b) ve `ovsyncBaslat` tanımı — hayvan kartında buton yokluğu korunur (K10).
6. `npm run test:unit` ikinci teyit (damga değişimi sonrası).

---

## Adım 6 — Teslim paketi + son review kapısı

**Teslim tanımı (sahibin isteği: "direkt demo testte hazır"):**
- Migration DEMO'da canlı (Adım 3) + T8-T10 kanıtlı;
- UI dalda commit'li (Adım 4), unit yeşil;
- Sahip yürüyüşü hazır: worktree kökünde `npm run serve:local` → http://127.0.0.1:8080 (demo modda) — **T11:** protokol uyarı panelinde kısır satırda `▶ Başlat` YOK, `💲 Kısır işaretli — üreme planı yok` VAR, `✕` çalışır; **T12:** görev kartında kisir hayvanda rozet, normalde buton; **T13:** hayvan kartında kısır rozet + ovsync butonu çelişkisizliği (kartta buton yokluğu regresyonu). (T11-T13 sahip yürüyüşüdür — ajan browser koşmaz.)

**Kanıt zarfı** (`reports/plans/ovsync-cila-s1-kanit.md` — reports/ gitignore'da, `git add -f` gerekirse; yazma yetkisi implementer zarfına tabidir): N0/N1 OZET çıktıları, T1-T6 blok çıktısı, T8-T10 demo çıktıları (tarih+kanal), commit A/B/C SHA'ları, sapma notları (aşağıda).

**Son review kapısı (sahip isteği: iş bitince tekrar review):** implementer kendi kendini onaylamaz; review ayrı ajan/koşumdur. Review girdileri: (1) commit aralığı `main..HEAD`, (2) bu plan + spec dosyaları, (3) kanıt zarfı, (4) bilinen sapmalar listesi, (5) rollback senaryosu (aşağıda). Review bulunmaları `docs/plans/2026-09-24-ovsync-cila/` altına ya da review ajanının kendi zarfına yazılır.

**Kapanış işlemleri:** `gitnexus analyze /home/melik/egesut-erp1` (kural: indeks çalışılan commit'i yansıtsın); LSP kapat (`code-change-precheck` sözleşmesi).

## Rollback (spec §9'nun somut hali — yalnız gerektiğinde)

1. Önce UI: `git revert <commit C>` (damga tek-değer kuralıyla geri döner). Sonra DB:
2. Tek psql script, tek transaction: dört gövdenin kisir-ÖNCESİ hallerini repo'dan `CREATE OR REPLACE` ile geri yaz — `_acik_disi_hedef_ic`+wrapper+`ilk_tohumlama_zamanlayici` = `20260924000002:L21-90,L99-301` (DROP satırı :L97 HARİÇ), `start_first_service_protocol`+`ovsync_baslat_uyarilari` = `20260924000001:L662-851,L1089-1126`; diff'lerin tersi uygulanmış (kisir satırları çıkarılmış); ACL satırları aynen; `NOTIFY pgrst, 'reload schema';`. Migration veri yazmadığından veri geri-dönüşü GEREKMEZ.
3. Doğrulama: T8 sorgusu tersine döner (kural tabanlı hayvanda `_ic` NULL döndürmez), `ovsync_baslat_uyarilari`'nda `kisir` alanı kaybolur.

## Bilinen sapmalar ve spec-notları (review'a sunulur)

| # | Sapma/not | Gerekçe |
|---|---|---|
| 1 | Yeni kabul blok etiketi `S1-T1…T6` (spec §5 "R32-11" demişti; spec 1.1'de etiket güncellendi) | `R32-11` etiketi dosyada zaten var — CONFIRMED `supabase/tests/ovsync_pg_kabul.sql:L1682-1696` |
| 2 | Damga 26 satırın tamamına uygulanır (spec §5 "tek satır" demişti) | tek-değer `?v=` kuralı; önceki bump `fe5f91d` da tüm satırları değiştirdi — CONFIRMED |
| 3 | `_ovsyncBaslatBtnHtml`'e `typeof getState==='function'` koruması eklendi (spec §7.1 sketch'i korumasızdı) | T14 birim-yeşil şartı; sandbox'ta `getState` yok — CONFIRMED `tests/unit/ovsync-pg-ui.test.js` + `support/loadModule.js` |
| 4 | M2 COMMENT'ine `KISIR` eklendi (spec'te açıkça istenmemişti) | muafiyet listesi dokümantasyon doğruluğu; davranışsız |
| 5 | Gerçek-dal tarama SELECT'i filtresiz kaldı (yalnız dry-run SELECT + duve_tabansiz filtreli) | spec §6.3 kararı; gerçek dalda davranışı `_ic` NULL'u taşır — bilinçli asimetri |
| 6 | tests/README.md'deki koşum zinciri bayat kalıyor (09-24 migrasyonları yok) | README spec zarfında dokunulmayacaklar listesinde; düzeltilmiş zincir bu planda |

## Onarım turu kaydı (1.1 — 2026-09-24, 3. review turu sonrası)

Review bulguları orkestratöre aktarılmadığından (BULGULAR alanı boş geldi) plan/spec repodan ve canlı demo şemasından TEK TEK yeniden doğrulandı; doğrulanan bulgular ve giderimler:

| # | Bulgular | Giderim | Kanıt |
|---|---|---|---|
| R1 | Adım 2c kapısında sayaç çelişkisi: "N1 = N0 + 11" yazıyordu, blok aritmetiği 19 | "N1 = N0 + 19 (beklenen fark TAM 19)" olarak düzeltildi; "≥" belirsizliği kaldırıldı | plan içi aritmetik: S1-T1:4 + T2:4 + T3:3 + T4:2 + T5:4 + T6:2 = 19 — CONFIRMED (2b bloklarındaki kb_ok çağrı sayımı) |
| R2 | R32-11 çapa satırı hatalıydı (:L1686-1698 / :L1686) | :L1682-1696 olarak düzeltildi (etiket yorumu :L1682, PASS NOTICE :L1696) | CONFIRMED `supabase/tests/ovsync_pg_kabul.sql:L1682-1696` |
| R3 | S1-T5'in dry-run `duve_tabansiz` iddiası "DIFF B"ye bağlanmıştı; oysa dry-run çıktısındaki sayaç dry döngüde (:L137-153) DIFF A'nın filtreli tarama SELECT'inden beslenir; DIFF B (:L262-277) GERÇEK-dal sayacıdır — dry-run koşumunda hiç çalışmaz | Assertion etiketi DIFF A'ya bağlandı ve iki sayacın ayrımı açıklığa kavuşturuldu (davranış beklentisi değişmedi; iddia zaten doğruydu, atıf yanlıştı) | CONFIRMED `20260924000002:L128-134` (dry scan), `:L137-153` (dry sayaç), `:L178-184` (dry çıktı), `:L262-277` (gerçek dal) |
| R4 | 2b girişi "yedi DO bloğu" diyordu, blok sayısı 6 | "altı DO bloğu" olarak düzeltildi | CONFIRMED (plan içi tutarlılık) |
| R5 | S1 bloklarının bayrak devri örtüktü (T2/T3/T6 `OZELLIK_KAPALI`'ya karşı) | Bayrak devri paragrafı eklendi: R32-11 son UPDATE :L1695 `deger=1`; kolon numeric; S1-T1 kendi 1'i çeker | CONFIRMED `supabase/tests/ovsync_pg_kabul.sql:L1688/L1695`, `20260620000001_protokol_ayar.sql:L6`, `20260924000001:L687-690` |
| R6 | APPEND noktası çapasızdı | :L1749 (R32-10 PASS NOTICE) / :L1750 (END) / :L1754 (ÖZET) çapaları eklendi | CONFIRMED `supabase/tests/ovsync_pg_kabul.sql` |
| R7 | **KANAL HATASI (kritik):** v1.0 planı Adım 0/3/5'te demo ölçüm ve apply için tools-bank `supabase_*`/`supabase_migrate`/`supabase_rpc` kanalını gösteriyordu; o kanal PROD'a bağlı (ref `zqnexqbdfvbhlxzelzju`). "supabase_migrate ile demo'ya apply" talimatı PROD-apply riski taşıyordu | Adım 0 kanal kuralı + Adım 3 apply/doğrulama + T9/T10 + Adım 5.4 DEMO kanalına (Mgmt API `SUPABASE_DEMO_REF`/`SUPABASE_DEMO_PAT` veya demo pooler psql) çevrildi; T9'un "acik_toplam=31" sabit beklentisi kaldırıldı (DEMO 29, tarih-bağımlı) | CONFIRMED `~/tools-bank/mcp_server/server.py` `SB_URL`/`SB_PROJECT` + `js/api.js:23-24`; OBSERVED demo kanalı 2026-09-24 (aşağıda) |
| R8 | M2 DIFF mekanik notu: canlı muafiyet bloğu düz ELSIF zinciri değil, `IF AKTIF_DEGIL … ELSE <iç-IF MK3 :L719-728> END IF` yapısındadır | Plan M2 zaten doğru mekanik veriyordu (ELSIF'i ELSE'den önceye ekle = ELSE'i böl); spec §6.2 "Canlı yapı notu" ile netleştirildi, plana işaret eklendi | CONFIRMED `20260924000001:L711-729` |
| R9 | S1-T5'in elle `hayvanlar` INSERT'i (dogum_tarihi'siz) şema riski sorusu — kabul DB'si prod-şemadan kuruluyor | Güvenli: üç tabloda default'suz NOT NULL tek kolon `hayvanlar.id` — planın tüm INSERT kolon setleri yeterli; dogum_tarihi'sizlik zaten bilinçli (tabansız düve fixture'ı) | OBSERVED demo `information_schema.columns` (`is_nullable='NO' AND column_default IS NULL`) → yalnız `hayvanlar.id` (2026-09-24) |
| R10 | Kanıt-zarf/rollback kanal etiketi + spec §9 rollback'te `:L662-846` çapası (boş satır dahil) | Adım 6 kanıt zarfı zaten "(tarih+kanal)" istiyor — kanal = DEMO; spec §9 `:L662-845` ($fn$; satırı) olarak netleştirildi | CONFIRMED `20260924000001:L844-845`; plan Adım 6 kanıt zarfı maddesi |
| R11 | Adım 0 impact satırı `start_first_service_protocol` için beklenen arayanı `js/forms.js` diye yazıyordu — yanlış: JS'te tek çağıran `js/ui.js:1176` (`ovsyncBaslat` içinde rpc); forms.js'te arayan yok (`js/api.js:320` yalnız RPC→tablo etki haritası). Spec V6 da `_vaka_ac_tek` çağıranlarını eksik sayıyordu (üçüncü çağıran `vaka_toplu_ac`, 20260906120000:L522) | Adım 0 satırı gerçek çağıranlarla düzeltildi; spec V6 üç çağıranı numaralandı (spec §13 satır 10) | CONFIRMED `grep -rn start_first_service_protocol js/` → yalnız `js/ui.js:1176` + `js/api.js:320`; `grep -n _vaka_ac_tek supabase/migrations/20260906120000_vaka_toplu_ac.sql` (:L257 create_case, :L522 toplu); `20260923000006:L528` (start gövdesi içinde) — üçüncü onarım geçişi 2026-09-24 |

Doğrulanıp DEĞİŞTİRİLMEYEN çapalar (3. turda yeniden ölçüldü, sağlam): `20260924000002:L21-68` `_ic` gövdesi + :L33 DIFF-1 eski satır + :L34-36 IF bloğu + :L70-72 COMMENT/REVOKE; `20260924000001:L662-845` start gövdesi + :L710 SELECT*INTO + :L712/713 KISIR-ELSIF sokma noktası + :L731-744 muafiyet kapanışı + :L847-851 COMMENT/ACL; `20260924000002:L99-295` zamanlayıcı gövdesi + :L97 DROP + :L297-301 COMMENT/ACL; `20260924000001:L1089-1126` uyarılar gövdesi (kisir sokma noktası :L1102 arkası); `js/ui.js` :L1162-1166 / :L1164-1165 / :L1173 / :L1177 / :L1190-1199 / :L1244 / :L1259 / :L1588 / :L1834-1844 / :L1840-1843; `index.html:24` --amber, `:L2336` ui.js damgası, `?v=20260924-01` tam 26 satır; `js/state.js:92` getState global; unit sandbox extras'ında getState YOK (`tests/unit/ovsync-pg-ui.test.js:L12-16`, test çağrısı :L40-45); kb yardımcıları ve INSERT sütun listeleri tests/ovsync_pg_kabul.sql öncülleriyle birebir (:L34-41 kb_ok, :L49-57 kb_hayvan, :L1415+ görev INSERT'i, :L297 tohumlama INSERT'i).

Canlı ölçüm (OBSERVED 2026-09-24, **DEMO kanalı** — Mgmt API `SUPABASE_DEMO_REF`): 184/199/208 `kisir=true, Aktif, Dişi`; AÇIK OVSYNC_BASLAT **29** (kisir_acik=0); 188 görevi `bcd5fe9d…` hedef 2026-10-06 açık, `kisir=false`; üç senkron vakası DEMO'da `status='active', protocol_family=NULL` (tools-bank kanalı bunların PROD ölçümünü verirdi: orada 31 görev ve family='OVSYNC' — kanal kuralı R7). Demo'da `_acik_disi_hedef_ic` gövdesi ESKİ :L33 satırını taşıyor ve dört fonksiyonun hiçbirinde `kisir` geçmiyor (diff hedefleri demo'da da taze). `kisir=true` hayvanlar: 6 (115/185 Satıldı, 184/199/204/208 Aktif — 204'ün açık görevi yok, M1 üretimi kapatır). Migration numarası `20260925000001` hâlâ boş (OBSERVED `ls supabase/migrations/`).
