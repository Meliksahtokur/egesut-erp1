# UI & Kod Bölüm Haritası (2026-09-01 yeniden üretim)

> **Yöntem:** `idle/docs-hatti` worktree kodundan grep ile üretildi (`^(async )?function` + `const X = (` taraması,
> Python; satır numaraları 2026-09-01 kod durumudur). Eski haritadaki ~2.8k satırlık dönem aralıkları GEÇERSİZDİ —
> bu sürüm günceldir. Yine de büyük refactor sonrası doğrulamak istersen: `grep -n "function <ad>" js/ui.js`.
>
> Dosya boyutları: ui.js **8513** · forms.js **1959** · api.js **675** · app.js **695** · ai-asistan.js 403 ·
> demo.js 87 · auth.js 267 · config.js 129 · state.js 96 · utils/ (5 dosya).

## js/ui.js Bölümleri (8513 satır)

| Satır | Özellik | Kilit Fonksiyonlar |
|---|---|---|
| 27–95 | Helper Utilities | `_findScroller()`, `_keepScroll()`, `setTaskKat()`, `band()`, `yasHesapla()`, `showTab()`, `showTab2()` |
| 96–172 | Dashboard stat + aşı uyarı + ileri gebe | `_dashStatRow()`, `_dashVacAlerts()`, `ileriGebeKontrol()`, `_dashBands()` (sessiz bandı sentinel-son) |
| 239–316 | Dashboard yükleme | `loadDash()` |
| 317–400 | Kızgınlık UI | `kizginlikYoktu()`, `kizginlikTedaviAc()`, `kizginlikSil()`, `updateKizginlikAlert()`, `asiDismiss()` |
| 401–481 | Gebe özet + pending-done bayrak sistemi | `showGebe()`, `_savePending()`, `updatePendingFab()`, `flushPendingDone()`, `recoverPendingDone()` |
| 482–815 | Görev listesi + seans kartları | `loadTasks()`, `_stokAdi()`, `renderTask()`, `renderSeansGrupAyrac()`, `renderSeansGorevKart()`, `toggleSeansAksiyon()`, `toggleSub()`, `openConfirm()`, `updateTaskBadge()`, `beslemeGunTamam()` |
| 816–955 | Hayvan listesi | `loadAnimals()`, `_yeniDogumGun()`, `_animalTagsHtml()`, `_animalCardHtml()`, `renderAnimals()`, `_toggleSpermaRest()` |
| 956–1043 | Sessiz + belirsiz üreme listeleri | `_showSessizList()` (9999 sentinel-son), `_showBelirsizList()`, `_belirsizRender()`, `_belirsizApply()` |
| 1044–1390 | Protokol ekranı (etken madde) | `_showProtokolEkran()`, `_showProtokolDetay()`, `_etkenFiltrele()`, `_sonDozGetir()`, `_puDozPrefill()`, `_protokolUygula()`, `_protokolUygulaKaydet()`, `_protokolDismiss()`, `_protokolGeriAl()`, `_islemSonrasiRefresh()` |
| 1391–1460 | Hayvan hızlı uygulama | `_hayvanHizliUygulama()`, `_hayvanHizliUygulaKaydet()` |
| 1461–1625 | Sürü istatistik paneli | `_renderSuruGrupFiltre()`, `_renderSuruStat()`, `_fetchSuruStat()`, `_applySuruStatHtml()`, `_toggleSuruStat()` |
| 1626–1720 | Arama/filtre çipleri | `srchDropdown()`, `srchSec()`, `fchipReset()`, `fchipSec()`, `filterA()` |
| 1721–2114 | Hayvan detay modal + geçmiş | `_detOzetHtml()`, `_detUremeHtml()`, `_detRenderGecmis()`, `_detSaglikRender()`, `_detGorevHtml()`, `openDet()`, `closeDet()`, `fromTaskOpenDet()`, `islemGeriAl()`, `openIslemDetay()` |
| 2115–2304 | Hayvan düzenleme + çıkış modal | `openAnimalEdit()`, `closeAnimalEdit()`, `openCikisModal()` |
| 2305–2467 | Doğumlar | `loadBirths()`, `gebeledenSec()`, `gebeFiltrele()`, `anneSe()`, `anneSecimSifirla()`, `openDetByKupe()`, `dogumYaptiAc()` |
| 2468–2937 | Üreme sekmesi + sorun bottom-sheet | `uremeTab()`, `_uremeKizginlik()`, `sorunBottomSheet()`, `sorunVakaAc()`, `kizginlikSearch()`, `tohumlamaSearch()`, `_uremeGebelik()`, `gebeAta()`, `_uremeDogum()`, `_uremeTohumlama()`, `_uremeAbort()`, `loadUreme()` |
| 2938–3141 | Geçmiş paneli | `_gecmisEntryHtml()`, `_gecmisSearchText()`, `_gecmisRender()`, `loadGecmis()` |
| 3142–3270 | Stok hızlı UI | `loadStock()`, `openStk()`, `stokDrugBagla()`, `openStokAdd()`, `saTipSec()` |
| 3271–3455 | Tanımlar paneli (hastalık kataloğu) | `openTanimlarPanel()`, `loadTanimlarPanel()`, `_renderHastaliklar()`, `_diseaseEditForm()`, `_diseaseSave()`, `_diseaseDelete()`, `_tanimVarsayilan()` |
| 3456–3669 | İlaç sınıfları (drug_class) | `_renderIlacSiniflari()`, `_dcAddGroup/Class/Ingredient()`, `_dcEditInline()`, `_dcDeleteGroup/Class/Ingredient()` |
| 3670–4008 | Kategoriler + tedavi şablonları | `_renderKategoriler()`, `_renderSablonlar()`, `silSablon()`, `openSablonBuilder()`, `_renderSablonBuilder()`, `sablonGunEkle/Sil/Toggle()`, `sablonSeansAc/Ekle/Vazgec()`, `sablonTohumlamaGunEkle()`, `sablonKaydet()` |
| 4009–4072 | Kategori edit | `_kategoriEditForm()`, `_kategoriSave()`, `_kategoriDelete()`, `_getIlacKatAdlari()`, `_buildTabFilter()` |
| 4073–4458 | Stok panel + hareketler | `loadStokPanel()`, `openStokDet()`, `stokDetKaydet()`, `stokDetArsivle()`, `stokDuzeltKaydet()`, `tumStokHareketleriniGoster()`, `loadStokList()`, `stokHareketGor()` (4315 `loadStokPanel_DEPRECATED` ölü) |
| 4459–4595 | Raporlar + çıkanlar | `loadRaporlar()`, `loadCikanlar()` |
| 4596–5074 | Görev detay modal | `openTaskDet()`, `detayTamamla()`, `_gorevStokSecVeTamamla()`, `_gorevStokTamamlaSubmit()`, `toggleTedaviIlac()`, `gorevTedaviGunDone()`, `_tedaviGunExecute()`, `asiFormAc()`, `asiUygulaVeTamamla()`, `rapelTarihiKaydet()`, `openTaskEdit()`, `detayIptal()`, `openDoneTaskDet()`, `gorevGeriAl()` |
| 5075–5124 | İlaç cache | `loadDrugsCache()` |
| 5125–6047 | Vaka detay + zaman çizelgesi + gün/seans yönetimi | `renderCasesForAnimal()`, `openCaseDet()`, `renderCaseTimeline()`, `caseDaySaatAc/Kaydet()`, `caseDayTamamla()`, `caseDayNotAc/Kaydet()`, `cdAccToggle()`, `caseGunEkle()`, `caseGunEkleOnayla()`, `caseTohumlamaEkleAc/Onayla()`, `caseTohumlamaKaydet()`, `caseDrugFormAc()`, `cdfChkChange()`, `caseDrugKaydet()`, `caseDrugSil()`, `caseDaySil()`, `caseDrugDuzenle/Kaydet()`, `caseKapat()`, `renderHstIlaclar()`, `acHdiStok()`, `hdiStokSec()` |
| 6048–6189 | Tohumlama detay modal | `openTohDet()`, `tekrarTohumla()` |
| 6190–6338 | Sperma autocomplete + stok modu | `acSperma()`, `selSperma()`, `getSpermaStok()`, `dusSpermaStok()`, `checkSpermaUyari()`, `trSpermaModStok()`, `onTrSpermaSelect()`, `spermaModStok/Elle()` |
| 6339–6420 | İlaç autocomplete | `refreshIlacCache()`, `acIlac()`, `selIlac()`, `ilacSatirEkle()`, `acDilacSatir()`, `selDilacSatir()` |
| 6421–6538 | Hayvan autocomplete + uygunluk | `_eligibleHayvanlar()`, `_activeAnimalsOnly()`, `acHayvan()`, `selHayvan()`, `acNav()` |
| 6503–6598 | Tohumlama/gebelik form modalları | `openMWithHayvan()`, `openInsemSafe()`, `openPlanliTohumlama()`, `_openInsemIntercept()`, `openGebelikEkle()` |
| 6599–6676 | Tema & ayarlar + drug-stok listesi | `setTheme()`, `ayarlarAc()`, `renderDrugStokList()` |
| 6677–6941 | Data yönetimi (kuyruk/replay) | `kuyrukTemizle()`, `stokHareketiTemizle()`, `dataTrafficYenile()`, `dataTrafficGonder()`, `dataTrafficTekGonder()`, `buildRpcParams()` (**6789** — offline replay param setleri, bilinçli bug adayı), `dataTrafficSil()` |
| 6942–7136 | Ayarlar: hekimler + aşı rapel | `renderAyarlarHekimList()`, `renderAyarlarVaccineList()`, `vaccineRapelGuncelle()`, `ayarlarHekimEkle/Kaydet()`, `hekimDetAc()`, `renderHekimStats()`, `hekimDetKaydet()`, `hekimDetSil()` |
| 7137–7248 | Ayarlar: padoklar | `renderAyarlarPadokList()`, `padokDuzenleAc/Kaydet()`, `padokSilOnay()`, `renderPadokDolulukBar()` |
| 7249–7707 | Bulk transfer (toplu padok taşıma) | `setPadokFiltreBt()`, `enterBtSecimModu()`, `_btRenderSuru()`, `openBulkTransfer()`, `btSecilidenKaldir()`, `btSerbestYukle()`, `_btGrupUygunMu()`, `_btRenderHedefPadoklar()`, `btHedefSec()`, `_btGuncelleOzet()`, `_btEtiketleriBir()`, `btTransferOnayla()` |
| 7708–7886 | Padok detay + grup↔padok eşlem | `padokDetayAc()`, `renderPadokHayvanlar()`, `pdToggleHayvan()`, `padokTekliTasi()`, `padokTopluTasi()`, `padokTransferOnayla()`, `renderGrupPadokEslem()`, `grupPadokCheckbox()`, `ayarlarPadokEkle/Kaydet()` |
| 7887–7934 | Bildirim sistemi | `bildirimIzniAl()`, `bildirimKontrol()`, `bildirimAc()` |
| 7935–8140 | Data lists + seans serit render | `buildDataLists()`, `stokFiltrele()`, `taskSrch()`, `fmtSeansSaat()`, `computeSeansState()`, `renderSeansSerit()`, `updateNowCursor()`, `fmtBeklemeSure()`, `renderSeansRow()`, `renderTedaviGunSeanslar()` |
| 8141–8404 | Vaka seans ekle/düzenle + erken kapatma | `caseSeansEkleFormAc()`, `seansAddSaatSec()`, `seansSilTekil()`, `seansDuzenleAc/Kaydet()`, `caseSeansEkleKaydet()`, `caseErkenKapatToggle/Onayla()` |
| 8405–8513 | Aşı ekle modalı | `openAsiEkle()`, `_renderAsiDiseasePicker()`, `_renderAsiForm()`, `asiDisToggle()`, `_syncAsiForm()` |

