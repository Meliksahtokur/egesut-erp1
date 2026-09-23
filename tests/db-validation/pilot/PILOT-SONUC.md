# DB-Validation Kapısı — Pilot Koşum Sonuçları

Tarih: 2026-09-24 · Dal: `db-validation-kurulum` · Koşan: pilot ajanı (plan adım 5)
Araçlar: sqlfluff 4.3.0, squawk 2.66.0, psql (yerel PG 18.6 @127.0.0.1:5432), baseline: `egesut_lsp`

## Özet

| Senaryo | Dosya | Beklenen | Gözlenen | Exit kodu | Rapor |
|---|---|---|---|---|---|
| pozitif | `pozitif.sql` | PASS (0) | **FAIL** | **1** [OBSERVED] | `reports/db-validation-704aa0ff.md` |
| negatif-syntax | `negatif-syntax.sql` | FAIL (1) | FAIL | **1** [OBSERVED] | `reports/db-validation-c48c6465.md` |
| negatif-cakisma | `negatif-cakisma.sql` | FAIL (1) | FAIL | **1** [OBSERVED] | `reports/db-validation-d996b979.md` |

**Sonuç: kapı REDDEDİLDİ.** İki negatif senaryo beklendiği gibi davrandı; pozitif
senaryo script hataları nedeniyle PASS üretemedi. Düzeltme yetkisi pilot ajanında
YOK (plan kuralı) — aşağıdaki hatalar `scripts/db-validate.sh` sahibine raporlanır.

## Kanıtlar [OBSERVED]

### negatif-syntax → FAIL, exit 1
- `A.sqlfluff-parse | FAIL | 1 parse hatası (PRS)` (kasıtlı `CREATE TABEL` yazımı yakalandı)
- `bash scripts/db-validate.sh tests/db-validation/pilot/negatif-syntax.sql` → `NEGCAK` değil,
  `NEGSYNTAX_EXIT=1`; `SONUÇ: FAIL` (reports/db-validation-c48c6465.md)

### negatif-cakisma → FAIL, exit 1
- Faz A parse PASS (sözdizimi gerçekten geçerli), hata C1'de yakalandı:
  `psql:...negatif-cakisma.sql:6: ERROR: relation "hayvanlar" already exists`
- `NEGCAK_EXIT=1`; `SONUÇ: FAIL` (reports/db-validation-d996b979.md)

### pozitif → BEKLENMEDIK FAIL, exit 1 (reports/db-validation-704aa0ff.md)
Kriter tablosu [OBSERVED]:
- `A.sqlfluff-parse PASS`, `B.sema-uyum PASS`, `C1.baseline-restore PASS`,
  `C1.migration-apply PASS`, `C1.postcheck-rls PASS` (RLS `val_pilot_test:→1`)
- `A.squawk FAIL` — `prefer-robust-stmts: Missing IF NOT EXISTS` (pilot SQL tarafında
  düzeltilebilir; kasıtlı bırakıldı çünkü asıl blokaj aşağıda)
- **`C1.postcheck-nesne FAIL` — "yaratılması beklenen nesne yok: val_pilot_test_select"**

## Bulunan script hataları (db-validate.sh — sahibine)

1. **POLICY post-check boşluğu (POZİTİF SENARYOYU BLOKLAYAN ASIL HATA):** Faz B
   CREATED_FILE regex'i POLICY nesnelerini yakalıyor (satır ~164), ama
   `C1.postcheck-nesne` sorgusu (satır ~278-288) yalnız pg_class/pg_proc/views/tables/
   pg_type'a bakıyor — **pg_policy/pg_policies yok**. Bu yüzden içeren her migration
   garanti FAIL üretir.
2. **Parite JSON anahtar uyumsuzluğu:** baseline `parite_durum` emit ediyor, validator
   `parite_durumu` okuyor (satır ~250) → her zaman `bilinmiyor` → `C1.ortam-paritesi`
   yanlışlıkla PASS. Düzeltildiğinde mevcut ortamda (prod PG 17.6 vs yerel 18.6; ayna
   fonksiyon sayısı 214 vs prod 221 → `parite_durum: uyumsuz`) pozitif senaryo SPEC
   gereği INCONCLUSIVE (exit 2) olurdu — yani PASS için ayrıca ayna refresh + parite
   gerekli.
