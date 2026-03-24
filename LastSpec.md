# EgeSüt ERP — LastSpec
> Son güncelleme: 2026-03-23 | Aktif referans dökümanı

---

## 1. MİMARİ ÖZET

- **Frontend:** Vanilla JS, tek `index.html`
- **Backend:** Supabase (PostgreSQL + RPC)
- **Cache:** IndexedDB (`egesut_v12`, DB_VER=13)
- **Deploy:** GitHub Pages (otomatik, her push)
- **State:** `js/state.js` → `getState/setState` pattern

---

## 2. VERİTABANI DURUMU

### Aktif Tablolar
hayvanlar, tohumlama, dogum, kizginlik_log
gorev_log, stok, stok_hareket
cases, diseases, drug_classes, drug_products, drug_administrations, treatment_days
islem_log, bildirim_log, cop_kutusu
### İlaç Hiyerarşisi
drug_classes (grup/sınıf/etken madde — 29 kayıt seed)
└── drug_products (preparat/marka — kullanıcı ekler)
└── stok (envanter — drug_product_id FK)
└── drug_administrations (tedavi uygulaması)
### Kritik View
- `treatment_timeline` — LEFT JOIN treatment_days → drug_administrations → drug_products → stok

### Aktif RPC'ler
| RPC | Durum |
|-----|-------|
| `create_case` | ✅ |
| `add_treatment_day(p_case_id, p_date)` | ✅ tarih parametreli |
| `add_drug_administration` | ✅ |
| `update_drug_administration` | ✅ |
| `remove_drug_administration` | ✅ |
| `delete_treatment_day` | ✅ stok geri alır |
| `close_case` | ✅ |
| `hayvan_ekle`, `dogum_kaydet`, `tohumlama_kaydet` | ✅ |
| `cikis_yap`, `abort_kaydet`, `geri_al` | ✅ |

### Teknik Borç
- `hastalik_log`, `tedavi` tabloları orphan (eski sistem, korunuyor)
- `drugs.stock_item_id` kolonu kalıntı
- `stok_hareket`'te `hekim_id` yok — kim ne yaptı izlenemiyor (auth sistemi bekliyor)
- Migration 013-014 repo'da yok (SQL Editor'dan uygulandı, drift var)

---

## 3. BU OTURUMDA YAPILAN İŞLER ✅

### Klinik Modül (CLN serisi)
- `treatment_timeline` view → `drug_product_id` mimarisine güncellendi (LEFT JOIN)
- `loadDrugsCache` → IDB boşsa Supabase'den pull garantisi eklendi
- `loadDrugsCache` → `drug_product_id=null` eski stok kalemleri fallback olarak listeye eklendi (`_legacy: true`)
- `add_drug_administration` trigger (`trg_drug_administration_stok`) kaldırıldı (eski `drugs.stock_item_id` kullanıyordu)
- `add_drug_administration` RPC yeniden yazıldı (stok düşümünü kendi yapıyor)
- Legacy ilaçlarda `drug_product_id: null` gönderilmesi sağlandı (FK hatası giderildi)
- DB_VER 12→13 yükseltildi (IDB store upgrade tetiklendi)
- `drug_classes` ve `drug_products` tabloları için RLS policy eklendi (SELECT + INSERT)

### Tedavi UI
- İlaç ekleme formu: free text → **gruplu checkbox sistemi** (Seçenek A)
  - Grup başlıkları altında alfabetik listeleme
  - Çoklu seçim, her seçili için doz/birim/yol satırı
  - Tek "Kaydet" ile toplu ekleme
- Tedavi günü ekleme: tek tarih → **çoklu tarih seçici takvim**
  - Ay navigasyonu, tıklayarak toggle, seçili günler listesi
  - Birden fazla gün tek seferde eklenebilir
- Aynı tarihe birden fazla gün: **1A, 1B, 1C** numaralama sistemi
- Gün silme butonu (🗑 Gün) — stok hareketini geri alır
- İlaç düzenleme butonu (✏️) — inline form, doz/birim/yol güncellemesi
- `update_drug_administration` + `delete_treatment_day` RPC eklendi
- Stok hareket listesinde tarih/saat + renk kodlama (+ yeşil, - kırmızı)

### Stok Modülü
- Yeni ilaç ekleme: etken madde dropdown `drug_classes`'tan doluyor
- `drug_products`'a INSERT RLS policy eklendi
- `drug_classes`'a INSERT RLS policy eklendi
- Amfenikol drug_class eksikliği not edildi (Florkem için)

