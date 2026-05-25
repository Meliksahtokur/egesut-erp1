# Tedavi → Görev Entegrasyonu

**Tarih:** 2026-05-25  
**Durum:** Fikir — FAZA 2, henüz planlanmadı (Faza 1 = done sistemi, ayrı)  
**Motivasyon:** Planlanan tedavi günleri (ileriki tarihler) şu an sadece vaka modalında görünüyor.
Görevler sekmesiyle bağlantısı yok — çiftçi ertesi gün ne yapması gerektiğini görevlerden takip edemiyor.

## Netleşen Kararlar (2026-05-25 istişare)

- **Rol ayrımı yok** — şimdilik tek kullanıcı = yönetici. Auth/rol en sona bırakıldı.
- **Görev bağlantısı manuel** — treatment_day yazılınca otomatik görev açılmaz. Vet "Görev olarak planla" seçerse açılır. "Sahaya sürmeye hazır değil" durumları korunuyor.
- **Done = tamamlandi:true + tamamlanma_tarihi (timestamp)** — başka meta yok, şimdilik yeterli.
- **Başarısız mantığı:** salt gün değil, `treatment_date + treatment_time + grace(~3h) < now` → gecikmiş. Gece 23:00 tedavisi sabah 02:00'de yapılsa başarılı sayılır.
- **Görev iptal:** gorev silinse bile treatment_day kalır, vakada "iptal_edildi" etiketi yaşar.
- **Tek DB değişikliği (Faza 2):** `gorev_log.treatment_day_id uuid FK REFERENCES treatment_days(id) ON DELETE SET NULL`

## Açık Sorular (Faza 2 öncesi netleşmeli)

1. Grace süresi: sabit 3h mi, değişken mi?
2. "Yapıldı" dashboarddan yapılınca ekstra ilaç eklenebilecek mi?
3. Tekrarlayan görev desteği: "5 gün boyunca her gün" → 5 ayrı görev mi?

---

---

## Mevcut Mimari

```
cases           → id, animal_id, disease_id, start_date, status, notes
treatment_days  → id, case_id, treatment_date, day_no, treatment_time
drug_admins     → id, treatment_day_id, drug_id, dose, unit, route

gorev_log       → id, hayvan_id, gorev_tipi, aciklama, hedef_tarih,
                   tamamlandi, tamamlanma_tarihi, kaynak, parent_id, ...
```

`treatment_days` ile `gorev_log` arasında **hiç bağlantı yok**.
İkisi paralel dünyada yaşıyor.

---

## Problem

Kullanıcı bugün bir vaka açıp 3 günlük tedavi planı yazıyor (yarın, öbür gün, 3 gün sonra).
Bu günler `treatment_days`'e kaydediliyor ama görevler sekmesinde **hiç görünmüyor**.

İki kullanım senaryosu var:

**A — O an yaptım, kaydettim** (reaktif)  
"Şu an verdim, arşive alayım." → Görev: does not apply. treatment_day bugün, zaten yapıldı.

**B — Planlıyorum, hatırlatsin** (proaktif)  
"Yarın sabah ilaç ver." → İşte burada görevler sekmesiyle bağlantı gerekiyor.

---

## Mimari Seçenekler

### Seçenek 1 — DB Trigger: treatment_days → gorev_log otosync

Treatment_days'e INSERT yapılınca:
- Eğer `treatment_date > today` → `gorev_log`'a otomatik kayıt
- `gorev_tipi = 'TEDAVI'`, `kaynak = 'TEDAVI_PLANI'`, `hedef_tarih = treatment_date`
- `aciklama = 'Vaka #X — Gün N tedavisi'` (case bilgisi join ile)
- `hayvan_id` cases tablosundan çekilir

**Silme senkronizasyonu:** treatment_day silinince → linked gorev de silinmeli.  
→ `gorev_log`'a `treatment_day_id uuid` kolonu ekle, ON DELETE CASCADE trigger koy.

**Tamamlama senkronizasyonu:**  
- Görev done yapılınca → treatment_day "done" mu sayılmalı? DB'de böyle bir kolon yok.  
- Ya da: treatment_date geçince ve ilaç eklenmişse → gorev otomatik tamamlandı sayılır.

**Avantaj:** Görev sekmesi kendi başına çalışır, hiçbir UI değişikliği gerekmez.  
**Dezavantaj:** İki tablo arasında iki yönlü sync — karmaşık. Biri güncellenir öbürü stale kalabilir.

---

### Seçenek 2 — Frontend Virtual Merge (DB değişikliği yok)

`loadTasks()` fonksiyonu `treatment_days` tablosunu da okur, gelecek tarihlileri görev gibi gösterir.
Hafıza içi merge, IDB'den:
```js
// gorev_log + gelecek treatment_days → birleşik liste
const virtualGorevler = futureTreatmentDays.map(td => ({
  id: 'td_' + td.id,
  hayvan_id: caseMap[td.case_id]?.animal_id,
  gorev_tipi: 'TEDAVI',
  hedef_tarih: td.treatment_date,
  aciklama: `Gün ${td.day_no} tedavisi — ${diseaseMap[caseMap[td.case_id]?.disease_id]?.name}`,
  tamamlandi: td.treatment_date < today && td.has_drugs,  // ilaç eklenmişse done
  _source: 'treatment_day',
  _treatment_day_id: td.id
}));
```