## js/forms.js (1959 satır — form submit handler'ları)

| Satır | Özellik | Kilit Fonksiyonlar |
|---|---|---|
| 26–154 | Hayvan ekleme | `_kupeKontrolEt()` (kupe_musait_mi RPC), `submitAnimal()` (hayvan_ekle) |
| 155–212 | Doğum formu | `submitBirth()` (dogum_kaydet) |
| 213–277 | Ek uygulama (tohumlama) | `ekChipSec()`, `_ekStokYukle()`, `ekUygulamaEkle()` |
| 278–419 | Tohumlama + tekrar aşım | `submitInsem()` (tohumlama_kaydet/planli_tohumlama_kaydet, VWP confirm), `submitTekrarAsim()`, `openTekrarAsim()` |
| 420–542 | Kızgınlık + vaka açma | `submitKizginlik()`, `loadDiseasesDropdown()`, `_renderSablonSecim()`, `submitCase()` (create_case) |
| 612–667 | Abort + not | `abortKaydet()` (tohumlama_abort RPC), `hayvanNotEkle()` |
| 676–802 | Çıkış + sütten kesme | `submitCikis()` (cikis_yap), `_sutIcenBuzagilar()`, `openSuttenKesModal()`, `submitSuttenKes()`, `suttenKesTekil()`, `suttenKesGeriAl()` |
| 825–887 | Protokol ayarları + tohum onayı/ertele | `protokolAyarYukle/Kaydet()`, `submitTohumOnayla()`, `submitTohumErtele()` |
| 888–1066 | Aşı picker + toplu aşılama formu | `renderVaccinePicker()`, `submitVaccination()`, `doneTask()` |
| 1067–1135 | Görev ekle/düzenle | `submitTaskAdd()`, `submitTaskEdit()`, `kaydetTaskEdit()` |
| 1136–1252 | Legacy hastalık düzenleme | `hstKapat()`, `hstDuzenleAc()`, `hstGuncelle()`, `hstSilOnay()` |
| 1253–1370 | Tohumlama sonucu + geri alma | `tohSonucKaydet()`, `tohSonuc()`, `openGeriAl()`, `islemGeriAl()` (geri_al/tohumlama_geri_al yönlendirme 1336-1355) |
| 1371–1461 | Stok ekle/giriş | `submitStk()`, `submitStokAdd()` |
| 1462–1514 | Gebelik elden ekle + bildirim | `submitGebelikEkle()` (gebelik_kaydet_manual) |
| 1515–1589 | Legacy hızlı ilaç satırları | `hstIlacEkle()`, `hstIlacSil()`, `submitDrugStokLink()` |
| 1590–1878 | Bulk aşılama + bulk ilaç | `loadBulkVaccine*()`, `submitBulkVaccination()`, `loadBulkIlac*()`, `submitBulkIlac()`, `applyBulkFiltre()` |
| 1890–1958 | Seans tamamla + aşı tanım ekle | `seansTamamla()`, `submitAsiEkle()` |

