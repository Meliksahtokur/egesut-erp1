# İyileştirme Önerileri

<!-- Aktif öneriler — orkestratör bunları kullanıcıya sunar -->
<!-- Format:
## [ID] Başlık
**Öncelik:** yüksek / orta / düşük
**Etkilenen:** [modüller]
**Özet:** [ne yapılmalı]
**Gerekçe:** [neden, hangi bulguda tespit edildi]
**Durum:** bekliyor / inceleniyor / onaylandı / reddedildi
-->

## [İ-001] knowledge/ dosyaları işletilmeye başlansın
**Öncelik:** yüksek
**Etkilenen:** .claude/knowledge/, orchestrator
**Özet:** bugs.md ve improvement-proposals.md'e plan dosyasındaki bekleyen maddeler taşınsın. Oturum başı briefing gerçek durumu yansıtsın.
**Gerekçe:** Plan dosyasında 2 bekleyen REST→RPC refactor var ama proposals'da görünmüyordu. Sistem denetimi 2026-03-27.
**Durum:** onaylandı (bugs.md ve bu dosya dolduruldu)

## [İ-002] Kritik ADR'lar yazılsın
**Öncelik:** yüksek
**Etkilenen:** .claude/arch-decisions/
**Özet:** En az 4 ADR belgesi: (1) tohumlama immutable event tasarımı, (2) Promise-based _pulling lock, (3) RPC-only write convention, (4) offline kuyruk mimarisi.
**Gerekçe:** arch-decisions/ dizini boş. Kritik kararlar sadece commit mesajlarında yaşıyor. Sistem denetimi 2026-03-27.
**Durum:** bekliyor

## [İ-003] Tohumlama write-path refactor — tohumlama_sonuc_* RPC'leri
**Öncelik:** yüksek
**Etkilenen:** forms.js, ui.js, supabase
**Özet:** forms.js:634 `tohSonuc()` ve forms.js:804 gebelik INSERT → `tohumlama_sonuc_gebe`, `tohumlama_sonuc_bos`, `tohumlama_abort` RPC'lerine taşınsın. SONARCLOUD_REMEDIATION_PLAN.md'de zaten planlandı.
**Gerekçe:** 3 farklı write-path var, sadece biri RPC üzerinden. Duplication ve validasyon riski. Sistem denetimi 2026-03-27.
**Durum:** bekliyor

## [İ-004] erp-planner vs feature-dev ayrımı CLAUDE.md'de netleştirilsin
**Öncelik:** orta
**Etkilenen:** CLAUDE.md, orchestrator kararları
**Özet:** "Yeni büyük özellik" için hem erp-planner hem feature-dev yönlendirmesi var. Hangisinin ne zaman çağrılacağı belirsiz. Kural netleştirilmeli (ör: erp-planner = domain-specific plan, feature-dev = greenfield geliştirme).
**Gerekçe:** Sistem denetimi 2026-03-27, arge-analyst tespiti.
**Durum:** bekliyor

## [İ-005] erp-qa-agent modeli haiku → sonnet
**Öncelik:** orta
**Etkilenen:** .claude/agents/erp-qa-agent.md
**Özet:** Karmaşık Playwright senaryoları için haiku yetersiz kalabilir. Sonnet'e yükselt.
**Gerekçe:** Sistem denetimi 2026-03-27.
**Durum:** bekliyor

## [İ-006] Feedback format standardizasyonu
**Öncelik:** düşük
**Etkilenen:** .claude/agents/*.md
**Özet:** arge-local-reader ve arge-web-researcher feedback formatı diğer agent'lardan farklı. Tüm agent'lar aynı format kullanmalı: `Ne işe yaradı / Ne çalışmadı / Bir sonraki sefere dikkat et`.
**Gerekçe:** Sistem denetimi 2026-03-27.
**Durum:** bekliyor
