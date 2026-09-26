# F4-Gate — son G2/G3 + prod bağımlılık haritası · 2026-09-25

Oturum: erteleme-genel/f4-gate · Ağaç: `.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme`
(dal `ovysch-feature-erteleme`, uç `76cd2b4`) · Onarım YOK — yalnız kanıt.

## G2(1) govde-dogrulama — GOVDE_FARK: 0 [OBSERVED taze koşum, bu oturum]

`bash scripts/govde-dogrulama.sh` → 26 kontrol satırının tamamı OK
(22 fonksiyon + SP protokol_ayar_guncelle alter-only tırnaksız search_path + VIEW
v_eligible + DROP gövdesi canlıda yok + TABLE gorev_ertele_kural canlıda var),
son satır `GOVDE_FARK: 0`. Demo ref vtzqjmazsvurxdeondmi doğrulandı; prod'a
hiç bağlanılmadı.

## G2(2) db-validate --priors seri — TÜMÜ PASS 7/7 [OBSERVED taze koşum 18:35–18:36]

Tek arka plan koşusu (koşucu `~/tmp/erteleme-gate/.priors-seri-kosucu-gate.sh`;
loglar `~/tmp/erteleme-gate/.priors-seri-*.log`); hedef başına C1+C2 baseline
(egesut_lsp aynası, prod taze T=54 F=244 V=13, PG 17.6 parite uyumlu) + priors.
Özet rapor `reports/db-validation-202609251-priors-serisi.md`; F4-DB
koşumundan tek fark oturum etiketi + zaman damgaları — yeniden-üretilebilirlik
kanıtlandı:

| Hedef | Priors | Sonuç | Rapor |
|---|---|---|---|
| 20260925100001_vaka_kalan_gunleri_kaydir.sql | 0 | PASS | db-validation-519c2e30.md |
| 20260925100002_add_treatment_day_ust_gorev_tarihi.sql | 1 | PASS | db-validation-7d66b886.md |
| 20260925100003_gorev_ertele_kural_tablo_seed.sql | 2 | PASS | db-validation-f03f1a95.md |
| 20260925100004_gorev_ertele_rpcs.sql | 3 | PASS | db-validation-b9adca56.md |
| 20260925100005_bagimsiz_pg_vaka_kapat.sql | 4 | PASS | db-validation-a5505160.md |
| 20260925100006_protokol_iptal.sql | 5 | PASS | db-validation-fee68007.md |
| 20260925100007_erteleme_f4_onarim.sql | 6 | PASS | db-validation-4df69cd3.md |

## G3 unit — 1165/1168, yeni fail 0 [OBSERVED `npm run test:unit`, log ~/tmp/erteleme-gate/unit-f4gate.log]

`ℹ tests 1168 · pass 1165 · fail 3`. 3 fail = tam bilinen baz: LUNA-3 (demo
information_schema esleme) + bc-tarih ×2. F4-DB bazı (1165/1168) ile birebir;
E1-UI/F4-UI eklenen testler dahil, bu kulvar kaynaklı yeni fail 0.

## Zincir temizliği

- `git status --short`: yalnız 8 takipli db-validation raporunun tazelemesi
  (1 satırlık oturum etiketi/zaman farkı); untracked kalıntı YOK — scratch'ler
  `~/tmp/erteleme-gate/` altında.
