# Aşılama Modülü Frontend Spec
> Tarih: 2026-04-09 · Sprint: VAC-01

---

## 0. Mevcut Durum Özeti

### ✅ Tamamlanan (Migration 032)
| Katman | Durum | Detay |
|--------|-------|-------|
| DB `vaccines` | ✅ | 10 seed aşı, name UNIQUE, stok FK |
| DB `vaccination_schedule` | ✅ | Protokol tanımları, timing, hedef grup |
| DB `vaccination_log` | ✅ | Uygulama kaydı, next_due_date, stok trigger |
| RPC `add_vaccination` | ✅ | Hayvan kontrolü, doz, stok düşümü, gorev_log yazımı, islem_log |
| RPC `get_vaccination_schedule` | ✅ | Hayvana özel protokol önerisi |
| RPC `list_vaccinations` | ✅ | Hayvan aşı geçmişi JOIN |
| HTML `m-vaccine` modal | ✅ | Hayvan, aşı dropdown, tarih, doz, notlar — index.html:573–612 |
| `openDet` aşı geçmişi | ✅ | `vaccination_log` IDB'den render — ui.js:489–511 |
| `openDet` "Aşı Uygula" butonu | ✅ | `openMWithHayvan('m-vaccine','v-hid',...)` — ui.js:486 |
| `pullTables` | ✅ | `vaccines`, `vaccination_log` dahil — api.js:13 |
| IDB store | ✅ | `egesut_v10`'da kayıtlı — api.js:10–13 |

### ❌ Eksik (Bu spec kapsamı)
| Bileşen | Dosya | Açıklama |
|---------|-------|----------|
| `loadVaccinesDropdown()` | forms.js | `v-vaccine-id` select'ini DB'den doldurur |
| `onVaccineSelect()` | forms.js | Seçilen aşının bilgilerini gösterir |
| `submitVaccination()` | forms.js | Validasyon + `add_vaccination` RPC |
| Dashboard alarm band | ui.js → `loadDash()` | Vadesi gelen/geçen aşı hatırlatmaları |
| `ASI_HATIRLATMA` görev render | ui.js → `renderTask()` | Görev listesinde aşı görevleri |
| Ayarlar: Aşı Kataloğu | ui.js | Vaccine listesi görüntüleme (readonly) |

---

## 1. Bileşen: m-vaccine Modal

### 1.1 HTML Değişikliği — `index.html`

Mevcut modal (satır 573–612) korunur; yalnızca iki iyileştirme:

**a) `v-vaccine-info` altına protokol öneri bölgesi ekle:**
```html
<!-- Protokol Önerisi (onVaccineSelect ile doldurulur) -->
<div id="v-protocol-hint" style="display:none;margin-top:4px;padding:6px 10px;
  border-radius:8px;background:rgba(78,154,42,.12);border:1px solid rgba(78,154,42,.25);
  font-size:.72rem;color:var(--ink2);line-height:1.5">
</div>
```
Yerleştirme: `v-vaccine-info` div'inden hemen sonra, `v-date` form grubundan önce.

**b) Doz alanının altına birim göstergesi ekle (onVaccineSelect doldurur):**
```html
<span id="v-dose-unit" style="font-size:.68rem;color:var(--ink3);margin-left:6px"></span>
```
`v-dose-override` input'ının yanına satır içi yerleştir.

---

### 1.2 `loadVaccinesDropdown()` — forms.js'e ekle

**Tetikleyici:** Modal açıldığında `openMWithHayvan('m-vaccine', ...)` çağrısı içinde çağrılır.

```
loadVaccinesDropdown()
  ├── IDB'den vaccines çek: getData('vaccines')
  ├── Yoksa: pullTables(['vaccines']).then(getData)
  ├── v-vaccine-id select'ini doldur:
  │    zorunlu aşılar üstte (is_mandatory=true), sonra diğerleri
  │    <option value="{id}">{name} — {disease_target}</option>
  └── Tarih alanını bugüne set et: v-date.value = today
```

