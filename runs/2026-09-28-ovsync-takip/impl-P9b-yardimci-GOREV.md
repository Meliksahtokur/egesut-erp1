# impl-P9b-yardimci — GOREV zarfı: `gunFarkiEtiket` saf yardımcı + kalem 12 testi (K15'ten bağımsız parça)

- **Goal:** `G-20260930-OVSYNC-TAKIP-IMPL` (active)
- **Plan madde:** **P9b (yalnız bağımsız parça)** — `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:619-636` — **ui.js bağlaması bu zarfta YOK** (P9 sonrası; tek-yazıcı).
- **GOREV (bu dosya):** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P9b-yardimci-GOREV.md`
- **DONE:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P9b-yardimci-DONE.md`

## Yazma manifesti (TEK YAZICI — liste dışı YASAK)

1. `js/utils/helpers.js` (MODIFY — saf yardımcı ekle)
2. `tests/unit/ovsync-takip.test.js` (create — kalem 12 testi; kalem 11 testleri P9'da aynı dosyaya eklenecek, sıralı)
3. `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P9b-yardimci-DONE.md` (create)

## Zorunlu davranış protokolü

1. **İLK İŞ:** `/home/melik/.claude/skills/using-superpowers-obra/SKILL.md` oku ve uygula (sahip kuralı; SUBAGENT-STOP geçersiz).
2. **Kod öncesi:** domain-rules.md; helpers.js mevcut desenlerini oku (`fmtTarih` [helpers.js:58-64] — onun ilk-10-karakter tuzağına DOKUNMA, yalnız öğren).
3. **Kırmızı test ÖNCE:** dört sınır case (aşağıda) kirmizi görülür, sonra yardımcı, yeşil.
4. **Bitiş kapısı:** `verification-before-completion-obra`; `node --check js/utils/helpers.js` + test koşumu.

## Görev (plan P9b birebir — plan.md:626-630)

**Arayüz (Produces):** `gunFarkiEtiket(tarihISO, bugun?) → 'bugün' | 'dün' | 'N gün önce' | 'N gün sonra'`
- Europe/Istanbul YEREL takvim günü farkı (UTC değil); hesap iki yerel tarih karşılaştırmasıyla (tarih→gg.aa.yyyy alanı, Date.now() değil); ileri tarih → 'N gün sonra'. Saf, durumsuz, dışa aktarılır (Node testi `require` ile).

**Test senaryoları (plan.md:629):** bugün/dün/N gün önce; gece yarisi sınırı (dün 23:30 vs bugün 00:30 yerel — aynı yerel gün değil, fark 1); UTC sınırı (UTC 21:30 = İstanbul 00:30 ertesi gün — yerel alana dönüşünce fark doğru); ileri tarih.

**Not:** `fmtTarih`'in ilk-10-karakter kesimi timestamptz için YANLIŞ gün üretir [helpers.js:58-64] — `gunFarkiEtiket` bu tuzağa düşmez (yerel alan dönüşümü kendi içinde); `fmtTarih`'i DEĞİŞTİRME.

## Kabul ölçütleri (plan.md:634'ün bu parçaya düşeni)

1. Birim testi yeşil — dört sınır case.
2. `node --check`; `git diff --check` temiz; kırmızı→yeşil çıktıları DONE'da.
3. Yardımcı saf (durumsuz; `window`/DOM erişimi yok — Node `require` ile test edilebilir).

## Yasaklar

- `js/ui.js` bağlaması (P9 sonrası); `fmtTarih` değişikliği; mevcut helpers davranış bozma.
- Commit atma; PROD; `.ss/`, `main`; sessiz varsayılan; 2 self-repair tavanı.

## DONE şablonu

Başlık: `impl-P9b-yardimci-DONE — TAMAM|KISMI|BLOKE` · kabul maddeleri kanıtlı · kırmızı→yeşil çıktıları · yazılan dosyalar · açık kalem (ui.js bağlaması P9 sonrası).
