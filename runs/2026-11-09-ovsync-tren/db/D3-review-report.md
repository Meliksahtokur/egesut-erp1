⟦ss-sub model=opus effort=high rol=ss-reviewer-kapi iş=ovsync-tren D3 + D2-EK T2 kapı review (görev doğumu tren−2, R10 anahtarı, G7 fail-closed, R6-EK aşama tanımı)⟧
sonuc: TAMAM

```
VERDICT: KABUL
OKUDUM: kat1 yok (brief nokta-paket taşımıyor; D2 turundaki emsalle aynı: root kapsamı `git diff 0426ce2 9aba75e -- supabase/ runs/.../db/` olarak verdi, ağaç taraması yapılmadı) · DONE D3-report.md 160 + D2-report.md §D2-EK 153-240 · lead review yok (T2 tek kapı; progress.md 1-60 okundu) · kat2 mig 003: 1-33, 38-149, 154-200, 280-290, 885-925, 1000-1015 + 6 gövdenin kanit/fn ile betikli tam diff'i; mig 002 D2-EK hunk'ı (03f7415..9aba75e) tam; kabul betiği 681-697, 968-991, 1146-1161 · araç 17
ÖLÇTÜM: kabul koşumu (BEGIN/ROLLBACK) → rc 0, `NOTICE:  OZET: 176 PASS` (D2-EK DONE 176 ile aynı; D3 DONE'daki 167 D2-EK öncesi) · db-validate 003 --priors 001 002 → rc 0 `SONUÇ: PASS` (db-validation-b96432c2.md) · CURRENT_DATE grep → rc 0 boş · gövde diff (python difflib, kanit/fn ↔ mig 003, 6 fn) → +92/−36; bunların 6+6'sı yalnız `$function$` / `$function$;` sonlandırıcısı → gerçek +86/−30 (DONE +87/−30 ile ±1); silinen 30 satırın hepsi plan satırı (imza başlıkları, C5 kapısı, GREATEST hedefi, eski anahtar, eski görevsiz kol, 2 çekirdek çağrısı) · md5 (mig 003:23-28) ↔ govde-taban.md prod sütunu → 6/6 eşit · kabul DB (prod eşi, RL-9) proacl → `_acik_disi_gorev_kur(text)` ve `_ovsync_baslat_gorev_kur(text,date,text,date)` `{lsp_user=X,service_role=X}` → Varsayım 4 GRANT service_role canlı ACL ile eş · sonda (BEGIN/ROLLBACK, seri uygulanmış): `_acik_disi_gorev_kur(<text>)` ve `(<varchar>)` 1-arg çağrıları çözüldü, iki fonksiyonda toplam 2 pg_proc satırı (overload yok) · ss-kalite-sinyal → OZET sinyal=6
İŞARETLİ:
- supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql:128-130 — plan sapması / assumption — KÜÇÜK — R6-EK lafzı "tamamlandi=true, seanslarının HİÇBİRİ tamamlanmamış, uygulanmadi işaretsiz → yapıldı" boş seans kümesinde de doğru; D2-EK `s.n > 0` ile seanssız tamamlanmış günü X (belirsiz) sayıyor. Yön fail-closed ve Varsayım olarak yazılı; root R6-EK'yi PLAN'a işlerken bu cümleyi açıkça yazmalı (D8 belirsiz sayımı bu günleri de listeleyecek).
- supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql:184-187 — test boşluğu — KÜÇÜK — R10 anahtarındaki "son tohumlama" sırası (DESC→ASC) mutantı ölçülmüyor; fixture'larda hayvan başına tek tohumlama var (DONE kendisi söylüyor). Dar fix (D8'e): iki tohumlamalı bir hayvanda kaynak_ref'in son tohumlama id'siyle bittiğini doğrulayan tek kb_ok.
- supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql:286 — davranış notu — KÜÇÜK — bayrak açıkken ayar bozuksa `_acik_disi_hedef_ic` artık OVSYNC_TREN_AYAR atıyor; çağıranlar (cron `ilk_tohumlama_zamanlayici`, `ovsync_baslat_uyarilari`, `ovsync_takip_listele`) hayvan başına değil toptan düşer. Spec §7 fail-closed'un istediği bu (INFERRED); bayrak açma runbook'una "ayar doğrulaması önce" adımı yeter.
BLOKLAYAN: 0 · ERTELENEBİLİR: 3
NOKTA NOTU: 24 D3 ve 30 D2-EK mutant koşumunu yeniden koşmadım (DONE beyanı, UNKNOWN); `hayvan_ekle` / `tedavi_sablon_bos_ata_uygula` yollarını uçtan uca koşmadım, yalnız çağrı çözümlemesini (text değişkenle 1-arg) sondaladım.
```

