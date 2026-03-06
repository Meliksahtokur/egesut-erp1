# EgeSüt ERP — Proje Spec Dosyası
> **Bu dosya her oturumun başında okunur. Her oturumun sonunda güncellenir.**
> Son güncelleme: 2026-03-06 — Faz 3 tamamlandı

---

## 0. HIZLI DURUM ÖZETİ

| Faz | İçerik | Durum |
|---|---|---|
| Faz 1 | Veri modeli, migration'lar, view'lar | ✅ Tamamlandı |
| Faz 2A | View entegrasyonu, duplikasyon, sürüden çıkış | ✅ Tamamlandı |
| Faz 2B | Sütten kesme, tohumlanabilir onay | ✅ Tamamlandı |
| Faz 2C | Frontend hesap temizliği | ✅ Tamamlandı |
| Faz 3 | İşlem geçmişi, geri alma | ✅ Tamamlandı |
| Faz 4 | Bildirim sistemi (GitHub Actions) | ❌ Başlanmadı |
| Faz 5 | Raporlama | ❌ Başlanmadı |
| Faz 6 | Startup sync ekranı | ❌ Başlanmadı |

**Bir sonraki oturum:** Faz 4 — GitHub Actions bildirim sistemi

---

## 1. TEKNİK ALTYAPI

### Dosyalar
| Dosya | Konum | Açıklama |
|---|---|---|
| `index.html` | repo root | Tek dosya uygulama, ~4187 satır |
| `sw.js` | repo root | Service Worker v13 |
| `manifest.json` | repo root | PWA manifest |
| `supabase/migrations/` | repo | 7 migration dosyası |
| `SPEC.md` | repo root | Bu dosya |

### Deployment
- GitHub Pages — Push → Actions otomatik deploy
- SW: `index.html` → network-only, statik → cache-first
- `APP_VERSION = '2026-03-06-a'`

### Supabase
- **URL:** `https://zqnexqbdfvbhlxzelzju.supabase.co`
- **DB / IndexedDB adı:** `egesut_v9`
- **IndexedDB version:** `DB_VER = 5`
- **RLS:** Kapalı

### IndexedDB TABLES array
```javascript
['hayvanlar','tohumlama','hastalik_log','dogum','stok','stok_hareket',
 'gorev_log','buzagi_takip','kizginlik_log','bildirim_log','islem_log','cop_kutusu']
```

---

## 2. MİMARİ — "BANKA MODELİ"

### Mimariyle Çelişen Kod (kalan)
| Sorun | Çözüm | Faz |
|---|---|---|
| `bildirimKontrol()` localStorage | `bildirim_log`'a taşı | 4 |

### ✅ Tüm Çözülen Sorunlar
- `_gebeGunMap/_bosGunMap` → view'dan `toh_gun/bos_gun`
- `submitCikis` cascade → `cikis_yap()` stored procedure
- `islem_log` entegrasyonu → tüm submit* fonksiyonlarında yazılıyor
- `loadGecmis` → `islem_log`'dan okuyor (fallback: eski tablolar)
- `updated_at` kolonları → migration 007
- `bos_gun` view'da → migration 007

### Offline Kuralları
**İzin:** Görüntüleme, doğum/hastalık/tohumlama/kızgınlık kaydı
**Yasak:** Geri alma, ölüm/satış, sütten kesme, tohumlanabilir onay, bildirim yönetimi

---

## 3. VERİTABANI ŞEMASI

### Migration Dosyaları
| Dosya | İçerik | Durum |
|---|---|---|
| `20260303000001` — `20260303000005` | Temel şema, FK, trigger | ✅ |
| `20260306000006_faz1_core.sql` | View'lar, stored proc, yeni tablolar | ✅ |
| `20260306000007_faz3.sql` | `updated_at`, `bos_gun`, `cikis_yap()`, `geri_al()` | ✅ Push edilmeli |

