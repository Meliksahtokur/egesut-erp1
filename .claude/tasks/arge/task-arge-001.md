# Task-arge-001: Agent ve Skill Optimizasyonu

**Durum:** bekliyor
**Session:** arge
**Branch:** gwen/arge-001

---

## Görev Özeti

Gwen'in agent tanımları ve skill'leri güncel değil. Temizle ve optimize et.

---

## 1. `gwen.md` agent'ını temizle

`/root/.qwen/agents/gwen.md` içinde **MCP Kullanımı** bölümü var:

```
## 🔧 MCP Kullanımı
- gwen-supabase  ← YOK, settings'de tanımlı değil
- gwen-context7  ← YANLIŞ isim, gerçek isim "context7"
- gwen-github    ← YOK, settings'de tanımlı değil
```

**Yapılacak:**

MCP bölümünü şununla değiştir:

```markdown
## 🔧 MCP Kullanımı

**Aktif MCP:**
- `context7` — kütüphane dokümantasyonu (supabase-js, vb.)

**CLI Araçları (MCP değil):**
- Supabase işlemleri → `supabase` CLI
- GitHub işlemleri → `gh` CLI
- DB sorguları → `supabase db` veya doğrudan SQL
```

**Ayrıca:** `## 🧪 Test & Telemetry` bölümünü oku.
`window.agentTestSession` browser'a bağımlı — Gwen bunu çalıştıramaz. Bu bölümü sil veya şu notu ekle: "Bu bölüm kullanıcı tarafından browser'da çalıştırılır, Gwen dokunmaz."

---

## 2. `egesut-fullstack` skill'ini güncelle

`/root/.qwen/skills/egesut-fullstack/SKILL.md` dosyasını oku.

Kontrol et:
- Son RPC isimleri doğru mu? (`tohumlama_kaydet`, `dogum_kaydet`, `abort_kaydet` vb.)
- `.claude/rpc-reference.md` ile karşılaştır — eksik/yanlış RPC varsa güncelle
- "Direkt REST PATCH/INSERT yasaktır" kuralı var mı? Yoksa ekle
- MCP referansı varsa kaldır, CLI ekle

---

## 3. `fix-ui` skill'ini gözden geçir

`/root/.qwen/skills/fix-ui/SKILL.md` dosyasını oku.

- Genel UI fix akışı mantıklı mı?
- `ui-map.md`'ye referans veriyor mu? Vermiyorsa ekle: "UI bileşeni bulmak için `/root/egesut-erp1-main/.claude/ui-map.md` kullan"
- Browser telemetry (`window.agentTestSession`) referansı varsa kaldır

---

## 4. `session-rules` skill'ini doğrula

`/root/.qwen/skills/session-rules/SKILL.md` dosyasını oku.

- Dev/arge ayrımı doğru mu?
- "DONE: commit" zorunluluğu açık mı?
- Paralel subagent yasağı yazıyor mu? Yazıyorsa "paralel YAZMA yasaktır, paralel okuma/analiz serbesttir" olarak netleştir

---

## 5. `gwen-self-improvement` skill'ini koru

Bu skill'e dokunma — sadece oku, sorun yoksa bırak.

---

## Kabul Kriterleri

- [ ] `gwen.md`'de olmayan MCP referansı yok
- [ ] `egesut-fullstack` skill RPC listesi `rpc-reference.md` ile uyumlu
- [ ] `fix-ui` skill `ui-map.md`'ye referans veriyor
- [ ] `session-rules` paralel yazma yasağı net
- [ ] Tüm değişiklikler `gwen/arge-001` branch'inde commit edildi

## Tamamlandığında

`.claude/gwen-tasks/task-arge-001-done.md` yaz.
