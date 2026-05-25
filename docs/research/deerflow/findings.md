# DeerFlow Araştırma Bulguları
> Kaynak: deerflow_research (flash mod) — 2026-05-25

---

## Mimari

DeerFlow 2.0 = LangGraph tabanlı "super agent harness". Claude Code → DeerFlow bağlantısı **native MCP değil** — tools-bank MCP'si HTTP bridge olarak çalışır. Claude Code dışarıdan orkestre eder.

| Layer | Port | Amaç |
|---|---|---|
| Gateway API | 8001 | Modeller, skill'ler, agent'lar, memory, dosya upload, health |
| LangGraph API | 8001 | Thread'ler, streaming run'lar, state yönetimi |

---

## Modlar — Gerçek Fark

| Mod | Düşünür | Planlar | Sub-agent | Kullanım |
|---|---|---|---|---|
| `flash` | ✗ | ✗ | ✗ | Hızlı tek cevap, status check |
| `standard` | ✓ | ✗ | ✗ | Tek kaynaklı orta analiz |
| `pro` | ✓ | ✓ | ✗ | Planlı yapısal araştırma |
| `ultra` | ✓ | ✓ | ✓ | Çok kaynaklı derin rapor |

**Kural:** Araştırma için default `pro`. `flash` sadece tek cevap gereken durumlar. `ultra` gerçekten paralel sub-agent lazımsa.

---

## Güçlü Yönler

- Multi-source web araştırması + yapısal rapor üretimi
- LangGraph `recursion_limit=1000` → uzun reasoning zincirleri
- PDF/PPTX/XLSX/DOCX otomatik Markdown dönüşümü
- Thread persistence — günler sonra devam edilebilir
- Sandboxed kod çalıştırma (Docker)
- Memory API — kişiselleştirme, fact persistence

---

## Limitler ve Tuzaklar

- **Native MCP yok** — Claude Code'dan HTTP bridge üzerinden erişim
- **Infrastructure ağır** — Docker, stack, API key zorunlu
- **Uzun thread'lerde context şişmesi** — farklı konular için yeni thread aç
- **Ultra modda sub-agent opak** — hata ayıklama zor, SSE stream'i parse etmek gerekir
- **Ultra modda latency yüksek** — dakikalar alabilir
- **LLM kalitesine bağımlı** — DeerFlow harness, model değil; hallucination LLM'den gelir
- **Recursion limit** — default 100 (config'den artırılabilir). Çok dallı sorgularda hit edilebilir

---

## Thread Yönetimi

```python
# Yeni thread
deerflow_research(query="...")  # → thread_id döner

# Thread devam
deerflow_chat(message="Devam sorusu", thread_id="thread_abc123")

# Kural: 1 araştırma konusu = 1 thread
# Farklı konu → yeni thread aç
```

---

## Claude Code + DeerFlow İş Bölümü

| DeerFlow'a ver | Claude Code'da tut |
|---|---|
| Multi-source web araştırması | Kod yazma, dosya düzenleme |
| Yapısal rapor üretimi | Basit tek cevap sorular |
| Belge analizi (PDF vb.) | Local git/commit işlemleri |
| Paralel sub-task araştırma | DeerFlow yoksa/setup maliyetliyse |
| Günler süren thread'ler | Anlık tek LLM çağrısı yeterliyse |

---

## Önemli: DeerFlow Dosya Yazabilir mi?

Evet — **kendi sandbox'ında**. Docker içinde `pip install`, script çalıştırma, dosya üretme yapabilir. Ancak bu dosyalar Claude Code'un çalıştığı host sisteme doğrudan yazılmaz. Çıktı text olarak döner, Claude Code o metni alıp dosyaya yazar.

---

## Bilinmesi Gereken Teknik Detaylar

- `recursion_limit` 1000 (config) — çok dallı flash sorgu → 100 limitine çarpabilir (BUG: tools-bank wrapper default 100 kullanıyor olabilir)
- Sub-agent debug için raw SSE stream gerekir
- Memory oturumlar arası kalıcı — `deerflow_memory("status")` ile kontrol et
- Gateway her restart'ta DOWN düşer — oturum başı health check şart

---

## Gateway Başlatma

```bash
cd /root/deer-flow/backend && PYTHONPATH=. nohup uv run uvicorn app.gateway.app:app \
  --host 0.0.0.0 --port 8001 --log-level warning \
  > /root/deer-flow/logs/gateway.log 2>&1 &
```
