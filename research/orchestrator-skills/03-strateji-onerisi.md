# Orchestrator-Master v2 — DeepSeek TUI Odaklı Strateji Önerisi

**Tarih:** 2026-05-23  
**Bağlam:** Mevcut skill'in gerçek API'ye eşlenmesi + araştırma bulgularının sentezi

---

## Mevcut Durum

### Elimizdekiler (Gerçek API)
- `agent_open(prompt, agent_type, fork_context, max_depth, model)` — sub-agent aç
- `agent_eval(agent_id, message, block)` — sonuç al / follow-up gönder
- `agent_close(agent_id)` — iptal
- `handle_read(var_handle)` — büyük çıktıları parçalı oku
- `fork_context: true` — prefix cache paylaşımı (DeepSeek'in güçlü silahı)
- Agent tipleri: `general`, `explore`, `plan`, `review`, `implementer`, `verifier`, `custom`
- Modeller: `deepseek-v4-flash` (hızlı), `deepseek-v4-pro` (güçlü)
- `DEEPSEEK_MAX_SUBAGENTS` env var ile global limit

### Sorunlar
1. **Skill, API ile eşleşmiyor** — `checklist_write`, `note`, `request_user_input` gibi hayalet fonksiyonlar var
2. **MCP tool isimleri yanlış** — `grep_files` yerine gerçek MCP tool adları kullanılmalı
3. **Hardcoded Turkish** — `(Turkish in this session)` skill'e gömülü
4. **Gereksiz agent spawn riski** — "Do NOT implement everything myself" kuralı bazen tek dosyalık işlerde bile sub-agent açtırıyor
5. **Evaluate fazında fallback zinciri** — doğru yönde ama `<deepseek:subagent.done>` event formatı doğrulanmalı

---

## Strateji: Ne Yapmalıyız?

### Yaklaşım: "İki Katmanlı Skill"

Skill'i tek dosyada tutmak yerine **iki ayrı dosyaya** bölelim:

```
.claude/skills/orchestrator-master/
├── SKILL.md          # Ana orkestratör — karar verici, workflow
└── WORKER.md         # Worker template — sub-agent'lara prompt olarak geçilir
```

**Neden?** Kullanıcının gözlemi doğru: "agentler dosyaya yazınca daha sağlam çıktı veriyorlar." Sub-agent'lara net bir rol şablonu vermek çıktı kalitesini artırır.

---

### 1. SKILL.md (Ana Orkestratör) — Değişiklikler

#### A. API Eşlemesi — Hayalet Fonksiyonları Kaldır

| Hayalet | Gerçek Karşılık |
|---------|----------------|
| `checklist_write` | Dosyaya yaz: `write_file(".deepseek/state/checklist.md", ...)` |
| `note` | `memory_add(content, category="code_change")` |
| `request_user_input` | `[KULLANICIYA SOR]` bloğu — DeepSeek TUI zaten duraksar |
| `grep_files(pattern)` | MCP: `semantic_search({query})` veya bash: `grep -rn` |
| `file_search(name)` | bash: `find . -name "..."` veya `ls` |
| `list_dir` | bash: `ls -la` |

#### B. Spawn Kararı — "Gerçekten Lazım mı?" Gate

Mevcut skill "hierarchical mode'da her zaman sub-agent aç" diyor. Yeni kural:

```yaml
SPAWN GEREKLİ Mİ?
├── Tek dosya değişikliği? → HAYIR, direkt yap
├── 2-3 bağımlı dosya? → HAYIR, sırayla direkt yap  
├── 3+ bağımsız dosya/modül? → EVET, territory ver, spawn et
├── Salt okuma araştırma? → EVET, explore tipinde paralel aç
└── Uzun sürecek iş (>50 adım)? → EVET, sub-orch aç
```

**Kural:** Spawn'ın overhead'i > işin kendisi ise spawn etme.

#### C. Quota — Gerçekçi Limitler

```yaml
max_concurrent_agents: 8    # Gerçekçi üst sınır (Rust hızlı ama context yine de sınırlı)
reserve: 2                  # Her zaman 2 slot boş tut (acil review/fix için)
active_quota: 6             # Aynı anda çalışan max
model_default: deepseek-v4-flash  # Hız öncelikli
model_heavy: deepseek-v4-pro      # Karmaşık reasoning gerektiren görevler
```

#### D. Worker Tipleri — alisherry'den Alınacaklar

| Tip | Özellik | Kullanım |
|-----|---------|----------|
| **Leaf** (Simple) | Tek deneme, başarısız → parent'a rapor | Küçük, izole görevler |
| **Resilient** | failure_budget: 3, her denemede doğrulama | DB migration, kritik JS değişiklikleri |
| **Sub-Orch** | Kendi sub-agent açabilir, quota devralır | Büyük modül refactor'ları |

#### E. Anti-Patterns — Skill'e Gömülecek

```
❌ YAPMA                                    ✅ BUN YAP
────────────────────────────────────────────────────────
Tek dosya için agent aç                     Direkt yap
"Hemen kontrol ederim" de                   agent_open(type="explore")
Sub-agent'lara aynı dosyayı yazdır          Territory enforce et
20 agent aç, 18'ini bekle                   Max 6 aktif, 2 reserve
Sub-agent çıktısını context'e kopyala       handle_read() kullan
"retry" de, nedenini araştırma              Hata analizi → düzeltilmiş prompt
Onay almadan DB'ye yaz                      ONAY GEREKLİ bloğu ekle
ground_truth dışı migration referans al     SADECE ground_truth.sql
```

---

### 2. WORKER.md (Sub-Agent Template)

Sub-agent spawn edilirken prompt'un başına eklenen şablon:

```markdown
# Rol: {{worker_type}} Worker

Sen bir {{worker_type}} worker'sın.

## Kurallar
- Territory: {{territory}} — SADECE bu dosyalara yaz
- Okuma: Herhangi dosyayı okuyabilirsin
- Sub-agent: {{can_spawn ? "Kotanı aşma: " + quota : "Sub-agent AÇMA"}}
- Failure budget: {{failure_budget}}
- Bitince: Sonucu {{output_file}} dosyasına yaz

## Çıktı Formatı
İşin bitince {{output_file}} dosyasına yaz:
- Değiştirilen dosyalar listesi
- Her dosya için yapılan değişikliğin tek satırlık özeti
- Doğrulama sonucu (test/lint/syntax check)
- Sorun varsa: ne, nerede, neden

## MCP Araçları
{{mcp_tools_table}}
```

**Neden dosyaya yazsınlar?**
- `agent_eval` bazen çıktıyı kaybediyor (mevcut fallback zinciri bunun kanıtı)
- Dosyaya yazılan sonuç kalıcı, doğrulanabilir, başka agent okuyabilir
- "Agentler dosyaya yazınca daha sağlam" — kullanıcı gözlemi doğru

---

### 3. Pattern Adherence (Yeni Faz: S.A.F.E.R. → S.P.A.F.E.R.)

Scout → **Pattern** → Ask → Fork → Evaluate → Review

**Pattern fazı:** Implementasyondan önce mevcut kod yapısını analiz et.

```
Pattern fazı (sadece hierarchical mode):
1. Değişecek dosyaları oku
2. Mevcut pattern'leri çıkar (naming, error handling, DOM structure)
3. Pattern spec'i yaz → sub-agent'lara geç (WORKER.md'ye ekle)
4. Sub-agent'lar bu spec'e uygun yazar
```

Bu, alisherry'nin en iyi fikri. Büyük refactor'larda tutarlılığı garanti eder.

---

### 4. Dosyaya Dayalı İletişim (File-Based Handoff)

Agent'lar arası iletişim dosya üzerinden:

```
.deepseek/state/
├── subagents.v1.json          # DeepSeek TUI native
├── checklist.md               # Orkestratörün progress tracker'ı
├── workers/
│   ├── worker-001-result.md   # Her worker'ın çıktı dosyası
│   ├── worker-002-result.md
│   └── interfaces.md          # Paylaşılan interface tanımları (ID'ler, function signatures)
```

**interfaces.md** — tightly-coupled dosyalarda (HTML+JS) paylaşılan identifier'lar:

```markdown
# Paylaşılan Interface'ler

## DOM ID'leri (HTML ↔ JS)
- `td-asi-form` — aşı formu container
- `td-rapel-info` — rapel bilgi paneli

## Fonksiyon İmzaları (forms.js ↔ ui.js)
- `onVaccineSelect(vaxId, taskRow)` — forms.js:420
- `renderTaskDetail(task)` — ui.js:1100
```

Main orkestratör bunu yazar, worker'lar okur. Territory collision'ı önler.

---

## Uygulama Planı

### Faz 1: Mevcut Skill'i Temizle (bugün)
- [ ] Hayalet fonksiyonları gerçek API'ye eşle
- [ ] Hardcoded Turkish kaldır
- [ ] Anti-patterns tablosu ekle
- [ ] Spawn gate ekle ("Gerçekten lazım mı?")

### Faz 2: Worker Template + File Handoff (yarın)
- [ ] WORKER.md oluştur
- [ ] `.deepseek/state/workers/` dizin yapısı
- [ ] interfaces.md mekanizması

### Faz 3: Pattern Adherence + Worker Tipleri (sonra)
- [ ] S.P.A.F.E.R. workflow
- [ ] Simple/Resilient/Sub-Orch ayrımı
- [ ] Failure budget mekanizması

---

## Açık Sorular

1. **`DEEPSEEK_MAX_SUBAGENTS` mevcut değeri ne?** — Varsayılan limiti bilmiyoruz
2. **`<deepseek:subagent.done>` event formatı** — Skill'de referans var ama doğrulanmamış
3. **`fork_context` gerçek cache hit oranı** — Prefix cache ne kadar etkili?
4. **Model seçimi kuralı** — Ne zaman flash, ne zaman pro?
