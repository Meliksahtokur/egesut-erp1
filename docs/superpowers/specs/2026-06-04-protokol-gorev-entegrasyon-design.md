# Protokol-Görev Entegrasyon — Design Spec

## Problem

Aynı "ilaç uygulandı" olayı 3 farklı giriş noktasından tetiklenebilir ama bu noktalar birbirinden habersiz:

| Giriş Noktası | Stok Düşer | Görev Kapanır | Scanner Görür |
|---|---|---|---|
| Görev sekmesi (`gorev_tamamla`) | Sadece `stok_id` doluysa | ✅ | ✅ (gorev_log) |
| Protokol ekranı (`hizli_uygulama`) | ✅ | Sadece `etken_kod` doğruysa | ✅ (uygulama_log) |
| Hayvan kartı | **giriş noktası yok** | — | — |

Ek olarak:
- `_etken_kod_bul` fonksiyonu CAROFERTIN-E gibi ürünleri tanımıyor (`etken_kod = NULL` dönüyor)
- Frontend `_ETKEN_FILTERE` regex'i kırılgan — yeni ürün eklenince regex güncellenmesi gerekiyor
- Protokol görevlerinde `stok_id` boş oluşturuluyor (ürün doğum anında bilinmiyor)

## Hedef

**Nereden yapılırsa yapılsın: stok düşer, görev kapanır, scanner güncellenir.**

---

## §1 Backend: `_etken_kod_bul` Düzeltmesi

### Mevcut Durum (Kırık)

```sql
-- stok.urun_adi üzerinden text matching + drug_class.class_name üzerinden ILIKE
IF v_class_name ILIKE '%E Vit%' OR v_stok_ad ILIKE '%yeldif%' OR v_stok_ad ILIKE '%e vit%'
  THEN RETURN 'E_VIT'; END IF;
```

"CAROFERTIN-E ( alivira )" hiçbir pattern'e uymuyor → NULL dönüyor.

### Yeni Yaklaşım: `drug_class_id` → `etken_kod` Lookup Tablosu

Stok → drug_products → drug_classes zinciri DB'de zaten doğru kurulu:

```
stok.drug_product_id → drug_products.drug_class_id → drug_classes
CAROFERTIN-E → 2b7172b6 → 5f2d199d → "Yağda Eriyen Vitaminler" / "E Vitamini"
Yeldif       → afe25bc1 → 5f2d199d → (aynı class)
```

**Çözüm:** `_etken_kod_bul` fonksiyonunda önce `stok.drug_product_id` → `drug_products.drug_class_id` zincirini kullan. Text fallback'i sadece `drug_product_id` NULL olan eski stok kayıtları için kalsın.

```sql
-- YENİ: Önce FK zinciri ile dene
IF p_stok_id IS NOT NULL THEN
  SELECT s.urun_adi, s.drug_product_id INTO v_stok_ad, v_dp_id
  FROM public.stok s WHERE s.id = p_stok_id;

  IF v_dp_id IS NOT NULL THEN
    SELECT dc.class_name, dc.group_name, dc.active_ingredient
    INTO v_class_name, v_group_name, v_active_ing
    FROM public.drug_products dp
    JOIN public.drug_classes dc ON dc.id = dp.drug_class_id
    WHERE dp.id = v_dp_id;
  END IF;

  -- active_ingredient bazlı eşleşme (daha güvenilir)
  IF v_active_ing ILIKE '%oxytocin%' OR v_active_ing ILIKE '%oksitosin%' THEN RETURN 'OKSITOSIN'; END IF;
  IF v_active_ing ILIKE '%dinoprost%' OR v_active_ing ILIKE '%cloprostenol%' OR v_active_ing ILIKE '%prostaglandin%' THEN RETURN 'PG'; END IF;
  IF v_active_ing ILIKE '%E Vitamini%' OR v_active_ing ILIKE '%vitamin e%' OR v_active_ing ILIKE '%tocopherol%' THEN RETURN 'E_VIT'; END IF;
  IF v_active_ing ILIKE '%ademin%' OR v_active_ing ILIKE '%ADE%' THEN RETURN 'ADEMIN'; END IF;
  IF v_active_ing ILIKE '%kalsiyum%' OR v_active_ing ILIKE '%calcium%' THEN RETURN 'KALSIYUM'; END IF;

  -- Fallback: urun_adi text matching (drug_product_id olmayan eski kayıtlar)
  IF v_stok_ad ILIKE '%oksitosin%' THEN RETURN 'OKSITOSIN'; END IF;
  -- ... (mevcut text fallback'ler)
END IF;
```

### Etki