## js/api.js (675 satır — veri katmanı)

| Satır | Özellik | Kilit Fonksiyonlar |
|---|---|---|
| 53–96 | RPC sarmalayıcı | `_trErr()`, `rpc()` (**66** — ok:false→Error, err.data; D2 notunun kanıtı 86-89) |
| 97–202 | IndexedDB + offline kuyruk | `openDB()`, `idbGetAll/Put/ClearAndPut/Delete()`, `queueOp()`, `getQueue()`, `removeFromQueue()` |
| 203–375 | Yazma katmanı | `dbUpdate()` (**203**, db.from PATCH), `dbInsert()` (**220**, db.from POST), `_writePatch()`, `_writePost()`, `write()` (D1: offline kuyruk db.from kullanır) |
| 376–456 | Render + pull | `renderSafe()`, `pullTables()`, `_pullTablesNow()` |
| 457–496 | Optimistic RPC + pull | `rpcOptimistic()` (**457**), `pullFromSupabase()` |
| 497–547 | Auto sync engine | `syncNow()` (**497** — kuyruk drain db.from PATCH/POST, B17 dead-letter) |
| 548–618 | Background sync + realtime | `startBackgroundSync()`, `stopBackgroundSync()`, `initRealtime()` |
| 619–675 | BUG-059 RPC sarmalayıcıları | `rpcAddTreatmentDayWithSessions()` (624), `rpcSeansTamamla()` (641), `rpcReceteGuncelle()` (657), `rpcCloseCaseWithRemaining()` (671) |

