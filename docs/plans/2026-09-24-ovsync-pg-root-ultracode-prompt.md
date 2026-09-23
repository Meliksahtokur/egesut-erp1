# ROOT PROMPTU — Ovsync/PG: feature'ı prod'a çıkar (DB R3.2 + UI + testler), sonra küçük fixler

Sen egesut-erp1 root'usun. **Hedef:** Ovsync/PG/tohumlama feature'ı prod'da çalışır ve bayrağı açık olsun. Kullanıcı arayüzü tamamlansın. Ardından küçük fixler yapılsın.

**Sıra kesin, atlama yok:**
1. Feature'ın tam implementasyonu: DB + UI.
2. Başarı testleri ve sağlama.
3. Prod'a çıkış.
4. Küçük işler.

Her sahip kapısında dur, kanıtla birlikte onay iste, onay gelmeden bir sonraki adıma geçme.

## 0. Önce oku (sırayla; başka kaynaktan politika kurma)
1. `.harness/contract.md`, `.harness/acceptance.md`, `.harness/runtimes/claude.md`, `.claude/skills/ultracode-rehber/SKILL.md`
2. **SPEC (kanonik):** `docs/plans/2026-09-23-ovsync-pg-tohumlama-SPEC.md`. Oku: §0 (sahip ve mimar kararları), S-1…S-10, §R3.1 (uygulandı), **§R3.2 (UYGULANMADI)**, "Kapsam dışı" (4. madde frontend listesi).
3. Board `.ss/ovsync-pg-sql-BOARD.md`, kırıntılar `.crumbs/ovsync-pg-sql.jsonl`. Kararlarını ve ölçümlerini buraya ekle (`role:"root"`).
4. `.harness/references/ui-map.md`, `domain-rules.md`, `rpc-reference.md`.
5. Hazır DB işi (commit bekliyor, ana checkout'ta STAGE'li):
   - `supabase/migrations/20260923000001…000006`
   - `supabase/tests/ovsync_pg_kabul.sql` (406 PASS) ve `README.md` (koşum komutu)
   - `scripts/kabul-db/`: yerel `egesut_ovsync_kabul`, canlı `public` + `surum_gizli` şemasının verisiz kopyası. Kurulum: `KABUL_OFFLINE=1 bash scripts/kabul-db/build.sh`; canlıdan taze kurulum için `KABUL_OFFLINE`'sız.

Proje ref'leri (`.env`): prod `SB_PROJECT_REF` (zqnexq…, `js/api.js:23`), demo `SUPABASE_DEMO_REF` (vtzqjm…). Her sorguda hangisine gittiğini kırıntıya yaz.

## Değişmez kurallar (ihlal = dur ve raporla)
- **Bayrak:** yeni davranış `protokol_ayar.ovsync_pg_kurallari_aktif` arkasında.
  - Bayrak kapalıyken davranış canlıyla eş olmalı (MK5).
  - Temizlik ve geri alma adımları bayraktan bağımsız çalışır (MK8).
  - Frontend bayrak kapalıyken de doğru çalışmalı; yeni UI yalnız yeni dönüş ya da hata geldiğinde devreye girer.
- **Migration'lar:**
  - Append-only. 000001–000006'ya dokunma; yeniler `20260924NNNNNN_*.sql`.
  - anon'a GRANT yok. `_` önekli iç yardımcılar authenticated'a kapalı. `GRANT … ON ALL FUNCTIONS` yazma.
  - SECURITY DEFINER + `SET search_path = public, pg_temp`.
  - İmza değişirse eski imza DROP edilir, tek overload kalır. Dosya sonunda `NOTIFY pgrst, 'reload schema'`.
  - Fonksiyonun tabanı en son migration'daki gövdesidir. Değiştirmeden önce `code-change-precheck` skill'i.
