# Research Directory

```
research/orchestrator-skills/
├── 00-ozet.md           # Bu dosya — özet
├── 01-karsilastirma.md  # orchestrator-master vs alisherry/claude-skills karşılaştırması
└── 02-alisherry-review.md  # alisherry skill'inin detaylı review'i
```

## Nasıl çalışıldı

1. **Web search** ile 3 farklı sorguda multi-agent orchestration pattern'leri arandı
2. `fetch_url` ile alisherry/claude-skills'in README ve multi-agent-orchestration SKILL.md'si indirildi
3. AgentPower.io multi-agent pattern rehberi okundu
4. Azure AI Agent Design Patterns referans alındı
5. Feature gap analizi yapıldı ve 3 araştırma belgesi yazıldı

## Sonuç

orchestrator-master skill'imiz mevcut alternatiflerden territory/quota/depth kontrolü ile ayrışıyor.
Eklenebilecekler: Worker mode auto-detection, Simple/Resilient worker ayrımı, Anti-Patterns listesi.
