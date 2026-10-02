# Demo DB apply raporu — ovsync P1–P3b zinciri — 2026-09-30 23:10

Sahip kararı: "Uygula (önerilen)" (AskUserQuestion, 2026-09-30 22:57 — ölçümlü soru:
demo'da şablon altyapısı tam ama yeni RPC+kolon zinciri yoktu).

## Uygulanan dosyalar (worktree ovsync-takip dalındaki commit'li halleri)

| # | Dosya | Madde | Süre |
|---|---|---|---|
| 1 | `20260929000001_ovsync_takip_listele.sql` | P1 | 2 sn |
| 2 | `20260929000002_takip_gorev_ve_bos_devam.sql` | P2a+P2b | 4 sn |
| 3 | `20260929000003_takip_kapanis_tetikleyicileri.sql` | P3a+P3b | 7 sn |
| 4 | `20260929000004_tohumlama_gebelik_gorev_kaldir.sql` | P2c | 1 sn (sarmalı tx) |
| 5 | `20260929000005_gebelik_gorev_temizlik.sql` | P2d | 1 sn (sarmalı tx) |

1–3 kendi BEGIN/COMMIT'ini taşıdığından aynen beslendi (runbook #4 kuralı);
4–5 tek transaction'a sarıldı. Hepsinde `ON_ERROR_STOP=1`. Apply betiği ve
loglar: `/home/melik/tmp/demo-yedek-2026-09-30-ovsync/apply-*.log`.

## Runbook adımları

- **#2 Yedek** [OBSERVED]: `/home/melik/tmp/demo-yedek-2026-09-30-ovsync/` —
  gorev_ertele_kural 24 satır, gorev_log (3 hedef tip) 178, tohumlama 302 CSV;
  fonksiyon gövdeleri 2764 satır; 21 trigger tanımı; `MANIFEST.sha256`.
- **#3 Dry-run**: teslim sırasındaki db-validate + izole prova apply/rollback
  kanıtlarıyla karşılandı (madde DONE'ları + `reports/db-validation-*.md`).
- **#4 Apply**: 5/5 OK, toplam 15 sn [OBSERVED yukarıdaki tablo].
- **#5 Kayıt**: **BAKİYE** — demo DB'de `schema_migrations` tablosu YOK
  [OBSERVED `relation does not exist`]. Sürüm kaydı bu raporun tablosudur;
  tablo sahibi kararıdır (gerekirse ayrı kaleme).
- **#6 Ground-truth**: **BAKİYE** — GT dosyası prod yüzeyidir; P13'te sahibe
  GT yenileme talebi zaten planlı (plan.md:717).
- **#7 Doğrulama** [OBSERVED 23:12–23:14]:
  - RPC 3/3: `ovsync_takip_listele` + `tohumlama_bos_ve_devam` + `start_first_service_protocol`.
  - `gorev_log.takip_kapanis_nedeni` kolonu canlı.
  - Seed: TAKIP_MUAYENE | ertelenebilir=t | pencere_kurali=yok | asimi=7 (P2a birebir).
  - Tetikleyiciler: `trg_takip_ovsync_case_kapisi`, `trg_takip_pg_olay_kapisi`, `trg_takip_yeni_tohumlama_kapat`.
  - **P2d temizliği demo'da da çalıştı:** açık GEBELIK_KONTROL 41 → 1 (40 iptal;
    toplam iptal 60 → 100). Prod'daki "40 aday" deseninin demo ikizi.
  - ACL: yeni 2 RPC'de anon/PUBLIC EXECUTE = 0.
  - `veri-eslesme-kontrol.py hepsi`: SIZINTI=0; BULGU 57'nin hiçbiri ovsync/takip
    yüzeyine değmiyor (apply öncesi klon/veri artefaktları; ozet.json tarama).

## P12 bağlamı

- E2E (P12) demo modunda koşabilir: yeni RPC'ler + kolon + tetikleyiciler yerinde.
- Test verisi (OVSYNC_BASLAT 30 açık görev mevcut; tohumlama kayıtları var)
  P12 zarfının senaryo ihtiyacına göre kurulur — bu apply veri kurmaz.
- Sahibin demo görünümü: Görevler'de 40 bayat +21/+35 gebelik kontrol görevi
  kapanır (P2d'nin amacı bu); yeni takip ekranı `?demo` ile çalışır durumda
  (UI merge sonrası sahibe ayrıca gösterilir).

## PROD

PROD apply bu goal kapsamında YOK (sahip kapısı — goal DB authority hükmü aynen).
