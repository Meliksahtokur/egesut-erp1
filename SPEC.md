# EgeSüt ERP — SPEC v5
> Her oturumun başında okunur. Hem harita hem rota. Sigortamız.
> Son güncelleme: 2026-03-10 — Pipeline kuruldu, S1-04/S2-03 kısmi, trigger fix

---

## 0. OTURUM BAŞI KONTROL LİSTESİ

1. Bu SPEC'i oku
2. Sprint tablosuna bak, sıradaki item'ı söyle
3. Onay al, başla
4. Değişiklik = diff patch formatında ver (tam dosya değil)
5. Oturum sonu SPEC'i güncelle

---

## 0b. GELİŞTİRME PİPELINE'I

**Araçlar:** Acode (editör) + Alpine terminal (git) + GitHub

**Her değişiklik için format:**
```
--- a/dosya
+++ b/dosya
@@ -N,M +N,M @@
 context satırı
-eski satır
+yeni satır
 context satırı
```

**Terminal komutu:**
```bash
cd /home/egesut-erp1
python3 apply.py
# patch yapıştır → CTRL+D
# VEYA
python3 apply.py /tmp/p.diff
```

**Kurallar:**
- Tam dosya rewrite YOK — sadece değişen satırlar + 2-3 context
- sed ile de uygulanabilir basit tek satır değişimlerde
- Migration değişiklikleri Supabase SQL Editor'dan çalıştırılır
- apply.py push eder, SSH key oturum başında yeniden kurulabilir

---

## 0. MEVCUT DURUM — GERÇEK

