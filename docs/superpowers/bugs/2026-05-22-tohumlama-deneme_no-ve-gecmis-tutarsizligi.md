# Tohumlama — deneme_no / geçmiş tutarsızlığı

**Tarih:** 2026-05-22
**Durum:** ✅ Düzeltildi — 2026-05-23 (commit `aca3557`)
**Bekleyen:** Sorun 3 (veri kaynağı farkı) ve Sorun 4 (Önceki Denemeler) hala açık.
**Keşfeden:** DeepSeek TUI (arşiv: `/root/egesut-erp1`)

---

## Sorunlar

### 1. `deneme_no` listede artık görünmüyor (🔴 Kritik)

**DB'de iki farklı kolon:**

| Kolon | Ne işe yarar | Güncel değer (195 için) |
|-------|-------------|------------------------|
| `deneme_no` | Trigger `set_deneme_no()` atar. Cycle başına 1,2,3... | 2026-05-21 kaydı → **3** |
| `deneme_sayisi` | `tohumlama_tekrar_kaydet` RPC artırır. AYNI kayıt üzerinde kaç kez Tekrar Aşım yapıldığı. | **1** (hiç Tekrar Aşım yapılmamış) |

**Frontend yanlış kolonu referans alıyor — `deneme_sayisi` yerine `deneme_no` kullanılmalı:**

| Yer | Satır | Hatalı kod |
|-----|-------|-----------|
| Hayvan detay → üreme | `js/ui.js:789` | `t.deneme_sayisi > 1 ? ...` |
| Üreme → Tohumlama tab | `js/ui.js:1538` | `t.deneme_sayisi > 1 ? ...` |
| Tohum detay modal | `js/ui.js:3111` | `t.deneme_sayisi\|\|1` → hep "1. deneme" |

Geçmiş tab (`js/ui.js:1617`) doğru — `data.deneme_no` kullanıyor.

---

### 2. Modal "kafasına göre numara" veriyor (🔴 Kritik)

`js/ui.js:3111`:
```js
`<span>${t.deneme_sayisi||1}. deneme</span>`
```

`deneme_sayisi` DEFAULT 1 olduğu için `1||1 = 1` → her kayıt "1. deneme". Oysa DB'de `deneme_no=3` olan kayda "3. deneme" yazılmalı.

---

### 3. "2 kayıt var ama 1 görünüyor" — veri kaynağı farkı (🔴 Kafa Karışıklığı)

**Hayvan detay sayfasında iki farklı veri kaynağı:**

```
Üreme tab  → IndexedDB'den tohumlama tablosu     (js/ui.js:924)
Geçmiş tab → Supabase'den direkt islem_log       (js/ui.js:801)
```

`tohumlama_tekrar_kaydet` RPC mevcut tohumlama kaydını **günceller** (yeni kayıt oluşturmaz). Ama islem_log her iki operasyonu da ayrı kaydettiği için geçmiş tab'da fazla kayıt görünür. 195 için:

- **tohumlama tablosu:** 2026-05-21 → 1 kayıt
- **islem_log:** 2026-05-21 → 2 TOHUMLAMA kaydı

> **Not:** `tohumlama_tekrar_kaydet` RPC islem_log yazmaz. 2026-05-21'deki 2. islem_log kaydı muhtemelen bulk geçmiş yüklemeden kalma veya `tohumlama_sonuc_bos` gibi başka bir operasyondan.

---

### 4. Modal'da "Önceki Denemeler" hiç görünmüyor (🟡 Orta)

`js/ui.js:3185`:
```js
if(t.denemeler&&t.denemeler.length>0){
```

- `denemeler` jsonb kolonu sadece `tohumlama_tekrar_kaydet` RPC tarafından doldurulur
- Normal `tohumlama_kaydet` ile oluşturulan tüm kayıtlarda `denemeler = []`
- 195'in tüm kayıtlarında DB sorgusuyla `denemeler: []` teyit edildi

Önceki denemeleri göstermek için aynı hayvanın aynı cycle'daki diğer tohumlama kayıtlarını `denemeler` jsonb yerine `tohumlama` tablosundan sorgulamak gerekir.

---

## Önerilen Düzeltme (3 satır)

**Sadece `deneme_sayisi` → `deneme_no` değişikliği:**

| Dosya | Satır | Şu an | Olması gereken |
|-------|-------|-------|---------------|
| `js/ui.js` | 789 | `t.deneme_sayisi > 1 ? ... ${t.deneme_sayisi}. Deneme` | `t.deneme_no > 1 ? ... ${t.deneme_no}. Deneme` |
| `js/ui.js` | 1538 | Aynı | Aynı |
| `js/ui.js` | 3111 | `t.deneme_sayisi\|\|1` | `t.deneme_no\|\|1` |

---

## DB Doğrulama

Migration'lar deploy edilmiş durumda:
- `deneme_sayisi` kolonu → Supabase'de var, tüm kayıtlar DEFAULT 1
- `denemeler` jsonb kolonu → Supabase'de var, tüm kayıtlar `[]`
- `tohumlama_tekrar_kaydet` RPC → Supabase'de var, çalışıyor

---

## İlgili Migration'lar

| Migration | İçerik |
|-----------|--------|
| `20260521000003_gebelik_deneme_no_per_cycle.sql` | `set_deneme_no()` trigger per-cycle, `tohumlama_kaydet` RPC güncellemesi |
| `20260521000004_backfill_deneme_no.sql` | Mevcut kayıtların deneme_no backfill |
| `20260522000004_tekrar_asim.sql` | `deneme_sayisi` + `denemeler` kolonları, `tohumlama_tekrar_kaydet` RPC |

## Referans

- Keşif sırası: `js/ui.js` satır 789, 1538, 1617, 3111, 3185; `js/forms.js` satır 209; Supabase sorguları
- Araştırma DeepSeek TUI ile yapıldı (root model: DeepSeek V4)
