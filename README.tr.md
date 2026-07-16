# EgeSüt ERP

> Çalışan bir süt çiftliği için offline-toleranslı web tabanlı yönetim sistemi — sürü, üreme, klinik, stok ve otomatik görev iş akışları tek bir uygulamada.

**Bu bir portföy projesi değil.** 157 hayvanlık bir süt çiftliği günlük operasyonunu bu sistemle yürütüyor. 16 Temmuz 2026 itibarıyla: 2.674 kayıtlı işlem, bunların 586'sı son 30 günde, son 90 günün 66'sında aktif kullanım.

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

Canlı veritabanı nesneleri: **48 tablo · 13 view · 180 fonksiyon · 35 trigger**, **221 versiyonlu migration** üzerinden inşa edildi.

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
- **Stok ledger immutable** — stok hareketleri append-only kaydedilir. Düzeltmeler yeni ledger satırı olarak girilir; hiçbir zaman düzenleme veya silme yapılmaz, denetim izi eksiksiz kalır. Güncel stok her zaman hesaplanır, saklanmaz.
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
- **Polling, realtime değil.** Senkronizasyon Supabase Realtime kanalları yerine 5 saniyelik interval ile çalışıyor. Mevcut tek-operatör kullanımı için yeterli; eşzamanlı çok kullanıcılı düzenleme için değişmesi gerekir.

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
hayvanlar (çekirdek)
  ├── tohumlama          — üreme olayları (per-cycle state machine)
  ├── dogum              — doğum kayıtları
  ├── kizginlik_log      — kızgınlık takibi
  ├── gorev_log          — görev sistemi (cascade/orphan guard)
  └── cases              — klinik vakalar
        ├── treatment_days → drug_administrations → drugs → stok
        ├── tedavi_sablon_*, tedavi_sablon_uygulama — şablon motoru
        └── tedavi (legacy, temizlendi)

stok
  └── stok_hareket       — ledger (immutable, append-only)

vaccines + vaccine_diseases + protocol_steps  — aşı yönetimi (içerik-odaklı)
agent_threads + agent_messages + agent_plans  — AI Asistan hafıza + plan motoru (kullanıcı-bazlı RLS)
prod_fdw                                      — Demo-Mirror FDW köprüsü
diseases / drugs                              — kontrollü listeler
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

**Melik Şah Tokur** — backend ve otomasyon mühendisi

Doğru olmak zorunda olan kısımları yazıyorum: kendi kurallarını kendi uygulayan veritabanı şemaları, gözetimsiz çalışan iş akışları ve kaynağı şekil değiştirdiğinde ayakta kalan veri hatları.

- GitHub: [@Meliksahtokur](https://github.com/Meliksahtokur)
- Canlı demo: https://meliksahtokur.github.io/egesut-erp1/

Kurumsal araçlar, iş süreci otomasyonu ve PostgreSQL tabanlı uygulamalar için sözleşmeli iş alıyorum. Bu depo referansın kendisi — gerçek bir operasyon her gün buna bağlı.
