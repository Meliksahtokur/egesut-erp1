# EgeSüt ERP — Ana Spec Dosyası v2
> Her oturumun başında okunur, sonunda güncellenir.
> Son güncelleme: 2026-03-06 — v2 başlangıcı (test raporu sonrası yeniden yapılanma)

---

## 0. GÖREV LİSTESİ — İLERLEME TAKİBİ

> Tamamlanan görevin yanına `+` koy. Oturum başında buradan devam edilir.

### BLOK 1 — Backend Temeli (Migration 008)
```
[ ] B-01  dogum_kaydet()       stored procedure
[ ] B-02  tohumlama_kaydet()   stored procedure
[ ] B-03  kizginlik_kaydet()   stored procedure  (yaş + cinsiyet kontrolü)
[ ] B-04  hastalik_kaydet()    stored procedure
[ ] B-05  hayvan_ekle()        stored procedure  (kupe kontrolü + irk sayacı)
[ ] B-06  abort_kaydet()       stored procedure
[ ] B-07  islem_log otomatik trigger (her işlemde DB seviyesi)
[ ] B-08  Doğum sonrası görev trigger'ı (anne protokol + buzağı bakım)
[ ] B-09  hayvan_durum_view güncelle (notlar, abort_sayisi)
[ ] B-10  irk_esik.kullanim_sayisi kolonu ekle
[ ] B-11  hayvanlar.notlar kolonu ekle
[ ] B-12  Migration 008 push
```

### BLOK 2 — Supabase JS SDK Geçişi
```
[ ] S-01  supabase-js CDN import (index.html head)
[ ] S-02  api.js oluştur — createClient + tüm sorgu fonksiyonları
[ ] S-03  sbGet() → db.from().select()
[ ] S-04  sbPost() → db.from().insert()
[ ] S-05  sbPatch() → db.from().update()
[ ] S-06  rpc çağrıları → db.rpc()
[ ] S-07  Eski fetch/HDR/SB_URL kodunu kaldır
```

### BLOK 3 — Dosya Bölme
```
[ ] F-01  js/api.js    — tüm Supabase çağrıları
[ ] F-02  js/ui.js     — tüm render/HTML fonksiyonları
[ ] F-03  js/forms.js  — tüm submit fonksiyonları
[ ] F-04  js/app.js    — init, routing, global state
[ ] F-05  index.html   — sadece HTML/CSS + script tag'leri (~1500 satır)
[ ] F-06  sw.js güncelle — js/*.js cache'e ekle
```

### BLOK 4 — Özellik Düzeltmeleri
```
[ ] O-01  Irk alanı: dropdown (irk_esik) + serbest giriş yan yana
[ ] O-02  Irk dropdown: kullanim_sayisi DESC sıralı
[ ] O-03  Kızgınlık: sadece >= 12 ay dişi hayvanlar (backend kontrolü)
[ ] O-04  Hayvan kartı: Notlar butonu + not ekleme
[ ] O-05  Geçmiş: HAYVAN_EKLENDI işlemi görünsün
[ ] O-06  Geçmiş: her satırda ikon + okunabilir metin
[ ] O-07  Görevler: geciken/bugün/yakın/gelecek renk mantığı
[ ] O-08  Görevler: gelecek görevler uyarı rengi olmadan listele
[ ] O-09  Gebelik tab: "Tohumlama Ekle" butonu kaldır
[ ] O-10  Doğum tab: anne+buzağı listesinde tetiklenen görevler
[ ] O-11  Abort tab: gebe listele + abort kaydet akışı
[ ] O-12  Hayvan kartı: abort geçmişi badge göster
```

### BLOK 5 — Temizlik
```
[ ] T-01  DB_VER = 6 (IndexedDB)
[ ] T-02  yazIslemLog() kaldır (trigger yapıyor artık)
[ ] T-03  _gecmisFallback() kaldır (islem_log her şeyi yazıyor)
[ ] T-04  Eski raw fetch kalıntılarını temizle
[ ] T-05  APP_VERSION güncelle
```

---

## 1. MİMARİ KARAR — "ÇAĞIR & GÖSTER"

```
┌─────────────────────────────────────────┐
│  Browser                                │
│  ┌──────────────┐  ┌─────────────────┐  │
│  │  HTML / CSS  │  │   JS (4 dosya)  │  │
│  │  Görsel yapı │  │  Çağır & Göster │  │
│  │  Değişmez    │  │  Hesap yapmaz   │  │
│  └──────────────┘  └────────┬────────┘  │
└───────────────────────────── │ ──────────┘
                               │ Supabase JS SDK
┌──────────────────────────────▼──────────┐
│  Supabase (Gerçek Backend)              │
│  • Stored Procedures  (iş mantığı)      │
│  • Triggers           (otomatik log)    │
│  • Views              (hesap + badge)   │
│  • islem_log          (tüm geçmiş)      │
└─────────────────────────────────────────┘
```

