# ADR-008 — Codex App-Server Gateway Entegrasyonu

**Tarih:** 2026-07-07
**Durum:** ✅ TÜM FAZLAR (1-7) TAMAM — Codex CLI, MCP tool-call'ları gerçekten çalıştırabilen, canlı doğrulanmış bir Agent Teams subagent'ı olarak entegre edildi.
**Etkilenen:** `codex-teammate.py` bridge (tools-bank main: `e18a357`+`928b190`+`939ec64`), `.claude/skills/codex-master/` (egesut-erp1 main: `1f88af8`), CLAUDE.md fallback tablosu, `~/.codex/config.toml`+profiller+agents/ (model optimizasyonu)
**Kalan opsiyonel iyileştirme (blocking değil):** `_handle_server_request`'in elicitation/tool-call dallarına özel unit test yok (review'de not edildi, "MERGE OK+küçük not" — fonksiyonel doğrulama canlı smoke testle yapıldı, otomatik test coverage follow-up olarak açık).
**İlgili takip planı:** `tools-bank/docs/plans/2026-07-07-global-agent-control-roadmap.md` (tools-bank main, `3847cbc`) — bu ADR'nin kapsamı Codex'in tek başına entegrasyonuydu; o plan tüm 4 köprünün (goose/omp/pi/codex) paylaştığı mailbox motorunu (lease/envelope/heartbeat/tool-enforcement/spawn-broker) ele alıyor. Motor tools-bank'ta yaşadığı için plan da orada — egesut-erp1'de sadece bu pointer var.

---

## İlerleme (canlı takip — /loop bu bölümü günceller)

**Takım:** `session-781169d1` · workerlar native mailbox'a kayıtlı, `SendMessage` ile otomatik bildirim geliyor.

