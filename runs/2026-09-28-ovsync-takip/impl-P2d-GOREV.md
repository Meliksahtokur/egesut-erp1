# impl-P2d — GOREV zarfı: açık +21/+35 GEBELIK_KONTROL görevlerinin veri temizliği

- **Goal:** `G-20260930-OVSYNC-TAKIP-IMPL` (active)
- **Plan madde:** **P2d** — `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:360-376` (MADDE DRIFT KAPISI: yalnız P2d; P3a tetikleyicileri YOK)
- **GOREV (bu dosya):** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P2d-GOREV.md`
- **DONE:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P2d-DONE.md`

## Yazma manifesti (TEK YAZICI — liste dışı YASAK)

1. `supabase/migrations/20260929000005_gebelik_gorev_temizlik.sql` (create)
2. `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P2d-DONE.md` (create)

Prova betikleri `/home/melik/tmp/agents/` altına (repo dışı).

## Zorunlu davranış protokolü

1. **İLK İŞ:** `/home/melik/.claude/skills/using-superpowers-obra/SKILL.md` oku ve uygula (sahip kuralı; SUBAGENT-STOP geçersiz).
2. **SQL yazmadan ÖNCE:** `.harness/references/domain-rules.md` oku; çelişkide dur.
3. **PostgreSQL LSP zorunlu** (false-positive sınıfları zarf geçmişiyle aynı: p_* parametreler, ayna-PROD-öncesi, `\` meta-komutlar).
4. **db-validation KAPISI:** WORKTREE İÇİ yol; taslakta PASS.
5. **Bitiş kapısı:** `verification-before-completion-obra` — her iddia [CONFIRMED dosya:satır]/[OBSERVED komut] etiketli.

## Görev (plan P2d birebir — plan.md:360-376)

Migration `20260929000005_gebelik_gorev_temizlik.sql` — veri temizliği (kod fix'ten AYRI kalem):

- **Seçim ölçütü (deterministik):** `gorev_tipi='GEBELIK_KONTROL' AND NOT tamamlandi AND NOT iptal AND kaynak LIKE 'TOH-%'` (cron kaynağı `GEBELIK-KONTROL-` önekli olduğundan ayırt eder); açıklama `IN ('21. Gün gebelik kontrolü','35. Gün gebelik kontrolü')` çapraz doğrulama — **kaynak-öncelikli ölçüt** (açıklama uyuşmazsa kaynak kazanır; DONE'a belgele).
- **ÖNCE SAY (demo):** temizlik öncesi `SELECT count(*), ... GROUP BY aciklama` prova çıktısı DONE'a (kaç aday, hangi eşikler). P2c DONE'ında demo'da 42 açık eski görev notu vardı — sayım bunu doğrulamalı.
- **Sonra iptal:** `UPDATE gorev_log SET iptal=true` + iptal izi `islem_log` kaydı (`tip='GOREV_GUNCELLENDI'`, snapshot: adet + ölçüt + `'§10d #1 veri temizliği'`). **Idempotent:** ikinci koşum 0 satır.
- **Çift görev kabulü:** temizlik sonrası eşik dolmuş hayvana cron ertesi sabah TEK görev doğar (`NOT EXISTS` açık görev koşulu); provada aynı hayvanda açık GEBELIK_KONTROL sayısı ≤1.
- **PROD apply: SAHİP KAPISI — bu zarfta YOK.** Demo provası rollback içinde ya da toplu-apply-kapısı deseni (P1/P2a/P2b/P2c kalıbı: prova sonrası eski duruma restore; resmi apply toplu kapıda). Runbook `.harness/runbooks/db-migration.md` PROD aşamasında.

## Kabul ölçütleri (plan P2d "Kabul" birebir — plan.md:374)

1. `scripts/db-validate.sh` (worktree yolu) taslakta **PASS** (rapor worktree `reports/` altında).
2. Demo: SAY çıktısı DONE'da (aday sayısı + eşik dağılımı).
3. İptal sonrası açık +21/+35 = 0 (aynı ölçütle yeniden sayım = 0) [OBSERVED].
4. Cron tek görev doğuyor (P2c kabulüyle birlikte ölçülür — eşik dolmuş aday hayvanda `gebelik_muayene_gorev_uret(false)`; aynı hayvanda açık GEBELIK_KONTROL ≤1).
5. Idempotency: ikinci koşum 0 satır [OBSERVED].
6. `git diff --check` temiz; islem_log izleri snapshot alanlı.

## Yasaklar

- PROD erişimi/apply (SAHİP KAPISI); push/merge/deploy; commit atma (mimar toplar).
- `.ss/`, `main`, manifest dışı repo dosyası; P3a tetikleyici/cycle_guard işi (ayrı madde).
- Demo temizliğini KALICI apply etme — prova deseni (restore/rollback); resmi demo apply'sı toplu kapıda.
- Sessiz varsayılan; en fazla 2 self-repair turu sonra DONE'a BLOKE yaz.

## DONE şablonu

Başlık: `impl-P2d-DONE — TAMAM|KISMI|BLOKE` · kabul maddeleri (6) tek tek kanıtlı · SAY çıktısı + idempotency + cron prova kanıtları · yazılan dosyalar · açık kalem.
