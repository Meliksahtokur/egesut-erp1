# Suçlu Araştırma Raporu — 2026-05-30

## Olay

`sk-7fb27f2c09d449539ac20d7d6aed9474` (etiket: "Goose tablet") DeepSeek API key'i
üzerinden 21-30 Mayıs arasında toplam **$8.71 (deepseek-v4-pro modeli)** harcanmış.
Özellikle 29 Mayıs: **947 request, 117M input token, $2.66**.

Kullanıcı bu işlemleri kendisinin yapmadığını, 29 Mayıs'ta yoğun çalışmadığını
belirtiyor. Goose daemon'un habersiz çalıştığı fark edilmiş.

---

## 1. Tespit Edilen DeepSeek API Key Deposu

### Key 1: `sk-7fb27f2c09d449539ac20d7d6aed9474` (GERÇEK KEY — SAĞLAM)
DeepSeek dashboard'ında "Goose tablet" olarak etiketlenmiş. Tüm gerçek API çağrıları
bu key üzerinden yapılıyor.

| Dosya | Kullanım Şekli |
|-------|---------------|
| `/root/.bashrc` (L51) | `export DEEPSEEK_API_KEY=...` — shell env |
| `/root/tools-bank/mcp_server/deepseek_mcp.py` (L10) | `API_KEY = "..."` — hardcode |
| `/root/deer-flow/.env` | `DEEPSEEK_API_KEY=...` — env file |
| `/root/tools-bank/internal/proxy/handler.go` | `os.Getenv("DEEPSEEK_UPSTREAM")` — runtime |

### Key 2: `sk-7634e7a3d2d44b97997475cc313a4bb0` (DUMMY — İPTAL EDİLDİ)
Sadece local proxy'e (localhost:8742) gitmek için kullanılıyor. Proxy bu key'i
atıp yerine gerçek 9474 key'ini koyuyor. İptalinin hiçbir etkisi yok.

| Dosya | Kullanım Şekli |
|-------|---------------|
| `/root/.config/goose/config.yaml` (L5) | Goose → localhost:8742 auth |
| `/root/.config/goose/secrets.yaml` (L2) | Yedek |
| `/root/tools-bank/scripts/start-goose-serve.sh` (L9) | Hardcode export |

---

## 2. Tüm Şüphelilerin İncelenmesi

### Şüpheli A: Goose ACP Daemon (goused-watchdog, goused-api, goused-proxy, goused-telsiz)

**Binary'ler:**
- `/root/tools-bank/bin/goused-watchdog` (Go, 8.6MB, 21 Mayıs build)
- `/root/tools-bank/bin/goused-api` (Go, 12.1MB, 21 Mayıs build)
- `/root/tools-bank/bin/goused-proxy` (Go, 9.0MB, 17 Mayıs build)
- `/root/tools-bank/bin/goused-telsiz` (Go, 12.0MB, 17 Mayıs build)

**Ne yapıyor:**
- goused-watchdog: 30 sn'de bir health check (proxy:8742, api:8743, telsiz:8744, goose-serve:3284)
  Ölü process'i otomatik restart eder.
- goused-proxy: DeepSeek API proxy'si. `thinking:disabled` ekler, model adını DEĞİŞTİRMEZ.
  `DEEPSEEK_API_KEY` env'den okur.
- goused-api: Goose worker session yöneticisi.
- goused-telsiz: Agent mesaj kuyruğu.

**Çalışma geçmişi:** ACP oturumlarının LOG'ları incelendi:
- Tüm ACP log'ları `/root/tools-bank/logs/goose-acp-*.log` — **hepsi 21 Mayıs** (09:00-20:22).
- 22 Mayıs sonrası hiçbir ACP worker oturumu kaydı yok.
- `goose_sessions.db` (goused-api'nin SQLite DB'si) — **tamamen boş** (0 kayıt).

**Mevcut durum:** goused process'leri çalışmıyor. Log dosyaları güncel değil.

**Sonuç: ❌ Elendi.** 21 Mayıs'tan sonra hiçbir ACP worker oturumu yok. Watchdog
sadece process canlılığını korumuş, API çağrısı yapmamış.

---

### Şüpheli B: deepseek_mcp.py (PID 4042)

