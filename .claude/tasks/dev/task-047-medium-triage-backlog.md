# TASK-047 — Medium-Severity Triage Backlog (Fix Bekliyor)

**Durum:** ✅ NEREDEYSE TAMAMLANDI (2026-07-06) — 27 FE + 6/7 BE bug fixed/kapatıldı, sadece M-3(BE) kalıyor
**Öncelik:** Orta
**Tarih:** 2026-07-06

## Sonuç (2026-07-06 güncelleme)

- **Frontend (27/27):** Tamamı fixed veya no-action-gerekçeli kapatıldı. XSS kümesi (M-1,2,4,5,6) + 14 bağımsız hardening bug (M-10,12,14-18,21,23-26) hepsi commit'lendi (`6c2097d` + öncesi). M-13 incelendi, gerçek bug bulunmadı (no-action). M-9/M-22 zaten High triage kapsamında (duplicate).
- **Backend (6/7):** M-1 canlı veriyle yanlış alarm çıktı (no-action), M-2/M-4 fixed (`20260706000003_medium_be_fixes.sql`), M-5 bilinçli Faz 2 kapsamı (no-action şimdilik), M-6 fixed (SECURITY DEFINER→INVOKER, demo-test edildi, `20260706000004_m6_be_asistan_sql_invoker.sql`).
- **Kalan tek iş: M-3(BE)** `protokol_eksik_tara` N+1 perf rewrite — bkz. Task #4, ayrı tasarım/test gerektiriyor, henüz başlanmadı.

---

## Bağlam

`reports/omp-frontend-audit.md` + `reports/omp-backend-audit.md`'deki 34 Medium-severity bug (27 FE + 7 BE), OMP worker'ları (worktree-per-lane, `[write]` etiketli) tarafından koda karşı triage edildi. Sonuç raporları main'e push edildi:
- `reports/omp-triage-medium-fe.md` (27 FE bug)
- `reports/omp-triage-medium-be.md` (7 BE bug)

## Özet Sayılar

| Kaynak | CONFIRMED-REAL | FALSE-ALARM | DUPLICATE | Diğer |
|---|---|---|---|---|
| Frontend (27) | ~17 (kısmi/line-shift dahil) | birkaç | 3 (M-9,M-22 vb. High ile çakışıyor) | M-26 audit senaryosu yanlış ama farklı bug var |
| Backend (7) | 5 | 0 | 1 (M-7 → BUG-H-2 BE ile aynı) | M-3 audit'in kendi sayısı yanlış (3→4 kontrol) |

**Toplam ~23 CONFIRMED-REAL** fix bekliyor (duplicate'ler zaten High triage kapsamında, ayrıca fix gerekmez).

## Öne Çıkan Backend Bulgular (SQL, orta risk)

- **M-1 (BE):** `_trg_hayvan_cikis_gorev_iptal` — `gorev_tipi` whitelist yok, "gerekli" görevler de iptal ediliyor. Kardeş: BE-H-3 (aynı whitelist-tutarsızlığı ailesi, ayrı trigger).
- **M-2 (BE):** `padok_degistir_toplu` — `p_yeni_grup=NULL` ise grup-uyum guard'ı tamamen atlanıyor.
- **M-3 (BE):** `protokol_eksik_tara` N+1 performans (hayvan başına ~4-32 iç sorgu) — materialized view önerisi (DEV-5).
- **M-4 (BE):** `tedavi_guncelle` — islem_log INSERT yok (BE-H-1'in kardeşi, farklı RPC — `tedavi_sil` zaten fix edildi, bu ayrı).
- **M-5 (BE):** RLS `USING(true)` yaygın (30+ policy) — bilinçli Faz 2 kapsamı, aksiyon gerekmiyor şimdilik.
- **M-6 (BE):** `asistan_sql_calistir` SECURITY DEFINER + RLS bypass riski (guard'lar var ama subquery injection açığı var).

## Öne Çıkan Frontend Bulgular

- 6/27 XSS/XSS-adjacent (M-1..M-6) — `.replace(/'/g,...)` anti-pattern, inline onclick, raw template. Dataset+delegated-listener göçü tamamlanmamış (Critical #3'ün devamı niteliğinde).
- §4.1 ihlalleri (M-7, M-11, M-15, M-26) — backend'de olması gereken kurallar frontend'de hard-coded/eksik.
- M-26: audit senaryosu yanlış ama aynı fonksiyonda gerçek bir bug var (localStorage parse try/catch eksik).

## Sonraki Adım

Fix sırası/lane dağılımı belirlenmedi — kullanıcı onayı sonrası:
1. Backend SQL'ler (M-1,2,4,6) → Claude'un kendi lane'i (canlı-doğrulama + draft/onay gerektirir, BE-H serisiyle aynı disiplin)
2. Frontend XSS kümesi (M-1..M-6) → OMP worktree-per-lane adayı (H-serisi XSS fix'lerine benzer, disjoint OWNS ile bölünebilir)
3. M-3 (performans), M-5 (RLS/Faz 2) → mimari kapsam, ayrı görüşme

## İlgili Dosyalar

- `reports/omp-triage-medium-fe.md`
- `reports/omp-triage-medium-be.md`
- `.claude/knowledge/bugs.md` (BE-H-3, dormant trigger — M-1 BE ile aynı aile)
- Native memory: `project-fullstack-audit-2026-07-05.md`
