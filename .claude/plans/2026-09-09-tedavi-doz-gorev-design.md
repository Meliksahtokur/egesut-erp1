# Tasarım: Tedavi Dozajlama Helperi + Görevler Saat→Grup→Küpe Listesi

Tarih: 2026-09-09
Branch: `idle/tedavi-doz-gorev` (worktree: `/home/melik/egesut-wt/tedavi-doz-gorev`)
Durum: Tasarım kullanıcı onaylı (Bölüm A koşullu onay: hint butonu tıkla-doldur; B tam onay)
Kapsam: 2 UI/veri özelliği + 1 seed-data çalışması. Implementasyon bu spec'ten ayrı planla yapılır.

---

## 1. Amaç

1. **Dozajlama helperi:** Tedavi/uygulama akışlarında doz girişinin boş tahminle değil,
   ilaç kartına yazılmış standart doz × hayvanın canlı ağırlığı üzerinden hesaplanmış
   öneriyle yapılması. Kural: **asla otomatik doldurma yok** — kullanıcı ufak 💡 butonuna
   tıklayınca doz kutusu doldurulur.
2. **Görevler listesi:** Görevler sekmesinde 3 katmanlı gruplama — **uygulama saati →
   hayvan grubu → küpe numarası (doğal sıra)** — ve arama kutusunun DOM hilesinden
   çıkıp veri katmanında, içerik (semantik) araması yapması.
3. **Seed data:** Mevcut ilaç/aşı kartlarının standart dozlarının web araştırmasıyla
   tespit edilip tek migration ile girilmesi. Sonraki ilaçları kullanıcı stok ekleme
   formundan elle girer.

## 2. Mevcut durum (keşif, 2026-09-09)

- Doz **hesaplama** kodda yok; doz her yerde elle girilen düz sayı.
  Veri hazır ama kullanılmıyor: `hayvanlar.canli_agirlik` (hayvan kartında),
  `drug_products.concentration` + `concentration_unit` ("100mg/ml" — hiçbir hesapta yok).
- Doz girilen 4 canlı giriş noktası:
  | Nokta | Kod | Doz input | İlaç kimliği | Hayvan kimliği |
  |---|---|---|---|---|
  | Toplu vaka seans satırı | `js/forms.js:_bcSeansDozSatiri` (~1937) | `bc-sdoz-<id>` | checkbox `data-id` (drugs cache) | `bc-hid` chip listesi (çoklu!) |
  | Vaka detayı seans ekleme + şablon seans formu | `js/ui.js:cdfChkChange` (6474, ortak) | `.cdf-dose-inp[data-drug-id]` | `data-drug-id` | vaka hayvanı (`_curCase`); **şablon builder'da hayvan yok** |
  | Seans düzenleme (inline) | `js/ui.js:seansDuzenleAc` (8988) | `sd-dose-<seansId>` | seans kaydındaki ilaç | `_seansAddCtx` vaka hayvanı |
  | Hızlı uygulama (protokol mini + görev stok tamamla) | `js/ui.js:_gorevStokTamamlaSubmit` (5494), `_protokolUygulaKaydet` (1678) | `pu-doz` | `pu-stok` select | görevin `hayvan_id` |
- Eski `tedavi_ekle` yolu (`js/forms.js:hstIlacEkle`) ölü kod — bu iş kapsamı dışı.
- Görevler sekmesi: `js/ui.js:loadTasks` (602–771). Arama `#task-srch` → `taskSrch()`
  (ui.js:8701) **client-side DOM filtresi**: yalnız o an render edilmiş ≤200 kartın
  `.tc-id` metninde arar; seans kartları ve alt görevler kapsam dışı; her
  `loadTasks` çağrısında input temizlenir.
- `hayvanlar.grup` canlı değerleri: `Süt İçen Buzağı`, `Sütten Kesilmiş Buzağı`,
  `Düve (Küçük)`, `Düve (Büyük)`, `Besi`, `Sağmal (Laktasyonda)`, `Sağmal (Kuru)`.
- İlaca veri zinciri: `stok.drug_product_id` → `drug_products` (kolon adı
  **`brand_name`**; `concentration`/`concentration_unit` canlıda **tamamen boş** —
  seed dolduracak; tek bozuk değer: Gastren Duo 600/"600", temizlenecek).
  Seans kalemleri `drug_administrations.drug_product_id` FK taşır.
