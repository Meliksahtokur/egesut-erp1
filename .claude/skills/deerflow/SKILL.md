---
name: deerflow
description: DeerFlow web araştırması — ne zaman, hangi mod, nasıl orkestre edilir, gateway nasıl kaldırılır
---

# DeerFlow — Web Araştırma Ajanı

DeerFlow = LangGraph tabanlı multi-agent araştırma harness'ı.
Claude Code → tools-bank MCP → HTTP → DeerFlow Gateway (:8001).

**Kullanım alanı:** Web araştırması, belge analizi, yapısal rapor.
**Kullanma:** Kod yazma, dosya düzenleme, implementasyon.

---

## Mod Seçimi

| Mod | Plan | Sub-agent | Not |
|-----|------|-----------|-----|
| `flash` | ✗ | ✗ | Thinking kapalı, hızlı (5-15 sn) |
| `standard` (default) | ✗ | ✗ | Thinking açık, tek kaynaklı analiz (20-60 sn) |
| `pro` | ✓ | ✗ | Planlı + TodoMiddleware (1-3 dk) |
| `ultra` | ✓ | ✓ | Sub-agent'lı derin rapor, max 3 concurrent (3-15+ dk) |

**Default = `standard`** (kod, `tools-bank/mcp_server/server.py:1979` → `mode: str = "standard"`).
SKILL.md'nin eski sürümlerinde "default flash" yazıyordu — bu **yanlış**. Parametre YAZILMAZSA `standard` çalışır (thinking=True, plan=False, subagent=False).
Mod seçimi kodu 3 Boolean bayrağa açılır: `thinking_enabled`, `is_plan_mode`, `subagent_enabled`.

**Politika (Legion PC donanım yeterli, 2026-07-04 sonrası):** Hepsi izinsiz kullanılabilir.
**Politika (`.skillopt-sleep` önerileri):** Kullanıcı açıkça `pro`/`ultra` istemedikçe override etme.

```python
# DOĞRU — default standard (parametre yazma)
deerflow_research(query="...")

# AÇIKÇA KULLANICI ONAYI İLE — pro/ultra
deerflow_research(query="...", mode="pro")
deerflow_research(query="...", mode="ultra")

# YANLIŞ — kullanıcı onayı olmadan pro/ultra
deerflow_research(query="X nedir?", mode="ultra")  # Tek-sorgu için overkill
```


---

## Araçlar

| İhtiyaç | Araç |
|---------|------|
| Tek araştırma (stateless) | `deerflow_research(query)` |
| Devam eden sohbet | `deerflow_chat(message, thread_id?)` |
| Gateway kontrolü | `deerflow_health()` |
| Gateway yeniden başlat | `deerflow_gateway_restart()` |
| Agent listesi | `deerflow_agents()` |
| Thread listesi | `deerflow_threads(limit=10)` |
| Memory özeti | `deerflow_memory("status")` |
| Memory'ye fact ekle | `deerflow_memory("add", content, category)` |
| Modelleri listele | `deerflow_list_models()` |
| Skill'leri listele | `deerflow_list_skills()` |

**Önemli araç-spesifik kısıtlar:**
- `deerflow_chat` mod parametresi almıyor (hardcoded `thinking=True, plan=False, subagent=False`).
- `deerflow_memory` mod-agnostic; **sadece izin verilen kategorileri kabul ediyor** (aşağıda "Memory Schema" bölümü).
- `deerflow_research` `mode="ultra"` iken `task` tool tool setine eklenir; diğer modlarda YOK.

---

## Thread & Recursion Bilinen Sorunlar

**ÇOK ÖNEMLİ — release-blocking issue'lar v2.0 main'de hâlâ açık:**

