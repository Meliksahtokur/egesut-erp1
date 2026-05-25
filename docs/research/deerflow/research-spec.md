# DeerFlow Research Spec

## Araştırma Soruları

### 1. MCP Entegrasyonu — Kullanım İncelikleri
- `deerflow_research` vs `deerflow_chat`: hangisi ne zaman?
- Stateful thread yönetimi: thread_id nasıl korunur, ne zaman kaybolur?
- Flash / standard / pro / ultra modlar: araştırma derinliği ve model farkı nedir?
- Response formatı: yapısal mı, serbest metin mi?
- Timeout ve hata davranışı: ne beklemeli?

### 2. Yazma / Kod Üretimi Yapabilir mi?
- DeerFlow doğrudan dosya yazabilir mi? Kod üretebilir mi?
- Tool/function calling entegrasyonu var mı?
- MCP üzerinden harici araçlara (filesystem, shell) erişim mümkün mü?

### 3. Orkestrasyon
- Claude Code + DeerFlow: iş bölümü nasıl olmalı?
- DeerFlow'u orchestrator olarak kullanmak mantıklı mı?
- Paralel araştırma için birden fazla thread açmak güvenli mi?
- DeerFlow memory sistemi ne kadar güvenilir, ne zaman sıfırlanır?

### 4. Limitler
- Context uzunluğu limiti var mı?
- Rate limiting / concurrency kısıtlaması?
- Internet erişimi gerçek mi yoksa simüle mi?

## Beklenen Çıktı
Her soru için: kısa açıklama + pratik kullanım önerisi + varsa tuzak/limit.
Dosyaya yaz: `docs/research/deerflow/findings.md`
