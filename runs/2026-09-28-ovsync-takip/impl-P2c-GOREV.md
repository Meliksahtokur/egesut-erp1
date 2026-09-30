# impl-P2c — GOREV zarfı: `tohumlama_kaydet`'ten +21/+35 g GEBELIK_KONTROL üretiminin kaldırılması

- **Goal:** `G-20260930-OVSYNC-TAKIP-IMPL` (active)
- **Plan madde:** **P2c** — `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:344-358` (MADDE DRIFT KAPISI: yalnız P2c; P2d veri temizliği AYRI madde — yapma)
- **GOREV (bu dosya):** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P2c-GOREV.md`
- **DONE:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P2c-DONE.md`

## Yazma manifesti (TEK YAZICI — liste dışı YASAK)

1. `supabase/migrations/20260929000004_tohumlama_gebelik_gorev_kaldir.sql` (create)
2. `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P2c-DONE.md` (create)

Prova betikleri `/home/melik/tmp/agents/` altına (repo dışı).

## Zorunlu davranış protokolü

1. **İLK İŞ:** `/home/melik/.claude/skills/using-superpowers-obra/SKILL.md` oku ve uygula (sahip kuralı; SUBAGENT-STOP geçersiz).
2. **SQL yazmadan ÖNCE:** `.harness/references/domain-rules.md` oku; çelişkide dur.
3. **PostgreSQL LSP zorunlu:** hover/typecheck/completion (false-positive sınıfları: p_* parametreler, ayna-PROD-öncesi yeni nesneler, `\` meta-komutlar).
4. **db-validation KAPISI:** WORKTREE İÇİ yol; taslakta PASS.
5. **Bitiş kapısı:** `verification-before-completion-obra` — her iddia [CONFIRMED dosya:satır]/[OBSERVED komut] etiketli.

## Görev (plan P2c birebir — plan.md:344-358)

Migration `20260929000004_tohumlama_gebelik_gorev_kaldir.sql`:

- `tohumlama_kaydet`'in GÜNCEL gövdesi (kaynak: `supabase/migrations/20260923000005_*.sql`, `CREATE OR REPLACE`) **birebir yeniden tanımlanır**; **yalnız :438-444'teki iki GEBELIK_KONTROL INSERT'i çıkar**. Gövdenin geri kalanı birebir: VWP/islem_log, `protokol_instance` INSERT :434-436 KALIR, sperma stok, ek uygulama, eski-Bekliyor kapatma döngüsü :372-407.
- ACL satırları aynen taşınır: `REVOKE ... PUBLIC, anon` + `GRANT authenticated, service_role` (mevcut grant'ler korunur).
- **DİKKAT:** mevcut canlı gövde migration'dan farklı olabilir — önce `pg_get_functiondef` ile CANLI DEMO gövdesini oku, çıkarma işlemini canlı gövde üzerinden yap (LSP aynası/izole baseline; kaynak migration referans). Canlı ≁ migration çelişkisinde dur ve DONE'a yaz.

## Kabul ölçütleri (plan P2c "Kabul" birebir — plan.md:356)

1. `scripts/db-validate.sh` (worktree yolu) taslakta **PASS** (rapor worktree `reports/` altında).
2. **Demo prova:** yeni tohumlama kaydı sonrası o hayvanda GEBELIK_KONTROL görevi DOĞMAZ — prova SQL: tohumlama → `SELECT count(*) FROM gorev_log WHERE hayvan_id=... AND gorev_tipi='GEBELIK_KONTROL' AND NOT iptal` = 0 [OBSERVED].
3. **Cron ≥40 g dolduğunda görev doğar:** `gebelik_muayene_gorev_uret(false)` aday hayvanda koşulur; çift görev oluşmaz (cron `NOT EXISTS` açık görev koşulu [20260925000002:352-354]).
4. `protokol_instance` UREME/TOHUMLAMA kaydı hâlâ kurulur (bağ kopmaz) [OBSERVED].
5. Gebe/Boş sonucunun tip-bazlı iptal filtresi cron görevini kapatır (K15 — muayene yolu görev önce tamamlar, çakışma yok).
6. `git diff --check` temiz; anon/PUBLIC EXECUTE değişimi yok (mevcut ACL korunur).

**Ground-truth notu:** `99999999999999_ground_truth.sql` eski +21/+35 üretimini de taşıyor → P13 replay doğrulamasına P2c dahil (son-kazanan yeni gövde olmalı). Bu madde bunu SİMÜLE ETMEZ — yalnız DONE'a not eder.

## Yasaklar

- PROD erişimi/apply; push/merge/deploy; commit atma (mimar toplar).
- `.ss/`, `main`, manifest dışı repo dosyası (20260929000002 dahil — o P2a/P2b'nin dosyası).
- P2d veri temizliği (DELETE/UPDATE mevcut görevler) — AYRI madde, bu zarfta yok.
- Sessiz varsayılan; en fazla 2 self-repair turu sonra DONE'a BLOKE yaz.

## DONE şablonu

Başlık: `impl-P2c-DONE — TAMAM|KISMI|BLOKE` · kabul maddeleri (6) tek tek kanıtlı · yazılan dosyalar · ölçüm komutları + çıktı özetleri · açık kalem.
