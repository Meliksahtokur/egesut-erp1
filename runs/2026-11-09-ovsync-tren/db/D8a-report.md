⟦ss-sub model=opus effort=high rol=ss-worker-high iş=ovsync_pg_kabul.sql betiğinin kurulum ve fixture kısmını bugünkü prod şemasına uydurup serisiz regresyon tabanını almak⟧
sonuc: TAMAM
progress: tur 1 KISMI (SORU-2), tur 2 root ruling ile kapandı.
job_id: j-20261109T084526Z-03751f
(tur 1 SORU-2, CEVAPLANDI → tur 2) Aşağıdaki "Anlam değişikliği gereken assert'ler" listesindeki 3 kalem önerildiği gibi yeniden yazılsın mı? · seçenekler: (a) üçü de önerildiği gibi (D8a ek turu, ≤20 satır); (b) T31 ve R32-2 bugünkü kurala göre ters çevrilsin, ACL imzaları ayrı kararla ele alınsın; (c) kalemler betikten çıkarılsın ve D8 tabanı Bölüm 0–5 ile sınırlansın · önerim: (a). Üçü de 2026-09-25 sonrası bilinçli sahip/mimar kurallarının (K3, C5, imza genişlemeleri) testteki karşılığı. Bayrak 0 bölüm tabanını (31 PASS) etkilemiyor.

## Tur 2 — root ruling SORU-2 (A1–A4 onaylı; lead mesajı ss-kulvar-lead-opus)
- A1–A4, aşağıdaki tablodaki "önerilen" sütunuyla birebir uygulandı. Değişen her assert'in yanında `-- root ruling 2026-11-09 SORU-2 Ax: <§ / fn:satır>` yorumu var.
  - A1: `v_g IS NULL`, "kısır → kurulmaz". Dayanak: §18.5 ve 20260925000019:66.
  - A2: fixture kısır olmayan hayvana alındı, doğum `kb_bugun()-51` (C5, :74). `v_n = 1` beklentisi aynen kaldı.
  - A3: iki assert oldu. "doğumda buzağıya OVSYNC_BASLAT yok" ve `_ovsync_kural_tarihi(buzağı) = v_b + 12a21g`. Dayanak: §18.2.
  - A4: 5 imza kabul DB'si `pg_proc`'tan alındı. Her biri tek overload, MEASURED: `hizli_uygulama(…,timestamptz,boolean)`, `seans_tamamla(uuid,boolean,text,boolean,text,boolean)`, `bulk_ilac(text[],text,numeric,text,text[],text,text[])`, `tedavi_sablon_uygula(uuid,uuid,date,boolean,text)`, `start_first_service_protocol(uuid,boolean)`. Eski 5 imza "DROP edildi" listesine eklendi.
- ACL sayısı ve hedef rolleri azalmadı: Bölüm 7, 153'ten 158'e çıktı (+5 eski imza). Kontrol edilen roller aynı: anon EXECUTE yok, authenticated EXECUTE var, iç yardımcılarda authenticated kapalı, SECURITY DEFINER, search_path. Mevcut betikte ayrı bir PUBLIC kontrolü yoktu, eklenmedi.
- Serisiz taban: **OZET 482 PASS**, bayrak 0 bölümü (Bölüm 1) **31 PASS**, psql rc 0. MEASURED. Ayrıntı d8a-taban.md'de.
- `git diff aeb2a78 -U0 | grep -c kb_ok` = 5. Bu satırların hepsi root ruling'li A1/A3 assert'leri (aşağıda ham). Başka kb_ok satırı değişmedi.
- Mutant denetimi yapılmadı: A1/A3 assert'leri canlı kuralın gözlenen hâline yazıldı, ters mutasyonla sınanmadı. Durumu UNKNOWN.

## Gelen iş denetimi
Bulgu yok. Brief ölçülebilir ve verilen dosyalarla yapılabilir. Not: S1-a (`deger=0`), betik başındaki bayrak 0 kurulumundan sonra artık yalnız kurulumu doğruluyor; satırın varlığı ve birim/min/max kontrolü hâlâ geçerli. Root ruling "bölüm 1 bayrak 0 → betik kendisi kurar" dediği için bu kurulum olarak uygulandı. Anlam listesine konmadı, burada bildiriliyor (INFERRED).

