# Hibrit Mimari Stratejisi — Dış Template + Custom Domain

> **Tarih:** 2026-04-04  
> **Konu:** Ne kendimiz yapalım, ne sadece hazır alalım — HİBRİT  
> **Cevap:** VoltAgent/Antigravity/Plugin template'lerini TEMEL AL, EgeSüt domain bilgisi ile ÖZELLEŞTİR  

---

## 0. MEVCUT DURUM TESPİTİ

### 0.1 Elimizde Ne Var?

```
📦 DIŞ KAYNAKLAR
├── VoltAgent awesome-claude-code-subagents
│   ├── 130+ agent template (10 kategori)
│   ├── backend-developer, frontend-developer, qa-expert, debugger...
│   └── Format: YAML header + talimatlar + invocation order
│
├── Antigravity awesome-skills
│   ├── 1,344+ skill (agentic-engineering, db-migrations, postgres-patterns...)
│   └── Format: SKILL.md + references/
│
├── Claude Code Plugin Agents (AKTİF)
│   ├── feature-dev/code-architect.md    ← KULLANILABİLİR
│   ├── feature-dev/code-explorer.md      ← KULLANILABİLİR
│   ├── feature-dev/code-reviewer.md      ← KULLANILABİLİR
│   ├── code-review/plugin (komut tabanlı)
│   └── claude-md-improver (dokümantasyon)
│
└── Mevcut EgeSüt Agent'ları
    ├── orchestrator.md    (135 satır) — güncellenmeli
    ├── erp-implementer.md — DB+FE aynı agent
    ├── erp-qa-git.md      — model: Haiku (yetersiz)
    └── erp-explorer.md    — temel çalışıyor
```

### 0.2 Senin Soruların — Tek Tek Cevaplar

#### ❓ "Her şeyi custom mı yapacağız?"

**HAYIR.** 3 katmanlı yaklaşım:

```
┌─────────────────────────────────────────────────────────────┐
│  KATMAN 1: DIŞ TEMPLATE (Hazır, sadece adaptasyon)         │
│  → VoltAgent agent template'lerini KOPYALA + domain enjekte │
│  → 5-10 dakikalık iş, sıfırdan yazmaktan 100× daha hızlı   │
│                                                             │
│  KATMAN 2: CUSTOM SKILL (Hiçbir yerde yok, sıfırdan yaz)  │
│  → EgeSüt domain kuralları (RPC-only, ledger, state mach.)│
│  → Mimariye özgü workflow'lar (SonarCloud remediation)      │
│                                                             │
│  KATMAN 3: MEVCUTTAN GÜÇLENDİR (İyileştir, yeniden yazma) │
│  → orchestrator.md, erp-implementer.md → adaptasyon        │
└─────────────────────────────────────────────────────────────┘
```

#### ❓ "Agentların toolları ve skill'leri belli mi?"

**EVET.** Şöyle belirlenecek:

| Agent | Base Template | Domain Injection | Tools (MCP dahil) |
|-------|-------------|-----------------|-------------------|
| `erp-db-agent` | VoltAgent `backend-developer.md` | EgeSüt SQL/RPC/Supabase rules | `gwen-supabase`, `mcp__supabase__*` |
| `erp-frontend-agent` | VoltAgent `frontend-developer.md` | Vanilla JS + IndexedDB rules | Read, Edit, Glob, Grep, Bash |
| `erp-qa-agent` | Plugin `code-reviewer.md` + VoltAgent `qa-expert.md` | TestSprite + EgeSüt test akışı | `mcp__TestSprite__*`, curl, node |
| `erp-debug-agent` | VoltAgent `debugger.md` | EgeSüt error patterns | `mcp__supabase__get_logs` |
| `erp-architect` | Plugin `code-architect.md` | EgeSüt schema/RPC contract | Read, Glob, Grep |
| `erp-explorer` | Plugin `code-explorer.md` + Custom | EgeSüt fonksiyon haritası | Glob, Grep, Read |
| `erp-knowledge-agent` | Custom | Dokümantasyon yönetimi | Read, Write, Edit |

