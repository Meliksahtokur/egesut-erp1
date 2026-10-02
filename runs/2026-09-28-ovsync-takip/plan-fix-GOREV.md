# GÖREV — Plan düzeltmesi (sol review 17 bulgu + sahip kararları) — glm-max lead

İlk iş: /using-superpowers-obra, sonra Skill(writing-plans-obra). **ultracode YASAK.** Commit, kod, DB yazma YOK.
**GLM saat kuralı:** 09:00–13:00 GLM durur. Saat 08:50'yi geçtiyse yeni adım/alt-ajan başlatma; o anki adımı bitir,
nerede kaldığını /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-fix-ILERLEME.md'ye yaz ve dur. 13:00 sonrası "ILERLEME'den devam et" gelir.

## Girdiler (oku)
- SPEC v4 (OTORİTE): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/design.md — özellikle YENİ K14, K15 ve §10c (review kararları tablosu), §10b
- Domain kuralları §18 (18.13–18.17 yeni), §14 (farm_id: tek-tenant, yalnız yeni nesne): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.harness/references/domain-rules.md
- Düzeltilecek plan: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md (önceki DONE: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-DONE.md)
- Review (17 bulgu, dosya:satır kanıtlı): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-review.md
- Test kataloğu (73 senaryo): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/test-senaryolari.md
- Mockup'lar: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/mockup/bos-devam/*.png, /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/mockup/v2/*.png

## Yapılacak
1. plan.md'yi yerinde düzelt: 17 bulgunun HER BİRİ §10c'deki karara göre uygulanır. Bulgu no → plan maddesi eşlemesini plan sonuna "Review kapanış tablosu" olarak yaz (bulgu # · karar · düzeltilen P maddesi/satır).
2. YENİ KAPSAM (K15 — en büyük değişiklik): mevcut gebelik muayenesi sistemi ile entegrasyon.
   - Önce KOD + TARAYICI ile anla (aşağıdaki "Akış doğrulama"): GEBELIK_KONTROL görevi nasıl doğar (cron gebelik_muayene_gorev_uret, 20260925000002:327,410), dashboard 40 g listesi (gebelik_muayene_listele, js/ui.js:614,2738), görev nasıl tamamlanır (gorev_tamamla, js/ui.js:8956-8973, js/forms.js:3891-3903), sonuç bugün nereden girilir (m-toh-det, forms.js:4347; gebeAta js/ui.js:5891).
   - Plan: GEBELIK_KONTROL ve TAKIP_MUAYENE aynı "muayene sonuç ekranı" bileşenini açar (Gebe · Boş→devam seçici · Muayeneyi ertele); GEBELIK_KONTROL sonuçsuz kapanamaz; cron/liste ile takip ekranı S2 aynı kaynak; tetikleyici kapanışlarla çakışma (ör. Gebe/Boş atanınca açık GEBELIK_KONTROL görevinin kapanması — tohumlama_sonuc_bos bugün zaten iptal ediyor) açıkça tasarlanır; eski sistemin değişen davranışı ayrı P maddesi.
3. K14 kategori: _katTipMap (js/ui.js:63-68) — GEBELIK_KONTROL + TAKIP_MUAYENE → ureme; üreme vaka filtresi (Ovsync, Kistik Over, Anoestrus) ile enfeksiyon/doğum sonrası (Metrit, Endometrit, Pyometra, RFM, Retensiyo Sekundinarum, Postpartum Hemoraji) ayrımı — filtrenin bugün nerede yaşadığını (_uremeVakaCaseIds js/ui.js:84 vb.) bul, yalnız eşleme güncellenir, hastalık kataloğu DEĞİŞMEZ.
4. P2/P3 bölünmesi (#16), kırmızı test iskeletleri önde (#17), T-01..T-73 kapsama matrisi (#15) — katalogdaki T'ler K14/K15 değişikliğiyle uyumsuzsa "KATALOG GÜNCELLEME" listesine yaz (kataloğu sen DÜZELTME).

## Akış doğrulama (ZORUNLU — sahip: "kod okumak yetmez, UI'da zinciri gör")
Değiştirdiğin her mevcut akış için (tohumlama sonuç modalı Boş/Gebe, PG kapısı "Boş ata ve uygula", GEBELIK_KONTROL görevi tamamlama, dashboard gebelik muayenesi listesi) demo'da tarayıcıda gerçekten yürü (Playwright, EGESUT_DEMO; tarif: bellek l4-sahip-yuruyusu-tarif; demo sahip şifresine DOKUNMA; salt-okuma yürüyüş — kayıt oluşturacaksan yalnız demo ve sonra not et).
Her akış için plan.md başına "Mevcut akış haritası" bölümüne mermaid (stateDiagram/flowchart) + ekran→fonksiyon→RPC→tablo zinciri + yürüyüş kanıtı (ekran görüntüsü yolu) yaz. Ekran görüntüleri: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/akis-yuruyus/.

## Yazabileceğin dosyalar (liste dışı YASAK)
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/akis-yuruyus/ (klasör altı: png + kısa notlar)
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-fix-DONE.md, /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-fix-ILERLEME.md
Okuma alt-ajanları ≤6, dosya yazmaz. DB'ye yazma yalnız demo UI yürüyüşü üzerinden ve DONE'da raporlanır; PROD'a dokunma.

## DONE
/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-fix-DONE.md — TAMAM|KISMI|BLOKE; 17 bulgunun kapanış özeti; K14/K15 için eklenen P maddeleri; yürünen akışlar + kanıt yolları; KATALOG GÜNCELLEME listesi; yeni SPEC SORULARI (uydurma cevap yok).
Sonra SendMessage ile dağıtana tek satır: DONE: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-fix-DONE.md · sonuc: <...>  (dağıtan oturum adı zarfı sana gönderen prompt'ta yazar)
