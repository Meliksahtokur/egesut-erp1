# DeepSeek TUI — Master Orchestrator

Bu skill, görev talebini DeepSeek TUI'ye uygun orkestrasyon planına dönüştürür.

**Tetikle:** Kullanıcı "DeepSeek'e ver / DeepSeek yapsın / Goose yok / planla" dediğinde.

---

## Adım 0 — Topoloji Belirle (Ruflo Pattern)

Plan yazmadan önce task bağımlılıklarını çıkar:

```
Tüm task'ları listele → bağımlılık grafiği çiz → topoloji seç
```

| Topoloji | Ne Zaman | Örnek |
|----------|----------|-------|
| **Hierarchical** | Sıralı bağımlı task'lar | Migration → JS → Commit |
| **Mesh** | Bağımsız paralel task'lar | JS değişikliği + SQL değişikliği aynı anda |
| **Ring** | Pipeline — her adım bir sonrakini besler | Analiz → Transform → Validate → Yükle |
| **Star** | 1 koordinatör + N bağımsız worker | Claude koordinatör + 3 DeepSeek worker |

Topolojiyi plan başına yaz: `> Topoloji: Hierarchical | 5 task | 2 paralel blok`

---

## Adım 1 — Model Routing Kararı Ver

Plan başında her task için model belirle:

| Task Tipi | Model | Gerekçe |
|-----------|-------|---------|
| Rutin okuma, basit kod | `deepseek-chat` (flash) | Hızlı, ucuz |
| Karmaşık SQL, mimari karar | `deepseek-chat` (flash yeterli) | Default |
| Kritik mantık, step-by-step reasoning | `deepseek-reasoner` | Kullanıcı onayı gerekir |
| Onay, risk değerlendirmesi | Claude direkt | Orchestrator rolü |

Plan başına ekle: `> Model: deepseek-chat (flash) — aksi belirtilmedi`

---

## Adım 2 — Planı Kafanda Kur