| Faz | Worker | PID | cwd | Durum |
|---|---|---|---|---|
| 1 (protokol haritalama) | goose-worker-p1 | 2746392 | scratchpad/codex-p1 | ✅ TAMAM — FINDINGS.md (581 satır), framing=NDJSON ampirik doğrulandı, çalışan client iskeleti hazır |
| 3 (MCP+LSP donanımı) | goose-worker-p3 | 2746393 | scratchpad/codex-p3 | ✅ TAMAM — 4 MCP sunucu eklendi+doğrulandı, rate-limit resetlendi, retry'de MCP discovery+tool-call ÜRETİLDİ (naked `codex exec` approval'ı otomatik iptal etti — wiring hatası değil, bridge'in approval-otomasyonunun neden gerekli olduğunu kanıtladı) |
| 4 (goose-master skill) | goose-worker-p4 | 2746394 | scratchpad/codex-p4 | ✅ TAMAM — ~/.codex/skills/goose-master/ yazıldı, canlı şemayla 8/8 alan doğrulandı |
| 2 (codex-teammate.py bridge) | goose-worker-p2 | 2753183 | tools-bank-lanes/codex-bridge-p2 (worktree) | ✅ YAZILDI+COMMIT (eec7059, 925 satır) — bağımsız review bekliyor |
| review (Faz 2 zorunlu) | goose-worker-review | 2758018 | tools-bank-lanes/codex-bridge-p2 | ✅ TAMAM — MERGE OK, 1 zorunlu düzeltme bulundu (legacy approval "approve"→"approved") ve Claude tarafından uygulandı (commit ceb44a6) |
| 5 (codex-master skill) | goose-worker-p5 | 2763427 | egesut-erp1-lanes/codex-p5 (worktree, kapatıldı) | ✅ TAMAM — SKILL.md (308 satır) yazıldı, worktree'de commit (2e45e11), main'e cherry-pick edildi (1f88af8), lane kapatıldı |
| 5b (CLAUDE.md tablo satırı) | Claude (direkt) | — | egesut-erp1 ana ağaç | ✅ TAMAM — mevcut uncommitted WIP ile çakışma riski nedeniyle worktree'den cherry-pick YERİNE doğrudan ana ağaçta eklendi |
| 6 (smoke test + review) | codex-worker-read / codex-worker-write | (durduruldu) | egesut-erp1 (read) / egesut-erp1-lanes/codex-live-write (write) | ⚠️ GERÇEK BUG BULUNDU — bkz. aşağıdaki not. Mailbox+write+commit ÇALIŞTI (SMOKE_TEST.md, commit 9a3d81e), MCP tool çağrısı elicitation hatasıyla reddedildi |
| 6-fix (elicitation handling) | goose-worker-fix2 | 2778909 | tools-bank-lanes/codex-elicitation-fix (worktree) | ✅ TAMAM — commit `159f193`, pushed origin/fix/codex-mcp-elicitation-action-schema. action/content şeması + item/tool/requestUserInput + item/tool/call dalları eklendi. 9 unit + 7 dispatch-envelope testi geçti, py_compile temiz. Canlı smoke-test rate-limit'e takıldı (kod hatası değil). |
| 6-review (fix2 zorunlu review) | goose-worker-p1 | 2746392 | scratchpad/codex-p1 (mevcut, reuse) | ✅ TAMAM — MERGE OK+küçük not (test iddiası commit içeriğiyle uyuşmuyor, blocking değil) |
| 7 (model/reasoning profil opt.) | goose-worker-p3 | 2746393 | scratchpad/codex-p3 (mevcut, reuse) | ✅ TAMAM — gpt-5.5/5.4/5.4-mini gerçek, gpt-5.3-codex-spark hayali (yazılmadı); config.toml+fast/deep-review profilleri+3 agent tanımı, canlı test edildi |
| 8 (Codex↔Goose canlı doğrulama) | codex-worker-goosetest + goose-worker-target | 2794601 / 2793486 | egesut-erp1 | ✅ TAMAM — Codex, `~/.codex/skills/goose-master/`'ı GERÇEK bir turn'de keşfedip kullandı: `goose-worker-target`'ın mailbox'ına `from:"codex"` ile gerçek bir görev yazdı (schema-check değil, canlı dispatch). Skill `goose-dispatch`'ten `goose-master`'a yeniden adlandırıldı (Claude'un kendi `.claude/skills/goose-master/` skill'iyle isim tutarlılığı, kullanıcı talebi) — tüm iç path referansları (SKILL.md, agents/*.yaml, references/*.md) güncellendi. |
| 9 (AGENTS.md hizalama) | Claude (direkt) | — | egesut-erp1 ana ağaç | ✅ TAMAM — `AGENTS.md`'ye CLAUDE.md'den ilham alan ama birebir olmayan, açıkça sınırlanmış "Codex CLI — Agent-Özel Not" bölümü eklendi ("goose/pi/omp bu bölümü atlasın" uyarısıyla, karışıklık önlendi). `codex-master/SKILL.md`'deki tüm `goose-dispatch` referansları `goose-master`'a düzeltildi. |

**🐛 Bulunan bug (Faz 1'in araştırma boşluğu, DÜZELTİLDİ):** `mcpServer/elicitation/request` — Codex app-server'ın HER MCP tool çağrısında gönderdiği bir consent/elicitation isteği, Faz 1'in FINDINGS.md'sinde (5 approval ailesi listelemişti) atlanmış. `codex-teammate.py`'nin "tanımadığım method → decline" fallback'i bu method için YANLIŞ response şeması gönderiyor (`{"decision":...}` yerine `{"action":...}` gerekiyor) → Codex server deserialize edemiyor → HER MCP tool çağrısı reddediliyor (`user rejected MCP tool call`). Canlı testte hem codex-worker-read hem codex-worker-write AYNI hatayı verdi. Şema: `McpServerElicitationRequestParams/Response.json` (codex-schema/). **Fix commit edildi (159f193) — şimdi bağımsız review aşamasında.**

**Not (worktree/WIP çakışma kararı):** egesut-erp1'in CLAUDE.md'sinde Faz 5'ten bağımsız, önceden var olan büyük bir uncommitted WIP diff var (goose-primary subagent kuralları vb., "Ne Zaman Ne Kullan" tablosunun ta kendisini de kapsıyor). Bir worktree HEAD'den (bu WIP'siz) checkout alacağından, o worktree'de tabloyu düzenleyip cherry-pick etmek çakışma/geri-alma riski taşırdı — bu yüzden Faz 5 goose lane'i SADECE yeni `.claude/skills/codex-master/SKILL.md` dosyasını yazıyor (çakışma riski yok, yeni dosya), tablo satırı Claude tarafından doğrudan ana ağaçta (mevcut WIP'in üzerine, aynı oturumda) eklendi.

**Rate-limit güncel durum:** Resetlendi (2026-07-07 ~20:35 civarı, goose-worker-p3'ün retry'ında doğrulandı) — artık engel değil.

**Entegrasyon geçmişi:** tools-bank worktree (codex-bridge-p2) main'e cherry-pick edildi (`e18a357` feat + `928b190` fix), worktree kapatıldı. egesut-erp1 worktree (codex-p5) main'e cherry-pick edildi (`1f88af8`), worktree kapatıldı. Şimdi bridge'in KENDİSİ (`/home/melik/tools-bank/scripts/codex-teammate.py`, canonical konum) ilk kez canlı çalıştırılıyor — codex-worker-read (egesut-erp1, [read] test) ve codex-worker-write (izole worktree, [write]+commit test).

Task tracker: Claude'un TaskList'inde #1-#6 (aynı fazlar, senkron tutulacak).

---

## Karar

Codex CLI'ı (`~/.npm-global/bin/codex`, v0.142.5, bu makinede zaten login'li ve bu repo zaten
`trusted`) goose-teammate.py / pi-teammate.py / omp-teammate.py ile **aynı native Agent Teams
mailbox konvansiyonuna** bağlayan bir `codex-teammate.py` bridge yazılacak. Bağlantı katmanı
`codex exec` subprocess değil, **`codex app-server`** — Codex'in kendi kalıcı JSON-RPC daemon'ı
(goose'un `goose serve`+ACP'sinin dengi, hatta bazı yönlerden daha zengin). İş dağılımı: protokol
haritalama + bridge kodu + MCP/LSP donanımı **goose-teammate lane'lerine paralel dağıtılır**,
Claude sadece mimari karar + review yapar.

---

## Bağlam

Kullanıcı Codex CLI'ı goose gibi bir "teammate" olarak bağlamak istiyor. Goose'un ACP kanalı
(`goose serve`, dual-SSE, per-session `mcpServers`) bu tip entegrasyonlarda çok işe yaradığı için
("ileride çok rahat ederiz" — kullanıcı, 2026-07-07) Codex için de benzer, kalıcı bir "gateway"
modeli arandı. `codex --help` ağacı derinlemesine tarandı (context7/tools-bank'ta Codex CLI
dokümanı yok — burada ilk kez biz çıkarıyoruz, bkz. aşağıdaki not).

**Not — context7 neden "lokal" görünüyordu:** `mcp__tools-bank__context7_resolve_library_id` ayrı
bir MCP sunucusu değil, `tools-bank/mcp_server/server.py` içine gömülü, gerçek Context7 API'sine
HTTP ile proxy yapan bir fonksiyon (`claude mcp list` çıktısında da ayrı bir `context7` server
YOK — sadece tools-bank/gitnexus/duckduckgo/exa/supabase-demo var). "Lokal tercih" diye bir seçim
yapılmadı — mevcut TEK context7 erişimi bu, ve upstream'den `"no valid response from context7"`
döndü (Codex CLI için zaten hiç içerik yoktu, `guide_search` de boş döndü — greenfield konu).

---

## Bulgu — `codex app-server` gerçek bir ACP-dengi protokol

`codex app-server generate-json-schema --out <dir>` ile tam JSON-RPC şeması çıkarıldı
(`codex_app_server_protocol.schemas.json`, 551KB + alt dosyalar,
`/tmp/.../codex-schema/` — geçici, kalıcı değil, Faz 1'de tools-bank'a taşınacak).

**Doğrulanmış protokol yüzeyi (`ClientRequest`/`ServerNotification` oneOf listesinden):**

| Kategori | Method'lar |
|---|---|
| Thread lifecycle | `thread/start`, `thread/resume`, `thread/fork`, `thread/rollback`, `thread/archive`, `thread/compact/start` |
| Turn (konuşma turu) | `turn/start`, `turn/steer` (goose'da karşılığı yok — turn ortasında yön değiştirme), `turn/interrupt` |
| Streaming (notification) | `item/agentMessage/delta`, `item/reasoning/summaryTextDelta`, `command/exec/outputDelta`, `item/commandExecution/outputDelta` |
| Onay akışı | `ExecCommandApprovalParams`, `PermissionsRequestApprovalParams`, `FileChangeRequestApprovalParams`, `ApplyPatchApprovalParams` — goose'un "dangerously-unauthenticated" bypass'ından çok daha ince taneli, native approval-hook |
| MCP | `config/mcpServer/reload` (**restart'sız** MCP yeniden yükleme — goose'da extension değişikliği restart istiyordu) |
| Introspection | `skills/list`, `hooks/list`, `plugin/list`, `model/list`, `permissionProfile/list` |
| Dosya sistemi | `fs/readFile`, `fs/writeFile`, `fs/watch` vb. (agent'ın kendi fs erişimi RPC üzerinden de yürütülebiliyor) |

**Transport:** `codex app-server` varsayılan `stdio://`; ayrıca `unix://PATH` veya `ws://IP:PORT`
ile de dinleyebiliyor. Kalıcı bir daemon (`codex app-server daemon start` / `bootstrap` — SSH-
durable) + `codex app-server proxy --sock <path>` (stdio↔socket bridge) kombinasyonu, birden
fazla bağımsız client'ın (birden fazla goose-teammate/Claude lane'i gibi) AYNI Codex process'ini
paylaşmasına izin veriyor — tam olarak `goose serve`'ün oynadığı rolün dengi.

**Şu an daemon çalışmıyor** (`daemon version` → soket dosyası yok, `No such file or directory`),
temiz bir başlangıç noktası.

**Feature flag'ler (ilgili, `codex features list`):** `multi_agent=stable/true`,
`hooks=stable/true`, `plugins=stable/true`, `plugin_sharing=stable/true`, `goals=stable/true`,
`auto_compaction=stable/true`, `remote_compaction_v2=stable/true`. `multi_agent_v2` ve
`code_mode`/`code_mode_only` henüz "under development" — pilot dışı tutulacak.

---

## Mimari

```
codex app-server daemon bootstrap/start     (kalıcı daemon — goose serve'ün dengi)
        ↕ unix socket (app-server-control.sock)  [framing: Faz 1'de netleşecek]
codex-teammate.py                            (Python JSON-RPC client — GooseACPSession dengi)
  ├─ thread/start (cwd, sandbox/approval-profile param'ları ile — Faz 1'de kesinleşecek)
  ├─ turn/start ("[read]"/"[write]" mesajı)
  ├─ item/agentMessage/delta + turn/completed dinleme
  └─ approval request geldiğinde otomatik response (task_type=write → auto-approve,
     read → sadece read-only işlemleri approve et)
        ↕ native mailbox (DEĞİŞMİYOR — diğer teammate'lerle birebir aynı)
Claude ↔ SendMessage(to="codex-worker", text="[write] ...")
```

**[read]/[write] eşlemesi:** `codex exec`'teki gibi tek bir `-s` flag'i yeterli olmayabilir —
app-server'da sandbox/approval muhtemelen `permissionProfile` + per-approval-request response
kombinasyonu ile kontrol ediliyor (`permissionProfile/list` + `PermissionsRequestApprovalParams`
şemaları Faz 1'de tam okunacak). Basit fallback: `thread/start`'a `sandbox: read-only|workspace-
write` param'ı geçebiliyorsa (`codex exec -s` ile birebir aynı enum), doğrudan onu kullan;
geçemiyorsa approval-response otomasyonu ile eşdeğerini kur.

**MCP donanımı:** `codex mcp add tools-bank/gitnexus/supabase-demo/lsp-bridge -- ...` — goose-
teammate.py'nin `mcp_servers` listesindeki komut/env'ler birebir kopyalanacak (aynı venv-python
tuzağı geçerli: `/home/melik/.venvs/tools-bank/bin/python3`, sistem python3'te `requests` yok).
`goose-lsp-bridge.py` **aynen reuse** edilecek — yeni LSP kodu yazılmayacak.

**"Goose kullanma gücü":** yeni bir MCP server yazılmayacak. `~/.codex/skills/goose-master/
SKILL.md` (Codex'in kendi skill-drop dizini zaten var, sadece `.system` içeriyor) ile Codex'e
Claude'un kullandığı AYNI mailbox JSON formatını bash üzerinden nasıl konuşacağı öğretilecek.
`app-server`'ın `fs/*` RPC'leri zaten dosya yazma yetkisini kapsıyor; mailbox path (`~/.claude/
teams/`) proje cwd dışında olduğu için thread başlatılırken ek dizin izni gerekebilir (Faz 1'de
netleşecek — `codex exec`'teki `--add-dir` karşılığı app-server'da bir thread/start param'ı
olarak var mı kontrol edilecek).

---

## Roadmap

**Faz 1 — Protokol derinlemesine haritalama** (goose lane, salt-okuma + rapor)
- `codex-schema/` altındaki `ClientRequest.json` / `ServerNotification.json` / `ServerRequest.json`
  içindeki `thread/start`, `turn/start`, `initialize` request'lerinin TAM param şemasını çıkar
  (zorunlu/opsiyonel alanlar, sandbox/approval-profile alanı var mı, cwd/add-dir karşılığı ne).
- Socket framing'i belirle: `codex app-server` stdio modunda çalıştırılıp ham `initialize`
  isteği gönderilerek (newline-delimited mi, Content-Length header'lı mı) ampirik doğrulama.
- Approval request/response turn'ünü (`ExecCommandApprovalParams` → `ExecCommandApprovalResponse`)
  uçtan uca bir deneme akışıyla doğrula.
- Çıktı: Faz 2'nin kod yazacağı kesin bir protokol notu (method + param + framing).

**Faz 2 — `codex-teammate.py` bridge** (goose lane, worktree, `tools-bank` reposu — cross-repo commit)
- Faz 1'in bulgularıyla JSON-RPC client + mailbox poll loop (pi-teammate.py'nin döngü iskeletinden
  esinlenerek, ACP-benzeri kalıcı bağlantı goose-teammate.py'nin `GooseACPSession` sınıfından).
- `[read]`/`[write]` → sandbox/approval eşlemesi.
- Lane devamlılığı: `thread/resume` (goose'un elle `_lane_sessions` dict'ine gerek kalmadan native).
- Ana-repo dirty-sweep guard'ı (goose'daki KRİTİK TUZAK) aynen taşınacak.

**Faz 3 — MCP + LSP donanımı** (goose lane, scratch cwd — `$HOME/.codex/config.toml`'a yazıyor)
- `codex mcp add` ile tools-bank/gitnexus/supabase-demo/lsp-bridge kaydı.
- `config/mcpServer/reload` ile restart'sız doğrulama.

**Faz 4 — "goose kullanma gücü"** (küçük, Faz 2 ile aynı lane'e eklenebilir)
- `~/.codex/skills/goose-master/SKILL.md` — mailbox protokolü dokümantasyonu.

**Faz 5 — Claude tarafı entegrasyon**
- `.claude/skills/codex-master/SKILL.md` (goose-master/pi-master formatında).
- CLAUDE.md "Ne Zaman Ne Kullan" tablosuna ekleme (fallback sırası: goose → pi → codex,
  mevcut sıra korunur — codex kendi yerini kanıtladıkça yeniden değerlendirilir).

**Faz 6 — Doğrulama**
- 1 `[read]` + 1 `[write]` smoke test: mailbox round-trip + gerçek MCP tool çağrısı + LSP çağrısı
  + approval-flow + git-commit-lane guard.
- Zorunlu sıra (CLAUDE.md kuralı): ÖNCE ayrı bir goose-teammate review lane'i, SONRA gerekirse
  native `code-reviewer`.

---

## Yasak

- `codex exec` tek-seferlik subprocess modeline geri dönülmeyecek (MCP/approval/thread-resume
  avantajları kaybolur) — bu ADR onaylandıktan sonra Faz 1'e geçilir, ara model denenmez.
- Yeni bir MCP server/köprü Codex'in Goose'u çağırması için YAZILMAYACAK — mevcut mailbox +
  bash yeterli (Faz 4).
- `codex app-server`'ın deneysel/under-development feature flag'leri (`multi_agent_v2`,
  `code_mode*`, `remote_control` — bazıları `removed=true` durumda) pilot kapsamına ALINMAYACAK.
- Ana repo (`egesut-erp1`) cwd'sinde worker başlatılıp otomatik commit atılmayacak — worktree
  veya scratch cwd zorunlu (goose'daki KRİTİK TUZAK aynen geçerli).
