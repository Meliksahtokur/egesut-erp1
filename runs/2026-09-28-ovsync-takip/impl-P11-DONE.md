# impl-P11-DONE — TAMAM

- **Goal:** `G-20260930-OVSYNC-TAKIP-IMPL` · **Plan madde:** P11 (plan.md:660-683, birebir; madde drift yok)
- **GOREV:** `runs/2026-09-28-ovsync-takip/impl-P11-GOREV.md` · **Tarih:** 2026-09-30 → 10-01 (gece yarısı devirli teslim)
- **Sonuç:** 4/4 kabul kanıtlı — **TAMAM** (self-repair 0/2 — tek turda yeşil; test-harness düzeltmesi gerekmedi)
- **Zorunlu protokol:** using-superpowers-obra (ilk iş; SUBAGENT-STOP sahibin kuralıyla geçersiz sayıldı) → TDD (kilitleme testi: implementasyon P4-P10'da teslim olduğundan yeşil beklenir; kırmızı kanıtı **kanarya mutasyonuyla** verildi — aşağıda) → verification-before-completion-obra (taze komut çıktılarıyla) · domain-rules.md tam okundu (D3'ün kilitlediği §18.15/§18.17 davranışları bağlamı) · code-change-precheck: kapsam dışı — js/ kaynağı, migration, şema, RPC DOKUNULMADI (yalnız test dosyası yazımı; blast radius yaratmıyor). Commit ATILMADI (yasak).

## Yazılan dosyalar (manifest 3/3 — TEK YAZICI, liste dışı yazım YOK)

1. `tests/unit/ovsync-takip.test.js` (MODIFY, +78 satır): **D3 bölümü** — `d3DbSetleri()` migration okuyucu + `uiTamYukle()` (ovsync-secici.test.js loadUiSaf deseni) + 1 test; `fs` import'u + header bölüm satırı.
2. `tests/unit/ovsync-api.test.js` (MODIFY, +31/−1 satır): invalidate envanteri testi **P9/P10 sarmal yüzeyleriyle genişletildi** + tamlık kilidi (iki yönlü türetme) + forms.js negatif kilidi; test adı güncellendi (aşağıda sapma 1).
3. `runs/2026-09-28-ovsync-takip/impl-P11-DONE.md` (bu dosya).

`git status --porcelain tests/` → yalnız bu 2 dosya `M` [OBSERVED]. Geçici kanarya mutasyonları her ikisinde de yedekten `cp` ile geri yüklendi; kalıntı sayacı 0/0 [OBSERVED `grep -c KANARYA`].

## Kabul 1 — D3 secim-tablo senkron kilidi: YEŞİL + migration-CASE'i OKUYARAK kilitli

**Test:** `D3: _muayeneSecimleri tablosu migration DB CASE ile birebir — secim-tablo senkron kilidi` (tests/unit/ovsync-takip.test.js).

**İki kaynak:**

| Kaynak | Yer | İçerik |
|---|---|---|
| UI yardımcısı | `js/ui.js:2292-2295` `_devamD3` → `_muayeneSecimleri` (`js/ui.js:2301`) | GEBELIK_KONTROL: `[GEBE, OVSYNC, PG, TAKIP, ERTALE]` · TAKIP_MUAYENE: `[GEBE, OVSYNC, PG, ERTALE]` |
| DB CASE | `supabase/migrations/20260929000002_takip_gorev_ve_bos_devam.sql:683-686` | `v_gecerli := CASE v_gorev.gorev_tipi WHEN 'GEBELIK_KONTROL' THEN p_secim IN ('GEBE','OVSYNC','PG','TAKIP','ERTALE') ELSE p_secim IN ('GEBE','OVSYNC','PG','ERTALE') END;` (TAKIP_MUAYENE ELSE dalına düşer; muayene tipleri :605 guard'ıyla ikisiyle sınırlı) |

Test gövdesi `fs.readFileSync(REPO_ROOT/20260929000002_…sql)` ile CASE bloğunu KESER (`v_gecerli := CASE v_gorev.gorev_tipi` → `END;`), WHEN/ELSE kümelerini regex'le ayıklar ve (a) plan.md:674 birebir literalleriyle, (b) gerçek `_muayeneSecimleri` çıktısıyla sıralı-küme karşılaştırması yapar; D3 özü iki kaynakta ayrıca sınanır (TAKIP yalnız GEBELIK_KONTROL'de).