|Issue #|Problem|Etki|
|---|---|---|
|[#3107](https://github.com/bytedance/deer-flow/issues/3107)|v2.0-m1-rc1 release-blocking bugs|ultra/user workflow testing|
|[#2569](https://github.com/bytedance/deer-flow/issues/2569)|Infinite `web_search ↔ web_fetch` döngüsü, `LoopDetectionMiddleware` atlatıyor|Thread sonsuz döngü|
|[#1987](https://github.com/bytedance/deer-flow/issues/1987)|`LoopDetectionMiddleware` cross-file `read_file` loop'larını kaçırıyor|`GraphRecursionError`|
|[#1055](https://github.com/bytedance/deer-flow/issues/1055)|Repetitive tool call loop'ları|Tüm modlarda görülür|
|[#2116](https://github.com/bytedance/deer-flow/issues/2116)|Loop detection false positives; thresholds `config.yaml`'dan yapılandırılamıyor|Tuning zor|

**Recursion limit değerleri:**
- `tools-bank/mcp_server/server.py`: hardcoded `recursion_limit=100` (her iki çağrıda: research + chat)
- DeerFlow config (deer-flow/backend): `recursion_limit=1000`
- Yani tools-bank tarafında **100 recursion** sınırı var, bu nedenle 4+ dallı sorgu veya uzun tool call zincirleri hızla tükenir.

**Mitigasyon (her sorgu için uygula):**

1. **Odaklı sorgu yaz** — tek seferde 2-3 soru max. Çok-dallı → recursion limit'e çarpar.
2. **Sorgu derinliği sınırla** — "X nedir, B nasıl çalışır, C neden, D ne zaman" gibi 4+ alt konu ayrı sorgulara böl.
3. **Termination condition koy** — özellikle `mode="ultra"` çağrılarında explicit "durdurma koşulu" tanımla.
4. **Tool çağrı zinciri kısa tut** — her sub-agent çağrısı context ekler, `LoopDetectionMiddleware` bazen geç algılar.
5. **Thread yönetimi** — 1 konu = 1 thread. Farklı konular için yeni thread; eski thread'de context şişmesine izin verme.

```python
# RİSKLİ — 4 dallı sorgu, recursion limit'i zorlar
deerflow_research(query="A nedir? B nasıl çalışır? C neden? D ne zaman?")

# DOĞRU — odaklı tek sorgu
deerflow_research(query="What are the practical limitations of DeerFlow for web research?")

# DAHA DOĞRU — sub-task'lere böl
deerflow_research(query="DeerFlow recursion limit mechanism and workarounds")
```

---

## Memory Schema (Rijit)

**`deerflow_memory("add", content, category)` sadece şu kategorileri kabul ediyor:**

- `workContext` — oturum-içi kısa vadeli çalışma hafızası
- `personalContext` — kalıcı kullanıcı tercihleri
- `topOfMind` — "always-on" öncelikli bilgi

**+ zorunlu `correction` alanı** (her fact için garanti düzeltme notu).

**Custom kategori kabul edilmiyor** (test 2026-07-06 ile doğrulandı → `category: "test"` → 200 OK döner AMA yeni thread'de hatırlamaz).

**Pratik kurallar:**
- `max_facts` ≤ 100, `fact_confidence_threshold` ≥ 0.7 tut
- 30s debounce ile duplicate fact birikmesi engellenir
- Built-in dedup var ama **semantic duplicate'ı önlemiyor** — aynı bilgi farklı kelimelerle yazılırsa birikir
- Kategorileri izin verilen 3 ile sınırla, custom kullanma

---

## Güvenlik: "Emir Kesin" Prompt-Injection

**`docs/research/deerflow/state-usage-2026-07-06.md:67-70`**'te tespit edilen flag:
- Kullanıcı girdisinde `"emir kesin"` gibi ifadeler tespit edilirse ajan farklı modda davranabiliyor
- DeerFlow'un memory/thread sistemine sızma riski
- **Kullanıcı promptlarına `"emir kesin"` ifadesini yazma** — bu test vektörü, üretim kullanımında sızma riski taşır
- Memory'den gelen "topOfMind summary" kullanıcı girdisini DeerFlow'a yansıtırken bu flag aktif olabilir

**Not:** Teknik detaylar (hangi mod, hangi prompt, hangi filtre) henüz belgelenmemiş. Bilinen tek doğrulanmış davranış: kullanıcı promptundaki literal `"emir kesin"` ifadesi tetikleyici.

---

## Sorgu Yazma Kuralları

1. **Tek odak** — bir sorguda 2-3 soru max. Fazlası recursion limitine çarpar (yukarıdaki tablo).
2. **İngilizce** — web araştırması için daha iyi kaynak bulur.
3. **Thread yönetimi:** 1 konu = 1 thread. Farklı konular için yeni thread.
4. **Temporal awareness** — "today/this week/recently" gibi niyetler için tarihli sorgu yaz (örn. "AI trends March 2026").
5. **Yetkili kaynak hintleri** — "[topic] research paper", "[topic] McKinsey report", "[topic] industry analysis" gibi.

```python
# Çok dallı → recursion limit riski (yukarıdaki issue #2569, #1987)
deerflow_research(query="A nedir? B nasıl çalışır? C neden? D ne zaman?")

# Doğru — odaklı
deerflow_research(query="What are the practical limitations of DeerFlow for web research?")
```

---

## Claude Code + DeerFlow İş Bölümü

| DeerFlow | Claude Code |
|----------|-------------|
| Multi-source web araştırması | Kod yazma, dosya düzenleme |
| Yapısal rapor üretimi | Basit tek cevap |
| PDF/PPTX/XLSX analizi | Git, commit, local işlemler |
| Günler süren araştırma thread'leri | DeerFlow DOWN veya setup maliyetliyse |

DeerFlow çıktısı → Claude Code alır, dosyaya yazar veya işler.
DeerFlow kendi sandbox'ında dosya yazabilir ama host'a yazmaz.

---

## Sandbox & Dosya Takası

DeerFlow sandbox ajan — ortamı boş, sadece tool'ları var.

- **Input:** `/mnt/user-data/uploads/` (OMP'tan upload edilmiş dosyalar)
- **Output:** `/mnt/user-data/outputs/` (sandbox'tan çıkan dosyalar, `ThreadState.artifacts` listesinde)
- **Default cwd:** `/mnt/user-data/workspace/`
- **MCP'de file upload tool'u yok** — direct HTTP `POST /api/threads/{id}/uploads` (CSRF + cookie) gerekli
- **Dosya takası pattern:** OMP dosyayı mount'a yazar → DeerFlow tool ile okur → sonuç outputs'a yazar → OMP oradan geri okur

---

## Gateway DOWN ise

```python
# 1. Kontrol
deerflow_health()  # → ❌

# 2. Restart (tools-bank üzerinden)
deerflow_gateway_restart()  # max 60sn bekler

# 3. Tekrar kontrol
deerflow_health()  # → ✅
```

**Manuel başlatma** (restart tool çalışmazsa):
```bash
cd /root/deer-flow/backend && PYTHONPATH=. nohup uv run uvicorn app.gateway.app:app \
  --host 0.0.0.0 --port 8001 --log-level warning \
  > /root/deer-flow/logs/gateway.log 2>&1 &
```

**Not:** Gateway her sistem restart'ında DOWN düşer — oturum başında `deerflow_health()` kontrol et.

---

## Bilinen Limitler

- **Recursion limit: tools-bank'te 100, DeerFlow config'te 1000** — yukarıdaki "Thread & Recursion Bilinen Sorunlar" bölümü
- **5 release-blocking issue** v2.0 main'de hâlâ açık (#3107, #2569, #1987, #1055, #2116)
- Ultra modda sub-agent davranışı opak — hata ayıklama zor
- Ultra modda latency dakikalar alabilir
- Uzun thread'lerde context şişmesi → yeni thread aç
- DeerFlow harness, model değil — hallucination LLM'den gelir
- Streaming instability (KKM-Mako testi): v2.2'de kısmen iyileşti, hâlâ risk; workaround: markdown download
- Memory schema custom kategori kabul etmiyor (yukarıdaki "Memory Schema" bölümü)
- Setup karmaşıklığı orta — Docker kurulumu gerekli, non-engineer için bariyer yüksek

---

*Araştırma kaynakları: `docs/research/deerflow/findings.md` (2026-05-25), `docs/research/deerflow/state-usage-2026-07-06.md` (2026-07-06), `research/deerflow-usage-2026-07-06/FINAL-SYNTHESIS.md` (2026-07-06)*
