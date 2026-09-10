---
name: codex-master
description: Use when delegating work to OpenAI Codex CLI (codex app-server, gpt-5/mini) as a Claude Code Agent Teams subagent via the native mailbox bridge — codex-teammate.py. Triggered by "codex'a ver", "codex worker başlat", "codex subagent", or when OMP/pi köprüleri sandbox/multi-tool fan-out gerektiren görevlerde yetersiz kalıyorsa. Covers NDJSON JSON-RPC wire format, OS-level sandbox flag mapping ([read]/[write] → read-only/workspace-write), approval flow (server→client JSON-RPC request), MCP wiring (tools-bank/gitnexus/lsp-bridge/supabase-demo), worktree-per-lane usage with omp-lane.sh, and Codex'in kendi goose-master skill'i.
---

# codex-master — OpenAI Codex (codex app-server) Subagent Köprüsü

> **Bağlam (2026-07-07):** EgeSüt orkestrasyonunda artık **üç gerçek teammate
> köprüsü** paralel çalışıyor: `omp-teammate.py` (MiniMax-M3, default),
> `pi-teammate.py` (MiniMax-M3 fallback, OMP tıkanırsa) ve `codex-teammate.py`
> (OpenAI gpt-5 ailesi, OS-level sandbox + MCP + çoklu thread). Üçü de
> **aynı native mailbox protokolünü** konuşuyor (`~/.claude/teams/{team}/
> config.json` + `inboxes/{name}.json`), birbirinden habersiz karışık
> çalıştırılabilir. Codex köprüsü özellikle **OS seviyesinde sandbox
> enforcement** (macOS seatbelt / Linux bubblewrap) ve **Codex'in kendi
> approval flow'u** (sunucu→client JSON-RPC request) istediğinde tercih
> edilir; pi/omp'deki tool-allowlist hack'i burada doğal bir yetenek olarak
> geliyor.

## Ne

Claude Code'un native Agent Teams dosya-tabanlı mailbox protokolünü (MCP değil —
`~/.claude/teams/{team}/config.json` + `inboxes/{name}.json`, FileLock'lı) doğrudan
konuşan bir adapter. OpenAI Codex CLI'ın stdio JSON-RPC `app-server`'ını (`codex
app-server` komutu) gerçek bir teammate gibi sokuyor. omp/pi ile **aynı protokol,
aynı [read]/[write] konvansiyonu, aynı worktree-per-lane modeli** — sadece alt
süreç persistent NDJSON peer olarak `codex app-server`, subprocess-per-call değil.

**Kaynak:** `/home/melik/tools-bank/scripts/codex-teammate.py`
(main'e merge edildi; 2026-07-08 itibarıyla Phase 1-3 mailbox lease/envelope +
worker registry heartbeat koduyla güncel). **Wire protokol haritası:**
`/tmp/claude-1000/.../codex-p1/FINDINGS.md`
(581 satır; NDJSON framing, JSON-RPC zarfı, `initialize`/`thread/start`/`turn/start`,
approval akışı v1+v2, notification listesi, örnek minimal client).

**Neden ayrı script, "omp"→"codex" string-replace DEĞİL:** Codex yüzeyi tamamen
farklı. omp/pi subprocess-per-call (her mesaj = yeni süreç + stdlib
`subprocess.run`); Codex ise **persistent NDJSON peer** — bir kez `codex
app-server` başlat, tüm lane ömrü boyunca stdin/stdout üzerinden JSON-RPC
konuştur. Ayrıca OMP/pi tool-allowlist (`--tools=...`) ile sınırlama yaparken
Codex **OS seviyesinde sandbox** uygular (FINDINGS.md §8: macOS seatbelt, Linux
bubblewrap). Bunlar string-replace ile taşınamaz, gerçek bir adapter gerektirir.

## KRİTİK FARKLAR (omp-teammate.py / pi-teammate.py'a göre — hepsi canlı test edildi)

