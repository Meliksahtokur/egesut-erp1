# BUG-051: Doğum Sonrası Stale State Anatomisi

**Tarih:** 2026-06-05
**Kaynak:** Migration analizi + gitnexus_context + JS kodu okuma

---

## ÖZET BULGU

**dogum_kaydet RPC'nin en son versiyonu (`20260603000001`), anyonik BESLEME görevlerini iptal eden bloğu İÇERMİYOR.** Bu blok daha önce `20260521000005_besleme_gorevi.sql` migration'ı ile eklenmişti ancak sonraki migration (`20260603000001_protokol_etken_kod.sql`) `CREATE OR REPLACE FUNCTION` ile BESLEME bloğu olmadan yeniden yazdı.

---

## 1. dogum_kaydet Anatomy

### Migration Geçmişi

| Migration | Değişiklik | BESLEME iptali var mı? |
|-----------|-----------|----------------------|
| `20260306000008_blok1_backend.sql` | İlk versiyon | ❌ (ilk versiyon) |
| `20260326000026_grup_padok_fixes.sql` | Grup/padok fix | ❌ |
| `20260326000027_besi_trigger_baba_fixes.sql` | Baba auto-fill | ❌ |
| `20260521000005_besleme_gorevi.sql` | **BESLEME iptal bloğu eklendi** | **✅** |
| `20260603000001_protokol_etken_kod.sql` | **Latest — protokol etken_kod** | **❌ KAYIP** |

### Latest RPC (20260603000001)

- **Parametreler:** p_anne_id, p_tarih, p_kupe, p_cins, p_tip, p_kg, p_baba, p_hekim_id
- **Dönüş:** jsonb `{ok, buzagi_id, dogum_id, gorev_sayisi, tohumlama_kapatildi}`
- **Yan etkiler:**
  1. ✅ Anne kontrol (hayvanlar tablosu)
  2. ✅ Küpe duplikasyon kontrolü
  3. ✅ Baba bilgisi otomatik doldurma (aktif Gebe tohumlamadan)
  4. ✅ Doğum kaydı INSERT
  5. ✅ Buzağı ID oluşturma + hayvanlar tablosuna INSERT
  6. ✅ Anne grup/padok güncelleme (→ Sağmal Laktasyonda)
  7. ✅ 10 protokol görevi oluşturma (etken_kod ile)
  8. ✅ Buzağı ana görev + 6 alt görev (BUZAGI_BAKIM)
  9. ✅ Tohumlama kaydını kapatma (sonuc='Doğum Yaptı')
  10. ❌ **EKSİK: BESLEME görevlerini iptal etme**
  11. ❌ **EKSİK: ileri_gebe data invalidation**

---

## 2. Anyonik BESLEME Görev İptali

### Kayıp Blok (20260521000005_besleme_gorevi.sql:346-352)

```sql
-- 9. Doğumda aktif BESLEME görevlerini iptal et
UPDATE gorev_log
SET iptal = true
WHERE hayvan_id = p_anne_id
  AND gorev_tipi = 'BESLEME'
  AND tamamlandi = false
  AND iptal = false;
```

**Bu blok latest RPC'de (20260603000001) yok.** `CREATE OR REPLACE FUNCTION` ile yeniden yazılırken düşmüş.

### Mevcut Durum

- `besleme_tamam(text)` RPC'si hala mevcut (tamamlama + zincirleme yapıyor)
- `gebelik_protokol_kontrol()` hala 260. günde BESLEME görevi oluşturuyor
- Ama **doğum yapan hayvanın BESLEME görevleri iptal edilmiyor**
- Hayvan doğum yapıp laktasyona geçmesine rağmen "Anyonik Besleme" görevleri `tamamlandi=false, iptal=false` olarak kalıyor

### Etkilenen Tablo: gorev_log
- `gorev_tipi = 'BESLEME'`
- `iptal = false`
- `tamamlandi = false`
- Bu görevler dashboard'da "geciken görev" veya "aktif görev" olarak görünmeye devam eder

---

## 3. ileri_gebeler Güncelleme Durumu

### ileri_gebe_view Tarihçesi
1. `20260519000001` — `ileri_gebe_view` oluşturuldu (210+ gün gebe inekler için)
2. `20260521000002_drop_ileri_gebe_view.sql` — **VIEW DROP EDİLDİ**
   - Sebep: Dashboard RPC sonucu (`gebelik_protokol_kontrol().hayvanlar`) kullanıyor artık
3. `20260521000001_gebelik_protokol_kontrol_hayvan_listesi.sql` — RPC'ye `hayvanlar` array'i eklendi

### Mevcut Veri Akışı
```
gebelik_protokol_kontrol() RPC
  └── returns {ok, olusturulan, hayvanlar: [{kuspe_no, gebelik_gun, ...}]}
       └── frontend: ileriGebeKontrol() → window.__ileriGebeListesi = res.hayvanlar
            └── dashboard: loadDash() → nearBirth band
```