- **Fail-closed:** tanımsız girdi gürültülü hata verir, sessiz varsayılan yok.
- **Veri değiştiren toplu işler** `p_dry_run` arkasında. Prod'da önce dry-run çıktısı sahibe gösterilir.
- **Prod ve demo'ya yazma yalnız sahip kapısından sonra.** Öncesinde yalnız SELECT (Management API).
- **Testler:** Playwright yalnız demo (`npm run test:docker:demo` / `PLAYWRIGHT_DEMO_MODE=1`); test DB client'ları prod'a bakamaz. Demo sahip şifresine dokunulmaz, değeri hiçbir dosyaya yazılmaz. Belgelenmiş bir Playwright koşumu tekrar koşulmaz, çıktısı kontrol edilir.
- **Ajanlar:**
  - Aynı anda en fazla 6 (MAX_CONC=6). TEK-YAZICI-PER-DOSYA; her zarf yazılabilir dosyaları listeler. **`js/ui.js` tek yazıcılı.**
  - Alt-ajan modeli: Opus haftalık kotası 27 Eyl 02:00'a kadar dolu; Sonnet ya da glmf/glm kullan. Worker koltuğu asla claude kolu olmaz.
  - `/tmp` yasak (`~/tmp` kullan). `free -g` available < 5 GB ise dur.
- **Git:**
  - Dal `feature/ovsync-tohumlama-tedavi-kapanisi`; worktree `~/egesut-wt/ovsync-pg`. main'e doğrudan commit yok (K11).
  - `docs/plans/` ve `*.sh` gitignore'da, `git add -f` gerekir.
  - Her anlamlı adımdan sonra commit. Commit öncesi `git diff --cached --stat` + gitnexus `detect_changes`. JS sembolü düzenlemeden önce `impact`; HIGH/CRITICAL riski sahibe bildir.

---

## A. FEATURE — tam implementasyon