- Bağımlılık sırası (hangi task hangi task'a bağlı)
- Paralel koşabilecek bağımsız task'lar → Mesh blok
- DB değişikliği olan task'lar → onay bayrakları
- JS değişikliği → `node --check` adımı
- 5+ task → checkpoint noktaları belirle
- Belirsizlik varsa kullanıcıya sor, planı yazmaya başlama

---

## Adım 3 — Planı Yaz

### Plan Dosyası Formatı

```markdown
# [Özellik Adı] — Implementasyon Planı

> Topoloji: [Hierarchical|Mesh|Ring|Star] | [N] task | [M] paralel blok
> Model: deepseek-chat (flash) — aksi belirtilmedi
> Soru varsa devam etmeden önce sor. DB değişikliklerinde onay bekle.

**Hedef:** [tek cümle]
**Etkilenen dosyalar:** [liste]

---

## Başlamadan Önce

Sırayla oku:
1. `cat /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql`
2. `cat /root/egesut-erp1/.claude/rpc-reference.md`
3. `cat /root/egesut-erp1/.claude/domain-rules.md`

Sonra planı oku, net olmayan şey varsa sor.

---

## Task 1 — [Başlık]

**Okuma:**
[Exact komut — hangi dosya/tablo, hangi araç]

**ONAY GEREKLİ:** ← sadece: bulk UPDATE/DELETE, DROP, canlı veri değişimi
[SQL taslağını göster → "Onaylıyor musunuz?" sorusunu sor → cevap gelmeden devam etme]
Rutin DDL (ADD COLUMN, CREATE FUNCTION, CREATE TRIGGER, CREATE INDEX) → onay bloğu KOYMA.

**Uygulama:**
[Exact araç çağrısı veya bash komutu — tam SQL içerik dahil]

**Doğrulama:**
[supabase_query veya supabase_rpc → beklenen sonuç]

**Commit:**
`git add [dosyalar] && git commit -m "[tip]([kapsam]): [açıklama]"`

**Checkpoint:** ← 5+ task'lı planlarda her task sonuna ekle
`memory_add({content: "Task 1 tamamlandı: [özet]", category: "code_change", priority: "low"})`
```

### Paralel Blok (Mesh Pattern)

```markdown
## Task 2 + Task 3 — Paralel Çalıştır

> Bağımsız task'lar. `/skill:delegate` ile paralel aç.
> Dosya sahipliği: Task 2 → `js/ui.js` | Task 3 → `js/api.js` (race condition yok)

**Task 2 — [Başlık]**
[açıklama + acceptance criteria]

**Task 3 — [Başlık]**
[açıklama + acceptance criteria]

Her ikisi bitince değiştirilmiş dosyaları oku, birleştir, commit at.
```

### Byzantine Onay Bloku (Riskli İşlemler)

```markdown
## Task N — [Kritik Değişiklik]

> ⚠️ YÜKSEK RİSK: Geri alınamaz işlem. Reviewer adımı zorunlu.

**Reviewer Adımı:**
1. Aşağıdaki SQL'i göster
2. "Bu işlemi onaylıyor musunuz? (evet/hayır)" sor
3. "evet" gelmeden bir sonraki adıma geçme
4. Ret gelirse alternatif öner, Claude'a danış

**SQL Taslağı:**
```sql
[tam SQL buraya]
```
```

---

## Adım 4 — SONA Memory Hook (Her Plan Sonuna Ekle)

Her planın son task'ı olarak şunu ekle:

```markdown
## Son Task — Pattern Kayıt

Plan tamamlandıktan sonra:
```
memory_add({
  content: "[Plan adı]: [ne yapıldı, hangi pattern işe yaradı, hangi sorun çıktı]",
  category: "code_change",
  priority: "medium",
  tags: "plan,pattern,[konu]"
})
```
Bu adım atlanamaz — gelecek planlar buradan öğrenir.
```

---

## Adım 5 — Komut Yazma Kuralları

- **Tam SQL yaz** — "şunu ekle" değil, migration bloğunun tamamını ver
- **Exact araç** — `supabase_query({table: "gorev_log", filters: "gorev_tipi=eq.BESLEME", limit: 5})`
- **Onay sadece gerçek risk için** — rutin DDL onay gerektirmez
- **Referans:** sadece `ground_truth.sql` + `rpc-reference.md` — `*_revize.sql` yasak
- **Dosya sahipliği** — paralel task'larda hangi agent hangi dosyaya yazıyor netleştir
- **Migration ≠ canlı** — `supabase_migrate({sql: "..."})` ile ayrıca deploy et

---

## Adım 6 — Plan Dosyasını Yaz

Dosya yolu: `docs/superpowers/plans/[YYYY-MM-DD]-[konu].md`

Ton: imperatif, Türkçe, "Claude" referansı yok.

---

## Adım 7 — Kullanıcıya Ver

```
Plan hazır: docs/superpowers/plans/[dosya-adı].md
Topoloji: [seçilen]
Task sayısı: N (M paralel)
Riskli task: [varsa belirt]

DeepSeek'e ilk prompt:
─────────────────────────────────────────────────
/skill:executing-plans

Plan: /root/egesut-erp1/docs/superpowers/plans/[dosya-adı].md

Başlamadan önce plan dosyasını ve ground_truth.sql'i oku.
Her task sonunda checkpoint kaydet.
DB değişikliklerinde onay bekle. Sorum varsa sor.
─────────────────────────────────────────────────
```

---

## Referans: DeepSeek TUI Araç Haritası

### Skills
| Skill | Kullanım |
|-------|---------|
| `/skill:executing-plans` | Plan dosyasını adım adım çalıştırır, batch+checkpoint |
| `/skill:delegate` | Bağımsız subtask'ları paralel dağıtır (Mesh topoloji) |
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
| Değişiklik kontrolü | `gitnexus_detect_changes({scope: "staged"})` |
| Bellek arama | `memory_search({query, category})` |
| Pattern kaydet | `memory_add({content, category: "code_change", priority: "medium"})` |

### Native (bash)
```bash
cat /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql
sed -n '100,200p' /root/egesut-erp1/js/ui.js
node --check /root/egesut-erp1/js/ui.js
git add ... && git commit -m "..." && git push origin main
```

---

*Kaynak araştırma: `.claude/research/2026-05-24-ruflo-agent-framework.md`*
