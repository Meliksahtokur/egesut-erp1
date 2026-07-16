# EgeSüt ERP

> Çalışan bir süt çiftliği için offline-toleranslı web tabanlı yönetim sistemi — sürü, üreme, klinik, eczane ve otomatik görev iş akışları tek bir uygulamada.

**Bu bir portföy projesi değil.** 157 hayvanlık bir süt çiftliği günlük operasyonunu bu sistemle yürütüyor. 16 Temmuz 2026 itibarıyla: 2.674 kayıtlı işlem, bunların 586'sı son 30 günde, son 90 günün 66'sında aktif kullanım.

**Bu şemanın nasıl görünmesi gerektiğine karar veren kişi, işi yapan veteriner.** Veri modelinin bu şekilde olmasının sebebi bu. İlaç kataloğu bir yazılımcının tahmin edeceği gibi değil, bir farmakoloğun gruplayacağı gibi gruplanmış — beta-laktamlar, makrolidler, florokinolonlar. Aşı motoru bir hayvanın bağışık olarak naive olup olmadığına aşı→hastalık grafiğini gezerek karar veriyor; çünkü "aynı hastalığı kapsayan iki farklı aşı" bir veri modelleme kararından önce klinik bir gerçek. Bu kuralları kimse bir analiz toplantısında derlemedi, derlemesi de gerekmedi.

Bu fark kendini özelliklerden çok korkuluklarda gösteriyor. `scripts/ground-truth-audit.sh` canlı veritabanını commit'lenmiş şemayla karşılaştırıyor, çünkü drift bir kez zaten yaşandı. Toplu onarım RPC'leri `p_dry_run` bayrağının arkasında duruyor ki deploy'da yıkıcı hiçbir şey çalışmasın. `20260710000001` migration'ı, aynı buga yazılan önceki üç fix'in neden geri geldiğini anlatarak açılıyor. Bunlar SQL yazmayı sevdiğin için kurduğun şeyler değil; verinin yanlış olmasının hesabını **veren kişi sen olduğunda** kurduğun şeyler.

Tek kişi tarafından, toplam yaklaşık dört aylık çalışma süresiyle yazıldı.

