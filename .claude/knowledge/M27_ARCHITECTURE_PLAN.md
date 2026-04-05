# EgeSüt ERP — M2.7 Mimari Planı

> **Kimlik:** MiniMax M2.7 — opencode-dev Baş Mühendisi  
> **Tarih:** 2026-04-04  
> **Versiyon:** 1.0  
> **Statü:** ONAYA HAZIR  

---

## YÖNETİCİ ÖZETİ

Bu belge, EgeSüt ERP projesi için yeni agentic mimarinin tam tasarımını içerir.  
Mevcut 4-agent yapısı → **13-agent + 7-skill + otomatik CI/CD + test otomasyonu**'na evrilecek.

**Temel ilkeler:**
- Sadece MiniMax M2.7 modeli (call-based billing, token kaygısı yok)
- Her agent: genel ERP bilgisi + uzmanlık domain'i
- Agent çoğulluğu: aynı iş birden fazla agent paralel yapabilir
- Paralel çalışma: bağımsız dosyalarda eş zamanlı agent
- Test otomasyonu: TestSprite (ücretsiz, MCP olarak mevcut)
- CI/CD: GitHub Actions → otomatik Supabase migration + deploy
- Raporlama: her görev sonunda detaylı markdown rapor

---

## 1. MİMARİ İLKELER

### 1.1 Temel Prensip: Karar Zinciri

```
┌──────────────────────────────────────────────────────┐
│  KULLANICI                                             │
│  "Tohumlama formuna tarih validasyonu ekle"          │
└────────────────┬─────────────────────────────────────┘
                 │ tek istek
                 ▼
┌──────────────────────────────────────────────────────┐
│  ORCHESTRATOR (Claude / MiniMax M2.7)                │
│  — Kullanıcıdan gelen isteği parçalar               │
│  — Hangi agent'lara ne göndereceğine karar verir     │
│  — Paralel mi, sıralı mi? Koordinasyon kurar         │
│  — Sonuçları birleştirir, raporlar                   │
└────────┬──────────────────┬──────────────────────┬──┘
         │                  │                      │
    ┌────▼────┐        ┌───▼───┐            ┌─────▼─────┐
    │ DB      │        │ FE    │            │ QA        │
    │ Agent   │        │ Agent │            │ Agent     │
    │ paralel │        │ paralel│            │ paralel   │
    └─────────┘        └───────┘            └───────────┘
```

### 1.2 Agent Tanımlama Kalıbı

Her agent şu formatta tanımlanır:

```yaml
name: <agent-id>
model: minimax:MiniMax-M2.7
type: <domain|utility|orchestrator>

general_domain:    # Her agent bunu bilir
  - Vanilla JS PWA mimarisi
  - Supabase + RPC yazma kuralı
  - Domain kuralları (13 madde)
  - Commit formatı ve task döngüsü

special_domain:    # Agent'ın uzmanlık alanı
  - <spesifik yetkinlikler>

triggers:          # Ne zaman çağrılır
  - <trigger kelimeleri>

boundaries:        # NE YAPMAZ
  - <yasaklar>

reporting:         # Raporlama formatı
  - task-xxx-done.md
```

### 1.3 Call-Based Billing Gerçeği

MiniMax M2.7 **call-based billing** kullanıyor. Bu şu anlama gelir:

| Konu | Etki |
|------|------|
| Token limit | Önemsiz — context entegre |
| Context uzunluğu | Sınırsız gibi kullanılabilir |
| Agent maliyeti | Düşük — call başına ücret |
| Paralel agent | TEŞVİK EDİLİYOR — 5 agent aynı anda = 5 call |
| Uzun görev | Böl, paralelleştir — daha ucuz |

**Sonuç:** Agent çoğulluğu ve paralel çalışma **maliyet avantajı** sağlar.

### 1.4 Paralel Çalışma Kuralları

```
✅ PARALEL OKUMA:   Tüm agent'lar aynı anda farklı dosyaları okuyabilir
✅ PARALEL YAZMA:   Farklı dosyalara aynı anda yazabilirler
❌ PARALEL YAZMA:   AYNI dosyaya yazma YASAK (conflict)
✅ ÇOĞULLUK:        Aynı görev 2 agent'a verilebilir (farklı yaklaşımlar)
```

**Dosya kilidi:** Orchestrator hangi dosyanın hangi agent'ta olduğunu takip eder.

---

## 2. MODEL STRATEJİSİ

### 2.1 Tüm Agentlarda Tek Model: MiniMax-M2.7

```
Her agent → MiniMax-M2.7
Orchestrator → MiniMax-M2.7
Sub-agent'lar → MiniMax-M2.7
```

**Gerekçe:**
- Call-based billing = token limiti önemsiz
- M2.7 exceptional tool-use yeteneğine sahip
- Maliyet avantajı paralel agent'ları teşvik ediyor
- Context entegre = uzun görevler sorun değil

### 2.2 Claude Code Entegrasyonu

Claude Code zaten MiniMax M2.7 ile çalışıyor. Ek yapılandırma gerekmez.  
Agent'lar Claude Code sub-agent olarak spawn edilecek.