| Konu | omp-teammate.py | pi-teammate.py | codex-teammate.py | Kanıt |
|---|---|---|---|---|
| Wire protokolü | `subprocess.run`, tek çağrı = tek süreç | `subprocess.run`, tek çağrı = tek süreç | **persistent NDJSON peer** — `codex app-server` bir kez başlar, lane ömrü boyunca yaşar | `CodexAppServer` sınıfı; `_reader_loop` / `_stderr_loop` daemon thread'leri |
| Transport | OS pipe (geçici) | OS pipe (geçici) | **stdin/stdout NDJSON**, satır başına bir JSON object + `"\n"`. Content-Length header YOK | FINDINGS.md §0; 380 byte stdout dump, `\n` delimiter doğrulandı |
| Framing | n/a (subprocess argv) | n/a | **JSON-RPC** envelope, ID monoton int (client→server) / server-assigned int (server→client request) | FINDINGS.md §1; `send_request` `_id_counter` |
| Handshake | n/a | n/a | `initialize` (zorunlu `clientInfo.name+version`) → response bekle. **`notifications/initialized` GEREKMİYOR** — LSP/MCP'nin aksine | FINDINGS.md §0 Deney 2; probe_initialized_notification.py |
| Sandbox/izin | `--tools=...` allowlist (UYGULAMA katmanı) | `--tools=...` allowlist (UYGULAMA katmanı) | **OS-level sandbox** (bubblewrap/seatbelt) + `sandbox` enum: `read-only` \| `workspace-write` \| `danger-full-access` | FINDINGS.md §3 Enum'lar; Codex OS tarafında enforce ediyor, ek allowlist şart değil |
| Onay akışı | `--auto-approve --approval-mode=yolo` flag'leri | `-p` modda `--tools` allowlist onaysız direkt çalışır | **server→client JSON-RPC request** (`item/commandExecution/requestApproval` vb.) — bridge otomatik `accept` döndürür, ID echo | FINDINGS.md §5/§5.1; `_handle_server_request` |
| Approval timeout | yok | yok (dış Python `timeout=`) | **30 sn fallback** (`APPROVAL_FALLBACK_TIMEOUT`) — Codex bir kez istek atıp cevap gelmezse bu kadar bekleyip "accept" fallback'i atar | `APPROVAL_FALLBACK_TIMEOUT = 30.0` constant |
| Turn timeout | subprocess.run timeout | subprocess.run timeout | **`TURN_TIMEOUT_DEFAULT = 600`** (saniye) — `turn/completed` notification'ına kadar; streaming agentMessageDelta metni biriktirilir | `run_turn` fonksiyonu, deadline loop |
| Thread/oturum | her mesajda yeni subprocess | her mesajda yeni subprocess (session dosyası biriktirmesin diye `--no-session` eklenmiş) | **cwd başına persistent thread** — ilk mesajda `thread/start`, sonrakilerde `thread/resume` → Codex'in oturum hafızası (önceki turdaki bağlam dahil) korunur | `_lane_threads` dict, `_get_or_create_thread` |
| Lane devamlılığı | `_lane_sessions: dict` (cwd → session_id) | yok | **`_lane_threads: dict`** (cwd → thread_id), `_get_or_create_thread` resume eder | omp'taki pattern'ın codex karşılığı |
| Cevap toplama | agent_end JSON parse, `_extract_final_text` | aynı | **`agentMessageDelta` text delta'ları biriktir**, `turn/completed` notification'ında `finalMessage` varsa onu tercih et, yoksa delta birleştir | `run_turn`, hem yeni hem legacy notification isimleri desteklenir |
| Binary keşfi | PATH'ta `omp` | PATH'ta `pi` (extension'lar settings.json'dan) | **`shutil.which("codex")` + hard-coded fallback** `/home/melik/.npm-global/bin/codex` (PATH'ta olmayabilir) | `find_codex_binary`, `CODEX_BIN_CANDIDATES` |
| Süreç ömrü | çağrı başına doğar/ölür | çağrı başına doğar/ölür | **process başına tek peer** (`_app`, `_app_key = bin_path`), `stop()` stdin close + terminate + wait + kill | `CodexAppServer.stop`, `_shutdown_app` |
| `--max-time` | subprocess.run timeout | subprocess.run timeout | aynı isim, ama **turn için bekleme üst sınırı**, subprocess değil | `--max-time` argümanı |
| `task` subagent | kapalı (asılı kalıyor) | kapalı (önlem) | **Codex'in kendi alt-ajan mekanizması yok** (Codex tek ajan), Codex dışarıya `goose-master` skill'i ile delege eder | bkz. "goose-master skill'i" bölümü aşağıda |
| Mailbox şeması, FileLock, register_self, lease-safe acquisition, write_to_inbox, parse_task_type, git_commit_lane, send_idle_notification, worker registry, main() argümanları ve poll loop iskeleti | — | — | **birebir aynı sözleşme** (üç köprü birbirinin yerine geçebilir) | mailbox_lib + worker_registry ortak çekirdek |

## Tool Setleri (sandbox enum'ları)

```python
SANDBOX_READ_ONLY         = "read-only"         # → [read] görevler için
SANDBOX_WORKSPACE_WRITE   = "workspace-write"   # → [write] görevler için (cwd + writableRoots yazılabilir)
APPROVAL_POLICY           = "on-request"        # → server→client approval request gönderir, bridge otomatik accept eder
APPROVAL_DECISION         = "accept"            # v2 ailesi karar string'i
APPROVAL_FALLBACK_TIMEOUT = 30.0                # approval request cevap gelmezse bu kadar sonra accept
TURN_TIMEOUT_DEFAULT      = 600                 # bir turn için bekleme üst sınırı (saniye)
```

`omp`/`pi`'deki tool-allowlist (`READ_ONLY_TOOLS`/`WRITE_TOOLS` virgülle ayrılmış
string) burada **YOK** — Codex'in `sandbox` enum'u OS düzeyinde enforce edildiği
için (bubblewrap/seatbelt) ek bir allowlist şart değil; sadece `thread/start`'ta
doğru sandbox değeri göndermemiz yeterli. `[write]` lane'de sandbox=workspace-write
+ cwd write root sayesinde Codex yalnızca cwd + `writableRoots`'u yazabilir;
`[read]` lane'de sandbox=read-only OS tarafından tamamen engellenir.