- CAROFERTIN-E artık `'E_VIT'` döner (active_ingredient = "E Vitamini")
- Yeni ürün eklendiğinde regex güncellemesi gerekmez — `drug_classes` tablosundaki sınıflandırma yeterli
- Mevcut trigger zinciri (`fn_dinle_uygulama` → `_gorev_dinle`) düzgün çalışmaya başlar

---

## §2 Frontend: `_ETKEN_FILTERE` → `drug_class` Bazlı Filtreleme

### Mevcut Durum (Kırık)

```javascript
const _ETKEN_FILTERE = {
  'OKSITOSIN': s => /oksitosin/i.test(s.urun_adi),
  'E_VIT':     s => /e[ .-]?vit|yeldif/i.test(s.urun_adi),
  // ...
};
```

CAROFERTIN-E bu regex'e uymuyor → dropdown'da görünmüyor.

### Yeni Yaklaşım

IDB `stok` store'una `drug_product_id` zaten çekiliyor. Ama `drug_classes` bilgisi yok. İki seçenek:

**(A) IDB'ye `drug_class_id` + `active_ingredient` ekle** — `pullTables(['stok'])` sırasında join ile zenginleştir.

**(B) Backend RPC** — `stok_etken_filtrele(p_etken_kod)` → eşleşen stok ID'lerini döndür.

**Seçim: (A)** — Offline çalışabilirlik korunur, ek RPC call gerekmez.

`api.js`'deki `pullTables` fonksiyonunda `stok` tablosu çekilirken select'e `drug_product_id` zaten dahil. `drug_products` ve `drug_classes` tablolarını da IDB'ye çekmek gerekiyor (küçük tablolar, birkaç düzine satır).

Frontend filtreleme:

```javascript
function _etkenFiltrele(etkenKod, stoklar) {
  const ETKEN_INGREDIENT = {
    'OKSITOSIN': /oxytocin|oksitosin/i,
    'PG':        /dinoprost|cloprostenol|prostaglandin/i,
    'E_VIT':     /e vitamini|vitamin e|tocopherol/i,
    'ADEMIN':    /ademin|ade\b/i,
    'KALSIYUM':  /kalsiyum|calcium/i,
    'ROTA':      /rota|corona|e\.?\s*coli/i,
  };
  const rx = ETKEN_INGREDIENT[etkenKod];
  if (!rx) return [];

  const dcMap = {};  // drug_class_id → active_ingredient
  idbGetAll('drug_classes').forEach(dc => { dcMap[dc.id] = dc.active_ingredient; });

  const dpMap = {};  // drug_product_id → drug_class_id
  idbGetAll('drug_products').forEach(dp => { dpMap[dp.id] = dp.drug_class_id; });

  return stoklar.filter(s => {
    if (!s.kategori || ['Yem','Sperma'].includes(s.kategori)) return false;
    if (s.drug_product_id) {
      const classId = dpMap[s.drug_product_id];
      const activeIng = classId ? dcMap[classId] : null;
      if (activeIng && rx.test(activeIng)) return true;
    }
    // Fallback: urun_adi (drug_product_id olmayan eski stoklar)
    const oldRx = _ETKEN_FILTERE_LEGACY[etkenKod];
    return oldRx ? oldRx(s) : false;
  });
}
```

---

## §3 Backend: `gorev_tamamla` ↔ `hizli_uygulama` Çift Yönlü Senkronizasyon

### Mevcut Trigger Zinciri

```
hizli_uygulama → INSERT uygulama_log → trigger fn_dinle_uygulama → _gorev_dinle → gorev kapanır ✅
gorev_tamamla  → UPDATE gorev_log   → stok düşer (SADECE stok_id doluysa)                        ⚠️
```

### Sorun

Protokol görevleri (`dogum_kaydet` ile oluşturulan) `stok_id = NULL` ve `miktar = NULL` ile yaratılıyor. Görevden tamamlandığında stok düşmüyor.

### Çözüm: `gorev_tamamla`'ya Opsiyonel `p_stok_id` + `p_doz` Parametreleri

```sql
CREATE OR REPLACE FUNCTION public.gorev_tamamla(
  p_gorev_id text,
  p_padok_hedef text DEFAULT NULL,
  p_stok_id text DEFAULT NULL,    -- YENİ
  p_doz numeric DEFAULT NULL,     -- YENİ
  p_birim text DEFAULT NULL,      -- YENİ
  p_rota text DEFAULT NULL        -- YENİ
) ...
```

Fonksiyon mantığı:

```
1. Görevi tamamla (mevcut)
2. IF p_stok_id IS NOT NULL THEN
     -- Stok düşümü yap (hizli_uygulama mantığıyla aynı)
     INSERT INTO stok_hareket ...
     -- Uygulama log'a da yaz → trigger görev zaten kapanmış, _gorev_dinle idempotent
     INSERT INTO uygulama_log (hayvan_id, stok_id, etken_kod, doz, birim, rota, notlar)
     VALUES (v_gorev.hayvan_id, p_stok_id, v_gorev.etken_kod, p_doz, p_birim, p_rota, 'Görev: ' || v_gorev.aciklama);
   ELSIF v_gorev.stok_id IS NOT NULL THEN
     -- Eski davranış: görevde stok_id doluysa düş (mevcut)
     INSERT INTO stok_hareket ...
   END IF;
3. Padok değişikliği (mevcut)
```

### Frontend Etkisi

Görev detay modalında `etken_kod` dolu + `stok_id` boş ise → stok seçim formu göster (protokol mini formuyla aynı UI). Seçilen stok bilgisi `gorev_tamamla`'ya `p_stok_id, p_doz, p_birim, p_rota` olarak geçirilir.

---

## §4 Frontend: Hayvan Kartı — Hızlı Uygulama Butonu

Hayvan kartının sağlık bölümüne "Hızlı Uygulama" butonu eklenir.

**Davranış:**
1. Stok listesini göster (tüm ilaçlar, filtresiz)
2. Stok seç → doz + birim + rota + not gir
3. `hizli_uygulama` RPC çağır
4. Trigger zinciri otomatik: uygulama_log → görev kapanır → scanner güncellenir

**Konum:** Hayvan detay kartında, sağlık bilgileri bölümünün altında veya üstünde, mevcut butonların (tedavi aç, muayene vb.) yanında.

---

## §5 Frontend: İşlem Sonrası Senkronizasyon

Herhangi bir giriş noktasından işlem yapıldıktan sonra:

```javascript
async function _islemSonrasiRefresh() {
  // 1. Scanner'ı çağır
  const proto = await rpc('protokol_eksik_tara', {});
  window.__protokolUyarilar = Array.isArray(proto) ? proto : [];

  // 2. Badge güncelle
  const aktif = window.__protokolUyarilar.filter(u => u.durum === 'eksik' || u.durum === 'yaklasan');
  const bb = document.getElementById('bellbadge');
  if (bb) {
    bb.textContent = aktif.length > 99 ? '99+' : aktif.length;
    bb.style.display = aktif.length > 0 ? 'flex' : 'none';
  }

  // 3. Görev badge güncelle
  updateTaskBadge();

  // 4. Açık ekranları yenile
  if (document.getElementById('proto-detay-bs')) {
    // Protokol detay açıksa yeniden oluştur
  }
  if (document.getElementById('protokol-bs')) {
    _showProtokolEkran();
  }
}
```

Bu fonksiyon şu anda 4 yerde tekrarlanan kodu tek noktaya toplar:
- `_protokolUygulaKaydet`
- `_protokolDismiss`
- `_protokolGeriAl`
- `doneTask` (görev sekmesinden tamamlama)
- Hayvan kartı hızlı uygulama (yeni)

---

## §6 Değişiklik Özeti

| Katman | Dosya | Değişiklik |
|---|---|---|
| DB | `_etken_kod_bul` | FK zinciri öncelikli, active_ingredient bazlı eşleşme |
| DB | `gorev_tamamla` | +4 opsiyonel parametre (stok_id, doz, birim, rota), stok düşüm + uygulama_log |
| DB | ground_truth | Tüm değişiklikler senkronize |
| FE | `js/api.js` | TABLES'a `drug_products`, `drug_classes` ekle, DB_VER bump |
| FE | `js/ui.js` | `_etkenFiltrele` (drug_class bazlı), `_islemSonrasiRefresh` (ortak), hayvan kartı butonu, görev detay stok formu |
| FE | `js/forms.js` | `doneTask`'e stok parametreleri geçirme |

## §7 Kapsam Dışı

- Event Bus / Custom Events — DB trigger'ları yeterli, frontend event sistemi gereksiz karmaşıklık
- Edge Functions'a taşıma — transactional bütünlük gerekiyor, PL/pgSQL doğru yer
- `ui.js` modüler refactor — ayrı iş, bu spec'in kapsamında değil
- İkiz doğum tam desteği — mevcut backlog item
- Push notification entegrasyonu — ayrı spec

## §8 Doğruluk Matrisi (Sonrası)

| Giriş Noktası | Stok Düşer | Görev Kapanır | Scanner Görür |
|---|---|---|---|
| Görev sekmesi (`gorev_tamamla` + stok params) | ✅ | ✅ | ✅ |
| Protokol ekranı (`hizli_uygulama`) | ✅ | ✅ (trigger) | ✅ |
| Hayvan kartı (`hizli_uygulama`) | ✅ | ✅ (trigger) | ✅ |
| Tedavi modülü (`drug_administrations`) | ✅ (mevcut) | ✅ (trigger) | ✅ |