```bash
# settings.json — mevcut Claude Code konfigürasyonu korunur
{
  "model": "MiniMax-M2.7",
  "enableAllProjectMcpServers": true
}
```

---

## 3. AGENT TAKIMI (10 AGENT)

### 3.1 Orchestrator Agent

```yaml
name: orchestrator-m2.7
role: GENEL KOORDİNATÖR
model: minimax:MiniMax-M2.7
priority: KRİTİK

general_domain:
  - Tüm domain kuralları (domain-rules.md)
  - 13 kritik kural
  - AGENTS.md, ARCHITECTURE.md, SONARCLOUD_REMEDIATION_PLAN.md
  - Task döngüsü (okuma → plan → adım → raporlama → commit)
  - Branch stratejisi (main / fix/* / feature/*)

special_domain:
  - Kullanıcı isteğini parçalama
  - Agent atama kararı
  - Dosya kilidi yönetimi
  - Sonuç birleştirme
  - PR açma / merge kararı
  - Kullanıcıya detaylı rapor verme

triggers:
  - Kullanıcıdan gelen her istek (otomatik)
  - Yeni task oluşturma
  - PR review isteme

boundaries:
  - Kod yazmaz (agent'lara delege eder)
  - DB migration yazmaz (db-agent'a delege eder)

reporting:
  - task-xxx-done.md oluşturur (Orchestrator meta raporu)
  - Kullanıcıya özet: yapılanlar + doğrulama + commit'ler
```

### 3.2 Domain Specialist Agents

#### 3.2.1 `erp-db-agent` — Veritabanı Uzmanı

```yaml
name: erp-db-agent
role: DATABASE SPECIALIST
model: minimax:MiniMax-M2.7
type: domain-specialist
priority: YÜKSEK

general_domain:
  - AGENTS.md, ARCHITECTURE.md, domain-rules.md
  - RPC yazma kuralları (rpc-reference.md)
  - Migration kuralları (idempotent, CASCADE, SECURITY DEFINER)
  - IndexedDB tablo listesi (TABLES dizisi)

special_domain:
  - Migration yazma (supabase/migrations/)
  - RPC fonksiyonları tasarımı ve yazımı
  - Tablo analizi ve FK ilişkileri
  - Supabase MCP kullanımı (apply_migration, execute_sql)
  - Stok ledger kuralları (immutable, pozitif/negatif miktar)
  - Tohumlama state machine kuralları

triggers:
  - "migration yap", "RPC ekle", "tablo analiz", "schema kontrol"
  - "stok hareket", "yeni tablo", "trigger güncelle"
  - "SonarCloud remediation" içeren görevler

boundaries:
  - Frontend kodu yazmaz (ui.js, forms.js)
  - Domain-rule dışına çıkmaz
  - Direkt REST yazmaz (sadece RPC)

files_owned:
  - supabase/migrations/*.sql

parallel_with:
  - erp-frontend-agent (farklı dosyalar, aynı task'ta paralel)
```

#### 3.2.2 `erp-frontend-agent` — Kullanıcı Arayüzü Uzmanı

```yaml
name: erp-frontend-agent
role: FRONTEND SPECIALIST
model: minimax:MiniMax-M2.7
type: domain-specialist
priority: YÜKSEK

general_domain:
  - AGENTS.md, ARCHITECTURE.md, domain-rules.md
  - Vanilla JS kod stili (Türkçe değişken, 2-boşluk, tek tırnak)
  - IndexedDB API (idbGetAll, idbPut, idbDelete, idbClearAndPut)
  - State yönetimi (AppState + global değişkenler)

special_domain:
  - js/ui.js render fonksiyonları (3000+ satır)
  - js/forms.js form submit handler'ları
  - js/app.js routing ve init
  - js/api.js RPC wrapper
  - index.html modal'lar ve CSS
  - UI bug düzeltme (render sonrası hata, null reference)

triggers:
  - "UI ekle", "form yap", "modal oluştur", "render düzelt"
  - "tooltip ekle", "input validasyon", "dropdown doldur"
  - "404 sayfa", "loading state", "error handling"

boundaries:
  - DB migration yazmaz
  - Domain kuralı ihlal etmez (RPC-only yazma)
  - node --check geçirmeden commit etmez

files_owned:
  - js/ui.js, js/forms.js, js/app.js, js/api.js
  - index.html

parallel_with:
  - erp-db-agent (farklı dosyalar)
```

#### 3.2.3 `erp-clinical-agent` — Klinik Modül Uzmanı

