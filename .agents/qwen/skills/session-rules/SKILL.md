---
name: session-rules
description: Dev/arge session tipi kilidi, paralel subagent kuralları, DONE: commit zorunluluğu
version: 1.0.1
session: her ikisi (dev + arge)
---

# Session Rules Skill

## 🗣️ Dil Kuralı (KRİTİK)

**ANADİL: TÜRKÇE**

- ✅ Tüm kurallar, açıklamalar **Türkçe**
- ✅ Commit mesajları **Türkçe**
- ❌ Kullanıcı istemedikçe İngilizce kullanma

---

## 🎯 Ne Zaman Kullanılır

**Bu skill HER session'da aktif olur (dev + arge).**

- Session başlangıcında tip belirleme
- Session kurallarını hatırlama
- Paralel subagent yönetimi
- Commit mesajı validasyonu

---

## 🔒 Session Tipi Kilidi (DEĞİŞTİRİLEMEZ)

### Session Tipleri

| Tip | Branch | Amaç | Yasak |
|-----|--------|------|-------|
| **dev** | `feature/gwen-*` | ERP geliştirme | Arge işi YASAK |
| **arge** | `feature/gwen-arge` | Sistem geliştirme | ERP dev YASAK |

### Kural

```
Session başında tip belirlenir → Sonuna kadar değişmez → İhlal YASAK
```

### Dev Session Kuralları

```
✅ Yapılabilir:
- Tohumlama, doğum, hayvan yönetimi geliştirme
- UI bug fix'leri (fix-ui skill)
- RPC/schema değişiklikleri
- Feature branch'lerde kod üretimi

❌ Yasak:
- Arge işleri (skill/agent/MCP geliştirme)
- .qwen/ dizininde değişiklik
- Bu skill'i dev session'da düzenleme
```

### Arge Session Kuralları

```
✅ Yapılabilir:
- Qwen skills geliştirme (egesut-fullstack, fix-ui, gwen-self-improvement)
- Yeni agent/skill/MCP oluşturma
- Workflow iyileştirme
- .qwen/ dizininde değişiklik

❌ Yasak:
- ERP geliştirme (tohumlama, doğum, hayvan yönetimi)
- js/ dizininde değişiklik
- Domain koduna müdahale
- Bu skill'i arge session'da düzenleme
```

---

## 🔄 Paralel Subagent Kuralları

### Sub-orchestrator Yasağı

```
❌ Qwen → Başka Qwen spawn EDEMEZ
✅ Qwen → Native subagent kullanabilir (runner olarak)
```

**Native Subagent'lar:**
- `gwen-architect` — Gwen CLI uzmanı
- `gwen` — Fullstack developer
- `general-purpose` — Genel amaçlı
- `Explore` — Codebase exploration

### Runner Subagent Kuralı

**Runner = Aynı ekranda, ayrı proses**

| Özellik | Açıklama |
|---------|----------|
| **Spawn** | Qwen → native subagent |
| **Execution** | Aynı ekranda çalışır |
| **Paralellik** | Birden fazla subagent aynı anda çalışabilir |

### ⚠️ Paralel İşlem Kuralları (KRİTİK)

**Paralel YAZMA yasaktır, paralel okuma/analiz serbesttir.**

| İşlem | Durum | Örnek |
|-------|-------|-------|
| **Paralel Okuma** | ✅ İZİN VERİLİR | Agent A: dosya1.md oku + Agent B: dosya2.md oku |
| **Paralel Analiz** | ✅ İZİN VERİLİR | Agent A: dosya1 analiz et + Agent B: dosya2 analiz et |
| **Paralel Yazma (Farklı Dosya)** | ✅ İZİN VERİLİR | Agent A: .qwen/QWEN.md + Agent B: .qwen/skills/SKILL.md |
| **Paralel Yazma (Aynı Dosya)** | ❌ YASAK | Agent A: QWEN.md düzenle + Agent B: QWEN.md düzenle |

**Kural:** Aynı dosyaya paralel yazma YASAK — çakışma önlenir.

---

