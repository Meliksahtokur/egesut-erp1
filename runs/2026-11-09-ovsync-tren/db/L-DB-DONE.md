⟦ss-sub model=opus effort=medium rol=ss-kulvar-lead-opus iş=ovsync-tren N1 L-DB (D0–D8) seri migration + kabul⟧
sonuc: TAMAM

kabul SHA: b69a195

Kulvar N1 L-DB, dal `ovsync-tren`, worktree `~/.herdr/worktrees/egesut-erp1/ovsync-tren`. DAG ve ruling'lerin tamamı:
`~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/progress.md`.
Prod ve demo DB'ye yazılmadı. Tüm koşumlar yerel `egesut_ovsync_kabul` üzerinde BEGIN/ROLLBACK içinde yapıldı. Push yapılmadı.

## Son ölçüm (lead, MEASURED, b69a195)
- Seri 001..008 + `supabase/tests/ovsync_tren_kabul.sql` → `NOTICE:  OZET: 546 PASS` (rc 0)
- Seri 001..008 + düzeltilmiş `supabase/tests/ovsync_pg_kabul.sql` → `OZET: 487 PASS`, `BOLUM 1-bayrak0: 33 PASS`. Bu 33'ün 31'i taban assert'i, 2'si A5 ekidir.
- D8a tabanı (serisiz) 482 / Bölüm 1 31. Geri alma provasından sonra taban betik yine 482/31 verdi ve pg_proc ile protokol_ayar farkı 0 çıktı (D8-report).
- db-validate 008 --priors 001..007 → `SONUÇ: PASS`; `grep CURRENT_DATE supabase/migrations/2026111010000*.sql` → boş

## Görev tablosu
| Görev | Commit(ler) | Kabul son satırı (görev sonunda) | Kapı verdict'i |
|---|---|---|---|
| D0 gövde/regresyon tabanı | f7edd8c | 16/16 md5 prod=demo=kanit=yerel, DRIFT yok | T0 (lead nokta-ölçümü ✓) |
| D8a pgk fixture onarımı | 97aeab2, 4e46386 | serisiz OZET 482 PASS | T2, D8 ile tek tur: D8a bulgusu yok |
| D1 Faz 0 hatırlatma | 4a32f60 | OZET 24 PASS | T2 PASS (tur 1) |
| D2 tren çekirdeği (+D2-EK R6-EK) | 0426ce2, 9aba75e | OZET 108 → 176 PASS | T2 KABUL (D2), D2-EK D3 ile KABUL |
| D3 görev doğumu/anahtar | 03f7415 | OZET 176 PASS | T2 KABUL (tur 1) |
| D4 başlatma/K8 (+D4-EK, tur 2) | 1adffe6, 4dd94df, 6a9e8db | OZET 220 → 290 PASS | T2 KABUL (D4); D4-EK D5 ile tur 1 DÜZELT → tur 2 KABUL |
| D5 K10 kilit + K9 | 6eabd94 | OZET 265 → 290 PASS | T2 tur 2 KABUL |
| D6 aşama RPC + K11 | 00420d2, 7ce4781 | OZET 362 → 366 PASS | T2 tur 1 DÜZELT → tur 2 PASS |
| D7 liste + toptan | 9dc700c, a9e4ff5 | OZET 456 → 488 PASS | T2 tur 1 DÜZELT. Tur 2 root talimatıyla yeniden review'a gitmeden lead nokta-ölçümüyle kapandı (488 PASS, db-validate PASS) |
| D8 ayar/göç/regresyon/geri-al | acd0f71, b69a195 | OZET 539 → 546 PASS | T2 tek tur DÜZELT. Tur 2 root talimatıyla Run kanıtı ve lead nokta-ölçümüyle kapandı (546 PASS) |

Report'lar aynı klasörde: `D<k>-report.md`, `D<k>-review-report.md`.

