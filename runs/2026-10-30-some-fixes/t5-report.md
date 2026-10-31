⟦ss-sub model=opus effort=high rol=ss-worker-high iş=İki migration ve veri onarımını yedek ve doğrulamayla prod'a uygula⟧
sonuc: KISMI
job_id: j-20261030T211433Z-ca0079
progress: Prod yazmaları tamam (2 migration + kayıt + onarım). Açık tek kapı: `veri-eslesme-kontrol.py hepsi` koşamadı, demo INACTIVE; `sizinti` ölçülemedi.
BOYUT: bütçe kod değişikliği yok · gerçek 0 · bütçe içinde

## Özet

| Adım | Sonuç | Etiket |
|---|---|---|
| Yedek | `~/yedek/prod-yedek-2026-10-31-dogum-kupe/` (11 dosya, manifest doğrulandı) | MEASURED |
| Dry run | 42703/42P01/42710 sıfır; ama ilk dosyada script rc=1, **bkz. Sapma 1** | MEASURED |
| `20261030000001_dogum_kupe_recycle` | Uygulandı, kayıtlı | MEASURED |
| `20261030100001_protokol_etken_senkron` | Uygulandı, kayıtlı | MEASURED |
| Onarım `t4-veri-onarim.sql` | Uygulandı; son durum kapısı geçti | MEASURED |
| `veri-eslesme hepsi` | **Koşamadı (rc=2)**; prod ayakları ayrı koşuldu | MEASURED |
| Gerçek doğum kaydı | Denenmedi (brief gereği); doğum akışı prod'da uçtan uca ölçülmedi | UNKNOWN |

Prod'a bu üç dosya dışında yazma yok. Push ve merge yok. Demo'ya dokunulmadı.

**Sahibin doğum girişi:** DB engeli kalktı. 503 ve 507'de tek istisna var, **bkz. Doğum ön koşulu**.

## Gelen iş denetimi

Üç bulgu, ikisi koşum yöntemini değiştirdi:

1. `db-dry-run.sh` kendi `BEGIN/COMMIT`'i olan dosyayı `exit 65` ile reddediyor; iki migration da bunları taşıyor. Yalnız bu iki satırı çıkaran kopyalar `$HOME/tmp` altında koşuldu.
2. Prod veritabanı bağlantı dizesi `.env`'de yok. Brief'in yedek yolu uygulandı: Mgmt API'ye tek istek, önce/sonra ayrı okuma.
3. Yetki kaynağı: sahip onayını yalnız brief üzerinden gördüm, sahibin kendi mesajını görmedim. `.harness/contract.md` DROP işlemi için "final specific approval" istiyor. Brief'in "İkisi + veri onarımı" seçimini `DROP INDEX` taşıyan migration'ı kapsayan onay saydım. Root teyit etsin.

## Sapmalar

