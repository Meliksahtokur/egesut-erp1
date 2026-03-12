# EgeSüt ERP — SPEC v9
> Her oturumun başında okunur. Hem harita hem rota. Sigortamız.
> Son güncelleme: 2026-03-12 — F-01 kısmen tamamlandı. m-disease edit modda çalışıyor. tedavi_guncelle + ledger düzeltmesi tamamlandı. Kalan: ilaç satırı düzenleme UI (detay modalında). T-07 hala bloke.

---

## 0. OTURUM PROTOKOLÜ

1. SPEC'i oku
2. Sıradaki item'ı söyle, onay al
3. Değişiklik formatı: SEARCH/REPLACE veya inline python (bkz. §0b). Tam dosya sadece büyük refactor'larda.
4. Oturum sonu SPEC'i güncelle, push et

---

## 0b. GELİŞTİRME PİPELINE'I

**Ortam:** Termux → `proot-distro login fedora` → `/root/egesut-erp1`

### Dosya Değişikliği — SEARCH/REPLACE (standart yöntem)

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

Çok dosya + commit — inline python (en hızlı):
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

Tam dosya: sadece büyük yeniden yapılandırmalarda (tüm dosya refactor, yeni modül).

### Migration
Supabase SQL Editor'dan çalıştırılır. Her migration idempotent olmalı.

### Git Token
```bash
git remote set-url origin https://Meliksahtokur:TOKEN@github.com/Meliksahtokur/egesut-erp1.git
```

---

## 1. SİSTEM DURUMU

