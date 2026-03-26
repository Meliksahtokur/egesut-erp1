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
| Abort | Erken doğum / gebelik kaybı | Değiştirilemez |

**Kural:** `Gebe` ve `Doğum Yaptı` durumundaki kayıtlar frontend üzerinden doğrudan değiştirilemez. Tüm kritik geçişler RPC üzerinden yapılmalıdır.

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