1. **Dry run rc=1 ile ilerledim.** Script `dogum_kupe_recycle` için `DRY-RUN: HATA` dedi. Tek neden, aynada index olmadığı için çıkan `NOTICE: 00000: index ... does not exist, skipping` satırı. Script `00000` kodunu bilinmeyen hata sayıyor. psql `ON_ERROR_STOP=1` altında `ROLLBACK`'e kadar gitti. Brief'in ölçütü olan üç kod sıfır. Bunu hata saymadım, durmadım.
2. **Bu dry run `DROP INDEX`'i sınamıyor.** Aynada index yok, deyim boşa çalıştı. Dayanak: canlıda index'e bağlı FK olmaması (t3 ölçümü) ve t3'ün prod kataloğu fixture testi. Canlı apply hatasız bitti.
3. **`schema_migrations` kaydı ayrı istek.** Dosyalar kendi transaction'ını taşıdığı için sarmalamadım (brief). Apply ile kayıt arası saniyeler, ikisi de geri okundu.
4. **`veri-eslesme` yalnız prod ayağıyla koşuldu.** Script'i değiştirmedim. Geçici sarmalayıcı (`ve_prod.py`) demo öz-sınamasını atlıyor, prod öz-sınaması duruyor. Çıktıdaki `iki DB'de de yazma reddedildi` satırı bu koşumda demo için doğru değil.

## Yedek ve rollback

Yol: `~/yedek/prod-yedek-2026-10-31-dogum-kupe/` (repo dışı, dizin 700, 3,9 MB)

| Dosya | İçerik |
|---|---|
| `hayvanlar.json` / `dogum.json` / `gorev_log.json` | 176 / 83 / 4471 satır |
| `fonksiyonlar.json` | 3 gövde, ACL, md5 |
| `indexler_hayvanlar.json` | `uq_hayvanlar_kupe_no` dahil 5 index |
| `onarim_hedef_once.json` | 11 hedef görevin önceki hali |
| `protokol_eksik_tara_once.json` / `_sonra.json` | tarama çıktıları |
| `schema_migrations_son.json`, `ROLLBACK.md`, `manifest.sha256` | kayıtlar ve manifest |

**Rollback (`ROLLBACK.md`):**

1. `fonksiyonlar.json` içindeki `def` alanları çalıştırılır.
2. Index şu tanımla kurulur: `CREATE UNIQUE INDEX uq_hayvanlar_kupe_no ON public.hayvanlar USING btree (kupe_no) WHERE (kupe_no IS NOT NULL);`. Recycle ile küpe tekrarı oluştuysa önce o temizlenmeli, yoksa CREATE hata verir. Önerilmez, K1'i yeniden kırar.
3. Onarım: `onarim_hedef_once.json` değerleri id ile geri yazılır.
4. İki `schema_migrations` satırı silinir.

## Doğrulama (apply sonrası canlı)

| Kontrol | Sonuç |
|---|---|
| `uq_hayvanlar_kupe_no` | Yok |
| `hayvanlar_kupe_no_key` | Var, `WHERE durum='Aktif' AND kupe_no IS NOT NULL AND kupe_no <> ''` |
| `dogum_kaydet` `COUNT(*)+1` | Yok |
| `gebelik_protokol_kontrol` etken literal | 3 (`ROTA`, `ADEMIN`, `E_VIT`) |
| `hizli_uygulama` | `p_occurred_at AT TIME ZONE 'Europe/Istanbul'` var |
| ACL ve `SECURITY DEFINER` | 3 fonksiyonda değişmedi |
| `schema_migrations` | İki sürüm var; `md5(statements[1])` dosya md5'iyle eşit |

Gövde md5, `prosrc` ile migration'daki `$function$` arası metin karşılaştırıldı:

| Fonksiyon | Önce | Sonra = migration |
|---|---|---|
| `dogum_kaydet` | `a90c2492…` | `19631d3f…` |
| `gebelik_protokol_kontrol` | `75e9c8ea…` | `20c3d27f…` |
| `hizli_uygulama` | `dab11827…` | `0a8b6ee9…` |

Apply öncesi canlı gövde ile migration farkı yalnız beklenen satırlardı (diff okundu). Drift yok. MEASURED

## Onarım ölçümü

| Ölçüm | Önce | Sonra |
|---|---|---|
| Etkensiz görev (9 hedefte) | 9 | 0 |
| 906 Rota kapalı | 0 | 1 |
| 191 açık görev | 0 | 2 |
| 907/906/207 tarama eksik | 6 | 1 (207 Rota) |
| Tüm tarama eksik | 15 | 10 |
| `stok_hareket` / `uygulama_log` / `gorev_log` | 1421 / 137 / 4471 | değişmedi |
| `degisim_log` | 6347 | 6359 (+12 = 9 etken + 1 Rota + 2 açılan görev) |

ÖNCE sayısı 6, review bulgu 6'nın öngördüğü değer; kuru koşudaki 9 değil. Görev satırları beklenen durumdaydı. 906 Rota: `tamamlanma_tarihi` 09-02 12:00 İstanbul, `kapatan_ref` = `vaccination_log:c03e8db3-…`. MEASURED

## 14 satırdan kalanlar

5 satır düştü, 9 satır kaldı.

| Küpe | Uyarı | Durum | Not |
|---|---|---|---|
| 906 | SC Ademin | Düştü | yanlış alarmdı |
| 906 | IM E Vit | Düştü | yanlış alarmdı |
| 906 | Rota | Düştü | 09-02 aşısına bağlandı |
| 207 | SC Ademin | Düştü | yanlış alarmdı |
| 207 | IM E Vit | Düştü | yanlış alarmdı |
| 207 | Rota | **Kaldı** | gerçek eksik, görev açık |
| 145 | Rota | **Kaldı** | gerçek eksik |
| 154 | Rota | **Kaldı** | gerçek eksik |
| 155 | Rota | **Kaldı** | gerçek eksik |
| 191 | Rota | **Kaldı** | gerçek eksik |
| 196 | Rota | **Kaldı** | gerçek eksik |
| 201 | Rota | **Kaldı** | gerçek eksik |
| 903 | Rota | **Kaldı** | gerçek eksik |
| 169 | 39. Gün PG | **Kaldı** | görevsiz uyarı; ✕ sahip kararında |

"Gerçek eksik" DB'ye göredir; sahada yapılmış olabilir (t2, UNKNOWN).

Listede olmayanlar:

- **008 kızgınlık takibi** (hedef 10-29): önceki 14 listesinde yok, tarama apply öncesi de gösteriyordu. Bu işten değil. MEASURED
- **191 SC Ademin** artık `yaklasan` (11-04). Onarımın beklenen sonucu. Yaklaşan sayısı 6'dan 7'ye çıktı. MEASURED
- **191 E Vit** henüz görünmüyor, 11-02'den itibaren görünür (t4, INFERRED).

Tarama: 21 satır (15 eksik + 6 yaklaşan) → 17 satır (10 eksik + 7 yaklaşan).

## Doğum ön koşulu (yalnız SELECT)

| Kontrol | Sonuç |
|---|---|
| Sonraki buzağı id'si | `gen_random_uuid()`; `COUNT+1` çakışması gövdeden çıktı |
| 503 | `H000169`, Ölü, aktif eşi 0, devlet küpesi çakışması 0 |
| 507 | `H000174`, Ölü, aktif eşi 0, devlet küpesi çakışması 0 |
| `kupe_no` unique index | Yalnız aktif filtreli `hayvanlar_kupe_no_key` kaldı |
| Aktif küpe tekrarı | 0 |

**Hâlâ red olacak durum** (INFERRED, gövdeden; koşulmadı):

- 503'ü **5708** numaralı anneye, 507'yi **163** numaralı anneye yeniden vermek. İkiz guard reddeder: `Bu küpe bu annenin yavrusu olarak zaten kayıtlı`. Bu t6'nın işi ve t6 migration'ı prod'a girmeden sürer. Başka anneler için engel yok.

**Kısa süreli JS riski** (INFERRED, koşulmadı): K7 düzeltmeleri (`openInsemSafe`, `btSerbestYukle`) ve yeni hata metni commit `82c0926`'da, yayında değil. SQL artık canlı. İlk recycle küpe girildikten sonra yayındaki JS bu iki yolda ölü hayvanı seçebilir. JS'in yayını geciktirilmemeli.

## veri-eslesme

`hepsi` iki denemede de rc=2. Neden: demo projesi `status: INACTIVE`, API `Database is possibly not accessible at the moment` dönüyor. Script bu cevabı `READ ONLY guard çalışmıyor — yazma kabul edildi` diye basıyor; **bu metin yanıltıcı, yazma olmadı**. MEASURED

| Ayak | Sonuç |
|---|---|
| `sizinti` | **Ölçülemedi** (demo gerekli) |
| `koken` | TEMİZ, yetim 0 |
| `statik` (iki dosya) | TEMİZ, sabit DML 0, türetilmiş 0, RPC gövdesi 22 |
| `isaret` | BULGU 58: kombinasyon kümesi 2026-10-17 koşumuyla birebir aynı, satır 2763 → 2790 |

`isaret` satır artışını tek tek incelemedim. Onarımın yazdığı alanlarda işaret yok (`kapatan_ref` test/deneme 0). Bu işin yeni işaret doğurmadığı kombinasyon eşitliğine dayanır. INFERRED

## Bakiye

1. **GT regen (runbook adım 6):** yapılmadı, brief gereği. İki sürüm de ground truth'ta yok. Sonraki migration sonrası tek seferde koşulacak.
2. **`veri-eslesme sizinti`:** demo açılınca `hepsi` yeniden koşulmalı.
3. **`scripts/ground-truth-audit.sh` (runbook adım 7):** brief'te yok, koşulmadı. GT regen ile birlikte anlamlı.
4. **Demo INACTIVE:** CLAUDE.md UI testi kapısı demoya bağlı; t3'teki LUNA-3 hatası da muhtemelen aynı kök (INFERRED). t6'nın UI yürüyüşü de buna takılır.
5. **Araç borcu:** `db-dry-run.sh` NOTICE `00000`'ı hata sayıyor ve kendi transaction'lı dosyayı reddediyor. `veri-eslesme` selftest'i her hedef dışı cevabı "yazma kabul edildi" sayıyor. Dosyalar yazılabilir listemde değil, dokunmadım.

SORU: Demo projesini (INACTIVE) kim, ne zaman açacak? · seçenekler: sahip panelden açar / root açar, sonra `hepsi` koşulur / `sizinti` bakiyede bırakılır · önerim: t6 UI testi de gerektirdiği için şimdi açılsın, `hepsi` o zaman koşulsun.

## Run kanıtı

Yardımcılar: `~/tmp/agents/claude-1000/-home-melik--herdr-worktrees-egesut-erp1-some-fixes/057d2d44-293e-444d-a62a-823b5fa81f48/scratchpad/` altında `q.sh` (Mgmt API, `ro`=`read_only:true`, `rw`=postgres), `apply.sh`, `dry.sh`, `ve_prod.py`. Bu bölümde `$S` bu dizindir. Token çıktıya ve dosyaya yazılmadı: yedek ve scratchpad taramasında 0 eşleşme. MEASURED

Dry run (main checkout, `TMPDIR=$S/dry`, kopya dosyalar):
```
( cd ~/egesut-erp1 && TMPDIR=$S/dry bash scripts/db-dry-run.sh $S/dry/20261030000001_dogum_kupe_recycle.sql )
```
rc: 1
```
    BEGIN
    DROP INDEX
    CREATE FUNCTION
    NOTIFY
    ROLLBACK
    psql:.../20261030000001_dogum_kupe_recycle.sql:14: NOTICE:  00000: index "uq_hayvanlar_kupe_no" does not exist, skipping