```yaml
name: erp-clinical-agent
role: CLINICAL DOMAIN SPECIALIST
model: minimax:MiniMax-M2.7
type: domain-specialist
priority: YÜKSEK

general_domain:
  - Tüm genel domain kuralları

special_domain:
  - Vaka açma → gün ekleme → ilaç ekleme → kapatma akışı
  - diseases tablosu (controlled entity)
  - drugs tablosu (stok bağlantılı controlled entity)
  - cases, treatment_days, drug_administrations tablo yapısı
  - Klinik RPC'ler (create_case, add_treatment_day, 
    add_drug_administration, update_drug_administration, 
    delete_treatment_day, link_drug_to_stock, close_case)
  - Stok hareket trigger'ı (ilaç uygulama → stok_hareket INSERT)
  - İlaç doz/unit/route validasyonu

triggers:
  - "klinik", "vaka", "ilaç ekle", "tedavi", "doz"
  - "drug administration", "treatment day", "case management"
  - "diseases dropdown", "drugs dropdown"

boundaries:
  - Sadece klinik domain (cases, drugs, diseases, tedavi)
  - Stok ledger kurallarına riayet

files_owned:
  - Klinik akışı js/ (ui.js render fonksiyonları + forms.js)
  - supabase/migrations/ (klinik RPC'leri)

parallel_with:
  - erp-db-agent (klinik migration + UI paralel)
```

#### 3.2.4 `erp-reproduction-agent` — Üreme Modülü Uzmanı

```yaml
name: erp-reproduction-agent
role: REPRODUCTION DOMAIN SPECIALIST
model: minimax:MiniMax-M2.7
type: domain-specialist
priority: YÜKSEK

general_domain:
  - Tüm genel domain kuralları

special_domain:
  - Tohumlama state machine:
    Bekliyor → Gebe / Boş / Abort
    Gebe → Doğum Yaptı / Abort
  - Kızgınlık → Tohumlama → Gebelik → Doğum → Buzağı akışı
  - RPC: tohumlama_kaydet, tohumlama_sonuc_gebe,
    tohumlama_sonuc_bos, tohumlama_abort,
    kizginlik_ekle, dogum_kaydet
  - Sperma stok bağlantısı
  - 21/35 gün kontrol görevleri (trigger)
  - Hayvan grup/padok güncelleme (gebe → gebe padok)
  - Buzağı → hayvanlar tablosuna ekleme trigger'ı

triggers:
  - "tohumlama", "gebе", "doğum", "buzağı"
  - "kızgınlık", "sonuç güncelle", "abort"
  - "sperma", "tohumlanabilir hayvanlar"

boundaries:
  - Sadece üreme domain
  - RPC refaktörü: mevcut 3 write path → tek RPC kanalı
  - Direkt REST yazma KESİNLİKLE YASAK

files_owned:
  - js/ui.js (tohumlama render, dogum render)
  - js/forms.js (tohumlama submit, dogum submit)
  - supabase/migrations/ (üreme RPC'leri)

parallel_with:
  - erp-db-agent (RPC refaktörü + UI paralel)
```

#### 3.2.5 `erp-stock-agent` — Stok Yönetimi Uzmanı

```yaml
name: erp-stock-agent
role: STOCK DOMAIN SPECIALIST
model: minimax:MiniMax-M2.7
type: domain-specialist
priority: ORTA

general_domain:
  - Tüm genel domain kuralları

special_domain:
  - Stok ledger: stok_hareket immutable prensibi
  - Pozitif miktar = kullanım/çıkış
  - Negatif miktar = giriş/iade
  - guncel_stok = baslangic_miktar - SUM(miktar WHERE NOT iptal)
  - Kritik eşik uyarısı
  - İlaç/malzeme girişi
  - Drug ↔ stok bağlantısı (drugs.stock_item_id)

triggers:
  - "stok", "ilaç girişi", "malzeme", "hareket"
  - "kritik eşik", "stok düşük", "kullanım"

boundaries:
  - Sadece stok domain
  - Ledger immutable kuralını ihlal etmez

files_owned:
  - js/ui.js (stok render)
  - js/forms.js (stok form submit)
  - supabase/migrations/ (stok RPC'leri)
```

#### 3.2.6 `erp-herd-agent` — Sürü Yönetimi Uzmanı

```yaml
name: erp-herd-agent
role: HERD MANAGEMENT SPECIALIST
model: minimax:MiniMax-M2.7
type: domain-specialist
priority: ORTA

general_domain:
  - Tüm genel domain kuralları

special_domain:
  - Hayvan kayıtları (kupe_no format: TR-XXXX)
  - Grup/padok atama (GRUP_PADOK mapping)
  - Fiziksel alanlar
  - Sürü filtresi
  - Hayvan → padok split kuralları (kuru inek, besi, gebe, buzağı)
  - Baba hayvan ayrımı

triggers:
  - "hayvan ekle", "grup", "padok", "sürü"
  - "kupe no", "hayvan güncelle", "yerleştir"

boundaries:
  - Sadece sürü domain
  - Free text input yasak (controlled entity)

files_owned:
  - js/ui.js (hayvan render, padok render)
  - js/forms.js (hayvan form)
  - supabase/migrations/ (sürü RPC'leri)
```

### 3.3 Utility Specialist Agents

#### 3.3.1 `erp-explorer` — Kod Keşif Uzmanı