### Tablolar — Önemli Güncellemeler
```
hayvanlar: + updated_at timestamptz  ← migration 007
tohumlama, hastalik_log, dogum, gorev_log: + updated_at  ← migration 007
hayvan_durum_view: + bos_gun  ← migration 007
```

### Stored Procedures
```
kupe_musait_mi()  → duplikasyon kontrolü
cikis_yap()       → ✅ FAZ 3: hayvan pasif + görev kapat + bildirim iptal + islem_log
geri_al()         → ✅ FAZ 3: snapshot'tan cascade geri dön
```

---

## 4. FRONTEND MİMARİSİ

### Global State
```javascript
_A, _S, _curStk, _curPg
_suruFilter, _suruSiralama
_curUremeTab, _curGecmisFilter, _curTaskFilter
// Temizlendi: _gebeIds, _gebeGunMap, _bosGunMap (hepsi kaldırıldı)
```

### Sayfalar
```
pg-gecmis → loadGecmis() — islem_log'dan okur, fallback: eski tablolar
            Filtreler: Hepsi | Doğum | Tohumlama | Hastalık | Görev | Çıkış
```

### Modal'lar
```
m-geri-al  ✅ YENİ — işlem geri alma onay modalı (ga-hid, ga-ozet)
```

### Yeni Fonksiyonlar (Faz 3)
```javascript
yazIslemLog(tip, anaHayvanId, snapshot)  // tüm submit* sonrası çağrılır
geriAl(islemLogId, btn)                  // geri_al() RPC çağrısı
openGeriAl(islemLogId, ozet)             // modal açar
_gecmisFallback(f)                       // islem_log boşken eski tablolardan göster
```

### islem_log Tipleri
```
DOGUM_KAYDI    ← submitBirth
TOHUMLAMA      ← submitInsem
HASTALIK_KAYDI ← submitDisease
SUTTEN_KESME   ← suttenKesTekil
OLUM_KAYDI     ← cikis_yap() stored proc (submitCikis)
SATIS_KAYDI    ← cikis_yap() stored proc (submitCikis)
```

---

## 5. FAZ PLANI

### ✅ FAZ 3 — İşlem Geçmişi + Geri Alma
- [x] `DB_VER = 5`, `islem_log` + `cop_kutusu` TABLES'a eklendi
- [x] `pullFromSupabase()` → `islem_log` çekiyor (son 100 kayıt)
- [x] `yazIslemLog()` yardımcı fonksiyonu
- [x] `submitBirth`, `submitInsem`, `submitDisease`, `suttenKesTekil` → `yazIslemLog` çağırıyor
- [x] `submitCikis` → `cikis_yap()` RPC (stored procedure, atomic)
- [x] `geriAl()`, `openGeriAl()` fonksiyonları
- [x] `m-geri-al` modal
- [x] `loadGecmis()` → `islem_log`'dan okur, fallback var
- [x] Geçmiş sekmesine `📤 Çıkış` filtresi eklendi
- [x] Her satırda `🔄 Geri Al` butonu (sadece `durum='aktif'` olanlar)
- [x] Migration 007: `updated_at`, `bos_gun`, `cikis_yap()`, `geri_al()`

### ❌ FAZ 4 — Bildirim Sistemi

**GitHub Actions Workflow:**
Dosya: `.github/workflows/bildirim_check.yml`
```yaml
name: Bildirim Kontrolü
on:
  schedule:
    - cron: '0 */3 * * *'   # Her 3 saatte bir
  workflow_dispatch:          # Manuel tetikleme
jobs:
  kontrol:
    runs-on: ubuntu-latest
    steps:
      - name: Bildirimleri Oluştur
        env:
          SB_URL: ${{ secrets.SUPABASE_URL }}
          SB_KEY: ${{ secrets.SUPABASE_SERVICE_KEY }}
        run: |
          # hayvan_durum_view'dan flag'leri çek
          # bildirim_log'da mükerrer var mı kontrol et
          # Yoksa INSERT
```