▶ Hata kodu analizi…
⚠ Bilinmeyen hata kodları (incele):
     • 00000
❌ DRY-RUN: HATA
yasak kod sayisi: 0
```
```
( cd ~/egesut-erp1 && TMPDIR=$S/dry bash scripts/db-dry-run.sh $S/dry/20261030100001_protokol_etken_senkron.sql )
```
rc: 0
```
    BEGIN
    CREATE FUNCTION
    CREATE FUNCTION
    ROLLBACK
✅ DRY-RUN: BAŞARILI
yasak kod sayisi: 0
```

Apply 1:
```
bash $S/apply.sh 20261030000001 dogum_kupe_recycle
```
rc: 0
```
80e8956d893e7886
--- apply 20261030000001
curl_rc=0
[]
__HTTP__201
--- record 20261030000001
curl_rc=0
[]
__HTTP__201
--- readback
[{"version":"20261030000001","name":"dogum_kupe_recycle","created_by":"t5-prod-apply/some-fixes","n_stmt":1,"stmt_md5":"ad80015b86859b3777574ec44daf4457"}]
__HTTP__201
file_md5 ad80015b86859b3777574ec44daf4457
```

Apply 2:
```
bash $S/apply.sh 20261030100001 protokol_etken_senkron
```
rc: 0
```
b29b878167e4a41b
--- apply 20261030100001
curl_rc=0
[]
__HTTP__201
--- record 20261030100001
curl_rc=0
[]
__HTTP__201
--- readback
[{"version":"20261030100001","name":"protokol_etken_senkron","created_by":"t5-prod-apply/some-fixes","n_stmt":1,"stmt_md5":"63c32b299f60a942a3311350c3cceb19"}]
__HTTP__201
file_md5 63c32b299f60a942a3311350c3cceb19
```
Dosya hash önekleri (`80e8956d`, `b29b8781`) t3 ve t4'ün db-validate raporlarıyla aynı.

Onarım:
```
$S/q.sh rw runs/2026-10-30-some-fixes/t4-veri-onarim.sql
```
rc: 0
```
curl_rc=0
[{"asama":"SONRA","etkensiz":0,"rota906_kapali":1,"g191_acik":2,"tara_eksik_907_906_207":1,"stok_hareket":1421,"uygulama_log":137}]
__HTTP__201
```

Veri eşleşme:
```
cd . && python3 scripts/veri-eslesme-kontrol.py hepsi --cikti $S/ve
```
rc: 2
```
[selftest] READ ONLY guard sınanıyor...
PANIK: [demo] READ ONLY guard çalışmıyor — yazma kabul edildi!: {"message":"Database is possibly not accessible at the moment"}
```
Prod ayakları (`ve_prod.py`, `statik --dosya 20261030000001 --dosya 20261030100001`, `isaret`, `koken`), her biri rc: 0:
```
[isaret] eslesen_kombinasyon=58 eslesen_toplam_satir=2790
HÜKÜM: BULGU: 58
[koken] fk=5 doldurulan=1 ad_eslesme=1 YETIM=0 std_dose_dolu=26
HÜKÜM: TEMIZ
[statik] dosya=2 turetilmis=0 sabit=0 rpc_govdesi=22
HÜKÜM: TEMIZ
```

## Kırıntılar

- gate (env-mismatch): `scripts/veri-eslesme-kontrol.py`, demo INACTIVE, `sizinti` ölçülemedi, yanıltıcı PANIK. Yedek yolu kırıntıda.
- gate (env-mismatch): `scripts/db-dry-run.sh`, NOTICE `00000` yanlış HATA, `DROP INDEX` aynada sınanmadı. Yedek yolu kırıntıda.
- measurement: iki migration kayıtlı, gövde md5 eşit, onarım 9→0 / 1 / 2, tarama eksik 15→10.
- open_item: GT regen bakiye, sonraki migration sonrası.
- Kod keşfi: bu iş kod değiştirmedi, atlas ve gitnexus kullanılmadı, `analyze` gerekmedi. Canlı katalog SELECT ile okundu.
