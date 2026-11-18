---
id: G-20261118-CIKANLAR
status: done
owner: Melik Şah Tokur
flow: Full mode, root (opus) -> Muse koltuğu (kod) -> ss-verifier + ss-reviewer (sonnet) -> UI kapısı ss-worker sonnet-medium -> sahip demo
created: 2026-11-18
base_sha: 854582b
launch_sha: 854582b
branch: cikanlar
worktree: null
plan_report: runs/2026-11-18-cikanlar/k1-report.md
report: runs/2026-11-18-cikanlar/cik1-report.md
write_manifest:
  - .harness/goals/2026/G-20261118-CIKANLAR.md
  - runs/2026-11-18-cikanlar/
  - index.html
  - js/app.js
  - js/utils/handlers.js
  - js/ui.js
  - tests/gecmis-ux.spec.js
---

# G-20261118-CIKANLAR — Sürüden çıkan hayvanlar ekranı

## Sahip isteği (2026-11-18, birebir)
"tamam iş ufaksa onu uiya bağlayın çıkanların hepsini görelim sorgulayabilelim veya sadece çıkış yapanlar için bir tab verin geçmişte"

## Kapsam değişikliği (sahip 2026-11-18, bağlayıcı — aşağıdaki "Kapsam"ı ezer)
"çıkan hayvanları geçmiş ekranına bağlamak uzun sürecekse direkt kayıt ekranında buton yap geç uğraşma fazla sadece ölenler satılanlar vb ayrı tablar olsa yeter açılan modalda"
→ Kayıt ekranında tek düğme → modal, Ölü/Satıldı/Kesildi/Kayıp sekmeleri; ayrı sayfa/goTo/app.js/arama yok (brief ROOT RULING-2).

## Kapsam (ilk hali, yukarıdaki ezer)
- Ölü kalan `loadCikanlar()` (js/ui.js:12863) ayrı `#pg-cikanlar` sayfasına bağlanır; giriş Geçmiş sayfasındaki düğmeden (alt nav'a buton eklenmez).
- Liste `durum !== 'Aktif'` olan TÜM hayvanlar (çıkış alanı boş olanlar dahil); arama + durum çipleri; satır → `openDet(a.id)`.
- DB / RPC / migration değişikliği YOK. Geçmiş defterinin olay hattı (gecmis.js) değişmez.

## Ruling
- B-hafif yolu (k1-report §Öneri): Geçmiş olay hattına sekme eklemek gün-modu/defter/CSV ile iç içe → riskli; ayrı sayfa izole ve e0c1e85'te zaten vardı. Geçmiş'teki giriş düğmesi sahibin "geçmişte bir tab" isteğini karşılar.
- domain-rules §10: çıkmış hayvan aktif listede görünmez, arayüzden düzenlenmez → ayrı görünüm, salt-okuma.
- §1 K1 küpe recycle → detay `openDet(a.id)` ile, küpeyle değil.
