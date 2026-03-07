# EgeSüt ERP — SPEC v3
> Her oturumun başında okunur. Hem harita hem rota. Sigortamız.
> Son güncelleme: 2026-03-07

---

## 0. MEVCUT DURUM — GERÇEK

### Tamamlanan ✅
- Migration 008 push edildi (tüm stored proc'lar, triggerlar, RLS, view)
- Modüler yapı: index.html + js/api.js + js/app.js + js/ui.js + js/forms.js
- Supabase JS SDK v2 (CDN)
- Service Worker cache v11
- pullTables / renderSafe / rpcOptimistic optimistic UI sistemi
- Hayvan kaydı (hayvan_ekle RPC)
- Irk dropdown (DB'den, kullanım sıklığına göre, "Diğer" text input)
- Tohumlama kaydı (ileri tarih engeli var)
- Görev tamamlama
- Sperma dropdown (spermaModStok / spermaModElle fonksiyonları eklendi)
- islem_log trigger (hayvanlar/dogum/tohumlama/hastalik/kizginlik)
- SECURITY DEFINER tüm stored proc'lara eklendi

### Çalışmayan / Eksik 🔴
| # | Sorun | Dosya | Sprint |
|---|---|---|---|
| 1 | Grup filtreleme — doğum tarihi bugün gelince yasGun=0, sadece "Süt İçen" çıkıyor | app.js | S1-01 |
| 2 | Tohumlama validasyonu — erkek/12ay altı tohumlanabiliyor | tohumlama_kaydet RPC | S1-02 |
| 3 | Hayvan kartından tedavi açınca küpe otomatik dolmuyor | ui.js/forms.js | S1-03 |
| 4 | Geçmiş — hayvan kaydı görünmüyor, detay/geri alma çalışmıyor | ui.js | S1-04 |
| 5 | Sürü filtrasyonu yok — dişi/erkek, gebe/boş, hasta/sağlıklı | ui.js | S2-01 |
| 6 | Hayvan detay ekranı yok — kilo/boy/notlar/timeline görünmüyor | ui.js | S2-02 |
| 7 | Hastalık formunda kategori→hastalık zinciri yok | ui.js/index.html | S2-03 |
| 8 | Hekimler DB'de değil, app.js'de sabit array | migration 009 | S2-04 |
| 9 | Abort tabı çalışmıyor — gebe listesi + abort kaydet akışı | ui.js/forms.js | S2-05 |
| 10 | Abort badge hayvan kartında yok | ui.js | S2-05 |
| 11 | Gebelik tabında "Tohumlama Ekle" butonu kaldırılmadı | ui.js | S2-06 |
| 12 | Doğum tabında tetiklenen görevler görünmüyor | ui.js | S2-06 |
| 13 | Görev renk mantığı eksik — geciken/bugün/yakın/gelecek | ui.js | S2-07 |
| 14 | Sperma stoktan gelmiyor — window._appState bağlantısı eksik | app.js | S1-05 |

### Temizlik Bekleyen 🟡
| # | Görev |
|---|---|
| T-01 | yazIslemLog() fonksiyonu kaldır — trigger yapıyor artık |
| T-02 | _gecmisFallback() kaldır — islem_log her şeyi yazıyor |
| T-03 | Eski raw fetch/HDR/SB_URL kalıntılarını temizle |
| T-04 | APP_VERSION güncelle |

---

## 1. MİMARİ

```
Frontend (JS)
  ↓ db.rpc() / db.from()
Supabase (Backend)
  • Stored Procedures  → iş mantığı + validasyon
  • Triggers           → otomatik islem_log
  • Views              → hesaplı veriler (hayvan_durum_view)
  • RLS + SECURITY DEFINER → güvenlik
  ↓
PostgreSQL (Veri)
```

**Tek kural:** Frontend hesap yapmaz. Veriyi çek, ekrana bas, aksiyonu RPC'ye gönder.

### Dosya Yapısı (Mevcut)
```
index.html      ~901 satır   — sadece HTML/CSS
js/api.js                    — Supabase client, pullTables, renderSafe, rpcOptimistic
js/app.js                    — init, routing, global state, form yardımcıları
js/ui.js        ~1501 satır  — tüm render fonksiyonları
js/forms.js                  — tüm submit fonksiyonları
sw.js           v11          — cache (tüm js dosyaları dahil)
supabase/migrations/         — 008 migration push edildi
```

### SDK Kullanım Şekli
```javascript
// Veri çek
const { data, error } = await db.from('hayvan_durum_view').select('*')

// Stored procedure
const { data, error } = await db.rpc('dogum_kaydet', {
  p_anne_id: '...', p_tarih: '...', p_kupe: '...'
})

// Hedefli sync (optimistic UI)
await pullTables(['hayvanlar', 'gorev_log'])
renderSafe()

// IndexedDB cache — offline için
await idbClearAndPut('hayvanlar', data)
```

---

## 2. VERİTABANI

### Migration Durumu
| Migration | İçerik | Durum |
|---|---|---|
| 001-005 | Temel şema, FK, triggerlar | ✅ |
| 006 | hayvan_durum_view, irk_esik, bildirim_log, islem_log, kupe_musait_mi() | ✅ |
| 007 | updated_at, bos_gun, cikis_yap(), geri_al() | ✅ |
| 008 | hayvan_ekle, dogum_kaydet, tohumlama_kaydet, kizginlik_kaydet, hastalik_kaydet, abort_kaydet, hayvan_not_ekle, triggerlar, RLS, SECURITY DEFINER | ✅ |
| 009 | hekimler tablosu, tohumlama validasyon güncelle, hayvan_timeline_view | ⏳ |

### Migration 009 — Planlanıyor
```sql
-- Hekimler tablosu
CREATE TABLE IF NOT EXISTS public.hekimler (
  id text PRIMARY KEY DEFAULT 'H'||nextval('hekimler_seq')::text,
  ad text NOT NULL,
  telefon text,
  aktif boolean DEFAULT true
);
INSERT INTO hekimler (id, ad) VALUES ('H1','Dr. Ahmet Yılmaz'),('H2','Dr. Elif Kaya')
ON CONFLICT DO NOTHING;

-- tohumlama_kaydet validasyon güncelle
-- yaş < 365 gün → hata
-- cinsiyet = 'Erkek' → hata
-- sonuc = 'Gebe' olan aktif tohumlama var → hata

-- hayvan_timeline_view — detay ekranı için
-- tüm islem_log kayıtlarını hayvan bazında göster
```

### Mevcut Stored Procedures
| Proc | Açıklama |
|---|---|
| hayvan_ekle() | Küpe kontrolü + hayvan INSERT + ırk sayacı |
| dogum_kaydet() | Doğum + buzağı + 13 görev (anne 7 + buzağı 6) |
| tohumlama_kaydet() | Tohumlama + 2 kontrol görevi + stok hareketi |
| kizginlik_kaydet() | Kızgınlık log |
| hastalik_kaydet() | Hastalık + ilaç stok hareketi + tedavi görevleri |
| abort_kaydet() | Abort + hayvan durumu güncelle |
| hayvan_not_ekle() | Nota append |
| cikis_yap() | Hayvan çıkış (satış/ölüm) |
| geri_al() | İşlem geri alma (cop_kutusu) |
| kupe_musait_mi() | Küpe kontrol |
| irk_listesi() | Dropdown için ırk listesi |

---

## 3. YOL HARİTASI

### Sprint 1 — Kritik Buglar
```
[ ] S1-01  Grup filtreleme — openM'de doğum tarihi auto-fill kaldırıldı ama hala bug var
[ ] S1-02  Tohumlama validasyonu — migration 009'a yaş+cinsiyet kontrolü
[ ] S1-03  Hayvan kartından tedavi — küpe + hayvan adı otomatik dolsun
[ ] S1-04  Geçmiş — hayvan kaydı görünsün, detay modal, geri alma
[ ] S1-05  Sperma stok bağlantısı — window._appState.stok
```

### Sprint 2 — Eksik Özellikler
```
[ ] S2-01  Sürü filtrasyonu — dişi/erkek, gebe/boş, hasta/sağlıklı, grup/padok
[ ] S2-02  Hayvan detay ekranı — kilo, boy, renk, notlar, timeline
[ ] S2-03  Hastalık formu — kategori→hastalık zinciri (tohumlama formu gibi)
[ ] S2-04  Hekimler DB'ye taşı — migration 009
[ ] S2-05  Abort akışı — gebe listesi, abort modal, badge
[ ] S2-06  Üreme tab düzeltme — gebelik butonu kaldır, doğum görevleri
[ ] S2-07  Görev renk mantığı — geciken/bugün/yakın/gelecek
```

### Sprint 3 — Gelecek
```
[ ] S3-01  Üreme sekmesi UX — ayrı tablar (kızgınlık/tohumlama/gebelik/doğum)
[ ] S3-02  Sürü ekranı — gelişmiş kart (tüm badge'ler, durum renkleri)
[ ] S3-03  Raporlar — dönemsel istatistikler
[ ] S3-04  Ayarlar ekranı — hekim/ırk/padok yönetimi
[ ] S3-05  Temizlik (T-01..T-04)
[ ] S3-06  Edge Functions değerlendirmesi
```

---

## 4. ÖZELLİK DETAYLARI

### Yaş → Grup Mantığı
```
Dişi:
  0-75 gün    → Süt İçen Buzağı
  76-180 gün  → Sütten Kesilmiş Buzağı
  181-365 gün → Düve (Küçük)
  366-730 gün → Düve (Büyük)
  730+ gün    → Sağmal (Laktasyonda) / Sağmal (Kuru) / Gebe Düve / Düve (Büyük)
  Tarih yok   → Tüm dişi gruplar

Erkek:
  0-75 gün    → Süt İçen Buzağı
  76-180 gün  → Sütten Kesilmiş Buzağı
  180+ gün    → Besi
  Tarih yok   → Besi / Sütten Kesilmiş Buzağı
```

### Grup → Padok Haritası
```
Sağmal (Laktasyonda)   → Sağmal Padok
Sağmal (Kuru)          → Kuru/Gebe Padok
Gebe Düve              → Kuru/Gebe Padok
Düve (Büyük)           → Düve Padok (Büyük)
Düve (Küçük)           → Düve Padok (Küçük)
S�t İçen Buzağı        → Buzağı Padok (Süt İçenler)
S�tten Kesilmiş Buzağı → Buzağı Padok (Sütten Kesilmiş)
Besi                   → Düve Padok (Büyük), Düve Padok (Küçük), Sağmal Padok
```

### Görev Renk Mantığı
```
geciken  (< bugün)   → kırmızı bg, badge sayısına dahil
bugün    (= bugün)   → amber bg, badge sayısına dahil
yakın    (1-3 gün)   → sarı, uyarı ikonu, badge'e dahil değil
gelecek  (> 3 gün)   → normal, uyarı yok
```

### Abort Akışı
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

### Geçmiş Etiketleri
```
DOGUM_KAYDI    → "🐄 Doğum Kaydı"
TOHUMLAMA      → "💉 Tohumlama"
HASTALIK_KAYDI → "🏥 Hastalık Kaydı"
HAYVAN_EKLENDI → "🐮 Hayvan Eklendi"
SUTTEN_KESME   → "🍼 Sütten Kesme"
SATIS_KAYDI    → "💰 Satış"
OLUM_KAYDI     → "💀 Ölüm"
ABORT_KAYDI    → "⚠️ Abort"
KIZGINLIK      → "🔴 Kızgınlık"
TEDAVI_GUNCELLE→ "💊 Tedavi Güncelleme"
```

### Irk Alanı
```
[Holstein ▼] seçilince → text input gizli
[+ Diğer]   seçilince → text input açılır, kullanıcı yazar
```
- Dropdown: irk_esik tablosundan, kullanim_sayisi DESC
- Sabit fallback: Holstein, Simental, Montofon, Jersey, Angus, Diğer

---

## 5. OTURUM KURALLARI

1. **Her oturum tek sprint item.** Bitmeden yenisine geçme.
2. **Küçük değişiklik** → sadece değişen kod bloğunu at, tüm dosyayı değil.
3. **Bug önce konsol hatası.** "Çalışmıyor" yetmez, hata mesajı lazım.
4. **Migration her zaman idempotent.** DROP IF EXISTS + CREATE OR REPLACE.
5. **RLS her yeni tabloda.** Tablo ekle = policy ekle = SECURITY DEFINER ekle.
6. **Oturum başı:** SPEC.md oku, hangi sprint item'dan devam edildiğini söyle.
7. **Oturum sonu:** SPEC.md güncelle, tamamlananları işaretle.

---

## 6. TEKNİK REFERANS

### Bağlantı
```
Supabase URL : https://zqnexqbdfvbhlxzelzju.supabase.co
Live URL     : https://meliksahtokur.github.io/egesut-erp1/
IndexedDB    : egesut_v9, DB_VER=6
Repo         : github.com/meliksahtokur/egesut-erp1
```

### Global State
```javascript
window._appState = {
  hayvanlar: [],   // hayvan_durum_view
  stok: [],        // stok tablosu
  gorevler: [],    // gorev_log
  gecmis: [],      // islem_log
  bildirimler: [], // bildirim_log
}
```

### Önemli Fonksiyonlar
```javascript
pullTables(['tablo'])      // hedefli fetch, _pulling lock ile race condition koruması
renderSafe()               // 60ms debounce render, spam önler
rpcOptimistic(fn, tables)  // toast → rpc → background pullTables → renderSafe
loadIrkDropdown()          // irk_esik'ten dropdown doldur
animalFormGuncelle()       // cinsiyet+yaş → grup filtrele
animalGrupDegisti()        // grup → padok filtrele
spermaModStok()            // sperma stoktan seç modu
spermaModElle()            // sperma elle gir modu
```