[![Live Demo](https://img.shields.io/badge/demo-live-4e9a2a?style=flat-square&logo=github&logoColor=white)](https://meliksahtokur.github.io/egesut-erp1/)
[![GitHub stars](https://img.shields.io/github/stars/Meliksahtokur/egesut-erp1?style=flat-square&logo=github)](https://github.com/Meliksahtokur/egesut-erp1/stargazers)
[![License](https://img.shields.io/badge/license-ISC-blue?style=flat-square)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/Meliksahtokur/egesut-erp1?style=flat-square&logo=git)](https://github.com/Meliksahtokur/egesut-erp1/commits/main)
[![Supabase](https://img.shields.io/badge/Supabase-PostgreSQL-3ECF8E?style=flat-square&logo=supabase&logoColor=white)](https://supabase.com)
[![Playwright](https://img.shields.io/badge/Playwright-E2E-2EAD33?style=flat-square&logo=playwright&logoColor=white)](https://playwright.dev)

**Canlı:** https://meliksahtokur.github.io/egesut-erp1/
**Backend:** Supabase (PostgreSQL)
**Repo:** github.com/Meliksahtokur/egesut-erp1

> 📘 English version: [`README.md`](README.md)

---

## Gerçekte ne çalışıyor

Aşağıdaki sayılar canlı veritabanından okundu, tahmin değil.

| | |
|---|---|
| Yönetilen hayvan | 157 |
| Üretilen ve takip edilen görev | 1.621 |
| Tohumlama kaydı | 258 |
| Doğum | 63 |
| Klinik vaka | 37 — 120 tedavi günü, 158 ilaç uygulaması |
| Stok ledger hareketi | 363 |
| Toplam loglanmış işlem | 2.674 |

Canlı veritabanı nesneleri: **48 tablo · 13 view · 180 fonksiyon · 35 trigger · 117 index**, **220 versiyonlu migration** üzerinden inşa edildi.

---

## Alan modeli

Bu projedeki mühendisliğin çoğu ekranlarda değil. Burada.

### İlaç bir metin alanı değil, dört katmanlı taksonomi

```
stok_kategorileri  (16)   Kategori            "Antimikrobiyaller (Antibiyotikler)"
   └── drug_classes (48)   Grup / Sınıf / Etken madde
                                               "Beta-Laktamlar" → Seftiofur
        └── drug_products (27)  Marka, konsantrasyon, uygulama yolu, birim
                                               "Sefanel", IM, ml
             └── stok (41)      Stok kalemi — raftaki fiziksel şişe
                  └── stok_hareket (363)  Append-only ledger
```

Her katman bir foreign key. Sistemde hiçbir yerde serbest metin ilaç adı yok — "bu yıl ne kadar seftiofur kullandık" sorusunun metin madenciliği değil, cevabı olmasının sebebi bu.

Kural UI'da değil, veritabanında zorlanıyor: `ilac_ekle()` `drug_class_id` boşsa exception fırlatıyor — *ilaç kataloglanmadan stoğa giremez.* Aynı çağrı stok kalemini, katalog ürününü ve audit kaydını tek transaction'da yazıyor.

### Klinik, döngüyü rafa geri kapatıyor

```
diseases (41)  ⇄  sablon_hastalik_eslem (11)  ⇄  tedavi_sablonu (3)
                                                    └── tedavi_sablonu_kalem (16)
                                                        gün · saat · doz · birim · yol
                                                        → drug_products → stok
```

Hastalığı seç, `tedavi_sablon_uygula(case_id, sablon_id)` çok günlük tedavi planını üretsin — her gün, her saat, her doz belirli bir ürüne ve belirli bir stok kalemine bağlı. Uygulama kaydedildiğinde stok düşümü ve ledger satırı **uygulamanın kendisiyle aynı transaction'da** yazılıyor (`add_drug_administration`); yani yazma sırasında ölen bir telefon, "ilaç verildi ama düşülmedi" durumunu bırakamıyor.

Hastalıklar şablonlara çoka-çok bağlanıyor, böylece bir protokol birden çok tanıya tekrar edilmeden hizmet ediyor.

### Aşılama protokol tabanlı ve hayvanın neyi gördüğünü biliyor

```
vaccines (12)          marka · etken madde · protokol tipi · zorunluluk · rapel aralığı
  ├── vaccine_diseases (17)        çoka-çok → diseases
  ├── vaccine_protocol_steps (14)  adım no · gün offset  (çok dozlu primer)
  └── vaccination_schedule (5)     hedef sınıf · zamanlama · sıra
       └── vaccination_log (378)
```

`add_vaccination()` "bu aşı daha önce yapıldı mı?" diye sormuyor — `vaccine_diseases` grafiği üzerinden, *daha önce yapılmış herhangi bir aşının* bu aşıyla ortak hedef hastalığı var mı diye soruyor. Yoksa hayvan naive'dir, primerin 2. doz offset'ini alır; varsa rapel aralığını alır. Takip görevi sonra otomatik üretiliyor, mükerrer kayda karşı korumalı.

### Görevleri veritabanı üretiyor ve kapatıyor

Bugüne kadar 1.621 görev, ve uygulama bunların hiçbirini yaratmadı. Trigger'lar yarattı:

| Olay | Trigger | Etki |
|---|---|---|
| Gebelik onaylandı | `trg_tohumlama_gebe_gorev` | Doğum öncesi protokol görevlerini üretir |
| Hayvan sürüden çıktı | `trg_hayvan_cikis_gorev_iptal` | Açık tüm görevlerini iptal eder |
| Başka padoğa geçti | `trg_padok_transfer_gorev` | Transfer görevini kapatır |
| Ana görev tamamlandı | `trg_gorev_parent_kapandi` | Alt görevlerini kapatır |
| Herhangi bir görev yazımı | `gorev_log_cycle_guard` | Görev döngüsü oluşmasını reddeder |

Tek başına doğum (`dogum_kaydet`) tek transaction'da 16 göreve açılıyor: postpartum ilaç protokolü (0. gün oksitosin/AD3E/kalsiyum, 2., 25. ve 39. günlerde PG — Presynch-14), 58. günde kızgınlık takibi, ve altı alt görevli bir "buzağı ilk gün bakımı" ana görevi — kolostrum, göbek dezenfeksiyonu, küpeleme.

Sistem kendini de denetliyor: `protokol_eksik_tara()` her hayvanı beklenen protokolüne karşı gezip **atlanmış**, geciken veya yaklaşan adımları raporluyor — görev logunu, uygulama logunu ve ilaç uygulamalarını birbirinden bağımsız kontrol ediyor, böylece hangi yoldan kaydedilmiş olursa olsun yapılmış adım yapılmış sayılıyor.

### Hiçbir şey hardcoded değil

| Tablo | Neyi ayarlanabilir kılıyor |
|---|---|
| `irk_esik` (7) | Irk bazında tohumlama ve sütten kesme gün eşikleri |
| `protokol_ayar` (9) | Protokol parametreleri, her biri `min_deger`/`max_deger` sınırlı |
| `diseases`, `drug_classes`, `drug_products`, `vaccines` | Tüm klinik sözlük |

Kataloglar uygulamadan, kullanıcı tarafından yönetiliyor — `disease_ekle/guncelle/sil`, `drug_class_ekle/guncelle/sil`, `drug_product_ekle`, `tedavi_sablon_kaydet`. Yeni bir etken madde, yeni bir hastalık veya yeni bir tedavi protokolü tanımlamak, veterinerin salı öğleden sonra yapacağı bir iş — destek talebi açıp sürüm beklemesi gereken bir şey değil.

---

## Teknik Stack

| Katman | Teknoloji |
|--------|-----------|
| Frontend | Vanilla JS, tek `index.html` — framework yok, derleme adımı yok, bundle yok |
| Backend | Supabase (PostgreSQL) — RPC + REST |
| Veri modeli | 48 tablo, 180 sunucu-tarafı fonksiyon, 35 trigger, RLS açık |
| Offline cache | IndexedDB (`egesut_v9`) — okumalar yerelden sunulur, çevrimiçiyken senkronize edilir |
| Hosting | GitHub Pages (statik frontend), Supabase (veritabanı) |
| Migration | 221 versiyonlu SQL dosyası, CI ile Supabase CLI üzerinden deploy |
| Test | Playwright E2E (3 runner'da sharded), `node:test` unit testleri |
| Kalite | SonarCloud statik analiz |

---

## Modüller ve Durum

| Modül | Durum | Açıklama |
|-------|-------|----------|
| **Sürü** | ✅ Canlıda | Hayvan kartı, kimlik bilgileri, grup/padok ataması, 157 hayvan arasında filtreleme, her hayvan için kronolojik zaman çizelgesi |
| **Üreme** | ✅ Canlıda | Kızgınlık tespiti → tohumlama → gebelik takibi → doğum → buzağı kaydı. Durum geçişleri DB trigger'ları ile korunur |
| **Klinik / Vaka** | ✅ Canlıda | Vaka açma, günlük tedavi seansları, kontrollü ilaç kataloğundan reçete, vaka kapatma. Tedavi şablonları ve geri alma desteği |
| **Stok / Eczane** | ✅ Canlıda | İlaç ve malzeme girişi, uygulamada otomatik stok düşümü, kritik stok uyarıları. Aşı ve sperma stoğu da takip edilir. Immutable ledger — düzeltmeler yeni hareket olarak girilir |
| **Görev** | ✅ Canlıda | Veritabanı tarafından otomatik üretilen görevler (aşı, takip, protokol adımları). Renk kodlu durum, tek tıkla tamamlama, denetim için immutable işlem logu |
| **Aşı** | ✅ Canlıda | İçerik-odaklı protokol yönetimi: aşılar, hedef hastalıklar, protokol adımları (primer + rapel), eşdeğer ürün ve çoklu doz desteği |
| **İstatistik** | ✅ Canlıda | Sürü özeti, üreme verimliliği (Düve/İnek ×3), sperma/PI endeksleri, hayvan bazında ve olay bazında zaman çizelgeleri |
| **AI Asistan** | ✅ Canlıda | Uygulama içi asistan — canlı şemaya karşı salt-okuma SQL çalıştırır, plan taslağı hazırlar, her yazma işlemi için insan onayı (HITL) bekler. Bugüne kadar 26 thread |
| **Demo-Mirror** | ✅ Canlıda | `postgres_fdw` köprüsü ile canlı verinin salt-okuma klonu, tek tıkla atomik klonlama, demo girişi, sürüklenme uyarısı |
| **Bildirimler** | ✅ Canlıda | Bekleyen uyarılar için birleşik gelen kutusu — yaklaşan görevler, düşük stok, açık vakalar |

---

## Mimari Prensipler

Bu kararların gerekçesi ve her birinin bedeli: [`DESIGN.md`](DESIGN.md)

- **İş mantığı DB'de** — frontend sadece render eder ve input toplar; hesap yapmaz, state machine işletmez, validasyon yapmaz. Mantık PostgreSQL'de yaşar (RPC + trigger + view).
- **Yazma RPC üzerinden** — uygulama kodu tabloya doğrudan yazmak yerine bir PostgreSQL fonksiyonu çağırır; validasyon, yetkilendirme ve yan etkiler sunucu tarafında tek noktada uygulanır. *(Bilinen bir istisna var: tohumlama modülünde RPC'yi bypass eden yazma yolları — "Bilinen sınırlar" bölümüne bakın.)*
- **Controlled entities** — hastalık, ilaç, hayvan asla free-text değil; FK + dropdown zorunlu, veri seti temiz ve raporlanabilir kalır.
- **Stok ledger immutable** — stok hareketleri append-only kaydedilir. Düzeltmeler yeni ledger satırı olarak girilir; hiçbir zaman düzenleme veya silme yapılmaz, denetim izi eksiksiz kalır. Güncel stok her zaman hesaplanır, saklanmaz. Burası kontrollü veteriner ilaçları tutan bir eczane; "kim, neyi, hangi hayvana, ne zaman verdi ve sonradan kayda dokunan oldu mu" sorusunun cevabını değiştirilebilir bir miktar kolonu yok eder.
- **Reel-time stok, fallback'li** — on tablo Supabase Realtime'a publish ediliyor; uygulama WebSocket üzerinden abone oluyor ve `postgres_changes` geldiğinde çekiyor. Bir telefonda ilaç uygula, diğerinde stok rakamı oynasın. Kanal hata verir veya zaman aşımına uğrarsa istemci 30 saniyelik polling'e düşüyor ve bunu söylüyor — sessizce bayatlamıyor.
- **Audit log yeniden yazılamaz** — `islem_log`'u `_islem_log_immutable_guard` koruyor; bir gelenek değil, bir trigger. Üç tablonun (`bildirim_log`, `hayvan_override`, `cop_kutusu`) RLS'i açık ve *hiç politikası yok*: bilinçli bir deny-all — hiçbir istemciden erişilemez, sadece `SECURITY DEFINER` RPC'lerle ulaşılır.
- **Migration'lar kök nedeni belgeler** — sadece şema farkı değiller. `20260710000001`, aynı buga yazılan önceki üç fix'in neden geri geldiğini anlatarak açılıyor, sonra beş katman savunma seriyor: otorite kolonu, yeniden hesaplama yolu, onarım RPC'si, düzeltilmiş üretici ve mevcut bozuk satırlar için bir bölücü — toplu onarım adımları `p_dry_run` guard'ının arkasında, deploy'da yıkıcı hiçbir şey çalışmasın diye.
- **Offline-toleranslı okuma** — okumalar IndexedDB'den sunulur ve bağlantı varken sunucuyla uzlaştırılır; sinyalin zayıf olduğu ahır ortamında uygulama kullanılabilir kalır. *(Uygulama kabuğunun kendisi yine de ağdan çekilir — "Bilinen sınırlar"a bakın.)*
- **Versiyonlu şema, CI ile deploy** — migration'lar `supabase/migrations/` altında yaşar ve her `main` merge'inde GitHub Actions ile production'a gönderilir. Kanonik şema `supabase/migrations/99999999999999_ground_truth.sql` ile yakalanır ve `scripts/ground-truth-audit.sh` ile canlı veritabanına karşı denetlenir.
- **Row Level Security** — 48 tablonun 47'sinde RLS açık. Asistan tabloları (`agent_threads`, `agent_messages`, `agent_plans`) `auth.uid()` ile gerçek kullanıcı-bazlı izolasyon uygular; mesajlar için üst thread üzerinden kapsayan korelasyonlu bir politika dahil. Üç tablo bilinçli olarak politikasız: RLS açık + politika yok = istemciden hiç erişilemez, sadece `SECURITY DEFINER` RPC'lerle ulaşılır.
- **Sıfır derleme adımı** — transpiler, bundle'layıcı veya deploy'da bağımlılık çözümü yok; statik dosyalar yazıldığı gibi gider, deploy yüzeyi küçük kalır.

---

## Bilinen sınırlar

Açıkça yazıyorum, çünkü hiçbir zayıflığı olmadığını iddia eden sistem kendisi hakkında dürüst değildir.

- **Bugün tek-tenant.** Çiftlik domaini tek kiracıyla çalışıyor ve RLS politikaları kiracı-kapsamlı değil, permissive (`USING(true)`) — 73 politikanın 69'u bilinçli olarak açık, çünkü ortada tek bir çiftlik var. `farm_id` kolon disiplini ve `current_farm_id()` yardımcısı zemin olarak hazır, ama **henüz hiçbir politika farm-kapsamlı değil.** Çoklu-çiftlik izolasyonu planlanan iş, teslim edilmiş iş değil.
- **Service worker yok.** Offline okumalar IndexedDB'den geliyor ama uygulama kabuğu ağdan çekiliyor — uygulama bağlantısız soğuk başlamıyor. Service worker bilinçli olarak kaldırıldı; kod eskiden kalanları aktif olarak unregister ediyor.
- **Tohumlama yazma yolları.** Üç yazma yolu var, ikisi diğer her şeyin geçtiği RPC katmanını bypass ediyor. Şimdilik UI guard'ları koruyor; `tohumlama_*` RPC'lerinde birleştirme sıradaki refactor.
- **Karens (ilaç kalıntı süresi) takibi henüz yok.** Sistem ilacı, dozu, hayvanı ve stok hareketini biliyor — ama o hayvanın sütünün veya etinin gıda zincirine ne zaman girebileceğini bilmiyor. Bir süt çiftliği için en göze batan eksik bu ve sıradaki özellik: şema ve türetme mantığı [`docs/drafts/`](docs/drafts/) altında taslak halinde duruyor, değerler prospektüsten girilene kadar bilerek migration dizininin dışında tutuluyor. Karens değerini tahmin etmek gıda güvenliği riskidir; o yüzden girilecek, çıkarsanmayacak.
- **Lot / son kullanma takibi yok.** Stok ürün bazında tutuluyor, parti bazında değil. Bir geri çağırma tarihle akıl yürütülerek ele alınmak zorunda kalır, lot numarasıyla izlenerek değil.
- **Süt verimi yok.** Bu bir sağlık, üreme ve eczane sistemi. Laktasyon eğrileri, sağım başına verim ve tank verisi modellenmiyor — çiftlik bunları başka yerde tutuyor.
- **Rasyon modülü yok.** Yem ve rasyon planlaması uygulanmadı. Planlanıyor, teslim edilmedi.
- **`drug_products.concentration` boş.** Kolon, kiloya göre doz hesabı için altyapı olarak duruyor (`hayvanlar.canli_agirlik` zaten kaydediliyor); özellik henüz yazılmadı.

---

## Kaynak Dosyalar

```
index.html                    — HTML + CSS + tüm modaller
js/
  config.js                   — GRUP_PADOK + sabitler
  state.js                    — AppState
  api.js                      — Supabase client, IDB sync, RPC wrapper
  app.js                      — Uygulama init + routing
  ui.js                       — Tüm render
  forms.js                    — Form submit + validasyon
  auth.js                     — Login gate, kayıt, şifre sıfırlama
  ai-asistan.js               — AI Asistan frontend
  demo.js                     — Demo-Mirror UI
  utils/
    helpers.js                — DOM, toast, autocomplete, debounce
    modal.js                  — openM/closeM/mClose
    errorHandler.js           — withErrorHandling
    handlers.js               — Global event handler'lar
    events.js                 — Event emitter
supabase/migrations/          — 221 migration dosyası (PostgreSQL)
scripts/                      — LSP, ground-truth-audit, sql-lsp daemon, vb.
tests/                        — Playwright E2E + node:test unit testleri
demo/                         — Demo-Mirror SQL (00_grants, 01_fdw, 02_klonla, 03_sema_diff)
```

## Veritabanı Özeti

```
hayvanlar (157)              — çekirdek; padok_id → padoklar, anne_id → hayvanlar (soy)
  ├── tohumlama (258)        — üreme olayları (per-cycle state machine)
  ├── dogum (63)             — doğum kayıtları
  ├── kizginlik_log (12)     — kızgınlık takibi
  ├── gorev_log (1621)       — görev sistemi (parent/child, döngü guard'ı, trigger üretimi)
  ├── protokol_instance (83) — hayvan başına işleyen protokol durumu
  ├── vaccination_log (378)  — → vaccines
  └── cases (37)             — klinik vakalar → diseases
        └── treatment_days (120) → drug_administrations (158) → drug_products → stok

İlaç taksonomisi
  stok_kategorileri (16) → drug_classes (48) → drug_products (27) → stok (41)
                           grup/sınıf/etken madde      marka/konsantrasyon/yol
       └── stok_hareket (363)  — ledger (immutable, append-only; stok hesaplanır, saklanmaz)

Tedavi şablonları
  tedavi_sablonu (3) ⇄ sablon_hastalik_eslem (11) ⇄ diseases (41)
       └── tedavi_sablonu_kalem (16)  — gün/saat/doz/yol → drug_products + stok

Aşılama
  vaccines (12) ⇄ vaccine_diseases (17) ⇄ diseases
       ├── vaccine_protocol_steps (14)  — çok dozlu primer takvimi
       └── vaccination_schedule (5)     — hedef sınıf + zamanlama

Konfigürasyon
  irk_esik (7)       — ırk bazında tohumlama / sütten kesme eşikleri
  protokol_ayar (9)  — protokol parametreleri, min/max sınırlı

islem_log                                     — immutable audit log (trigger korumalı)
agent_threads + agent_messages + agent_plans  — AI Asistan hafıza + plan motoru (kullanıcı-bazlı RLS)
prod_fdw                                      — Demo-Mirror FDW köprüsü
```

Tasarım gerekçesi: [`DESIGN.md`](DESIGN.md)
Mimari referans: [`ARCHITECTURE.md`](ARCHITECTURE.md)
`ground_truth` referans: [`supabase/migrations/99999999999999_ground_truth.sql`](supabase/migrations/99999999999999_ground_truth.sql)

---

## Başlarken

### Gereksinimler
- Bir Supabase projesi (veya Supabase runtime ile herhangi bir PostgreSQL 14+)
- Node.js 18+ (test suite için)
- Python 3 (opsiyonel lokal statik sunucu için)

### Uygulamayı yerel çalıştırma
Frontend düz statik dosyalardır — repo kökünü herhangi bir statik sunucuyla sunun:

```bash
python3 -m http.server 8080
# http://127.0.0.1:8080/ adresini açın
```

Kendi veritabanınıza bağlanmak için `js/config.js` dosyasındaki Supabase proje URL'si ve anon key'i kendi değerlerinizle değiştirin.

### Veritabanı şemasını uygulama
Kanonik şema ve tüm migration'lar `supabase/migrations/` altındadır. Supabase CLI ile:

```bash
supabase link --project-ref <proje-ref>
supabase db push --include-all
```

### Testleri çalıştırma
```bash
npm install
npm test                 # Playwright E2E
npm run test:unit        # node:test unit testleri
npm run test:docker      # Resmi Playwright Docker imajında E2E
```

---

## CI/CD

| Workflow | Amaç |
|---------|------|
| `test.yml` | Her push ve pull request'te 3 shard'da Playwright E2E |
| `deploy.yml` | main'e merge'de bekleyen migration'ları Supabase'e gönderir |
| `pages.yml` | Statik frontend'i GitHub Pages'e yayınlar |
| `sonarcloud.yml` | Statik analiz ve kalite kapıları |
| `db-backup.yml` | Zamanlanmış veritabanı yedekleri |
| `test-migration-ready.yml` | Migration'ları deploy öncesi doğrular |

[![E2E Tests](https://github.com/Meliksahtokur/egesut-erp1/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/Meliksahtokur/egesut-erp1/actions/workflows/test.yml)
[![Deploy to Supabase](https://github.com/Meliksahtokur/egesut-erp1/actions/workflows/deploy.yml/badge.svg?branch=main)](https://github.com/Meliksahtokur/egesut-erp1/actions/workflows/deploy.yml)
[![GitHub Pages](https://github.com/Meliksahtokur/egesut-erp1/actions/workflows/pages.yml/badge.svg?branch=main)](https://github.com/Meliksahtokur/egesut-erp1/actions/workflows/pages.yml)
[![SonarCloud](https://github.com/Meliksahtokur/egesut-erp1/actions/workflows/sonarcloud.yml/badge.svg?branch=main)](https://github.com/Meliksahtokur/egesut-erp1/actions/workflows/sonarcloud.yml)

---

## Lisans

ISC lisansı ile dağıtılmaktadır. Detaylar için `package.json` dosyasına bakın. Bu depodaki veritabanı şeması, migration'lar ve uygulama kaynak kodu olduğu gibi sağlanmıştır.

---

## İletişim

**Melik Şah Tokur** — veteriner hekim ve sistem tasarımcısı
*Full-stack: PostgreSQL · JavaScript · Python · Supabase · Playwright · n8n*

Gerçek kuralları olan alanların veri modelini tasarlıyorum, sonra da kuruyorum: kendi kısıtlarını kendi uygulayan şemalar, gözetimsiz çalışan iş akışları ve kaynağı şekil değiştirdiğinde ayakta kalan veri hatları.

Uzmanlık alanı modelleyen sistemlerin çoğu, uzmanlarla görüşen yazılımcılar tarafından kuruluyor ve aradaki boşluk kendini şemada gösteriyor — foreign key olması gereken alanda, yılda iki kez yaşanan geçişi atlayan state machine'de. Ben bu işe diğer taraftan geldim. Probleminizin altında gerçek bir alan varsa, ilgilendiğim kısım orası.

- GitHub: [@Meliksahtokur](https://github.com/Meliksahtokur)
- Canlı demo: https://meliksahtokur.github.io/egesut-erp1/

Kurumsal araçlar, iş süreci otomasyonu ve PostgreSQL tabanlı uygulamalar için sözleşmeli iş alıyorum. Bu depo referansın kendisi — gerçek bir operasyon her gün buna bağlı.
