# EgeSüt ERP — Veteriner & Hayvancılık Domain Kuralları

Bu dosya, EgeSüt ERP'nin iş kurallarını ve veteriner/hayvancılık domain bilgisini belgeler.
Yeni özellik geliştirirken veya mevcut kodu değiştirirken bu kurallara uyulmalıdır.

---

## 1. Hayvan Kimliği

- Her hayvanın **işletme küpesi** (`kupe_no`) ve/veya **devlet küpesi** (`devlet_kupe`) vardır.
- Tohumlama ve doğum kayıtlarında `hayvan_id` alanı bazen `id` (UUID), bazen `kupe_no` değeri olarak saklanmış olabilir. Arama yaparken her ikisini de kontrol et: `a.id === x || a.kupe_no === x`.
- Buzağı doğduğunda küpesi (`yavru_kupe`) anında sisteme girilir; küpeleme ayrıca görev olarak da takip edilir.

---

## 2. Hayvan Grupları ve Padok Eşlemeleri

Grup → padok ataması `js/config.js:GRUP_PADOK` sabitiyle yönetilir. Bir grup yalnızca belirli padoklara atanabilir.

| Grup | Padok |
|---|---|
| Sağmal (Laktasyonda) | Sağmal Padok |
| Sağmal (Kuru) | Kuru/Gebe Padok |
| Gebe Düve | Kuru/Gebe Padok |
| Düve (Büyük) | Düve Padok (Büyük) |
| Düve (Küçük) | Düve Padok (Küçük) |
| Süt İçen Buzağı | Buzağı Padok (Süt İçenler) |
| Sütten Kesilmiş Buzağı | Buzağı Padok (Sütten Kesilmiş) |
| Besi | Besi Padok (Erkek) veya Besi Padok (Dişi) |

**Kural:** Erkek hayvan Sağmal / Kuru / Gebe grubuna girmez. Backend ve frontend her ikisi de bu kontrolü yapar.

---

## 3. Yaşa Göre Grup Sınırları

Hayvan kaydında yaş zorunlu değil; biliniyorsa aşağıdaki kurallar uygulanır.

### Dişi

| Yaş | İzin verilen gruplar |
|---|---|
| 0–75 gün | Süt İçen Buzağı |
| 76–180 gün | Sütten Kesilmiş Buzağı |
| 181–365 gün | Düve (Küçük) |
| 366–730 gün | Düve (Büyük), Düve (Küçük) |
| 730+ gün veya yaş bilinmiyor | Sağmal, Kuru, Gebe Düve, Düveler |
| Tohumlama geçmişi var | + Gebe Düve seçeneği eklenir |
| Doğum veya abort geçmişi var | Yalnızca Sağmal (Laktasyonda), Sağmal (Kuru) |

### Erkek

| Yaş | Grup |
|---|---|
| 0–75 gün | Süt İçen Buzağı |
| 76–180 gün | Sütten Kesilmiş Buzağı |
| 180+ gün | Besi |

**Kural:** 12 aydan (365 gün) büyük hayvan buzağı grubuna eklenemez. Bu kural frontend ve backend'de kontrol edilir.

**Kural:** 6 aydan (180 gün) büyük "Süt İçen Buzağı" grubuna eklenemez.

---

## 4. Tohumlama (İnseminasyon)

### Ön Koşullar (backend `tohumlama_kaydet` RPC)

- Hayvan `durum = 'Aktif'` olmalı
- Cinsiyet `Dişi` olmalı
- Yaş ≥ 12 ay (365 gün)
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

### `dogum_kaydet` RPC'nin Yaptıkları (14 görev üretir)

