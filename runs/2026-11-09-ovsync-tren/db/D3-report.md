⟦ss-sub model=opus effort=high rol=ss-worker-high iş=ovsync-tren D3: görev doğumu (tren−2), R10 ACIK-DISI anahtarı, G7 fail-closed, G9 tren günü + kabul bölümü⟧
sonuc: TAMAM

## Gelen iş denetimi
- Bulgu 1 (MEASURED): Plan, D3 için "~520 satır" bütçe veriyor ve gerekçe olarak yalnız `tohumlama_bos_ve_devam` (487 satır) kopyasını gösteriyor. Oysa değişen 6 fonksiyonun hepsi `CREATE [OR REPLACE]` ile tam gövde ister; kanit gövdelerinin toplamı 103+37+89+68+118+487 = 902 satır. Bütçe bu yüzden yapısal olarak aşılıyor (aşağıda BOYUT). Kapsamı değiştirmiyor, devam ettim.
- Bulgu 2 (MEASURED): `ovsync_pg_kabul.sql` iki şeye bağlı: eski imzalar (ACL listesi :1514-1515) ve eski anahtar biçimi (R32-3/SK8 :1684). D3 sonrası bu 3 assert düşüyor; bu, planın kendi istediği değişikliğin beklenen sonucu. Dosya benim yazılabilir listemde değil, D8'e open_item olarak bıraktım (aşağıda Etki).
- Diğer: bulgu yok. Okuduklarım: PLAN.md (Global Constraints, R1–R20, N1, D3, Kapı tur 2), ortak.md, progress.md RL-1..RL-9, D2 report/review, govde-taban.md, d8a-taban.md. domain-rules §5/§18 ile çelişki görmedim. build.sh koşulmadı (RL-9).

