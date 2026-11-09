# UB-sozlesme — N4 UI brief'i öncesi veri sözleşmesi + test tabanı (salt-okuma ölçüm, tek rapor)
job_id: j-20261109T123605Z-6fb328

report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/UB-sozlesme-report.md

## Plan maddesi
PLAN N4 (UB1–UB5) Muse brief'ini dağıtmadan önce root kontrol listesi madde 1-3 (veri sözleşmesi, tanımlar, bayat test).
Worktree: ~/.herdr/worktrees/egesut-erp1/ovsync-tren (dal ovsync-tren). Kod DEĞİŞTİRME, commit ATMA.

Kaynaklar:
- PLAN: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/docs/plans/2026-11-09-ovsync-tren/PLAN.md (N4 :476-551, R1-R20 :88-116, Kapı tur 2 ekleri :645)
- Spec: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/docs/plans/2026-11-09-ovsync-tren/design.md
- Mockup'lar (sahip onaylı): ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/mockup/
- UA1 modülü + rapor: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/js/ovsync-tren.js, ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/UA1-report.md
- Ekler: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/UB-ekler.md
- RPC gövdeleri (otorite): ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001..008_*.sql; L-DB kayıtları ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/ (L-DB-DONE.md, D4/D6/D7/D8-report.md, progress.md RL-*)

## İstenen (report bölümleri)
1. `## Sözleşme tablosu` — her mockup ekranı için her görünen bilgi/düğme → kaynak (RPC adı + jsonb alan yolu, ya da UA1 fonksiyonu) → gövdede tanımlandığı `dosya:satır`. Kaynağı OLMAYAN bilgi `BOŞLUK` işaretli ayrı listede. Ayrıca `ovsync_tren_listele`, `ovsync_tren_onizle`, `ovsync_tren_ertele_onizle`, `ovsync_tren_ertele`, `ovsync_hayvan_ertele`, `ovsync_pg48_tohumla`, `ovsync_bastan_baslat`, `ovsync_tren_yeniden_hedefle`, `ovsync_tren_ayar_guncelle`, `dogum_sonrasi_pg_hatirlatma`, `start_first_service_protocol`, `seans_tamamla` (ovsync_uyari) için imza + dönüş jsonb şeması (alan adları, tip, null olabilir mi) + hata kodları (`OVSYNC_*` RAISE metinleri, payload alanları) — gövdeden, dosya:satır ile.
2. `## Tanımlar` — UI'ın göstereceği durumlar ve kenar halleri gövdeden: aşama 0/1/2/belirsiz (NULL), gecikmiş, ritim dışı (ritim_disi_neden değerleri), bağımsız, ileri (ileri_vakalar/ileri_sayisi), üye sayısı (sorulan hayvan hariç mi), "yapıldı" (kısmi tren günü). Her biri: tanım + kaynak satırı + UI'da hangi metin/düğme.
3. `## UA1 ile fark` — UA1 fonksiyonlarının beklediği alanlarla gerçek RPC alanları arasındaki ad/şekil uyuşmazlıkları (UB-ekler #4, L-DB-DONE açık kalem 3 dahil). Var/yok + dosya:satır.
4. `## Test tabanı` — aşağıdaki Run komutunu koş; fail eden HER test adı + dosya:satır + kısa neden; hangileri main'de de kırmızı (bilinen: LUNA-3 demo haritasız 8 kolon, EG-7/EG-8, vaka-toplu-ac ay ‹/›), hangisi N4'te bayatlayacak (ör. tests/unit/ileri-gebe-duve-siralama.test.js:209 `?v=` sayısını sabitliyor — UB5 cache-bust ve yeni script etiketiyle değişir). `node scripts/etiket-tazelik.mjs` rc.
5. `## Toast/XSS ölçümü` — `toast()` innerHTML mı textContent mi (dosya:satır) — UB-ekler #1.
Kanıt etiketi her satırda (CONFIRMED dosya:satır / OBSERVED komut).

## Model
sonnet (ss-worker) — token-ağır okuma.

## Yazılabilir dosyalar
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/UB-sozlesme-report.md

## Run
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && NODE_PATH=~/egesut-erp1/node_modules node --test tests/unit/*.test.js 2>&1 | tail -40
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && node scripts/etiket-tazelik.mjs; echo rc=$?

## Review: T0

## Önceden cevaplanmış kararlar
- Bu iş salt-okuma; kod/test düzeltme önerisi yazabilirsin ama uygulama.
- Keşifte önce atlas (`atlas-sorgu <ara|tanim|fn|rpc|etki> <arg>` cwd worktree; MCP `mcp__tools-bank__atlas_query`), sonra grep.
- `/tmp` yasak; geçici `$HOME/tmp/ovsync-tren-ui/`.
