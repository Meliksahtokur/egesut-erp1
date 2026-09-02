# Idle Raporu — ci-saglamlastirma: E2E CI hattına demo-pause dayanıklılığı

**Tarih:** 2026-09-02 · **Worktree:** `/home/melik/egesut-wt/ci-saglamlastirma` (branch `idle/ci-saglamlastirma`, taban main `a71b7a0`)
**Kaynak:** e2e-gercek raporu §4 (`.claude/idle-reports/2026-09-02-e2e-gercek.md`) · **Kapsam:** yalnız `.github/workflows/test.yml` (+ bu rapor)

## Amaç

2026-09-01'de demo Supabase projesi free-tier pause'a girdi (DNS NXDOMAIN) → demo-mode CI koşumları açılışta asılı kaldı. Ayrıca paralel worker demo free-tier'ı vurdu (run1: 23 fail); `--workers=1` kararlı (final 64/0/3). Bu görev, CI'yı her iki risk karşısında dayanıklı hale getirir.

## Değişiklik özeti

**Tek dosya:** `.github/workflows/test.yml` — `git diff --stat`: **97 ekleme / 0 silme** (saf ekleme; mevcut 3 shard job'ı, smoke job'ı, trigger'lar, concurrency bloğu ve tüm mevcut adımlar bayt-bayt korundu).

Yeni job: `demo-e2e` ("E2E Demo (health-gated, stub fallback)"), smoke-test'ten önce eklenir:

| # | Adım | Davranış |
|---|---|---|
| 1 | `Demo health check` (id: demo) | `curl -s -o /dev/null -w '%{http_code}' --max-time 10` → `https://vtzqjmazsvurxdeondmi.supabase.co/rest/v1/`; 3 deneme (000'da 5 sn arayla); sonuç `code` + `status` olarak `GITHUB_OUTPUT`'a yazılır. **status sözlüğü:** `2xx`→`ok` (key ile doğrulanmış) · `000`→`down` (pause/NXDOMAIN; curl ağ hatası dahil) · diğer HTTP (key'siz `401` dahil)→`alive` (DNS+gateway ayakta, pause değil). |
| 2 | `Run E2E (demo gerçek backend)` | `if: status != 'down'` → `PLAYWRIGHT_DEMO_MODE: '1'` + `--workers=1` **TEK job, shard YOK** (free-tier paralel yük kaldırmıyor — run1 kanıtı: paralel=23 fail, serial=64/0/3). |
| 3 | `Run E2E (stub fallback)` | `if: status == 'down'` → `PLAYWRIGHT_DEMO_MODE: '1'` + `PLAYWRIGHT_STUB_BACKEND: '1'` + `--workers=1`. Spec kodu aynı; stub modda DB-bağımlı e2e.spec testleri (2.01/2.03/3.02) kendiliğinden skip olur (`tests/support/stub-backend.js`). |
| 4 | Artifact upload'ları | Shard job'larındaki pattern ile aynı (`playwright-report-e2e-demo`, `playwright-trace-e2e-demo`). |

Korunanlar: `smoke-test` job demosuz prod (GH Pages baseURL) koşusuna devam eder — **dokunulmadı**; `test-shard1/2/3` demosuz prod koşumları da aynen korundu ("mevcut yapıyı koru, ekle" talimatı); `PLAYWRIGHT_BASE_URL` set edilmediği için demo/stub koşumları da prod GH Pages baseURL kullanır (webServer bloğu devreye girmez).

## Secret eksiği — KULLANICI ADIMI

**`DEMO_ANON_KEY` secret'ı repoda tanımlı DEĞİL** (workflow yazım anında doğrulandı). Key **koda gömülmedi** (guardrail gereği); health check iki dallı tasarlandı:

- **Secret yoksa (bugünkü durum):** curl key'siz atılır. Supabase gateway, proje ayaktayken `401` döner → `status=alive` → **demo gerçek koşum seçilir** (doğru davranış: 401 bile pause olmadığını kanıtlar; testler kendi kredansiyelini `js/api.js` DEMO_LOGIN'den alır, workflow key'ine bağımlı değildir). Proje paused ise DNS çözülmez → `000` → `down` → stub fallback. Step ayrıca `::warning::` basar.
- **Secret eklenirse:** `-H "apikey: $DEMO_ANON_KEY"` ile `2xx` doğrulanır → `status=ok` (tam doğrulama).
- **Kullanıcı şunu eklemeli:** GitHub → Settings → Secrets and variables → Actions → `DEMO_ANON_KEY` = demo projesi (`vtzqjmazsvurxdeondmi`) anon key (demo.supa.demo hesabında; kodda zaten public-by-design ama guardrail gereği workflow'a gömülmedi). Bu bir **blocker değil** — eklenmese de pause-dayanıklılık tam çalışır.

Sağlamlık notu: Health step'i çıktısız kalırsa (teorik, `|| true` + fallback zinciriyle pratikte imkânsız) `status` boş olur → `!= 'down'` doğru değerlendiğinden demo koşumu seçilir; 000 tespiti her koşulda stub'a düşürür.

## Doğrulama kanıtı

1. **actionlint (docker, resim `rhysd/actionlint:latest`):**
   ```
   $ docker run --rm -v /tmp/al-probe:/work --workdir /work rhysd/actionlint:latest -color
   (çıktı boş)  actionlint EXIT=0
   ```
   (İlk deneme worktree mount'unda `.git` gitdir-link olduğu için "no project found" verdi; geçici `git init` repo'suna dosya kopyalanıp aynı imajla doğrulandı. Ayrıca shellcheck'i de kapsayan actionlint hatasız.)
2. **python yaml.safe_load:** `YAML OK — jobs: ['test-shard1', 'test-shard2', 'test-shard3', 'demo-e2e', 'smoke-test']`
3. **Diff ile "diğer adımlar bozulmadı":** `git diff -U0` → **0 silinen satır**; `smoke-test` ve shard job'ları diff'te yalnız bağlam (context) satırı olarak görünür.
4. **Yerel koşum yok** — actionlint/yaml dışında CI simülasyonu yapılmadı (Supabase çağrısı YASAK; pause-dayanıklılığın canlı kanıtı ancak gerçek pause senaryosunda alınabilir).

## Öneri (uygulanmadı — kullanıcı kararı): haftalık scheduled demo-health

Pause, CI push'unu beklemeden erken görülsün diye opsiyonel job (test.yml'ye eklenebilir):

```yaml
  demo-health-weekly:
    name: Weekly demo Supabase health check
    if: github.event_name == 'schedule'   # ya da ayrı workflow: on: schedule: [cron: '0 6 * * 1']
    runs-on: ubuntu-latest
    steps:
      - name: Health check
        env: { DEMO_ANON_KEY: ${{ secrets.DEMO_ANON_KEY }} }
        run: |
          code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
            -H "apikey: $DEMO_ANON_KEY" \
            https://vtzqjmazsvurxdeondmi.supabase.co/rest/v1/ || true)
          echo "code=$code" >> "$GITHUB_OUTPUT"
      - name: Open issue on pause
        if: steps.health.outputs.code == '000'
        uses: actions/github-script@v7
        with:
          script: |
            await github.rest.issues.create({
              owner: context.repo.owner, repo: context.repo.repo,
              title: 'Demo Supabase paused (weekly health check)',
              body: 'HTTP 000/NXDOMAIN — restore runbook: .claude/session-learnings.md (2026-09-01), Management API POST /v1/projects/vtzqjmazsvurxdeondmi/restore (demo token .mcp.json supabase-demo env).'
            })
```

Uyarı: demo projenin free-tier dk/saatlik istek kotalarına haftalık 1 curl kayda değer yük bindirmez; ama sürekli ping'li (cron sık) tasarımdan kaçınılmalı.

## Teslim

- Tek commit: `idle: ci-saglamlastirma — demo health check + stub fallback + workers=1` (test.yml + bu rapor)
- **Push YOK** — CI doğrulaması (health check'in gerçek GitHub runner'ında çalışması, secret var/yok davranışı) merge sonrası kullanıcı push'unda olur. İlk push'ta izlenecekler: (1) `demo-e2e` job'ı `Demo health: HTTP 401 -> alive` (veya key eklenmişse `200 -> ok`) basmalı, (2) demo gerçek koşum workers=1 yeşil, (3) smoke ve shard job'ları eskisi gibi yeşil.
- js/, tests/, index.html: **dokunulmadı** (guardrail).
