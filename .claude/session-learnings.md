# Session Learnings — EgeSüt ERP

---

## Oturum 2026-05-25 — Treatment Timeline + Accordion

### Accordion Teknoloji Seçimi (KRİTİK)

**Sıralama (güvenilirlik sırasına göre):**
1. `display:none` / `display:block` toggle — en güvenilir, tüm tarayıcı/mobil ✅
2. `max-height:0 → max-height:Xpx` CSS transition — çoğu zaman çalışır, ama `overflow:hidden` parent içinde bazı mobillerde render etmez ⚠️
3. `<details>/<summary>` native HTML — masaüstü iyi, mobile Safari: summary click buton onclick'ini yutabilir, toggle → modal scroll kayması ❌

**Kural:** Vanilla JS template string içinde accordion → her zaman `display:none` ile başla.

### openAttr Mantığı (Accordion Default State)

```js
// YANLIŞ — kapalı vakada tüm günler açılır
const openAttr = (!isDone && !isLocked) ? 'open' : '';

// DOĞRU — sadece aktif vakada, sadece ilk aksiyon bekleyen gün açık
const firstActiveDay = aktif ? sortedDays.find(d => !d.tamamlandi && !d._locked) : null;
const openAttr = aktif && day === firstActiveDay;
```

### Template String UI'da Patinaj Neden Olur?

1. **Kör kodlama** — `innerHTML = template literal` çıktısı görünmez, her iterasyon push → test döngüsü
2. **Edge case körlüğü** — closed/active/locked state kombinasyonları template'de zihinsel simülasyon gerektirir
3. **Protokol:** Önce edge case'leri listele, sonra kodu yaz

### Frontend Patinaj Neden — YouTube vs Biz

YouTube'daki "1 prompt harika site" videoları şu koşullarda çalışır:
- Greenfield, standalone HTML dosyası — mevcut kod yok
- React/Tailwind/Next — framework semantik garantiler verir
- LLM çıktısı direkt tarayıcıda görünür — visual feedback loop hızlı
- Edge case yok — "kayıtlı vaka kapalıysa tüm günler lock'lu" gibi domain mantığı yok

**Bizim durumumuz:**
- Vanilla JS + `innerHTML` string templates — görünmez output, IDE yardımı yok
- Mevcut codebase constraints (CSS variables, inline handlers, IDB cache)
- Domain mantığı karmaşık (active/closed/locked/done state combinations)
- LLM + DeepSeek chain — plan → implement → test → fix döngüsü

**Ne yapmalı:**
1. **Önce statik HTML** — template'i JS'e koymadan önce plain HTML yaz, tarayıcıda gör
2. **Edge case listesi önce** — "kapalı vaka", "0 done", "hepsi done" → her birini açıkla
3. **Teknoloji seçimi önce** — accordion için hangi yöntem? → kararı planın başına yaz
4. **CSS class > inline style** — test edilebilir, tekrar kullanılabilir

### Yeni RPC'ler (2026-05-25)

