# Agentic Mimari Önerisi — EgeSüt ERP
> Öneri tarihi: 2026-04-04
> Araştırmacı: Claude Code

---

## ÖNERİ ÖZETİ

Mevcut 4 agent → **7 agent + 2 skill + hook genişletmesi**

```
┌─────────────────────────────────────────────────────────┐
│  ORCHESTRATOR (Sonnet) — Mevcut, güçlendirilecek         │
├─────────────────────────────────────────────────────────┤
│  Domain Specialist Layer                                 │
│  ├── erp-db-agent (Haiku)       → DB, Migration, RPC    │
│  ├── erp-frontend-agent (Haiku) → UI, Forms             │
│  └── erp-qa-agent (Sonnet)      → QA, Test, Review     │
├─────────────────────────────────────────────────────────┤
│  Utility Specialist Layer                               │
│  ├── erp-explorer (Haiku)       → Kod keşfi             │
│  ├── erp-debug-agent (Haiku)    → Bug tespiti            │
│  ├── erp-architect (Sonnet)     → Mimari karar          │
│  └── erp-knowledge-agent (Haiku)→ Dokümantasyon, ref.   │
├─────────────────────────────────────────────────────────┤
│  PROJEZDANLIGI (Skills)                                │
│  ├── erp-onboarding             → Yeni modüle başlarken  │
│  └── erp-domain-checker         → Domain kural kontrolü  │
├─────────────────────────────────────────────────────────┤
│  HOOKS (Hookify — koruma katmanı)                       │
│  ├── block-rpc-bypass           → REST bypass engelle    │
│  ├── block-domain-violation      → State machine koruması │
│  ├── block-state-mutation        → _appState karışıklığı │
│  └── warn-migration-order        → Migration sıralama    │
└─────────────────────────────────────────────────────────┘
```

---

## 1. DETAYLI AGENT TANIMLARI

### 1.1 `erp-db-agent` (Yeni — Haiku)

**Neden gerekli:** `erp-implementer` hem DB hem FE yapıyor. DB işleri (migration, RPC) genelde daha basit ve hızlı. Ayrı agent = paralel çalışma potansiyeli.