**Her agent'ın tam tool listesi belli — template'lerde tanımlı.**

#### ❓ "Mix yapabilir miyiz?"

**EVET, HİBRİT.** Şu strateji:

```
STRATEJİ: TEMPLATE BASE + DOMAIN LAYER

VoltAgent/Plugin Template
  ├── name, description, model
  ├── tools listesi
  ├── invocation order / process
  └── generic kod kalitesi kuralları
        ↓ adaptasyon
  + EgeSüt Domain Layer (eklenir)
        ├── RPC-only yazma kuralı
        ├── Domain kuralları (13 madde)
        ├── Supabase MCP kullanımı
        ├── Türkçe kod stili
        ├── Commit formatı
        ├── Task döngüsü
        └── Hookify koruma referansı
              ↓ sonuç
  = ERP-Specific Agent (10 dakikada hazır)
```

#### ❓ "Agent eğitimi nasıl yapılacak?"

**İki aşama:**

```
FAZ 1: BOOTSTRAP (1-2 saat) — ilk agentları kur
│
├── 1. VoltAgent template'leri oku (dakika 1-30)
│   → backend-developer.md, frontend-developer.md, qa-expert.md, debugger.md
│
├── 2. Her template'e EgeSüt domain layer ekle (dakika 31-120)
│   → ~5-10 dakika / agent × 7 agent = ~1 saat
│   → Sadece Ekle: "Sen EgeSüt ERP için çalışıyorsun, bunları bilmelisin"
│
└── 3. İlk test görevi çalıştır (dakika 121-180)
    → Küçük bir UI bug fix
    → Agent nasıl davrandığını gör
    → Prompt'ta ince ayar

FAZ 2: ITERATIF OGRENME (sürekli) — agentlar görevlerden öğrenir
│
├── Her görev sonunda feedback döngüsü
│   → Agent iyi yaptı mı? → Agent prompt'unu GÜÇLENDİR
│   → Agent hata yaptı mı? → Domain layer'a YENİ KURAL EKLE
│
├── TestSprite sonuçları → agent'a öğretici sinyal
│   → "QA agent şunu kaçırdı" → agent prompt'una ekle
│
└── MEMORY dosyası → agent'ın kalıcı hafızası
    → MEMORY.md güncellenir her önemli karardan sonra
    → Yeni agent spawn edildiğinde MEMORY otomatik okunur
```

---

## 1. TAM HİBRİT PLAN

### 1.1 Mimari Formül

```
MİMARİ = (Dış Template × Domain Bilgi) + Custom Skill + Hookify Koruma
```

### 1.2 Agent Oluşturma Prosedürü (Standart)

Her agent için şu 4 adım izlenecek:

**Adım 1 — Template seç:**
```
ERP görevi → "Bu hangi VoltAgent/Plugin template'e en yakın?"
  DB işi      → backend-developer.md
  FE işi      → frontend-developer.md
  QA işi      → code-reviewer.md + qa-expert.md
  Debug       → debugger.md
  Mimari      → code-architect.md
  Keşif       → code-explorer.md
  Domain-özel → CUSTOM (klinik, üreme, stok, sürü)
```

**Adım 2 — Template'i oku ve adapte et:**
```
 VoltAgent template'ten AL:
   ├── name, description, model
   ├── tools listesi
   ├── 3-5 adımlık process / invocation order
   └── quality criteria

 EgeSüt domain layer OLARAK EKLE:
   ├── ## Genel Domain (tüm agent'ların bildiği)
   ├── ## Özel Domain (bu agent'ın uzmanlık alanı)
   ├── ## Yasaklar (NE YAPMAZ)
   ├── ## EgeSüt Tools (Supabase MCP, TestSprite, vs)
   └── ## Raporlama Formatı
```

**Adım 3 — Skill ataması yap:**
```
Domain'e özel skill varsa kullan (Antigravity + custom)
  Database işi     → Antigravity: db-migrations, postgres-patterns
  Test işi         → Custom: erp-domain-checker
  Migration yazımı → Custom: erp-migration
  Onboarding       → Custom: erp-onboarding
```

