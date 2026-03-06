# EgeSüt ERP — Proje Spec Dosyası
> **Bu dosya her oturumun başında okunur. Her oturumun sonunda güncellenir.**
> Son güncelleme: 2026-03-06 — Faz 2B + 2C tamamlandı

---

## 0. HIZLI DURUM ÖZETİ

| Faz | İçerik | Durum |
|---|---|---|
| Faz 1 | Veri modeli, migration'lar, view'lar | ✅ Tamamlandı |
| Faz 2A | View entegrasyonu, duplikasyon, sürüden çıkış | ✅ Tamamlandı |
| Faz 2B | Sütten kesme, tohumlanabilir onay | ✅ Tamamlandı |
| Faz 2C | Frontend hesap temizliği | ✅ Tamamlandı |
| Faz 3 | İşlem geçmişi, geri alma, çöp kutusu | ❌ Başlanmadı |
| Faz 4 | Bildirim sistemi (GitHub Actions) | ❌ Başlanmadı |
| Faz 5 | Raporlama | ❌ Başlanmadı |
| Faz 6 | Startup sync ekranı | ❌ Başlanmadı |

**Bir sonraki oturum:** Faz 3 — İşlem geçmişi + geri alma

---

## 1. TEKNİK ALTYAPI

### Dosyalar
| Dosya | Konum | Açıklama |
|---|---|---|
| `index.html` | repo root | Tek dosya uygulama, ~4055 satır, vanilla JS |
| `sw.js` | repo root | Service Worker v13 |
| `manifest.json` | repo root | PWA manifest |
| `supabase/migrations/` | repo | 6 migration dosyası |
| `SPEC.md` | repo root | Bu dosya |

### Deployment
- GitHub Pages — Push → Actions otomatik deploy
- SW: `index.html` → network-only, statik → cache-first
- `APP_VERSION = '2026-03-06-a'` ✅ düzeltildi

### Supabase
- **URL:** `https://zqnexqbdfvbhlxzelzju.supabase.co`
- **DB / IndexedDB adı:** `egesut_v9`, **version:** `DB_VER = 4`
- **RLS:** Kapalı

### IndexedDB TABLES array
```javascript
['hayvanlar','tohumlama','hastalik_log','dogum','stok',
 'stok_hareket','gorev_log','buzagi_takip','kizginlik_log','bildirim_log']
```
⚠️ `islem_log` ve `cop_kutusu` Supabase'de var ama TABLES'a eklenmemiş → Faz 3'te eklenecek.

---

## 2. MİMARİ — "BANKA MODELİ"

```
Backend (Supabase) = BANKA       → Tek otorite
Frontend           = VEZNECİ     → Toplar, gönderir, gösterir. HESAPLAMAZ.
IndexedDB          = ŞUBE KASASI → Sadece offline tampon
```

### Mimariyle Çelişen Kod (kalan)
| Sorun | Yer | Çözüm | Faz |
|---|---|---|---|
| `submitCikis` cascade JS'de | `submitCikis()` | `cikis_yap()` stored proc | 3 |
| `bildirimKontrol()` localStorage | app init | `bildirim_log`'a taşı | 4 |
| `loadGecmis()` direkt tablolardan | `loadGecmis()` | `islem_log`'dan oku | 3 |

### ✅ Çözülen Sorunlar (bu oturumda)
- `_gebeGunMap` / `_bosGunMap` frontend hesabı → view'dan `toh_gun` / `bos_gun` kullanılıyor
- `_gebeIds` → `a.toh_sonuc==='Gebe'` ile inline
- `updatePadokOzet` temizlendi
- `submitCikis` offline kontrolü eklendi
- Tüm duplikat `let` bildirimleri temizlendi
- `APP_VERSION` düzeltildi

### Offline Kuralları
**İzin:** Görüntüleme, doğum/hastalık/tohumlama/kızgınlık kaydı
**Yasak:** Geri alma, ölüm/satış, sütten kesme, tohumlanabilir onay, bildirim yönetimi

---

## 3. VERİTABANI ŞEMASI

### Migration Dosyaları
| Dosya | İçerik | Durum |
|---|---|---|
| `20260303000001_initial_schema.sql` | Temel tablolar | ✅ |
| `20260303000002_add_columns.sql` | Ek kolonlar | ✅ |
| `20260303000003_fixes.sql` | Düzeltmeler | ✅ |
| `20260303000004_foreign_keys.sql` | FK kısıtları | ✅ |
| `20260303000005_triggers.sql` | `set_deneme_no` trigger | ✅ |
| `20260306000006_faz1_core.sql` | Faz 1 tam şema | ✅ |
| `20260306000007_faz3.sql` | `updated_at` + islem_log/cop_kutusu | ❌ Yazılmadı |

