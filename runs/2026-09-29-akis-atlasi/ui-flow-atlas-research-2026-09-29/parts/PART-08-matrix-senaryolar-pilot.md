# PART-08 — Aday matrisi, senaryolar, risk ve pilot

## Aday matrisi

> Kurulum eforları **INFERRED** kaba tahmindir; bu oturumda kurulum yapılmadı.

| Aday | Ne yapar | Kategori | Vanilla JS modal SPA | Local/self-host | Agent entegrasyonu | Çıktı | Olgunluk / güncellik | Maliyet | Kurulum |
|---|---|---|---|---|---|---|---|---|---|
| Playwright Test Agents | Planner→plan, generator→test, healer→repair | keşif/test üretimi | **Yüksek**; gerçek browser + seed | Evet | Claude Code/Codex/OpenCode | Markdown + test | Aktif 2026 | Ücretsiz OSS + seçilen LLM | 1–2 sa |
| Playwright MCP | Agent browser control | keşif | **Yüksek**, fakat a11y/modal kör noktaları var | Evet | MCP | snapshots/actions | v0.0.82, aktif 2026 | Ücretsiz | <1 sa |
| Chrome DevTools MCP | DevTools network/console/perf | izleme/debug | **Yüksek** | Evet | MCP/CLI | structured tool output | v1.10.1, 2026-09-23 | Ücretsiz | <1 sa |
| Playwright trace + HAR | Aksiyon + DOM + screenshot + network | izleme/evidence | **Çok yüksek** | Evet | API/CLI | trace.zip/HAR | Playwright aktif 2026 | Ücretsiz | 2–4 sa wrapper |
| `plpgsql_check` + PG catalogs | Function relation/function deps + trigger graph | DB analizi | N/A | Evet, DB extension | SQL | rows/JSON export | Aktif 2026; 2.10.x code | Ücretsiz BSD | 1–3 sa |
| browser-use | Autonomous browser agent | keşif | Orta-yüksek | Evet | MCP/CLI/Python | agent trajectory | v0.13.10, 2026-09-04 | OSS ücretsiz; LLM maliyeti | 1–3 sa |
| Stagehand | AI observe/act/extract/agent | keşif | Orta-yüksek | Evet LOCAL | API | actions/extract | Aktif 2026 | OSS ücretsiz; LLM | 1–3 sa |
| OpenBrowser | Autonomous TS Playwright agent | keşif | Orta | Evet | CLI/API | replay/session | Aktif 2026 | OSS + LLM | 2–4 sa |
| Crawljax | Otomatik state-flow graph | keşif/model | Kavramsal yüksek; operasyonel risk | Evet | Java CLI/API | state-flow graph | **Son release 2023-06-01** | Ücretsiz Apache-2 | 2–6 sa PoC |
| GraphWalker | Verilen modeli yürütür | MBT/test | Model sonrası yüksek | Evet | CLI/REST/WebSocket | coverage/path | son release 2024-09-26 | Ücretsiz MIT | 2–4 sa |
| agentic-test-explorer | Agentic exploratory QA + reproducer | keşif/test | Orta | Evet | CLI + MCP opsiyon | Markdown/test/Mermaid | Community/deneysel 2026 | OSS + LLM | 2–6 sa |

## Senaryo ayrıntıları

### A — Trace-first minimal stack

**Trigger:** kritik bir flow değişti veya ajan “bu feature nasıl çalışıyor?” diyor.  
**Bileşenler:** Playwright Test Agents, recorder, GitNexus, DB introspector.  
**Data path:** browser action → trace/HAR → parser → GitNexus join → DB deps → flow.json.  
**Failure:** explorer bir state'i bulamaz; insan seed/mission verir, recorder aynı kalır.  
**Tercih:** varsayılan.

### B — Crawljax-assisted discovery

**Trigger:** “bilmediğimiz kaç modal/state var?” sorusu.  
**Data:** Crawljax graph → canonicalize → seçilen path'leri Playwright ile replay/verify.  
**Failure:** Chrome incompatibility/state explosion.  
**Exit:** Crawljax'ı sök, state graph formatını koru.

### C — LLM exploration swarm

**Trigger:** docs'ta olmayan edge case arama.  
**Bileşen:** 2–3 ucuz browser agent farklı mission ile gezer; her bulgu deterministic Playwright reproducer'a çevrilmeden kabul edilmez.  
**Failure:** token maliyeti, nondeterministic coverage, UI hallucination.  
**Tercih:** gece/demo discovery.

### D — Atlas → model-based coverage

**Trigger:** atlas düzinelerce flow'a büyüdü.  
**Bileşen:** flow graph → GraphWalker.  
**Amaç:** every-edge/every-vertex gibi coverage ile “hangi transition hiç test edilmiyor?” bulmak.  
**Failure:** model manually stale; atlas generator bunu azaltır.

### E — Trace context / OTel augmentation

**Trigger:** browser request ile DB etkisi zaman korelasyonu yetmiyor; backend servisler çoğalıyor.  
**Bileşen:** OTel browser fetch + backend instrumentation.  
**Failure:** instrumentation complexity ve hosted Supabase sınırları.  
**Tercih:** ileride, gerekirse.

## Risk matrisi

| Risk | Etki | Olasılık | Azaltma |
|---|---|---|---|
| State explosion | yüksek | yüksek | semantic fingerprint + ignore rules + budget |
| Modal/a11y snapshot kör noktası | yüksek | orta | screenshot/CDP cross-check + explicit modal probes |
| `confirm()` auto-dismiss ile akış kaçması | yüksek | orta | global dialog listener + decision log |
| Offline action network üretmiyor | yüksek | yüksek | IndexedDB diff + sync queue evidence |
| Service worker HAR replay farkı | orta | yüksek | discovery ve replay modlarını ayır |
| Dynamic SQL lineage eksik | orta | orta | runtime DB diff/log + UNVERIFIED edge |
| Agent nondeterminism | orta | yüksek | reproducer test olmadan CONFIRMED verme |
| Evidence storage büyümesi | orta | orta | hash/dedup/retention; only failures+critical runs full trace |
| Test data drift | yüksek | orta | immutable demo fixture/scenario reset |
| Auth/session leak | yüksek | düşük-orta | demo-only storageState, secret redaction, domain allowlist |

## 1 günlük pilot sonucu nasıl okunmalı?

Pilot başarılıysa full sistem yazmaya başlamadan önce iki sayı topla:

1. **Evidence completeness:** beklenen edge'lerin yüzde kaçı runtime/static/db kaynaklarından en az ikisiyle doğrulandı?
2. **Discovery value:** manuel kod review'unda kaçırılan en az bir producer/branch bulundu mu?

İkinci sayı sıfırsa atlasın maliyeti tekrar değerlendirilir. Hedef “güzel diyagram” değil, kaçırılan davranışı yakalamak.
