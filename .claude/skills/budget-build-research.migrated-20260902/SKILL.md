---
name: budget-build-research-v0.1
description: Use when researching current verified prices for a budget shopping list and assembling a compatible basket (PC parts first; generalizable to other products). Triggers — "bütçeyle toplama sistemi", "PC topla", "parça fiyat araştır", "budget build", "fiyat araştırması yap", "toplama sistemi v5". Enforces a browser-free fetch escalation ladder (curl_cffi→primp→Jina) + a price-verification gate so research never falls back to stale search snippets. Now has a deterministic structured extractor (akakce provider + pgList offers).
---

# budget-build-research v0.1

Research **verified, current** prices for a budget shopping list and assemble a **compatible** basket. Built to fix the v3/v4 failure where the agent hit Cloudflare 403 and used stale search snippets as prices.

## Hard rules (the Research Contract)

1. **Never use a search snippet as a price.** A price is valid ONLY if it comes from a fetched product page (see gate below).
2. **Always fetch via the ladder script** — do not hand-roll fetching:
   `python3 SKILL_DIR/scripts/fetch_ladder.py <url> --text`
   It tries curl_cffi → primp → Jina Reader automatically and reports which tier succeeded + whether the page was blocked.
3. **Price-verification gate** — every line item needs: source_url, price (TRY), seller, last_updated, stock_status, evidence (quote from fetched body). `extract_product.py` grades each record: **VERIFIED** (real price + ≥3 priced sellers + all category-mandatory specs present), **PARTIAL** (price exists but thin market, empty specs, or missing critical specs for compat — `missing_specs[]` lists them), **UNVERIFIED** (no usable price / fetch error). The category spec gate (`providers/specs_gate.py`) maps an akakce slug → required keys (CPU→Soket/Çekirdek/RAM Tipi, anakart→Soket/RAM Tipi/Form, RAM→Tipi/Kapasite, GPU→Chipset/RAM, PSU→Güç, SSD→Kapasite). Never treat PARTIAL/UNVERIFIED as a final price.
4. **"out_of_stock" requires fetched-page evidence.** Otherwise `unknown`. (Kills v4 false positives.)
5. **Cross-check the headline price:** ≥2 independent confirmations OR one aggregator page with ≥3 **distinct** sellers + a timestamp ≤7 days old. The extractor **enforces this** — a single-seller scalper listing (the dogfood "ylmzhome" Corsair case, 1 seller at 3-5×) is auto-downgraded to PARTIAL with a `thin_market_N_sellers` flag. Seller count is **deduped by normalized identity** (`base.distinct_sellers`) so one shop's spelling/case variants — the live pgList "Magıc Teknolojı / MAGIC TEKNOLOJİ / magic" case, 5 rows → 1 seller — can't fake a healthy market. It also flags `price_outliers` (median+IQR) so a bait low price or an inflated seller never becomes the "cheapest".
6. **Output must validate** against `references/output-schema.json` (run `scripts/validate_run.py`) before declaring done.

## Flow

> **Fast path — one call (A1):** for a whole shopping list, prefer the single-entry
> orchestrator over driving the steps by hand:
> `python3 SKILL_DIR/scripts/build.py --items '[{"query":"AMD Ryzen 5 7600","category":"islemci"}, ...]' --budget 25000`
> It runs **search → number-gated match → structured extract → confidence grade** per
> item, fully deterministically, and returns a graded taxonomic basket: per-item
> `status` (OK / AMBIGUOUS / NO_MATCH / ERROR), `cheapest_price`, `confidence`,
> `flags`, plus basket `total`, `within_budget`, `remaining`, `basket_confidence`,
> `warnings`. **The LLM submits the list and reads the result — it makes NO
> mid-pipeline decisions** (no eyeballing results, no picking a seller). A NO_MATCH is
> never silently substituted; an AMBIGUOUS item lists `rivals` for you to choose. Drop
> to the manual steps below only for one-off items or when build.py returns a status
> you must resolve. Budget over-run is flagged automatically (P1-2).