## ✅ DONE: Commit Zorunluluğu

### Commit Mesajı Formatı

```
DONE: [session-tipi] — [açıklama]

Örnekler:
DONE: dev — Tohumlama formu tarih validasyonu eklendi
DONE: arge — session-rules skill'i oluşturuldu
DONE: dev — UI bug: modal kapanma sorunu fix edildi
DONE: arge — gwen-self-improvement skill güncellendi
```

### Kurallar

1. **İlk satır `DONE:` ile başlar** — Her zaman
2. **Session tipi belirtilir** — `dev` veya `arge`
3. **Açıklama net olur** — Ne yapıldığı tek cümlede
4. **Türkçe** — Commit mesajı Türkçe

### Dev Session Commit

```bash
git add js/ supabase/
git commit -m "DONE: dev — [açıklama]"
```

### Arge Session Commit

```bash
git add .qwen/
git commit -m "DONE: arge — [açıklama]"
```

---

## 📋 Session Checklist

### Session Başlangıcı

```
[ ] Session tipi belirlendi (dev/arge)
[ ] Doğru branch'e geçildi
[ ] MCP servers doğrulandı (qwen mcp list)
[ ] İlgili skills aktif edildi
```

### Task Başlangıcı

```
[ ] Session tipi kontrol edildi (dev/arge kilidi)
[ ] Task session tipine uygun mu?
[ ] Paralel subagent gerekiyor mu?
[ ] Aynı dosyaya çakışma riski var mı?
```

### Task Sonu

```
[ ] Kod test edildi (UI değişikliği ise tarayıcıda)
[ ] Syntax kontrolü geçti (node --check)
[ ] Duplikat kontrolü yapıldı (grep)
[ ] DONE: commit mesajı hazır
```

---

## 🚨 İhlal Senaryoları

### Senaryo 1: Session Tipi İhlali

```
❌ dev session'da:
   "Yeni agent oluşturalım"
   → YASAK! Bu arge işi → gwen-arge kullan

❌ arge session'da:
   "Tohumlama formuna alan ekleyelim"
   → YASAK! Bu ERP dev → gwen-dev kullan
```

### Senaryo 2: Paralel Yazma Çakışması

```
❌ Aynı anda:
   gwen-architect → .qwen/QWEN.md düzenle
   gwen → .qwen/QWEN.md düzenle
   → YASAK! Çakışma oluşur

✅ Doğru:
   Önce gwen-architect → .qwen/QWEN.md düzenle
   Sonra gwen → .qwen/skills/SKILL.md düzenle
```

### Senaryo 3: DONE: Olmayan Commit

```
❌ git commit -m "fix: UI bug"
   → YASAK! DONE: ile başlamalı

✅ git commit -m "DONE: dev — UI bug fix edildi"
   → Doğru!
```

---

## 📖 Referanslar

- **Session Yönetimi:** `.qwen/QWEN.md`
- **Hiyerarşi:** `.qwen/AGENT_HIERARCHY.md`
- **CLI Script:** `gwen-cli.sh`
- **Dev Skills:** `egesut-fullstack`, `fix-ui`
- **Arge Skills:** `gwen-self-improvement`

---

## 🎯 Özet

```
┌─────────────────────────────────────────────┐
│  SESSION RULES — 3 KRİTİK KURAL             │
├─────────────────────────────────────────────┤
│  1. Session tipi kilidi (dev/arge)          │
│     → Başında belirlenir, değişmez          │
│     → İhlal YASAK                           │
├─────────────────────────────────────────────┤
│  2. Paralel subagent                        │
│     → Aynı dosyaya paralel yazma YASAK      │
│     → Farklı dosyalara paralel yazma ✅     │
├─────────────────────────────────────────────┤
│  3. DONE: commit                            │
│     → İlk satır DONE: ile başlar            │
│     → Session tipi belirtilir               │
│     → Türkçe mesaj                          │
└─────────────────────────────────────────────┘
```

---

**Bu skill yüklendiğinde:** Session kuralları otomatik aktif olur. İhlal yok!

🔒 Session Rules aktif.
