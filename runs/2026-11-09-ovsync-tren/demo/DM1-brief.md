# DM1 — Demo DB uygulaması + bayrak-0 regresyonu + gerçek demo e2e + zaman senaryosu (DB)
job_id: j-20261109T160538Z-2e9ee7

report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/demo/DM1-report.md

## Plan maddesi
PLAN N6 DM1 (~/.herdr/worktrees/egesut-erp1/ovsync-tren/docs/plans/2026-11-09-ovsync-tren/PLAN.md :569-584) birebir + root ekleri. Goal izni: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/.harness/goals/2026/G-20261109-OVSYNC-TREN.md:50 (demo yazma izinli; prod YASAK).
Worktree: ~/.herdr/worktrees/egesut-erp1/ovsync-tren (dal ovsync-tren). Ortak SQL kuralları: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/ortak.md. Runbook: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/.harness/runbooks/db-migration.md.
Ekler (BAĞLAYICI): ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/UB-ekler.md "DM1 (N6) eki" ve "N6 eki — ZAMAN SENARYOSU" madde 1.

## İş (sırayla)
1. Demo durumu: ref `vtzqjmazsvurxdeondmi` (bunun dışındaki her ref — prod dahil — YASAK; `.env`'deki prod ref değişkenini hiçbir çağrıda kullanma). INACTIVE ise `~/egesut-erp1/.env` `SUPABASE_DEMO_PAT` ile Management API `POST /v1/projects/<demo ref>/restore`, sormadan; ACTIVE_HEALTHY bekle.
2. TABAN (seri uygulanmadan): main kodu (`~/egesut-erp1`, b9542b1) ile `tests/e2e/ovsync-takip.spec.js` demo'da → PASS/FAIL kümesi `demo/e2e-taban-main.txt`. Komut: spec başlığındaki docker satırı (`tests/e2e/ovsync-takip.spec.js:31` civarı).
3. Uygulama: seri 001..008 (D9 yerinde düzenlenmiş hali, uç 47e843a+) demo'ya TEK transaction Management API ile; D0 md5 korumaları demo'da eşleşmeli (eşleşmezse DUR, `<FN>_GOVDE_FARKLI` ham çıktısıyla SORU); `supabase_migrations.schema_migrations`'a 8 satır; `SELECT public.demo_sema_diff()` çıktısı rapora (cases.ovsync_tren + cases.ovsync_bagimsiz demo tarafında fazla — beklenen). Uygulama öncesi demo'da ilgili 16 fonksiyon gövdesi + protokol_ayar satırları dosyaya yedek: `demo/oncesi-yedek.sql` (geri dönüş için; geri-al.sql ile birlikte).
4. anon EXECUTE (UB-ekler DM1 eki): yeni/değişen TÜM imzalar için `has_function_privilege('anon','<imza>','EXECUTE')` = false, `authenticated` dışa açık RPC'lerde true, iç yardımcılarda false → tablo `demo/acl-olcum.md`. Sapma = DUR, SORU.
5. Bayrak kapalı regresyon: bayrak 0 iken dal kodu (worktree, yerel sunucu) ile `ovsync-takip.spec.js` → küme `demo/e2e-regresyon-bayrak0.txt`, adım 2 kümesiyle birebir (fark → assert adıyla rapora, DUR).
6. Bayrak aç: `ovsync_tren_ayar_guncelle(true, <bu haftanın Perşembesi>)` (demo klonu protokol_ayar'ı prod'dan ezebilir; açılış dönüşündeki `yeniden_hedef`/`belirsiz_asama` rapora).
7. `tests/e2e/ovsync-tren.spec.js` (stub yok; `ovsync-takip.spec.js` kalıbı; `E2E-TREN-PW-` işaretli seed, afterAll temizlik): PLAN :577-581 on test birebir adlarıyla. Koşum çıktısı `demo/e2e-cikti.txt` → hepsi PASS. FAIL'in kökü UI kodundaysa (js/) DÜZELTME — dosya:satır + beklenen/görülen ile rapora `BULGU:` yaz (UI kodu bu brief'in yazılabilirinde yok).
8. ZAMAN SENARYOSU DB (UB-ekler N6 eki madde 1): yeni dosya `supabase/tests/ovsync_tren_zaman_senaryosu.sql`, yerel kabul DB'sinde (`egesut_ovsync_kabul`, BEGIN/ROLLBACK, `pg_temp.kb_bugun()` ilerletme kalıbı mevcut kabul betiğinden), 3 haftalık olay dizisi; her adımda `ovsync_tren_listele` üyeleri/aşamaları, açık görev hedef tarihleri, `ovsync_tren`/`ovsync_bagimsiz` beklenen tabloyla `kb_ok` assert'leri. Beklenen değerler PLAN R1–R20 + design.md K1–K11'den çıkarılır, her assert yanında kural kimliği (`-- R7`, `-- K9` …). Kural çıkmayan adım → SORU. Koşum: seri + kabul betiği yardımcıları + bu dosya, `OZET n PASS`.
9. LUNA-3 haritası: `tests/unit/support/degisiklikler-kapsam-kolonlari.json`'a yalnız `cases.ovsync_tren` ve `cases.ovsync_bagimsiz` (dosyanın mevcut biçimiyle; etiket anlamı: tren üyeliği / bağımsız işareti). Taban 8 haritasız kolon KAPSAM DIŞI. LUNA-3 koşumunda yeni 2 kolonun listede olmadığını göster.

