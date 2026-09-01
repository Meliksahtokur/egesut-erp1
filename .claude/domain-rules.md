# EgeSüt ERP — Veteriner & Hayvancılık Domain Kuralları

Bu dosya, EgeSüt ERP'nin iş kurallarını ve veteriner/hayvancılık domain bilgisini belgeler.
Yeni özellik geliştirirken veya mevcut kodu değiştirirken bu kurallara uyulmalıdır.

> **2026-09-01 revizyonu (Idle-A):** docs denetimi `.claude/idle-reports/2026-08-31-docs-tutarlilik.md`
> §2.2'deki 8 çelişki ve §2.3'teki 8 bayatlık bu sürümde düzeltildi — gerekçeler dosya sonundaki
> **Düzeltme Günlüğü**'nde. Kanonik imza kaynağı: `.claude/schema-snapshots/2026-08-31-live-schema-imzalar.md`.

---

## 1. Hayvan Kimliği

- Her hayvanın **işletme küpesi** (`kupe_no`) ve/veya **devlet küpesi** (`devlet_kupe`) vardır.
- Tohumlama ve doğum kayıtlarında `hayvan_id` alanı bazen `id` (UUID), bazen `kupe_no` değeri olarak saklanmış olabilir. Arama yaparken her ikisini de kontrol et: `a.id === x || a.kupe_no === x`.
- Buzağı doğduğunda küpesi (`yavru_kupe`) anında sisteme girilir; küpeleme ayrıca görev olarak da takip edilir.

### Küpe Numara Planı (2026-09-01 — spec `.claude/specs/2026-09-01-buzagi-kupe-revizyon-kararlar.md`)