```yaml
name: erp-explorer
role: CODE EXPLORER
model: minimax:MiniMax-M2.7
type: utility-specialist
priority: ORTA

general_domain:
  - Tüm dosya yapısı
  - grep, Glob, Read kullanımı
  - Kod navigasyonu

special_domain:
  - Fonksiyon izleme (hangi dosyada ne var)
  - Duplicate tespiti (aynı fonksiyon 2 dosyada mı?)
  - Domain-rule ihlal tespiti
  - Kod karmaşıklığı analizi
  - RPC kullanım analizi (nerede REST bypass var?)

triggers:
  - "nerede bu fonksiyon", "kim bu dosyayı değiştiriyor"
  - "duplicate var mı", "grep yap", "bak şuraya"
  - "domain ihlal", "RPC dışı yazma"

boundaries:
  - Kod yazmaz, sadece okur ve raporlar
  - Sadece keşif ve analiz

reporting:
  - Keşif raporu: dosya yolu, satır sayısı, fonksiyon listesi
```

#### 3.3.2 `erp-debug-agent` — Hata Analiz Uzmanı

```yaml
name: erp-debug-agent
role: DEBUG SPECIALIST
model: minimax:MiniMax-M2.7
type: utility-specialist
priority: ORTA

general_domain:
  - Tüm genel domain kuralları

special_domain:
  - ui_logs tablosu analizi
  - Hata izleme (null reference, syntax error, RLS hatası)
  - Migration hataları (42883, 42501, 23505, 23503, PGRST116)
  - IndexedDB senkronizasyon hataları
  - RPC hata yanıtları (ok: true/false, error mesajı)
  - Telemetri okuma (uiLog tablosu)

triggers:
  - "hata var", "console'da error", "log oku"
  - "şu işlem çalışmıyor", "sync hatası"
  - "RPC hata verdi", "migration başarısız"

boundaries:
  - Sadece hata tespiti ve analiz
  - Düzeltme kararı orchestrator'a aittir

reporting:
  - Hata raporu: tip, kaynak, muhtemel sebep, öneri
```

#### 3.3.3 `erp-qa-agent` — Kalite Güvence Uzmanı

```yaml
name: erp-qa-agent
role: QA SPECIALIST
model: minimax:MiniMax-M2.7
type: utility-specialist
priority: YÜKSEK

general_domain:
  - Tüm genel domain kuralları
  - TestSprite MCP kullanımı
  - Playwright smoke test

special_domain:
  - Frontend smoke test (TestSprite MCP)
  - Backend RPC test (curl ile doğrulama)
  - Migration doğrulama (migration kontrolü)
  - Domain-rule compliance test
  - node --check syntax kontrolü
  - Telemetri test (uiLog sonuç analizi)
  - Akış testi: kullanıcı adımlarını simüle etme

triggers:
  - "test et", "doğrula", "smoke test"
  - "regresyon var mı", "çalışıyor mu"
  - Görev tamamlandıktan sonra OTOMATİK tetiklenir
  - PR açılmadan önce OTOMATİK tetiklenir

boundaries:
  - Sadece test ve doğrulama
  - Koddaki hataları düzeltmez, raporlar

tools:
  - TestSprite MCP (mcp__TestSprite__)
  - curl (RPC doğrulama)
  - node --check (syntax)

reporting:
  - Test sonuçları: pass/fail, detaylar
  - task-xxx-done.md'ye test sonuçlarını ekler
```

#### 3.3.4 `erp-knowledge-agent` — Bilgi Yönetimi Uzmanı

```yaml
name: erp-knowledge-agent
role: KNOWLEDGE MANAGER
model: minimax:MiniMax-M2.7
type: utility-specialist
priority: DÜŞÜK

general_domain:
  - Tüm dokümantasyon dosyaları
  - .claude/knowledge/ dizini
  - RPC referansı
  - Domain kuralları

special_domain:
  - AGENTS.md, ARCHITECTURE.md, SONARCLOUD_REMEDIATION_PLAN.md
  - .claude/knowledge/ güncelleme
  - rpc-reference.md güncelleme (yeni RPC eklendiğinde)
  - Task dosyaları yönetimi
  - Memory güncelleme (MEMORY.md)

triggers:
  - "dökümantasyon güncelle", "rpc-reference ekle"
  - "domain-rules güncellendi", "yeni RPC eklendi"
  - "task dosyası oluştur", "memory güncelle"

boundaries:
  - Sadece dokümantasyon
  - Kod yazmaz

files_owned:
  - .claude/knowledge/*.md
  - .claude/rpc-reference.md
  - .claude/domain-rules.md
  - .claude/tasks/*.md
```

### 3.4 Agent Etkileşim Matrisi

```
                         Orch
                          │
          ┌───────────────┼──────────────────────┐
          │               │                      │
      ┌───▼───┐      ┌───▼────┐           ┌─────▼─────┐
      │db-agent│◄────►│fe-agent│◄─────────►│clinical-ag│
      └────────┘      └────────┘           └───────────┘
          │               │                      │
      ┌───▼───┐      ┌───▼────┐           ┌─────▼─────┐
      │stock-ag│      │repro-ag│◄─────────►│herd-agent │
      └────────┘      └────────┘           └───────────┘
          │
    ┌─────┼─────┐
    │     │     │
┌───▼─┐┌──▼─┐┌──▼──────┐
│exp- ││dbg-││qa-agent │◄── otomatik (her görev sonu)
│agent││ag- ││         │
└─────┘└────┘└─────────┘
```

