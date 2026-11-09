# N4-brief — Ovsync treni UI (UB1–UB5): API, K8 kancaları, tren ekranı, görev/vaka kartı, 🔔 panel
job_id: j-20261109T124746Z-d3c3dd

tip: is
effort: xhigh (sinyal cokmodul + UI)
job: ovsync-tren N4
workspace: tedavi-arge
report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/N4-report.md
repo/dal: ~/.herdr/worktrees/egesut-erp1/ovsync-tren (dal ovsync-tren, uç 7ff1e7b). Açılışta `git branch --show-current` → `ovsync-tren` (detached YAPMA, rebase/merge YAPMA).

girdi (BAĞLAYICI, satır nolar buradan):
- Plan N4 bölümü: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/docs/plans/2026-11-09-ovsync-tren/PLAN.md :476-551 (UB1–UB5 davranış + testler), "Önceden cevaplanmış kararlar" :70-87, "Kapı tur 2 ekleri" :645-650. Spec: aynı klasörde design.md (K1–K11).
- Veri sözleşmesi + tanımlar + UA1 farkları + test tabanı (ÖLÇÜLMÜŞ): ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/UB-sozlesme-report.md — "Sözleşme tablosu" RPC alanlarının TEK kaynağıdır; alan uydurma.
- Ekler: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/UB-ekler.md (1–6).
- Mockup'lar (sahip onaylı, görünüm hedefi): ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/mockup/ (01a…07b .html/.png, MOCKUP-ONAY.md, _tren-yeni.css).
- UA1 modülü (saf, test edilmiş): ~/.herdr/worktrees/egesut-erp1/ovsync-tren/js/ovsync-tren.js + ~/.herdr/worktrees/egesut-erp1/ovsync-tren/tests/unit/ovsync-tren.test.js; rapor ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/UA1-report.md.
- Domain: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/.harness/references/domain-rules.md §18; UI haritası ~/.herdr/worktrees/egesut-erp1/ovsync-tren/.harness/references/ui-map.md.

## ROOT RULING (N4 dağıtım, 2026-11-09 — sözleşme raporu bulgularına bağlayıcı karar)

Genel: bayrak (tren aktif) KAPALIYKEN hiçbir yol, metin, düğme, RPC parametresi değişmez — mevcut testler bunu kilitler, onlara DOKUNMA. Sunucu yanıtı IDB bayrağına karşı kazanır (F12). RPC imza/dönüşü DEĞİŞMEZ (RPC genişletme yok); mockup bilgisi RPC'de yoksa aşağıdaki gibi indirilir.

