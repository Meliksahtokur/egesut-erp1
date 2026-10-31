⟦ss-sub model=opus effort=high rol=ss-worker-high iş=Görev/protokol etken_kod fix migration'ı, hizli_uygulama tarih yazımı ve veri onarım SQL'ini test ederek hazırla⟧
sonuc: TAMAM
job_id: j-20261030T182831Z-b9f9ad
kabul_sha: 5d394d2
BOYUT: bütçe iki gövde + 5 satır · gerçek iki gövde + 16 satır (327 satırlık dosya; 6 kod satırı, kalanı başlık ve BEGIN/COMMIT) · başlıkta drift ve kapsam notu tutuldu. Onarım 52/60. Test 165/120: kuru koşu 12 satırlık görev fixture'ı taşıyor, ikisi ayrı dosya olmak zorunda (onarım kendi COMMIT'ini atıyor).

## Özet

- **F1** ve **F2** migration'da hazır: `supabase/migrations/20261030100001_protokol_etken_senkron.sql`. Prod'a uygulanmadı.
- **Veri onarımı** hazır ve yerelde sınandı: `runs/2026-10-30-some-fixes/t4-veri-onarim.sql`. Prod'a uygulanmadı.
- Davranış testi fix öncesi 6/8 kırmızı, fix sonrası 8/8 yeşil. MEASURED
- `db-validate` PASS (`reports/db-validation-b29b8781.md`). MEASURED

