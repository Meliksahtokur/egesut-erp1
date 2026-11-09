# S2b-damga — önbellek damgası toplu artırımı (S2 sonrası)

İlk iş: ~/.claude/skills/using-superpowers-obra/SKILL.md oku ve uygula (sahip kuralı; SUBAGENT-STOP bu kural için geçersiz).

## Plan maddesi
S2 (4214d2d) js/ovsync-tren.js'i değiştirdi ama `?v=` damgası artmadı; canlıda tarayıcı eski JS'i önbellekten verir. Proje kuralı (tests/unit/ovsync-tren-entegrasyon.test.js:146-159, :809, :900-906): index.html'deki TÜM `?v=` damgaları + `manifest.json?v=` tek değer. Tümünü `20261110-1` → `20261110-2` yap; testlerdeki sabitleri (`:146-147` etiket, `:157-159` tek değer, `:809 UB5_YENI_DAMGA`) aynı değere güncelle. Bağlam: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/S2-gecikmis-report.md:38.
Service worker / başka bir yerde aynı damgayı ya da cache adını taşıyan dosya varsa (grep `20261110-1` tüm repo, node_modules hariç) listele; yazılabilir listede değilse dokunma, report'a yaz.

## Model
sonnet (ss-worker) — mekanik

## Yazılabilir dosyalar
~/.herdr/worktrees/egesut-erp1/ovsync-tren/index.html
~/.herdr/worktrees/egesut-erp1/ovsync-tren/tests/unit/ovsync-tren-entegrasyon.test.js
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/S2b-damga-report.md

## Boyut bütçesi
Yalnız damga dizesi değişimi; mantık değişikliği 0 satır.

## Önceden cevaplanmış kararlar
- Yeni damga birebir `20261110-2`.
- Diğer unit testler başka bir damga sayısını pinliyorsa (ör. ileri-gebe-duve-siralama ?v= sayısı) sayı değişmez, yalnız değer — kırılırsa report'ta yaz, düzeltme yapma.
- Commit: yalnız yazılabilir kod/test dosyaları, `git add` dosya dosya, mesaj sonu `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Push/merge YOK.

## Run
NODE_PATH=~/egesut-erp1/node_modules node --test tests/unit/ovsync-tren-entegrasyon.test.js
NODE_PATH=~/egesut-erp1/node_modules node --test tests/unit/ovsync-tren.test.js

(cwd = ~/.herdr/worktrees/egesut-erp1/ovsync-tren; ağır komut ise `ram-ultracode exec --class test --wait 300 -- bash <script>` ile.) Ek olarak tests/unit altında `?v=` geçen diğer testleri bul ve koş.

## Review: T0

## DONE
Report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/S2b-damga-report.md — `sonuc:`, `kabul SHA:`, `## Run kanıtı` (komut + rc + son ≤30 satır).