## Kullanım

```bash
# Worker'ı arka planda başlat (bir kez, takım/session başına)
nohup /home/melik/.venvs/tools-bank/bin/python3 \
  /home/melik/tools-bank/scripts/codex-teammate.py \
  --team <takım-adı> --name codex-worker --cwd /home/melik/egesut-erp1 \
  --lead-name claude --model codex-cli-default \
  > /tmp/codex-teammate-<takım-adı>.log 2>&1 &
```

> **venv notu:** omp/pi ile aynı gerekçe — bridge kendi `subprocess.run` çağrılarında
> tools-bank venv Python'unu görebilsin diye script başında
> `_tools_bank_bin = "/home/melik/.venvs/tools-bank/bin"` PATH'e ekleniyor.
> Codex binary ayrıca PATH'te olmayabilir (`/home/melik/.npm-global/bin/codex`
> hard-coded fallback); `find_codex_binary()` kendisi çözüyor.

> **Codex binary yoksa:** script `RuntimeError: codex binary bulunamadı` ile
> erken fail (exit code 2). Önce `npm i -g @openai/codex` veya eşdeğeri kur.

Görev gönderimi: native Agent Teams aktifse `SendMessage(to="codex-worker", ...)`;
değilse doğrudan `~/.claude/teams/{takım}/inboxes/codex-worker.json`'a mesaj yaz
(format: `{from, text, summary, timestamp, color, read:false}`).

**Phase 3 registry/heartbeat (2026-07-08):** `codex-teammate.py` artık diğer üç
bridge gibi `~/.claude/teams/{team}/workers.json` dosyasına register/heartbeat yazar.
Başlatma veya uzun görev sırasında durum kontrolü:

```bash
python3 /home/melik/tools-bank/scripts/worker_list.py --team <takım-adı>
python3 /home/melik/tools-bank/scripts/worker_list.py --team <takım-adı> --json
```

Beklenen alanlar: `kind=codex`, `status=idle|running|stopping|dead`,
`current_task_id`, `last_seen`, `expires_at`, `stale/expired`, `write_capable=true`.
Bu CLI read-only'dir; spawn/kill/reap yapmaz. Eski kodla başlatılmış worker registry'de
görünmezse restart sonrası görünür.

**Görev tipi etiketi — omp/pi ile AYNI konvansiyon:** Mesajın başına `[read]` veya
`[write]` yaz, yoksa güvenli taraf `read`.

