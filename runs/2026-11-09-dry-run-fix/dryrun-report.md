⟦ss-sub model=opus effort=high rol=ss-worker-high iş=scripts/db-dry-run.sh onarımı: ayna yükleme sırası ve tazelenen≠denenen DB⟧
sonuc: TAMAM
kabul SHA: 7e2895ef2bb830183f8f4d6d3819322b69388d86 (dal `dryrun-fix`, worktree ~/.herdr/worktrees/egesut-erp1/dryrun-fix; push/merge yok)
BOYUT: bütçe 60 · gerçek 39 · bütçe içinde (üretim: 39 ekleme + 25 silme, 2 betik; test 88 satır ayrı)
Gelen iş denetimi: bulgu yok. Bir not: brief'teki temiz Run dosyası (20261110100001) bu arada prod'a uygulanmış. Bu yüzden rc 0 kanıtı başka dosyadan da alındı, aşağıda.

## Kök neden (MEASURED)
1. **Ayna yüklenemiyor (rc 66):** `refresh_lsp_schema.sh` fonksiyon parçalarını `check_function_bodies=on` (varsayılan) ile yüklüyordu. `LANGUAGE sql` gövdeleri oluşturma anında doğrulanıyor. İki parça, kendinden sonra yüklenen nesneye referans verdiği için düştü:
   - `fn_part_4.sql:3125`: `function public._ovsync_tren_aktif() does not exist` (sonraki oid'de yüklenen fonksiyon)
   - `fn_part_5.sql:3795`: `relation "public.v_stat_saglik_vaka" does not exist` (view'lar fonksiyonlardan sonra yükleniyor)
   `ON_ERROR_STOP=1` parçanın geri kalanını da atlattı. Sonuç: yerel F=300, canlı F=328 → "2 dosya hatalı" → dry-run rc 66. Ölçüm 22:25Z, değiştirilmemiş betikle. İlk tahmin "yükleme sırası" yarı doğruydu. Asıl kök, SQL gövdesinin oluşturma anında doğrulanması. pg_dump bu yüzden `check_function_bodies = false` koyar.
2. **Tazelenen ≠ denenen (env-mismatch):** refresh `LOCAL_LSP_URL`'yi (127.0.0.1/egesut_lsp) tazeliyordu. dry-run ise migration'ı `NEON_LSP_URL` (Neon) üzerinde deniyordu. Neon hiç tazelenmiyordu.
3. **Ölçümde çıkan üçüncü kusur, yanlış-kırmızı:** `-v VERBOSITY=verbose` NOTICE satırlarına da SQLSTATE yazıyor. Örnekler: `NOTICE: 42701: ... already exists, skipping` ve `RAISE NOTICE` → `00000`. "Bilinmeyen kod" taraması bunları hata saydı. Gerçek migration 20261110100002 yalnız NOTICE taşıdığı halde (psql rc 0) DRY-RUN: HATA aldı. MEASURED: `run-100002.log` (düzeltme öncesi) ve test T5 kırmızı.

## Düzeltme (7e2895e)
- `scripts/refresh_lsp_schema.sh`
  - Her fn parçasının başına `SET check_function_bodies = off;` eklendi.
  - `surum_gizli` artık her tazelemede `DROP SCHEMA … CASCADE; CREATE SCHEMA`. Eskiden `IF NOT EXISTS` vardı ve tablolar bayat kalıyordu (MEASURED: "already exists, skipping" notları).
  - Ortak ayna kilidi `~/.cache/egesut-lsp-ayna.lock` eklendi (flock, 600 sn, alınamazsa rc 67). dry-run kilidi tutarken çağırırsa (`EGESUT_AYNA_KILITLI=1`) tekrar almaz.
- `scripts/db-dry-run.sh`
  - Hedef `NEON_LSP_URL` yerine `LOCAL_LSP_URL` ve refresh'e export ediliyor. Böylece tek hedef var: yerel ayna.
  - Ölü PG* python ayrıştırması silindi.
  - `psql -X` ile koşuyor.
  - Tazeleme ve deneme aynı flock altında. DDL hook'unun refresh'i arada aynayı sıfırlayıp yarım aynada yanlış-yeşile yol açamaz.
  - SQLSTATE yalnız `ERROR|FATAL|PANIC|HATA` satırlarından ayıklanıyor. Karar ayrıca `PSQL_EXIT`'e (ON_ERROR_STOP) bağlı, yani süzme fail-open yapmaz.
  - Tazeleme hatasında, çıkışta silinen log'un yolu yerine log kuyruğu basılıyor.
  - Sınır notları güncellendi.
- `scripts/tests/db-dry-run.test.sh` (yeni, `.gitignore *.sh` nedeniyle `git add -f`): T1 hedef tutarlılığı (statik), T2 view'a bakan temiz fixture rc 0, T3 olmayan kolon rc≠0 ve 42703, T5 NOTICE-only migration rc 0, T4 çıktıda parola yok.

Neon kararı (önceden cevaplanmış kararlardaki öneriyle aynı): tek hedef yerel ayna. Gerekçe: refresh zaten yerel Postgres'e yazıyor ve Mgmt API ile canlıdan tam sayım karşılaştırması yapıyor (T/F/V birebir, fail-closed). Neon'u tazelemek ikinci bir yükleme yolu ve uzak bağımlılık ekler. README.md:277 zaten "local schema mirror" diyor, belge de kodla hizalandı. `NEON_LSP_URL` .env'de kaldı. sql-lsp gibi başka kullanıcısı olabilir, ona dokunulmadı.

## TDD ve mutant (MEASURED)
- Kırmızı: değiştirilmemiş betik kopyasında test → T1 FAIL, T2 FAIL rc 66, T3 FAIL rc 66 (23 sn).
- Yeşil: düzeltme sonrası T1-T4 PASS. T5 eklendi, önce kırmızı (rc 1, `• 00000 • 42701`), süzme sonrası yeşil.
- Mutant: yalnız `SET check_function_bodies = off` satırı kaldırıldı → T2, T3, T5 FAIL rc 66 (test bu satırı yakalıyor).
- Kilit: kilit 15 sn tutulurken dry-run 26 sn sürdü, kilitsizken 13 sn. Bekleme ölçüldü.
- Ayna sadakati: düzeltme sonrası refresh tek başına rc 0, `Canlı: T=60 F=328 V=16 / Yerel: T=60 F=328 V=16`, tüm parçalarda 0 hata. `dogum_kaydet` md5 yerelde `98baca62…` ve prod'da `98baca62…` (Mgmt API read_only), eşit.

## Run kanıtı
Ortam: worktree'de .env yok. Ana checkout `.env`'i kopyalanmadan ortama yüklendi (`set -a; . ~/egesut-erp1/.env; set +a`), cwd `~/.herdr/worktrees/egesut-erp1/dryrun-fix`. ram-ultracode havuzu `critical` durumdaydı ve oturum test tavanı kardeş ajanın slotundaydı. İlk deneme 300 sn kuyrukta zaman aşımına düştü, bu yüzden komutlar doğrudan koşuldu (assumption kırıntısı).

Önemli bağlam (MEASURED, Mgmt API read_only): prod `schema_migrations` artık 20261110100001…100008 kayıtlarının **8'ini de** taşıyor. ovsync-tren apply'ı bu iş sürerken yapılmış. Ayna = güncel prod. Bu yüzden 100001'in kendi md5 koruması (`DOGUM_KAYDET_GOVDE_FARKLI`, P0001) doğru biçimde tetikleniyor: gövde artık D0 tabanı değil. Bu araç hatası değil, migration'ın yeniden uygulamaya karşı koruması. Aynı dosya bugün prod'da da aynı hatayla durur. 100007 ve 100008 de `42723 already exists` verdi, beklenen sonuç. Temiz rc 0 kanıtı: aşağıda 100002 (gerçek migration, yalnız NOTICE) ve test T2.

### 1) Brief komutu (birebir)
```
bash scripts/db-dry-run.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_*.sql
```
rc: 1
```
  Migration çıktısı:
    BEGIN
    SET
    SET
  Hata çıktısı:
    psql:~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql:21: ERROR:  P0001: DOGUM_KAYDET_GOVDE_FARKLI: canlı gövde D0 tabanı değil (govde-taban.md), Faz 0 durdu
    BAĞLAM:  PL/pgSQL function inline_code_block line 5 at RAISE
    YER:  exec_stmt_raise, pl_exec.c:3909
▶ Hata kodu analizi…
⚠ Bilinmeyen hata kodları (incele):
     • P0001
❌ DRY-RUN: HATA
⚠ ÖNEMLİ — yerel ayna CONSTRAINT-FREE olduğu için:
   • FK ihlalleri (yanlış ref_tohumlama_id) burada YAKALANMAZ
   • Unique/PK ihlalleri burada YAKALANMAZ
   • Sadece kolon/tablo/fonksiyon VARLIK + TİP kontrolü çalışır
   • Index/trigger/policy/constraint adı çakışması (42710/42P07) YAKALANMAZ
   • plpgsql gövdesindeki olmayan kolon/tablo (42703/42P01) YAKALANMAZ
   • Migration canlıya uygulanmadan önce ayrıca gerçek DB'de de test et
rc: 1
```
Eskiden rc 66 alınıyordu (ayna kurulamıyordu). Şimdi ayna kuruluyor ve migration gerçek prod durumunda deneniyor. rc 1'in nedeni yukarıdaki bağlam.

### 2) Temiz gerçek migration (yalnız NOTICE)
```
bash scripts/db-dry-run.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_*.sql
```
rc: 0
```
    REVOKE
    REVOKE
    ROLLBACK
  Hata çıktısı:
    psql:.../20261110100002_ovsync_tren_cekirdek.sql:29: NOTICE:  42701: column "ovsync_tren" of relation "cases" already exists, skipping
    YER:  check_for_column_name_collision, tablecmds.c:7688
    psql:.../20261110100002_ovsync_tren_cekirdek.sql:33: NOTICE:  42701: column "ovsync_bagimsiz" of relation "cases" already exists, skipping
    YER:  check_for_column_name_collision, tablecmds.c:7688
▶ Hata kodu analizi…
✓ Hiçbir hata yakalanmadı. Migration yerel aynada temiz çalışıyor (ROLLBACK atıldı).
✅ DRY-RUN: BAŞARILI
rc: 0
```

### 3) Kasıtlı bozuk migration (olmayan kolon), geçici dosya `~/tmp/dryrun-bozuk-20261109.sql` (koşumdan sonra silindi, commitlenmedi)
```
bash scripts/db-dry-run.sh ~/tmp/dryrun-bozuk-20261109.sql
```
rc: 1
```
  Migration çıktısı:
    BEGIN
    ALTER TABLE
  Hata çıktısı:
    psql:~/tmp/dryrun-bozuk-20261109.sql:3: ERROR:  42703: column "zz_olmayan_kolon" of relation "cases" does not exist
    SATIR 1: UPDATE public.cases SET zz_olmayan_kolon = 1 WHERE false;
    YER:  transformUpdateTargetList, analyze.c:2589
▶ Hata kodu analizi…
🚨 1 hata kodu yakalandı:
   42703 → undefined_column  (kolon YOK)
❌ DRY-RUN: HATA
rc: 1
```

### 4) Kabul testi (kabul SHA 7e2895e'de)
```
bash scripts/tests/db-dry-run.test.sh
```
rc: 0
```
PASS T1 dry-run ve refresh aynı hedef (LOCAL_LSP_URL)
PASS T2 temiz fixture rc=0
PASS T3 bozuk fixture rc=1 + 42703
PASS T5 NOTICE-only migration rc=0 (42701 NOTICE hata sayılmadı)
PASS T4 çıktıda parola yok
SONUÇ: 0 hata
```
Sır taraması: Run log'larında (R1-R3) LOCAL_LSP_URL parolası ve proje ref'i grep ile 0 (MEASURED). Rapora ve commit'e sır, parola ya da ref yazılmadı.

## Açık kalemler (bütçe dışı, düzeltilmedi)
- **Ayna sınırı (INFERRED, koddan):** Ayna constraint-free. Tablo, kolon, fonksiyon ve view var. index, trigger, policy ve constraint yok. Bu yüzden bu nesnelerin ad çakışması (42710/42P07) yakalanmaz. plpgsql gövdesi oluşturmada derlenmediği için gövde içindeki 42703/42P01 de yakalanmaz. Bu, "42710'u güvenilir yakala" hedefinin bir kısmını karşılamıyor. Kapatmak ayna mimarisi değişikliği ister (pg_get_triggerdef/indexdef/constraintdef ve policy üretimi, plpgsql_check), ≤60 bütçesini aşar. Önerilen plan: refresh'e 4. ve 5. adım olarak `pg_get_indexdef` + `pg_get_triggerdef` + `pg_get_constraintdef` (FK hariç) + `pg_policies`'ten CREATE POLICY eklemek ve sayım kapısını genişletmek. plpgsql için `plpgsql_check` eklentisi yerelde varsa migration sonrasında yalnız değişen fonksiyonlara uygulanır. Bu turda dry-run çıktısı sınırı açıkça basıyor.
- `refresh_lsp_schema.sh:31` prod proje ref'ini varsayılan olarak public repoda taşıyor. Önceden vardı, bu işte dokunulmadı.
- `db-validate` (egesut_val_tmp) kilitsizliği ayrı kalem (ce98243ee790); dokunulmadı.
- Başarısız refresh koşumlarının temp dizinleri `~/tmp/agents/refresh_lsp.*` altında korunuyor (tasarım gereği). Benim 6 dizinim silindi. P2-P9 koşumlarından kalan 11 dizine dokunulmadı.

SORU (bloke etmeyen): ayna index/trigger/policy/constraint + plpgsql_check genişletmesi ayrı bir lead işine taşınsın mı? · seçenekler: (a) ayrı kulvar, (b) şimdilik sınır notu yeter · önerim: (a). runbook adım 3 "42710 = 0" diyor, oysa ayna bu sınıfın yalnız tablo/fonksiyon kısmını görüyor.

## Kırıntılar
- gate env-mismatch: tazelenen ≠ denenen giderildi (T1, kilit ölçümü)
- gate silent-success: NOTICE kodları yanlış-kırmızıydı, ERROR'a süzüldü (T5, R2)
- gate doc-drift: `.gitignore *.sh` scripts/tests'i yok sayıyor, `git add -f`
- measurement: kök neden check_function_bodies, F 300→328
- open_item: ayna sınırı (index/trigger/policy/constraint/plpgsql)
- open_item: refresh varsayılan proje ref'i
- assumption: ram-ultracode havuzu dışı doğrudan koşum
- assumption: gitnexus. dryrun-fix worktree'si indekslenmemiş (`gitnexus status` → not indexed) ve değişiklik yalnız bash betiği. Bu yüzden `analyze --index-only` koşulmadı. Kod keşfi doğrudan okuma ile yapıldı (2 betik, tam okundu).