## Yapılan
- `~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql` (yeni dosya, 1015 satır)
  - md5 koruması: 6 fonksiyon tek DO döngüsünde. Değerler D0 prod md5'leri. Fark varsa `<FN>_GOVDE_FARKLI` atılır (ör. `OVSYNC_BASLAT_GOREV_KUR_GOVDE_FARKLI`).
  - `DROP FUNCTION public._ovsync_baslat_gorev_kur(text, date, text, date)` + `CREATE FUNCTION …(p_hayvan_id text, p_baslangic date, p_kaynak_ref text, p_kural_tarihi date, p_hemen boolean DEFAULT false) RETURNS uuid`.
    - Tren açık: `v_tren := _ovsync_tren_gunu(kural)`; `IF NOT p_hemen AND v_tren − 2 > bugün_TR THEN RETURN NULL`; hedef `v_tren`; `islem_log` payload'a `tren_gunu` eklenir.
    - Tren kapalı: C5 kapısı ve `GREATEST` hedefi birebir; `p_hemen` yok sayılır; payload eski biçimde kalır (`tren_gunu` anahtarı yok).
    - Kısır/Aktif/Dişi guard'ı ve parametre doğrulaması tren kapısından önce, değişmedi.
  - `DROP FUNCTION public._acik_disi_gorev_kur(text)` + `CREATE FUNCTION …(p_hayvan_id text, p_hemen boolean DEFAULT false) RETURNS uuid`.
    - R10 anahtarı: `'ACIK-DISI-' || h || '-' || kural || '-' || COALESCE(<son tohumlama id>, '0')`. Son tohumlama = `tarih DESC NULLS LAST, created_at DESC NULLS LAST`.
    - `p_hemen` çekirdeğe geçer.
  - `_acik_disi_hedef_ic` (imza aynı): son satır `RETURN public._ovsync_tren_gunu(v_k);`.
  - `ovsync_baslat_uyarilari()` (imza aynı):
    - `bugun` CTE'sine `tren` (`_ovsync_tren_aktif()`) eklendi.
    - Görevsiz kol, açıkken `tren−2 ∈ [bugün, bugün+2]`; hedef = tren; TAI = tren+10.
    - Kapalıyken eski süzgeç (`kural ∈ [bugün, bugün+2]`, hedef = kural) birebir.
    - Her satıra `tren_gunu` ve `kural_tarihi` eklendi. LATERAL ve `unnest … k(alias)` kullanılmadı (D2 db-validate bulgusu).
  - `protokol_iptal` (imza aynı): yeniden başlat çağrısına `p_hemen => true` (G9).
  - `tohumlama_bos_ve_devam` (imza aynı), OVSYNC dalı (G7):
    - `_acik_disi_gorev_kur(v_hayvan_id, p_hemen => true)` çağrılır.
    - NULL dönerse hayvanın açık `OVSYNC_BASLAT` görevinin id'si kullanılır.
    - O da yoksa `OVSYNC_GOREV_ACILAMADI:{hayvan_id, sebep}` atılır; Boş ataması dahil her şey geri sarılır (R10).
  - Gövde kopyası: 6 gövde kanit/fn'den üretici betikle kopyalandı. Betik değişiklik öncesi her kanit gövdesinin md5'ini D0 değeriyle doğruladı (`$HOME/tmp/ovsync-tren-db/d3gen/gen.py`).
    - Kanit ile migration arasındaki fark: +87 / −30 satır, hepsi D3 yorumlu bloklar (CONFIRMED, `$HOME/tmp/ovsync-tren-db/d3gen/govde-diff.txt`).
    - Silinen 30 satırın hepsi yukarıda adı geçen satırlar (imza başlıkları, C5 kapısı, GREATEST hedefi, eski anahtar, eski görevsiz kol, iki çekirdek çağrısı).
  - ACL:
    - DROP + CREATE edilen 2 iç yardımcı ve `_acik_disi_hedef_ic`: `REVOKE ALL … FROM PUBLIC, anon, authenticated`. Yeniden yaratılan ikisine `GRANT … TO service_role` (canlıdaki ACL'yi korumak için; Varsayım 4).
    - 3 RPC: `REVOKE … FROM PUBLIC, anon` + `GRANT … TO authenticated`.
- `~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/tests/ovsync_tren_kabul.sql`
  - D2 review KÜÇÜK düzeltildi: TR-K1-2 artık `random()` yerine `generate_series(-30, 51, 9)` kullanıyor; 10 sabit kural, mod 7'nin 0..6 kalanlarının hepsi kapsanıyor.
  - D3 yardımcıları ilk savepoint'ten önce eklendi:
    - `kb_duve(kural, kisir)`: kural günü tam istenen gün olan düve.
    - `kb_acik_ob`, `kb_uyari`, `kb_toh_bekliyor`, `kb_eski_instance`.
    - `kb_takili`: runbook P1(c) listesi sorgusu.
  - Yeni bölüm "D3". F0 ve K1/K2 bölümleri değişmedi.

## Test id → PASS (MEASURED, `$HOME/tmp/ovsync-tren-db/d3-yesil.txt`)
OZET **167 PASS**: önceki 108 + D3'ün 59'u. Her id en az bir `kb_ok` ile koşuyor.
| id | kapsam | sonuç |
|---|---|---|
| TR-DOGUM-1 | çapa b+2, kural b+3: hedef_ic = b+2; görev doğar (sınır tren−2 = bugün), hedef b+2, kaynak `ACIK-DISI-<h>-<k>-0`, payload tren_gunu/hedef/kural, tek görev | PASS |
| TR-DOGUM-N1 | çapa b+4, kural b+5 → NULL, satır/instance yok; sınır tren−2 = b+1 → NULL; `p_hemen` → görev, hedef b+4 | PASS |
| TR-REG-DOGUM | bayrak 0 + bozuk çapa (20261131): kural b+5 → NULL, `p_hemen` yok sayılır, hedef_ic GREATEST; kural geçmiş → hedef bugün, R10 anahtarı, payload'da tren_gunu yok; `_ilk_tohumlama_rota_kur` (4 arg) → hedef bugün | PASS |
| TR-ANAH-1 | eski instance + Boş → G7 `ovsync_gorev_id` NOT NULL, kaynak `…-<son tohumlama>`, Boş yazıldı; açık OVSYNC_BASLAT varken onun id'si, ikinci görev yok; tren açıkken G7 hedefi tren b+5 (`p_hemen`) | PASS |
| TR-ANAH-N1 | açık "senkron" ILAC → `OVSYNC_GOREV_ACILAMADI {hayvan_id, sebep:HEDEF_YOK}`; tohumlama Bekliyor ve hayvan durumu değişmedi; yeni görev/instance yok | PASS |
| TR-ANAH-GOC | takılı hayvan P1(c) listesinde → `_acik_disi_gorev_kur` görev açar, sonra listeden çıkar; cron (`ilk_tohumlama_zamanlayici`) ikinci takılı hayvana görev açar | PASS |
| TR-G9-1 | açık, kural b−30, çapa b+3 → `protokol_iptal(…, true)` yeni görev hedefi `_ovsync_tren_gunu(kural)` = b+3; kaynak `PROTOKOL-IPTAL-<case>` | PASS |
| TR-G9-REG | bayrak 0 → hedef bugün (iptal günü), yeniden_not NULL | PASS |
| TR-UYARI-1 | kural b+5 / çapa b+3 → görevsiz satır hedef/tren b+3, TAI b+13, kural b+5; tren−2 = b+8 → yok; alt sınır tren−2 = b−1 → yok; üst sınır tren−2 = b+2 → var; tren b+11 → yok; görevli satırda tren_gunu = hedef, kural_tarihi | PASS |
| TR-UYARI-REG | bayrak 0 + bozuk çapa: kural b+1 → eski değerler (hedef b+1, TAI b+11, kaynak, taban_turu duve), tren_gunu NULL; alanlar = eski 10 + 2 yeni; kural b+2 → var, b+5 → yok; görevli satır | PASS |
| TR-K5-KISIR | tren açık, kısır: `_ovsync_baslat_gorev_kur(…, p_hemen => true)` NULL ve `_acik_disi_gorev_kur(…, true)` NULL; görev/instance yok | PASS |
| TR-ETKI-D3 (ek) | 1-arg çağıran `tohumlama_sonuc_bos` çalışır (kaynak son tohumlama); 1-arg ve 4-arg çağrılar default ile çözülür | PASS |
| TR-ACL-D3 (ek) | 3 iç yardımcı: anon/authenticated kapalı, service_role açık. 3 RPC: anon kapalı, authenticated açık. Eski imzalar yok, overload yok | PASS |

Mutant denetimi (MEASURED): **24/24 öldü**. Betik `$HOME/tmp/ovsync-tren-db/d3gen/mutant.py`, çıktı `$HOME/tmp/ovsync-tren-db/d3-mutant.txt`. Kapsadığı yerler:
- `p_hemen` (yok sayma; `_acik_disi_gorev_kur`'dan çekirdeğe geçmemesi; G7 ve G9 çağrılarında false)
- kapı sınırı tren−1 / tren−3
- hedef tren değil
- kapalı dalda C5 kapısı yok
- eski anahtar
- G7 fallback yok, RAISE yok, sabit sebep
- hedef_ic GREATEST'te kalmış
- uyarı penceresi (kural/alt/üst), hedef/TAI kuralda kalmış, görevli satırda tren_gunu NULL, kapalı dalda tren dolu
- payload'a tren_gunu her zaman eklenmiş
- ACL REVOKE ya da service_role eksik
- md5 koruması

Sağ kalan mutant yok. Bilinen kör nokta (INFERRED): son tohumlama sıralaması (DESC → ASC) mutantı denenmedi. Fixture'larda hayvan başına tek tohumlama var, bu yüzden bu mutant sağ kalırdı.

## Etki (PLAN.md D3 "Etki")
- **pg_proc taraması** (MEASURED, D3 uygulandıktan sonra, BEGIN/ROLLBACK). Değişen iki imzayı çağıran gövdeler ve sınandıkları yer:
  - `_ilk_tohumlama_rota_kur` → `_ovsync_baslat_gorev_kur(p_hayvan_id, p_olay_tarihi, p_kaynak_ref, v_kural)` (4 arg, default): TR-REG-DOGUM'da koştu.
  - `protokol_iptal` → `…(…, v_kural, p_hemen => true)`: TR-G9-1/REG.
  - `hayvan_ekle` → `_acik_disi_gorev_kur(v_id)` (1 arg)
  - `ilk_tohumlama_zamanlayici` → `_acik_disi_gorev_kur(r.id)` (1 arg): TR-ANAH-GOC'ta koştu.
  - `tedavi_sablon_bos_ata_uygula` → `_acik_disi_gorev_kur(v_hayvan)` (1 arg)
  - `tohumlama_sonuc_bos` → `_acik_disi_gorev_kur(v_toh.hayvan_id)` (1 arg): TR-ETKI-D3'te koştu.
  - `tohumlama_bos_ve_devam` → `_acik_disi_gorev_kur(v_hayvan_id, p_hemen => true)`: TR-ANAH-1/N1.
  - Overload sayısı: `_acik_disi_gorev_kur` 1, `_ovsync_baslat_gorev_kur` 1. Belirsiz çağrı yok.
  - `hayvan_ekle` ve `tedavi_sablon_bos_ata_uygula` çalışma anında koşulmadı. Çağrıları birebir aynı biçimde (tek argümanlı değişken), aynı çözümleme yolunu `tohumlama_sonuc_bos` ölçülü olarak koşturdu (INFERRED).
- **`_acik_disi_hedef_ic` çağıranları:** `_acik_disi_ovsync_hedef` (→ `ovsync_baslat_uyarilari`, `ovsync_takip_listele`, cron) ve `ilk_tohumlama_zamanlayici` dry-run.
  - Bu çağıranlar dönüşü yalnız `IS [NOT] NULL` için kullanıyor (CONFIRMED kanit/fn). Tren kapalıyken değer birebir aynı (TR-REG-DOGUM).
  - Tren açıkken ayar bozuksa artık `OVSYNC_TREN_AYAR` atılır. Bu, spec §7'nin istediği fail-closed davranış.
- **Regresyon (`ovsync_pg_kabul.sql`, D8a tabanı 482)**, MEASURED:
  - D2+D3 seriyle ilk FAIL `ACL: public._ovsync_baslat_gorev_kur(text,date,text,date) var gerçek yok`.
  - Scratch kopyada (repo dışında, `$HOME/tmp/ovsync-tren-db/pgk-d3imza.sql`) yalnız 3 satır düzeltildi: :1514-1515 imzalara `,boolean`, :1684 kaynak `= …` yerine `LIKE …-%`. Sonuç **OZET 482 PASS**, Bölüm 1 (bayrak 0) **31 PASS**; ikisi de taban ile birebir (`$HOME/tmp/ovsync-tren-db/d3-pgk-imza.txt`).
  - Ayrıca D1+D2 seriyle `FAIL S10 gorev_sayisi 15 → 12` çıkıyor. Bu D1 (Faz 0) kaynaklı, D3'le ilgisi yok.
  - İkisi de D8'in işi (open_item).
- **JS:**
  - atlas `rpc tohumlama_bos_ve_devam` → yalnız `js/api.js:tohumlamaBosVeDevam@1389`, hatayı yeniden fırlatıyor. Yeni `OVSYNC_GOREV_ACILAMADI` kodunu UA1 `ovsyncTrenHataMetni` zaten tanıyor (`js/ovsync-tren.js:593`); UB kancası bağlamalı.
  - atlas `rpc ovsync_baslat_uyarilari` → `ui.js:loadDash@2021`, `ovsyncAcilisOzeti@4458`, `_showProtokolEkran@5474`. Alanlar yalnız ekleniyor; bayrak 0 iken eski alanların değerleri birebir (TR-UYARI-REG).
  - Atlas HEAD 192570a ağacında sorgulandı; JS bu görevde değişmedi (OBSERVED).

## Run kanıtı

Kırmızı (D3 migration yok, test-önce; `$HOME/tmp/ovsync-tren-db/d3-kirmizi.txt`). rc: 3. D1/D2 testleri PASS, ardından:
```
NOTICE:  PASS TR-ACL-1: iç yardımcılar kapalı, tohumlar ve kolon sözleşmede
ERROR:  FAIL TR-DOGUM-1: beklenen _acik_disi_hedef_ic = tren günü bugün+2 gerçek 2026-11-12
```

1)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
```
rc: 0
```
NOTICE:  PASS TR-ETKI-D3: eski arg sayılı çağıranlar çalışır
NOTICE:  PASS TR-ACL-D3: yeni imza ACL
NOTICE:  OZET: 167 PASS
```

2)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql
```
rc: 0
```
════════════════════════════════════════════════
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-b96432c2.md
 İzole DB'ler drop edildi: egesut_val_2208694_a52dc1b7 egesut_val_2208694_add6076b
════════════════════════════════════════════════
```
(İlk koşumda PASS; INCONCLUSIVE yok.)

3)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql
```
rc: 0
```
(çıktı yok)
```

## Kabul
- `OZET: 167 PASS`; listelenen 11 TR-* id'sinin her biri ≥1 `kb_ok` ile PASS (tablo). MEASURED
- db-validate exit 0 PASS (RL-8 biçimi). MEASURED
- CURRENT_DATE grep'i boş. MEASURED
- Etki listesindeki çağıranlar yeni imzayla kırılmıyor (pg_proc taraması + 5 çağıran yolun çalışma anı testi). MEASURED; 2 yol INFERRED.
- Commit `03f7415` "ovsync-tren L-DB D3: görev doğumu tren−2, R10 ACIK-DISI anahtarı, G7 fail-closed, G9 tren günü".
  - `git add` dosya dosya yapıldı (migration, sonra test).
  - `git diff --cached --stat` = yalnız 2 dosya (1425 ekleme, 3 silme). Report dosyası commit'e girmedi (runs/ önceki görevlerde de commit'lenmedi).
  - Push yok. MEASURED

BOYUT: bütçe 520 · gerçek 1015 · migration dosyasının 902 satırı 6 prod gövdesinin zorunlu tam kopyası (CREATE [OR REPLACE] tam gövde ister; planın 520 tahmini yalnız tohumlama_bos_ve_devam'ı saymış). D3'ün yeni/değişen gövde satırı +87 −30; geri kalanı başlık, md5 koruması (~20) ve ACL (13).

## Varsayımlar
- Varsayım 1 (`OVSYNC_GOREV_ACILAMADI` sebep): plan alan adını veriyor, değerini vermiyor.
  - `HEDEF_YOK`: `_acik_disi_ovsync_hedef` NULL (aktif aileli vaka, senkron görev, takip, gebe/bekliyor, kısır, tabansız).
  - `KURULAMADI`: hayvan uygun ama çekirdek NULL döndü (idempotens çakışması, guard).
  - UA1 metni `sebep`'i olduğu gibi gösteriyor.
- Varsayım 2 (uyarı `tren_gunu`): tren açıkken satırın hedefi (görevli kolda görevin `hedef_tarih`'i, görevsiz kolda `_ovsync_tren_gunu(kural)`), kapalıyken NULL. `kural_tarihi` her iki kolda `_ovsync_kural_tarihi(hayvan)`.
- Varsayım 3 (son tohumlama sırası): R10 "tarih DESC, created_at DESC" diyor; `NULLS LAST` ekledim. Böylece `_acik_disi_hedef_ic` ve `ilk_tohumlama_zamanlayici` içindeki mevcut "son tohumlama" sorgusuyla aynı.
- Varsayım 4 (service_role): DROP + CREATE canlıdaki `service_role=X` yetkisini düşürürdü. Prod'da varsayılan yetki bunu geri verir, kabul DB'sinde vermez. Canlı ACL ile eşlik için açık `GRANT … TO service_role` yazdım; anon/authenticated kapalı.
- Varsayım 5 (G7 fallback sırası): birden çok açık `OVSYNC_BASLAT` olursa (normalde olmaz; çekirdek yenisini açınca eskiyi iptal eder) `hedef_tarih DESC, created_at DESC` ile en yenisi alınır.
- Varsayım 6 (ERKEN kapısı): `tohumlama_bos_ve_devam` OVSYNC dalındaki `OVSYNC_SECIM_ERKEN` (kural > bugün) kapısı plan gereği değişmedi. Tren açıkken kural−2 günündeki öne çekme G7'den seçilemez, cron/uyarı yolundan gelir. Spec'i değiştirmedim.
- Varsayım 7 (`ilk_tohumlama_zamanlayici` dry-run): `hedef_tarih` hâlâ `GREATEST(kural, bugün)` (kanit :62). Bu gövde D3'ün 6 fonksiyonu arasında değil, dokunmadım (open_item).

## Kırıntılar
- measurement: OZET 167 PASS, 24/24 mutant öldü, db-validate PASS b96432c2, commit 03f7415.
- assumption: sebep HEDEF_YOK/KURULAMADI; uyarı tren_gunu kaynağı; NULLS LAST; service_role GRANT.
- open_item (D8): `ovsync_pg_kabul.sql` 3 assert'inin anlamı D3 ile değişti (:1514-1515 eski imzalar, :1684 eski anahtar). Scratch düzeltmeyle seri 482 PASS (taban eşit); SORU-1 şartı gereği değişiklik listesi ve gerekçe root'a gider. Ayrıca D1 kaynaklı S10 düşüşü (gorev_sayisi 15 → 12).
- open_item (UB): `tohumlama_bos_ve_devam` yeni `OVSYNC_GOREV_ACILAMADI` hatası UI'da `ovsyncTrenHataMetni` ile gösterilmeli. Zamanlayıcı dry-run hedefi tren değil (D8/plan).
- Not: gitnexus analyze koşulmadı (ortak.md: kulvar sonunda lead koşar). Gerekli geçici dosyalar `$HOME/tmp/ovsync-tren-db/` altında (= `~/tmp/ovsync-tren-db/`).