### Tablolar (özet)
```
hayvanlar: + kategori, suttten_kesme_tarihi, tohumlama_onay_tarihi,
             tohumlama_durumu (NULL|tohumlanabilir|tohumlandi|gebe|ertelendi)
             cikis_tipi, cikis_tarihi, cikis_sebebi, satis_fiyati
             ⚠️ updated_at henüz yok — migration 007'de eklenecek

tohumlama, hastalik_log, dogum, gorev_log, kizginlik_log
stok, stok_hareket, buzagi_takip
irk_esik: Holstein(365g,60g) Montofon(420g,60g) Simmental(400g,60g) Jersey(365g,56g)
bildirim_log: bekliyor|goruldu|ertelendi|tamamlandi|iptal — GitHub Actions yazar
islem_log: snapshot jsonb — Faz 3
cop_kutusu: 30 gün — Faz 3
```

### Views
```
hayvan_durum_view — SADECE durum=Aktif, tüm badge ve hesaplar burada
  Alanlar: yas_gun, toh_gun, toh_sonuc, hesap_kategori
           tohumlama_bildirisi_gerekli, suttten_kesme_bildirisi_gerekli
           dogum_yaklasti, dogum_gecikme_gun, aktif_hastalik_sayisi
  ⚠️ bos_gun henüz yok — migration 007'de eklenecek (şu an fallback: yas_gun)

gebelik_ozet_view, hastalik_istatistik_view, stok_tuketim_view
```

### Stored Procedures
```
kupe_musait_mi(p_kupe_no, p_devlet_kupe, p_hayvan_id?) → duplikasyon kontrolü

Faz 3'te eklenecek:
cikis_yap(hayvan_id, tip, tarih, sebep, fiyat?) → tek transaction cascade
geri_al(islem_log_id) → snapshot'tan geri dön
```

---

## 4. FRONTEND MİMARİSİ

### Global State (temizlenmiş hali)
```javascript
_A            = []       // hayvan_durum_view'dan — badge'ler hazır gelir
_S            = []       // Stok
_curStk       = null
_curPg        = 'dash'
_suruFilter   = 'tumuu'     // tumuu|gebe|bos
_suruSiralama = 'kupe'      // kupe|yas
_curUremeTab  = 'kizginlik'
_curGecmisFilter = 'hepsi'
_curTaskFilter   = 'today'

// ✅ KALDIRILDI (Faz 2C):
// _gebeIds, _gebeGunMap, _bosGunMap — artık view'dan a.toh_sonuc/toh_gun/bos_gun
```

### Sayfalar
```
pg-dash      → loadDash()
pg-suru      → loadAnimals() + renderAnimals() + updatePadokOzet()
pg-tasks     → loadTasks()
pg-ureme     → loadUreme() [kizginlik|tohumlama|gebelik|dogum|abort|suttenkes]
pg-gecmis    → loadGecmis()        ⚠️ Faz 3'te islem_log'a taşınacak
pg-cikanlar  → loadCikanlar()
pg-log       → loadBirths() + loadStokList()
```

### Modal'lar
```
m-animal, m-cikis, m-disease, m-insem, m-birth, m-stk, m-task-add
m-tohum-ertele  ✅ YENİ — tohumlama erteleme (1/2/3 ay)
m-sutten-kes    ✅ YENİ — toplu sütten kesme checkbox listesi
```

### Yeni Fonksiyonlar (Faz 2B)
```javascript
suttenKesTekil(hayvanId, btn)      // Hayvan kartından tekil sütten kesme
submitSuttenKes(hayvanIdList, btn) // Toplu sütten kesme — online zorunlu
submitTohumOnayla(hayvanId, btn)   // Tohumlama onayı — online zorunlu
submitTohumErtele(hayvanId, ay, btn) // Tohumlama erteleme
openTohumErtele(hayvanId, kupe)    // Ertele modal aç
openSuttenKesModal()               // Toplu modal aç
skHepsiniSec(durum)                // Modal checkbox seç/temizle
skOnayla(btn)                      // Modal onay tetikleyici
```

---

## 5. FAZ PLANI

### ✅ FAZ 1 — Veri Modeli
### ✅ FAZ 2A — Temel Entegrasyon
### ✅ FAZ 2B — Sütten Kesme + Tohumlanabilir Onay
- [x] `suttenKesTekil()` — hayvan kartı özet sekmesinde koşullu buton
- [x] `submitSuttenKes()` — online kontrolü var, sadece `sut_icen` hayvanlar
- [x] Üreme sekmesine `🍼 Sütten Kes` tab'ı eklendi
- [x] Toplu seçim modal: `m-sutten-kes`, checkbox listesi
- [x] `submitTohumOnayla()` + `submitTohumErtele()` — online zorunlu
- [x] Hayvan kartı Özet sekmesinde: `💉 Onay Bekliyor` / `💉 Tohumlanabilir` badge + butonlar
- [x] `m-tohum-ertele` modal — 1/2/3 ay seçimi
- [x] `submitCikis()` online kontrolü eklendi

### ✅ FAZ 2C — Frontend Hesap Temizliği
- [x] `_gebeIds`, `_gebeGunMap`, `_bosGunMap` kaldırıldı
- [x] `loadAnimals()` sadeleştirildi — sadece `getData` + `suruSirala` + `renderAnimals`
- [x] `renderAnimals()` → `a.toh_sonuc`, `a.toh_gun`, `a.bos_gun` kullanıyor
- [x] `updatePadokOzet()` → `a.toh_sonuc==='Gebe'` kullanıyor
- [x] `srchDropdown()` temizlendi
- [x] Tüm duplikat `let` bildirimleri temizlendi

