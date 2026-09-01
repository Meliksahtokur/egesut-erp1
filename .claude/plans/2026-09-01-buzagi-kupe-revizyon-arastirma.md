# Buzağı Küpe Bloğu (0-99) Dolması + Çıkmış Hayvan Küpe Kilidi — Araştırma Raporu

> Tarih: 2026-09-01 · Worktree: `idle/buzagi-kupe-revizyon` (`/home/melik/egesut-wt/buzagi-kupe-revizyon`)
> Tür: Araştırma + çözüm önerisi. **Hiçbir migration yazılmadı/deploy edilmedi** — SQL taslakları öneri amaçlıdır.
> Yöntem: ground truth SQL + js/ kod incelemesi (ana oturum + Explore subagent), canlı Supabase read-only sorguları, TURKVET mevzuat taraması.

## TL;DR

1. **Çıkmış hayvan küpe kilidinin tek nedeni yok sayılabilir bir detay değil, tasarım:** hayvan sürüden çıkınca satır `hayvanlar`'da kalıyor (`durum='Ölü'/'Satıldı'/...`), ve tüm küpe çakışma kontrolleri **`durum` filtresiz** tüm satırlara bakıyor. Ölen/satılan hayvanın işletme numarası sonsuza dek bloke.
2. **0-99 bloğu fiilen doldu:** canlıda blokta 81 küpe string'i var (65 aktif hayvan elinde, 16'sı çıkmış hayvanlara kilitli), hiç kullanılmamış yalnız ~19 numara kaldı. Doğum temposu ~6 buzağı/ay → boş numaralar **~3 ayda** biter. Yeni blok tahsisi kaçınılmaz; kilidin açılması ise tek başına ~2,5 ay daha kazandırır.
3. **Öneri:** (A) işletme küpesi teklik kontrolünü `durum='Aktif'` ile sınırla (devlet/TR küpesi kontrolleri **global kalmalı** — TURKVET'te numara hayvana ömür boyu), (B) buzağılara **300-399** bloğunu aç (canlıda tamamen boş; 200'ler kısmen, 900'ler ineklerde dolu), (C) savunma katmanı olarak aktifler üzerine partial unique index ekle — şu an DB'de hiç unique kısıt yok ve `p_padok_id`'li yeni RPC overload'larında küpe kontrolü **tamamen eksik**.

---

## 1. Bulgular — bloklama mekanizması (kod)

Zorlama katmanları ve durumları:

| # | Katman | Konum | Çıkmış hayvanı engelliyor mu? |
|---|--------|-------|------------------------------|
| 1 | JS blur ön kontrolü | `js/forms.js:26-57` `_kupeKontrolEt` → `kupe_musait_mi` RPC; submit bloğu `js/forms.js:65-68` | **Evet** (RPC filtresiz olduğundan) |
| 2 | RPC `kupe_musait_mi` | `99999999999999_ground_truth.sql:2114-2147` | **Evet** — `WHERE kupe_no = p_kupe_no AND (p_hayvan_id IS NULL OR id != p_hayvan_id)`, `durum` filtresi YOK |
| 3 | RPC `hayvan_ekle` (legacy 14-param) | GT:2170-2213, `kupe_musait_mi` çağırır → "İşletme küpesi zaten kayıtlı" | **Evet** (2'nin üzerinden) |
| 4 | RPC `dogum_kaydet` (buzağı kaydının ana yolu!) | GT:~9767 `SELECT id ... WHERE kupe_no = p_kupe OR devlet_kupe = p_kupe LIMIT 1` | **Evet** — kendi inline kontrolü, filtresiz |
| 5 | RPC `hayvan_guncelle` (legacy) | GT:2647-2649 `RAISE EXCEPTION 'İşletme küpesi zaten kayıtlı'` | **Evet** |
| 6 | **`p_padok_id`'li yeni overload'lar (h11, 2026-07-06)** | `20260706000006_h11_hayvan_yas_grup_validasyon.sql:22-92`; `js/ui.js:6803` `p_padok_id`'yi koşullu ekler | **Kontrol YOK** — padok_id gönderilince DB tarafında hiç küpe kontrolü çalışmıyor, tek savunma JS blur |
| 7 | DB unique index / constraint | — | **YOK** — `hayvanlar.kupe_no` üzerinde hiçbir kısıt yok (tek kupe unique'i `hayvan_override` PK'sı, GT:225) |

Yani: "130 öldü, 130'ı tekrar kullanamıyorum" şikayetinin somut kaynağı 2 ve 4 numaralı filtresiz sorgular. Ayrıca tablo, 6'daki boşluğu da gösteriyor: sunucu tarafı garanti zaten zayıf.

### Çıkış nasıl temsil ediliyor

- `cikis_yap(p_hayvan_id, p_cikis_tipi, ...)` (GT:10234-10288; 4 tip: satis/kesim/olum/kayip, `js/forms.js:686-715` `RPC_TIP_MAP`) satırı **yerinde UPDATE** eder: `durum` + `cikis_tipi/cikis_tarihi/cikis_sebebi/satis_fiyati` (GT:1953-1956 kolonlar). Açık görevleri iptal eder, protokolleri kapatır. **Satır asla tablodan çıkmaz; hayvan silme RPC'si ve hard-delete yok.**
- İstemci `hayvan_durum_view`'ın tamamını çekiyor (`js/api.js:399`) — çıkmışlar dahil. Küpe ile arama yapan her `find()` bu yüzden çıkmışlara da bakıyor (risk haritası §4).

### 0-99 konvansiyonu kodda mı?

**Hayır — tamamen saha alışkanlığı.** Hiçbir yerde aralık kontrolü, numara önerme, sequence yok. Tek iz: `index.html:1418` placeholder `"001"` (işletme küpesi) ve `index.html:1382` placeholder `"BZ-001"` (buzağı küpesi). Toplu giriş migration'ı `20260601000001_buzagi_toplu_giris.sql` 0-99 bloğunu buzağılara zaten kullanmış (bir kısmı `Satıldı`/`Ölü` olarak girmiş).

## 2. Bulgular — canlı veri (2026-09-01, read-only sorgu)

`hayvanlar`: **164 kayıt = 141 aktif + 23 çıkmış** (14 Satıldı, 8 Ölü, 1 Kesildi; bunların 4'ü test kaydı/"xx").

**0-99 buzağı bloğu doluluk:**

| Durum | Adet | Küpe numaraları |
|---|---|---|
| Aktif hayvanlarda | ~65 | 01, 02, 04, 06, 07, 11, 14, 17, 19, 23, 28, 31, 32, 36, 38, 43-49, 53-56, 59-62, 64, 65, 67-69, 71, 73-89, 91-98 (+ "002", "008", "015" string'leri) |
| **Çıkmış hayvanlara KİLİTLİ** | **16** | Satılan: 33, 34, 35, 40, 41, 42 · Ölen: 37, 50, 52, 57, 58, 63, 66, 70, 72, 90 |
| Hiç kullanılmamış (boş) | ~19 | 3, 5, 9, 10, 12, 13, 16, 18, 20, 21, 22, 24, 25, 26, 27, 29, 30, 51, 99 |

**Tempo hesabı:** 2025-09-15 (#33) → 2026-08-19 (#98) = 11 ayda ~66 buzağı ≈ **6/ay**.
- Kalan ~19 boş numara ≈ **3 ay** ömür.
- Kilit açılırsa +16 numara ≈ **+2,5-3 ay**.
- **Sonuç: kilidin açılması doğru ve gerekli, ama tek başına yetmez — yeni blok şart.**

**Boş blok taraması:** 300-399 **tamamen boş**. 200'ler kısmen dolu (201-208 düve), 900'ler ineklerde (900-907), 1000+ tek tük (2044, 4019, 5621, 5638, 5708, 5748).

**Veri hijyeni yan bulguları:**
- "Test buzağı cabbiş", "Test inek 2", "Test inek 3" **Aktif** durumda duran test kayıtları (ayrıca 3 satılmış test kaydı + "xx").
- Sayısal kimlik çakışması: "002" (inek) ile "02" (düve) string olarak farklı ama sahada ikisi de "2"; "015" benzeri. Normalizasyon kararı (baştaki sıfırlar) ayrı bir temizlik maddesi.
- `hayvan_override` tablosu (kupe_no PK + `pasif_mi`, GT:218-225) canlıda var ama **hiçbir kod kullanmıyor** — yeniden kullanım/pasifleştirme tasarımı için hazır bir kanca (veya dikkat edilecek boş bir tuzak).

## 3. Mevzuat (TURKVET) bağlamı

- Resmi kulak küpesi (TR numarası) **hayvana ömür boyu özgü**; mükerrer küpe numarası oluşması yönetmelikle önleniyor (18.11.2023 RG değişikliği, ilçe müdürlükleri duyuruları).
- Büyükbaş doğumdan itibaren **3 ay içinde** küpelenip TURKVET'e kaydedilmeli.
- Düşen/silinen küpe aynı hayvan için yenilenir; **numara başka hayvana verilemez**.
- **Sonuç:** `devlet_kupe` çakışma kontrolü **tüm satırlar (çıkmışlar dahil) üzerinde kalmalı** — oradaki global teklik doğru davranış. Kısıt sadece `kupe_no` (işletme numarası) için kaldırılmalı; işletme içi numaralandırma mevzuatta serbest.

Kaynaklar: hayvanbilgi.tarim.gov.tr (Küpe Sorgulama Hakkında), tarimorman.gov.tr il duyuruları (eskisehir/bursa/söke), 18.11.2023 RG küpeleme yönetmelik değişikliği özetleri.

## 4. Yeniden kullanım (recycle) risk haritası — küpe ile bakan yerler

Numara bir çıkmış + bir aktif hayvanda aynı anda varsa yanlış eşleşme riski:

| Yer | Konum | Not |
|---|---|---|
| Detay açma (küpe ile) | `js/ui.js:2451-2455` `openDetByKupe`, `js/ui.js:2046` | `find()` ilk eşleşmeyi alır — sıra bağlı |
| Form hayvan çözümleyicileri | `js/forms.js:169, 286, 427, 550, 974, 1010, 1077` (doğum/hastalık/tedavi/aşı/görev) | hepsi `find(a => a.kupe_no===...)` deseni |
| Global arama | `js/ui.js:1633-1680` (`#srch`) | liste filtresi, çift sonuç görünebilir (kabul edilebilir, hatta faydalı) |
| AI asistan detayı | `asistan_hayvan_detay` GT:518-531 `... OR kupe_no = p_kupe LIMIT 1` | rastgele biri döner |
| String bağlar (tarihsel) | `dogum.yavru_kupe` (GT:148), `tohumlama.buzagi_kupe` (GT:1927) | geçmiş kayıt donmuş bilgi; tarih+anne ile ayırt edilir. İyileştirme: `dogum`'a `yavru_id` FK eklenebilir |

Tüm log tabloları (tohumlama, dogum, gorev_log, islem_log, uygulama_log) hayvanı **id ile** bağlar → recycle geçmiş kayıtları **bozmaz**; risk yalnızca yukarıdaki "küpe string'iyle şimdi arama" noktalarında.

## 5. Çözüm önerileri

### A) Çıkmış hayvan küpe kilidini aç (katmanlı fix)

1. **`kupe_musait_mi`** — işletme küpesi sorgusuna `AND durum = 'Aktif'`; `devlet_kupe` sorgusu **global kalır**. Çakışan aktif yok ama geçmişte varsa `kupe_gecmis_id` + geçmiş `durum` döndür (UI bilgilendirsin, engellemesin):

```sql
-- TASLAK — öneri, uygulanmadı
SELECT id INTO v_kupe_cakisma FROM public.hayvanlar
 WHERE kupe_no = p_kupe_no AND durum = 'Aktif'
   AND (p_hayvan_id IS NULL OR id != p_hayvan_id) LIMIT 1;

SELECT id INTO v_kupe_gecmis FROM public.hayvanlar
 WHERE kupe_no = p_kupe_no AND durum IS DISTINCT FROM 'Aktif'
   AND (p_hayvan_id IS NULL OR id != p_hayvan_id) LIMIT 1;
-- dönüşe 'kupe_gecmis_id' ekle; musait = aktif çakışma yok && devlet çakışma yok
```

2. **`dogum_kaydet`** inline kontrolü aynı ayrımla: `(kupe_no = p_kupe AND durum='Aktif') OR devlet_kupe = p_kupe` (global).
3. **Partial unique index** (DB seviyesi garanti; 6 numaralı kontrolsüz overload deliğini de kapatır):

```sql
-- TASLAK — öneri, uygulanmadı
CREATE UNIQUE INDEX IF NOT EXISTS hayvanlar_kupe_no_key
  ON public.hayvanlar (kupe_no)
 WHERE durum = 'Aktif' AND kupe_no IS NOT NULL AND kupe_no <> '';
-- isim bilinçli: tests/unit/errorHandler.test.js:57-61 bu constraint adını zaten
-- "Bu kayıt zaten mevcut" mesajına map ediyor (schema'da hiç var olmamış — phantom)
```

Deploy öncesi mevcut aktif dublikasyon taraması şart (`002`/`02` string bazında farklı → index string karşılaştırır, sorun yok).
4. **h11 `p_padok_id` overload'larına** `kupe_musait_mi` çağrısı ekle (şu an sıfır kontrol).
5. **`hayvan_guncelle` (GT:7174 yeni sürüm)** sunucu tarafı kontrolü de yok — ekle (self-ID muaf).
6. **JS `_kupeKontrolEt`**: "⚠️ Bu küpe zaten kayıtlı (aktif hayvan)" vs "ℹ️ Bu numara geçmişte X'te kullanılmış — yeniden kullanılabilir" ayrımı. Doğum formundaki buzağı küpe alanına da blur ön kontrolü bağla (şu an sadece m-animal modalında).
7. **Küpe ile bulma çağrılarında aktif-öncelik**: `find()` sonuçlarını `durum==='Aktif'` önceleyecek şekilde değiştir (ui.js 2451/2046, forms.js 7 form, `asistan_hayvan_detay`'a `ORDER BY (durum='Aktif') DESC`).

### B) 0-99 bloğu doldu — numara planı

| Seçenek | Kazanç | Maliyet/risk |
|---|---|---|
| **Yeni blok: buzağı = 300-399** (önerilen) | Tamamen boş; 3 haneli saha alışkanlığı korunur; 400-499 merdiveni hazır | Hayır yok; kod değişikliği gerektirmez (konvansiyon) |
| 4 haneli 1000-1099 | Çok uzun ömür | Saha alışkanlığı, karışıklık (5621 gibi mevcut kayıtlar var) |
| Recycle (A fix'i) | 16 numara hemen + sürekli geri dönüşüm | Tek başına ~3 ay; A zaten yapılmalı |
| Otomatik öner (`sonraki_kupe_oner()` RPC + formda "Öner") | Yanlış/kilitli numara denemeleri biter | Nice-to-have, küçük iş |

Önerilen paket: **A (1-5) + buzağı bloğu 300-399 + domain-rules.md'e numara planı yazımı.** JS mesaj farkı (A6) ve aktif-öncelik sweep (A7) ikinci adım; otomatik öneri opsiyonel üçüncü adım.

### Karar noktaları (kullanıcı)

1. Yeni buzağı bloğu **300-399** mü, 1000+ mı?
2. Recycle politikası: çıkış sonrası **hemen** mi kullanılabilir (öneri: hemen, uyarıyla), yoksa bekleme süresi mi?
3. Aktif test kayıtları ("Test buzağı cabbiş", "Test inek 2/3") çıkarılsın mı? (Sürü listelerini ve istatistikleri kirletiyorlar.)
4. "002"/"02"/"015" sıfır-normalizasyonu yapılsın mı (string kimlik netliği için önerilir; migration + UI doğrulama gerektirir)?

## 6. Uygulama öncesi zorunlu adımlar (hatırlatma)

- `gitnexus_impact` — `kupe_musait_mi`, `hayvan_ekle`, `dogum_kaydet`, `_kupeKontrolEt` upstream blast radius (kod yazım anında).
- Migration canlıya **kullanıcı deploy emriyle** gider (`supabase_migrate`); bu rapondaki SQL'ler taslaktır.
- E2E kilidi: "ölen hayvanın küpe nosuyla yeni buzağı kaydı başarıyla açılır + doğum kaydı yavru_kupe string'i korunur" senaryosu.

## 7. Kanıt dizini (özet)

- GT = `supabase/migrations/99999999999999_ground_truth.sql`
- Kontrol noktaları: GT:2114 (kupe_musait_mi), GT:9767 (dogum_kaydet inline), GT:2647 (legacy guncelle), `20260706000006_h11_...sql:22-92` (kontrolsüz overload), `js/forms.js:26-68` (blur + submit bloğu)
- Çıkış: GT:10234 (cikis_yap), GT:1953-1956 (cikis kolonları), `js/forms.js:686-715`
- Görünüm/veri: `js/api.js:399` (hayvan_durum_view tam çekim), GT:8155 (suruden_cikti etiketi)
- Kupe-ile-bakış: `js/ui.js:2451,2046,1633-1680`; `js/forms.js:169,286,427,550,974,1010,1077`; GT:518 (asistan)
- String bağlar: GT:148 (dogum.yavru_kupe), GT:1927 (tohumlama.buzagi_kupe)
- Phantom constraint: `tests/unit/errorHandler.test.js:57-61`
- Testler: `tests/unit/forms-validation.test.js:133-170` (blur kontrolü) — recycle semantiği için test yok
- Canlı sayımlar: 2026-09-01 tarihli `hayvanlar` sorguları (164/141/23; blok dağılımı §2)