- Aşılar `drug_products`'ta DEĞİL: aşı kartı `vaccines` tablosu, doz alanı
  `vaccines.dose` zaten mevcut (`js/forms.js:3092` `stdDoz=vax?.dose`).
  Aşı seed'i bu alana `UPDATE` olarak girer — yeni kolon/RPC yok.
- Görevlerin saat verisi: `gorev_log.hedef_saat` (nullable) + TEDAVI_SEANS'ta
  `aciklama` JSON `planned_time`. Mevcut sıralama zaten saat kullanıyor
  (ui.js:679–684) ama **gruplama** yok — liste düz akış.

## 3. Özellik 1 — Dozajlama Helperi

### 3.1 Veri modeli (tek migration)

```sql
ALTER TABLE public.drug_products
  ADD COLUMN IF NOT EXISTS std_dose numeric,
  ADD COLUMN IF NOT EXISTS std_dose_unit text
    CHECK (std_dose_unit IN ('ml/kg','mg/kg','ml/hayvan')) OR std_dose_unit IS NULL;
COMMENT ON COLUMN drug_products.std_dose      IS 'Sığırda standart doz değeri';
COMMENT ON COLUMN drug_products.std_dose_unit IS 'ml/kg (hacim-ağırlık) | mg/kg (etken, konsantrasyonla çevrilir) | ml/hayvan (sabit)';
```

- Üçüncü tip `ml/hayvan` gerekli: hormonlar (Dalmazin 2 ml, ovarelin 2 ml,
  PGs 2 ml, Calcio Ph 250 ml…) ve aşıların prospektüs dozu sabittir.
- Seed aynı migration'da iki blok:
  1. `drug_products` UPDATE (isim-match `LOWER(btrim(brand_name))`; canlı
     isimler §5 tablosundaki gibidir — örn. `Tatrasiklin (ceva)` yazımıyla) —
     `std_dose`, `std_dose_unit` ve **mg/kg ürünleri için `concentration` +
     `concentration_unit`** (canlıda boş!) set edilir.
  2. `vaccines.dose` UPDATE (aşılar; mevcut alan, şema değişikliği yok).
  **PROD deploy ayrı onay kapısı.**
- Stok/ilaç ekleme formu (`index.html:sa-konst` çevresi) + `submitStokAdd`
  (`js/forms.js:3544`): `Standart Doz` (number, opsiyonel) + birim select
  (`ml/kg` / `mg/kg` / `ml/hayvan`) alanları eklenir; `ilac_ekle` atomik RPC
  imzası genişletilir.

### 3.2 Hesap motoru (frontend, saf fonksiyon — `js/utils/helpers.js`)

```
dozOner(canliAgirlik, kart) →
  kart.std_dose yok                        → { ok:false, neden:'kartta standart doz yok' }
  ml/kg | mg/kg: canliAgirlik yok/0        → { ok:false, neden:'hayvanın canlı ağırlığı yok' }
  ml/kg:      doz = canliAgirlik × std_dose                          → aciklama:'650 kg × 2 ml/kg = 13 ml'
  mg/kg:  kart.concentration yok           → { ok:false, neden:'konsantrasyon girilmemiş' }
          doz = canliAgirlik × std_dose ÷ concentration(mg/ml)       → aciklama:'650 kg × 2 mg/kg ÷ 100 mg/ml = 13 ml'
  ml/hayvan: doz = std_dose (ağırlıksız)                             → aciklama:'sabit doz: 2 ml'
  ortak:  → { ok:true, doz, birim: kart.default_unit||'ml', aciklama }
```

- Yuvarlama: 1 ondalık (`Math.round(x*10)/10`); sonuç ≤0 ise `ok:false`.
- Birim: `mg/kg` çeviriminde her zaman `ml`; `ml/kg` ve `ml/hayvan`'da kartın
  `default_unit`'i.
- RPC sözleşmeleri **değişmiyor** — hesap yalnızca form ön-dolumu.

### 3.3 UI: 💡 hint butonu (kullanıcı kuralı: tıkla-doldur, asla otomatik)

