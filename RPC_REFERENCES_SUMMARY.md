# RPC References in Memory System - Summary Report

**Generated:** 2026-04-05  
**System:** EgeSüt ERP  
**Database:** Supabase (PostgreSQL + RPC)  

---

## 📊 Executive Summary

The memory system contains **comprehensive RPC documentation** with 5 dedicated memory notes and 123 knowledge graph relationships. RPC is a **critical architectural pattern** enforced throughout the codebase with strict "no direct REST" rules.

### Key Metrics

| Metric | Count |
|--------|-------|
| Memory Notes mentioning RPC | 5 |
| RPC-specific category notes | 1 |
| Knowledge Graph RPC entities | 1 |
| RPC-related relationships | 123 |
| Total RPC functions documented | 22 |

---

## 🗄️ Memory Database Findings

### RPC-Referenced Notes

#### 1. **Tech Stack Configuration** (ID: 2)
- **Category:** `tech_stack`
- **Priority:** Medium | **Confidence:** 1.0
- **Content:**
  ```
  Frontend: Vanilla JS PWA, tek index.html, build step yok 
  Backend: Supabase (PostgreSQL + RPC) 
  Cache: IndexedDB 
  Migration: GitHub Actions → Supabase CLI 
  DB: zqnexqbdfvbhlxzelzju
  ```
- **Key Point:** RPC is explicitly listed as core backend technology

#### 2. **File Structure** (ID: 3)
- **Category:** `file_structure`
- **Content Highlights:**
  - `js/api.js` — Supabase client, IndexedDB, RPC (~335 satır)
  - `js/forms.js` — Form submit, RPC (~941 satır)
- **Key Point:** RPC usage is concentrated in API layer and form submissions

#### 3. **Critical Rules** (ID: 4)
- **Category:** `critical_rules`
- **Rule #1:** Sadece RPC ile yaz — direkt REST INSERT/UPDATE/DELETE YASAK
- **Key Point:** RPC-first development is mandatory, not optional

#### 4. **RPC Reference** (ID: 6) ⭐
- **Category:** `rpc_reference`
- **Priority:** Medium | **Confidence:** 1.0
- **Source:** json_migration
- **Complete RPC List:**
  ```
  Tüm RPC'ler jsonb döndürür: {ok: boolean, ...}
  
  Hayvan: hayvan_ekle, hayvan_guncelle, hayvan_not_ekle
  
  Üreme: tohumlama_kaydet, tohumlama_sonuc_gebe, tohumlama_sonuc_bos, 
         dogum_kaydet, abort_kaydet, kizginlik_kaydet
  
  Vaka: create_case, add_treatment_day, add_drug_administration, 
        remove_drug_administration, close_case
  ```

#### 5. **Known Issues** (ID: 9)
- **Category:** `known_issues`
- **RPC-Related Issues:**
  - "Tohumlama write path 3 farklı yol (2'si RPC bypass)"
  - Problem: Multiple write paths, some bypass RPC validation

---

## 🕸️ Knowledge Graph Analysis

### RPC Entity Relationships

The knowledge graph contains **123 RPC-related relationships** showing strong connections between RPC and:

#### High-Weight Connections (weight: 1.5)
```
html ─────────── co-occurs ─────────── RPC
index ────────── co-occurs ─────────── RPC
Supabase ─────── co-occurs ─────────── RPC
Migration ────── co-occurs ─────────── RPC
js ───────────── co-occurs ─────────── RPC
ui ───────────── co-occurs ─────────── RPC
```

#### Medium-Weight Connections (weight: 1.0)
```
Frontend ──────── co-occurs ─────────── RPC
Vanilla ───────── co-occurs ─────────── RPC
PWA ───────────── co-occurs ─────────── RPC
Backend ───────── co-occurs ─────────── RPC
PostgreSQL ────── co-occurs ─────────── RPC
Cache ─────────── co-occurs ─────────── RPC
IndexedDB ─────── co-occurs ─────────── RPC
GitHub ────────── co-occurs ─────────── RPC
Actions ───────── co-occurs ─────────── RPC
CLI ───────────── co-occurs ─────────── RPC
DB ─────────────── co-occurs ─────────── RPC
api ────────────── co-occurs ─────────── RPC
app ────────────── co-occurs ─────────── RPC
init ───────────── co-occurs ─────────── RPC
```

### Entity Context

- **RPC** entity:
  - Type: `variable`
  - Count: 5
  - First seen: 2026-04-05 13:59:56
  - Last seen: 2026-04-05 13:59:57

---

