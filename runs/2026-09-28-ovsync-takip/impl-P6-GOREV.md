# impl-P6 — GOREV zarfı: S0–S4 render + KPA şeridi (js/ui.js)

- **Goal:** `G-20260930-OVSYNC-TAKIP-IMPL` (active)
- **Plan madde:** **P6** — `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:508-533` (MADDE DRIFT KAPISI: yalnız P6; P7 giriş hücreleri YOK)
- **Önkoşul:** P4 + P5 KABUL (api.js veri katmanı + iskelet yerinde).
- **GOREV (bu dosya):** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P6-GOREV.md`
- **DONE:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P6-DONE.md`

## Yazma manifesti (TEK YAZICI — liste dışı YASAK)

1. `js/ui.js` (MODIFY — render fonksiyonları; `loadOvsyncDash` gövdesi)
2. `index.html` (MODIFY — yalnız gerekiyorsa rozet/gün-şeridi CSS; mevcut sınıflar tercih edilir)
3. `tests/unit/ovsync-render.test.js` (create — P11 kırmızı iskeleti)
4. `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P6-DONE.md` (create)

## Zorunlu davranış protokolü

1. **İLK İŞ:** `/home/melik/.claude/skills/using-superpowers-obra/SKILL.md` oku ve uygula (sahip kuralı; SUBAGENT-STOP geçersiz).
2. **Kod öncesi:** domain-rules.md + ui-map.md + code-change-precheck skill; JS keşfinde ÖNCE `atlas_query` (openTaskDet, openCaseDet, renderCaseTimeline, ovsyncBaslat, _erteleBtnHtml konumları), sonra bitişik JSDoc+gövde.
3. **Kırmızı test ÖNCE:** `_ovsyncGunDurumu` matrisi + "bilinmiyor" yolları + KPA sınıf kuralı testleri — kirmizi gör, sonra uygula, yeşiltir.
4. **Bitiş kapısı:** `verification-before-completion-obra` — her iddia [CONFIRMED dosya:satır]/[OBSERVED komut] etiketli; `node --check js/ui.js` + test koşumu.

## Görev (plan P6 birebir — plan.md:516-529)

**Arayüz (Produces):** `renderOvsyncSayfa(veri)`, `_ovsyncKpaHtml(kpa)`, `_ovsyncBolumHtml(bolumAd, satirlar)`, `_ovsyncSatirHtml(satir)` — P7 yalnız `__ovsyncTakip.veri.kpa` okur.

**İş:**
1. KPA şeridi: Aktif · Bugün · Geciken · Muayene bekleyen · **Bekleyen başlatma (toplam; `(N takipte)` alt metni `bekleyen_baslatma_takipte` — S-6/#8)**.
2. S0 BUGUN & GECIKEN canlı kartlar — boşsa bölüm gizli.
3. S1 dalga gruplu satırlar (§4 satır şeması; gün etiketleri "1./2./3./4. uygulama").
4. Gün durum renkleri: tamam yeşil · plan amber · gecikti kırmızı · uygulanmadı soluk · tutarsız ⚠ (R12).
5. Satır aksiyonları MEVCUT motorlara: TAI → `openTaskDet` [ui.js:8702]; gün → `openCaseDet` [ui.js:9440] / `renderCaseTimeline` [ui.js:9521]; ▶ Başlat → `_ovsyncBaslatKilitHtml` [ui.js:1736] / `ovsyncBaslat` [ui.js:1799]; ertele → `_erteleBtnHtml` [ui.js:1767]. **PG dokunuşu yok** (§18.8).
6. **S2 (K15):** kalan_gun > 0 → sayaç, aksiyon yok; **kalan_gun ≤ 0 → "muayene vakti"** → satır aksiyonu birleşik muayene sonuç ekranı (P9 `_muayeneSonucAc` — P6'da çağrı noktası hazırlanır, ekran P9'da): `satir.muayene_gorev_id` doluysa o görevden; NULL ise hayvan detayına gider (§10d #2 KARAR: bilgi satırı; görev ertesi sabah cron'la doğar). Deneme rozeti "2. deneme — önceki boş" (son doğumdan, §18.14).
7. S3: hedef tarih sıralı; ilk 5 + "tümü (M)"; takiptekiler "🔍 takipte · muayene GG.AA SS:DD" rozeti (mockup 06).
8. S4: katlanır, `p_sonlanan_gun=60`; sonlanma rozeti + `toh_sonuc` (K6).
9. Tanınmayan yapı/alan/değer → "bilinmiyor" (§7.8 — sessiz varsayılan YOK).
10. Birim testler için saf eşleme fonksiyonları ayrıştırılır: `_ovsyncGunDurumu(tamamlandi_tarihi, hedef)` vb.

## Kabul ölçütleri (plan.md:531 birebir)

1. Birim matris yeşil (gün durumu 5+1 durum, bilinmiyor yolları, KPA sınıf kuralı).
2. Demo gözle denetimi mockup ana ekranla karşılaştırmalı (runs/2026-09-28-ovsync-takip/mockup/ — HTML karşılaştırma notu DONE'a; tam tarayıcı yürüyüşü P12'de).
3. 21g/50g/55g sabiti JS grep sıfır (esikler RPC'den).
4. S2 "muayene vakti" satırın aksiyonu P9 ekranına bağlanmış (T-39 K15 hali — P6'da çağrı noktası kanıtı).
5. `node --check js/ui.js`; `git diff --check` temiz; kırmızı→yeşil çıktıları DONE'da.

## Yasaklar

- `js/api.js`, `js/forms.js`, `js/app.js` yazımı (P4/P9/P5 dosyaları); P7 giriş hücreleri/K14 işi; yeni RPC çağrısı üretimi.
- Mockup dışı UI icat; mevcut sınıflar yerine yeni CSS yazmak (yalnız gerekiyorsa).
- Commit atma; PROD; `.ss/`, `main`; sessiz varsayılan; 2 self-repair tavanı.

## DONE şablonu

Başlık: `impl-P6-DONE — TAMAM|KISMI|BLOKE` · kabul maddeleri kanıtlı · kırmızı→yeşil çıktıları · mockup karşılaştırma notu · yazılan dosyalar · açık kalem.