**Avantaj:** Hiç migration yok, DB sade kalır.  
**Dezavantaj:** Görev sekmesinde "tamamla" tıklayınca ne olacak? gorev_log'a mı yazacak, treatment_day'e mi? İki yerde farklı durum oluşabilir.

---

### Seçenek 3 — Hybrid: gorev_log'a treatment_day_id FK ekle, sync opsiyonel

`gorev_log`'a tek kolon: `treatment_day_id uuid REFERENCES treatment_days(id) ON DELETE CASCADE`

Kullanıcı treatment_day eklerken "Görev olarak planla" toggle'ı seçerse → gorev_log'a kayıt.  
Seçmezse → sadece vaka kaydı.

"Görev tamamla" → gorev_log.tamamlandi = true (zaten var).  
"Treatment day'e ilaç eklendi" → gorev otomatik done yapılabilir (trigger veya frontend).

**Avantaj:** İsteğe bağlı, kademeli geçiş. Her treatment_day otomatik görev olmak zorunda değil.  
**Dezavantaj:** UI'da toggle ekstra adım, UX komplikasyonu.

---

### Seçenek 4 — Sadece "TEDAVI" tipi görevden vaka oluşturma (ters yön)

Görevler sekmesinden "Tedavi" tipli görev oluşturulunca → vaka ya da treatment_day bağlanır.
"Bugün Muayene ol" → görev. "5 gün ilaç ver" → 5 görev (tekrarlayan).

Bu seçenek mevcut görev oluşturma akışını güçlendirir, vaka modali dokunulmaz.

---

## Önerilen Yaklaşım

**Kısa vadede (az iş, büyük kazanç):** Seçenek 2 — Virtual Merge  
- `loadTasks()` `treatment_days` IDB'den okur, bugün ve gelecek tarihlileri oluşturur
- Görev sekmesinde `🏥 Tedavi` tipiyle görünür, tıklayınca doğrudan vaka modalı açılır
- "Tamamla" butonu → görev sekmesinde gizlenir (treatment_day'i treatment_day modundan yönet)
- Migration yok, sıfır sync riski

**Uzun vadede (doğru mimari):** Seçenek 3 + Hybrid  
- `gorev_log.treatment_day_id` FK
- Treatment_day oluşturunca opsiyonel "🔔 Görev olarak hatırlat" toggle
- Tamamlama iki yönde çalışır

---

## UI Değişiklikleri (Vaka Modalı)

Mevcut durum garip hissettiriyor çünkü:
1. Gün kartları inline style seli — tutarsız görünüm
2. "Bugün Tedavi Günü Ekle" → takvim açıyor, tek tık olmalı
3. Vaka özeti yok: kaç gün, toplam kaç ilaç, son tedavi ne zaman
4. "Kapat" butonu ile "Vakayı Kapat" aynı görsel ağırlıkta, karışıklık

**İstenen akış:**
```
[🏥 Topallık]    [🔴 Aktif 4. gün]
[#156]  ·  📅 22.05 — 25.05  ·  3 ilaç
─────────────────────────────────────
[➕ Bugün Ekle]   [📅 Başka Gün]

📋 Tedavi Günleri
┌─ Gün 1 — 24.05 18:00 ────────────────────┐
│  Fulimed 20ml IM · Sefanel 20ml IM       │
│  Teknovet B12 50ml IM           [+ İlaç] │
└───────────────────────────────────────────┘
...
─────────────────────────────────────────
[✅ Vakayı Kapat]
```

---

## İlgili Dosyalar

- `js/ui.js:2587` → `openCaseDet()`
- `js/ui.js:2627` → `renderCaseTimeline()`
- `js/ui.js:2740` → `caseGunEkle()`
- `js/ui.js` → `loadTasks()` (göreve ekleme noktası)
- `index.html:1340` → `m-case-det` modal HTML
- `supabase/migrations/99999999999999_ground_truth.sql:2715` → `treatment_days` tablo
- `supabase/migrations/99999999999999_ground_truth.sql:44` → `gorev_log` tablo

---

## Açık Sorular

1. Görev sekmesinde "tamamla" tıklayınca treatment_day modeli ne olacak?
   - Sadece görsel mi? (gorev_log tamamlandi = true, treatment_day dokunulmaz)
   - Yoksa ilaç da kaydedilmeli mi? (Tedaviyi hem planladın hem yaptın)

2. Tekrarlayan görevler: "5 gün boyunca her sabah ilaç ver" → 5 ayrı görev mi, 1 tekrarlayan görev mi?

3. Virtual merge yeterli mi yoksa gerçek DB bağlantısı şart mı?
   - Offline sync açısından virtual merge daha güvenli (IDB'den okur)
   - Bildirim/push notification hedefliyorsak DB seviyesinde kayıt şart