1. `dogum` tablosuna kayıt ekler
2. Buzağıyı `hayvanlar` tablosuna ekler (grup: Süt İçen Buzağı, padok: Buzağı Ahırı)
3. Buzağıya anne ırkı atanır
4. Buzağıya baba bilgisi (`p_baba`) yazılır
5. Annenin açık tohumlama kaydını `sonuc = 'Doğum Yaptı'` olarak kapatır
6. Anneye doğum sonrası ilaç protokolü görevleri oluşturur (7 görev):
   - Doğum günü: Oksitosin + Ademin + Kalsiyum
   - 2. Gün: PG
   - 11. Gün: PG
   - 25. Gün: PG
   - 53. Gün: Ademin + Yeldif
   - 54. Gün: Yeldif
   - 58–63. Gün: Kızgınlık takibi
7. Buzağıya ilk gün bakım görevleri oluşturur (6 alt görev):
   - Kolostrum (ilk 2 saat)
   - Göbek kordonu dezenfeksiyonu (iyot)
   - Küpeleme
   - Ademin (1. gün)
   - Maya (1. gün)
   - Probiyotik (1. gün)

### Doğum Kuralları

- Doğum tarihi ileri tarih olamaz
- Anne sistemde kayıtlı ve aktif olmalı
- Doğum yapmış hayvan artık "inek" sayılır → grup seçenekleri Sağmal/Kuru ile sınırlı
- Baba bilgisi: anneanin aktif tohumlama kaydında sperma varsa otomatik doldurulur; yoksa serbest metin

---

## 6. Gebelik ve Abort

- **Abort** (erken doğum / gebelik kaybı): yalnızca `sonuc = 'Gebe'` olan kayıt için yapılabilir
- Abort kaydı `islem_log`'a `ABORT_KAYDI` tipiyle yazılır
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

### Hastalık Kategorileri

| Kategori | Hastalıklar |
|---|---|
| Meme | Mastit, Subklinik Mastit, Klinik Mastit |
| Üreme | Metrit, Endometrit, Pyometra, Retensiyo Sekundinarum, Kistik Over, Anoestrus |
| Metabolik | Hipokalsemi (Süt Humması), Ketozis, Ruminal Asidoz, Timpani, Şirden Deplasmanı |
| Ayak | Topallık (Dermatit), Topallık (Laminit), Beyaz Çizgi, Tırnak Yarası |
| Solunum | Pnömoni |
| Buzağı | Buzağı İshali, Buzağı Göbek İltihabı, Neonatal Zayıflık |

### Vaka Kuralları

- Bir hayvanın aynı anda birden fazla aktif vakası olabilir
- Vaka `status`: `active` veya `closed`
- Lokasyon bilgisi bazı kategoriler için zorunludur (Meme: Sol/Sağ Ön/Arka; Ayak: Sol/Sağ Ön/Arka)

---

## 9. Sütten Kesme

- **Bireysel:** tek hayvan için, onay tarihi belirlenerek yapılır
- **Toplu:** birden fazla süt içen buzağı aynı anda kesilebilir
- Sütten kesme `tohumlama_durumu = 'tohumlanabilir'` ve onay tarihi yazar (veteriner protokolü)

---

## 10. Çıkış Kaydı (Hayvan Sistemden Çıkışı)

- Çıkış nedenleri: Satış, Ölüm, Kesim, Kayıp
- Çıkış kaydında hayvan `durum = 'Pasif'` olur
- Pasif hayvan listelerde görünmez, tohumlama/doğum kaydı yapılamaz

---

## 11. İşlem Günlüğü (islem_log)

Her kritik işlem `islem_log` tablosuna yazılır. Tip değerleri:

| Tip | Tetikleyen |
|---|---|
| `TOHUMLAMA` | Tohumlama INSERT |
| `TOHUMLAMA_GUNCELLENDI` | Sonuç güncelleme (Gebe/Boş dışı) |
| `ABORT_KAYDI` | `sonuc = 'Abort'` UPDATE |
| `DOGUM_KAYDI` | `sonuc = 'Doğum Yaptı'` UPDATE veya dogum INSERT |
| `HAYVAN_EKLENDI` | Hayvan INSERT |
| `HAYVAN_GUNCELLENDI` | Hayvan UPDATE |
| `HASTALIK_KAYDI` | Vaka INSERT |
| `KIZGINLIK` | Kızgınlık kaydı |