**Tek kural:** Frontend hiçbir şey hesaplamaz.
1. Supabase'den veri çek
2. Ekrana bas
3. Kullanıcı aksiyonunu stored procedure'e gönder

---

## 2. TEKNİK ALTYAPI

### Mevcut Dosyalar
| Dosya | Durum | Hedef |
|---|---|---|
| `index.html` | ~4484 satır, her şey burada | Sadece HTML/CSS, ~1500 satır |
| `sw.js` | Service Worker | Yeni JS dosyalarını cache'e alacak |
| `manifest.json` | PWA | Değişmez |
| `supabase/migrations/` | 7 dosya | +1 dosya (008) |

### Hedef Dosya Yapısı
```
index.html          → HTML/CSS + <script src="js/..."> tag'leri
js/
  app.js            → init(), goTo(), global state (_A, _S, _curPg...)
  api.js            → createClient, tüm db sorguları
  ui.js             → loadDash(), renderAnimals(), loadUreme()...
  forms.js          → submitBirth() → db.rpc('dogum_kaydet')...
sw.js               → cache: ['/', '/js/app.js', '/js/api.js', ...]
```

### Supabase
- **URL:** `https://zqnexqbdfvbhlxzelzju.supabase.co`
- **IndexedDB:** `egesut_v9`, `DB_VER` → 5'ten 6'ya çıkacak
- **SDK:** `@supabase/supabase-js` v2 CDN — build pipeline yok
- **RLS:** Kapalı

### SDK Kullanım Şekli
```javascript
// js/api.js
const { createClient } = window.supabase
const db = createClient(SB_URL, SB_KEY)

// Veri çek
const { data, error } = await db.from('hayvan_durum_view').select('*')

// Stored procedure
const { data, error } = await db.rpc('dogum_kaydet', {
  p_anne_id: '...', p_tarih: '...', p_kupe: '...'
})

// IndexedDB cache — offline için
await idbClearAndPut('hayvanlar', data)
```

---

## 3. VERİTABANI

### Mevcut Migration'lar (Uygulandı)
| Dosya | İçerik |
|---|---|
| 001-005 | Temel şema, FK, trigger'lar |
| 006 | hayvan_durum_view, irk_esik, bildirim_log, islem_log, kupe_musait_mi() |
| 007 | updated_at, bos_gun, cikis_yap(), geri_al() |

### Migration 008 — Planlanıyor

**Yeni kolonlar:**
```sql
ALTER TABLE hayvanlar ADD COLUMN IF NOT EXISTS notlar text;
ALTER TABLE irk_esik  ADD COLUMN IF NOT EXISTS kullanim_sayisi integer DEFAULT 0;
```

**Stored Procedures:**

`dogum_kaydet(p_anne_id, p_tarih, p_kupe, p_cins, p_tip, p_kg, p_baba, p_hekim_id)`
- dogum INSERT
- hayvanlar INSERT (buzağı)
- gorev_log INSERT × 13 (anne 7 protokol + buzağı 6 bakım)
- tohumlama UPDATE → sonuc='Doğum Yaptı'
- RETURNS jsonb {ok, buzagi_id, gorev_sayisi}

`tohumlama_kaydet(p_hayvan_id, p_tarih, p_sperma, p_hekim_id)`
- Kontrol: cinsiyet=Erkek? yas<365? zaten gebe?
- tohumlama INSERT
- gorev_log INSERT × 2 (21. ve 35. gün)
- stok_hareket INSERT (sperma)
- irk_esik.kullanim_sayisi UPDATE
- RETURNS jsonb {ok, mesaj}

`kizginlik_kaydet(p_hayvan_id, p_tarih, p_belirti, p_notlar)`
- Kontrol: cinsiyet=Erkek? yas<365?
- kizginlik_log INSERT
- RETURNS jsonb {ok, mesaj}

`hastalik_kaydet(p_hayvan_id, p_tani, p_kategori, p_siddet, p_semptomlar, p_lokasyon, p_ilaclar jsonb, p_tedavi_gun, p_hekim_id)`
- hastalik_log INSERT
- stok_hareket INSERT (her ilaç)
- gorev_log INSERT (tedavi günleri)
- RETURNS jsonb {ok, hastalik_id}

