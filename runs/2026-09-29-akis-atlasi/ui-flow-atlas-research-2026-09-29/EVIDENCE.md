# EVIDENCE — ana iddialar

| İddia | Etiket | Kaynak | Sınır |
|---|---|---|---|
| Playwright Test Agents planner/generator/healer sunuyor ve Claude/Codex loop'ları var | CONFIRMED | S01 | Full graph coverage garantisi yok |
| Playwright trace action ile network/console/DOM snapshot'ı korele ediyor | CONFIRMED | S04 | Atlas formatını kendi üretmez |
| IndexedDB state Playwright storageState'e dahil edilebilir | CONFIRMED | S05 | Full diff stratejisi bizim tasarımımız |
| Chrome DevTools MCP network request inspection sunuyor | CONFIRMED | S06,S07 | Agent başlamadan önceki request görünmeyebilir (S25) |
| Crawljax SPA state-flow graph çıkarır | CONFIRMED | S10,S13 | Son release 2023; operasyonel güncellik zayıf |
| Crawljax ana motor olarak riskli | INFERRED | S11,S12,S14 | Repo'nun her commit'i bu araştırmada doğrulanmadı |
| browser-use active/local/MCP | CONFIRMED | S08,S28 | 2026 MCP bug reports var |
| browser-use ana evidence recorder olmamalı | INFERRED | S23,S24,S29 | Sorunlar sürüme/ortama bağlı olabilir |
| Stagehand local browser destekliyor | CONFIRMED | S09 | Deterministik graph output yok |
| `plpgsql_check` relation/function deps çıkarabilir | CONFIRMED | S15 | Dynamic SQL eksik kalabilir |
| `pg_trigger` trigger→function graph için yeterli metadata verir | CONFIRMED | S16 | Function içi yan etkiler ayrıca analiz gerekir |
| `pg_depend` tek başına full PL/pgSQL lineage değildir | CONFIRMED/INFERRED | S17,S38 | Spesifik schema üzerinde test edilmedi |
| pg_cron job ve run history tablolarda bulunabilir | CONFIRMED | S18,S39 | Supabase plan/permission farklılıkları olabilir |
| Flow atlasın JSON/YAML kanonik, Markdown render olması daha iyi | INFERRED | problem yapısı + evidence | Uygulama üzerinde ölçülmedi |
| Source hash + live E2E en pratik staleness gate | INFERRED | S42,S43 + mimari | CI uygulanmadı |
| `confirm()` listener yoksa semantik branch kaçabilir | CONFIRMED | S26 | Playwright varsayılan davranış bağlamında |
