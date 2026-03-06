# EgeSüt ERP — Proje Spec Dosyası
> **Bu dosya her oturumun başında okunur. Her oturumun sonunda güncellenir.**
> Son güncelleme: 2026-03-06

---

## 1. TEKNİK ALTYAPI

### Dosyalar
| Dosya | Konum | Açıklama |
|---|---|---|
| `index.html` | repo root | Tek dosya uygulama, ~3881 satır |
| `sw.js` | repo root | Service Worker v13 — index.html HİÇ cache'lenmez |
| `manifest.json` | repo root | PWA manifest |
| `supabase/migrations/` | repo | 6 migration dosyası |

### Deployment
- **GitHub Pages** üzerinde çalışır
- Push → Actions otomatik deploy
- SW stratejisi: `cache-first` statik assets, `network-only` index.html

### Supabase
- **URL:** `https://zqnexqbdfvbhlxzelzju.supabase.co`
- **DB adı:** `egesut_v9`
- **IndexedDB version:** `DB_VER = 4`
- **RLS:** Kapalı (tek kullanıcı, ileride açılacak)

### IndexedDB Stores (TABLES array)
```javascript
['hayvanlar','tohumlama','hastalik_log','dogum','stok',
 'stok_hareket','gorev_log','buzagi_takip','kizginlik_log','bildirim_log']
```
⚠️ `islem_log` ve `cop_kutusu` migration'da var ama TABLES'a **eklenmemiş** — Faz 3'te eklenecek.

---

## 2. KESİNLEŞEN MİMARİ — "BANKA MODELİ"

### Backend (Supabase) = Banka, tek otorite
- Tüm kalıcı veriler
- Tüm iş kuralları ve validasyon
- Badge ve kategori hesaplamaları (`hayvan_durum_view`)
- Bildirim kararları (GitHub Actions → REST, 3 saatte bir)
- Cascade işlemler (stored procedure — Faz 3)
- İşlem log'u / audit trail (`islem_log` — Faz 3)
- Çöp kutusu, 30 gün saklama (`cop_kutusu` — Faz 3)

### Frontend = Vezneci
- Form göster → kullanıcı inputunu topla → backend'e gönder
- Backend view'larını render et (hesaplama yapma)
- Offline tampon: sadece okuma + temel veri girişi
- Startup sync ekranı (Faz 6)

### Offline Kuralları (kesinleşti)
**Offline'da İZİN VERİLENLER:**
- Hayvan listesi görüntüleme
- Doğum, hastalık, tohumlama kaydı girişi

**Offline'da YASAK:**
- Geri alma işlemleri (backend transaction gerekiyor)
- Ölüm/satış kaydı (cascade etkisi var)
- Bildirim yönetimi

**Çakışma politikası:** Yetki seviyesi yüksek olan kazanır. Eşit yetkide timestamp kazanır. (Çoklu kullanıcıya geçince aktif olur)

---

## 3. VERİTABANI ŞEMASI

### Migration Dosyaları
| Dosya | İçerik | Durum |
|---|---|---|
| `20260303000001_initial_schema.sql` | Temel tablolar | ✅ Uygulandı |
| `20260303000002_add_columns.sql` | Ek kolonlar | ✅ Uygulandı |
| `20260303000003_fixes.sql` | Düzeltmeler | ✅ Uygulandı |
| `20260303000004_foreign_keys.sql` | FK kısıtları | ✅ Uygulandı |
| `20260303000005_triggers.sql` | `set_deneme_no` trigger | ✅ Uygulandı |
| `20260306000006_faz1_core.sql` | Faz 1 tam şema | ✅ Uygulandı |

