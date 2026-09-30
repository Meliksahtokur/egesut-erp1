# impl-P1-DONE — TAMAM

- **Görev:** `ovsync_takip_listele(p_padok text DEFAULT NULL, p_sonlanan_gun int DEFAULT 60) RETURNS jsonb` salt-okunur RPC migration'ı (plan v7 P1, `G-20260930-OVSYNC-TAKIP-IMPL`)
- **Migration:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000001_ovsync_takip_listele.sql` — SHA-256 ilk 8: `32caeed4` [OBSERVED `sha256sum`]
- **Dal:** ovsync-takip (değişmedi) · **Commit YOK** (mimar devir topluyor — zarf emri)
- **Self-repair turu:** 1/2 kullanıldı (Faz B uyum biçimlendirmesi; kapı 1. koşum INCONCLUSIVE → 2. koşum PASS). Semantik değişiklik yok — bkz. §5.

## Kabul ölçütleri (zarf 6 madde, tek tek kanıt)

### 1. `scripts/db-validate.sh` taslakta PASS — ✓
- [OBSERVED `bash scripts/db-validate.sh <migration>`] → `SONUÇ: PASS`, rapor `/home/melik/egesut-erp1/reports/db-validation-32caeed4.md` (SHA-256 eşleşmeli: rapor SHA `346af96b`→`32caeed4` 2. koşum; taze `sha256sum` = `32caeed46d918f55`).
- Rapor içi fazlar: A.sqlfluff-parse PASS (0 parse hatası; dosya 31 KB — sqlfluff 20 KB limitinden atladı, gerçek parse kanıtı C1 apply'da), A.squawk PASS (0 ihlal), B.sema-uyum PASS (tüm FROM/JOIN hedefleri biliniyor), C1.migration-apply PASS (psql ON_ERROR_STOP hatasız), C1.postcheck-nesne PASS, C1.postcheck-rls PASS (RLS farkı yok), C1.ortam-paritesi PASS (parite=uyumlu, prod_pg=17.6/yerel=17.6), C2.sentetik-tohum + C2.veri-uyumluluk PASS.
- Not: kapının `db-build-baseline.sh` alt bileşeni salt-okunur Mgmt API şema çekimi yapar (kapının kendi belgeli sözleşmesi); PROD veri sorgusu yapılmadı (zarf yasağı veri-erişim içindir).

### 2. Demo prova: apply → açık+kapalı bayrak yolu → rollback — ✓
- [OBSERVED apply] `psql -v ON_ERROR_STOP=1 -f <migration>` (demo pooler, .env'den kimlik okundu, değerler basılmadı) → `COMMIT`.
- [OBSERVED açık yol] `SELECT public.ovsync_takip_listele()` → `{"ok": true, "kpa": {"aktif": 0, "bugun": 0, "geciken": 0, "muayene_bekleyen": 1, "bekleyen_baslatma": 30, "bekleyen_baslatma_takipte": 0}, "esikler": {"muayene_gun": 40, "pencere_gun": 2}, "bayrak_kapali": false}`; satır dağılımı S2:1 + S3:30 (toplam 31).
- [OBSERVED kapalı yol] tek transaction içinde `UPDATE protokol_ayar SET deger=0` → `SELECT …takip_listele()` → `{"ok": true, "satirlar": [], "bayrak_kapali": true}` → `ROLLBACK` (zarf biçimi birebir; bayrak canlıda 1'e döndü, pencere kapanmadı).
- [OBSERVED rollback ölçümü] `DROP FUNCTION public.ovsync_takip_listele(text, integer)` → 0.8 s; `pg_proc` sayımı `0`. Prova sonunda tekrar `DROP FUNCTION IF EXISTS` + `fonksiyon_kaldi=0` — demo temiz teslim edildi; `cases`=148, `tohumlama`=302 değişmedi [OBSERVED].

### 3. Anon EXECUTE yok (demo canlı sorgu) — ✓
- [OBSERVED demo] `has_function_privilege`: `anon|f`, `authenticated|t`, `service_role|t`.
- [CONFIRMED migration:622-623] `REVOKE ALL … FROM PUBLIC, anon, authenticated` + `GRANT EXECUTE … TO authenticated, service_role` (kalıp 20260926000003:106-107; anon GRANT yazılmadı).

### 4. KPA sayıları mevcut PROD envanteriyle nokta-doğrulama (PROD canlı sorgu YOK) — ✓
- [CONFIRMED runs/2026-09-28-ovsync-takip/db-ovsync-durum-raporu.md §2.3] "44 görevin … 30'u açık (iptal=false, tamamlandi=false)" ↔ [OBSERVED demo RPC] `bekleyen_baslatma=30` — birebir.
- [OBSERVED] `muayene_bekleyen=1` ↔ `gebelik_muayene_listele()` demo kümesi = 1; küme eşitliği madde 5'te fark=0 ile ayrıca kanıtlı.
- **Demo klon farkı (belgelendi):** demo klonunda `protocol_family='OVSYNC'` vakası yok [OBSERVED demo: `SELECT count(*) FROM cases WHERE protocol_family='OVSYNC'` → 0, toplam cases 148]; PROD raporundaki 12 aktif / 23 sonlanan vaka demo verisinde bulunmadığından `aktif/geciken/S4` gerçek veride 0 çıktı. Bu yolların veriyle doğrulaması sentetik BEGIN..ROLLBACK provasıyla yapıldı: [OBSERVED] sentetik aktif vaka + günler (tamam/planli/gecikti) + şablon-TAI görevi + 2 kapalı vaka + TAKIP_MUAYENE görevi → `kpa {aktif:1, geciken:1, muayene_bekleyen:1, bekleyen_baslatma:31, bekleyen_baslatma_takipte:1}`; bolum dağılımı `S0:1, S2:1, S3:31, S4:2`.
- [OBSERVED örnek satırlar] S0 (küpe 904): `tai{durum:planli, kaynak:sablon, hedef 2026-10-10}`, `gunler[3]` tamam/planli/gecikti, `gecikme_gun:1`, `sonraki_gun:2`, `dalga_anahtari:start_date` (görevsiz açılış davranışı) · S2 (küpe 176): `muayene{kalan_gun:0}` (S-9 sınırı: "muayene vakti"), `muayene_gorev_id` dolu (K15), `deneme_sayisi:3` (K13) · S3 (küpe 200/142): `takip{gorev_id, hedef_tarih, hedef_saat}` (§6c.5) · S4 (küpe 191): `toh_sonuc:'Gebe'` (K6 köprü), `close_reason:'ESKI'` (NULL→ESKI, §7.4) · S4 (küpe 155): `toh_sonuc:'bilinmiyor'` (§7.5), `close_reason:'TOHUMLAMA'` korunumu.

### 5. T-45: S2 kümesi ≡ `gebelik_muayene_listele` + cooldown prova + farm_id grep — ✓
- [OBSERVED demo] `rpc_S2=1`, `gebelik_muayene_listele=1`, `rpc_olmayan_gml=0`, `gml_olmayan_rpc=0` → fark=0.
- [CONFIRMED migration] 5 predicate kaynakla bayt-bayt aynı [OBSERVED grep karşılaştırma, kaynak `supabase/migrations/20260925000002_sessiz_siniflandirma.sql:305-320`]: (1) `t.sonuc='Bekliyor'`, (2) `t.tarih <= CURRENT_DATE - _ayar('sessiz_tohumlama_muafiyet_gun', 40)::int`, (3) `h.cinsiyet='Dişi' AND h.durum='Aktif' AND h.kisir IS NOT TRUE`, (4) son tohumlama `ORDER BY t2.tarih DESC NULLS LAST, t2.created_at DESC NULLS LAST LIMIT 1`, (5) 30 g cooldown `NOT EXISTS (gorev_log g WHERE g.kaynak='GEBELIK-KONTROL-'||t.id AND g.tamamlandi=true AND g.tamamlanma_tarihi >= (CURRENT_DATE-30))`. `CURRENT_DATE` kasıtlı — kaynak fonksiyonla birebir (RPC'nin geri kalanı Europe/Istanbul günü kullanır; yorumla işlendi).
- [OBSERVED cooldown prova] sentetik 50 gün önceki `Bekliyor` tohumlama + **30 g içinde tamamlanmış `GEBELIK-KONTROL-<toh_id>` görevi** → hayvan `rpc_S2`'de 0, `gml`'de 0 (cooldown'a GİREN düşer); kontrol grubu (cooldownsuz) iki kümede de görünür kaldı [OBSERVED prova-1/2 öncesi-sonrası rpc_S2=1 ↔ gml=1]. Prova verisi BEGIN..ROLLBACK içinde — canlıya satır işlemedi (`tohumlama`=302 sabit).
- [OBSERVED grep] `farm_id` dosyada 4 eşleşme — tamamı başlık yorumu (satır 6, 30-32); **yorum-dışı gövdede 0** → farm_id predikatı hiçbir CTE'ye yazılmadı (#13 + C6). `pg_application_event` hiçbir yerde okunmuyor [OBSERVED grep: dosyada `pg_application_event` 0 eşleşme]; `PG_TOHUMLAMA:<event>` TAI'leri hayvan-seviyesinde bağlanır.

### 6. `node --check` gerekmez (SQL-only); `git diff --check` temiz — ✓
- [OBSERVED] `git diff --check` → çıktı boş, exit 0. Çalışma ağacında yalnız manifest dosyaları: `?? supabase/migrations/20260929000001_ovsync_takip_listele.sql` + bu DONE [OBSERVED `git status --porcelain`]. Zarf öncesi ` M` görünen dosyalara (goals/domain-rules/BOARD/design.md) dokunulmadı.

## Yazılan dosyalar (manifest 2/2)

1. `supabase/migrations/20260929000001_ovsync_takip_listele.sql` (create; SHA8 `32caeed4`)
2. `runs/2026-09-28-ovsync-takip/impl-P1-DONE.md` (bu dosya)

Prova betikleri repo DIŞINDA: `/home/melik/tmp/p1-prova/prova.sh`, `prova2.sh` (sunum amaçlı geçici; manifest konusu değil).

## Ölçüm komutları (özet)

- `bash scripts/db-validate.sh <migration>` → PASS (`/home/melik/egesut-erp1/reports/db-validation-32caeed4.md`)
- demo `SELECT public.ovsync_takip_listele()` (açık/kapalı bayrak; kpa+satirlar) → çıktılar yukarıda
- demo `has_function_privilege('anon'|'authenticated'|'service_role', …)` → f/t/t
- T-45 küme karşılaştırma SQL'i (EXCEPT iki yön) → 0/0; cooldown prova → 0/0
- `DROP FUNCTION` → 0.8 s, `pg_proc` sayımı 0; `cases`/`tohumlama` sayıları değişmez
- `git diff --check` → temiz; `sha256sum` → `32caeed4…`

## Tasarım kararları (plan/spec doğrultusunda; review'ın bileceği yerler)

- **Omurga:** `vaka_spine` (aktif+kapalı tek omurga) → `gun_durum/gun_ozet` (§7.3 durum makinesi: gelecek 'tamamlandı'→`tutarsiz`, kapalı vakada açık gün→`uygulanmadi`), `tai_tumu` (kaynak parse: `TEDAVI_SABLON_TOHUMLAMA:<case>:<sablon>`→case-bağlı [CONFIRMED 20260722000003:13]; `PG_TOHUMLAMA:<event>`/diğer→hayvan fallback, `kaynak_tur='sablon'|'pg'|'bilinmiyor'` §7.8), `vaka_tai` (yalnız aktif TAI: iptal/tamamlanmış/`kapatan_ref` dolu hariç — §7.2 "son PG kazanır"), `vaka_toh` (K6 köprü: `hayvan_id + tarih ∈ [start_date, kapanış+2g]`), `vaka_dalga` (açan OVSYNC_BASLAT hedefi, pencere [start−14, start+2]; yoksa `start_date`).
- **bolum sınıflandırma:** S0 = aktif zincirde geciken gün/TAI VEYA bugün-isi; S1 = diğer aktif; S2 = 5-predicate küme; S3 = tüm açık OVSYNC_BASLAT ∪ pencere görevsiz öneri (uyarılar gorevsiz CTE birebir) ∪ açık TAKIP_MUAYENE; S4 = kapalı (p_sonlanan_gun). KPA `bekleyen_baslatma`=S3 toplamı, `takipte` ayrı (§10c #8); 🔔 eşitliği yalnız uyarılar alt kümesi — S3 genişletmesi bunu bozmaz.
- **grup alanı** = `COALESCE(h.kategori, h.grup)` — uyarılar modeliyle (20260926000003:47) aynı; PROD raporundaki "Grup" kolonu (Sağmal) `h.grup`'tan; kategori dolu hayvanda kategori kazanır (örnek çıktıda "inek"). Spec §5 alan ADI korunur.
- **esikler.pencere_gun=2** sabit — canlıda ayrı protokol_ayar anahtarı yok [OBSERVED ayna/anahtar listesi]; §18.3 penceresi. JS'e kopyalanmaz.
- **Sıralama:** bolum → (S4: kapanış yeniden→eskiye; S2: kalan_gun; diğer: dalga/hedef) → hayvan_id.

## Açık kalem / notlar (BLOKE YOK)

1. **Zarf dosya-adı drifti:** zarf "20260926000003_ovsync_baslat_uyarilari.sql" diyor; repodaki gerçek ad `20260926000003_ovsync_baslat_gorevsiz_pencere.sql` (numara aynı; gövde `ovsync_baslat_uyarilari()`'ı yeniden beyan eder). Model satırları 38-104 ve ACL 106-107 zarfla uyumlu [CONFIRMED].
2. **LSP aynası bayat:** `egesut_lsp` canlıdan geride (yerel T54/F244 vs prod T55/F256 [OBSERVED baseline meta]; örnek: `treatment_days.ust_gorev_tarihi` aynada yok, `cases.disease_id` aynada nullable — canlıda NOT NULL [OBSERVED prova INSERT hatası]). P1'in dokunduğu kolonların tamamı aynada mevcut olduğundan typecheck/etkilenmedi; `refresh_lsp_schema.sh` PROD Mgmt API okuması gerektirdiğinden zarfın PROD yasağı gereği koşturulmadı. **Öneri:** sahibin PROD-schema-okuma izninde ayna tazelensin (P2a'dan ÖNCE).
3. **postgrestools kısıtı:** gövdeyi bağımsız statement çözümlediğinden SQL-language fonksiyon parametre adlarını (`p_padok`) çözemez → tek yanlış-pozitif (42703) verdi; gerçek hüküm izole-klon apply + çağrı provasıyla alındı. `documentSymbol`/`hover` postgrestools sunucusunda desteklenmiyor/boş döndü [OBSERVED] — komut-satırı `check` kullanıldı.
4. **S3 görevsiz öneri penceresi:** yalnız [bugun, bugun+2] arası kural günleri öneri satırı doğurur (uyarılar davranışı); daha uzak kural günlü görevsiz hayvan S3'te YOKTUR (görevi doğduğunda girer). Bilinçli — uyarılar paneliyle tutarlı.
5. **Demo klon farkı:** demo klonunda OVSYNC damgalı vaka yok; P2+ maddelerde sentetik vaka prova kalıbı gerekebilir (prova2.sh şablonu `/home/melik/tmp/p1-prova/prova2.sh`).
6. **Commit:** atılmadı — mimar devir topluyor (zarf emri). Demo'da fonksiyon KALDIRILDI (temiz durum; apply normal zincirden yapılır).