- BOŞLUK-1 (PG1+48 s tarih/saati): `pg1_zaman` varsa istemci "≈ <gün> <saat>" (pg1_zaman + 48 s) gösterir, başında "≈"; `pg1_zaman` yoksa yalnız "PG1 + 48 s'te tohumla". Uygulandıktan sonra yanıttaki `tai_hedef` gösterilir.
- BOŞLUK-2 (dokunulmaz küpeler): yalnız sayı: "Dokunulmaz: 2 bağımsız · 1 ritim dışı" (`plan.dokunulmaz`). Küpe listesi yok.
- BOŞLUK-3 (bağımsız kart alt satırı): `bagimsizlar[]` üyesinde ne varsa (küpe, sonraki iş/tarih); neden/hastalık adı satırı YAZILMAZ (istemci türetimi yok).
- BOŞLUK-4 (Baştan başlat tren tarihi): eylemden ÖNCE düğme/metin tarih göstermez ("Baştan başlat → trene bin"); eylemden SONRA `ovsync_bastan_baslat` dönüşündeki `hedef_tarih` / `basladi` ile toast/metin ("Per 3 Ara treninde başlar" ya da "bugün başladı"). K11 sheet'inde (07b) `bastan_tren_gunu` gösterilmez, aynı kural.
- BOŞLUK-5 / F1: tren gruplaması `grp.S0 ∪ grp.S1` üyeleriyle yapılır; başlık sayısı sunucunun `uyeler.length`'idir; S0 kartları da `ovsyncAsamaAksiyonHtml` alır.
- F2: ritim dışı notu `ritim_disi_neden`'den üretilir (sabit metin kalkar).
- F3: aşama 0 "Sonraki trene aktar" etiketi hedef tarihi yalnız `ritim_disi=false` ise gösterir; eylem sonrası yanıttaki `yeni_tarih` gösterilir. Aşama 1 "+N" seçici 1..`pg_pay`; bağımsız aşama 0 1..7.
- F4: önizlemede `sonuc` null (aşama belirsiz) üye "Aşama belirsiz — Baştan başlat" satırıyla görünür, satırda baştan başlat eylemi; o üye çözülmeden toptan onay kapalı kalır (metin bunu söyler, sessiz kapalı değil).
- F5 / L-DB-DONE açık kalem 3: `ileri_vakalar`, `iptal_tai`, `basladi:false` + `yeniden_hedef` önizleme/sonuç metninde gösterilir; `ONCEKI_TREN_VAR` için hata metni (F7).
- F7: `ovsyncTrenHataMetni` raporda listelenen TÜM kodlara Türkçe metin verir; `OVSYNC_TREN_GUNU_DEGIL` sebep `ONCEKI_TREN_VAR` → "Önce <ilk_tren> treni ertelenmeli"; `DUSTU.dusenler[].sebep` özyinelemeli çözülür; `GECMIS_TARIH` yakalanır. Bilinmeyen kod ham mesajla görünür (sessiz değil).
- F8: `ovsyncTrenGorevMu` JSON.parse yalnız `aciklama` `^\s*\{` ile başlarsa (SQL M2:194-203 ile aynı); düz metin sessiz `false`, bozuk JSON görünür hata (Kapı tur 2 eki).
- F9 / UB-ekler 6: "Tren gününü ertele…" YALNIZ bugünden itibaren üyesi olan ilk ritim günü başlığında.
- F10 / UB-ekler 5: K8 modalı gecikmiş görevde "Görev <eski tarih> yerine <tren> trenine taşınır" der (`gorev_hedef_eski`); "(n hayvan)" = `uye_kupeler.length`.
- F11: `start_first_service_protocol` `basladi:false` dönüşünde `case_id` yok — UB2 çağıranları buna dayanmaz.
- F13: UB1 `RPC_TABLES` yazma girdileri PLAN listesi ∪ `drug_administrations` ∪ mevcut `start_first_service_protocol` / `protokol_iptal` / `seans_tamamla` haritalarının tabloları (api.js:418, :428-432 kalıbı). Salt-okuma RPC'ler haritaya GİRMEZ (EG-10 invariantı).
- F14: `_tren-yeni.css` içeriği `index.html` `<style>`'ına taşınır, AMA sahip kuralı: vurgu yalnız YAZI RENGİ; satır zemini, sol şerit, krem/beyaz panel YOK; sheet/modal mevcut uygulama stilinde.
- F15 / UB-ekler 3: UA1 inline `onclick` → UB3 bağlama kalıbı; SECIM geçerlilik koşulu tek yardımcı; Vazgeç/Onay satırı tek yardımcı.
- UB-ekler 1: `toast()` textContent (helpers.js:204, ölçüldü) — yine de `ovsyncTrenHataMetni` çıktısı innerHTML'e giderse `esc`.
- UB-ekler 2: `ovsyncTrenSor` `await o.acModal(...)` reddi yakalanır, toast; throw sızmaz.
- Damga: UB1 yeni `<script src="js/ovsync-tren.js?v=20261031-13">` (mevcut damgayla AYNI, `ui.js`'ten önce, istatistik/hayvan-takip bitişik bloklarının ARASINA DEĞİL); UB5'te tüm `?v=` + manifest tek adımda `20261110-1`.
- UB5 dahil tüm UB görevleri bu koltukta; UA1 düzeltmeleri (`js/ovsync-tren.js`) serbest.
- Test (adlı, her UB için PLAN'daki test listesi + aşağıdakiler): `F1 S0 üyesi tren başlığında`, `F4 belirsiz üye → onay kapalı + baştan başlat satırı`, `F7 ONCEKI_TREN_VAR metni`, `F8 düz metin aciklama → false, hata yok`, `F9 ertele düğmesi yalnız ilk başlıkta`, `BOŞLUK-4 eylem öncesi tarih yok`, `bayrak kapalı → eski html birebir`.
  Mutant (her biri ADLI testte kırmızı, MEASURED): (m1) F9 koşulunu kaldır; (m2) F8 `^\s*\{` ön koşulunu kaldır; (m3) UB2 V2 `p_bagimsiz:true` parametresini sil; (m4) bayrak kapalı dalını tren dalına düşür.
- Kapsam DIŞI: `supabase/**` (SQL, D9 kulvarı), mevcut testlerin beklentileri (yalnız ekleme), EG-7/EG-8 tarih düzeltmesi, `ui.js:3801` UTC günü, LUNA-3 haritası (N6'da), demo/prod DB (okuma dahil gerekmez), `.harness/references/**` (N5 doc kulvarı).

## Kabul

- Yeni testler kırmızı→yeşil + m1–m4 ADLI testte kırmızı (MEASURED, report'ta komut + çıktı).
- Tam birim suit: `fail 4` ve fail edenler TAM OLARAK taban dördü (LUNA-3 degisiklikler-etiketler.test.js:88, EG-7 erteleme-genel-ui.test.js:262, EG-8 :292, vaka-toplu-ac.test.js:2624 "ay ‹/›"); başka fail yok. pass sayısı > 2277.
- `etiket-tazelik`: yeni HATALI/DOĞRULANAMADI yok (taban: HATALI 15 / DOĞRULANAMADI 4, liste UB-sozlesme-report.md "Test tabanı"); yeni fonksiyonlar etiketli.
- BOYUT: üretim net ≤ +900 satır (js + index.html; test hariç). Aşımda gerekçe.
- Diff yalnız Yazılabilir'deki dosyalar. Report: `## Fan-out`, `## Self-review`, UB1–UB5 × (commit, test adları, PASS) tablosu, ruling → uygulama satırı (dosya:satır) tablosu; son commit SHA = dal ucu.
  Commit öneki `ovsync-tren N4 UB<k>:`; `git add <dosya>` dosya dosya (`-A`/`.`/`-u` YASAK), `git diff --cached --stat` kontrol; push YOK.
  TUI son satırı `DONE <report yolu>` / `SORU <report yolu>`.

Yazılabilir:
~/.herdr/worktrees/egesut-erp1/ovsync-tren/js/api.js
~/.herdr/worktrees/egesut-erp1/ovsync-tren/js/ui.js
~/.herdr/worktrees/egesut-erp1/ovsync-tren/js/forms.js
~/.herdr/worktrees/egesut-erp1/ovsync-tren/js/ovsync-tren.js
~/.herdr/worktrees/egesut-erp1/ovsync-tren/index.html
~/.herdr/worktrees/egesut-erp1/ovsync-tren/manifest.json
~/.herdr/worktrees/egesut-erp1/ovsync-tren/tests/unit/ovsync-tren.test.js
~/.herdr/worktrees/egesut-erp1/ovsync-tren/tests/unit/ovsync-tren-entegrasyon.test.js
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/N4-report.md
~/tmp/muse-ovsync-n4

## Bilinen tuzaklar

- Birim test koşumu: `cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && NODE_PATH=~/egesut-erp1/node_modules node --test tests/unit/*.test.js 2>&1 | tail -5` (worktree'de node_modules yok → NODE_PATH şart). Çıplak koşum kancaya takılırsa: betiği `$TMPDIR`'e yaz, `ram-ultracode exec --class test --wait 900 -- bash <betik>`. `etiket-tazelik`: `NODE_PATH=~/egesut-erp1/node_modules node scripts/etiket-tazelik.mjs`.
- Bu worktree'de eş zamanlı başka yazıcı: `supabase/**` ve `runs/2026-11-09-ovsync-tren/db/**` (D9 review/düzeltme). Onlara dokunma, staged alanında yalnız kendi dosyaların olsun.
- egesut JS keşfi: dosya taramadan ÖNCE atlas — `atlas_query`/`atlas_status` (MCP, tools-bank) | `atlas-sorgu <ara|tanim|fn|rpc|tablo|secici|olay|modul|etki|status> <arg>` (CLI, cwd worktree). Her UB görevi öncesi değişecek sembol için `etki` (PLAN N4 başı); `ozet` alanı rehberdir, gövde otoritedir. CLI rc 2/3/4 → LSP/grep.
- Mevcut testler `loadExtractedFunction` ile fonksiyon gövdesi çıkarır: imza/fonksiyon adını değiştirme, yeni parametre opsiyonel ve sonda.
- Bayrak kapalı dalı tek yerde: her kancada `ovsyncTrenAktif(...)` false → mevcut kod yolu aynen (kopya fonksiyon YAZMA).
- Offline: K8 yolları ve tren eylemleri online şartlı ("İnternet yok" toast, kuyruğa yazma YOK — Review Focus 5).
- Script sırası tuzakları: istatistik-atolye.test.js:90-101 ve hayvan-takip-pencere.test.js:889-896 bitişik blokları; `?v=` tek değer kuralı (ileri-gebe-duve-siralama.test.js:216).
- `JSON.parse` her yerde try/catch; bozuk veri görünür hata.
- Tarih yalnız TR: `Europe/Istanbul` günü (UTC `toISOString().slice(0,10)` YASAK yeni kodda).
- Spec'te olmayanı uydurma; varsayımı report'a `Varsayım:` satırıyla yaz. Mockup'la çelişen ruling'de ruling kazanır.
- Canlı DB'ye YAZMA; supabase_* yazma araçları YASAK. Mutant geri yükleme yedek dosyadan; `git checkout --` ve `git stash` YASAK.
- Yeni test dosyası yalnız `ovsync-tren-entegrasyon.test.js` (PLAN UB1); diğer testler `ovsync-tren.test.js`'e.

## Fan-out planı (zorunlu; yaprak sayısı serbest)

İç review + self-review TEK reviewer çocuğu.

cocuk-model: spark

Sıra: UB1 → UB2 → UB3 → UB4 → UB5 (PLAN bağımlılığı; aynı dosyaya tek yazıcı). Paralellik yalnız ayrık dosyada: UA1 düzeltmeleri (js/ovsync-tren.js + ovsync-tren.test.js: F2/F3/F4/F7/F8/F9/F15, UB-ekler 2/3) bir çocukta UB1 ile paralel; UB2–UB4 ui.js/forms.js'e sırayla.
Parça 1 (alt ajan): UA1 düzeltmeleri — js/ovsync-tren.js, tests/unit/ovsync-tren.test.js.
Parça 2 (alt ajan): UB1 — js/api.js, index.html, tests/unit/ovsync-tren-entegrasyon.test.js.
Parça 3..5 (alt ajan, sırayla): UB2, UB3, UB4 — js/ui.js, js/forms.js (+ api.js UB4), test ekleri entegrasyon dosyasına.
Parça 6 (alt ajan): UB5 + F14 CSS — js/ui.js panel, index.html damga/style, manifest.json.
Sen: entegrasyon, m1–m4 mutantları, tam suit + etiket-tazelik, ruling→uygulama tablosu, report, tek reviewer çocuğu.
