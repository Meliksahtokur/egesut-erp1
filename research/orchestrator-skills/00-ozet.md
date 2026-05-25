# Orchestrator Skill Araştırması

**Tarih:** 2026-05-23  
**Kapsam:** orchestrator-master skill'ine alternatif/tamamlayıcı açık kaynak skill'lerin taranması

## Özet

- **DeepSeek-native orchestrator skill'i yok.** DeepSeek ekosisteminde bizimki gibi territory/quota/depth kontrollü bir skill bulunamadı.
- **En yakın alternatif:** `alisherry/claude-skills/multi-agent-orchestration` — üç agent tipi (Simple/Resilient/Sub-Orch), parallel swarm, pattern adherence workflow.
- **Bizim avantajımız:** Territory enforcement, quota allocation, depth control gibi production-ready özellikler rakiplerde yok.
- **Eksiklerimiz:** Pattern adherence workflow, failure budget, worker types ayrımı (simple/resilient).
