# DC1 — N5 belgeler: domain-rules / rpc-reference / ui-map (Ovsync treni)
job_id: j-20261109T160417Z-7bc080

report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/doc/DC1-report.md

## Plan maddesi
PLAN N5 DC1 (~/.herdr/worktrees/egesut-erp1/ovsync-tren/docs/plans/2026-11-09-ovsync-tren/PLAN.md :554-565) birebir + aşağıdaki root ekleri.
Worktree: ~/.herdr/worktrees/egesut-erp1/ovsync-tren (dal ovsync-tren). Kaynaklar (otorite sırası: migration gövdesi > kayıtlar > plan):
- Spec: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/docs/plans/2026-11-09-ovsync-tren/design.md (K1–K11, §9 domain-rules metni)
- PLAN R1–R20 (:88-116), Kapı tur 2 ekleri (:645)
- SQL: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001..008_*.sql
- L-DB kayıtları: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/ (L-DB-DONE.md, progress.md RL-1..RL-18 + RD9-1..6, D9-report.md)
- Veri sözleşmesi (RPC imza/dönüş/hata kodları, dosya:satırlı): ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/UB-sozlesme-report.md
- UI kayıtları: aynı ui/ klasörü N4-brief.md, N4-F1-brief.md, N4-F2-brief.md (ROOT RULING'ler), N4-F2-report.md

## İş
1. domain-rules.md — PLAN DC1 maddeleri (§5.6, §18.2, §18.3, §18.10, §18.15, §18.18, §18.19) + root ekleri:
   - §18.18/K8: bağımsızlık kalıcı işaret `cases.ovsync_bagimsiz` (D9): bayrak açıkken etiketi NULL kalan vaka (bağımsız seçimi, tren dışı D0, hastalık günü) işaretlenir; işaretli vaka hiçbir yoldan (çapa değişimi, yeniden hedefleme dahil) trene girmez; bayrak kapalıyken açılan eski vaka işaretsizdir ve açılışta R14 ile trene bağlanabilir.
   - Toptan erteleme: yalnız bugünden itibaren üyesi olan ilk ritim gününde (RL-16, `ONCEKI_TREN_VAR`); ileri D0'lı aşama 0 vakalar da N gün kayar (RL-14); aşama 2 üyesi PG48/BASTAN seçimi ister; aşama belirsiz üye düşer (onay kapalı).
   - Mevcut §'lerin numarası/başlığı korunur; yalnız ilgili maddeler güncellenir/eklenir; çelişen eski cümle kalmaz (aynı konuda iki kural YASAK).
2. rpc-reference.md — PLAN'daki 10 yeni RPC + 3 imza değişikliği; her biri için gerçek imza (migration dosyası:satır), dönüş jsonb alanları, hata kodları + payload alanları, yazdığı tablolar; `ovsync_bastan_baslat`'ın 4. parametresi `p_hedef` (RL-15), `ovsync_tren_yeniden_hedefle` dönüşünde `belirsiz_asama`/`belirsiz_sayisi` (R6-EK). Kaynak: sözleşme raporu + gövde; uydurma alan YASAK.
3. ui-map.md — `js/ovsync-tren.js` modülü; Ovsync ekranı tren başlıkları + bağımsızlar bloğu + "Tren gününü ertele…" (yalnız ilk başlık) + toptan modal + tren ayarı paneli; K8 "Trene bin" modalı ve 7 giriş yolu (V2–V6, G7, G9); görevler ekranı "Ovsync ekranında düzenle →"; vaka kartı kaydır aşama dalları; K11 geç tamamlama sheet'i; 🔔 doğum PG hatırlatma. Her satırda fonksiyon adı + dosya (satır no YAZMA; kayar).

## Model
sonnet (ss-worker)

## Boyut bütçesi
Toplam ≤ +350 satır net (3 dosya).

## Yazılabilir dosyalar
~/.herdr/worktrees/egesut-erp1/ovsync-tren/.harness/references/domain-rules.md
~/.herdr/worktrees/egesut-erp1/ovsync-tren/.harness/references/rpc-reference.md
~/.herdr/worktrees/egesut-erp1/ovsync-tren/.harness/references/ui-map.md
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/doc/DC1-report.md

## Run
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && NODE_PATH=~/egesut-erp1/node_modules node --test tests/unit/domain-rules-karar7.test.js 2>&1 | tail -5
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && git diff --stat HEAD~1 HEAD

## Kabul
- Run 1 `fail 0`. Commit yalnız 3 belge dosyası (+ report ayrı commit olabilir); mesaj `ovsync-tren N5 DC1: domain-rules/rpc-reference/ui-map`; `git add` dosya dosya, push YOK.
- Report'ta: değişen/eklenen her § listesi; rpc-reference'a giren her RPC için kaynak migration dosya:satır; çözemediğin çelişki → `SORU:` + `sonuc: KISMI`.

## Review: T1

## Önceden cevaplanmış kararlar
- Sahip kararları: design.md "## Kararlar" tablosu ve K1–K11 bağlayıcı (doğum sonrası PG artık zorunlu değil → hatırlatma; hastalık günü → bağımsız; haftalık tren, ≤2 gün öne çekme, toptan erteleme).
- Kod/SQL DEĞİŞTİRME. Test komutu kancaya takılırsa betiği `$HOME/tmp/dc1/` altına yaz, `ram-ultracode exec --class test --wait 600 -- bash <betik>`. `/tmp` yasak.
