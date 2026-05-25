# alisherry/claude-skills Review

> **Skill:** multi-agent-orchestration  
> **URL:** github.com/alisherry/claude-skills  
> **Boyut:** ~84KB (bizim skill ~13KB)  
> **Dil:** Tamamen İngilizce  

## Genel Değerlendirme

**Güçlü yanları:**
- Kapsamlı worker type sistemi (Simple/Resilient/Sub-Orch)
- Orchestrator/Worker rol ayrımı net (agent kendi rolünü prompt'tan okuyor)
- Failure budget mekanizması var
- Paralel swarm kullanımı iyi

**Zayıf yanları:**
- Aşırı şişkin (84KB) — gereksiz tekrarlar, persona/flavor abartılmış
- Territory/quota/depth kontrolü yok — sub-agent'lar sınırsız spawn olabilir
- Dil desteği yok (hep İngilizce)
- Error handling zayıf (sadece "retry")

## Bizim Skill'imize Eklenebilecekler

### 1. Worker Mode Auto-Detection

alisherry'nin en iyi fikri: agent prompt'ta "You are a WORKER agent" varsa, otomatik olarak sub-agent açmayı reddet. Bizde şu an her agent eşit seviyede.

```yaml
# Prompt template for workers:
"You are a WORKER agent (leaf). 
- Territory: src/auth/
- Do NOT spawn sub-agents
- Complete this specific task, report back"
```

### 2. Simple vs Resilient Worker

**Simple:** Tek deneme, başarısız olursa orchestrator'a hata raporu.
**Resilient:** N deneme (failure budget = 5), her denemede doğrulama (test/lint/type check).

Bizdeki mevcut sub-orch'lar "resilient", leaf'ler "simple" olarak düşünülebilir. Ama açıkça belirtilmemiş.

### 3. Pattern Adherence Workflow

Refactor öncesi 4 adım:
1. **Analyze** — mevcut kodu oku, pattern'leri çıkar
2. **Spec** — değişiklik spec'i yaz
3. **Implement** — uygula
4. **Verify** — test et, lint kontrol et

Bizde S.A.F.E.R. var (Scout→Ask→Fork→Evaluate→Review). Pattern Adherence daha çok "implementasyon öncesi kod analizi" odaklı — S'de (Scout) kısmen var ama resmileştirilmemiş.

### 4. Anti-Patterns Tablosu

```markdown
| ❌ Yapma | ✅ Bunu Yap |
|----------|-------------|
| Kodu kendin değiştir | Sub-agent spawn et |
| "Hemen bakarım" de | Agent aç |
| Tek tek bekle | Paralel batch |
```

### 5. Failure Budget

Her sub-orch'a max hata/deneme sayısı ver:
```yaml
failure_budget: 5  # max başarısız deneme
on_exhausted: report_to_parent  # budget bitince parent'a rapor
```

## Alınmaması Gerekenler

1. **Flamboyant persona** — ASCII art kutular, "Conductor" rolleri, milestone celebrations. Biz sade ve teknik kalmalıyız.
2. **Her şeyi sub-agent'a yaptırma** — alisherry "Forbidden: explore codebase yourself, write code yourself, run bash yourself" diyor. Bizde main orchestrator gerektiğinde direkt implementasyon yapabilir (tightly-coupled HTML+JS gibi). alisherry'nin kuralı çok katı.
3. **84KB gereksiz genişlik** — skill ne kadar kısa o kadar iyi. Biz 13KB'de kalmalıyız.