| RPC | Açıklama |
|-----|----------|
| `treatment_day_tamamla(uuid, text)` | Sıralı done — önceki bitmeden sonraki done edilemez |
| `treatment_day_not_guncelle(uuid, text)` | treatment_days.notes güncelle (done'dan bağımsız) |
| `update_treatment_time(uuid, time)` | Tedavi saati güncelle (mevcut) |

---

## What Worked Well

- **Parallel agents for multi-issue discovery** — dispatching 2-3 agents to explore different aspects simultaneously (UI patterns, data flow, duplicate code) gave comprehensive context fast
- **`execute_sql` for DB changes** — applied migration SQL directly via MCP, works reliably
- **`getState` + `idbGetAll` pattern** — consistent way to read local cache; always check both when animal lookups fail
- **Plan-file-first** — updating SONARCLOUD_REMEDIATION_PLAN.md before implementing keeps decisions auditable

## What Didn't Work / Pitfalls

- **`apply_migration` MCP endpoint unavailable** — `UnauthorizedException`; use `execute_sql` instead for all DB changes
- **Patching one file without checking duplicates** — `tohSonuc` existed in both `ui.js` and `forms.js`; the ui.js version (unprotected, added earlier) silently overrode the forms.js version. Always `grep -n "function name"` across all JS files before patching.
- **`git revert` when user said things are "ok enough"** — user rejected revert attempt; when user says "push as-is", do it without cleanup
- **`git push` HTTPS auth** — token needed via `git remote set-url origin https://<token>@github.com/...`; not cached by default in this env

## MCP Usage Patterns

| Tool | Status | Notes |
|---|---|---|
| `mcp__supabase__execute_sql` | ✅ Works | Use for all DB reads and schema changes |
| `mcp__supabase__apply_migration` | ❌ Unavailable | `UnauthorizedException` — skip, use execute_sql |
| `mcp__supabase__list_tables` | ✅ Works | Good for schema exploration |
| `mcp__supabase__get_project_url` | ✅ Works | Needed for RPC calls |

## Tohumlama Module — Architecture Debt (next session)

Three write paths exist, only one goes through the validated RPC:
1. `tohSonuc()` in forms.js — direct PATCH (bypasses validation)
2. `tohSonucGuncelle()` in ui.js — direct PATCH (partially guarded)
3. `tohumlama_kaydet` RPC — correct path

Full refactor plan is in `SONARCLOUD_REMEDIATION_PLAN.md` under "🔴 TOHUMLAMA MODÜLÜ".
Proposed new RPCs: `tohumlama_sonuc_gebe`, `tohumlama_sonuc_bos`, `tohumlama_abort`.

## Oturum 2026-03-26 Ek Öğrenmeler

### Stok Sistemi
- Stok tabloları: `stok` + `stok_hareket` + `stok_tuketim_view`
- Sperma **dropdown'dan seçilir** — `stok` tablosundan `kategori='Sperma'` filtreyle gelir
- `tohumlama_kaydet` RPC stok düşer ama `ILIKE` eşleşmesi başarısızsa **sessizce atlar** — hata fırlatmaz
- Stok UI'da görünmüyorsa: `RPC_INVALIDATION_MAP`'te `stok`/`stok_hareket` eksik olabilir

### Geri Al Modal Sorunu
- `geriAl()` başarısında `closeM('m-geri-al')` var ama tohumlama detay modal (`m-td2`) açık kalıyor
- Geri al sonrası: `closeM('m-geri-al')` + `closeM('m-td2')` ikisi de çağrılmalı
- `renderSafe()` sayfayı yeniliyor ama açık modal içeriğini güncellemiyor

### Migration 028 Sınırı
- Migration 028 öncesi `islem_log.ref_id` = NULL → geri alma butonu görünmüyor (expected)
- 028 sonrası kayıtlarda `ref_id` = `tohumlama.id` (dolu)
- Eski kayıtları temizlemek için: `DELETE FROM tohumlama WHERE id NOT IN (SELECT ref_id FROM islem_log WHERE tip='TOHUMLAMA' AND ref_id IS NOT NULL)`

### Çoklu Gebe Kirli Veri
- `tohSonucGuncelle` / `gebeIsaretKaydet` hayvanın mevcut durumunu kontrol etmediğinden birden fazla "Gebe" kayıt oluşabiliyor
- Guard: `if (hayvan?.tohumlama_durumu === 'Gebe') { toast(...); return; }`

### Agent Knowledge Gap
- Agent dosyaları (`erp-db-agent.md`, `erp-frontend-dev.md`, `erp-explorer.md`) projeye özgü mekaniklerle güncellendi (2026-03-26)
- Her yeni proje mekaniği keşfedilince → ilgili agent dosyasına eklenmeli

## What to Avoid

- Don't add `console.log` debug lines to production files without removing them
- Don't assume `hayvan_id` is always UUID — can also be `kupe_no` (see domain-rules.md §1)
- Don't touch `Gebe` veya `Doğum Yaptı` tohumlama records from frontend directly — RPC only
- Don't skip confirm dialogs for destructive state transitions (Gebe→Boş, Gebe→Abort)
- **Agent'lara "stok sistemi nedir?" veya "sperma nasıl seçilir?" sormayın** — cevap artık agent dosyalarında mevcut

---

## Oturum 2026-05-23 — Orchestrator-Master Skill Tasarımı

### Ne Yapıldı
`orchestrator-master` adında tek bir DeepSeek TUI skill'i oluşturuldu. İki modu var: **research** (flat, parallel) ve **hierarchical** (recursive, depth-controlled).

### Skill Yeri
- `.agents/skills/orchestrator-master/SKILL.md` — proje kökünde
- `feature-dev` skill'i ile yan yana duruyor

### Mimari Kararlar

| Karar | Sebep |
|-------|-------|
| **Tek skill, iki mod** | Kullanıcı tek bir `/skill orchestrator-master` ile her iki işi de yapabilir. Mode auto-detect. |
| **Sub-agent'lar read-only (research modu)** | `type: explore` ile garanti. Keşif için paralel, yazma için serial. |
| **Hierarchical modda herkes yazabilir** | Ama sadece kendi territory'sinde. Territory disjoint olduğu sürece çakışma olmaz. |
| **max_depth ile recursion kontrolü** | DeepSeek TUI'nin built-in `agent_open(max_depth=N)` parametresi kullanılır. Main=3, Sub=2, Sub-sub=1, Leaf=0. |
| **Quota sistemi (≤20)** | Total agent sayısı 20 ile sınırlı. Her sub-orch kendi quota'sını yönetir. Prompt ile enforce edilir. |
| **Dil ayrımı** | Skill body ve sub-agent iletişimi İngilizce. Main agent kullanıcıyla Türkçe konuşur. |
| **fork_context: true her zaman** | Prefix cache korunur, context şişmesi azalır. |
| **handle_read büyük çıktılar için** | Sub-agent çıktısı >50 satır ise context'e kopyalama, handle_read ile projeksiyon al. |
| **Janitor agent yok** | Checklist + PLAN.md yeterli. Fazladan agent context şişirir. |
| **feature-dev silinmedi** | Eski skill geriye dönük uyumluluk için duruyor. orchestrator-master onun yerini alabilir. |

### Kullanım

```bash
# Research modu (otomatik)
/skill orchestrator-master
Görev: Şu konuyu araştır...

# Hierarchical modu (otomatik)
/skill orchestrator-master  
Görev: Kullanıcı giriş sistemi implemente et...

# Hem araştırma hem implementasyon
/skill orchestrator-master
Görev: Web'den auth pattern'lerini araştır, sonra implemente et.
```

### Sub-agent Prompt Dili
- Tüm sub-agent prompt'ları **İngilizce** yazılır
- Sub-agent'lar kendi arasında **İngilizce** konuşur
- Alt seviye orkestratörler kendi children'larına İngilizce prompt verir
- Sadece main agent kullanıcıya cevap yazarken kullanıcının dilini kullanır

### Önemli Uyarılar
- Research modunda batch aç (tüm agent'ları tek turda). Serial açma.
- Hierarchical modda territory'ler disjoint olmalı. İki agent aynı dosyayı sahiplenemez.
- Quota aşımı → sub-orch reddeder, parent'a rapor eder. Parent yeniden dağıtır.
- Test gate: her dosya sonrası test. FAIL → `git revert HEAD`, düzelt, tekrar dene.
- Son çare çakışma çözümü: projeyi klonla, her ekibe ayrı workspace ver, sonra merge.

---

## Oturum 2026-06-12 — BUG-059 Faz 4 (Live Smoke Test + Final Handoff)

### Pattern 1: Cast Hatası Doğrulama Zinciri (KRİTİK)

**Her SQL/RPC yazmadan önce 3 sorgu zorunlu:**

```sql
-- 1. Tablo var mı?
SELECT to_regclass('public.tablo_adi');
-- NULL ise → tablo yok, hata

-- 2. Kolon adı + tipi doğru mu?
SELECT column_name, data_type, udt_name
FROM information_schema.columns
WHERE table_schema='public' AND table_name='tablo_adi' AND column_name='kolon';

-- 3. FK tipi (özellikle parent_id, *_id gibi)
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid='public.tablo'::regclass AND contype='f';
```

**Bu 3'ü yapmadan yazılan spec → %60 cast hatası** (T2 + T7'de 4 bug çıktı).

**Yakalanan hatalar (BUG-059):**
- `gorev_log.parent_id` uuid ama `::text` cast (Bug A)
- `drug_admins` rename edilmiş → `drug_administrations` (Bug B)
- `drug_administrations.uygulama_tamamlandi_at` kolonu yok (Bug C)
- `cases.end_date` kolonu yok → `status, closed_at` kullan (Bug D)

### Pattern 2: Spec Üretim Metodolojisi

**Adımlar (production fix için):**
1. **Ground truth'tan al** — `99999999999999_ground_truth.sql` canonical referans (10.780 satır, 437KB). Ara migration'lar (revize/fix) şüpheli, **asla referans alma**.
2. **Satır aralığını belirle** — `grep -n "CREATE OR REPLACE FUNCTION" ground_truth.sql` ile fonksiyon başlangıç satırı bul.
3. **Sed ile minimal fix** — `sed -i '3333s/old/new/'` gibi. Diff'i `git diff` ile gözden geçir.
4. **Production deploy** — `supabase_migrate` ile. `-- source:` yorum otomatik eklenir.
5. **Verify** — `psql -c "SELECT prosrc FROM pg_proc WHERE proname='rpc'"` ile production'dan prosrc çek, ground truth ile birebir diff yap.
6. **Ground truth sync** — Aynı fix'i ground truth'a uygula, tek commit'te push et.

**Test ortamı:** Canlı Supabase + test case UUID'si + test hayvan UUID'si (production'la aynı DB).

### Pattern 3: Idempotent RPC Pattern (KRİTİK)

**`treatment_day_tamamla` gibi "kapat" RPC'leri idempotent olmalı:**
- 1. çağrı: `ok=true, step='uygulanmadi_ok'`
- 2. çağrı (aynı state): `ok=true, step='zaten_tamam'` (HATA DEĞİL)
- 3. çağrı (farklı state): normal işlem

**Neden:** UI butonuna 2 kez tıklayınca hata almamak için. Frontend'de her RPC sonrası `pullTables()` çağrılır — eğer RPC hata fırlatırsa UI state tutarsız olur.

**Counter sayımı yanıltıcı olabilir:** T7 `iade_edilen_stok=5` dedi ama 6 hareket iptal edildi (T4'ün 1 iadesi + T7'nin 5'i). RPC sadece yeni iptalleri sayıyor. UI'da bu sayıya güvenmeyip `SELECT COUNT(*)` ile doğrula.

### Pattern 4: Stok Hareket İade — String Pattern Matching

**`stok_hareket.notlar` kolonunda string pattern kullanılıyor:**
```sql
'notlar', 'drug_admin:' || drug_admins.id::text
```

**Parse:** `split_part(sh.notlar, ':', 2)::uuid` ile UUID çekilebilir.

**Alternatif düşünülebilirdi:** `drug_admin_id uuid` kolon ekle (Faz 1'de yapılmadı, geriye dönük uyumluluk için pattern korundu).

**UI için:** Stok raporlarında JOIN yaparken `notlar` parse etmek gerekirse yukarıdaki pattern'i kullan.

### Pattern 5: Edit Tool Hata Ayıklama

**Belirti:** `edit` tool "No match found for the specified text" hatası — aslında dosya değişmiş ama tool eşleşmiyor.

**Sebep:** Sondaki `\n` veya boş satır farkı, satır sonu karakteri (LF vs CRLF) farkı, görünmez karakter.

**Çözüm protokolü:**
1. `tail -3 dosya.md | cat -A` ile gerçek son satırı gör (M-... = multibyte)
2. Sondaki 1-2 satırı kopyala, **birebir** eşleştir (son satır dahil)
3. Hâlâ hata → `wc -l` ile satır sayısını doğrula
4. Son çare: `write` ile dosyayı baştan yaz (ama büyük dosya parse hatası riski var)

**Bu oturumda:** §8-§9 eklendikten sonra §10 eklemesinde 2 deneme hata aldı, 3. denemede `tail -1 | cat -A` ile son satırı görüp eşleştirince başarılı oldu.

### Pattern 6: Çok Büyük Tool Call Hatası

**Belirti:** `A tool call could not be parsed — the response may have been truncated. Try breaking the task into smaller steps or resending your message.`

**Sebep:** Tek seferde yazılan içerik çok büyük (>5KB) + JSON encoding.

**Çözüm:**
- `write` ile dosya oluştur → büyükse parçalara böl
- `edit` ile parça parça ekle (her edit <100 satır)
- `read` ile her edit öncesi son satırı doğrula

**Bu oturumda:** Final handoff 871 satır → `write` ile başlık + `edit` ile 7 parça (her biri <200 satır).