ŞABLON-VERDICT: PASS

## Odak maddeleri (şablon 1-7 + brief'in D3'e özgü soruları)
1. Gövde türetimi — CONFIRMED (MEASURED diff yukarıda). Her fonksiyon için kanit/fn ↔ migration farkı yalnız plan satırları: `_ovsync_baslat_gorev_kur` +14/−4, `_acik_disi_gorev_kur` +10/−2, `_acik_disi_hedef_ic` +2/−1, `ovsync_baslat_uyarilari` +38/−21, `protokol_iptal` +2/−1, `tohumlama_bos_ve_devam` +20/−1 (sonlandırıcı satırları düşülmüş). BOYUT 1015/520 gerekçesi kabul: 902 satır prod tam gövde kopyası, D3 farkı ~116 satır.
2. md5 — CONFIRMED: 6 imza + değer govde-taban.md prod sütunuyla birebir; `to_regprocedure` NULL → COALESCE false → durur (eksik fonksiyon da yakalanır).
3. ACL — CONFIRMED: DROP+CREATE iki iç yardımcıda REVOKE PUBLIC/anon/authenticated + GRANT service_role (canlı eşi ölçüldü); `_acik_disi_hedef_ic` CREATE OR REPLACE (ACL korunur) + REVOKE; 3 RPC REVOKE PUBLIC/anon + GRANT authenticated (kabul DB'de üçü de authenticated=X). `hayvan_ekle` SECURITY INVOKER overload'u (14 arg) `_acik_disi_gorev_kur` çağırmıyor (MEASURED prosrc), yetki kırılması yok.
4. Bayrak 0 eşitliği — CONFIRMED kod yolu: mig 003:84-92 `ELSIF` C5 kapısı birebir, :120 `COALESCE(v_tren, GREATEST(...))` v_tren NULL iken eski ifade, payload `tren_gunu` yalnız v_tren dolu iken; TR-REG-DOGUM / TR-G9-REG / TR-UYARI-REG PASS. R10 anahtarı ve G7 fail-closed R19 gereği bayraktan bağımsız (planlı).
5. TR tarih / hata kodu — CURRENT_DATE yok (MEASURED); `OVSYNC_GOREV_ACILAMADI:{hayvan_id,sebep}` plan adıyla aynı, sebep değeri Varsayım 1.
6. Testler — 11 TR-* id + 2 ek id PASS; TR-ANAH-N1 (968-991) hata kodunu, payload'ı ve geri sarmayı (tohumlama Bekliyor, hayvan durumu, görev/instance yok) ayrı assert'lerle ölçüyor; TR-R6EK-1 (681-697) önce fixture'ın gerçekten "geçmiş, tamamlandi, seans işaretsiz" olduğunu assert ediyor (vacuous değil).
7. Kapsam — `git diff --stat 0426ce2 9aba75e -- supabase/ runs/.../db/` = 3 dosya (002, 003, kabul betiği), hepsi D3/D2-EK yazılabilir listesinde. 192570a (UA1 js) kapsam dışı (brief).
- R10 G7 fail-closed: `tohumlama_bos_ve_devam` OVSYNC dalına bayrak 0'da da varılıyor mu? `_ovsync_pg_aktif()` kapalıyken :727 `IF NOT v_bayrak` erken çıkıyor, OVSYNC_SECIM_ERKEN (:882) kural > bugün'ü önceden eliyor; bu yüzden C5/pg_aktif NULL'u G7'ye sızıp sahte KURULAMADI üretmez (CONFIRMED gövde okuması). Açık OVSYNC_BASLAT varken `_acik_disi_hedef_ic` (kanit :39) NULL döner → yeni anahtar mevcut görevleri ilk cron'da çalkalamaz (CONFIRMED kanit okuması).
- p_hemen: yalnız tren açıkken kapıyı atlar, `_acik_disi_gorev_kur` → çekirdeğe geçiyor (mig 003:196), G9 :448, G7 :895 (CONFIRMED).
- hayvan_ekle / tedavi_sablon_bos_ata_uygula INFERRED yeterli mi: çağrıları `text` değişkenle 1-arg (kanit hayvan_ekle.sql:58/114, tedavi_sablon_bos_ata_uygula.sql:9/28); sonda aynı biçimi seri uygulanmış DB'de çözdü ve overload yok → çözümleme için yeterli (MEASURED); davranış farkı yalnız anahtar biçimi, o da TR-ETKI-D3/TR-ANAH-GOC ile ölçülü.
- D2-EK (002:119-160): Y/N/X sınıfları birbirini dışlıyor (tamamlandi & uygulandı=0 & uygulanmadi=0 → ilk WHEN'de Y; uygulanmadi>0 → N); `uygulanmadi` sayacı artık yalnız uygulanmamış seanslarda sayılıyor; çapa `COALESCE(max işaret TR günü, treatment_date)`, LEAST yok — R6-EK ile uyumlu (CONFIRMED).

OZET sinyal=6
KALİTE: boyut eklenen=1654 butce=520 oran=3.2 → gerekli — 1654'ün 1015'i mig 003 (902 satır zorunlu prod gövde kopyası), kalanı test betiği ve kapsam dışı UA1 js commit'i; D3'ün kendi mantık farkı +86/−30.
KALİTE: tekrar 003:39 ~ 003:155 pencere=6 → gerekli — iki fonksiyonun `RETURNS uuid / LANGUAGE plpgsql / SECURITY DEFINER / SET search_path` başlığı, ortak hale getirilemez.
KALİTE: tekrar 003:378 ~ 003:498 pencere=6 → gerekli — aynı fonksiyon başlığı kalıbı (protokol_iptal / tohumlama_bos_ve_devam).
KALİTE: tekrar 003:855 ~ 003:940 pencere=10 → gerekli — tohumlama_bos_ve_devam'ın prod gövdesinden birebir kopyası (D3 farkı 892-906 dışı; gövde diff'i bu satırları değişmemiş gösteriyor), yeniden yazmak plan dışı olurdu.
KALİTE: olcum-yok: 2 dosya — dil-desteksiz

## Run kanıtı
1)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
```
rc: 0
```
NOTICE:  PASS TR-ETKI-D3: eski arg sayılı çağıranlar çalışır
NOTICE:  PASS TR-ACL-D3: yeni imza ACL
NOTICE:  OZET: 176 PASS
```
2)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql
```
rc: 0
```
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-b96432c2.md
 İzole DB'ler drop edildi: egesut_val_2281017_c965e5e9 egesut_val_2281017_9d71bbcb
```
3)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql
```
rc: 0
```
(çıktı yok)
```
4) `~/tools-bank/scripts/ss-kalite-sinyal --repo ~/.herdr/worktrees/egesut-erp1/ovsync-tren --base 0426ce2 --head 9aba75e --butce 520`
rc: 0
```
SINYAL olcum-yok supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql dil-desteksiz
OZET sinyal=6 eklenen=1654 butce=520
```

## Kırıntılar
- decision: KALİTE: D3+D2-EK T2 KABUL (PASS); 3 KÜÇÜK, bloklayan yok; sinyal 6'nın tamamı gerekli.
- measurement: OZET 176 PASS rc 0; db-validate PASS b96432c2; gövde diff gerçek +86/−30, yalnız plan satırları; md5 6/6; service_role ACL kabul DB'de eş.
- open_item (D8): iki tohumlamalı fixture ile R10 son tohumlama sırası assert'i; seanssız tamamlanmış gün = belirsiz kararını root PLAN R6-EK metnine yazsın.
- not: gitnexus/atlas kullanılmadı (SQL gövdeleri, kapsam brief'te sabit; kanıt doğrudan diff + pg_proc). Bilinen ovsync_pg_kabul.sql 3 assert kırığı D8 kapsamı, bulgu sayılmadı.
