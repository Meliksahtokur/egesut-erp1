# ui-tur2 — GOREV zarfı: 25 maddelik UI turu YENİDEN KOŞUM (run 4 hükümsüz)

supersedes koşum: `ui-tur-GOREV.md` (zarf v1 — madde tanımları oradan geçerli, bu zarf koşum mühendisliğini düzeltir)

- **GOREV (bu dosya):** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/ui-tur2-GOREV.md`
- **DONE:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/ui-tur-DONE.md`
- **Liste (sözleşme):** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/ui-test-listesi.md` (25 madde; ⚠ 7/8/19 notlarıyla)
- **Önceki koşum çalışma dizini (YENİDEN KULLAN):** `/home/melik/tmp/agents/uitur-20261001/` — içinde `uitur.spec.js` (63KB, 25 madde), `playwright.config.js`, `clean.cjs`, `diag*.cjs`, `fix-sablon.cjs`, `run4.log`, `server.log`, `uitur-sonuc.json`

## Neden yeniden koşum (mimar hükmü 09:05)

Run 4 (08:35→08:50:55) makine kanıtı: **7 PASS / 18 FAIL** (`uitur-sonuc.json`). 18 FAIL'in
ezici çoğunluğu `E2E-UITUR-*` işaretli fixture satırlarının UI'de HİÇ görünmemesi (M9/M11/M13/
M14/M20/M21/M22/M25 doğrudan; M2/M3/M4/M5/M8/M10/M12/M15/M23/M24 dolaylı) — run4.log'da seed
hatası YOK → **tohumlama sessizce yarım kalmış** (`silent-success` deseni). P12 e2e süiti aynı
ürün yüzeyini 12/12 yeşil geçti → ürün şüphesi değil, koşum altyapısı. Bu yüzden run 4 kapı
hükmü TAŞIMAZ; 25 madde TEK tutarlı koşumda yeniden ölçülür.

## İLK İŞ — run 4 kanıtını yedekle (ezilme tuzağı)

    cp /home/melik/tmp/agents/uitur-20261001/uitur-sonuc.json /home/melik/tmp/agents/uitur-20261001/uitur-sonuc.run4.bak.json
    cp /home/melik/tmp/agents/uitur-20261001/run4.log /home/melik/tmp/agents/uitur-20261001/run4.bak.log

(Yalnız 7 PASS maddesi kanıt değeri taşır: M1, M6, M7, M16, M17, M18, M19 — yeni koşumda kırmızı
çıkarsa tur kırmızı sayılır, run4 hükmüyle çelişki rapor edilir.)

## Zorunlu mühendislik düzeltmeleri (bu zarfın özü)

1. **KÖK NEDEN ÖNCE:** spec'in tohum katmanını oku; neden bazı marker'lı satırlar
   (`E2E-UITUR-z/b/e/q/g/p/y`) DB'ye girdiği hâlde UI listesine düşmüyor (ya da hiç girmiyor)?
   `diag*.cjs` betikleri hazır — INSERT sonrası satırın DB'de VARLIĞINI psql/supabase ile
   DOĞRULA; üreme geçmişi render/filtre mantığındaki (js/gecmis.js / ui.js) görünürlük
   koşulunu ölç. **Hipotez kontrolü yapmadan tam tur koşma.**
2. **Precondition assertion (repo test sözleşmesi):** her veri-taşıyan madde ÖNCESİ fixture
   kurulumunun sonucunu ASSERT et (DB'de marker satır sayısı ≥1 VE UI'de satır görünür).
   Assert atarsa o madde **UNKNOWN** işaretlenir ve koşum DURMAZ ama DONE'da ayrı satır olur —
   sessiz FAIL yasak (fail-closed). Kök neden çözüldüyse UNKNOWN çıkmamalı.
3. **Kanarya kapısı:** tam turdan ÖNCE tek madde koş (M9 önerilir — en saf marker-görünürlük
   maddesi). Kanarya kırmızıysa tam turu BAŞLATMA; KISMI DONE yaz (durum: BLOKE, kanıt + teşhis
   + önerilen mimar eylemi) ve dur.
4. **Temizlik FK-güvenli:** `pg_application_event` DELETE yetkisi yoktu — temizliği marker bazlı
   yap (kendi marker'lı satırların), yetkisiz DELETE'i deneme; clean.cjs bu düzeltmeyle güncel.
5. **Ovsynch-56 şablonu:** `fix-sablon.cjs` (protokol_ailesi='OVSYNC') uygulanmış hâlde;
   koşum ÖNCESİ tekrar doğrula (NULL'sa uygula — prod hizası).

## Koşum sözleşmesi (v1 zarftan aynen)

- Docker `mcr.microsoft.com/playwright:v1.58.2-noble --network host`; worktree yerel sunucu +
  `?demo`; `NODE_PATH=/home/melik/egesut-erp1/node_modules`; **workers=1** (paylaşılan seed);
  EGESUT_DEMO initScript + IDB pull bekleme + temizlik deseni: `tests/e2e/ovsync-takip.spec.js`.
- Liste maddelerindeki "beklenen görünüm" metinleri SÖZLEŞMEDİR; kopya farkı FAIL'dir; ⚠ 7/8/19
  beklentileri maddedeki nottan.
- Sahip demo hesabı/şifresi ve geri-alma akışına DOKUNMA.
- RAM: koşum öncesi `free -g`; available <5 GB → dur, DONE'a yaz.
- Self-repair en fazla 2, YALNIZ koşum altyapısı (spec/fixture/betik); ürüne dokunma.
- ÜRÜN KODUNA YAZMA YASAK (js/, tests/, supabase/, index.html). FAIL düzeltilmez — rapor edilir.

## Yazma manifesti (TEK YAZICI)

1. `runs/2026-09-28-ovsync-takip/ui-tur-DONE.md` (create — yalnız sen)
2. `runs/2026-09-28-ovsync-takip/artifacts/uitur-*.png` (kanıt — run4 PNG'leri ezilir, yenisi yazılır)
3. `/home/melik/tmp/agents/uitur-20261001/**` (repo DIŞI — betikler, loglar, JSON)

## Kabul ölçütleri

1. 25/25 madde hükümlü DONE tablosu (madde → PASS/FAIL/UNKNOWN → kanıt PNG yolu → katman DOM/RPC/DB).
2. Her FAIL: kesin gözlem (beklenen/görülen), yüzey tahmini (ui.js satırı), çoğaltma adımı.
3. Koşum ortamı notları: sunucu portu, süre, kanarya sonucu, kullanılan seed doğrulama kanıtı.
4. Süre üst sınırı: **90 dakika** — dolarsa elindeki hükümlü tabloyla KISMI DONE yaz ve dur;
   asılı bırakma. DONE'dan sonra tek satır mesaj: `DONE: <mutlak yol> · sonuc: <TAMAM|KISMI|BLOKE>`.