### Mevcut Tablolar (Faz 1 sonrası)
```
hayvanlar         — Ana hayvan kaydı
  + kategori, suttten_kesme_tarihi, tohumlama_onay_tarihi
  + tohumlama_durumu (NULL|tohumlanabilir|tohumlandi|gebe|ertelendi)
  + cikis_tipi (olum|satis), cikis_tarihi, cikis_sebebi, satis_fiyati

tohumlama         — Tohumlama kayıtları
  + dogum_tarihi, buzagi_kupe, abort_notlar

hastalik_log      — Hastalık/tedavi kayıtları
  + lokasyon, siddet

dogum             — Doğum kayıtları
  + hekim_id

gorev_log         — Görev ve takip
  + kaynak, iptal, padok_hedef, hekim_id, miktar

kizginlik_log     — Kızgınlık gözlemleri (YENİ)
stok              — Stok ürünleri
stok_hareket      — Stok hareketleri
buzagi_takip      — Buzağı takip

irk_esik          — Irk bazlı eşikler (YENİ)
  Holstein: tohumlama=365g, suttten_kesme=60g
  Montofon: tohumlama=420g, suttten_kesme=60g
  Simmental: tohumlama=400g, suttten_kesme=60g
  Jersey: tohumlama=365g, suttten_kesme=56g

bildirim_log      — Backend yazar, frontend okur (YENİ)
  durum: bekliyor|goruldu|ertelendi|tamamlandi|iptal

islem_log         — İşlem audit trail / geri alma (YENİ, Faz 3'te kullanılacak)
  snapshot: jsonb — {olusturulan, guncellenen, silinen}

cop_kutusu        — Silinen kayıtlar 30 gün (YENİ, Faz 3'te kullanılacak)
```

### Views
```
hayvan_durum_view     — Tüm badge + kategori hesabı burada
  → hesap_kategori, tohumlama_bildirisi_gerekli
  → suttten_kesme_bildirisi_gerekli, dogum_yaklasti
  → dogum_gecikme_gun, aktif_hastalik_sayisi
  → toh_sonuc, toh_gun, toh_tarih, sperma
  SADECE durum=Aktif hayvanları döndürür

gebelik_ozet_view     — Son 12 ay gebelik istatistikleri
hastalik_istatistik_view — Tanı bazlı istatistik
stok_tuketim_view     — Güncel stok seviyeleri
```

### Stored Procedures
```
kupe_musait_mi(p_kupe_no, p_devlet_kupe, p_hayvan_id?)
  → {musait: bool, kupe_cakisma_id, devlet_cakisma_id}
  Duplikasyon kontrolü için kullanılır
```

---

## 4. FRONTEND MİMARİSİ

### Global State
```javascript
_A          = []          // Aktif hayvanlar (hayvan_durum_view'dan)
_S          = []          // Stok listesi
_curStk     = null        // Seçili stok
_curPg      = 'dash'      // Mevcut sayfa
_gebeIds    = []          // Gebe hayvan ID'leri
_gebeGunMap = {}          // hayvan_id → gebelik gün sayısı
_bosGunMap  = {}          // hayvan_id → boş gün sayısı
_suruFilter = 'tumuu'     // Sürü filtresi
_suruSiralama = 'kupe'    // 'kupe' | 'yas'
_curUremeTab = 'kizginlik'
_curGecmisFilter = 'hepsi'
_curTaskFilter = 'today'
```

### Veri Akışı
```
Supabase → pullFromSupabase() → IndexedDB → getData()/idbGetAll() → render
                                     ↑
                              write() → queue → syncNow()
```

### Core Fonksiyonlar
| Fonksiyon | Açıklama |
|---|---|
| `write(table, data, method, filter)` | POST/PATCH/DELETE — online ise direkt, offline ise queue |
| `getData(table, filterFn)` | IndexedDB'den filtreli veri çeker |
| `pullFromSupabase()` | Supabase'den çeker, IndexedDB'ye yazar |
| `syncNow()` | Queue'daki bekleyen işlemleri gönderir |
| `renderFromLocal()` | IndexedDB'den okuyarak tüm sayfaları günceller |
| `refreshAll()` | pullFromSupabase + renderFromLocal |

### Sayfalar (goTo ile navigate)
```
dash      → loadDash()
suru      → loadAnimals() + renderAnimals()
tasks     → loadTasks()
ureme     → loadUreme() [kizginlik|tohumlama|gebelik|dogum]
gecmis    → loadGecmis()
cikanlar  → loadCikanlar()  ← YENİ (Faz 2)
log       → loadBirths() + loadStokList()
```

---

## 5. FAZ DURUMU

### ✅ FAZ 1 — Veri Modeli (TAMAMLANDI)
- [x] `kizginlik_log`, `irk_esik`, `bildirim_log`, `islem_log`, `cop_kutusu` tabloları
- [x] Hayvanlar tablosuna yaşam döngüsü kolonları
- [x] `hayvan_durum_view` + raporlama view'ları
- [x] `kupe_musait_mi()` fonksiyonu

### ⚠️ FAZ 2 — Hayvan Yaşam Döngüsü (KISMI)