**Sıralama kuralı:** `is_mandatory` true olanlar group başlığı `<optgroup label="Zorunlu">` altında, false olanlar `<optgroup label="Diğer">` altında.

**Hata durumu:** `vaccines` listesi boşsa dropdown'a `<option disabled>Aşı listesi yüklenemedi</option>` yaz, kaydet butonunu devre dışı bırak.

---

### 1.3 `onVaccineSelect()` — forms.js'e ekle

**Tetikleyici:** `v-vaccine-id` `onchange` eventi.

```
onVaccineSelect()
  ├── Seçili vaccine_id yoksa: v-vaccine-info, v-protocol-hint gizle → return
  ├── IDB'den vaccines: getData('vaccines', v => v.id === selectedId)
  ├── v-vaccine-info göster:
  │    "Standart doz: {dose} {unit} · Uygulama: {route}"
  │    "Tekrar: {repeat_interval_days} günde bir" (null ise gösterme)
  ├── v-dose-unit.textContent = unit  (doz alanı placeholder için)
  ├── v-protocol-hint:
  │    Eğer repeat_interval_days varsa:
  │    "⏰ Bu aşı uygulandıktan {repeat_interval_days} gün sonra otomatik
  │     hatırlatma görevi oluşturulur."
  │    Yoksa: "Tek doz aşı — hatırlatma görevi oluşmaz."
  └── v-dose-override.placeholder = dose (standart doz)
```

---

### 1.4 `submitVaccination()` — forms.js'e ekle

**Tetikleyici:** "💉 Aşı Uygula" butonu `onclick`.

```
submitVaccination(btn)
  ├── btn.disabled = true
  ├── Hayvan: v-hid.value.trim()  →  boşsa toast("Hayvan seçin") return
  ├── Aşı: v-vaccine-id.value     →  boşsa toast("Aşı seçin") return
  ├── Tarih: v-date.value         →  boşsa toast("Tarih girin") return
  │    ileri tarih kontrolü: tarih > today → toast("İleri tarih girilemez") return
  ├── Doz override: parseFloat(v-dose-override.value) || null
  ├── Notlar: v-notes.value.trim() || null
  ├── Hayvan ID çözümle:
  │    IDB'den hayvan bul (kupe_no veya id eşleşmesi)
  │    bulunamazsa toast("Hayvan bulunamadı") return
  ├── rpcOptimistic(
  │    'add_vaccination',
  │    {
  │      p_animal_id: hayvan.id,
  │      p_vaccine_id: vaccineId,
  │      p_date: date,
  │      p_dose_override: doseOverride,
  │      p_notes: notes
  │    },
  │    {
  │      successMsg: '💉 Aşı kaydedildi',
  │      onSuccess: (res) => {
  │        closeM('m-vaccine')
  │        resetVaccineForm()
  │        if (res.next_due) toast(`⏰ Sonraki aşı: ${fmtTarih(res.next_due)}`, 'info')
  │      }
  │    })
  └── .finally(() => btn.disabled = false)

> **NOT:** `api.js` `RPC_TABLES` map'ine `add_vaccination` girişi eklenmeli:
> ```javascript
> add_vaccination: ['vaccination_log', 'gorev_log', 'stok_hareket'],
> ```
> `rpcOptimistic` bu map'ten ilgili tabloları otomatik çeker (api.js:286).
```

**`resetVaccineForm()`:**
```
v-hid.value = ''
v-vaccine-id.value = ''
v-date.value = today
v-dose-override.value = ''
v-notes.value = ''
v-vaccine-info gizle
v-protocol-hint gizle
v-dose-unit.textContent = ''
```

---

### 1.5 `openMWithHayvan` güncelleme — ui.js

Mevcut `openMWithHayvan` fonksiyonu (`ui.js:2428–2543`) `m-vaccine` case'ini ele almaz. Eklenecek:

```javascript
// m-vaccine case'ine loadVaccinesDropdown() çağrısı
case 'm-vaccine':
  loadVaccinesDropdown();
  break;
```

---

## 2. Bileşen: Dashboard Alarm Band — "Yaklaşan Aşılar"

### 2.1 Konum ve Tetikleyici

`loadDash()` fonksiyonu (`ui.js:53–115`) içine yeni alarm band eklenir. Mevcut "Yaklaşan Doğumlar" bandının hemen altına yerleşir.

### 2.2 Hesaplama Mantığı

```
_dashVacAlerts(today, vaxLogs, vaccines)
  ├── Grupla: vaccination_log kayıtlarında next_due_date olan tüm kayıtlar
  ├── Geciken  : next_due_date < today  →  kırmızı (red)
  ├── Bu hafta : next_due_date <= today+7 →  turuncu (amber)
  ├── Bu ay    : next_due_date <= today+30 → mavi (blue)
  └── Her kayıt için: hayvan küpe no + aşı adı + kaç gün kaldı/geçti
```

**Görünmeme kuralı:** Hiç kayıt yoksa band render edilmez.

**Limit:** İlk 5 kayıt gösterilir, fazlası `+N daha` satırıyla belirtilir.

### 2.3 HTML Yapısı

```html
<div class="aband">
  <div class="aband-hdr {red|amber|blue}">
    💉 Yaklaşan Aşılar ({toplam_sayı})
  </div>
  <div class="aband-body">
    <!-- her hayvan için bir .arow -->
    <div class="arow" onclick="openDet('{hayvan_id}')">
      <div class="arow-left">
        <div class="arow-main">{kupe_no} — {vaccine_name}</div>
        <div class="arow-sub">
          {gecikmiş: "⚠️ {N} gün gecikti" | "⏰ {N} gün kaldı"}
        </div>
      </div>
      <div class="arow-right">{tarih_str}</div>
    </div>
  </div>
</div>
```

**Renk önceliği:** Herhangi bir gecikmiş kayıt varsa başlık kırmızı; tümü bu haftaysa turuncu; tümü bu aydaysa mavi.

### 2.4 Veri Kaynağı

`loadDash()` başında zaten `pullTables` çağrısı var. Buraya `'vaccination_log'` ve `'vaccines'` eklenmesi gerekiyorsa kontrol et — migration 032 sonrası `api.js` TABLES listesinde zaten var.

---

## 3. Bileşen: Hayvan Detay — Sağlık Sekmesi (tab-saglik)

### 3.1 Mevcut Durum

