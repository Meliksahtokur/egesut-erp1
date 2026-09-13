---
id: G-20260913-TARIH-SECICI-R1
status: in_progress
owner: root
flow: ss_org
created: 2026-09-13
base_sha: 46abbc8
branch: agent/tarih-secici-standardi
worktree: /home/melik/.superset/worktrees/1dddb562-abe3-495c-970e-872567945510/agent/tarih-secici-standardi
report: .harness/reports/2026-09-13-tarih-secici-r1.md
write_manifest:
  - index.html
  - js/ui.js
  - js/forms.js
  - js/tarih/tarih.js
  - tests/unit/tarih-saf.test.js
  - tests/unit/vaka-toplu-ac.test.js
  - tests/tarih-secici.spec.js
  - .harness/goals/2026/G-20260913-TARIH-SECICI-R1.md
  - .harness/reports/2026-09-13-tarih-secici-r1.md
  - .claude/tasks/2026-09-13-tarih-secici-r1.md
  - .claude/tasks/2026-09-13-tarih-secici-r1-denetim.md
  - .claude/reviews/2026-09-13-tarih-secici-r1-teslim.md
  - .claude/reviews/2026-09-13-tarih-secici-r1-denetim.md
pattern_refs:
  - FORM-SUBMIT-01
  - MODAL-ROUTER-01
  - TESTING-01
pattern_exceptions: []
docs_authority:
  tracked_paths:
    write:
      - .harness/goals/2026/G-20260913-TARIH-SECICI-R1.md
      - .harness/reports/2026-09-13-tarih-secici-r1.md
      - .claude/tasks/2026-09-13-tarih-secici-r1*.md
      - .claude/reviews/2026-09-13-tarih-secici-r1*.md
review_lane: codex_luna_optional
implement_lane: glmf_workers
---

# G-20260913-TARIH-SECICI-R1 — Sahip testi revizyonu (5 bulgu)

- **Status:** IN_PROGRESS (2026-09-13, owner /goal directive)
- **Task envelope:** `/home/melik/egesut-erp1/.ss/tasks/R1-tarih-secici-revizyon.md`
  (verbatim authority)
- **Scope:** owner'un 5 test bulgusu — (1) ok boyut/kontrast/dokunma ≥40px,
  (2) masaüstü kompakt modal ≤~440px + mobil korunur, (3) el girişi maske +
  ayraç toleransı `, / - boşluk`→`.` + segment sınırları + inputmode +
  Enter=Uygula + geçerli girişte takvim o tarihe atlar + açıklayıcı hata,
  (4) başlıkta ay + yıl dropdown (Türkçe, min/max'a göre yıl aralığı; ‹ › kalır),
  (5) büyük puntolar. **Tüm tarih seçim ekranlarında** (tekTarihTakvimAc,
  bcTakvim*, caseGunModalRender). ASLA `mm/dd` yorumu yok.
- **Kapsam dışı:** main/entegrasyon (root), push, DB.

## Kısıtlar (owner /goal, 2026-09-13)

- Kendi dalda; worker yalnız glmf; luna codex OPSİYONEL (serbest).
- `git merge` YAPMA — entegrasyon root'ta.
- Commit mesajları `R1` içerir.
- `?v=` damga: runtime değişiyor → tüm kaynaklar TEK yeni değer AYNI commit'te
  (beklenen `20260913-17`).
- Guard (`tarih-saf.test.js` § F4): yeni takvim-semantikli fonksiyon adları
  beyaz listeye bilinçli eklenir; mevcut muhafızlar (type="date"=0, kopya
  sembol yasağı, saf katman) yeşil kalır.

## Acceptance (owner task dosyasından)

1. Unit: maske/normalize/segment saf testler (`11122026`→`11.12.2026`,
   `13,09,2026`→`2026-09-13`, `90.01.2026` red, `31.02.2026` red,
   `05.02.2026`→`2026-02-05`); tam suite yalnız bilinen `_gmGroupHtml` kırmızı.
2. Playwright: 1920×1080 modal genişliği ≤440px; 412×915 mobil mevcut davranış
   değişmedi; dropdown ile ay/yıl seçimi; elle `11122026` girişi.
3. Koruma testleri yeşil (F4 guard, type="date"=0, kopya takvim yok).
4. Rapor `.harness/reports/2026-09-13-tarih-secici-r1.md`; commit mesajında `R1`. Sonra dur.

## Stop conditions

- Mobil görünümde davranış değişikliği zorunlu hale gelirse → stop + root'a soru.
- Reader `.value`→ISO sözleşmesi riske girerse → stop + root'a soru.
- Masaüstü kompakt düzen bcTakvim çoklu-seçim UX'ini bozarsa → lead kararı
  (tek/çoklu için ayrı genişlik kabul edilebilir; raporda beyan).
