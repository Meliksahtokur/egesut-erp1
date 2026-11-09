⟦ss-sub model=opus effort=high rol=ss-reviewer-kapi iş=Ovsync treni planı kapı tur 2: PLAN.md @9618d34 düzeltmelerini tur 1 bulgularına karşı yeniden ölç⟧
sonuc: TAMAM

```
VERDICT: KABUL
OKUDUM: kat1 yok (plan kapısı tur 2) · plan-report.md "## Düzeltme 1" tablosu (B1–B9) · git diff 3fe0cdd..9618d34 PLAN.md (+56/−28, eklenen satırların tamamı) · PLAN.md:184-199 bağlam · tur 1 raporu PLAN-KAPI-1-report.md · araç 6 (tur 2)
ÖLÇTÜM:
- git diff --stat 3fe0cdd 9618d34 → yalnız PLAN.md, 56+/28− (MEASURED); değişiklik haritası satırları (:94, :96, :98, :109-111, :186-196, :250-254, :339, :355, :365-367, :372, :396-398, :442, :460, :576, :583, :606-609, :631) diff'te birebir var (MEASURED)
- grep ground_truth.sql "aciklama::jsonb->>'day_id'" → 1703, 4528, 4551, 4571 (TEDAVI_GUN/SEANS gün id'si aciklama JSON'unda; R5 (c) tanımı gerçek veri biçimine uyuyor) (MEASURED)
- grep js/ui.js day_id → ui.js:554 ve :2602-2660 JSON.parse try/catch ile sarılı (mevcut idiyom) (MEASURED)
- Senaryo hesabı (TR-K7-HAFTA2): X'te ertele(X,1) sonrası 4 vakanın etiketi X+1; X+8 için küme (iii) `ovsync_tren = X+1` → 4/4; GnRH1'i yapılmış 2 vaka için R18 kayma = (X+8) − (X+7) = 1 → onizle(X+8,1) = BASTAN (1+1 > 1) → tur 1'deki iki KRİTİK yol kapanıyor (INFERRED, plan metninden elle hesap)
- Ritim dışı vaka hesabı: tek hayvan +k (k ≤ tolerans ≤ 2, kayma −1 payıyla ≤ 3) → günleri t+{0,7,8,9,10}, t ≡ X+k (mod 7) → hiçbiri ritim gününe düşmez → R7 "ritim dışı toptan kümesine girmez" K7'yi çiğnemiyor (INFERRED)
Tur 1 bulgu kapanışı:
- B1 KRİTİK (üyelik etiketi) — KAPANDI — PLAN.md:94 R3 "her kaymada ovsync_tren += k", :98 R7, :355 D6, testler :396 TR-K7-HAFTA2, :397 TR-K7-TOL, :398 TR-K7-RITIM.
- B2 KRİTİK (K5 birikimli) — KAPANDI — PLAN.md:109 R18 `_ovsync_pg1_kayma` (çapa = gerçek GnRH1 + 7), :355 `kayma + p_gun ≤ tolerans`, :366 TR-K5-N2 (ardışık +1 red), :367 TR-K5-2, :372 TR-K11-3; R13 aynı çapa (:104).
- B3 ÖNEMLİ (test yalıtımı) — KAPANDI — PLAN.md:186-196 SAVEPOINT/ROLLBACK TO + TEMP SEQUENCE sayaç + GUC sıfırlama + KB- kümesine süzme; TR-IZOL-1, TR-K10-GUC kendi savepoint'inde (:263).
- B4 ÖNEMLİ (K10 kilit kapsamı) — KAPANDI — PLAN.md:96 R5 (a)/(b)/(c) tek tanım, :252-254 `_ovsync_gorev_mu` + kilit formülü, :339 TR-K10-7/8/9, :460 JS eşi, :468 ortak tablo testi.
- B5 KÜÇÜK (R1 to_date) — KAPANDI — PLAN.md:92 trunc + EXCEPTION → OVSYNC_TREN_AYAR; :261 TR-AYAR-N2/N4.
- B6 KÜÇÜK (hızlı geri) — KAPANDI — PLAN.md:110 R19, :631 P11 "hızlı geriyle dönmeyenler".
- B7 KÜÇÜK (V3/G7 yürüyüşü) — KAPANDI — PLAN.md:583 e2e, :606-609 UI kapısı 13-14, kabul 14/14.
- B8 KÜÇÜK (bayrak-0 e2e) — KAPANDI — PLAN.md:576-577.
- B9 KÜÇÜK (R4 sapması) — KAPANDI — PLAN.md:111 R20, :442 mockup README etiketi.
İŞARETLİ (yeni, düzeltmenin doğurdukları):
- PLAN.md:98 + :385 — spec izlenebilirliği/§6 — ÖNEMLİ (ertelenebilir) — R7 "ritim dışı" vakanın Ovsync ekranında ayrı etiketli başlıkta göründüğünü söylüyor, SQL `ritim_disi:boolean` dönüyor; ama hiçbir UI görevi bunu çizmiyor: M1 mockup listesi (:411-418), UA1 `ovsyncTrenBaslikHtml`/`ovsyncTrenGrupla` (:457-458 civarı), UB3 ve UI kapısı tablosunda ritim_disi geçmiyor (grep "ritim" → yalnız :98, :385, :397, :398, :400). KANIT: design.md:143-144 "Kod öncesi her ekranın PNG mockup'ı sahip onayına". Daha sade hâli: M1 madde 2'ye ritim dışı başlık varyantı, UA1'e `başlık: ritim_disi → "ritim dışı" etiketi` testi, UI kapısına tek satır.
- PLAN.md:196-197 — test/kabul — KÜÇÜK — "Bölüm başında bayrak/çapa UPDATE protokol_ayar ile kurulur" artık senaryo başına ROLLBACK TO ile çelişiyor: senaryo dışında yapılan bölüm kurulumu sonraki bölümlere sızar, içinde yapılan ilk senaryodan sonra silinir. KANIT: PLAN.md:187-189 ↔ :196-197. Daha sade hâli: "bayrak/çapa her senaryonun DO bloğu içinde `kb_tren_ac(...)` ile kurulur".
- PLAN.md:94 (R3) + :355 — doğruluk/risk — KÜÇÜK — Etiket güncellemesi çağıranlarda (D6 `ovsync_hayvan_ertele`, D7 toptan) yapılıyor, `vaka_kalan_gunleri_kaydir` içinde değil; bayrak kapatılıp (R19 hızlı geri) vaka günleri kilitsiz kaydırılır, sonra bayrak yeniden açılırsa etiket bayat kalır, R14 yalnız NULL etiketleri doldurur (PLAN.md:105). Daha sade hâli: `vaka_kalan_gunleri_kaydir` (D5 zaten değiştiriyor) `ovsync_tren IS NOT NULL` ise aynı UPDATE'te `+= p_gun` yapsın; tek nokta. (INFERRED)
- PLAN.md:460 — idiyom — KÜÇÜK — `JSON.parse(t.aciklama).day_id` korumasız; mevcut kod ui.js:554 ve :2602 try/catch'li `_gorevAciklama` kalıbını kullanıyor; bozuk aciklama görev listesinin çizimini düşürür. SQL eşinde de (:252) `aciklama::jsonb` dökümü `gorev_tipi` kontrolünden SONRA (IF/CASE) yapılmalı, düz WHERE'de değerlendirme sırası garantisiz. (KANIT ui.js:554, ground_truth.sql:1703)
BLOKLAYAN: 0 · ERTELENEBİLİR: 4
NOKTA NOTU: Tur 2 yalnız değişen hunk'ları ve onların etkilediği R3/R5/R7/R18 yollarını ölçtü; değişmeyen D3/D4/D8 ve runbook tur 1'deki ölçümle (o zaman doğru) kabul edildi.
```

