# TASK-045 — BUG-049/050/051 Scout + Fix

**Oluşturulma:** 2026-06-05
**Durum:** bekliyor
**Öncelik:** yüksek

---

## Kapsam

| Bug | Başlık | Tip |
|-----|--------|-----|
| BUG-049 | Timezone — gece 02:00 doğum kaydı reddediliyor | Fix (scout gereksiz) |
| BUG-050 | Duplikat doğum/tohumlama/gebelik kontrol mekanizmaları | Scout → harita → karar |
| BUG-051 | Doğum sonrası anyonik görev devam ediyor, ileri gebeler güncellenmez | Scout → fix |

---

## BUG-049 — Timezone Fix (Claude direkt yapar)

**Kök neden:** Supabase DB UTC çalışıyor. Türkiye UTC+3. Gece 02:00 TR = 23:00 UTC önceki gün.
Date karşılaştırması yapan RPC'ler `NOW()` yerine `NOW() AT TIME ZONE 'Europe/Istanbul'` kullanmalı.

**Fix adımları:**
1. `ground_truth.sql` içinde `NOW()` kullanan tüm RPC'leri tara (özellikle doğum/tohumlama)
2. Date karşılaştırması yapan yerleri `AT TIME ZONE 'Europe/Istanbul'` ile güncelle
3. `CURRENT_DATE` kullananları da `(NOW() AT TIME ZONE 'Europe/Istanbul')::date` yap
4. Migration olarak yaz, test et, push et

**Not:** İleride auth sisteminde kullanıcı bazlı timezone ayarı (ayarlar tablosu → `timezone` kolonu).

---

## BUG-050 + BUG-051 — Scout Spec (DeepSeek TUI)

### SKİLL ve ARAÇLAR

```
SKİLL: tools-bank-mcp  (oturum başında yükle — tüm araçlar buradan)

ARAÇ ÖNCELİK SIRASI:
1. mcp__gitnexus__tool_map      → Tüm RPC tanımları + handler haritası
2. mcp__gitnexus__api_impact    → RPC değişikliği öncesi consumer + risk raporu
3. gitnexus_query               → Execution flow, semantic arama
4. gitnexus_context             → Tek sembolün tam caller/callee listesi
5. ast_grep_search              → Pattern bazlı yapısal doğrulama
6. semantic_search              → Kavramsal fallback (gitnexus bulamazsa)
7. supabase_query               → DB tarafı doğrulama
```

> GitNexus index taze olmalı. İlk iş: `gitnexus_list_repos()` → repo görünüyorsa devam,
> görmüyorsa terminalde `npx gitnexus analyze` çalıştır.

---

### BÖLÜM A — BUG-050: Duplikat Kontrol Mekanizmaları Haritası

**Hedef:** Sistemdeki tüm doğum / tohumlama / gebelik kontrol noktalarını tespit et,
hangilerinin çakıştığını veya aynı işi yaptığını raporla.

**ADIM 1 — RPC haritasını çıkar:**
```
mcp__gitnexus__tool_map()
→ Tüm Supabase RPC tanımlarını listele
→ "dogum", "tohumlama", "gebelik", "kontrol", "check" içerenleri filtrele
→ Her birinin handler dosyasını not al
```

**ADIM 2 — Her kontrol RPC'si için api_impact:**
```
mcp__gitnexus__api_impact(route="dogum_kaydet")
mcp__gitnexus__api_impact(route="tohumlama_ekle")   # varsa
→ Consumer sayısı, risk seviyesi, hangi frontend fonksiyonları çağırıyor
→ MEDIUM/HIGH risk olanları işaretle
```

**ADIM 3 — Execution flow ile kontrol zincirini izle:**
```
gitnexus_query("doğum kontrolü izin geçerli")
gitnexus_query("tohumlama kontrol uygun hayvan durum")
gitnexus_query("gebelik kontrol mekanizması")
→ Her sonuç için gitnexus_context(sembol) çağır
→ Aynı iş yapan farklı fonksiyonları tespit et
```

