# Session Learnings — EgeSüt ERP

## What Worked Well

- **Parallel agents for multi-issue discovery** — dispatching 2-3 agents to explore different aspects simultaneously (UI patterns, data flow, duplicate code) gave comprehensive context fast
- **`execute_sql` for DB changes** — applied migration SQL directly via MCP, works reliably
- **`getState` + `idbGetAll` pattern** — consistent way to read local cache; always check both when animal lookups fail
- **Plan-file-first** — updating SONARCLOUD_REMEDIATION_PLAN.md before implementing keeps decisions auditable

## What Didn't Work / Pitfalls

- **`apply_migration` MCP endpoint unavailable** — `UnauthorizedException`; use `execute_sql` instead for all DB changes
- **Patching one file without checking duplicates** — `tohSonuc` existed in both `ui.js` and `forms.js`; the ui.js version (unprotected, added earlier) silently overrode the forms.js version. Always `grep -n "function name"` across all JS files before patching.
- **`git revert` when user said things are "ok enough"** — user rejected revert attempt; when user says "push as-is", do it without cleanup
- **`git push` HTTPS auth** — token needed via `git remote set-url origin https://<token>@github.com/...`; not cached by default in this env

## MCP Usage Patterns

| Tool | Status | Notes |
|---|---|---|
| `mcp__supabase__execute_sql` | ✅ Works | Use for all DB reads and schema changes |
| `mcp__supabase__apply_migration` | ❌ Unavailable | `UnauthorizedException` — skip, use execute_sql |
| `mcp__supabase__list_tables` | ✅ Works | Good for schema exploration |
| `mcp__supabase__get_project_url` | ✅ Works | Needed for RPC calls |

## Tohumlama Module — Architecture Debt (next session)

Three write paths exist, only one goes through the validated RPC:
1. `tohSonuc()` in forms.js — direct PATCH (bypasses validation)
2. `tohSonucGuncelle()` in ui.js — direct PATCH (partially guarded)
3. `tohumlama_kaydet` RPC — correct path

Full refactor plan is in `SONARCLOUD_REMEDIATION_PLAN.md` under "🔴 TOHUMLAMA MODÜLÜ".
Proposed new RPCs: `tohumlama_sonuc_gebe`, `tohumlama_sonuc_bos`, `tohumlama_abort`.

## Oturum 2026-03-26 Ek Öğrenmeler

### Stok Sistemi
- Stok tabloları: `stok` + `stok_hareket` + `stok_tuketim_view`
- Sperma **dropdown'dan seçilir** — `stok` tablosundan `kategori='Sperma'` filtreyle gelir
- `tohumlama_kaydet` RPC stok düşer ama `ILIKE` eşleşmesi başarısızsa **sessizce atlar** — hata fırlatmaz
- Stok UI'da görünmüyorsa: `RPC_INVALIDATION_MAP`'te `stok`/`stok_hareket` eksik olabilir

### Geri Al Modal Sorunu
- `geriAl()` başarısında `closeM('m-geri-al')` var ama tohumlama detay modal (`m-td2`) açık kalıyor
- Geri al sonrası: `closeM('m-geri-al')` + `closeM('m-td2')` ikisi de çağrılmalı
- `renderSafe()` sayfayı yeniliyor ama açık modal içeriğini güncellemiyor

### Migration 028 Sınırı
- Migration 028 öncesi `islem_log.ref_id` = NULL → geri alma butonu görünmüyor (expected)
- 028 sonrası kayıtlarda `ref_id` = `tohumlama.id` (dolu)
- Eski kayıtları temizlemek için: `DELETE FROM tohumlama WHERE id NOT IN (SELECT ref_id FROM islem_log WHERE tip='TOHUMLAMA' AND ref_id IS NOT NULL)`

### Çoklu Gebe Kirli Veri
- `tohSonucGuncelle` / `gebeIsaretKaydet` hayvanın mevcut durumunu kontrol etmediğinden birden fazla "Gebe" kayıt oluşabiliyor
- Guard: `if (hayvan?.tohumlama_durumu === 'Gebe') { toast(...); return; }`