## 📋 Complete RPC Function Reference

### Source: `.claude/rpc-reference.md`

#### **All RPCs Return:** `jsonb { ok: boolean, ... }`

#### 1. Hayvan Yönetimi (Animal Management)

| RPC Function | Parameters | Purpose |
|--------------|-----------|---------|
| `hayvan_ekle` | `p_kupe_no, p_devlet_kupe, p_irk, p_cinsiyet, p_dogum_tarihi, p_grup, p_padok, [p_dogum_kg?], [p_anne_id?], [p_baba_bilgi?], [p_canli_agirlik?], [p_boy?], [p_renk?], [p_ayirici_ozellik?]` | Create new animal record |
| `hayvan_guncelle` | `p_id, [p_kupe_no?], [p_devlet_kupe?], [p_irk?], [p_cinsiyet?], [p_dogum_tarihi?], [p_grup?], [p_padok?], [p_dogum_kg?], [p_canli_agirlik?], [p_boy?], [p_renk?], [p_ayirici_ozellik?]` | Update animal info |
| `hayvan_not_ekle` | `p_hayvan_id, p_not` | Add note to animal |

#### 2. Üreme (Reproduction)

| RPC Function | Parameters | Purpose |
|--------------|-----------|---------|
| `tohumlama_kaydet` | `p_hayvan_id, p_tarih, p_sperma, [p_hekim_id?], [p_irk_bilgisi?]` | Record insemination |
| `tohumlama_sonuc_gebe` | `p_tohumlama_id` | Mark result as "Gebe" (Pregnant) |
| `tohumlama_sonuc_bos` | `p_tohumlama_id` | Mark result as "Boş" (Empty) |
| `tohumlama_sonuc_bekliyor` | `p_tohumlama_id` | Correct to "Bekliyor" (Waiting) |
| `dogum_kaydet` | `p_anne_id, p_tarih, p_kupe, [p_cins?], [p_tip?], [p_kg?], [p_baba?], [p_hekim_id?]` | Record birth + create calf + 14 tasks |
| `abort_kaydet` | `p_tohumlama_id, [p_notlar?]` | Record abortion |
| `kizginlik_kaydet` | `p_hayvan_id, p_tarih, [p_belirti?], [p_notlar?]` | Record heat observation |

#### 3. Hastalık - Legacy (Disease - Legacy System)

| RPC Function | Parameters | Purpose |
|--------------|-----------|---------|
| `hastalik_kaydet` | `p_hayvan_id, p_tani, [p_kategori?], [p_siddet?], [p_semptomlar?], [p_lokasyon?], [p_hekim_id?], [p_ilaclar?], [p_tedavi_gun?]` | Create disease case + treatments |
| `hastalik_guncelle` | `p_id, p_tani, p_kategori, p_siddet, p_semptomlar, p_lokasyon, p_hekim_id, [p_tarih?]` | Update case info |
| `hastalik_kapat` | `p_id` | Close active case |
| `hastalik_sil` | `p_id` | Delete case + follow-up tasks |

#### 4. Tedavi - Legacy (Treatment - Legacy System)

| RPC Function | Parameters | Purpose |
|--------------|-----------|---------|
| `tedavi_ekle` | `p_vaka_id, p_hayvan_id, p_ilac_stok_id, p_miktar, [p_uygulama_yolu?], [p_bekleme_gun?], [p_hekim_id?], [p_notlar?]` | Add treatment + deduct stock |
| `tedavi_sil` | `p_tedavi_id` | Delete treatment + restore stock |
| `tedavi_guncelle` | `p_tedavi_id, [p_miktar?], [p_uygulama_yolu?], [p_bekleme_gun?], [p_hekim_id?], [p_notlar?]` | Update treatment + calculate delta |
| `update_treatment_time` | `p_day_id uuid, p_treatment_time time` | Update treatment time |

#### 5. Vaka Sistemi - Yeni (Case System - New)

| RPC Function | Parameters | Purpose |
|--------------|-----------|---------|
| `create_case` | `p_animal_id, p_disease_id uuid, [p_notes?]` | Create new case from controlled disease list |
| `add_treatment_day` | `p_case_id uuid` | Add treatment day (auto day_no) |
| `add_drug_administration` | `p_day_id uuid, p_drug_id uuid, p_dose, p_unit, [p_route?]` | Record drug administration + deduct stock |
| `remove_drug_administration` | *(inferred)* | Remove drug administration |
| `close_case` | `p_case_id uuid` | Close case (status='closed') |

#### 6. Diğer (Other)

