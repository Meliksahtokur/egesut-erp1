## ⚠️ 4 DEMİR KURAL — İHLAL YASAK

### Kural 1: Task İzolasyonu
- gwen/dev (qwen-dev) → SADECE `.claude/tasks/dev/` klasörüne bak
- gwen/arge (qwen-arge) → SADECE `.claude/tasks/arge/` klasörüne bak
- Diğer klasörü aç**ma**, oku**ma**, yap**ma**

### Kural 2: Otonom Workflow (sıra değişmez)
```
1. .claude/tasks/{session}/ACTIVE.md yaz
2. Task uygula
3. node --check js/*.js (dev için)
4. git add + git commit -m "DONE: [session] — [açıklama]"
5. /review → gwen-reviewer
6. ✅ → git push + BLACKBOARD güncelle + done.md yaz + ACTIVE.md sil
7. ❌ → düzelt + commit + tekrar /review (max 3)
8. 3'te geçmezse → BLOCKED-[id].md yaz, dur
```

### Kural 3: Context7 Zorunlu
`.from()` `.rpc()` `.select()` `.insert()` `IndexedDB` `Service Worker` kullanmadan önce:
→ context7'den güncel doküman çek. "Biliyorum" demek YASAK.

### Kural 4: Task Bitişi Zorunlu Kontrol
Push sonrası HEPSI yapılmış olmalı:
- [ ] done.md oluşturuldu
- [ ] BLACKBOARD.md güncellendi
- [ ] ACTIVE.md silindi
- [ ] Claude'a bildirildi (BLACKBOARD'a "DONE: task-XXX" yaz)

---

## Worktree Paths

| Session | Path | Branch |
|---------|------|--------|
| dev | `/root/qwen-dev` | `gwen/dev` |
| arge | `/root/qwen-arge` | `gwen/arge` |
| claude | `/root/egesut-erp1` | `main` |

---

## Qwen Added Memories
- Gwen MCP Server (gwen-mcp-server.js) arka planda başlatılamıyor - nohup/setsid ile başlatılınca 1-2 saniye içinde çöküyor. Manuel "node server.js </dev/null &" ile çalışıyor. Sorun: script içindeki başlatma yöntemi (nohup/setsid) MCP server'ın stdio mode'u ile uyumsuz. Çözüm bulunana kadar gwen-cli.sh proses yönetimi tam çalışmaz.
- Hata çözme kuralı: Bir sorunla max 4-5 kere uğraş, çözemezsen kullanıcıya detaylı hata raporu ver ve durumu izah et. Aynı sorunu defalarca çözmeye çalışma, zaman kaybetme.