## Skorlar (6 boyut × 1-5)

| # | Boyut | Tur 1 | Tur 2 | Gerekçe |
|---|---|---|---|---|
| 1 | Spec izlenebilirliği | 4 | 4 | R20 ile R4 sapması sahibe görünür; yeni "ritim dışı" ekran durumu mockup/UI görevine bağlanmadı. |
| 2 | Domain-rules uyumu | 3 | 5 | K5/§18.19 birikimli tolerans (R18) ve K10 tip kapsamı (R5) spec ile birebir; §18.4/18.5/18.6/18.10 korunuyor. |
| 3 | Test/kabul gücü | 3 | 4 | Savepoint yalıtımı, birikimli ve iki haftalık senaryolar, V3/G7 yürüyüşü, bayrak-0 e2e eklendi; bölüm kurulumu cümlesi çelişkili, ritim_disi UI testi yok. |
| 4 | Görev bölünmesi | 5 | 5 | DAG/tek yazıcı değişmedi; yeni yardımcılar mevcut D2/D6/D7 düğümlerine doğru yerleşti. |
| 5 | Risk ve geri dönüş | 4 | 4 | R19 hızlı geri sınırı açık; bayrak kapat→aç arasında bayat etiket riski kalıyor (KÜÇÜK). |
| 6 | Uygulanabilirlik/doğruluk | 3 | 4 | İki KRİTİK yol kapandı (elle senaryo hesabıyla doğrulandı); R5 (c) gerçek aciklama JSON biçimine uyuyor; kalanlar idiyom/sağlamlık düzeyinde. |

**Ortalama: 26/6 = 4.33**, en düşük boyut 4 → **KABUL** (eşik ort ≥ 4.0, hiçbiri < 3).

Ertelenebilir 4 bulgu UA1/M1/D5 görev briefine tek satırlık ek olarak taşınabilir; plan için 3. tur gerekmiyor.

## Kırıntılar
- decision: KALİTE/kapı tur 2 KABUL 4.33 (4/5/4/5/4/4); tur 1'in 9 bulgusu kapandı.
- open_item: ritim_disi başlık UI/mockup bağlantısı (PLAN.md:98, :385) — UA1/M1 briefine.
