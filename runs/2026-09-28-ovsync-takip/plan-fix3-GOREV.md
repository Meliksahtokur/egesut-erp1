# GÖREV — Plan düzeltmesi 3: luna re-review bulguları (plan v3 → v4) — glm-max lead

İlk iş: /using-superpowers-obra, sonra Skill(writing-plans-obra). **ultracode YASAK.** Commit, kod, DB YAZMA YOK (demo'da salt-okuma sorgu serbest).
**GLM saat kuralı:** 08:50'yi geçtiyse yeni adım/alt-ajan başlatma; adımı bitir, /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-fix3-ILERLEME.md'ye yaz, dur. 13:00 sonrası "ILERLEME'den devam et" gelir.
**YASAK:** `.ss/` altına (HANDOFF, BOARD dahil) hiçbir dosya yazma; oturum handoff'u yazma. Kayıt yüzeyin yalnız kırıntı + DONE.

## Girdiler
- Review (DÜZELTME): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-rereview.md — A tablosundaki 7 KISMİ + D1–D8
- Plan (v3 → v4): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md
- SPEC v4 (OTORİTE): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/design.md (§6c, §10b, §10c, §10d, K14, K15)
- Domain: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.harness/references/domain-rules.md §14, §18.13–18.17
- Test kataloğu: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/test-senaryolari.md

## Yapılacak (numaralı; DONE birebir sayar)
1. **D1 — KRİTİK, MİMAR KARARI (bu yönde tasarla, yön değiştirme):** genel `tohumlama_sonuc_gebe` RPC'sinin `Bekliyor`-only kuralı DEĞİŞMEZ. Gebe işinin ortak gövdesini dahili bir çekirdeğe çıkar (ör. `_tohumlama_gebe_uygula(p_tohumlama_id, p_boş_duzeltme boolean)`; REVOKE PUBLIC/anon/authenticated, yalnız sarmal RPC'lerden çağrılır). `p_boş_duzeltme=true` yalnız `tohumlama_bos_ve_devam` muayene yolunda `p_secim='GEBE'` + `TAKIP_MUAYENE` görevinde ve şu koşulların HEPSİ varken: hedef tohumlama hayvanın SON tohumlaması, `sonuc='Boş'`, açık takip zinciri o tohumlamaya bağlı; aksi `RAISE`. Boş atamasının yan etkilerini (hayvanlar.tohumlama_durumu, iptal edilen görevler vb.) ve Gebe'nin yan etkilerini `20260830000031` gövdesinden ÇIKAR, hangisinin geri alındığını/yeniden kurulduğunu tabloyla yaz; audit izi (`islem_log` ya da mevcut desen) + `FOR UPDATE` + `GEBE_BULUNDU` kapanışı aynı transaction. GEBELIK_KONTROL yolunda tohumlama zaten `Bekliyor` → mevcut yol. Prova: T-05 Gebe varyantı + geri-alınma kanıtı.
2. **D2:** P1 S2 CTE'si `gebelik_muayene_listele`'nin predicate'lerinin TAMAMINI taşır (30 g tamamlanmış-cooldown dahil, `20260925000002:314-320`); T-45 cooldown'a giren + girmeyen hayvanla fark=0.
3. **D3:** `p_secim` kümesini görev tipine bağlı açık tabloya çevir — GEBELIK_KONTROL: {GEBE, OVSYNC, PG, TAKIP, ERTALE}; TAKIP_MUAYENE: {GEBE, OVSYNC, PG, ERTALE}. DB guard + UI aynı tabloyu kullanır.
4. **D4:** her PG giriş yolu (`hizli_uygulama`, `seans_tamamla`, `bulk_ilac`) için PG_KAPI + TAKIP_ACIK birleşik PREFLIGHT (yazmadan önce, `20260923000004:134-149` sırası) ve bulk için hayvan-bazlı onay listesi; tek retry yalnız onaylanan satırları aynı transaction'da kapatır/uygular. A2 akış haritasındaki tek düğümü üç RPC'ye aç.
5. **D5:** kilit sözleşmesi: `p_tohumlama_id` yolunda hedef tohumlama + hayvan satırı durum kontrolünden ÖNCE `FOR UPDATE`; `p_muayene_gorev_id` yolunda görev satırı; kilit sırası sabit (deadlock önleme) yazılır; T-72 iki-oturum provası tek kazanan.
6. **D6:** P7/P11 manifestine mevcut `tests/unit/ovsync-pg-ui.test.js:27-29` ve `tests/unit/gorev-kat-filtre.test.js` güncellemesini ekle (kırmızı→yeşil).
7. **D7:** `test-senaryolari.md` güncellemesini sahipli madde yap (öneri: test koltuğunun 1. adımı "kataloğu plana hizala") ve P12/P13 PASS'ının ön koşulu olarak yaz. Kataloğu SEN düzeltme.
8. **D8:** `gorev_log.farm_id` — demo DB'de `information_schema.columns` ile ÖLÇ (salt-okuma; bağlantı tarifi: proje belgeleri/bellek, demo dışına dokunma). Kolon varsa damga kalır; yoksa §14 gereği mevcut tabloya kolon EKLENMEZ, INSERT'ten damga çıkar ve bunu karar olarak yaz. Ölçüm çıktısını DONE'a koy.
9. **Kalan KISMİ'ler:** #16 elle Ovsync vaka RPC adı — canlı şemayı/demo'yu ÖLÇ ve kesin adı+imzayı yaz (tahmin yok; ölçemezsen BLOKE kalemi). #1/#3/#4/#5/#9/#13 yukarıdaki maddelerle kapanır — Review kapanış tablosuna "v4 kapanış" sütunu ekle.
11. **EK (sahip 2026-09-29, design.md §10e):** D1 sahip ONAYLI. D1-UI: üreme geçmişinde düzeltilen tohumlama İKİ SATIR — üstü çizili "❌ Boş (Boş giriş tarihi)" + "✅ Gebe (takip muayenesi tarihi)"; tahmini doğum Gebe'den. Kayıt izi eski sonucu + Boş giriş tarihini saklar (tohumlama'da sonuç tarihi kolonu var mı ÖLÇ). Üreme geçmişini render eden JS noktası (atlas_query; dosya:satır) → yeni UI alt maddesi + T eşlemesi + KATALOG GÜNCELLEME. D2 sahip ONAYLI.
12. **EK (sahip 2026-09-29, design.md §10e UI-R1):** hayvan kartı üreme geçmişi satırlarına göreli gün ("· N gün önce", "bugün", "dün"; hep gün). Aynı render noktası (11). Yerel tarih (Europe/Istanbul) gün farkı — saf yardımcı fonksiyon + Node birim testi (gece yarısı/UTC sınır vakası dahil). Ayrı küçük P alt maddesi, K15'ten bağımsız paralellenebilir.
10. Başlık v4; kapsama matrisi + izlenebilirlik güncel; SPEC çelişkisi çıkarsa "SPEC SORULARI" (uydurma cevap yok).

## Yazabileceğin dosyalar (liste dışı YASAK)
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-fix3-DONE.md, /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-fix3-ILERLEME.md
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.crumbs/ovsync-takip.jsonl (yalnız satır ekleme, role "lead")
Okuma alt-ajanları ≤6, dosya yazmaz.

## DONE
/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-fix3-DONE.md — TAMAM|KISMI|BLOKE; 1–10 her kalem ayrı satır (yapıldı/yer); D1 yan-etki tablosu özeti; D8 + #16 ölçüm çıktıları; yeni SPEC SORULARI.
Sonra SendMessage ile tek satır: `DONE: <mutlak yol> · sonuc: <...>` → alıcı oturum: **ovsync-takip-dd**.