## Yapılan (yalnız kurulum/fixture; hiçbir `kb_ok` beklentisi değişmedi)
Dosya: `~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/tests/ovsync_pg_kabul.sql`
1. Betik başında `UPDATE protokol_ayar SET deger = 0` var (prod bayrağı 1). Bölüm 2+ mevcut `UPDATE … = 1` satırıyla açılıyor. Bu ek, S1-a'daki ilk kırmızıyı kapattı. MEASURED
2. T07: Ovsync vakası Gebe tohumlamadan ÖNCE açılıyor. 20261031200007 sonrası `tedavi_sablon_uygula` planlama anında da `_pg_kapi` çalıştırıyor, gebe hayvanda `PG_KAPI:BLOCK_PREGNANT` ile fixture düşüyordu (D0 bulgusu). MEASURED
3. `pg_temp.kb_gk_eski(toh)` eklendi. 20260929000004 `tohumlama_kaydet`'ten +21/+35 GEBELIK_KONTROL üretimini kaldırdı; `_pg_olay_isle` ACK yolu ise hâlâ `kaynak='TOH-<id>'` görevlerini kapatıyor. Eski gövdenin iki görevi (20260923000005:438-444) fixture olarak kuruluyor. Kullanıldığı yerler: T09, S4-geri-al-ack, MK10-ui. MEASURED
4. C5 kural günü kapısı (`20260925000019_kural_gunu_kapisi.sql`): kural tarihi ileride ise OVSYNC_BASLAT açılmıyor. Bu yüzden doğum/abort tarihi `kb_bugun() - 51` yapıldı (kural günü = bugün, `hedef = olay+51` beklentisi aynen geçiyor). Etkilenen testler: T28'/T19/T18, S8-start/SK4/T18, T29 (tohumlama ile abort arası 57 gün korundu), R32-1. MEASURED
5. T20 AKTIF_DEGIL: K3 (`20260925000012_kisir_zincir_guard.sql`) Aktif olmayan hayvana rota açmıyor. Rota `pg_temp.kb_rota_elle` ile doğrudan kuruluyor (`_ovsync_baslat_gorev_kur` INSERT kalıbı, instance dahil). Böylece start'ın AKTIF_DEGIL dalı sınanıyor. MEASURED
6. Bölüm sayacı `pg_temp.kb_bolum(ad)` eklendi. Her bölüm sonunda `NOTICE: BOLUM <ad>: n PASS (kümülatif k)` basıyor. 12 çağrı var, bayrak 0 bölümü `1-bayrak0` adıyla ayrışıyor.

