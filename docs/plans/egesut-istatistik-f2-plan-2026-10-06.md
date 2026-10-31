# İstatistik Modülü F2 (Python motor v1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Tarih:** 2026-10-06 · **Yazar:** ss-mimar (istat-mimar) · **Dal:** `istatistik-modülü` · **Durum:** TASLAK — sahip incelemesi bekliyor (açık sorular `runs/2026-10-05-istatistik-modulu/f2/SORULAR.md`)

**Goal:** Bu makinede koşan Python motoru, tedavi vakalarını yalnız Postgres'ten içerik hash-diff ile çekip Kaplan-Meier sağkalım eğrisi ve protokol farkı (log-rank + Cox) hesaplar, sonucu `stat_analiz_sonuc`'a yazar; ekran sonucu hesap tarihiyle gösterir.

**Architecture:** Postgres ayıklama fonksiyonları (`stat_ayikla_*`, yalnız `stat_motor` rolü çağırır) vaka başına satır + içerik hash'i verir. Motor (`tools/stat-motor/`, Python 3.14, uv) yerel parquet önbelleğiyle hash'leri karşılaştırır. Değişiklik yoksa koşum `atlandi` olur. Değişiklik varsa yalnız yeni/değişen satırları çeker, modeli önbellekteki tam kümeden yeniden kurar ve tek transaction'da upsert eder. Hesap saf fonksiyondur (`bugun` parametreli), DB ve önbellek ince kabuklardır.

**Tech Stack:** PostgreSQL (Supabase), Python 3.14 + uv, `psycopg[binary]` 3, `lifelines==0.30.3`, `pandas` 3.0, `pyarrow`, `scipy==1.18.1`, `pytest`; vanilla JS (`js/ui.js`, `js/api.js`), `node --test`; systemd user timer.

**Spec:** `docs/2026-10-05-istatistik-modulu-spec.md` (ONAYLI v1). Bu plan §3.2, §5.3 motor satırları, §7.1-7.3, §8.1-8.2, §9 F2 ve §11'deki motor risklerini uygular; A5 (motor bağlantısı/rol) burada kapanır. Maddeler `P1…P9`.

## Global Constraints

- Motor **yalnız Postgres'ten** beslenir (K3), yerel dosyadan veri okumaz; önbellek yalnız DB çıktısından dolar, bozulursa silinir ve tam çekim yapılır (§7.2-4).
- Delta = içerik hash-diff (K4); kaynakta damga yok. Değişen yoksa ve `--force` verilmemişse koşum `durum='atlandi'`, hesap yok (K5).
- Model her koşumda önbellekteki **tam** kümeden baştan kurulur (K6). Taşınan veri yalnız delta.
- Motor DB kimliği: özel rol `stat_motor`. Yetkileri yalnız `stat_ayikla_*` EXECUTE, `stat_analiz_sonuc` ve `stat_motor_kosum` SELECT/INSERT/UPDATE(/DELETE yalnız sonuç). service-role anahtarı kullanılmaz (§7.1). Bağlantı dizesi `~/.config/stat-motor/<profil>.env` dosyasında, git dışı, izin `600`. Dizgi hiçbir log'a, rapora ya da kırıntıya yazılmaz.
- Zarf §8.1 birebir: `olcum, hesap_at, surum, n, yetersiz, x{ad,deger}, seriler[{ad,n,y,alt,ust}], tablo[], dipnot[]`. `surum = 'motor:<git sha kısa>'`, `motor_surum` = aynı sha, `girdi_ozeti` = kümedeki `(id, hash)` çiftlerinin sıralı md5'i (§7.3).
- K8: grup `n < 5` → değer `null`, `yetersiz: true`; protokol farkı n<5 grupta üretilmez (§5.3).
- "Bugün" `Europe/Istanbul` tarihi. SQL'de `(now() AT TIME ZONE 'Europe/Istanbul')::date`, Python'da `datetime.now(ZoneInfo('Europe/Istanbul')).date()`. `CURRENT_DATE` yasak.
- Yeni tablo yok. Yeni fonksiyonlar `SET search_path = public, pg_temp`. Ayıklama fonksiyonları `SECURITY DEFINER`, çünkü `stat_motor`'un kaynak tablolarda SELECT yetkisi yoktur. `REVOKE ALL … FROM PUBLIC, anon, authenticated` + `GRANT EXECUTE … TO stat_motor`.
- Migration adı `2026100600000N_<ad>.sql`. Her biri `bash scripts/db-validate.sh <dosya> --priors <20261005000001…000005 + önceki F2'ler>` → exit 0, ardından demo `psql -f`. Prod uygulaması bu planın DIŞI (sahip adımı, F0+F1 Ö1 ile aynı pencere).
- Demo DB yardımcısı `~/tmp/istat-f0f1/demo-env.sh` (değer içermez, kaynak `.env`); ilk bağlantıda ref `vtzqjmazsvurxdeondmi` doğrulanır.
- git: dosya dosya `git add`; `-A`/`.`/`-u` yasak; `docs/plans/`, `reports/` → `git add -f`. Merge/push yok. JS düzenlemesinden ≤600 sn önce `atlas_query(komut="etki")` (blast-radius hook; dolanmak yasak).
- Python: `uv` ile `tools/stat-motor/.venv`, `uv.lock` commit'lenir. Testler `uv run --project tools/stat-motor pytest -q`.