### A0 — Bekleyen commit (bloklayıcı, ilk iş)
1. `git worktree add ~/egesut-wt/ovsync-pg feature/ovsync-tohumlama-tedavi-kapanisi`, sonra orada `git merge --ff-only main` (dal main'in atası).
2. Ana checkout'tan worktree'ye kopyalanacak 16 dosya:
   - Stage'li 15: 6 migration, `supabase/tests/` (2), `scripts/kabul-db/` (6), SPEC.
   - Artı bu prompt dosyası: `docs/plans/2026-09-24-ovsync-pg-root-ultracode-prompt.md`.
   - SPEC'i **güncel** haliyle al; R3.2 stage'den sonra eklendi.
   - `git add` (+`-f`); stat yalnız bu 16 dosyayı göstermeli.
   - Commit.
3. Ana checkout'ta `git restore --staged` + kopyaları sil. `AGENTS.md`, `CLAUDE.md` ve `.claude/skills/sut-kalinti/` bu işe ait değil, dokunma.
- KÖ: dal ucunda dosyalar var; worktree'den kabul koşumu 406 PASS.

### A1 — DB: SPEC §R3.2 (workflow yok, doğrudan; repo kuralı)
- **SK6 gün sayımı:** inekte başlangıç = doğum/abort **+51** gün. Düvede başlangıç = `dogum_tarihi + 12 ay + 21 gün`. TAI şablondan: başlangıç +10 gün, 10:00.
- **SK7 açık dişi kuralı:**
  - Tek fonksiyon: `_acik_disi_ovsync_hedef(p_hayvan_id) RETURNS date`.
  - Kapsam: Boş çıkanlar dahil. Muaf: Gebe, Bekliyor, aktif senkronizasyon, Aktif değil.
  - `TOHUMLAMA_VAR` muafiyeti kalkar.
  - Hedef = `GREATEST(kural tarihi, bugün[İstanbul])`. Tabanı olmayan hayvan (doğum kaydı yok ya da `dogum_tarihi` NULL) görev almaz ve raporlanır.
- **SK8 tetikler (birincil = olay):**
  - `dogum_kaydet`: anne +51; **dişi buzağı** → düve kuralı.
  - `tohumlama_abort`: +51.
  - `tohumlama_sonuc_bos`: kural fonksiyonuyla görev.
  - `hayvan_ekle`: iki overload; canlı gövdeleri oku.
  - `ilk_tohumlama_zamanlayici` (cron) **yalnız yedek**: açık dişi taraması (sayaç + üst sınır) ve hedefi gelenleri başlatma.
    - `p_dry_run boolean DEFAULT false` parametresi eklenir: dry-run hiçbir şey yazmaz, açılacak görevleri ve başlatılacak zincirleri listeler; **bayrak kapalıyken de** çalışır.
    - İmza değişiyor: eski imza DROP, cron komutu aynı kalır.
  - İdempotency `protokol_instance.kaynak_ref` UNIQUE üzerinden: `ILK-TOH-DOGUM-<olay_id>`, `ILK-TOH-ABORT-<tohumlama_id>`, `ACIK-DISI-<hayvan>-<kural tarihi>`.
- **SK9 uyarı verisi:** `OVSYNC_BASLAT` görevi `hedef − 2 gün`den itibaren protokol uyarıları ekranında listelenebilir olmalı. Ekranın veri kaynağını genişlet (`protokol_eksik_tara` ya da yeni salt-okuma RPC; `js/ui.js:1496` `_showProtokolEkran`'ın kaynağını incele).
- **SK10 geçiş (migration içinde, bayraktan bağımsız):**
  - Başlangıcından sonra tohumlanmış ve açık seansı olmayan aktif Ovsync vakaları `_vaka_kapat(…,'TOHUMLAMA',…)` ile kapatılır. Prod ölçümü 2026-09-24: 10 vaka, 13 Eylül başlangıçlı; migration'ı yazmadan hemen önce yeniden say.
  - Açık seansı olan vaka (küpe 002) kendi akışında devam eder.
- Kabul betiğine R3.2 testleri (SPEC §R3.2 son madde).
- KÖ:
  - Kabul PASS: 406 + R3.2.
  - Tüm migration'lar iki kez art arda uygulanınca hata yok; tek overload.
  - `scripts/ground-truth-audit.sh` temiz.

### A2 — UI tasarımı (`/ultracode-workflows:design-tournament`)
- **Brief:** SPEC "Kapsam dışı" 4 + SK9 + §R3.1. Ekranlar:
  - (a) **Protokol uyarıları:** `OVSYNC_BASLAT` kartı `hedef−2g`den itibaren; [Başlat] (`start_first_service_protocol`) ve [İptal]; düve ve inek ayrımı; hedef ve TAI tarihi görünür.
  - (b) **PG kapısı modalı:**
    - `BLOCK_PREGNANT` → "Yine de uygula" YOK.
    - `REQUIRE_ACK_PENDING` → gerekçeli onay + hayvan başına **[Boş ata]** (`tohumlama_sonuc_bos`; tek ekranda, modal-modal gezinti yok).
    - `BLOCK_CATALOG_UNRESOLVED`.
  - (c) **Hata ayrıştırma:** `PG_KAPI:<KOD>:<json>`, `PG_ZAMAN_GECERSIZ`, `SISTEM_ETKEN_MADDE`, `KATALOG_SINIF_KODU_KILITLI`. `js/utils/errorHandler.js` `getUserMessage` bunları jenerik metne çevirmemeli.
  - (d) **Toplu PG sonucu:** `bulk_ilac` `applied/blocked/requires_ack`; kaydırılabilir tek modal; onay listesiyle tekrar gönderme.
  - (e) **Erteleme modalı:** `tohumlama_gorev_ertele`, mevcut tarih seçiciyle; pencere yuvarlaması gösterilir; `ERTELEME_7_GUN_ASILDI` uyarısı.
  - (f) **Hızlı uygulama:** opsiyonel "uygulama saati" alanı (`p_occurred_at`).
  - (g) **Tohumlama kaydı sonrası:** `kapatilan_senkronizasyon_vakalari` özeti.
  - (h) **Görev kartları ve Tohumlamalar paneli:** `TOHUMLAMA_PLANLI` kaynak etiketi (şablon TAI / PG+48s / ilk tohumlama).
  - (i) **Katalog düzenleme:** sistem satırında toplu düzenleme yarım kalmasın.
  - (j) **`js/api.js` pull haritası:** `bulk_ilac`/`tohumlama_abort` → `gorev_log`; `tohumlama_kaydet` → `cases` + seanslar.
- **Kısıtlar:** vanilla JS; mevcut modal-router ve tarih seçici kalıpları (`tests/modal-router.spec.js`, `tests/tarih-secici.spec.js`); sahada telefon (mobil öncelik); Türkçe; `escAttr`/XSS disiplini.
- **Çıktı:** `docs/plans/2026-09-24-ovsync-pg-PLAN.md`. Madde numaralı; her madde dosya/fonksiyon + kabul ölçütü taşır (PLAN DRIFT kapısı).
- **SAHİP KAPISI 1:** PLAN onayı. Onaysız A3'e geçme.

### A3 — UI implementasyonu
1. `js/ui.js`'e dokunmadan önce `ss-parallel-review` workflow'u (repo kuralı).
2. `/ultracode-workflows:feature-factory` (girdi: PLAN.md). Dosya sahipliği:
   - `js/ui.js` tek kulvar
   - `js/forms.js`
   - `js/api.js`
   - `js/config.js`
   - `js/utils/errorHandler.js`
   Aynı dosyayı iki kulvara verme; ayrışmıyorsa sıralı yürüt.
3. `?v=` sürüm damgası tek değer.
- KÖ: PLAN maddelerinin hepsi işaretli; `npm run test:unit` yeşil.

## B. BAŞARI TESTLERİ VE SAĞLAMA

### B1 — Yerel
- `npm run test:unit`: PG_KAPI ayrıştırıcı, 2 gün uyarı filtresi, kaynak etiketleri, pencere gösterimi.
- Kabul DB: tüm migration'lar + `ovsync_pg_kabul.sql`, ROLLBACK'li, hepsi PASS.
- `/ultracode-workflows:deep-code-review` (DB + JS değişiklik seti). Bulguları skepsis ile doğrula, düzelt, yeniden koş.

### B2 — Demo
- **SAHİP KAPISI 2:** demoya uygulama.
  1. Önce kabul betiği demoda ROLLBACK'li koşar. Betik, sahip şifresi tablosu doluysa UI geri alma testini kendisi atlar.
  2. Sonra migration'lar **bayrak kapalı** uygulanır.
- **Playwright smoke** (`tests/ovsync-pg-smoke.spec.js`, demo). Sıra:
  1. **Bayrak kapalıyken** mevcut akışlar değişmedi: hızlı uygulama, seans, toplu ilaç, tohumlama, doğum. Ardından `ilk_tohumlama_zamanlayici(p_dry_run := true)` çıktısı kaydedilir, sonra **demo bayrağı açılır** (demo'da sahip kapısı 2'nin parçası).
  2. Doğum → `OVSYNC_BASLAT` hedef +51 → hedef−2g'de uyarı ekranında → [Başlat] → vaka + 4 seans + TAI kartı.
  3. Düve 12a21g → uyarı → [Başlat].
  4. Bekliyor inekte PG → onay modalı → [Boş ata] → tekrar uygula geçer, +48s görev.
  5. Gebe inekte PG → engel, uygulama yok.
  6. Toplu PG → karışık sonuç modalı, stok yalnız uygulananlar kadar.
  7. Tohumlama → Ovsync vakası kapandı özeti; Boş sonucu → yeni `OVSYNC_BASLAT`.
  8. Ertele → yeni tarih ve pencere, 7 gün uyarısı.
- `/ultracode-workflows:acceptance-qa-deep`: kriterler SPEC S-1…S-10 + R3.1 + R3.2 KÖ'leri + PLAN maddeleri; kanıt + karşı saldırı.
- L4 sahip yürüyüşü (memory tarifi): sahip demo'da insan akışını tarayıcıda yürür.
- `/ultracode-workflows:release-gate`: go / no-go.

## C. PROD'A ÇIKIŞ (her adım sahip kapısı; sıra değişmez)
1. **SAHİP KAPISI 3:** migration'ları prod'a uygula, bayrak kapalı.
   - Yol: repodaki mevcut prod uygulama yolu (Management API / tools-bank `supabase_migrate`; memory: supabase-mgmt-token-setup). `deploy.yml` eski ve KULLANILMAZ.
   - Ardından:
     - `supabase_migrations.schema_migrations` kayıtlarını ve fonksiyon imzalarını (tek overload, ACL) doğrula.
   - `python3 scripts/veri-eslesme-kontrol.py hepsi` temiz.
   - SK10 geçişinin kapattığı vakaları raporla.
2. **SAHİP KAPISI 4:** frontend'i yayınla. Feature dalı main'e merge edilir, GitHub Pages yayını yapılır. Bayrak kapalıyken prod'da mevcut akışlar üzerinde salt-okuma duman kontrolü: sayfa açılıyor, konsolda hata yok, görev listesi yükleniyor.
3. **SAHİP KAPISI 5:** prod bayrağını aç.
   - **Açmadan önce** `ilk_tohumlama_zamanlayici(p_dry_run := true)` çıktısını sahibe göster: kaç inek/düve, hangi hedeflerle görev alacak, hedefi geçmiş olup hemen başlayacak olanlar. Bayrak açılınca 07:00 cron'u bu taramayı kendiliğinden yapar.
   - Sahip onaylarsa bayrağı aç (`protokol_ayar_guncelle`). İlk koşumu elle tetikle ya da 07:00 cron'unu bekle; `FIRST_SERVICE_CRON` log'unu raporla.
4. Bayrak açıldıktan sonra ilk 24 saatte oluşan `pg_application_event`, `OVSYNC_BASLAT` ve `CASE_CLOSED_BY_TOHUMLAMA` sayılarını raporla. Beklenmeyen durumda bayrağı kapatmayı sahibe öner; bayrak kapatılınca temizlik yolları çalışmaya devam eder (MK8).

## D. KÜÇÜK İŞLER VE FİXLER (C bittikten sonra)
Her madde ayrı migration ya da betik ve kendi kabul testi. Veri değiştirenler dry-run → sahip onayı → gerçek koşum.
1. **D11 artığı:** 11. gün PG görevi olup 39. gün görevi olmayan inek(ler)e 39. gün PG görevi; D11 görevi iptal. Önce prod'da say (2026-09-23: 1 açık D11 görevi, hedef 2026-09-28; tarih geçtiyse sahibe sor).
2. **`hayvanlar.tohumlama_durumu` tutarlılığı:**
   - (a) Önce JS'te okuma yerlerini listele (`grep -n tohumlama_durumu js/`); UI hangi yazımı bekliyor? Sonra normalizasyon: `gebe`→`Gebe`, `bos`→`Boş`.
   - (b) Son tohumlaması `Doğum Yaptı`/`Abort` olup gebe görünen hayvanlar son tohumlamadan türetilen değere çekilir. Prod ölçümü 2026-09-24: aktif 13 hayvan, hepsinin doğum kaydı var.
     - 002, 008, 110, 122, 144, 149, 168, 169, 184, 186, 188, 199
     - "Test inek 3" (sahibin deneme hayvanı)
     - Aktif olmayan: 157, 185
   - (c) Kök neden: `dogum_kaydet` doğumda bu kolonu sıfırlamıyor; düzelt.
   - RPC: `tohumlama_durumu_uzlastir(p_dry_run boolean DEFAULT true)`.
3. **"Test inek 3":** sahibin bilerek oluşturduğu deneme hayvanı; sızıntı değil. DOKUNMA. Uzlaştırma ve açık dişi taramasında normal hayvan gibi davranır; raporda ayrıca belirt.
4. **Doğum kaydı olmayan "Doğum Yaptı":** 7 tohumlama satırı (eski veri). Listele, sahibe sor. Bu hayvanlar açık dişi kuralında "taban yok" olarak raporlanır.
5. **`bulk_ilac` stok çift düşüm şüphesi:** önce ölç (kart ↔ hareket toplamı, kalan stok formülü). Bug doğrulanırsa düzelt ve geçmişi dry-run'lı uzlaştır. Değilse "yanlış alarm" + kanıt.
6. **Seans geri almasında PG kaydı:** seans tamamlama geri alındığında `TEDAVI_SEANS` event'i MK10 trigger'ıyla aynı temizliği alsın. `TOPLU_ILAC`'ın geri alma yolu yoksa yalnız belgelenir.
7. **`tohumlama_abort` varsayılan tarihi** UTC → İstanbul günü; imza aynı kalır. Test: 00:30 İstanbul senaryosu.
8. **ACL denetimi:** canlıya karşı salt-okuma `scripts/acl-denetim.sql`. Kontroller: `_` önekli fonksiyonlarda authenticated/anon EXECUTE = 0; anon'da yeni EXECUTE = 0. `.harness/contract.md`'ye "migration'da `GRANT … ON ALL FUNCTIONS` yasak" notunu sahibe öner (policy dosyasını sen yazma).
9. **Belgeler** (`.harness/docs-update.md`):
   - `rpc-reference.md`: yeni RPC'ler, değişen imzalar, PG_KAPI hata sözleşmesi.
   - `domain-rules.md`: PG+48s, VWP 55, açık dişi kuralı, +51 / 12a21g, bayrak.
   - `ui-map.md`: yeni modaller.
10. **Kapanış:** `node .gitnexus/run.cjs analyze`. Birleşmiş dal sahip kuralına göre kapatılır (ölç + hasat + yedek etiket).

## Teslim
- Faz → KÖ → kanıt (komut + çıktı; CONFIRMED/OBSERVED/LOCAL-MEASURED etiketleri).
- Commit listesi, açık kalemler, sahip kapıları (1–5) ve her birinin durumu.
- Board ve kırıntılar güncel. Sahip kapısında bekleyen hiçbir madde listeden sessizce düşmez.
