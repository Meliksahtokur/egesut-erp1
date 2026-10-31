⟦ss-sub model=opus effort=high rol=ss-worker-high iş=Erkek doğum kaydı / ölmüş hayvan küpesi kök nedenini prod'da salt-okuma ile kanıtla⟧
sonuc: TAMAM
job_id: j-20261030T181742Z-663858
BOYUT: bütçe 0 · gerçek 0 · bütçe içinde (salt-okuma teşhis; kod/DB değişmedi, commit yok)
Gelen iş denetimi: bulgu yok.

## Özet

İki ayrı kök neden var. Biri bütün doğumları, diğeri ölmüş hayvan küpelerini kilitliyor.

| # | Kök neden | Etki | Başlangıç |
|---|---|---|---|
| **A** | `dogum_kaydet` buzağı id'sini `COUNT(*)+1` ile üretiyor. Bir hayvan silinince sayı geriye düşüyor ve dolu bir id üretiliyor. | **Dişi, erkek fark etmeden tüm doğumlar** PK ihlaliyle düşüyor. | 2026-10-27 10:22 UTC (13:22 TR) |
| **B** | Prod'da eski, tam unique `uq_hayvanlar_kupe_no` duruyor. K3 partial index'i eklendi ama bu index hiç silinmedi. | **Çıkmış hayvanın küpesi kullanılamıyor.** K1 recycle prod'da hiç çalışmamış. Şu an 503 ve 507'yi vuruyor. | Index, K3'ten önceye ait (K3 canlı: 2026-09-01) |

Sahip "erkek" diye gördü, çünkü erkek önerisinin ilk iki numarası (503, 507) ölü hayvanların küpesi. Ancak A yüzünden 510 gibi boş bir numara da, dişi doğum da şu an geçmiyor.