- `[read] ...` → `sandbox="read-only"`, Codex OS sandbox'ı dosya yazımını engelliyor
- `[write] ...` → `sandbox="workspace-write"`, yalnızca cwd + `writableRoots` yazılabilir;
  ayrıca bridge prompt'un başına şu sistem mesajını enjekte ediyor:
  `"You have full read/write/shell access for this task; make the necessary changes directly, then stop."`
  (read lane'de ise `"You are in read-only mode for this task: inspect and answer, do not edit or write any files, do not run destructive shell commands."`)

`git_commit_lane` write lane'de cwd'de TEK commit atar, sonuç metnine
`[lane-commit: <sha> @ <cwd>]` ekler — lead cherry-pick yapar.

## Approval Flow (Codex'e özgü — diğer köprülerde YOK)

Codex, `approvalPolicy="on-request"` iken **server→client JSON-RPC request** yollar
(FINDINGS.md §5). Bridge bunları otomatik handle eder:

- **v2 ailesi** (yeni): `item/commandExecution/requestApproval`,
  `item/fileChange/requestApproval`, `item/permissions/requestApproval` →
  hepsine `"accept"` döner
- **Legacy** (eski): `execCommandApproval`, `applyPatchApproval` → `"approved"`
  döner (`"approve"` DEĞİL — `ReviewDecision` oneOf'ında sadece `approved` var,
  bu string review sırasında bulunan 5b bug'ıydı, `ceb44a6`'da düzeltildi)
- **Tanımadığımız server request** (`item/tool/requestUserInput`,
  `attestation/generate`, `account/chatgptAuthTokens/refresh`) → `"decline"`
  (turn iptal, server crash etmez)
- **Approval timeout (30 sn)** → bridge otomatik fallback `"accept"` atar

Server request'leri **JSONRPCRequest** (id ile) — cevap **aynı id** ile
`{"id":..., "result":{"decision":"accept"}}` olarak dönülmeli. Birden fazla
approval pipeline paralel olabilir, ID echo kritik.

## MCP Donanımı

Codex'in MCP server'ları `~/.codex/config.toml`'da tanımlı (`codex mcp add`
ile eklenmiş, **2026-07-07 durumu**):

```toml
[mcp_servers.tools-bank]
command = "/home/melik/.venvs/tools-bank/bin/python3"
args = ["/home/melik/tools-bank/mcp_server/server.py", "--stdio"]

[mcp_servers.gitnexus]
command = "gitnexus"
args = ["mcp"]

[mcp_servers.lsp-bridge]
command = "/home/melik/.venvs/tools-bank/bin/python3"
args = ["/home/melik/tools-bank/scripts/goose-lsp-bridge.py", "--stdio"]

[mcp_servers.supabase-demo]
command = "npx"
args = ["-y", "@supabase/mcp-server-supabase@0.8.2",
        "--project-ref=vtzqjmazsvurxdeondmi",
        "--features=database,development,debugging"]
```

**Not:** Codex'in kendi OpenAI rate-limit'i smoke test sırasında sık sık tetikleniyor
(özellikle gpt-5 için) — bu **dış servis kaynaklı geçici bir engel**, bridge
hattında değil. `model="codex-cli-default"` (gpt-5.4-mini) ile çalıştırıldığında
genelde sorun yok; gpt-5 zorlanıyorsa birkaç dakika beklemek veya model'i
`gpt-5-mini`'e indirmek yeterli. Worker hata mesajında `429` / `rate_limit`
geçiyorsa **bridge'i suçlama, OpenAI tarafına bak**.

## goose-master skill'i (Codex → Goose ters yön)

Codex'in **kendisi** de halihazırda çalışan goose-teammate worker'larına görev
gönderebilir — `~/.codex/skills/goose-master/SKILL.md` (goose-worker-p4'ün işi).
Bunun nedeni Codex'in kendi `agent`/`task` alt-ajanı olmaması; Codex tek ajan
olarak çalışıyor ve paralel fan-out'u dışarıya (goose worker'larına) delege ediyor.
Akış:

1. Lead birden fazla teammate başlatır (örn. `omp-worker-A`, `pi-worker-B`, `codex-worker-C`)
2. Codex kendi inbox'ına gelen bir görevi alır, görev karmaşıksa Codex kendi
   `bash` tool'uyla `~/.codex/skills/goose-master/scripts/dispatch.py` çağırır
3. `dispatch.py` hedef worker'ın mailbox'ına `[read]` veya `[write]` etiketli mesaj yazar
4. Worker cevabını aynı mailbox'a yazar, Codex `bash` ile poll edip alır

Bu skill Codex'in kendi ajan yeteneklerine dokunmaz — sadece dosya-IO. Worker
yoksa önce `worker_list.py --team <takım>` + inbox/ps ile gerçekten worker olmadığını
doğrula. Yeni goose teammate gerekiyorsa `goose_start` kullanma — o legacy `goused-api`
(tablet/Termux) sistemidir. Lead/Claude doğrudan
`/home/melik/tools-bank/scripts/goose-teammate.py --team ... --name ...` başlatmalı;
Codex kendi `~/.codex/skills/goose-master/SKILL.md` protokolünü izler.

