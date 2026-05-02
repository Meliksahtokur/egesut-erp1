# Operator Mimarisi Tasarımı

**Task:** task-arge-011
**Tarih:** 2026-04-02
**Tip:** Araştırma + Tasarım (kod yok)

---

## 1. Qwen Code Agent Spawning — Nasıl Çalışıyor

### Mevcut Yetenekler

**Agent Tool:**
Qwen Code'un `agent` tool'u ile subagent spawn edilebilir. Mevcut agent tipleri:

| Agent Tipi | Açıklama | Ne Zaman Kullanılır |
|------------|----------|---------------------|
| `gwen-architect` | Gwen CLI uzmanı | MCP/Agent/Skill geliştirme |
| `gwen-reviewer` | Push öncesi review | Diff analizi + security check |
| `gwen` | Fullstack developer | ERP geliştirme (tohumlama, doğum) |
| `general-purpose` | Genel amaçlı | Karmaşık araştırma görevleri |
| `Explore` | Codebase keşfi | Dosya/pattern arama |

### Spawn Mekanizması

```
┌─────────────────────────────────────────────────────────┐
│  Claude (Ana Orkestratör)                               │
│    ↓ agent tool ile Qwen spawn eder                     │
│    ↓                                                    │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Qwen (Sub-Orchestrator)                        │   │
│  │    ↓ agent tool ile subagent spawn edebilir     │   │
│  │    ↓                                            │   │
│  │  ┌──────────────────────────────────────────┐  │   │
│  │  │  Subagent (Runner)                       │  │   │
│  │  │  - Aynı ekranda çalışır                  │  │   │
│  │  │  - Ayrı context penceresi değil          │  │   │
│  │  │  - Tek görev yapar, sonuç döner          │  │   │
│  │  └──────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### Kısıtlar

**Sub-Orchestrator Kuralı:**
- ✅ Claude → Qwen spawn edebilir
- ✅ Qwen → subagent spawn edebilir (gwen-architect, gwen, general-purpose, Explore)
- ❌ Subagent → başka subagent spawn edemez (runner olarak çalışır)

**Runner Subagent Kuralı:**
- Runner subagent = aynı ekranda çalışır, ayrı ekran değil
- Paralel okuma/yazma için kullanılır
- **Aynı dosyaya paralel yazma YASAK** — çakışma önlenir

### Parallel Spawn

**Mümkün mü?** → EVET

Qwen aynı anda birden fazla subagent spawn edebilir:

```javascript
// Örnek: Paralel okuma
agent(gwen-architect): ".qwen/QWEN.md oku"
agent(gwen): ".qwen/AGENT_HIERARCHY.md oku"

