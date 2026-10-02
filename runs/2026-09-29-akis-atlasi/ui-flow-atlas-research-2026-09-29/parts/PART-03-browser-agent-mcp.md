# PART-03 — LLM browser ajanları ve MCP

## Playwright Test Agents

**CONFIRMED:** Güncel Playwright dokümantasyonu üç agent tanımlıyor: **planner**, **generator**, **healer**. Planner uygulamayı keşfedip Markdown test planı üretir; generator planı Playwright teste çevirir; healer failing testleri çalıştırıp onarmaya çalışır. `init-agents` Claude Code, Codex, OpenCode ve VS Code loop'larını destekler. [S01]

Bu projeye uyumu yüksek çünkü:
- mevcut Playwright yatırımını kullanır,
- plan dosyaları repo içinde kalıcı olabilir,
- seed test ile demo login/storageState kurulabilir,
- agent çıktısı doğrudan tekrar yürütülebilir test haline gelir.

**Sınır:** planner'ın keşfettiği şey “tam uygulama state graph” garantisi değildir. Bu yüzden planner çıktısı atlas değil, atlas için exploration planıdır.

## Playwright MCP

**CONFIRMED:** Playwright MCP, accessibility snapshot üzerinden LLM'e browser automation araçları verir ve Claude Code dahil MCP client'larla çalışır. [S02][S03]

Güçlü taraf:
- local ve açık kaynak,
- doğrudan mevcut agentlere eklenebilir,
- screenshot vision zorunlu değil,
- dialog handling için özel araçları var. [S27]

Riskler / kullanıcı raporları:
- Modal overlay'lerde click interception rapor edilmiş. [S21]
- Bazı elementlerin accessibility snapshot'ta görünmediği rapor edilmiş. [S22]
- Accessibility snapshot içeriğinin LLM context'ine taşınması indirect prompt injection yüzeyi oluşturabilir; demo/allowlist domain önemli. [S20]

Bu nedenle Playwright MCP tek explorer olmamalı; gerektiğinde Chrome DevTools MCP/screenshot ile cross-check yapılmalı.

## Chrome DevTools MCP

**CONFIRMED:** Google'ın Chrome DevTools MCP'si v1.10.1, 23 Eylül 2026 tarihli; Apache-2.0. Network request listeleme/inceleme, screenshot ve performance trace gibi araçlar sunuyor. [S06][S07]

Bu projedeki ideal rol:
- “Bu click'ten sonra hangi `/rest/v1/rpc/*` request'i oluştu?” doğrulaması,
- request/response body inspection,
- console error/warning,
- service worker / network timing gibi Playwright test layer'ından farklı DevTools görünümü.

Sınır: Bağlanmadan önce oluşmuş network request'lerin görünmemesi hakkında açık issue var. Bu nedenle recorder'ın test başında bağlanmış olması gerekir. [S25]

## browser-use

**CONFIRMED:** browser-use 0.13.10, 4 Eylül 2026 release; local MCP/CLI entegrasyonu ve Linux desteği var; MIT lisans. [S08][S28]

Keşif için avantajı semantik otonomi. Ancak 2026 issue'larında:
- MCP/CDP startup timeout,
- bazı tool failure'larının `isError=false` dönmesi,
- Codex'in read-only annotation eksikliği nedeniyle tool call iptali
rapor edilmiş. [S23][S24][S29]

**Rol:** ana evidence recorder değil; “unknown flow hunter” veya ikinci keşif agenti.

## Stagehand

**CONFIRMED:** Stagehand v3 local ve Browserbase environment'larını destekliyor; MIT lisans; 2026'da aktif release'ler var. [S09][S30]

`observe/act/extract/agent` yaklaşımı karmaşık UI'da semantik gezinime yardımcı olabilir. Ancak local modda Playwright'ın bazı context özelliklerinin doğrudan expose edilmemesi (ör. recordVideo feature request) kullanıcılara ek wrapper ihtiyacı çıkarabiliyor. [S31]

**Rol:** keşif alternatifi; mevcut Playwright recorder'ın yerine geçmesi gerekmez.

## OpenBrowser

**CONFIRMED:** TypeScript + Playwright üzerinde açık kaynak autonomous browser agent framework; MIT ve multi-model. [S32]

Artısı: TypeScript stack'e yakın ve sandbox/replay fikirleri yararlı. Eksisi: kendi state-flow graph standardı yok; ekosistem olgunluğu Playwright kadar yüksek değil.

## agentic-test-explorer

**REPORTED/EXPERIMENTAL:** Community projesi Playwright + LangGraph swarm ile exploratory testing, bug bulduğunda reproducible Playwright test üretme ve Mermaid dashboard gibi özellikler sunuyor. [S33]

Bu, sizin hedefe kavramsal olarak çok yakın ama bağımlılık ve olgunluk riski yüksek. Kodunu ürün olarak almak yerine fikir kaynağı olarak incelemek mantıklı: mission, action tape, explored paths, generated reproducer.
