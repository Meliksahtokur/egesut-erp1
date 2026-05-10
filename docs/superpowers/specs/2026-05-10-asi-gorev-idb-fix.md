# Spec: Aşı Görev IDB Sync Fix

**Tarih:** 2026-05-10
**Durum:** Analiz tamamlandı, fix bekliyor
**Öncelik:** KRİTİK (gerçek veri, canlı kullanım)

---

## Problem

Aşı görevi "Uygula ve Tamamla" ile tamamlandıktan sonra:
1. ❌ "Tamamlanan görevler" sekmesinde görünmüyor
2. ❌ Rapel (2. doz) görevi "Bekleyen" sekmesinde görünmüyor
3. ✅ Geçmiş işlemler sekmesinde aşı kaydı görünüyor (vaccination_log'dan)
4. ✅ Supabase'de tüm data doğru (tamamlandi=true, rapel oluşmuş)

## Kök Neden

`js/api.js:262` — gorev_log FETCHER filtresi:
```js
gorev_log: () => db.from('gorev_log').select('*').eq('tamamlandi', false),
```

`pullTables(['gorev_log'])` çağrıldığında:
1. Sadece `tamamlandi=false` kayıtları Supabase'den çeker
2. `idbClearAndPut('gorev_log', data)` — IDB'deki TÜM gorev_log'u siler, sadece incomplete olanları koyar
3. Tamamlanmış görevler IDB'den kaybolur → "Done" tab boş
4. `_doneIds` (parent'ı biten rapelleri göstermek için) boş → rapel filtrelenir

## Neden Doğum Görevleri Çalışıyor?

Doğum görevleri `doneTask()` ile tamamlanıyor:
```js
await write('gorev_log', {...task, tamamlandi:true, ...}, 'PATCH', `id=eq.${id}`);
```
`write()` IDB'yi LOKAL olarak güncelliyor (optimistic update). IDB'deki kayıt `tamamlandi=true` olarak kalıyor. Bir sonraki `pullTables` çağrısına kadar done tab çalışıyor.

Ama aşı görevleri `ileri_gebe_asi_tamamla` RPC ile tamamlanıyor → sunucu tarafında çalışıyor → IDB lokal güncelleme YOK → hemen ardından `pullTables` çalışınca incomplete filter yüzünden tamamlanan görev IDB'den siliniyor.

## Supabase Doğrulama (2026-05-10)

```
148 (c9780dc8): 1. doz tamamlandi=true (2026-05-09 19:55) ✅
               Rapel (2. doz) id=60e523dc, hedef=2026-05-30, parent_id=b1e8adc0 ✅

bugünkü (bcc67af7): 1. doz tamamlandi=true (2026-05-10 11:30) ✅
                    Rapel (2. doz) id=82f43dc4, hedef=2026-05-31, parent_id=43f09bca ✅
```

RPC düzgün çalışıyor. Sorun %100 frontend IDB sync.

---

## Çözüm Planı

### Fix 1: FETCHER filtresini kaldır (Ana fix)

**Dosya:** `js/api.js:262`
**Mevcut:** `gorev_log: () => db.from('gorev_log').select('*').eq('tamamlandi', false),`
**Yeni:** `gorev_log: () => db.from('gorev_log').select('*'),`

**Neden tüm kayıtlar?**
- Tamamlanmış görevler "done" tab'da lazım
- `_doneIds` hesaplaması için tamamlanmış parent'lar lazım
- gorev_log tablosu büyük değil (şu an ~50 aktif + ~2 done = ~52 kayıt)
- İleride büyürse: `.or('tamamlandi.eq.false,tamamlanma_tarihi.gte.XXXX')` ile son 90 gün done'ları filtrele

### Fix 2: önceki pullTables satırlarını kaldır (İsteğe bağlı cleanup)

Daha önce (bu sabah) eklenen 3 satırlık fix artık gereksiz değil — hâlâ tutarlılık için faydalı. Ama asıl sorun Fix 1 olmadan hiçbirinin işe yaramamasıydı.

### Fix 3: Realtime subscription tetikleme doğrula (İsteğe bağlı)

`js/api.js:403`:
```js
.on('postgres_changes', { event: '*', schema: 'public', table: 'gorev_log' }, () => pullTables(['gorev_log']).then(renderSafe))
```
Bu zaten var — realtime subscription RPC'nin insert/update'ini yakalaması gerekir. Ama Supabase realtime bazen gecikmeli, o yüzden explicit pull hâlâ gerekli.

---

## Test Senaryosu (Canlı)

Fix sonrası:

1. **Yeni aşı tamamla:**
   - Bekleyen ILERI_GEBE_ASI görevi → "Uygula ve Tamamla"
   - Görevler → "Tamamlanan" tab → AZ ÖNCE tamamlanan görev görünmeli
   - Bekleyen tab → 21 gün sonrası rapel (2. doz) görünmeli

2. **Mevcut veriler doğrula:**
   - 148'in 1. dozu done tab'da görünmeli (2026-05-09)
   - Bugünkü hayvanın 1. dozu done tab'da görünmeli (2026-05-10)
   - Rapeller bekleyen tab'da görünmeli (Mayıs 30 ve 31)

3. **Doğum görevleri regression yok:**
   - Normal görev tamamla → done tab'da görünmeli (mevcut davranış korunmalı)

---

## Risk Değerlendirmesi

- **Düşük risk:** Tek satır değişiklik, filter kaldırma
- **Performans:** gorev_log max birkaç yüz kayıt, select('*') sorun değil
- **Regression:** Tüm veriyi çekmek ek veri = daha doğru UI, kötü tarafı yok
- **Geriye dönük:** Eski filtre geri konabilir, IDB her pull'da yenilendiği için data kaybı yok