## Worktree-per-lane (paralel çoklu worker)

`omp-lane.sh` **ajan-agnostik** — sadece `git worktree add`/`worktree remove`
çağırıyor, `omp`/`pi`/`codex` binary'sine hiç bağımlı değil. Sadece
`REPO_DIR="/home/melik/egesut-erp1"` sabiti repoya işaret ediyor; `codex-teammate.py`
için değişiklik gerekmeden kullanılabilir:

```bash
path=$(/home/melik/tools-bank/scripts/omp-lane.sh open codex-lane-A)   # worktree açar, path basar
nohup /home/melik/.venvs/tools-bank/bin/python3 \
  /home/melik/tools-bank/scripts/codex-teammate.py \
  --team <takım> --name codex-worker-A --cwd "$path" --lead-name claude \
  --model codex-cli-default > /tmp/codex-lane-A.log 2>&1 &
# [write] görevi gönder → lane kendi worktree'sinde TEK commit atar (git_commit_lane()),
# sonuç metnine "[lane-commit: <sha> @ <path>]" ekler
git -C /home/melik/egesut-erp1 cherry-pick <sha>   # review + gate sonrası main'e al
/home/melik/tools-bank/scripts/omp-lane.sh close codex-lane-A
```

**tools-bank reposu için (egesut-erp1 dışı):** `omp-lane.sh` `REPO_DIR`'i
sabit tuttuğu için **doğrudan kullanılamaz** — o repoda `git worktree add <path> HEAD`
ile manuel aç, sonra `codex-teammate.py --cwd "$path"` ver, kapatırken de `git
worktree remove --force`. tools-bank için özel bir `tools-bank-lane.sh`
yazılmadı, ihtiyaç hâlâ düşük (tools-bank'ta write lane nadir).

OMP, pi ve codex lane'leri **aynı anda, karışık** çalıştırılabilir (üçü de aynı
mailbox protokolünü konuşuyor, birbirinden habersiz, çakışmıyorlar) — biri
tıkanırsa diğerine görev yönlendir, üçü de aynı `~/.claude/teams/{takım}/`
dizinini paylaşıyor.

## Smoke Test Kanıtı (2026-07-07)

`codex-teammate.py` ayrı bir izole takımda (takım adı codex-smoke-XXX) test
edildi:

- **Initialize handshake:** `codex app-server` başladı, `initialize` isteği
  gönderildi, response beklendi (380 byte). `userAgent="myclient/0.142.5"`,
  `codexHome="/home/melik/.codex"`, `platformFamily="unix"` doğrulandı.
- **thread/start:** minimal (`{}`) → server cwd olarak probe'un çalıştığı
  dizini döndürdü; dolu (`cwd=/tmp, sandbox=workspace-write, approvalPolicy=on-request,
  personality=pragmatic`) → server normalize edip `sandbox={"type":"workspaceWrite",
  "writableRoots":[],"networkAccess":false,...}` döndürdü.