`openDet` sağlık sekmesi (`ui.js:484–512`):
- "Aşı Uygula" butonu ✅
- Aşı geçmişi listesi ✅ (vaxLogs IDB'den, vaccines ile join)

**Sorun:** Geçmiş listede `vaxLogs` değişkeni tanımlı ancak hayvan filtrelemesi `getData('vaccination_log', v => v.animal_id === id)` ile yapılıyor — bu doğru. Kontrol et: `idbGetAll('vaccines')` yerine `getData('vaccines')` kullanılmalı (tutarlılık için).

### 3.2 İyileştirme: Sonraki Aşı Göstergesi

Aşı geçmişi başlığının yanına "Sıradaki aşı" bilgisi eklenir:

```
// ui.js _detSaglikHtml içinde:
const nextDues = vaxLogs
  .filter(v => v.next_due_date)
  .sort((a,b) => a.next_due_date.localeCompare(b.next_due_date));
const nextVax = nextDues[0];  // en yakın gelecek aşı
```

Eğer `nextVax` varsa, "Aşı Uygula" butonunun hemen altına bilgi chip'i:
```html
<div class="chip chip-k" style="font-size:.68rem">
  ⏰ Sonraki: {vaccine_name} — {fmtTarih(next_due_date)}
  {gecikmiş ise: class="chip-r" ve "⚠️ gecikti" uyarısı}
</div>
```

### 3.3 Protokol Öneri Butonu (Opsiyonel — v2)

`get_vaccination_schedule` RPC'si hayvan için protokol önerir. İleride "Protokolü Uygula" butonuyla toplu aşı uygulama akışı tetiklenebilir. Bu sprint kapsamı dışı, yer tutucu bırak.

---

## 4. Bileşen: Görev Listesi — ASI_HATIRLATMA Tipi

### 4.1 `renderTask()` Güncelleme — ui.js

Mevcut görev render fonksiyonu `gorev_tipi` değerlerine göre ikon/renk belirler. `ASI_HATIRLATMA` için eksik:

```javascript
// gorev_tipi → ikon mapping'e ekle:
'ASI_HATIRLATMA': '💉'

// Başlık rengi: --blue (mavi) — gecikmiş ise --red
// aciklama alanı zaten aşı adı + "Tekrar dozu" içerir (RPC'den)
```

### 4.2 Dashboard Görev Bandı

Dashboard'daki bekleyen görevler bandında `ASI_HATIRLATMA` tipi görevler artık görünecek. Ek filtreleme gerekmez.

---

## 5. Bileşen: Ayarlar — Aşı Kataloğu

### 5.1 Konum

`ayarlarAc()` / `renderAyarlarHekimList()` gibi ayarlar panelleri `ui.js:2583–2750` aralığında. Aynı pattern ile:

```
renderAyarlarVaccineList()
  ├── getData('vaccines')
  ├── Her aşı için kart:
  │    {name} — {disease_target}
  │    {dose} {unit} · {route} · {repeat_interval_days ? "Her "+N+" gün" : "Tek doz"}
  │    {is_mandatory ? "🔴 Zorunlu" : "İhtiyari"}
  └── Düzenleme/silme yok (controlled entity, seed data)
```

**Ayarlar HTML:** Mevcut ayarlar modalına yeni bir sekme veya accordion section ekle.

### 5.2 Seed Aşı Listesi (Referans)

| Ad | Hedef | Doz | Yol | Tekrar |
|----|-------|-----|-----|--------|
| Şarbon Aşısı | Şarbon | 2 ml | SC | 365 gün |
| BVD Aşısı | BVD | 2 ml | IM | 365 gün |
| IBR Aşısı | IBR | 2 ml | IM | 365 gün |
| Leptospirosis | Leptospirosis | 2 ml | IM | 365 gün |
| BRSV Aşısı | BRSV | 2 ml | IM | 365 gün |
| Piogen Aşısı | Piogen | 2 ml | IM | 365 gün |
| Clostridium | Clostridial | 5 ml | IM | 365 gün |
| E. coli Aşısı | E. coli (Buzağı) | 2 ml | IM | 365 gün |
| Rotavirus | Rotavirus (Buzağı) | 2 ml | IM | 365 gün |
| Coronavirus | Coronavirus (Buzağı) | 2 ml | IM | 365 gün |

---

## 6. Veri Akışı

```
Kullanıcı "Aşı Uygula" tıklar
  → openMWithHayvan('m-vaccine', 'v-hid', kupe_no)
      → v-hid.value = kupe_no
      → loadVaccinesDropdown()        [IDB'den vaccines → select doldurur]
      → v-date.value = today

Kullanıcı aşı seçer
  → onVaccineSelect()                 [dose, route, tekrar bilgisi gösterir]

Kullanıcı "Aşı Uygula" tıklar
  → submitVaccination()
      → validasyon (hayvan, aşı, tarih)
      → hayvan ID çözümleme (kupe → id)
      → rpcOptimistic('add_vaccination', [...])
           → DB: vaccination_log INSERT
           → TRIGGER: stok_hareket INSERT (stok bağlıysa)
           → RPC: gorev_log INSERT (ASI_HATIRLATMA, next_due)
           → RPC: islem_log INSERT (ASI_KAYDI)
      → pullTables(['vaccination_log','gorev_log'])
      → renderFromLocal()
      → Modal kapanır
      → next_due varsa toast bilgisi
```

---

## 7. IDB ve pullTables Kontrol Listesi

| Tablo | TABLES listesi (api.js) | pullTables çağrısı |
|-------|------------------------|-------------------|
| `vaccines` | ✅ satır 13 | `openDet` ✅ · `loadDash` kontrolü gerekir |
| `vaccination_log` | ✅ satır 13 | `openDet` ✅ · `loadDash` kontrolü gerekir |

`loadDash()` içinde `pullTables` çağrısına `'vaccines'`, `'vaccination_log'` eklenmesi gerekiyorsa kontrol et.

---

## 8. Validasyon Kuralları

| Kural | Tetikleyici | Hata Mesajı |
|-------|-------------|-------------|
| Hayvan zorunlu | v-hid boş | "Hayvan seçin" |
| Aşı zorunlu | v-vaccine-id boş | "Aşı seçin" |
| Tarih zorunlu | v-date boş | "Tarih girin" |
| İleri tarih yok | v-date > today | "İleri tarih girilemez" |
| Hayvan aktif | RPC kontrolü | RPC'den dönen mesaj gösterilir |
| Stok yeterliliği | RPC trigger | "Yetersiz stok: ..." (RPC'den) |

Backend validasyonu RPC içinde zaten mevcut. Frontend yalnızca basic field kontrolü yapar.

---

## 9. Toplu Aşılama (Sonraki Sprint — BULK-VAC-01)

Bu sprint **kapsam dışı**. Yer tutucu olarak belgelenir:

- Padok bazlı toplu aşılama: tüm hayvanları seç → tek tık → hepsine aynı aşı uygula
- `m-bulk-vaccine` modal: padok/grup filtre + aşı seçimi + tarih
- Backend: `bulk_vaccination(p_animal_ids[], p_vaccine_id, p_date)` RPC gerektirir (henüz yok)
- Önkoşul: `add_vaccination` RPC tekli çalışıyor ve test edildi

---

## 10. Uygulama Sırası

```
1. forms.js: loadVaccinesDropdown()
2. forms.js: onVaccineSelect()
3. forms.js: submitVaccination() + resetVaccineForm()
4. ui.js: openMWithHayvan → m-vaccine case ekle
5. index.html: v-protocol-hint div + v-dose-unit span ekle
6. ui.js: loadDash() → _dashVacAlerts() band
7. ui.js: renderTask() → ASI_HATIRLATMA ikon
8. ui.js: renderAyarlarVaccineList()
9. ui.js: openDet sağlık sekmesi → sonraki aşı chip
10. Test: manuel uygulama → gorev_log + vaccination_log kontrol
```

---

## 11. Test Kriterleri

| Test | Beklenen |
|------|----------|
| Aşı seçildiğinde doz/rota gösterilir | ✅ v-vaccine-info görünür |
| Tekrarlı aşı seçildiğinde protokol hint görünür | ✅ v-protocol-hint görünür |
| Eksik alan ile kaydet | ✅ Toast, modal açık kalır |
| İleri tarih girişi | ✅ Toast, kayıt yapılmaz |
| Geçerli kayıt sonrası | ✅ Modal kapanır, vaccination_log'da kayıt var |
| next_due_date olan aşı sonrası | ✅ gorev_log'da ASI_HATIRLATMA görevi var |
| Stok bağlı aşı sonrası | ✅ stok_hareket'te ledger kaydı var |
| Hayvan detay sağlık sekmesi | ✅ Yeni kayıt listede görünür |
| Dashboard alarm band | ✅ next_due_date yakın hayvanlar görünür |
| Görev listesi | ✅ ASI_HATIRLATMA görevi 💉 ikonu ile görünür |
