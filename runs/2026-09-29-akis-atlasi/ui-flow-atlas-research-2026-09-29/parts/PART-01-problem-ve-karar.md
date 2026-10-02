# PART-01 — Problem, kriterler ve ana karar

## Problem yeniden tanımı

Buradaki eksik “E2E test yazamamak” değil. Eksik olan, bir ajan için uygulamanın davranışını **kanıt zinciriyle görünür kılan runtime program comprehension** katmanı.

Bir akışın gerçek tanımı:

`UI state → user action → JS handler → RPC/HTTP → SQL function → table write → trigger → cron/background producer → yeni UI-observable state`

Vanilla JS + modal SPA'da route graph tek başına anlamsız olabilir; aynı URL üzerinde çok sayıda operasyonel state vardır. Offline-first nedeniyle bazı anlamlı geçişler network bile üretmeyebilir.

## Tasarım prensipleri

1. **Agent inference ≠ evidence.** LLM “bu buton şu RPC'yi çağırıyor” diyebilir; atlas ancak trace/HAR/static edge veya DB evidence ile CONFIRMED olmalı.
2. **State = URL değil.** State fingerprint: görünür modal/bottom-sheet, kritik form alanları, role/name seti, selected animal/task id, offline queue digest, IndexedDB digest.
3. **Her edge'in provenance'ı olmalı.** `trace_step`, `network_request`, `source_location`, `sql_dependency`, `db_observation`.
4. **Statik ve dinamik kanıt çelişebilir.** Statik graph “olası”; runtime trace “bu koşulda gerçekten oldu”. Atlas ikisini ayrı tutmalı.
5. **Canlı belge:** kritik flow Markdown'ı elle yazılan prose değil, E2E evidence'dan render edilen çıktı olmalı.

## Neden tek araç yok?

- Crawljax gibi crawler, state ve transition keşfeder ama RPC→trigger→cron semantiğini bilmez.
- Playwright MCP ajan etkileşimini sağlar ama kendi başına kalıcı state machine üretmez.
- Chrome DevTools MCP network/console'u iyi görür ama iş akışının domain modelini çıkarmaz.
- `plpgsql_check` DB dependency çıkarır ama UI hangi koşulda o RPC'yi çağırdı bilmez.

Bu nedenle “flow atlas” bir **evidence fusion** problemidir.

## Karar

Başlangıç mimarisi: **Playwright-native evidence recorder**. Çünkü projede Playwright zaten var; uygulamayı demo ortamında gerçek davranışla yürütmek hata sınıfınızı daha önce yakalamış. Yeni katman bu manuel pratiği kalıcılaştırmalı.