Prod sırası önerisi: migration, sonra onarım. İkisi birbirine bağlı değil; ters sıra da çalışır (INFERRED, onarım fix'siz gövdeyi çağırmıyor).

## Gelen iş denetimi

Dört bulgu, hiçbiri işi durdurmadı:

1. **"`_gorev_dinle` neden kapattı" varsayımı yarı doğru.** Yalnız E Vit `_gorev_dinle` ile kapanmış; Ademin değil (aşağıda §191).
2. **`kapatan_ref='vaccination_log:c03e8db3'` kısa id.** Tam uuid yazdım (`assumption` kırıntısı). Canlı satırlar ve `fn_dinle_vaccination` tam uuid kullanıyor; kısası geri alma eşleşmesini kırardı.
3. **Run komutu worktree'de koşamıyor.** Worktree'de `.env` yok, `scripts/db-validate.sh` de çalıştırılabilir değil. Script'i değiştirmeden `~/tmp/t4/val/` altına kopyaladım, `.env` bağı ve `chmod +x` orada; komut o dizinden birebir koşuldu, rapor worktree `reports/`a kopyalandı. `diff -q` ile script'ler aynı. OBSERVED
4. **db-validate aynası davranış testine yetmiyor.** `db-build-baseline` çıktısında default 0/765, constraint 0, tetik 0 var. MEASURED. Bu yüzden davranış testi `scripts/kabul-db/build.sh`in kopyasıyla kurulan özel `egesut_t4_kabul` veritabanında koştu; orijinal `egesut_ovsync_kabul`e dokunmadım. Eski `tests/sql/*` başlıklarındaki "izole parite DB" tarifi bu aynada artık geçerli olmayabilir (UNKNOWN, koşmadım).

Canlı gövde drift: `gebelik_protokol_kontrol` son migration'dan yalnız bir yorum satırı farklı, `hizli_uygulama` birebir aynı. Ayna md5'leri canlıyla aynı. Stop koşulu değil. MEASURED

## Yapılan değişiklik

| | Ne | Kanıt |
|---|---|---|
| F1 | Rota 1. doz / Ademin / E Vit INSERT'leri `ROTA` / `ADEMIN` / `E_VIT` yazar | canlı gövdeyle diff yalnız bu satırlar |
| F2 | `uygulama_log.tarih = COALESCE((p_occurred_at AT TIME ZONE 'Europe/Istanbul')::date, CURRENT_DATE)` | test `F2-*` |
| Pencere | Tarayıcı değişmedi | `protokol_eksik_tara` migration'da yok |

## Test sonuçları

Komut: `psql "$K" -X -v ON_ERROR_STOP=1 -f tests/sql/protokol_etken_senkron_test.sql` (`$K` = `egesut_t4_kabul`, tam kopya: nesne farkı 0).

| Senaryo | Fix öncesi | Fix sonrası |
|---|---|---|
| F1-URETICI | RED (etken yok) | PASS `ROTA,ADEMIN,E_VIT` |
| A-ADEMIN-DONE (görev done → tarama) | RED `eksik→eksik` | PASS `eksik→tamamlandi` |
| A-ROTA-DONE | RED `eksik→eksik` | PASS, tek stok satırı |
| B-UYGULA-GOREV (`hizli_uygulama` → görev) | RED görev açık | PASS, `kapatan_ref` dolu |
| F2-TARIH-ISTANBUL | RED `10-30` | PASS `10-28` |
| F2-PENCERE-GEC-GIRIS | RED `eksik→eksik` | PASS `eksik→yok` |
| F2-BOS-VARSAYILAN | PASS | PASS |
| F2-MK7-SINIR | PASS | PASS |

Son iki satır fix öncesi de yeşil: değişmemesi gereken davranışı kilitler.

**Mutantlar (5/5 kırmızı):** `E_VIT`, `ROTA`, `ADEMIN` kaldırılınca ilgili senaryolar; `AT TIME ZONE` kaldırılınca `F2-TARIH-ISTANBUL` (`10-27`); `CURRENT_DATE - 1` ile `F2-BOS-VARSAYILAN`. MEASURED. Test `SET LOCAL TIME ZONE 'UTC'` ile koşuyor; yerel +03 dilimi gün hatasını örtüyordu.

**Onarım kuru koşusu** (`tests/sql/protokol_veri_onarim_kuru_test.sql`, atılan kopya, sahte hayvan + onarımın gerçek görev id'leri) PASS:

| Ölçüm | Önce | Sonra |
|---|---|---|
| etkensiz görev | 9 | 0 |
| 906 Rota kapalı | 0 | 1 |
| 191 açık görev | 0 | 2 |
| 907/906/207 tarama eksik | 9 | 1 (207 Rota) |
| `stok_hareket` / `uygulama_log` | 0 / 0 | 0 / 0 |

- İkinci koşum satır md5'ini değiştirmedi (idempotent).
- 191 sonradan meşru kapanırsa üçüncü koşum geri açmıyor.
- Aşı satırı yoksa son durum kapısı RAISE veriyor, 9 etken de geri alınıyor (fail-closed).

Canlı satırlar SELECT ile yeniden doğrulandı: açık/iptalsiz etkensiz 9 görev. 147'nin 2 etkensiz görevi `iptal=true`, kapsam dışı. MEASURED

## Sahip kararları: canlı ölçüm

### 906 Rota `20bd2c65`

Doğrudan UPDATE; `tamamlanma_tarihi` = 09-02 12:00 İstanbul (`_istanbulAnIso` öğlen çapası, gün her dilimde 09-02). Tetikler: `trg_gorev_parent_kapandi` çocuk iptal eder, bu görevin çocuğu 0; `trg_gorev_asip_iade` yalnız iptalde; `trg_degisim_log` iz yazar. Stok ve `uygulama_log` yazılmaz. MEASURED

### 191 Ademin `51a66c91` + E Vit `4647be58`: neden kapandı

Tek işlem, aynı an (`2026-06-04 09:48:13.238687+00`). Kullanıcı Ademin görevini (hedef 11-04, 153 gün erken) **Yeldif** stoğuyla tamamladı:

- **Ademin:** o günkü `gorev_tamamla` görevi doğrudan kapattı; `kapatan_ref` boş. `_gorev_dinle` DEĞİL. INFERRED (aynı `now()`, `notlar='Görev: 💊 SC Ademin uygulaması'`, gövde `20260604000001:160`).
- **E Vit:** o işlemin yazdığı `uygulama_log ae8c6dae` (Yeldif → `E_VIT`) tetiği çalıştırdı, `_gorev_dinle` tek açık E_VIT görevini tarih bakmadan kapattı; `kapatan_ref` dolu. CONFIRMED

**Yeniden kapanma riski: VAR, F4'e kadar sürer.** `_gorev_dinle`de alt sınır yok. 191'e hedeften önce girilen herhangi bir ADEMIN veya E_VIT uygulaması (Yeldif dahil) o görevi yine kapatır, uyarı da çıkmaz. Ölçüm: 191'de 06-04'ten bugüne bu tek uygulama var; olasılık düşük görünür ama engel yok. Ayrıca 06-04 Yeldif kaydı silinmedi; pencere dışında olduğu için uyarıyı bastırmaz. Onarım sonrası Ademin hemen `yaklasan` (kuru koşuda ölçüldü), E Vit 11-02'den itibaren görünür (INFERRED, `hedef-7`).

### 169 d39 PG: sahip ✕ basınca (SQL'e girmedi)

Canlı SELECT 2026-10-30:

- **Açık PG görevi: 0.** PG'li üç görev (d2, d11, d25) kapalı. ✕ bugün **hiçbir görevi iptal etmez**.
- 169'un diğer açık görevleri (53. Gün E Vit, kızgınlık takibi, Ovsynch-56 başlat) `etken_kod='PG'` değil, etkilenmez.
- **Süresiz yan etki kalıyor:** kayıt `(169, PG, DOGUM_PROTOKOL)` tarihsiz. Sonraki laktasyonlarda da d2/d25/d39 PG **uyarıları** çıkmaz. Görevler açılmaya devam eder. CONFIRMED (gövde), gelecek etkisi INFERRED.
- Yan gözlem: 169'da aynı tarihli (09-17) iki `dogum` satırı var; ikiz mi mükerrer mi bakmadım. UNKNOWN

## Sahibin bilmesi gerekenler

1. **F2 uyarıdaki tüm geç girişleri kurtarmaz.** Bayrak açıkken 7 günden eski tarih `PG_ZAMAN_GECERSIZ` ile reddedilir, PG olmayan stoklarda da. Hedefi 10-04 olan 207 Rota için geçmiş tarih girilemez; bugünkü tarihle girilirse backfill sonrası görev kapanır, uyarı da düşer (INFERRED, `B-UYGULA-GOREV` ile aynı yol). MK7 sınırı bu işte değişmedi. MEASURED (test `F2-MK7-SINIR`)
2. **F2 yalnız Protokol Uygula ekranında görünür.** `_gorevStokTamamlaSubmit` ve `_hayvanHizliUygulaKaydet` `p_occurred_at` göndermiyor; onlarda davranış değişmez. OBSERVED
3. **Bayrak kapalıyken** tarih yine yazılır ama 7 gün / 5 dk kontrolü yok (`assumption`, brief F2 koşulsuz). Prod bayrağı 1. MEASURED. MK5 yorumu güncellendi.
4. **Canlı gün hesabı:** boş tarih `CURRENT_DATE` kalıyor, TR 00:00-03:00 arası bir gün geride. Brief "bugünkü varsayılan" dedi; dokunmadım.
5. **Onarım apply yolu:** Mgmt API yalnız son SELECT'i döndürür. Önce/sonra sayımı için `psql -X -v ON_ERROR_STOP=1 -f` kullanılmalı.
6. **`.harness/references/domain-rules.md` §15 notu** ölü `ileri_gebe_gorev_kontrol`e atıf yapıyor (t2 ek 6). Yazılabilir listemde yok, güncellenmedi. Üç sahip kararı da veri kararı; yeni kural §'i açmadım.

Kapsam dışı, yalnız not: F3 (tetikleyici INSERT'te çalışmıyor), F4 (dismiss kapsamı, `_gorev_dinle` alt sınır). 207 Rota ve diğer 7 gerçek eksik onarımla kapanmaz, sahada uygulanmalı.

## Run kanıtı

Çalışma dizini: `~/tmp/t4/val` (bkz. denetim bulgu 3).

```
scripts/db-validate.sh supabase/migrations/20261030100001_protokol_etken_senkron.sql
```
rc: 0
```
════════════════════════════════════════════════
 SONUÇ: PASS
 Rapor: ~/tmp/t4/val/scripts/../reports/db-validation-b29b8781.md
 İzole DB'ler drop edildi: egesut_val_tmp egesut_val_tmp
════════════════════════════════════════════════
NOTICE:  database "egesut_val_tmp" does not exist, skipping
```

SHA-256 `b29b8781…` commit'teki dosyayla aynı. Squawk'ta 2 WARNING (`require-lock-timeout`, `require-statement-timeout`), FAIL değil. Fazlar A, B, C1, C2 PASS.

Davranış testi (kırmızı, fix öncesi aynı DB):
```
psql "$K" -X -v ON_ERROR_STOP=1 -f tests/sql/protokol_etken_senkron_test.sql
```
rc: 3
```
 A-ADEMIN-DONE        | RED   | eksik→eksik
 A-ROTA-DONE          | RED   | eksik→eksik stok_hareket=1
 B-UYGULA-GOREV       | RED   | eksik→eksik (f,)
 F1-URETICI           | RED   | 
 F2-BOS-VARSAYILAN    | PASS  | tarih=2026-10-30
 F2-MK7-SINIR         | PASS  | PG_ZAMAN_GECERSIZ:{...}
 F2-PENCERE-GEC-GIRIS | RED   | eksik→eksik
 F2-TARIH-ISTANBUL    | RED   | tarih=2026-10-30
psql:tests/sql/protokol_etken_senkron_test.sql:100: ERROR:  PROTOKOL ETKEN TEST RED: 6 / 8 senaryo kirmizi
```

Davranış testi (yeşil, migration uygulandıktan sonra):
```
psql "$K" -X -v ON_ERROR_STOP=1 -f tests/sql/protokol_etken_senkron_test.sql
```
rc: 0
```
 A-ADEMIN-DONE        | PASS  | eksik→tamamlandi
 A-ROTA-DONE          | PASS  | eksik→tamamlandi stok_hareket=1
 B-UYGULA-GOREV       | PASS  | eksik→tamamlandi (t,uygulama_log:1213934a-cd90-43bb-88e2-70e91a0bcfa4)
 F1-URETICI           | PASS  | ROTA/ILERI_GEBE_ASI,ADEMIN/ILERI_GEBE,E_VIT/ILERI_GEBE
 F2-BOS-VARSAYILAN    | PASS  | tarih=2026-10-30
 F2-MK7-SINIR         | PASS  | PG_ZAMAN_GECERSIZ:{...}
 F2-PENCERE-GEC-GIRIS | PASS  | eksik→yok
 F2-TARIH-ISTANBUL    | PASS  | tarih=2026-10-28
psql:tests/sql/protokol_etken_senkron_test.sql:100: NOTICE:  PROTOKOL ETKEN TEST PASS
```

Kuru koşu:
```
PGTZ=UTC psql "$DRY" -X -v ON_ERROR_STOP=1 -f tests/sql/protokol_veri_onarim_kuru_test.sql
```
rc: 0
```
psql:tests/sql/protokol_veri_onarim_kuru_test.sql:65: NOTICE:  VERI ONARIM KURU KOSU PASS
DO
```

Tekrar kurulum: `scripts/kabul-db/build.sh` içinde `DB=` adını değiştirip kopyadan koş; canlıya yalnız SELECT. Geçici dosyalar `~/tmp/t4/`.

## Koşulmayan

**Birim testleri koşulmadı.** Bellek havuzu kırmızıda kaldı (`ram-ultracode`, 25+ dk kuyruk, hook birim koşumunu kuyruk dışına bırakmıyor). Goal kabulünde yok, ama bilinmesi gerekir. Statik bakış: `hizli_uygulama`yı anan birim testlerin (`hizli-uygulama-guard`, `det-tazeleme-kanca`, `ovsync-api`, `pg-kapi-onay-tekrar`) hiçbiri migration okumuyor; `ovsync-takip-kapi` ve `protokol-senkron-cift-yon` yalnız eski, değişmeyen migration dosyalarını okuyor; `migration-sira-kilidi` yeni dosyaya takılmaz (yalnız Modify/Delete bakar). INFERRED, koşum değil. t3 aynı anda `tests/unit/` ve `js/` üzerinde çalıştığı için root tam süiti t3 sonrası koşmalı.

Bu report commit edilmedi (t1, t2 report'ları gibi untracked; mutlak yol taşıyor, repo public).

UI tarayıcıda koşulmadı (JS değişmedi). Prod'a yazma, push, merge yok. Ground truth'a dokunulmadı (apply sonrası regen, t3 yazıcısı).

## Kırıntılar

- measurement: 6/8 RED → 8/8 PASS, 5/5 mutant kırmızı, kuru koşu PASS.
- assumption: bayrak kapalıyken de `p_occurred_at` tarihe yazılır.
- assumption: `kapatan_ref` tam uuid.
- open_item: `_gorev_dinle` alt sınırı yok; 191 yeniden kapanabilir (F4).
- open_item: `gitnexus analyze --index-only` koşmadı (bellek kuyruğu 120 sn doldu); bu rolün değişikliği SQL + test, JS yok. Root t3 sonrası worktree için koşmalı.
- gate (dead-path): baseline aynasında default/constraint/tetik yok; davranış testi kabul kopyasına bağlandı.
