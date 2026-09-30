# DB Validation Raporu — c22244db

- Tarih: 2026-09-30 18:54:43+0300
- Migration: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000003_takip_kapanis_tetikleyicileri.sql`
- Priors (1): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000002_takip_gorev_ve_bos_devam.sql
- SHA-256: `c22244db64cc353188f54bf75f14b69c32bf8fbf48588e9f0f028295db3ae05f`
- Baseline (C1): {'tablo': 55, 'fonksiyon': 256, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': 'taze (nesne sayımı prod ile eşleşiyor: T=55 F=256 V=13)', 'parite_dosya': '/home/melik/tmp/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} · parite: uyumlu
- Data mode: koşulmadı (migration veri dokmuyor, --data-mode=auto)
- Genel sonuç: **PASS**

## Faz bazlı sonuç tablosu

| Kriter | Sonuç | Not |
|---|---|---|
| A.sqlfluff-parse | PASS | parse hatası yok (stil uyarısı: 0) |
| A.squawk | PASS | varsayılan kurallar (istisna: require-concurrent-index-creation,ban-drop-table) ihlal yok |
| B.sema-uyum | PASS | tüm FROM/JOIN/ALTER/REFERENCES hedefleri biliniyor (ayna ya da migration-içi) |
| C1.baseline-restore-schema | PASS | db=egesut_val_tmp parite=uyumlu meta={'tablo': 55, 'fonksiyon': 256, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': 'taze (nesne sayımı prod ile eşleşiyor: T=55 F=256 V=13)', 'parite_dosya': '/home/melik/tmp/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} |
| priors.C1.20260929000002_takip_gorev_ve_bos_devam.sql | PASS | prior migration hatasız uygulandı |
| C1.migration-apply | PASS | psql ON_ERROR_STOP ile hatasız uygulandı |
| C1.postcheck-nesne | PASS | migration-içi yaratılan tüm nesneler izole DB'de mevcut |
| C1.postcheck-rls | PASS | RLS farkları: yok; etkilenen tablolar relrowsecurity: (yeni tablo ya da aynada yok) |
| C1.ortam-paritesi | PASS | baseline parite_durumu=uyumlu |
| C1.baseline-restore-data | PASS | db=egesut_val_tmp parite=uyumlu meta={'tablo': 55, 'fonksiyon': 256, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': 'taze (nesne sayımı prod ile eşleşiyor: T=55 F=256 V=13)', 'parite_dosya': '/home/melik/tmp/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} |
| priors.C2.20260929000002_takip_gorev_ve_bos_devam.sql | PASS | prior migration hatasız uygulandı |
| C2.sentetik-tohum | PASS | etkilenen tablolara sentetik satır eklendi |
| C2.veri-uyumluluk | PASS | sentetik veri üzerinde migration hatasız; unique/fk ihlali yok |

## Uygulanan komutlar

```bash
$ sqlfluff lint --dialect postgres '/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000003_takip_kapanis_tetikleyicileri.sql'
$ squawk --exclude=require-concurrent-index-creation,ban-drop-table '/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000003_takip_kapanis_tetikleyicileri.sql'
$ psql egesut_lsp: tablo/view/fonksiyon isimleri (information_schema + pg_proc)
$ timeout 900 bash '/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/scripts/db-build-baseline.sh' --json --db-url postgres://postgres:val@127.0.0.1:5433/postgres  # (schema)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000002_takip_gorev_ve_bos_devam.sql'  # prior (C1)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000003_takip_kapanis_tetikleyicileri.sql'  # db=egesut_val_tmp
$ timeout 900 bash '/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/scripts/db-build-baseline.sh' --json --db-url postgres://postgres:val@127.0.0.1:5433/postgres  # (data)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000002_takip_gorev_ve_bos_devam.sql'  # prior (C2)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000003_takip_kapanis_tetikleyicileri.sql'  # C2 db=egesut_val_tmp (tohumlu)
```

## Çıktı parçaları

### FAZ A sqlfluff (`sqlfluff.out`)
```
WARNING    Length of file '/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000003_takip_kapanis_tetikleyicileri.sql' is 96407 bytes which is over the limit of 20000 bytes. Skipping to avoid parser lock. Users can increase this limit in their config by setting the 'large_file_skip_byte_limit' value, or disable by setting it to zero. 
All Finished!
```

### FAZ A squawk (`squawk.out`)
```

