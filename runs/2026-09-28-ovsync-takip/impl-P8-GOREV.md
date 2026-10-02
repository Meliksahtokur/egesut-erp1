# impl-P8 — GOREV zarfı: devam seçici bileşeni ('bos' + 'muayene' modları)

- **Goal:** `G-20260930-OVSYNC-TAKIP-IMPL` (active)
- **Plan madde:** **P8** — `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:559-588` (MADDE DRIFT KAPISI: yalnız P8; P9 giriş bağlama YOK)
- **Önkoşul:** P4 + P6 KABUL.
- **GOREV (bu dosya):** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P8-GOREV.md`
- **DONE:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P8-DONE.md`

## Yazma manifesti (TEK YAZICI — liste dışı YASAK)

1. `js/ui.js` (MODIFY — yeni bileşen fonksiyonları)
2. `js/utils/handlers.js` (MODIFY — `data-action` kayıtları)
3. `index.html` (MODIFY — yalnız gerekiyorsa bottom-sheet CSS; `_pgKapiAc` inline stil deseni tercih edilir)
4. `tests/unit/ovsync-secici.test.js` (create — P11 kırmızı iskeleti)
5. `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P8-DONE.md` (create)

## Zorunlu davranış protokolü

1. **İLK İŞ:** `/home/melik/.claude/skills/using-superpowers-obra/SKILL.md` oku ve uygula (sahip kuralı; SUBAGENT-STOP geçersiz).
2. **Kod öncesi:** domain-rules.md + ui-map.md + code-change-precheck skill; JS keşfinde ÖNCE `atlas_query` (_pgKapiAc/_pgKapiKapat/_pgKapiHata/_pgKapiBosAtaUygula konumları), sonra bitişik JSDoc+gövde. Mockup copy sahip onaylı — BİREBİR: `runs/2026-09-28-ovsync-takip/mockup/` (01/02/03/05).
3. **Kırmızı test ÖNCE:** kilit matrisi, buton etiket üretimi, PG doz zorunluluğu, bayrak-kapalı koşulu testleri.
4. **Bitiş kapısı:** `verification-before-completion-obra`; `node --check` + test koşumu.

## Görev (plan P8 birebir — plan.md:568-584; mockup copy plan içinden KESİN)

**Arayüz (Produces):**
- `_devamSeciciAc(mod, baglam)` — `mod ∈ {'bos','muayene'}`; açılışta `tohumlamaBosVeDevam({p_secim:null,…})` dry-run → ön-bilgi; **dry-run `bayrak_kapali:true` → SEÇİCİ AÇILMAZ (#6):** "Ovsync/PG kuralları kapalı" notu + bugünkü Boş davranışı yaşar (S-5).
- `_devamSeciciKapat()` — `_pgKapiKapat` deseni [ui.js:1443-1448].
- Seçenek sabitleri mockup 01/05'ten aynen (plan.md:571): OVSYNC/PG/TAKIP etiket+rozet+alt metinleri.

**İş (plan.md:575-584 tam liste — bölümden oku):**
1. Bottom-sheet `_pgKapiAc` deseni (dinamik div, history girişli, arka plan tiki kapat [ui.js:1384-1425]).
2. 'bos' modu: sonuç çipleri ✅Gebe/❌Boş (Boş aktif) + hayvan bağlam satırı.
3. **'muayene' modu (K15):** başlık görev tipine göre; **seçenek seti `_muayeneSecimleri(gorevTipi)` yardımcısından üretilir (elle iki liste YAZILMAZ)** — GEBELIK_KONTROL {Gebe/Ovsync/PG/Takibe bırak/Ertele}, TAKIP_MUAYENE {Gebe/Ovsync/PG/Ertele}. Ertele: +7 ön ayar, saat SEÇİLEBİLİR VARSAYILAN SAATSIZ (§10d #3), `→ GG.AA [SS:DD]` canlı ön izleme; ≥21 g dry-run `takip_bilgi` → onay penceresi (S-7). TAKIP_MUAYENE'de TAKIP yok + bilgi kutusu "Boş atandı GG.AA · takip N. gün" + "🐄 Kızgınlıkta → tohumlama kaydına geç" link-butonu.
4. Grup başlığı "Devam nasıl olsun? (zorunlu)"; seçim zorunlu — seçilmeden ana buton pasif (S3).
5. Ön seçim Ovsync; kilit koşulları dry-run `ovsync_kilitli`+`kilit_gerekce` → Ovsync kartı `.kilitli` + amber gerekçe; ön seçim Takibe bırak'a düşer.
6. PG seçilince ürün+doz seçici: dry-run `son_pg` ön-dolu; doz boşsa Kaydet pasif.
7. Ana buton etiketleri (plan.md:581 — 'muayene' modunda "Boş ata" öneki YOK, S-10).
8. Dipnot: "Sonuç kaydı ve seçilen devam adımı tek işlemde yapılır".
9. Sunucu red işleme: `OVSYNC_SECIM_*`, `PG_KAPI:*` (`_pgKapiHata` yeniden kullanım), `TAKIP_ACIK:*` + birleşik payload (`PG_KAPI:TAKIP_ACIK`) → P10 tek sheet (P8'de red tanıma + yönlendirme noktası), `TAKIP_UZADI` (tek onay), `TOH_SONUCLU`/`TAKIP_KAPALI`, `MUAYENE_SONUC_GEREKLI`.
10. Offline guard: açılışta/dry-run hatasında seçici açılmaz — "İnternet yok" toast; bayat veriyle seçim YAPILMAZ.

## Kabul ölçütleri (plan.md:586 birebir)

1. Birim test yeşil: kilit matrisi, etiketler, bayrak-kapalı, saat seçimi (varsayılan saatsiz), 21 g eşik metni.
2. Mockup copy birebirlik gözle denetim (01/02/03/05) — DONE'a karşılaştırma notu.
3. `node --check` değişen JS; `git diff --check` temiz; kırmızı→yeşil çıktıları.

## Yasaklar

- `js/api.js`, `js/forms.js` yazımı; P9 giriş noktaları/bağlama; elle iki ayrı seçenek listesi (D3 tablosu ihlali).
- Mockup metnini değiştirme/paraphrase (sahip onaylı copy).
- Commit atma; PROD; `.ss/`, `main`; sessiz varsayılan; 2 self-repair tavanı.

## DONE şablonu

Başlık: `impl-P8-DONE — TAMAM|KISMI|BLOKE` · kabul maddeleri kanıtlı · kırmızı→yeşil çıktıları · mockup karşılaştırma notu · yazılan dosyalar · açık kalem.
