---
name: pi-master
description: Use when delegating work to pi (Earendil Works pi-coding-agent, MiniMax-M3) as a Claude Code Agent Teams subagent via the native mailbox bridge — pi-teammate.py. Triggered by "pi'ye ver", "pi ile yap", "pi subagent", "pi worker başlat", or when OMP/omp-teammate.py is erroring/stuck and needs a fallback. Covers CLI flag differences from omp-teammate.py, tool-name mapping, task-type ([read]/[write]) conventions, and worktree-per-lane usage.
---

# pi-master — pi (MiniMax-M3) Subagent Köprüsü

> **Bağlam (2026-07-06):** OMP/MiniMax köprüsü (`omp-teammate.py`) kullanıcı tarafından
> güvenilmez bulundu ("sürekli hata veriyor"). Bu skill, **aynı native mailbox protokolünü**
> konuşan ama `pi` (Earendil Works pi-coding-agent) çalıştıran bir alternatif/yedek köprüyü
> belgeliyor: `/home/melik/tools-bank/scripts/pi-teammate.py`. OMP tıkanırsa/hata verirse
> önce buna geç — OMP'yi debug etmeye zaman harcama, ikisi paralel de çalıştırılabilir.

## Ne

Claude Code'un native Agent Teams dosya-tabanlı mailbox protokolünü (MCP değil —
`~/.claude/teams/{team}/config.json` + `inboxes/{name}.json`, lockfile'lı) doğrudan
konuşan bir adapter. `pi`'yi (MiniMax-M3, bu makinede zaten `~/.pi/agent/auth.json` +
`settings.json` ile yapılandırılı: `defaultProvider=minimax`, `defaultModel=MiniMax-M3`)
gerçek bir teammate gibi sokuyor. `omp-teammate.py` ile **aynı protokol, aynı [read]/[write]
konvansiyonu, aynı worktree-per-lane modeli** — sadece alt süreç `omp` yerine `pi` çalıştırıyor.

**Neden ayrı script, "omp"→"pi" string-replace DEĞİL:** pi'nin CLI yüzeyi omp'ninkiyle isim
olarak örtüşüyor (`-p`, `--mode`, `--model`, `--tools`, `--thinking` hepsi var) ama flag
semantiği farklı — canlı testle (2026-07-06) doğrulanan farklar aşağıda.

## KRİTİK FARKLAR (omp-teammate.py'a göre — hepsi canlı test edildi)