Her doz satırında doz input'unun sağında ufak `💡` butonu (title="Dozaj önerisi:

<ağırlık> kg × <doz>"):
- **Tıklama:** hesap `ok` ise doz input'una yazılır + kısa inline bilgi/toast:
  `💡 650 kg × 2 ml/kg = 13 ml`. Input'a elle değer yazılmışsa **dokunulmaz** —
  buton yalnızca tıklanınca üzerine yazar (kullanıcının tek onay tıklaması).
- `ok:false` ise buton tıklanınca neden toast'u gösterir (buton render edilir ama
  pasif bilgi taşır) veya hesap imkânsızsa hiç render edilmez — uygulama tercihi:
  **neden'i gösterecek şekilde render edilir** (kullanıcı "neden öneri yok" sorusunu
  butondan alır).
- Butonlar mevcut satır üreticilerine (§2 tablosu) tek satır HTML helper'ıyla
  eklenir; tıklama mevcut yeni-kod deseniyle bağlanır (inline `onclick` yerine
  dataset/`data-action` — kod-temizlik dersi: onclick inline ölür).
- Hayvan bağlamı olmayan yerlerde (şablon builder seans formu, ui.js:4488) buton
  **render edilmez** (ağırlık bilinemez).
- Toplu vakada referans ağırlık = seçili hayvanlardan **en büyük canlı ağırlık**
  (mevcut `vaka_toplu_ac` sözleşmesi kalem başına tek `dose` taşıyor; hayvan-başına
  doz ayrı faz). Açıklamada referans açık yazılır: `💡 en ağır: 650 kg × 2 ml/kg = 13 ml`.

### 3.4 Kapsam (4 nokta)

| # | Nokta | Buton yeri | Ağırlık kaynağı |
|---|---|---|---|
| 1 | Toplu vaka seans satırı `_bcSeansDozSatiri` | `bc-sdoz-<id>` yanı | `bc-hid` chip hayvanları, max |
| 2 | Vaka detayı seans ekleme `cdfChkChange` | `.cdf-dose-inp` yanı | vaka hayvanı |
| 3 | Seans düzenleme `seansDuzenleAc` | `sd-dose-<id>` yanı | vaka hayvanı |
| 4 | Hızlı uygulama (`pu-doz` iki modal) | doz input yanı | görev `hayvan_id` |

Ertelenen: tohumlama "Ek Uygulamalar" (`ek-doz`) — 2. faz.

### 3.5 Test planı

- Unit (tests/unit, saf fonksiyon): ml/kg yolu; mg/kg+konsantrasyon yolu;
  std_dose yok; ağırlık yok/0; konsantrasyon yok; yuvarlama; ≤0 korumaları.
- Mevcut 448+ unit süitesi yeşil kalır; form testleri (bulk-case) dokunulmaz
  davranışla (elle girilen doz) regresyonsuz.

## 4. Özellik 2 — Görevler: Saat → Grup → Küpe

### 4.1 Gruplama algoritması (açık görevler; Bugün/Geciken/Bekleyen ortak kural)

```
hedef_tarih ASC (mevcut dış sıra)
  └─ saat grubu ASC  ("09:00" < "13:00"; saatsizler EN SONDA, ayracı "⏰ Saatsiz")
       └─ hayvan grubu: sabit config sırası (aşağıda)
            └─ küpe DOĞAL SIRA ASC (sayısal: 002 < 01 < 19 < 2044)
```

- Saat kaynağı: `hedef_saat` → yoksa TEDAVI_SEANS `aciklama` JSON `planned_time`.
- Sabit grup sırası (`js/config.js` yeni sabit `GOREV_GRUP_SIRA` — kolayca
  değiştirilebilir): `Süt İçen Buzağı → Sütten Kesilmiş Buzağı → Düve (Küçük) →
  Düve (Büyük) → Besi → Sağmal (Laktasyonda) → Sağmal (Kuru) → (grubsuz hayvan) →
  📋 Genel (hayvansız görevler)`.
- Grup ayraçları: saat bloğu başlığı `⏰ 09:00 · N görev`; altında grup başlığı
  `🐄 <grup> · N`; içinde görev kartları (mevcut `renderTask` kartı yerinde kalır).
