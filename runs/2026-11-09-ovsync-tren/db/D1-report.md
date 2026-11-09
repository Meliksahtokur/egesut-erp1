⟦ss-sub model=opus effort=high rol=ss-worker-high iş=ovsync-tren D1: doğum sonrası PG görevlerini bayrak arkasına alıp d2/d25 hatırlatma RPC'si ve kabul betiğinin ilk sürümünü kur⟧
sonuc: KISMI
progress: iş kodu, testleri ve commit'i bitti (4a32f60). Açık kalan tek şey: brief'in db-validate Run komutu bu worktree'de birebir haliyle rc=1 veriyor (.env yok). Aynı script ana checkout'tan koşulunca PASS. Lead `.env` symlink'ini kurar ya da eşdeğer komutu kabul ederse sonuç TAMAM olur.
SORU: Brief'teki `bash scripts/db-validate.sh …` worktree'de `.env` olmadığı için rc=1 veriyor; bayt-eş ana checkout script'i rc=0 PASS · seçenekler: (a) lead `ln -s ~/egesut-erp1/.env ~/.herdr/worktrees/egesut-erp1/ovsync-tren/.env` (istatistik-ap2-plan worktree'sindeki emsal; `.env` gitignore'da) kurar, ben literal komutu yeniden koşarım · (b) D1–D8 Run'ı `bash ~/egesut-erp1/scripts/db-validate.sh <mutlak yol>` diye RL ile değiştirilir · önerim: (a) — D2–D8 de aynı engele takılacak.

## Gelen iş denetimi
- Bulgu 1 (MEASURED): Plan "ayar seed `ON CONFLICT (anahtar) DO NOTHING`" diyor, ama db-validate baseline'ında protokol_ayar PK'si yok → C1 apply `42P10 no unique or exclusion constraint matching the ON CONFLICT specification` ile düştü. Bunun yerine `INSERT … SELECT … WHERE NOT EXISTS` kullandım (20260925000002 emsali; anlamı aynı: satır varsa dokunulmaz). D2'deki dört seed de aynı engele takılacak.
- Bulgu 2 (MEASURED): `scripts/db-validate.sh` yalnız `SCRIPT_DIR/../.env` dosyasını okuyor, env değişkeniyle ezilemiyor. Worktree'de `.env` yok → yukarıdaki SORU. Ayrıca doğrulama motoru `egesut-val-pg17` konteyneri (5433) 3 gündür kapalıydı. `docker start egesut-val-pg17` ile açtım; bu yalnız yerel doğrulama motoru, prod/demo'ya dokunulmadı.
- Diğer: bulgu yok. Plan + ortak.md + govde-taban.md + domain-rules §5/§18 okundu; çelişki yok.

