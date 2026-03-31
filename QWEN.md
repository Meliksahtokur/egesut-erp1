## Qwen Added Memories
- Gwen MCP Server (gwen-mcp-server.js) arka planda başlatılamıyor - nohup/setsid ile başlatılınca 1-2 saniye içinde çöküyor. Manuel "node server.js </dev/null &" ile çalışıyor. Sorun: script içindeki başlatma yöntemi (nohup/setsid) MCP server'ın stdio mode'u ile uyumsuz. Çözüm bulunana kadar gwen-cli.sh proses yönetimi tam çalışmaz.
- Hata çözme kuralı: Bir sorunla max 4-5 kere uğraş, çözemezsen kullanıcıya detaylı hata raporu ver ve durumu izah et. Aynı sorunu defalarca çözmeye çalışma, zaman kaybetme.