**Ne yapıyor:** Claude Code'un MCP subprocess'i olarak çalışan minimal DeepSeek MCP
server. 9474 key'i hardcode içeriyor.

**Modeli:** `deepseek-chat` (maps to deepseek-v4-flash), NOT v4-pro.

**CPU tüketimi:** 0:02 — neredeyse hiç kullanılmamış.

**Claude Code history:** `grep -c deepseek_chat` = 0 çağrı.

**Sonuç: ❌ Elendi.** Modeli flash (pro değil), CPU'su 0:02, hiç çağrılmamış.

---

### Şüpheli C: DeerFlow Gateway

**Config:** `/root/deer-flow/config.yaml`
- `deepseek-v4-flash` ve `deepseek-v4-pro` **ikisi de aktif** (yorum satırı DEĞİL).
- İkisi de `$DEEPSEEK_API_KEY` kullanıyor → .env'deki 9474 key.

**Çalışma geçmişi:**
- 25 Mayıs 15:36:37 — Gateway başarıyla başlamış:
  ```
  Uvicorn running on http://0.0.0.0:8001
  LangGraph runtime initialised
  ```
- `/tmp/deerflow.log`'da kaydı var.
- Gateway çalışırken `deerflow_research` MCP tool'u üzerinden API çağrıları
  yapılabilir.

**Cache hit oranı analizi:** 29 Mayıs verileri:
- Input (Cache hit): 112,645,888 token (%96)
- Input (Cache miss): 4,312,094 token (%4)
- Toplam: 116,957,982 token