**Kullanıcının gördüğü hata (MEASURED, gerçek kod Node'da koşuldu):** iki durumda da aynı metin çıkıyor, hangisi olduğu anlaşılmıyor:
`❌ Doğum kaydedilemedi: Bir hata oluştu. Lütfen daha sonra tekrar deneyin.`

## Kök neden A: `COUNT(*)+1` id çakışması

- CONFIRMED (canlı `pg_get_functiondef`, gövde satır 68): `SELECT 'H' || LPAD((COUNT(*)+1)::text, 6, '0') INTO v_buzagi_id FROM public.hayvanlar;`
- MEASURED (canlı SELECT): `hayvan_say=176`, `sonraki_id=H000177`, `sonraki_id_var=true`, `h_max=H000177`. H000177 küpe 9, 2026-10-26 tarihli doğumun buzağısı.
- CONFIRMED (`degisim_log`, hayvanlar için tek D kaydı): 2026-10-27 10:22:40 UTC'de `app_name=mgmt-api`, `rol=postgres` ile küpe 2044 silindi. Notu "Muhtemelen 183 nolu hayvanin duplicate kaydi", durumu Kayıp. Son doğumdan 14 dakika sonra yapılmış elle bir veri temizliği. Aynı işlemde 3 gorev_log, 2 vaccination_log ve 1 pedigree_nodes satırı da silindi. Sayı 177'den 176'ya düştü.
- MEASURED: bu silmeden sonra `dogum` tablosunda hiç yazma yok. Son doğum kaydı 2026-10-27 10:08 UTC. 2026-10-26'dan sonraki tarihli kayıt: 0.
- CONFIRMED (TEMP tablo, yerel PG): `insert ('H000177','510','Aktif')` → `duplicate key … "h_pkey"`.
- INFERRED: id üretimi ortak yolda, cinsiyetten önce çalışıyor (satır 68). Bu yüzden dişi doğum da aynı şekilde düşer. Prod'da yazma denemesi yapılmadı (brief yasağı).
- Kırılganlık yeni değil: desen 2026-03 migration'larından beri her `dogum_kaydet` sürümünde var (`20260306000008_blok1_backend.sql` ilk adaylardan). Silme olana kadar tetiklenmemiş. Yeni bir regresyon değil.
- Bugün geçici: tablo bir satır büyürse sayı kurtulur, ama sonraki hard delete'te aynı arıza döner.
- OBSERVED: 14 parametreli eski `hayvan_ekle` overload'unda da aynı `COUNT(*)+1` var. `js/forms.js:171` `p_padok_id` geçtiği için 15 parametreli uuid'li sürüm çağrılıyor, JS'te tek çağıran bu. Eski overload ölü görünüyor, başka çağıran taranmadı.

## Kök neden B: partial olmayan eski unique index

- CONFIRMED (canlı `pg_index`): `hayvanlar` üzerinde `kupe_no` için iki unique index var:
  - `hayvanlar_kupe_no_key … WHERE durum='Aktif' AND kupe_no IS NOT NULL AND kupe_no<>''`. Domain-rules §1 K3'ün tarif ettiği index bu.
  - `uq_hayvanlar_kupe_no … WHERE kupe_no IS NOT NULL`. **Durum filtresi yok**, K1'i kırıyor.
- MEASURED: 54 çıkmış hayvanın küpesi var. `kupe_no` tekrarı 0 (`dup_kupe=null`). Yani prod'da hiçbir küpe bugüne kadar yeniden kullanılmamış.
- CONFIRMED (TEMP tablo, yerel PG, aynı iki index): ölü küpe `507` → `duplicate key … "uq_h_kupe"`. Index düşürülünce aynı insert başarılı, aktif küpe tekrarı ise `h_key` ile yine reddediliyor. Yani K3 korunuyor.
- CONFIRMED (repo): `uq_hayvanlar_kupe_no` hiçbir migration'da yok, yalnız `99999999999999_ground_truth.sql:12637`'de. `20260901000002_kupe_revizyon.sql:218` partial index'i ekliyor, eskisini `DROP` etmiyor (dosyada `DROP INDEX/CONSTRAINT` yok).
- MEASURED: index oid sırası `uq_hayvanlar_kupe_no=115259` < `hayvanlar_kupe_no_key=123171`. Eski index K3'ten önce var. INFERRED: migration dışı (elle) kurulmuş. Tam kurulma tarihi UNKNOWN.
- OBSERVED: `tests/sql/dogum_buzagi_id_test.sql:91` yorumu "hayvanlar.kupe_no tam unique" diyerek bu durumu 2026-09-11'de görmüş ama arıza olarak işaretlememiş.

**Neden testler yakalamadı:** `tests/unit/kupe-oneri.test.js:78` recycle'ı yalnız JS öneri listesinde ölçüyor. Recycle'ı DB INSERT ile deneyen bir SQL testi bulamadım (dar grep, kesin hüküm değil).

## Üç katman birbiriyle çelişiyor (503 senaryosu)

MEASURED/CONFIRMED, `js/config.js:170 bosKupeOner`, canlı `kupe_musait_mi`, canlı `dogum_kaydet` gövdesi:

1. 💡 önerisi gerçek aktif küpelerle: `503, 507, 510, 511, …` (`bosKupeOner` yalnız Aktif sayar, K1'e uygun).
2. Blur kontrolü (`_kupeKontrolEt`, `js/forms.js:46`): `ℹ️ Bu numara geçmişte kullanılmış (Ölü) — yeniden kullanılabilir`. Soft uyarı olduğu için submit'i engellemez.
3. `dogum_kaydet` satır 25: `kupe_no = p_kupe AND durum='Aktif'` → geçer.
4. `INSERT INTO hayvanlar` → unique ihlali (B; şu an A da var). Transaction geri alınır.

Yani frontend ve RPC kurala uygun, tek aykırı olan DB index'i. Lokal state'te çıkmış hayvanı sayma hatası YOK.

## Hata metni neden yutuluyor (üçüncü, ikincil kusur)

MEASURED (`_trErr` + `getUserMessage` gerçek kaynaktan):
- `js/api.js:46` `['duplicate key','Bu kayıt zaten mevcut']`: `rpc()` ham mesajı önce buna çeviriyor (noktasız).
- `js/utils/errorHandler.js getUserMessage`: `USER_FRIENDLY` anahtarı artık eşleşmiyor. Noktalama regex'i de sağlanmıyor, metin jenerik "Bir hata oluştu…" ile eziliyor.
- `tests/unit/errorHandler.test.js:58` ham mesajı doğrudan verdiği için geçiyor, gerçek `rpc()` yolunu ölçmüyor.

## Brief'in kalan maddeleri

**Veri (MEASURED):**
- 500-599 aralığında 10 kayıt var. Aktif: 500, 501, 502, 504, 505, 506, 508, 509. Ölü: 503 (çıkış 2026-10-07), 507 (2026-10-16).
- Kural gereği boş 92 numara var. Bugün gerçekten kullanılabilir olan 90 numara: 510-599.
- Aktif erkek 5xx dışı: 96, 98, 89 (K12, dokunulmaz).
- Son 60 gün: 13 doğum, 10 erkek + 3 dişi. Son erkek 509 (2026-10-22). Erkek yolu 5 gün önce sorunsuz çalışmış, erkeğe özgü bir kural kırığı yok.

**Kayıt bekleyen aday anneler (MEASURED), Gebe ve tahmin = tohumlama + 280 gün:**

| Küpe | Tohumlama | Tahmini doğum | Durum |
|---|---|---|---|
| **907** | 2026-01-10 | 2026-10-17 | **13 gün geçmiş, tek gecikmiş aday** |
| 906 | 2026-01-25 | 2026-11-01 | 2 gün kaldı |
| 182 | 2026-01-26 | 2026-11-02 | 3 gün kaldı |
| 207 | 2026-02-06 | 2026-11-13 | 14 gün kaldı |

Hepsi Aktif, Dişi, Sağmal (Kuru), kısır değil. Sahibin kastettiği hayvanın 907 olması INFERRED, sahibe sorulmalı.

**Diğer katmanlar (OBSERVED, gövde okundu):**
- Tek `dogum_kaydet` overload'u var.
- `_guard_hayvanlar_cinsiyet_grup`, `_guard_dogum_ileri_tarih`, `pedigree_ensure_farm_node`, `gorev_log_cycle_guard` küpe kontrolü yapmıyor.
- `dogum`, `gorev_log`, `protokol_instance`, `pedigree_*` üzerinde küpeye bağlı unique yok. `dogum.yavru_kupe` için de unique yok. Yani B'den sonra küpe için başka engel görmedim.
- `fn_hayvan_grup_padok_sync` gövdesinde yalnız `RAISE` satırları tarandı. Aynı yol 2026-10-27'de başarılı çalışmış.

**Offline (CONFIRMED):** `submitBirth` çevrimdışıysa başta dönüyor (`js/forms.js:208`), kuyruk yolu yok. Bu arızanın kaynağı değil.

**Git ve drift:**
- CONFIRMED: `main` = HEAD = `5d3f6a3`.
- MEASURED: canlı `dogum_kaydet` gövdesi `20260924000001_ovsync_pg_r32_acik_disi.sql` ile birebir (fark 0 satır). Sonraki migration'larda `dogum_kaydet` tanımı yok. Prod son sürüm `20261017100001`.
- Yani son migration'lar küpe kuralını regress etmemiş. RPC drift'i yok, drift yalnız index'te.

**Yan bulgu (OBSERVED, küçük):** `b-cins` için `onchange` yok (`index.html:1754`). Liste "Dişi" iken açılıp sonra Erkek seçilirse chip'ler bayat kalır. Seçilen numara açık bir "500-599" toast'ı verir, sessiz değil.

## Minimal fix önerisi (yazılmadı)

**1) Migration (A + B), DB:**
```sql
DROP INDEX IF EXISTS public.uq_hayvanlar_kupe_no;
-- dogum_kaydet: CREATE OR REPLACE, canlı gövdeden birebir, yalnız satır 68:
v_buzagi_id := gen_random_uuid()::text;
```
- `gen_random_uuid` önerim, çünkü `hayvan_ekle` (15 parametre) zaten bunu kullanıyor ve `COUNT` ile `MAX+1`'in eşzamanlılık riski yok. JS ve 2026 migration'larında `H` önek bağımlılığı dar grep'te çıkmadı (INFERRED).
- `H000…` biçimi korunacaksa alternatif: sequence, 178'den başlatılır.
- Ground truth'tan `uq_hayvanlar_kupe_no` satırı çıkarılır. `scripts/db-validate.sh` zorunlu.

**2) JS (metin), `js/api.js:46`:** eşlemeyi noktayla bitirmek jenerik ezmeyi kaldırır (`'Bu kayıt zaten mevcut.'`). Küpe çakışması için `hayvanlar_kupe_no_key` adına özel bir eşleme daha faydalı olur. `?v=` damgası gerekir.

