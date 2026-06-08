# Mevcut Altyapı Envanteri

## 1. Backend (Supabase RPC'ler)

### `padok_degistir` — Tekli Transfer RPC

| Özellik | Detay |
|---------|-------|
| **Dosya** | `supabase/migrations/20260512000001_padok_degistir_rpc.sql` |
| **İmza** | `padok_degistir(p_hayvan_id text, p_yeni_padok_id uuid, p_not text DEFAULT NULL)` |
| **İşlem** | 1. Hayvan var mı? 2. Hedef padok var mı? 3. Zaten aynı padokta mı? 4. `UPDATE hayvanlar SET padok_id, padok` 5. `INSERT islem_log` |
| **Güvenlik** | SECURITY DEFINER |
| **Rollback** | Transactional — tüm adımlar tek transaction |

### `padok_degistir_toplu` — Toplu Transfer RPC

| Özellik | Detay |
|---------|-------|
| **Dosya** | `supabase/migrations/20260512000002_padok_degistir_toplu_rpc.sql` |
| **İmza** | `padok_degistir_toplu(p_hayvan_ids text[], p_yeni_padok_id uuid)` |
| **İşlem** | Her hayvan için loop: 1. Var mı? 2. Zaten aynı padokta mı? 3. UPDATE + islem_log |
| **Dönüş** | `{ success, basarili, basarisiz, hatalar[], yeni_padok, yeni_padok_id }` |
| **Hata yönetimi** | EXCEPTION WHEN OTHERS — her hayvan bağımsız, hatalar dizi olarak döner |

### `gorev_tamamla` — Görev Tamamlama (Padok Hedefli)

| Özellik | Detay |
|---------|-------|
| **İmza** | `gorev_tamamla(p_gorev_id text, p_padok_hedef text)` |
| **Kullanım** | Görev tamamlanırken `padok_hedef` varsa hayvanın padok'u güncellenir |
| **Frontend** | `doneTask()` → `rpc('gorev_tamamla', { p_gorev_id, p_padok_hedef })` |

## 2. Frontend — JS Fonksiyonları (ui.js)

### Durum Değişkenleri

```
5450: let _pdHayvanIds = [];        // Seçili hayvan ID'leri (checkbox)
5451: let _pdTransferHayvanIds = []; // Onay bekleyen hayvan ID'leri
5452: let _pdKaynakPadokId = null;  // Kaynak padok ID
```

### Fonksiyonlar

| Fonksiyon | Satır | Açıklama |
|-----------|-------|----------|
| `padokDetayAc(id)` | 5454-5467 | Padok detay modal'ını açar, hayvan listesini yükler |
| `renderPadokHayvanlar(padokId)` | 5469-5507 | Padoktaki aktif hayvanları checkbox'lu liste olarak render eder |
| `pdToggleHayvan(id, checked)` | 5509-5516 | Checkbox toggle — seçimi günceller, "Toplu Taşı" butonunu gösterir/gizler |
| `padokTekliTasi(hayvanId, kupe)` | 5518-5522 | Tek hayvan transfer akışını başlatır |
| `padokTopluTasi()` | 5524-5529 | Seçili hayvanları toplu transfer akışına gönderir |
| `_pdTransferAcSelector()` | 5531-5543 | Transfer modal'ını açar, padok dropdown'ını doldurur (kaynak padok hariç) |
| `padokTransferOnayla()` | 5545-5578 | Transferi onaylar — tekliyse `padok_degistir`, topluysa `padok_degistir_toplu` RPC çağırır |

### Diğer Padok İlişkili Fonksiyonlar

| Fonksiyon | Dosya/Satır | Açıklama |
|-----------|-------------|----------|
| `padokDuzenleKaydet()` | ui.js:5418-5422 | Padok adı/kapasite güncelleme |
| `padokSilOnay()` | ui.js:5432-5443 | Padok silme (önce aktif hayvan kontrolü) |
| `doneTask(id, hid, stokId, miktar, padok, btn)` | forms.js:826-841 | Görev tamamlama + padok_hedef güncellemesi |
| `animalGrupDegisti()` | app.js:335-357 | Grup değişince padok dropdown'ını GRUP_PADOK mapping'ine göre doldurur |
| `animalFormGuncelle()` | app.js:255-333 | Cinsiyet+yaş'a göre grup seçeneklerini hesaplar |
| `submitAnimal(btn)` | forms.js:26-103 | Hayvan ekleme/güncelleme — `p_padok_id` gönderir |

