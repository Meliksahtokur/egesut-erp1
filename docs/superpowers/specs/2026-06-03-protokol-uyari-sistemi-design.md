# Protokol Uyarı Sistemi — Design Spec

**Tarih:** 2026-06-03
**Durum:** Onaylandı
**Konu:** Eksik protokol adımlarını tespit eden scanner, global görev dinleme mekanizması, hızlı uygulama akışı ve bildirim UI

---

## 1. Problem

Mevcut sistemde görevler RPC çağrısı anında (trigger-based) oluşturuluyor. Retroaktif veri girişinde (sonradan eklenen doğumlar, geçmişten aktarılan hayvanlar) trigger ateşlenemiyor ve görevler hiç oluşmuyor. Ayrıca görev dışından yapılan işlemler (hayvan kartından aşı/ilaç uygulama, toplu aşılama) ilgili açık görevi otomatik kapatmıyor — görev ve aksiyon birbirinden habersiz.

## 2. Çözüm Özeti

3 katmanlı bir sistem:

1. **Global Dinleme (`_gorev_dinle`)** — Herhangi bir ilaç/aşı uygulaması gerçekleştiğinde, kaynağına bakmadan, `etken_kod` bazında eşleşen açık görevi otomatik kapatır
2. **Gap Scanner (`protokol_eksik_tara`)** — Veri durumuna bakarak eksik protokol adımlarını tespit eder (fallback + uyarı kaynağı)
3. **Hızlı Uygulama (`hizli_uygulama`)** — Case açmadan tek seferlik ilaç/vitamin/enjeksiyon kaydı

---

## 3. Etken Kod Sistemi

Görevlerin neyi beklediğini ve uygulamaların neyi karşıladığını eşleştirmek için basit string tag sistemi. `drug_classes` ve `vaccines` tabloları birbirine karışmaz — `etken_kod` ikisinden de bağımsız bir eşleştirme katmanı.

### Tanımlı Kodlar

| etken_kod | Açıklama | Eşleşen Kaynaklar |
|-----------|----------|-------------------|
| `OKSITOSIN` | Oksitosin preparatları | drug_class ILIKE '%oksitosin%' |
| `PG` | Prostaglandin (Dinoprost, Estrumate vb.) | drug_class ILIKE '%prostaglandin%' OR '%PG%' |
| `E_VIT` | E Vitamini (Yeldif dahil) | drug_class ILIKE '%E Vit%' OR stok_ad ILIKE '%yeldif%' |
| `ADEMIN` | A+D+E kompleks vitamin | drug_class ILIKE '%ademin%' OR stok_ad ILIKE '%ademin%' |
| `KALSIYUM` | Kalsiyum preparatları | drug_class ILIKE '%kalsiyum%' OR '%calcium%' |
| `ROTA` | Rota-Corona aşısı | vaccine.name ILIKE '%Rota%' |

### Helper Fonksiyon

```sql
_etken_kod_bul(p_stok_id text, p_vaccine_id uuid) RETURNS text
```

- `p_stok_id` verildi → `stok` → `drug_products` → `drug_classes` → CASE ile etken_kod
- `p_vaccine_id` verildi → `vaccines.name` → CASE ile etken_kod
- İkisi de NULL → NULL döner

Preparat markasına bakılmaz, içerik/sınıf bazlı eşleşme yapılır.

---

## 4. `_gorev_dinle` — Global Dinleme Mekanizması

### Yeni Kolonlar: `gorev_log`

| Kolon | Tip | Açıklama |
|-------|-----|----------|
| `etken_kod` | text | Görevin beklediği etken madde kodu (NULL = dinleme yok) |
| `kapatan_ref` | text | Görevi kapatan kaydın referansı (ör: `uygulama_log:uuid`) |

### Fonksiyon

```sql
_gorev_dinle(p_hayvan_id text, p_etken_kod text, p_ref text)
```

1. `gorev_log` WHERE `hayvan_id = p_hayvan_id AND etken_kod = p_etken_kod AND tamamlandi = false AND iptal = false`
2. Eşleşen ilk görevi kapatır: `tamamlandi = true, tamamlanma_tarihi = now(), kapatan_ref = p_ref`
3. Birden fazla eşleşme varsa sadece `hedef_tarih`'e en yakın olanı kapatır (FIFO)

