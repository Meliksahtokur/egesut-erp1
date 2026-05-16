# EgeSut ERP - Mimari Ihlal Remediation Tasarimi

> **Tarih:** 2026-05-16
> **Kapsam:** Tum mimari ihlallerin duzeltilmesi (A + C + B sirasiyla)
> **Felsefe:** Frontend asla is mantigi yapmaz. Tum yazma RPC, tum hesaplama view/RPC.

---

## Ozet

24 mimari ihlal tespit edildi. 3 fazda duzeltilecek:

| Faz | Grup | Ihlal Sayisi | Risk | Tahmini Sure |
|-----|------|-------------|------|-------------|
| 1 | A - RPC Bypass (write() ile PATCH) | 6 | Yuksek | 12 saat |
| 2 | C - Frontend Hesaplama | 7 | Orta | 4 saat |
| 3 | B - Direkt REST (db.from()) | 11 | Yuksek (dusuk trafik) | 8 saat |

Ek bulgular (arastirma sirasinda kesfedilen):
- `gorev_guncelle` RPC_MAP'te tanimli ama DB'de yok
- `stok_hareket_ekle` RPC_MAP'te tanimli ama DB'de yok  
- `cikis_yap` forms.js'den cagiriliyor ama DB'de yok
- `drug_product_ekle` forms.js'den cagiriliyor ama DB'de yok

---

## FAZ 1 - Grup A: RPC Bypass Duzeltmeleri

### Ilke
Her `write('tablo', {...}, 'PATCH', ...)` cagrisi yerine `rpc('fonksiyon', {...})` kullanilacak.
Her yeni RPC: SECURITY DEFINER, jsonb donus, islem_log kaydi, validasyon.

---

### A1 - Sutten Kesme Tarihi

**Ihlal:** `forms.js:429,447` - `write('hayvanlar', { suttten_kesme_tarihi: bugun }, 'PATCH', ...)`
**Sorun:** Direkt PATCH, validasyon yok, audit log yok.

**Cozum:**
1. **Yeni RPC:** `buzagi_sutten_kesme_onayla(p_hayvan_id uuid)`
   - Validasyon: hayvan.grup ILIKE '%Sut Icen Buzagi%', durum='Aktif'
   - `UPDATE hayvanlar SET suttten_kesme_tarihi = CURRENT_DATE WHERE id = p_hayvan_id`
   - `INSERT INTO islem_log (tip, hayvan_id, detay)` -> SUTTEN_KESME_ONAYI
   - Return: `{ok: true, hayvan_id, tarih}`

2. **Frontend degisikligi:**
   - `forms.js:429` -> `await rpc('buzagi_sutten_kesme_onayla', { p_hayvan_id: id })`
   - `forms.js:447` -> ayni RPC cagrisi

