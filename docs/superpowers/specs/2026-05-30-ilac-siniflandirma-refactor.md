# İlaç Sınıflandırma Sistemi Refactor — Faz 1 ✅ TAMAMLANDI (2026-05-30)

## Problem

Sistemde 3 paralel ilaç yapısı var (`drugs`, `drug_classes→drug_products`, `stok.kategori`) ve birbirini görmüyor. Tanımlar panelinde yapılan değişiklik Stok paneline yansımıyor. Kategori isimleri tutarsız ("Diğer İlaç" vs "Diger Ilac" vs "Diğer İlaçlar"). GRUPLAR hardcoded. drug_classes.drug_id anlamsız FK (tüm 29 kayıt aynı phantom "İlaç" kaydına bağlı).

## Hedef

Tek tutarlı ilaç sınıflandırma sistemi: `drug_classes` (etken madde) → `drug_products` (preparat) → `stok` (envanter). Veteriner farmakoloji ders kitabı referansına uygun sınıflandırma. Tanımlar panelinden sınıflandırma yönetimi.

## Kapsam Dışı (Faz 2)

- `stok.kategori` string → `stok_kategorileri.id` UUID FK dönüşümü
- `drugs` tablosu DROP
- drug_products otomatik kategori propagasyonu

---

## 1. Veri Modeli

### 1.1 stok_kategorileri — yeni kategoriler

Mevcut tip=ilac kategorilerine ek olarak:

| ad | tip | sira |
|----|-----|------|
| Metabolik | ilac | 14 |
| GI İlaçlar | ilac | 15 |
| Topikal | ilac | 16 |
| Anestezik / Sedatif | ilac | 17 |

Mevcut düzeltmeler:
- "Diğer İlaçlar" → "Diğer İlaç" (rename)
- "Mide Koruyucular" → DELETE (GI İlaçlar ile değiştirildi)

### 1.2 stok — kategori tutarsızlıkları

| Eski değer | Yeni değer |
|------------|-----------|
| "Diger Ilac" | "Diğer İlaç" |

### 1.3 drug_classes — yapısal değişiklik

Kolon değişiklikleri:
- `drug_id` → DROP (anlamsız FK)
- `kategori_id UUID REFERENCES stok_kategorileri(id)` → ADD
- Backfill: group_name → stok_kategorileri eşleştirmesi ile kategori_id doldur

### 1.4 drug_classes — ders kitabı seed

Veteriner farmakoloji referansına göre tam sınıflandırma:

```
1. Antimikrobiyaller (Antibiyotikler) → kategori: Antibiyotik
├── Beta-Laktamlar
│   ├── Penisilin
│   ├── Amoksisilin
│   └── Seftiofur
├── Makrolidler
│   ├── Tilmikosin
│   └── Tulathromycin
├── Florokinolonlar
│   ├── Enrofloksasin
│   └── Marbofloksasin
├── Tetrasiklinler
│   ├── Oksitetrasiklin
│   └── Doksisiklin
├── Aminoglikozidler
│   └── Gentamisin
└── Sulfonamidler
    └── Trimetoprim-SMX

2. Anti-inflamatuar İlaçlar → kategori: NSAID
├── NSAID
│   ├── Meloksikam
│   ├── Ketoprofen
│   └── Flunixin
└── Kortikosteroidler → kategori: Hormon
    └── Deksametazon

3. Hormonlar ve Üreme İlaçları → kategori: Hormon
├── Prostaglandinler
│   └── Dinoprost
├── GnRH Agonistleri
│   └── Gonadorelin
├── Progestagenler
│   └── Progesteron
└── Oksitosin
    └── Oksitosin

4. Antiparaziter İlaçlar → kategori: Antiparaziter
├── Makrosiklik Laktonlar
│   ├── İvermektin
│   └── Doramektin
└── Benzimidazoller
    └── Albendazol

5. Vitaminler ve Mineraller → kategori: Vitamin
├── Suda Eriyen Vitaminler
│   ├── B1 (Tiamin)
│   ├── B6 (Piridoksin)
│   ├── B12 (Siyanokobalamin)
│   ├── B Kompleks
│   └── C Vitamini
├── Yağda Eriyen Vitaminler
│   ├── E Vitamini
│   └── AD3E Kombinasyon
└── Mineraller / İz Elementler
    └── Selenyum

6. Metabolik / Sıvı Tedavi → kategori: Metabolik
├── Kalsiyum Preparatları
│   └── Kalsiyum Boroglukonat
├── Magnezyum
│   └── Magnezyum Sülfat
├── Glukoz / Dekstroz
│   ├── Glukoz %50
│   └── Dekstroz %30
└── Elektrolitler
    ├── Oral Rehidrasyon Solüsyonu
    └── IV Serum (İzotonik NaCl, Ringer Laktat)

7. Gastrointestinal İlaçlar → kategori: GI İlaçlar
├── Gastroprotektanlar
│   └── Sukralfat (Antepsin)
├── Rumen Stimülanları
│   └── Rumen Stimülanı
└── Probiyotikler / Maya
    ├── Saccharomyces (Maya)
    └── Probiyotik Preparatları

8. Topikal / Harici İlaçlar → kategori: Topikal
└── Merhemler
    └── İhtiyol (Kara Merhem)

9. Anestezik / Sedatif → kategori: Anestezik / Sedatif
├── Sedatifler
│   └── Ksilazin
├── Genel Anestezikler
│   └── Ketamin
└── Lokal Anestezikler
    └── Lidokain
```

