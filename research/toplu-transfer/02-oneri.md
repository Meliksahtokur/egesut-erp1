# Önerilen Çözüm Mimarisi

## Yaklaşım: Aşamalı İyileştirme

Mevcut altyapı çalışıyor — komple rewrite yerine aşamalı iyileştirme önerilir.

| Aşama | Ne Yapılacak | Etki | Tahmini Süre |
|-------|-------------|------|-------------|
| **Faz 0** | Mevcut kodun feature status dökümanını güncelle (line numaraları) | Dökümantasyon | 15 dk |
| **Faz 1** | Kapasite kontrolü + grup-padok uyum kontrolü | Kritik validasyon | 1-2 saat |
| **Faz 2a** | Frontend: dropdown tek seçenekliyse otomatik seç (animalGrupDegisti) | Hızlı kazanç | 30 dk |
| **Faz 2b** | Backend: `hayvan_guncelle` RPC'sine otomatik padok atama | "p1" kalıcı çözümü | 1 saat |
| **Faz 3** | UX iyileştirme: bottom action bar + inline padok seçimi | Kullanıcı deneyimi | 3-4 saat |
| **Faz 4** | Cross-padok seçim (dashboard'dan) | Yeni yetenek | 2-3 saat |
| **Faz 5** | MCP tool olarak `padok_degistir_toplu` ekle | Agent erişimi | 30 dk |

---

## Faz 1: Validasyon Ekleme (Önerilen Başlangıç)

### 1.1 RPC'ye Kapasite Kontrolü

**Dosya:** `supabase/migrations/yeni_migration.sql` (veya mevcut RPC'leri güncelle)

```sql
-- padok_degistir içinde, UPDATE öncesi:
IF (SELECT kapasite FROM padoklar WHERE id = p_yeni_padok_id) IS NOT NULL THEN
  IF (SELECT COUNT(*) FROM hayvanlar 
      WHERE padok_id = p_yeni_padok_id AND durum = 'Aktif') 
     >= (SELECT kapasite FROM padoklar WHERE id = p_yeni_padok_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hedef padok kapasitesi dolu');
  END IF;
END IF;

-- Aynı kontrol padok_degistir_toplu'da da eklenmeli
```

### 1.2 Frontend'de Kapasite Gösterimi

**Dosya:** `js/ui.js`, `_pdTransferAcSelector()` (~5531)

Dropdown'da her padok için kapasite bilgisini göster:
```
selection: Kuru/Gebe Padok (12/20 dolu)
```

### 1.3 Frontend'de Grup-Padok Uyum Filtresi

**Dosya:** `js/ui.js`, `_pdTransferAcSelector()` (~5531)

Seçili hayvanların gruplarını tara, ortak uyumlu padokları bul, dropdown'ı filtrele:

```javascript
// Seçili hayvanların gruplarını al
const gruplar = [...new Set(hayvanlar
  .filter(h => _pdTransferHayvanIds.includes(h.id))
  .map(h => h.grup))];

// Ortak padokları bul (tüm gruplar için uygun)
const ortakPadok = padoklar.filter(p => 
  gruplar.every(g => {
    const uygunAdlar = GRUP_PADOK[g] || [];
    return uygunAdlar.includes(p.ad);
  })
);
```

---

## Faz 2a: Frontend Otomatik Padok Seçimi

**Dosya:** `js/app.js`, `animalGrupDegisti()` (~335)

```javascript
function animalGrupDegisti() {
  // mevcut kod...
  
  // Dropdown tek seçenek içeriyorsa otomatik seç
  if (padokSel.options.length === 1 && padokSel.options[0].value) {
    padokSel.value = padokSel.options[0].value;
  }
}
```

Bu küçük değişiklik, tek padoklu gruplarda (Sağmal, Düve, Buzağı) otomatik seçim yapar. Besi grubu zaten cinsiyet bazlı otomatik seçiyor.

---

## Faz 2b: Backend Grup→Padok Otomatik Atama

### Seçenek A — `hayvan_guncelle` RPC'sine ekle

```sql
-- hayvan_guncelle içinde, grup güncelleniyorsa:
IF p_grup IS NOT NULL AND p_grup != (SELECT grup FROM hayvanlar WHERE id = p_id) THEN
  -- grup_padok_eslem'den uygun padok'u bul
  SELECT padok_id INTO v_otomatik_padok_id
  FROM grup_padok_eslem 
  WHERE grup = p_grup
  LIMIT 1;
  
  -- Kullanıcı p_padok_id göndermemişse otomatik ata
  IF p_padok_id IS NULL AND v_otomatik_padok_id IS NOT NULL THEN
    p_padok_id := v_otomatik_padok_id;
  END IF;
END IF;
```

### Seçenek B — Trigger

```sql
CREATE OR REPLACE FUNCTION fn_grup_padok_otomatik()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.grup IS DISTINCT FROM OLD.grup THEN
    SELECT pe.padok_id INTO NEW.padok_id
    FROM grup_padok_eslem pe
    WHERE pe.grup = NEW.grup
    ORDER BY pe.padok_id
    LIMIT 1;
    
    SELECT ad INTO NEW.padok 
    FROM padoklar WHERE id = NEW.padok_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_grup_padok_otomatik
  BEFORE UPDATE OF grup ON hayvanlar
  FOR EACH ROW
  EXECUTE FUNCTION fn_grup_padok_otomatik();
```

**Öneri:** Seçenek A (RPC'ye ekle) daha güvenli — trigger görünmez yan etki yaratabilir. RPC'de kullanıcının `p_padok_id` gönderip göndermediği açıkça kontrol edilebilir.

---

## Faz 3: UX İyileştirme

`.claude/ideas/padok-transfer-ux.md`'deki pattern uygulanabilir:

### Mevcut (3 katman):
```
m-padok-det → checkbox → "Toplu Taşı" → m-padok-transfer → dropdown → Taşı
```

### Önerilen (0 katman - inline):
```
Sürü Dashboard → uzun basış/seçim → bottom action bar → inline dropdown → Taşı
```

Detaylar için ilgili dokümana bak: `.claude/ideas/padok-transfer-ux.md`

---

## Değişmesi Gereken Dosyalar

| Dosya | Faz | Değişiklik |
|-------|-----|-----------|
| `supabase/migrations/20260512000001_padok_degistir_rpc.sql` | Faz 1 | Kapasite kontrolü ekle |
| `supabase/migrations/20260512000002_padok_degistir_toplu_rpc.sql` | Faz 1 | Kapasite kontrolü ekle |
| `supabase/migrations/20260306000008_blok1_backend.sql` (hayvan_guncelle) | Faz 2b | Grup→padok otomatik atama |
| `js/ui.js:5531-5543` (`_pdTransferAcSelector`) | Faz 1 | Kapasite + grup uyum filtresi |
| `js/ui.js:5545-5578` (`padokTransferOnayla`) | Faz 1 | Hata detaylarını göster |
| `js/app.js:335-357` (`animalGrupDegisti`) | Faz 2a | Tek seçenek otomatik seç |
| `js/forms.js:26-103` (`submitAnimal`) | Faz 2a | Padok boşsa GRUP_PADOK'tan otomatik doldur |
| `index.html:1746-1796` (modal'lar) | Faz 3 | UX revizyonu |
| `docs/feature-status-2026-05-13.md` | Faz 0 | Line numaralarını güncelle |

---

## Önerilen İlk Adım

**Faz 1'den başla** — en kritik eksik (kapasite kontrolü) ve en kolay çözüm.

1. `padok_degistir` RPC'sine kapasite kontrolü ekle
2. `padok_degistir_toplu` RPC'sine kapasite kontrolü ekle
3. `_pdTransferAcSelector()`'da dropdown'da kapasite bilgisi göster
4. `_pdTransferAcSelector()`'da grup-padok uyum filtresi ekle
5. Yeni migration oluştur, deploy et
