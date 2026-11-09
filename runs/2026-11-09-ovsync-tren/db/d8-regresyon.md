# D8: regresyon eşitliği, seri bütün koşumu, geri alma provası

Ölçüm zamanı 2026-11-09T12:14Z. DB yerel `egesut_ovsync_kabul`; build.sh koşulmadı (RL-9). Koşumların hepsi BEGIN/ROLLBACK içinde, kalıcı yazma yok.
Seri: `supabase/migrations/2026111010000{1..8}_*.sql`.

## 1. ovsync_pg_kabul.sql regresyonu (root ruling SORU-1 (b) + SORU-4)

Taban: D8a betiği (commit `4e46386`), serisiz koşum, `d8a-taban.md`. Karşılaştırılan: seri 001..008 uygulanmış hâl + SORU-4 A5–A7 ile düzeltilmiş betik (bu görev).
Her iki koşumda psql rc 0, `KABUL TAMAM`. MEASURED

| bölüm | bayrak | taban (D8a, serisiz) | seri 001..008 + düzeltilmiş betik | fark |
|---|---|---|---|---|
| 0 (şema/katalog) | 0 | 29 | 29 | 0 |
| **1 (BAYRAK 0, MK5)** | **0** | **31** | **33** | **+2: S10 (A5 dal ii)** |
| bayrak1-geçiş | 1 | 1 | 1 | 0 |
| 2 | 1 | 65 | 65 | 0 |
| 3 | 1 | 47 | 47 | 0 |
| 4 | 1 | 11 | 11 | 0 |
| 5 | 1 | 28 | 28 | 0 |
| 6 | 1 | 59 | 59 | 0 |
| 7 (S-9 + ACL) | — | 158 | 161 | +3: ACL "DROP edildi" (A6) |
| 8 | 1 | 8 | 8 | 0 |
| 9 | 1 | 26 | 26 | 0 |
| S1 | 1 | 19 | 19 | 0 |
| **OZET** | | **482** | **487** | **+5** |

