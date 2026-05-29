# Gecmis Sekmesi — Arama Motoru UX Tasarimi

**Tarih:** 2026-05-29
**Durum:** Onaylandi

## Amac

Gecmis sekmesini "tamamlanmis islemlerin kronolojik listesi"nden "tum surecleri arayip bulabilecegim bir merkez"e donusturmek. Hibrit yaklasim: varsayilan olarak tamamlanmis islemleri goster, toggle ile kapsamı genislet.

## Bilesenler

### 1. Kapsam Toggle (Kayar Buton)

Arama input'unun sagina toggle switch eklenir.

- **Varsayilan: kapali** — sadece tamamlanmis islemler (mevcut davranis)
- **"Tumu" acikken** — devam eden gorevler, bekleyen tohumlamalar, aktif vakalar da dahil
- Toggle state `_gecmisTumu` global flag'de tutulur
- Degistiginde `loadGecmis` yeniden cagrilir
- Filtre butonlari (Hepsi/Dogum/Tohumlama/Hastalik/Gorev/Hayvan) her iki modda calisir

### 2. Veri Kaynaklari

| Filtre | Mevcut (tamamlanmis) | Tumu acikken eklenen |
|--------|---------------------|----------------------|
| Dogum | `dogum` tablosu (hepsi) | Degisiklik yok |
| Tohumlama | `tohumlama` (hepsi) | Degisiklik yok |
| Hastalik | `cases` (hepsi) | Degisiklik yok |
| Gorev | `gorev_log` `tamamlandi=true && !parent_id` | `tamamlandi` filtresi kalkar, `!parent_id` kalir |
| Hayvan | `islem_log` belirli tipler | Degisiklik yok |

Pratikte sadece gorev filtresinde degisiklik var. Diger tablolar zaten tam cekiliyordu.

Gorev kartlarinda durum pill'i:
- `tamamlandi=true` → gri "Tamamlandi"
- `tamamlandi=false` → mavi "Bekliyor"

### 3. TEDAVI_GUN Kart Render

Mevcut sorun: `type==='gorev'` dalinda `data.aciklama` ham JSON string olarak title'a basiliyor.

TEDAVI_GUN gorevleri ozel render alir:
- **Title**: `{kupe} — Gun {N} tedavisi` (aciklama JSON'dan `label` parse edilir)
- **Sub satir 1**: Ilac adlari virgulle (`drug_administrations` → `stok.urun_adi`)
- **Sub satir 2**: Hastalik adi (`case` → `disease`) + durum pill
- **Tiklama**: `openCaseDet(case_id)`

Diger gorev tipleri (MUAYENE, ASI vb.) mevcut render'i korur, sadece `aciklama` JSON ise `label` parse edilir.

### 4. Tiklama Davranislari

| Tip | Tiklama | Degisiklik |
|-----|---------|------------|
| dogum | `openDet(anne_id)` | Yok |
| tohumlama | `openTohDet(id)` | Yok |
| hastalik | `openCaseDet(id)` | Yok |
| gorev (TEDAVI_GUN) | `openCaseDet(case_id)` | Yeni |
| gorev (diger) | `openDet(hayvan_id)` | Yeni |
| islem | `openDet(ana_hayvan_id)` | Yok |

### 5. Arama

Mevcut arama mekanizmasi korunur. Ek olarak:
- TEDAVI_GUN kartlarinda ilac adlari aranabilir (`_drugNames` → `_gecmisSearchText`)
- Gorev aciklama JSON'dan `label` parse edilir (ham JSON yerine)
- Toggle "Tumu" acikken arama tum surecleri tarar

## Etkilenen Dosyalar

- `index.html` — toggle switch HTML
- `js/ui.js` — `loadGecmis`, `_gecmisEntryHtml`, `_gecmisSearchText`
- `js/utils/handlers.js` — toggle handler

## Degismeyen

- Filtre butonlari, arama debounce, dogum/tohumlama/hastalik/islem render'lari
- Hicbir RPC veya DB degisikligi yok
- Stok, gorevler, hayvan detay sayfalari etkilenmez

## Risk

Dusuk. Sadece UI render ve filtre genislemesi. Mevcut davranis toggle kapaliyken birebir korunur.