### Tamamlanan ✅
- Migration 008 push edildi (tüm stored proc'lar, triggerlar, RLS, view)
- Modüler yapı: index.html + js/api.js + js/app.js + js/ui.js + js/forms.js
- Supabase JS SDK v2 (CDN)
- ~~Service Worker cache v11~~ → **SW KALDIRILDI** (cache kilidi sorunu yaşatıyordu, offline-first ihtiyaç yok)
- pullTables / renderSafe / rpcOptimistic optimistic UI sistemi
- Hayvan kaydı (hayvan_ekle RPC)
- Irk dropdown (DB'den, kullanım sıklığına göre, "Diğer" text input)
- Tohumlama kaydı (ileri tarih engeli var)
- Görev tamamlama
- Sperma dropdown (spermaModStok / spermaModElle)
- islem_log trigger (hayvanlar/dogum/tohumlama/hastalik/kizginlik)
- SECURITY DEFINER tüm stored proc'lara eklendi
- **Migration 009 push edildi** (hekimler tablosu, tohumlama validasyon, islem_log payload jsonb, hayvan_timeline_view)
- **Migration 010 push edildi** (hayvan_guncelle RPC — küpe çakışma kontrolü, COALESCE pattern)
- **S1-01 ✅** Grup filtreleme düzeltildi — closeM() hayvan formunu tam sıfırlıyor
- **S1-02 ✅** Tohumlama validasyonu — erkek/12ay altı/aktif gebelik DB'de engelleniyor (migration 009)
- **S1-03 ✅** Hayvan kartından tedavi küpe otodolumu — dispatchEvent kaldırıldı, acMap ile kapatılıyor
- **S2-04 ✅** Hekimler DB'ye taşındı — migration 009, loadHekimler() ile fallback korumalı
- **Hayvan bilgi düzenleme ✅** — hayvan kartından ✏️ Bilgileri Düzenle butonu, tüm fiziksel alanlar (boy, ağırlık, renk vb.) güncelleniyor
- **Fiziksel alanlar hayvan kartında ✅** — info-grid'e cinsiyet, canlı ağırlık, boy, renk, ayırt edici eklendi
- **renderFromLocal fix ✅** — güncelleme sonrası await ile _A güncelleniyor, refresh gerekmeden UI yenileniyor
- **_pulling lock fix ✅** — ardışık pullTables çağrıları artık skip edilmiyor, queue'ya alınıyor
- **updateBildirimBadge / loadBildirimler stub ✅** — tanımsız hata giderildi

### Çalışmayan / Eksik 🔴
| # | Sorun | Dosya | Sprint |
|---|---|---|---|
| 4 | Geçmiş — hayvan kaydı görünmüyor, detay/geri alma çalışmıyor | ui.js | S1-04 |
| 5 | Sperma stoktan gelmiyor — window._appState bağlantısı eksik | app.js | S1-05 |
| 6 | Sürü filtrasyonu yok — dişi/erkek, gebe/boş, hasta/sağlıklı | ui.js | S2-01 |
| 7 | Hayvan detay ekranı yok — kilo/boy/notlar/timeline görünmüyor | ui.js | S2-02 |
| 8 | Hastalık formunda kategori→hastalık zinciri yok | ui.js/index.html | S2-03 |
| 10 | Abort tabı çalışmıyor — gebe listesi + abort kaydet akışı | ui.js/forms.js | S2-05 |
| 11 | Abort badge hayvan kartında yok | ui.js | S2-05 |
| 12 | Gebelik tabında "Tohumlama Ekle" butonu kaldırılmadı | ui.js | S2-06 |
| 13 | Doğum tabında tetiklenen görevler görünmüyor | ui.js | S2-06 |
| 14 | Görev renk mantığı eksik — geciken/bugün/yakın/gelecek | ui.js | S2-07 |

### Temizlik Bekleyen 🟡
| # | Görev |
|---|---|
| T-01 | yazIslemLog() fonksiyonu kaldır — trigger yapıyor artık |
| T-02 | _gecmisFallback() kaldır — islem_log her şeyi yazıyor |
| T-03 | Eski raw fetch/HDR/SB_URL kalıntılarını temizle |
| T-04 | APP_VERSION güncelle |
| T-05 | pullTables() setInterval kaldır — Realtime geçince gereksiz |

---

## 1. MİMARİ — MEVCUT

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
index.html      ~922 satır   — sadece HTML/CSS
js/api.js       ~324 satır   — Supabase client, pullTables, renderSafe, rpcOptimistic
js/app.js       ~535 satır   — init, routing, global state, form yardımcıları
js/ui.js        ~1540 satır  — tüm render fonksiyonları
js/forms.js     ~684 satır   — tüm submit fonksiyonları
sw.js                        — SW kaydını siler (cache temizleme), fetch handler YOK
supabase/migrations/         — 010 push edildi
```

---

## 2. MİMARİ VİZYON — HEDEF (Sprint 3+)

> Strangler fig pattern ile yavaş geçiş.

### Teşhis — Mevcut 3 Sorun
```
1. UI-Centric  → iş mantığı kısmen ui.js'de, bir şey değişince başkası kırılıyor
2. Data Dump   → frontend veriyi ayıklıyor/hesaplıyor (view kısmen çözüyor)
3. God Module  → ui.js 1540 satır, büyümeye devam ediyor
```

### Hedef Mimari
```
USER ACTION
    ↓
EVENT INSERT (events tablosu)
    ↓
POSTGRES TRIGGER
    ↓
PROJECTION UPDATE (state tabloları)
    ↓
SUPABASE REALTIME (websocket)
    ↓
FRONTEND STATE UPDATE (polling yok)
```

### Eksik — Sprint 3'te Eklenecek
```
events tablosu   → islem_log rename + payload standardize
eventBus.js      → 20 satır frontend event bus
modules/         → her yeni özellik domain modülü olarak
Realtime sub     → supabase.channel() → polling kalkacak
```

---

## 3. VERİTABANI

### Migration Durumu
| Migration | İçerik | Durum |
|---|---|---|
| 001-005 | Temel şema, FK, triggerlar | ✅ |
| 006 | hayvan_durum_view, irk_esik, bildirim_log, islem_log, kupe_musait_mi() | ✅ |
| 007 | updated_at, bos_gun, cikis_yap(), geri_al() | ✅ |
| 008 | hayvan_ekle, dogum_kaydet, tohumlama_kaydet, kizginlik_kaydet, hastalik_kaydet, abort_kaydet, hayvan_not_ekle, triggerlar, RLS, SECURITY DEFINER | ✅ |
| 009 | hekimler tablosu, tohumlama validasyon (erkek/yaş/gebelik), hayvan_timeline_view, islem_log payload jsonb | ✅ |
| 010 | hayvan_guncelle RPC (küpe çakışma + COALESCE pattern) | ✅ |
| 011 | hayvan_durum_view'a fiziksel alanlar (boy/ağırlık/renk) — şu an gerek yok, view pullTables'dan zaten geliyor | ⏸ Beklemede |
| 012 | _islem_log_yaz trigger fix — hastalik_log INSERT hatası düzeltildi | ✅ |
| 012 | Realtime subscription, projection tabloları, eventBus entegrasyonu | 🔮 Sprint 3 |

### Mevcut Stored Procedures
| Proc | Açıklama |
|---|---|
| hayvan_ekle() | Küpe kontrolü + hayvan INSERT + ırk sayacı |
| hayvan_guncelle() | Fiziksel + kimlik alanları güncelle, COALESCE ile sadece gönderilen değişir |
| dogum_kaydet() | Doğum + buzağı + 13 görev (anne 7 + buzağı 6) |
| tohumlama_kaydet() | Tohumlama + validasyon (erkek/yaş/gebelik) + 2 kontrol görevi + stok hareketi |
| kizginlik_kaydet() | Kızgınlık log |
| hastalik_kaydet() | Hastalık + ilaç stok hareketi + tedavi görevleri |
| abort_kaydet() | Abort + hayvan durumu güncelle |
| hayvan_not_ekle() | Nota append |
| cikis_yap() | Hayvan çıkış (satış/ölüm) |
| geri_al() | İşlem geri alma (cop_kutusu) |
| kupe_musait_mi() | Küpe kontrol |
| irk_listesi() | Dropdown için ırk listesi |
| hekim_listesi() | Hekimler dropdown |
| hekim_ekle() | Yeni hekim ekle (app + DB) |

---

## 4. YOL HARİTASI

### Sprint 1 — Kritik Buglar
```
[x] S1-01  Grup filtreleme — closeM() hayvan formunu tam sıfırlıyor
[x] S1-02  Tohumlama validasyonu — migration 009'da erkek/yaş/gebelik kontrolü
[x] S1-03  Hayvan kartından tedavi — dispatchEvent kaldırıldı, küpe düzgün doldu
[x] S1-04  Geçmiş — küpe çözümlendi, detay modal küpe gösteriyor, geri al butonu eklendi
[x] S1-05  Sperma stok bağlantısı — seçimde stok göster, stok=0 kaydet disabled
[ ] S1-06  Tohumlama dropdown filtresi — hayvan_durum_view'a tohumlanabilir boolean ekle (migration), frontend sadece filtreler
```

### Sprint 2 — Eksik Özellikler
```
[x] S2-04  Hekimler DB'ye taşındı — migration 009
[ ] S2-01  Sürü filtrasyonu — dişi/erkek, gebe/boş, hasta/sağlıklı, grup/padok
[ ] S2-02  Hayvan detay ekranı — kilo, boy, renk, notlar, event timeline
[x] S2-03  Hastalık formu — kategori→hastalık zinciri + çoklu semptom dropdown
[ ] S2-05  Abort akışı — gebe listesi, abort modal, badge
[ ] S2-06  Üreme tab düzeltme — gebelik butonu kaldır, doğum görevleri
[ ] S2-07  Görev renk mantığı — geciken/bugün/yakın/gelecek
[ ] S2-08  Toplu işlem paneli — toplu tohumlama, aşı, padok değişimi, satış
[ ] S2-09  Excel import/export — SheetJS, boş şablon indir → doldur → yükle
```

### Sprint 3 — Mimari Geçiş + Gelecek
```
[ ] S3-01  events tablosu — islem_log standardize, payload jsonb
[ ] S3-02  Supabase Realtime subscription — polling kalkacak
[ ] S3-03  eventBus.js — 20 satır, frontend domain event bus
[ ] S3-04  modules/ klasörü — yeni özellikler domain modülü olarak
[ ] S3-05  Workflow pipeline — kızgınlık→tohumlama→gebelik→doğum zinciri
[ ] S3-06  Üreme sekmesi UX — ayrı tablar
[ ] S3-07  Sürü ekranı — gelişmiş kartlar, tüm badge'ler
[ ] S3-08  Raporlar — dönemsel istatistikler
[ ] S3-09  Ayarlar ekranı — hekim/ırk/padok yönetimi
[ ] S3-10  Temizlik (T-01..T-05)
[ ] S3-11  Aşılama modülü
```

---

## 5. ÖZELLİK DETAYLARI

### Yaş → Grup Mantığı
```
Dişi:
  0-75 gün    → Süt İçen Buzağı
  76-180 gün  → Sütten Kesilmiş Buzağı
  181-365 gün → Düve (Küçük)
  366-730 gün → Düve (Büyük)
  730+ gün    → Sağmal (Laktasyonda) / Sağmal (Kuru) / Gebe Düve / Düve (Büyük)
  Tarih yok   → Tüm dişi gruplar açık

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
Süt İçen Buzağı        → Buzağı Padok (Süt İçenler)
Sütten Kesilmiş Buzağı → Buzağı Padok (Sütten Kesilmiş)
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

### Geçmiş / Event Etiketleri
```
DOGUM_KAYDI     → "🐄 Doğum Kaydı"
TOHUMLAMA       → "💉 Tohumlama"
HASTALIK_KAYDI  → "🏥 Hastalık Kaydı"
HAYVAN_EKLENDI  → "🐮 Hayvan Eklendi"
SUTTEN_KESME    → "🍼 Sütten Kesme"
SATIS_KAYDI     → "💰 Satış"
OLUM_KAYDI      → "💀 Ölüm"
ABORT_KAYDI     → "⚠️ Abort"
KIZGINLIK       → "🔴 Kızgınlık"
TEDAVI_GUNCELLE → "💊 Tedavi Güncelleme"
ASIL_KAYDI      → "💉 Aşı"
PADOK_DEGISIM   → "🏠 Padok Değişimi"
```

### Irk Alanı
```
[Holstein ▼] seçilince → text input gizli
[+ Diğer]   seçilince → text input açılır
```
- Dropdown: irk_esik tablosundan, kullanim_sayisi DESC
- Sabit fallback: Holstein, Simental, Montofon, Jersey, Angus, Diğer

### Excel Import/Export (Sprint 2)
```
Export: hayvan_durum_view → SheetJS → .xlsx indir
Import: boş şablon indir → doldur → yükle → hayvan_ekle() RPC loop
Kural: DB her zaman kaynak gerçek, Excel sadece giriş/çıkış aracı
```

---

## 6. OTURUM KURALLARI

1. **Her oturum tek sprint item.** Bitmeden yenisine geçme.
2. **Küçük değişiklik** → sadece değişen kod bloğunu at, tüm dosyayı değil.
3. **Bug önce konsol hatası.** "Çalışmıyor" yetmez, hata mesajı lazım.
4. **Migration her zaman idempotent.** DROP IF EXISTS + CREATE OR REPLACE.
5. **RLS her yeni tabloda.** Tablo ekle = policy ekle = SECURITY DEFINER ekle.
6. **Oturum başı:** SPEC.md oku, hangi sprint item'dan devam et.
7. **Oturum sonu:** SPEC.md güncelle, tamamlananları işaretle.
8. **Mimari kural:** Frontend hesap yapmaz. Event gönder, state göster.
9. **SW yok.** Service Worker kaldırıldı, ekleme. Offline-first ihtiyaç yok.
10. **Migration öncesi kolon kontrolü.** View güncellemeden önce tablo kolonlarını doğrula.
11. **Upload yerine GitHub web editörü.** Spck'tan dosya upload etme — çakışma riski var. GitHub'da direkt düzenle.

---

## 7. DERSLER — TEKRAR EDİLMESİN

### SW Cache Kilidi (2026-03-08)
**Ne oldu:** SW "önce cache" stratejisi yüzünden yeni dosyalar deploy edilse bile eski kod çalışmaya devam etti. Firefox SW'yi otomatik güncellemedi.
**Çözüm:** SW tamamen kaldırıldı. `app.js`'de unregister + cache temizleme kodu var.
**Ders:** SW'yi sadece gerçek offline-first ihtiyaçta kullan. Supabase bağlantısı olmadan uygulama zaten çalışmıyor.

### Spck Upload Çakışması (2026-03-08)
**Ne oldu:** Spck IDE'den 6 dosya upload edilirken `api.js`'e `app.js` içeriği gitti. `db is not defined` hatası çıktı.
**Çözüm:** GitHub web editöründen dosya düzenlendi.
**Ders:** Toplu upload yerine GitHub web editöründen tek tek düzenle. Upload öncesi diff kontrolü yap.

### View Güncelleme — Kolon Sırası (2026-03-08)
**Ne oldu:** `CREATE OR REPLACE VIEW` kolon sırası değişince `cannot change name of view column` hatası verdi.
**Çözüm:** Önce `DROP VIEW IF EXISTS`, sonra `CREATE VIEW`.
**Ders:** View güncellemelerinde her zaman DROP + CREATE. Ayrıca yeni kolon eklemeden önce tabloda var mı kontrol et.

### Alpine Terminal SSH Kalıcılığı (2026-03-10)
**Ne oldu:** Acode Alpine terminal her oturumda sıfırlanıyor, SSH key kayboluyor.
**Çözüm:** HTTPS + PAT token ile push. Remote URL'e token göm: `https://user:token@github.com/...`
**Ders:** SSH yerine HTTPS+token daha stabil bu ortamda.

### Patch Format (2026-03-10)
**Ne oldu:** `git apply` satır numarası uyuşmazlığında reddediyor. Özel karakterler heredoc'ta bozuluyor.
**Çözüm:** Basit değişimlerde `sed -i` kullan. Çok satırlı değişimlerde `python3 apply.py /tmp/p.diff`.
**Ders:** Patch vermeden önce `sed -n 'N,Mp' dosya` ile satırları doğrula.

### renderSafe vs renderFromLocal (2026-03-08)
**Ne oldu:** Edit submit'ten sonra `renderSafe()` çağrıldı, 60ms debounce yüzünden `openDet()` eski `_A` ile açıldı.
**Çözüm:** Kritik işlem sonrası `await renderFromLocal()` kullan.
**Ders:** `renderSafe` = fire-and-forget, background sync için. `renderFromLocal` = kritik işlem sonrası, sıradaki adım güncel veriye bağlıysa.

---

## 8. TEKNİK REFERANS

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
  gecmis: [],      // islem_log (→ events)
  bildirimler: [], // bildirim_log
}
```

### Önemli Fonksiyonlar
```javascript
pullTables(['tablo'])      // hedefli fetch, _pulling lock + _pendingPull queue
renderSafe()               // 60ms debounce render — background sync için
renderFromLocal()          // await'li render — kritik işlem sonrası kullan
rpcOptimistic(fn, tables)  // toast → rpc → arka planda pull + render
loadIrkDropdown()          // irk_esik'ten dropdown
loadHekimler()             // DB'den hekimler, fallback korumalı
animalFormGuncelle()       // cinsiyet+yaş → grup filtrele
animalGrupDegisti()        // grup → padok filtrele
spermaModStok()            // sperma stoktan seç
spermaModElle()            // sperma elle gir
openAnimalEdit(id)         // hayvan bilgi düzenleme modalı
closeAnimalEdit()          // edit modunu temizle, form sıfırla
```

### Supabase Realtime (Sprint 3)
```javascript
// Polling'i tamamen kaldıracak
supabase
  .channel('events')
  .on('postgres_changes',
    { event: 'INSERT', schema: 'public', table: 'events' },
    payload => eventBus.emit(payload.new.event_type, payload.new)
  )
  .subscribe()
```
