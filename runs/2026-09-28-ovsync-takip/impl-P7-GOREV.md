# impl-P7 — GOREV zarfı: girişler — 6. stat hücresi + 🔔 linki + Görevler köprüsü + K14 kategorisi

- **Goal:** `G-20260930-OVSYNC-TAKIP-IMPL` (active)
- **Plan madde:** **P7** — `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:535-557` (MADDE DRIFT KAPISI: yalnız P7; P8 devam seçici YOK)
- **Önkoşul:** P4 + P6 KABUL (api.js veri + KPA alanları yerinde).
- **GOREV (bu dosya):** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P7-GOREV.md`
- **DONE:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P7-DONE.md`

## Yazma manifesti (TEK YAZICI — liste dışı YASAK)

1. `js/ui.js` (MODIFY — `_dashStatRow` :259-270; `loadDash` :639-651; 🔔 `_showProtokolEkran` :2888-2963; `_katTipMap` :63-71; `_uremeVakaCaseIds` :84-86; Görevler görünümü)
2. `tests/unit/ovsync-pg-ui.test.js` (MODIFY — D6: :27-29 exact liste eskir; kırmızı→yeşil)
3. `tests/unit/gorev-kat-filtre.test.js` (MODIFY — D6: C3-1/C3-2/C3-5 güncelle; kırmızı→yeşil)
4. `tests/unit/ovsync-girisler.test.js` (create — P11 kırmızı iskeleti: stat sınıf kuralı 3 durum + kategori eşleme)
5. `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P7-DONE.md` (create)

## Zorunlu davranış protokolü

1. **İLK İŞ:** `/home/melik/.claude/skills/using-superpowers-obra/SKILL.md` oku ve uygula (sahip kuralı; SUBAGENT-STOP geçersiz).
2. **Kod öncesi:** domain-rules.md + ui-map.md + code-change-precheck skill; JS keşfinde ÖNCE `atlas_query`, sonra bitişik JSDoc+gövde.
3. **Kırmızı test ÖNCE** (yeni test) + **D6 mevcut testler kırmızı görülüp güncellenir** — iki yönlü kırmızı→yeşil kanıtı DONE'a.
4. **Bitiş kapısı:** `verification-before-completion-obra`; `node --check js/ui.js` + üç test dosyası koşumu.

## Görev (plan P7 birebir — plan.md:544-553)

1. `_dashStatRow` imzasına ovsync verisi parametresi; 6. `.sc` hücresi: `🔄 Ovsync ›` + aktif zincir sayısı; `onclick="goTo('ovsync')"` (R4: grid 2 kolon, yeni hücre son satırı tamamlar).
2. Sınıf kuralı: `S0>0 ∨ muayene vakti dolan>0 → 'alert'`; `yalnız bekleyen-başlatma>0 → 'warn'`; sakin → `'ok'`; bayat/hata → `'warn' + "?"`.
3. `loadDash` içinde `ovsyncTakipGetir()` çağrısı [ui.js:639-651 bölgesine].
4. 🔔 🌱 bölüm başlığına `sh-link` deseniyle "Tüm takibi aç →" [ui.js:472,480 kalıp; ekleme :2954/:2961 bölgesine].
5. **K14 görev eşlemesi:** `_katTipMap.ureme` → `['TOHUMLAMA_PLANLI','OVSYNC_BASLAT','GEBELIK_KONTROL','TAKIP_MUAYENE']`; `_katTipMap.muayene` → `GEBELIK_KONTROL` ÇIKARILIR (`['MUAYENE','VETERINER_KONTROL']`). Rozet/çip sayıları otomatik izler (`_allKatTips` türetilmiş).
6. **K14 vaka filtresi:** `_uremeVakaCaseIds` eşlemesi `protocol_family==='OVSYNC'`dan → **hastalık adı kümesi {Ovsync, Kistik Over, Anoestrus}** (`diseases.name` eşleşmesi; cases→disease_id→diseases join'i IDB verisiyle). `protocol_family='OVSYNC'` damgalı vakalar da KÜMEDE kalır. C3 sızıntı güveni: Metrit/Endometrit/Pyometra/RFM/Retensiyo Sekundinarum/Postpartum Hemoraji küme dışı — unit test pini. Hastalık kataloğu DEĞİŞMEZ.
7. Görevler: 🌱 Üreme çipi başlığına "Tüm ovsync takibi →" köprüsü (K9; yeni emoji YOK, varsayılan).
8. **D6 mevcut test güncellemeleri (kırmızı→yeşil):** `ovsync-pg-ui.test.js:27-29` exact liste `['TOHUMLAMA_PLANLI','OVSYNC_BASLAT']` → yeni dörtlü liste; `gorev-kat-filtre.test.js` C3-1 (hastalık-adı kümesi + damgalılar kalır), C3-2 (fixture K14 tipleri), C3-5 (`_planliUremeTipler` tam-liste). `_planliUremeTipler` türetimi kaynağını izler; C3-6 sayı kanıtı aynı kalır.
9. Görevler rozeti (IDB) ve can rozeti DEĞİŞMEZ (R2).

## Kabul ölçütleri (plan.md:555 birebir)

1. Sınıf koşulu birim testi yeşil (3 durum + bayat).
2. K14: GEBELIK_KONTROL görevi 🌱 Üreme çipinde görünür (Muayene'de DEĞİL) — unit test (T-03/T-57 K14 hali PW'si P12'de).
3. D6 iki dosyada kırmızı→yeşil kanıtı.
4. `node --check`; `git diff --check` temiz.

## Yasaklar

- `js/api.js`, `js/forms.js`, `js/app.js` yazımı; P8 devam seçici; hastalık kataloğu değişikliği; yeni emoji.
- KPA ≡ 🔔 uyarılar alt kümesi eşzamanlılığı PW kanıtı P12'ye ait (P7'de birim test yeter).
- Commit atma; PROD; `.ss/`, `main`; sessiz varsayılan; 2 self-repair tavanı.

## DONE şablonu

Başlık: `impl-P7-DONE — TAMAM|KISMI|BLOKE` · kabul maddeleri kanıtlı · D6 kırmızı→yeşil çıktıları · yazılan dosyalar · açık kalem.