3. **RPC_MAP guncelleme:** Gerekli degil (tek seferlik islem, queue'dan gecmez)
4. **RPC_TABLES guncelleme:** `buzagi_sutten_kesme_onayla: ['hayvanlar', 'islem_log']`

---

### A2 - Tohumlanabilir Onay

**Ihlal:** `forms.js:462` - `write('hayvanlar', { tohumlama_durumu: 'tohumlanabilir', tohumlama_onay_tarihi: ... }, 'PATCH', ...)`
**Sorun:** State machine bypass, frontend tarih hesabi, validasyon yok.

**Cozum:**
1. **Yeni RPC:** `hayvan_tohumlanabilir_onayla(p_hayvan_id uuid)`
   - Validasyon:
     - hayvan.durum = 'Aktif'
     - hayvan.cinsiyet = 'Disi'
     - yas >= irk_esik.tohumlama_gun (irk bazli)
     - Aktif gebelik yok (tohumlama.sonuc != 'Gebe')
     - hayvan.kisir = false
   - `UPDATE hayvanlar SET tohumlama_durumu = 'tohumlanabilir', tohumlama_onay_tarihi = CURRENT_DATE`
   - `INSERT INTO islem_log` -> TOHUMLAMA_DURUMU_ONAYLA
   - Return: `{ok: true, hayvan_id}`

2. **Frontend degisikligi:**
   - `forms.js:462` -> `await rpc('hayvan_tohumlanabilir_onayla', { p_hayvan_id: hayvanId })`

3. **RPC_TABLES:** `hayvan_tohumlanabilir_onayla: ['hayvanlar', 'islem_log']`

---

### A3 - Tohumlama Erteleme

**Ihlal:** `forms.js:474-476` - `dFwd(now, ay*30)` frontend tarih hesabi + `write('hayvanlar', { tohumlama_durumu: 'ertelendi', tohumlama_onay_tarihi: erteleme }, 'PATCH', ...)`
**Sorun:** Tarih hesabi frontend'de, state machine bypass, audit yok.

**Cozum:**
1. **Yeni RPC:** `hayvan_tohumlama_ertele(p_hayvan_id uuid, p_ay integer)`
   - Validasyon: p_ay BETWEEN 1 AND 12, hayvan.durum = 'Aktif'
   - `v_erteleme := CURRENT_DATE + (p_ay * 30)`
   - `UPDATE hayvanlar SET tohumlama_durumu = 'ertelendi', tohumlama_onay_tarihi = v_erteleme`
   - `INSERT INTO islem_log` -> TOHUMLAMA_ERTELEME, detay: {ay: p_ay, hedef: v_erteleme}
   - Return: `{ok: true, hedef_tarih: v_erteleme}`

2. **Frontend degisikligi:**
   - `forms.js:474-476` -> `await rpc('hayvan_tohumlama_ertele', { p_hayvan_id: hayvanId, p_ay: ay })`
   - `dFwd()` cagrisi kaldirilir

3. **RPC_TABLES:** `hayvan_tohumlama_ertele: ['hayvanlar', 'islem_log']`

---

### A4 - Gorev Tamamlama (3 tablo, transaction yok)

**Ihlal:** `forms.js:626-631` - 3 ayri `write()`: gorev_log PATCH + stok_hareket INSERT + hayvanlar PATCH
**Sorun:** Atomik degil, stok hareketi manuel, padok guncelleme validasyonsuz.

**Cozum:**
1. **Yeni RPC:** `gorev_tamamla(p_gorev_id text, p_padok_hedef text DEFAULT NULL)`
   - Validasyon: gorev_log.tamamlandi = false
   - Transaction icinde:
     a. `UPDATE gorev_log SET tamamlandi = true, tamamlanma_tarihi = NOW() WHERE id = p_gorev_id`
     b. Gorev stok_id varsa: `INSERT INTO stok_hareket (stok_id, tur, miktar, notlar, iptal) VALUES (v_gorev.stok_id, 'Gorev', v_gorev.miktar, 'GorevID:'||p_gorev_id, false)`
     c. p_padok_hedef ve hayvan_id varsa: `UPDATE hayvanlar SET padok = p_padok_hedef WHERE id = v_gorev.hayvan_id`
   - `INSERT INTO islem_log` -> GOREV_TAMAMLA
   - Return: `{ok: true, gorev_id, stok_dusuldu: boolean, padok_guncellendi: boolean}`

2. **Frontend degisikligi:**
   - `forms.js:626-631` -> `await rpc('gorev_tamamla', { p_gorev_id: id, p_padok_hedef: padok || null })`
   - 3 satir write() tek rpc() olur

3. **RPC_MAP guncelleme:** `gorev_log: { PATCH: 'gorev_tamamla' }` (mevcut gorev_guncelle yerine)
4. **RPC_TABLES:** `gorev_tamamla: ['gorev_log', 'stok_hareket', 'hayvanlar', 'islem_log']`

5. **Ek: `gorev_guncelle` phantom RPC temizligi:**
   - RPC_MAP'teki `gorev_guncelle` referansi `gorev_tamamla` ile degistirilmeli
   - buildRpcParams'taki gorev_guncelle case'i guncellenmeli

---

### A5 - Stok Ekleme / Guncelleme

**Ihlal:** `forms.js:941,975-981` - Frontend aritmetik + manuel UUID + 2 ayri write (stok PATCH + stok_hareket INSERT)
**Sorun:** Race condition, transaction yok, stok aritmetigi frontend'de.

**Cozum:**
1. **Yeni RPC:** `stok_ekle(p_urun_adi text, p_kategori text, p_birim text, p_baslangic_miktar numeric, p_esik numeric DEFAULT 0)`
   - Yeni stok kaydini UUID ile olusturur
   - Ilk stok_hareket kaydini olusturur (tur='Baslangic')
   - Return: `{ok: true, stok_id}`

2. **Yeni RPC:** `stok_ekleme(p_stok_id text, p_miktar numeric, p_notlar text DEFAULT NULL)`
   - Validasyon: stok kaydi var mi, p_miktar > 0
   - Transaction icinde:
     a. `UPDATE stok SET baslangic_miktar = baslangic_miktar + p_miktar`
     b. `INSERT INTO stok_hareket (stok_id, tur, miktar, notlar, iptal) VALUES (p_stok_id, 'Ekleme', -p_miktar, ...)`
   - Return: `{ok: true, yeni_toplam}`

3. **Frontend degisikligi:**
   - `forms.js:941` -> `await rpc('stok_ekleme', { p_stok_id: curStk.id, p_miktar: mik })`
   - `forms.js:975-977` -> `await rpc('stok_ekleme', { p_stok_id: mevcut.id, p_miktar: bslg })`
   - `forms.js:981-984` -> `await rpc('stok_ekle', { p_urun_adi: urun, p_kategori: kat, p_birim: birim, p_baslangic_miktar: bslg, p_esik: esik })`

4. **RPC_MAP:** stok icin yeni mapping ekle
5. **RPC_TABLES:** `stok_ekle: ['stok', 'stok_hareket'], stok_ekleme: ['stok', 'stok_hareket']`

---

### A6 - Tohumlama Direkt INSERT (Manuel Gebelik)

**Ihlal:** `forms.js:1031` - `write('tohumlama', { id: crypto.randomUUID(), ..., sonuc: 'Gebe', deneme_no: 1 })`
**Sorun:** State machine tamamen bypass, validasyon yok, gorev uretilmiyor, audit yok.

**Cozum:**
1. **Yeni RPC:** `gebelik_kaydet_manual(p_hayvan_id uuid, p_tarih date, p_sperma text DEFAULT NULL)`
   - Validasyon: hayvan aktif/disi, yas >= 365 gun, aktif gebelik yok, tarih ileri degil
   - Transaction icinde:
     a. `INSERT INTO tohumlama (hayvan_id, tarih, sperma, sonuc, deneme_no) VALUES (..., 'Gebe', 1)`
     b. 21-gun ve 35-gun kontrol gorevleri olustur
     c. Gebe gorev trigger'i da calisir (240/260/261/265 gun gorevleri)
   - `INSERT INTO islem_log` -> GEBELIK_MANUEL_KAYDI
   - Return: `{ok: true, tohumlama_id, gorev_sayisi}`

2. **Frontend degisikligi:**
   - `forms.js:1031` -> `await rpc('gebelik_kaydet_manual', { p_hayvan_id: hayvanId, p_tarih: tarih, p_sperma: sperma || null })`

3. **RPC_TABLES:** `gebelik_kaydet_manual: ['tohumlama', 'gorev_log', 'hayvanlar', 'islem_log']`

---

### A-EK: Phantom RPC Temizligi

Arastirmada kesfedilen, RPC_MAP/kod'da referans edilen ama DB'de olmayan fonksiyonlar:

| Phantom RPC | Referans Yeri | Cozum |
|-------------|---------------|-------|
| `gorev_guncelle` | ui.js:3506 RPC_MAP | `gorev_tamamla` ile degistir |
| `stok_hareket_ekle` | ui.js:3507 RPC_MAP | `stok_ekleme` RPC'si kapsayacak, MAP'ten kaldir veya yeni RPC yaz |
| `cikis_yap` | forms.js (cikis formu) | Yeni RPC yaz: `hayvan_cikis(p_hayvan_id, p_neden, p_tarih, p_notlar)` |
| `drug_product_ekle` | forms.js (stok ekleme) | Yeni RPC yaz veya mevcut `stok_ekle` icine entegre et |

**`hayvan_cikis` RPC tasarimi:**
- Validasyon: hayvan aktif olmali
- `UPDATE hayvanlar SET durum = 'Pasif', cikis_tarihi = p_tarih, cikis_nedeni = p_neden`
- `INSERT INTO islem_log` -> HAYVAN_CIKIS
- Return: `{ok: true}`

---

## FAZ 2 - Grup C: Frontend Hesaplama -> View Kullanimi

### Ilke
Frontend'de tekrarlanan hesaplamalar kaldirilir, mevcut DB view'lari kullanilir.

---

### C1-C6 - Stok Net Hesaplama (6 Kopya!)

**Ihlal:** ui.js:220, 1537, 2019, 2361, 3087, 3158 - Ayni hesaplama 6 yerde:
```js
const used = moves.filter(m => m.stok_id === s.id).reduce((a,m) => a+(+m.miktar||0), 0);
const guncel = (+s.baslangic_miktar||0) - used;
```

**Mevcut View:** `stok_tuketim_view` DB'de zaten var!
- Kolonlar: `guncel_stok`, `stok_durum` ('tukendi'|'kritik'|'normal'), `toplam_kullanim`

**Cozum:**
1. **api.js FETCHERS guncelleme:**
   - `stok` fetch'i `stok_tuketim_view`'dan cekilecek:
   ```js
   stok: () => db.from('stok_tuketim_view').select('*')
   ```
   - `stok_hareket` fetch'i artik stok hesabi icin gerekli degil (sadece detay gosterimi icin kalabilir)

2. **Frontend 6 lokasyon degisikligi:**
   - Her yerde `const used = moves.filter...` blogu kaldirilir
   - Yerine `s.guncel_stok` ve `s.stok_durum` kullanilir
   - Ornek: `ui.js:220` -> `const critStk = stock.filter(s => s.stok_durum === 'kritik').length`
   - Ornek: `ui.js:1537` -> `return {...s, guncel: s.guncel_stok, durum: s.stok_durum}`

3. **Performans kazanimi:** O(n*m) filter+reduce yerine DB'den hazir deger gelir

---

### C7 - Dashboard Gebelik/Bos Orani

**Ihlal:** ui.js:2000-2004 - Frontend'de gebe/bos orani hesaplanıyor
**Mevcut View:** `gebelik_ozet_view` DB'de var ama kullanilmiyor!
- Kolonlar: `gebe_sayisi`, `bekleyen_sayisi`, `abort_sayisi`, `dogum_yapti_sayisi`, `gebelik_orani_pct`

**Cozum:**
1. **api.js FETCHERS'a ekle:**
   ```js
   gebelik_ozet: () => db.from('gebelik_ozet_view').select('*')
   ```

2. **Frontend degisikligi:**
   - `ui.js:2000-2004` -> `gebelik_ozet_view`'dan gelen hazir degerleri kullan
   - `const gebeOran = ozet.gebelik_orani_pct`
   - `const abortlar = ozet.abort_sayisi`

3. **Ek: dashboard_stats view (opsiyonel)**
   - Tum dashboard istatistiklerini tek view'da birlestirmek icin olusturulabilir
   - Ancak zorunlu degil — gebelik_ozet_view + stok_tuketim_view yeterli

---

## FAZ 3 - Grup B: Direkt REST -> RPC

### Ilke
`db.from('tablo').insert/update/delete(...)` cagrilari RPC'ye tasinir.
Admin CRUD dusuk trafikli oldugu icin oncelik en dusuk.

---

### B1-B2 - Stok Guncelleme ve Arsivleme

**Ihlal:**
- `ui.js:1781` - `db.from('stok').update(updates).eq('id', ...)`
- `ui.js:1797` - `db.from('stok').update({kategori:'Arsiv'}).eq('id', ...)`

**Cozum:**
1. **Yeni RPC:** `stok_guncelle(p_stok_id text, p_urun_adi text, p_kategori text, p_birim text, p_esik numeric)`
   - Validasyon: stok kaydi var mi
   - Return: `{ok: true}`

2. **Yeni RPC:** `stok_arsivle(p_stok_id text)`
   - Validasyon: aktif hareket var mi kontrol
   - `UPDATE stok SET kategori = 'Arsiv'`
   - Return: `{ok: true}`

3. **Frontend:** `ui.js:1781` -> `rpc('stok_guncelle', {...})`, `ui.js:1797` -> `rpc('stok_arsivle', {...})`

---

### B3 - Vaccine Rapel Guncelleme

**Ihlal:** `ui.js:3669` - `db.from('vaccines').update({repeat_interval_days: days}).eq('id', vaccineId)`

**Cozum:**
1. **Yeni RPC:** `vaccine_rapel_guncelle(p_vaccine_id uuid, p_repeat_days integer)`
   - Validasyon: p_repeat_days > 0
   - Return: `{ok: true}`

2. **Frontend:** `ui.js:3669` -> `rpc('vaccine_rapel_guncelle', {...})`

---

### B4-B5 - Hekim Ekleme ve Guncelleme

**Ihlal:**
- `ui.js:3686` - `db.from('hekimler').insert({id, ad, aktif:true})`
- `ui.js:3800` - `db.from('hekimler').update({ad}).eq('id', ...)`

**Mevcut RPC:** `hekim_ekle` zaten var! Ama `ui.js:3686` kullanmiyor.

**Cozum:**
1. **Frontend:** `ui.js:3686` -> `rpc('hekim_ekle', { p_id: id, p_ad: ad })` (mevcut RPC)
2. **Yeni RPC:** `hekim_guncelle(p_hekim_id text, p_ad text)`
   - Return: `{ok: true}`
3. **Frontend:** `ui.js:3800` -> `rpc('hekim_guncelle', {...})`

---

### B6 - Sperma (Stok) Direkt INSERT

**Ihlal:** `ui.js:3830` - `db.from('stok').insert({id:'SP'+Date.now(), ...})`

**Cozum:** Faz 1'deki `stok_ekle` RPC'si bunu da kapsayacak.
- **Frontend:** `ui.js:3830` -> `rpc('stok_ekle', { p_urun_adi: kod, p_kategori: 'Sperma', p_birim: 'doz', p_baslangic_miktar: 0, p_esik: 0 })`

---

### B7-B11 - Padok CRUD

**Ihlal:**
- `ui.js:3892` - padok update
- `ui.js:3909-3910` - padok delete (2 tablo, transaction yok)
- `ui.js:4079-4093` - padok insert + grup_padok_eslem CRUD

**Cozum:**
1. **Yeni RPC:** `padok_ekle(p_ad text, p_kapasite integer DEFAULT NULL)`
   - Return: `{ok: true, padok_id}`

2. **Yeni RPC:** `padok_guncelle(p_padok_id uuid, p_ad text, p_kapasite integer)`
   - Validasyon: kapasite >= mevcut hayvan sayisi
   - Return: `{ok: true}`

3. **Yeni RPC:** `padok_sil(p_padok_id uuid)`
   - Validasyon: padokta aktif hayvan yok
   - Transaction: `DELETE grup_padok_eslem` + `DELETE padoklar`
   - Return: `{ok: true}`

4. **Yeni RPC:** `grup_padok_eslem_toggle(p_grup text, p_padok_id uuid, p_checked boolean)`
   - p_checked=true -> INSERT, p_checked=false -> DELETE
   - Return: `{ok: true}`

5. **Frontend:** Tum `db.from()` cagrilari -> `rpc()` ile degistirilir

---

## Yeni Kesfedilen Sorunlar (Ek)

### EK1 - `cikis_yap` RPC Eksik

**Sorun:** forms.js'den `rpc('cikis_yap', {...})` cagiriliyor ama DB'de fonksiyon yok.
**Cozum:** Faz 1 A-EK bolumunde tanimli `hayvan_cikis` RPC'si yazilacak.

### EK2 - `drug_product_ekle` RPC Eksik

**Sorun:** forms.js stok ekleme icinde cagiriliyor ama DB'de fonksiyon yok.
**Cozum:** `stok_ekle` RPC'si icine entegre edilebilir veya ayri RPC olarak yazilabilir.
Karar: Ayri RPC olarak yazilsin (separation of concerns).

**Yeni RPC:** `drug_product_ekle(p_brand_name text, p_stock_item_id text, p_unit text DEFAULT 'ml')`
- `INSERT INTO drug_products (brand_name, stock_item_id, unit)`
- Return: `{ok: true, drug_product_id}`

### EK3 - `stok_hareket_ekle` Phantom RPC

**Sorun:** RPC_MAP'te `stok_hareket: { POST: 'stok_hareket_ekle' }` var ama DB'de yok.
**Cozum:** Basit stok hareketi kaydeden RPC yazilacak.

**Yeni RPC:** `stok_hareket_ekle(p_stok_id text, p_tur text, p_miktar numeric, p_notlar text DEFAULT NULL)`
- Validasyon: stok kaydi var mi, p_miktar > 0
- `INSERT INTO stok_hareket`
- Return: `{ok: true, hareket_id}`

---

## Toplam Yeni RPC Listesi

| # | RPC Adi | Faz | Kapsadigi Ihlal |
|---|---------|-----|-----------------|
| 1 | `buzagi_sutten_kesme_onayla` | 1-A1 | forms.js:429,447 |
| 2 | `hayvan_tohumlanabilir_onayla` | 1-A2 | forms.js:462 |
| 3 | `hayvan_tohumlama_ertele` | 1-A3 | forms.js:474-476 |
| 4 | `gorev_tamamla` | 1-A4 | forms.js:626-631 |
| 5 | `stok_ekle` | 1-A5 | forms.js:981-984, ui.js:3830 |
| 6 | `stok_ekleme` | 1-A5 | forms.js:941,975-977 |
| 7 | `gebelik_kaydet_manual` | 1-A6 | forms.js:1031 |
| 8 | `hayvan_cikis` | 1-EK1 | forms.js cikis formu |
| 9 | `drug_product_ekle` | 1-EK2 | forms.js stok ekleme |
| 10 | `stok_hareket_ekle` | 1-EK3 | RPC_MAP phantom |
| 11 | `stok_guncelle` | 3-B1 | ui.js:1781 |
| 12 | `stok_arsivle` | 3-B2 | ui.js:1797 |
| 13 | `vaccine_rapel_guncelle` | 3-B3 | ui.js:3669 |
| 14 | `hekim_guncelle` | 3-B5 | ui.js:3800 |
| 15 | `padok_ekle` | 3-B10 | ui.js:4093 |
| 16 | `padok_guncelle` | 3-B7 | ui.js:3892 |
| 17 | `padok_sil` | 3-B8 | ui.js:3909-3910 |
| 18 | `grup_padok_eslem_toggle` | 3-B11 | ui.js:4079,4081 |

**Not:** `hekim_ekle` zaten mevcut, sadece frontend'in kullanmasi saglanacak.

---

## Frontend Degisiklik Haritasi

### forms.js Degisiklikleri
| Satir | Mevcut | Yeni |
|-------|--------|------|
| 429 | `write('hayvanlar', {...}, 'PATCH')` | `rpc('buzagi_sutten_kesme_onayla', {...})` |
| 447 | `write('hayvanlar', {...}, 'PATCH')` | `rpc('buzagi_sutten_kesme_onayla', {...})` |
| 462 | `write('hayvanlar', {...}, 'PATCH')` | `rpc('hayvan_tohumlanabilir_onayla', {...})` |
| 474-476 | `dFwd() + write('hayvanlar', {...}, 'PATCH')` | `rpc('hayvan_tohumlama_ertele', {...})` |
| 626-631 | 3x `write()` (gorev+stok+hayvan) | `rpc('gorev_tamamla', {...})` |
| 941 | `write('stok', {...}, 'PATCH')` | `rpc('stok_ekleme', {...})` |
| 975-981 | `write('stok',...) + write('stok_hareket',...)` | `rpc('stok_ekleme', {...})` veya `rpc('stok_ekle', {...})` |
| 1031 | `write('tohumlama', {...})` | `rpc('gebelik_kaydet_manual', {...})` |

### ui.js Degisiklikleri
| Satir | Mevcut | Yeni |
|-------|--------|------|
| 220, 1537, 2019, 2361, 3087, 3158 | `moves.filter().reduce()` stok hesabi | `s.guncel_stok` (view'dan) |
| 2000-2004 | `gebe.length/aktif.length*100` | `gebelik_ozet_view` degerler |
| 1781 | `db.from('stok').update(...)` | `rpc('stok_guncelle', {...})` |
| 1797 | `db.from('stok').update({kategori:'Arsiv'})` | `rpc('stok_arsivle', {...})` |
| 3669 | `db.from('vaccines').update(...)` | `rpc('vaccine_rapel_guncelle', {...})` |
| 3686 | `db.from('hekimler').insert(...)` | `rpc('hekim_ekle', {...})` |
| 3800 | `db.from('hekimler').update(...)` | `rpc('hekim_guncelle', {...})` |
| 3830 | `db.from('stok').insert(...)` | `rpc('stok_ekle', {...})` |
| 3892 | `db.from('padoklar').update(...)` | `rpc('padok_guncelle', {...})` |
| 3909-3910 | `db.from(...).delete()` x2 | `rpc('padok_sil', {...})` |
| 4079,4081 | `db.from('grup_padok_eslem').insert/delete` | `rpc('grup_padok_eslem_toggle', {...})` |
| 4093 | `db.from('padoklar').insert(...)` | `rpc('padok_ekle', {...})` |

### api.js Degisiklikleri
| Degisiklik | Detay |
|-----------|-------|
| FETCHERS.stok | `db.from('stok')` -> `db.from('stok_tuketim_view')` |
| FETCHERS.gebelik_ozet | Yeni ekleme: `db.from('gebelik_ozet_view')` |
| RPC_TABLES | 18 yeni RPC icin tablo mapping'leri eklenmeli |
| RPC_MAP (ui.js) | gorev_guncelle -> gorev_tamamla, stok_hareket_ekle guncelle |

---

## Migration Plani

Her faz icin tek migration dosyasi:

1. **`20260517000001_faz1_rpc_bypass_fix.sql`** - 10 yeni RPC (A1-A6 + EK1-EK3 + stok_ekle)
2. **`20260517000002_faz2_view_kullanim.sql`** - View'larda gerekli ayarlamalar (varsa)
3. **`20260517000003_faz3_admin_crud_rpc.sql`** - 8 yeni RPC (B1-B11)

---

## Test Stratejisi

Her RPC icin:
1. **Basarili cagri:** Dogru parametrelerle cagir, sonuc kontrol
2. **Validasyon hatasi:** Yanlis parametrelerle cagir, hata mesaji kontrol
3. **Idempotency:** Ayni cagrinin tekrari veri bozmuyor mu
4. **islem_log:** Kayit olusturuldu mu, geri_al() ile geri alinabiliyor mu

Frontend icin:
1. **Fonksiyonel test:** Form submit -> RPC cagiriliyor mu
2. **Hata durumu:** RPC hata donerse toast gosteriliyor mu
3. **View verisi:** Stok hesaplamalari view'dan dogru mu geliyor

---

## Riskler ve Azaltmalar

| Risk | Etki | Azaltma |
|------|------|---------|
| Offline queue RPC_MAP degisikligi | Onceden queue'da bekleyen kayitlar eski formatta | Migration oncesi queue bosaltmasi (syncNow) |
| View performansi | stok_tuketim_view agir olabilir | EXPLAIN ANALYZE + gerekirse materialized view |
| Mevcut RPC imzasi uyumsuzlugu | buildRpcParams eski parametreleri bekler | Her RPC'nin parametre mapping'i guncellenmeli |
| Paralel gelistirme catismasi | Baska gelistiriciler ayni dosyalarda calisiyorsa | Branch bazli calisma, merge oncesi test |
