⟦ss-sub model=opus effort=high rol=ss-reviewer-kapi iş=D7 T2 review⟧
sonuc: TAMAM

VERDICT: FAIL (K-F2 karşılığı: DÜZELT)
OKUDUM: kat1 yok (şablon tabanlı T2 brief; nokta-paket değil) · DONE (D7-report.md) 175 satır tam · lead review yok (progress.md RL-1..RL-14 + SORU-1..4 tam) · kat2 = `git diff 7ce4781 9dc700c -- supabase/ runs/.../db/`: 007 345/345 satır, 006 diff 21+/5−, kabul.sql 3152-3200 (TR-K7-5) + grep satırları; PLAN.md D7, Global Constraints, R1–R20, Kapı tur 2; design.md K2/K4–K7, :55-75, :149-150; 005:80-100; 006:412-433; ground_truth islem_geri_al · araç 22
ÖLÇTÜM:
- kabul seri (BEGIN/ROLLBACK) → rc 0, `NOTICE:  OZET: 456 PASS` (DONE iddiası 456 = MEASURED, birebir)
- db-validate 007 --priors 001..006 → rc 0, `SONUÇ: PASS`, rapor db-validation-ed7f7e8c.md (DONE ile aynı sha; MEASURED)
- `! grep -n CURRENT_DATE …2026111010000*.sql` → çıktı yok, rc 0 (MEASURED)
- ss-kalite-sinyal → `OZET sinyal=6 eklenen=361 butce=400` (BOYUT 361/400 DONE ile birebir; MEASURED)
- Varsayım 1 sondası (001..007 uygulanmış, ROLLBACK): `_ovsync_tren_gunu_ic(kural=bugün−60, yeni_çapa, 2, bugün)` →
  X=bugün,N=7 → **2026-11-09 (= X = bugün)**; X=bugün+3,N=4 → **2026-11-09 (bugün)**; X=bugün+7,N=2 → **2026-11-11** (R7 X+N=2026-11-18);
  X=bugün,N=3 → 2026-11-12 (= X+N, TR-K7-2 fixture'ı) (MEASURED)
İŞARETLİ:
- [ÖNEMLİ] supabase/migrations/20261110100007_ovsync_tren_toptan.sql:190-191 (+ :294) — spec/plan sapması (Varsayım 1) — toptan BASTAN hedefi "yeni ritimde en yakın tren" (K2) olduğu için X−bugün ≥ 7−N iken hedef X+N değil daha erken çıkıyor; X=bugün,N=7 ve X=bugün+3,N=4'te hedef **bugün** → `ovsync_bastan_baslat` aynı işlemde başlatır (basladi:true): çiftçi X'teki işleri ertelerken hayvan bugün/X'te yeniden GnRH1'e girer. Spec K5/K2 ("en yakın trene biner") lafzına ve D6 tek-hayvan yoluna uyar, önizleme = gerçek tutar (aynı formül); ama R7 "(yeni tren X+N)" ve K7 "o tarihteki işler … ertelenir" amacıyla çelişir. DONE'daki "X bugünse her zaman X+N" iddiası N=7 için yanlış (doc-drift) — kanıt: ÖLÇTÜM Varsayım 1 sondası (MEASURED) — dar fix: root ruling (SORU-5 aşağıda); öneri R7 lafzı: BASTAN hedef tabanı X+1 → `_ovsync_tren_gunu_ic(GREATEST(kural, p_tarih+1), X+N, one, bugün)` (= X+N); D6 RPC'ye (006 henüz hiçbir yere uygulanmadı) `p_en_erken date DEFAULT NULL` eklenip toptan X+1 geçer, önizleme :191 aynı tabanı kullanır; TR-K7-2'ye X=bugün,N=7 ve X=bugün+3,N=4 alt senaryosu.
- [ÖNEMLİ] supabase/migrations/20261110100007_ovsync_tren_toptan.sql:156-161, :169, :178, :205 — plan boşluğu (RL-14'ün X'ten ÖNCEKİ simetriği) — p_tarih yalnız "≥ bugün ve ritimde" doğrulanıyor; X ilk yaklaşan üyeli trenden ilerideyse (spec design.md:149 her tren başlığında "Tren gününü ertele…", liste bugün+28'e kadar başlık gösterir) çapa global değişir ama hedefi [bugün, X) aralığındaki açık OVSYNC_BASLAT'lar (ne (i) ne ileri_gorevler: :205 `> p_tarih`) ve ovsync_tren ∉ {X, X−7} önceki tren vakaları eski ritimde kalır → hepsi "ritim dışı" olur, o günler için toptan erteleme artık `OVSYNC_TREN_GUNU_DEGIL`; bugünkü başlatılmamış görev RL-11 ile bugün başlamaz, yeni ritme yeniden hedeflenir — kanıt: kod okuma, INFERRED (ölçülmedi) — dar fix: lead/root ruling, RL-14 ile aynı tur 2; öneri fail-closed: `p_tarih` > bugünden itibaren üyesi olan ilk ritim günü ise `OVSYNC_TREN_GUNU_DEGIL:{tarih, ilk_tren}` (önizleme dahil) + test TR-K7-N2 alt senaryosu; alternatif RL-14 kalıbıyla aradaki sınıfları da kaydırmak.
- [KÜÇÜK] supabase/migrations/20261110100007_ovsync_tren_toptan.sql:100-101 — (d) verimlilik — ritim dışı vaka satırında `_ovsync_pg1_kayma` 3 kez + `_ovsync_tren_uye_vaka` içinde 1 kez (her biri gün/seans sorgusu) — kanıt: gözden okuma — dar fix: kaymayı bir alt sorguda bir kez hesapla (ya da uye_vaka dönüşüne `kayma` ekleyip oradan oku).
- [KÜÇÜK] supabase/migrations/20261110100007_ovsync_tren_toptan.sql:147 — (b) — önizlemeden gelen OVSYNC_TREN_KAPALI payload'ı da `rpc:'ovsync_tren_ertele'` diyor — kanıt: gözden okuma — dar fix: payload'dan `rpc`'yi kaldır ya da çağıran adını parametreyle geç (UA1 kodla eşleşiyorsa davranış etkisi yok).
- [KÜÇÜK] supabase/migrations/20261110100007_ovsync_tren_toptan.sql:181, :189, :290 — K4 ayrışması/test boşluğu — (iii) sınıfında GnRH1'i X−7<bugün'de işaretlenmemiş (aşama 0, gecikmiş) vaka +N ile gün#1'i X−7+N'ye (geçmiş) taşır; önizleme geçmiş `yeni_tarih` gösterir, `vaka_kalan_gunleri_kaydir`'ın geçmiş güne tepkisi ölçülmedi (UNKNOWN: ya tüm toptan öneri'siz DUSTU ya geçmiş günlü vaka). K4 "sonraki trene geçer" der — kanıt: kod okuma, INFERRED — dar fix: test ekle; DUSTU ise `oneri` ver, değilse ruling.
- [KÜÇÜK] supabase/tests/ovsync_tren_kabul.sql:3184-3186 — test gücü notu — TR-K7-5 "hepsi geri" assert'i RAISE'in alt-transaction geri sarmasıyla yapısal olarak garanti; asıl ölçüm DUSTU RAISE'i (mutant "DUSTU raise yok" öldü) — fix gerekmez.
BLOKLAYAN: 2 (ikisi de ruling'e bağlı; tur 2'de RL-14 ile birlikte) · ERTELENEBİLİR: 4
NOKTA NOTU: Nokta-review değil, tam diff okundu; js/ commit'leri kapsam dışı bırakıldığı için UA1'in BASTAN satırında "baştan başlar → <tren>" tarihini X+N varsayıp varsaymadığı ölçülmedi.

## D7'ye özgü kontrol listesi
| madde | sonuç | kanıt |
|---|---|---|
| R7 küme (i)/(ii)/(iii) | uygun | 007:169 (i) hedef=X, :178 `ovsync_tren IN (X, X−7)`; bağımsız (NULL) dışarıda (CONFIRMED kod) |
| R18 birikimli aşama 1 kararı | uygun | :182-183 `N ≤ pg_pay` = `kayma+N ≤ tol`; pg_pay ham :56; kayma NULL → sonuc NULL → düşer |
| Kısmi başarı yok (TR-K7-5) | uygun | :278-307 alt blok, :319-321 DUSTU RAISE; çapa :270 aynı işlemde → geri; TR-K7-5 PASS |
| Önizleme yazmaz (TR-K7-ONIZLE) | uygun | onizle/plan `STABLE` (plpgsql STABLE içinde UPDATE çalışmaz) + kb_ozet md5 PASS |
| R9 ileri görevler | uygun (plan lafzı) | :198-207 `_ic(GREATEST(kural, eski), X+N, one, bugün)`, kural NULL → `kural_yok`; yazma :312 `gorev_ertele` (iç bayrak :257) |
| R16 listele | uygun | :95 `≤ bugün+28`, :116-118 ileri_sayisi; vakalara sınır yok (Varsayım 7, kabul) |
| RL-1 etiket çift sayım yok | uygun | :290 yalnız `vaka_kalan_gunleri_kaydir`; 007'de `ovsync_tren` UPDATE yok (CONFIRMED) |
| RL-12 BASTAN/PG48 D6 RPC'leri | uygun | :294 `ovsync_bastan_baslat`, :297 `ovsync_pg48_tohumla` |
| R6-EK öneri | uygun | :306 BELIRSIZ → `oneri:'BASTAN_BASLAT_YA_DA_SEANS_ISARETLE'`; :281 plan↔işlem arası aşama değişimi de BELIRSIZ |
| SÖZLEŞME EKİ (TR-EK-LISTE / TR-EK-ONIZLE-2) | uygun | listele üye: pg_pay/pg1_zaman :56, ritim_disi_neden :91-92/:99-102; plan üye: ovsync_tren/pg_pay/pg1_zaman :166/:172; tren_sayisi :218; dokunulmaz :209-215 |
| ACL | uygun | :338-345 iç yardımcılar PUBLIC/anon/authenticated REVOKE; 3 RPC anon REVOKE + authenticated GRANT (anon varsayılanı kabul DB'de ölçülemez → DM1, devralınan açık kalem) |
| TR tarih | uygun | :70, :136 TR ifadesi; CURRENT_DATE grep boş (MEASURED) |
| D6 dar fix iptal_tai | uygun | 006 diff: iki dalda `iptal_tai`, basladi=false dalında `OVSYNC_BASTAN_BEKLIYOR` islem_log (islem_log değişmez guard'ı gerekçeli); TR-K6-B1 assert PASS |
| md5 koruması | gerekmez | 007 yalnız yeni nesne; 006 gövdesi D6'nın kendi yeni fonksiyonu, seri uygulanmadı |
| Kapsam | uygun | diff yalnız brief yazılabilirleri (006, 007, kabul.sql) — `git diff --stat` 3 dosya +940/−5 (MEASURED) |
| Varsayım 8 (yeni islem_log tipleri) | uygun | ground_truth `islem_geri_al` tip CASE'i bilinmeyen tipe "geri alma desteklenmiyor" döner → OVSYNC_TREN_ERTELE snapshot'ı sahte geri almaya açık değil (OBSERVED, ground_truth:8244-8269; canlı gövde değil) |
| Varsayım 2–7, 9 | kabul | gerekçeli, spec'i değiştirmiyor |

## Varsayım 1 değerlendirmesi (brief isteği)
- Spec K5 "baştan başlar … yeni trene biner", K6(b) "baştan başlat → trene bin", K2 "en yakın tren", modal "baştan başlar → <tren>": hedefin X+N'ye sabit olmasını spec ŞART KOŞMAZ; Varsayım 1 spec lafzıyla ve D6 tek-hayvan yoluyla tutarlı, önizleme = gerçek tutar (CONFIRMED kod :191 ↔ D6 hedef).
- PLAN R7 "aksi baştan başlat (yeni tren X+N)" ve TR-K7-2 "yeni görev hedefi X+3": yalnız X−bugün < 7−N iken sağlanır (MEASURED sonda). N=7'de X=bugün bile istisna (DONE'daki "her zaman" iddiası yanlış).
- Asıl risk K7 amacı: hedef ≤ X çıktığında (MEASURED: bugün) çiftçinin ertelediği gün/öncesinde hayvan yeniden başlatılır; X=bugün ise aynı gün `basladi:true`. Bu, spec'in iki maddesi (K2 vs K7) arasında yorum farkıdır → root ruling.
- SORU-5 (root'a): Toptan BASTAN hedefi (a) R7 lafzı: yeni ritimde X'ten sonraki ilk tren (= X+N; öneri) mi, (b) K2 en yakın tren (bugün dahil, mevcut kod) mu?

## Kalite
OZET sinyal=6
KALİTE: tekrar 006:29 ~ 007:240 → gerekli — SECDEF RPC başlık kalıbı (`RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path`), proje idiyomu
KALİTE: tekrar 006:252 ~ 007:240 → gerekli — aynı başlık kalıbı
KALİTE: tekrar 006:334 ~ 007:240 → gerekli — aynı başlık kalıbı
KALİTE: tekrar 006:398 ~ 007:240 → gerekli — aynı başlık kalıbı
KALİTE: olcum-yok: 2 dosya — dil-desteksiz
Gözden okuma: (a) 361/400 bütçe içinde, yeni nesneler gerekli; (b) üye satırı tek tanım (`_ovsync_tren_uye_vaka`) liste+plan ortak — iyi; (c) yüzey plan imzalarıyla birebir; (d) :100-101 tekrar çağrı KÜÇÜK.

## Run kanıtı
1)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/migrations/20261110100004_ovsync_tren_baslatma.sql supabase/migrations/20261110100005_ovsync_tren_kilit.sql supabase/migrations/20261110100006_ovsync_tren_asama.sql supabase/migrations/20261110100007_ovsync_tren_toptan.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
```
rc: 0
```
NOTICE:  PASS TR-EK-ONIZLE-2: aşama 1 pg_pay
NOTICE:  PASS TR-ACL-4: D7 ACL
NOTICE:  OZET: 456 PASS
```
2)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100007_ovsync_tren_toptan.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100005_ovsync_tren_kilit.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100006_ovsync_tren_asama.sql
```
rc: 0
```
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-ed7f7e8c.md
 İzole DB'ler drop edildi: egesut_val_410016_cdb55ed7 egesut_val_410016_8b5fedd0
```
3)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql
```
rc: 0
```
(çıktı yok)
```
4) ss-kalite-sinyal --repo … --base 7ce4781 --head 9dc700c --butce 400 → rc: 0, son satır `OZET sinyal=6 eklenen=361 butce=400`
5) Varsayım 1 sondası (001..007 + SELECT, ROLLBACK) → rc: 0, son satır `X=bugun N=3 (TR-K7-2)|2026-11-12|R7 X+N=|2026-11-12`

## Kırıntılar
- gate (doc-drift/unmeasured-claim): D7 Varsayım 1 "X bugünse her zaman X+N" N=7'de yanlış; toptan BASTAN hedefi bugün çıkabiliyor (MEASURED sonda) → SORU-5 root.
- gate (dead-path): X ilk üyeli trenden ilerideyken önceki trenler ritim dışı kalıyor, toptan erteleme o günlere kapanıyor (INFERRED) → RL-14 ile tur 2 ruling.
- measurement: kabul 456 PASS, db-validate 007 PASS (ed7f7e8c), CURRENT_DATE yok, sinyal 6 (4 gerekli + 2 olcum-yok), eklenen 361/400.
- Kod keşfi: gitnexus/atlas kullanılmadı — worktree indeksli değil (DONE ve önceki review'larla aynı; tazelik ölçülmedi); hedefli okuma + grep.
