# Research Contract (mandatory)

## Fetch escalation ladder
Always fetch through `scripts/fetch_ladder.py <url> --text`. It runs:
1. curl_cffi (curl-impersonate JA3/JA4, our IP, fast) — primary
2. primp (different TLS/HTTP2 fingerprint, our IP) — if tier 1 blocked
3. Jina Reader (r.jina.ai, remote JS render + separate IP) — if tier 2 blocked
The script reports `tier` and `blocked`. If `blocked:true` after all tiers → the
item is UNVERIFIED. Never invent a price.

## Tool routing
| Site class | Path |
|---|---|
| Cloudflare TR (akakce, vatanbilgisayar, n11, hepsiburada, trendyol, incehesap, mediamarkt, cimri, pttavm) | fetch_ladder.py only. The tools-bank r.jina wrapper is FORBIDDEN for prices. |
| Blog/news/general | fetch_ladder.py (Jina tier is fine) |
| Discovery | mcp__duckduckgo__search → real product URL → then fetch_ladder. A snippet is NOT a price. |

## Price-verification gate (per item)
VERIFIED requires ALL of: source_url (fetched product page), price (TRY number),
seller, last_updated (page timestamp or fetch time), stock_status, evidence
(quote from fetched body). Missing any → UNVERIFIED.

## Stock rule
out_of_stock only with fetched-page evidence; otherwise unknown.

## Cross-check
Headline/cheapest price: ≥2 independent confirmations OR one aggregator page with
≥3 sellers + timestamp ≤7 days old.

## Done gate
Run `scripts/validate_run.py <run.json>` — must print VALID before reporting.