Found 0 issues in 1 file 🎉
```

### C1/C2 baseline (`baseline.out`)
```
[1;34m▶ FAZ-0 Ortam paritesi (Mgmt API, salt-okunur)…[0m
[1;34m▶   Parite: uyumlu (prod=17.6 yerel=17.6) → /home/melik/tmp/parite-egesut_val_tmp.txt[0m
[1;34m▶   Ayna tazeliği: taze (nesne sayımı prod ile eşleşiyor: T=55 F=256 V=13)[0m
[1;34m▶ İzole DB kuruluyor: egesut_val_tmp[0m
[1;34m▶ Roller kuruluyor (NOLOGIN)…[0m
DO
[1;34m▶ egesut_lsp aynasından pg_dump alınıyor…[0m
[1;34m▶ Baseline izole DB'ye yükleniyor (ON_ERROR_STOP=1)…[0m
[1;34m▶ pgTAP çekiliyor…[0m
curl: (22) The requested URL returned error: 404
[1;33m⚠ raw master pgtap.sql 404 (repo içinde üretilmiyor) — latest release zip'e düşülüyor…[0m
Makefile:181: To use pg_prove, TAP::Parser::SourceHandler::pgTAP Perl module
Makefile:182: must be installed from CPAN. To do so, simply run:
Makefile:183: cpan TAP::Parser::SourceHandler::pgTAP
[1;34m▶ pgTAP yükleniyor (370922 byte, ayrı 'pgtap' şemasına)…[0m
ALTER DATABASE
{"db_name":"egesut_val_tmp","tablo":55,"fonksiyon":256,"view":13,"pgtap_fn":1085,"parite_durum":"uyumlu","baseline_kaynak":"egesut_lsp","ayna_tazelik":"taze (nesne sayımı prod ile eşleşiyor: T=55 F=256 V=13)","parite_dosya":"/home/melik/tmp/parite-egesut_val_tmp.txt","prod_pg":"17.6","yerel_pg":"17.6"}
```

### C1 apply (`apply.out`)
```
BEGIN
SET
SET
CREATE FUNCTION
psql:/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000003_takip_kapanis_tetikleyicileri.sql:120: NOTICE:  trigger "trg_takip_yeni_tohumlama_kapat" for relation "public.tohumlama" does not exist, skipping
DROP TRIGGER
CREATE TRIGGER
COMMENT
CREATE FUNCTION
psql:/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000003_takip_kapanis_tetikleyicileri.sql:164: NOTICE:  trigger "trg_takip_pg_olay_kapisi" for relation "public.pg_application_event" does not exist, skipping
DROP TRIGGER
CREATE TRIGGER
COMMENT
CREATE FUNCTION
psql:/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000003_takip_kapanis_tetikleyicileri.sql:223: NOTICE:  trigger "trg_takip_ovsync_case_kapisi" for relation "public.cases" does not exist, skipping
DROP TRIGGER
CREATE TRIGGER
COMMENT
CREATE FUNCTION
COMMENT
CREATE FUNCTION
COMMENT
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
COMMIT
BEGIN
SET
SET
CREATE FUNCTION
COMMENT
DROP FUNCTION
CREATE FUNCTION
DROP FUNCTION
CREATE FUNCTION
DROP FUNCTION
CREATE FUNCTION
DROP FUNCTION
```

### C2 apply (tohumlu) (`c2_apply.out`)
```
BEGIN
SET
SET
CREATE FUNCTION
psql:/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000003_takip_kapanis_tetikleyicileri.sql:120: NOTICE:  trigger "trg_takip_yeni_tohumlama_kapat" for relation "public.tohumlama" does not exist, skipping
DROP TRIGGER
CREATE TRIGGER
COMMENT
CREATE FUNCTION
psql:/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000003_takip_kapanis_tetikleyicileri.sql:164: NOTICE:  trigger "trg_takip_pg_olay_kapisi" for relation "public.pg_application_event" does not exist, skipping
DROP TRIGGER
CREATE TRIGGER
COMMENT
CREATE FUNCTION
psql:/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000003_takip_kapanis_tetikleyicileri.sql:223: NOTICE:  trigger "trg_takip_ovsync_case_kapisi" for relation "public.cases" does not exist, skipping
DROP TRIGGER
CREATE TRIGGER
COMMENT
CREATE FUNCTION
COMMENT
CREATE FUNCTION
COMMENT
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
COMMIT
BEGIN
SET
SET
CREATE FUNCTION
COMMENT
DROP FUNCTION
CREATE FUNCTION
DROP FUNCTION
CREATE FUNCTION
DROP FUNCTION
CREATE FUNCTION
DROP FUNCTION
```

### C2 sentetik tohum (`seed.log`)
```
ERROR:  relation "public.farm" does not exist
LINE 1: ... ELSE (SELECT quote_literal(min(f.id)::text) FROM public.far...
                                                             ^
(genel) public.farm yok/boş — farm_id tohum değeri sabit zero-uuid fallback
cases: sentetik satır eklendi (id, animal_id, disease_id, start_date, status)
diseases: sentetik satır eklendi (id, name)
gorev_log: sentetik satır eklendi (id)
islem_log: sentetik satır eklendi (id, tip, durum, snapshot)
stok_hareket: sentetik satır eklendi (id)
uygulama_log: sentetik satır eklendi (id, hayvan_id, doz, birim, rota, tarih, notlar)
```

### Prior apply (`prior_C1_20260929000002_takip_gorev_ve_bos_devam.sql.out`)
```
BEGIN
SET
SET
CREATE FUNCTION
COMMENT
REVOKE
CREATE FUNCTION
REVOKE
GRANT
CREATE FUNCTION
REVOKE
GRANT
COMMENT
NOTIFY
COMMIT
```

### Prior apply (`prior_C2_20260929000002_takip_gorev_ve_bos_devam.sql.out`)
```
BEGIN
SET
SET
CREATE FUNCTION
COMMENT
REVOKE
CREATE FUNCTION
REVOKE
GRANT
CREATE FUNCTION
REVOKE
GRANT
COMMENT
NOTIFY
COMMIT
```
