# kat-2: tam diff -U10 — ovsync-mu-fix 56900c38..40c77309
```diff
diff --git a/index.html b/index.html
index 3f24544..b0b7d55 100644
--- a/index.html
+++ b/index.html
@@ -1,21 +1,21 @@
 <!DOCTYPE html>
 <html lang="tr">
 <head>
 <meta charset="UTF-8">
 <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover">
 <meta name="mobile-web-app-capable" content="yes">
 <meta name="apple-mobile-web-app-capable" content="yes">
 <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
 <meta name="apple-mobile-web-app-title" content="Ege Süt">
 <meta name="theme-color" content="#111a0a">
-<link rel="manifest" href="manifest.json?v=20261013-09">
+<link rel="manifest" href="manifest.json?v=20261017-01">
 <meta name="apple-mobile-web-app-capable" content="yes">
 <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
 <meta name="apple-mobile-web-app-title" content="EgeSüt">
 <title>Ege Süt</title>
 <link rel="preconnect" href="https://fonts.googleapis.com">
 <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
 <style>
 :root{
   --bg:#111a0a;--bg2:#1a2812;--bg3:#22361a;
   --card:#f7f4ee;--card2:#edeae2;--card3:#e2ddd3;
@@ -2429,45 +2429,45 @@ body.dark .ac-vurgu{color:#8ec6ff}
   </div>
 </div>
 
 <div id="toast"></div>
 
 <!-- Supabase SDK -->
 <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js"></script>
 
     <!-- EgeSüt JS modülleri -->
     <!-- ?v= damgası: her js/css değişikliğinde GÜNCELLE (cache-busting) -->
-    <script src="js/utils/helpers.js?v=20261013-09"></script>
-    <script src="js/gecmis.js?v=20261013-09"></script>
-    <script src="js/utils/modal.js?v=20261013-09"></script>
-    <script src="js/utils/errorHandler.js?v=20261013-09"></script>
-    <script src="js/utils/events.js?v=20261013-09"></script>
-    <script src="js/config.js?v=20261013-09"></script>
-    <script src="js/state.js?v=20261013-09"></script>
-    <script src="js/api.js?v=20261013-09"></script>
-    <script src="js/auth.js?v=20261013-09"></script>
-    <script src="js/tarih/tarih.js?v=20261013-09"></script>
-    <script src="js/ui.js?v=20261013-09"></script>
-    <script src="js/forms.js?v=20261013-09"></script>
-    <script src="js/ai-asistan.js?v=20261013-09"></script>
-    <script src="js/demo.js?v=20261013-09"></script>
-    <script src="vendor/cytoscape.min.js?v=20261013-09"></script>
-    <script src="js/pedigree/pedigree-api.js?v=20261013-09"></script>
-    <script src="js/pedigree/pedigree-adapter.js?v=20261013-09"></script>
-    <script src="js/pedigree/pedigree-style.js?v=20261013-09"></script>
-    <script src="js/pedigree/pedigree-view.js?v=20261013-09"></script>
-    <script src="js/pedigree/pedigree-controller.js?v=20261013-09"></script>
-    <script src="js/degisiklikler/etiketler.js?v=20261013-09"></script>
-    <script src="js/degisiklikler/diff.js?v=20261013-09"></script>
-    <script src="js/degisiklikler/degisiklikler.js?v=20261013-09"></script>
-    <script src="js/app.js?v=20261013-09"></script>
-    <script src="js/utils/handlers.js?v=20261013-09"></script>
+    <script src="js/utils/helpers.js?v=20261017-01"></script>
+    <script src="js/gecmis.js?v=20261017-01"></script>
+    <script src="js/utils/modal.js?v=20261017-01"></script>
+    <script src="js/utils/errorHandler.js?v=20261017-01"></script>
+    <script src="js/utils/events.js?v=20261017-01"></script>
+    <script src="js/config.js?v=20261017-01"></script>
+    <script src="js/state.js?v=20261017-01"></script>
+    <script src="js/api.js?v=20261017-01"></script>
+    <script src="js/auth.js?v=20261017-01"></script>
+    <script src="js/tarih/tarih.js?v=20261017-01"></script>
+    <script src="js/ui.js?v=20261017-01"></script>
+    <script src="js/forms.js?v=20261017-01"></script>
+    <script src="js/ai-asistan.js?v=20261017-01"></script>
+    <script src="js/demo.js?v=20261017-01"></script>
+    <script src="vendor/cytoscape.min.js?v=20261017-01"></script>
+    <script src="js/pedigree/pedigree-api.js?v=20261017-01"></script>
+    <script src="js/pedigree/pedigree-adapter.js?v=20261017-01"></script>
+    <script src="js/pedigree/pedigree-style.js?v=20261017-01"></script>
+    <script src="js/pedigree/pedigree-view.js?v=20261017-01"></script>
+    <script src="js/pedigree/pedigree-controller.js?v=20261017-01"></script>
+    <script src="js/degisiklikler/etiketler.js?v=20261017-01"></script>
+    <script src="js/degisiklikler/diff.js?v=20261017-01"></script>
+    <script src="js/degisiklikler/degisiklikler.js?v=20261017-01"></script>
+    <script src="js/app.js?v=20261017-01"></script>
+    <script src="js/utils/handlers.js?v=20261017-01"></script>
 
 
     <!-- GEBELİK EKLE MODAL -->
 <div id="m-gebelik" class="mo" data-action="mclose-overlay">
   <div class="modal"><div class="m-handle"></div><div class="m-title">🤰 Gebelik Ekle</div>
     <div class="m-body">
       <div id="gebelik-hayvan-label" style="font-size:.8rem;font-weight:700;color:var(--ink3);margin-bottom:10px;padding:8px;background:var(--card2);border-radius:8px"></div>
       <div class="fg">
         <label class="flbl">Tohumlama Tarihi *</label>
         <input id="geb-tarih" class="fi" type="text" autocomplete="off">
diff --git a/js/ui.js b/js/ui.js
index cc661ad..e241024 100644
--- a/js/ui.js
+++ b/js/ui.js
@@ -911,38 +911,42 @@ function _ovsyncBaglamKur(gorevler, vakalar, hayvanlar, yedek){
     const ok=kabulVar
       ?_hastalikKabulMu(c,{gorevler:gorevler,eslem:(yedek&&yedek.eslem)||[],sablonlar:(yedek&&yedek.sablonlar)||[]})
       :(c.status==='active'&&c.protocol_family==='OVSYNC');
     if(ok) ovsyncKabul.add(c.id);
   });
   return {baslat:baslat,vakaAktif:vakaAktif,vakaKapali:vakaKapali,kisir:kisir,acikIs:acikIs,ovsyncKabul:ovsyncKabul};
 }
 /**
  * "+ Hastalık" kabulü (K10-UI2 B1, saf): aktif vaka + damga
  * (`protocol_family==='OVSYNC`) ya da ailesi NULL iken yedek tanım
