# REV-3 — idle/ci-saglamlastirma: E2E CI hattına demo-pause dayanıklılığı

**Tarih:** 2026-09-02 · **Taban:** main `a71b7a0` · **Branch:** `idle/ci-saglamlastirma` (worktree: `/home/melik/egesut-wt/ci-saglamlastirma`)
**Kaynak:** e2e-gercek raporu §4 "CI önerileri" (`.claude/idle-reports/2026-09-02-e2e-gercek.md`)

## ZORUNLU GUARDRAIL

- Push YOK (CI doğrulaması merge sonrası kullanıcı push'unda olur — bunu raporda belirt)
- Yalnız `.github/workflows/*.yml` (+ gerekirse `tests/` dokunmadan uyumluluk notu) — **js/ DOKUNMA**
- Supabase çağrısı YOK · tek commit · rapor: `.claude/idle-reports/2026-09-02-ci-saglamlastirma.md`
- YAML doğrulama: `docker run --rm -v "$PWD":/work rhysd/actionlint:latest -color` (veya python yaml.safe_load en azından)

## Arka plan (ölçülmüş)

- 2026-09-01'de demo projesi free-tier pause'a girdi (DNS NXDOMAIN) → tüm demo-mode CI koşumları açılışta asılı kaldı.
- e2e-gercek run1 kanıtı: paralel worker ile demo free-tier 23 fail verdi; `--workers=1` ile kararlı (final 64/0/3).
- Mevcut `test.yml`: 3 shard + smoke job, demosuz, baseURL=prod GH Pages. Shard'lar demo'ya paralel vurursa riskli.
- `tests/` tarafı hazır: `PLAYWRIGHT_STUB_BACKEND=1` modu var (stub-backend.js); stub modda DB-bağımlı
  e2e.spec testleri (2.01/2.03/3.02) otomatik skip.

## Kapsam — tek dosya, üç değişiklik

`.github/workflows/test.yml` (mevcut yapıyı koru, ekle):

1. **Demo health check step:** `curl -s -o /dev/null -w '%{http_code}' --max-time 10` +
   `https://vtzqjmazsvurxdeondmi.supabase.co/rest/v1/` + `apikey: ${{ secrets.DEMO_ANON_KEY }}` → `GITHUB_OUTPUT`.
   (DEMO_ANON_KEY secret'ı repoda yoksa: workflow'u `secrets.DEMO_ANON_KEY || vars` fallback'iyle yazma —
   key'i koda gömme; rapora "kullanıcı secret'ı eklemeli" notu düş ve health check'i opsiyonel dalda bırak.)
2. **Demo gerçek koşum:** health OK ise `PLAYWRIGHT_DEMO_MODE=1` + **tek job + `--workers=1`**
   (shard KULLANMA — free-tier paralel yük kaldırmıyor, run1 kanıtı).
3. **Stub fallback:** health 000/NXDOMAIN ise `PLAYWRIGHT_DEMO_MODE=1 PLAYWRIGHT_STUB_BACKEND=1` koş
   (spec kodu aynı; stub'da DB testleri kendiliğinden skip olur).
4. **Opsiyonel (raporda öner olarak):** haftalık scheduled demo-health job; pause tespitinde issue açan
   küçük step (restore runbook referansı: `.claude/session-learnings.md` 2026-09-01).
5. smoke job demosuz prod koşusuna devam etsin (dokunma).

## Teslim

Tek commit (`idle: ci-saglamlastirma — demo health check + stub fallback + workers=1`),
actionlint/yaml kanıtı, rapor: değişiklik özeti + secret eksiği varsa kullanıcı adımı.
