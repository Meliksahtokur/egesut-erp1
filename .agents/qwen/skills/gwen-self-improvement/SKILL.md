---
name: gwen-self-improvement
description: Gwen自我 improvement — Gwen CLI, MCP, Agent, Skill geliştirme. Kendini daha iyi hale getir.
version: 2.0.0
session: arge
---

# Gwen Self-Improvement Skill

## ⚠️ ÖNKOŞUL: Branch Kontrolü (KRİTİK)

**Bu skill SADECE `feature/gwen-arge` branch'inde çalışır!**

### 🚀 Otomatik Branch Değişimi (ÖNERİLEN)

Skill kullanılmadan önce wrapper script çalıştır:
```bash
./gwen-self-improvement-wrapper.sh
```

Bu script:
- ✅ Otomatik olarak `feature/gwen-arge` branch'ine geçer
- ✅ Varsa değişiklikleri stash eder
- ✅ Branch değiştirdikten sonra stash geri yükler

### 📝 Manuel Branch Değişimi

```bash
git checkout feature/gwen-arge
```

---

## 🗣️ Dil Kuralı (KRİTİK)

**ANADİL: TÜRKÇE**

- ✅ Tüm iyileştirme önerileri **Türkçe**
- ✅ Dokümantasyon güncellemeleri **Türkçe**
- ✅ Agent/skill tanımları **Türkçe**
- ❌ Kullanıcı istemedikçe İngilizce kullanma

---

## 🎯 Ne Zaman Kullanılır

**Bu skill SADECE `arge` session'da aktif olur.**

- Gwen CLI'da bug tespit edildiğinde
- Yeni özellik ekleneceğinde
- Performance iyileştirmesi gerektiğinde
- Yeni agent/skill/MCP oluşturulacağında
- Workflow iyileştirme önerisi olduğunda

## ⚠️ Session Kilidi

**Bu skill AR-GE geliştirme içindir. ERP dev işi YASAK.**

❌ Tohumlama, doğum, hayvan yönetimi → `gwen-dev` kullan
❌ `js/` dizininde değişiklik → `gwen-dev` kullan

---

## 📚 Gwen Architecture

### Bileşenler

```
Gwen System
├── CLI Layer
│   ├── gwen-cli.sh              # Startup script
│   └── qwen-gwen.sh             # Qwen Code wrapper
├── Agent Layer
│   ├── /root/.qwen/agents/gwen.md         # Main agent
│   └── /root/.qwen/agents/gwen-architect.md # Architect agent
├── Skill Layer
│   ├── /root/.qwen/skills/egesut-fullstack/SKILL.md
│   ├── /root/.qwen/skills/fix-ui/SKILL.md
│   └── /root/.qwen/skills/gwen-self-improvement/SKILL.md
├── MCP Layer
│   ├── gwen-mcp-servers/supabase/
│   ├── gwen-mcp-servers/context7/
│   └── gwen-mcp-servers/github/
└── Config Layer
    └── /root/.qwen/settings.json
```

### İyileştirme Noktaları

**1. CLI Layer:**
- Startup hızı
- Error handling
- Output format
- Yeni komutlar

**2. Agent Layer:**
- Yeni subagent'lar
- System prompt iyileştirmeleri
- Tool optimizasyonu

**3. Skill Layer:**
- Domain knowledge genişletme
- Pattern ekleme
- Checklist güncelleme

**4. MCP Layer:**
- Yeni MCP sunucuları
- Mevcut MCP iyileştirmeleri
- Performance optimization

**5. Config Layer:**
- Settings optimizasyonu
- Environment variables
- Trust settings

---

## 🛠️ Geliştirme Process

### 1. Analiz

```bash
# Mevcut durumu anla
cat /root/.qwen/agents/gwen.md
cat /root/.qwen/skills/egesut-fullstack/SKILL.md
ls -la gwen-mcp-servers/
cat gwen-cli.sh
```

### 2. İyileştirme Önerisi

**Format:**
```markdown
## İyileştirme: [Başlık]

**Mevcut Durum:**
[Ne var?]

**Sorun/Fırsat:**
[Ne yanlış/eksik?]

**Öneri:**
[Ne yapılmalı?]

**Fayda:**
[Ne kazanılır?]

**Efor:**
[Küçük/Orta/Büyük]

**Öncelik:**
[Düşük/Orta/Yüksek/Kritik]
```

### 3. Implementasyon

**Küçük İyileştirme (1-2 saat):**
- Tek dosya değişikliği
- Tek agent/skill güncelleme
- Basit MCP ekleme

**Orta İyileştirme (1-2 gün):**
- Çoklu dosya değişikliği
- Yeni agent oluşturma
- MCP sunucusu geliştirme

**Büyük İyileştirme (1 hafta+):**
- Architecture değişikliği
- Yeni layer ekleme
- Major refactor

### 4. Test

```bash
# Her değişiklik sonrası
./gwen-cli.sh
# Output kontrol
# Agent kullanımı test
# MCP bağlantı test
```