`hayvan_ekle(p_kupe_no, p_devlet_kupe, p_irk, p_cinsiyet, p_dogum_tarihi, p_grup, p_padok, p_dogum_kg, p_anne_id, p_baba_bilgi)`
- kupe_musait_mi() kontrolü
- hayvanlar INSERT
- irk_esik.kullanim_sayisi UPDATE
- RETURNS jsonb {ok, hayvan_id, mesaj}

`abort_kaydet(p_tohumlama_id, p_notlar)`
- tohumlama UPDATE → sonuc='Abort', abort_notlar=p_notlar
- hayvanlar UPDATE → tohumlama_durumu=NULL
- RETURNS jsonb {ok}

**Trigger — islem_log otomatik:**
```sql
-- dogum INSERT → islem_log INSERT (DOGUM_KAYDI)
-- tohumlama INSERT → islem_log INSERT (TOHUMLAMA)
-- hayvanlar INSERT → islem_log INSERT (HAYVAN_EKLENDI)
-- tohumlama UPDATE sonuc='Abort' → islem_log INSERT (ABORT_KAYDI)
```

**hayvan_durum_view güncellemesi:**
```sql
-- notlar kolonu eklenir
-- abort_sayisi: tohumlama tablosundan COUNT WHERE sonuc='Abort'
```

---

## 4. ÖZELLİK DETAYLARI

### Irk Alanı (O-01/02)
```
[Holstein ▼] [____________ serbest giriş]
  Montofon        ↑
  Simmental   bilinmeyenler buraya
  ...
```
- Sol: `irk_esik` tablosundan, `kullanim_sayisi DESC`
- Sağ: serbest metin, backend'de `diger` grubuna eklenir
- Form gönderilince: sol seçildiyse sol değer, sağ yazıldıysa sağ değer

### Görev Renkleri (O-07/08)
```
geciken  (< bugün)    → kırmızı bg, badge'e dahil
bugün    (= bugün)    → amber bg, badge'e dahil
yakın    (1-3 gün)    → sarı, uyarı ikonu var, badge'e dahil değil
gelecek  (> 3 gün)    → normal, uyarı yok, liste görünümü
```

### Abort Akışı (O-11/12)
```
Abort tab açılır
  → "Gebe Hayvanları Listele" butonu
  → Liste: gebelik günü ASC, küpe arama
  → Hayvan seçilir → "Abort Kaydet" butonu
  → Modal: "⚠️ Bu işlem geri alınamaz. {kupe} hayvanının gebeliği sonlandırılacak."
  → Onay → abort_kaydet() RPC
  → Hayvan boş olarak düşer
  → Hayvan kartında: "⚠️ {n} Abort" kırmızı badge
```

### Geçmiş Metin Etiketleri (O-06)
```
DOGUM_KAYDI    → "🐄 Doğum Kaydı"
TOHUMLAMA      → "💉 Tohumlama"
HASTALIK_KAYDI → "🏥 Hastalık Kaydı"
HAYVAN_EKLENDI → "🐮 Hayvan Eklendi"
SUTTEN_KESME   → "🍼 Sütten Kesme"
SATIS_KAYDI    → "💰 Satış"
OLUM_KAYDI     → "💀 Ölüm"
ABORT_KAYDI    → "⚠️ Abort"
```

---

## 5. SIRALAMA MANTIĞI

```
BLOK 1 → BLOK 2 → BLOK 3 → BLOK 4 → BLOK 5
Backend   SDK       Dosya    Özellik  Temizlik
```

- BLOK 1 olmadan BLOK 4 yapılırsa → frontend'e iş mantığı eklenir, yanlış
- BLOK 2 olmadan BLOK 3 yapılırsa → dosya bölme yarım kalır
- BLOK 3 olmadan BLOK 4 yapılırsa → yine 4500 satırlık dosyaya eklenir
- **Bir oturumda bir blok. Blok ortasında bırakılmaz.**

---

## 6. BİLİNEN SORUNLAR

| # | Sorun | Görev |
|---|---|---|
| 1 | Irk serbest giriş | O-01/02 |
| 2 | Hayvan kaydı geçmişte yok | B-07, O-05 |
| 3 | Görev sayısı tutarsız | O-07/08 |
| 4 | Kızgınlık yaş/cinsiyet filtresi yok | B-03, O-03 |
| 5 | Notlar butonu yok | B-11, O-04 |
| 6 | Abort tabı çalışmıyor | B-06, O-11/12 |
| 7 | Geçmiş işlem metin yok | O-06 |
| 8 | Doğum tab görevler yok | O-10 |
| 9 | Gebelik tabı ekstra buton | O-09 |
| 10 | islem_log eksik | B-07 |
