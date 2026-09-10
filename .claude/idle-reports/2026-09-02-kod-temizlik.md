# Kod Temizlik Turu — 2. Jenerasyon (idle/kod-temizlik)

**Tarih:** 2026-09-02 · **Worktree:** `/home/melik/egesut-wt/kod-temizlik` (base: e6d8782)
**Kapsam:** yalnız `js/` + `index.html` · Supabase'e HİÇBİR çağrı yapılmadı · davranış değişikliği yok
**Sonuç:** 4 dosya, +76/−113 satır · `npm run test:unit` **344/344 yeşil** (düzenleme sonrası 2 kez)
**Doğrulama:** her düzenlenen sembol için `gitnexus impact` (upstream) — LOW olmayanlara dokunulmadı;
commit öncesi `detect_changes` + ham diff hunk-bazlı kapsam doğrulaması.

---

## 0 · Kritik ampirik bulgu: escAttr-inline onclick'te ÇALIŞMAZ (desen kararı)

Görev "escAttr/dataset" diyordu. Playwright (gerçek Chromium) ile test edildi:

```
onclick="fn('a&#39;b')"   → buton ÖLÜ (tık hiçbir şey yapmaz)
data-v="a&#39;b" + this.dataset.v → 'a'b doğru gelir
```

Neden: HTML parser event-handler attribute değerini **entity-decode edip** JS motoruna verir;
`&#39;` → `'` JS string'i kırar. escAttr tek başına JS-string-literal bağlamında `'` için yetersiz.
**Sonuç:** metin değerli tüm onclick'lerde `data-x="${escAttr(v)}"` + `this.dataset.x` deseni
(ev kuralı: AGENTS.md modal-router uyumu; mevcut doğru örnekler ui.js:2949/2953/1765) kullanıldı.
İlk turun (62e87e5) escAttr-inline küpe siteleri (ui.js:1976/1977) hâlâ kırık — bkz. §5 takip notu.

## 1 · B9 kalan escape — düzeltildi (28 nokta)

### 1a. onclick-string → dataset deseni (16 nokta)
| Yer (yeni satır) | Değer | Fonksiyon |
|---|---|---|
| ui.js:1102 | protokol adı | _showProtokolEkran `_satirHtml` |
| ui.js:1111, 1161 | kapatan_ref | _showProtokolEkran / _showProtokolDetay |
| ui.js:1665 | küpe (main) | srchDropdown → srchSec |
| ui.js:2399 | küpe+dt+sperma | gebeledenSec → anneSeç (2441'deki mevcut desenle hizalı) |
| ui.js:2656 | sorun id+tanı | sorunBottomSheet → sorunSec |
| ui.js:3570-3609 (6) | grp/cls | _renderIlacSiniflari → _dcEditInline/_dcDeleteGroup/_dcDeleteClass/_dcAddIngredient/_dcAddClass |
| ui.js:4903 | padok_hedef (padok ADI — GT: `WHERE ad=p_padok_hedef`) | _gorevStokSecVeTamamla |
| ui.js:7822 | küpe | renderPadokHayvanlar → padokTekliTasi |
| ui.js:7917 | grup adı | renderGrupPadokEslem → grupPadokCheckbox |
| app.js:467, 502 + forms.js:1234 | semptom çipi (forms.js'teki DB kaynaklı — `cases.semptomlar` serbest metin!) | semptomEkle/hdeSmptomEkle/hstDuzenleAc |

### 1b. innerHTML ham metin → esc() (12 bölge, ~30 alan)
`_detOzet` hariç hepsi: srchDropdown (main/devlet_kupe/padok), openCikisModal (kupe/irk/grup),
gebeledenSec satırı, tumStokHareketleriniGoster (urunAd/birim/tur/notlar), stokHareketGor
(tur/notlar/birim), openTohDet (hk.ad, deneme sperması), _openInsemIntercept, renderDrugStokList
(name + title attr → escAttr), renderAyarlarVaccineList (name/disease_target),
renderAyarlarPadokList + openBulkTransfer + _btRenderHedefPadoklar (p.ad),
_btRenderSeciliHayvanlar + _btRenderEtiketTekkek + renderPadokHayvanlar (küpe/grup/padok/cinsiyet),
renderGrupPadokEslem (p.ad, grup başlığı), renderBuzagiPicker (getDisplayKupe/irk),
loadBulkVaccine/IlacHayvanlar (küpe), submitBulkIlac hata satırları (e.error),
app.js spermaModStok (option value → escAttr + label esc).

## 2 · Ölü hata-kontrol kalıntıları — 24 nokta silindi

Kontrat (api.js:66-92): `rpc()` hata VE `ok:false` gövdelerinde **throw** eder (`err.data` taşır);
`rpcOptimistic`/`rpcSeansTamamla` passthrough. Dönüş şekilleri GT'den doğrulandı
(create_case/kizginlik_sil/tohumlama_geri_al/geri_al → başarıda `ok:true`):

- **forms.js (13):** submitCase:599 (`!res?.ok`), abortKaydet:682, hstKapat, hstGuncelle, hstSilOnay,
  islemGeriAl ×2 (`!res?.ok` throw'ları), submitStokAdd (`r.ok===false` + kullanılmayan `r` atamaları),
  hstIlacEkle, hstIlacSil, submitDrugStokLink, submitBulkIlac (ölü ternary → başarı kolu),
  seansTamamla, submitAsiEkle (`let r` kaldırıldı).
- **ui.js (11):** kizginlikSil:367, rpcOptimistic sonrası `res&&res.ok===false` ×10
  (_diseaseSave, _diseaseDelete, _tanimVarsayilan ×2, _dcAddGroup/_dcAddClass/_dcAddIngredient/
  _dcEditIngredient/_dcDeleteIngredient, _kategoriSave, _kategoriDelete — son üçü taramada ortaya çıktı,
  impact sonrası LOW) + kullanılmayan `const res` atamaları 9 fonksiyonda düşürüldü.

Hata bildirimi kaybı YOK: bu dallar zaten hiç çalışmıyordu; gerçek hata try/catch (veya
rpcOptimistic'in kendi catch'i) üzerinden toast ediliyor. **B8'in tam fix'i (try/catch ekleme)
bilinçli kapsam dışı — davranış değişikliği yasağı.** Pozitif `if(res?.ok)` başarı kapıları
(ui.js:187/345/413/1327/1375/1467) canlı kod — dokunulmadı.

## 3 · loadHekimler (app.js) — hekim_listesi ölü dalı

Canlıda olmayan `hekim_listesi` RPC çağrısı her açılışta hataya düşüp config fallback'inde
kalıyordu (konsol gürültüsü). `loadHekimler()` artık `loadHekimlerFromDB()`'ye delege ediyor
(IDB `hekimler` = `getData`) + populate. Offline init dalındaki gerçek-fazlalık çift
`loadHekimlerFromDB+populateHekimSelects` kaldırıldı (aynı IDB, arada yazma yok);
online dalındaki pull-sonrası refresh **korundu** (veri değişebilir).

## 4 · index.html hata paneli — renderErrorLog self-XSS

`${e.msg}`, `${e.src}`, `${e.stack}` → `esc()`. `esc` geç yüklenme riski yok: panel yalnız
kullanıcı açınca render ediliyor (o ana kadar helpers.js yüklü).

## 5 · Dokunulmayanlar — impact HIGH/CRITICAL (guardrail)

| Sembol | Risk | İçinde kalan B9 ihlali (takip işi) |
|---|---|---|
| renderTask | CRITICAL | ui.js:712 togglePendingDone `{padok:'${t.padok_hedef}'}` |
| _detOzetHtml | HIGH | infoFields `${i.v}` (14 kullanıcı-metni alanı), `${anneKupe}` |
| _detUremeHtml | HIGH | ui.js:1808-1819 dogumYaptiAc/openInsemSafe/openTekrarAsim (hid/sperma ham) |
| _detSaglikRender | HIGH | `${dis?.name}`; **1976/1977: ilk turun escAttr-inline küpe'si — §0 gereği hâlâ kırık** |
| _detGorevHtml | HIGH | ui.js:2053 openMWithHayvan('${kupe}') |
| _uremeKizginlik | CRITICAL | ui.js:2611/2613 openInsemSafe/kizginlikTedaviAc (küpe ham) |
| renderPadokDolulukBar | CRITICAL | ui.js:7304/7311 setPadokFiltreBt(p.ad) + title/padokAdi ham |
| animalGrupDegisti | CRITICAL | app.js:337 option `${p.ad}` ham |

Not: bu fonksiyonların HIGH/CRITICALliği template satırlarından değil, openDet akışına
fan-out'larından geliyor — değişiklikler mekanik olsa da guardrail mutlak uygulandı.

## 6 · Değerlendirildi, bilinçli bırakıldı (ihlal değil / düşük risk)

- **Statik config kaynaklı:** filterHastalikList (HASTALIK_KAT/LOKASYON_KAT — app.js:425/432),
  sorun sheet label'ları (literal dizi), stok grup `baslik`/`alt.ad` (literal config),
  HIZLI_SAATLER, LABEL[l.tip] (enum+config), kupeOnerGoster/kupeOnerSec (üretilmiş sayısal öneriler).
- **Üretilmiş/uuid değerler onclick'te:** openDet('${id}') vb. — tırnak üretilemez, tehdit modeli dışı.
- **textContent/dataset/confirm/toast argümanları:** HTML bağlamı değil.
- Yeni bölgeler (güncelleme notu): yavru-ekle butonu (1765) ve ikiz kardeş satırı zaten
  data-action/escAttr + esc'li doğru desendeydi; b-kupe-warn textContent kullanıyor — düzeltme gerekmedi.

## 7 · Doğrulama zinciri

1. `npm run test:unit` → 344/344 (düzenleme sonrası 2. koşu da yeşil; renderBuzagiPicker
   testleri düz metin assert ediyor, esc değiştirmiyor).
2. `gitnexus detect_changes` (worktree parametreli) → 4 dosya (app/forms/ui/index) ✓.
   Sembol listesindeki dokunulmayan isimler (suttenKesGeriAl vb.) indeks satır-kayma gürültüsü;
   `git diff` hunk başlıkları gerçek dokunulan fonksiyonlarla birebir doğrulandı.
3. `node --check` üç js dosyasında OK.

## 8 · Takip önerileri (sonraki tura)

1. HIGH/CRITICAL 8 semboldeki kalan B9 noktaları (§5) — impact riski kabul edilirse ~15 noktalık
   ikinci dilim; özellikle 1976/1977 escAttr-inline küpe (ampirik kırık).
2. B8 tam fix: rpcOptimistic çağrılarını try/catch'siz bekleyen _dc*/_kategori* ailesi
   unhandled rejection üretiyor (rpcOptimistic kendi toast'unu basıp re-throw ediyor) —
   davranış değişikliği olduğundan bu turda bilinçli dışarıda bırakıldı.
3. escAttr-inline-in-onclick deseni helpers.js:90-91 yorumunda hâlâ "JS string literal context
   için" diye tarif ediliyor — §0 bulgusuyla çelişiyor; yorum dataset desenini işaret etmeli.

## 9 · Review + merge kapanışı (2026-09-02, ZCode review oturumu)

**Review:** Bağımsız reviewer subagent, `962689b` diff'ini 5 iş kalemi + regreso ekseninde
satır satır inceledi → **APPROVE**. Öne çıkan doğrulamalar: 26 silinen ok-kontrolünün tamamı
rpc/rpcOptimistic/rpcSeansTamamla sonrası (tek bir ham db.rpc/db.from sonrası kontrol
silinmemiş; api.js kontratı + GT Return gövdeleri çaprazlandı); 16 dataset dönüşümünde
data-x ↔ this.dataset.x ve fonksiyon imzaları birebir; çift-escape yok; 8 HIGH/CRITICAL
koruma sembolüne diff'te zero-touch.

**Review bulguları:**
- MINOR: `tumStokHareketleriniGoster` iade/iptal dalında `${urunAd}/${birim}/${m.tur}` hâlâ
  esc'siz (aynı fonksiyonun tamamlandı dalı esc'lendi) → sonraki tura.
- NIT: forms.js rpc() tarafında ~10 fonksiyonda kullanılmayan `const res/result` kalmış
  (ui.js rpcOptimistic ailesi temizlendi, forms tarafı kalmadı); rapor sayımı 24 → diff'te 26;
  eski hekim dalının `telefon` maplemesi loadHekimlerFromDB'de yok (0 kullanım — dokunma).

**Merge:** `idle/kod-temizlik` bu oturumun review'i sürerken **dış aktör tarafından**
(00:10:42, muhtemel kullanıcı/paralel oturum) main'e merge edildi ve pushlandı:
`ebe20aa merge: idle/kod-temizlik — ...`. Worktree ve branch silinmiş durumda.
Merge + push bu oturumda yapılmadı; oturum merge SONRASI doğrulamayı üstlendi.

**Merge sonrası doğrulama (bu oturum):**
1. `git diff 5daf0d6..ebe20aa` = birebir commit içeriği (4 dosya, +76/−113; sürpriz edit yok).
2. 3-way merge semantic riski (worktree e6d8782 tabanlıydı; main'de buzağı-modal +
   gorev-asi-fix ui.js değişiklikleri vardı) → merged main'de **362/362 unit test yeşil**
   (buzağı modal testleri dahil), `node --check` 3 js OK.
3. Dataset dönüşümleri merge'de bozulmadan geçti; `hekim_listesi` yalnız yorumda.

**Sonraki tura listesine eklendi (§8'e ilave):**
4. ui.js:8453/8503/8548/8606 — seans ailesinde rpc() sonrası 4 erişilemez `res?.ok === false`
   kaldı (aynı ölü-dal sınıfı; zararsız, temizlik turalarına).
5. MINOR iade dalı esc (yukarıda).