- * (OVSYNC-eşlemeli şablon + `TEDAVI_SABLON_TOHUMLAMA:<vaka>:%` logu).
+ * (OVSYNC-eşlemeli şablon ya da `TEDAVI_SABLON_TOHUMLAMA:<vaka>:<OVSYNC şablon id>`
+ * logu, iptal===false; `:MANUEL` saymaz).
  * OVSYNC-dışı damga kapalıdır; desteksiz NULL fail-closed'dur.
  * @param {Object} vaka cases satırı.
  * @param {Object} [ek] {gorevler, eslem:[{disease_id,sablon_id}], sablonlar:[{id,protokol_ailesi}]}.
  * @returns {boolean} Kabul görürse true.
  */
 function _hastalikKabulMu(vaka, ek){
   if(!vaka||vaka.status!=='active') return false;
   if(vaka.protocol_family==='OVSYNC') return true;
   if((vaka.protocol_family??null)!==null) return false;
   const e=ek||{};
   const ovsyncSablon=new Set((Array.isArray(e.sablonlar)?e.sablonlar:[])
     .filter(s=>s&&s.protokol_ailesi==='OVSYNC').map(s=>s.id));
   if(vaka.disease_id&&(Array.isArray(e.eslem)?e.eslem:[])
     .some(x=>x&&x.disease_id===vaka.disease_id&&ovsyncSablon.has(x.sablon_id))) return true;
+  // ovsync-mu-fix (DB 20261017100001 aynası): log kolu yalnız anahtardaki
+  // şablon OVSYNC ve iptal===false iken; :MANUEL/NULL-aile şablon saymaz.
   const pref='TEDAVI_SABLON_TOHUMLAMA:'+vaka.id+':';
   return (Array.isArray(e.gorevler)?e.gorevler:[])
-    .some(g=>g&&typeof g.kaynak==='string'&&g.kaynak.indexOf(pref)===0);
+    .some(g=>g&&typeof g.kaynak==='string'&&g.kaynak.indexOf(pref)===0
+      &&g.iptal===false&&ovsyncSablon.has(g.kaynak.slice(pref.length)));
 }
 /**
  * Kayıtlı IDB bağlamını okur; yoksa/bozuksa boş bağlam (aksiyon çizilmez,
  * satır 'bilinmiyor' gösterir — duck-typing realm-bağımsız).
  * @returns {{baslat:Map, vakaAktif:Map, vakaKapali:Map, kisir:Set}}.
  */
 function _ovsyncBaglamAl(){
   const w=typeof window!=='undefined'?window:{};
   const b=w._ovsyncBaglam;
   if(b&&b.baslat&&typeof b.baslat.get==='function'&&b.vakaAktif&&typeof b.vakaAktif.get==='function'
diff --git a/runs/2026-10-17-ovsync-mu-fix/brief.md b/runs/2026-10-17-ovsync-mu-fix/brief.md
new file mode 100644
index 0000000..48dd861
--- /dev/null
+++ b/runs/2026-10-17-ovsync-mu-fix/brief.md
@@ -0,0 +1,29 @@
+# Brief — `_vaka_ovsync_mu` log kolu yanlış pozitif düzeltmesi (2026-10-17)
+
+## Plan maddesi
+Sahip onayı (2026-10-17, "ok"): istatistikten AYRI küçük düzeltme işi. Dal `fix/ovsync-mu-log-kolu` (main 56900c3'ten), worktree `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-mu-fix`. Prod'a uygulama ve merge YOK (sahip kapısı) — yalnız fix + test + doğrulama + prod etki ölçümü.
+
+**Hata (MEASURED, demo salt-okuma, 2026-10-17):** `_vaka_ovsync_mu` (`supabase/migrations/20261013000003_alt_vaka.sql:66-84`) `gorev_log`'daki `TEDAVI_SABLON_TOHUMLAMA:<case>:%` anahtarını Ovsync belirteci sayıyor. Aynı anahtarı tedavi şablonlarının opsiyonel "planlı tohumlama" adımı da yazıyor (`20260730000001_sablon_tohumlama_opsiyonel_ve_yasam_dongusu.sql:97,128`, `20260909000001_sablon_aktif_vakaya_uygula.sql:115,130`; elle ekleme `20260730000002_vaka_tohumlama_ekle.sql:134` `:MANUEL`). Demo örnekleri: vaka 232e7f7d Klinik Mastit (şablon "Enrolen mastit"), 375a8d6a Neonatal Zayıflık (3 günlük buzağı H000159, şablon "Kas / tendon zayiflik"), 1f03f184 Tırnak Yarası (şablon "3x30 sefanel + nsaid") — logları `gorev_tipi=TOHUMLAMA_PLANLI`, `iptal=true`, şablonların `protokol_ailesi` NULL. Prod'da aynı tanım farkı 5 vaka (İnaktif Ovaryum 2, Klinik Mastit 1, Neonatal Zayıflık 1, Tırnak Yarası 1).
+
+**İstenen düzeltme (root ruling; istatistik dalındaki `stat_vaka_ovsync_mu` ile aynı kural):** log kolu yalnız log anahtarındaki şablonun `protokol_ailesi = 'OVSYNC'` olduğu VE log `iptal = false` olduğu durumda Ovsync sayar. Diğer kollar (protocol_family, ad, şablon-eşlem) AYNEN. Elle tohumlama `:MANUEL` anahtarının bugünkü davranışı ölç, değiştirme kararını gerekçeyle rapora yaz (Ruling).
+
+## Adımlar
+1. Önce oku: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-mu-fix/.harness/references/domain-rules.md` (Ovsync §18 ve sonrası) — çelişki → dur, `SORU:`. code-change-precheck ve db-validation skill'lerini yükle.
+2. Etki: `_vaka_ovsync_mu`'yu kim çağırıyor (gitnexus/atlas → grep supabase/migrations js/); hangi davranış (alt vaka, rozet, senkron) yanlış sınıflamadan etkileniyor — prod'daki 5 vakada bugün ne yanlış oluyor (Mgmt API SALT-OKUMA: `BEGIN; SET TRANSACTION READ ONLY; …; ROLLBACK;`), MEASURED.
+3. TDD: kırmızı SQL testi (mevcut alt_vaka test kalıbıyla) — (i) protokol_ailesi NULL şablondan iptal=true TOHUMLAMA logu olan tedavi vakası → Ovsync DEĞİL; (ii) OVSYNC şablonundan iptal=false logu → Ovsync; (iii) mevcut pozitif durumlar değişmez. Sonra yeni migration (damga ≥ 20261017, main'in migration sırası kilidi testine uygun — `tests/unit/migration-sira-kilidi.test.js`'i oku) `CREATE OR REPLACE` ile; GRANT/SECURITY aynen korunur (anon GRANT YAZMA).
+4. Doğrulama: `scripts/db-validate.sh` PASS; SQL testleri PASS; `NODE_PATH=/home/melik/egesut-erp1/node_modules node --test tests/unit/` — yeni fail 0 (taban: main 56900c3'te 6 bilinen fail; önce tabanı ölç).
+5. Demo'ya uygulama YALNIZ planlı yolla ve rapora yaz; prod'a HİÇBİR ŞEY uygulanmaz.
+
+## Model
+opus high (ss-worker-high) — prod'daki Ovsync paketinin fonksiyonu, domain hassas.
+
+## Yazılabilir dosyalar
+/home/melik/.herdr/worktrees/egesut-erp1/ovsync-mu-fix/supabase/migrations/2026101700000X_ovsync_mu_log_kolu.sql (tek yeni migration; X main sırasına göre)
+/home/melik/.herdr/worktrees/egesut-erp1/ovsync-mu-fix/tests/sql/ altında tek yeni test dosyası (ya da mevcut alt_vaka testine ek — raporda belirt)
+/home/melik/.herdr/worktrees/egesut-erp1/ovsync-mu-fix/runs/2026-10-17-ovsync-mu-fix/ (report, progress)
+
+## Boyut bütçesi
+Migration ≤80 satır, test ≤150 satır. Commit: görev başına, `git add` dosya dosya; `-A`/`.` YASAK; git stash YASAK; push/merge YOK.
+
+## Teslim
+`/home/melik/.herdr/worktrees/egesut-erp1/ovsync-mu-fix/runs/2026-10-17-ovsync-mu-fix/report.md`: etki (çağıranlar + prod 5 vakada bugünkü yanlış davranış), test kırmızı→yeşil kanıtı, db-validate sonucu, birim süit sayıları, `:MANUEL` ruling'i, prod uygulama taslağı (sahip kapısı için: hangi migration, geri alma), `kabul SHA:`. Dönüş ≤5 satır.
diff --git a/runs/2026-10-17-ovsync-mu-fix/kanit/birim-ozet.txt b/runs/2026-10-17-ovsync-mu-fix/kanit/birim-ozet.txt
new file mode 100644
index 0000000..270b42e
--- /dev/null
+++ b/runs/2026-10-17-ovsync-mu-fix/kanit/birim-ozet.txt
@@ -0,0 +1,3 @@
+ℹ tests 1598
+ℹ pass 1594
+ℹ fail 4
diff --git a/runs/2026-10-17-ovsync-mu-fix/kanit/db-validation-3a69ea5d.md b/runs/2026-10-17-ovsync-mu-fix/kanit/db-validation-3a69ea5d.md
new file mode 100644
index 0000000..e03ad53
--- /dev/null
+++ b/runs/2026-10-17-ovsync-mu-fix/kanit/db-validation-3a69ea5d.md
@@ -0,0 +1,92 @@
+# DB Validation Raporu — 3a69ea5d
+
+- Tarih: 2026-10-17 22:28:27+0300
+- Migration: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-mu-fix/supabase/migrations/20261017100001_ovsync_mu_log_kolu.sql`
+- SHA-256: `3a69ea5d75ec89e5b0cd15786271bde76c6177ebc9e3f1d88d4273c96ad4337d`
+- Baseline (C1): {'tablo': 55, 'fonksiyon': 267, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': 'taze (nesne sayımı prod ile eşleşiyor: T=55 F=267 V=13)', 'parite_dosya': '/home/melik/tmp/agents/claude-1000/-home-melik--herdr-worktrees-egesut-erp1-istatistik-mod-l/e16a86bb-8b0a-42c2-b12a-2f3f236aa153/scratchpad/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} · parite: uyumlu
+- Data mode: koşulmadı (migration veri dokmuyor, --data-mode=auto)
+- Genel sonuç: **PASS**
+
+## Faz bazlı sonuç tablosu
+
+| Kriter | Sonuç | Not |
+|---|---|---|
+| A.sqlfluff-parse | PASS | parse hatası yok (stil uyarısı: 0) |
+| A.squawk | PASS | varsayılan kurallar (istisna: require-concurrent-index-creation,ban-drop-table) ihlal yok |
+| B.sema-uyum | PASS | tüm FROM/JOIN/ALTER/REFERENCES hedefleri biliniyor (ayna ya da migration-içi) |
+| C1.baseline-restore-schema | PASS | db=egesut_val_tmp parite=uyumlu meta={'tablo': 55, 'fonksiyon': 267, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': 'taze (nesne sayımı prod ile eşleşiyor: T=55 F=267 V=13)', 'parite_dosya': '/home/melik/tmp/agents/claude-1000/-home-melik--herdr-worktrees-egesut-erp1-istatistik-mod-l/e16a86bb-8b0a-42c2-b12a-2f3f236aa153/scratchpad/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} |
+| C1.migration-apply | PASS | psql ON_ERROR_STOP ile hatasız uygulandı |
+| C1.postcheck-nesne | PASS | migration-içi yaratılan tüm nesneler izole DB'de mevcut |
+| C1.postcheck-rls | PASS | RLS farkları: yok; etkilenen tablolar relrowsecurity: (yeni tablo ya da aynada yok) |
+| C1.ortam-paritesi | PASS | baseline parite_durumu=uyumlu |
+
+> VERİ UYUŞUMLULUĞU DOĞRULANMADI (data-mode=auto, veri dokan migration deseni saptanmadı: 0 eşleşme).
+
+## Uygulanan komutlar
+
+```bash
+$ sqlfluff lint --dialect postgres '/home/melik/.herdr/worktrees/egesut-erp1/ovsync-mu-fix/supabase/migrations/20261017100001_ovsync_mu_log_kolu.sql'
+$ squawk --exclude=require-concurrent-index-creation,ban-drop-table '/home/melik/.herdr/worktrees/egesut-erp1/ovsync-mu-fix/supabase/migrations/20261017100001_ovsync_mu_log_kolu.sql'
+$ psql egesut_lsp: tablo/view/fonksiyon isimleri (information_schema + pg_proc)
+$ timeout 900 bash '/home/melik/egesut-erp1/scripts/db-build-baseline.sh' --json --db-url postgres://postgres:val@127.0.0.1:5433/postgres  # (schema)
+$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovsync-mu-fix/supabase/migrations/20261017100001_ovsync_mu_log_kolu.sql'  # db=egesut_val_tmp
+```
+
+## Çıktı parçaları
+
+### FAZ A sqlfluff (`sqlfluff.out`)
+```
+== [/home/melik/.herdr/worktrees/egesut-erp1/ovsync-mu-fix/supabase/migrations/20261017100001_ovsync_mu_log_kolu.sql] FAIL
+L:   2 | P:   1 | LT05 | Line is too long (87 > 80). [layout.long_lines]
+L:   3 | P:   1 | LT05 | Line is too long (84 > 80). [layout.long_lines]
+L:  10 | P:   1 | LT05 | Line is too long (82 > 80). [layout.long_lines]
+L:  23 | P:   1 | LT05 | Line is too long (83 > 80). [layout.long_lines]
+L:  28 | P:   1 | LT02 | Line should not be indented. [layout.indent]
+L:  29 | P:   1 | LT02 | Line should not be indented. [layout.indent]
+L:  30 | P:   1 | LT02 | Line should not be indented. [layout.indent]
+L:  31 | P:   1 | LT02 | Line should not be indented. [layout.indent]
+L:  48 | P:   1 | LT05 | Line is too long (85 > 80). [layout.long_lines]
+L:  48 | P:  58 | CP02 | Unquoted identifiers must be consistently lower case.
+                       | [capitalisation.identifiers]
+All Finished!
+```
+
+### FAZ A squawk (`squawk.out`)
+```
+
+Found 0 issues in 1 file 🎉
+```
+
+### C1/C2 baseline (`baseline.out`)
+```
+[1;34m▶ FAZ-0 Ortam paritesi (Mgmt API, salt-okunur)…[0m
+[1;34m▶   Parite: uyumlu (prod=17.6 yerel=17.6) → /home/melik/tmp/agents/claude-1000/-home-melik--herdr-worktrees-egesut-erp1-istatistik-mod-l/e16a86bb-8b0a-42c2-b12a-2f3f236aa153/scratchpad/parite-egesut_val_tmp.txt[0m
+[1;34m▶   Ayna tazeliği: taze (nesne sayımı prod ile eşleşiyor: T=55 F=267 V=13)[0m
+[1;34m▶ İzole DB kuruluyor: egesut_val_tmp[0m
+NOTICE:  database "egesut_val_tmp" does not exist, skipping
+[1;34m▶ Roller kuruluyor (NOLOGIN)…[0m
+DO
+[1;34m▶ egesut_lsp aynasından pg_dump alınıyor…[0m
+[1;34m▶ Baseline izole DB'ye yükleniyor (ON_ERROR_STOP=1)…[0m
+[1;34m▶ pgTAP çekiliyor…[0m
+curl: (22) The requested URL returned error: 404
+[1;33m⚠ raw master pgtap.sql 404 (repo içinde üretilmiyor) — latest release zip'e düşülüyor…[0m
+Makefile:181: To use pg_prove, TAP::Parser::SourceHandler::pgTAP Perl module
+Makefile:182: must be installed from CPAN. To do so, simply run:
+Makefile:183: cpan TAP::Parser::SourceHandler::pgTAP
+[1;34m▶ pgTAP yükleniyor (370922 byte, ayrı 'pgtap' şemasına)…[0m
+ALTER DATABASE
+{"db_name":"egesut_val_tmp","tablo":55,"fonksiyon":267,"view":13,"pgtap_fn":1085,"parite_durum":"uyumlu","baseline_kaynak":"egesut_lsp","ayna_tazelik":"taze (nesne sayımı prod ile eşleşiyor: T=55 F=267 V=13)","parite_dosya":"/home/melik/tmp/agents/claude-1000/-home-melik--herdr-worktrees-egesut-erp1-istatistik-mod-l/e16a86bb-8b0a-42c2-b12a-2f3f236aa153/scratchpad/parite-egesut_val_tmp.txt","prod_pg":"17.6","yerel_pg":"17.6"}
+```
+
+### C1 apply (`apply.out`)
+```
+BEGIN
+SET
+SET
+CREATE FUNCTION
+REVOKE
+GRANT
+NOTIFY
+COMMIT
+```
diff --git a/runs/2026-10-17-ovsync-mu-fix/kanit/js-mutant-M1-iptal-yok.out b/runs/2026-10-17-ovsync-mu-fix/kanit/js-mutant-M1-iptal-yok.out
new file mode 100644
index 0000000..b6997a8
--- /dev/null
+++ b/runs/2026-10-17-ovsync-mu-fix/kanit/js-mutant-M1-iptal-yok.out
@@ -0,0 +1,10 @@
+✖ ovsync-mu-log-kolu-js: kabul matrisi (3.405029ms)
+✔ ovsync-mu-log-kolu-js: bağlam kabul kümesi (8.044795ms)
+✔ ovsync-mu-log-kolu-js: vaka detay barı (prod 232e7f7d deseni) (5.431661ms)
+ℹ tests 3
+ℹ pass 2
+ℹ fail 1
+✖ failing tests:
+✖ ovsync-mu-log-kolu-js: kabul matrisi (3.405029ms)
+    actual: true,
+    expected: false,
diff --git a/runs/2026-10-17-ovsync-mu-fix/kanit/js-mutant-M2-sablon-yok.out b/runs/2026-10-17-ovsync-mu-fix/kanit/js-mutant-M2-sablon-yok.out
new file mode 100644
index 0000000..f4ec0ed
--- /dev/null
+++ b/runs/2026-10-17-ovsync-mu-fix/kanit/js-mutant-M2-sablon-yok.out
@@ -0,0 +1,10 @@
+✖ ovsync-mu-log-kolu-js: kabul matrisi (3.526127ms)
+✔ ovsync-mu-log-kolu-js: bağlam kabul kümesi (5.267821ms)
+✔ ovsync-mu-log-kolu-js: vaka detay barı (prod 232e7f7d deseni) (5.435223ms)
+ℹ tests 3
+ℹ pass 2
+ℹ fail 1
+✖ failing tests:
+✖ ovsync-mu-log-kolu-js: kabul matrisi (3.526127ms)
+    actual: true,
+    expected: false,
diff --git a/runs/2026-10-17-ovsync-mu-fix/kanit/js-mutant-M3-iptal-gevsek.out b/runs/2026-10-17-ovsync-mu-fix/kanit/js-mutant-M3-iptal-gevsek.out
new file mode 100644
index 0000000..602e15b
--- /dev/null
+++ b/runs/2026-10-17-ovsync-mu-fix/kanit/js-mutant-M3-iptal-gevsek.out
@@ -0,0 +1,10 @@
+✖ ovsync-mu-log-kolu-js: kabul matrisi (3.433522ms)
+✔ ovsync-mu-log-kolu-js: bağlam kabul kümesi (5.38892ms)
+✔ ovsync-mu-log-kolu-js: vaka detay barı (prod 232e7f7d deseni) (5.900624ms)
+ℹ tests 3
+ℹ pass 2
+ℹ fail 1
+✖ failing tests:
+✖ ovsync-mu-log-kolu-js: kabul matrisi (3.433522ms)
+    actual: true,
+    expected: false,
diff --git a/runs/2026-10-17-ovsync-mu-fix/kanit/js-test-kirmizi.out b/runs/2026-10-17-ovsync-mu-fix/kanit/js-test-kirmizi.out
new file mode 100644
index 0000000..41fe903
--- /dev/null
+++ b/runs/2026-10-17-ovsync-mu-fix/kanit/js-test-kirmizi.out
@@ -0,0 +1,17 @@
+Running as unit: ram-exec-2004622-2004622.scope; invocation ID: a82b1d59a7ef48cf8cd0a7088bea4889
+✖ ovsync-mu-log-kolu-js: kabul matrisi (5.132704ms)
+✖ ovsync-mu-log-kolu-js: bağlam kabul kümesi (6.950463ms)
+✖ ovsync-mu-log-kolu-js: vaka detay barı (prod 232e7f7d deseni) (6.549155ms)
+ℹ tests 3
+ℹ pass 0
+ℹ fail 3
+✖ failing tests:
+✖ ovsync-mu-log-kolu-js: kabul matrisi (5.132704ms)
+    actual: true,
+    expected: false,
+✖ ovsync-mu-log-kolu-js: bağlam kabul kümesi (6.950463ms)
+    actual: true,
+    expected: false,
+✖ ovsync-mu-log-kolu-js: vaka detay barı (prod 232e7f7d deseni) (6.549155ms)
+    actual: 'block/block/flex',
+    expected: 'none/none/none',
diff --git a/runs/2026-10-17-ovsync-mu-fix/kanit/js-test-yesil.out b/runs/2026-10-17-ovsync-mu-fix/kanit/js-test-yesil.out
new file mode 100644
index 0000000..3ce664f
--- /dev/null
+++ b/runs/2026-10-17-ovsync-mu-fix/kanit/js-test-yesil.out
@@ -0,0 +1,22 @@
+Running as unit: ram-exec-2008776-2008776.scope; invocation ID: bff895892eb34b799927011a78c5b261
+✔ hastalik-modal-oneri-inaktif (17.061543ms)
+✔ hastalik-modal-bos-kist (7.273418ms)
+✔ tai-once-sonra (3.728132ms)
+✔ hastalik-kaydet-tek-rpc (6.004191ms)
+✔ f3-ok-false-kismi-basari (3.976278ms)
+✔ f3-istisna-sheet-kapanir (3.159414ms)
+✔ hastalik-cift-ekle-tek-cagri (32.851486ms)
+✔ hastalik-ac-offline-gizli (2.689241ms)
+✔ hastalik-kaydet-offline-durur (2.92314ms)
+✔ hastalik-kabul-yedek (1.973297ms)
+✔ tai-ertele-notu (1.453259ms)
+✔ s4-gun-hedefi-ebeveyn (4.064138ms)
+✔ yetim-rozet-baglamsiz (2.043348ms)
+✔ MUT-ALT-VAKA-KALINTI (83.48402ms)
+✔ k10-ilac-bar-yalniz-ovsync (27.89687ms)
+✔ ovsync-mu-log-kolu-js: kabul matrisi (5.910394ms)
+✔ ovsync-mu-log-kolu-js: bağlam kabul kümesi (5.807099ms)
+✔ ovsync-mu-log-kolu-js: vaka detay barı (prod 232e7f7d deseni) (7.634358ms)
+ℹ tests 18
+ℹ pass 18
+ℹ fail 0
diff --git a/runs/2026-10-17-ovsync-mu-fix/kanit/sql-test-kirmizi.out b/runs/2026-10-17-ovsync-mu-fix/kanit/sql-test-kirmizi.out
new file mode 100644
index 0000000..726a446
--- /dev/null
+++ b/runs/2026-10-17-ovsync-mu-fix/kanit/sql-test-kirmizi.out
@@ -0,0 +1,42 @@
+=== OVSYNC-MU LOG KOLU — izole DB testi ===
+BEGIN
+CREATE FUNCTION
+CREATE FUNCTION
+DELETE 0
+DELETE 0
+DELETE 0
+DELETE 0
+DELETE 0
+DELETE 0
+INSERT 0 2
+INSERT 0 2
+INSERT 0 1
+INSERT 0 8
+INSERT 0 8
+INSERT 0 6
+CREATE TABLE
+DO
+DO
+psql:tests/sql/ovsync_mu_log_kolu_test.sql:64: NOTICE:  trigger "trg_hayvan_kisir_zincir_bitir" for relation "public.hayvanlar" does not exist, skipping
+DROP TRIGGER
+CREATE TRIGGER
+DO
+DO
+    senaryo     | sonuc |                                                        kanit                                                         
+----------------+-------+----------------------------------------------------------------------------------------------------------------------
+ C-KISIR        | RED   | mastit=closed/ERKEN_KAPANIS ovsync=closed/ERKEN_KAPANIS
+ C-RPC          | RED   | rpc={"ok": true, "ilac": 0, "gun_id": "cd741730-f46e-48ad-8701-5362beb06df6", "mevcut": false, "ertelenen": 0} gun=1
+ G-YETKI        | RED   | (t,s,"{""search_path=public, pg_temp""}",t,t,t)
+ K-DAMGA        | PASS  | vaka 6: beklenen=t gelen=t
+ K-ESLEM        | PASS  | vaka 7: beklenen=t gelen=t
+ L-IPTAL-NULL   | RED   | vaka 8: beklenen=f gelen=t
+ L-MANUEL       | RED   | vaka 5: beklenen=f gelen=t
+ L-MASTIT-ACIK  | RED   | vaka 2: beklenen=f gelen=t
+ L-MASTIT-IPTAL | RED   | vaka 1: beklenen=f gelen=t
+ L-OVSYNC-ACIK  | PASS  | vaka 3: beklenen=t gelen=t
+ L-OVSYNC-IPTAL | RED   | vaka 4: beklenen=f gelen=t
+(11 satır)
+
+ROLLBACK
+psql:tests/sql/ovsync_mu_log_kolu_test.sql:94: ERROR:  OVSYNC-MU TEST RED: 8 / 11 senaryo kirmizi
+BAĞLAM:  PL/pgSQL function inline_code_block line 3 at RAISE
diff --git a/runs/2026-10-17-ovsync-mu-fix/kanit/sql-test-yesil.out b/runs/2026-10-17-ovsync-mu-fix/kanit/sql-test-yesil.out
new file mode 100644
index 0000000..88f5ee2
--- /dev/null
+++ b/runs/2026-10-17-ovsync-mu-fix/kanit/sql-test-yesil.out
@@ -0,0 +1,42 @@
+=== OVSYNC-MU LOG KOLU — izole DB testi ===
+BEGIN
+CREATE FUNCTION
+CREATE FUNCTION
+DELETE 0
+DELETE 0
+DELETE 0
+DELETE 0
+DELETE 0
+DELETE 0
+INSERT 0 2
+INSERT 0 2
+INSERT 0 1
+INSERT 0 8
+INSERT 0 8
+INSERT 0 6
+CREATE TABLE
+DO
+DO
+psql:tests/sql/ovsync_mu_log_kolu_test.sql:64: NOTICE:  trigger "trg_hayvan_kisir_zincir_bitir" for relation "public.hayvanlar" does not exist, skipping
+DROP TRIGGER
+CREATE TRIGGER
+DO
+DO
+    senaryo     | sonuc |                           kanit                           
+----------------+-------+-----------------------------------------------------------
+ C-KISIR        | PASS  | mastit=active/- ovsync=closed/ERKEN_KAPANIS
+ C-RPC          | PASS  | rpc={"ok": false, "error": "ANA_ACIK_OVSYNC_DEGIL"} gun=0
+ G-YETKI        | PASS  | (t,s,"{""search_path=public, pg_temp""}",f,f,t)
+ K-DAMGA        | PASS  | vaka 6: beklenen=t gelen=t
+ K-ESLEM        | PASS  | vaka 7: beklenen=t gelen=t
+ L-IPTAL-NULL   | PASS  | vaka 8: beklenen=f gelen=f
+ L-MANUEL       | PASS  | vaka 5: beklenen=f gelen=f
+ L-MASTIT-ACIK  | PASS  | vaka 2: beklenen=f gelen=f
+ L-MASTIT-IPTAL | PASS  | vaka 1: beklenen=f gelen=f
+ L-OVSYNC-ACIK  | PASS  | vaka 3: beklenen=t gelen=t
+ L-OVSYNC-IPTAL | PASS  | vaka 4: beklenen=f gelen=f
+(11 satır)
+
+ROLLBACK
+psql:tests/sql/ovsync_mu_log_kolu_test.sql:94: NOTICE:  OVSYNC-MU TEST PASS
+DO
diff --git a/runs/2026-10-17-ovsync-mu-fix/report.md b/runs/2026-10-17-ovsync-mu-fix/report.md
new file mode 100644
index 0000000..607932c
--- /dev/null
+++ b/runs/2026-10-17-ovsync-mu-fix/report.md
@@ -0,0 +1,73 @@
+# ovsync-mu-fix report (worker a6b6376bc95fb318a, ss-worker-high opus)
+
+> Root yazdı (2026-10-17): alt ajanın rapor dosyası yazması araçla engellendi
+> ("Subagents should return findings as text, not write report files."); içerik
+> worker'ın iki dönüş metninden birebir aktarıldı.
+
+sonuc: TAMAM
+kabul SHA: 4163167 (dal fix/ovsync-mu-log-kolu; taban 56900c3)
+Commit'ler: e7ba499 SQL test (kırmızı 8/11) · c38f0e3 migration · b48a0ba kanıt · d68be34 JS test (kırmızı) · 51389be JS fix + k10 testleri + ?v=20261017-01 · 074343e git mv → 20261017100001 · 4163167 kanıt
+BOYUT: migration 52 (≤80) · SQL test 94 (≤150) · ui.js +6/−2 (≤40) · JS test 59 (≤80) · iki eski testte 3 satır
+
+## Ana bulgu (MEASURED)
+Prod'da 5 vaka yanlış Ovsync sayılıyor (46 → 41). Açık 2'si aynı hayvanda (197): Klinik Mastit 232e7f7d, İnaktif Ovaryum aad17352. Veri bozulmadı: hiçbiri ERKEN_KAPANIS ile kapanmamış, hiçbirine hastalık günü açılmamış.
+
+| vaka | hastalık | durum | log | bugün yanlış olan |
+|---|---|---|---|---|
+| aad17352 | İnaktif Ovaryum | açık | `:MANUEL` | hastalık günü kabul edilir; kısır işaretlenirse kapanır |
+| 232e7f7d | Klinik Mastit | açık | NULL aileli şablon, iptal=true | aynı iki risk |
+| 0a23bc51 | İnaktif Ovaryum | kapalı | `:MANUEL` | etkisi yok |
+| 375a8d6a | Neonatal Zayıflık | kapalı | NULL aileli şablon, iptal=true | etkisi yok |
+| 1f03f184 | Tırnak Yarası | kapalı | NULL aileli şablon, iptal=true | etkisi yok |
+
+Prod'daki 23 iptal edilmiş OVSYNC şablon logunun hepsi zaten Ovsync damgalı vakalarda; `iptal=false` gerçek Ovsync vakasını düşürmüyor. İptali NULL log yok.
+
+## Değişiklik
+- `supabase/migrations/20261017100001_ovsync_mu_log_kolu.sql`: log kolu yalnız anahtardaki şablon OVSYNC ve log iptal değilse (`JOIN tedavi_sablonu t ON t.id::text = split_part(g.kaynak,':',3)` + `t.protokol_ailesi='OVSYNC'` + `g.iptal = false`). protocol_family ve hastalık eşlemesi kolları aynen; STABLE, DEFINER, search_path, REVOKE PUBLIC/anon/authenticated, GRANT yalnız service_role.
+- `tests/sql/ovsync_mu_log_kolu_test.sql`: 11 senaryo.
+- `js/ui.js` `_hastalikKabulMu`: log kolu yalnız `g.iptal===false` ve `kaynak` şablon id'si OVSYNC şablon kümesindeyse; `:MANUEL` ve NULL aileli şablon sayılmaz. Çağıranlar `_hastalikBtnSync`, `_ovsyncBaglamKur` (atlas) değişmedi. IDB `gorev_log` = `v_gorev_log_sync` (`kaynak`, `iptal` taşır).
+- `tests/unit/ovsync-mu-log-kolu-js.test.js` yeni; `k10-hastalik-modal` ve `k10-ilac-bar-yalniz-ovsync` yeni kurala çekildi.
+- `index.html`: `?v=20261013-09` → `20261017-01` (26 yer).
+
+## Etki
+Fonksiyonu iki yer çağırıyor (prod+demo pg_proc + repo grep): `ovsync_hastalik_gunu_ekle` (yanlış pozitifte mastit vakasına gün/ilaç yazar, TAI öteler) ve `_kisir_zincir_bitir` tetiği (kısırda vakayı ERKEN_KAPANIS kapatır); ikisi de izole DB'de düzeltme öncesi ölçüldü.
+
+## Testler
+- SQL: 8/11 RED → 11/11 PASS; mutantlar (iptal→true, OVSYNC→true, IS NOT TRUE) 3/3 RED. `sessiz_ovsync_dislama_test` iki durumda PASS; `ovsync_paketi_test`/`ovsync_takip_test` iki durumda ortam hatası (aynada ON CONFLICT hedefi / kizginlik_vaka_ac imzası yok), ilgisiz.
+- JS: 3/3 RED → hedefli 18/18 PASS; mutantlar M1 iptal yok, M2 şablon yok, M3 iptal!==true 3/3 RED.
+- Tam birim: 1598 / pass 1594 / fail 4 (LUNA-3, EG-7, EG-8, bc-tarih) = taban kümesi; `migration-sira-kilidi` PASS.
+- db-validate PASS, rapor SHA `3a69ea5d…` (yeni yolla da aynı). İlk iki yeni-yol koşusu ortam FAIL (istatistik oturumuyla paylaşılan `egesut_val_tmp`; ardından konteyner kapalı); üçüncü PASS.
+
+## :MANUEL kararı
+MANUEL Ovsync sayılmaz (yeni kural kendiliğinden sağlar). Prod'da MANUEL loglu 15 vakanın 13'ü zaten damgalı, 2'si bağımsız İnaktif Ovaryum; `vaka_tohumlama_ekle` genel eylem; §18.18.
+
+## Demo
+- Prova BEGIN…ROLLBACK 65 → 62; kalıcı uygulama gövde + schema_migrations tek transaction; md5 `28b209ab…` → `6fd299d3…`.
+- Yeniden adlandırma: demo `schema_migrations` `20261017000001 ovsync_mu_log_kolu` → `20261017100001` (DO bloğu, ROW_COUNT=1); md5 değişmedi.
+- Prod (CONFIRMED): md5 `28b209ab…`, max sürüm `20261013000005`; dokunulmadı.
+
+## Prod taslağı (sahip kapısı)
+1. Yedek, `BEGIN … ROLLBACK` provası; beklenen 41 (bugün 46).
+2. Gövde + `INSERT INTO supabase_migrations.schema_migrations(version,name) VALUES ('20261017100001','ovsync_mu_log_kolu')` tek transaction.
+3. Doğrulama: md5 `6fd299d3…`, düşen küme tam aad17352/0a23bc51/232e7f7d/375a8d6a/1f03f184, `veri-eslesme-kontrol.py hepsi`.
+4. JS (`?v=20261017-01`) aynı pencerede merge ile yayınlanır.
+5. Geri alma: `20261013000003_alt_vaka.sql` satır 70-88 geri yükle, kaydı DELETE; md5 `28b209ab…`.
+
+## Demo tarayıcı test listesi (UI kapısı)
+1. Klinik Mastit 232e7f7d (hayvan 197) detayında "+ Hastalık"/"+ İlaç" görünmez, `#cd-hastalik-bar` gizli (ekran + `display==='none'`); IDB `gorev_log`'da `TEDAVI_SABLON_TOHUMLAMA:232e7f7d…` satırı var mı raporlanır (iptal kaydı son-300 penceresinde değil; yoksa eski kodla da gizli çıkar, asıl kanıt birim testi).
+2. Damgasız yalnız `:MANUEL` loglu açık vaka varsa düğmeler görünmez; yoksa "uygulanamaz, birim kanıtlı".
+3. Damgalı (`protocol_family='OVSYNC'`) açık vakada düğmeler görünür, bar `flex`; "+ Hastalık" sheet'i açılır ("+ Hastalık — Küpe <no>"), kayıtsız kapatılır.
+4. Ovsync takip ekranında damgalı satırda "MUAYENEDE SORUN VARSA HASTALIK GÜNÜ AÇ" kartları görünür.
+5. Konsolda yeni JS hatası yok; `js/ui.js?v=20261017-01` yüklü.
+
+## Kapsam dışı bulgu
+`v_gorev_log_sync` kapalı/iptal logları son 300 ile sınırlıyor; tamamlanmış OVSYNC şablon logu pencereden düşerse JS log kolu false negatif verir (DB doğru). Bugün damga/eşlem kolları gerçek vakaları kapsıyor, risk düşük.
+
+## Varsayımlar
+- İptali NULL log sayılmaz (prod/demo'da yok).
+- Worktree'de `.env` yok; `refresh_lsp_schema.sh`, `db-build-baseline.sh`, `db-validate.sh` ana checkout'tan (/home/melik/egesut-erp1, 56900c3) koşuldu.
+- Yerel şema aynası prod'dan salt-okuma tazelendi.
+- Demo kalıcı uygulama kontrattaki "demo prova apply db-validate PASS sonrası serbest" kuralına dayanır.
+
+## Kanıt
+`runs/2026-10-17-ovsync-mu-fix/kanit/`: db-validation-3a69ea5d.md, sql-test-kirmizi/yesil.out, js-test-kirmizi/yesil.out, js-mutant-M1/M2/M3.out, birim-ozet.txt
diff --git a/supabase/migrations/20261017100001_ovsync_mu_log_kolu.sql b/supabase/migrations/20261017100001_ovsync_mu_log_kolu.sql
new file mode 100644
index 0000000..ef639af
--- /dev/null
+++ b/supabase/migrations/20261017100001_ovsync_mu_log_kolu.sql
@@ -0,0 +1,52 @@
+-- ════════════════════════════════════════════════════════════════════
+-- `_vaka_ovsync_mu` log kolu yanlış pozitif düzeltmesi (2026-10-17, sahip onayı "ok").
+-- Önceki tanım: 20261013000003_alt_vaka.sql §1b (prod+demo md5 28b209ab… MEASURED).
+--
+-- Hata: log kolu her `TEDAVI_SABLON_TOHUMLAMA:<case>:%` logunu Ovsync belirteci
+-- sayıyordu; aynı anahtarı tedavi şablonlarının opsiyonel "planlı tohumlama"
+-- adımı (20260730000001, 20260909000001) ve elle ekleme `:MANUEL`
+-- (20260730000002) da yazar → mastit/tırnak/neonatal vakaları "Ovsync" sayıldı
+-- (prod 5 vaka). Etki: `ovsync_hastalik_gunu_ekle` bu vakaları kabul ediyor,
+-- `_kisir_zincir_bitir` kısır işaretlemede bunları ERKEN_KAPANIS ile kapatıyordu.
+--
+-- Yeni kural (root ruling; istatistik `stat_vaka_ovsync_mu` ile aynı): log kolu
+-- yalnız anahtardaki şablonun `protokol_ailesi = 'OVSYNC'` olduğu VE log
+-- `iptal = false` olduğu durumda Ovsync sayar. `:MANUEL` anahtarı şablonsuzdur
+-- → saymaz. Diğer kollar (protocol_family damgası, OVSYNC-eşlemeli hastalık)
+-- AYNEN. İmza, LANGUAGE/STABLE/DEFINER/search_path ve yetkiler AYNEN
+-- (service_role dışı kapalı; anon EXECUTE YOK).
+-- Geri alma: 20261013000003_alt_vaka.sql §1b gövdesi CREATE OR REPLACE ile.
+-- ════════════════════════════════════════════════════════════════════
+
+BEGIN;
+
+-- squawk hijyeni: yeniden tanım öncesinde timeout'lar (emsal 20261013000003:26-27)
+SET LOCAL lock_timeout = '5s';
+SET LOCAL statement_timeout = '30s';
+
+CREATE OR REPLACE FUNCTION public._vaka_ovsync_mu(p_case_id uuid)
+ RETURNS boolean
+ LANGUAGE sql STABLE
+ SECURITY DEFINER
+ SET search_path TO 'public', 'pg_temp'
+AS $function$
+  SELECT EXISTS (
+    SELECT 1 FROM public.cases c
+     WHERE c.id = p_case_id
+       AND (c.protocol_family = 'OVSYNC'
+            OR (c.protocol_family IS NULL
+                AND (EXISTS (SELECT 1 FROM public.sablon_hastalik_eslem e
+                              JOIN public.tedavi_sablonu t ON t.id = e.sablon_id
+                             WHERE e.disease_id = c.disease_id AND t.protokol_ailesi = 'OVSYNC')
+                     OR EXISTS (SELECT 1 FROM public.gorev_log g
+                                  JOIN public.tedavi_sablonu t
+                                    ON t.id::text = split_part(g.kaynak, ':', 3)
+                                 WHERE g.kaynak LIKE 'TEDAVI_SABLON_TOHUMLAMA:' || c.id::text || ':%'
+                                   AND t.protokol_ailesi = 'OVSYNC'
+                                   AND g.iptal = false)))));
+$function$;
+REVOKE ALL ON FUNCTION public._vaka_ovsync_mu(uuid) FROM PUBLIC, anon, authenticated;
+GRANT EXECUTE ON FUNCTION public._vaka_ovsync_mu(uuid) TO service_role;
+
+NOTIFY pgrst, 'reload schema';
+COMMIT;
diff --git a/tests/sql/ovsync_mu_log_kolu_test.sql b/tests/sql/ovsync_mu_log_kolu_test.sql
new file mode 100644
index 0000000..06ec67d
--- /dev/null
+++ b/tests/sql/ovsync_mu_log_kolu_test.sql
@@ -0,0 +1,94 @@
+-- tests/sql/ovsync_mu_log_kolu_test.sql — `_vaka_ovsync_mu` log kolu yanlış pozitif kilidi (2026-10-17).
+-- HEDEF: YALNIZ yerel izole parite DB (db-build-baseline.sh çıktısı). Canlıya (demo/prod) bu betikle erişilmez.
+-- KOŞUM: psql "$ISO" -X -v ON_ERROR_STOP=1 -f tests/sql/ovsync_mu_log_kolu_test.sql → rc=0 hepsi PASS; rc!=0 en az biri RED.
+-- Kural (root ruling, istatistik `stat_vaka_ovsync_mu` ile aynı): log kolu yalnız anahtardaki şablon
+-- `protokol_ailesi='OVSYNC'` VE log `iptal=false` iken Ovsync sayar; `:MANUEL` anahtarı şablonsuzdur → saymaz.
+-- Diğer kollar (protocol_family damgası, OVSYNC-eşlemeli hastalık) AYNEN. Fixture + yan etkiler tek
+-- transaction'da, sonda ROLLBACK. Sabit uuid: pg_temp.omu_id(sınıf, no) — c=vaka, e=görev, 1=hastalık, 3=şablon, 5=eşlem.
+\echo '=== OVSYNC-MU LOG KOLU — izole DB testi ==='
+BEGIN;
+CREATE FUNCTION pg_temp.omu_id(p text, i int) RETURNS uuid LANGUAGE sql IMMUTABLE
+  AS $$ SELECT ('e2e00000-0000-4000-8000-0000000' || p || '0f' || lpad(i::text, 2, '0'))::uuid $$;
+CREATE FUNCTION pg_temp.bg() RETURNS date LANGUAGE sql STABLE AS $$ SELECT (now() AT TIME ZONE 'Europe/Istanbul')::date $$;
+DELETE FROM gorev_log WHERE hayvan_id LIKE 'E2E-OMU-H-%'; DELETE FROM cases WHERE animal_id LIKE 'E2E-OMU-H-%';
+DELETE FROM hayvanlar WHERE id LIKE 'E2E-OMU-H-%'; DELETE FROM sablon_hastalik_eslem WHERE sablon_id IN (SELECT id FROM tedavi_sablonu WHERE ad LIKE 'E2E-OMU-%');
+DELETE FROM tedavi_sablonu WHERE ad LIKE 'E2E-OMU-%'; DELETE FROM diseases WHERE name LIKE 'E2E-OMU-%';
+-- Hastalıklar: 1=Mastit (eşlemesiz), 2=Ovsync (OVSYNC şablonuna eşlemeli)
+INSERT INTO diseases(id, name, category) VALUES (pg_temp.omu_id('1',1), 'E2E-OMU-Mastit', 'Meme'), (pg_temp.omu_id('1',2), 'E2E-OMU-Ovsync', 'Üreme');
+-- Şablonlar: 1=mastit tedavisi (protokol_ailesi NULL, planlı tohumlama adımlı), 2=OVSYNC
+INSERT INTO tedavi_sablonu(id, ad, protokol_ailesi) VALUES (pg_temp.omu_id('3',1), 'E2E-OMU-MASTIT', NULL), (pg_temp.omu_id('3',2), 'E2E-OMU-OVSYNC', 'OVSYNC');
+INSERT INTO sablon_hastalik_eslem(id, sablon_id, disease_id) VALUES (pg_temp.omu_id('5',1), pg_temp.omu_id('3',2), pg_temp.omu_id('1',2));
+INSERT INTO hayvanlar(id, kupe_no, cinsiyet, durum, grup, padok, dogum_tarihi)
+  SELECT 'E2E-OMU-H-' || i, 'E2E-OMU-' || i, 'Dişi', 'Aktif', 'Sağmal (Laktasyonda)', 'Sağmal Padok', pg_temp.bg() - 800 FROM generate_series(1, 8) i;
+-- Vakalar (hepsi active): i → (hastalık, protocol_family)
+INSERT INTO cases(id, animal_id, disease_id, start_date, status, protocol_family)
+  SELECT pg_temp.omu_id('c', i), 'E2E-OMU-H-' || i, pg_temp.omu_id('1', d), pg_temp.bg() - 5, 'active', pf
+    FROM (VALUES (1, 1, NULL), (2, 1, NULL), (3, 1, NULL), (4, 1, NULL), (5, 1, NULL), (6, 1, 'OVSYNC'), (7, 2, NULL), (8, 1, NULL)) v(i, d, pf);
+-- TEDAVI_SABLON_TOHUMLAMA logları: vaka i → (şablon eki, iptal)
+INSERT INTO gorev_log(id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, kaynak, iptal, tamamlandi)
+  SELECT pg_temp.omu_id('e', i), 'E2E-OMU-H-' || i, 'TOHUMLAMA_PLANLI', 'E2E-OMU planlı tohumlama', pg_temp.bg() + 10,
+         'TEDAVI_SABLON_TOHUMLAMA:' || pg_temp.omu_id('c', i)::text || ':' || ek, ip, ip
+    FROM (VALUES (1, pg_temp.omu_id('3',1)::text, true),   -- mastit şablonu, iptal (prod 232e7f7d deseni)
+                 (2, pg_temp.omu_id('3',1)::text, false),  -- mastit şablonu, açık
+                 (3, pg_temp.omu_id('3',2)::text, false),  -- OVSYNC şablonu, açık
+                 (4, pg_temp.omu_id('3',2)::text, true),   -- OVSYNC şablonu, iptal
+                 (5, 'MANUEL', false),                     -- elle eklenen tohumlama
+                 (8, pg_temp.omu_id('3',2)::text, NULL)    -- iptal NULL (kolon nullable) → açık sayılmaz
+         ) v(i, ek, ip);
+CREATE TEMP TABLE _omu_durum(senaryo text PRIMARY KEY, sonuc text, kanit text);
+
+-- ── Sınıflama matrisi: (vaka, beklenen) — (i) yanlış pozitifler, (ii) OVSYNC logu, (iii) değişmeyen kollar
+DO $do$ DECLARE r record; v_g boolean; BEGIN
+  FOR r IN SELECT * FROM (VALUES
+      ('L-MASTIT-IPTAL', 1, false), ('L-MASTIT-ACIK', 2, false), ('L-OVSYNC-ACIK', 3, true),
+      ('L-OVSYNC-IPTAL', 4, false), ('L-MANUEL', 5, false), ('K-DAMGA', 6, true), ('K-ESLEM', 7, true),
+      ('L-IPTAL-NULL', 8, false)) v(ad, i, bek) LOOP
+    BEGIN
+      v_g := public._vaka_ovsync_mu(pg_temp.omu_id('c', r.i));
+      INSERT INTO _omu_durum VALUES (r.ad, CASE WHEN v_g IS NOT DISTINCT FROM r.bek THEN 'PASS' ELSE 'RED' END,
+        format('vaka %s: beklenen=%s gelen=%s', r.i, r.bek, v_g));
+    EXCEPTION WHEN OTHERS THEN INSERT INTO _omu_durum VALUES (r.ad, 'RED', SQLERRM); END;
+  END LOOP;
+END $do$;
+
+-- ── C-RPC (çağıran 1): mastit vakasına hastalık günü açılmaz → ANA_ACIK_OVSYNC_DEGIL, gün yazılmaz
+DO $do$ DECLARE v_r jsonb; v_n int; BEGIN
+  v_r := public.ovsync_hastalik_gunu_ekle(pg_temp.omu_id('c', 1), pg_temp.omu_id('1', 1), pg_temp.bg(), 7, '[]'::jsonb);
+  SELECT count(*) INTO v_n FROM treatment_days WHERE case_id = pg_temp.omu_id('c', 1);
+  INSERT INTO _omu_durum VALUES ('C-RPC', CASE WHEN v_r->>'error' = 'ANA_ACIK_OVSYNC_DEGIL' AND v_n = 0 THEN 'PASS' ELSE 'RED' END,
+    format('rpc=%s gun=%s', v_r, v_n));
+EXCEPTION WHEN OTHERS THEN INSERT INTO _omu_durum VALUES ('C-RPC', 'RED', SQLERRM); END $do$;
+
+-- ── C-KISIR (çağıran 2): kısır işaretleme mastit vakasını kapatmaz, OVSYNC-damgalı vakayı ERKEN_KAPANIS ile kapatır.
+-- İzole ayna tetik taşımaz → prod tanımı (20261013000003 §4) transaction içinde kurulur.
+DROP TRIGGER IF EXISTS trg_hayvan_kisir_zincir_bitir ON public.hayvanlar;
+CREATE TRIGGER trg_hayvan_kisir_zincir_bitir AFTER UPDATE OF kisir ON public.hayvanlar
+  FOR EACH ROW WHEN (NEW.kisir IS TRUE AND OLD.kisir IS DISTINCT FROM TRUE) EXECUTE FUNCTION public._kisir_zincir_bitir();
+DO $do$ DECLARE v_m text; v_o text; BEGIN
+  UPDATE hayvanlar SET kisir = true WHERE id IN ('E2E-OMU-H-1', 'E2E-OMU-H-6');
+  SELECT status || '/' || COALESCE(close_reason, '-') INTO v_m FROM cases WHERE id = pg_temp.omu_id('c', 1);
+  SELECT status || '/' || COALESCE(close_reason, '-') INTO v_o FROM cases WHERE id = pg_temp.omu_id('c', 6);
+  INSERT INTO _omu_durum VALUES ('C-KISIR', CASE WHEN v_m = 'active/-' AND v_o = 'closed/ERKEN_KAPANIS' THEN 'PASS' ELSE 'RED' END,
+    format('mastit=%s ovsync=%s', v_m, v_o));
+EXCEPTION WHEN OTHERS THEN INSERT INTO _omu_durum VALUES ('C-KISIR', 'RED', SQLERRM); END $do$;
+
+-- ── G-YETKI: imza/güvenlik aynen (DEFINER, STABLE, search_path; anon/authenticated EXECUTE yok)
+DO $do$ DECLARE v_p record; BEGIN
+  SELECT p.prosecdef, p.provolatile, p.proconfig, has_function_privilege('anon', p.oid, 'EXECUTE') AS an,
+         has_function_privilege('authenticated', p.oid, 'EXECUTE') AS au, has_function_privilege('service_role', p.oid, 'EXECUTE') AS sr
+    INTO v_p FROM pg_proc p WHERE p.oid = 'public._vaka_ovsync_mu(uuid)'::regprocedure;
+  INSERT INTO _omu_durum VALUES ('G-YETKI', CASE WHEN v_p.prosecdef AND v_p.provolatile = 's' AND NOT v_p.an AND NOT v_p.au AND v_p.sr
+    AND array_to_string(v_p.proconfig, ',') LIKE '%search_path=public, pg_temp%' THEN 'PASS' ELSE 'RED' END, format('%s', v_p));
+EXCEPTION WHEN OTHERS THEN INSERT INTO _omu_durum VALUES ('G-YETKI', 'RED', SQLERRM); END $do$;
+
+-- ── Özet + hüküm (ROLLBACK = temizlik). Beklenen senaryo sayısı: 11.
+SELECT senaryo, sonuc, kanit FROM _omu_durum ORDER BY senaryo;
+SELECT count(*) FILTER (WHERE sonuc <> 'PASS') AS omu_red, count(*) AS omu_toplam FROM _omu_durum \gset
+ROLLBACK;
+SELECT set_config('omu.red', :'omu_red', false), set_config('omu.toplam', :'omu_toplam', false) \g /dev/null
+DO $do$ BEGIN
+  IF current_setting('omu.toplam')::int <> 11 OR current_setting('omu.red')::int > 0 THEN
+    RAISE EXCEPTION 'OVSYNC-MU TEST RED: % / % senaryo kirmizi', current_setting('omu.red'), current_setting('omu.toplam');
+  END IF;
+  RAISE NOTICE 'OVSYNC-MU TEST PASS';
+END $do$;
diff --git a/tests/unit/k10-hastalik-modal.test.js b/tests/unit/k10-hastalik-modal.test.js
index a313031..e50e98a 100644
--- a/tests/unit/k10-hastalik-modal.test.js
+++ b/tests/unit/k10-hastalik-modal.test.js
@@ -183,21 +183,22 @@ test('hastalik-kaydet-offline-durur', async () => {
   await vm.runInContext(`hastalikGunKaydet('v-ana')`, ctx);
   assert.strictEqual(rpcCagrilari.length, 0, 'çevrimdışı RPC YOK, ölçülen: ' + JSON.stringify(rpcCagrilari));
 });
 
 test('hastalik-kabul-yedek', () => {
   const f = loadExtractedFunction('js/ui.js', '_hastalikKabulMu', { extra: ESC });
   const damga = { id: 'v1', status: 'active', protocol_family: 'OVSYNC' };
   assert.strictEqual(f(damga, {}), true, 'damga kazanır');
   const nul = { id: 'v2', status: 'active', protocol_family: null, disease_id: 'd9' };
   assert.strictEqual(f(nul, {}), false, 'NULL desteksiz kapalı (fail-closed)');
-  assert.strictEqual(f(nul, { gorevler: [{ kaynak: 'TEDAVI_SABLON_TOHUMLAMA:v2:7' }] }), true, 'NULL + tohumlama logu açık');
+  assert.strictEqual(f(nul, { gorevler: [{ kaynak: 'TEDAVI_SABLON_TOHUMLAMA:v2:7', iptal: false }], sablonlar: [{ id: '7', protokol_ailesi: 'OVSYNC' }] }), true, 'NULL + OVSYNC şablon tohumlama logu açık');
+  assert.strictEqual(f(nul, { gorevler: [{ kaynak: 'TEDAVI_SABLON_TOHUMLAMA:v2:7', iptal: false }] }), false, 'NULL + OVSYNC-dışı şablon logu kapalı (ovsync-mu-fix)');
   assert.strictEqual(f(nul, { eslem: [{ disease_id: 'd9', sablon_id: 's7' }], sablonlar: [{ id: 's7', protokol_ailesi: 'OVSYNC' }] }), true, 'NULL + şablon eşlemesi açık');
   assert.strictEqual(f({ ...nul, protocol_family: 'METRIT' }, { gorevler: [{ kaynak: 'TEDAVI_SABLON_TOHUMLAMA:v2:7' }] }), false, 'OVSYNC-dışı damga kapalı');
   assert.strictEqual(f({ ...damga, status: 'closed' }, {}), false, 'kapalı vaka kapalı');
 });
 
 test('tai-ertele-notu', () => {
   const f = loadExtractedFunction('js/ui.js', '_taiErteleNotu', { extra: ESC });
   assert.strictEqual(f('g1', []), '', 'kayıt yoksa suffix yok');
   const logs = [{ tip: 'TOHUMLAMA_ERTELE', ref_tablo: 'gorev_log', ref_id: 'g1', payload: { eski_tarih: '2026-10-15', yeni_tarih: '2026-10-20', ilk_hedef_tarih: '2026-10-15' } }];
   assert.strictEqual(f('g1', logs), ' (15.10 → 20.10)', 'ilk→hedef notu');
diff --git a/tests/unit/k10-ilac-bar-yalniz-ovsync.test.js b/tests/unit/k10-ilac-bar-yalniz-ovsync.test.js
index 7c12554..a93aa27 100644
--- a/tests/unit/k10-ilac-bar-yalniz-ovsync.test.js
+++ b/tests/unit/k10-ilac-bar-yalniz-ovsync.test.js
@@ -49,16 +49,16 @@ test('k10-ilac-bar-yalniz-ovsync', async () => {
     const vaka = { id: 'v-ov', status: 'active', protocol_family: 'OVSYNC' };
     const t = barCtx(vaka, {});
     await vm.runInContext('_hastalikBtnSync()', t.ctx);
     assert.strictEqual(disp(t.bar, 'cd-hastalik-btn'), 'block', 'ovsync: + Hastalık görünür');
     assert.strictEqual(disp(t.bar, 'cd-ilac-btn'), 'block', 'ovsync: + İlaç görünür');
     assert.strictEqual(t.bar.style.display, 'flex', 'ovsync: bar görünür');
   }
   // 3) NULL-aile + şablon TAI izli vaka → görünür.
   {
     const vaka = { id: 'v-t', status: 'active', protocol_family: null, disease_id: 'd9' };
-    const t = barCtx(vaka, { gorev_log: [{ kaynak: 'TEDAVI_SABLON_TOHUMLAMA:v-t:7' }] });
+    const t = barCtx(vaka, { gorev_log: [{ kaynak: 'TEDAVI_SABLON_TOHUMLAMA:v-t:7', iptal: false }], tedavi_sablonu: [{ id: '7', protokol_ailesi: 'OVSYNC' }] });
     await vm.runInContext('_hastalikBtnSync()', t.ctx);
     assert.strictEqual(disp(t.bar, 'cd-ilac-btn'), 'block', 'null+TAI: + İlaç görünür');
     assert.strictEqual(t.bar.style.display, 'flex', 'null+TAI: bar görünür');
   }
 });
diff --git a/tests/unit/ovsync-mu-log-kolu-js.test.js b/tests/unit/ovsync-mu-log-kolu-js.test.js
new file mode 100644
index 0000000..83c3eda
--- /dev/null
+++ b/tests/unit/ovsync-mu-log-kolu-js.test.js
@@ -0,0 +1,59 @@
+// tests/unit/ovsync-mu-log-kolu-js.test.js
+// ovsync-mu-fix (2026-10-17): JS aynası `_hastalikKabulMu` DB `_vaka_ovsync_mu`
+// (20261017100001) ile aynı kural: log kolu yalnız anahtardaki şablon
+// protokol_ailesi='OVSYNC' VE log iptal===false iken kabul; `:MANUEL` saymaz.
+'use strict';
+const test = require('node:test');
+const assert = require('node:assert');
+const vm = require('node:vm');
+const { loadExtractedFunction, extractFunctionSource, makeDomStub, makeElement } = require('./support/loadModule.js');
+
+const SB = [{ id: 's-mastit', protokol_ailesi: null }, { id: 's-ovs', protokol_ailesi: 'OVSYNC' }];
+const vaka = (id) => ({ id, status: 'active', protocol_family: null, disease_id: 'd-mastit' });
+const log = (id, ek, iptal) => ({ kaynak: 'TEDAVI_SABLON_TOHUMLAMA:' + id + ':' + ek, iptal });
+
+test('ovsync-mu-log-kolu-js: kabul matrisi', () => {
+  const f = loadExtractedFunction('js/ui.js', '_hastalikKabulMu');
+  const m = [
+    ['mastit şablonu iptal', log('v1', 's-mastit', true), false],
+    ['mastit şablonu açık', log('v1', 's-mastit', false), false],
+    ['MANUEL', log('v1', 'MANUEL', false), false],
+    ['OVSYNC şablonu iptal', log('v1', 's-ovs', true), false],
+    ['OVSYNC şablonu iptal yok (undefined)', log('v1', 's-ovs', undefined), false],
+    ['OVSYNC şablonu iptal null', log('v1', 's-ovs', null), false],
+    ['bilinmeyen şablon', log('v1', 's-yok', false), false],
+    ['OVSYNC şablonu açık', log('v1', 's-ovs', false), true],
+  ];
+  for (const [ad, g, bek] of m) {
+    assert.strictEqual(f(vaka('v1'), { gorevler: [g], sablonlar: SB }), bek, ad);
+  }
+  assert.strictEqual(f(vaka('v1'), { gorevler: [log('v2', 's-ovs', false)], sablonlar: SB }), false, 'başka vakanın logu');
+  assert.strictEqual(f({ ...vaka('v1'), protocol_family: 'OVSYNC' }, {}), true, 'damga kolu aynen');
+});
+
+test('ovsync-mu-log-kolu-js: bağlam kabul kümesi', () => {
+  const kur = loadExtractedFunction('js/ui.js', '_ovsyncBaglamKur', {
+    extra: { _hastalikKabulMu: loadExtractedFunction('js/ui.js', '_hastalikKabulMu') },
+  });
+  const gorevler = [log('v-mastit', 's-mastit', true), log('v-ovs', 's-ovs', false)];
+  const b = kur(gorevler, [vaka('v-mastit'), vaka('v-ovs')], [], { eslem: [], sablonlar: SB });
+  assert.strictEqual(b.ovsyncKabul.has('v-mastit'), false, 'mastit kümede değil');
+  assert.strictEqual(b.ovsyncKabul.has('v-ovs'), true, 'OVSYNC logu kümede');
+});
+
+test('ovsync-mu-log-kolu-js: vaka detay barı (prod 232e7f7d deseni)', async () => {
+  const govde = ['_hastalikBtnSync', '_hastalikKabulMu', '_hgSonGunId']
+    .map(a => extractFunctionSource('js/ui.js', a)).join('\n');
+  const kos = async (v, gl) => {
+    const doc = makeDomStub(); const wrap = makeElement('div'); const kapat = makeElement('div');
+    wrap.appendChild(kapat); doc.__setEl('cd-kapat-bolum', kapat);
+    const bar = makeElement('div'); doc.__setEl('cd-hastalik-bar', bar);
+    const idb = { gorev_log: gl, tedavi_sablonu: SB, sablon_hastalik_eslem: [] };
+    const ctx = { console, document: doc, _curCase: v, idbGetAll: async (t) => idb[t] || [] };
+    vm.createContext(ctx); vm.runInContext(govde, ctx); await vm.runInContext('_hastalikBtnSync()', ctx);
+    const d = (id) => (bar.children.find(c => c && c.id === id) || { style: {} }).style.display;
+    return [d('cd-hastalik-btn'), d('cd-ilac-btn'), bar.style.display].join('/');
+  };
+  assert.strictEqual(await kos(vaka('v-m'), [log('v-m', 's-mastit', true)]), 'none/none/none', 'mastit: gizli');
+  assert.strictEqual(await kos(vaka('v-o'), [log('v-o', 's-ovs', false)]), 'block/block/flex', 'OVSYNC logu: görünür');
+});
```
