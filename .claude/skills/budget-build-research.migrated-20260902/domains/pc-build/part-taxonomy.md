# PC parts taxonomy + TR search hints

Categories (research each as a line item): cpu, motherboard, ram, gpu, ssd, psu, case, cooler.

## TR aggregators (Cloudflare — use fetch_ladder)
- akakce.com — best multi-seller price + "Son güncelleme" timestamp + seller count
- cimri.com — second aggregator for cross-check
- vatanbilgisayar.com, incehesap.com, n11.com, hepsiburada.com, trendyol.com — direct sellers

## Search patterns (discovery via mcp__duckduckgo__search)
- `akakce.com <model> fiyat` → opens the akakce product page (has ≥N sellers + timestamp)
- `cimri.com <model> fiyat` → cross-check source
- For a category sweep: `akakce.com <category> en ucuz` (e.g. "akakce.com ddr5 32gb 6000 en ucuz")

## Per-item spec fields to capture (for compatibility)
- cpu: socket, tdp
- motherboard: socket, form_factor, ram_type
- ram: type (DDR5/DDR4)
- gpu: tbp, length_mm (if listed)
- psu: watt
- case: form_factor, gpu_clearance_mm (if listed)
- ssd: count toward ssd_count; cooler: tdp_rating