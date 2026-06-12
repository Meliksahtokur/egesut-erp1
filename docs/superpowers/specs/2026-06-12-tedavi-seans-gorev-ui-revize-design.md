# Tasarım: Tedavi Seans → Görev Kartı UI Revizyonu (BUG-059 devam)

**Tarih:** 2026-06-12
**Branch:** feature/asilama-tam-mimari
**İlgili:** BUG-059 Faz 5 (klinisyen monitörü reddedildi → ikinci revizyon)
**Önceki handoff:** `.claude/notes/handoff-bug059-faz5-revision.md`

## Problem

Tedavi seans sistemi DB tarafında doğru çalışıyor ama frontend iki yüzeyde de kötü gösteriyor:

1. **Görevler sayfası** — bir günün tüm seansları tek `TEDAVI_GUN` kartına sıkışıyor;
   seanslar `parent_id` ile çocuk olduğu için `loadTasks` filtresi onları gizliyor
   (*"eklenen seans görünmez"* bug'ı). İlaçlar saatten bağımsız tek güne dump ediliyor.
2. **Tedavi modalı (`m-case-det`)** — saatsiz ilaç + seans planı ikiliği 6 butonla
   dağınık, kullanışsız.

DB modeli sağlam: `add_treatment_day_with_sessions` her seans için ayrı `TEDAVI_SEANS`
görevini `parent_id` + `seans_admin_id` ile zaten oluşturuyor. `seans_tamamla` RPC ve
`computeSeansState` (6 zaman-bazlı durum) hazır. **Sorun %100 frontend render + filtre.**
Bu revizyon yeni RPC/migration gerektirmez.

## Kararlar (brainstorm sonucu)

| Konu | Karar |
|---|---|
| Görev listesi düzeni | Her seans **ayrı kart** |
| Gruplama | Aynı hayvan+gün seansları **ince ayraç** altında, saate göre sıralı |
| Tamamlama | Checkbox tek dokunuş = "yapıldı"; kartta `▾` ok → inline ikincil aksiyon (uzun basma/sağ-tık YOK) |
| İlaç modeli | İki yol **korunur** (saatli seans + saatsiz hızlı ilaç), sadece netleşir |
| Saatsiz ilaçlar | Görevde tek `TEDAVI_GUN` kartı, sadece `seans_admin_id=null` ilaçlar |
| Backend | Yeni RPC yok |

## A. Görevler Sayfası

### A1. Seansları üst seviyeye çıkar (filtre fix)

`loadTasks` (`js/ui.js:441`):
```js
let data=all.filter(t=>!t.tamamlandi&&!t.iptal&&(!t.parent_id||_doneIds.has(t.parent_id)));
```
`TEDAVI_SEANS` görevleri `parent_id=TEDAVI_GUN.id` taşıdığı ve parent açık olduğu için
buradan eleniyor. Fix: `gorev_tipi==='TEDAVI_SEANS'` görevlerini parent durumundan
**bağımsız** üst seviye say.

```js
let data=all.filter(t=>!t.tamamlandi&&!t.iptal&&(
  t.gorev_tipi==='TEDAVI_SEANS' || !t.parent_id || _doneIds.has(t.parent_id)
));
```

Aynı düzeltme `updateTaskBadge` (`js/ui.js:554`) ve `done` filtresi için de gözden geçirilir
(TEDAVI_SEANS tamamlanınca done listesinde tekrarlamamalı — done görünümünde gün bazlı özetlenebilir,
detay implementasyon planında).

### A2. TEDAVI_GUN kartını gizle (seanslı günlerde)

Bir `TEDAVI_GUN` görevi, kendisine bağlı en az bir `TEDAVI_SEANS` varsa **görev listesinde
kart olarak render edilmez** — yerine seans kartları + ayraç gösterilir. Sadece saatsiz-ilaç
günlerinde (seansı olmayan) TEDAVI_GUN kartı çizilir.

Render aşamasında: TEDAVI_GUN görevleri için `seans_admin_id`'li çocuk var mı diye bak;
varsa o günün TEDAVI_GUN kartını atla.

### A3. Hayvan/gün ayracı + seans kartları

Görev listesi sıralaması: önce hayvan, sonra gün (treatment_date), sonra `planned_time`.
Aynı `(hayvan_id, day_id)` grubu için bir ayraç başlığı:

```
─ 🐄 1234 · Gün 2/3 · 🏥 Mastitis ─────────
```
- Küpe no: mevcut `getState('animals')` eşlemesi (renderTask'taki pattern)
- `Gün 2/3`: seansın bağlı olduğu `treatment_days.day_no` / toplam gün; `aciklama.day_id`'den
- Teşhis adı: `treatment_days → cases → diseases` (renderCaseTimeline'daki `_dayDiseaseMap` pattern'i,
  `loadTasks` zaten `_dayDiseaseMap` kuruyor — yeniden kullanılır)

Ayraç altında o gruba ait seans kartları.

### A4. Seans kartı

```
┌────────────────────────────────┐
│ ⬜ 🕐14:00 Penisilin 10ml · IM ▾ │
└────────────────────────────────┘
```
- Sol checkbox: dokun → `seansTamamla(seansAdminId, false, btn)` (mevcut handler,
  `js/forms.js:1712`). Optimistic; gerçek saat NOW kaydı; geç ise durum kırmızı.
- Saat + ilaç + doz·yol: seans (`treatment_day_uygulamalar`) alanlarından. İlaç adı
  `drug_products.brand_name` ya da `stok.urun_adi` (renderCaseTimeline pattern'i).
- Durum rengi/etiketi: `computeSeansState(s)` + `SEANS_STATE` (mevcut). `now`/`overdue`
  durumunda `◀ şimdi` / `⚠ gecikti` göstergesi.
- `▾` ok: tıkla → kartın altı **inline** açılır (display toggle):
  - `↩ Yapılmadı · stok iade` → `seansTamamla(seansAdminId, true, btn)`
  - (Saati düzelt bu menüde YOK — modaldaki "Planı Düzenle"den yapılır)
- Tamamlanmış/iptal seans: checkbox yerine durum çipi, `▾` yok.

Mevcut `renderSeansRow` (`js/ui.js:6980`) bu kartın temelidir; görev listesi için
checkbox + `▾` inline varyantına uyarlanır. Yeni `seans-card` benzeri sınıf değil,
mevcut `task-card` / `seans-row` token'ları kullanılır (pastoral tema).

### A5. Saatsiz ilaç dump fix

`loadTasks` `_dayDrugMap` kurulumu (`js/ui.js:460-462`) tüm `drug_administrations`'ı güne
gruplluyor. Fix: **sadece `seans_admin_id` boş (saatsiz) olanlar**:

```js
_allDrugAdmins.forEach(da=>{
  if(da.seans_admin_id) return;            // saatli olanlar seans kartına gider
  (_dayDrugMap[da.treatment_day_id] ||= []).push({...});
});
```
Böylece TEDAVI_GUN kartı sadece gerçekten saatsiz ilaçları gösterir.

## B. Tedavi Modalı (`m-case-det` / `renderCaseTimeline`)

`renderCaseTimeline` (`js/ui.js:4355`) gün akordeonu zaten saatsiz ilaç + seans planını
ayrı render ediyor (`drugHtml` + `seansHtml`). Revizyon görsel sadeleştirme:

1. **İki bölüm net başlıkla ayrılır:**
   - `Hızlı ilaçlar (saatsiz)` — `day.drugs` (mevcut `drugHtml`)
   - `⏰ Seans planı` — `renderSeansSerit` + `renderSeansRow` (mevcut `seansHtml`)
   Boş olan bölüm gizlenir.
2. **Aksiyon çubuğu sadeleşir** (`js/ui.js:4500-4510`): ana akış butonları
   (`+İlaç` / `⏰ Seans Planla|Düzenle` / `📝 Not`) belirgin; ikincil (`🕐 Saat`, `🗑 Sil`)
   küçük ikon. Buton sayısı görsel olarak gruplanır, 6 buton tek satır karmaşası giderilir.
3. Mevcut `.cd-*` sınıfları ve pastoral tema korunur; yeni paralel CSS sistemi eklenmez
   (önceki revizyonun `.med-*` hatası tekrarlanmaz).

## C. Kapsam Dışı (YAGNI)

- Yeni RPC / migration
- Saat-bazlı ajanda (timeline) görünümü — değerlendirildi, reddedildi
- Tek seans `planned_time` düzenleme RPC'si — "Planı Düzenle" replace-mode yeterli
- `▾` menüsünde "Saati düzelt"

## Doğrulama

1. Seanslı güne sahip vaka → görev listesinde her seans ayrı kart, hayvan/gün ayracı altında
2. Yeni seans ekle → anında görev listesinde görünür (*"görünmez" bug'ı gitti*)
3. Saatsiz ilaçlı gün → tek TEDAVI_GUN kartı, sadece saatsizler listeli (*dump gitti*)
4. Seans checkbox dokun → tamamlanır, geç ise uyarı; `▾` → yapılmadı·iade çalışır
5. `now`/`overdue` durum renkleri doğru (*saat sistemi görünür*)
6. Modal akordeonu: iki bölüm net, aksiyon çubuğu sade, görsel tutarlı
7. Mevcut modallarla font/radius/spacing tutarlılığı
```
