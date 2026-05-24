# Orchestrator-Master Geliştirme Stratejisi

**Tarih:** 2026-05-24
**Amaç:** Ruflo projesinden alınacak pattern'lerle skill'imizi geliştirmek, basitliği koruyarak.

---

## Strateji Prensibi

**"Ruflo'nun zenginliğini, bizim basitliğimizle."** Ruflo 20 MiB TypeScript + 54k yıldızlık bir proje. Biz tek bir SKILL.md dosyasıyız. Her şeyi almaya çalışmak hata olur. Seçici ol.

---

## Aşama 1: Hemen Entegre Edilebilecekler (Düşük Çaba, Yüksek Kazanç)

### 1.1 Config-Driven Skill Parametreleri

**Mevcut:** Territory, quota, max_depth prompt içinde elle yazılır.

**Öneri:** Skill'in yanına bir `config.toml` koy:

```toml
# .claude/skills/orchestrator-master/config.toml
[defaults]
max_concurrent_agents = 10
reserve_slots = 2
default_model = "deepseek-v4-flash"
fork_context = true
max_depth = 3

[profiles]
[profiles.fast]
max_depth = 1
max_concurrent_agents = 4

[profiles.deep]
max_depth = 3
max_concurrent_agents = 10
reserve_slots = 2
max_recursion_per_sub_orch = 2
```

**Etki:** Skill kullanımı standardize olur, prompt şişmez. Kullanıcı profil seçebilir.

### 1.2 Post-Task Öğrenme Hooks

**Mevcut:** Task bitince sadece checklist güncellenir.

**Öneri:** 3 hook (opsiyonel, implementasyon prompt'a bırakılır):

```
- pre-dispatch:  Sub-agent açılmadan önce çalışır
- post-task:     Sub-agent tamamlanınca çalışır
- on-failure:    Sub-agent başarısız olunca çalışır
```

**Etki:** Hata durumlarında otomatik toparlama, başarılı task'lardan öğrenme.

### 1.3 Sub-Agent Türleri

**Mevcut:** Bütün sub-agent'lar aynı tipte.

**Öneri:** 4 tür (Ruflo'nun 8'inden sadeleştirilmiş):

| Tür | Rol | Açıklama |
|-----|-----|----------|
| `explorer` | Keşif | Read-only, dosya okuma |
| `implementer` | Uygulama | Kod yazma, test |
| `reviewer` | İnceleme | Kod review, hata bulma |
| `consolidator` | Birleştirme | Çıktıları sentezleme |

**Etki:** Agent seçimi daha net, performans tahmini kolaylaşır.

---

## Aşama 2: Orta Vadeli (Daha Fazla Çaba)

### 2.1 Background Worker Sistemi

**Mevcut:** Her şey ana thread'de.

**Öneri:** Basitleştirilmiş worker sistemi:

- **`worker-audit`**: Her N task'ta bir kod kalitesi kontrolü
- **`worker-cache`**: Bellek temizliği/optimizasyonu
- **`worker-learn`**: Başarılı pattern'leri memory_add ile kaydet

TOML'da tanımlanır, ana orchestrator periyodik spawn eder.

### 2.2 Consensus Mekanizması (Opsiyonel)

**Mevcut:** Sub-agent output'u direkt kabul.

**Öneri:** 3-way review:
- Aynı task için 3 sub-agent spawn et
- Majority voting ile en iyi sonucu seç
- Sadece `mode: "critical"` task'larda aktif

TOML flag: `consensus = "none"` (default) | `"majority"` | `"reviewer"`

### 2.3 Memory + Learning Integration

**Mevcut:** tools-bank memory var ama skill içinde referansı yok.

**Öneri:** Skill'e memory adımları ekle:
- Pre-task: `memory_search` ile geçmiş pattern'leri yükle
- Post-task: `memory_add` ile başarılı pattern'leri kaydet
- `note` ile kritik kararları persist et

---

## Aşama 3: İleri Seviye (Yüksek Çaba)

### 3.1 Multi-Provider Routing

**Öneri:** Basit round-robin + fallback:
1. Default: DeepSeek V4 Flash
2. Fallback: DeepSeek V4 Pro (karmaşık task)
3. Ultimate fallback: User'a bildir

### 3.2 Federation Lite

**Öneri:** İki DeepSeek TUI instance'ı arasında:
- `agent_send` / `agent_receive` (zaten tools-bank'ta var)
- Session ID + task delegation
- Sonuç birleştirme

---

## Uygulama Öncelik Sırası

```
Öncelik  ────────────────────────────────────────────────► Zaman
  Acil        Hızlı kazanç          Orta              İleri
  ┌─────────┐ ┌───────────────┐ ┌────────────┐ ┌──────────────┐
  │ Config  │ │ Post-task     │ │ Background │ │ Multi-       │
  │ TOML    │ │ hooks         │ │ workers    │ │ provider     │
  ├─────────┤ ├───────────────┤ ├────────────┤ ├──────────────┤
  │ Agent   │ │               │ │ Consensus  │ │ Federation   │
  │ tipleri │ │               │ │ (ops.)     │ │ Lite         │
  └─────────┘ └───────────────┘ └────────────┘ └──────────────┘
```

---

## Değişiklik Planı

### SKILL.md Değişiklikleri

| Bölüm | Değişiklik |
|-------|-----------|
| **Workflow** | S.A.F.E.R → S.A.F.E.R. + H (Hook) |
| **Spawn Gate** | Agent tipi seçimi ekle |
| **Fork** | Config TOML referansı ekle |
| **Evaluate** | Post-task hook referansı ekle |
| **Review** | Consensus opsiyonu ekle |
| **Yeni bölüm** | "Configuration" — TOML şeması |
| **Yeni bölüm** | "Agent Types" — 4 tür tanımı |
| **Yeni bölüm** | "Hooks" — 3 hook tanımı |

### Yeni Dosyalar

| Dosya | İçerik |
|-------|--------|
| `.claude/skills/orchestrator-master/config.toml` | Varsayılan yapılandırma |
| `.claude/skills/orchestrator-master/AGENTS.md` | Sub-agent'lar için yönergeler |

### Mevcut Dosyalarda Değişiklik

| Dosya | Değişiklik |
|-------|-----------|
| `WORKER.md` | Agent tipi alanı ekle |
| `SKILL.md` | Yukarıdaki bölümleri güncelle |