Farkın kaynağı (assert id'leriyle; diff: `runs/2026-11-09-ovsync-tren/db/d8-pgk-assert-diff.txt`):
- Bölüm 1, +2, `S10`. Bu iki assert A5 dal (ii) için eklendi: `dogum_sonrasi_pg_gorev_aktif=0` iken doğum 12 görev açar ve PG görevi açmaz; doğumu bugün−2 olan anne `dogum_sonrasi_pg_hatirlatma()` çıktısında gun=2 satırıyla görünür (RL-13).
  Tabandaki 31 assert'in hepsi aynı beklentiyle koşup PASS verdi. Dal (i) (`=1`, arşiv kodu) S10'un mevcut assert'lerini değiştirmeden çalıştırıyor: 15 görev, PG günleri {2,25,39}, MK5 ve tarayıcı.
  Bayrak 0 bölümünde eşitlik ölçüsü: 31/31 taban assert'i PASS, üstüne 2 yeni assert. MEASURED
- Bölüm 7, +3, `ACL`. A6 gereği D3/D4'te DROP+CREATE ile genişleyen 3 imzanın eski hâli "DROP edildi" listesine girdi: `start_first_service_protocol(uuid,boolean)`, `_ovsync_baslat_gorev_kur(text,date,text,date)`, `_acik_disi_gorev_kur(text)`.
  `v_rpc`/`v_ic` dizilerindeki 3 imza yenileriyle değişti; dizi boyu aynı kaldığı için kontrol sayısı ve roller azalmadı. MEASURED
- A7, `R32-3/SK8`. Anahtar beklentisi R10 biçimine çekildi (`-<son tohumlama id>` eki). Sayı değişmedi.
- `git diff 4e46386 -U0` çıktısında değişen `kb_ok` satırı 2. İkisi de A5 dal (ii) için eklenen satırlar; silinen `kb_ok` yok.
  Silinen 7 satırın dağılımı: 1 DECLARE (A5 değişkenleri), 3 imza dizisi (A6), 1 DROP listesi (A6), 2 R32-3 (A7). Her değişikliğin yanında `-- root ruling 2026-11-09 SORU-4 Ax: …` yorumu var (6 yorum). MEASURED

Ham son satırlar (seri + düzeltilmiş betik):
```
NOTICE:  BOLUM 0: 29 PASS (kümülatif 29)
NOTICE:  BOLUM 1-bayrak0: 33 PASS (kümülatif 62)
NOTICE:  BOLUM 7: 161 PASS (kümülatif 434)
NOTICE:  BOLUM S1: 19 PASS (kümülatif 487)
NOTICE:  OZET: 487 PASS
```

### TR-*-REG (ovsync_tren_kabul.sql, seri bütün koşumunda)
`TR-REG-1`, `TR-REG-DOGUM`, `TR-G9-REG`, `TR-UYARI-REG`, `TR-K8-REG`, `TR-K10-REG` ve `TR-K11-REG` hepsi PASS. MEASURED

## 2. Seri bütün koşumu
`( echo BEGIN; cat 001..008 supabase/tests/ovsync_tren_kabul.sql; echo ROLLBACK; ) | psql …` komutu rc 0 döndü, sonuç `NOTICE:  OZET: 539 PASS`. D7 tabanı 488 PASS'ti; fark +51, D8 bölümü ve 22:00 assert'i. MEASURED

## 3. Geri alma provası (`runs/2026-11-09-ovsync-tren/db/geri-al.sql`)
Prova tek transaction içinde şu sırayla koştu: seri öncesi `pg_proc` anlık görüntüsü (public; imza, md5(prosrc), ACL kümesi, secdef, proconfig) ve `protokol_ayar` → seri 001..008 → `geri-al.sql` → karşılaştırma → `ovsync_pg_kabul.sql` taban sürümü (`4e46386`) → ROLLBACK. MEASURED
```
NOTICE:  SERI UYGULANDI: yeni fn 27, kolon 1
NOTICE:  GERI_AL TAMAM: 16 gövde D0 md5, 24 yeni fonksiyon + 3 yeni imza yok, cases.ovsync_tren yok, 5 ayar yok
NOTICE:  PROVA: public pg_proc (imza, md5, acl, secdef, config) seri öncesiyle fark = 0, protokol_ayar fark = 0
NOTICE:  BOLUM 1-bayrak0: 31 PASS (kümülatif 60)
NOTICE:  OZET: 482 PASS
```
- 16 fonksiyonun `md5(prosrc)` değeri D0 tablosuyla (`govde-taban.md`) aynı. Doğrulama dosyanın kendi DO bloğunda; tutmazsa `GERI_AL_GOVDE_FARKLI` verir.
- D3/D4'ün yeni imzaları düştü, eski imzalar yeniden yaratıldı. Bunlar `start_first_service_protocol(uuid,boolean)`, `_ovsync_baslat_gorev_kur(text,date,text,date)` ve `_acik_disi_gorev_kur(text)`.
- 24 yeni fonksiyon kaldırıldı. D6'nın `ovsync_bastan_baslat(uuid,boolean,text,date)` (p_hedef'li imza) ile D8'in iki RPC'si bunlara dahil. `cases.ovsync_tren` yok, 5 ayar satırı yok.
- Bütün public fonksiyon kümesi seri öncesiyle birebir aynı: ACL dahil, fark 0. ACL sıra-bağımsız karşılaştırıldı. Rol kümesi aynıydı, yalnız `_vaka_ac_tek` için ACL dizisinin sırası değişmişti.
- Geri alma sonrasında aynı transaction'da taban betik (482 / Bölüm 1 31) koştu. Sonuç D8a tabanıyla birebir.
- Prod notu: ACL deseni prod `proacl` değerinden alındı (Management API read_only, 2026-11-09; sahibi postgres, roller kabul DB ile aynı). MEASURED
  Kolon DROP'u sahip son onayı ister (P11). GOREV_ERTELE ile taşınmış görev hedefleri geri alınmaz; islem_log soyu kalır.

## 4. Runbook notları
- Bayrak açıkken ayar bozuksa (çapa geçersiz, öne çekme ya da tolerans aralık dışı) cron (`ilk_tohumlama_zamanlayici`), uyarı ve takip/listele yolları toptan `OVSYNC_TREN_AYAR` ile düşer (spec §7). TR-AYAR-CRON bunu ölçüyor: cron ve `ovsync_tren_listele()`. MEASURED
  Önlemler:
  - `ovsync_tren_ayar_guncelle(true, X)` açılıştan önce ayarı `_ovsync_tren_ayar()` ile doğrular. Bozuksa `OVSYNC_TREN_AYAR` döner ve bayrak 0 kalır (TR-AYAR-N3).
  - Çapa 20260101..20991231 dışındaysa `ARALIK_DISI` döner (TR-AYAR-N5).
  - Hızlı geri (`ovsync_tren_ayar_guncelle(false, NULL)`) ayarı doğrulamaz, bozuk çapada da çalışır (TR-AYAR-P1).
- P9/P10: `ovsync_tren_yeniden_hedefle(true, '2026-11-12')` dönüşünde `belirsiz_asama`/`belirsiz_sayisi` (R6-EK) gelir. Bu liste P1c yanında sahibe gider.
- Ayarlar ekranı `ovsync_tren_aktif`'i göstermiyor (`index.html` data-ayar listesinde yok — MEASURED). Bayrağın genel `protokol_ayar_guncelle` ile göç yapılmadan açılma yolu UI'da yok. UB3 ayar düğmesi `ovsync_tren_ayar_guncelle`'yi çağırmalı.