- `git log --oneline 2facc31..HEAD` → **21 commit** (zarf içi tam zincir;
  uç 76cd2b4 = F4-DB son commit'i + aaaa07d F4-UI).

## Prod bağımlılık haritası (202609251000NN)

### Seri durumu

| Seri | Prod durumu | Kanıt |
|---|---|---|
| 20260923000001..000006 (ovsync-pg + dogum + zincir) | **VAR** (canlı) | E0-HAZIR CONFIRMED; ayna tazelik T=54 F=244 V=13 |
| 20260924000001..000002 (r32 + dryrun) | **VAR** (canlı) | aynı |
| 20260925000001..000017 (cila) | **YOK** | ayna gövde incelemesi (aşağıda) |
| 20260925100001..000007 (erteleme, bu dal) | **YOK** | aynada 4 yeni RPC yok [OBSERVED] |

### Nesne bağımlılık matrisi (kod içi referanslar; yorum/kısıt-adı hariç)

| 202609251 | Bağımlılık | İlk tanım yeri | Prod |
|---|---|---|---|
| 100001 | tohumlama_gorev_ertele, _tohumlama_pencere; tablolar cases/gorev_log/treatment_days | 20260923000003 + eski tablolar | VAR |
| 100002 | add_treatment_day_with_sessions gövdesi (20260611000002); eski tablolar + drug_administrations/treatment_day_uygulamalar | eski | VAR |
| 100003 | — (tablo + 20 satır seed + RLS; dış bağımlılık yok) | kendi | - |
| 100004 | gorev_ertele_kural (100003), _tohumlama_pencere (20260923000003), protokol_instance (20260605000003), islem_log/gorev_log | seri içi + VAR | VAR |
| 100005 | _vaka_kapat (ilk 20260923000005), _pg_sonrasi_tohumlama (20260923000003), _pg_olay_isle (ilk 20260923000003), cases_close_reason_check takası | VAR | VAR |
| 100006 | + _ovsync_kural_tarihi (20260924000001), **_ovsync_baslat_gorev_kur (ilk 20260924000001; cila 000012+000016 gövde yeniden yazımı)**, tohumlama/hayvanlar/dogum | VAR (gövde cilasız) | VAR |
| 100007 | 100006 ile aynı + gorev_ertele_kural seed (100003) | VAR + seri içi | VAR |

**Cila sert bağımlılığı YOK:** cila 000001..000017 hiç tablo, kolon veya YENİ
fonksiyon yaratmıyor — yalnızca CREATE OR REPLACE (gövde), ALTER (search_path)
ve REVOKE/ACL [CONFIRMED grep: CREATE TABLE/ADD COLUMN yok]. 7/7 priors koşusu
cilasız prod aynasında PASS → varlık (sert) bağımlılık sıfır.

**Anlamsal (davranış) bağımlılık TEK nokta:** `protokol_iptal` yeniden-başlat
bacağı (100006/100007) guard'larını `_ovsync_baslat_gorev_kur` ÇEKİRDEĞİNDEN
alır (kısırlık/Aktif/Dişi + sıra guard'ları; 100007:137-140 `IF v_yeni_gorev IS
NULL` sessiz-NULL deseni). Bu guard'lar cila 000012 (kisir_zincir_guard) +
000016 (baslat_guard_sira) gövdelerinde. Aynadaki (prod) gövde guard/sıra
işaretsiz = 20260924000001 gövdesi [OBSERVED pg_get_functiondef grep]. Yani
cilasız prod'da 100006/100007 uygulanırsa guard'sız yeniden-başlat mümkün —
tam seri yolunda cila önkoşulu bu yüzden ANLAMSAL zorunlu.

**Constraint notu:** ayna tasarımı gereği constraint-free kurulur
(refresh_lsp_schema.sh adım 3) → 100005/100006'ın cases_close_reason_check
takası (3 değer → 4 değer) yalnız yapısal doğrulanabildi. Prod'da satır
doğrulaması argümanla güvenli: prod'daki _vaka_kapat (20260923000005:93)
close_reason'a yalnız ERKEN_KAPANIS/TOHUMLAMA yazar; ikisi de yeni listede.
Uygulama anında 100005 öncesi `SELECT DISTINCT close_reason` pre-check'i
aşağıdaki sıraya eklendi.

### Hedef-durum parmak izi (demo canlı = 100007 sonrası) [OBSERVED psql]

| Fonksiyon | anon | authenticated | proconfig |
|---|---|---|---|
| vaka_kalan_gunleri_kaydir(uuid,integer) | f | t | {"search_path=public, pg_temp"} |
| gorev_ertele(uuid,date,time) | f | t | {"search_path=public, pg_temp"} |
| gorev_ertele_kural_get(text) | f | **f** (iç yardımcı; 100007 kapattı) | - |
| gorev_ertele_kural_listele() | f | t | - |
| protokol_iptal(uuid,boolean,text) | f | t | {"search_path=public, pg_temp"} |
| add_treatment_day_with_sessions(uuid,date,jsonb,uuid) | f | t | {"search_path=public, pg_temp"} |

seed=23 satır · RLS=t · constraint=CHECK (close_reason = ANY(ARRAY['ERKEN_KAPANIS','TOHUMLAMA','PG','IPTAL']))

---

## PROD UYGULAMA SIRASI (DONE'a gider)

### (a) E0 tek-başına hızlı yol — 20260925100001 YALNIZ

Önkoşul: YOK (20260923/20260924 serileri prod'da zaten canlı; **cila GEREKMEZ**
[CONFIRMED E0-HAZIR + bu kapıda aynada yeniden doğrulandı]).

1. Uygula: `supabase/migrations/20260925100001_vaka_kalan_gunleri_kaydir.sql`
   (db-validate PASS: db-validation-519c2e30.md, cilasız prod aynası).
2. Sonrası doğrulama (ARA TESLİM kalıbı):
   - `SELECT p.proconfig FROM pg_proc p WHERE p.proname='vaka_kalan_gunleri_kaydir';` → `{"search_path=public, pg_temp"}`
   - `SELECT has_function_privilege('anon','public.vaka_kalan_gunleri_kaydir(uuid, integer)','EXECUTE');` → f
   - `SELECT has_function_privilege('authenticated','public.vaka_kalan_gunleri_kaydir(uuid, integer)','EXECUTE');` → t
   - kapalı-vaka ret probe: `SELECT public.vaka_kalan_gunleri_kaydir('<kapalı-vaka-uuid>', 1);`
     → `VAKA_KAYDIRILAMAZ:{"sebep":"VAKA_ACIK_DEGIL",...}` (hata dalı; veri yazmaz)
3. UI: index.html `?v=20260925-05` damgasıyla birlikte publish edilmeli
   (damga 26 referans tek değer).
4. E0-Y YEDEK (yalnız E0 RPC prod'a çıkamazsa): `scripts/erteleme/2026-09-25-prod-kaydir.sql`.
   Koşum — DEMO PROVA (varsayılan, COMMIT yok):
   `bash -c 'set -a; source /home/melik/egesut-erp1/.env; set +a; PGPASSWORD="$SUPABASE_DEMO_DB_PASSWORD" psql "postgresql://postgres.${SUPABASE_DEMO_REF}:${SUPABASE_DEMO_DB_PASSWORD}@${SUPABASE_DEMO_POOLER}:6543/postgres" -X -v ON_ERROR_STOP=1 -f scripts/erteleme/2026-09-25-prod-kaydir.sql'`
   PROD (SAHİP ELİYLE, agent koşmaz): (1) `\set prod_mod true`, (2) `$guard$`
   bloğunda `v_prod_onay := 'zqnexqbdfvbhlxzelzju'` (dosyada tek yer), (3)
   `\set vaka_ids '<prod aktif vaka id listesi>'`, (4) `p_commit` FALSE ile
   BEGIN…ROLLBACK provası, (5) `\set p_commit true` → gerçek uygulama, (6) bağlantı
   dizgesinden ref doğrula. DİKKAT (B-2/F4): prod dalı, ortamda 20260925 ailesi
   işaret sayısı 0 DEĞİLSE `PROD_MOD_ISARET_UYUSMAZ` EXCEPTION ile mekanik durur —
   betik yalnız E0-hızlı-yol penceresinde (hiçbir 20260925* kayıtlı değilken)
   koşulabilir; tam seri uygulandıysa yeniden değerlendirilmeli.

### (b) Tam seri — cila 000001..000017 önkoşulu + 100001..100007

Önkoşul: cila `20260925000001..000017` ÖNCE (sırasıyla). Gerekçe: (1)
protokol_iptal yeniden-başlat bacağının guard'ları cila 000012+000016
`_ovsync_baslat_gorev_kur` gövdesinden — cilasız uygulanırsa guard'sız restart;
(2) demo kabul durumuna (GOVDE_FARK 0'ın karşılaştırduğu gövdeler) parite.
Sert bağımlılık yoktur; cila atlanamaz sebebi ANLAMSALDIR.

Sıra: cila 17 dosya → 20260925100001 → 000002 → 000003 → 000004 → 000005 →
000006 → 000007 (her dosya tek transaction; hata → DUR, atlama yok).

Her dosya sonrası doğrulama sorguları (beklenen değerler hedef-durum parmak
izinden):

- **cila sonrası (000017):** `SELECT pg_get_functiondef(p.oid) FROM pg_proc p WHERE p.proname='_ovsync_baslat_gorev_kur';` → gövdede kisir/sıra guard'ları mevcut (OVSYNC_BASLAT_PARAMETRE dalı); `SELECT has_function_privilege('anon','public.sessiz_hayvanlar_reconcile()','EXECUTE');` → f
- **100001:** (a) yolundaki 4 sorgu aynı.
- **100002:** `SELECT proconfig FROM pg_proc WHERE proname='add_treatment_day_with_sessions';` → `{"search_path=public, pg_temp"}`
- **100003:** `SELECT count(*) FROM public.gorev_ertele_kural;` → **20**; `SELECT relrowsecurity FROM pg_class WHERE relname='gorev_ertele_kural';` → t
- **100004:** `SELECT has_function_privilege('authenticated','public.gorev_ertele(uuid, date, time without time zone)','EXECUTE');` → t; `...('anon',...)` → f; `gorev_ertele_kural_listele()` anon f / authenticated t
- **100005:** ÖNCE pre-check: `SELECT DISTINCT close_reason FROM public.cases WHERE close_reason IS NOT NULL;` → yalnız ERKEN_KAPANIS/TOHUMLAMA (farklı değer varsa DUR — sahip kararı). Sonra: `SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname='cases_close_reason_check';` → CHECK 3 değer (ERKEN_KAPANIS, TOHUMLAMA, PG)
- **100006:** aynı constraint sorgusu → CHECK 4 değer (+IPTAL); `SELECT to_regprocedure('public.protokol_iptal(uuid, boolean, text)');` → null değil
- **100007:** `SELECT count(*) FROM public.gorev_ertele_kural;` → **23**; `SELECT has_function_privilege('anon','public.protokol_iptal(uuid, boolean, text)','EXECUTE');` → f; `...('authenticated',...)` → t; `add_treatment_day_with_sessions(uuid, date, jsonb, uuid)` anon f / authenticated t; `gorev_ertele_kural_get(text)` anon f **ve** authenticated f
- **Son adım:** `bash scripts/govde-dogrulama.sh` (demo'ya karşı; prod'a değil) GOVDE_FARK: 0 + `bash scripts/veri-eslesme-kontrol.py hepsi` (sahip kuralı: her prod uygulamasından sonra).

---

## AÇIK KALEMLER — sahip kapısı (DONE listesi)

1. **C-4 kaynak_ref sapması (CONFIRMED-DÜŞÜK):** zarf (GOREV.md:44)
   `protokol_instance.kaynak_ref senkronu` isterken teslim 20260925100004:181-192
   kaynak anahtarını `bilinçli korunur` notuyla yazmadı. Teknik gerekçe bağımsız
   doğrulandı: canlı `protokol_instance_kaynak_unique` constraint'i +
   `_ovsync_baslat_gorev_kur` ON CONFLICT (kaynak_ref) DO NOTHING çift-katman
   koruma — işlevsel risk düşük, zarf-sözleşme sapması sahip onayına açık.
2. **RA: PG VWP_ICINDE/UYGUNSUZ sessiz kırılma:** PG olayı bu sonuçlanırsa TAI
   hiç oluşmaz, kullanıcıya görev/bildirim düşmez [CONFIRMED
   _pg_sonrasi_tohumlama 136-151]; bildirim yüzeyi (ovsync_baslat_uyarilari
   rozet genişletmesi) v1 dışı.
3. **RA: tedavi bitişi ↔ TAI senkron yok:** otomatik öteleme yok; manuel
   erteleme (gorev_ertele + E0 kaydırma) var.
4. **RA: close_case protokol vakasında düz flip:** seanslar açık kalır, stok
   iadesi yok (ön-var; UI'nin eski close_case yolu — E4 protokol_iptal RPC'si
   bu desenle gelmez).
5. **RA: önü-başlangıç iptalinde protokol_instance aktif kalıyor.**
6. **Taşıyıcı (F4-DB):** demo'da cases INSERT kırık — `_guard_cases_kisir_ovsync`
   INSERT dalı `PERFORM _kisir_ovsync_guard(text animal_id)` çağrısı ile
   `(uuid, boolean)` imzası uyuşmuyor; kapı gündemi dışı bırakıldı, sahip kapısı.
7. **Taşıyıcı (plan-db §7):** E3 farklı-vaka assumption'ı (4c) ve E3 geri-al
   kararı (4d-ii) sahip kapısı listesinde.

## Kanıt etiketleri

- [OBSERVED] govde-dogrulama taze çıktısı (bu oturum), db-validate 7/7 taze
  koşum 18:35–18:36 + loglar `~/tmp/erteleme-gate/`, unit özeti
  `~/tmp/erteleme-gate/unit-f4gate.log`, ayna sorguları (fonksiyon VAR/YOK,
  gövde işaretleri, constraint-free tasarım), demo hedef-durum parmak izi.
- [CONFIRMED] E0-HAZIR prod-önkoşul analizi (grep tek-dosya tanım), cila
  CREATE-ONLY-REPLACE taraması, 20260923000005:93 close_reason yazar kümesi.