// Sonuç: 2 agent paralel çalışır, sonuçlar ayrı ayrı döner
```

**Max Kaç Agent?**
- Resmi limit: Qwen Code tarafından belirlenir (muhtemelen 5-10)
- Pratik limit: Context window ve koordinasyon overhead'i
- Önerilen: 3-5 paralel agent (coordination manageable)

### İletişim Pattern'leri

**1. Return Value:**
```
Subagent → Result object döner → Operator işler
```

**2. Shared State (Blackboard):**
```
Operator: BLACKBOARD.md'ye task yaz
Subagent: BLACKBOARD.md'yi oku → task yap → BLACKBOARD.md güncelle
```

**3. Tool Calls (Dolaylı):**
```
Subagent: Dosya oluştur/güncelle
Operator: Dosyayı oku → sonuç çıkar
```

---

## 2. Mevcut gwen.md Analizi

### Mevcut Workflow

```
┌─────────────────────────────────────────────────────────┐
│  gwen.md (Tek Başına Worker)                            │
├─────────────────────────────────────────────────────────┤
│  1. TASK AL                                             │
│     - BLACKBOARD.md oku                                 │
│     - Boş task seç                                      │
│                                                         │
│  2. CONTEXT YÜKLE                                       │
│     - domain-rules.md                                   │
│     - rpc-reference.md                                  │
│     - ui-map.md                                         │
│                                                         │
│  3. KEŞİF YAP                                           │
│     - İlgili dosyaları oku (ui.js, forms.js, api.js)   │
│     - Mevcut implementasyonu anla                       │
│                                                         │
│  4. KOD YAZ                                             │
│     - Domain kurallarına uy                             │
│     - RPC contract'larına uy                            │
│     - Türkçe toast/error mesajları                      │
│                                                         │
│  5. TEST ET                                             │
│     - node --check [dosya].js                           │
│     - Duplikat fonksiyon kontrolü (grep)               │
│     - Syntax doğrulama                                  │
│                                                         │
│  6. COMMIT                                              │
│     - git add                                           │
│     - git commit -m "DONE: [dev/arge] — [özet]"        │
│                                                         │
│  7. REVIEW (OTONOM)                                     │
│     - /review → gwen-reviewer çalışır                   │
│     - Raporu bekle                                      │
│                                                         │
│  8. KARAR                                               │
│     - ✅ PUSH ONAYLI → Adım 9                           │
│     - ❌ PUSH BLOKE → Adım 8-FIX                        │
│                                                         │
│  8-FIX. OTONOM FIX LOOP                                 │
│     - Hataları düzelt                                   │
│     - Tekrar review                                     │
│     - Max 3 deneme                                      │
│                                                         │
│  9. PUSH                                                │
│     - git push origin gwen/dev (veya gwen/arge)        │
│                                                         │
│  10. BLACKBOARD.md GÜNCELLE                             │
│      - Task'ı "tamamlandı" yap                          │
│                                                         │
│  11. SONRAKİ TASK'A GEÇ                                 │
│      - Bekleyen task'ları tara                          │
│      - Loop → Adım 1                                    │
└─────────────────────────────────────────────────────────┘
```

### Sınırlar / Bottleneck'ler

**1. Context Switching Overhead'i:**
```
gwen.md aynı anda:
- Domain expert (tohumlama kuralları)
- Frontend developer (UI render)
- Backend developer (RPC calls)
- Test engineer (node --check)
- Git operator (commit/push)

→ Her task'ta 5 farklı rol arasında context switch
→ Bilişsel yük yüksek, hata riski artar
```

**2. Sıralı İşlemler (Paralelize Edilebilir):**

| Adım | Şu Anki | Potansiyel |
|------|---------|------------|
| Context yükle | Sıralı (3 dosya) | Paralel (3 agent) |
| Keşif | Sıralı (ui.js → forms.js → api.js) | Paralel (3 agent) |
| Kod yaz | Tek dosya | Paralel (frontend + backend) |
| Test | Sıralı (syntax → duplikat → DB) | Paralel (2 agent) |

**3. Tek Nokta Arızası:**
```
gwen.md yorulursa / hata yaparsa → tüm task durur
```

**4. Uzmanlaşma Eksikliği:**
```
- RPC contract validation → genel kural, uzman değil
- Security check → gwen-reviewer'a devredilmiş
- Performance optimization → kimse yapmıyor
- Telemetry validation → manuel, otomatik değil
```

### Hangi Task'larda Tek Agent Yeterli?

**✅ Yeterli (Basit Task'lar):**
- UI bug fix (tek dosya, tek form)
- RPC çağrısı ekleme (tek fonksiyon)
- Toast mesajı düzeltme
- Basit validasyon ekleme

**❌ Yetersiz (Kompleks Task'lar):**
- Multi-file refactor (5+ dosya)
- Yeni feature (UI + RPC + DB trigger)
- Performance optimization (bundle + query + caching)
- Telemetry validation (browser + DB sync)

---

## 3. Önerilen Operator Mimarisi

### Tasarım Hedefi

```
┌─────────────────────────────────────────────────────────┐
│  gwen.md → OPERATOR (Takım Lideri)                      │
├─────────────────────────────────────────────────────────┤
│  - Task'ı alır, planlar                                 │
│  - Ekibi kurar (subagent spawn)                         │
│  - İşi dağıtır (parallel execution)                     │
│  - Sonuçları derler                                     │
│  - Kalite kontrolü yapar                                │
│  - Commit + Push                                        │
└─────────────────────────────────────────────────────────┘
```

### Operator Workflow

```
┌──────────────────────────────────────────────────────────┐
│  OPERATOR (gwen.md)                                      │
│  1. Task Al: BLACKBOARD.md → task-XXX.md                │
│  2. Plan Hazırla: 3-5 adım                               │
│  3. Ekibi Kur:                                           │
│     ┌────────────────────────────────────────────────┐  │
│     │  Researcher  → Context yükle (paralel 3 dosya) │  │
│     │  Analyst     → Mevcut kodu analiz et           │  │
│     │  Coder       → Kod yaz (frontend + backend)    │  │
│     │  Tester      → Test et (syntax + security)     │  │
│     └────────────────────────────────────────────────┘  │
│  4. Sonuçları Derle: Tüm agent sonuçlarını birleştir    │
│  5. Kalite Kontrol: /review → gwen-reviewer             │
│  6. Commit + Push: git add + commit + push              │
│  7. Rapor: done.md + BLACKBOARD.md güncelle             │
└──────────────────────────────────────────────────────────┘
```

### ASCII Workflow Diyagramı

```
                    ┌─────────────────┐
                    │   TASK ALINIR   │
                    │  (BLACKBOARD)   │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  PLAN HAZıRLA   │
                    │  (3-5 adım)     │
                    └────────┬────────┘
                             │
              ┌──────────────┴──────────────┐
              │   EKİP KUR (PARALEL)        │
              │                             │
    ┌─────────▼─────────┐       ┌──────────▼─────────┐
    │  RESEARCHER       │       │  ANALYST           │
    │  - domain-rules   │       │  - ui.js oku       │
    │  - rpc-reference  │       │  - forms.js oku    │
    │  - ui-map         │       │  - api.js oku      │
    └─────────┬─────────┘       └──────────┬─────────┘
              │                            │
              └──────────────┬─────────────┘
                             │
                    ┌────────▼────────┐
                    │  CODER          │
                    │  - Kod yaz      │
                    │  - RPC kullan   │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  TESTER         │
                    │  - node --check │
                    │  - grep duplikat│
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  REVIEW         │
                    │  /review        │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  COMMIT + PUSH  │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  RAPOR          │
                    │  done.md        │
                    └─────────────────┘
