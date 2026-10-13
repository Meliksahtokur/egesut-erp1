@AGENTS.md

# Claude Code Runtime Entry Point

Shared governance is imported from `AGENTS.md` and
`.harness/contract.md`. Do not copy shared policy into this file.

For Claude-specific execution guidance, read
`.harness/runtimes/claude.md`.

Use inline work or Claude built-in agents by default. Recommend a flow and ask
the owner when ambiguous multi-worker or long-running work has no selection.
Herdr and external worker systems are explicit-only flows.

Task completion does not authorize automatic commit, merge, push, deploy, or
database mutation. The active goal and owner gates control those actions.

## UI testi kapısı (sahip kuralı, 2026-09-25 — BAĞLAYICI)

Sahibe demo/UI testi (yerel sunucu `?demo` ya da herhangi bir test sürümü)
vermeden ÖNCE aynı test listesi bir **worker sonnet-medium** koltuğunda (`ss-worker-sonnet-medium`)
tarayıcıda koşulur. (2026-10-02: eski glmf-max koltuğu Anthropic-only geçişiyle arşivlendi.)
Sonuç **PASS** olmadan sahibe test verilmez.

1. Test listesi zarfa yazılır: her madde ayrı, beklenen görünüm/sonuç açık.
2. Worker koltuğu listeyi demo modunda koşar; madde başına PASS/FAIL +
   kanıt (ekran görüntüsü / DOM / konsol) raporlar.
3. FAIL varsa düzeltilir ve koltuk FAIL maddeleri yeniden koşar.
4. Hepsi PASS → ancak o zaman sahibe link + liste verilir.

Playwright koşumu belgelendiyse tekrarlanmaz; demo sahip şifresine dokunulmaz.

**Domain kuralları ZORUNLU (sahip, 2026-09-26):** plan/spec/SQL/implementasyon yazmadan ÖNCE
`.harness/references/domain-rules.md` okunur; çelişkide dur ve sahibe sor (AGENTS.md Start here #2).

## Model yönlendirme (kanon, 2026-10-02)

Koltuk/model seçimi Anthropic-only tablosuna göre yapılır (ss-org §2d):
implementasyon = worker sonnet-medium, mekanik iş = worker sonnet-low, parçalama/zarf = lead
sonnet-medium, büyük spec+plan = mimar opus-high, sahiple konuşma/kabul/merge = root opus-high.
**codex luna-max YALNIZ dış review içindir; implementasyon luna'ya verilmez.**
glm, glmf, zcode ve goose kolları arşivlendi (artık yok). Builtin alt-ajanda model açık seçilir
(tarama haiku, test/mekanik sonnet, kod review sonnet).
