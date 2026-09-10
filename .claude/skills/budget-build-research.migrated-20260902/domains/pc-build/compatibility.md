# PC-build compatibility rules

Apply with `scripts/check_compat.py <basket.json>`. Verdict logic:
- Hard contradiction with KNOWN data → FAIL
- Rule not evaluable (missing data) → WARN
- All evaluable rules pass → PASS

Rules:
1. CPU socket == motherboard socket (AM5, LGA1851, ...)
2. RAM type == motherboard memory type (AM5/LGA1851 → DDR5)
3. PSU watt ≥ (CPU TDP + GPU TBP) × 1.4
4. Motherboard form factor fits case (ATX accepts ATX/mATX/ITX; mATX accepts mATX/ITX; ITX accepts ITX)
5. GPU length ≤ case GPU clearance
6. SSD count ≤ M.2 slot count
7. Cooler TDP rating ≥ CPU TDP

Basket JSON shape: see check_compat.py docstring.