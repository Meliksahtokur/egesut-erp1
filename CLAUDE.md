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
vermeden ÖNCE aynı test listesi bir **glmf-max** koltuğunda tarayıcıda koşulur.
Sonuç **PASS** olmadan sahibe test verilmez.

1. Test listesi zarfa yazılır: her madde ayrı, beklenen görünüm/sonuç açık.
2. glmf-max koltuğu listeyi demo modunda koşar; madde başına PASS/FAIL +
   kanıt (ekran görüntüsü / DOM / konsol) raporlar.
3. FAIL varsa düzeltilir ve koltuk FAIL maddeleri yeniden koşar.
4. Hepsi PASS → ancak o zaman sahibe link + liste verilir.

Playwright koşumu belgelendiyse tekrarlanmaz; demo sahip şifresine dokunulmaz.