### Trigger'lar (Ana mekanizma)

| Trigger | Tablo | `_gorev_dinle` çağrısı |
|---------|-------|----------------------|
| `trg_dinle_vaccination` | `AFTER INSERT ON vaccination_log` | `_gorev_dinle(animal_id, _etken_kod_bul(NULL, vaccine_id), 'vaccination_log:' || id)` |
| `trg_dinle_uygulama` | `AFTER INSERT ON uygulama_log` | `_gorev_dinle(hayvan_id, etken_kod, 'uygulama_log:' || id)` |
| `trg_dinle_drug_admin` | `AFTER INSERT ON drug_administrations` | hayvan_id'yi treatment_day → case üzerinden çözer, `_gorev_dinle(animal_id, _etken_kod_bul(stok_id, NULL), 'drug_admin:' || id)` |

### Backfill Migration

Mevcut açık görevlere `etken_kod` atanır:

| Görev açıklaması pattern | etken_kod |
|--------------------------|-----------|
| `%Oksitosin%` | `OKSITOSIN` |
| `%PG%` | `PG` |
| `%Ademin%` (tek başına) | `ADEMIN` |
| `%Yeldif%` veya `%E Vit%` | `E_VIT` |
| `%Kalsiyum%` | `KALSIYUM` |
| `%Rota%` | `ROTA` |

### Görev Oluşturan RPC'lere Ekleme

Görev INSERT eden tüm RPC'ler `etken_kod` set edecek:

- `dogum_kaydet`: 7 anne görevine uygun etken_kod
- `fn_gebe_gorev_yarat` (trigger): ileri gebe görevlerine etken_kod
- `sessiz_hayvanlar_gorev_olustur`: etken_kod NULL (dinleme yok — veteriner kontrol)
- `buzagi_sutten_kesme_kontrol`: etken_kod NULL (dinleme yok — padok transfer)

---

## 5. `uygulama_log` + `hizli_uygulama` — Case'siz Hızlı Uygulama

### Tablo

```sql
CREATE TABLE public.uygulama_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hayvan_id text NOT NULL REFERENCES hayvanlar(id),
  stok_id text REFERENCES stok(id),
  etken_kod text,
  doz numeric NOT NULL,
  birim text NOT NULL,
  rota text NOT NULL CHECK (rota IN ('IM','IV','SC','PO','Topikal','Intrauterin')),
  tarih date NOT NULL DEFAULT CURRENT_DATE,
  notlar text NOT NULL,
  created_at timestamptz DEFAULT now()
);
```

### RPC: `hizli_uygulama`

```sql
hizli_uygulama(
  p_hayvan_id text,
  p_stok_id text,
  p_doz numeric,
  p_birim text,
  p_rota text,
  p_notlar text  -- zorunlu
) RETURNS jsonb
```

1. `_etken_kod_bul(p_stok_id, NULL)` → etken_kod türet
2. `uygulama_log` INSERT (etken_kod dahil)
3. `stok_hareket` INSERT (stok düşüm)
4. `trg_dinle_uygulama` trigger otomatik `_gorev_dinle` çağırır
5. RETURN `{ok, id, etken_kod, stok_kalan}`

### RPC: `hizli_uygulama_geri_al`

```sql
hizli_uygulama_geri_al(p_uygulama_id uuid) RETURNS jsonb
```

1. `uygulama_log` kaydını bul
2. `stok_hareket` ters kayıt INSERT (iade)
3. `kapatan_ref = 'uygulama_log:' || p_uygulama_id` olan görev varsa → `tamamlandi = false, tamamlanma_tarihi = NULL, kapatan_ref = NULL`
4. `uygulama_log` DELETE
5. RETURN `{ok}`

---

## 6. `protokol_eksik_tara` — Gap Scanner (Fallback)

### Taranan Protokoller

**A. Doğum Sonrası Protokol (0-58. gün)**

Kaynak: `dogum` tablosu, son 70 gün doğum yapan anneler.