**Adım 4 — Hookify korumasını entegre et:**
```
Agent çalışırken hangi hook'lar koruyacak?
  DB write         → block-direct-db-writes
  Syntax           → pre-commit node --check
  Duplicate fn     → warn-duplicate-functions
  Domain violation → custom: warn-domain-rule
```

---

## 2. TEMPLATE KAYNAK MATRİSİ

### 2.1 VoltAgent Templates (Alınacak / Adapt Edilecek)

| VoltAgent Template | Hedef Agent | Adaptasyon |
|--------------------|------------|------------|
| `backend-developer.md` | `erp-db-agent` | + Supabase RPC rules, + idempotent migration, + EgeSüt schema |
| `frontend-developer.md` | `erp-frontend-agent` | + Vanilla JS, + IndexedDB, + Türkçe kod stili |
| `qa-expert.md` | `erp-qa-agent` | + TestSprite MCP, + curl RPC test, + EgeSüt smoke test |
| `debugger.md` | `erp-debug-agent` | + Supabase log okuma, + EgeSüt error codes |
| `code-reviewer.md` (plugin) | `erp-qa-agent` | + Domain-rule compliance, + confidence scoring |
| `code-architect.md` (plugin) | `erp-architect` | + Supabase schema design, + RPC contract |

### 2.2 Custom Yazılacak Agent'lar (Dışında Yok)

| Custom Agent | Neden Custom | Domain |
|-------------|-------------|--------|
| `erp-clinical-agent` | Klinik domain bilgisi | cases, drug_administrations, treatment_days |
| `erp-reproduction-agent` | Tohumlama state machine | kızgınlık → tohumlama → gebelik → doğum |
| `erp-stock-agent` | Stok ledger prensibi | immutable ledger, kritik eşik |
| `erp-herd-agent` | Sürü yönetimi | padok/grup, TR-XXXX format |
| `erp-knowledge-agent` | Dokümantasyon yönetimi | .claude/knowledge/, MEMORY.md |

### 2.3 Antigravity Skills (Doğrudan Kullanılabilir)

| Antigravity Skill | Kullanım | Nasıl |
|-----------------|---------|-------|
| `agentic-engineering/` | Agent oluşturma workflow'u | Referans olarak oku, adapt et |
| `database-migrations/` | Migration yazım pattern'leri | SKILL.md'den kuralları al |
| `postgres-patterns/` | PostgreSQL best practices | EgeSüt RPC'lerde uygula |
| `codebase-onboarding/` | Yeni codebase'e adaptasyon | erp-onboarding skill için temel |
| `continuous-agent-loop/` | Agent loop prevention | orchestrator'da uygula |

---

## 3. AGENT EĞİTİM PROSEDÜRÜ

### 3.1 Bootstrap Aşaması (İlk Kurulum)

```
SAAT 0-0.5  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
│  Template'leri oku
│  → VoltAgent backend-developer.md
│  → VoltAgent frontend-developer.md  
│  → Plugin code-reviewer.md
│  → Plugin code-architect.md
│  → VoltAgent qa-expert.md
│  → VoltAgent debugger.md
│
SAAT 0.5-1.5 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
│  6 agent dosyası oluştur (her biri ~10 dk)
│  → Adapte edilmiş template + EgeSüt domain layer
│  → Standart format: YAML header + process + domain + tools
│
SAAT 1.5-2.0 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
│  4 custom skill dosyası oluştur
│  → erp-domain-checker, erp-migration, erp-onboarding
│  → Antigravity skill'lerden referans al
│
SAAT 2.0-2.5 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
│  Hook konfigürasyonu
│  → Mevcut Hookify kurallarını agent'lara entegre et
│  → Yeni hook'ları .claude/settings.json'a ekle
│
SAAT 2.5-3.0 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
│  Pilot görev
│  → Küçük bir UI bug fix → agent'ı test et
│  → Davranışı gözle → prompt'ta ince ayar
```

**Toplam ilk kurulum: ~3 saat**

