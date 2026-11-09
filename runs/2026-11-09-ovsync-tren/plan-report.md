⟦ss-sub model=opus effort=high rol=ss-mimar iş=Sahip onaylı Ovsync treni spec'inden uygulama planı yaz⟧
sonuc: TAMAM

job_id: j-20261109T073651Z-b3f710

## Teslim
- Plan: `~/.herdr/worktrees/egesut-erp1/ovsync-tren/docs/plans/2026-11-09-ovsync-tren/PLAN.md` (615 satır)
- Commit: `3fe0cdd` (dal `ovsync-tren`, yalnız PLAN.md, `git add -f`). Push yok.
- Görev sayısı: **25** — N0 (1), L-DB D0–D8 (9), L-MOCK M1 (1), L-UI-A UA1 (1), L-UI-B UB1–UB5 (5), L-DOC DC1 (1), L-DEMO DM1–DM2 (2), L-PROD P1–P11 (runbook, 1 düğüm; 11 adım), + 3 kapı (G-MOCK, G-UI, G-SAHIP).
- Migration serisi: `20261110100001`…`20261110100008` (8 dosya; çakışma ölçüldü: repo son `20261031200007`, açık dallarda en büyük `20261106000001` — MEASURED).

## Ruling listesi (R1–R17, gerekçeler planda)
R1 çapa YYYYMMDD numeric · R2 migration adları · R3 tren üyeliği `cases.ovsync_tren date` kolonu · R4 tren günü = bugün ise K8 tek seçenek, üyelik D0 tarihinden · R5 K10 kilidi + `app.ovsync_tren_ic` iç bypass · R6 aşama türetimi (gün#1/gün#2, belirsiz → NULL) · R7 toptan erteleme kümesi (X görevleri, `ovsync_tren` X ve X−7) · R8 görev doğumu tren−2 + `p_hemen` · R9 yeniden hedef formülü `GREATEST(kural, eski_hedef)` · R10 ACIK-DISI anahtarı + son tohumlama id, G7 fail-closed · R11 RPC adları · R12 PG1+48 (a) yolu · R13 K11 olay anı now() + uyarı · R14 ayar değişikliği yeniden hedefler + advisory lock · R15 hatırlatma günleri · R16 liste ufku 28 gün · R17 mockup statik HTML→PNG.

## Açık sahip soruları
Yok. R3/R4/R7/R10 spec'i değiştirmez, yorumlar (INFERRED); kapı review'u itiraz ederse root üzerinden ruling sorusu olur.

## Bulgular
- R10 anahtar değişikliği bayraktan bağımsızdır: apply'dan sonraki ilk cron, eski anahtar çakışmasıyla takılı hayvanlara görev doğurur (kanit/fn/_acik_disi_gorev_kur.sql:33-35 + _ovsync_baslat_gorev_kur.sql:50-56; CONFIRMED kod, etki INFERRED). Prod P1(c) listesi sahibe gidecek şekilde planlandı.
- K10 kilidi düz uygulanırsa `vaka_kalan_gunleri_kaydir` → `tohumlama_gorev_ertele` ve `ovsync_hastalik_gunu_ekle` → `tohumlama_gorev_ertele` iç zincirleri kırılır (CONFIRMED kanit/fn). R5 iç GUC bypass'ı bu yüzden zorunlu.
- Brief'teki `scripts/backup-local-state` egesut'ta yok (tools-bank aracı; OBSERVED). Yedek = git tag + runbook adım 2 satır yedeği.
- Tazelik: atlas ve gitnexus indeksi `b9542b1` (main); dal HEAD `11b48bc` yalnız docs farkı taşır → JS etki sonuçları taze (OBSERVED).

## Kırıntılar
- decision: R3/R4/R5 (ss-crumbs, ovsync-tren)
- open_item: R10 ilk cron etkisi, P1(c) listesi
- assumption: backup-local-state yok

## Bağlam bandı
- SARI-1 (344170 token) iş bittikten sonra geldi. Rapor değişmedi; açık iş yok, devralacak iş yok.

## Düzeltme 1 (kapı tur 1 DÜZELT 3.67 → 9/9 bulgu ele alındı)
Kaynak: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/PLAN-KAPI-1-report.md

| # | Bulgu | Değişiklik (PLAN.md:satır) |
|---|---|---|
| B1 KRİTİK | Aşama 1'de kayan hayvanın etiketi güncellenmiyordu | R3 etiket = ritim sınıfı, her kaymada `ovsync_tren += k` (:94); R7 küme + ritim dışı kural (:98); D6 aşama 1 etiket güncellemesi (:355); testler TR-K7-HAFTA2 (:396), TR-K7-TOL (:397), TR-K7-RITIM (:398), TR-K5-1 etiket +1 (:365); Review Focus 1 (:56-58) |
| B2 KRİTİK | K5 toleransı her çağrıda ayrı ölçülüyordu, birikmiyordu | R18 `_ovsync_pg1_kayma` = PG1 − (gerçek GnRH1 + 7) (:109, imza :250); D6 `kayma + p_gun ≤ tolerans` (:355); R7 toptan kararı (:98); R13 K11 aynı çapa (:104); TR-KAYMA-1, TR-K5-N2/TR-K5-2 (:366-367), TR-K11-3 (:372) |
| B3 ÖNEMLİ | Kabul testleri birbirinden yalıtılmamıştı | Senaryo izolasyonu: SAVEPOINT/ROLLBACK TO + TEMP SEQUENCE sayaç + kilit testinde GUC sıfırlama + fixture kümesine süzme (:186-196); TR-IZOL-1 (:196 ve D1 testi); TR-K10-GUC kendi savepoint'inde (:263) |
| B4 ÖNEMLİ | `_ovsync_kilit_gorev` görev tipi koşulu tanımsızdı | R5 "Ovsync görevi" tek tanım (a)/(b)/(c) (:96); `_ovsync_gorev_mu` + kilit formülü (:252-254); TR-K10-7/8/9 (:339); JS eşi `ovsyncTrenGorevMu(t,{hayvanIdSet,gunIdSet})` + aynı tablo testi (:460) |
| B5 KÜÇÜK | R1 `to_date` 22008 ham hatası | R1 ondalık kontrolü + EXCEPTION → OVSYNC_TREN_AYAR (:92); TR-AYAR-N4 (:261) — kapatıldı |
| B6 KÜÇÜK | Hızlı geri bayraksız değişiklikleri kapsamıyordu | R19 Ruling (:110) + P11 "hızlı geriyle dönmeyenler" (:631) — Ruling'lendi |
| B7 KÜÇÜK | G7/V3 demo/UI kapısında yürünmüyordu | DM1 e2e'ye V3 ve G7 (:583); UI kapısı madde 13-14, kabul 14/14 (:606-608) — kapatıldı |
| B8 KÜÇÜK | Bayrak 0 iken ovsync-takip e2e regresyonu yoktu | DM1 "Bayrak kapalı regresyon" adımı (:576) — kapatıldı |
| B9 KÜÇÜK | R4 spec §6'dan sapıyor | R20 Ruling (:111) + mockup README etiketi (:442) — Ruling'lendi |

Yeni Ruling'ler: R18 (birikimli tolerans), R19 (hızlı geri sınırı), R20 (R4 sapma etiketi). Toplam R1–R20. Açık sahip sorusu: yok (R20 sapması G-MOCK'ta sahibe sunulur).

## Bağlam bandı (Düzeltme 1 sonrası)
- SARI-1 (376474 token) Düzeltme 1 commit edildikten (9618d34) sonra geldi. Açık iş yok. Tur 2 düzeltmesi gerekirse taze bir mimar açılmalı; girdi bu rapor ve PLAN-KAPI-1-report.md.