`ref_id` alanı migration 016+ sonrası kayıtlarda dolu; eski kayıtlarda `snapshot` içinde aranmalı.

---

## 12. Görev Sistemi (gorev_log)

- `gorev_tipi`: `ILAC`, `BUZAGI_BAKIM`, `TOHUMLAMA_HAZIRLIK`, `DIGER`
- Ana görev (`parent_id = NULL`) + alt görevler (`parent_id` dolu)
- `tamamlandi = false` → bekleyen görev
- `hedef_tarih` geçmişte kalan ve tamamlanmamış görevler gecikmiş sayılır
- Görevler RPC'ler tarafından otomatik oluşturulur; elle silinmemelidir

---

## 13. Kritik İş Kuralları Özeti

> Bu kurallar frontend'de bypass edilemez; backend RPC'lerinde de kontrol edilir.

1. **Erkek hayvan tohumlanamaz, sağmal/gebe grubuna girilemez**
2. **12 aydan küçük hayvan tohumlanamaz, kızgınlık kaydı yapılamaz**
3. **Aktif gebeligi olan hayvan tekrar tohumlanamaz**
4. **Tohumlama tarihi ileri tarih olamaz; doğum tarihi ileri tarih olamaz**
5. **12 aydan büyük hayvan buzağı grubuna eklenemez**
6. **`Gebe` ve `Doğum Yaptı` tohumlama kayıtları direkt değiştirilemez — RPC kullan**
7. **Doğum veya abort geçmişi olan dişi hayvan artık düve değil inek (Sağmal/Kuru)**
8. **Tohumlama verisi yalnızca RPC üzerinden yazılmalı; direkt REST PATCH validation'ı bypass eder**

---

## 14. Multi-Tenancy ve farm_id Disiplini (Faz 2 hazırlığı)

**Durum:** Sistem KASITLI tek-tenant (RLS `USING(true)`). Multi-tenant (`farm_id` + `profiles` + JWT) Faz 2'ye planlı; kaynak `docs/superpowers/specs/2026-06-14-login-auth-gate-design.md` §İzolasyon.

**Sabit:** `REAL_FARM_ID = 400b9107-a85e-4126-af2c-fd7fe73fb68e`. Mevcut tüm gerçek veri bu çiftliğe ait sayılır. Helper: `public.current_farm_id()` (STABLE SQL — şimdilik `REAL_FARM_ID` döner, Faz 2'de JWT/`profiles`'tan okur).

**Kapsam:** Bu disiplin YALNIZCA YENİ nesnelere uygulanır. Mevcut 41 tablo + ~170 fonksiyon bu görevin kapsamı DIŞINDA — Faz 2'de retrofit edilir.

| Kural | Uygulama |
|---|---|
| Yeni tenant-scoped tablo | `farm_id uuid NOT NULL DEFAULT '400b9107-a85e-4126-fd7fe73fb68e'` kolonu + `(farm_id, ...)` index. FK YOK (`farms` Faz 2'de). |
| Yeni yazma fonksiyonu (tenant tablo INSERT) | `farm_id = public.current_farm_id()` damgası. |
| Yeni RLS policy | `USING(true)` KALSIN — Faz 2'de `USING(farm_id = public.current_farm_id())`'ye flip. |
| Global katalog / sistem | `farm_id` ALMAZ (bkz `.claude/farm-id-discipline.md` §4). |
| Emin değilsen | Operasyonel sürü verisi = tenant-scoped varsay; katalog = global. |

**Neden:** Faz 2'de retrofit yükünü bugünden bugüne düşürür; yeni yazılan her şey zaten "farm_id-hazır".

**Detay:** `.claude/farm-id-discipline.md` — kanonik kural belgesi (DRY: burada kural gövdesini tekrar etme).
