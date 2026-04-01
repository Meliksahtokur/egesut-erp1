# Task-arge-003: MCP Temizliği + Gwen Test Protokolü

**Durum:** bekliyor
**Branch:** gwen/arge
**Session:** arge

---

## Açıklama

İki iş var:
1. Ölü MCP config'lerini temizle (gwen-supabase, gwen-github node_modules yok, çalışmıyor)
2. Gwen'in test sırasında ui_logs realtime okuması için protokol ekle

---

## 1. settings.json temizliği

Dosya: `/root/egesut-erp1/.qwen/settings.json`

`mcpServers` bölümünden `gwen-supabase` ve `gwen-github` girdilerini sil. Sadece `context7` kalsın:

```json
"mcpServers": {
  "context7": {
    "command": "npx",
    "args": ["-y", "@upstash/context7-mcp@latest"],
    "env": { "CONTEXT7_API_KEY": "ctx7sk-3690ea35-9122-479a-b65b-d4fe04478ff1" },
    "trust": true
  }
}
```

---

## 2. QWEN.md + gwen.md — Test Protokolü

`task-dev-008` tamamlanınca `ui_logs` tablosu ve realtime kanalı hazır olacak. Gwen'in test sırasında bunu kullanması için protokol ekle.

### gwen.md'ye ekle (`/root/.qwen/agents/gwen.md`)

`Test & Telemetry` bölümüne şunu ekle/güncelle:

```markdown
## 🧪 Test Protokolü (ui_logs + Realtime)

Test sırasında Gwen şunları yapar:

1. **Kullanıcı test başlamadan önce:** `ui_logs` tablosunu temizle (opsiyonel) veya `session_id` not al
2. **Test sırasında:** `ui_logs` realtime kanalını izle — her INSERT gelince ekrana yaz
3. **Test bittikten sonra:**
   ```sql
   select level, message, source, payload, created_at
   from ui_logs
   where session_id = '[session_id]'
   order by created_at;
   ```
4. **Hata varsa:** `level = 'error'` kayıtlarına bak → DB ile karşılaştır (`islem_log`)
5. **Rapor:** Hata + aksiyon zinciri özeti çıkar

### Supabase CLI ile okuma (alternatif):
```bash
# Son 50 ui log
supabase db exec --project-ref zqnexqbdfvbhlxzelzju \
  "select level, message, created_at from ui_logs order by created_at desc limit 50"
```
```

### QWEN.md'ye de aynı bölümü ekle (`/root/egesut-erp1/.qwen/QWEN.md`)

---

## 3. arge-002'den STATUS adımlarını geri al

`/root/.qwen/agents/gwen.md` içinde arge-002'nin eklediği STATUS.md güncelleme adımlarını çıkar — STATUS.md kaldırıldı, bu adımlar gereksiz kaldı.

---

## Kabul Kriterleri

- [ ] `settings.json`'da sadece `context7` MCP var
- [ ] `gwen.md`'de test protokolü bölümü var (ui_logs + realtime)
- [ ] `QWEN.md`'de de aynı bölüm var
- [ ] `gwen.md`'den STATUS.md adımları temizlendi
- [ ] Branch: gwen/arge
- [ ] Tamamlanınca `task-arge-003-done.md` yaz

---

## Notlar

- Bu task `task-dev-008` ile paralel çalışabilir
- `task-dev-008` bitmeden test protokolü kullanılamaz ama yazılabilir
- js/ dosyalarına dokunma