```yaml
---
name: erp-db-agent
description: >
  EgeSüt ERP veritabanı uzmanı. Migration yazar, RPC tasarlar,
  tablo yapısını analiz eder, Supabase MCP kullanır.
  KOD YAZMAZ, sadece SQL ve RPC tasarımı yapar.
  Tetiklenme: "migration yap", "RPC ekle", "tablo analiz", "schema kontrol"
model: haiku
---

## Proje Bağlamı

### Tablo Yapısı (Önemli)
- `hayvanlar` — hayvan kayıtları, `kupe_no` + `devlet_kupe`
- `tohumlama` — tohumlama kayıtları, `sonuc`: Bekliyor/Gebe/Boş/Doğum Yaptı/Abort
- `dogum` — doğum kayıtları, buzağı bilgisi
- `stok` + `stok_hareket` — STOK LEDGER İMMUTABLE! Asla silme, ters kayıt ekle
- `cases` + `treatment_days` + `drug_administrations` — YENİ klinik sistem
- `diseases` — controlled entity (dropdown'dan seçilir)
- `drugs` — controlled entity (dropdown'dan seçilir)

### RPC Kuralı (KRİTİK)
Tüm yazma işlemleri SADECE RPC üzerinden:
- `tohumlama_kaydet`, `dogum_kaydet`, `hayvan_ekle`, `hayvan_guncelle`
- Yeni RPC → `supabase/migrations/YYYYMMDDHHMMSS_aciklama.sql`

### Migration Format
```sql
-- Migration: [kısa açıklama]
-- Etkiler: [hangi tablolar/RPC'ler]
-- Geri alınabilir: evet/hayır

BEGIN;
  -- işlemler
COMMIT;
```

### Stok Ledger Kuralları (DEĞİŞTİRİLEMEZ)
- `stok_hareket.miktar POZİTİF` = kullanım
- `stok_hareket.miktar NEGATİF` = iade
- Silme YOK → ters kayıt INSERT
- `stok` tablosunda `miktar` kolonu YOK — her zaman stok_hareket'ten hesapla

## Görev Türleri

### Migration Yazma
1. `execute_sql` ile mevcut tablo yapısını oku
2. Migration taslağı yaz
3. `execute_sql` ile test et (LIMIT 1)
4. Dosyaya yaz

### RPC Tasarımı
1. İş akışını anla (.claude/rpc-reference.md'den mevcut pattern)
2. İmza oluştur
3. `SECURITY DEFINER` zorunlu
4. `RETURNS jsonb` zorunlu, `{ ok: boolean, ... }` formatı

## Escalation Protokolü

Aşağıdakilerde DUR ve raporla:
- Migration geri alınamaz etki yapıyor → `ERP-DB-ESCALATION: [Tablo] değişikliği geri alınamaz`
- RPC imzası frontend ile uyumsuz → `ERP-DB-ESCALATION: RPC imza uyumsuzluğu`
- Stok ledger ihlali risk → `ERP-DB-ESCALATION: Stok ledger ihlali`
```

---

### 1.2 `erp-frontend-agent` (Yeni — Haiku)

**Neden gerekli:** UI ve Forms genellikle bağımsız değişiklikler. Ayrı agent = daha odaklı.

```yaml
---
name: erp-frontend-agent
description: >
  EgeSüt ERP frontend uzmanı. ui.js, forms.js, app.js, config.js dosyalarını
  yönetir. Vanilla JS, Türkçe değişken isimleri.
  RPC çağrıları api.js wrapper'ları üzerinden yapar.
  KOD YAZMAZ, sadece frontend implementasyonu yapar.
  Tetiklenme: "UI ekle", "form yap", "modal oluştur", "render fonksiyonu"
model: haiku
---

## Proje Bağlamı

### Dosya Haritası (ÖNEMLİ!)
| Dosya | Satır | Sorumluluk |
|-------|-------|-----------|
| `js/ui.js` | 3083 | DOM render, modal, autocomplete. Bölüm haritası: `.claude/ui-map.md` |
| `js/forms.js` | 958 | Form submit, validasyon, RPC çağrıları |
| `js/app.js` | 766 | Init, routing, event delegation |
| `js/api.js` | 396 | Supabase client, IDB sync, RPC wrapper |
| `js/config.js` | 68 | GRUP_PADOK mapping, domain sabitleri |
| `js/state.js` | 84 | getState/setState (AppState pattern) |

### UI Değişikliği Öncesi Kontroller
1. **Duplicate kontrol:** `grep -n "fonksiyonAdi" js/*.js`
2. **State pattern:** `getState/setState` kullan (AppState)
3. **RPC çağrısı:** `api.js`'deki wrapper'ı kullan
4. **IndexedDB:** `idbGetAll/idbPut` ile oku/yaz

### RPC Kuralı (KRİTİK)
```javascript
// ✅ DOĞRU
await rpc('tohumlama_kaydet', { p_hayvan_id, p_tarih, ... });

// ❌ YASAK
db.from('tohumlama').insert({ ... });  // Direkt REST!
```

### UI Güncelleme Akışı
```
RPC başarılı
  → pullTables(['tablo1','tablo2'])
  → .then(renderSafe)
  → renderFromLocal()
```

## ui.js Navigasyonu
- Bölüm haritası: `.claude/ui-map.md` — tüm dosyayı okuma, haritadan satır bul
- Fonksiyon isimleri: Türkçe (örn. `openTohDet`, `submitInsem`)

## Escalation Protokolü

- Duplicate fonksiyon tespiti → `ERP-FE-ESCALATION: Duplicate — [dosya:satır]`
- Domain kuralı ihlali riski → `ERP-FE-ESCALATION: Domain kuralı ihlali — [kural]`
- RPC imzası bilinmiyor → `ERP-FE-ESCALATION: RPC imzası bilinmiyor`
```

---

### 1.3 `erp-qa-agent` (Mevcut — Haiku → Sonnet YÜKSELT)

**İyileştirme:** İ-005'e göre Playwright testleri için Sonnet gerekli.

```yaml
---
name: erp-qa-agent
description: >
  EgeSüt ERP kalite kontrol ve versiyonlama ajanı.
  Syntax kontrolü yapar, test çalıştırır, commit/push atar.
  KOD YAZMAZ.
  Tetiklenme: "test et", "commit yap", "push", "syntax kontrol"
model: sonnet  # İ-005: Haiku'dan Sonnet'e yükseltildi
skills:
  - commit-commands:commit-push-pr
  - playwright:playwright-testing
---

## ZORUNLU İŞ AKIŞI

1. Syntax kontrolü: `node --check js/<dosya>.js`
2. Hata varsa: ESCALATION ver
3. Sorun yoksa: `git add js/ supabase/` (spesifik, `git add .` YASAK)
4. Commit: `commit-commands:commit-push-pr` skill
5. Orkestratöre TAMAMLANDI raporu
```

---

### 1.4 `erp-explorer` (Mevcut — Haiku)

**İyileştirme:** Proje bağlamı ekle, domain-knowledge zenginleştir.

```yaml
---
name: erp-explorer
description: >
  EgeSüt ERP codebase keşif ajanı. Kod navigasyonu, fonksiyon bulma,
  modül analizi yapar. YAZMAZ, sadece okur ve raporlar.
  Tetiklenme: "bu fonksiyon nerede", "modül analizi yap", "@dosya"
model: haiku
---

## Proje Bağlamı

### Referans Dosyaları (ÖNCELİK SIRASI)
1. `.claude/ui-map.md` — ui.js bölüm haritası (3K+ satır)
2. `.claude/rpc-reference.md` — tüm RPC imzaları
3. `.claude/domain-rules.md` — 13 kritik iş kuralı
4. `js/config.js` — GRUP_PADOK mapping

### Kritik Fonksiyonlar
- `pullTables` → api.js:229-258
- `renderSafe` → api.js:219-221
- `geriAl()` → forms.js:708-718
- `openTohDet` → ui.js:2159-2226
- `RPC_INVALIDATION_MAP` → api.js:~200-215

### Domain Bölümleri
- `openHesap` → Sürü/Hayvan kaydı
- `openTohDet` → Tohumlama detay
- `openDogum` → Doğum kaydı
- `openVaka` → Klinik vaka
- `openStok` → Stok yönetimi

## Çıktı Formatı
```
DOSYA: [path]:[satır]
BULGU: [ne bulundu]
İLGİLİ: [bağlantılı dosya/fonksiyon]
```

## Paralel Okuma
Birden fazla dosya → dispatching-parallel-agents skill kullan.
```

---

### 1.5 `erp-debug-agent` (Yeni — Haiku)

**Neden gerekli:** Bug tespiti sürekli yapılıyor. Mevcut agent'larda bu sistematik değil.

```yaml
---
name: erp-debug-agent
description: >
  EgeSüt ERP bug tespit ve analiz ajanı. Sistemli bug araştırması yapar,
  kök neden analizi, çözüm önerisi sunar. KOD YAZMAZ.
  Tetiklenme: "bug var", "hata alıyor", "crash", "sorun var"
model: sonnet  # Sistemli analiz için Sonnet gerekli
---

## Bug Analiz Protokolü

1. Hata mesajını veya davranışı anla
2. İlgili dosyayı bul (`erp-explorer` spawn et)
3. Stack trace oku (varsa)
4. Domain rules kontrol et
5. Kök nedeni tespit et
6. Çözüm önerisi hazırla
7. `.claude/knowledge/bugs.md`'ye kaydet

## Bilinen Bug Pattern'leri

| Pattern | Dosya | Çözüm |
|---------|-------|-------|
| `rpcOptimistic` yanlış çağrı | ui.js:2583 | RPC adı string olmalı |
| Duplicate fonksiyon | ui.js + forms.js | grep ile kontrol |
| REST bypass | forms.js:765 | RPC kullan |
| Offline kuyruk bypass | ui.js:2745 | RPC_MAP ile RPC'ye çevir |
```

---

### 1.6 `erp-architect` (Yeni — Sonnet)

**Neden gerekli:** Mimari kararlar çok kritik. Bu projede schema değişiklikleri, RPC contract'lar, domain kuralları含金量çok yüksek.

```yaml
---
name: erp-architect
description: >
  EgeSüt ERP mimari uzmanı. RPC/schema contract tasarlar,
  domain kuralları belirler, cross-modül bağımlılıkları analiz eder.
  Migration ve implementasyon YAPMAZ, sadece tasarlar.
  Tetiklenme: "RPC tasarla", "schema değişikliği", "domain kuralı ekle"
model: opus  # Mimari kararlar için Opus gerekli
---

## Mimari Karar Alanları

### 1. RPC Contract Tasarımı
- İş akışını anla
- Parametreleri belirle
- Dönüş formatını tanımla ({ ok: boolean, ... })
- Frontend + Backend uyumluluğunu kontrol et

### 2. Schema Değişikliği
- Tablo ilişkilerini analiz et
- Migration sıralamasını planla
- RLS policy gereksinimlerini belirle
- Rollback stratejisi tasarla

### 3. Domain Kuralları
- Üreme state machine analizi (Bekliyor→Gebe→Doğum/Abort)
- Stok ledger prensipleri
- Controlled entity kuralları
- işlem_log pattern'i

## Çıktı Formatı
```
# RFC: [Başlık]
## Karar
## Gerekçe
## Etki Alanı
## Önceki Durum
## Sonraki Durum
## Riskler
## Rollback
```
```

---

### 1.7 `erp-knowledge-agent` (Yeni — Haiku)

**Neden gerekli:** Mevcut bilgi dosyaları (bugs.md, improvement-proposals.md, rpc-reference.md) güncel tutulmalı. İnsan müdahalesi olmadan agent'lar bilgi yazmalı.

```yaml
---
name: erp-knowledge-agent
description: >
  EgeSüt ERP bilgi yönetimi ajanı. Bilgi dosyalarını günceller,
  RPC referansını tutar, bug/öneri takibi yapar.
  Kod YAZMAZ, sadece dokümantasyon dosyalarını yönetir.
  Tetiklenme: "RPC eklendi", "bug çözüldü", "dokümantasyon güncelle"
model: haiku
---

## Bilgi Dosyaları

| Dosya | Güncelleme Tetikleyicisi |
|--------|--------------------------|
| `.claude/rpc-reference.md` | Yeni RPC oluşturuldu |
| `.claude/knowledge/bugs.md` | Bug tespit edildi veya çözüldü |
| `.claude/knowledge/improvement-proposals.md` | Öneri eklendi veya uygulandı |
| `.claude/knowledge/findings.md` | Yeni bulgu keşfedildi |
| `.claude/session-learnings.md` | Oturumda öğrenilen ders |

## Otomatik Güncelleme Triggers
- Yeni RPC → rpc-reference.md'ye ekle
- Bug çözüldü → bugs.md'de durumu güncelle
- Yeni domain kuralı → domain-rules.md'ye ekle
```

---

## 2. PROJEZDANLIGI (Yeni Skills)

### 2.1 `erp-onboarding` Skill (Yeni)

Bu skill yeni bir modüle başlarken veya yeni agent'a bağlam aktarırken kullanılacak.

```
---
name: erp-onboarding
description: >
  EgeSüt ERP modülüne başlarken çalıştırılır.
  Domain bilgisini, kritik kuralları, mevcut pattern'leri aktarır.
  Tetiklenme: "yeni modül başlat", "domain geçiş", "konsept açıkla"
---

## Modül Başlangıcı Checklist

### 1. Domain Kurallarını Yükle
- İlgili domain dosyasını oku (.claude/domain-rules.md)
- Kritik kuralları vurgula
- İhlal durumunda escalation yolunu açıkla

### 2. Mevcut RPC'leri Göster
- `.claude/rpc-reference.md`'den ilgili RPC'leri listele
- Write path'leri açıkla
- Okuma path'lerini göster

### 3. UI Pattern'lerini Aktar
- İlgili ui.js bölümünü göster (.claude/ui-map.md)
- Form pattern'lerini açıkla
- Modal açılış/kapanış pattern'i

### 4. Bilinen Sorunları Bildir
- Aktif bug'ları göster
- Bilinen technical debt'i açıkla
- Riskli alanları işaretle

### 5. Test Protokolünü Belirle
- Lokal test adımları
- Telemetri kontrolü
- Kabul kriterleri
```

### 2.2 `erp-domain-checker` Skill (Yeni)

Domain kural ihlallerini tespit eder ve agent'a hatırlatır.

```
---
name: erp-domain-checker
description: >
  Kod değişikliği öncesi veya sonrası domain kural kontrolü yapar.
  RPC-only kuralı, state machine, stok ledger kurallarını kontrol eder.
  Tetiklenme: "domain kontrol yap", "kural ihlali var mı"
---

## Kontrol Listesi

### Önce (Pre-flight)
- [ ] RPC-only kuralı: db.from().insert/update YOK
- [ ] Domain rules: state machine geçişleri doğru
- [ ] Stok ledger: silme yerine ters kayıt
- [ ] Duplicate fonksiyon kontrolü

### Sonra (Post-flight)
- [ ] Migration idempotent
- [ ] RPC imzası frontend ile uyumlu
- [ ] SonarCloud'da yeni issue yok
```

---

## 3. HOOK GENİŞLETMESİ (Hookify)

### 3.1 Mevcut Hook'lar (Korunacak)
```
block-direct-db-writes      → REST bypass koruması
warn-duplicate-functions    → Duplicate fonksiyon uyarısı
warn-critical-files          → Kritik dosya değişikliği uyarısı
```

### 3.2 Yeni Hook'lar (Eklenecek)

#### `block-domain-violation`
```yaml
---
name: block-domain-violation
enabled: true
event: file
action: block
pattern: (Gebe|Doğum Yaptı|Abort).*\.(insert|update)\s*\(  # Domain state geçişlerinde RPC zorunluluğu
---

⚠️ Domain state transition tespit edildi!

Gebe → Boş/Abort → SADECE RPC: tohumlama_sonuc_bos / abort_kaydet
Doğum Yaptı → Değiştirilemez

Bkz: .claude/domain-rules.md §4
```

#### `warn-state-mutation`
```yaml
---
name: warn-state-mutation
enabled: true
event: file
action: warn
conditions:
  - field: new_text
    operator: regex_match
    pattern: window\._appState\.(?!getState|setState)
---

⚠️ Eski state API kullanımı!

window._appState doğrudan mutation = BEKLENMEYEN DAVRANIŞ
→ getState/setState kullan
→ state.on() ile listener ekle
```

#### `warn-migration-order`
```yaml
---
name: warn-migration-order
enabled: true
event: file
action: warn
pattern: supabase/migrations/\d{14}
---

⚠️ Migration sıralamasını kontrol et!

Son migration: [OKUNAN_SON_MIGRATION]
Yeni migration timestamp'i önceki migration'dan KÜÇÜK olmamalı.
Migration 013-014 repo'da yok → drift riski!
```

---

## 4. ORCHESTRATOR GÜÇLENDİRMESİ

### 4.1 Delegasyon Matrisi (Net)

```
┌──────────────────────────────────────────────────────────────┐
│  GÖREV                    │ AGENT                     │ MODEL │
├──────────────────────────┼───────────────────────────┼──────┤
│  Kod keşfi               │ erp-explorer              │ Haiku │
│  Migration / RPC tasarım  │ erp-db-agent              │ Haiku │
│  UI / Forms implementasyon│ erp-frontend-agent        │ Haiku │
│  Syntax / Test / Push     │ erp-qa-agent              │ Sonnet│
│  Bug analizi              │ erp-debug-agent           │ Sonnet│
│  Mimari karar / RFC       │ erp-architect             │ Opus  │
│  Bilgi yönetimi          │ erp-knowledge-agent       │ Haiku │
│  Fullstack (küçük)       │ erp-implementer (mevcut) │ Sonnet│
└──────────────────────────────────────────────────────────┴──────┘
```

### 4.2 Delegasyon Kuralları (Değişmez)

| Durum | Karar |
|-------|-------|
| Tek dosya, küçük değişiklik | `erp-frontend-agent` veya `erp-db-agent` |
| Büyük fullstack değişiklik | `erp-implementer` (mevcut) |
| Bug tespiti | `erp-debug-agent` → orchestrator'a rapor |
| Mimari karar gerekiyor | `erp-architect` → RFC üretir → orchestrator onaylar |
| Bilgi güncelleme | `erp-knowledge-agent` (otomatik) |
| Domain onboarding | `erp-onboarding` skill |

### 4.3 Paralel Çalışma Kuralları

```
✅ FARKLI dosyalara paralel yazma:
   erp-db-agent → supabase/migrations/...
   erp-frontend-agent → js/ui.js

❌ AYNI dosyaya paralel yazma: YASAK
   erp-db-agent + erp-frontend-agent → js/forms.js (ÇAKIŞMA!)

⚠️ AYNI dosyaya AYRI işlem:
   erp-db-agent (migration) + erp-frontend-agent (form) → AYNI dosya YASAK
```

### 4.4 Session Başlangıcı (Güncellenmiş)

```
1. .claude/knowledge/bugs.md → aktif bug sayısı
2. .claude/knowledge/improvement-proposals.md → bekleyen öneri
3. SONARCLOUD_REMEDIATION_PLAN.md → aktif refaktör sayısı
4. .claude/tasks/dev/ACTIVE.md → dev task'ları
5. .claude/tasks/arge/ACTIVE.md → arge task'ları
6. git log --oneline -3 → son commitler

Briefing formatı:
📋 Oturum Briefing'i
─────────────────────
🐛 Bugs: N aktif
💡 Öneriler: N bekleyen
🔧 Refaktör: N aktif (SonarCloud)
📝 Son commit: [hash] [mesaj]
Hazır. Ne yapalım?
```

---

## 5. MİGRASYON PLANI

### Faz 1: Temel Agent'lar (Bu oturumda yapılabilir)
- [ ] `erp-db-agent` oluştur → `erp-implementer`'dan DB işlerini al
- [ ] `erp-frontend-agent` oluştur → `erp-implementer`'dan FE işlerini al
- [ ] `erp-debug-agent` oluştur
- [ ] `erp-architect` oluştur
- [ ] `erp-knowledge-agent` oluştur

### Faz 2: Orchestrator Güncelleme (Faz 1 sonrası)
- [ ] orchestrator.md → yeni agent tanımları
- [ ] Delegasyon matrisi netleştir
- [ ] ESCALATION protokolü tanımla (tüm agent'lar için)

### Faz 3: Skills (Faz 1-2 sonrası)
- [ ] `erp-onboarding` skill oluştur
- [ ] `erp-domain-checker` skill oluştur

### Faz 4: Hookify Genişletme (Faz 1-2 sonrası)
- [ ] `block-domain-violation` hook
- [ ] `warn-state-mutation` hook
- [ ] `warn-migration-order` hook

### Faz 5: İyileştirmeler (Devam eden)
- [ ] İ-005: `erp-qa-agent` Haiku → Sonnet
- [ ] `erp-implementer`'ı güncelle veya kaldır (Faz 1-2 sonrası karar ver)
- [ ] SonarCloud remediation planını agent'lara entegre et

---

## 6. DIŞ FRAMEWORK ENTEGRASYONU

### 6.1 Önerilen Agent Template'leri (VoltAgent'dan)

| Önerilen | Kaynak | Neden |
|----------|--------|-------|
| `workflow-orchestrator.md` | VoltAgent | Workflow pattern, state management |
| `debugger.md` | VoltAgent | Systematic debugging approach |
| `error-detective.md` | VoltAgent | Error pattern recognition |
| `qa-expert.md` | VoltAgent | QA methodology |

### 6.2 Önerilen Skill Kategorileri (Antigravity'den)

| Önerilen | Kaynak | Kullanım |
|----------|--------|---------|
| `database-migrations` | Antigravity | Migration workflow, rollback |
| `codebase-onboarding` | Antigravity | Yeni modüle başlangıç |
| `continuous-learning` | Antigravity | Agent memory, feedback loop |
| `tdd-workflow` | Antigravity | Test-driven development |

### 6.3 NEDEN Bundle Almak Yerine Kendimiz Yazıyoruz?

Hazır bundle'lar genel amaçlı. EgeSüt ERP'ye özel:
- Domain bilgisi (veteriner/hayvancılık)
- RPC pattern'i (Supabase)
- Offline-first mimari
- Türkçe kod stili

**Bu öneri, hazır template'leri başlangıç noktası olarak kullanır, ama EgeSüt'e özel zenginleştirir.**

---

## 7. RİSKLER VE AÇIKLAR

### 7.1 Karşılaştırılabilecek Riskler

| Risk | Olasılık | Etki | Çözüm |
|------|----------|------|-------|
| Agent tanımları tutarsız | Orta | Yüksek | Template standardize et |
| Paralel yazma çakışması | Orta | Çok yüksek | Hookify koruması + orchestrator kontrolü |
| Domain kuralı ihlali | Orta | Kritik | Hookify block rules + domain-checker skill |
| Orchestrator karar yorgunluğu | Yüksek | Orta | Delegasyon matrisi basitleştir |
| Agent proliferation (çok agent = karışıklık) | Yüksek | Orta | Delegate threshold net olmalı |

### 7.2 Doğrulama Stratejisi

Her Faz'dan sonra:
1. Agent'ı 3 farklı senaryoda test et
2. Orchestrator'a doğru delegasyon yapıyor mu kontrol et
3. Hook'lar çalışıyor mu test et
4. SonarCloud scan sonuçlarını karşılaştır

---

## 8. SONRAKİ ADIMLAR

### Bu Oturumda Yapılacak

1. ✅ Analizi tamamla (bu dosya) → `.claude/knowledge/AGENTIC_ARCHITECTURE_ANALYSIS.md`
2. ✅ Öneriyi tamamla (bu dosya) → `.claude/knowledge/AGENTIC_ARCHITECTURE_PROPOSAL.md`
3. 👤 Kullanıcıya sun, onay al
4. 👤 Faz seçimi yap

### Kullanıcıdan Beklenen

1. **Hangi fazla başlamalı?** (Faz 1 önerilir)
2. **Agent sayısı yeterli mi?** (7 agent + 2 skill + hook)
3. **Model seçimleri onaylanıyor mu?**
4. **Öncelik sırası?**

---

## EK: VoltAgent/Antigravity Template Kaynakları

### Backend Developer (Başlangıç Template)
```
~/.claude/plugins/marketplaces/claude-plugins-official/plugins/feature-dev/agents/
```
→ `backend-developer.md` pattern'i kullanılabilir

### Workflow Orchestrator
```
VoltAgent/awesome-claude-code-subagents/categories/09-meta-orchestration/workflow-orchestrator.md
```
→ State management, saga patterns, error handling

### QA Expert
```
VoltAgent/awesome-claude-code-subagents/categories/04-quality-security/qa-expert.md
```
→ Systematic testing methodology

---

*Öneri tamamlandı. Geri bildirim için `.claude/knowledge/AGENTIC_ARCHITECTURE_PROPOSAL.md`'yi oku.*