### 3.2 İteratif Öğrenme Döngüsü (Sürekli)

```
HER GÖREV ─────────────────────────────────────────────
│
├─ Agent görevi tamamlar
│
├─ QA agent test eder (TestSprite + curl)
│   ├─ GEÇTİ  → Görev tamam
│   └─ KALDI  → Hata analizi
│
├─ Hata varsa → Root cause analizi
│   ├─ "Agent domain kuralını bilmiyordu"
│   │     → Domain layer'a yeni kural EKLE
│   │     → Agent prompt'unu GÜNCELLE
│   │
│   ├─ "Agent template'i yanlış kullandı"
│   │     → Template adaptasyonunu DÜZELT
│   │
│   └─ "Yeni bir pattern ortaya çıktı"
│         → MEMORY.md'ye KAYDET
│         → Gerekirse yeni skill dosyası OLUŞTUR
│
└─ Görev kapanır → MEMORY güncellenir
      → "Bu görevde öğrenilen: ..."
      → "Bir sonraki benzer görevde dikkat: ..."
```

### 3.3 Agent Knowledge Base (Kalıcı Hafıza)

```
MEMORY.md içeriği (her agent için):
├── Domain uzmanlıkları (neyi bilir)
├── Bilinen hata kalıpları (neyi yapmaz)
├── Başarılı workflow'lar (nasıl çalışır)
├── Son düzeltmeler (ne değiştirildi, neden)
└── Kullanılan template kaynağı ( VoltAgent #.## )
```

---

## 4. SKILL ENJEKSİYON PROSEDÜRÜ

### 4.1 Skill Atama Kuralları

```
Her görev atandığında → Orchestrator şunu yapar:

1. Görevin domain'ini belirle
   → Klinik / Üreme / Stok / Sürü / Genel
   
2. İlgili skill'leri listele
   → Genel: erp-domain-checker (her görevde)
   → Migration: erp-migration (DB işi varsa)
   → Onboarding: erp-onboarding (yeni modül başlangıcı)
   
3. Skill dosyalarını agent'a reference olarak ver
   → "Bu görevde şu skill'leri kullanmalısın: ..."
   
4. Antigravity referans varsa ekle
   → "PostgreSQL işi yapıyorsan: Antigravity/postgres-patterns/"
```

### 4.2 Skill Dosyası Şablonu

```yaml
# .claude/skills/<skill-name>/SKILL.md
name: <skill-name>
purpose: <ne için>
domain: <hangi domain>

## Ne Zaman Kullanılır
<trigger kuralları>

## Workflow Adımları
<adım 1>
<adım 2>

## EgeSüt'e Özgü Kurallar
<domain rule inject>

## Referans Kaynaklar
- VoltAgent/Antigravity: <varsa>
- Mevcut örnek: <dosya yolu>
```

---

## 5. DOĞRUDAN KULLANILABİLİR TEMPLATE KAYNAKLARI

### 5.1 VoltAgent — Tam Kullanılabilir

```
backend-developer.md
  ├── SQL/Migration uzmanlığı
  ├── Supabase/PostgreSQL pattern'leri
  └── Invocation order: analyze → design → implement

frontend-developer.md
  ├── Vanilla JS pattern'leri (adaptasyon gerekli)
  ├── Component structure
  └── Invocation order: understand → implement → verify

qa-expert.md
  ├── Test plan oluşturma
  ├── Smoke test, regression test
  └── Invocation order: analyze → plan → execute → report

debugger.md
  ├── Error pattern recognition
  ├── Root cause analysis
  └── Invocation order: reproduce → investigate → fix
```

### 5.2 Plugin Agents — Doğrudan Kullanılabilir

```
feature-dev/code-architect.md
  ├── Mevcut: ✅ Var, 35 satır — çok iyi
  ├── Kullanım: Schema tasarımı, RPC contract, büyük feature planı
  └── Adaptasyon: EgeSüt schema + RPC pattern ekle

feature-dev/code-explorer.md
  ├── Mevcut: ✅ Var, kullanılıyor
  ├── Kullanım: Fonksiyon izleme, duplicate tespit
  └── Adaptasyon: EgeSüt dosya haritası ekle

feature-dev/code-reviewer.md
  ├── Mevcut: ✅ Var, 40+ satır — çok detaylı
  ├── Kullanım: PR review, confidence scoring
  └── Adaptasyon: Domain-rule compliance ekle
```