```

---

## 4. Subagent Rolleri

### Rol 1: RESEARCHER (Araştırmacı)

**Sorumluluk:** Context yükleme, dokümantasyon okuma

**Giriş:**
- Task tipi (tohumlama, doğum, hayvan, RPC)

**Çıkış:**
- domain-rules.md ilgili bölüm
- rpc-reference.md ilgili RPC'ler
- ui-map.md ilgili UI bileşeni

**Workflow:**
```
1. Task tipini belirle
2. 3 dosyayı paralel oku:
   - domain-rules.md → bölüm X
   - rpc-reference.md → RPC Y
   - ui-map.md → component Z
3. Özet çıkar: "Tohumlama için: yaş ≥ 12 ay, RPC: tohumlama_kaydet(p_hayvan_id, p_tarih)"
```

**Örnek Prompt:**
```markdown
Sen RESEARCHER'sın. EgeSüt ERP domain uzmanısın.

Task: [task tipi]

Şu dosyaları oku ve özet çıkar:
1. domain-rules.md → ilgili bölüm
2. rpc-reference.md → ilgili RPC'ler
3. ui-map.md → ilgili UI

Çıktı: 3-5 satır özet + kritik kurallar
```

---

### Rol 2: ANALYST (Kod Analisti)

**Sorumluluk:** Mevcut kodu anlama, pattern tespiti

**Giriş:**
- İlgili dosyalar (ui.js, forms.js, api.js)
- RESEARCHER'dan gelen özet

**Çıkış:**
- Mevcut implementasyon analizi
- Değişiklik gerektiren satırlar
- Pattern önerisi

**Workflow:**
```
1. İlgili dosyaları oku
2. Mevcut kodu analiz et
3. Değişiklik noktalarını belirle
4. Pattern öner: "Şu fonksiyonu kullan, şu satıra ekle"
```

**Örnek Prompt:**
```markdown
Sen ANALYST'sın. EgeSüt ERP kod analistisin.

Task: [task özeti]
Domain: [RESEARCHER özeti]