## Model
opus / high (ss-worker-high) — KRİTİK-ÇEKİRDEK: canlı demo DB uygulaması + gerçek e2e.

## Boyut bütçesi
e2e spec ≤ 450 satır; zaman senaryosu SQL ≤ 350 satır; üretim kodu 0.

## Yazılabilir dosyalar
~/.herdr/worktrees/egesut-erp1/ovsync-tren/tests/e2e/ovsync-tren.spec.js
~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/tests/ovsync_tren_zaman_senaryosu.sql
~/.herdr/worktrees/egesut-erp1/ovsync-tren/tests/unit/support/degisiklikler-kapsam-kolonlari.json
~/.herdr/worktrees/egesut-erp1/ovsync-tren/js/degisiklikler/etiketler.js
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/demo

## Run
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/migrations/20261110100004_ovsync_tren_baslatma.sql supabase/migrations/20261110100005_ovsync_tren_kilit.sql supabase/migrations/20261110100006_ovsync_tren_asama.sql supabase/migrations/20261110100007_ovsync_tren_toptan.sql supabase/migrations/20261110100008_ovsync_tren_ayar_goc.sql supabase/tests/ovsync_tren_zaman_senaryosu.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && cat runs/2026-11-09-ovsync-tren/demo/e2e-cikti.txt | tail -15
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && diff <(sort runs/2026-11-09-ovsync-tren/demo/e2e-taban-main.txt) <(sort runs/2026-11-09-ovsync-tren/demo/e2e-regresyon-bayrak0.txt) && echo REGRESYON-AYNI

## Kabul
- Adım 3: demo'da 8 schema_migrations satırı + md5 korumaları geçti (ham API yanıtı rapora).
- Adım 4: acl-olcum.md'de sapma yok.
- Adım 5: Run 3 `REGRESYON-AYNI`.
- Adım 7: on e2e testin hepsi PASS (ham çıktı); FAIL varsa `BULGU:` + `sonuc: KISMI`.
- Adım 8: `OZET n PASS`, her assert kural kimlikli.
- Commit dosya dosya, mesaj `ovsync-tren N6 DM1: <özet>`; push YOK. Report'a `## Run kanıtı` (komut + rc + son ≤30 satır) ve demo'ya yazılan her şeyin listesi (geri dönüş için).

## Review: T2

## Önceden cevaplanmış kararlar
- Demo yazma izinli (goal:50); prod yazma/okuma bu işte YOK (prod okuma bile gerekmez). Demo sahip şifresine dokunma (betik ezerse geri yükle).
- Eşzamanlı yazıcı: aynı worktree'de N5 doc kulvarı `.harness/references/*.md` yazıp commit atıyor — ona dokunma; `index.lock` çakışmasında birkaç saniye bekleyip yeniden dene.
- `/tmp` yasak; geçici `$HOME/tmp/dm1/`. Test koşumu kancaya takılırsa `ram-ultracode exec --class test --wait 1800 -- bash <betik>`.
- Playwright bir kez yeter: belgelenmiş koşumu tekrar koşma; FAIL düzeltmesi sonrası yalnız FAIL testleri.
- Web/GBM gerekmez (GBM kullanacaksan önce Skill("gbm")).

## Devam (root, 2026-11-09 — taze worker; önceki report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/demo/DM1-report.md, commit 5c9a05a)
Durum (CONFIRMED önceki report): adım 1–5 ve 8 TAMAM — seri demoda (16/16 md5, schema_migrations 8, ACL 40/40), zaman senaryosu OZET 45 PASS; bayrak KAPALI; `tests/e2e/ovsync-tren.spec.js` yazıldı, commitsiz, koşulmadı.
ROOT RULING:
- SORU-1 → (a): Y-CIFT-TIK main tabanında FAIL, dalda PASS, main tek başına tekrar PASS (report :156) → kararsız test, regresyon DEĞİL (PASS→FAIL dönen yok). Adım 6'ya devam. Kırıntı `assumption`.
- SORU-2 → (a): Yazılabilire eklendi: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/js/degisiklikler/etiketler.js — YALNIZ `cases` bloğuna `ovsync_tren: 'Tren üyeliği', ovsync_bagimsiz: 'Bağımsız işareti'` (tek satır) + JSON'a 2 kolon. Birim suit yine taban dördü dışında fail 0 (LUNA-3 canlı koşumda yeni 2 kolon listede yok).
Yapılacak: adım 6 (bayrak aç, `~/tmp/dm1/js/ayar.mjs 2026-11-12` ya da eşdeğeri; dönüş rapora) → adım 7 (spec'i gözden geçir, koş; FAIL kökü js/ ise BULGU, düzeltme yok) → adım 9 → commit (spec, json, etiketler.js dosya dosya) → DM1-report.md'ye `## Devam turu` bölümü (Run kanıtı dahil). Adım 1–5, 8'i TEKRARLAMA.
