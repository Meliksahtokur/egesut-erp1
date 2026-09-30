# impl-P5-DONE — TAMAM

- **Goal:** G-20260930-OVSYNC-TAKIP-IMPL · **Plan madde:** P5 (plan.md:482-506)
- **GOREV:** runs/2026-09-28-ovsync-takip/impl-P5-GOREV.md
- **Dal:** ovsync-takip (worktree: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip) — commit ATILMADI (yasak), PROD'a dokunulmadı.
- **Tarih:** 2026-09-30 · **Self-repair:** 1/2 (tavan altında; bkz. §6)

## 1. Yazılan dosyalar (manifest uyumu)

| Dosya | İşlem | Kanıt |
|---|---|---|
| `index.html` | MODIFY — `#pg-ovsync` .pg bloğu | [CONFIRMED index.html:939-949; `git diff --stat`: +13 satır, 0 silme] |
| `js/app.js` | MODIFY — goTo scroll kancası + ovsync dalı | [CONFIRMED js/app.js:113-118 scroll kaydı; :137 zincir dalı; +7 satır] |
| `js/ui.js` | MODIFY — YALNIZ P5 iskeleti (durum makinesi + loader) | [CONFIRMED js/ui.js:539-602; +65 satır; mevcut hiçbir fonksiyona dokunulmadı — diff salt ekleme] |
| `tests/unit/ovsync-gezinti.test.js` | CREATE — P11 iskeleti (20 test) | [OBSERVED `ls`; 20/20 yeşil] |
| `js/api.js` | **DOKUNULMADI** (P4'ün dosyası — paralel koşuyor) | [OBSERVED `git status`: js/api.js modified kaydı P4'e ait; benim diff'imin dışında] |
| `js/utils/handlers.js` | **DEĞİŞİKLİK GEREKMEDİ** — manifest'te MODIFY vardı ama iskeletin istediği tek data-action (`nav-geri`) zaten mevcut; R13 "dokunma" gereği ek kayıt yazılmadı | [CONFIRMED js/utils/handlers.js:48 `'nav-geri': () => navGeriDon()`; :562-565 `navGeriDon` = `history.back()`, history boşsa `goTo('log')`] |

## 2. Kabul ölçütleri (GOREV §Kabul)

1. **Durum matrisi testi yeşil (4 durum)** — EVET.
   [OBSERVED `node --test tests/unit/ovsync-gezinti.test.js` → `tests 20 / pass 20 / fail 0`]
   - (i) bayrak_kapalı → açık mesaj [CONFIRMED js/ui.js:588-596 dal + test "P5 DOM (i)"]
   - (ii) bayat → "çevrimdışı · HH:MM verisi" seridi [CONFIRMED js/ui.js:565-569 etiket üretici + :593 serit]
   - (iii) veri:null → "İnternet yok — takip verisi alınamadı" [CONFIRMED js/ui.js:595]
   - (iv) taze → P6 yer tutucusu (loader; render P6'nın) [CONFIRMED js/ui.js:590-591; test "P5 sınır" renderOvsyncSayfa çağrı YASAK'ını pinler]
   - Ek: durum kararı SAF fonksiyonda pinli (`_ovsyncDashDurum`, js/ui.js:549) — P11/P6 matrisi bunu sürdürür. Sessiz boş YASAK: throw/eksik P4'te de açık mesaj [test "P5 DOM (iii-b)"].
2. **`node --check` tüm değişen JS; `git diff --check` temiz** — EVET.
   [OBSERVED `node --check js/app.js` OK · `node --check js/ui.js` OK · `node --check tests/unit/ovsync-gezinti.test.js` OK · `git diff --check` çıktısız (temiz)]
3. **Kırmızı→yeşil sırası kanıtı** — bkz. §4 (iki koşum çıktısı DONE'ya işlendi).
4. **R13 geri buton sözleşmesi** — EVET.
   - Buton: [CONFIRMED index.html:946 `data-action="nav-geri"` ‹ Geri]
   - Handler mevcut, dokunulmadı: [CONFIRMED handlers.js:48 → :562-565 `history.back()`]
   - `goTo('dash')` YOK: test kaynakta arar — pg-ovsync bloğunda ve navGeriDon gövdesinde yok [OBSERVED test "P5 gezinti: R13" yeşil; navGeriDon'un history-boşsa düşüşü mevcut davranış `goTo('log')`, R13 ihlali değil — pre-existing, dokunulmadı].

## 3. P5 iş maddeleri (plan.md:496-502) tek tek

- **Kırmızı test önce:** uygulama ÖNCE 18 kırmızı görüldü (bkz. §4).
- **#pg-ovsync iskeleti:** `.pg` deseni birebir (index.html:68-70 CSS'i) [CONFIRMED index.html:939 `class="pg"`]; başlık + ‹ geri [index.html:941-947].
- **goTo zinciri:** `else if (pg === 'ovsync')` dalı eklendi [CONFIRMED app.js:137]. Dosyanın W3 kısmi-yükleme disiplinine uygun `typeof` koruması kullanıldı (aynı desen :130 asistan dalında) — plan metnindeki çıplak çağrıyla işlevsel aynı, yüklenmemiş ui.js'te popstate'i çökertmez. pushState/popstate jenerik akışa katıldı (ek işlem gerekmedi; popstate `default:` dalı app.js:221 civarı zaten jenerik) [CONFIRMED app.js:219-222 default dal `goTo(pg,false)`].
- **Scroll sözleşmesi (§6b):** ovsync'ten ayrılırken `window._ovsyncScrollY` kaydı [CONFIRMED app.js:115-118 — `setState` ÖNCESİ, eski sayfa 'ovsync' iken]; `loadOvsyncDash` render sonrası geri yükleme [CONFIRMED js/ui.js:600-601]. DOM testi: 240 kaydet → render sonrası scrollTop=240 [OBSERVED test yeşil]; kayıt yokken dokunulmaz [OBSERVED].
- **Modal = sayfa geçişi değil:** yeni modal/yer tutucu eklenmedi; `_modalBackGuard`/modalStack/navGeriKarar zinciri AYNEN korundu [CONFIRMED handlers.js:513-538 değişmedi; popstate 'ovsync-yardim' vakası p5b'den mevcut app.js:191-197].
- **Alt-nav'a giriş YOK:** `nb-ovsync` hiçbir yerde yok [OBSERVED test "alt-nav'a giriş YOK" yeşil; index.html'de 0 eşleşme].

## 4. Kırmızı→yeşil kanıtı (iki koşum)

**KIRMIZI (uygulama öncesi):** [OBSERVED `node --test tests/unit/ovsync-gezinti.test.js`]
```
ℹ tests 20 · ✖ 18 · ✔ 2
✖ P5: durum makinesi fonksiyonları ui.js tanımlı... (TypeError: yok)
✖ P5 matris (i)...(iv), bayat etiketi, DOM (i)...(gez. durumu), gezinti (goTo zinciri + index bloğu), P5 sınır
✔ P5 gezinti: R13 (mevcut handler zaten doğru) · ✔ alt-nav'a giriş YOK (mevcut temizlik pini)
```
18 kırmızının hepsi "özellik yok" nedenli (sembol/markup/app dalı tanımsız) — yanlış-kırmızı yok.

**YEŞİL (uygulama sonrası):** [OBSERVED aynı komut]
```
ℹ tests 20 · ℹ pass 20 · ℹ fail 0
```

## 5. Tam süit koşumu (TDD "projenin komutu" şartı) ve sorumluluk ayrımı

[OBSERVED `NODE_PATH=/home/melik/egesut-erp1/node_modules npm run test:unit` → tests 1250 / pass 1244 / fail 6; worktree'de node_modules yok → ana checkout NODE_PATH (bilinen kurulum)]

6 kırmızının dağılımı — **hiçbiri P5 diff'ine ait değil**:
- 3 gerçek kırmızı **baseline'da da düşüyor** (HEAD'den geçici worktree açılıp aynı dosyalar koşuldu; değişikliğim yokken de kırmızı): `degisiklikler-etiketler` LUNA-3 (canlı DEMO şema erişimi ister — ortam-duyarlı), `vaka-toplu-ac` "gelecek güne tık" + "ay ‹/›" (bugüne-göre tarih-duyarlı, 30 Eylül kenarı). [OBSERVED baseline: 243 test / 3 fail; worktree temizlendi] — bellek kaydı "5.07 pre-existing" ile uyumlu.
- 2 kırmızı `ovsync-api.test.js` — **P4'ün süren TDD turu** (aynı worktree'de api.js paralel yazılıyor; koşumlar arası sayı değişiyor = aktif düzenleme). P5 kapsamı dışı.
- 1 satır, üst-suit çift sayımı (bc-tarih takvim parent'ı).

`ovsync-gezinti.test.js` tam süitte de 20/20 yeşil (fail listesinde yok) [OBSERVED].

## 6. Notlar / açık kalem

1. **P4 bağımlılığı (bilinçli, zarfsal):** `ovsyncTakipGetir` worktree'de henüz yok [OBSERVED grep 0 eşleşme]. `loadOvsyncDash` `typeof` korumalı: P4 yoksa `window.__ovsyncTakip` önbelleği varsa bayat, yoksa açık mesaj üretir (sessiz boş YASAK korunur). P4 merge olunca birincil yol devreye girer; P5 tarafında iş kalmaz.
2. **Self-repair 1/2:** İlk yeşil koşumda 19/20 — kalan kırmızı, iskelet içindeki P6 yorumunun `renderOvsyncSayfa(...)` yazımı taşımasıydı; test regex'ini zayıflatmak yerine kod yorumu çağrı-sözdiziminden arındırıldı (test katılığı korundu) [CONFIRMED js/ui.js:590-591].
3. **Blast radius:** `goTo` upstream 15 sembol (10 doğrudan), risk MEDIUM [OBSERVED gitnexus impact; hook şartı /tmp/blast-radius-done tazelendi]. Değişiklik salt ekleme (yeni else-if + setState-öncesi scroll kaydı) — mevcut 9 dalın hiçbirine dokunulmadı; MEDIUM etki bu nedenle sınırlı.
4. **Sınır disiplini:** render P6'nın (loadOvsyncDash gövdesi P6'da render'a bağlanacak), `_dashStatRow` girişleri P7'nin, `js/forms.js` P9'un — hiçbirine dokunulmadı. `index.html`'e yeni CSS eklenmedi (inline stil, P6'nın CSS maddesi boşta). F4 tarih kilidi: blokta native date input yok [OBSERVED test pinli].
5. **Açık kalem (P6'ya devir):** `window._curOvsyncPadok` / `_curOvsyncBolum{acik}` başlangıç değerleri P5'te kuruluyor [CONFIRMED js/ui.js:578-580]; bunları yazacak padok filtresi/bölüm katlama UI'sı P6'nın maddesi. Gezinti sözleşmesinin Playwright ayağı (dash⇄ovsync⇄tasks, ‹ history.back, modal-geri yalnız modal kapatır, scroll korunur) plan P12'nin kabulü — P5 birim katmanı pinli.
