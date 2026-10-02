# PILOT — 1 günde “tohumlama → gebelik kontrol” flow atlası

## Amaç

Bir tek flow için otomatik/yarı otomatik kanıt paketi üretmek ve aynı görev tipini üreten tüm producer'ları görünür kılmak.

## Ön koşullar

- Demo DB resetlenebilir.
- Playwright login `storageState` hazır.
- Test yalnız demo data ile çalışır.
- GitNexus CLI/çıktısına erişim var.
- Supabase DB'de introspection query çalıştırma yetkisi var.

## Adımlar

1. Fixture oluştur: bir hayvan + tohumlama senaryosu + tarih kontrolü.
2. Planner'a yalnız bu flow'u ver; test planı üret.
3. Testi `test.step` ile domain aksiyonlarına böl.
4. Global `dialog` listener: confirm/prompt eventlerini JSONL'e yaz.
5. Trace `screenshots/snapshots` açık.
6. HAR `full` kayıt; auth header redaction post-process.
7. Request listener `/rest/v1/rpc/` çağrılarını `step_id` ile JSONL'e yaz.
8. Her step öncesi/sonrası kritik IndexedDB store digest'i.
9. RPC isimleri için `plpgsql_show_dependency_tb` export.
10. İlgili tablolar için trigger graph export.
11. `cron.job` içinde pregnancy/task üreten job'ları export.
12. GitNexus ile UI handler→RPC static path export.
13. Merger: canonical node IDs oluştur, edge confidence ata.
14. `FLOW.md`, `flow.json`, `flow.mmd` üret.
15. Aynı flow'u ikinci kez temiz DB'de çalıştır; graph fingerprint stabil mi bak.

## Başarı koşulu

- +21/+35/+40 veya gerçekte var olan tüm producer yolları atlas içinde ayrı ayrı görünür.
- En az 1 UI→RPC edge runtime trace ile doğrulanır.
- En az 1 RPC→table/function edge `plpgsql_check` ile doğrulanır.
- Trigger/cron varsa graph'a girer.
- Dialog/retry branch'i varsa kaybolmaz.
- Offline queue değişimi varsa network'ten bağımsız görünür.
- İki temiz run'da semantic graph fingerprint aynı veya açıklanabilir fark gösterir.

## Başarısız say

- Crawler/agent yalnız URL listesi çıkarıyorsa.
- Network request ile action eşleşmiyorsa.
- DB side-effect producer'larının biri hâlâ manuel inceleme olmadan bulunamıyorsa.
- Dynamic DOM yüzünden state sayısı kontrolsüz büyüyorsa.
- Atlası güncellemek mevcut elle yazılan Playwright testinden belirgin daha zahmetliyse.
