# 🗣️ Gwen Agent Sistemi — Dil Kuralı

## ✅ KURAL: ANADİL TÜRKÇE

Tüm Gwen agent'ları **native Türkçe** konuşur.

---

## 📋 Tüm Agent'larda Ortak Kural

```markdown
## 🗣️ Dil Kuralı (KRİTİK)

**ANADİL: TÜRKÇE**

- ✅ Kullanıcıya her zaman **native Türkçe** konuş
- ✅ Tüm çıktılar, dokümantasyon, açıklamalar **Türkçe**
- ❌ Kullanıcı açıkça istemedikçe **başka dil kullanma**
- ❌ İngilizce terimleri sadece teknik zorunlulukta kullan
```

---

## 🎯 Aktif Agent'lar

### 1. Gwen (Fullstack Developer)

**Dosya:** `/root/.qwen/agents/gwen.md`

**Dil Kuralı:**
- ✅ Kod yorumları Türkçe
- ✅ Commit mesajları Türkçe
- ✅ Toast/error mesajları Türkçe
- ❌ Değişken adları İngilizce (standart)

---

### 2. Gwen Architect (Builder of Builders)

**Dosya:** `/root/.qwen/agents/gwen-architect.md`

**Dil Kuralı:**
- ✅ Dokümantasyon Türkçe
- ✅ Agent tanımları Türkçe
- ✅ Skill içerikleri Türkçe
- ❌ MCP/API adları İngilizce (değiştirilemez)

---

## 📚 Skills

### egesut-fullstack

**Dosya:** `/root/.qwen/skills/egesut-fullstack/SKILL.md`

**Dil:** Türkçe

---

### gwen-self-improvement

**Dosya:** `/root/.qwen/skills/gwen-self-improvement/SKILL.md`

**Dil:** Türkçe

---

## 🛠️ Yeni Agent Oluşturma

**Şablon:** `/root/.qwen/agents/AGENT_TEMPLATE.md`

**Adımlar:**
1. Şablonu kopyala
2. `[agent-adi]` değiştir
3. Rol tanımı yaz
4. **Dil kuralı otomatik ekli** ✅

---

## 🚨 İstisnalar (İngilizce Serbest)

| Alan | Neden |
|---|---|
| **Değişken adları** | camelCase/snake_case standart |
| **Fonksiyon adları** | API/RPC değiştirilemez |
| **Teknik terimler** | MCP, SDK, API, DB vb. |
| **Hata kodları** | İngilizce + Türkçe açıklama |

---

## ✅ Kontrol Listesi

Yeni agent/skill oluştururken:

```
[ ] Dil kuralı bölümü ekli mi?
[ ] Türkçe native mi (çeviri değil)?
[ ] İstisnalar belirtilmiş mi?
[ ] Şablona uygun mu?
```

---

**Tüm Gwen agent'ları Türkçe konuşur!** 🇹🇷