**ADIM 4 — Frontend kontrol noktaları:**
```
ast_grep_search("function $NAME($$$) { $$$ }", lang="javascript", path="js/")
→ İsimde: kontrol/check/dogrula/gecerli/valid/izin içerenleri listele
ast_grep_search("if ($$$kontrol$$$)", lang="javascript", path="js/")
```

**ADIM 5 — DB tarafı (RAISE EXCEPTION noktaları):**
```
semantic_search("RAISE EXCEPTION kontrol doğum tohumlama")
→ Hangi RPC'ler DB seviyesinde guard koyuyor?
```

**ÇIKTI FORMAT:**
```
| Mekanizma Adı | Tip (RPC/JS/DB) | Dosya:Satır | Ne kontrol ediyor | Caller'ları | Çakışma riski |
```
Ayrıca: çakışma tespit edilirse "BUG-050-ÇAKIŞMA-[N]" olarak numaralandır.

---

### BÖLÜM B — BUG-051: Doğum Sonrası Stale State

**Hedef:** `dogum_kaydet` çalıştıktan sonra neden anyonik görev iptal edilmiyor
ve ileri_gebeler tablosu neden güncellenmez?

**ADIM 1 — dogum_kaydet'in tam anatomisi:**
```
mcp__gitnexus__api_impact(route="dogum_kaydet")
→ Kaç consumer var, hangi frontend fonksiyonları çağırıyor, risk seviyesi
→ Sonra: gitnexus_context("dogum_kaydet")
→ Tüm callee'ler: RPC içinde ne çağrılıyor? (gorev iptali var mı?)
```

**ADIM 2 — Anyonik görev iptal mekanizması:**
```
gitnexus_query("anyonik besleme görevi iptal tamamla")
gitnexus_context("besleme_gorevi_iptal")   # varsa
ast_grep_search("anyonik", lang="javascript", path="js/")
supabase_query(table="gorev_log", filters="aciklama=like.*anyonik*", limit=5)
→ Doğum yapan hayvanın anyonik görevi hala "aktif" mi?
→ Görevi iptal eden/kapatan fonksiyon var mı? Nerede?
```

**ADIM 3 — ileri_gebeler güncelleme:**
```
gitnexus_query("ileri gebeler tablosu güncelleme refresh invalidation")
ast_grep_search("ileri_gebe", lang="javascript", path="js/")
→ Kim okuyor (render), kim güncelliyor (invalidate)?
→ dogum_kaydet sonrası invalidation tetikleniyor mu?
```

**ADIM 4 — Shape kontrolü:**
```
mcp__gitnexus__shape_check()
→ dogum_kaydet'in döndürdüğü ile frontend'in beklediği uyuşuyor mu?
→ Eksik alan var mı?
```

**ÇIKTI FORMAT:**
```
dogum_kaydet mevcut yan etkiler:
- [liste]

Eksik yan etkiler:
- [ ] Anyonik görev iptali → nerede olmalı: RPC içi / frontend trigger
- [ ] ileri_gebeler invalidation → nerede olmalı: RPC içi / realtime / manuel

Önerilen fix yaklaşımı: [A: RPC içine ekle | B: frontend'de dogum_kaydet sonrası tetikle | C: ikisi]
Risk: [LOW/MEDIUM/HIGH]
```

---

## Akış

```
1. Claude → BUG-049 timezone fix (direkt, bu session)
2. DeepSeek TUI → BUG-050 + BUG-051 scout (bu spec)
3. Scout çıktısı gelince → Claude veya DeepSeek fix yapar
```

---

## Notlar

- BUG-050, BUG-012 ile örtüşüyor (aynı domain duplikat mekanizmaları)
- `mcp__gitnexus__rename` — BUG-050 refactor aşamasında duplikat fonksiyonları birleştirirken kullan
- Timezone fix migration'ı `ground_truth.sql`'e de yansıt