| Gün | Etken Kod | Kontrol |
|-----|-----------|---------|
| +0 | `OKSITOSIN`, `ADEMIN`, `KALSIYUM` | gorev tamamlanmış OR uygulama_log/drug_admin'da kayıt var |
| +2 | `PG` | aynı |
| +11 | `PG` | aynı |
| +25 | `PG` | aynı |
| +53 | `ADEMIN`, `E_VIT` | aynı |
| +54 | `E_VIT` | aynı |
| +58 | — (kızgınlık takibi) | gorev tamamlanmış OR kizginlik_log/tohumlama kaydı var |

**B. İleri Gebe Protokol (240-265. gün)**

Kaynak: `tohumlama` WHERE `sonuc = 'Gebe'`, gebelik süresi 230+ gün.

| Gün | Etken Kod | Kontrol |
|-----|-----------|---------|
| +240 | `ROTA` | vaccination_log'da Rota kaydı var mı |
| +260 | `ADEMIN` | gorev/uygulama_log/drug_admin |
| +265 | `E_VIT` | gorev/uygulama_log/drug_admin |

**C. Kızgınlık Takibi (58-63. gün)**

Kaynak: `dogum` tablosu, doğumdan 58-70 gün geçmiş anneler.

Kontrol: gorev tamamlanmış OR kizginlik_log/tohumlama kaydı var.

### Kontrol Sırası (Her Adım İçin)

1. `gorev_log` — tamamlandi = true AND etken_kod eşleşiyor?
2. `vaccination_log` — ilgili aşı kaydı var mı?
3. `uygulama_log` — ilgili uygulama kaydı var mı?
4. `drug_administrations` → `treatment_days` → `cases` — ilgili ilaç uygulaması var mı?
5. `protokol_dismiss` — kullanıcı geçersiz kılmış mı?
6. Hiçbiri yok → **UYARI**

### Dönen Format

```json
[
  {
    "hayvan_id": "548df203...",
    "kupe_no": "173",
    "grup": "Sağmal",
    "protokol": "DOGUM_PROTOKOL",
    "adim": "53. Gün: Ademin + Yeldif",
    "etken_kod": "E_VIT",
    "hedef_tarih": "2026-06-06",
    "gecikme_gun": 3,
    "durum": "eksik",
    "stok_oneri_id": "...",
    "oneri_doz": 10,
    "oneri_birim": "ml",
    "oneri_rota": "IM"
  }
]
```

`durum` değerleri:
- `eksik` — hedef tarih geçmiş, işlem yapılmamış
- `yaklasan` — hedef tarih 7 gün içinde
- `tamamlandi` — son 24 saatte tamamlanmış (geri al için gösterilir)

Son 24 saat tamamlananlar da döner (`durum: 'tamamlandi'`, `tamamlanma_tarihi`, `kapatan_ref`).

### Dismiss Tablosu

```sql
CREATE TABLE public.protokol_dismiss (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hayvan_id text NOT NULL REFERENCES hayvanlar(id),
  etken_kod text NOT NULL,
  protokol text NOT NULL,
  tarih timestamptz DEFAULT now(),
  neden text,
  UNIQUE(hayvan_id, etken_kod, protokol)
);
```

### Çağrılma Zamanı

`loadDash()` içinden çağrılır. Sonuç zil ikonu badge'ini ve protokol ekranını besler.

---

## 7. UI — Zil İkonu + Protokol Uyarı Ekranı

### Zil İkonu

- Dashboard header'da reload ve ayarlar butonlarının yanında
- Kırmızı badge: aktif uyarı sayısı (`eksik` + `yaklasan`)
- Uyarı yoksa badge gizli, ikon pasif renkte
- Tıklayınca tam sayfa protokol ekranı açılır

### Protokol Ekranı — Tam Sayfa

İki bölüm:

**Bekleyen Uyarılar:**

Her satır:
- Renk kodu: 🔴 kırmızı (gecikmiş) / 🟡 sarı (7 gün içinde)
- Hayvan küpe + grup
- Protokol adımı açıklaması + gecikme/kalan gün
- `[💉 Uygula]` butonu — tıklayınca mini bottom-sheet açılır
- `[Geçersiz ✕]` butonu — opsiyonel neden girişi, `protokol_dismiss` INSERT