## Anlam değişikliği gereken assert'ler (tur 1 listesi; tur 2'de root ruling ile uygulandı)
| # | dosya:satır | mevcut beklenti | neden | önerilen |
|---|---|---|---|---|
| A1 | ovsync_pg_kabul.sql:1402 (T31) | `v_g IS NOT NULL` "kısır işaretli hayvanda da OVSYNC_BASLAT kurulur" (fixture `dogum_kaydet(kısır, CURRENT_DATE-10)`) | K3 (20260925000012) kısıra zincir görevi açmıyor; ayrıca C5, gelecekteki kural günü için açmıyor. S1-T1 tersini (kısır → görev yok) zaten PASS ediyor. Beklenti bugünkü kurala aykırı. MEASURED | Assert ters çevrilir: "kısır → OVSYNC_BASLAT kurulmaz" (`v_g IS NULL`), ya da S1-T1 ile çakıştığı için kaldırılır. |
| A2 | ovsync_pg_kabul.sql:1407 (T31) | `v_n = 1` "elle iptal degisim_log'a düşer" | Kendi anlamı bozulmadı ama A1'in `v_g`'sine bağlı; A1'de görev doğmadığı için 0 dönüyor. MEASURED | Fixture'ı kısır olmayan hayvan + `dogum_kaydet(kb_bugun()-51)` olan ayrı bir görevle kurulur. Beklenti (`v_n = 1`) aynen kalır. A1 kararına bağlı olduğu için ayrıca soruluyor. |
| A3 | ovsync_pg_kabul.sql:1647-1649 (R32-2/SK8) | Dişi buzağıya doğumda OVSYNC_BASLAT açılır; `hedef = v_b + 12a21g`, kaynak `ILK-TOH-DUVE-<buzağı>` | C5: buzağının kural günü doğumdan 12a21g sonra; doğum anında görev satırı doğmuyor. Bu tarih anne kuralıyla (doğum+51 = bugün) aynı doğumda sağlanamıyor. Düve görevi artık zamanlayıcı/açık dişi yolundan `ACIK-DISI-…` kaynağıyla geliyor (INFERRED, `_acik_disi_gorev_kur`). MEASURED | Assert "dişi buzağıya doğumda görev yok (C5)" olur; düve kuralı tarihini sınayan ayrı bir assert eklenir: `_ovsync_kural_tarihi(buzağı) = v_b + 12a21g`. |
| A4 | ovsync_pg_kabul.sql:1496-1501 (ACL `v_rpc` dizisi) | 5 imza var/anon/search_path/authenticated/secdef: `hizli_uygulama(…,timestamptz)`, `seans_tamamla(uuid,boolean,text,boolean,text)`, `bulk_ilac(text[],text,numeric,text,text[],text)`, `tedavi_sablon_uygula(uuid,uuid,date)`, `start_first_service_protocol(uuid)` | Beşi de sonraki migration'larda parametre eklenerek tek overload'a genişledi. Eski imzalar yok (MEASURED, `to_regprocedure` NULL). Bugünkü imzalar sırasıyla `…,timestamptz,boolean`, `…,text,boolean`, `…,text,text[]`, `(uuid,uuid,date,boolean,text)`, `(uuid,boolean)`. Bunlar için anon kapalı, authenticated açık, secdef ve search_path doğrulandı (scratch'te 153/153). Eklendikleri migration'lar INFERRED (grep: 20260925000018, 20260926000002, 20260929000003, 20261013000002, 20261030100001). | Dizide 5 imza güncellenir. Eski 5 imza "eski imzalar düştü" listesine eklenir (+5 assert). |

Not: A1/A2 aynı DO bloğunda. A4 `kb_ok` satırı değil, beklenen veri dizisi. Brief "beklenen değer değişmez" dediği için listede.

## Kırıntılar
- measurement (tur 2): serisiz taban OZET 482 PASS, Bölüm 1 (bayrak 0) 31, Bölüm 0 29. psql rc 0. MEASURED (tur 1 ara: T31 durması, scratch 473)
- open_item: anlam listesi A1–A4. Kapanış koşulu: root kararı ve D8a ek turu.
- assumption: C5 sınırındaki 4 fixture tarihinde `CURRENT_DATE` yerine `kb_bugun()-51` kullanıldı. TR 00–03 arasında `CURRENT_DATE` UTC'de bir gün geride kalıyor; o zaman `GREATEST(kural, bugün)` bugünü seçer ve `olay+51` beklentisi kırılır. Diğer `CURRENT_DATE` kullanımlarına dokunulmadı (brief kararı).
- open_item (ürün gözlemi, kapsam dışı): `_pg_olay_isle` ACK yolu yalnız `TOH-<id>` kaynaklı GEBELIK_KONTROL görevlerini kapatıyor. 20260929000004'ten beri GEBELIK_KONTROL görevini cron üretiyor ve kaynağı `GEBELIK-KONTROL-<id>`; bu görevler PG onayında kapanmıyor. Bu yol bugün fiilen ölü olabilir. OBSERVED (pg_proc gövdeleri)
(workspace fable-rol-ve-davranislar; 4 kırıntı yazıldı)

## Run kanıtı
(tur 2, son hâl)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/tests/ovsync_pg_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
```
rc: 0
(tail'siz koşumda psql rc 0)
```
NOTICE:  KABUL TAMAM: tüm testler PASS
DO
ROLLBACK
```
Aynı koşumun `OZET` ve `BOLUM` satırları (`grep -E "BOLUM|OZET"`):
```
NOTICE:  BOLUM 0: 29 PASS (kümülatif 29)
NOTICE:  BOLUM 1-bayrak0: 31 PASS (kümülatif 60)
NOTICE:  BOLUM bayrak1-gecis: 1 PASS (kümülatif 61)
NOTICE:  BOLUM 2: 65 PASS (kümülatif 126)
NOTICE:  BOLUM 3: 47 PASS (kümülatif 173)
NOTICE:  BOLUM 4: 11 PASS (kümülatif 184)
NOTICE:  BOLUM 5: 28 PASS (kümülatif 212)
NOTICE:  BOLUM 6: 59 PASS (kümülatif 271)
NOTICE:  BOLUM 7: 158 PASS (kümülatif 429)
NOTICE:  BOLUM 8: 8 PASS (kümülatif 437)
NOTICE:  BOLUM 9: 26 PASS (kümülatif 463)
NOTICE:  BOLUM S1: 19 PASS (kümülatif 482)
NOTICE:  OZET: 482 PASS
```
Not: kabul maddesi "son satır OZET" diyor. Betiğin mevcut ÖZET bloğu OZET'ten sonra `KABUL TAMAM` basıyor; psql de ardından `DO` ve `ROLLBACK` basıyor. OZET, FAIL olmadan sondan 4. satırda. ÖZET bloğuna dokunulmadı (kapsam: yalnız kurulum ve fixture). Bu sapma D0 koşum biçimiyle aynı. OBSERVED

```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && git diff aeb2a78 -U0 -- supabase/tests/ovsync_pg_kabul.sql | grep -c "^[-+].*kb_ok"
```
rc: 0
```
5
```
Beşi de root ruling SORU-2 A1/A3 satırları:
```
-  PERFORM pg_temp.kb_ok(v_g IS NOT NULL, 'T31', 'kısır işaretli hayvanda da OVSYNC_BASLAT kurulur', NULL);
+  PERFORM pg_temp.kb_ok(v_g IS NULL, 'T31', 'kısır işaretli hayvanda OVSYNC_BASLAT kurulmaz', v_g::text);
-  PERFORM pg_temp.kb_ok(v_g.hedef_tarih = (v_b + interval '12 months 21 days')::date
+  PERFORM pg_temp.kb_ok(v_n = 0, 'R32-2/SK8', 'dişi buzağı → doğumda OVSYNC_BASLAT yok (kural günü gelmedi)', v_n::text);
+  PERFORM pg_temp.kb_ok(public._ovsync_kural_tarihi(v_buzagi) = (v_b + interval '12 months 21 days')::date,
```
Tur 1'de (yalnız fixture değişikliği) aynı sayı 0'dı. MEASURED

Kırmızılar (tur 1): D0'da `FAIL S1-a`. Ardından sırayla T07 FIXTURE `PG_KAPI:BLOCK_PREGNANT`, T09 fixture 0 GEBELIK_KONTROL, T28' görev NULL, iki `GOREV_BULUNAMADI` (S8-start ve T20 AKTIF_DEGIL), T31. Hepsi MEASURED.

## Commit
- 97aeab2 (tur 1) `ovsync-tren L-DB D8a: ovsync_pg_kabul kurulum/fixture onarımı`. 
- 4e46386 (tur 2) `ovsync-tren L-DB D8a: SORU-2 A1-A4 root ruling (T31, R32-2, ACL imzaları) — taban OZET 482`. Staged alan yalnız ovsync_pg_kabul.sql ve d8a-taban.md (`git diff --cached --stat`).
- Tur 1 ayrıntısı: Staged alan `git diff --cached --stat` ile doğrulandı: yalnız `supabase/tests/ovsync_pg_kabul.sql` (+72/−8) ve `runs/2026-11-09-ovsync-tren/db/d8a-taban.md` (+61). Push yok. Report commit edilmedi (D0/D1 emsali).
- build.sh KOŞULMADI. DB'ye kalıcı yazma yok (tüm koşumlar BEGIN/ROLLBACK).

BOYUT: bütçe 150 · gerçek 117 değişen test satırı (aeb2a78'e göre +96/−21), üretim kodu 0 · bütçe içinde