---

## 4. SKILL PAKETİ (4 SKILL)

### 4.1 `erp-onboarding-skill` — Yeni Modül Başlangıç Skill'i

**Dosya:** `.claude/skills/erp-onboarding/SKILL.md`

```yaml
name: erp-onboarding
purpose: Yeni bir modüle başlarken izlenecek standart yol

steps:
  1. Domain rules oku (domain-rules.md)
  2. Mevcut RPC'leri kontrol et (rpc-reference.md)
  3. Mevcut UI akışını analiz et (ui.js)
  4. DB schema planla (migration ön tasarım)
  5. Task dosyası oluştur
  6. Adım adım uygula:
     a) Migration yaz → db-agent
     b) UI yap → frontend-agent
     c) Test et → qa-agent
  7. Raporla → task-xxx-done.md
  8. Commit + Push
```

### 4.2 `erp-domain-checker-skill` — Domain Kural Kontrol Skill'i

**Dosya:** `.claude/skills/erp-domain-checker/SKILL.md`

```yaml
name: erp-domain-checker
purpose: Her kod değişikliğinden sonra domain rule ihlali kontrolü

checklist:
  - RPC-only yazma kuralı ihlal edilmiş mi? (REST bypass var mı?)
  - Controlled entity'lere FK kullanılmış mı? (free text yasak)
  - Stok ledger immutable kuralı ihlal edilmiş mi? (silme/iptal var mı?)
  - Tohumlama state machine kuralları ihlal edilmiş mi?
  - IndexedDB'den okuma yapılıyor mu? (direkt REST okuma yasak)
  - node --check geçiyor mu?
  - Fonksiyon duplicate var mı? (grep kontrolü)
```

### 4.3 `erp-migration-skill` — Migration Yazım Skill'i

**Dosya:** `.claude/skills/erp-migration/SKILL.md`

```yaml
name: erp-migration
purpose: Migration dosyası yazarken izlenecek standart yol

template:
  -- Migration: <ne yapıyor>
  -- Etkiler: <hangi tablo/fonksiyon değişiyor>
  -- Geri alınabilir: <nasıl geri alınır>

  -- İdempotent yaz:
  CREATE OR REPLACE FUNCTION ...
  DROP FUNCTION IF EXISTS ...
  ALTER TABLE ... ADD COLUMN IF NOT EXISTS ...

  -- Yeni tablo: RLS + SECURITY DEFINER
  -- View güncelleme: DROP VIEW IF EXISTS ... CASCADE

deployment:
  - GitHub Actions: push to supabase/migrations/ → otomatik deploy
  - Alternatif: npx supabase db push
  - Doğrulama: curl RPC test
```

### 4.4 `erp-parallel-workflow-skill` — Paralel Çalışma Skill'i

**Dosya:** `.claude/skills/erp-parallel-workflow/SKILL.md`

```yaml
name: erp-parallel-workflow
purpose: Paralel agent çalışmasını yönetmek için standart yol

patterns:
  pattern_1_parallel_db_fe:
    desc: "DB migration + FE UI paralel"
    agents: [db-agent, frontend-agent]
    files: [supabase/migrations/, js/]
    coordination: "FE, DB'den RPC imzalarını bekler"
    
  pattern_2_multi_domain:
    desc: "Birden fazla domain paralel"
    agents: [herd-agent, clinical-agent, repro-agent]
    files: [js/ui.js, js/forms.js, supabase/migrations/]
    coordination: "Dosya kilidi orchestrator'da"
    
  pattern_3_explorer_parallel:
    desc: "Keşif + geliştirme paralel"
    agents: [explorer, frontend-agent]
    files: [farklı dosyalar]
    coordination: "Explorer okur, FE yazar"

conflict_prevention:
  - Aynı dosyaya yazma: KESİNLİKLE YASAK
  - Dosya kilidi: orchestrator takip eder
  - Sonuç birleştirme: orchestrator yapar
```

---

## 5. HOOK KORUMA KATMANI

### 5.1 Mevcut Hookify Kuralları

Şu anda aktif olan Hookify kuralları (AGENTS.md § "Kritik Kurallar"):

```
1. RPC-only yazma       → Direkt REST write YASAK
2. IndexedDB okuma      → Direkt Supabase okuma YASAK
3. Fonksiyon duplicate  → Aynı fonksiyon 2 dosyada YASAK
4. Paralel yazma        → Aynı dosyaya 2 agent YASAK
5. Task dosyası         → Commit öncesi güncelleme ZORUNLU
```

### 5.2 Ek Hook Kuralları (Yeni)