**Uygula Mini Formu (Bottom-sheet):**

- Stok seçimi: `etken_kod`'a göre ön-filtrelenmiş (sadece E_VIT ürünleri, sadece PG ürünleri vb.)
- Doz + birim: protokolden önerilen değerler pre-filled
- Rota: dropdown, önerilen değer pre-selected
- Not: zorunlu text input
- `[Kaydet]` butonu → `hizli_uygulama` RPC

**Son 24 Saat — Tamamlananlar:**

Her satır:
- ✅ yeşil arka plan
- Hayvan küpe + tamamlanan adım + "X saat/dakika önce"
- `[🔴 ↩ Geri Al]` butonu — kırmızı renkte
  - Tıklayınca "Bu işlemi geri almak istediğinize emin misiniz?" onay dialogu
  - Onaylanırsa `hizli_uygulama_geri_al` RPC → stok iade + görev tekrar açılır
  - Satır bekleyen bölümüne döner

---

## 8. UI — Hayvan Kartı Hızlı Uygulama

### Buton

`💉 Hızlı Uygulama` — hayvan detay ekranında mevcut aksiyon butonlarının yanında.

### Bottom-sheet

- Stok seçimi: tüm ilaç + aşı stokları (filtre/arama destekli)
- Doz + birim input
- Rota dropdown (IM, IV, SC, PO, Topikal)
- Not: zorunlu text input
- `[Kaydet]` → `hizli_uygulama` RPC
- Başarılıysa toast: "Uygulama kaydedildi"

Protokol ekranındaki "Uygula" ile fark: burada stok filtresi yok, kullanıcı serbestçe seçer. Protokol ekranında `etken_kod`'a göre ön-filtrelenmiş gelir.

### Uygulama Geçmişi

Hayvan kartında mevcut tedavi/aşı geçmişi bölümlerinin yanında `uygulama_log` kayıtları da listelenir: tarih + stok adı + doz + rota + not.

---

## 9. Yapılacaklar Sırası

| # | Parça | Katman | Bağımlılık |
|---|-------|--------|-----------|
| 1 | `gorev_log`'a `etken_kod` + `kapatan_ref` kolon ekle | DB migration | — |
| 2 | `_etken_kod_bul()` helper fonksiyonu | DB | — |
| 3 | `_gorev_dinle()` fonksiyonu | DB | 1 |
| 4 | Mevcut açık görevlere `etken_kod` backfill | DB migration | 1 |
| 5 | `dogum_kaydet` ve `fn_gebe_gorev_yarat`'a `etken_kod` ekleme | DB migration | 1 |
| 6 | `uygulama_log` tablosu | DB migration | — |
| 7 | `hizli_uygulama()` RPC | DB | 2, 6 |
| 8 | `hizli_uygulama_geri_al()` RPC | DB | 7 |
| 9 | 3 AFTER INSERT trigger (vaccination_log, uygulama_log, drug_administrations) | DB | 2, 3 |
| 10 | `protokol_dismiss` tablosu | DB migration | — |
| 11 | `protokol_eksik_tara()` scanner RPC | DB | 6, 10 |
| 12 | Zil ikonu + badge (dashboard header) | UI | 11 |
| 13 | Protokol uyarı ekranı (tam sayfa) | UI | 11, 12 |
| 14 | "Uygula" mini form + "Geri Al" akışı | UI | 7, 8, 13 |
| 15 | Hayvan kartı "Hızlı Uygulama" butonu + bottom-sheet | UI | 7 |
| 16 | Hayvan kartı uygulama geçmişi listesi | UI | 6 |
| 17 | `ground_truth.sql` sync | DB | 1-11 |

---

## 10. Kapsam Dışı

- Cron/scheduler: Dashboard yenilenince scanner çalışır, şimdilik yeterli
- Push notification: İleride eklenebilir
- Mevcut trigger'lara dokunulmaz — aynen çalışmaya devam eder
- `drug_classes` ve `vaccines` tabloları birbirine bağlanmaz