## 3. Frontend — Handler Kayıtları (handlers.js)

```
238: 'padok-duzenle-kaydet': () => padokDuzenleKaydet(),
239: 'padok-sil-onay':       () => padokSilOnay(),
240: 'padok-input':          () => { if (_pdKaynakPadokId) renderPadokHayvanlar(_pdKaynakPadokId); },
241: 'close-padok-det':      () => closeM('m-padok-det'),     (line 115)
242: 'close-padok-transfer': () => closeM('m-padok-transfer'), (line 116)
243: 'padok-toplu-tasi':     () => padokTopluTasi(),           (line 242)
244: 'padok-transfer-onay':  () => padokTransferOnayla(),      (line 243)
```

## 4. HTML Modal Yapısı

### `m-padok-det` (1746-1779)

```
├── #padok-det-title (h3)
├── #pd-edit-section
│   ├── #pd-ad (input) — padok adı
│   ├── #pd-kap (input, number) — kapasite
│   ├── [data-action=padok-duzenle-kaydet] — kaydet butonu
│   └── [data-action=padok-sil-onay] — sil butonu
├── #pd-hayvan-section
│   ├── #pd-hayvan-sayisi (span) — hayvan sayısı
│   ├── #pd-hayvan-filtre (input) — arama filtresi
│   ├── #pd-toplu-tasi-btn (button, hidden) — "📦 Seçilenleri Taşı"
│   └── #pd-hayvan-listesi (div) — hayvan listesi
│       ├── checkbox → onchange="pdToggleHayvan(...)"
│       └── button → onclick="padokTekliTasi(...)"  (➡️)
```

### `m-padok-transfer` (1782-1796)

```
├── #pt-title (h3) — "Padok Seç"
├── #pt-bilgi (div) — bilgi mesajı (ör: "📦 5 hayvan → hedef padok seçin:")
├── #pt-select (select) — hedef padok dropdown
└── [data-action=padok-transfer-onay] — "✅ Taşı" butonu
```

### `a-padok` Seçici (index.html ~958-960)

```
<select id="bi-padok" class="fsel" data-change="bi-load">
  <option value="">— Padok Seç —</option>
</select>
```

## 5. GRUP_PADOK Mapping (config.js)

```
'Sağmal (Laktasyonda)':      ['Sağmal Padok'],
'Sağmal (Kuru)':             ['Kuru/Gebe Padok'],
'Gebe Düve':                 ['Kuru/Gebe Padok'],
'Gebe İnek':                 ['Kuru/Gebe Padok'],
'Düve (Büyük)':              ['Düve Padok (Büyük)'],
'Düve (Küçük)':              ['Düve Padok (Küçük)'],
'Süt İçen Buzağı':           ['Buzağı Padok (Süt İçenler)'],
'Sütten Kesilmiş Buzağı':    ['Buzağı Padok (Sütten Kesilmiş)'],
'Besi':                      ['Besi Padok (Erkek)', 'Besi Padok (Dişi)'],
```

`loadPadokConfig()` DB'den `padoklar` + `grup_padok_eslem` tablolarını okuyarak bu mapping'i dinamik olarak günceller.

## 6. Kapasite Kontrolü Durumu

| Durum | Detay |
|-------|-------|
| **Kapasite verisi DB'de** | ✅ `padoklar.kapasite` kolonu var, frontend'de gösteriliyor |
| **UI'da gösterim** | ✅ `renderAyarlarPadokList` kapasiteyi "(N baş)" olarak gösterir |
| **Transfer öncesi kapasite kontrolü** | ❌ YOK — hiçbir yerde hedef padok kapasitesi kontrol edilmez |
| **RPC tarafında kontrol** | ❌ YOK — `padok_degistir` ve `padok_degistir_toplu` kapasite kontrolü yapmaz |

## 7. Mevcut Araştırma / Plan Dokümanları

| Dosya | İçerik |
|-------|--------|
| `.claude/notes/padok-transfer-arastirma.md` | 2026-05-21 araştırması: mevcut durum, eksikler |
| `.claude/ideas/padok-transfer-ux.md` | 2026-05-25 UX fikri: sürü dashboard'ından bottom action bar |
| `docs/feature-status-2026-05-13.md` | Özellik durumu: "Toplu padok değişimi ✅ tamam" |
| `docs/superpowers/plans/2026-05-13-asama3-ui.md` | Aşama 3 UI planı: handler tanımları |
| `.claude/domain-rules.md` | Grup-padok mapping kuralları |