- TEDAVI_SEANS hayvan-ayracı (`renderSeansGrupAyrac`) yeni hiyerarşinin küpe
  katmanına yerleşir; alt görev kartları ana kartının olduğu grupta (mevcut davranış:
  ana kart içinde liste).
- Geciken/Bekleyen: aynı kural, üstte gün ayracı (`── 📅 Cuma, 11 Eylül ──`).
- Doğal sıra helper'ı (saf, tests/unit): alfanümerik split karşılaştırma;
  `"002"→2, "19"→19, "2044"→2044`; sayısal eşitlikte string fallback; kirli
  küpeler (`"Test buzağı"`, `"xx"`) sayısal olmayan blokta alfabetik sonda.

### 4.2 Semantik (içerik) araması — `#task-srch` güçlendirme

- `taskSrch()` DOM gizle/göster yerine **veri katmanı filtresi**: `loadTasks`
  render'ından ÖNCE predicate uygulanır.
- Arama alanları: `kupe_no`, `devlet_kupe`, hayvan adı alanları, `aciklama`
  (TEDAVI_GUN JSON label dahil), `gorev_tipi`, ilaç adı (mevcut `_stokAdi`/
  drug haritası), teşhis adı (`_dayDiseaseMap`). Tümü lowercase `includes`.