- **Approval flow:** `execCommandApproval` legacy request'i geldi → bridge
  `"approved"` döndü (önce `"approve"` yazılmıştı, ReviewDecision oneOf'ında
  olmadığı için server reddediyordu — `ceb44a6`'da düzeltildi, tekrar test OK).
- **NDJSON framing:** `\n` delimiter doğrulandı, Content-Length yok, 4 ardışık
  mesaj (initialize + initialized + thread/start×2) bağımsız parse oldu.
- **MCP smoke:** `codex mcp add` ile tools-bank/gitnexus/supabase-demo/lsp-bridge
  eklendi, Codex bunları `mcpServer/startupStatus/updated` notification'ıyla
  ready olarak bildirdi. **Ancak** Codex'in kendi OpenAI rate-limit'i (özellikle
  gpt-5 için) birden fazla smoke test'te tetiklendi — bu **dış/dış servis
  kaynaklı**, bridge'de bug yok; `codex-cli-default` (mini) ile çalıştırıldığında
  sorun yok.

Test takımı ve process sonrasında temizlendi — repoda kalıcı iz yok.

## Ne Zaman Codex

| Durum | Karar |
|---|---|
| **OS-level sandbox şart** (dosya yazımı bypass'a karşı koruma) | Codex — bubblewrap/seatbelt, omp/pi'nin allowlist hack'inden daha güçlü |
| **Persistent thread/oturum hafızası gerekli** (önceki turdaki bağlam korunsun) | Codex — `thread/resume` ile aynı cwd'de oturum devam eder, omp/pi her mesajda yeni süreç |
| **MCP server fan-out** (tools-bank + gitnexus + supabase-demo + lsp-bridge paralel) | Codex — dört MCP aynı anda, omp/pi'de extension'larla sınırlı |
| **gpt-5 kalitesi gerekiyor** (kod review, mimari karar) | Codex — MiniMax-M3 yetmediğinde, rate-limit'e dikkat |
| **Çok uzun süren görev + erken kesilme riski** | OMP veya Pi — Codex'te `TURN_TIMEOUT_DEFAULT=600` (10 dk) sonrası turn kesilir, partial output kaybı riski |
| **Lead'ler-arası delege (Codex → Goose)** | Codex kendi `goose-master` skill'i ile — Codex tek ajan, paraleli dışarıya devreder |
| **Yardımcı küçük görev, hız kritik** | OMP veya Pi — Codex persistent peer başlatma maliyeti (~2-3 sn) her mesajda ödense de ilk başlatma daha ağır |

## Bilinen Tuzaklar

### 1. Ana-repo dirty-sweep guard (CRITICAL)

`git_commit_lane` cwd-relative TEK commit atar — **write lane asla ana repoya
commit atmaz**. Lead cherry-pick yapar.omp-teammate.py / pi-teammate.py ile
**aynı implementasyon**, aynı gerekçe: lane worker'ı yanlışlıkla ana repoda
(`/home/melik/egesut-erp1/`) dosya değiştirip dirty bırakırsa, sonraki cherry-pick
çakışır + WIP dosyalar lead'in commit'ini bozar. **worktree-per-lane bunu
doğal olarak engelliyor** — lane kendi `/home/melik/egesut-erp1-lanes/<lane>/`'inde,
ana repoyu hiç görmüyor.

### 2. Legacy approval decision string (FIXED — `ceb44a6`)

İlk implementasyonda `_handle_server_request` legacy `execCommandApproval`
için `"approve"` döndürüyordu. **Review sırasında** Codex'in `ReviewDecision`
oneOf şeması kontrol edildi ve `"approved"` olduğu (fiil değil sıfat) bulundu
— server `"approve"` ile gelen cevabı reddediyor, turn fail ediyordu. 5b
seviyesinde bir bug (collateral değil, gerçek break). `ceb44a6` commit'inde
düzeltildi, regression test eklendi. **Yeni bridge yazarken bu string'i
sakın değiştirme** — Codex şeması katı, başka varyant kabul etmiyor.

### 3. Reader-thread stdin write deadlock (benzer fix, `1f71d86`)

`codex-teammate.py` da aynı **stdin-write-from-reader-thread** tuzağına karşı
yazıldı (Codex reader thread'i stdout okur, stdin'e **ASLA** o thread yazmaz —
pipe deadlock olur, tıpkı goose-lsp-bridge.py'teki `1f71d86` fix'i gibi).
`_send_raw` her zaman caller thread'inden çağrılır. Yeni bridge yazarken
bu desen korunmalı.

### 4. Codex binary PATH'te olmayabilir

`/home/melik/.npm-global/bin/codex` PATH'te değilse `find_codex_binary()`
hard-coded fallback listesini dener. Hâlâ bulamazsa `RuntimeError` + exit 2.
Smoke test'ten önce `which codex` çalıştır, yoksa kurulumu yap.

### 5. OpenAI rate-limit bridge'de değil

Smoke test sırasında `429 / rate_limit_exceeded` hataları **dış servis kaynaklı**,
bridge'de bug yok. `model="codex-cli-default"` (mini) ile çalıştır, sorun
devam ederse birkaç dakika bekle. Worker stderr/log'unda `rate_limit` geçiyorsa
bridge'i suçlama.

### 6. Server-assigned ID echo kritik

Approval request'leri server-assigned int ID taşır (büyük int olabilir). Cevabı
**aynı id** ile döndürmezsen server eşleştiremez, turn timeout olur. Birden fazla
approval pipeline paralel olabilir, ID echo kritik (zaten `_handle_server_request`
doğru yapıyor, ama custom override yazarken bozma).

memory: `project_codex_app_server_bridge`, `project_omp_minimax_bridge`,
`project_pi_minimax_bridge`, `feedback_agent_bridge_prefer_native`,
`feedback_codex_approval_decision_approved`
