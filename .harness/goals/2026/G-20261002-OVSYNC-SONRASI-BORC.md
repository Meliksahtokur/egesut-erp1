# G-20261002-OVSYNC-SONRASI-BORC — Ovsync takip sonrası borç turu

- **id:** G-20261002-OVSYNC-SONRASI-BORC
- **status:** active
- **owner:** Melik Şah Tokur (2026-10-02 sıra/kapsam onayı: önerilen sıra tümü; TB-1 arşivle; UI kapısı ss-worker-sonnet-medium koltuğu; prod YALNIZ-OKUMA serbest)
- **flow:** Full mode, mimar oturumu + builtin subagent zarfları (sonnet/haiku; opus worker yok; ultracode YASAK); UI tarayıcı kapısı herdr ayrı tab ss-worker-sonnet-medium
- **base SHA:** `ffdc342`
- **branch:** `ovsync-sonrasi`
- **worktree:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-sonrasi`
- **görev zarfı:** `runs/2026-10-02-ovsync-sonrasi/BASLANGIC-PROMPTU.md` (ana checkout)
- **kaynak borç listesi:** `.harness/goals/2026/G-20260930-OVSYNC-TAKIP-IMPL.md` "teknik borç" (TB-1..TB-7) + B9 backlog + GT refresh bakiyesi
- **kalemler (madde numaralı — her alt zarf bir kalem numarasına referans verir):**
  1. **B9** `gebelik_muayene_gorev_uret` cron saati — prod yalnız-okuma ölçüm (cron.job schedule, son üretilen GEBELIK_KONTROL hedef_tarih ↔ created_at TR günü). Kabul: ölçüm tablosu + hüküm (kayma VAR/YOK). Kayma varsa Istanbul yerel gün kalıbıyla (migration 20261001000001 deseni) migration taslağı + db-validate PASS + demo prova; PROD apply sahip kapısı.
  2. **GT refresh** — runbook `.harness/runbooks/db-migration.md` adım 6, 2026-10-02 prod'a giden 6 migration'ın nesneleri GT'ye; `Tarih:` başlığı. Kabul: GT diff + commit.
  3. **TB-6** `tests/e2e/ovsync-takip.spec.js` `temizle()` — kupe_no ile arar, silme hatalarını raporlar (fail-closed), FK'lı hayvanı `Satildi`'ye çeker. Kabul: temizlik sonrası E2E-* aktif 0; e2e 12/12 (A/B ile).
  4. **TB-1** eski otomatik ui-tur betiği ARŞİV (sahip kararı) — kopya + arşiv notu `runs/2026-10-02-ovsync-sonrasi/arsiv-tb1/`; triyaj yok. Kabul: arşiv notu.
  5. **TB-5** `_pg_kapi_detay`'a `karar` alanı (migration) + UI'nın sunucu kararını göstermesi. Kabul: db-validate PASS, demo prova, birim/e2e, UI kapısı; PROD apply sahip kapısı.
  6. **TB-7** S0 "TAI bugün/yarın" demo tarayıcı kanıtı (fixture). Kabul: koltuk PASS + ekran görüntüsü.
  7. **TB-3** ovsync render zaman aşımı + hata dalı (TDD). Kabul: kırmızı→yeşil birim + node --check.
  8. **TB-2** demo `demo_sema_diff` RPC 401 — sahiplik/izin teşhisi + düzeltme önerisi/uygulaması. Kabul: kök neden kanıtı; düzeltme demo'da konsol 401 yok.
  9. **TB-4** KAPSAM DIŞI (tools-bank; ram-pool sahip kararıyla deaktif 2026-10-01) — root'a not.
- **write manifest (tek yazıcı per dosya; her zarf kendi alt listesini taşır):**
  - `supabase/migrations/202610020*.sql` (kalem 1, 5; kalem 8 gerekirse)
  - `js/ui.js` (kalem 7, ardından kalem 5 — SIRALI), `js/api.js` (yalnız kalem 5/8 gerektirirse), `index.html` (`?v=` damgası yalnız JS değişince)
  - `tests/e2e/ovsync-takip.spec.js` (kalem 3), `tests/unit/ovsync-*.test.js` (kalem 5, 7), `tests/sql/ovsync_takip_test.sql` (kalem 5)
  - GT dosyası (kalem 2; yol zarfında)
  - bu goal dosyası
- **local paths:** `runs/2026-10-02-ovsync-sonrasi/*` (ana checkout: zarf/DONE/ILERLEME), `.crumbs/ovsync-sonrasi.jsonl`
- **DB authority:** prod YALNIZ-OKUMA (SELECT) serbest (sahip 2026-10-02). Demo prova apply/rollback db-validate PASS sonrası serbest. PROD apply / merge / push SAHİP KAPISI (root üzerinden talep belgesi). Demo sahip şifresi değiştirilmez.
- **pattern_refs:** RPC-WRITE-01 (kalem 5), TESTING-01 (kalem 3, 6, 7), mevcut migration REVOKE-anon şablonu; Istanbul yerel gün kalıbı `supabase/migrations/20261001000001*`.
- **acceptance commands:** `scripts/db-validate.sh` her migration; `node --check` değişen JS; birim koşumu (baseline 1491/1489/2); hedefli Playwright Docker `mcr.microsoft.com/playwright:v1.58.2-noble --network host`; e2e kırmızısı A/B ile; `git diff --check`; sahibe demo öncesi koltuk UI kapısı PASS + `kupe_no LIKE 'E2E-%'` aktif 0.
- **stop conditions:** push/merge/PROD apply YASAK; `.ss/` yazma YASAK; domain-rules çelişkisi → dur, sahibe; db-validate'siz migration teslimi yok.
- **report path:** `runs/2026-10-02-ovsync-sonrasi/DONE.md` (+ `ILERLEME.md`)
- **latest checkpoint:** 2026-10-02 — goal açıldı, sahip sıra/kapsam onayı alındı.