- Arama aktifken kart limiti kalkar (IDB'de zaten tüm `gorev_log` çekiliyor);
  arama boşsa mevcut 200/150 limitleri korunur.
- Seans kartları ve alt görev kartları da korpusa girer (ilgili üst kartla).
- Arama metni sekme/filtre/kategori geçişlerinde **korunur** (ui.js:617–618
  temizlemesi kaldırılır); yalnız ✕ ile temizlenir.
- Eşleşen metin kart üzerinde `<mark>` ile vurgulanır (küçük dokunuş).

## 5. Seed Data — Mevcut ilaçların standart dozları

Kaynak: web araştırması (3 paralel ajan, prospektüs/üretici/Vet-KMK öncelikli,
her satıra kaynak URL). Aşağıdaki tablo araştırma tamamlanınca nihai değerlerle
dolduruldu; migration'a isim-match `UPDATE` olarak girer. Bulunamayanlar boş
bırakılır (hesap o kartlarda sessizce devre dışı — buton "kartta standart doz yok"
der). Sperma kalemleri kapsam dışı (doz = 1 adet). Sonraki ilaçları kullanıcı elle girer.

<!-- SEED_TABLO_BASLANGIC -->

### 5.1 drug_products seed'i (`std_dose` + `std_dose_unit` + mg/kg'lar için `concentration`)

Kaynaklar: üretici prospektüsleri (VETAŞ, MSD TR, Ceva TR, Alke, Vilsan, Bavet, ARMA,
Teknovet, Bioveta, Zoetis, Microsules) + VetRehberi/Vetilac + KÜB PDF'leri. 3 ajan,
2026-09-09. **TAHMİN** = kaynak aralığın orta değeri, kullanıcı teyit etsin;
aralık notları açıklamada kalır. Eşleşme anahtarı canlı `brand_name` (birebir,
yazım hataları dahil).

| brand_name (canlı) | etken madde | std_dose | unit | conc (mg/ml) | yol notu | kaynak |
|---|---|---|---|---|---|---|
| Ketojezik | ketoprofen | 3 | mg/kg | 100 | IM + yavaş IV; ~3 gün | [vetrehberi](https://vetrehberi.com/ketojezik/) |
| Fulimed | fluniksin meglumin | 2 | mg/kg | 50 | IV/IM; 1–3 gün | [alkenet](https://alkenet.com/fulimed) |
| Flunixin (alke) | fluniksin (= Fulimed, tek ürün) | 2 | mg/kg | 50 | IV/IM | [alkenet](https://alkenet.com/fulimed) |
| Gentavilin | gentamisin 50 mg/ml | 2 | mg/kg | 50 | IM/IV; **2×/gün**; 3–7 gün | [vilsan](https://vilsan.com.tr/tr/product/gentavilin) |
| Pigenta (pifarma) | **gentamisin 100 mg/ml (antibiyotik!)** | 4 | mg/kg | 100 | IM; ilk gün bölünür, 3–5 gün | [vetrehberi](https://vetrehberi.com/pigenta/) |
| Enrolen | enrofloksasin 100 mg/ml | 2.5 | mg/kg | 100 | SC/IM/IV; 3 gün | [alkenet](https://alkenet.com/enrolen-10) |
| Florkem | florfenikol 300 mg/ml | 20 | mg/kg | 300 | IM (48 sa sonra 1 tekrar); SC: 40 mg/kg tek | [vetrehberi](https://vetrehberi.com/florkem/) |
| Florkem (ceva) | florfenikol (aynı ürün) | 20 | mg/kg | 300 | IM | [ceva](https://tr.ruminant.ceva.com/products/florkem/) |
| Marbox | marbofloksasin 100 mg/ml | 2 | mg/kg | 100 | SC/IM/IV; 3 gün (alt: tek IM 8 mg/kg) | [vetrehberi](https://vetrehberi.com/marbox/) |
| Sefanel | ceftiofur HCl 50 mg/ml | 1 | mg/kg | 50 | IM/SC (IV yasak); 3 gün | [vetrehberi](https://vetrehberi.com/sefanel/) |
| Makrovil | tilmikosin 300 mg/ml | 10 | mg/kg | 300 | **yalnız SC; tek doz** | [vetrehberi](https://vetrehberi.com/makrovil/) |
| Meloksikam ( bavet ) | meloksikam 5 mg/ml | 0.5 | mg/kg | 5 | SC/IV; tek doz | [bavet](https://www.bavet.com.tr/urunler/hayvan-sagligi/pet/bavet-meloksikam-enjeksiyonluk-cozelti/) |
| Klavil (vilsan) | amoksisilin 140+klav 35 mg/ml | 8.75 (=1 ml/20 kg) | mg/kg | 175 | IM/SC (IV yasak); 3–5 gün | [vetrehberi](https://vetrehberi.com/klavil/) |
| Halocur (MSD) | halofuginon 0.5 mg/ml | 0.2 (=2 ml/10 kg/gün) | ml/kg | 0.5 | PO; 7 gün; yalnız buzağı kriptosporidiozis | [MSD TR](https://www.msd-hayvan-sagligi.com/downloads/halocur/) |
| Ademin ( ceva ) | A 500k IU + D3 75k IU + E 50 mg/ml | 0.02 (=1 ml/50 kg) | ml/kg | — | derin IM (boyun); tek doz | [vetrehberi](https://vetrehberi.com/ademin/) |
| Oksitosin yerli | oksitosin 10 IU/ml | 2 (aralık 1–4; **TAHMİN** orta) | ml/hayvan | — | derin IM; mastitis protokolü farklı | [VETAŞ PDF](https://vetas.com.tr/assets/urunler/kt/vetas-oksitosin-10-iu-enjeksiyonluk-cozelti.pdf) |
| Dalmazin ( fatro ) | **d-kloprostenol 75 µg/ml** (sedatif değil!) | 2 | ml/hayvan | — | IM (IV yasak); endikasyona göre tekrar | [vetrehberi](https://vetrehberi.com/dalmazin/) |
| ovarelin (ceva) | gonadorelin 50 µg/ml | 2 | ml/hayvan | — | IM/IV; tohumlama anı/6 sa önce | [vetrehberi](https://vetrehberi.com/ovarelin/) |
| PGs (alke) | kloprostenol (D+L) 250 µg/ml | 2 | ml/hayvan | — | yalnız IM; senkron 11 gün arayla 2 doz | [alkenet](https://alkenet.com/pgs) |
| Buserin (alke) | buserelin 4 µg/ml | 2.5 (tohumlama; kist 5) | ml/hayvan | — | IM; senkron protokolü G0/G9 | [vetrehberi](https://vetrehberi.com/buserin/) |
| Kalsiyum ( vilsan ) | Ca-Mg-P kompleksi | 100 (200–500 kg → 80–100) | ml/hayvan | — | **IV yavaş** öncelikli; IM/SC bölerek | [vetrehberi](https://vetrehberi.com/kalsimin/) |
| Calcio Ph ( fatro ) | Ca-glukonat + P + Mg | 250 | ml/hayvan | — | IV/SC/IM yavaş; tekrar hekim kararlı | [vetrehberi](https://vetrehberi.com/calcio-ph/) |
| Vetakort / kortikosteroid | deksametazon 2 mg/ml | 0.03 (=3 ml/100 kg) | ml/kg | 2 | IM; 24–48 sa tekrar olabilir; ketozis endikasyonu | [vetrehberi](https://vetrehberi.com/vetakort-2mg/) |
| CAROFERTIN-E ( alivira ) | beta-karoten 15 + E vit 20 mg/ml | 0.05 (3.5–7/100 kg; **TAHMİN** orta) | ml/kg | — | IM/SC; doğum+30 g tek, +60–70 tekrar | [vetrehberi](https://vetrehberi.com/carofertin-e/) |
| K vitamin (alke) | fitomenadion (K1) 10 mg/ml | 0.15 (0.05–0.25 ml/kg; **TAHMİN** orta) | ml/kg | 10 | IM/SC; rodentisit zehirlenmesi | [alkenet](https://alkenet.com/hemadur-k) |
| Teknovet - B12 (fosforlu) | butafosfan 100 + B12 0.05 mg/ml | 15 (5–25; **TAHMİN** orta) | ml/hayvan | — | sığırda IV (IM/SC da); dana 5–12 | [teknovet](https://www.teknovet.com.tr/tr/urunler/vitamin%2C-mineral-ve-elektrolitler/teknosol-b12) |

### 5.2 vaccines seed'i (`vaccines.dose` — mevcut alan, ml/hayvan)

| aşı (canlı ad) | fiili ticari ürün | dose (ml) | yol/rapel notu | kaynak |
|---|---|---|---|---|
| Rotavirus Aşısı | Rotavec Corona (MSD) — **gebe anneye**, buzağılamadan 12–3 hafta önce | 2 | IM; her gebelikte | [MSD TR](https://www.msd-hayvan-sagligi.com/downloads/rotovec-corona/) |
| E. coli Aşısı | Rotavec Corona kombine — **gebe anneye** | 2 | IM | [MSD TR](https://www.msd-hayvan-sagligi.com/downloads/rotovec-corona/) |
| Coronavirus Aşısı | Rotavec Corona kombine — **gebe anneye** | 2 | IM | [MSD TR](https://www.msd-hayvan-sagligi.com/downloads/rotovec-corona/) |
| Şarbon Aşısı | Basilax (Vetal, canlı) | 1 (buzağı 0.5) | SC; yıllık tekrar | [Vetal](https://www.vetal.com.tr/urun/basilax) |
| BVD Aşısı | Bovilis BVD (MSD) | 2 | IM; 2 doz 4 hafta ara + yıllık | [MSD TR](https://www.msd-hayvan-sagligi.com/downloads/bovilis-bvd/) |
| IBR Aşısı | Bovilis IBR Marker (MSD) | 2 | IM; 2 doz + yıllık (Live: IN) | [MSD TR](https://www.msd-hayvan-sagligi.com/downloads/bovilis-ibr-marker-inac/) |
| Leptospirosis Aşısı | BioBos L(6) (Bioveta) | 2 | SC; 2 doz + yıllık | [Bioveta](https://www.bioveta.cz/tr/urunlerimiz/hayvan-sagligi/biobos-l-6-sgrlar-icin-enjeksiyon-suspansiyonu.html) |
| BRSV Aşısı | Bovipast RSP (MSD) | 5 | SC; 2 doz 4 hafta ara | [MSD TR](https://www.msd-hayvan-sagligi.com/downloads/bovilis-bovipast-rsp/) |
| Clostridium Aşısı | UltraChoice 8 (Zoetis) | 2 | SC; 2 doz + yıllık | [vetrehberi](https://vetrehberi.com/ultrachoice-8/) |
| Coglavax (ceva) | **klostridial polivalan** (koronavirüs DEĞİL) | 2 (buzağı/≤100 kg; ergin 4) | SC; 2 doz 4 hafta ara + yıllık | [vetrehberi](https://vetrehberi.com/coglavax/) |
| Vac-Sules Feedlot | BRD kompleksi (Microsules) | 5 | SC; 2 doz 28–30 gün ara | [Microsules](https://www.laboratoriosmicrosules.com/producto/vac-sules-feedlot/) |

### 5.3 Boş bırakılanlar (hesap devre dışı — kullanıcı kartına elle girer)

| kayıt | neden |
|---|---|
| Yeldif ( ceva ) | doz yaş/aşılık-bağımlı (buzağı 0.5–2 / gebe inek 6–8) — tek değerle temsil edilemez; etkeni Se+E+B1 (A-D-E-C değil) |
| Vitamino | ruhsatlı ilaç değil (takviye); doz yalnız buzağı 5–10 ml oral bulundu — TAHMİN |
| Antepsin | beşeri ürün, off-label; doz 4–15 g PO (AU farmakoloji) — birim gr, hesap dışı |
| Kara merhem | topikal ihtiyol pomad; lezyona 3–5 g — hesap dışı |
| Gastren Duo (humanis) | sığır dozu BULUNAMADI (beşeri antasit); bozuk conc değeri (600/"600") migration'da NULL'a çekilir |
| Devamisin | **klortetrasiklin 500 mg TABLET** (oral buzağı 10–20 mg/kg / uterus içi) — birim adet, hesap dışı |
| Tatrasiklin (ceva) | Tetramisin 30 TAHMİNİ; konsantrasyon KÜB'den teyit edilmedi — kullanıcı kararına bırakıldı |
| Piogen Aşısı | ruhsatlı ticari ürün yok — otovaksin (çiftlik özaşı), sabit doz yok |

### 5.4 Kimlik düzeltmeleri (kullanıcıya bilgi)

1. **Fulimed = Flunixin (alke)** — aynı Alke ürünü; iki stok kalemi de aynı karta bağlanır.
2. **Pigenta (pifarma) gentamisin antibiyotiktir** — uterus ürünü varsayımı yanlıştı.
3. **Dalmazin (fatro) d-kloprostenol'dür (PGF2α)** — sedatif varsayımı yanlıştı.
4. **Coglavax klostridial polivalan aşıdır** — "koronavirüs aşısı" varsayımı yanlıştı
   (koronavirüs maternal koruması Rotavec Corona ile).
5. **Devamisin klortetrasiklin tabletidir** — "uzun etkili oksitetrasiklin" değil.
6. Eksik alt bilgiler (Sefanel/Meloksikam bekleme süreleri vb.) Titck KÜB/KT'den
   tamamlanabilir — seed'i bloklamaz (bekleme süresi alanı bu iş kapsamı dışı).

<!-- SEED_TABLO_BITIS -->

## 6. Riskler / açık konular

- **'Meme içi' CHECK boşluğu:** DB tarafında `drug_administrations.route`,
  `treatment_day_uygulamalar.route`, `tedavi_sablonu_kalem.route` CHECK listelerinde
  'Meme içi' yok (88b311b yalnız frontend'e ekledi). Dozaj işi DB migration'ı
  açarken bu CHECK'lerin genişletilmesi **ayrı bir madde olarak önerilir** —
  canlı doğrulama sonrası aynı ya da ayrı migration.
- Toplu vakada hayvan-başına doz yok (tek doz/kalem sözleşmesi) — V1 bilinçli sınır.
- `drugs` legacy tablosu ile `drug_products` ikiliği: std_dose yalnız
  `drug_products`'ta yaşar; `_drugsCache` join'i drug_product alanlarını da
  taşımalı (uygulamada cache üretimine 3 alan eklenir).
- Kirli test küpeleri (`Test buzağı`, `xx`) doğal sırada sonda — davranış testle kilitlenir.

## 7. Fazlama (implementasyon önerisi)

- **F1:** DB migration (std_dose kolonları + seed) + stok formu alanları + `ilac_ekle` RPC.
- **F2:** Saf hesap fonksiyonu + unit testler + 4 giriş noktasına 💡 butonu.
- **F3:** Görev listesi 3 katmanlı gruplama + doğal sıra helper'ı + testler.
- **F4:** Semantik arama (veri katmanı) + arama korunumu + testler.
Her faz kendi unit süitesiyle kapanır; merge+push kullanıcı onayıyla.
