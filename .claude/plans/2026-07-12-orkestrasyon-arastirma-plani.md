# Orkestrasyon Harness Araştırması — Revize Plan

> **Tarih:** 2026-07-12
> **Amaç:** Piyasadaki 7 orkestrasyon/metaharnes projesini inceleyip mevcut mailbox+broker sistemimize entegre edilebilirliklerini değerlendirmek
> **Kapsam dışı:** OpenAI Symphony (sadece Codex, tek agent)
> **Çıktı:** `research/orkestratör katman/` altında her proje için rapor + puan tablosu
> **tools-bank referans altyapı:**
>   - `tools-bank/docs/plans/2026-07-07-global-agent-control-roadmap.md` — Global Agent Control Roadmap (Phase 1-6)
>   - `tools-bank/docs/plans/2026-07-10-hermes-control-plane-v0.md` — Hermes Control Plane V0
>   - `tools-bank/scripts/mailbox_lib.py` — JSON lease-safe mesajlaşma
>   - `tools-bank/scripts/worker_registry.py` — workers.json + heartbeat
>   - `tools-bank/scripts/spawn_broker.py` — Phase 5 worker lifecycle
>   - `tools-bank/scripts/goose-teammate.py` / `codex-teammate.py` / `omp-teammate.py` / `pi-teammate.py` — teammate bridge'ler

---

## 1. Araştırma Soruları (Her Proje İçin)

Her sub-agent şu 3 soruyu cevaplayacak:

### S1: Hazır Kullanabilir miyiz?
- Mevcut sistemimizle (Python, mailbox JSON, subprocess, Phase 5 Broker) **kod seviyesinde uyumlu mu?**
- Dependency'leri neler? (Node.js, Go, Rust, Python?)
- Kaç satır? Kendi ağırlığını taşıyacak mı, yoksa hafif mi?
- Lisansı nedir? Ticari kullanıma uygun mu?
- **Kullanılabilirlik puanı:** 1-10

