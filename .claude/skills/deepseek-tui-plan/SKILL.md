# DeepSeek TUI Plan Yönetimi

Bu skill, implementasyon fikrini DeepSeek TUI'ye uygun bir plan dosyasına dönüştürmek için kullanılır.

**Tetikle:** Kullanıcı "DeepSeek'e ver / DeepSeek yapsın / Goose yok" dediğinde.

---

## DeepSeek TUI Araç Haritası

### Skills (DeepSeek'in kendi sistemi)
| Skill | Kullanım |
|-------|---------|
| `/skill:executing-plans` | Plan dosyasını adım adım çalıştırır, batch+checkpoint |
| `/skill:delegate` | Bağımsız subtask'ları `agent_open/eval/close` ile dağıtır |
| `/skill:subagent-driven-development` | Bağımsız task'lar için paralel subagent |
| `/skill:egesut-erp-architecture` | ERP mimari kuralları (pre-check zorunlu) |
| `/skill:systematic-debugging` | Beklenmedik hata varsa |
| `/skill:verification-before-completion` | Her task sonrası doğrulama |

### MCP Tools (tools-bank)
| İhtiyaç | Exact Araç |
|---------|-----------|
| DB okuma | `supabase_query({table, filters, select, limit})` |
| RPC çağrısı | `supabase_rpc({function_name, params})` |
| Migration deploy | `supabase_migrate({sql: "..."})` |
| Kod arama | `semantic_search({query, limit})` |
| Sembol etkisi | `gitnexus_impact({target, direction: "upstream"})` |
| Execution flow | `gitnexus_query({query})` |
| Commit sonrası değişiklik kontrolü | `gitnexus_detect_changes({scope: "staged"})` |
| Bellek arama | `memory_search({query, category})` |
| Karar kaydet | `memory_add({content, category: "code_change", priority: "high"})` |

### Native (bash)
```bash
cat /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql
sed -n '100,200p' /root/egesut-erp1/js/ui.js
node --check /root/egesut-erp1/js/ui.js
git add ... && git commit -m "..." && git push origin main
```

---

## Adım 1 — Planı Kafanda Kur

Şunları netleştir:
- Bağımlılık sırası (hangi task hangi task'a bağlı)
- Paralel koşabilecek bağımsız task'lar → `delegate` ile verilebilir
- DB değişikliği olan task'lar → onay gerektiren noktalara bayrak koy
- JS değişikliği olan task'lar → `node --check` adımı ekle
- Doğrulama kriterleri (beklenen DB sonucu, beklenen davranış)

Belirsizlik varsa kullanıcıya sor, planı yazmaya başlama.

---

## Adım 2 — Planı DeepSeek Formatına Dönüştür

`executing-plans` skill'inin beklediği format:

### Plan Dosyası Yapısı

```markdown
# [Özellik Adı] — Implementasyon Planı

> Soru varsa devam etmeden önce sor. DB değişikliklerinde onay bekle.

**Hedef:** [tek cümle]
**Etkilenen dosyalar:** [liste]

---

## Başlamadan Önce

Sırayla oku (atla):
1. `cat /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql`
2. `cat /root/egesut-erp1/.claude/rpc-reference.md`
3. `cat /root/egesut-erp1/.claude/domain-rules.md`

Sonra planı oku, net olmayan şey varsa sor.

---

## Task 1 — [Başlık]

**Okuma:**
[Exact komut — hangi dosya/tablo, hangi araç]

**ONAY GEREKLİ:** (DB değişikliği varsa bu blok)
[SQL/değişiklik özetini göster → "Onaylıyor musunuz?" sorusunu sor → cevap gelmeden devam etme]

**Uygulama:**
[Exact araç çağrısı veya bash komutu — tam SQL içerik dahil]

**Doğrulama:**
[supabase_query veya supabase_rpc → beklenen sonuç ne]

**Commit:**
`git add [dosyalar] && git commit -m "[tip]([kapsam]): [açıklama]"`
```

### Komut Yazma Kuralları

- **Tam SQL yaz** — "şunu ekle" değil, migration bloğunun tamamını ver
- **Exact araç** — "sorgula" değil `supabase_query({table: "gorev_log", filters: "gorev_tipi=eq.BESLEME", limit: 5})` yaz
- **Onay noktası açık** — DeepSeek onayı beklemeden geçemesin
- **Referans:** sadece `ground_truth.sql` + `rpc-reference.md` — `*_revize.sql` yasak
- **Migration ≠ canlı** — `supabase_migrate({sql: "..."})` ile ayrıca deploy et

### Paralel Task'lar İçin (`delegate`)

Task'lar birbirinden bağımsızsa plana şunu ekle:

```markdown
## Task 2 + Task 3 — Paralel Çalıştır

Bu iki task birbirinden bağımsız. `/skill:delegate` ile paralel aç:

**Task 2 — [Başlık]** (dosya sahipliği: `js/ui.js`)
[açıklama + acceptance criteria]

**Task 3 — [Başlık]** (dosya sahipliği: `js/api.js`)  
[açıklama + acceptance criteria]

Her ikisi bitince: değiştirilmiş dosyaları doğrudan oku, sonra birleştir.
```

---

## Adım 3 — Plan Dosyasını Yaz

Dosya yolu: `docs/superpowers/plans/[YYYY-MM-DD]-[konu].md`

Ton: kullanıcının yazdığı gibi — imperatif, Türkçe, "Claude" referansı yok.

---

## Adım 4 — Kullanıcıya Ver

```
Plan hazır: docs/superpowers/plans/[dosya-adı].md

DeepSeek'e ilk prompt:
---
/skill:executing-plans

Plan: /root/egesut-erp1/docs/superpowers/plans/[dosya-adı].md

Başlamadan önce plan dosyasını ve ground_truth.sql'i oku.
DB değişikliklerinde onay bekle, sorum varsa sor.
---
```
