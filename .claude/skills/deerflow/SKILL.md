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

## Mod Seçimi (ZORUNLU KURAL)

| Mod | Model | Plan | Sub-agent | İzin |
|-----|-------|------|-----------|------|
| `flash` | v4-flash | ✗ | ✗ | ✅ Default — izinsiz |
| `standard` | v4-flash | ✗ | ✗ | ✅ Kullanıcı onayı ile |
| `pro` | v4-pro | ✓ | ✗ | ❌ İzinsiz yasak |
| `ultra` | v4-pro | ✓ | ✓ | ❌ İzinsiz yasak |

```python
# DOĞRU — default flash
deerflow_research(query="...")

# YANLIŞ — izinsiz pro/ultra
deerflow_research(query="...", mode="pro")
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

---

## Sorgu Yazma Kuralları

1. **Tek odak** — bir sorguda 2-3 soru max. Fazlası recursion limitine çarpar.
2. **İngilizce** — web araştırması için daha iyi kaynak bulur.
3. **Thread yönetimi:** 1 konu = 1 thread. Farklı konular için yeni thread.

```python
# Çok dallı → recursion limit riski
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

- Recursion limit: config'de 1000, ama çok dallı sorgularda erken tükenebilir
- Ultra modda sub-agent davranışı opak — hata ayıklama zor
- Ultra modda latency dakikalar alabilir
- Uzun thread'lerde context şişmesi → yeni thread aç
- DeerFlow harness, model değil — hallucination LLM'den gelir

---

*Araştırma kaynağı: `docs/research/deerflow/findings.md` — 2026-05-25*
