# Task-arge-010: rpc-contract Skill + gwen-reviewer Güvenlik Kontrolleri

**Durum:** bekliyor
**Branch:** gwen/arge
**Tarih:** 2026-04-02
**Öncelik:** orta

---

## Yapılacaklar

### 1. rpc-contract Skill (dev session)

**Dosya:** `.agents/qwen/skills/rpc-contract/SKILL.md`

İçerik — Gwen/dev'in RPC kullanırken başvuracağı kontrol listesi:

```markdown
# rpc-contract

## Kural
- Direkt INSERT/UPDATE/DELETE/PATCH → YASAK
- SADECE `supabase.rpc()` kullan
- RPC imzasını `.claude/rpc-reference.md`'den doğrula

## Kullanım Öncesi Kontrol
- [ ] RPC adı `.claude/rpc-reference.md`'de var mı?
- [ ] Parametreler imzayla eşleşiyor mu?
- [ ] Return `{ ok: boolean, ... }` formatında mı?
- [ ] `rpcOptimistic(name, params, opts)` — 1. parametre string RPC adı

## Yasak Örnek
supabase.from('tohumlama').insert({...})  ← YASAK

## Doğru Örnek
await rpcOptimistic('tohumlama_kaydet', { hayvan_id, tarih })
```

---

### 2. gwen-reviewer'a Güvenlik Kontrolleri Ekle

**Dosya:** `.agents/qwen/agents/gwen-reviewer.md` — mevcut kontrollere ekle

Eklenecek bölüm:

```markdown
## Güvenlik Kontrolleri (pre-push zorunlu)

### API Key / Token Exposure
- `grep -rn "ghp_\|supabase\|apikey\|password\|secret" js/ --include="*.js"` → sonuç varsa BLOKE
- Hardcoded credential → push YASAK, hata raporu yaz

### SQL Injection
- `write()` veya direkt REST çağrısında kullanıcı inputu string concat ile birleşiyorsa → BLOKE
- RPC parametre binding kullanıyor mu? → OK

### Kural
Bu kontroller FAIL olursa push YASAK. gwen-reviewer raporu:
❌ GÜVENLİK BLOKE: [sebep]
```

---

## Kabul Kriterleri

- [ ] `.agents/qwen/skills/rpc-contract/SKILL.md` oluşturuldu
- [ ] `gwen-reviewer.md`'ye güvenlik kontrol bölümü eklendi
- [ ] Setup.sh ile yeni skill `~/.qwen/skills/`'e kopyalanıyor (kontrol et)
- [ ] Push edildi, `arge/task-arge-010-done.md` yazıldı

---

## Notlar

- MCP yazmak YASAK — bash/grep yeterli
- Yeni agent açmak YASAK — reviewer'a kural ekle
- Telemetry, performance, docs agent'ları bu task'a dahil değil