| Konu | omp-teammate.py | pi-teammate.py | Kanıt |
|---|---|---|---|
| Flag sözdizimi | `--flag=value` çalışır | **`--flag=value` PATLAR** ("Unknown options") — sadece `--flag value` (ayrı arg) | Doğrudan `pi --mode=json ...` denendi, hata; `pi --mode json ...` çalıştı |
| cwd | `--cwd=` flag'i var | **flag YOK** — `subprocess.run(cwd=...)` ile veriliyor | `pi --help` çıktısında `--cwd` yok |
| Zaman sınırı | `--max-time=` flag'i var (zayıf da olsa) | **flag YOK, pi'de hiç dahili wall-clock kesme yok** — TEK kesme dış Python `timeout=` | `pi --help`'te yok; donan çağrı sadece SIGKILL ile kesilir, partial output kaybı riski omp'den YÜKSEK |
| Onay atlama | `--auto-approve --approval-mode=yolo` gerekli | **hiçbiri yok/gerekmiyor** — `-p` modda `--tools` allowlist'indeki bash/edit/write onaysız direkt çalışır | Git bile olmayan güvensiz bir `/tmp` dizininde test edildi: bash + write tool onay istemeden çalıştı, dosya gerçekten yazıldı |
| `--no-title` | var | yok/gerekmiyor | — |
| `--no-session` | karşılığı yok | pi'ye özel, session dosyası biriktirmesin diye eklendi | Test: session sayısı çağrı öncesi/sonrası aynı kaldı |
| Tool adları | `read,grep,glob,lsp,python,notebook,web_search,todo` | builtin SADECE `read,bash,edit,write,grep,find,ls` (glob yerine **find**; lsp/python/notebook/todo builtin DEĞİL). Bu makinede ek `web_search`/`web_fetch` (rpiv-web-tools extension) kurulu | `dist/core/tools/` dizini listelendi + `rpiv-web-tools` README'si okundu |
| Subagent fan-out | `task` tool kapalı (2026-07-05 audit'te asılı kalmıştı) | `pi-subagents` extension'ının `Agent`/`get_subagent_result`/`steer_subagent` tool'u AYNI sebeple kapalı tutuluyor (henüz test edilmedi, önlem amaçlı) | `@tintinweb/pi-subagents` README'si |
| agent_end JSON yapısı | `messages[].content[]` → text/thinking/toolCall | **aynı yapı** — `_extract_final_text`/`_clean_think` değişmeden taşındı | agent_end event'i karşılaştırıldı |
| `--model` formatı | `minimax/MiniMax-M3` | **aynı format çalışıyor** | Canlı testte `"provider":"minimax","model":"MiniMax-M3"` çıktısı doğrulandı |
| `--thinking` seviyeleri | low/medium/high | aynı isimler + ek olarak off/minimal/xhigh de var | `pi --help` |

## Tool Setleri (script içinde sabit)

```python
READ_ONLY_TOOLS = "read,grep,find,ls,web_search,web_fetch"
WRITE_TOOLS = "read,bash,edit,write,grep,find,ls,web_search,web_fetch"
```

`Agent`/`get_subagent_result`/`steer_subagent` (pi-subagents) HİÇBİR lane'de allowlist'e
konmuyor — OMP'nin kendi `task` tool'unun asılı kalması (2026-07-05 fullstack audit) ile aynı
risk sınıfı, paralelleştirme BİZİM orkestrasyon katmanımızda (birden fazla `pi-teammate.py`
lane'i) yapılıyor, pi'nin kendi fan-out'una hiç izin verilmiyor.

## Kullanım

```bash
# Worker'ı arka planda başlat (bir kez, takım/session başına)
nohup python3 /home/melik/tools-bank/scripts/pi-teammate.py \
  --team <takım-adı> --name pi-worker --cwd /home/melik/egesut-erp1 \
  --lead-name claude --model minimax/MiniMax-M3 \
  > /tmp/pi-teammate-<takım-adı>.log 2>&1 &
```

Görev gönderimi: native Agent Teams aktifse `SendMessage(to="pi-worker", ...)`; değilse
doğrudan `~/.claude/teams/{takım}/inboxes/pi-worker.json`'a mesaj yaz (format:
`{from, text, summary, timestamp, color, read:false}`).

**Görev tipi etiketi — omp-teammate.py ile AYNI konvansiyon:** Mesajın başına `[read]` veya
`[write]` yaz, yoksa güvenli taraf `read`.
- `[read]` → `READ_ONLY_TOOLS`, `--thinking low` (varsayılan, `--thinking-read` ile değişir)
- `[write]` → `WRITE_TOOLS`, `--thinking high` (varsayılan, `--thinking-write` ile değişir)

## Worktree-per-lane (paralel çoklu worker)

`omp-lane.sh` **ajan-agnostik** — sadece git worktree açıp/kapatıyor, `omp` binary'sine hiç
bağımlı değil. Değişiklik yapmadan `pi-teammate.py` ile de kullanılabilir:

```bash
path=$(/home/melik/tools-bank/scripts/omp-lane.sh open lane-A)   # worktree açar, path basar
nohup python3 /home/melik/tools-bank/scripts/pi-teammate.py \
  --team <takım> --name pi-worker-A --cwd "$path" --lead-name claude \
  --model minimax/MiniMax-M3 > /tmp/pi-lane-A.log 2>&1 &
# [write] görevi gönder → lane kendi worktree'sinde TEK commit atar (git_commit_lane()),
# sonuç metnine "[lane-commit: <sha> @ <path>]" ekler
git -C /home/melik/egesut-erp1 cherry-pick <sha>   # review + gate sonrası main'e al
/home/melik/tools-bank/scripts/omp-lane.sh close lane-A
```

OMP ve pi lane'leri **aynı anda, karışık** çalıştırılabilir (ikisi de aynı mailbox protokolünü
konuşuyor, birbirinden habersiz, çakışmıyorlar) — biri tıkanırsa diğerine görev yönlendir.

## Smoke Test Kanıtı (2026-07-06)

İzole bir test takımında worker başlatıldı, inbox'a `[read] bash ile 'ls migrations | wc -l'
çalıştır` mesajı yazıldı → worker doğru `cwd`'de çalıştı, top-level `migrations/` dizininin
olmadığını fark edip `supabase/migrations/` altına yöneldi (kendi düzeltti), `bash` tool'u
allowlist'te olmadığı için hiç denemedi, sadece izinli `ls` tool'unu kullandı, tüm dizin
girdilerini (219 .sql + ground_truth.sql + `.github/` + `backup/` = 220) şeffaf bir açıklamayla
raporladı, `idle_notification` mailbox'a native formatta yazıldı. Test takımı ve process
sonrasında temizlendi — repoda kalıcı iz yok.

## Ne Zaman OMP Yerine Pi

| Durum | Karar |
|---|---|
| OMP hata veriyor / boş cevap dönüyor / takılıyor | Pi'ye geç, OMP'yi debug etmeye zaman harcama |
| Uzun süren, çok araç-çağrılı görev | Pi tercih et — dahili zaman sınırı olmadığından uzun görevlerde erken kesilmiyor (ama dış timeout'u cömert tut, aşağıya bak) |
| web_search/web_fetch gerekiyor | Pi'de extension olarak hazır kurulu (rpiv-web-tools); omp'de karşılığı ayrı doğrulanmalı |
| Paralel çoklu lane | İkisi de aynı worktree-per-lane modelini destekliyor — karışık kullanılabilir |

## Bilinen Risk

Pi'de OMP'deki gibi bile olsa bir iç zaman-aşımı güvenlik ağı YOK. `--max-time` argümanı
SADECE Python-tarafı `subprocess.run(timeout=...)` içindir, pi'ye hiç iletilmez. Donan bir
çağrı SIGKILL ile kesilir, kısmi çıktı kaybı riski OMP'den daha yüksek. `--max-time`'ı cömert
tut (`feedback_omp_no_time_limit` dersi burada da geçerli — kısa süre iş yarıda keser).

memory: `project_pi_minimax_bridge`, `project_omp_minimax_bridge`, `feedback_agent_bridge_prefer_native`
