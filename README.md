# EgeSüt ERP

> 130+ hayvanlık süt çiftliği için offline-first web tabanlı yönetim sistemi.
> Herd, reproduction, klinik, stok ve otomatik görev iş akışları tek bir uygulamada.

[![Live Demo](https://img.shields.io/badge/demo-live-4e9a2a?style=flat-square&logo=github&logoColor=white)](https://meliksahtokur.github.io/egesut-erp1/)
[![GitHub stars](https://img.shields.io/github/stars/Meliksahtokur/egesut-erp1?style=flat-square&logo=github)](https://github.com/Meliksahtokur/egesut-erp1/stargazers)
[![License](https://img.shields.io/badge/license-ISC-blue?style=flat-square)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/Meliksahtokur/egesut-erp1?style=flat-square&logo=git)](https://github.com/Meliksahtokur/egesut-erp1/commits/main)
[![Supabase](https://img.shields.io/badge/Supabase-PostgreSQL-3ECF8E?style=flat-square&logo=supabase&logoColor=white)](https://supabase.com)
[![Playwright](https://img.shields.io/badge/Playwright-E2E-2EAD33?style=flat-square&logo=playwright&logoColor=white)](https://playwright.dev)

**Canlı:** https://meliksahtokur.github.io/egesut-erp1/
**Backend:** Supabase (PostgreSQL)
**Repo:** github.com/Meliksahtokur/egesut-erp1

---

## Teknik Stack

| Katman | Teknoloji |
|--------|-----------|
| Frontend | Vanilla JS, tek `index.html` — framework yok, derleme adımı yok, bağımlılık yok |
| Backend | Supabase (PostgreSQL) — RPC + REST |
| Veri modeli | 50 tablo, 170+ sunucu-tarafı fonksiyon, trigger, RLS politikaları |
| Offline Cache | IndexedDB (`egesut_v9`) |
| Hosting | GitHub Pages (statik frontend), Supabase (veritabanı) |
| Migration | 222 versiyonlu SQL dosyası, CI ile Supabase CLI üzerinden deploy |
| Test | Playwright E2E (3 runner'da sharded), `node:test` unit testleri |
| Kalite | SonarCloud statik analiz |

---

## Modüller ve Durum

| Modül | Durum | Açıklama |
|-------|-------|----------|
| **Sürü** | ✅ Tamamlandı | Hayvan kartı, kimlik bilgileri, grup/padok ataması, 130+ hayvan arasında filtreleme, her hayvan için kronolojik zaman çizelgesi |
| **Üreme** | ✅ Tamamlandı | Kızgınlık tespiti → tohumlama → gebelik takibi → doğum → buzağı kaydı. Durum geçişleri DB trigger'ları ile korunur |
| **Klinik / Vaka** | ✅ Tamamlandı | Vaka açma, günlük tedavi seansları, kontrollü ilaç kataloğundan reçete, vaka kapatma. Tedavi şablonları ve geri alma desteği |
| **Stok / Eczane** | ✅ Tamamlandı | İlaç ve malzeme girişi, uygulamada otomatik stok düşümü, kritik stok uyarıları. Aşı ve sperma stoğu da takip edilir. Immutable ledger — düzeltmeler yeni hareket olarak girilir |
| **Görev** | ✅ Tamamlandı | Veritabanı tarafından otomatik üretilen görevler (aşı, takip, protokol adımları). Renk kodlu durum, tek tıkla tamamlama, denetim için immutable işlem logu |
| **Aşı** | ✅ Tamamlandı | İçerik-odaklı protokol yönetimi: aşılar, hedef hastalıklar, protokol adımları (primer + rapel), eşdeğer ürün ve çoklu doz desteği |
| **İstatistik** | ✅ Tamamlandı | Sürü özeti, üreme verimliliği (Düve/İnek ×3), sperma/PI endeksleri, hayvan bazında ve olay bazında zaman çizelgeleri |
| **AI Asistan** | ✅ Tamamlandı | Uygulama içi asistan — canlı şemaya karşı salt-okuma SQL sorguları çalıştırır, plan taslağı hazırlar, yazma işlemleri için insan onayı (HITL) bekler |
| **Demo-Mirror** | ✅ Tamamlandı | `postgres_fdw` köprüsü ile canlı verinin salt-okuma klonu, tek tıkla atomik klonlama, demo girişi, sürüklenme uyarısı |
| **Bildirimler** | ✅ Tamamlandı | Bekleyen uyarılar için birleşik gelen kutusu — yaklaşan görevler, düşük stok, açık vakalar |

---

## Mimari Prensipler

- **İş mantığı DB'de** — frontend sadece render ve input toplar, hesap yapmaz, state machine işletmez, validasyon yapmaz. Tüm iş mantığı PostgreSQL'de (RPC + trigger + view).
- **Sadece RPC ile yaz** — tarayıcı asla tabloya doğrudan INSERT/UPDATE/DELETE yapmaz. Her mutasyon bir PostgreSQL fonksiyonu çağırır; validasyon, yetkilendirme ve yan etkiler sunucu-tarafında tek noktada uygulanır.
- **Controlled entities** — hastalık, ilaç, hayvan asla free-text değil; FK + dropdown zorunlu, veri seti temiz ve raporlanabilir kalır.
- **Stok ledger immutable** — stok hareketleri ek-olarak (append-only) kaydedilir; düzeltmeler yeni ledger girişi olarak girilir, tam denetim izi korunur.
- **Offline-first** — tüm okumalar IndexedDB'den sunulur, çevrimiçiyken sunucuyla senkronize edilir; service worker bağlantı olmasa bile uygulama kabuğunu kullanılabilir tutar. Sinyalin zayıf olduğu ahır ortamında kullanılmak üzere tasarlanmıştır.
- **Versiyonlu şema, CI ile deploy** — Migration'lar `supabase/migrations/` altında yaşar ve her `main` birleştirmesinde GitHub Actions ile production'a gönderilir. Kanonik şema `supabase/migrations/99999999999999_ground_truth.sql` ile yakalanır.
- **Multi-tenant temeller** — `farm_id` disiplini ve kiracı- kapsamlı RLS politikaları gelecekteki çoklu-çiftlik genişlemesi için hazırdır.
- **Demo ortamı** — `postgres_fdw` üzerinden `demo_klonla()` RPC ile canlı verinin salt-okuma klonu, potansiyel kullanıcıların production'a dokunmadan gerçek şemayı keşfetmesini sağlar.
- **Sıfır derleme adımı** — transpiler, bundle'layıcı veya deploy'da bağımlılık çözümü yok; statik dosyalar yazıldığı gibi gider, yüzey alanı küçük kalır.

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
supabase/migrations/             — 222 migration dosyası (PostgreSQL)
scripts/                       — LSP, ground-truth-audit, sql-lsp daemon, vb.
tests/                         — Playwright E2E + node:test unit testleri
demo/                          — Demo-Mirror SQL (00_grants, 01_fdw, 02_klonla, 03_sema_diff)
```

## Veritabanı Özeti

**50 public tablo** (canlı, LSP teyitli).

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
agent_threads + agent_messages + agent_plans  — AI Asistan hafıza + plan motoru
prod_fdw                                       — Demo-Mirror FDW köprüsü
diseases / drugs                               — kontrollü listeler
```

Mimari kararlar: [`ARCHITECTURE.md`](ARCHITECTURE.md)
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

**Melik Şah Tokur** — freelance full-stack geliştirici

- GitHub: [@Meliksahtokur](https://github.com/Meliksahtokur)
- Depo: [egesut-erp1](https://github.com/Meliksahtokur/egesut-erp1)
- Canlı demo: https://meliksahtokur.github.io/egesut-erp1/

Kurumsal araçlar, iş uygulamaları ve veri odaklı web uygulamaları için freelance iş alıyorum. Bu depo, bir demo projesi değil, gerçek bir işletmede çalışan üretim sistemidir.

---

> 📘 English version available: [`README.en.md`](README.en.md)