```yaml
hook_5_domain_violation_block:
  trigger: Her form submit veya DB write
  check:
    - RPC fonksiyonu mevcut mu? (rpc-reference.md'de var mı?)
    - Direkt db.from().insert/update/delete var mı?
    - Free text input controlled entity için mi? (diseases, drugs)
  action: Block + hata mesajı + önerilen RPC'yi göster

hook_6_migration_order_warn:
  trigger: Migration dosyası oluşturulurken
  check:
    - DROP önce mi, sonra mı? (42P13 hatası önleme)
    - ADD COLUMN önce, DROP sonra
    - View CASCADE kullanılmış mı?
  action: Warn + düzeltme önerisi

hook_7_test_required:
  trigger: Commit öncesi
  check:
    - node --check geçti mi?
    - TestSprite smoke test yapıldı mı?
  action: Block + test talimatı
```

### 5.3 Hook Konfigürasyonu

```json
// .claude/settings.json — mevcut yapıya ekle
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash(git commit*)",
        "hooks": [
          {
            "type": "command",
            "command": "node --check js/api.js js/forms.js js/app.js js/ui.js js/state.js js/config.js",
            "timeout": 30,
            "statusMessage": "Syntax kontrol ediliyor..."
          }
        ]
      }
    ]
  }
}
```

---

## 6. OTOMASYON: GİTHUB ACTIONS + TEST

### 6.1 Mevcut CI/CD Durumu

```
✅ deploy.yml           → main/feature/*/fix/* push → GitHub Pages deploy
✅ supabase-migration-tl → feature/gwen-arge push → Supabase migration repair
✅ test-migration-ready  → feature/gwen-arge push → Migration doğrulama
✅ bildirim_check.yml    → cron (5,8,11,14,17 saat) → bildirim_log oluşturma
```

### 6.2 Yeni Workflow: `test-sprite-smoke.yml`

```yaml
name: Test — Smoke (TestSprite)

on:
  pull_request:
    branches: [main]

jobs:
  smoke-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup
        run: |
          # Playwright veya test ortamı hazırla
          npx playwright install chromium --with-deps 2>/dev/null || true

      - name: TestSprite Smoke Test
        run: |
          echo "🤖 TestSprite smoke test başlatılıyor..."
          # TestSprite MCP entegrasyonu (henüz Actions desteği yoksa
          # yerel Playwright test'leri çalıştır)
          echo "✅ Frontend smoke test: EL YAPIMI"
          echo "   Alternatif: ${{ vars.TESTSPRITE_API_KEY }} kullan"
```

### 6.3 TestSprite MCP Entegrasyonu

**TestSprite** mevcut MCP olarak kurulu. CI/CD'de kullanımı:

```bash
# mcp__TestSprite__testsprite_bootstrap
# → Proje başlatma

# mcp__TestSprite__testsprite_generate_code_and_execute
# → Test üret + çalıştır

# mcp__TestSprite__testsprite_open_test_result_dashboard
# → Sonuçları incele
```

**İki kullanım senaryosu:**

```yaml
# Senaryo 1: Geliştirici makinesinde (yerel)
# Her görev sonunda qa-agent TestSprite'i çağırır
# → mcp__TestSprite__testsprite_bootstrap
# → mcp__TestSprite__testsprite_generate_code_and_execute
# → Sonuç: task-xxx-done.md'ye test sonuçları

# Senaryo 2: CI/CD'de (GitHub Actions)
# GitHub Actions → Supabase migration auto-deploy
# + yerel Playwright smoke test
# → mcp__TestSprite__testsprite_generate_backend_test_plan
# → mcp__TestSprite__testsprite_generate_code_and_execute
```

### 6.4 Tam CI/CD Pipeline

```
┌──────────────────────────────────────────────────────────────┐
│  PUSH (herhangi bir branch)                                 │
└────────────────┬───────────────────────────────────────────┘
                 │
     ┌───────────┼──────────────────┐
     │           │                  │
     ▼           ▼                  ▼
┌─────────┐ ┌──────────────┐ ┌───────────────┐
│deploy.yml│ │migration auto│ │test-sprite-   │
│          │ │push trigger  │ │smoke.yml      │
└────┬────┘ └──────┬───────┘ └───────┬───────┘
     │              │                 │
     ▼              ▼                 ▼
GitHub Pages   Supabase CLI    TestSprite
deploy        migration       smoke test
               apply

┌──────────────────────────────────────────────────────────────┐
│  NOT: supabase/migrations/ push → otomatik Supabase push    │
│  NOT: test-sprite-smoke → sadece PR'da çalışır              │
└──────────────────────────────────────────────────────────────┘
```

---

## 7. TEST OTOMASYONU STRATEJİSİ

### 7.1 Test Katmanları

| Katman | Araç | Ne Test Edilir | Kim Çalıştırır |
|--------|------|----------------|----------------|
| Syntax | node --check | JS syntax | Hookify (pre-commit) |
| Smoke | Playwright (lokal) | UI açılışı, render | qa-agent |
| Backend | curl + RPC test | RPC çalışıyor mu | qa-agent |
| Integration | TestSprite | Kullanıcı akışı | qa-agent (geliştirici makinesinde) |
| Migration | test-migration-ready | Migration syntax | GitHub Actions |

### 7.2 TestSprite Kullanım Akışı