**3) Testler:**
- SQL: ölü küpe ile doğum geçer, aktif küpe ile red, `DELETE` sonrası doğum geçer.
- Unit: `rpc()` yolundan geçen hata metni.
- `tests/sql/dogum_buzagi_id_test.sql:91` yorumu güncellenir.

**Fix'in açacağı risk (K1 prod'da ilk kez işleyecek, review'a ver):**
- Aynı küpe ilk kez iki satırda olacak. Hiçbir ekran bugüne kadar gerçek veride bu durumu yaşamadı.
- JS'te 13 `kupe_no ===` eşleşmesi var. Örnek: `js/ui.js:15301 openInsemSafe` yalnız `kupe_no` ile `find` yapıyor, aktif filtresi yok, ölü hayvana düşebilir (OBSERVED, satır okundu, davranış çalıştırılmadı). `hayvanByKupeRef` (K7) aktif-öncelikli, diğerleri tek tek bakılmalı.
- Canlı SQL'de `kupe_no` ile eşleşme deseni: `_kisir_ovsync_guard`, `_dogum_buzagi_backfill` (regex taraması, gövde okunmadı).

Öneri: A ve B aynı migration'da, önce demo. Sahip aciliyet isterse A tek başına önce gidebilir, doğumu açmaya yeter.