**Frontend:**
- `bildirim_log` listesi sayfası/modal'ı
- Tohumlama bildirimi → Onayla / Ertele
- Sütten kesme → bilgilendirme
- `bildirimKontrol()` → `setInterval` 1h→3h, localStorage kaldır

### ❌ FAZ 5 — Raporlama
- gebelik_ozet_view, hastalik_istatistik_view, stok_tuketim_view grafikleri
- Dashboard genişletmesi veya yeni "Raporlar" sayfası

### ❌ FAZ 6 — Startup Sync Ekranı
- Queue'da bekleyen varsa ön ekran göster
- updated_at karşılaştırmayla çakışma tespiti

---

## 6. BİLİNEN SORUNLAR

### 🟡 Orta
| # | Sorun | Çözüm | Faz |
|---|---|---|---|
| 1 | `bildirimKontrol()` localStorage | `bildirim_log`'a taşı | 4 |
| 2 | `cop_kutusu` hiç yazılmıyor | Faz 3'te unuttuk — silme işlemlerinde yazılmalı | 3.5 |
| 3 | `geri_al()` view'lardan okuma yapamaz (dynamic SQL kısıtı) | Test edilmeli, gerekirse düzelt | Test |

### 🟢 Küçük
| # | Sorun | Çözüm | Faz |
|---|---|---|---|
| 4 | `islem_log` fallback mesajı her zaman görünüyor | İlk kayıt sonrası kaybolur, sorun değil | — |
| 5 | RLS kapalı | Çoklu kullanıcıya geçince | Gelecek |

---

## 7. OTURUM PROTOKOLÜ

Başta: Bölüm 0 özeti → Bölüm 9 başlangıç noktası
Sonda: Faz durumu güncelle → sorunları ekle → Bölüm 9 yaz → outputs'a kaydet → push

---

## 8. BİR SONRAKİ OTURUM BAŞLANGIÇ NOKTASI

**Hedef:** Faz 4 — Bildirim Sistemi

**Adım 0 — Migration 007'yi push et (henüz yapılmadıysa):**
```
supabase/migrations/20260306000007_faz3.sql
```
Supabase'e GitHub Actions ile uygulanacak.

**Adım 1 — GitHub Actions workflow dosyası yaz:**
Dosya: `.github/workflows/bildirim_check.yml`
- `secrets.SUPABASE_URL` ve `secrets.SUPABASE_SERVICE_KEY` ayarlanmış olmalı
- Supabase REST API ile `hayvan_durum_view` çek
- Mükerrer kontrol: `bildirim_log`'da aynı `hayvan_id` + `tip` + `durum=bekliyor` varsa INSERT yapma
- Tipleri: `tohumlama_yasi`, `suttten_kesme`, `dogum_yaklasti`, `dogum_gecikti`

**Adım 2 — Frontend bildirim ekranı:**
- Mevcut nav'da bildirim ikonu veya yeni sayfa
- `bildirim_log` listesi: `durum=bekliyor` olanlar
- Tohumlama → `✅ Onayla` (submitTohumOnayla çağrısı) + `⏰ Ertele`
- Sütten kesme → `🍼 Sütten Kes` butonu
- Okuma onayı: `durum='goruldu'` PATCH

**Adım 3 — bildirimKontrol() temizle:**
- Görev bildirimleri kısmı kalır
- Yaşam döngüsü bildirimleri kaldırılır (artık `bildirim_log`'dan okunacak)
- `setInterval` 1h → 3h

**⚠️ Adım 0.5 — cop_kutusu eklemesi (küçük, Faz 3 artığı):**
- `submitCikis` (cikis_yap stored proc) zaten islem_log yazıyor — cop_kutusu ayrıca yazılmaya gerek yok
- Hayvan fiziksel silinmediği için (durum=Pasif) cop_kutusu'na gerek kalmadı — bu özelliği Faz 5+'a ertele