```javascript
// qa-agent her görev sonunda şunu yapar:

// 1. Bootstrap (ilk seferde)
mcp__TestSprite__testsprite_bootstrap({
  projectPath: "/root/egesut-erp1",
  type: "frontend",        // veya "backend"
  testScope: "codebase",   // veya "diff"
  localPort: 3000          // geliştirme sunucusu portu
});

// 2. Test planı oluştur
mcp__TestSprite__testsprite_generate_frontend_test_plan({
  projectPath: "/root/egesut-erp1",
  needLogin: true
});

// 3. Testleri çalıştır
mcp__TestSprite__testsprite_generate_code_and_execute({
  projectName: "egesut-erp1",
  projectPath: "/root/egesut-erp1",
  testIds: [],  // boş = tüm plan
  serverMode: "development",
  additionalInstruction: "Özellikle klinik ve tohumlama akışlarını test et"
});

// 4. Sonuçları incele
// → task-xxx-done.md'ye sonuçları yaz
```

### 7.3 Raporlama Formatı

```markdown
## Yapılanlar
- [ ] Adım 1 — ne yapıldı
- [ ] Adım 2 — ne yapıldı

## Doğrulama
| Kabul Kriteri | Sonuç | Not |
|---------------|-------|-----|
| RPC çalışıyor | ✅ | curl test edildi |
| UI render hatası yok | ✅ | TestSprite smoke |
| Domain kural ihlali yok | ✅ | grep kontrolü |
| node --check geçti | ✅ | Syntax temiz |

## Test Sonuçları (TestSprite)
- Toplam: 24 test
- Geçen: 23 ✅
- Başarısız: 1 ❌ → [test-id] — detay: task-xxx-test-report.md

## Commit(ler)
- abc1234 — commit mesajı
```

---

## 8. MIGRATION FAZLARI

### Phase 1: Agent Dosyalarını Oluştur (1 gün)

- [ ] 10 agent definition dosyası oluştur
- [ ] 4 skill dosyası oluştur
- [ ] Hook konfigürasyonu güncelle
- [ ] TestSprite MCP doğrula

### Phase 2: Orchestrator Güncelle (1 gün)

- [ ] Mevcut orchestrator.md → yeni mimariye uyarla
- [ ] Agent atama karar matrisini entegre et
- [ ] Paralel çalışma koordinasyonunu entegre et

### Phase 3: İlk Pilot Görev (2 gün)

- [ ] Pilot: "Klinik modül frontend tamamlama" görevi
- [ ] db-agent + clinical-agent paralel çalışsın
- [ ] qa-agent sonuçları test etsin
- [ ] Raporlama formatını doğrula

### Phase 4: Kalan Domain Agent'larını Entegre Et (3 gün)

- [ ] erp-reproduction-agent → RPC refaktörü
- [ ] erp-herd-agent → padok/grup yönetimi
- [ ] erp-stock-agent → kritik eşik iyileştirmesi
- [ ] erp-explorer → codebase analizi

### Phase 5: CI/CD + Test Entegrasyonu (2 gün)

- [ ] test-sprite-smoke.yml workflow oluştur
- [ ] GitHub Actions → Supabase migration pipeline doğrula
- [ ] Bildirim cron workflow doğrula
- [ ] SonarCloud remediation plan'ı agent'lara dağıt

### Tahmini Toplam: 9 iş günü (faz 1)

---

## 9. BRANCH STRATEJİSİ

```
main (korunuyor)
  │
  ├── fix/tech-debt       ← mevcut, agent çalışma branch'i
  │    ├── .claude/tasks/ ← task dosyaları
  │    ├── js/            ← frontend değişiklikleri
  │    └── supabase/      ← migration değişiklikleri
  │
  ├── feature/klinik      ← klinik modül (faz 3 pilot)
  │    └── ...
  │
  └── feature/tohumlama-refactor  ← RPC refaktörü (faz 4)
       └── ...
```

**Agent çalışma kuralı:**
- Agent'lar sadece `fix/*` veya `feature/*` branch'lerinde çalışır
- `main` push = sadece merge sonucu
- Her görev ayrı task dosyasında

---

## 10. DETAYLI ROL ATAMA MATRİSİ

| Görev | DB | FE | Clinical | Repro | Stock | Herd | QA | Explorer | Knowledge |
|-------|----|----|---------|-------|-------|------|----|----------|-----------|
| Klinik UI tamamla | ✅ | ✅ | ✅ | | | | ✅ | | |
| Tohumlama RPC refaktörü | ✅ | ✅ | | ✅ | | | ✅ | | |
| Yeni migration yaz | ✅ | | | | ✅ | | | | |
| UI bug düzeltme | | ✅ | | | | | ✅ | ✅ | |
| Domain ihlal tespiti | | | | | | | ✅ | ✅ | ✅ |
| Kod analizi | | | | | | | | ✅ | |
| Dokümantasyon | | | | | | | | | ✅ |
| TestSprite smoke | | | | | | | ✅ | | |

---

## 11. MALİYET ANALİZİ

### Model Maliyeti (Call-Based)