Şu dosyaları oku ve analiz et:
- js/ui.js → ilgili fonksiyon
- js/forms.js → submit handler
- js/api.js → RPC wrapper

Çıktı:
1. Mevcut kod analizi
2. Değişiklik gerektiren satırlar (lin no)
3. Pattern önerisi
```

---

### Rol 3: CODER (Kodlayıcı)

**Sorumluluk:** Kod yazma, RPC çağrıları

**Giriş:**
- ANALYST'tan pattern önerisi
- RESEARCHER'dan domain kuralları

**Çıkış:**
- Yazılmış kod
- node --check geçti

**Workflow:**
```
1. Pattern önerisini al
2. Domain kurallarına uyarak kod yaz
3. RPC çağrılarını ekle
4. Türkçe toast mesajları ekle
5. node --check çalıştır
```

**Örnek Prompt:**
```markdown
Sen CODER'sın. EgeSüt ERP fullstack developer'sın.

Task: [task özeti]
Domain: [RESEARCHER özeti]
Pattern: [ANALYST önerisi]

Kod yaz:
1. Domain kurallarına uy
2. RPC kullan (direkt REST yasak)
3. Türkçe toast/error mesajları
4. node --check çalıştır

Çıktı:
- Değiştirilen dosya + satırlar
- node --check sonucu
```

---

### Rol 4: TESTER (Test Mühendisi)

**Sorumluluk:** Syntax, security, duplikat kontrolü

**Giriş:**
- CODER'dan yazılmış kod

**Çıkış:**
- Test raporu (PASS/FAIL)
- Hatalar + öneriler

**Workflow:**
```
1. node --check [dosya].js
2. grep duplikat kontrolü
3. Security scan (API key, SQL injection)
4. RPC bypass kontrolü
5. Rapor: PASS/FAIL + hatalar
```

**Örnek Prompt:**
```markdown
Sen TESTER'sın. EgeSüt ERP test mühendisisin.

Kod: [CODER yazdı]

Test et:
1. node --check [dosya].js
2. Duplikat fonksiyon kontrolü (grep)
3. Security scan (API key, SQL injection, RPC bypass)
4. Türkçe mesaj kontrolü

Çıktı:
- ✅ PASS / ❌ FAIL
- Hatalar (varsa)
- Öneriler
```

---

### Rol 5: REVIEWER (Kod Reviewer) — Mevcut

**Sorumluluk:** Push öncesi final review

**Mevcut:** gwen-reviewer.md zaten var

**Giriş:**
- git diff HEAD
- TESTER raporu

**Çıkış:**
- .review-status.json (ONAYLI/BLOKE)
- Review raporu

---

## 5. Implementasyon Önerisi (task-arge-012)

### Öncelik Sırası

**Faz 1: Operator Temeli (1-2 gün)**
1. gwen.md'yi operator'e çevir
2. RESEARCHER agent tanımla
3. Paralel context yükleme implement et

**Faz 2: Kodlama Ekibi (2-3 gün)**
1. ANALYST agent tanımla
2. CODER agent tanımla
3. İş dağıtımı mekanizması

**Faz 3: Test Ekibi (1 gün)**
1. TESTER agent tanımla
2. Otomatik test workflow'u

**Faz 4: Optimizasyon (1 gün)**
1. Koordinasyon overhead'i azalt
2. Context window yönetimi
3. Loop riski önleme

### task-arge-012 İçeriği

```markdown
# Task-arge-012: Operator Pattern Implementasyonu — Faz 1

## Yapılacaklar

### 1. gwen.md Operator'e Çevir

**Değişiklik:**
- Kod yazma adımlarını CODER'a devret
- Subagent spawn mekanizması ekle
- Sonuç derleme mekanizması ekle

**Yeni Workflow:**
1. Task al
2. RESEARCHER spawn → context yükle
3. ANALYST spawn → kod analizi
4. CODER spawn → kod yaz
5. TESTER spawn → test et
6. Sonuçları derle
7. /review → gwen-reviewer
8. Commit + Push

### 2. RESEARCHER Agent Oluştur

**Dosya:** `.agents/qwen/agents/researcher.md`

