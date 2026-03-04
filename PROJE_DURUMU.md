---
# EgeSüt ERP v9 — Proje Durumu & Bağlam

## Proje Nedir
Offline-first süt çiftliği yönetim uygulaması.
Tek HTML dosyası (index.html) + Supabase backend.
GitHub Pages üzerinde yayınlanıyor.
Firebase KULLANILMIYOR — sadece Supabase.

## Teknik Stack
- Frontend: Vanilla JS, single HTML file (index.html)
- Backend: Supabase (PostgreSQL + REST API)
- Offline: IndexedDB + sync queue
- Deploy: GitHub Pages (otomatik, her push\'ta)
- DB Migration: GitHub Actions → Supabase CLI

## Supabase Bilgileri
- Project ID: zqnexqbdfvbhlxzelzju
- URL: https://zqnexqbdfvbhlxzelzju.supabase.co
- API Key: index.html içinde SB_KEY değişkeninde

## GitHub Actions
Her push\'ta otomatik çalışır:
- supabase/ klasörü değişince → Supabase migrate
- Her push\'ta → GitHub Pages deploy

## Tablolar
- hayvanlar: Sürüdeki hayvanlar
- stok: İlaç ve malzeme stoku
- stok_hareket: Stok giriş/çıkış hareketleri
- gorev_log: Görevler (protokol + manuel)
- hastalik_log: Hastalık kayıtları
- tohumlama: Tohumlama kayıtları
- dogum: Doğum kayıtları
- buzagi_takip: Buzağı takip

## Migration Durumu
- 001_initial_schema.sql ✅ çalıştı
- 002_add_columns.sql ✅ çalıştı
- 003_fixes.sql ✅ çalıştı
- 004_foreign_keys.sql ✅ çalıştı
- 005_triggers.sql ✅ çalıştı

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
submitBirth\'te tohumlama sonucunu Doğurdu yap,
anne seçilince sperma bilgisini baba alanına doldur,
loadBirths\'te sperma bilgisini göster.
Sadece: submitBirth, loadBirths, anneSeç fonksiyonları

### Prompt 3 — Hayvan Detayı Anne/Yavru İlişkisi
openDet\'te anne kartı ve yavru listesi göster,
info-grid\'e anne_id, cinsiyet, canli_agirlik ekle.
Sadece: openDet fonksiyonu, tab-ozet HTML

### Prompt 4 — Raporlama
Alt navda yeni RAPOR sekmesi,
gebe oranı / doğum / hastalık / ilaç tüketimi kartları.

### Prompt 5 — Input Validation
Formlarda Türkçe hata mesajları,
dogum_kg 20-80 arası, tarih gelecekte olamaz vb.

### Prompt 6 — Push Notifications
Görev gecikince / stok kritikse / doğum yaklaşınca
browser notification, 30 dakikada bir kontrol.

## Önemli Kararlar (Neden Böyle)
- id tipi TEXT (UUID) — frontend crypto.randomUUID() kullanıyor
- Null field filtering — Supabase schema cache hatalarını önler
- Her migration ayrı dosya — rollback kolaylığı için
- gorev_log teker teker POST — Supabase batch farklı kolonları reddediyor
- hastalik_log FK kaldırıldı — buzağı ID\'leri UUID, FK kırıyordu

## Firebase Studio\'da Çalışırken
- Built-in Model kullan (API key gerektirmez)
- Agent modu açık olsun
- Autocommit açık olsun
- Her prompt tek dosya değişikliği
- Actions yeşil olmadan sonraki promptu verme
- index.html\'e dokunma talimatını her prompta ekle

## Herhangi Bir AI\'ya Verilecek Başlangıç Promptu
Read PROJE_DURUMU.md first.
This project uses Supabase (not Firebase).
Single HTML file with offline-first IndexedDB + Supabase sync.
Understand the context before making any changes. Sana verdiğim her guncellemeden sonra bu dosyayı da güncelle veya düzenini bozmadan bir not ekle.The following snippets may be helpful:
From index.html in local codebase:
```
Line 2483:    <script>
Line 2484:    // Service Worker — GitHub Pages\'de ayrı sw.js gerektirir, blob SW Firefox\'ta çalışmaz
Line 2485:    // SW devre dışı — IndexedDB offline storage yeterli
Line 2486:    </script>
Line 2487:    </body>
Line 2488:    </html>
```

From index.html in local codebase:
```
Line 674:     <script>
Line 675:     // ══════════════════════════════════════════
Line 676:     // CONFIG
Line 677:     // ══════════════════════════════════════════
Line 678:     const SB_URL = \'https://zqnexqbdfvbhlxzelzju.supabase.co\';
Line 679:     // ⚠️ ÖNEMLI: Supabase Dashboard > Settings > API > "anon public" JWT key\'ini buraya yaz
Line 680:     // sb_publishable_ formatı REST API\'de çalışmıyor — eyJ... ile başlayan key lazım
Line 681:     const SB_KEY = \'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpxbmV4cWJkZnZiaGx4emVsemp1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzMDE4OTksImV4cCI6MjA4Nzg3Nzg5OX0.VggKv3KsmXm7C1LqBxCJaMj2yLQh10iRwSXMtuC4cmc\';
Line 682:     const HDR = {\'apikey\':SB_KEY,\'Authorization\':\'Bearer \'+SB_KEY,\'Content-Type\':\'application/json\',\'Prefer\':\'return=representation\'};
Line 683:     const HDR_UPSERT = {\'apikey\':SB_KEY,\'Authorization\':\'Bearer \'+SB_KEY,\'Content-Type\':\'application/json\',\'Prefer\':\'resolution=merge-duplicates,return=representation\'};
Line 684:     const DB_NAME = \'egesut_v9\';
Line 685:     const DB_VER  = 1;
```

From index.html in local codebase:
```
Line 992:     // ══════════════════════════════════════════
Line 993:     // INIT
Line 994:     // ══════════════════════════════════════════
Line 995:     window.addEventListener(\'load\',async()=>{
Line 996:       // IndexedDB aç — hata olursa yine de devam et
Line 997:       try { await openDB(); } catch(e){
Line 998:         console.error(\'DB hatası:\',e.message);
Line 999:         document.getElementById(\'dash-body\').innerHTML=\`<div class="empty" style="padding:20px">⚠️ Veritabanı hatası: ${e.message}<br><button class="btn btn-g" style="margin-top:12px" onclick="location.reload()">Yenile</button></div>\`;
Line 1000:      }
Line 1001:      // API key kontrolü
Line 1002:      if(!SB_KEY.startsWith(\'eyJ\')){
Line 1003:        setSyncBar(\'warn\',\'⚠️ Supabase API key hatalı! Dashboard > Settings > API > anon public key gerekli\');
Line 1004:        document.getElementById(\'sync-bar\').classList.add(\'on\');
Line 1005:      }
Line 1006:      const t=new Date().toISOString().split(\'T\')[0];
Line 1007:      [\'b-tarih\',\'i-tarih\',\'ta-tarih\'].forEach(id=>{ const el=document.getElementById(id); if(el) el.value=t; });
Line 1008:      populateHekimSelects();
```

The user is currently editing this part of a file named `supabase/migrations/20260303_005_triggers.sql`:
```
Line 13:      CREATE TRIGGER trg_deneme_no
Line 14:        BEFORE INSERT ON public.tohumlama
Line 15:        FOR EACH ROW EXECUTE FUNCTION public.set_deneme_no();
Line 16:      
Line 17:      NOTIFY pgrst, \'reload schema\';
```