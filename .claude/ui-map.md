# ui.js Bölüm Haritası (2804 satır)

Subagent dispatch için kullan: hangi satır aralığını hangi agent'ın okuması gerektiğini belirle.

## Bölümler

| Satır | Özellik | Kilit Fonksiyonlar |
|---|---|---|
| 1–49 | Helper Utilities | `band()`, `yasHesapla()`, `showTab()`, `showTab2()` |
| 53–115 | Dashboard | `loadDash()`, `showGebe()`, `_dashStatRow()`, `_dashBands()` |
| 126–382 | Hayvan Listesi | `renderAnimals()`, `filterA()`, `_animalCardHtml()`, `srchDropdown()`, `loadTasks()` |
| 387–540 | Hayvan Detay Modal | `openDet()`, `closeDet()`, `_detOzetHtml()`, `_detUremeHtml()`, `_detGorevHtml()` |
| 542–662 | Hayvan Düzenleme | `openAnimalEdit()`, `closeAnimalEdit()`, `openNotModal()`, `openCikisModal()` |
| 680–847 | Doğumlar | `loadBirths()`, `dogumYaptiAc()`, `anneSeç()`, `openDetByKupe()` |
| 851–987 | Üreme Sekmesi | `uremeTab()`, `_uremeKizginlik()`, `_uremeGebelik()`, `_uremeTohumlama()`, `_uremeAbort()` |
| 989–1078 | Geçmiş | `loadGecmis()`, `_gecmisEntryHtml()`, `openIslemDetay()` |
| 1094–1273 | Stok Yönetimi | `openStk()`, `loadStokPanel()`, `openStokAdd()`, `stokDrugBagla()` |
| 1327–1497 | Çıkışlar | `loadCikislar()` |
| 1527–1578 | Görev Detay Modal | `openTaskDet()`, `detayTamamla()`, `detayIptal()` |
| 1584–1647 | İlaç Cache | `loadDrugsCache()` — global drug/stock state |
| 1650–1891 | Vaka Detay | `openCaseDet()`, `renderCaseTimeline()`, `caseGunEkle()`, `renderCasesForAnimal()` |
| 1897–1981 | Vaka İlaç Formu | `caseDrugFormAc()`, `cdfChkChange()`, `caseDrugKaydet()` |
| 2049–2149 | İlaç Yönetimi | `caseDrugDuzenle()`, `hdiStokSec()` |
| 2157–2227 | Tohumlama Detay | `openTohDet()`, `tekrarTohumla()` |
| 2228–2339 | Sperma Autocomplete | `acSperma()`, `selSperma()`, `getSpermaStok()`, `onSpermaSelect()` |
| 2344–2403 | İlaç Autocomplete | `acIlac()`, `selIlac()`, `ilacSatirEkle()`, `refreshIlacCache()` |
| 2428–2543 | Form Helpers | `acHayvan()`, `selHayvan()`, `_eligibleHayvanlar()`, `openMWithHayvan()` |
| 2555–2581 | Tema & Ayarlar | `setTheme()`, `ayarlarAc()` |
| 2583–2750 | Ayarlar Panelleri | `renderAyarlarHekimList()`, `renderAyarlarSpermaList()`, `renderDrugStokList()` |
| 2754–2791 | Bildirim Sistemi | `bildirimIzniAl()`, `bildirimKontrol()`, `bildirimAc()` |
| 2795–2804 | Data Yönetimi | `kuyrukTemizle()`, `stokHareketiTemizle()`, `dataTrafficYenile()` |

## Paralel Subagent Dispatch Rehberi

**Üreme değişikliği:**
- Agent A: satır 680–987 (Doğumlar + Üreme sekmesi)
- Agent B: `forms.js` + `api.js` tohumlama/dogum handler'ları

**Vaka/Hastalık değişikliği:**
- Agent A: satır 1584–2149 (Vaka sistemi UI)
- Agent B: `forms.js` vaka handler'ları + RPC çağrıları

**Hayvan listesi/detay değişikliği:**
- Agent A: satır 126–540 (Liste + Detay)
- Agent B: `app.js` event delegation + `state.js`

**Stok değişikliği:**
- Agent A: satır 1094–1273 + 2228–2403 (Stok UI + Autocomplete'ler)
- Agent B: `forms.js` stok handler'ları