## O hayvanın doğumu şu an nasıl girilir

Saf UI ile yan etkisiz bir yol YOK. Doğum A yüzünden blokede.

| Yol | Nasıl | Bedel |
|---|---|---|
| **Y1 (önerim)** | Migration'ı prod'a uygula (sahip onayı), sonra normal doğum girişi. | Küçük migration, db-validate ve demo akışı gerekir. |
| **Y2 (deploy'suz)** | Yeni Hayvan formundan **gerçek** bir hayvan ekle (uuid'li yol, sayı 177 olur, sıradaki id H000178 boştur). Sonra doğumu **510 veya üstü** küpeyle gir. 503/507 yine reddedilir. | Yalnız mantıkla çıkarıldı, koşulmadı (INFERRED). Elde gerçek hayvan yoksa sahte kayıt sürü ve istatistiği kirletir. O kayıt sonra silinmemeli, sayı yine düşer. Dişiyse `_acik_disi_gorev_kur` görev açabilir. |
| Y3 (önermiyorum) | Silinen 2044'ü geri yükle. | Duplicate olduğu için bilerek silinmiş, üstelik bağlı satırları da gitmiş. |

Fix gelene kadar prod'da `hayvanlar` hard delete yapılmamalı.

SORU: Sahip beklenen doğumu Y1 ile mi (migration onayı) yoksa Y2 ile mi (deploy'suz, koşulmamış yol) girmek istiyor, ve doğum yapan hayvan 907 mi? · seçenekler: Y1 / Y2 · önerim: Y1. Y2 yalnız elde gerçekten eklenecek bir hayvan varsa.

## Ölçülemeyenler

- Prod'da gerçek hata yeniden üretilmedi (brief yasağı). Semantik yerel PG'de TEMP tabloyla ölçüldü, kalıcı yan etki yok.
- Demo sorgulanamadı: Management API token'ının demo projesine yetkisi yok ("does not have the necessary privileges"). Demo'da `uq_hayvanlar_kupe_no` var mı UNKNOWN. Demo'ya yazma denenmedi.
- `ui_logs` kullanılamadı: son kayıt 2026-06-12, 2026-10-20'den sonra 0 satır. Sahibin hangi küpeyi denediği ve kaç kez denediği UNKNOWN. Telemetri ölü görünüyor (yan bulgu, nedeni araştırılmadı).
- Hata metni, PostgREST'in ham Postgres mesajını `error.message` olarak ilettiği varsayımına dayanıyor (INFERRED). Sahibin ekranından doğrulanmadı.

## Kanıt dosyaları

Hepsi `~/tmp/t1diag/` altında:
- `~/tmp/t1diag/dogum_kaydet__9154.sql`
- `~/tmp/t1diag/kupe_musait_mi__1322.sql`
- `~/tmp/t1diag/hayvan_ekle__3136.sql`
- `~/tmp/t1diag/hayvan_ekle__2218.sql`
- `~/tmp/t1diag/repro.js`
- `~/tmp/t1diag/temp.sql`

Sorgu ham çıktıları aynı klasörde `a.out` … `h.out`. Token hiçbir dosyaya yazılmadı.

## Kırıntılar

- measurement (`ss-crumbs`, workspace `some-fixes`): prod `dogum_kaydet` COUNT+1 id çakışması ve `uq_hayvanlar_kupe_no`.
- assumption: brief'te workspace adı yazılı değildi. Kırıntı worktree adıyla `some-fixes`'a yazıldı, ajan tanımındaki varsayılan `fable-rol-ve-davranislar`'a değil.
- Kod keşfi: JS için atlas (taze, `5d3f6a3`). SQL ve dize aramaları için grep. Gitnexus kullanılmadı, kod yazılmadığı için `analyze` koşulmadı.