**Tools:**
- read_file (paralel 3 dosya)
- grep_search

**Prompt:**
- Domain rules oku
- RPC reference oku
- UI map oku
- Özet çıkar

### 3. Sync Mekanizması

**Setup.sh güncelle:**
- RESEARCHER agent'ı ~/.qwen/agents/'e kopyala

### Kabul Kriterleri
- [ ] gwen.md operator workflow'u var
- [ ] RESEARCHER agent oluşturuldu
- [ ] Paralel context yükleme çalışıyor
- [ ] Push edildi
```

---

## 6. Riskler / Dikkat Edilecekler

### 1. Coordination Overhead'i

**Risk:**
```
Operator: 5 subagent spawn eder
Her agent: 100-200 satır context
Toplam: 500-1000 satır context switch
```

**Önlem:**
- Max 3 paralel agent (RESEARCHER + ANALYST + CODER)
- TESTER sıralı (CODER bitince)
- Context özetleme (her agent 50 satır max özet)

---

### 2. Loop Riski

**Risk:**
```
Operator → RESEARCHER spawn
RESEARCHER → hata yap → Operator'a dön
Operator → tekrar RESEARCHER spawn
→ Sonsuz loop
```

**Önlem:**
- Max 3 retry per agent
- Retry sonrası manuel intervention
- Error budget: 3 failed agent → task bloke

---

### 3. Context Sınırı

**Risk:**
```
Qwen Code context window: Sınırlı
5 subagent × 200 satır = 1000 satır
+ Operator context = 1500+ satır
→ Context overflow
```

**Önlem:**
- Agent özetleri 50 satır max
- BLACKBOARD.md shared state (context dışı)
- Dosya bazlı iletişim (agent dosya yazar, operator okur)

---

### 4. Aynı Dosyaya Paralel Yazma

**Risk:**
```
CODER-A: js/forms.js satır 100-150
CODER-B: js/forms.js satır 120-170
→ Çakışma! Git merge conflict
```

**Önlem:**
- BLACKBOARD.md dosya kilidi:
  ```
  js/forms.js → CODER-A (meşgul)
  js/ui.js → CODER-B (boş)
  ```
- Operator koordinasyon: "Sen forms.js yap, ben ui.js yaparım"

---

### 5. Agent Yorgunluğu

**Risk:**
```
Uzun task (2+ saat):
- Operator: 10+ subagent spawn
- Her spawn: context switch
- Agent: "I'm getting tired" → kalite düşer
```

**Önlem:**
- Task bölme: Büyük task → 2-3 küçük task
- Blackboard checkpoint: Her 30 dakikada rapor
- Manual intervention: 2 saat → kullanıcı onayı

---

## 7. Sonuç

### Önerilen Mimari

```
┌─────────────────────────────────────────────────────────┐
│  OPERATOR (gwen.md) — Takım Lideri                      │
├─────────────────────────────────────────────────────────┤
│  ├── RESEARCHER → Context yükle (paralel)              │
│  ├── ANALYST    → Kod analizi                           │
│  ├── CODER      → Kod yaz (frontend + backend)          │
│  ├── TESTER     → Test et (syntax + security)           │
│  └── REVIEWER   → Push onayı (gwen-reviewer)            │
└─────────────────────────────────────────────────────────┘
```

### Beklenen Faydalar

**1. Hız:**
- Paralel context yükleme: 3× hızlanır
- Paralel kod yazma: 2× hızlanır
- Toplam: %40-60 task süresi azalır

**2. Kalite:**
- Uzmanlaşma: Her agent kendi işinde uzman
- Test otomasyonu: TESTER her task'ta
- Review zorunluluğu: Değişmez

**3. Ölçeklenebilirlik:**
- Büyük task'lar: 5+ subagent ile manageable
- Paralel task'lar: BLACKBOARD ile koordine

### Riskler

- Coordination overhead: 3 paralel agent max
- Loop riski: 3 retry limit
- Context sınır: 50 satır özet max
- Dosya çakışma: BLACKBOARD file lock

---

**Tasarım tamamlandı.** task-arge-012 implementasyon için hazır.

🏗️ Operator pattern ready for implementation.
