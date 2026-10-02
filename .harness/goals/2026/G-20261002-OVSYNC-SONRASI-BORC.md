# G-20261002-OVSYNC-SONRASI-BORC — Ovsync takip sonrası borç turu

- **id:** G-20261002-OVSYNC-SONRASI-BORC
- **status:** done (2026-10-02 — CANLI: PROD 20261002000002 + merge 9a48b8a + push; açık kalanlar aşağıda "teknik borç" TB-8..TB-17)
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
- **latest checkpoint:** 2026-10-02 — 9 kalem kapandı (TB-4 kapsam dışı). Commitler: 9ecd6a0 GT · d6ea1dd TB-3 · f9ca7b6 TB-2 · bf35723 TB-5 SQL · 20766cb TB-5 UI test · b986755 damga ?v=20261002-02 · 626e3ee+5e8466e TB-6 e2e. Kanıt: birim 1511/1509/2 (baseline kırmızılar), e2e ovsync-takip 12/12 ×2, UI kapısı (sonnet-medium koltuk) 12/12 PASS, db-validate e98ae410 PASS, demo apply 20261002000002 + schema_migrations kaydı. B9: kayma yok (cron TR 08:10). Rapor `runs/2026-10-02-ovsync-sonrasi/DONE.md`.
- **canlı checkpoint (root, 2026-10-02):** denetim KABUL (sonnet code-reviewer; 3 KÜÇÜK → TB-16) · GH DB Backup 36972508679 → prod prova temiz (sayım farkı 0) → PROD apply `20261002000002` + `schema_migrations` (160) → `_pg_kapi_detay` prod=demo md5 `dc51bc38…`, anon/authenticated EXECUTE yok → `veri-eslesme-kontrol.py hepsi` temiz (işaret 57 taban) → merge `9a48b8a` + hasat `3a3669b` push → Pages `?v=20261002-02` canlı. Dal silindi (tag `backup/2026-10-02-ovsync-sonrasi-dal-ucu`); worktree kalıntıları sahip tarafından silindi. Loglar `/home/melik/tmp/ovsync-sonrasi-prod-2026-10-02/`.
- **teknik borç (devir 2026-10-02, AÇIK — kaynak `runs/2026-10-02-ovsync-sonrasi/DONE.md` "Açık kalemler" + root denetimi):**
  - **TB-8 GT bakiyesi:** 2026-09-15..09-27 dönemi 79 `ground-truth-audit` farkı — 2 eksik tablo (`gorev_ertele_kural`, `pg_application_event`), 34 fonksiyon, 41 trigger bağı. Ayrı GT senkron kalemi (runbook adım 6, mekanik).
  - **TB-9 UX — ilk IDB pull:** Üreme/Tohumlama listesi ilk pull sırasında "Arama sonucu yok" gösteriyor; "yükleniyor" durumu ayrılmıyor.
  - **TB-10 IDB konsol uyarısı:** Boş bağlamı ilk pull'da `IDBObjectStore put key path` uyarısı (kök UNKNOWN).
  - **TB-11 seans ✓ butonu:** vaka detayında `seansTamamla` butonu tarayıcı turunda bulunamadı (T8 fonksiyon doğrudan çağrılarak kanıtlandı) — UI'da erişilebilirliği kontrol.
  - **TB-12 `vaka_toplu_ac` PG etiketi:** `js/forms.js:3295` satırında `pgKarar: null` → bu yolda PG karar etiketi gösterilmiyor (TB-5 sunucu kararı buraya bağlanmadı).
  - **TB-13 TB-3 artığı:** yeniden yüklemede spinner yerine eski içerik kalıyor (hata dalı zamanında geliyor); `ovsyncTakipGetir` ağ çağrısının askıda kalma riski zaman aşımı kapsamı dışında.
  - **TB-14 B9 savunma (opsiyonel):** `gebelik_muayene_gorev_uret` CURRENT_DATE (UTC); cron TR 08:10'da olduğu için bugün kayma yok, elle TR 00–03 çağrısına karşı Istanbul yerel gün kalıbı (`20261001000001`) eklenebilir.
  - **TB-15 araç:** `gitnexus_impact` `/root/egesut-erp1` izin hatası (indeks yolu yanlış kökte).
  - **TB-16 denetim KÜÇÜK bulguları (root, 2026-10-02):** (a) `js/demo.js:51-56` `onAuthStateChange` geri çağrısı `abone` const'una atamadan önce erişebilir (TDZ ReferenceError sessiz yutulur, abonelik temizlenmez); (b) `js/demo.js:42-58,63` `catch (_) {}` / `if (error || !data) return` sessiz yutma — demo-özel, görünürlük için hata kaydı; (c) `js/ui.js:889-899` zaman aşımında askıdaki IDB okumaları arka planda sürer (ezmez; bilgi notu).
  - **TB-17 demo kalıntısı:** demo DB'de 12 `E2E-*` test hayvanı `Satildi` durumunda (`pg_application_event` FK silmeyi engelliyor) — kalıcı temizlik stratejisi (FK'lı kayıtlarla birlikte silme ya da arşiv).
  - **TB-4 (tools-bank) ram-pool slot sızıntısı:** bu repoda değil → ticket `tools-bank/docs/goals/2026-10-02-ticket-ram-pool-slot-sizintisi.md` (`0f9f2644`; kancalar kapalı ama daemon 4 suspect slot tutuyor).
