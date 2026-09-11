# W2-fix2 — luna F4 + F5: late-writer fence + integrityReport mühür istisnası

Bağımsız luna review (`.claude/reviews/2026-09-11-pedigree-p2-lead-review.md`):

- **F4 [race-lifecycle, major]:** cache miss sonucu `await` sonrası koşulsuz yazılıyor;
  `invalidateCache()` yalnız Map'i temizliyor. Luna'nın doğrudan ölçümü:
  `invalidateCache()` in-flight istekten ÖNCE koştu, yine de eski yanıt önbelleği
  doldurdu (`sizeAfterLateWriter:1, cached:true`) — yazma sonrası ilk ağaç eski
  veriyle servis edebilir.
- **F5 [doc-drift, minor]:** `_sealCached()` `meta.cached`'yi her nesneye basıyor;
  `integrityReport()` da bu yoldan geçiyor. P1 RPC kontratı `cutoff/generated_at/groups`
  — üst-düzey alan eklemek kontrat sapması (Luna'nın shape probe'u `meta`'yı 4. alan
  olarak gördü).

## Düzeltmeler

1. **F4 — yazma engeli (fence):** istek başlangıcında bir **revizyon sayacı** yakala;
  yanıt döndüğünde sayaç değiştiyse (arada invalidate olduysa) önbelleğe YAZMA ve
  yanıtı ağ sonucu olarak döndür (cache'e alma). `invalidateCache()` TAM boşaltma +
  sayaç artışı yapar. In-flight istek sayısını beklemek GEREKMEZ — fence yeter.
2. **F5 — mühür kapsamı:** `meta.cached` yalnız **projection** payload'larında
  (`subgraph*`) basılsın; `integrityReport()` dönüşü P1 kontrat şekline sadık kalsın
  (üst-düzey `meta` ekleme). Saklanan snapshot saflığı korunur.
3. **Testler:** (a) luna'nın senaryosu kilitlenir — deferred/iletim-gecikmeli RPC +
   invalidate yarışı: geç yazan cache'e GİRMEZ, sonraki okuma ağa gider; (b) invalidate
   sonrası taze istek normal akış (mevcut testler korunsun); (c) `integrityReport()`
   dönüşünde üst-düzey `meta` alanı YOK + `groups/cutoff/generated_at` mevcut;
   (d) subgraph cache-servisinde `meta.cached===true` (mevcut test korunsun).

## Kabul

- `npm run test:unit` → yeşil + regresyonsuz (known-red gecmis-pipeline hariç).
- Teslim notunda: iki düzeltmenin özeti + subagent review notu.

## Sınırlar

- Yalnız `js/pedigree/pedigree-api.js` + `tests/unit/pedigree-{api,cache}.test.js`.
- RPC/migration (W1), frontend (W3), vendor DOKUNMA. PROD YASAK.

## Teslim

- `idle/pedigree-p2-W2` üzerine yeni commit. Kırıntı: merkezî
  `/home/melik/egesut-erp1/.crumbs/pedigree-p2-w2.jsonl`.