## js/app.js (695 satır — init & form dinamikleri)

| Satır | Özellik | Kilit Fonksiyonlar |
|---|---|---|
| 10–63 | Init + hekim yükleme | `uiLog()`, `loadHekimler()` (**28** — hekim_listesi RPC, canlıda yok → config fallback) |
| 64–151 | Sync bar + navigasyon | `updateSyncBar()`, `setSyncBar()`, `hideSyncBar()`, `goTo()` |
| 152–199 | Render + bildirim | `renderFromLocal()`, `updateBildirimBadge()`, `loadBildirimler()`, `refreshAll()`, `populateHekimSelects()` |
| 200–324 | Irk dropdown + hayvan form dinamikleri | `loadIrkDropdown()` (irk_listesi), `irkSecimDegisti()`, `animalFormGuncelle()` (**249** — yaş/grup pencereleri 280-304 erkek↔grup frontend guard'ı) |
| 325–408 | Grup değişimi + sperma modu | `animalGrupDegisti()`, `spermaModStok/Elle()`, `buildSpermaList()` |
| 409–543 | Hastalık/semptom dinamikleri | `buildDiseaseFreq()`, `filterHastalikList()`, `updateSemptomDropdown()`, `semptomEkle/Kaldir()`, `hde*`, `toggleLokasyon()` |
| 544–670 | Hasta düzenleme semptomları + PWA | `selDis()`, `pwaInstall()` |

## Paralel Subagent Dispatch Rehberi (güncel aralıklarla)

**Üreme değişikliği:**
- Agent A: ui.js 2305–2937 (Doğumlar + Üreme sekmesi) + 6048–6189 (toh-det modal)
- Agent B: forms.js 278–419 + 1253–1370 (tohumlama/sonuç/geri-al) + api.js rpc()

**Vaka/Hastalık değişikliği:**
- Agent A: ui.js 5125–6047 (vaka detay) + 8141–8404 (seans yönetimi)
- Agent B: forms.js 420–542 + 1136–1252 (vaka/legacy hastalık) + api.js 619–675 (BUG-059 sarmalayıcıları)

**Hayvan listesi/detay değişikliği:**
- Agent A: ui.js 816–955 (liste) + 1721–2114 (detay modal)
- Agent B: app.js 200–324 (form dinamikleri) + state.js

**Görev değişikliği:**
- Agent A: ui.js 482–815 (liste) + 4596–5074 (görev detay modal)
- Agent B: forms.js 888–1135 (görev ekle/düzenle + doneTask)

**Stok değişikliği:**
- Agent A: ui.js 4073–4458 (stok panel) + 6339–6420 (ilaç autocomplete)
- Agent B: forms.js 1371–1589 (stok/ilaç formları)

**Offline/sync değişikliği:**
- Agent A: api.js 97–547 (IDB + kuyruk + syncNow)
- Agent B: ui.js 6677–6941 (data traffic + buildRpcParams)