NOT: Kortikosteroidler, "Anti-inflamatuar" grubu altında yer alır ama kategori olarak "Hormon"a bağlanır (kategori_id). Bu kullanıcının tercihi ve veteriner pratiğiyle uyumludur.

---

## 2. RPC'ler

### 2.1 Yeni RPC'ler

**drug_class_ekle(p_group_name, p_class_name, p_active_ingredient, p_kategori_id)**
- Aynı group+class+ingredient kombinasyonu varsa hata
- RETURNS jsonb {ok, id, mesaj}

**drug_class_guncelle(p_id, p_group_name, p_class_name, p_active_ingredient)**
- Mevcut kaydı günceller
- RETURNS jsonb {ok, mesaj}

**drug_class_sil(p_id)**
- Bağlı drug_products varsa → {ok:false, mesaj:"Bu etken maddeye bağlı X preparat var. Önce preparatları başka sınıfa taşıyın."}
- Bağlı yoksa → sil
- RETURNS jsonb {ok, mesaj}

**drug_class_varsayilan_yukle()**
- Ders kitabı seed'ini uygular
- Mevcut seed class'lar varsa SKIP (ON CONFLICT DO NOTHING mantığı)
- Eksik olanları ekler
- RETURNS jsonb {ok, eklenen}

### 2.2 Değişen RPC'ler

**stok_ekle** — p_kategori parametresine validate ekle:
```sql
IF NOT EXISTS (SELECT 1 FROM stok_kategorileri WHERE ad = p_kategori)
THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Geçersiz kategori: ' || p_kategori);
END IF;
```

**stok_guncelle** — aynı validate.

---

## 3. UI — Tanımlar "İlaç Sınıfları" Tab

### 3.1 Genel yapı

Mevcut "İlaçlar" tab'ı → "İlaç Sınıfları" olarak değişir. Accordion tree görünümü:

```
▼ Antimikrobiyaller (Antibiyotikler)    [✏️][🗑]
  ▼ Beta-Laktamlar                      [✏️][🗑]
    Penisilin                           [✏️][🗑]
    Amoksisilin                         [✏️][🗑]
    + Etken Madde Ekle
  ▶ Makrolidler                         [✏️][🗑]
  + Alt Grup Ekle
▶ Anti-inflamatuar İlaçlar              [✏️][🗑]
▶ Hormonlar ve Üreme İlaçları           [✏️][🗑]
...
+ Yeni Grup Ekle

[🔄 Varsayılana Dön]
```

### 3.2 CRUD işlemleri

**Ekleme:** "+" butonuna tıkla → inline input açılır → Enter ile kaydet → RPC drug_class_ekle çağrılır

**Düzenleme:** ✏️ tıkla → isim inline input'a dönüşür → Enter kaydet, Esc iptal → RPC drug_class_guncelle

**Silme:** 🗑 tıkla → onay iste:
- Alt grupları varsa: "Bu grubun altında X alt grup var. Önce taşıyın veya silin."
- Bağlı drug_products varsa: "Bu etken maddeye bağlı X preparat var. Önce preparatları başka sınıfa taşıyın."
- Bağlantısız: "Bu kaydı silmek istediğinize emin misiniz?" → Evet/Hayır

### 3.3 Varsayılana Dön

1. Buton tıklanır
2. Orphan taraması: mevcut drug_products'ın bağlı olduğu drug_class'lar, seed'de var mı kontrol
3. Orphan yoksa → matematik onay: "Varsayılan sistem düzenine dönülecek. Özel sınıflarınız silinecektir. Bu işlem geri alınamaz. Devam etmek için [rastgele] + [rastgele] = ? yazın:"
4. Orphan varsa → eşleme modal: "Bu ilaçlar yeni düzende yeri olmayan sınıflara ait. Lütfen taşıyın:" + her orphan için dropdown
5. Eşleme + onay tamamlanınca → RPC drug_class_varsayilan_yukle çağrılır

