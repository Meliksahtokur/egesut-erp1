# L4-W5 — UI onarımı: luna L4-04/05/06/07/08 (teslim raporu)

- **Dal:** `agent/geri-alma-akisi-W5` (taban `agent/geri-alma-akisi` @ 5f483f2)
- **Rol:** glmf worker (W5). **Merge YOK, push YOK, DB YAZMA YOK** (W4 paralel).
- **Zarf:** `/home/melik/egesut-erp1/.ss/tasks/L4-W5-ui-onarimi.md`
- **Bağlayıcı:** `G-20260914-GERI-ALMA-AKISI.md` § "Onarım turu sözleşmesi" md.4-8.
- **Kapsam:** yalnız UI/istemci; motor (L4-01/02/03 + telafi INSERT'inin gerçek
  tipi) W4'ündür — bu teslim **demo'ya hiçbir şey yazmadı**, canlı RPC
  davranışı lead entegrasyonunda ölçülür.

## 1. Dosya kapsamı

| Dosya | Değişiklik |
|---|---|
| `js/gecmis.js` | L4-05 resolver zaman yedeği + L4-06 allow-list/etiket (+yorumlar) |
| `js/degisiklikler/degisiklikler.js` | L4-04 rehber seviyesi + L4-07 `_dgDegerMetni`/plan-kart pk katlaması |
| `js/ui.js` | L4-07 `_islemDetaySatirlariHtml` (SAF, esc'li, küpe) + ölü-buton onarımı |
| `js/utils/modal.js` | L4-08 openM tek-entry guard'ı |
| `index.html` | `?v=` TEK yeni değer **20260914-09** (26 yer) |
| `tests/unit/geri-al-hedef.test.js` | L4-05 sözleşme testleri (3 yeni) + eski created_at testi güncellendi |
| `tests/unit/geri-al-baslik.test.js` | L4-06 etiket testi güncellendi (harf-kümesi vektörleri) |
| `tests/unit/gecmis-pipeline.test.js` | 5-tip → 6-tip allow-list testi |
| `tests/unit/gecmis-geri-alindi.test.js` | **YENİ** — L4-06 pipeline + etiket (5 test) |
| `tests/unit/islem-detay-guvenli.test.js` | **YENİ** — L4-07 adversarial esc/UUID (13 test; review kilidi dahil) |
| `tests/unit/geri-al-rehber.test.js` | L4-04 `_dgRehberTokenlari` seviye testleri (2 yeni) |
| `tests/unit/modal.test.js` | L4-08 tek-entry testleri (3 yeni) |
| `tests/geri-alma-w3-nav.spec.js` | L4-08 E2E: S5-L4-08 (yapısal) + S3-L4-08 (gerçek akış) |

## 2. Bulgu × düzeltme tablosu

| Bulgu | Konum (önce) | Düzeltme | Kanıt |
|---|---|---|---|
| **L4-05** zaman yedeği fiilen çalışmıyordu: resolver ref yolunda yalnız `created_at` arıyor (canlıda YOK), `tarih`i hedefe koymuyordu | `js/gecmis.js:126-147` | ref yolu + tip-fallback: `zaman = entry.tarih \|\| entry.created_at` (savunmacı fallback korundu); köprü (`degisim_txid`) önceliği AYNEN; modül sözleşme yorumu güncellendi | unit: `geri-al-hedef.test.js` — L4-öncesi satır (tarih'li, txid'siz) → zamanlı hedef; iki tarihli aynı satırda her kart KENDİ zamanını taşır (eski olay eski zamanla eşlenir) |
| **L4-04** rehber satırı `seviye:'islem'` ile çağrılıyordu (çok satırlı tx tümünü geri alır) | `js/degisiklikler/degisiklikler.js:547` | yeni SAF `_dgRehberTokenlari()` — seviye `'satir'` sabit; `_dgRehberBloku` tokenları buradan basar (data-hi hizası korunur) | unit: `geri-al-rehber.test.js` "L4-04 — tokenlar seviye 'satir' taşır (islem asla)" + bozuk-girdi güvenliği |
| **L4-06a** `GERI_ALINDI` allow-list dışı → telafi kartı listeden düşüyor | `js/gecmis.js:16,212,224` | `_GM_ISLEM_TIPLERI` += `GERI_ALINDI` (defter `_gmPolicyRow` + klasik `_gmPolicyRowKlasik` otomatik) | unit: `gecmis-geri-alindi.test.js` — defter + klasik politika + pipeline entry üretimi (luna `GERI_ALINDI_entries=0` senaryosu artık 1 entry) |
| **L4-06b** `_gmGeriAlindiEtiketi` harf-kümesini (`I,U,D`) işlem tipi gibi etiketliyordu ("İşlem: i,u,d geri alındı") | `js/gecmis.js:161-165` | gerçek tip → gerçek etiket ("Tohumlama geri alındı"); harf-kümesi (`/^[IUD](\s*,\s*[IUD])*$/`)/eksik/bilinmeyen → nötr **"Kayıt geri alındı"** | unit: `gecmis-geri-alindi.test.js` + `geri-al-baslik.test.js` (I / I,U,D / 'I, U ,D' / boş / null vektörleri) |
| **L4-07a** `_openIslemDetayRow` payload değerleri ham `${v}` innerHTML'e (stored-XSS) | `js/ui.js:2995-2998` | yeni SAF `_islemDetaySatirlariHtml(payload)` — değerler VE bilinmeyen alan adları `esc()`'li; nesne değerler `_detayDegerMetni` ile JSON metnine | unit: `islem-detay-guvenli.test.js` — `<img src=x onerror>` payload VE anahtar vektörleri ham tag üretmez; grep: eski `max-width:60%">${v}` kalıntısı YOK |
| **L4-07b** hayvan referans alanları ham UUID/çözülmemiş kalıyordu; Değişiklikler'de "kupe (uuid-önek)" sızıntısı, `buzagi_id/farm_animal_id` hiç dönüştürülmüyordu | `js/ui.js:2996`; `js/degisiklikler/degisiklikler.js:341-349` | ui.js: `hayvan_id/ana_hayvan_id/buzagi_id/farm_animal_id/anne_id/animal_id` → `_gmHayvanKupeById` küpesi, çözülmezse `'?'` (UUID desenliyse; ham UUID ASLA). degisiklikler.js: `DG_HAYVAN_REF_ALANLARI` += `buzagi_id/farm_animal_id`; uuid-önek parantezi KALKTI → küpe ya da `'?'` | unit: `islem-detay-guvenli.test.js` — 5 alan küpe dönüşümü; çözülemeyen → `'?'`; UUID regex görünür html'de YOK; `_dgDegerMetni` 3 vaka |
| **L4-07c** önizleme plan kartı `#pkKisa` görünür satırda basıyordu | `js/degisiklikler/degisiklikler.js:572` | görünür kartta pk YOK (rozet+tablo+yapılacak); plan adımlarının pk'ları `_dgTeknikDetayHtml`'e eklendi ("Plan adımı N: tablo · pkKısa") — denetlenebilirlik teknik katlamada | unit: `_dgOnizleHtml` görünür bölümde UUID YOK + teknik blokta pk KALIR; grep `dg-pk` çipi YOK |
| **L4-08** zincir önerisi/⟲ iç yeniden-açılışı `openM`'i 2. kez çağırıyor; her çağrı history entry açıyordu, `closeM` tek geri aldı → S5 "tek geri" sızıntısı | `js/utils/modal.js:12`; `js/degisiklikler/degisiklikler.js:454+` | openM guard'ı: `history.state.modal === id` iken pushState YOK (invariant: açık modal başına TEK entry; farklı modallar her push alır — regresyon testli) | unit: `modal.test.js` 3 yeni test (2. openM push yok / open-open-close tek back temizler / farklı modal push alır). E2E: `S5-L4-08` (yapısal) + `S3-L4-08` (GERÇEK RPC zincir akışı — öneri→zincir→Vazgeç→geri; skip OLMADI) |
| **BULGU-X (zarf-dışı, bulundu-düzeltildi):** detay paneli Geri Al butonu ÖLÜ — `GeriAlabilir=_gmGeriAlHedef(l)?['*']:[]` sonrası `['*'].includes(l.tip)` her zaman false → buton hiç render edilmiyordu (sahibin "geri al butonu her yerde yok" sözü bu yüzde yaşıyordu; entegrasyon-smoke'un "düğme yoksa önizleme atlanır" tuzaklaşması da buradan besleniyordu) | `js/ui.js:2993,3001` | buton kararı doğrudan çözücüden: `geriAlabilir=!!_gmGeriAlHedef(l)` (W2'nin "buton kararı çözücüde" sözleşmesi zaten buydu) | unit: çözücü tablosu aynı kuralı testliyor; kod yorumunda kök neden işaretli |
| **REVIEW-1 (code-reviewer Minor-1, işlendi):** L4-06 ile telafi kartı listede görünür olunca detay panelinde `orijinal_tip/seviye/adim` ham anahtar+kod basılıyordu | `js/ui.js` `_islemDetaySatirlariHtml` | anahtar etiketleri (`Geri alınan olay / Kapsam / Adım`) + değer humanizasyonu (`TOHUMLAMA`→"Tohumlama", `satir`→"Kayıt") | unit: `islem-detay-guvenli.test.js` "telafi payload'ı işlem dilli" |
| **REVIEW-2 (code-reviewer Minor-4, işlendi):** ölü-buton onarımı test kilitsizdi — regresyonda sessiz geri düşebilirdi | `tests/unit/islem-detay-guvenli.test.js` | 2 kilit testi: hedef üreten entryde panel butonu render edilir; üretmeyende yok | unit yeşil (13/13 dosya içi) |

## 3. Temizlik kalemi (zarf "Kurallar" md.4)

- `l4_rehber` istemci kalıntısı: `grep -rn l4_rehber js/ tests/ index.html` → **eşleşme yok** (W2 stub'ı zaten sökülmüş; gönderen yol hiç oluşmamış). Temiz.

## 4. Damga

- `?v=20260914-09` TEK değer (index.html 26 yer: manifest link + 25 script);
  eski değerler için rakam-sınırlı negatif regex testleri (`vaka-toplu-ac.test.js`
  damga-pin bloğu) -08'i de kapsayacak şekilde güncellendi + changelog satırı.

## 5. Test sonuçları

**Unit** (`NODE_PATH=/home/melik/egesut-erp1/node_modules node --test tests/unit/*.test.js`):
**1023 tests / 1023 pass / 0 fail / 0 skipped** (taban 997/997/0 @ d2a26a4 → **+26**).
- Editler SONRASI, test güncellemelerinden ÖNCE ölçüm: 997/995/**2 fail** — iki
  kırılma da devreden çıkmış ESKİ sözleşmeyi kodluyordu (created_at-zaman; "İşlem
  geri alındı") → yeni sözleşmeye güncellendi (dürüst döküm; test-tekrar değil).
- Yeni: gecmis-geri-alindi 5, islem-detay-guvenli 13 (12 L4-07 + review kilidi
  2'li blok -1 ortak), geri-al-rehber +2, modal +3, geri-al-hedef +3-1güncelleme,
  damga-pin güncellemesi.

**PW — FINAL KANIT** (f1/W3 şablonu, demo Docker):

```bash
docker run --rm \
  -e PLAYWRIGHT_DEMO_MODE=1 -e PLAYWRIGHT_BASE_URL=http://127.0.0.1:8080/ \
  -v "$PWD":/work -v /home/melik/egesut-erp1/node_modules:/home/melik/egesut-erp1/node_modules \
  -w /work mcr.microsoft.com/playwright:v1.58.2-noble \
  bash -c "ln -sfn /home/melik/egesut-erp1/node_modules /work/node_modules && \
    npx playwright test tests/geri-alma-w3-nav.spec.js tests/entegrasyon-smoke.spec.js \
      tests/gecmis-ux.spec.js --workers=1 --retries=0 --reporter=list --output=/tmp/pw-out"
```

**FINAL: 16 passed / 0 failed / 0 skipped (1.8m)** — run-2, teslim ağacının
son hâli (review sonrası telafi-etiket polish'i DAHİL) üzerinde.
**Log:** `~/tmp/agents/l4-akis-w5/pw-final-20260914-run2.log` (tam çıktı; koşum
`?v=20260914-09` servis ediyor — damga-hizalı kanıt).
**Tarihçe (dürüst döküm):** run-1 (review öncesi ağaç) 16 passed / 0 failed
(1.6m), `~/tmp/agents/l4-akis-w5/pw-final-20260914.log` — S3-L4-08 gerçek akış
testi burada da skip OLMADI (zincir-önerisi bulundu, tek-entry canlı doğrulandı).

| # | Test | Kapsam |
|---|---|---|
| 1 | entegrasyon-smoke (gerçek RPC liste + gerçek önizleme) | stub'sız entegrasyon |
| 2-5 | gecmis-ux (U1 regresyon: ham UUID YOK, detay paneli, katlı kart, çipler) | U1 regresyon |
| 6-12 | w3-nav S5a-f (takvim/gün/tx-detay/ESC/←Geri) | W3 regresyon |
| 13 | **S5-L4-08 (yapısal)**: 2. openM push YOK; Vazgeç sonrası tepede modal-entry YOK; tek geri → degisiklikler kapanır, dash gelir | **L4-08** |
| 14 | **S3-L4-08 (gerçek akış)**: gerçek RPC önizlemesinde zincir-önerisi bulundu (skip OLMADI); zincir önizlemesi (2. openM) history sızdırmaz; Vazgeç temiz döner | **L4-08 gerçek S3** |
| 15-16 | S6a/b takvim işaretli günler (çevrimdışı IDB + kart kapsamı) | W3 regresyon |

## 6. W4-bağımlı / canlıda ölçülemeyen kısımlar (dürüst işaretleme)

1. **L4-04/05 canlı davranışı** gerçek `degisim_onizle/geri_al` mutation'ına
   bağlıdır — bu teslimde DEMO'ya yazma YASAK olduğundan plan JSON
   karşılaştırması lead final yürüyüşünde yapılmalı (PW yalnız önizleme
   açılışını ve history mekanizmasını kanıtlar; uygulama mutasyonu ölçmez).
2. **Zaman yedeği sunucu penceresi:** `_l4_zaman_txid` ±120 sn penceresiyle
   eşler. `islem_log.tarih` timestamptz default now() olduğundan L2-dönemi
   kayıtlarında tarih≈kayit_zamani eşleşir; ama EXPLICIT iş tarihi yazan
   yollarda (ör. bulk-ilac INSERT'i) ZAMAN_ESLESME_YOK beklenebilir — UI
   yönlendirme metni hazır (`DG_NEDEN_METNI.ZAMAN_ESLESME_YOK`); pencerenin
   gevşetilip gevşetilmeyeceği W4'ün motor sözleşme alanıdır.
3. **Telafi kartı etiketi** W4'ün gerçek `orijinal_tip` yazmasına bağlıdır;
   istemci artık harf-kümesini de güvenle nötrleştirir (iki taraf bağımsız
   korunur).

## 7. Kalan riskler

- `_islemDetaySatirlariHtml` hayvan referans alanlarını ESKİDEN GİZLİYKEN artık
  küpe etiketiyle GÖRÜNÜR kılar — bilinçli davranış değişikliği (zarf md.7
  "→ küpe etiketi" buyruğu; gizlemek dönüşümü anlamsızlaştırırdı). İstenmeyen
  ise tek satırla geri gizlenir (filter listesi).
- `history.state.modal` guard'ı pushState'i yalnız gerçek entry varken atlar;
  stack-tepe === id ama entry yoksa (kuramsal tutarsız durum) push YAPILIR —
  modal-entry'nin yok olmaması (S5) stack-tepe kontrolünden önce gelir.
- (review Minor-2) `hekim_id` referans dönüşüm listesinde değil; config'te
  'H1' biçimli kısa kod olsa da DB kaynaklı opak id olasılığında ham değer
  basılabilir — zarf ref listesi dışı bırakıldı, istenirse tek satırla eklenir.
- (review Minor-3) UUID regex + referans-alan listesi ui.js ve degisiklikler.js'te
  paralel kopya (DRY) — ortak sabite taşıma bu teslimin kapsamı dışında.
- (review Minor-6) bilinmeyen ama boş olmayan `orijinal_tip` lowercase yankıyla
  ("İşlem: xyz geri alındı") görünür — kabul edilebilir yedek.

## 8. Açık sorular (lead'e)

1. BULGU-X (ölü detay-paneli butonu) onarıldı — L4-04/05 canlı doğrulamasında
   bu butonun da yürüyüşe alınmasını öneririz (artık render ediliyor).
2. Gün görünümü (`_gmGunEntriesFromSources`) islem_log satırlarını TÜM tiplerle
   zaten gösteriyordu; defter allow-list'iyle artık hizalı. GERI_ALINDI telafi
   kartının gün görünümündeki DEDUP etkileşimi ölçülmedi (islem-log aynaları
   ASI/KIZGINLIK/SUTTEN/TOHUMLAMA/VAKA tiplerine bağlı — GERI_ALINDI baskılanmaz,
   kod okuması); istenirse unit eklenir.
3. Zaman yedeği ±120 sn sunucu penceresi (yukarıda §6.2) — W4 ile ortak karar.
4. (review Minor-5, ön-var olan/diff dışı) `_dgAgDegisti` çift-modal kapanışında
   ikinci closeM'in back'i 'yut' dalına düşüyor — L4-08 invariant'ının closeM
   tarafındaki simetriği istenirse ayrı kalemden eklenir.

## 9. Review notu (ZORUNLU)

**Builtin code-reviewer subagent** (kırıntı: `.crumbs/geri-alma-akisi-W5.jsonl`):
**Ready to merge: YES — Critical 0, Important 0, Minor 6.** Review 5 risk
sorusunu da doğruladı: (1) L4-08 guard'ı en-racy köşede bile dengeli — çift-entry
ne kapanmaz-modal kalıyor; (2) hayvan-ref görünürlüğü sözleşmenin kendisi, XSS
sızıntısı kapandı; (3) rehber token ↔ data-hi hizası stabil sort ile birebir;
(4) '?' dönüşü diff yollarında yanlış-etiket üretmiyor; (5) test kilidi sağlam.
Minor triage: 2 işlendi (REVIEW-1 telafi etiketleri, REVIEW-2 ölü-buton kilidi),
3 raporlandı (§7), 1 ön-var olan açık soruya (§8.4).