- **YEŞİL:** [OBSERVED `node --test tests/unit/ovsync-takip.test.js` → **31/31** (30 mevcut + 1 D3); dosya çifti → 48/48].
- **KIRMIZI kanıtı (kanarya):** gerçek kaynaklara mutasyon YASAK olduğundan kırmızı, test-dosyası kanaryasıyla verildi — D3 testinin migration ANCHOR'u geçici bozuldu → [OBSERVED fail 1, `AssertionError: migration D3 CASE bloğu bulunamadı (v_gecerli := CASE v_gorev.gorev_tipi) — migration metni değişti, D3 kilidi güncellenmeli`] → yedekten geri yüklendi (KANARYA 0) → 31/31 yeniden yeşil. Bu, "migration metni değişirse test kırılır" hükmünün doğrudan kanıtıdır (test boş-green tautolojisi değil).

## Kabul 2 — Invalidate envanteri P9/P10 sonrası kaynakla senkron (nokta → dosya:satır tablosu)

`_ovsyncTakipInvalidate` TEK üretim tanımı `js/api.js:1093`; çağrı noktaları yalnız `js/api.js:1135/:1138` (tohumlamaBosVeDevam gövdesi — ok:true ve ok:false/throw yollarında). ui.js/forms.js'te DİREKT çağrı 0 hit [OBSERVED grep]. Bu yüzden invalidate üreten ui.js yüzeyleri = sarmalı çağıran yüzeyler:

| Nokta (fonksiyon) | dosya:satır | Sarmal çağrıları | Sahip | Envanter |
|---|---|---|---|---|
| `tohumlamaBosVeDevam` (api.js içi nokta) | js/api.js:1132 (çağrılar :1135/:1138) | — | P4 | zaten kilitli (:258 testi) |
| `_pgKapiBosAtaUygula` | js/ui.js:2214 | :2222 (dry-run), :2244 (yazma), :2260 (takipRetry) | **P9** (md.5) | NOKTALAR'a EKLENDİ |
| `_devamSeciciAc` | js/ui.js:2462 | :2468 (açılış dry-run; P9 muayene sonuç akışı `_muayeneSonucAc` bu yolu kullanır) | P8 → P9 akışı | NOKTALAR'a EKLENDİ |
| `_devamSeciciOnayla` | js/ui.js:2682 | :2699 (onay), :2720/:2755 (TAKIP_ACIK/PG_KAPI:TAKIP_ACIK retry) | P8 + **P10** dalları | NOKTALAR'a EKLENDİ |
| forms.js | — | **0 çağrı** (tohSonuc Boş dalı seçiciye yönlendirir) | — | NEGATİF kilit eklendi |

- **TAKIP_ACIK catch'leri LİSTEYE GİRMEDİ** (zarf kuralı: yalnız gerçek invalidate üreten yüzeyler): `_takipAcikHata`/`_takipAcikAc`/`_takipTopluSheet` vb. P10 yüzeyleri cache'i invalide ETMEZ (onay sheet'i açar; retry kendi RPC'sini yeniden çağırır, sarmaldan geçmez) — grep kanıtı yukarıdaki 0-hit.
- **Tamlık kilidi (plan.md:670 "grep tabanlı senkron — muayene sonu akışları dahil"):** test artık sarmalı çağıran ui.js fonksiyonlarını KAYNAKTAN türetir (yorum satırları süzülür, `^(async )?function` sınırıyla kapsayan fonksiyon bulunur) ve kümenin `[_pgKapiBosAtaUygula, _devamSeciciAc, _devamSeciciOnayla]` ile birebir olduğunu assert eder — yeni sarmal çağıran yüzey listeye eklenmezse TEST KIRILIR (eksik yönü), listeden düşerse de kırılır (fazla yönü).
- **KIRMIZI kanıtı (kanarya):** SARMAL_YUZEYLERİ'ne geçici `ovsyncBaslat` eklendi → [OBSERVED fail 1, küme-senkron assertion] → geri yüklendi (kalıntı 0) → 17/17 yeşil.
- **YEŞİL:** [OBSERVED `node --test tests/unit/ovsync-api.test.js` → **17/17**].