| Kural | İçerik |
|---|---|
| **Erkek yeni doğum** | Sayısal küpe **500-599 zorunlu** (JS sert engel `submitBirth` + RPC `dogum_kaydet` — çift katman). Sayısal OLMAYAN küpe (ör. `BZ-001`) serbest. |
| **Manuel erkek kaydı** | 500-599 dışı sayısal küpe → **uyarı** (engel değil, K5'in yumuşak ayağı). |
| **Dişi** | **1-999 içinde 5xx hariç her numara serbest.** Öneri listesi küçükten büyüğe (sıra disiplini teşviki, K10). |
| **Öneri havuzu (K6)** | Erkek → yalnız 500-599; dişi → 1-999 \ 500-599. Doluluk **sayısal uzayda**: `"02"` ve `"002"` aynı 2'yi işgal eder sayılır. Yalnız **Aktif**lerin numaraları dolu. UI: `bosKupeOner()` (js/config.js), 💡 butonu `b-kupe`/`a-kupe` yanında. |
| **Recycle (K1)** | Çıkmış (Ölü/Satıldı/Kesildi/Kayıp) hayvanın **işletme küpesi** çıkıştan hemen sonra yeniden kullanılabilir — loglar `id` ile bağlı olduğundan geçmiş kayıtlar bozulmaz. |
| **Devlet küpesi (K2)** | TURKVET: hayvana ömür boyu — kontrol **GLOBAL** kalır, çıkmışta dahi çakışırsa red. |
| **Çift katman (K3)** | DB: partial unique index `hayvanlar_kupe_no_key` (`WHERE durum='Aktif' AND kupe_no IS NOT NULL AND kupe_no <> ''`) + `kupe_musait_mi` aktif-filtre + h11 `hayvan_ekle`/`hayvan_guncelle` overload'larında kontrol. |
| **Sıfır-trick (K9)** | `"002" ≠ "02"` string farkı **bilinçli özellik** — normalizasyon YASAK, mevcut stringlere dokunulmaz. |
| **Mevcut erkekler (K12)** | Kural yalnız **yeni** kayıtlar; mevcut aktif Erkek 5xx dışı küpelere DOKUNULMAZ. Sürüden çıkınca numaraları havuza döner. |
| **Aktif-öncelik arama (K7)** | Aynı küpe string'i geçmişte çıkmışta + bugün aktifte varsa arama/detay/asistan **aktif** hayvanı bulur (`hayvanByKupeRef` js/ui.js; `asistan_hayvan_detay` ORDER BY aktif DESC). |

**Deploy durumu:** canlıda aktif (2026-09-01, Management API deploy). Bağlam: `.claude/specs/2026-09-01-buzagi-kupe-revizyon-kararlar.md`; RPC özetleri `rpc-reference.md`.

---

## 2. Hayvan Grupları ve Padok Eşlemeleri

Grup → padok ataması `js/config.js:GRUP_PADOK` sabitiyle yönetilir (DB `grup_padok_eslem`'den yüklenir,
sabit fallback'tir). Bir grup yalnızca belirli padoklara atanabilir. **Canlıda 9 grup** (2026-09-01 doğrulama):

| Grup | Padok |
|---|---|
| Sağmal (Laktasyonda) | Sağmal Padok |
| Sağmal (Kuru) | Kuru/Gebe Padok |
| Gebe Düve | Kuru/Gebe Padok |
| Gebe İnek | Kuru/Gebe Padok |
| Düve (Büyük) | Düve Padok (Büyük) |
| Düve (Küçük) | Düve Padok (Küçük) |
| Süt İçen Buzağı | Buzağı Padok (Süt İçenler) |
| Sütten Kesilmiş Buzağı | Buzağı Padok (Sütten Kesilmiş) |
| Besi | Besi Padok (Erkek) veya Besi Padok (Dişi) |

**Kural:** Erkek hayvan Sağmal / Kuru / Gebe grubuna girmez. Kontrol **iki katmanda** yapılır:
frontend (app.js:280-304 grup filtresi) + **tablo trigger'ı** `_guard_hayvanlar_cinsiyet_grup`
(hayvanlar BEFORE INSERT/UPDATE, 2026-08-31, migration 20260831000003) — REST/RPC ayrımı olmaksızın
yakalar, `RAISE EXCEPTION 'Erkek hayvan Sağmal/Gebe grubuna eklenemez'`. RPC gövdesinde ayrıca yaş-grup
kontrolü vardır (`hayvan_ekle`/`hayvan_guncelle`).

---

## 3. Yaşa Göre Grup Sınırları

Hayvan kaydında yaş zorunlu değil; biliniyorsa aşağıdaki kurallar uygulanır.

### Dişi

| Yaş | İzin verilen gruplar |
|---|---|
| 0–180 gün | Süt İçen Buzağı, Sütten Kesilmiş Buzağı |
| 181–365 gün | Düve (Küçük) |
| 366–730 gün | Düve (Büyük), Düve (Küçük) |
| 730+ gün veya yaş bilinmiyor | Sağmal, Kuru, Gebe Düve, Gebe İnek, Düveler |
| Tohumlama geçmişi var | + Gebe Düve / Gebe İnek seçenekleri eklenir |
| Doğum veya abort geçmişi var | Yalnızca Sağmal (Laktasyonda), Sağmal (Kuru) |

### Erkek

| Yaş | Grup |
|---|---|
| 0–180 gün | Süt İçen Buzağı, Sütten Kesilmiş Buzağı |
| 180+ gün | Besi |

> **Not (2026-09-01):** eski tablolardaki 75. gün buzağı/sütten-kesilmiş ayrımı **kodda uygulanmıyor** —
> app.js:287-298 her iki grubu da 0-180 gün penceresinde sunar; sütten kesme tetikleyicisi 60. günde
> ateşlenir (`_ayar('sutten_kesme_gun',60)`). 75 gün ayrımı **öneridir, uygulanmaz**.

**Kural:** 12 aydan (365 gün) büyük hayvan buzağı grubuna eklenemez. Frontend ve backend RPC'de kontrol edilir.

**Kural:** 6 aydan (180 gün) büyük "Süt İçen Buzağı" grubuna eklenemez.

---

## 4. Tohumlama (İnseminasyon)

### Ön Koşullar (backend — `tohumlama_kaydet` RPC + `tohumlama` tablo guard'ı)

- Hayvan `durum = 'Aktif'` olmalı
- Cinsiyet `Dişi` olmalı (RPC + `_guard_tohumlama_yas_cinsiyet` tablo trigger'ı, 2026-08-31)
- Yaş ≥ 12 ay (365 gün) (RPC + aynı tablo trigger'ı)
- Aktif gebelik (`sonuc = 'Gebe'`) olmamalı
- Tohumlama tarihi ileri tarih olamaz
- **VWP (voluntary waiting period) ≥ 55 gün:** son doğumdan VEYA son aborttan (`abort_tarihi`) geçen süre. Dolmadıysa RPC `VWP_VIOLATION:gun:55` (doğum) / `ABORT_VWP_VIOLATION:gun:55` (abort) RAISE eder; frontend confirm ile `p_vwp_override=true` geçer. Abort çapası 2026-08-30'da eklendi — abort, postpartum korumasına dahildir; ayrı pencere motoru YOKTUR.

### Tohumlama Sonuç Durumları (durum makinesi)

```
[Bekliyor] ──→ [Gebe]
    ↓               ↓
  [Boş]        [Doğum Yaptı]
                   [Abort]
```

| Sonuç | Anlamı | İzin verilen geçişler |
|---|---|---|
| Bekliyor | Tohumlama yapıldı, sonuç bekleniyor | → Gebe, → Boş |
| Gebe | Gebelik onaylandı | → Doğum Yaptı (RPC), → Abort (RPC) |
| Boş | Tohumlama tutmadı | → Bekliyor (hatalı kayıt düzeltme) |
| Doğum Yaptı | Doğum gerçekleşti | Değiştirilemez |
| Abort | Erken doğum / gebelik kaybı | → Gebe (yalnız `geri_al` ile, ABORT_KAYDI snapshot restore — toh-det modalı / geçmiş panelindeki "↩ Abort İşlemini Geri Al") |

**Kural:** `Gebe` ve `Doğum Yaptı` durumundaki kayıtlar frontend üzerinden doğrudan değiştirilemez. Tüm kritik geçişler RPC üzerinden yapılmalıdır.

### Abort Akışı (2026-08-30 güncel)

- Abort `tohumlama_abort(p_tohumlama_id, p_notlar?, p_abort_tarihi?)` ile kaydedilir; `abort_tarihi` kolonu (default bugün, geriye dönük girilebilir) VWP çapasıdır.
- Abort yapan hayvana 55 gün dolmadan tohumlama denemesi `ABORT_VWP_VIOLATION` + confirm uyarısı verir ("Bu hayvan abort yaptı").
- **Aktif vaka (hastalık/tedavi) hayvanı sessiz takipten DÜŞÜRMEZ** — v_eligible'da vaka filtresi yoktur.
- `geri_al` ile abort geri alınabilir (kayıt tekrar Gebe olur); `tohumlama_geri_al` ise kaydı SILER — ikisi karıştırılmamalı.

### Sessiz Hayvan Takibi (2026-08-31 güncel — v_eligible ankraj fix'i)

- **Sayaç ankrajı = en yeni üreme event'i** (20260831000001): kızgınlık, tohumlama, abort (`tohumlama.abort_tarihi`), doğum (`dogum` tablosu veya `tohumlama.dogum_tarihi`). Gebe kalıp doğum yapan/abort yapan ineğin sayacı **eski tohumlama tarihinden sayılmaz** — doğum/abort çapası sayaçları sıfırlar.
- **Listeye giriş:** en yeni event 55 günden eskiyse hayvan sessiz listededir; doğum/abort sonrası ilk 55 gün listede görünmez (v_eligible WHERE).
- **Event'siz düveler** (20260831000002): sayaç ham yaş değil, **13 aylık tohumlama uygunluk noktasından** sayılır; RPC `p_min_gun=55` ile düve listeye **13 ay + 55 gün**de girer. 13 aydan önce tohumlama yapılmadığı için genç düve listede görünmez.
- **"Hiç kayıt yok" (9999):** ne event'i ne doğum bilgisi olan hayvanlarda `sessiz_gun` NULL'dur; RPC `COALESCE(...,9999)` ile 9999 döner. UI'da (dashboard bandı + modal) **en altta** sıralanır (bb4ea92) — sentinel-son sıralama her iki yüzeyde de client-side yapılır.
- `v_eligible` SADECE sessiz akışlarını besler (listele/reconcile/stat); tohumlama form uygunluk listesi client-side `_eligibleHayvanlar()`'dır — view'dan bağımsız.
- Bilinen tutarsızlık: `stat_suru_ozet` sessiz sayacı `sessiz_gun >= 55` (NULL hariç), liste ise 9999'ları içerir → istatistik, listeden "hiç kayıt yok" kadar düşük görünür (henüz kapatılmadı).

### Gebelik Süresi

- Tahmini doğum = tohumlama tarihi + **280 gün**
- 21. gün gebelik kontrolü görevi otomatik oluşturulur
- 35. gün gebelik kontrolü görevi otomatik oluşturulur

### Tohumlama ve Sperma

- Sperma stoku `SPERMA_LISTESI` sabitinde + DB'deki özel kayıtlarda tutulur
- `tohumlama_kaydet` RPC sperma stoku düşer (varsa)
- Baba bilgisi (`baba_bilgi`): tohumlama kaydındaki `sperma` alanı, buzağı doğduğunda otomatik aktarılır
- `deneme_no`: her başarısız tohumlama sonrası bir artar; RPC otomatik hesaplar

---

## 5. Doğum Kaydı

### `dogum_kaydet` RPC'nin Yaptıkları (ilk yavru: 17 görev — 10 anne + 7 buzağı; 2.+ yavru: yalnız 7 buzağı görevi)

1. `dogum` tablosuna kayıt ekler
2. Buzağıyı `hayvanlar` tablosuna ekler (grup: Süt İçen Buzağı, padok: **Buzağı Padok (Süt İçenler)**)
3. Buzağıya anne ırkı atanır
4. Buzağıya baba bilgisi (`p_baba`) yazılır
5. Annenin açık tohumlama kaydını `sonuc = 'Doğum Yaptı'` olarak kapatır
6. Anneye doğum sonrası ilaç protokolü görevleri oluşturur (10 görev, Presynch-14 şeması):
   - Doğum günü: Oksitosin + Ademin + Kalsiyum (3 ayrı görev)
   - 2. Gün: PG
   - 25. Gün: PG
   - 39. Gün: PG
   - 53. Gün: Ademin + **E Vitamini** (etken_kod `E_VIT`; "Yeldif" bir ürün adı değil E vit sınıfıdır)
   - 58–63. Gün: Kızgınlık takibi
7. Buzağıya ilk gün bakım görevleri oluşturur (6 alt görev):
   - Kolostrum (ilk 2 saat)
   - Göbek kordonu dezenfeksiyonu (iyot)
   - Küpeleme
   - Ademin (1. gün)
   - Maya (1. gün)
   - Probiyotik (1. gün)

### İkiz / Çoklu Doğum (2026-09-01, migration 20260901000001 — spec: docs/2026-09-01-ikiz-dogum-modeli-spec.md)

- `dogum.olay_id uuid`: 1 doğum olayı = 1 olay_id; her buzağı ayrı `dogum` satırı (1 satır = 1 buzağı)
- **Olay penceresi 10 gün:** aynı annede pencere içinde yeni doğum girilirse aynı olaya bağlanır → dönüş `coklu_dogum: true, yavru_sirasi`; yalnız 7 buzağı görevi açılır
- **Anne görev guard'ı 60 gün:** yakın doğum varsa 10 anne görevi + tohumlama kapatma + grup/padok + protokol + BESLEME iptali ASLA tekrarlanmaz (kullanıcı kuralı: "birinci yavrunun hiçbir anne görevi tekrarlanmaz")
- Aynı (anne_id, yavru_kupe) ikinci kez gönderilemez — RPC reddeder (typo → yanlış ikiz engeli)
- Kardeş tanımı (frontend, `_kardeslerBul`): aynı `anne_id` + aynı `dogum_tarihi` → hayvan kartında `Anne:` bloğu altında kardeş satırı
- UI: doğumdan sonraki 10 günde anne kartında "➕ Bu doğuma yavru ekle" butonu (anne/tarih/baba prefilled modal; `ikinciYavruAc`)
- `dogum_sayisi` = `COUNT(DISTINCT olay_id)` (`hayvan_belirsiz_ureme_listele` + `v_ureme_dongusu`); buzağı sayısı = satır sayısı

### Doğum Kuralları

- Doğum tarihi ileri tarih olamaz — frontend (forms.js:155) + **tablo trigger'ı** `_guard_dogum_ileri_tarih`
  (dogum BEFORE INSERT/UPDATE, 2026-08-31, migration 20260831000003). `dogum_kaydet` RPC gövdesinde
  ayrıca kontrol yoktur; kural tablo seviyesinde uygulanır.
- Anne sistemde kayıtlı ve aktif olmalı
- Doğum yapmış hayvan artık "inek" sayılır → grup seçenekleri Sağmal/Kuru ile sınırlı
- Baba bilgisi: annenin aktif tohumlama kaydında sperma varsa otomatik doldurulur; yoksa serbest metin

---

## 6. Gebelik ve Abort

- **Abort** (erken doğum / gebelik kaybı): yalnızca `sonuc = 'Gebe'` olan kayıt için yapılabilir
- Abort kaydı `islem_log`'a `ABORT_KAYDI` tipiyle yazılır (üretici: `tohumlama_abort` RPC'si — trigger UPDATE kolu 2026-08-30'dan beri sessiz)
- Abort sonrası hayvan tekrar tohumlanabilir; `deneme_no` bir artar
- Hayvan abort veya doğum yapmışsa artık "düve" değil "inek" sayılır

---

## 7. Kızgınlık Takibi

- Kızgınlık kaydı için yaş ≥ 12 ay kontrolü yapılır (erkek kontrolü de var)
- Normal kızgınlık döngüsü **21 gün**
- Doğum sonrası 58–63. günde kızgınlık takip görevi otomatik oluşturulur
- `kizginlik_log` tablosunda saklanır; `islem_log`'a `KIZGINLIK` tipiyle yazılır

---

## 8. Sağlık Vakaları (Cases)

### Hastalık Kategorileri (config.js `HASTALIK_KAT` — canlıdaki tam liste)

| Kategori | Hastalıklar |
|---|---|
| Meme | Mastit, Subklinik Mastit, Klinik Mastit |
| Üreme | Metrit, Endometrit, Pyometra, Retensiyo Sekundinarum, Kistik Over, Anoestrus |
| Metabolik | Hipokalsemi (Süt Humması), Ketozis, Ruminal Asidoz, Timpani, Şirden Deplasmanı |
| Sindirim | Ruminal Asidoz, Timpani, Şirden Deplasmanı (Metabolik ile kesişir) |
| Ayak | Topallık (Dermatit), Topallık (Laminit), Beyaz Çizgi Hastalığı, Tırnak Yarası |
| Solunum | Pnömoni |
| Buzağı | Buzağı İshali, Buzağı Göbek İltihabı, Neonatal Zayıflık |
| Diğer | (serbest) |

### Vaka Kuralları

- Bir hayvanın aynı anda birden fazla aktif vakası olabilir
- Vaka `status`: `active` veya `closed`
- Lokasyon seçenekleri Meme/Ayak/**Göz** kategorilerinde sunulur (config.js `LOKASYON_KAT`); ancak
  **zorunluluk yaptırımı yok** — form boş geçilebilir, backend'de RAISE yok. Lokasyon istenen-bilgi
  düzeyindedir,sert kural değildir.

---

## 9. Sütten Kesme

- **Bireysel:** tek hayvan için, onay tarihi belirlenerek yapılır (`buzagi_sutten_kesme_onayla`)
- **Toplu:** birden fazla süt içen buzağı aynı anda kesilebilir (limit 200, partial success)
- Sütten kesme yalnızca `suttten_kesme_tarihi` yazar; grup/padok senkronu BEFORE trigger ile olur.
  **`tohumlama_durumu` yazılmaz** — "tohumlanabilir" flag yaklaşımı terk edildi (2026-06-20 revizyonu);
  tohumlama uygunluğu `v_eligible`/`_eligibleHayvanlar()` üzerinden hesaplanır.

---

## 10. Çıkış Kaydı (Hayvan Sistemden Çıkışı)

- Çıkış nedenleri: Satış, Ölüm, Kesim, Kayıp (`p_cikis_tipi`: satis/olum/kesim/kayip)
- Çıkış kaydında hayvan `durum` değerleri: `Satıldı` / `Ölü` / `Kesildi` / `Kayıp`
  (kod tabanında `'Pasif'` değeri **yoktur** — davranışsal sonuç aynıdır: hayvan listelerde görünmez,
  tohumlama/doğum kaydı yapılamaz)
- Çıkış sonrası açık görevleri `trg_hayvan_cikis_gorev_iptal` trigger'ı iptal eder

---

## 11. İşlem Günlüğü (islem_log)

Her kritik işlem `islem_log` tablosına yazılır. Tip değerleri (kodda üretilen tam liste):

| Tip | Tetikleyen |
|---|---|
| `TOHUMLAMA` | Tohumlama INSERT |
| `TOHUMLAMA_OTOMATIK_BOS` | Otomatik boş sayma (stale temizlik) |
| `TOHUMLAMA_GUNCELLENDI` | *(2026-08-30'tan beri ÜRETİLMİYOR — trigger UPDATE kolu sessiz, 20260830000030)* |
| `VWP_OVERRIDE` | VWP confirm ile aşıldığında |
| `ABORT_KAYDI` | `tohumlama_abort` RPC'si (trigger değil) |
| `DOGUM_KAYDI` | `sonuc='Doğum Yaptı'` UPDATE veya dogum INSERT |
| `HAYVAN_EKLENDI` | Hayvan INSERT |
| `HAYVAN_GUNCELLENDI` | Hayvan UPDATE |
| `HASTALIK_KAYDI` | Vaka INSERT |
| `HASTALIK_GUNCELLENDI` | Vaka güncelleme |
| `KIZGINLIK` | Kızgınlık kaydı |
| `SUTEN_KESME` | Sütten kesme işlemi |
| `padok_degisim` | Padok transferi |
| `TEDAVI_GUNCELLENDI` | Tedavi güncelleme |
| `GOREV_EKLENDI` / `GOREV_GUNCELLENDI` | Görev yaşam döngüsü |
| `VAKA_ACILDI` | Vaka açılışı |

`ref_id` alanı migration 016+ sonrası kayıtlarda dolu; eski kayıtlarda `snapshot` içinde aranmalı.

---

## 12. Görev Sistemi (gorev_log)

- `gorev_tipi` değerleri (CHECK kısıtı **yok** — serbest metin; kodda üretilenler):
  `ILAC`, `BUZAGI_BAKIM`, `GEBELIK_KONTROL` (eski `TOHUMLAMA_HAZIRLIK`'ın yerini aldı, 20260830000010),
  `ILERI_GEBE`, `ILERI_GEBE_ASI`, `BESLEME`, `SUTTEN_KESME`, `PADOK_DEGISIM`, `TOHUMLAMA_PLANLI`,
  `TEDAVI_GUN`, `TEDAVI_SEANS`, `VETERINER_KONTROL`, `KIZGINLIK_TAKIP`, `DIGER`
- Ana görev (`parent_id = NULL`) + alt görevler (`parent_id` dolu); parent kapanınca çocuklar `trg_gorev_parent_kapandi` ile iptal olur
- `tamamlandi = false` → bekleyen görev
- `hedef_tarih` geçmişte kalan ve tamamlanmamış görevler gecikmiş sayılır
- Görevler RPC'ler tarafından otomatik oluşturulur; elle silinmemelidir
- Zincir tipler (BESLEME, BUZAGI_BAKIM, TEDAVI_GUN, ILERI_GEBE_ASI) orphan temizlikten muaf

---

## 13. Kritik İş Kuralları Özeti

> Bu kurallar frontend'de bypass edilemez; backend RPC'lerinde ve/veya tablo trigger'larında da kontrol edilir.

1. **Erkek hayvan tohumlanamaz** (`_guard_tohumlama_yas_cinsiyet` tablo trigger'ı + RPC), **sağmal/gebe grubuna girilemez** (`_guard_hayvanlar_cinsiyet_grup` tablo trigger'ı + frontend)
2. **12 aydan küçük hayvan tohumlanamaz, kızgınlık kaydı yapılamaz**
3. **Aktif gebeliği olan hayvan tekrar tohumlanamaz**
4. **Tohumlama tarihi ileri tarih olamaz (RPC); doğum tarihi ileri tarih olamaz (frontend + `_guard_dogum_ileri_tarih` tablo trigger'ı, 2026-08-31)**
5. **12 aydan büyük hayvan buzağı grubuna eklenemez**
6. **`Gebe` ve `Doğum Yaptı` tohumlama kayıtları direkt değiştirilemez — RPC kullan**
7. **Doğum veya abort geçmişi olan dişi hayvan artık düve değil inek (Sağmal/Kuru)**
8. **Tohumlama verisi yalnızca RPC üzerinden yazılmalı; direkt REST PATCH, RPC validation'ı bypass eder.**
   *(Nüans, 2026-08-31: erkek/yaş kuralları tablo trigger'ı ile REST'te de yakalanır; VWP ve aktif gebelik
   kontrolleri yalnız `tohumlama_kaydet` RPC gövdesindedir — RPC'siz INSERT bu iki kontrolü atlar.)*

---

## 14. Multi-Tenancy ve farm_id Disiplini (Faz 2 hazırlığı)

**Durum:** Sistem KASITLI tek-tenant (RLS `USING(true)`). Multi-tenant (`farm_id` + `profiles` + JWT) Faz 2'ye planlı; kaynak `docs/superpowers/specs/2026-06-14-login-auth-gate-design.md` §İzolasyon.

**Sabit:** `REAL_FARM_ID = 400b9107-a85e-4126-af2c-fd7fe73fb68e`. Mevcut tüm gerçek veri bu çiftliğe ait sayılır. Helper: `public.current_farm_id()` (STABLE SQL — şimdilik `REAL_FARM_ID` döner, Faz 2'de JWT/`profiles`'tan okur).

**Kapsam:** Bu disiplin YALNIZCA YENİ nesnelere uygulanır. Mevcut tablo + fonksiyonlar bu görevin kapsamı DIŞINDA — Faz 2'de retrofit edilir.

| Kural | Uygulama |
|---|---|
| Yeni tenant-scoped tablo | `farm_id uuid NOT NULL DEFAULT '400b9107-a85e-4126-af2c-fd7fe73fb68e'` kolonu + `(farm_id, ...)` index. FK YOK (`farms` Faz 2'de). |
| Yeni yazma fonksiyonu (tenant tablo INSERT) | `farm_id = public.current_farm_id()` damgası. |
| Yeni RLS policy | `USING(true)` KALSIN — Faz 2'de `USING(farm_id = public.current_farm_id())`'ye flip. |
| Global katalog / sistem | `farm_id` ALMAZ (bkz `.claude/farm-id-discipline.md` §4). |
| Emin değilsen | Operasyonel sürü verisi = tenant-scoped varsay; katalog = global. |

**Neden:** Faz 2'de retrofit yükünü bugünden bugüne düşürür; yeni yazılan her şey zaten "farm_id-hazır".

**Detay:** `.claude/farm-id-discipline.md` — kanonik kural belgesi (DRY: burada kural gövdesini tekrar etme).

---

## Düzeltme Günlüğü (2026-09-01, Idle-A — 16 madde)

Kaynak: `.claude/idle-reports/2026-08-31-docs-tutarlilik.md` §2.2 (çelişki) + §2.3 (bayatlık).
"Doğru taraf" gerekçesiyle işlendi; şüpheli olanda kaynak değiştirilmedi, aşağıda gerekçe var.

| # | Bölüm | Eski | Yeni | Doğru taraf + kanıt |
|---|---|---|---|---|
| ❌1 | §5 | 14 görev | 16 görev | Kod — 20260730000002:407-417 `"gorev_sayisi",16`; Oksitosin/Ademin/Kalsiyum 3 ayrı görev |
| ❌2 | §5 | PG d11 | d2·d25·d39 (Presynch-14) | Kod — 20260730000002:412-414; d11 20260628000001 ile kaldırıldı |
| ❌3 | §5 | d53 "Ademin+Yeldif", d54 "Yeldif" | d53 Ademin + E Vitamini; d54 görevi yok | Kod — 20260730000002:415-416,358-359, etken_kod E_VIT (commit 978e018); Yeldif ürün değil sınıf |
| ❌4 | §5 | Buzağı Ahırı | Buzağı Padok (Süt İçenler) | Kod — 20260730000002:401; 20260326000026:7 |
| ❌5 | §9 | sütten kesme `tohumlama_durumu='tohumlanabilir'` yazar | yalnız `suttten_kesme_tarihi` yazar | Kod — 20260620000003:47 (commit 6e41b94); flag yaklaşımı terk edildi |
| ❌6 | §10 | `durum='Pasif'` | Ölü/Satıldı/Kesildi/Kayıp değerleri | Kod — 20260706000003:191-201; 'Pasif' 0 grep; davranışsal sonuç (listelerde görünmez) değişmedi |
| ❌7 | §2/§13 | "backend ve frontend her ikisi de kontrol eder" (RPC'lerde yoktu — kod eksiğiydi) | Tablo trigger'ı 2026-08-31'de eklendi: `_guard_hayvanlar_cinsiyet_grup` (20260831000003, canlıda deploy'lu — snapshot envanteri) | Kod — guard migration'ı denetim sonrası canlıya gitti; doc artık gerçek durumunu yansıtıyor |
| ❌8 | §14 | `'400b9107-a85e-4126-fd7fe73fb68e'` (geçersiz UUID) | `400b9107-a85e-4126-af2c-fd7fe73fb68e` | Migration — 20260701214717:12; tipografi hatası |
| ⚠️1 | §3 | 0-75 / 76-180 kesin sınır | 0-180 pencere + "75g ayrımı öneri, uygulanmıyor" notu | Kod — app.js:287-298 iki gruba da izin veriyor; sınır doc'ta vardı, kodda yok |
| ⚠️2 | §2 | 8 grup | 9 grup (Gebe İnek eklendi) | Kod — config.js GRUP_PADOK + 20260511000001:46 |
| ⚠️3 | §8 | 6 kategori, "Beyaz Çizgi" | + Sindirim, Diğer; "Beyaz Çizgi Hastalığı" | Kod — config.js HASTALIK_KAT |
| ⚠️4 | §8 | "Lokasyon bazı kategoriler için zorunlu" | Lokasyon öneri düzeyinde; yaptırım yok; Göz kategorisi de var | Kod — config.js LOKASYON_KAT (Göz dahil); forms.js boş geçilebilir, RAISE yok |
| ⚠️5 | §11 | 8 tip | +TOHUMLAMA_OTOMATIK_BOS, VWP_OVERRIDE, SUTEN_KESME, HASTALIK_GUNCELLENDI, padok_degisim, TEDAVI_GUNCELLENDI, GOREV_EKLENDI/GUNCELLENDI, VAKA_ACILDI | Kod — tip sabitleri migration'lardan çıkarıldı |
| ⚠️6 | §11 | TOHUMLAMA_GUNCELLENDI üretilir; ABORT_KAYDI trigger'dan | UPDATE kolu sessiz (20260830000030); ABORT_KAYDI üreticisi `tohumlama_abort` RPC'si | Kod — 20260830000030:29-37; 20260830000034:46 |
| ⚠️7 | §12 | `ILAC, BUZAGI_BAKIM, TOHUMLAMA_HAZIRLIK, DIGER` | 14 değerlik gerçek liste; TOHUMLAMA_HAZIRLIK→GEBELIK_KONTROL; CHECK kısıtı yok | Kod — 20260830000010:185 + GT:51 |
| ⚠️8 | §5/§13 K4 | "ileri doğum tarihi backend'de yok (kod eksiği adayı)" | `_guard_dogum_ileri_tarih` tablo trigger'ı eklendi (2026-08-31); RPC gövdesinde hâlâ yok | Kod — 20260831000003:63-68; denetimden sonra canlıya deploy edildi |
