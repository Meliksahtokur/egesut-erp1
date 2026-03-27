# ArGe Analist Belleği

## Son Kontrol Edilen Commit
<!-- Güncellenir: her tarama sonrası -->
LAST_CHECKED_COMMIT=55a1f6a

## Araştırılan Konular
<!-- Tekrar araştırmayı önlemek için -->
<!-- Format: [tarih] konu — özet sonuç -->
- [2026-03-27] 27c5e70..55a1f6a arası değişiklikler — agent mimari refactor (haiku/sonnet hiyerarşisi), Dream departmanı eklendi, JS syntax check kaldırıldı, submitInsem pullTables kaldırıldı

## Öğrenilen Proje Kalıpları
- Agent'lar "beyin" (sonnet: orchestrator, debug, planner, architect, arge-analyst, dream-director) ve "eller" (haiku: explorer, db, frontend, qa, git) olarak ayrılıyor
- Dream departmanı: agent feedback analizi için meta-katman — bugs.md ve improvement-proposals.md'yi besler
- RPC auto-invalidation varsayımı var ama doğrulanmamış — pullTables kaldırılması risk

## Başarılı Stratejiler
- git diff --stat ile hızlı değişiklik özeti al, sonra kritik dosyaları derinlemesine oku
- Mevcut bugs.md/improvement-proposals.md'yi önce oku, duplikat önle

## Kaçınılacak Yaklaşımlar
- Tüm dosyaları okumaya çalışma — diff'ten ne değiştiğine odaklan