### 5. Review (ZORUNLU)

**Workflow:**
```bash
# 1. Commit
git commit -m "DONE: arge — [iyileştirme özeti]"

# 2. Review (gwen-reviewer agent)
/review

# Agent şunları yapar:
# - git diff HEAD alır
# - Native /review skill'ini çağırır (Qwen Code)
# - Custom check yapar (architecture/security/consistency)
# - Tek rapor üretir

# 3. Push (sadece onaylı ise)
git push origin feature/gwen-arge
```

**Review Kriterleri:**
- ✅ Native review: Syntax, best practice, code quality
- ✅ Custom check: Architecture consistency, security, Türkçe dokümantasyon
- ✅ Push kararı: ✅ ONAYLI / ❌ BLOKE

### 6. Dokümantasyon

```markdown
# Değişiklik Log

## [Tarih] [Başlık]

**Değişiklik:**
[Ne değişti?]

**Neden:**
[Neden değişti?]

**Sonuç:**
[Ne kazanıldı?]

**Dosyalar:**
- [Değişen dosya 1]
- [Değişen dosya 2]
```

---

## 📋 İyileştirme Checklist

Her iyileştirme sonrası:

```
[ ] Analiz tamamlandı
[ ] İyileştirme önerisi yazıldı
[ ] Implementasyon yapıldı
[ ] Test edildi (./gwen-cli.sh)
[ ] Dokümantasyon güncellendi
[ ] DONE: commit mesajı hazır
[ ] /review çağrıldı mı?
[ ] Review onayı alındı mı?
```

---

## 🚨 Sık Yapılan Hatalar

1. **Test etmeden commit** → Her değişiklik sonrası test et!
2. **Dokümantasyon eksik** → Değişikliği belge!
3. **Breaking change** → Geriye uyumluluğu koru!
4. **Over-engineering** → Basit tut, KISS prensibi!
5. **ERP dev ihlali** → js/ dizininde değişiklik YASAK!

---

## 💡 İyileştirme Örnekleri

### Örnek 1: Yeni MCP Sunucusu

**Sorun:** Weather API erişimi yok
**Öneri:** `gwen-mcp-weather` ekle
**Fayda:** Hava durumu bilgisi ile task planlama
**Efor:** Küçük (2-3 saat)

### Örnek 2: Yeni Agent

**Sorun:** Test coverage düşük
**Öneri:** `gwen-tester` agent'ı oluştur
**Fayda:** Her task sonrası otomatik test
**Efor:** Orta (1 gün)

### Örnek 3: Skill Genişletme

**Sorun:** Domain bilgisi eksik
**Öneri:** `egesut-fullstack` skill'ine yeni bölümler ekle
**Fayda:** Daha iyi kod kalitesi
**Efor:** Küçük (1-2 saat)

---

## 🎯 Önceliklendirme

**Kritik (Hemen):**
- Bug fix'ler
- Security açıkları
- Data loss riski

**Yüksek (Bu hafta):**
- Performance bottleneck
- Major usability issue
- Frequently requested feature

**Orta (Bu ay):**
- New agent/skill
- MCP enhancement
- Documentation improvement

**Düşük (Zaman olunca):**
- Nice to have features
- Cosmetic improvements
- Refactoring

---

## 🔧 Hızlı Komutlar

**Durum Analizi:**
```bash
# Agent'ları listele
ls -la /root/.qwen/agents/

# Skills'leri listele
ls -la /root/.qwen/skills/

# MCP'leri listele
ls -la gwen-mcp-servers/

# Config kontrolü
cat /root/.qwen/settings.json
```

**Yeni Agent Oluştur:**
```bash
cat > /root/.qwen/agents/gwen-[name].md << 'EOF'
---
name: gwen-[name]
description: [Açıklama]
tools:
  - [tool listesi]
---

[... system prompt ...]
EOF
```

**Yeni Skill Oluştur:**
```bash
mkdir -p /root/.qwen/skills/gwen-[name]
cat > /root/.qwen/skills/gwen-[name]/SKILL.md << 'EOF'
---
name: gwen-[name]
description: [Açıklama]
---

[... skill content ...]
EOF
```

**Yeni MCP Oluştur:**
```bash
mkdir -p gwen-mcp-servers/[name]
cd gwen-mcp-servers/[name]
npm init -y
npm install @modelcontextprotocol/sdk zod
# index.js yaz
# Qwen Code settings'e ekle
```

---

## 📖 Referanslar

- **Session Kuralları:** `.qwen/QWEN.md`
- **Hiyerarşi:** `.qwen/AGENT_HIERARCHY.md`
- **CLI Script:** `gwen-cli.sh`
- **Wrapper:** `gwen-self-improvement-wrapper.sh`

---

**Bu skill yüklendiğinde:** Gwen自我 improvement mode aktif olur. Sürekli iyileştirme fırsatları ara!

🔧 Gwen自我 improvement hazır!
