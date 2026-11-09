# L-DB ortak kurallar (her D brief'i için bağlayıcı)

- Worktree / dal: `~/.herdr/worktrees/egesut-erp1/ovsync-tren` (`ovsync-tren`). Tüm komutlar mutlak yolla.
- Plan (bağlayıcı): `~/.herdr/worktrees/egesut-erp1/ovsync-tren/docs/plans/2026-11-09-ovsync-tren/PLAN.md`
  — "Global Constraints", "Önceden cevaplanmış kararlar", "Ruling'ler" (R1–R20), "N1 — L-DB" (ortak kabul koşumu + senaryo
  izolasyonu sözleşmesi + senin D bölümün), "Kapı tur 2 ekleri". Spec: aynı klasörde `design.md`.
- Domain ZORUNLU okuma: `~/.herdr/worktrees/egesut-erp1/ovsync-tren/.harness/references/domain-rules.md` §5 ve §18.
  Çelişki görürsen DUR, report'a `SORU:` yaz.
- Lead ruling'leri: `~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/progress.md` "Lead Ruling'leri" (RL-*) bağlayıcı.
- Prod gövde kanıtı (taban): `~/.herdr/worktrees/egesut-erp1/tedavi-arge/runs/2026-11-09-ovsync-toplu-gun/kanit/fn/*.sql`
  ve md5 tablosu `~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/govde-taban.md` (D0 çıktısı).
  Gövdesi değişen her mevcut fonksiyon bu gövdeden kopyalanır, yalnız planın söylediği satırlar değişir; migration başında
  md5(prosrc) koruması (`supabase/migrations/20261031200007_vaka_sablon_pg_kapi.sql:21-23` kalıbı, `<FN>_GOVDE_FARKLI`).
- Kabul koşumu (RL-5: `EGESUT_REPO` VERİLMEZ):
  ```
  cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren
  bash scripts/kabul-db/build.sh            # görev başına bir kez; egesut_ovsync_kabul'u prod şemasından verisiz kurar
  ( echo 'BEGIN;'; cat <seri dosyaları sırayla> supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) \
    | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
  bash ~/egesut-erp1/scripts/db-validate.sh <worktree>/supabase/migrations/<bu görevin dosyası> --priors <önceki seri dosyaları, mutlak>   # RL-8: worktree'de .env yok → ana checkout betiği (diff -q aynı)
  grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql   # çıktı yok
  ```
- DB yazma: YALNIZ yerel `egesut_ovsync_kabul` (ve db-validate'in kendi geçici DB'si). Prod/demo'ya YAZMA YOK. Prod/demo okuma yalnız
  Management API `read_only:true` SELECT (token: `~/egesut-erp1/.env` `SB_MGMT_TOKEN`; demo `SUPABASE_DEMO_REF`/`SUPABASE_DEMO_PAT`).
- Test-önce: önce kabul betiğine testleri yaz, koş, beklenen FAIL'i report'a koy; sonra uygula, PASS.
- ACL: her yeni/yeniden yaratılan fonksiyonda `REVOKE ALL … FROM PUBLIC, anon;`; dışa açık RPC `GRANT EXECUTE … TO authenticated;`;
  iç yardımcı ayrıca `REVOKE … FROM authenticated`. `CREATE OR REPLACE` edilen mevcut RPC'lerde aynı satırlar dosya sonunda.
- Tarih yalnız TR: `(now() AT TIME ZONE 'Europe/Istanbul')::date`; yeni/değişen gövdede `CURRENT_DATE` yok.
- Commit (RL-3): kendi dosyaların, `git add <dosya>` dosya dosya (`-A`/`.`/`-u` YASAK); `git diff --cached --stat` ile yalnız
  kendi dosyalarının staged olduğunu doğrula (aynı worktree'de mockup kulvarı `runs/2026-11-09-ovsync-tren/mockup/**` yazıyor —
  ona ve `js/`, `index.html`'e DOKUNMA). Push YOK. Commit mesajı sonu:
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
- Report: brief'teki `report:` yoluna; ilk satır `⟦ss-sub model=opus effort=high rol=ss-worker-high iş=<görev>⟧`, sonra `sonuc: TAMAM|KISMI|BLOKE`,
  `## Kırıntılar`, `## Run sonuçları` (komut + rc + son satır, ham), `BOYUT: <eklenen üretim SQL satırı> / <bütçe>` (aşım varsa gerekçe),
  commit SHA'ları, kanıt etiketleri (CONFIRMED/OBSERVED/MEASURED/INFERRED/UNKNOWN). Çıplak `report.md` yasak.
- `/tmp` YASAK; geçici dosya `$HOME/tmp/ovsync-tren-db/`.
- Bitince: `gitnexus analyze --index-only ~/.herdr/worktrees/egesut-erp1/ovsync-tren` koşma — L-DB yalnız SQL yazıyor, lead kulvar sonunda koşar.