## Kabul 3 — Kapsama matrisi özeti (plan.md:725+ — T bazında katman sahipliği; yeni artefakt DOSYASI YOK)

[OBSERVED programatik sayım — plan.md matrisi awk+node ile ayrıştırıldı]:

- **60 matris satırı** = 45 T satırı (**T-01..T-73 eksiksiz** — distinct 73 T, eksik YOK) + **15 ek satır** (KATALOG-yeni: +21/+35 kaldırma/temizlik, Dashboard 40 g, D1 geri-alınma, D1-UI, D4 üç-yol, Göreli gün, T-72b, C4, H6, H5, H8, C1, kizginlik_vaka_ac, C5).
- **T bazında katman girdileri** (bir T çok katmanlı): **DB 34 · PW 57 · UNIT 23 · İNSAN 1** (T-57).
- **P11 sahipli satırlar (7) — UNIT katman yeşil kanıt dosyaları:**

| Satır | Katman | Sahip P | Yeşil kanıt (UNIT) |
|---|---|---|---|
| T-44 (21/eşik hiçbir yerde yok) | UNIT | P11 | `tests/unit/ovsync-render.test.js:639` ESIK-SIZINTISI (21/50/55 yalnız `esikler` akışı) |
| T-50 (yazma sonrası invalidate) | UNIT | P4, P11 | `tests/unit/ovsync-api.test.js` invalidate envanteri — **bu teslimde P9/P10'a genişletildi + tamlık kilidi** |
| T-62 (RPC_TABLES disiplini) | UNIT | P4, P11 | `tests/unit/ovsync-api.test.js:62` (sarmal pull seti) + `:69` (harita-dışı invariant) |
| **D1-UI iki satır** (kalem 11) | PW+UNIT | P9, P11 | `tests/unit/ovsync-takip.test.js` KALEM11 (5 saf + 2 render; geri_alindi/çoklu/UTC dahil) |
| **Göreli gün etiketi** (kalem 12) | UNIT+PW | P9b, P11 | `tests/unit/ovsync-takip.test.js` gunFarkiEtiket (7 test; 23:30/00:30 sabit +03) |
| **H8** (40P01/55P03 mesaj, retry YOK) | UNIT+PW | P4, P11 | `tests/unit/ovsync-api.test.js` H8 (4 test; mock rpc çağrı sayısı 1) |
| **C1 çözücü üç vakası** | UNIT | P11 | `tests/unit/ovsync-takip.test.js` KALEM11 (geri_alindi dışlama / çoklu EN-SON / UTC gece yarısı) |

- **Bu teslimin yeni kalemi D3** (plan.md:674 P11 checklist; matris T-satırı yok — T-05/T-39 seçenek kümelerinin makine-kilidi): `tests/unit/ovsync-takip.test.js` D3 testi (Kabul 1). PW katmanı sahipliği P12'de (matris notu gereği burada tekrarlanmaz).

## Kabul 4 — Tam süit + statik kontroller

