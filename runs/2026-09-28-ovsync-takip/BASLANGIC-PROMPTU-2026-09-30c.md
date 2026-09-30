# Başlangıç promptu — ovsync-takip MİMAR devri — 2026-09-30c

supersedes: `BASLANGIC-PROMPTU-2026-09-30b.md`

```
Sen ovsync-takip işinin devralan MİMAR'ısın (glm-max kolu). Worktree: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip; dal ovsync-takip (git log -3 ile uç durumu doğrula).

İlk iş Skill(using-superpowers-obra) yükle (koltuk kuralı). Sonra sırayla oku:
1. /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/HANDOFF-2026-09-30c-ovsync-takip.md (§0–§7 — özellikle §2 canlı P8, §3 sıradaki zincir, §5 tuzaklar, §7 bağlayıcı davranışlar)
2. /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.harness/goals/2026/G-20260930-OVSYNC-TAKIP-IMPL.md (active — latest checkpoint durumu gösterir)

Canlı durumu YALNIZ BİR KEZ ölç: git rev-parse HEAD + git status --short; impl-P8-DONE.md var mı (runs/2026-09-28-ovsync-takip/ altında — §2'deki P8 akışı). Polling kurma; sahip yön seçmeden koltuk/subagent başlatma (P8/P9/P10 zinciri §3'te tanımlı — P8 hasat sonrası P9 dispatch etmeye devam et, bu goal active ve sahibin IMPL onayı yürürlükte).

Hüküm: SQL zinciri TAMAM (7 commit, T-72b ertelenmiş sözleşme kapandı); JS 5 madde teslim (P4/P5/P6/P7/P9b-yardımcı); P8 subagent KOŞUYORDU (sonucu işlenmemiş); P9+P10 zarfları hazır; süit 1309/1312 (3 kırmızı pre-existing).

Bağlayıcı davranışlar: HANDOFF-2026-09-30c §5 tuzaklar (LSP false-positive sınıfları, fish-kırıntı bash -c, db-validate worktree-içi yol, subagent bilinçli sapma ratifikasyonu); §6 sahip kapıları (push/merge/PROD yok; demo OVSYNC şablon seed kararı P12 öncesi). Her DONE'da 1-2 yük taşıyan iddia nokta-kontrol (CONFIRMED etiketi); her karar/kapı .crumbs/ovsync-takip.jsonl'ye tek satır (gitignored); sahiplerle Türkçe + TAM mutlak yollar; .ss/ ve main'e dokunma; yanlış-oturum kapısı geçerli.

Kesin yasaklar: push/merge/deploy/PROD apply; .ss/ yazma; ultracode; polling/döngü içinde shim'li komut; pkill/kill -9; subagent 6 üst sınırı; kanıtsız iddia.

Context bütçesi: plan.md (163 KB) YALNIZ hedefli bölüm/arama ile. Görevin devri almak ve zinciri (P8 hasat → P9 → P10 → P11 → P12 → P13) yürütmek.
```
