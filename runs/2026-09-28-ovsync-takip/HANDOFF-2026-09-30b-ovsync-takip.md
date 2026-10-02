# HANDOFF — ovsync-takip / MİMAR (glm-max) — 2026-09-30 ~10:00

supersedes: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/HANDOFF-2026-09-30a-ovsync-takip.md`. Bu devir 2026-09-30 sabah turunun kapanışıdır; o turda ürün implementasyonu BAŞLAMADI (sahip kapısında).

## §0 İlk 5 dakika

1. Sırayla oku: bu belge; `.harness/contract.md`; `.harness/goals/2026/G-20260929-OVSYNC-TAKIP-TEST-HAZIRLIK.md`; `.harness/goals/2026/G-20260930-OVSYNC-TAKIP-IMPL.md` (draft).
2. Canlı durumu BİR KEZ ölç: `git rev-parse HEAD` + `git status --short`; `herdr tab list --workspace w14` (beklenen: yalnız mimar tab'ı; ovsync worker/koltuk YOK); arka plan bekleyici yok. Bekleyici/polling kurma; sahip yön seçmeden koltuk açma.
3. `Skill(using-superpowers-obra)` yükle (koltuk kuralı). Düzen sorusunda `ss-org` skill'i.

## §1 Ne oldu (2026-09-30 sabah turu — kararlar K-no'larıyla)

- **K1 — Katalog v3 (100 senaryo):** sahip "eksik senaryoları inbuild subagent ile yaz" talimatı → kapsam denetimi 6 GERÇEK açık buldu; **T-95..T-100** yazıldı (P2b/P3a sözleşmelerinden türetildi; uydurma yok). Subagent dosyayı manifest dışı `test-senaryolari.md` olarak yeniden adlandırdı → mimar **ratifiye etti** (plan.md 3/4 doğru yazım, kod yüzeyi sıfır bağımlılık; kanonik ad `test-senaryolari.md`). Üç bayat "96" sayı cümlesi düzeltildi.
- **K2 — İki dış review döngüsü de KABUL ile kapandı** (sahip kuralı: review DIŞA → ss-lead-codex luna/max, herdr yan tab):
  - Katalog v3 review: ilk tur DÜZELTME (2 ÖNEMLİ + 1 MİNÖR) → **K3 düzeltmeleri** → re-check **KABUL** (`runs/2026-09-28-ovsync-takip/katalog-v3-review-DONE.md` §6).
  - Diyagramlar (6 mermaid, T-95..T-100): ilk tur DÜZELTME (aynı üç eskime noktası) → subagent tamiri (mmdc render exit=0 kanıtlı) → re-check **KABUL** (`runs/2026-09-28-ovsync-takip/diyagram-review-DONE.md` §6).
- **K3 — Katalog düzeltmeleri (mimar uyguladı, plan kaynağından doğrulayarak):** T-97'e tam `p_tohumlama_id` fixture'ı (XOR geçilir, red bayrak kapısından); T-98'e (a) izinli red kümesi {`TOH_SONUCLU`,`BOS_DUZELTME_KOSUL`} + (b) deterministik `treatment_date`/`created_at`; T-100'e `pg_get_functiondef` H3 kaynak kanıtı adımı. Dayanaklar `plan.md:288-304, 390-392`.
- **K4 — T-72b (B erteleme + C koşum, sahip onaylı):** `--rounds=30` koşuldu; betik yeni-yol nesneleri yokken yarış turlarını **yapısal olarak koşmaz** [CONFIRMED `tests/concurrency/ovsync-takip-t72b.mjs:214-220`] — ölçülen: envanter + Ç1/Ç2/Ç4/Ç5 RED(beklenen) + Ç3 BLOKE. Gerçek 5×30 yarış ölçümü implementasyon sonrası; Ç3 ertelenmiş sözleşme olarak IMPL goal'de. Kanıt: `/home/melik/tmp/ovsync-takip-olcum/t72b-rounds30-2026-09-30.txt`.
- **K5 — IMPL goal draft** yazıldı (sahip: "mimar açabilir, push/merge hariç"): `.harness/goals/2026/G-20260930-OVSYNC-TAKIP-IMPL.md`. SQL maddeleri (P1–P3b) builtin subagent'a YAZDIRILIR; her migration `scripts/db-validate.sh` kapısı + demo prova.
- **K6 — Dış öneri değerlendirmesi** (`/home/melik/İndirilenler/glm-vs-glmf-test-uretim-mimarisi.md`): benimsenenler IMPL goal + `runs/2026-09-28-ovsync-takip/test-zarf-SABLONU.md`'ye işlendi (risk routing R0–R6, precondition assertion, ters-kanıt mapping, max-2 self-repair, evidence packet, üçlü UI oracle, eskalasyon sinyalleri). **`tests/test-manifest.yaml` üretildi**: 100 kayıt; owner glmf=77 / glmf+review=17 / glm=6; hedefler sql=42 / e2e=41 / insan-ui=10 / unit=4 / concurrency=3. Ertelenen: mutation testing; her-PASS audit (yalnız R3+).
- **K7 — GLM pencere kuralı değişti (sahip):** "glmf koltukları 9'dan sonra da koşmaya devam edebilir, işlerini bitirsinler" — glmf/worker işleri 09:00–13:00'den MUAF; duraklatma yalnız glm koltukları. Global `~/.claude/CLAUDE.md`'deki eski satır henüz güncellenmedi (sahip onayı bekler).
- **K8 — D kalemı:** manifest dışı `test-uygulanabilir-HANDOFF.md` goal manifestine retroaktif eklendi (korundu, sahiplenildi).
- **Akış atlası (HAT 2):** `runs/2026-09-29-akis-atlasi/BRIEF-2026-09-30.md` üretildi (8 parça özetlendi; ana tez "agent inference ≠ evidence"); **5 sahip sorusu** açıkta.

## §2 Canlı işler (yazım anı ölçümü)

| İş | Koltuk | Durum | Takip |
|---|---|---|---|
| Bu devir | w14:t3 (mimar glm-max, bu oturum) | kapanıyor | devir sonrası tab sahibin kontrolünde |
| Diğer her şey | — | YOK: tüm subagent'lar bitti, herdr koltukları (tN/tP/tR) kapatıldı, bekleyiciler tamamlandı | `herdr tab list --workspace w14` doğrulandı |

## §3 Sıradaki (SAHİP kararları; otomatik dağıtım YOK)

1. **[sahip] Katalog v3 final onayı** (100 senaryo + diyagramlar + manifest paketi) → HAT 0 kapanır: G-20260929 `done` + kapanış ölçümü.
2. **[sahip] HAT 1 (IMPL) aktivasyonu** → mimar P1 zarfını yazar (salt-okunur `ovsync_takip_listele` RPC; SQL builtin subagent; db-validation; demo prova apply). Plan sırası P1→P2a-d→P3a→P3b (sıralı) → P4–P10 (JS) → P11 (birim) → P12 (PW + glmf-max 25 madde) → P13 (doküman).
3. **[sahip] Akış atlası 5 sorusu** (BRIEF §7): pilot zamanlaması, A/B koltuğu, PNG kademesi, PASS eşiği, Crawljax.
4. **[sahip] Mutation erteleme teyidi** (itiraz yoksa ertede).

## §4 Araçlar ve geçiciler

- Kanıt/geçici dizinler: `/home/melik/tmp/ovsync-takip-olcum/` (T-72b çıktısı — SİLME), `~/tmp/diyagram-fix/` (render geçicileri, silinebilir).
- Demo DB: `/home/melik/egesut-erp1/.env` → `SUPABASE_DEMO_REF/_DB_PASSWORD/_POOLER` (değer dosyada; URL'yi kurgula, pane/bash'e basma).
- Diyagram render reçetesi: mmdc 12.0.0 + Playwright chromium `executablePath` (çalışan build `chromium-1228`); Docker PW deseni `mcr.microsoft.com/playwright:v1.58.2-noble --network host`.
- `.crumbs/ovsync-takip.jsonl` **gitignored** (yerel kayıt; commit edilmez). `docs/plans/` da gitignored — `test-senaryolari.md` bu devir commit'ine `-f` ile girdi.
- Dirty dosyalar BAŞKA oturumların (`.harness/references/domain-rules.md`, `design.md`, `.ss/ovsync-takip-BOARD.md`) — dokunma, geri alma.
- `.ss/` yazma yasağı sürer (BOARD + HANDOFF); `.ss/ovsync-takip-mimar-HANDOFF.md` işaretçisi hiç kurulmadı — giriş noktası bu belge + hafıza işaretçisi.
- Kırıntı sözleşmesi + kanıt etiketleri + board disiplini: derlenmiş kimlikte (roles/_core.md) — aynen uygula.

## §5 Dersler

- Subagent manifest dışı davranışının iki biçimi görüldü: (a) sessiz dosya adı değiştirme — plan çoğunluğu + kod bağımlılığı sıfır ise ratifiye ET, ihlali kırıntıya yaz; (b) rapor "dokunmadım" derken gözlem çelişkisi — gözlemi INFERRED etiketiyle kayda al, içeriği doğrula, sahiplen.
- T-72b tipi fail-closed betikler: "koşulmadı" mesajı atlanan adım değil, tasarım olabilir — betik kaynağından doğrula (kısa devre dalı vs gerçek döngü) BEFORE hüküm verme.
- Review döngüsü reçetesi işledi: DÜZELTME → mimar/subagent düzeltme → AYNI standarda re-check → KABUL → koltuğu kapat. Bulgu önemi: her hüküm `dosya:satır` kanıtı taşır; kanıtsız bulgu RED sayılmaz.
- Dış öneri değerlendirme ayrımı: (A) zaten sistemde olan → teyit et, işlem yapma; (B) yeni değerli → hedef belgeye işle (goal/şablon); (C) ağır → risk-seçimli uyarla; (D) öncülü eski → belirt.
- Aynı gün iki kere "96 iddia/94 gerçek" sınıfı sayı tutarsızlığı çıktı: her DONE'da sayı iddialarını grep ile BAĞIMSIZ doğrula.

## §6 Davranış mirası — yeni ajan bunları KURAL olarak alır (sahibin cümleleri)

1. **"Dışa gidecek reviewler... ss-lead-codex luna/max'a, yan taba; diğer işleri inbuild yap."** Review/her DEĞERLENDİRME dışa: herdr'de yan tab aç (`herdr tab create --workspace w14 --cwd <wt> --label <ad> --no-focus`), pane'e `ss-lead-codex "Görev zarfın: <mutlak yol>"` yaz (`herdr pane run`; send-keys yalnız tuş adı kabul eder), luna/max'ı pane altbilgisinden doğrula, zarf GOREV+DONE mutlak yollu + tek-yazıcı manifest, re-check'i AYNI koltukta/dosyada `## N. Re-check` bölümüyle yap, KABUL sonrası `herdr tab close`. Amele/üretim işi inbuild subagent: `using-superpowers-obra` zorunlu ilk iş + `verification-before-completion-obra` bitirme kapısı + tek-yazıcı yazma manifesti; keşif/yazım ajanları `model: sonnet`.
2. **"SQL dosyalarını kendin subagent ile yazdır inbuild."** (IMPL'de uygulanacak; her SQL db-validation kapısından geçer.)
3. **"Full goal manifestini sen de açabilirsin, sorun yok; sadece push/merge yapamazsın."** Goal kayıtları mimar tarafından yazılır/güncellenir; commit devir kapsamında serbest; push/merge/deploy/PROD apply HER ZAMAN sahip kapısı.
4. **"GLMF koltukları 9'dan sonra da koşmaya devam edebilir, işlerini bitirsinler."** Worker işleri 09:00–13:00 penceresinden muaf; yalnız glm (glm-max karar koltuğu) sahibin yönlendirmesi olmadan boşta çalışmaz.
5. **"Hızlı halletsin."** Review tek tur + dar kapsam; review işin kendisinden büyük olamaz.
6. Mimar mirası: her DONE'da 1–2 yük taşıyan iddiayı kaynaktan nokta-kontrol et (CONFIRMED etiketiyle); iddialar kanıt etiketsiz yazılmaz; her karar/ölçüm/kapı kırıntıya tek satır düşer; sahipler Türkçe + TAM mutlak yollar; `.ss/` ve `main` dokunulmaz; koltuk zarfına kapsamını aşan kısıt yazma.
