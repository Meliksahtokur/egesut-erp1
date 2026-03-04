---
# EgeSüt ERP v9 — Proje Durumu & Bağlam

## Proje Nedir
Offline-first süt çiftliği yönetim uygulaması.
Tek HTML dosyası (index.html) + Supabase backend.
GitHub Pages üzerinde yayınlanıyor.
Firebase KULLANILMIYOR — sadece Supabase.

## Teknik Stack
- Frontend: Vanilla JS, tek HTML dosyası (index.html)
- Backend: Supabase (PostgreSQL + REST API)
- Geliştirme Ortamı: Node.js ve `package.json` ile yönetilen `supabase` CLI (veritabanı migration'ları için).
- Offline: IndexedDB + sync queue
- Deploy: GitHub Pages (otomatik, her push'ta)
- DB Migration: GitHub Actions → Supabase CLI

## Proje Dosya Ağacı (Tree)
Projenin ana dizin yapısı şu şekildedir:
- `index.html`: Uygulamanın tüm frontend kodunu içeren tek dosyadır.
- `package.json` / `package-lock.json`: `supabase` CLI gibi geliştirme bağımlılıklarını yönetir.
- `node_modules/`: `npm install` ile kurulan bağımlılıkların bulunduğu klasör.
- `supabase/`: Veritabanı migration dosyalarının bulunduğu klasör. Her SQL dosyası sıralı olarak çalıştırılır.
- `PROJE_DURUMU.md`: Bu dosya. Projenin mevcut durumunu, hedeflerini ve teknik detaylarını içerir.
- `README.md`: Standart proje tanıtım dosyası.

## Supabase Bilgileri
- Project ID: zqnexqbdfvbhlxzelzju
- URL: https://zqnexqbdfvbhlxzelzju.supabase.co
- API Key: index.html içinde SB_KEY değişkeninde

## GitHub Actions
Her push'ta otomatik çalışır:
- `supabase/` klasörü değişince → Supabase migrate
- Her push'ta → GitHub Pages deploy

## Tablolar
- `hayvanlar`: Sürüdeki hayvanlar
- `stok`: İlaç ve malzeme stoku
- `stok_hareket`: Stok giriş/çıkış hareketleri
- `gorev_log`: Görevler (protokol + manuel)
- `hastalik_log`: Hastalık kayıtları
- `tohumlama`: Tohumlama kayıtları
- `dogum`: Doğum kayıtları
- `buzagi_takip`: Buzağı takip

## Migration Durumu
- `001_initial_schema.sql` ✅ çalıştı
- `002_add_columns.sql` ✅ çalıştı
- `003_fixes.sql` ✅ çalıştı
- `004_foreign_keys.sql` ✅ çalıştı
- `005_triggers.sql` ✅ çalıştı

## Tamamlanan Özellikler
- Offline-first IndexedDB sync ✅
- Doğum kaydı → otomatik buzağı oluştur ✅
- Doğum kaydı → Gebelerden Seç (280 gün hesabı) ✅
- Tohumlama → otomatik 21/35 gün kontrol görevleri ✅
- Stok yönetimi + kritik eşik uyarısı ✅
- Data Traffic paneli (başarısız kayıt takibi) ✅
- Hayvan fiziksel özellikler (boy, kilo, renk) ✅
- GitHub Actions → Supabase otomatik migration ✅
- Null field filtering (schema cache hataları çözüldü) ✅

## Devam Eden / Yarım Kalan İşler
Şu sırayla yapılıyor, Actions yeşil oldukça devam et:

### Prompt 2 — Doğum ↔ Tohumlama Bağlantısı
`submitBirth`'te tohumlama sonucunu `Doğurdu` yap,
anne seçilince sperma bilgisini baba alanına doldur,
`loadBirths`'te sperma bilgisini göster.
Sadece: `submitBirth`, `loadBirths`, `anneSeç` fonksiyonları

### Prompt 3 — Hayvan Detayı Anne/Yavru İlişkisi
`openDet`'te anne kartı ve yavru listesi göster,
`info-grid`'e `anne_id`, `cinsiyet`, `canli_agirlik` ekle.
Sadece: `openDet` fonksiyonu, `tab-ozet` HTML

### Prompt 4 — Raporlama
Alt navda yeni RAPOR sekmesi,
gebe oranı / doğum / hastalık / ilaç tüketimi kartları.

### Prompt 5 — Input Validation
Formlarda Türkçe hata mesajları,
`dogum_kg` 20-80 arası, tarih gelecekte olamaz vb.

### Prompt 6 — Push Notifications
Görev gecikince / stok kritikse / doğum yaklaşınca
browser notification, 30 dakikada bir kontrol.

## Önemli Kararlar (Neden Böyle)
- `id` tipi `TEXT` (UUID) — frontend `crypto.randomUUID()` kullanıyor
- Null field filtering — Supabase schema cache hatalarını önler
- Her migration ayrı dosya — rollback kolaylığı için
- `gorev_log` teker teker POST — Supabase batch farklı kolonları reddediyor
- `hastalik_log` FK kaldırıldı — buzağı ID'leri UUID, FK kırıyordu

**Not:** Bu dosya, proje üzerindeki her önemli değişiklikten sonra güncellenmelidir. Lütfen commit yapmadan önce bu dosyanın güncel olduğundan emin olunuz.