### ❌ FAZ 3 — İşlem Geçmişi + Geri Alma

**Migration 007 yazılacak:**
```sql
-- Her tabloya updated_at ekle + otomatik trigger
-- hayvan_durum_view'a bos_gun ekle
-- cikis_yap() stored procedure
-- geri_al() stored procedure
```

**Frontend:**
- `islem_log` + `cop_kutusu` TABLES'a ekle (DB_VER = 5)
- Her `submit*` sonrası snapshot yaz: submitBirth, submitInsem, submitCikis, submitDisease, suttenKesTekil
- `loadGecmis()` → `islem_log`'dan oku (şu an tablolardan okuyor)
- Geçmiş ekranında `🔄 Geri Al` butonu
- Geri alma onay modalı

### ❌ FAZ 4 — Bildirim Sistemi
- GitHub Actions `0 */3 * * *` — bildirim_log yazar
- Frontend bildirim ekranı — bildirim_log okur
- `bildirimKontrol()` localStorage → bildirim_log'a taşı

### ❌ FAZ 5 — Raporlama
- gebelik_ozet_view, hastalik_istatistik_view, stok_tuketim_view grafikleri

### ❌ FAZ 6 — Startup Sync Ekranı
- Queue'da bekleyen varsa ön ekran göster

---

## 6. BİLİNEN SORUNLAR

### 🔴 Kritik
| # | Sorun | Çözüm | Faz |
|---|---|---|---|
| 1 | `submitCikis` cascade JS'de | `cikis_yap()` stored proc | 3 |
| 2 | `islem_log` hiç yazılmıyor | Entegrasyon | 3 |
| 3 | `updated_at` kolonu yok | Migration 007 | 3 |
| 4 | `bos_gun` view'da yok | Migration 007 | 3 |

### 🟡 Orta
| # | Sorun | Çözüm | Faz |
|---|---|---|---|
| 5 | `bildirimKontrol()` localStorage | `bildirim_log`'a taşı | 4 |
| 6 | `loadGecmis()` direkt tablolardan | `islem_log`'dan oku | 3 |

### 🟢 Küçük
| # | Sorun | Çözüm | Faz |
|---|---|---|---|
| 7 | RLS kapalı | Çoklu kullanıcıya geçince | Gelecek |

---

## 7. ÇOKLU KULLANICI GEÇİŞİ (Gelecek)

```sql
CREATE TABLE kullanicilar (id, ad, rol, yetki_seviyesi);
-- Her tabloya: kullanici_id + updated_at
-- RLS + politikalar
```

---

## 8. OTURUM PROTOKOLÜ

Başta: Bölüm 0 özeti → Bölüm 9 başlangıç noktası
Sonda: Faz durumu güncelle → sorunları ekle → Bölüm 9 yaz → outputs'a kaydet → push

---

## 9. BİR SONRAKİ OTURUM BAŞLANGIÇ NOKTASI

**Hedef:** Faz 3 — İşlem Geçmişi + Geri Alma

**Adım 1 — Migration 007 yaz:**
Dosya: `supabase/migrations/20260306000007_faz3.sql`
```sql
-- 1. updated_at tüm tablolara
ALTER TABLE hayvanlar ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();
-- (tohumlama, hastalik_log, dogum, gorev_log için de aynısı)

-- 2. updated_at otomatik trigger
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$ BEGIN NEW.updated_at = now(); RETURN NEW; END; $$ LANGUAGE plpgsql;
-- CREATE TRIGGER ... BEFORE UPDATE ON hayvanlar ...

-- 3. hayvan_durum_view güncelle: bos_gun ekle
-- bos_gun: son boş toh veya son doğumdan bu yana gün

-- 4. cikis_yap() stored procedure
-- 5. geri_al() stored procedure
```

**Adım 2 — IndexedDB versiyonu artır:**
```javascript
DB_VER = 5  // islem_log ve cop_kutusu store'ları eklenecek
TABLES = [...mevcut..., 'islem_log', 'cop_kutusu']
```

**Adım 3 — islem_log yazma:**
Her submit* fonksiyonundan sonra snapshot yaz:
```javascript
// submitBirth, submitInsem, submitCikis, submitDisease, suttenKesTekil
const snapshot = {
  olusturulan: [{tablo:'dogum', id:..., veri:{...}}],
  guncellenen: [{tablo:'hayvanlar', id:..., onceki:{...}, sonraki:{...}}],
  silinen: []
};
await write('islem_log', {tip:'DOGUM_KAYDI', ana_hayvan_id:..., snapshot}, 'POST');
```

**Adım 4 — loadGecmis() yeniden yaz:**
`islem_log`'dan oku, snapshot içindeki detayları göster

**Adım 5 — Geri Al UI:**
- Geçmiş sekmesinde her satıra `🔄 Geri Al` butonu
- Onay modalı: "Şu kayıtlar etkilenecek: ..."
- `geri_al(islem_log_id)` RPC çağrısı