## Review Focus

1. **Upsert başarısızken önbellek ilerlerse** sonraki koşum değişikliği görmez, sonuç sonsuza dek bayat kalır → önbellek yalnız DB commit'inden SONRA yazılır → P6 test `onbellek_commit_sonrasi`.
2. **Artık hastalığı kalmamış eski sonuç satırları** (tüm vakaları silinmiş/protokol sayılmış hastalık) ekranda kalırsa yanlış eğri gösterilir → koşum, aynı `olcum` için yeni kümede olmayan `anahtar`ları aynı transaction'da siler → P6 test `kaybolan_anahtar_silinir`.
3. **İki koşum aynı anda** (timer + elle) önbelleği ve koşum defterini bozar → önbellek dizininde `fcntl` kilidi; ikinci koşum `durum='atlandi'`, `mesaj='kilit: başka koşum sürüyor'` → P6 test `es_zamanli_kilit`.
4. **Tanımsız süre** (ters tarih, `olay_tarihi NULL` ama sonuç `iyilesti`) KM'ye negatif/NaN süre sokar → bu vakalar dışarıda, sayısı dipnotta → P5 test `tanimsiz_sure_dislanir`.
5. **Medyan ulaşılmayan eğri** (iyileşme < %50) lifelines `inf` döner, JSON'a `Infinity` yazılırsa ekran kırılır → `inf`/`NaN` → `null` → P5 test `medyan_ulasilmadi_null`.

---

## Dosya yapısı

| Dosya | Görev | Sorumluluk |
|---|---|---|
| `scripts/db-validate.sh` | P1 | sqlfluff büyük dosya atlamasını kapat |
| `tests/sql/db_validate_buyuk_dosya_test.sh` | P1 | >20000 bayt bozuk SQL → FAIL kanıtı |
| `supabase/migrations/20261006000001_stat_motor_rol.sql` | P2 | `stat_motor` rolü (NOLOGIN) + sonuç tablosu yetkileri |
| `supabase/migrations/20261006000002_stat_ayikla_tedavi.sql` | P3 | `stat_ayikla_tedavi_vaka_ozet`, `stat_ayikla_tedavi_vaka` |
| `tests/sql/stat_ayikla_test.sql` | P3 | hash kararlılığı, yetki, protokol dışlama |
| `tools/stat-motor/pyproject.toml`, `uv.lock` | P4 | paket + sabit bağımlılıklar, `stat-motor` giriş noktası |
| `tools/stat-motor/stat_motor/onbellek.py` | P4 | parquet + `ozet.json`, `fark()`, kilit |
| `tools/stat-motor/stat_motor/hesap.py` | P5 | KM + log-rank/Cox → zarf (saf) |
| `tools/stat-motor/stat_motor/db.py` | P6 | bağlantı, ayıklama, koşum defteri, upsert |
| `tools/stat-motor/stat_motor/kosum.py`, `cli.py` | P6 | akış (§7.1 Şekil 4), CLI |
| `tools/stat-motor/systemd/stat-motor@.service`, `stat-motor@.timer` | P6 | gece timer birimleri (kurulum P9) |
| `tools/stat-motor/tests/*.py` | P4-P6 | pytest |
| `supabase/migrations/20261006000003_stat_motor_aktif.sql` | P7 | motor ölçümlerini listeye aç |
| `js/ui.js`, `js/api.js`, `index.html`, `tests/unit/stat-ui.test.js` | P7 | motor sonucu görünümü, `_statInvalidate` bağlama, `?v=` |
| `runs/2026-10-05-istatistik-modulu/f2/` | P8, P9 | UI zarf/rapor, DONE |
| `.gitignore` | P4 | `tools/stat-motor/.venv/`, `.pytest_cache/` |