### Çalışan Altyapı ✅
- Modüler yapı: `index.html` + `js/api.js` + `js/app.js` + `js/ui.js` + `js/forms.js`
- Service Worker kaldırıldı → unregister script `app.js`'de mevcut
- `pullTables` / `renderSafe` / `rpcOptimistic` / `renderFromLocal` sistemi
- `islem_log` trigger: hayvanlar / dogum / tohumlama / hastalik_log / kizginlik_log
- Hayvan kaydı (`hayvan_ekle`) + düzenleme (`hayvan_guncelle`)
- Irk dropdown (DB'den kullanım sıklığına göre, "Diğer" text fallback)
- Tohumlama kaydı + validasyon (erkek / yaş / aktif gebelik DB'de engelleniyor)
- Sperma dropdown: stok modu (varsayılan) + elle giriş modu
- Hastalık kaydı: kategori → hastalık zinciri + çoklu semptom + lokasyon chip
- Hastalık detay: düzenle / kapat / sil
- Görev tamamlama + iptal
- Hekimler DB'den, fallback korumalı
- Hayvan kartında fiziksel alanlar (cinsiyet, ağırlık, boy, renk, ayırt edici)
- Sürü filtrasyonu: dişi/erkek, gebe/boş, hasta/sağlıklı chip filtreleri
- Geçmiş ekranı: detay modal, hastalık/tohumlama detay, geri al butonu

### Tamamlanan Sprint İtemleri ✅
| Item | Açıklama |
|------|----------|
| S1-01 | Grup filtreleme — closeM() formu tam sıfırlıyor |
| S1-02 | Tohumlama validasyonu — erkek/yaş/gebelik DB'de |
| S1-03 | Hayvan kartından tedavi küpe otodolumu |
| S1-04 | Geçmiş ekranı — detay modal, geri al |
| S1-05 | Sperma stok bağlantısı — stok=0 disabled |
| S1-06 | Tohumlama autocomplete — tohumlanabilir_hayvanlar view |
| S2-01 | Sürü filtrasyonu chip filtreleri |
| S2-02 | Hayvan detay geçmiş sekmesi (düzenle/kapat/sil) |
| S2-03 | Hastalık formu — kategori→hastalık + çoklu semptom |
| S2-04 | Hekimler DB'ye taşındı |

### Bekleyen Sprint İtemleri 🔴
| Item | Açıklama | Dosyalar |
|------|----------|----------|
| **F-01** | **Form Mimarisi Yeniden Tasarımı** — kısmen ✅. Kalan: detay modalında ilaç satırı düzenleme UI (tedavi_guncelle frontend) | forms.js / index.html |
| T-07 | İlaç yönetimi — F-01 tamamlandıktan sonra | ui.js / forms.js |
| S2-05 | Abort akışı — gebe listesi, abort modal, badge | ui.js / forms.js |
| S2-06 | Üreme tab: gebelik butonu kaldır, doğum görevleri | ui.js |
| S2-07 | Görev renk mantığı — geciken/bugün/yakın/gelecek | ui.js |
| S2-08 | Toplu işlem paneli | ui.js / forms.js |
| S2-09 | Excel import/export — SheetJS | yeni modül |
| S2-10 | Grup/padok/laktasyon yeniden tasarımı + mig-015 | app.js + migration |
| S2-11 | Kızgınlık/tohumlama sekmesi | ui.js |

### Temizlik 🟡
| # | Görev | Durum |
|---|-------|-------|
| T-01..03 | yazIslemLog / _gecmisFallback / raw fetch | ✅ Zaten temizdi |
| T-04 | APP_VERSION | ✅ 2026-03-12 |
| T-05 | pullTables setInterval kaldır | ⏸ Realtime gelince |
| T-06 | Lokasyon — düzenleme formunda chip dropdown | ✅ |
| T-07 | İlaç yönetimi | ⏸ F-01 bekliyor |

---

## 2. F-01 — FORM MİMARİSİ YENİDEN TASARIM

### Sorun
Tüm formlar serbest text girişi üzerine kurulu. DB'de tanımlı objeler var ama formlar bunları kullanmıyor.
Bu durum analitik verileri bozuyor — aynı hastalık farklı yazılışlarla kayıt altına giriyor.

### Etkilenen Formlar
| Form | Sorun |
|------|-------|
| Hastalık kayıt | Tanı, semptom elle yazılıyor — DB dropdown yok |
| Hastalık düzenleme | Eski kayıt verisi yükleniyor ama ilaç/hekim dropdown yok |
| İlaç ekleme (detay modal) | Stok autocomplete çalışmıyor, birim otomatik dolmuyor |
| Tüm formlar | Hekim dropdown var ama tutarsız bağlanmış |

### Yapılacaklar

**1. Hastalık kayıt formu (mevcut `m-disease` modalı)**
- Tanı: `HASTALIK_KAT` zaten var, dropdown çalışıyor → dokunma
- Semptom: `SEMPTOM_KAT` zaten var, chip sistemi çalışıyor → dokunma
- İlaç satırı: stok autocomplete `kategori='İlaç'` filtreli → düzelt
- İlaç satırına uygulama yolu dropdown + bekleme süresi ekle
- Payload'a `uygulama_yolu` ve `bekleme_suresi_gun` ekle

**2. Hastalık düzenleme formu (`hd-edit-form`)**
- Tanı: text input → autocomplete (HASTALIK_KAT'tan)
- Şiddet: select — zaten var, veri dolumu kontrol et
- Semptomlar: text → chip sistemi (kayıt formuyla aynı)
- Hekim: text → `loadHekimler()` dropdown
- Tarih: input date ekle

**3. İlaç ekleme formu (detay modal `hd-ilac-form`)**
- `acHdiStok()` debug et — stok listesi gelmiyor
- Birim: ilaç seçince otomatik dolsun, readonly
- Uygulama yolu: dropdown ✅ (çalışıyor)
- Bekleme süresi: input ✅

**4. Genel**
- `btn-o` renk sorunu — CSS kontrol et
- "İyileşti" butonu renk ekle (sarı/yeşil)

### T-07 ile İlişki
F-01 tamamlandıktan sonra T-07 (ilaç yönetimi) anlamlı hale gelir.
Şu an T-07 backend'i hazır, ilaç listesi ve silme çalışıyor.
Eksik: ilaç ekleme formu stok'tan seçim yapamıyor.

---

## 3. MİMARİ

### Mevcut
```
Frontend (Vanilla JS)
  ↓ db.rpc() / db.from()
Supabase
  • Stored Procedures  → iş mantığı + validasyon
  • Triggers           → otomatik islem_log
  • Views              → hesaplı veriler
  • RLS + SECURITY DEFINER
  ↓
PostgreSQL
```

**Kural:** Frontend hesap yapmaz. DB'den hazır değeri okumak filtredir, hesap değildir.

### Hedef (Sprint 3+)
```
USER ACTION → RPC → POSTGRES TRIGGER → islem_log → SUPABASE REALTIME → eventBus → Frontend
```

### Dosya Yapısı
```
index.html          — HTML + CSS + modaller
js/api.js           — Supabase client, pullTables, renderSafe, rpcOptimistic, IndexedDB
js/app.js           — init, routing, global state, form yardımcıları, dropdown mantığı
js/ui.js            — tüm render fonksiyonları
js/forms.js         — tüm submit / RPC çağrıları
sw.js               — SW kaydını siler (fetch handler yok)
apply.py            — SEARCH/REPLACE yardımcısı (ikincil)
supabase/migrations/ — idempotent SQL dosyaları
```

---

## 4. VERİTABANI

### Migration Durumu
| # | İçerik | Durum |
|---|--------|-------|
| 001-005 | Temel şema, FK, triggerlar | ✅ |
| 006 | hayvan_durum_view, irk_esik, bildirim_log, islem_log, kupe_musait_mi() | ✅ |
| 007 | cikis_yap(), geri_al() | ✅ |
| 008 | hayvan_ekle, dogum_kaydet, tohumlama_kaydet, tüm RPC'ler, triggerlar, RLS | ✅ |
| 009 | hekimler, tohumlama validasyon, islem_log payload jsonb | ✅ |
| 010 | hayvan_guncelle RPC (COALESCE pattern) | ✅ |
| 011 | ⏸ Atlandı | — |
| 012 | _islem_log_yaz trigger fix | ✅ |
| 013 | ground_truth — tüm stored proc'lar yeniden tanımlandı | ✅ |
| 014 | tohumlanabilir_hayvanlar view | ✅ |
| 015 | hayvanlar.laktasyonda boolean — S2-10 için | 🔜 |
| 016-018 | ref_id/ref_tablo, hastalik_guncelle/kapat/sil | ✅ |
| 019 | tedavi yeniden tasarım: uygulama_yolu, tedavi_ekle/sil, hastalik_kaydet/sil güncellendi | ✅ |
| 020 | hastalik_guncelle RPC'ye p_tarih eklendi | ✅ |
| 021 | stok_hareket audit kolonları (referans_tipi/id) + tedavi_sil ledger + tedavi_guncelle RPC | ✅ |

### Tablolar
| Tablo | Amaç |
|-------|------|
| hayvanlar | Ana sürü kaydı |
| hayvan_durum_view | Hesaplı alanlar (yaş, tohumlama durumu vb.) |
| tohumlanabilir_hayvanlar | View — tohumlama yapılabilecek hayvanlar |
| tohumlama | Tohumlama kayıtları |
| dogum | Doğum kayıtları |
| hastalik_log | Hastalık vakası |
| tedavi | İlaç uygulamaları (hastalik_log.vaka_id ile bağlı) |
| tedavi_view | tedavi + stok join (ilac_adi, ilac_birim) |
| gorev_log | Görevler |
| stok | Ürün stok tanımları (İlaç / Sperma / Malzeme / Yem / Diğer) |
| stok_hareket | Stok giriş/çıkış hareketleri |
| irk_esik | Irka göre tohumlama/sütten kesme eşikleri |
| islem_log | Event log (trigger ile dolar) |
| bildirim_log | Sistem bildirimleri |
| kizginlik_log | Kızgınlık kayıtları |
| cop_kutusu | Silinen kayıtlar 30 gün burada |

---

## 5. YOL HARİTASI

### Sprint 2 — Devam
```
[🔴] F-01   Form mimarisi yeniden tasarım — ÖNCELİKLİ
[⏸]  T-07   İlaç yönetimi (F-01 sonrası)
[ ]  S2-05  Abort akışı
[ ]  S2-06  Üreme tab düzeltme
[ ]  S2-07  Görev renk mantığı
[ ]  S2-08  Toplu işlem paneli
[ ]  S2-09  Excel import/export
[ ]  S2-10  Grup/padok/laktasyon + mig-015
[ ]  S2-11  Kızgınlık/tohumlama sekmesi
```

### Sprint 3 — Mimari Geçiş
```
[ ]  S3-00  geri_al RPC yeniden tasarım
[ ]  S3-01  Supabase Realtime
[ ]  S3-02  eventBus.js
[ ]  S3-03  modules/ klasörü
[ ]  S3-04  Workflow pipeline (kızgınlık→tohumlama→gebelik→doğum)
[ ]  S3-05  Raporlar ekranı
[ ]  S3-06  Ayarlar ekranı
[ ]  S3-07  Aşılama modülü
[ ]  T-05   pullTables setInterval kaldır
```

---

## 6. İŞ MANTIĞI REFERANSI

### Grup/Padok (S2-10 detayı)
```
DİŞİ:
  0-60 gün                             → Süt İçen Buzağı / Buzağı Padok (Süt İçenler)
  61-120 gün                           → Süt İçen | Kesilmiş / Buzağı Padok
  121-240 gün                          → Düve (Küçük) / Düve Padok (Küçük|Büyük)
  241-420 gün                          → Düve (Büyük) / Düve Padok (Büyük) | Sağmal Padok
  420+, doğum yok                      → Düve (Büyük) | Gebe Düve
  420+, doğum var, laktasyon=true      → Sağmal (Laktasyonda) / Sağmal Padok
  420+, doğum var, laktasyon=false     → Sağmal (Kuru) / Kuru/Gebe Padok
  420+, doğum var, gebe=true           → Gebe Düve | Sağmal (Kuru)
ERKEK:
  0-60 gün    → Süt İçen Buzağı
  61-120 gün  → Süt İçen | Sütten Kesilmiş
  120+ gün    → Besi | Sütten Kesilmiş
```

### Görev Renk Mantığı
```
geciken  (< bugün)  → kırmızı,  badge'e dahil
bugün    (= bugün)  → amber,    badge'e dahil
yakın    (1-3 gün)  → sarı,     badge'e dahil değil
gelecek  (> 3 gün)  → normal
```

### islem_log Event Tipleri → UI Etiketleri
```
DOGUM_KAYDI        → 🐄 Doğum
TOHUMLAMA          → 💉 Tohumlama
HASTALIK_KAYDI     → 🏥 Hastalık
HAYVAN_EKLENDI     → 🐮 Hayvan Eklendi
ABORT_KAYDI        → ⚠️ Abort
KIZGINLIK          → 🔴 Kızgınlık
```

---

## 7. OTURUM KURALLARI

1. Her oturum tek sprint item — bitmeden yenisine geçme
2. Değişiklik formatı: SEARCH/REPLACE veya inline python. Tam dosya sadece büyük yeniden yapılandırmalarda.
3. Migration her zaman idempotent: `DROP IF EXISTS + CREATE OR REPLACE`
4. Yeni tablo = RLS policy + SECURITY DEFINER
5. Frontend hesap yapmaz
6. SW ekleme
7. Bug'da önce konsol — mobilde toast/hint div ile debug
8. View güncellemede her zaman `DROP IF EXISTS ... CASCADE`

---

## 8. DERSLER — TEKRAR EDİLMESİN

| Konu | Ders |
|------|------|
| SW Cache | SW kaldırıldı, geri gelmiyor |
| Spck Upload | Dosyalar karıştı. GitHub web editörü kullan |
| View kolon sırası | Her zaman DROP + CREATE |
| git apply | Unicode + satır kayması. Tam dosya veya SEARCH/REPLACE |
| islem_log RLS | Her tabloda SELECT policy gerekli |
| _pulling lock | Kritik fetch'leri direkt `db.from()` ile yap |
| renderSafe debounce | Kritik sonrası `await renderFromLocal()` kullan |
| hastalik_log id | Her zaman `id::text = p_id` cast et |
| gorev_log kolon | `notlar` yok, `aciklama` var |
| Geri Al vs Sil | Geri Al = snapshot restore. Sil = sadece o kayıt |
| Diff birikimi | Aşırı küçük diff'ler dosyaları karıştırabilir. Değişiklikler mantıklı gruplar halinde verilmeli. |
| Modal auto-date | today() otomatik dolunca yasGun=0 bug'ı çıktı |
| Stok ledger | stok_hareket asla silinmez/iptal edilmez — her düzeltme yeni hareket INSERT |
| tedavi_sil | iptal=true yanlış — ledger: +miktar yeni hareket ekle |
| Migration Actions | supabase/migrations push → GitHub Actions otomatik Supabase'e uygular |
| Zip verme | Değişiklikleri zip değil SEARCH/REPLACE veya PYEOF bloğu olarak ver |

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
  hayvanlar: [],    // hayvan_durum_view
  stok: [],         // stok tablosu
  gorevler: [],     // gorev_log
  gecmis: [],       // islem_log
  bildirimler: [],  // bildirim_log
  tedavi: [],       // tedavi_view — T-07 ile eklenecek
}
window._TH = []     // tohumlanabilir_hayvanlar — m-insem açılınca fetch edilir
```

### Önemli Fonksiyonlar
```javascript
pullTables(['tablo'])        // hedefli fetch, _pulling lock var
renderSafe()                 // 60ms debounce — background sync
renderFromLocal()            // await — kritik işlem sonrası
rpcOptimistic(fn, tables)    // toast → rpc → pull + render
loadIrkDropdown()            // irk_esik'ten dropdown
loadHekimler()               // DB'den, fallback korumalı
animalFormGuncelle()         // cinsiyet+yaş+laktasyon → grup filtrele
animalGrupDegisti()          // grup → padok filtrele
spermaModStok()              // sperma stoktan seç
spermaModElle()              // sperma elle gir
openAnimalEdit(id)           // hayvan bilgi düzenleme
openHstDet(id)               // hastalık detay modal
acHayvan(inputId, listId)    // hayvan autocomplete
```