3. **Fail-open gözlemi (1 kez):** baseline FAZ-0 (Mgmt API) geçici arızası iki kez
   `C1.baseline-restore FAIL` üretti (doğru davranış, reports/db-validation-b09bdbe7.md);
   ancak bir koşumda `timeout 900` baseline'i öldürdüğünde validator **exit 0 ve rapor
   YAZMADAN** sonlandı ("Terminated" + `DIAG3_EXIT=0`, rapor dosyası yok) — timeout-kill
   yolunda çıkış kodu kayboluyor, fail-open riski.

## Rapor sözleşmesi (SPEC §4) kontrolü [OBSERVED]

- SHA-256 raporda var ve `sha256sum` ile birebir doğrulandı
  (704aa0ff…, c48c6465…, d996b979… = dosya SHA'leri).
- Baseline bilgisi raporda var: tablo 53, fonksiyon 214, view 13, pgtap_fn 1085,
  baseline_kaynak=egesut_lsp, parite_dosya, prod_pg=17.6, yerel_pg=18.6.
- Data-mode koşulmadı notu: `> VERİ UYUŞUMLULUĞU DOĞRULANMADI` cümlesi raporlarda mevcut.

## İzole DB artığı kontrolü [OBSERVED]

```
psql … -c "SELECT datname FROM pg_database WHERE datname LIKE '%val%' OR datname LIKE '%pilot%'"
→ (0 satır)   # trap drop'ları çalıştı; elle yaratılan egesut_val_tmp elle drop edildi
```

## Pilot dosyaları

- `tests/db-validation/pilot/pozitif.sql` (sha256 704aa0ff…)
- `tests/db-validation/pilot/negatif-syntax.sql` (sha256 c48c6465…)
- `tests/db-validation/pilot/negatif-cakisma.sql` (sha256 d996b979…)

---

## Düzeltme turu 2 (root, 2026-09-24) — pilotun bulduğu 3 bug fix sonrası final sonuçlar

| Senaryo | Beklenen | Gözlenen | Exit |
|---|---|---|---|
| pozitif.sql | PASS ya da INCONCLUSIVE (parite uyumsuzsa) | INCONCLUSIVE — C1.ortam-paritesi: prod PG 17.6 ↔ yerel 18.6, ayna F=214 ↔ prod F=221 | **2** |
| negatif-syntax.sql | FAIL(1) | FAIL — A.sqlfluff-parse + C1 apply | **1** |
| negatif-cakisma.sql | FAIL(1) | FAIL — C1.migration-apply `relation "hayvanlar" already exists` | **1** |

Düzeltilen bug'lar:
1. `db-build-baseline.sh:130` jq `-n` eksikliği (stdin'de sonsuz kilitlenme) — root.
2. `db-validate.sh` parite anahtarı `parite_durumu`→`parite_durum` (yanlış-PASS kapandı).
3. C1 post-check'e pg_policies + pg_trigger sorguları eklendi (CREATE POLICY artık yanlış-FAIL üretmiyor).
4. Squawk politika: ERROR=FAIL, WARNING=INCONCLUSIVE-kayıt (masun migration düşmüyor, sessiz de geçilmiyor).
5. Rapor yazımı INT/TERM/HUP tuzağına bağlandı (fail-open kapatıldı).

Açık kalem (sahip): kapı mevcut ortamda PASS üretmez — parite uyumsuz (yerel PG 18.6 vs prod 17.6; ayna fonksiyon sayısı 214 vs prod 221 → refresh_lsp_schema.sh koşulmalı). PG major eşitlemesi (17.x yan yüklemesi) sahip kararidir.

---

## Final (2026-09-24, gece) — PG17 motoru + taze ayna ile KULLANIMA HAZIR

Ortam: izole motor = supabase/postgres:17.6.1.093 konteyneri (port 5433, VAL_DB_URL
.env'de) — prod ile birebir major; ayna taze (T=54 F=243 V=13 = canlı; refresh'e
uygulama-şemaları adımı eklendi: surum_gizli).

| Senaryo | Sonuç | Exit |
|---|---|---|
| pozitif.sql | **PASS** (parite uyumlu, A.squawk WARNING'leri raporda, hüküm vermez) | **0** |
| negatif-syntax.sql | FAIL | 1 |
| negatif-cakisma.sql | FAIL | 1 |

Kapı artık gerçek PASS üretir. squawk politikası: ERROR=FAIL, WARNING=rapor kaydı
(sahip düzeltmesi D: statik katman kesin hüküm vermez).