### 3.4 Accordion davranışı

- Her seviye toggle ile açılır/kapanır (display:none/block)
- `<details>/<summary>` KULLANILMAZ (mobile Safari sorunları)
- İlk yüklemede tüm gruplar kapalı
- Indent: grup=0px, alt grup=20px, etken madde=40px

---

## 4. UI — Stok Paneli Değişiklikleri

### 4.1 GRUPLAR dinamikleştirme

Hardcoded GRUPLAR dizisi kaldırılır. `stok_kategorileri`'nden dinamik üretilir:

```javascript
const katlar = await idbGetAll('stok_kategorileri');
const ilacKats = katlar.filter(k => k.tip === 'ilac').sort((a,b) => a.sira - b.sira);
const genelKats = katlar.filter(k => k.tip !== 'ilac').sort((a,b) => a.sira - b.sira);

const GRUPLAR = [
  { baslik: '💊 Sağlık', alt: ilacKats.map(k => ({
      ad: '💊 ' + k.ad,
      filtre: s => s.kategori === k.ad
    }))
  },
  { baslik: '💉 Aşılar', alt: [
      { ad: '💉 Aşı Ürünleri', filtre: s => s.isVaccine || s.kategori === 'Aşı' }
    ]
  },
  { baslik: '🐂 Sperma', alt: [
      { ad: '🐂 Sperma', filtre: s => s.kategori === 'Sperma' }
    ]
  },
  { baslik: '🌾 Yem', alt: [
      { ad: '🌾 Yem & Katkı', filtre: s => s.kategori === 'Yem' }
    ]
  },
  { baslik: '🔧 Ekipman', alt: genelKats
      .filter(k => !['Aşı','Sperma','Yem'].includes(k.ad))
      .map(k => ({
        ad: '🔧 ' + k.ad,
        filtre: s => s.kategori === k.ad
      }))
  }
];
```

### 4.2 Emoji mapping

| Tip/Kategori | Emoji |
|-------------|-------|
| tip=ilac | 💊 |
| Aşı | 💉 |
| Sperma | 🐂 |
| Tohumlama | 🐂 |
| Yem | 🌾 |
| Ekipman/Sarf/Diğer | 🔧 |

### 4.3 Stok ekleme formu — KAT_MAP

Hardcoded `KAT_MAP` kaldırılır. Etken madde seçildiğinde `drug_classes.kategori_id` → `stok_kategorileri.ad` üzerinden otomatik resolve:

```javascript
sel.onchange = () => {
  const opt = sel.selectedOptions[0];
  const dcId = opt?.value;
  const dc = drugClasses.find(c => c.id === dcId);
  if (dc && dc.kategori_id) {
    const kat = allKats.find(k => k.id === dc.kategori_id);
    if (kat) katInp.value = kat.ad;
  }
};
```

---

## 5. drugs Tablosu Geçişi

Faz 1'de `drugs` tablosu DROP edilmez. Yapılacak:
- Frontend'in drugs tablosunu okuması/yazması kesilir
- `_renderIlaclar` → drug_classes okuyan accordion tree'ye dönüşür
- `_drugEditForm`, `_drugSave`, `_drugDelete` → drug_class RPC'lerine bağlanır
- `loadDrugsCache` → zaten drug_classes/drug_products okuyor, değişiklik yok

Faz 2'de drugs tablosu DROP edilecek (ayrı sprint, Supabase snapshot ile).

---

## 6. Faz Sınırları

### Faz 1 (bu sprint)
1. Migration: kategori tutarsızlıkları düzelt
2. Migration: stok_kategorileri'ne yeni kategoriler ekle
3. Migration: drug_classes.drug_id → kategori_id FK
4. Migration: ders kitabı seed
5. RPC: drug_class_ekle/guncelle/sil/varsayilan_yukle
6. RPC: stok_ekle/guncelle validate
7. UI: Tanımlar "İlaç Sınıfları" accordion tree
8. UI: Silme koruması + Varsayılana Dön (matematik onay + orphan eşleme)
9. UI: GRUPLAR dinamik
10. UI: Emoji 🐂 sperma/tohumlama

### Faz 2 (gelecek sprint — Supabase snapshot gerekli)
- stok.kategori string → kategori_id UUID FK
- drugs tablosu DROP
- drug_products otomatik kategori propagasyonu