### submitBirth Sonrası Ne Oluyor? (forms.js:168-180)
```javascript
// SADECE bunlar:
toast(`✅ Doğum kaydedildi...`);
closeM('m-birth');
// Form sıfırlama...
pullTables(['hayvanlar','dogum','gorev_log']).then(renderSafe).catch(console.warn);
```

**renderSafe** → `renderFromLocal()` çağırır → `loadDash()` çağırır → `ileriGebeKontrol()` çağırır.

**Sorun:** `pullTables` Async olduğu için `renderSafe` çalıştığında `tohumlama` tablosu henüz güncellenmemiş olabilir. `dogum_kaydet` RPC tohumlama.sonuc='Doğum Yaptı' yapar ama bu değişiklik henüz IndexedDB'ye yansımamıştır.

**Eksik:** submitBirth sonrası `pullTables` listesinde `tohumlama` YOK:
```javascript
pullTables(['hayvanlar','dogum','gorev_log'])  // ← 'tohumlama' eksik!
```

---

## 4. Eksik Yan Etkiler Tablosu

| Yan Etki | Olması Gereken Yer | Şu Anda Nerede? | Fix Önerisi |
|----------|-------------------|-----------------|-------------|
| BESLEME görev iptali | dogum_kaydet RPC (step 9) | ❌ Migration overwrite ile kayboldu | RPC içine BESLEME UPDATE bloğu ekle |
| ileri_gebe invalidation | submitBirth → pullTables | ❌ `tohumlama` tablosu pull edilmiyor | `pullTables`'a `tohumlama` ekle |
| ileri_gebe invalidation | Frontend: `ileriGebeKontrol()` çağrısı | ❌ Sadece loadDash üzerinden dolaylı | submitBirth başarı callback'inde `ileriGebeKontrol()` çağır |
| Tohumlama invalidation | submitBirth → pullTables | ❌ `tohumlama` tablosu eksik | `pullTables`'a `tohumlama` ekle |
| Dashboard güncelleme | submitBirth → renderSafe | ✅ renderSafe → renderFromLocal → loadDash | Zincir sağlam ama `tohumlama` eksikliği yüzünden stale |

---

## 5. Trigger Analizi

| Trigger | Tablo | Event | Ne yapıyor? | dogum_kaydet ile ilişkisi |
|---------|-------|-------|-------------|--------------------------|
| `fn_islem_log` | tohumlama | AFTER UPDATE | sonuc='Doğum Yaptı' → islem_log'a DOGUM_KAYDI yazar | ✅ Çalışıyor (UPDATE tetikliyor) |
| `fn_gebe_gorev_yarat` | tohumlama | AFTER INSERT | sonuc='Gebe' → ILERI_GEBE görevleri | İlgisiz (sadece INSERT) |
| Cycle guard trigger | tohumlama | BEFORE UPDATE | Cycle iptali | İlgili ama BUG-051 ile doğrudan alakasız |

---

## 6. Risk Değerlendirmesi

### BESLEME iptal kaybı
- **Risk:** YÜKSEK
- **Etki:** Doğum yapan hayvanın anyonik besleme görevleri aktif kalır. Dashboard'da kafa karıştırıcı görünür. Çiftlik çalışanları doğum yapmış hayvana anyonik besleme vermeye çalışabilir.
- **Tespit:** 3 haftadır fark edilmemiş (kayıp 2026-06-03 migration'ından beri)
- **Çözüm:** `dogum_kaydet` RPC'sine BESLEME iptal bloğunu geri eklemek

### ileri_gebe / tohumlama stale
- **Risk:** ORTA
- **Etki:** Doğum kaydı sonrası hayvan dashboard'da hala "ileri gebe" bandında görünebilir. Sayfa manuel yenilenene kadar.
- **Sebep:** submitBirth'te `pullTables` çağrısına `tohumlama` eklenmemiş
- **Çözüm:** `pullTables(['hayvanlar','dogum','gorev_log','tohumlama'])` veya submitBirth callback'inde `ileriGebeKontrol()` çağırmak

---

## 7. Önerilen Fix Yaklaşımı

### A — RPC içi fix (öncelikli)
1. `dogum_kaydet` RPC'sine step 9 olarak BESLEME iptal bloğunu geri ekle
2. Yeni migration dosyası oluştur

### B — Frontend fix
1. `submitBirth` başarı callback'inde `pullTables`'a `tohumlama` ekle
2. Veya `submitBirth` sonrası `ileriGebeKontrol()` manuel çağır

### Öneri: A + B ikisi birlikte
- **A** (RPC) — BESLEME iptali için zorunlu
- **B** (frontend) — Stale state önlemek için tamamlayıcı
- Toplam iş: 2 dosyada değişiklik (1 SQL migration + 1 JS)