### 5.3 Antigravity — Referans Olarak Alınabilir

```
agentic-engineering/SKILL.md
  ├── Agent oluşturma workflow
  └── → Mimariyi buradan AL, EgeSüt'e adaptasyon YAP

database-migrations/SKILL.md
  ├── Idempotent migration pattern
  └── → EgeSüt migration rule'ları ile birleştir

postgres-patterns/SKILL.md
  ├── PostgreSQL best practices
  └── → EgeSüt RPC'lerde uygula
```

---

## 6. UYGULAMA SIRASI

### 6.1 Adım 1: Template'leri Topla (30 dakika)

```
1. VoltAgent awesome-claude-code-subagents indir:
   → /tmp/voltagent/agents/ altına
   
2. İlgili template'leri oku:
   → backend-developer.md
   → frontend-developer.md
   → qa-expert.md
   → debugger.md

3. Plugin agent'ları oku:
   → code-architect.md
   → code-reviewer.md
```

### 6.2 Adım 2: Adaptasyon (2 saat)

```
Her agent için:
1. Template dosyasını kopyala
2. YAML header'ı güncelle (name, description, model)
3. EgeSüt domain layer ekle
4. Tool listesi güncelle (Supabase MCP ekle)
5. Raporlama formatı ekle
```

### 6.3 Adım 3: Custom Agent'lar (1 saat)

```
5 custom agent (klinik, üreme, stok, sürü, knowledge):
→ Sıfırdan yazılacak ama ~20-30 satır / agent
→ Domain bilgisi + standart format
```

### 6.4 Adım 4: Skill Dosyaları (30 dakika)

```
4 skill dosyası oluştur:
→ erp-onboarding, erp-domain-checker, erp-migration, erp-parallel-workflow
→ Antigravity'den format al, EgeSüt'e adapte et
```

### 6.5 Adım 5: Pilot Test (1 saat)

```
→ Küçük bir görev seç (UI bug fix veya basit RPC ekleme)
→ Agent'ları test et
→ Davranışı gözle
→ Prompt'ta düzeltme yap
```

**Toplam: ~5 saat**

---

## 7. CEVAPLAR — TEK LİSTE

| Soru | Cevap |
|------|-------|
| Custom mı, hazır mı? | **HİBRİT** — template base + domain layer |
| Agent toolları belli mi? | **EVET** — template'lerde tanımlı, adaptasyonla netleşir |
| Ne zaman mix? | DB/FE/QA/Debug → external template. Domain-özel → custom |
| Agent eğitimi nasıl? | Bootstrap (3 saat) + iteratif feedback (sürekli) |
| Kaynak yeterli mi? | **EVET** — VoltAgent 130+, Antigravity 1,344+, Plugin agents |
| Ne kadar zaman? | ~5 saat ilk kurulum, pilot test dahil |

---

## 8. KARAR BEKLEYEN

```
1. Hangi VoltAgent template'leri önce adapte edilsin?
   → Öneri: erp-db-agent (en çok iş yapacak) + erp-frontend-agent
   
2. Agent multiplicity (aynı iş 2 agent) hangi durumlarda?
   → Öneri: Büyük migration + büyük UI aynı anda
   
3. Custom agent sayısı kaç olsun?
   → Öneri: 5 custom (klinik, üreme, stok, sürü, knowledge)
   
4. Skill'ler nereye?
   → Öneri: .claude/skills/<skill-name>/SKILL.md
```

---

**Sıradaki adım:**  
→ Bu stratejiyi onayla → **"onayladım, template'leri topla"**  
→ Hangi değişiklik? → **hangisini söyle**  
→ Alternatif? → **"sadece custom yapalım"** veya **"sadece hazır alalım"**