**Tamamlananlar:**
- [x] `hayvan_durum_view` entegrasyonu (pullFromSupabase view'ı çekiyor)
- [x] `bildirim_log` TABLES'a eklendi
- [x] Duplikasyon kontrolü (`kupe_musait_mi` çağrısı submitAnimal'da)
- [x] Ölüm/satış modal (`m-cikis`, `openCikis`, `submitCikis`)
- [x] Sürüden çıkanlar sayfası (`pg-cikanlar`, `loadCikanlar`)
- [x] Nav'a "Çıkanlar" butonu eklendi
- [x] Sıralama: küpe no veya yaşa göre (`suruSirala`, `setSirala`)
- [x] View alanları renderAnimals'da kullanılıyor (`toh_sonuc`, `hesap_kategori`, `tohumlama_bildirisi_gerekli`)
- [x] Kategori badge (`kategoriTxt` + `katBadge`)

**EKSİK — Paket B:**
- [ ] **Sütten kesme** — Süt İçen listesinde toplu seçim + hayvan kartında buton
  - Sadece `hesap_kategori === 'sut_icen'` hayvanlar için
  - Tek yönlü, bir defaya mahsus
  - `suttten_kesme_tarihi` alanını doldurur
  - Hayvan kartında buton (`openDet` içinde koşullu)
  - Üreme sekmesindeki süt içenler listesinde "Sütten Kes" butonu + checkbox
- [ ] **Tohumlanabilir onay** — `tohumlama_bildirisi_gerekli=true` hayvanlar için
  - Onay verilince: `tohumlama_durumu='tohumlanabilir'`, `tohumlama_onay_tarihi=bugun`
  - Erteleme: `tohumlama_durumu='ertelendi'` + 1/2/3 ay sonra bildirim
  - Badge: 💉 Tohumlanabilir (onaylanmışsa), mavi — gebe olunca düşer
  - UI: bildirim ekranından veya hayvan kartından onay/ertele

**MİMARİ SORUN — henüz çözülmedi:**
- `_gebeGunMap` ve `_bosGunMap` hâlâ frontend'de hesaplanıyor
  → view'dan `toh_gun` geliyor, yeterince kullanılmıyor
  → Faz 2 tamamlanırken bu hesaplar kaldırılmalı

### ❌ FAZ 3 — İşlem Geçmişi + Geri Alma
- [ ] `islem_log` entegrasyonu — her write() işleminde snapshot kaydı
  - `submitBirth`, `submitInsem`, `submitCikis`, `submitDisease`, `suttenKes`
  - Snapshot formatı: `{olusturulan:[...], guncellenen:[...], silinen:[...]}`
- [ ] `cop_kutusu` entegrasyonu — silmelerde buraya yaz
- [ ] Geri alma UI — Geçmiş sekmesinde her işleme "Geri Al" butonu
  - Onay ekranı: "Emin misiniz? Şu kayıtlar etkilenecek: ..."
  - Cascade: bağlı tüm kayıtlar birlikte geri alınır
- [ ] `islem_log` TABLES'a eklenmeli (IndexedDB store)
- [ ] `cop_kutusu` TABLES'a eklenmeli

### ❌ FAZ 4 — Bildirim Sistemi
- [ ] GitHub Actions scheduled workflow — 3 saatte bir
  - `0 */3 * * *` cron
  - Supabase'den `hayvan_durum_view` okur
  - `tohumlama_bildirisi_gerekli=true` → `bildirim_log`'a yazar
  - `suttten_kesme_bildirisi_gerekli=true` → `bildirim_log`'a yazar
  - `dogum_yaklasti=true` → `bildirim_log`'a yazar
  - Aynı hayvan için mükerrer bildirim yazmaz (kontrol eder)
- [ ] Frontend bildirim ekranı — `bildirim_log`'u listele
  - Tohumlama onayı: "Onayla" / "Ertele (1/2/3 ay)" butonları
  - Sütten kesme: bilgilendirme, "Tamam" ile kapat
  - Doğum yaklaşıyor: bilgilendirme
- [ ] Mevcut `bildirimKontrol()` → sadece görev bildirimleri için kalsın
  - Yaşam döngüsü bildirimleri artık `bildirim_log`'dan okunacak

### ❌ FAZ 5 — Raporlama
- [ ] Yeni "Raporlar" sayfası veya Dashboard genişletmesi
- [ ] `gebelik_ozet_view` → gebelik oranı grafiği
- [ ] `hastalik_istatistik_view` → hastalık tablo/grafik
- [ ] `stok_tuketim_view` → stok durumu (bu kısmen var)

### ❌ FAZ 6 — Startup Sync Ekranı
- [ ] App açılışında IndexedDB vs Supabase karşılaştır
- [ ] Bekleyen queue varsa ön ekran göster:
  - "X işlem bekliyor" → [Backend'e Gönder] [Yerel Veriyle Devam] [Sıfırdan Çek]
- [ ] Çakışma tespiti: timestamp + yetki seviyesi bazlı

---

## 6. BİLİNEN SORUNLAR / DIKKAT EDİLECEKLER

### Kritik
1. **`_gebeGunMap` / `_bosGunMap`** hâlâ frontend'de hesaplanıyor — view'dan gelen `toh_gun` kullanılmalı
2. **`submitCikis`** cascade işlemi backend stored procedure olmalı, şu an JS'de yapılıyor
3. **`islem_log`** hiçbir işlemde yazılmıyor — Faz 3'e kadar geri alma yok

### Orta
4. **`bildirimKontrol()`** `localStorage` kullanıyor — mimari karara aykırı, Faz 4'te `bildirim_log` ile değiştirilecek
5. **`loadGecmis()`** mevcut işlem geçmişi `islem_log`'dan değil, doğrudan tablolardan okuyor — Faz 3'te değişecek
6. **Çoklu kullanıcı** için `kullanici_id` kolonları ve RLS hazır değil — ileride migration gerekecek

### Küçük
7. `APP_VERSION = '2025-03-05-c'` — yanlış yıl yazılmış, deploy'da güncellenmeli
8. `suruSirala()` yaşa göre sıralarken "küçükten büyüğe" yorumu: `bg-ag` = en yeni doğum önce = en genç önce — doğru mu kontrol et

---

## 7. ÇOK KULLANICIYA GEÇİŞ (Gelecek)

Şu an tek kullanıcı. Çoklu kullanıcıya geçmek için eklenecekler:
```sql
-- Her tabloya eklenecek:
kullanici_id text REFERENCES public.kullanicilar(id)

-- Yeni tablo:
CREATE TABLE kullanicilar (
  id text PRIMARY KEY,
  ad text,
  rol text,  -- mudur | veteriner | yemci | izleyici
  yetki_seviyesi integer  -- 4 | 3 | 2 | 1
);
```
Çakışma kuralı: Yetki seviyesi yüksek kazanır. Eşit yetkide timestamp kazanır.

---

## 8. OTURUM SONUNDA YAPILACAKLAR

Her oturum sonunda bu dosyayı güncelle:
1. Faz durumunu güncelle (tamamlananları işaretle)
2. Yeni bilinen sorunları ekle
3. Bir sonraki oturumun başlangıç noktasını yaz
4. outputs/ klasörüne koy, kullanıcı GitHub'a push eder

---

## 9. BİR SONRAKİ OTURUM BAŞLANGIÇ NOKTASI

**Devam edilecek:** Faz 2 Paket B

**Adım 1 — Sütten kesme:**
1. `hayvan_durum_view`'dan `hesap_kategori='sut_icen'` olan hayvanları filtrele
2. Üreme sekmesinde "Süt İçen Buzağılar" tab'ına "🍼 Sütten Kes" butonu ekle
3. Butona basınca liste checkbox moduna geçer
4. Toplu seçim → onay → `suttten_kesme_tarihi = bugun` yazılır
5. Hayvan kartının Özet sekmesinde: sadece `sut_icen` kategorisindeyse buton görünsün
6. `write('hayvanlar', {suttten_kesme_tarihi: bugun}, 'PATCH', 'id=eq.X')`

**Adım 2 — Tohumlanabilir onay:**
1. `loadAnimals()` sırasında `tohumlama_bildirisi_gerekli=true` olanları tespit et
2. Hayvan kartı chip'lerine badge: `💉 Onay Bekliyor` (mavi, `tohumlama_durumu` null ise)
3. Hayvan kartında buton: "✅ Tohumlanabilir Onayla" / "⏰ Ertele"
4. Onay: `write('hayvanlar', {tohumlama_durumu:'tohumlanabilir', tohumlama_onay_tarihi: bugun}, 'PATCH', ...)`
5. Ertele modalı: 1 / 2 / 3 ay seçimi → `tohumlama_durumu='ertelendi'`
6. Tohumlama yapılınca badge düşer (zaten `toh_sonuc` değişince view günceller)
