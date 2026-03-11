# EgeSüt ERP — SPEC v6
> Her oturumun başında okunur. Hem harita hem rota. Sigortamız.
> Son güncelleme: 2026-03-11 — S2-01/S2-02 tamamlandı, sürü filtre chip'leri + hayvan detay geçmiş sekmesi (islem_log direkt DB sorgusu)

---

## 0. OTURUM BAŞI KONTROL LİSTESİ

1. Bu SPEC'i oku
2. Sprint tablosuna bak, sıradaki item'ı söyle
3. Onay al, başla
4. Değişiklik = SEARCH/REPLACE formatında ver (tam dosya değil)
5. Oturum sonu SPEC'i güncelle

---

## 0b. GELİŞTİRME PİPELINE'I

**Araçlar:** Termux → proot-distro login fedora → `/root/egesut-erp1`

**Ortam:**
```bash
proot-distro login fedora
cd /root/egesut-erp1
```

**Her değişiklik için format — SEARCH/REPLACE (tercih edilen):**

Tek dosya, tek blok:
```bash
cat > /tmp/r.txt << 'EOF'
SEARCH:
eski metin
REPLACE:
yeni metin
EOF
python3 apply.py --replace js/ui.js /tmp/r.txt
```

Tek dosya, çoklu blok (`---` ayracıyla):
```bash
cat > /tmp/r.txt << 'EOF'
SEARCH:
eski1
REPLACE:
yeni1
---
SEARCH:
eski2
REPLACE:
yeni2
EOF
python3 apply.py --replace js/ui.js /tmp/r.txt
```

Çok dosya + commit — inline python (en hızlı yöntem):
```bash
python3 << 'PYEOF'
import subprocess, os
os.chdir('/root/egesut-erp1')
changes = [
    ('js/api.js', 'eski1', 'yeni1'),
    ('js/ui.js',  'eski2', 'yeni2'),
]
for filepath, search, replace in changes:
    with open(filepath, encoding='utf-8') as f: content = f.read()
    if search not in content:
        print(f"HATA: {filepath}: {search[:60]}"); continue
    content = content.replace(search, replace, 1)
    with open(filepath, 'w', encoding='utf-8') as f: f.write(content)
    print(f"OK: {filepath}")
subprocess.run(["git", "add", "."])
subprocess.run(["git", "commit", "-m", "commit mesajı"])
push = subprocess.run(["git", "push"], capture_output=True, text=True)
print("Tamam" if push.returncode == 0 else f"Push hatasi:\n{push.stderr}")
PYEOF
```

**Kurallar:**
- Tam dosya rewrite YOK — sadece değişen satırlar
- `git apply` KULLANMA — satır numarası kayması, unicode bozulması yaşatıyor
- SEARCH/REPLACE tercih edilir — string match, unicode sorun çıkarmaz
- Migration değişiklikleri Supabase SQL Editor'dan çalıştırılır
- Remote URL token gömülü olmalı: `https://Meliksahtokur:TOKEN@github.com/Meliksahtokur/egesut-erp1.git`
- Token oturum başında kaybolursa: `git remote set-url origin https://Meliksahtokur:TOKEN@github.com/Meliksahtokur/egesut-erp1.git`

---

## 1. MEVCUT DURUM

