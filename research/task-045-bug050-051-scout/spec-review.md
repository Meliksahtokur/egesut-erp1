# TASK-045 Spec Review — Bulgular ve Sapmalar

**Tarih:** 2026-06-05
**Review eden:** DeepSeek TUI (scout sonrası)
**Spec kaynağı:** `.claude/tasks/dev/task-045-bug049-051-scout-fix.md`

---

## 1. Genel Uyum

| Spec Maddesi | Durum | Sapma |
|---|---|---|
| BUG-049 timezone fix (Claude) | Bekliyor | Claude'a bırakıldı |
| BUG-050 scout | ✅ Tamamlandı | `bug050-duplikat-kontrol-haritasi.md` |
| BUG-051 scout | ✅ Tamamlandı | `bug051-dogum-sonrasi-stale-state.md` |
| Scop'ta olmayan trigger analizi | ✅ Fazladan yapıldı | fn_islem_log, fn_gebe_gorev_yarat, cycle guard |
| Çıktı formatı | ✅ Uyumlu | Tablo + BUG-050-ÇAKIŞMA-[N] formatı |

---

## 2. Araç Uyumsuzlukları

Spec'te belirtilen bazı araçlar tools-bank MCP'de mevcut değil:

| Spec Aracı | Durum | Kullanılan Alternatif |
|------------|-------|-----------------------|
| `mcp__gitnexus__tool_map` | ❌ Yok | `gitnexus_query` + `grep_files` migration taraması |
| `mcp__gitnexus__api_impact` | ❌ Yok | `gitnexus_impact(target, direction="upstream")` |
| `mcp__gitnexus__shape_check` | ❌ Yok | Manuel return/shape karşılaştırması |
| `mcp__gitnexus__rename` | ❌ Yok | Not edildi, refactor aşamasında manuel |

Not: tools-bank-mcp SKILL.md'de bu isimlerde araç bulunmuyor. Bunlar spec yazılırken planlanmış ama implemente edilmemiş olabilir.

---

## 3. BUG-049 — Spec'te Atlanan Nokta

Spec `ground_truth.sql` içinde `NOW()` taramasından bahsediyor. 
Ancak **canlı migration dosyalarında** da CURRENT_DATE kullanımı var:

| Dosya | Kullanım |
|-------|----------|
| `supabase/migrations/20260526000003_ek_uygulama_stok.sql:64` | `IF p_tarih > CURRENT_DATE THEN` |
| `supabase/migrations/20260308000009_sperma_stok_fix.sql:276` | `IF p_tarih > CURRENT_DATE THEN` |

Fix migration'ı yazılırken **hem ground_truth.sql hem de canlı migration'daki RPC** güncellenmeli.

---

## 4. BUG-050 — Spec'ten Fazla Bulgular

Spec sadece doğum/tohumlama/gebelik kontrol mekanizmalarını istemişti.
Ek olarak bulunanlar:

- **Trigger seviyesi kontroller:** fn_islem_log, fn_gebe_gorev_yarat, tohumlama cycle guard
- **Stok kontrol noktaları:** case_management + vaccination modülünde RAISE EXCEPTION
- **Sıralı tedavi kontrolü:** `treatment_day_done.sql` sequential guard

---

## 5. BUG-051 — Spec'in Öngörmediği Kök Neden

Spec "anyonik görev iptal edilmiyor" diyordu.
Beklenen: bir frontend veya RPC çağrısı unutulmuş olabilir.
**Gerçek:** `20260603000001_protokol_etken_kod.sql` migration'ı `CREATE OR REPLACE FUNCTION public.dogum_kaydet` yaparken BESLEME bloğunu **düşürmüş.** Bu migration overwrite'ı spec'te öngörülmemişti.

**İkinci bulgu:** `submitBirth`'te pullTables listesinde `tohumlama` eksik — bu da ileri_gebe stale state'in ikinci sebebi (spec'te yok).

---

## 6. Yapılmayanlar / İleri Adımlar

| Yapılmadı | Sebep | Ne zaman yapılmalı |
|-----------|-------|-------------------|
| `supabase_query` ile canlı DB doğrulama | Migration'lar yeterli bilgi verdi | Fix migration öncesi isteğe bağlı |
| BUG-049 timezone fix | Spec Claude'a demişti | Claude bekleniyor veya devralınabilir |
| BUG-050 fix (refactor) | Scout aşaması bitti, karar bekliyor | Fix aşamasında |
| BUG-051 fix | Scout aşaması bitti, onay bekliyor | Fix aşamasında |

---

## 7. Puan Tablosu

| Kriter | Puan | Açıklama |
|--------|------|----------|
| Kapsam | 9/10 | Tüm spec maddeleri karşılandı |
| Araç kullanımı | 7/10 | Spec araçları yoktu, alternatif kullanıldı |
| Derinlik | 9/10 | Beklenenden fazla bulgu (migration overwrite) |
| Çıktı formatı | 9/10 | Spec formatına uygun + ek bölümler |
| Fix netliği | 8/10 | BUG-051 net, BUG-050 fix kararı bekliyor |
