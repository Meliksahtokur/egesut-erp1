# D9 — Bağımsız vaka işareti (`cases.ovsync_bagimsiz`)
job_id: j-20261109T123459Z-0899d7

report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D9-report.md

## Plan maddesi
L-DB-DONE açık kalem 2 (~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/L-DB-DONE.md:68).
Sorun (CONFIRMED, D8-report.md:160 TR-GOC-6 ilk FAIL): `cases.ovsync_tren IS NULL` hem "eski (bayrak öncesi)" hem
"bağımsız (K8/K9)" demek. Bayrak açıkken çapa değişince ya da doğrudan `ovsync_tren_yeniden_hedefle(false)` çağrılınca
R14 üyelik yazımı (008:74, :96-98) D0'ı yeni ritme düşen bağımsız vakayı trene bağlar. Sahip K8: "Bağımsız hayvan trene
sayılmaz"; K9: "hastalık günü girilirse hasta bağımsız devam eder" → bağımsız vaka hiçbir yoldan trene bağlanmamalı.

Ortak kurallar: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/ortak.md (bağlayıcı).
Domain: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/.harness/references/domain-rules.md §18 (K8/K9 karşılıkları).

## İş (root ruling'leri — progress.md "D9" satırları)
- **RD9-1 DDL:** `ALTER TABLE public.cases ADD COLUMN IF NOT EXISTS ovsync_bagimsiz boolean NOT NULL DEFAULT false;`
  PLAN "Tek DDL" kuralı root ruling'iyle iki kolona genişler (spec yalnız "yeni tablo yok" der; değişmez).
- **RD9-2 YERİNDE DÜZENLEME:** Seri (001..008) henüz hiçbir DB'ye uygulanmadı (demo/prod yazılmadı). Yeni migration
  dosyası AÇMA, gövde kopyalama YOK: DDL'i `20261110100002_ovsync_tren_cekirdek.sql:29`'un hemen altına ekle; etiket
  yazan noktaları kendi dosyalarında yerinde düzelt. Mevcut md5 korumaları (prod gövde tabanına karşı) aynen kalır.
- **RD9-3 Değişmez (invariant):** bayrak açıkken başlatılan/etiketlenen her aktif OVSYNC vakada
  `ovsync_tren IS NULL ⇔ ovsync_bagimsiz = true`. Yazma noktaları (en az; hepsini grep'le bul ve report'ta listele):
  (a) başlatma yolları (004, ör. :470 civarı ve `tedavi_sablon_uygula`/`vaka_toplu_ac` etiket yazımı): bayrak açık +
  OVSYNC + etiket NULL kalıyorsa (bağımsız seçimi ya da D0 tren günü değil) → `ovsync_bagimsiz = true`; R4 gereği
  bugün tren günüyse `p_bagimsiz=>true` bile trene biner → false kalır.
  (b) K9 `ovsync_hastalik_gunu_ekle` (005:711): `ovsync_tren = NULL` ile aynı UPDATE'te `ovsync_bagimsiz = true`.
  (c) `ovsync_bastan_baslat(p_bagimsiz=>true)` — yeni vaka (a) yolundan geçiyorsa ek iş yok; geçmiyorsa aynı kural.
  Bayrak kapalıyken açılan vaka `false` kalır (eski) → açılışta R14 onu bağlayabilir (mevcut davranış korunur).
  `true` olan işaret hiçbir yolda `false`'a dönmez; tek hayvan ertelemesi (005:396) işarete dokunmaz.
- **RD9-4 Üyelik dışlaması:** R14 üyelik kümesi (008:74 seçimi ve :96-98 UPDATE) `AND NOT c.ovsync_bagimsiz` alır.
  007:115 ve 007:234-239'u oku: üyelik/bağımsız sayımı amacıyla NULL kullanıyorsa davranışı RD9-3 ile tutarlı kıl,
  yalnız sayım/listeleme ise DOKUNMA (UI sözleşmesi: `bagimsizlar` bloğu NULL etiketten gelir, değişmez).
- **RD9-5 RL-18 kalır** (göç yalnız açılış/çapa değişiminde); D9 çapa değişimini de güvenli kılar.
- **RD9-6 RPC imzaları ve dönüş alanları DEĞİŞMEZ** (N4 UI sözleşmesi donuk). Yeni RPC yok.
- `geri-al.sql`: `ALTER TABLE public.cases DROP COLUMN IF EXISTS ovsync_bagimsiz;` ekle; prova sonrası kolon yok assert'i.