| RPC Function | Parameters | Purpose |
|--------------|-----------|---------|
| `geri_al` | `p_islem_id` | Revert operation from islem_log |
| `irk_listesi` | *(none)* | Return race reference list |
| `hekim_ekle` | `p_id, p_ad, [p_telefon?]` | Add veterinarian record |

---

## 🏗️ Architectural Patterns

### RPC Wrapper System

#### `api.js` - RPC Layer
```javascript
// RPC_TABLES mapping
const RPC_TABLES = {
  'tohumlama_kaydet': ['tohumlama', 'islem_log', 'gorev_log'],
  'dogum_kaydet': ['dogum', 'hayvanlar', 'gorev_log'],
  // ... etc
};

// Optimistic RPC call
rpcOptimistic(name, params, opts)
```

#### RPC Call Flow
```
Form Submit → rpcOptimistic() → RPC → 
  ✓ Success → Toast + UI Update
  ✗ Error → Error Message
```

### Offline Queue Integration

```javascript
// dataTrafficTekGonder - Offline queue
const RPC_MAP = {
  'tohumlama': { POST: 'tohumlama_kaydet', ... },
  'dogum': { POST: 'dogum_kaydet', ... },
  // Maps table operations to RPC calls
};
```

---

## ⚠️ Known Issues & Technical Debt

### 1. **BUG-007: Offline Kuyruk RPC'ye Çevir**
- **Status:** Ertelendi
- **Problem:** Offline kuyruk direkt REST kullanıyor
- **Required:** RPC gateway
- **Reference:** `.claude/gwen-tasks/task-bug007-offline-rpc.md`

### 2. **Multiple Write Paths**
- **Problem:** Tohumlama write path 3 farklı yol (2'si RPC bypass)
- **Impact:** Validation inconsistency
- **Reference:** Known issues (ID: 9)

### 3. **RPC Bypass Detection**
- **Location:** `js/forms.js`, `js/ui.js`
- **Pattern:** Direct `supabase.from('X').insert()` calls
- **Detection:** gwen-tester, gwen-reviewer agents
- **Reference:** `.agents/qwen/skills/rpc-contract/SKILL.md`

---

## 📚 Documentation & References

### Key Files

1. **`.claude/rpc-reference.md`** - Complete RPC signatures (103 lines)
2. **`.agents/qwen/skills/rpc-contract/SKILL.md`** - RPC validation rules
3. **`js/api.js`** - RPC wrapper implementations (~335 lines)
4. **`js/forms.js`** - RPC call sites (~941 lines)
5. **`js/ui.js`** - RPC integration (~2865 lines)
6. **`supabase/migrations/*.sql`** - RPC function definitions

### Agent System Integration

- **rpc-contract skill** - Validates RPC usage
- **gwen-researcher** - Retrieves RPC signatures
- **gwen-coder** - Implements RPC calls
- **gwen-tester** - Detects RPC bypass
- **gwen-reviewer** - Enforces RPC contracts

---

## 🎯 Recommendations

### 1. Complete Offline Queue RPC Integration
- **Priority:** High
- **Action:** Implement RPC gateway for offline operations
- **Reference:** task-bug007-offline-rpc.md

### 2. Consolidate Write Paths
- **Priority:** High
- **Action:** Eliminate direct REST writes in tohumlama module
- **Reference:** task-arge-004.md

### 3. Enhance RPC Documentation
- **Priority:** Medium
- **Action:** Add more RPC examples to memory system
- **Current:** Only 5 notes mention RPC
- **Target:** 20+ detailed RPC usage notes

### 4. Strengthen RPC Validation
- **Priority:** Medium
- **Action:** Automate RPC signature validation in CI/CD
- **Reference:** SONARCLOUD_REMEDIATION_PLAN.md

---

## 📈 Statistics

| Category | Count |
|----------|-------|
| Total RPC functions | 22 |
| Active (used) | ~18 |
| Deprecated (legacy) | ~4 |
| Memory notes | 5 |
| Knowledge graph relationships | 123 |
| Migration files referencing RPC | 5 |
| Agent skills referencing RPC | 12 |

---

## 🔗 Related Artifacts

- **ARCHITECTURE.md** - RPC in system architecture
- **SONARCLOUD_REMEDIATION_PLAN.md** - RPC refactoring progress
- **DEFERRED_FEATURES.md** - RPC backlog
- **SPEC.md** - RPC specifications
- **LastSpec.md** - Current RPC status
- **domain-rules.md** - Domain rules enforced by RPCs

---

**End of Report**
