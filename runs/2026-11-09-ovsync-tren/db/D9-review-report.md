⟦ss-sub model=opus effort=high rol=ss-reviewer-kapi iş=D9 T2 review⟧
VERDICT: KABUL
sonuc: TAMAM
(Salt-okuma reviewer inline döndü; metni root dosyaya yazdı, 2026-11-09.)

OKUDUM: brief · şablon · D9-brief · D9-report · diff d359e4e..7ff1e7b (6 dosya, +147/−9).
ÖLÇTÜM: kabul serisi rc 0 `OZET: 557 PASS` · prova_d9.sh rc 0 fark 0 · db-validate 004 rc 0 PASS · CURRENT_DATE grep boş · ikinci şablon sondası + mutant.

## Odak
1. RD9-3 (CONFIRMED): `ovsync_tren` yazan yalnız 4 nokta: 004:472-476, 005:396, 005:712, 008:97-99. OVSYNC yapan her yol `tedavi_sablon_uygula`'dan geçer (start_first_service_protocol 004:239-244, vaka_toplu_ac, tedavi_sablon_bos_ata_uygula; DB'de calls_tsu=true); ovsync_bastan_baslat (006:447) start üzerinden; doğrudan INSERT INTO cases yalnız `_vaka_ac_tek` (DEFAULT false). Report listesi eksiksiz. 005:712 K9 aynı UPDATE'te işaret yazar; 005:396 dokunmaz.
2. RD9-4 (CONFIRMED): 008:75 seçim ve 008:99 UPDATE `NOT c.ovsync_bagimsiz`; UPDATE'teki tekrar READ COMMITTED eşzamanlı işarete karşı da korur (INFERRED). 007:115, 007:234-239 yalnız sayım — dokunulmaması doğru.
3. R4 (MEASURED): TR-BAG-5 PASS.
4. Worker açık kalemi (MEASURED sonda): işaretli vakaya tren gününde ikinci OVSYNC şablonu → (NULL,t), ok=true. Mutant `SET ovsync_tren = v_tren` de 557 PASS — WHERE'deki IS DISTINCT FROM koruması dalı ikinci kez kapatıyor; davranış doğru, test yok (KÜÇÜK-2).
5. RD9-6 (CONFIRMED): imza ve jsonb dönüşü değişmemiş.
6. geri-al (MEASURED): iki kolon da yok, prova fark 0, kalıcı yazma yok.
7. Kapsam/boyut: 6 dosya yazılabilirde; ss-kalite-sinyal eklenen=21 bütçe=40.

## İŞARETLİ
- [KÜÇÜK-1] 20261110100004_ovsync_tren_baslatma.sql:472-476 — tekrar: işaret ifadesi SET ve IS DISTINCT FROM'da iki kez, `_ovsync_tren_aktif()` 3 kez çağrılıyor. Dar fix: `v_bag` değişkeni bir kez hesaplanır. BLOKLAMAZ.
- [KÜÇÜK-2] supabase/tests/ovsync_tren_kabul.sql D9 bölümü — işaretli vakaya ikinci şablon dalı testsiz (mutant 557 PASS). Dar fix: sonda TR-BAG-7 olarak.
- [KÜÇÜK-3] TR-BAG-3 üçüncü assert işaret filtresini tek başına ölçmez (hastalık günlü vaka 008:76 ile zaten dışlanır); ayrıştırıcı TR-BAG-2. Fix gerekmez.
BLOKLAYAN: 0 · ERTELENEBİLİR: 3

NOKTA NOTU: pgk serisi (487 / Bölüm 1 33) ve db-validate 002/005/008 yeniden koşulmadı (worker beyanı); 004 reviewer tarafından koşuldu.

## Run kanıtı
- Kabul serisi (Run 1): rc 0 → `NOTICE:  PASS TR-BAG-6: V3 yolu işaret` / `NOTICE:  OZET: 557 PASS`.
- `! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql`: rc 0, çıktı yok.
- `bash ~/tmp/ovsync-tren-db/prova_d9.sh`: rc 0 → `PROVA: … fark = 0, protokol_ayar fark = 0`.
- db-validate 004 (--priors 001-003): rc 0 → `SONUÇ: PASS` (~/egesut-erp1/reports/db-validation-29c0f3ee.md).

## Root kararı (2026-11-09)
KABUL, kabul SHA 7ff1e7b. KÜÇÜK-1/2 N7 prod öncesi tek "SQL cila" kalemine ertelendi (sahip token kaygısı: yeni tur açılmaz); KÜÇÜK-3 not.