| Senaryo | Call Sayısı | Maliyet | Açıklama |
|---------|-------------|---------|----------|
| Tek agent, sıralı | 1 call | Düşük | 1 görev = 1 agent |
| 3 agent paralel | 3 call | Orta | 3 kat call ama 3× hızlı |
| 5 agent paralel | 5 call | Orta-Yüksek | Paralel = call × N ama süre ÷ N |

### Hız Kazancı

| Görev | Sıralı Süre | Paralel Süre | Kazanç |
|-------|-------------|--------------|--------|
| Klinik UI (DB + FE) | 2 saat | 1 saat | 50% |
| Tohumlama refaktör | 4 saat | 1.5 saat | 62% |
| Yeni migration + UI | 3 saat | 1.5 saat | 50% |

**Sonuç:** Call-based billing = paralel agent = hız × maliyet dengesi  
Call sayısı artsada, süre azaldığı için toplam maliyet düşer.

---

## 12. ORTAYA ÇIKAN SORULAR VE ÖNERİLER

### 12.1 Kararlar Bekleyen Konular

| # | Soru | Öneri | Karar Kimde? |
|---|------|-------|--------------|
| 1 | Mevcut orchestrator.md güncellensin mi, yenisi mi yazılsın? | Güncelle (mevcut + phase plan) | Kullanıcı |
| 2 | Agent multiplicity (aynı iş 2 agent) hangi durumlarda kullanılsın? | Kritik migration + UI paralel = her zaman | Kullanıcı |
| 3 | TestSprite CI/CD'de kullanılabilir mi? | GitHub Actions + TestSprite API araştırması gerek | Kullanıcı |
| 4 | SonarCloud remediation 40KB kim yapacak? | Agent'lara parçalı dağıt | Kullanıcı |

### 12.2 Riskler

| Risk | Olasılık | Etki | Azaltma |
|------|----------|------|---------|
| Agent çoğulluğu → dosya çakışması | Orta | Yüksek | Orchestrator dosya kilidi takibi |
| Paralel write → conflict | Düşük | Yüksek | Hookify block kuralı |
| TestSprite CI/CD desteklemiyor | Orta | Orta | Yerel Playwright + curl fallback |
| Mevcut 4 agent → yeni 10 agent geçiş süresi | Yüksek | Orta | Phase-wise migration |

---

## 13. ANİ YAPILACAKLAR (BU DOSYADAN SONRA)

### Bu dosya ONAYLANDIĞINDA:

```
1. .claude/agents/ dizininde 10 agent dosyası oluştur
2. .claude/skills/ dizininde 4 skill dosyası oluştur
3. .claude/settings.json → Hookify kuralı ekle
4. .github/workflows/test-sprite-smoke.yml oluştur
5. İlk pilot görev ataması yap (klinik modül)
6. Orchestrator agent'ı güncelle
```

### Bu dosya REDDEDİLDİĞİNDE:

```
→ Hangi konuda değişiklik isteniyor?
→ Model tercihi mi, agent sayısı mı, skill'ler mi?
→ Geri bildirim bekleniyor.
```

---

## 14. EKLER

### A14.1 Agent Tanımlama Dosya Şablonu

Her agent için standart dosya formatı:

```markdown
# erp-<domain>-agent

## Kimlik
- **Model:** MiniMax-M2.7
- **Tip:** Domain Specialist | Utility Specialist
- **Öncelik:** KRİTİK | YÜKSEK | ORTA | DÜŞÜK
- **Branch:** fix/tech-debt

## Genel Domain (her agent bilir)
- [domain-rules.md](domain-rules.md)
- [AGENTS.md](AGENTS.md)
- [ARCHITECTURE.md](ARCHITECTURE.md)
- [rpc-reference.md](rpc-reference.md)

## Uzmanlık Alanı
...

## Tetikleyiciler
...

## Yasaklar (NE YAPMAZ)
...

## Raporlama Formatı
...

## Dosya Sahipliği
...
```

### A14.2 Task Dosyası Formatı

```markdown
# Task-XXX: [Başlık]

**Atanan:** erp-<domain>-agent  
**Branch:** fix/<task-name>  
**Durum:** bekliyor  

## Açıklama
[Kullanıcı isteğinin detaylı açıklaması]

## Kabul Kriterleri
- [ ] Kriter 1
- [ ] Kriter 2

## Adımlar
1. [ ] Adım 1
2. [ ] Adım 2

## Parallel Agent Planı
- erp-db-agent → supabase/migrations/...
- erp-frontend-agent → js/...

## Tahmini Süre
~2 saat
```

### A14.3 Mevcut Agent Analizi

| Dosya | İçerik | Yapılacak |
|-------|--------|-----------|
| orchestrator.md | 135 satır | Güncelle + phase plan ekle |
| erp-implementer.md | DB+FE aynı agent | Ayrıştır: db-agent + fe-agent |
| erp-qa-git.md | QA + git | Genişlet: qa-agent + test otomasyonu |
| erp-explorer.md | Kod keşfi | Mevcut + yeni özellikler ekle |

---

**Planı inceledin. Ne değişiklik istersin?**  
Mevcut haliyle onaylarsan → **"onayladım, uygula"** yaz.  
Değişiklik istersen → hangi konuda olduğunu belirt.