---

## 4. YAPILMASI PLANLANAN İŞLER

### Acil / Kısa Vadeli
- [ ] **İlaç kartı modülü** — hayvan kartı gibi ilaç detay/düzenleme sayfası
  - drug_products listesi, düzenleme, drug_class değiştirme
  - Stok bağlantısı UI'dan kurulabilmeli
- [ ] **Stok paneli gruplandırma** — checkbox veya padok benzeri filtre sistemi
- [ ] **Manuel etken madde girişi** — drug_classes'ta olmayanlar için free text + DB'ye kayıt
- [ ] **Amfenikol drug_class eklenmesi** (Florkem için)
- [ ] **`renderCasesForAnimal` debug div kaldırılması** (dbg-hint geçici kod)
- [ ] **Debug alert'lerin temizlenmesi** (index.html'deki setTimeout debug bloğu)

### Orta Vadeli
- [ ] **Auth sistemi** — kullanıcı girişi, kim ne yaptı izleme
  - `stok_hareket.hekim_id`, `drug_administrations.hekim_id`
  - Supabase Auth entegrasyonu
- [ ] **VAC-01: Aşılama modülü**
  - `vaccines` tablosu, protokol, otomatik görev üretimi
  - `vaccination_records` tablosu
- [ ] **`geri_al` RPC yeniden tasarım** — snapshot formatı: `olusturulan/guncellenen/silinen`
- [ ] **Supabase Realtime** — setInterval kaldır, push-based sync
- [ ] **Görev → Tedavi bağlantısı** — tedavi görevi tamamlanınca vaka güncellenir

### Uzun Vadeli / Mimari
- [ ] **Migration drift çözümü** — 013-014 repo'ya eklenmeli, ground truth migration
- [ ] **Orphan tablo temizliği** — `hastalik_log`, `tedavi`, `drugs.stock_item_id` (mig-023)
- [ ] **Toplu işlem paneli** — sürü seç → toplu ilaç/aşı/görev
- [ ] **Raporlama** — irk dağılımı, hastalık kategorileri, stok analizi (alt yapı hazır)
- [ ] **Yem modülü** (placeholder hazır)
- [ ] **Ekipman modülü**

---

## 5. BİLİNEN SORUNLAR

| Sorun | Önem | Durum |
|-------|------|-------|
| Debug alert'ler index.html'de | 🟡 | Temizlenmedi |
| dbg-hint debug div ui.js'de | 🟡 | Temizlenmedi |
| `link_drug_to_stock` RPC gereksiz | 🟡 | Kaldırılmadı |
| Ayarlar menüsündeki drug-stok bağlantı UI eski mimari | 🟡 | Kaldırılmadı |
| Migration 013-014 repo'da yok | 🟠 | Drift devam ediyor |
| `kizginlik_log` anon INSERT policy yok | 🔴 | Migration ile eklenecek |
| Üreme sekmesi yazı rengi koyu — dark bg'da zor okunuyor | 🟡 | CSS fix bekliyor |
| `kizginlik_log` anon INSERT policy yok | 🔴 | Migration ile eklenecek |
| Üreme sekmesi yazı rengi koyu — dark bg'da zor okunuyor | 🟡 | CSS fix bekliyor |
| `stok_hareket` hekim takibi yok | 🟡 | Auth bekliyor |

---

## 6. DEĞİŞMEZ KARARLAR

1. **DB-centric:** İş mantığı RPC'lerde, frontend sadece render/input
2. **Stok ledger immutable:** `stok_hareket` asla silinmez/iptal edilmez, düzeltme yeni INSERT
3. **Controlled entities:** hastalık, ilaç, hayvan asla free text (dropdown zorunlu)
4. **Framework yok:** Vanilla JS, bundle yok, build step yok
5. **Migration idempotent:** `DROP IF EXISTS + CREATE OR REPLACE`
6. **`await renderFromLocal()`** kritik işlem sonrası, `renderSafe()` background için
7. **`node --check`** her commit öncesi

---

## 7. PROJE KONFİGÜRASYON
Supabase : https://zqnexqbdfvbhlxzelzju.supabase.co
Live     : https://meliksahtokur.github.io/egesut-erp1/
Repo     : github.com/Meliksahtokur/egesut-erp1
IDB      : egesut_v12 (DB_VER=13)