Testler (`supabase/tests/ovsync_tren_kabul.sql`'e yeni bölüm, mevcutları bozma):
- `TR-BAG-1` açıkken bugün≠tren `start_first_service_protocol(.., p_bagimsiz=>true)` → `ovsync_tren` NULL, `ovsync_bagimsiz` true.
- `TR-BAG-2` aynı vaka, çapayı vakanın D0'ı yeni ritme düşecek şekilde değiştir (`ovsync_tren_ayar_guncelle(true, yeni_capa)`) → NULL + true kalır; doğrudan `ovsync_tren_yeniden_hedefle(false)` sonrası da NULL.
- `TR-BAG-3` K9: hastalık günü eklenen vaka → NULL + true; çapa değişimi sonrası NULL kalır.
- `TR-BAG-4` eski vaka (bayrak kapalıyken açılmış, D0 yeni ritimde) → açılışta trene bağlanır (regresyon), işaret false.
- `TR-BAG-5` bugün tren günü + `p_bagimsiz=>true` → trende, işaret false (R4).
- `TR-BAG-6` V3 yolu: açıkken `tedavi_sablon_uygula` tren olmayan D0 → NULL + true.
- `TR-GOC-6` mevcut haliyle PASS.
Akış: testleri yaz → koş → FAIL ham çıktısı report'a → uygula → seri tam PASS → pgk seri (487 PASS, Bölüm 1 33 değişmez)
→ db-validate (değişen her dosya, kendinden önceki seri `--priors`) → geri alma provası → commit.

## Model
opus / high (ss-worker-high) — fail-closed üyelik kuralı, çekirdek DB (Muse istisnası: kritik çekirdek kod).

## Boyut bütçesi
Üretim SQL ≤ 40 satır net ekleme (DDL + yerinde düzeltmeler). Aşım = `BOYUT:` gerekçesi.

## Yazılabilir dosyalar
~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql
~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql
~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100005_ovsync_tren_kilit.sql
~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100006_ovsync_tren_asama.sql
~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100007_ovsync_tren_toptan.sql
~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100008_ovsync_tren_ayar_goc.sql
~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/tests/ovsync_tren_kabul.sql
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/geri-al.sql
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D9-report.md

## Kabul
- Seri koşumu son satırı `NOTICE:  OZET: <n> PASS` (n > 546); TR-BAG-1..6 ve TR-GOC-6 her biri `kb_ok` ile koşuyor (report'ta id → PASS listesi).
- pgk seri koşumu 487 PASS, Bölüm 1 33 (değişmedi).
- db-validate exit 0 (değişen her migration dosyası).
- `grep -n CURRENT_DATE supabase/migrations/2026111010000*.sql` boş.
- Geri alma provası: 16 fonksiyon md5 = D0 tablosu, `cases.ovsync_tren` ve `cases.ovsync_bagimsiz` yok.
- Report'ta: `ovsync_tren` yazan tüm noktaların listesi (dosya:satır) ve her birinde işaretin nasıl ele alındığı.
- Commit dosya dosya; mesaj `ovsync-tren L-DB D9: bagimsiz vaka isareti (cases.ovsync_bagimsiz)`.

## Run
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/migrations/20261110100004_ovsync_tren_baslatma.sql supabase/migrations/20261110100005_ovsync_tren_kilit.sql supabase/migrations/20261110100006_ovsync_tren_asama.sql supabase/migrations/20261110100007_ovsync_tren_toptan.sql supabase/migrations/20261110100008_ovsync_tren_ayar_goc.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/migrations/20261110100004_ovsync_tren_baslatma.sql supabase/migrations/20261110100005_ovsync_tren_kilit.sql supabase/migrations/20261110100006_ovsync_tren_asama.sql supabase/migrations/20261110100007_ovsync_tren_toptan.sql supabase/migrations/20261110100008_ovsync_tren_ayar_goc.sql supabase/tests/ovsync_pg_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100008_ovsync_tren_ayar_goc.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100005_ovsync_tren_kilit.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100006_ovsync_tren_asama.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100007_ovsync_tren_toptan.sql
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql

## Bağımlı
D8 (b69a195)

## Review: T2

## Önceden cevaplanmış kararlar
- Sahip K8 (design.md:90): "Bağımsız hayvan trene sayılmaz". Sahip K9 (design.md:91, birebir): "hastalık günü girilirse hasta bağımsız devam eder".
- PLAN R3/R4/R7/R14, progress.md RL-1..RL-18 bağlayıcı; RD9-1..6 (yukarıda) root ruling'i — ikinci DDL ve yerinde düzenleme onaylı.
- RL-9: build.sh KOŞMA, kabul DB'si hazır. Push yok. `js/`, `index.html`, `runs/2026-11-09-ovsync-tren/mockup/**`, `runs/2026-11-09-ovsync-tren/ui/**` DOKUNMA.
- Plan boşluğunda kendi kararını report'ta `Varsayım:` olarak gerekçele; spec'i değiştiren bir şey görürsen DUR, `SORU:` + `sonuc: KISMI`.
- Review: tek T2 tur. DÜZELT gelirse düzelt + Run kanıtıyla kapanır (yeni review turu yok). Yalın çalış.
