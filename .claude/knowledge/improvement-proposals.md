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
**Durum:** kısmen tamamlandı — `tohumlama_sonuc_gebe/bos/bekliyor` RPC'leri oluşturuldu (migration 20260327000001), forms.js:640 `tohSonuc()` frontend güncellemesi eksik → BUG-009

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

## [İ-007] JS syntax check startup'a geri eklensin — veya CI/pre-commit hook yapılsın
**Öncelik:** orta
**Etkilenen:** .claude/scripts/startup-check.sh, CI
**Özet:** startup-check.sh'ten JS syntax kontrolü kaldırıldı (6d9b0d8, "node-check kaldırıldı"). Bu hızlandırma makul ama JS hataları artık oturum briefing'inde görünmüyor. Alternatif: pre-commit hook olarak `node --check` ekle — commit sırasında yakala, oturum başında değil.
**Gerekçe:** arge-analyst tespiti, commit 6d9b0d8. Syntax hatası sessiz kalırsa runtime'da zor debug edilir.
**Durum:** bekliyor

## [İ-008] haiku agent'lar için "escalation path" protokolü tanımlanmalı
**Öncelik:** orta
**Etkilenen:** .claude/agents/erp-db-agent.md, erp-frontend-dev.md
**Özet:** erp-db-agent ve erp-frontend-dev haiku'ya düşürüldü ("uygularsın, düşünmezsin" modeli). Ancak agent'ın mimari karar gerektiğini nasıl tespit edeceği ve erp-architect'e nasıl geri döneceği protokolü eksik. Haiku agent belirsizlikle karşılaşırsa sessiz kalabilir veya yanlış uygulayabilir.
**Gerekçe:** arge-analyst tespiti, commit 5da2ef6. Escalation path eksikliği hatalı uygulamalara yol açabilir.
**Durum:** tamamlandı — commit e4158d9, tüm haiku agent'lara ESCALATION protokolü eklendi