## Lead ruling'leri (progress.md, özet)
- RL-1: `ovsync_tren` etiket artışı yalnız `vaka_kalan_gunleri_kaydir` içinde yapılır; çağıranlar ayrıca artırmaz.
- RL-2: md5 korumaları D0 prod sütunundan alınır.
- RL-3: commit görev başına.
- RL-4 / RL-9: kabul DB'si tek sahipli; build yalnız D0 ve D1'de.
- RL-5: build.sh EGESUT_REPO'suz koşulur.
- RL-6: brief "Yazılabilir dosyalar" satırları çıplak yol.
- RL-7: D8a seri koşturuldu.
- RL-8: db-validate ana checkout betiğiyle koşulur (worktree'de `.env` yok).
- RL-10: R6-EK D2 dosyasında uygulandı.
- RL-11 (düzeltilmiş): gecikmiş ya da ritim dışı görevde v_tren R9 formülüyle hesaplanır (K2 öne çekme ≤2).
- RL-12: `ovsync_bastan_baslat` her dalda açık PG+48 TAI'yi kapatır (K6 a/b dışlaması).
- RL-13: A5 hatırlatma assert'i yalnız d2/d25 için.
- RL-14: toptanda ileri D0'lı aşama 0 vakalar da +N kayar.
- RL-15: toptan BASTAN hedefi X+N'dir ve aynı işlemde başlatılmaz.
- RL-16: toptan erteleme yalnız üyesi olan ilk ritim gününde yapılabilir; aksi `ONCEKI_TREN_VAR`.
- RL-17: (iii) sınıfında aşama 0 → BASTAN.
- RL-18: R14 göçü ve üyelik yazımı yalnız açılışta ya da çapa değişince koşar.
- Varsayım ruling'leri: seanssız gün belirsiz sayılır (R6-EK); D7 tur 2'de RL-15 tabanı X+1+öne_çekme.
- Root ruling'leri: SORU-1 (b), SORU-2 A1–A4, SORU-3 R6-EK, SORU-4 A5–A7, D4 notları (gorev_hedef_eski, uye_sayisi tek kaynak), sözleşme eki.
- **Root'a not:** R6-EK, RL-11..18 ve seanssız-gün kararı PLAN.md "Ruling'ler" tablosuna işlenmedi, çünkü PLAN.md L-DB zarfının dışında. Kaynak progress.md'dir.

## Sözleşme eki (alan → dosya:satır → assert id)
- D4 `ovsync_tren_onizle`: `kupe_no`, `kural_tarihi`, `uye_kupeler` ve `gorev_hedef_eski` (root D4 ruling) → `supabase/migrations/20261110100004_ovsync_tren_baslatma.sql:595-605` → TR-EK-ONIZLE (`supabase/tests/ovsync_tren_kabul.sql:1611-1685`), TR-D4EK-1/2/3.
- D6 `seans_tamamla.ovsync_uyari`: `kupe_no`, `planlanan_tarih`, `tamamlanan_tarih`, `bastan_tren_gunu` → `supabase/migrations/20261110100006_ovsync_tren_asama.sql:223-224` → TR-EK-UYARI (`ovsync_tren_kabul.sql:2712-2744`).
- D7 `ovsync_tren_listele` üye satırı: `pg_pay`, `pg1_zaman`, `ritim_disi_neden` → `supabase/migrations/20261110100007_ovsync_tren_toptan.sql:58,91-100` → TR-EK-LISTE (`ovsync_tren_kabul.sql:2863-2901`).
- D7 önizleme `uyeler`: `ovsync_tren`, `pg_pay`, `pg1_zaman`. Üst düzey: `tren_sayisi`, `dokunulmaz{bagimsiz,ritim_disi}`, `ileri_vakalar[]` (RL-14) → `20261110100007_ovsync_tren_toptan.sql:184,242` → TR-EK-ONIZLE-2, TR-K7-ILERI.
- Yeni dönüş alanları ve kodlar:
  - `ovsync_bastan_baslat`: `iptal_tai[]` döner ve default'lu `p_hedef` parametresi alır (D7 tur 2; geçersizse `OVSYNC_BASTAN_HEDEF_GECERSIZ`).
  - `start_first_service_protocol`: `basladi:false` + `yeniden_hedef` dönebilir; yeni hata `OVSYNC_TREN_UYELIK_YOK`.
  - `OVSYNC_TREN_GUNU_DEGIL`: `sebep:'ONCEKI_TREN_VAR', ilk_tren` alanları.
  - `OVSYNC_TREN_ERTELE_DUSTU.dusenler[].oneri`.
  - `ovsync_tren_yeniden_hedefle`: `belirsiz_asama[]` ve `belirsiz_sayisi` (`20261110100008_ovsync_tren_ayar_goc.sql:103`).

## Açık kalemler
1. anon EXECUTE kabul DB'sinde ölçülemiyor, çünkü varsayılan ACL yok. REVOKE satırları yalnız metin olarak doğrulandı. DM1 demo apply'dan sonra yeni ve değişen tüm imzalar için `has_function_privilege('anon', …)` ölçülmeli.
2. Bağımsız işareti yok. Bayrak açıkken çapa değişirse ya da doğrudan `ovsync_tren_yeniden_hedefle(false)` çağrılırsa, bağımsız (NULL) vaka D0'ı yeni ritme düşüyorsa üyelik alabilir. RL-18 bunu yalnız aynı çapada önler. Tam çözüm ayrı bir kolon ister; bu durumda "tek DDL" kuralı root/sahip kararıdır.
3. UI (UB2/UB3) şunları ele almıyor: `ONCEKI_TREN_VAR`, `ileri_vakalar`, `basladi:false` + `yeniden_hedef`, `iptal_tai`. "Tren gününü ertele…" düğmesi yalnız ilk tren başlığında olmalı.
4. Cron `ilk_tohumlama_zamanlayici`, yeniden hedeflenen görevi `baslatilan` sayısına `case_id` null olarak yazıyor. Bu kozmetik bir log sayımı; fonksiyon plan dışında olduğu için değiştirilmedi.
5. `hedef_saat` 21:00'ten sonra olan Ovsync görevi yeniden hedeflenirken `_tohumlama_pencere` yuvarlaması yüzünden ertesi güne, yani tren dışına kayabilir. Prod'daki 25 açık görevin hepsi 10:00 (D8 MEASURED); bugün etkisi yok.
6. Prod runbook notları:
   - Bayrak açılmadan önce ayar doğrulanmalı. Bayrak açıkken ayar bozuksa cron, uyarı ve takip ekranı toptan `OVSYNC_TREN_AYAR` ile düşer (spec §7).
   - P1c listesinin yanına `belirsiz_asama` listesi eklenmeli (R6-EK).
   - `geri-al.sql`'deki `DROP COLUMN` adımı sahibin son onayını ister.
7. Bütçe aşımları gerekçeli ve kabul edildi. Hepsinin nedeni prod gövdelerinin zorunlu tam kopyası:
   - D3: 1015/520
   - D4: 573/450
   - D5: 755/600
   - D6: 462/450
   - D7: 441/400
8. Kulvar sonunda `gitnexus analyze --index-only` koşulmadı (yalnız SQL değişti, JS atlası etkilenmedi). Gerekirse root koşar.

## Kırıntılar
- decision ve measurement kırıntıları her görev için yazıldı (workspace fable-rol-ve-davranislar): RL-5, SORU-1..4, R6-EK, RL-11..18, review turları.
- gate kırıntıları: doc-drift (D4-EK K2, RL-11 lead hatası) ve race-lifecycle (D6 K6 a/b).
- open_item kırıntıları: pgk tabanı (kapandı), onizle UB2 (root ruling ile kapandı), anon ACL (açık), bağımsız işareti (açık).