1. **Claude (reasoning):** build the shopping list, budget split, part tiers. Read `domains/pc-build/part-taxonomy.md` for TR aggregators + search patterns.
2. **Extract — structured first (Paradigm B):** for each item, prefer the deterministic extractor over eyeballing text:
   - **akakce.com** (and any registered provider): `python3 SKILL_DIR/scripts/extract_product.py --search "<model>"` to discover — the search output already includes a **number-gated `match`** (`match_reason`: `ok` = confident pick, `ambiguous` = rivals listed, you choose, `no_confident_match` = right variant absent, don't substitute). This kills the dogfood RM650→RM750 silent mismatch: a query number (650) absent from a candidate scores 0, so the wrong variant is never auto-selected. Take `match.url`, then `extract_product.py <product_url>` → typed JSON `{name, sku, specs, cheapest_price, cheapest_seller, last_updated, all_offers[], offer_count, price_median, price_stats, outlier_count, confidence, flags[]}`. The full per-seller list comes from akakce's internal `pgList` endpoint (price + stock + minute-precise timestamp), browser-free. The extractor picks the cheapest **non-outlier** offer and grades confidence (see rules 3 & 5). Add `--price-only` to skip the JSON-LD spec parse when only the price matters. **The LLM consumes this JSON, never raw HTML — but always check `confidence` + `flags`.**
   - **Unsupported sites / no JSON-LD:** fall back to `fetch_ladder.py <url> --text` and read the page (Paradigm A). Mark `UNVERIFIED` unless the price gate is met.
3. **Dispatch (optional, token-heavy):** for large sweeps, hand a worker prompt (`references/subagent-prompt-template.md`) to openclaude. For small runs Claude does it inline.
4. **Claude (review):** merge items → `scripts/validate_run.py` → `scripts/check_compat.py` (PC-build only) → final report (markdown table + JSON).

> **Why structured-first:** clean-markdown fetchers (firecrawl/jina) strip the `<script application/ld+json>` and the pgList JSON we depend on — they help human reading, not machine data. For prices we want RAW HTML/JSON. See `research/2026-06-29-budget-build-skill-iyilestirme/01-VIZYON-ve-MIMARI.md`.

## Setup (once)

`bash SKILL_DIR/scripts/bootstrap.sh` — creates a persistent venv with curl_cffi + primp (no browser).

## Providers (structured adapters, browser-free)
- `providers/akakce.py` — `search(q)` · `detail(url)` (JSON-LD) · `offers(key, referer)` (pgList, full seller list + stock + timestamp). Richest source; use for specs.
- `providers/cimri.py` — second aggregator (JSON-LD AggregateOffer). Price list only (no seller/stock/specs in its JSON-LD) — used as an **independent price cross-check**, not for specs.
- `providers/base.py` — shared curl_cffi session (warm-up + Referer), rate-limit, retry, JSON-LD parse, TR price normalization, outlier guard (`mark_outliers`/`cheapest_clean`).
- `providers/specs_gate.py` — category → mandatory-spec table (akakce key names).
- `providers/match.py` — product-identity matcher (`score`/`best_match`). Number-gated title matching; refuses wrong variants (RM650≠RM750) instead of silently substituting. Grounded to data we actually have (title+brand+specs) — akakce/cimri expose **no GTIN/MPN**, so a GTIN cascade is not buildable. Known limitation: letter-suffix variants (B650 vs B650M, 7600 vs 7600X) are not auto-rejected; they surface via `match_reason: ambiguous` or stay for the caller to weigh.
- Registry in `providers/__init__.py`. Adding a site = new `providers/<site>.py` with `search/detail/offers/get` + register it.

## Cross-provider check (anomaly guard)
For any item where one aggregator looks thin or suspicious, run:
`python3 SKILL_DIR/scripts/cross_check.py --search "<model>"` (or `--akakce <url> --cimri <url>`)
→ compares akakce vs cimri medians. Verdict: **CONFIRMED** (medians agree, trust it), **DISAGREE** (prices/products don't line up — verify manually; this is what catches the dogfood "ylmzhome" lone-scalper case), **SINGLE_SOURCE** (only one provider returned data). Emits `consensus_cheapest` that ignores bait prices below half of both medians.

## MCP (tools-bank) — the machine as tools

Exposed via tools-bank (subprocess bridge into this skill's venv; restart tools-bank
to load). Layered on purpose — one orchestrator + escape hatches + taxonomy admin, so
the agent is never trapped when the happy path hits an ambiguity:

- `budget_build_basket(items_json, budget=0)` — **primary**: list in, graded basket out.
- `budget_search(query, provider, limit)` — escape hatch for AMBIGUOUS/NO_MATCH (see candidates + match verdict).
- `budget_extract(url, price_only=False)` — extract+grade one chosen URL/rival.
- `budget_cross_check(query)` — akakce↔cimri anomaly guard.
- `budget_get_category_schema(category="")` / `budget_set_category_schema(category, required_json)` — **taxonomy registry**.

**Beyond PC (taxonomy):** the mandatory-spec gate is data-driven (`providers/specs_gate.py`
+ `data/category_schemas.json`). PC categories ship built-in; for anything else
(athlete's-foot cream, doormats) the agent defines the schema **once** —
`budget_set_category_schema("ayak-bakim", '[["etken madde"],["hacim","ml"]]')` — and the
engine grades that category deterministically forever after. LLM defines the schema
(rare, cached); the engine applies it (every item, deterministic). The price/seller/
outlier/dedup/cross-check core is already category-agnostic; only the spec taxonomy
needs this one-time definition. Unstructured Turkish listings (everything dumped in the
title) still get a verified price + correct identity; their specs may be absent → PARTIAL.

## References
- `references/research-contract.md` — full routing/gate/ladder detail
- `references/fetch-helpers.md` — fetch_ladder usage + Jina API key
- `references/output-schema.json` — run JSON schema
- `domains/pc-build/compatibility.md` — compat rules
- `research/2026-06-29-budget-build-skill-iyilestirme/` — design vision, architecture, empirical proofs (pgList endpoint, browser-free map)