## Yapılan
- `~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql`
  - Dosya başında md5 koruması: `dogum_kaydet(text,date,text,text,text,numeric,text,text)` = `756c56afb83401721521e42e613ab7f9` (D0 prod), farklıysa `DOGUM_KAYDET_GOVDE_FARKLI`. CONFIRMED (db-validate baseline'ında ve kabul DB'sinde geçti)
  - Seed `dogum_sonrasi_pg_gorev_aktif` = 0, birim bool, 0..1, insert-eksikse.
  - `dogum_kaydet` = kanit/fn gövdesi + yalnız şu değişiklikler (diff MEASURED):
    - 3 PG satırı ('2. Gün PG', '39. Gün PG (Presynch-14 senkron)', '25. Gün PG') ayrı INSERT'e alındı ve `IF public._ayar('dogum_sonrasi_pg_gorev_aktif', 0) = 1` arkasına kondu. Yorumda "arşiv — sahip 2026-11-09" var; kod silinmedi.
    - Yeni değişken `v_pg_gorev`. `gorev_sayisi` artık açılan görevi sayıyor (ayrıntı aşağıda).
  - `public.dogum_sonrasi_pg_hatirlatma() RETURNS jsonb`, STABLE SECDEF, `search_path public, pg_temp`. Dönüş: `{ok, aktif, satirlar:[{hayvan_id, kupe_no, dogum_tarihi, gun}]}`.
    - `aktif` = ayar ≠ 1 (dogum_kaydet'teki `= 1` koşulunun tam tersi).
    - Kapsam: Aktif dişi; TR bugünü − son doğum ∈ {2, 25}; son doğum = annenin daha yeni doğumu olmayan doğumu. İkiz (aynı tarih) DISTINCT ile tek satır.
  - ACL: hatırlatma RPC ve dogum_kaydet için `REVOKE ALL … FROM PUBLIC, anon` + `GRANT EXECUTE … TO authenticated`.
- `~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/tests/ovsync_tren_kabul.sql`: kabul betiğinin ilk sürümü.
  - Yardımcılar: `kb_bugun/kb_ok/kb_id/kb_hayvan/kb_yerel` ve ek olarak `kb_ayar/kb_dogum_pg_sayi/kb_hatirlatma`.
  - Sayaç `CREATE TEMP SEQUENCE kb_gecti_seq`.
  - Her senaryo `SAVEPOINT kb_s / DO / ROLLBACK TO SAVEPOINT kb_s` üçlüsüyle; bayrak kurulumu senaryonun içinde (Kapı tur 2 eki).
  - Sonda `OZET: <currval> PASS`. Tarihler yalnız `kb_bugun()`; betikte CURRENT_DATE yok.
  - `\set QUIET on` var, böylece son satır OZET oluyor (ROLLBACK etiketi basılmıyor).
- `~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/tests/README.md`: `ovsync_tren_kabul.sql` bölümü eklendi (koşum komutu, seri dosyaları, sözleşme özeti). Mevcut metin korundu.

## Testler (6 id, 24 kb_ok)
- TR-F0-1 (5 kb_ok): bayrak 0 → annede 3 PG açıklamalı açık görev 0; Oksitosin/Ademin/Kalsiyum/E Vitamini 4 görev var; gorev_sayisi 12; ayar satırı var.
- TR-F0-2 (4 kb_ok): bayrak 1 → üç PG görevi doğru gün/etken/kaynakla açılıyor (+2/+25/+39); gorev_sayisi 15.
- TR-F0-3 (9 kb_ok), bayrak 0:
  - −2 doğum → gun 2; −25 doğum → gun 25 (dogum_tarihi ve kupe_no doğru); −3 doğum → satır yok.
  - Önceki doğum −25 + son doğum −2 → yalnız gun 2.
  - İkiz −25 → tek satır.
  - Aktif olmayan (Satıldı) anne → satır yok.
- TR-F0-4 (1 kb_ok): bayrak 1 → `aktif=false`, `satirlar=[]` (fixture'da −2 doğum olduğu halde).
- TR-IZOL-1 (2 kb_ok):
  - Senaryo (a) ayarı 1'e ve `app.ovsync_tren_ic`'i '1'e çekip içeride doğruluyor.
  - Senaryo (b) ayarı 0 ve GUC'u boş görüyor.
- TR-F0-ACL (4 kb_ok): hatırlatma RPC'si anon'a kapalı, authenticated'a açık; dogum_kaydet anon'a kapalı; ayar 0/0/1.
- Mutant denetimi (MEASURED, 11 mutant, hepsi öldü):
  - son-doğum filtresi kaldırıldı → TR-F0-3
  - Aktif filtresi kaldırıldı → TR-F0-3
  - DISTINCT kaldırıldı → TR-F0-3 (ikiz)
  - aktif tersine çevrildi → TR-F0-3
  - −3 pencereye eklendi → TR-F0-3
  - gorev_sayisi 8 sabitlendi → TR-F0-1
  - arşiv dalı `IF false` yapıldı → TR-F0-2
  - anon GRANT verildi → TR-F0-ACL
  - seed 1 yapıldı → TR-IZOL-1
  - `WHERE a.aktif` kaldırıldı → TR-F0-4
  - IZOL(a) savepoint'i ROLLBACK yerine RELEASE edildi → TR-IZOL-1

## Run kanıtı

Kırmızı (migration olmadan, test-önce), MEASURED:
```
( echo 'BEGIN;'; cat supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1
```
rc: 3
```
ERROR:  FAIL TR-F0-1: beklenen açık doğum PG görevi 0 gerçek 3
BAĞLAM:  PL/pgSQL function pg_temp_22.kb_ok(boolean,text,text,text) line 4 at RAISE
SQL statement "SELECT pg_temp.kb_ok(v_n = 0, 'TR-F0-1', 'açık doğum PG görevi 0', v_n::text)"
PL/pgSQL function inline_code_block line 9 at PERFORM
```

Ön koşul `cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash scripts/kabul-db/build.sh` → rc: 0, son satır `SONUÇ: TEMİZ — egesut_ovsync_kabul canlı public şemasıyla nesne-düzeyinde eş`.

1)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
```
rc: 0
```
NOTICE:  PASS TR-IZOL-1: savepoint geri sarımı ayar ve GUC'u sıfırlar
NOTICE:  PASS TR-F0-ACL: anon kapalı, authenticated açık
NOTICE:  OZET: 24 PASS
```

2) Brief'teki birebir komut:
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash scripts/db-validate.sh supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql
```
rc: 1
```
scripts/db-validate.sh: line 86: LOCAL_LSP_URL: LOCAL_LSP_URL missing — .env dosyasını kontrol et (egesut_lsp şema aynası bağlantısı)
```
Eşdeğer komut. Ana checkout script'i `diff <(git show HEAD:scripts/db-validate.sh) ~/egesut-erp1/scripts/db-validate.sh` sonucuna göre AYNI:
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql
```
rc: 0
```
════════════════════════════════════════════════
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-725fb9c8.md
 İzole DB'ler drop edildi: egesut_val_1904048_706bf388 egesut_val_1904048_e71912a4
════════════════════════════════════════════════
```
Raporda A.sqlfluff, A.squawk, B, C1 (restore/apply/postcheck/rls/parite) ve C2 (tohum/veri) hepsi PASS. Raporun notu: "ayna bayat olabilir: yerel T=55 F=267, prod T=60 F=304" (OBSERVED). Buna rağmen md5 koruması baseline'da geçti, yani dogum_kaydet gövdesi aynada da prod ile eşit (INFERRED).

3)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql
```
rc: 0
```
(çıktı yok)
```

## Kabul
- OZET 24 PASS; n ≥ 6; 6 test id'sinin her biri ≥1 kb_ok. MEASURED
- db-validate PASS: yalnız eşdeğer komutla MEASURED; brief'in literal komutu rc=1 (SORU).
- CURRENT_DATE grep boş. MEASURED
- md5 koruması dosya başında; PG kodu duruyor, bayrak arkasında, yorumu "arşiv — sahip 2026-11-09". CONFIRMED (diff)
- Commit `4a32f60` "ovsync-tren L-DB D1: doğum sonrası PG → hatırlatma (Faz 0)". 3 dosya, dosya dosya `git add`; `git diff --cached --stat` = yalnız bu 3 dosya (499 ekleme). Push yok. MEASURED

BOYUT: bütçe 120 · gerçek 224 · migration dosyasının tamamı. Bunun 160 satırı dogum_kaydet gövde kopyası (prod gövdesi 151 satır, değişen yaklaşık 15). Brief'in ~120 tahmini 151 satırlık gövde kopyasını sığdıramıyor. Yeni mantık yaklaşık 40 satır (seed + hatırlatma RPC + ACL + md5 koruması).
Commit SHA: 4a32f60

## Kırıntılar
- gate env-mismatch (id 8b9c89980c2e): worktree'de .env yok, db-validate literal komutu rc=1; eşdeğer PASS; egesut-val-pg17 başlatıldı.
- assumption (c0dc740db958): seed ON CONFLICT yerine WHERE NOT EXISTS (db-validate baseline'ında PK yok).
- assumption (91a62e6283a1): `gorev_sayisi` bayrak 0'da 12 olacak şekilde düzeltildi. forms.js:252 toast'ta "N görev oluşturuldu" diye gösteriyor; düzeltilmeseydi açılmayan 3 görevi de sayardı (sessiz yanlış). Planın "yalnız PG satırları" kapsamının dışında, T2 review kabul etmeli.
- measurement (a20a9b0ae6d2): OZET 24 PASS, 11 mutant öldü, commit 4a32f60.
- open_item: domain-rules §5 madde 6 hâlâ "uygulama bekliyor / yeni doğumlar PG görevi açmaya devam eder" diyor. D1'den sonra bu belge kayması (doc-drift) oluyor; düzeltmesi N5 L-DOC (DC1) kapsamında, benim yazılabilir listemde değil.
- open_item: D2 seed'leri (`ovsync_tren_*`) için de ON CONFLICT yerine insert-eksikse kalıbı gerekecek (Bulgu 1).
- Not: gitnexus analyze koşulmadı (ortak.md: lead kulvar sonunda koşar).