- **TAM SÜİT:** [OBSERVED `NODE_PATH=/home/melik/egesut-erp1/node_modules node --test "tests/unit/*.test.js"` → **tests 1405 · pass 1402 · fail 3**]. Baseline P10: 1404/1401/3 → +1 test (D3), +1 pass; **kırmızı üçlü PRE-EXISTING baseline kümesiyle BİREBİR**: `ay ‹/› sayfalama` + `gelecek güne tık` (2 tarih-duyarlı bc-tarih) + `LUNA-3 canlı DEMO` (canlı-DB). Yeni kırmızı YOK.
- **node --check:** [OBSERVED] tests/unit/ovsync-takip.test.js OK + tests/unit/ovsync-api.test.js OK (değişen tüm JS).
- **`git diff --check`:** [OBSERVED] boş çıktı, exit 0.
- **Sapma notu (komut):** zarftaki `node --test tests/unit/` dizin-argümanı bu Node'ta (v26.7.0) `MODULE_NOT_FOUND` verdi [OBSERVED]; baseline'ın kanıtlı glob deseni (`"tests/unit/*.test.js"`, P9/P10 DONE'lardaki aynı komut) kullanıldı — kanıt kümesi aynı.

## Bilinçli sapmalar (mimar ratifiyesine — sessiz sapma yok)

1. **Envanter testinin adı değişti:** eski ad "…(P9/P10 çağrıları buraya düşecek)" bir VAAD metniydi; P9/P10 teslim edildiğinden ad gerçek hâline çevrildi: "invalidate envanteri: P4 noktaları + P9/P10 sarmal yüzeyleri kaynakta senkron (tamlık iki yönlü)". Yalnız test adı+comment; davranış genişletme Kabul 2'de.
2. **`_devamSeciciAc`/`_devamSeciciOnayla` P8'de doğdu, envantere P9/P10 referans notuyla girdi:** zarf "P9'un yeni noktaları: muayene sonuç akışı → tohumlamaBosVeDevam çağıran yüzeyler" diyor — muayene sonuç akışının (K15 `_muayeneSonucAc`) RPC yüzeyleri bu iki fonksiyondur ve P10 TAKIP_ACIK/birleşik dalları `_devamSeciciOnayla`'ya dokunur; invalidate'i GERÇEKten ürettikleri için kural gereği listeye aldılar. Sahiplik etiketi tabloda ayrı verildi.
3. **Kırmızı-önce hükmünün uygulanma biçimi:** P11 kilitleme testidir — implementasyon teslim (P4-P10), dolayısıyla yazılan test birinci koşumda yeşildir (zarfın kendi öngörüsü). Kırmızı kanıt, kaynaklara mutasyon YASAK olduğu için kanarya mutasyonuyla (2 adet: D3 anchor, tamlık kümesi) verildi; her ikisi de yedekten geri yüklendi ve kalıntı 0 olarak doğrulandı. Bu, TDD'nin "watch it fail" gereğinin kilitleme-testi karşılığıdır.
4. **Envanter tamlık testi ek katman:** zarf "NOKTALAR listesine ekle" dedi; ek olarak iki yönlü türetme kilidi ve forms.js negatif kilidi EKLENDİ — plan.md:670'in "tamlık" kelimesinin birebir karşılığı; tek-yönlü includes listesi refactor'a karşı kör kalırdı.

## Açık kalemler (BLOKE değil)

1. **P10 retry yolları cache invalidate ETMİYOR** (hizli_uygulama/seans/bulk/vaka açma catch+retry'leri kendi RPC'sini yeniden çağırır, sarmaldan geçmez): envanter kuralı gereği listeye GİRMEDİLER. Pratik etkisi sınırlı — `ovsyncTakipGetir` her açılışta rpc çeker, bayat veri yalnız rpc HATA anında gösterilir; yine de zarf kuralının bilinçli sonucudur (mimar istersen ayrı kalem).
2. **PW katmanı kanıtları P12'de** (T-50, D1-UI, Göreli gün, H8 ve D3'ün tarayıcı provası — plan kabul metni gereği).
3. **api.js JSDoc :1089 "ui.js/forms.js'teki çağrı noktaları P9/P10'da eklenir" cümlesi bayatlaştı** (noktalar artık envanter testinde kilitli) — js/ yazımı bu zarfta yasak olduğundan dokunulmadı; P13 docs turunun doğal kalemi.
4. Kanarya yedekleri `~/tmp/ovsync-*.p11-kanarya-yedek` (geçici; restore sonrası artık gereksiz).

## Ölçüm komutları (özet)

- `node --test tests/unit/ovsync-takip.test.js` → 31/31 · `node --test tests/unit/ovsync-api.test.js` → 17/17 · çift → 48/48 [OBSERVED, kanarya-restore sonrası taze]
- `node --test "tests/unit/*.test.js"` → **1405/1402/3** (3 = baseline PRE-EXISTING kümesi birebir) [OBSERVED]
- Kanarya 1 (D3 anchor) → fail 1 ("migration D3 CASE bloğu bulunamadı") → restore → yeşil; Kanarya 2 (tamlık kümesi +ovsyncBaslat) → fail 1 → restore → yeşil [OBSERVED]
- `node --check` ×2 → OK; `git diff --check` → exit 0; `git status --porcelain tests/` → yalnız 2 manifest dosyası [OBSERVED]