### S2: Ne Öğrenebiliriz?
- Hangi pattern'i kullanıyor? (Supervisor, Pipeline, Router, Fan-out?)
- Hata yönetimi nasıl? (Retry, timeout, fallback?)
- Worker lifecycle nasıl? (Spawn, health check, kill, reap?)
- Context yönetimi nasıl? (Agent'lar arası state paylaşımı?)
- **Öğrenme değeri puanı:** 1-10

### S3: Ne Çalabiliriz / İlham Alabiliriz?
- Hangi kod parçası doğrudan alınabilir? (Fonksiyon, sınıf, algoritma?)
- Hangi tasarım kararı bizimkini iyileştirir?
- Hangi özellik bizde eksik?
- **Çalınabilirlik puanı:** 1-10

---

## 2. Sub-Agent Görev Dağılımı

### Agent 1: Omnigent + Gas Town
| Proje | Repo | Dil | Star |
|-------|------|-----|------|
| **Omnigent** (Databricks) | `databricks/omnigent` | Python? | Yeni (13 Haz 2026) |
| **Gas Town** (Steve Yegge) | `gastownhall/gastown` | ? | ? |

**Öncelik:** Omnigent en yakın meta-harness konsepti — nasıl compose ediyor, governance nasıl?

### Agent 2: AgentWrapper + Oh My Claude Code
| Proje | Repo | Dil | Star |
|-------|------|-----|------|
| **AgentWrapper** | `AgentWrapper/agent-orchestrator` | ? | ~8.2k ⭐ |
| **Oh My Claude Code** | `zephyrpersonal/oh-my-claude-code` | ? | ~3.6k ⭐ |

**Öncelik:** AgentWrapper en popüler — paralel agent yönetimi, session isolation nasıl?

### Agent 3: Docker Harnesses + Maestro + Oh My OpenCode
| Proje | Repo | Dil | Star |
|-------|------|-----|------|
| **Docker Agent Harnesses** | `docker/docs` + `docker/agent` | Go/Python | — |
| **Maestro** | `runmaestro.ai` | ? | — |
| **Oh My OpenCode** | `oh-my-opencode/sisyphus` | ? | ? |

**Öncelik:** Docker Harnesses'in `background-agents` konsepti bize en yakın — nasıl implemente etmişler?

---

## 3. Her Sub-Agent'ın Yapacağı İşlem Sırası

```python
# Pseudo-code
1. git clone --depth 1 https://github.com/{org}/{repo} /tmp/orkestrasyon/{repo}/
2. pygount --format=summary --folders-to-skip=".git,node_modules,venv" .
3. README.md oku → projenin ne olduğu, nasıl çalıştığı
4. docs/ varsa oku → mimari, pattern, kurulum
5. examples/ varsa oku → gerçek kullanım
6. Ana kaynak kod dosyalarını oku (en önemli 3-5 dosya)
7. package.json / pyproject.toml / Cargo.toml → dependency analizi
8. LICENSE → lisans kontrolü
9. Raporu yaz: /tmp/orkestrasyon/notlar/{repo}-rapor.md
```

### Rapor Şablonu

```markdown
# {Proje Adı} — İnceleme Raporu

## Künye
- **Repo:** {url}
- **Dil:** {Python/Go/TypeScript/...}
- **Star:** {N}
- **Lisans:** {MIT/Apache2/GPL/...}
- **Son güncelleme:** {tarih}
- **LOC:** {N} (pygount)

## Nasıl Çalışıyor?
{Kısa mimari özet — 3-5 cümle}

## S1: Hazır Kullanabilir miyiz?
- Kod uyumu: {Python/JS/Go? Bizimle aynı stack mi?}
- Dependency: {Ne kadar bağımlılık?}
- Boyut: {Kaç satır? Hafif mi ağır mı?}
- Lisans uyumu: {Evet/Hayır}
- **Puan: X/10**
- **Gerekçe:** {neden}

## S2: Ne Öğrenebiliriz?
- Pattern: {Supervisor/Pipeline/Router/Fan-out}
- Hata yönetimi: {nasıl?}
- Worker lifecycle: {nasıl?}
- Context yönetimi: {nasıl?}
- **Puan: X/10**
- **Gerekçe:** {neden}

## S3: Ne Çalabiliriz / İlham Alabiliriz?
- {Kod parçası / tasarım / fikir} — {neden işe yarar?}
- {Kod parçası / tasarım / fikir} — {neden işe yarar?}
- **Puan: X/10**
- **Gerekçe:** {neden}

## Özet
{Karar: Kullan / Öğren / Çal / Geç}
```

---

## 4. Benim (Orchestrator) Yapacağım

1. **Hazırlık:** `/tmp/orkestrasyon/` dizinini oluştur
2. **Dispatch:** 3 sub-agent'ı paralel başlat (`delegate_task` batch)
3. **Bekle:** Hepsi bitince bildirim gelir
4. **Oku:** Her raporu oku, not al
5. **Puanla:** 10 kriter üzerinden puan tablosu çıkar
6. **Kaydet:** `research/orkestratör katman/` altına yaz
7. **Sun:** Sana özet + öneri sun

---

## 5. Puanlama Tablosu (Final)

| Kriter | Ağırlık | Omnigent | Gas Town | AgentW. | OMC | Docker | Maestro | OMO |
|--------|---------|----------|----------|---------|-----|--------|---------|-----|
| Kod uyumu (Python/JS/Go?) | 20% | | | | | | | |
| Pipeline desteği | 15% | | | | | | | |
| Hafiflik / overhead | 15% | | | | | | | |
| CLI tabanlı | 10% | | | | | | | |
| Açık kaynak / lisans | 10% | | | | | | | |
| Topluluk | 10% | | | | | | | |
| Dökümantasyon | 10% | | | | | | | |
| Mevcut sisteme uyum | 5% | | | | | | | |
| Olgunluk | 3% | | | | | | | |
| Özgün fikirler | 2% | | | | | | | |
| **TOPLAM** | **100%** | | | | | | | |

---

## 6. Zaman Tahmini

| Aşama | Süre |
|-------|------|
| 3 sub-agent paralel clone + analiz | ~2-3 dk |
| Rapor yazma (her biri) | ~1-2 dk |
| Benim okuma + puanlama | ~2 dk |
| **Toplam** | **~5-7 dk** |
