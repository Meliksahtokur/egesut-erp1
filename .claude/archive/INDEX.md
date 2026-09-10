# egesut-erp1 Archive Index

**Last updated:** 2026-05-02  
**Reason:** Deep status investigation (2026-05-02) found 10 tasks marked pending but already implemented in code.

---

## Tasks — Completed

### Gwen Tasks (2026-Q1, abandoned Gwen system)

| File | Title | Resolution Date |
|------|-------|-----------------|
| task-004-dev-cleanup.md | Development Branch Temizliği — Merge Öncesi Zorunlu | implemented |
| task-004-done.md | Task-004 Tamamlandı | done |
| task-004-push-issue.md | Push Sorunu Raporu | resolved |
| task-arge-002-done.md | Workflow Kalite Kapıları | done |
| task-arge-002.md | Workflow Kalite Kapıları | done |
| task-arge-003-done.md | MCP Temizliği + Gwen Test Protokolü | done |
| task-arge-003.md | MCP Temizliği + Gwen Test Protokolü | done |
| task-arge-004-done.md | Gwen Kalite Araçları — Reviewer + Domain Skill | done |
| task-arge-004.md | Gwen Kalite Araçları — Reviewer + Domain Skill | done |
| task-arge-005-done.md | Hook Sistemi Dokümantasyonu | done |
| task-arge-005.md | Hook Sistemi Dokümantasyonu | done |
| task-arge-006-done.md | Root Dosyaları .agents/'a Taşı | done |
| task-arge-006.md | Root Dosyaları .agents/'a Taşı | done |
| task-arge-007.md | — | superseded (tools-bank MCP config system) |
| task-bug003-revize-done.md | Task-bug003 Revize Tamamlandı | done |
| task-bug007-offline-rpc.md | — | resolved (RPC_MAP exists in ui.js:2951-2978) |
| task-dev-008-done.md | UI Telemetry Logger Tamamlandı | done |
| task-dev-008.md | UI Telemetry Logger | done |

### Arge Tasks

| File | Title | Resolution Date |
|------|-------|-----------------|
| task-arge-001-done.md | Agent ve Skill Optimizasyonu | done |
| task-arge-001.md | Agent ve Skill Optimizasyonu | done |
| task-arge-001-revize.md | Revize | done |
| task-arge-009-done.md | Worktree İzolasyonu + 4 Demir Kural | done |
| task-arge-009.md | Worktree İzolasyonu + 4 Demir Kural | done |
| task-arge-010-done.md | rpc-contract Skill + gwen-reviewer Güvenlik Kontrolleri | done |
| task-arge-010.md | rpc-contract Skill + gwen-reviewer Güvenlik Kontrolleri | done |
| task-arge-011-done.md | Operator Mimarisi Tasarımı | done |
| task-arge-011.md | Operator Mimarisi Danışma + Tasarım | done |
| task-arge-012-done.md | Operator Pattern Implementasyonu — Faz 1 | done |
| task-arge-012.md | Operator Pattern Implementasyonu — Faz 1 | done |
| task-arge-013-done.md | Operator Pattern Fix + Git Hook'lar | done |
| task-arge-013.md | Gwen Orchestrator — Agent + Context Dosyaları | done |
| task-arge-014-done.md | Bekleyen Eksikler Kapatıldı | done |
| task-arge-015-done.md | Gwen Orchestrator (Qwen Code için) | done |
| task-arge-016-done.md | supa-query Wrapper Script | done |
| task-arge-016.md | — | superseded (tools-bank supabase MCP tools) |

### Dev Tasks

| File | Title | Resolution Date |
|------|-------|-----------------|
| task-bug003-revize.md | feature/gwen-bug003-fix merge öncesi düzeltmeler | done |
| task-dev-001.md | Test Hataları — IDB Store, Duplicate Telemetry, Tohumlama 42883 | done (Hata 1+2 fixed) |
| task-dev-005-done.md | Bug Tracker Güncelleme + drug_product_ekle RPC | done |
| task-dev-005.md | Bug Tracker Güncelleme + drug_product_ekle RPC | done |
| task-dev-005-revize2.md | Revize 3 (Son) | done |
| task-dev-005-revize.md | Revize 2 | done |
| task-dev-006-done.md | Security Hardening | done |
| task-dev-006.md | BUG-005 — stok update RPC'ye taşı | done |
| task-dev-006-revize.md | Migration güvenlik düzeltmeleri | done |
| task-dev-008-done.md | UI Telemetry Logger Tamamlandı | done |

### Standalone Tasks

| File | Title | Resolution Date |
|------|-------|-----------------|
| task-m2.5-001-done.md | tohumlama_sonuc_bos Duplicate RPC Temizliği | done |
| task-m2.5-001.md | tohumlama_sonuc_bos Duplicate RPC Temizliği | done |
| task-m2.5-002.md | Klinik Modülü — 3 Eksik RPC | 2026-05-02 (implemented in migrations 20260403000002/03/04) |
| minimax-tech-debt.md | MiniMax M2.5 — Teknik Borç Kapatma Görevi | done (vaccines IDB store, _origConsoleError fixed) |
| task-claude-shared-mcp.md | Ortak MCP Sunucuları | superseded (tools-bank achieved independently) |
| task-claude-testsprite.md | TestSprite MCP Entegrasyonu | stale (PRoot limitation still exists) |

---

## Plans — Implemented or Superseded

| File | Title | Outcome |
|------|-------|---------|
| plans/2026-03-26-tohumlama-event-stack.md | Tohumlama event stack | **Implemented** — migration 030 exists, all RPCs in place, forms.js uses rpcOptimistic |
| plans/2026-04-10-tools-bank-mcp-integration.md | Tools-Bank MCP Entegrasyonu | **Superseded** — implemented via tools-bank MCP tools |
| plans/2026-04-10-tools-bank-mcp-integration-design.md | Design: Tools-Bank → Claude Code CLI | **Superseded** — design patterns absorbed into tools-bank |
| 2026-04-09-ureme-modulu-bakim.md | Üreme Modülü Bakım (BUG-6/6b/4/2) | **Partially implemented** — BUG-6/6b/4 fixed in migrations 20260409000001/02; BUG-2 policy done, REALTIME_TABLES flag pending separate spec |

---

## Archive Statistics

- **Gwen Tasks:** 18 files
- **Arge Tasks:** 19 files
- **Dev Tasks:** 10 files
- **Standalone Tasks:** 6 files
- **Plans:** 4 files
- **Total:** 57 archived items

---

*This archive was created as part of spec-egesut-mark-and-archive (2026-05-02)*