**F0+F1 borçlarının kaderi:**
| Borç | Karar |
|---|---|
| db-validate >20000 bayt sessiz-PASS | **GİRER** → P1 (F2 migration'ları bu kapıdan geçer) |
| service_role stat_* yazma GRANT'i | **GİRER, değişmiş biçimde** → P2: yazma yetkisi service_role'e değil `stat_motor` rolüne (spec §7.1 "service-role anahtarı kullanılmaz") |
| `_statInvalidate` üretimde çağrılmıyor | **GİRER** → P7 (motor sonucu yeni veriyle tazelenebilsin) |
| `.stat-yetersiz` dark tema | **GİRMEZ** — görsel tasarım ayrı UI spec'inde (F1 plan Kapsam notu) |
| 000005 gövde kopyasını DROP+CREATE ile birleştir | **GİRMEZ** — davranış değiştirmeyen refactor, prod'a 000001-000005 henüz gitmedi. Sahip prod uygulamasından önce isterse ayrı kalem (`SORULAR.md` F2-S5) |

---

### Task 1: db-validate sqlfluff büyük dosya kapısı (P1 — F1 borcu)

**Model:** ss-worker-high (opus) · review ss-reviewer (opus)

**Files:**
- Modify: `scripts/db-validate.sh:159-176` (Faz A)
- Create: `tests/sql/db_validate_buyuk_dosya_test.sh`

**Interfaces:** Produces: Faz A'da dosya boyutundan bağımsız parse denetimi. Sonraki görevler normal biçimde kullanır.

- [ ] **Step 1: Test betiği (kırmızı).** Betik scratchpad'de iki dosya üretir: (a) `select 1;` satırlarıyla >20000 bayt ve sonunda `selec broken from;` olan dosya, (b) aynı boyutta temiz dosya. `bash scripts/db-validate.sh <a>; echo $?` → beklenen `1`, (b) için → `0`. Betik iki beklentiyi `PASS/FAIL` satırıyla basar ve biri tutmazsa exit 1 döner.
- [ ] **Step 2: Koş.** `bash tests/sql/db_validate_buyuk_dosya_test.sh` → (a) bugün exit 0 verdiği için FAIL beklenir. Çıktı rapora.
- [ ] **Step 3: Uygula.** sqlfluff'a `large_file_skip_byte_limit = 0` veren geçici config (`$WORK/sqlfluff.cfg`, `[sqlfluff]` bölümü) `--config` ile geçirilir. Ayrıca `sqlfluff.out`'ta "skipped"/"large file" ibaresi görülürse `A.sqlfluff-parse` = FAIL ("dosya atlandı"). Sessiz PASS olmaz.
- [ ] **Step 4: Yeşil + regresyon.** Test betiği exit 0; `bash scripts/db-validate.sh supabase/migrations/20261005000005_stat_protokol_disla.sql --priors <000001..000004>` → exit 0 (önce/sonra aynı).
- [ ] **Step 5: Commit** `git commit -m "onarim(arac): db-validate sqlfluff büyük dosya atlaması FAIL (F2 P1)" -- scripts/db-validate.sh tests/sql/db_validate_buyuk_dosya_test.sh`

---

### Task 2: `stat_motor` rolü ve sonuç yetkileri (P2 — spec §7.1, A5)

**Model:** ss-worker-high (opus) · review ss-reviewer (opus)

**Files:**
- Create: `supabase/migrations/20261006000001_stat_motor_rol.sql`

**Interfaces:**
- Produces: rol `stat_motor` (migration'da `NOLOGIN`, parola yok). Yetkiler: `USAGE ON SCHEMA public`; `stat_analiz_sonuc` SELECT/INSERT/UPDATE/DELETE; `stat_motor_kosum` SELECT/INSERT/UPDATE; `stat_olcum_kayit` SELECT; iki tablonun identity sequence'lerine USAGE. Başka tablo/fonksiyon yetkisi yok.
- Demo'da LOGIN: migration dışında, `ALTER ROLE stat_motor LOGIN PASSWORD '<geçici>'` (sahip kararı F2-S3; parola yalnız `~/.config/stat-motor/demo.env` dosyasında, `600`).

- [ ] **Step 1: Migration.** `DO $$ … IF NOT EXISTS (select from pg_roles where rolname='stat_motor') THEN CREATE ROLE stat_motor NOLOGIN; END IF $$` + GRANT'ler. Idempotent. `COMMENT ON ROLE` spec §7.1 cümlesi.
- [ ] **Step 2: db-validate** (priors 000001-000005) → exit 0, iki kez.
- [ ] **Step 3: Demo uygula + LOGIN + env dosyası.** Dosya `~/.config/stat-motor/demo.env` içinde tek satır `STAT_MOTOR_DSN=postgresql://stat_motor.<demo ref>:<parola>@<pooler>:5432/postgres?sslmode=require`, `chmod 600`. Parola `openssl rand -base64 24`.
- [ ] **Step 4: Rol kabulü (demo, rol olarak bağlanarak).** `select current_user` → `stat_motor`. `insert into stat_analiz_sonuc(olcum,anahtar,sonuc) values ('t','{}','{}')` → başarılı; temizlenir. `select count(*) from cases` → `permission denied`. `select stat_tedavi_ozet(...)` → `permission denied`. Pooler'ın özel rolü kabul etmemesi A5 riskidir: kabul etmezse DUR → mimara (doğrudan `db.<ref>` 5432 alternatifi seçenek olarak raporda).
- [ ] **Step 5: Commit** migration + `reports/db-validation-<sha8>.md` (`-f`).

---

### Task 3: Ayıklama fonksiyonları (P3 — spec §7.2)

**Model:** ss-worker-high (opus) · review ss-reviewer (opus)

**Files:**
- Create: `supabase/migrations/20261006000002_stat_ayikla_tedavi.sql`
- Create: `tests/sql/stat_ayikla_test.sql`

**Interfaces:**
- Consumes: `v_stat_vaka` (000005; protokol vakaları zaten dışarıda), `stat_protokol_etiket(p_dizi text[], p_tedavi_suresi_gun int, p_duzey text)` (000004:26).
- Produces:
  - `stat_ayikla_tedavi_vaka(p_ids uuid[] DEFAULT NULL) RETURNS TABLE(vaka_id uuid, hastalik text, protokol_etiket text, baslangic date, sonuc text, olay_tarihi date)`. `p_ids NULL` → tüm küme. `protokol_etiket = stat_protokol_etiket(protokol, tedavi_suresi_gun, 'urun')` (F1 ekranıyla aynı etiket). `olay_tarihi = baslangic + olay_gun` (`sonuc <> 'devam'` iken), `devam` → NULL. Bu sayede satır bugüne bağlı değildir ve hash günden güne değişmez.
  - `stat_ayikla_tedavi_vaka_ozet() RETURNS TABLE(vaka_id uuid, hash text)`. `hash = md5(row(...)::text)`: `stat_ayikla_tedavi_vaka(NULL)`'ın döndürdüğü altı kolon üzerinden (tek tanım: özet tam fonksiyonu çağırır).
  - Spec §7.2 `p_ids bigint[]` der; vaka kimliği uuid olduğu için `uuid[]` (Ruling, plan yazarı).
  - İkisi `STABLE SECURITY DEFINER SET search_path = public, pg_temp`. EXECUTE yalnız `stat_motor`.

- [ ] **Step 1: Test (kırmızı).** F1 E2E-STAT fixture bloğunu kopyala (`tests/sql/stat_tedavi_test.sql:1-58` deseni). Kodlar:
  - `ozet_tam`: özet satır sayısı = `count(*) from v_stat_vaka`.
  - `hash_kararli`: iki ardışık çağrıda aynı hash kümesi.
  - `devam_bugunsuz`: `devam` vakada `olay_tarihi IS NULL`.
  - `degisim_hash`: fixture vakasına bir uygulama günü ekle → yalnız o vakanın hash'i değişir.
  - `protokol_yok`: E2E protokol vakası (`protocol_family='OVSYNC'`) özette yok.
  - `yetki`: `has_function_privilege('authenticated', …,'EXECUTE')=f`, `anon`=f, `stat_motor`=t.
  - `ids_alt_kume`: `p_ids` 2 elemanlı → 2 satır.
- [ ] **Step 2: Kırmızı koş** (`does not exist`).
- [ ] **Step 3: Migration** (Interfaces). `COMMENT ON FUNCTION` hash kolon listesini yazar.
- [ ] **Step 4: db-validate** (priors +20261006000001) → exit 0; demo `psql -f`; test 7/7 PASS, E2E artığı 0.
- [ ] **Step 5: Commit.**

---

### Task 4: Motor paketi iskeleti + hash-diff önbelleği (P4 — spec §7.1, §7.2)

**Model:** general-purpose (sonnet) · review ss-reviewer (opus)

**Files:**
- Create: `tools/stat-motor/pyproject.toml`, `tools/stat-motor/uv.lock`, `tools/stat-motor/stat_motor/__init__.py`, `tools/stat-motor/stat_motor/onbellek.py`, `tools/stat-motor/tests/test_onbellek.py`
- Modify: `.gitignore` (`tools/stat-motor/.venv/`, `tools/stat-motor/.pytest_cache/`)

**Interfaces:** Produces (`stat_motor.onbellek`):
- `Fark(yeni: set[str], degisen: set[str], kaybolan: set[str])` dataclass + `bos: bool` özelliği.
- `fark(eski: dict[str,str], yeni: dict[str,str]) -> Fark`.
- `girdi_ozeti(ozet: dict[str,str]) -> str`: `"\n".join(f"{id}:{h}" for id,h in sorted(ozet.items()))` md5'i.
- `Onbellek(kok: Path, profil: str, kume: str)`. `.oku() -> tuple[dict[str,str], pandas.DataFrame]` (dosya yok ya da bozuk → `({}, boş DataFrame)` ve dosyalar silinir). `.yaz(ozet, df)` önce geçici dosyaya, sonra `os.replace` ile atomik yazar. `.kilit()` context manager (`fcntl.flock` LOCK_EX|LOCK_NB; alınamazsa `KilitMesgul`).
- Varsayılan kök `~/.cache/stat-motor`.
- pyproject: `requires-python = ">=3.14"`, bağımlılıklar `psycopg[binary]>=3.2`, `lifelines==0.30.3`, `pandas>=3.0,<3.1`, `pyarrow`, `scipy==1.18.1`; dev `pytest`; script `stat-motor = "stat_motor.cli:main"`.

- [ ] **Step 1: Testler (kırmızı)** `test_onbellek.py`: `test_fark_uc_kume` (yeni/değişen/kaybolan ayrı), `test_fark_bos`, `test_girdi_ozeti_sira_bagimsiz`, `test_bozuk_dosya_tam_cekime_doner` (parquet yerine çöp bayt → `({}, boş)` ve dosya silinmiş), `test_yaz_atomik` (yazım ortasında istisna → eski dosya bozulmaz), `test_kilit_ikinci_alamaz`. Hepsi `tmp_path`.
- [ ] **Step 2:** `uv sync --project tools/stat-motor` + `uv run --project tools/stat-motor pytest -q` → import hatası.
- [ ] **Step 3: Uygula** (Interfaces).
- [ ] **Step 4:** pytest → 6 passed.
- [ ] **Step 5: Commit** (uv.lock dahil, `.venv` hariç: `git status --short` ile doğrula).

---

### Task 5: Hesap — Kaplan-Meier ve protokol farkı (P5 — spec §5.3 motor satırları, §8.1, K8)

**Model:** general-purpose (sonnet) · review ss-reviewer (opus) — reviewer KM değerlerini lifelines referansıyla elle doğrular

**Files:**
- Create: `tools/stat-motor/stat_motor/hesap.py`, `tools/stat-motor/tests/test_hesap.py`

**Interfaces:**
- Consumes: Task 3 satır şeması (DataFrame kolonları `vaka_id, hastalik, protokol_etiket, baslangic, sonuc, olay_tarihi`).
- Produces (`stat_motor.hesap`, DB'siz, saf):
  - `sure_olay(df, bugun: date) -> DataFrame` kolonları `sure_gun:int, olay:bool`. `iyilesti` → olay=True, süre `olay_tarihi−baslangic`. `devam` → olay=False, süre `bugun−baslangic`. `oldu_kesildi`, `nuks` → olay=False, süre `olay_tarihi−baslangic` (F2-S1 önerisi; sahip H derse yalnız bu fonksiyon değişir). Süre NULL ya da <0 → satır dışarıda, `dislanan` sayısı döner.
  - `sagkalim_zarflari(df, bugun, surum: str, hesap_at: str) -> dict[str, dict]`. Anahtar hastalık adı, değer §8.1 zarfı, `olcum='stat_tedavi_sagkalim'`. `x.ad='gün'`, `x.deger=[0..maks süre]`. Seri protokol etiketi başına: `y` = kümülatif iyileşme `1−S(t)`, `alt/ust` = `1−` GA sınırları (%95, lifelines varsayılanı), değerler 4 hane yuvarlanır. Grup n<5 → seri `y/alt/ust=null`. `tablo` satırı `{protokol, n, olay_n, sansur_n, medyan_gun, medyan_alt, medyan_ust, yetersiz}`, `inf`/`NaN` → `null`. Zarf `n` = hastalık toplamı, `yetersiz = n<5`. `dipnot`: "Ölüm/kesim ve nüks, olay gününde sansürlendi." + dışlanan>0 ise "Süresi tanımsız k vaka dahil edilmedi." + "Karşılaştırma yalnız aynı hastalık içinde anlamlıdır; neden-sonuç değildir."
  - `fark_zarflari(df, bugun, surum, hesap_at) -> dict[str, dict]`. `olcum='stat_tedavi_protokol_fark'`. n≥5 protokollerin her ikilisi için `tablo` satırı `{a, b, n_a, n_b, logrank_p, hr, hr_alt, hr_ust}`. `logrank_p` `lifelines.statistics.logrank_test` ile, HR `CoxPHFitter` ile (tek ikili değişken `b` grubu, `hr = exp(coef)`). Uygun protokol <2 → `yetersiz=true`, `tablo=[]`. Cox yakınsamazsa ya da tek grupta olay yoksa satırda `hr/hr_alt/hr_ust=null` ve dipnot "HR hesaplanamadı (a–b)." `x=null`, `seriler=[]`.

- [ ] **Step 1: Testler (kırmızı)** `test_hesap.py` sabit sentetik DataFrame'lerle:
  - `test_sure_olay_kurallari`: dört sonuç tipi + `bugun` sabit.
  - `test_tanimsiz_sure_dislanir` (RF 4): ters tarih → dışarıda, dipnot sayısı 1.
  - `test_km_referans`: 6 vakalık grup, beklenen `y` değerleri `KaplanMeierFitter` ile testte bağımsız hesaplanıp karşılaştırılır.
  - `test_medyan_ulasilmadi_null` (RF 5): `json.dumps(zarf, allow_nan=False)` istisna atmaz.
  - `test_n5_alti_seri_null` (K8).
  - `test_fark_iki_protokol`: belirgin ayrık iki grup → `logrank_p < 0.05`, `hr` sonlu.
  - `test_fark_tek_protokol_yetersiz`.
  - `test_deterministik`: aynı girdi + `bugun` → `json.dumps(sort_keys=True)` eşit.
- [ ] **Step 2:** kırmızı. **Step 3:** uygula. **Step 4:** `pytest -q` → hepsi geçer.
- [ ] **Step 5: Commit.**

---

### Task 6: Koşum akışı, DB katmanı, CLI, systemd birimleri (P6 — spec §7.1 Şekil 4, §7.3, §9 F2 kabulü)

**Model:** general-purpose (sonnet) · review ss-reviewer (opus)

**Files:**
- Create: `tools/stat-motor/stat_motor/db.py`, `kosum.py`, `cli.py`, `tools/stat-motor/tests/test_kosum.py`, `tools/stat-motor/systemd/stat-motor@.service`, `tools/stat-motor/systemd/stat-motor@.timer`

**Interfaces:**
- Consumes: Task 3 SQL, Task 4 `Onbellek/fark/girdi_ozeti`, Task 5 `sagkalim_zarflari/fark_zarflari`.
- Produces:
  - `db.baglan(profil: str) -> psycopg.Connection`. `~/.config/stat-motor/<profil>.env` dosyasından `STAT_MOTOR_DSN` okur. Dosya izni `0o077` maskesine değiyorsa `PermissionError("env dosyası 600 olmalı")` atar. DSN istisna mesajına ya da log'a girmez.
  - `Depo` protokolü (test için sahte uygulanır): `ozet() -> dict[str,str]`, `satirlar(ids: list[str]) -> DataFrame`, `kosum_ac() -> int`, `kosum_kapat(id, durum, mesaj, degisen: dict)`, `yaz(olcum: str, zarflar: dict[str,dict], girdi_ozeti: str, motor_surum: str)`. `yaz` her zarfı `{"hastalik": ad}` anahtarıyla upsert eder (`ON CONFLICT (farm_id, olcum, anahtar)`) ve aynı `olcum`'da listede olmayan anahtarları siler (RF 2). Tek transaction'dır.
  - `kosum.calistir(depo, onbellek, bugun, surum, force=False) -> str` → `'ok'|'atlandi'|'hata'`. Akış: kilit (alınamazsa `kosum_ac`+`atlandi` "kilit…", RF 3) → `kosum_ac` (durum NULL) → `ozet` → `fark` → boş ve `force` yoksa `atlandi` → değişen satırlar çekilir, önbellekle birleşir, kaybolanlar düşer → iki hesap → `yaz` → **commit sonrası** `onbellek.yaz` (RF 1) → `kosum_kapat('ok', degisen={"tedavi_vaka":{"yeni":n,"degisen":n,"kaybolan":n}})`. İstisnada rollback, `kosum_kapat('hata', mesaj[:500])`, önbellek yazılmaz, eski sonuçlar kalır (§7.1).
  - `cli.main()`: `stat-motor run --profil {demo,prod} [--force]`. `surum = git rev-parse --short HEAD` (repo kökü paketten bulunur; git yoksa `motor:yerel`). Çıkış kodu: ok/atlandi 0, hata 1.
  - systemd: `stat-motor@.service` (`Type=oneshot`, `ExecStart=<repo>/tools/stat-motor/.venv/bin/stat-motor run --profil %i`), `stat-motor@.timer` (`OnCalendar=*-*-* 03:30`, `Persistent=true`, `RandomizedDelaySec=10m`).

- [ ] **Step 1: Testler (kırmızı)** `test_kosum.py`, sahte `Depo` + `tmp_path` önbellek:
  - `test_ilk_kosum_ok_ve_onbellek`.
  - `test_ikinci_kosum_atlandi` (K5).
  - `test_force_ayni_sonuc` (§9 F2: aynı `girdi_ozeti`, `hesap_at` hariç aynı `sonuc`).
  - `test_degisen_yalniz_delta_ceker` (`satirlar` yalnız değişen id'lerle çağrılır).
  - `test_onbellek_commit_sonrasi` (RF 1: `yaz` istisna → önbellek eski, durum `hata`).
  - `test_kaybolan_anahtar_silinir` (RF 2).
  - `test_es_zamanli_kilit` (RF 3).
  - `test_env_izin_600`.
- [ ] **Step 2:** kırmızı. **Step 3:** uygula. **Step 4:** pytest yeşil.
- [ ] **Step 5: Demo uçtan uca** (`STAT_MOTOR` demo profili). `stat-motor run --profil demo` → `ok`. Tekrar → `atlandi`. `--force` → `ok`, `girdi_ozeti` aynı, `sonuc - 'hesap_at'` aynı (psql ile `stat_analiz_sonuc` iki anlık görüntü karşılaştırması). `stat_motor_kosum` son 3 satır `ok, atlandi, ok`. Çıktılar rapora.
- [ ] **Step 6:** `systemd-analyze --user verify tools/stat-motor/systemd/stat-motor@.service` → hatasız. Kurulum YOK (P9).
- [ ] **Step 7: Commit.**

---

### Task 7: Ekran — motor ölçümleri, invalidate (P7 — spec §9 F2 "ekranda sağkalım eğrisi + hesap tarihi", K5)

**Model:** general-purpose (sonnet) · review ss-reviewer (sonnet) · JS düzenlemesinden önce `atlas_query etki` (`loadIstatistik`, `istatistikYenile`, `syncNow`)

**Files:**
- Create: `supabase/migrations/20261006000003_stat_motor_aktif.sql`
- Modify: `js/ui.js:619-720`, `js/api.js:873` (`syncNow` sonu), `index.html` (`?v=` tek değer), `tests/unit/stat-ui.test.js`

**Interfaces:**
- Consumes: `statSonucOku(olcum, anahtar)` (`js/api.js:1229`), `stat_olcum_listele` `tip` alanı, Task 5 zarf şekli.
- Produces:
  - Migration: `UPDATE stat_olcum_kayit SET aktif=true WHERE ad IN ('stat_tedavi_sagkalim','stat_tedavi_protokol_fark')`. db-validate + demo uygulama.
  - `istatistikYenile`: `tip==='motor'` ölçümde hastalık zorunlu ("Bu ölçüm için hastalık seçin", sure_dagilim kalıbı) → `statSonucOku(ad, {hastalik})`. Dönem filtresi motor ölçümünde gizlenir (sonuç dönemsizdir).
  - `_istatistikSeriTabloHtml(zarf, gunler = [7,14,21,30,60]) -> string` (saf). Her seri bir satır, her gün bir kolon: `y` değeri (`x.deger` içinde ≤ gün olan son nokta) `%` biçiminde, `null` → `—`. Eğrinin grafik çizimi F2-S2 kararına bağlıdır; öneri (a) bu tablo, grafik UI spec'inde. Altında mevcut `_istatistikTabloHtml(zarf)` (medyan/fark tablosu + dipnot + `Hesap:` satırı) aynen.
  - `SIRA` haritasına iki motor ölçümünün kolon sırası.
  - `syncNow` başarıyla bitince `_statInvalidate()` (F1 borcu).
  - `?v=` tek yeni değer.

- [ ] **Step 1: Testler (kırmızı)** `stat-ui.test.js`:
  - `seri_tablo_gunler` (2 seri × 5 gün, `null` → `—`, `%` biçimi).
  - `seri_tablo_kacis` (seri adında `<b>` → `&lt;b&gt;`).
  - `motor_hesap_satiri` (zarf `hesap_at` → `Hesap:` satırı).
- [ ] **Step 2:** kırmızı. **Step 3:** uygula. **Step 4:** `NODE_PATH=<ana-checkout>/node_modules npm run test:unit` → yeni fail 0 (taban 1527/1523/4).
- [ ] **Step 5:** demo duman yürüyüşü (1 png `runs/2026-10-05-istatistik-modulu/f2/ekran-01.png`).
- [ ] **Step 6: Commit.**

---

### Task 8: UI testi kapısı (P8 — proje CLAUDE.md, bağlayıcı)

**Model:** general-purpose (sonnet) koşucu · FAIL → Task 7 implementer'ı, yalnız FAIL maddeleri

**Files:** Create `runs/2026-10-05-istatistik-modulu/f2/ui-test-zarf.md`, `…/ui-test-rapor.md`, png'ler.

- [ ] **Step 1: Zarf.** Maddeler:
  1. Sekmelerde 5 ölçüm (3 SQL + 2 motor).
  2. Motor sekmesi + "Tümü" → "hastalık seçin" uyarısı, çağrı yok.
  3. Motor + hastalık → gün kesitli eğri tablosu.
  4. Medyan tablosu ve `Hesap: <tarih> · motor:<sha>`.
  5. n<5 protokol satırında `—` ve yetersiz.
  6. `protokol_fark` tablosunda p ve HR ya da yetersiz.
  7. Hiç hesaplanmamış hastalıkta "Henüz hesaplanmadı" dipnotu.
  8. SQL sekmeleri F1'deki gibi (regresyon).
  9. Konsolda hata yok.
  10. Ağ kesilince hata şeridi, eski tablo kalır.
- [ ] **Step 2-3:** koş. FAIL → düzelt → yalnız FAIL maddeleri. 10/10 PASS.
- [ ] **Step 4: Commit.**

---

### Task 9: Kapanış (P9 — spec §9 F2 kabulü, acceptance.md)

**Model:** lead + ss-worker-low (sonnet) komut koşucu; final broad review ss-reviewer (opus)

- [ ] **Step 1: Tam test.** `uv run --project tools/stat-motor pytest -q` 0 fail. Birim süit yeni fail 0. `stat_ayikla_test.sql` 7/7, F1 SQL testleri 10/10 + 15/15 (regresyon). Üç db-validate raporu PASS.
- [ ] **Step 2: F2 kabulü (demo).** Task 6 Step 5 üçlüsü yeniden koşmaz, çıktısı kontrol edilir ("Playwright bir kez yeter" ilkesi). Ekran kanıtı Task 8 raporundan.
- [ ] **Step 3: Timer kurulumu** (F2-S4 E ise): `mkdir -p ~/.config/systemd/user && ln -sf <repo>/tools/stat-motor/systemd/stat-motor@.{service,timer} ~/.config/systemd/user/ && systemctl --user daemon-reload && systemctl --user enable --now stat-motor@demo.timer`. `systemctl --user list-timers | grep stat-motor` → bir satır. H ise atlanır, DONE'a açık kalem.
- [ ] **Step 4: DONE** `runs/2026-10-05-istatistik-modulu/f2/LEAD-DONE.md`: kabul SHA, görev→commit, koşum defteri alıntısı, açık kalemler (prod: 20261006000001-3 + stat_motor LOGIN + prod.env sahip adımı; F0+F1 Ö1 ile aynı pencere).

---

## Önceden cevaplanmış kararlar (bu plan için)

- Yürütme hiyerarşisi: mimar → `ss-kulvar-lead-opus` (medium) → SQL `ss-worker-high` (opus), Python/JS/UI `general-purpose` (sonnet; bu oturumdaki ss-worker tanımları atlas görmüyor), review `ss-reviewer` (SQL/Python opus, JS sonnet). Merge/push/prod yok.
- Ayıklama fonksiyonları DEFINER: motor rolünün kaynak tablolara SELECT'i yok (spec §7.1 "yalnız stat_ayikla_* EXECUTE"). Yüzey EXECUTE GRANT'iyle `stat_motor`'a daraltılır.
- Hash, bugüne bağlı olmayan kolonlardan alınır (`olay_tarihi`, `olay_gun` değil). Aksi hâlde açık vakalar hash'i her gün değiştirir ve K5 "yeni veri yoksa koşmaz" hiç tutmaz. Açık vakaların sansür süresi motorda `bugun` ile hesaplanır. Veri değişmedikçe eğri son hesap gününde kalır (K5 tazelik önemsiz, hesap tarihi ekranda).
- Sağkalım ve fark ölçümleri yalnız ürün düzeyi protokol etiketiyle (F1 `duzey=urun` ile aynı). Sınıf düzeyi F7'ye.
- `stat_olcum_kayit.surum` motor satırlarında `'motor:-'` kalır (motor rolü kayıt tablosuna yazamaz). Gerçek sürüm zarfta ve `motor_surum` kolonunda.
- Yeni bağımlılıklardan `statsmodels` ve `openpyxl` F2'ye alınmaz (F7/F3 işleri, YAGNI).

- [F2 ruling] K16 (sahip 2026-10-06): Task 5 `sure_olay` kuralı (ölüm/kesim + nüks olay gününde sansür) sahip onaylı; dipnot korunur. K17 (aktif dönem = aktif hayvan): F2'de aktif-dönem kesitli ölçüm yok (KM uzun dönem, protokol farkı vaka bazlı) → plana filtre eklenmez; F3/F4 planlarına kayıt.

## Self-review notları (mimar)

- Spec kapsamı: §7.1 → P2 (rol), P4-P6 (motor, timer), P9 (kurulum). §7.2 → P3 + P4. §7.3 → P5-P6. §5.3 motor satırları → P5. §8.2 `stat_ayikla_*` → P3, `stat_sonuc_oku` ekranda → P7. §9 F2 kabulü → P6 Step 5 + P8. §11 "laptop kapalı" → `Persistent=true` + hesap tarihi. §11 "motor DB kimliği sızar" → P2 + env 600 + DSN log yasağı. A5 → P2 Step 4.
- Tip tutarlılığı: vaka id Python'da `str` (uuid metni), SQL'de `uuid`. Zarf alanları P5 ↔ P7 aynı. `girdi_ozeti` P4 tanımı P6'da kullanılır.
- Oran: spec ~480 satır, plan ~300 satır. Gövde yok; imza, test ve kabul var.