### Agent Knowledge Gap
- Agent dosyaları (`erp-db-agent.md`, `erp-frontend-dev.md`, `erp-explorer.md`) projeye özgü mekaniklerle güncellendi (2026-03-26)
- Her yeni proje mekaniği keşfedilince → ilgili agent dosyasına eklenmeli

## What to Avoid

- Don't add `console.log` debug lines to production files without removing them
- Don't assume `hayvan_id` is always UUID — can also be `kupe_no` (see domain-rules.md §1)
- Don't touch `Gebe` veya `Doğum Yaptı` tohumlama records from frontend directly — RPC only
- Don't skip confirm dialogs for destructive state transitions (Gebe→Boş, Gebe→Abort)
- **Agent'lara "stok sistemi nedir?" veya "sperma nasıl seçilir?" sormayın** — cevap artık agent dosyalarında mevcut

---

## Oturum 2026-05-23 — Orchestrator-Master Skill Tasarımı

### Ne Yapıldı
`orchestrator-master` adında tek bir DeepSeek TUI skill'i oluşturuldu. İki modu var: **research** (flat, parallel) ve **hierarchical** (recursive, depth-controlled).

### Skill Yeri
- `.agents/skills/orchestrator-master/SKILL.md` — proje kökünde
- `feature-dev` skill'i ile yan yana duruyor

### Mimari Kararlar

| Karar | Sebep |
|-------|-------|
| **Tek skill, iki mod** | Kullanıcı tek bir `/skill orchestrator-master` ile her iki işi de yapabilir. Mode auto-detect. |
| **Sub-agent'lar read-only (research modu)** | `type: explore` ile garanti. Keşif için paralel, yazma için serial. |
| **Hierarchical modda herkes yazabilir** | Ama sadece kendi territory'sinde. Territory disjoint olduğu sürece çakışma olmaz. |
| **max_depth ile recursion kontrolü** | DeepSeek TUI'nin built-in `agent_open(max_depth=N)` parametresi kullanılır. Main=3, Sub=2, Sub-sub=1, Leaf=0. |
| **Quota sistemi (≤20)** | Total agent sayısı 20 ile sınırlı. Her sub-orch kendi quota'sını yönetir. Prompt ile enforce edilir. |
| **Dil ayrımı** | Skill body ve sub-agent iletişimi İngilizce. Main agent kullanıcıyla Türkçe konuşur. |
| **fork_context: true her zaman** | Prefix cache korunur, context şişmesi azalır. |
| **handle_read büyük çıktılar için** | Sub-agent çıktısı >50 satır ise context'e kopyalama, handle_read ile projeksiyon al. |
| **Janitor agent yok** | Checklist + PLAN.md yeterli. Fazladan agent context şişirir. |
| **feature-dev silinmedi** | Eski skill geriye dönük uyumluluk için duruyor. orchestrator-master onun yerini alabilir. |

### Kullanım

```bash
# Research modu (otomatik)
/skill orchestrator-master
Görev: Şu konuyu araştır...

# Hierarchical modu (otomatik)
/skill orchestrator-master  
Görev: Kullanıcı giriş sistemi implemente et...

# Hem araştırma hem implementasyon
/skill orchestrator-master
Görev: Web'den auth pattern'lerini araştır, sonra implemente et.
```

### Sub-agent Prompt Dili
- Tüm sub-agent prompt'ları **İngilizce** yazılır
- Sub-agent'lar kendi arasında **İngilizce** konuşur
- Alt seviye orkestratörler kendi children'larına İngilizce prompt verir
- Sadece main agent kullanıcıya cevap yazarken kullanıcının dilini kullanır

### Önemli Uyarılar
- Research modunda batch aç (tüm agent'ları tek turda). Serial açma.
- Hierarchical modda territory'ler disjoint olmalı. İki agent aynı dosyayı sahiplenemez.
- Quota aşımı → sub-orch reddeder, parent'a rapor eder. Parent yeniden dağıtır.
- Test gate: her dosya sonrası test. FAIL → `git revert HEAD`, düzelt, tekrar dene.
- Son çare çakışma çözümü: projeyi klonla, her ekibe ayrı workspace ver, sonra merge.
