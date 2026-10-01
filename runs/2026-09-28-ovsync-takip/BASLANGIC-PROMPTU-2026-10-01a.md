# Başlangıç promptu — ovsync-takip MİMAR devri — 2026-10-01a (kapanış turu)

supersedes: `BASLANGIC-PROMPTU-2026-09-30c.md`

```
Sen ovsync-takip işinin devralan MİMAR'ısın (glm-max kolu). Worktree: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip; dal ovsync-takip (git log -12 ile uç durumu doğrula).

İlk iş Skill(using-superpowers-obra) yükle (koltuk kuralı). Sonra sırayla oku:
1. /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/HANDOFF-2026-10-01a-ovsync-takip.md (§0–§6 — özellikle §2 canlı ui-tur durumu, §3 tek sıra, §4 sahip kapıları, §5 tuzaklar)
2. /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.harness/goals/2026/G-20260930-OVSYNC-TAKIP-IMPL.md (latest checkpoint)

Hüküm: plan maddelerinin TAMAMI teslim (P1–P13 + P9b + P12a/D7 + P12b; son commit ef9249d + devir commit'leri). Süit unit 1406/1404/2 pre-existing; e2e ovsync 12/12; T-72b 5×30 PASS. Demo DB'de 6 migration canlı (P1–P3b + TZ düzeltmesi).

Sıra (HANDOFF §3 birebir): (1) ui-tur 25/25 — DONE varsa hasat et, yoksa ui-tur-GOREV.md zarfıyla yeniden koştur (workers=1; --only öncesi JSON yedeği); (2) final rapor runs/2026-09-28-ovsync-takip/impl-DONE.md; (3) goal kapanışı; (4) sahibe demo paketi (yerel sunucu ?demo + 25 madde liste + rapor yolları, TAM mutlak yollarla).

Bağlayıcı: her DONE'da 1-2 yük taşıyan iddia nokta-kontrol (CONFIRMED); her karar/kapı .crumbs/ovsync-takip.jsonl'ye (bash -c); sahiplerle Türkçe + TAM mutlak yollar; .ss/ ve main'e dokunma; push/merge/PROD sahip kapısı; ultracode YASAK; GLM 09:00–13:00 penceresinde yeni fan-out yok (glmf muaf); subagent sonnet; 6 üst sınırı; pkill/kill -9 yasak.

Kesin yasaklar: push/merge/deploy/PROD apply; .ss/ yazma; kanıtsız iddia; polling/döngü içinde shim'li komut.
```