DeerFlow LangChain/LangGraph tabanlıdır. Her research çağrısında LangGraph farklı
prompt yapıları kurar — bu kadar yüksek cache hit oranı (%96) LangChain yapısıyla
tutarlı DEĞİLDİR. Yüksek cache hit oranı, aynı system prompt'un tekrar tekrar
gönderildiği native DeepSeek API kullanımını işaret eder (agent loop pattern'i).

**Mevcut durum:** Gateway çalışmıyor (port 8001 kapalı, process yok).

**Sonuç: ❌ Elendi.** Yüksek cache hit oranı DeerFlow/LangChain pattern'i ile
açıklanamaz. Model aktif olmasına rağmen 947 çağrının kaynağı olamaz.

---

### Şüpheli D: Eski Python/Bash Daemon'ları

**Dosyalar:**
- `/root/tools-bank/workers/event_daemon_v2.sh` (855 satır) — inotifywait ile
  blackboard/tasks/ izler, yeni task gelince Goose worker başlatır.
- `/root/tools-bank/workers/start_pipeline.sh` — event_daemon + proxy başlatır.
- `/root/tools-bank/workers/goose+` — proxy-aware Goose launcher.
- `/root/tools-bank/automation/file_watcher.sh` — kod değişikliğini izler,
  memory update tetikler.

**Mevcut durum:** Hiçbiri çalışmıyor. Log'ları güncel değil.
`daemon-manager.sh` zaten `exit 0` ile devre dışı.

**Sonuç: ❌ Elendi.**

---

### Şüpheli E: master_daemon.sh (KAYIP DOSYA)

**Kanıt:** `/tmp/tools-bank-master.log` — 29 Mayıs 22:54:
```
bash: /root/tools-bank/workers/master_daemon.sh: No such file or directory
```
(15 kere tekrarlanmış, sonra durmuş.)

**Geçmiş:** Task-044'te geçiyor: `master_daemon.sh` eskiden varmış, webhook
sistemiyle değiştirilmiş. `termux_boot_claude.sh` boot'ta bunu çağırıyormuş.

**Durum:** Dosya silinmiş. 15 kere denenmiş, fail etmiş. API çağrısı yapacak
kadar çalışmamış.

**Sonuç: ❌ Elendi.** Çalışmadı, sadece "file not found" hatası verdi.

---

### Şüpheli F: Claude Code (PID 3540)

**Ne yapıyor:** `/usr/local/bin/claude --dangerously-skip-permissions --resume`
ile çalışan Claude Code CLI.

**Yan process'leri:**
- `python3 deepseek_mcp.py` (PID 4042) — MCP subprocess, idle
- `python3 server.py --stdio` (PID 4136) — tools-bank MCP

**tools-bank MCP üzerinden yapabilecekleri:**
- `deerflow_research` → DeerFlow Gateway (ama DeerFlow çalışmıyor)
- `goose_start` → yeni Goose worker başlatma
- `memory_search`, `semantic_search` → embedding API (MiniMax/Jina, DeepSeek değil)

**Claude Code kendi API'si:** Claude Code (Anthropic ürünü) kendi Anthropic API'ini
kullanır. Anthropic API harcaması DeepSeek dashboard'ında GÖRÜNMEZ.

**tools-bank'ta Claude'un son commit'i:** 21 Mayıs 20:07.

**tools-bank'ta Claude'dan sonra:** Hiçbir aktivite yok.

**Sonuç: ❌ Elendi.** Claude Code'un Anthropic API kullanımı başka bir dashboard'da
görünür. 29 Mayıs'ta tools-bank'ta hiç Claude aktivitesi yok.

---

### Şüpheli G: DeepSeek TUI (kullanıcının kendi oturumları)

**Config:** `/root/.config/deepseek/settings.toml`:
```
default_model = "deepseek-v4-flash"
[provider_models]
deepseek = "deepseek-v4-flash"
```

**Versiyon:** 0.8.35.

**Key:** `.bashrc`'den `DEEPSEEK_API_KEY` env'i alır → 9474 key.

**29 Mayıs commit trafiği:** 29 commit (06:34 - 21:58).

**Cache hit oranı:** %96 — TUI'in her adımda aynı system prompt'u göndermesiyle
tutarlı. Agent loop pattern'i.

**Kullanıcı beyanı:** "Dün çok fazla çalışamadım, başka işler vardı",
"Kullanmadım ki TUI'yi", "Varsayılan flash, v4-pro değil".

**Sonuç: ❌ Elendi** (kullanıcı beyanına dayanarak). Ancak teknik verilerle
çelişiyor: 29 commit atılmış, 947 API çağrısı yapılmış.

---

## 3. Çözülemeyen Çelişki

```
Kullanıcı:  "29 Mayıs'ta çalışmadım, TUI kullanmadım"
Git log:    29 Mayıs'ta 29 commit var (author: Meliksahtokur)
DeepSeek:   947 v4-pro isteği, 117M token, $2.66
Cache hit:  %96 — native DeepSeek API agent loop pattern'i
```

**Elenen tüm şüpheliler:**
- ❌ Goose ACP daemon (son aktivite 21 Mayıs)
- ❌ deepseek_mcp.py (idle, model flash)
- ❌ DeerFlow (LangChain cache hit pattern'iyle uyuşmaz)
- ❌ Eski bash daemon'ları (çalışmıyor)
- ❌ master_daemon.sh (dosya yok, çalışamadı)
- ❌ Claude Code (Anthropic API, farklı fatura)
- ❌ DeepSeek TUI (kullanıcı beyanı)

**Geriye kalan tek olasılık — doğrulanamayan:**
947 isteğin tamamı aynı API key (9474) üzerinden ve aynı "Goose tablet"
etiketiyle görünüyor. Bu key'e sahip olabilecek herşey elendi. Ya:
- Kullanıcının unuttuğu/hatırlamadığı bir DeepSeek TUI oturumu oldu,
- Veya sistemde hâlâ bulunamayan bir otomatik süreç var,
- Veya DeepSeek dashboard'ındaki "Goose tablet" etiketi kullanıcının
  sandığından farklı bir key'e ait (9474 değil, başka bir key olabilir).

---

## 4. Ek: Temizlenmesi Gereken Güvenlik Açıkları

| Risk | Dosya | Yapılacak |
|------|-------|-----------|
| 🔴 Hardcode API key | `tools-bank/mcp_server/deepseek_mcp.py` (L10) | Key'i kaldır, env'den al |
| 🟡 DeerFlow v4-pro açık | `deer-flow/config.yaml` (L177) | Modeli kaldır veya yorumla |
| 🟡 DeerFlow .env'de key | `deer-flow/.env` | Placeholder ile değiştir |
| 🟢 Goose config'de dummy key | `.config/goose/config.yaml` | Zaten iptal edildi |