### Tamamlanan ✅
- Migration 008–013 push edildi
- Modüler yapı: index.html + js/api.js + js/app.js + js/ui.js + js/forms.js
- ~~Service Worker~~ → **SW KALDIRILDI**, unregister script app.js'de
- pullTables / renderSafe / rpcOptimistic / renderFromLocal sistemi
- Hayvan kaydı (hayvan_ekle RPC), hayvan düzenleme (hayvan_guncelle RPC)
- Irk dropdown (DB'den, kullanım sıklığına göre, "Diğer" text input)
- Tohumlama kaydı + validasyon (erkek/yaş/aktif gebelik DB'de engelleniyor)
- Sperma dropdown (spermaModStok / spermaModElle) — modal açılınca stok modu varsayılan
- Görev tamamlama, hastalık kaydı (kategori→hastalık zinciri)
- islem_log trigger (hayvanlar/dogum/tohumlama/hastalik/kizginlik)
- Hekimler DB'de, loadHekimler() fallback korumalı
- Hayvan kartında fiziksel alanlar (cinsiyet, ağırlık, boy, renk, ayırt edici)
- **S1-01 ✅** Grup filtreleme — closeM() formu tam sıfırlıyor
- **S1-02 ✅** Tohumlama validasyonu — erkek/yaş/gebelik DB'de engelleniyor
- **S1-03 ✅** Hayvan kartından tedavi küpe otodolumu
- **S1-04 ✅** Geçmiş ekranı — küpe çözümlendi, detay modal, geri al butonu
- **S1-05 ✅** Sperma stok bağlantısı — seçimde stok göster, stok=0 kaydet disabled
- **S1-06 ✅** Tohumlama küpe autocomplete — sadece tohumlanabilir_hayvanlar view'ından, modal açılınca fetch
- **S2-03 ✅** Hastalık formu — kategori→hastalık zinciri + çoklu semptom
- **S2-04 ✅** Hekimler DB'ye taşındı

### Çalışmayan / Eksik 🔴
| # | Sorun | Dosya | Sprint |
|---|---|---|---|
| 1 | Grup/padok form mantığı yanlış — yaş+laktasyon+doğum durumu birlikte değerlendirilmeli | app.js + migration | S2-10 |
| 2 | Sürü filtrasyonu yok — dişi/erkek, gebe/boş, hasta/sağlıklı | ui.js | S2-01 |
| 3 | Hayvan detay ekranı yok — kilo/boy/notlar/timeline | ui.js | S2-02 |
| 4 | Abort tabı çalışmıyor — gebe listesi + abort kaydet akışı | ui.js/forms.js | S2-05 |
| 5 | Abort badge hayvan kartında yok | ui.js | S2-05 |
| 6 | Gebelik tabında "Tohumlama Ekle" butonu kaldırılmadı | ui.js | S2-06 |
| 7 | Doğum tabında tetiklenen görevler görünmüyor | ui.js | S2-06 |
| 8 | Görev renk mantığı eksik — geciken/bugün/yakın/gelecek | ui.js | S2-07 |
| 9 | Kızgınlık/tohumlama sekmesi boş — tohumlanabilir hayvan listesi yok | ui.js | S2-11 |

### Temizlik Bekleyen 🟡
| # | Görev |
|---|---|
| T-01 | yazIslemLog() kaldır — trigger yapıyor |
| T-02 | _gecmisFallback() kaldır — islem_log her şeyi yazıyor |
| T-03 | Eski raw fetch/HDR/SB_URL kalıntılarını temizle |
| T-04 | APP_VERSION güncelle |
| T-05 | pullTables() setInterval kaldır — Realtime geçince gereksiz |

---

## 2. MİMARİ — MEVCUT

```
Frontend (JS)
  ↓ db.rpc() / db.from()
Supabase (Backend)
  • Stored Procedures  → iş mantığı + validasyon
  • Triggers           → otomatik islem_log
  • Views              → hesaplı veriler (hayvan_durum_view, tohumlanabilir_hayvanlar)
  • RLS + SECURITY DEFINER → güvenlik
  ↓
PostgreSQL (Veri)
```

**Tek kural:** Frontend hesap yapmaz. Veriyi çek, ekrana bas, aksiyonu RPC'ye gönder.
DB'den gelen hazır kolonları okumak (ör: `tohumlama_durumu_hesap === 'tohumlanabilir'`) hesap değildir, filtredir — kabul edilebilir.

### Dosya Yapısı
```
index.html      ~940 satır   — sadece HTML/CSS
js/api.js       ~330 satır   — Supabase client, pullTables, renderSafe, rpcOptimistic
js/app.js       ~650 satır   — init, routing, global state, form yardımcıları
js/ui.js        ~1580 satır  — tüm render fonksiyonları
js/forms.js     ~690 satır   — tüm submit fonksiyonları
sw.js                        — SW kaydını siler, fetch handler YOK
apply.py                     — SEARCH/REPLACE + patch -p1 + git push
supabase/migrations/         — 013 push edildi
```

---

## 3. MİMARİ VİZYON — HEDEF (Sprint 3+)

> Strangler fig pattern ile yavaş geçiş.

```
USER ACTION → EVENT INSERT → POSTGRES TRIGGER → PROJECTION UPDATE → SUPABASE REALTIME → FRONTEND
```

Sprint 3'te eklenecek: events tablosu (islem_log standardize), eventBus.js, Realtime subscription, modules/ klasörü

---

## 4. VERİTABANI

### Migration Durumu
| Migration | İçerik | Durum |
|---|---|---|
| 001-005 | Temel şema, FK, triggerlar | ✅ |
| 006 | hayvan_durum_view, irk_esik, bildirim_log, islem_log, kupe_musait_mi() | ✅ |
| 007 | updated_at, bos_gun, cikis_yap(), geri_al() | ✅ |
| 008 | hayvan_ekle, dogum_kaydet, tohumlama_kaydet, tüm RPC'ler, triggerlar, RLS | ✅ |
| 009 | hekimler, tohumlama validasyon, hayvan_timeline_view, islem_log payload jsonb | ✅ |
| 010 | hayvan_guncelle RPC (COALESCE pattern) | ✅ |
| 011 | ⏸ Beklemede | ⏸ |
| 012 | _islem_log_yaz trigger fix | ✅ |
| 013 | ground_truth — tüm stored proc'lar yeniden tanımlandı | ✅ |
| 014 | tohumlanabilir_hayvanlar view (Supabase SQL Editor'dan çalıştırıldı) | ✅ |
| 015 | hayvanlar.laktasyonda boolean kolonu — S2-10 için gerekli | 🔜 |

### Mevcut Views
| View | Açıklama |
|---|---|
| hayvan_durum_view | Tüm hesaplı alanlar — yas_gun, tohumlama_durumu_hesap, hesap_kategori vb. |
| tohumlanabilir_hayvanlar | hayvan_durum_view'dan WHERE tohumlama_durumu_hesap = 'tohumlanabilir' |

---

## 5. YOL HARİTASI

### Sprint 1 — Kritik Buglar ✅ Tamamlandı
```
[x] S1-01  Grup filtreleme — closeM() formu tam sıfırlıyor
[x] S1-02  Tohumlama validasyonu — erkek/yaş/gebelik DB'de engelleniyor
[x] S1-03  Hayvan kartından tedavi küpe otodolumu
[x] S1-04  Geçmiş ekranı — detay modal, geri al butonu
[x] S1-05  Sperma stok bağlantısı — stok göster, stok=0 disabled
[x] S1-06  Tohumlama autocomplete — sadece tohumlanabilir hayvanlar, tohumlanabilir_hayvanlar view
```

### Sprint 2 — Eksik Özellikler
```
[ ] S2-01  Sürü filtrasyonu — dişi/erkek, gebe/boş, hasta/sağlıklı, grup/padok
[ ] S2-02  Hayvan detay ekranı — kilo, boy, renk, notlar, event timeline
[x] S2-03  Hastalık formu — kategori→hastalık zinciri + çoklu semptom
[x] S2-04  Hekimler DB'ye taşındı
[ ] S2-05  Abort akışı — gebe listesi, abort modal, badge
[ ] S2-06  Üreme tab düzeltme — gebelik butonu kaldır, doğum görevleri
[ ] S2-07  Görev renk mantığı — geciken/bugün/yakın/gelecek
[ ] S2-08  Toplu işlem paneli — toplu tohumlama, aşı, padok değişimi, satış
[ ] S2-09  Excel import/export — SheetJS
[ ] S2-10  Grup/padok/laktasyon yeniden tasarımı — hayvan formu + migration (detay aşağıda)
[ ] S2-11  Kızgınlık/tohumlama sekmesi — tohumlanabilir hayvan listesi gruplu gösterim
```

### Sprint 3 — Mimari Geçiş
```
[ ] S3-01  events tablosu — islem_log standardize
[ ] S3-02  Supabase Realtime subscription
[ ] S3-03  eventBus.js
[ ] S3-04  modules/ klasörü
[ ] S3-05  Workflow pipeline — kızgınlık→tohumlama→gebelik→doğum
[ ] S3-06  Üreme sekmesi UX
[ ] S3-07  Sürü ekranı — gelişmiş kartlar
[ ] S3-08  Raporlar
[ ] S3-09  Ayarlar ekranı
[ ] S3-10  Temizlik (T-01..T-05)
[ ] S3-11  Aşılama modülü
```

---

## 6. ÖZELLİK DETAYLARI

### S2-10 — Grup/Padok/Laktasyon Yeniden Tasarımı

**Sorun:** Mevcut `animalFormGuncelle()` sadece yaşa bakıyor. Gerçekte grup; yaş + doğum sayısı + laktasyon durumu + gebelik durumuna göre belirleniyor.

**DB Değişikliği (migration 015):**
```sql
ALTER TABLE hayvanlar ADD COLUMN IF NOT EXISTS laktasyonda boolean DEFAULT false;
```

**Yeni Grup/Padok Mantığı:**
```
DİŞİ:
  0-60 gün       → grup: Süt İçen Buzağı
                   padok: Buzağı Padok (Süt İçenler)

  61-120 gün     → grup: Süt İçen Buzağı | Sütten Kesilmiş Buzağı
                   padok: Buzağı Padok (Süt İçenler) | Buzağı Padok (Sütten Kesilmiş)

  121-240 gün    → grup: Düve (Küçük)
                   padok: Düve Padok (Küçük) | Düve Padok (Büyük)

  241-420 gün    → grup: Düve (Büyük)
                   padok: Düve Padok (Büyük) | Sağmal Padok

  420+ gün, doğum yok   → grup: Düve (Büyük) | Gebe Düve
                           padok: Düve Padok (Büyük) | Kuru/Gebe Padok | Sağmal Padok

  420+ gün, doğum var, laktasyonda=true    → grup: Sağmal (Laktasyonda)
                                              padok: Sağmal Padok

  420+ gün, doğum var, laktasyonda=false   → grup: Sağmal (Kuru)
                                              padok: Kuru/Gebe Padok

  420+ gün, doğum var, gebe=true           → grup: Gebe Düve | Sağmal (Kuru)
                                              padok: Kuru/Gebe Padok

  Tarih yok → tüm gruplar açık

ERKEK:
  0-60 gün    → Süt İçen Buzağı
  61-120 gün  → Süt İçen Buzağı | Sütten Kesilmiş Buzağı
  120+ gün    → Besi | Sütten Kesilmiş Buzağı
```

**Form Değişiklikleri:**
- Hayvan formu yeni alanlar: "Buzağı sayısı" (0 = doğum yok), "Laktasyonda mı?" checkbox, "Gebe mi?" checkbox
- Gebe=true + Laktasyonda=false → Kuru dönem
- Bu alanlar hem grup/padok seçimini etkiler hem DB'ye kaydedilir
- `animalFormGuncelle()` bu 3 inputu okuyacak, grup/padok listesini DB'deki mantığa göre değil — view'dan gelecek şekilde güncellenecek (S3 hedefi)
- Şimdilik frontend mantığı kabul edilebilir çünkü grup listesi sabit, hesap yok

**Sütten Kesme Bildirisi:**
- `irk_esik.suttten_kesme_gun` eşiği geçince `bildirim_log`'a kayıt düşülüyor (mevcut trigger)
- 60 gün sonra kullanıcı formu güncelleyip sütten kesme yapmalı

### Yaş → Grup Mantığı (Güncel)
Detay S2-10 bölümünde. Özet: yaş + buzağı sayısı + laktasyon + gebelik birlikte değerlendiriliyor.

### Grup → Padok Haritası
```
Sağmal (Laktasyonda)   → Sağmal Padok
Sağmal (Kuru)          → Kuru/Gebe Padok
Gebe Düve              → Kuru/Gebe Padok
Düve (Büyük)           → Düve Padok (Büyük) | Sağmal Padok
Düve (Küçük)           → Düve Padok (Küçük) | Düve Padok (Büyük)
Süt İçen Buzağı        → Buzağı Padok (Süt İçenler)
Sütten Kesilmiş Buzağı → Buzağı Padok (Sütten Kesilmiş) | Buzağı Padok (Süt İçenler)
Besi                   → Düve Padok (Büyük) | Düve Padok (Küçük) | Sağmal Padok
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
Abort tab → "Gebe Hayvanları Listele" → Liste (gebelik günü ASC)
→ Hayvan seç → "Abort Kaydet" → Onay modal → abort_kaydet() RPC
→ Hayvan boş düşer → Hayvan kartında "⚠️ {n} Abort" kırmızı badge
```

### Geçmiş / Event Etiketleri
```
DOGUM_KAYDI → "🐄 Doğum"  |  TOHUMLAMA → "💉 Tohumlama"
HASTALIK_KAYDI → "🏥 Hastalık"  |  HAYVAN_EKLENDI → "🐮 Hayvan Eklendi"
SUTTEN_KESME → "🍼 Sütten Kesme"  |  SATIS_KAYDI → "💰 Satış"
OLUM_KAYDI → "💀 Ölüm"  |  ABORT_KAYDI → "⚠️ Abort"
KIZGINLIK → "🔴 Kızgınlık"  |  TEDAVI_GUNCELLE → "💊 Tedavi"
```

### Irk Alanı
- Dropdown: irk_esik'ten kullanim_sayisi DESC
- "Diğer" seçilince text input açılır
- Fallback: Holstein, Simental, Montofon, Jersey, Angus, Diğer

---

## 7. OTURUM KURALLARI

1. **Her oturum tek sprint item.** Bitmeden yenisine geçme.
2. **Değişiklik formatı:** SEARCH/REPLACE veya inline python — tam dosya rewrite YOK.
3. **Bug önce konsol hatası.** Mobilde konsol yok, görsel debug (geçici toast/hint) kullan.
4. **Migration her zaman idempotent.** DROP IF EXISTS + CREATE OR REPLACE.
5. **RLS her yeni tabloda.** Tablo ekle = policy ekle = SECURITY DEFINER ekle.
6. **Oturum başı:** SPEC.md oku, hangi sprint item'dan devam et, onay al.
7. **Oturum sonu:** SPEC.md güncelle, tamamlananları işaretle.
8. **Mimari kural:** Frontend hesap yapmaz. DB'den gelen hazır değeri okumak filtredir, hesap değildir.
9. **SW yok.** Service Worker kaldırıldı, ekleme.
10. **Migration öncesi kolon kontrolü.** View güncellemeden önce tablo kolonlarını doğrula.
11. **Repo yöntemi:** GitHub web editörü veya Termux/Fedora terminal. Spck'tan upload etme.
12. **apply.py kullan.** `git apply` kullanma — unicode + satır numarası sorun çıkarıyor.

---

## 8. DERSLER — TEKRAR EDİLMESİN

### SW Cache Kilidi
SW "önce cache" yüzünden eski kod çalışmaya devam etti. → SW kaldırıldı, unregister script var.

### Spck Upload Çakışması
Toplu upload'da api.js'e app.js içeriği gitti. → GitHub web editörü veya tek tek düzenle.

### View Güncelleme — Kolon Sırası
`CREATE OR REPLACE VIEW` kolon sırası değişince hata. → Her zaman DROP IF EXISTS + CREATE.

### git apply Sorunları
Satır numarası kayması + unicode bozulması. → SEARCH/REPLACE veya inline python kullan, git apply kullanma.

### _pulling Lock
Modal açılırken `pullTables` çağrısı lock'a takılıyordu. → Kritik fetch'leri `db.from().select()` ile direkt yap, `pullTables`'ı bypass et. (Örnek: `m-insem` açılınca `tohumlanabilir_hayvanlar` direkt fetch ediliyor.)

### renderSafe vs renderFromLocal
`renderSafe` 60ms debounce — kritik işlem sonrası eski veriyle açılıyor. → Kritik işlem sonrası `await renderFromLocal()` kullan.

### Mobil Debug
Mozilla Nightly Android'de F12 yok. → Geçici toast veya hint div'e değer yaz, test et, kaldır.

### Remote URL Token
Her Fedora oturumunda token kayboluyor. → `git remote set-url origin https://Meliksahtokur:TOKEN@github.com/Meliksahtokur/egesut-erp1.git`

---

## 9. TEKNİK REFERANS

### Bağlantı
```
Supabase URL : https://zqnexqbdfvbhlxzelzju.supabase.co
Live URL     : https://meliksahtokur.github.io/egesut-erp1/
IndexedDB    : egesut_v9, DB_VER=6
Repo         : github.com/Meliksahtokur/egesut-erp1
Fedora path  : /root/egesut-erp1
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
window._TH = []    // tohumlanabilir_hayvanlar — m-insem açılınca fetch edilir
```

### Önemli Fonksiyonlar
```javascript
pullTables(['tablo'])           // hedefli fetch, _pulling lock var
renderSafe()                    // 60ms debounce — background sync
renderFromLocal()               // await — kritik işlem sonrası
rpcOptimistic(fn, tables)       // toast → rpc → pull + render
loadIrkDropdown()               // irk_esik'ten dropdown
loadHekimler()                  // DB'den hekimler, fallback korumalı
animalFormGuncelle()            // cinsiyet+yaş+laktasyon → grup filtrele
animalGrupDegisti()             // grup → padok filtrele
spermaModStok()                 // sperma stoktan seç (varsayılan mod)
spermaModElle()                 // sperma elle gir
onSpermaSelect(sel)             // stok kontrolü + hint + disabled
openAnimalEdit(id)              // hayvan bilgi düzenleme
acHayvan(inputId, listId)       // genel hayvan autocomplete
```

### Supabase Realtime (Sprint 3)
```javascript
supabase.channel('events')
  .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'events' },
    payload => eventBus.emit(payload.new.event_type, payload.new))
  .subscribe()
```
