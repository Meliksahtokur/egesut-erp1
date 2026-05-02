## Resolution

BUG-6/6b/4 fixed in migrations 20260409000001/02. tohumlama_sonuc_gebe and tohumlama_sonuc_bos UUID casts resolved. BUG-2 partially fixed (policy done, REALTIME_TABLES flag pending separate spec). BUG-1 pullTables error handling, BUG-2 kizginlik_log realtime, BUG-4 buildRpcParams fix, BUG-5 kızgınlık geçmişi implemented.

**resolved_date:** 2026-05-02
**status:** implemented
**documentation_date:** 2026-04-09

---

# Üreme Modülü Bakım — Bug Fix Plan

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

Reference: PLANS.md methodology at `references/PLANS.md` from skill `community/execplan-skill`.

## Purpose / Big Picture

Bu plan 5 bug'ı düzeltir ve üreme modülünü (kızgınlık kaydı + tohumlama) stabilize eder. Her düzeltmeden sonra kullanıcı, ilgili iş akışını tarayıcıda canlı olarak doğrulayabilir. Tüm değişiklikler `main`'e değil, feature branch'e commit edilir; merge edilmez.

## Progress

- [ ] (2026-04-09) BUG-1: `pullTables` — RPC sonrası sessiz veri kaybı (Kritik)
- [ ] (2026-04-09) BUG-2: `kizginlik_log` Realtime'da yok (Orta)
- [ ] (2026-04-09) BUG-3: `submitKizginlik` — ulaşılamaz kod, `result.oneri` yanlış gösteriliyor (Düşük)
- [ ] (2026-04-09) BUG-4: Offline queue — `kizginlik_kaydet` parametre uyumsuzluğu (Orta)
- [ ] (2026-04-09) BUG-5: Üreme sekmesi — kızgınlık geçmişi gösterilmiyor (Orta)
- [ ] (2026-04-09) BUG-6: `tohumlama_sonuc_gebe` — `operator does not exist: text = uuid` (Kritik)
- [ ] (2026-04-09) BUG-6b: `tohumlama_sonuc_bos` — aynı cast hatası (Kritik)

## Surprises & Discoveries

- Observation: `kizginlik_kaydet` RPC backend'de `ok: false` döndüğünde `oneri` alanı mevcut ama frontend bu yapıyı beklemediği için toast mesajı bozuk. Backend `jsonb_build_object('ok',false,'mesaj',...,'oneri','...')` döner ama frontend `result.oneri` kontrolü yapıyor — bu kısım doğru. Asıl sorun başka: backend `ok:true` döndüğünde `oneri` yok, `ok:false` döndüğünde `oneri` var. Frontend 211-214 satırları doğru çalışır ama 12 aydan küçük hayvan için backend'in döndüğü `oneri` değeri `"Hayvan kartındaki Notlar bölümüne ekleyin"` şeklinde — kullanıcıya gösterilir.
  Evidence: `forms.js:211-213` + `blok1_backend.sql:260-264`

- Observation: `kizginlik_log` tablosu `REALTIME_TABLES` listesinde yok. Bu sebeple başka bir tarayıcı tab'ında veya cihazında yapılan kızgınlık kaydı, mevcut açık tarayıcıda Realtime üzerinden görülmez.
  Evidence: `api.js:366` — `REALTIME_TABLES` dizisi

- Observation: `_detUremeHtml` (ui.js:420-448) sadece `tohumlama` tablosundan gelen `tohs` parametresine bağlı. Kızgınlık geçmişi (`kizginlik_log`) bu fonksiyona hiç aktarılmıyor. `openDet` çağrıldığında `_detRender` üreme sekmesi için `_detUremeHtml`'i çağırıyor ama `kizginlik_log` verisi gönderilmiyor.
  Evidence: `ui.js:420` — fonksiyon sadece `tohs` (tohumlama) alıyor, `kizginlik_log` için parametre yok

- Observation: `RPC_TABLES` (api.js:208) `kizginlik_kaydet: ['kizginlik_log','gorev_log']` girdisini **zaten içeriyor** — bu satır mevcut. Asıl sorun farklı: `buildRpcParams()` fonksiyonu (ui.js:2935-2940) offline queue'daki `kizginlik_kaydet` kayıtları için yanlış parametre adı kullanıyor. `p_gozlem: data.gozlem` gönderiyor; RPC `p_belirti` ve `p_notlar` bekliyor. `p_notlar` da eksik.
  Evidence: `ui.js:2935-2940` — `p_gozlem` kullanılıyor, RPC imzası `p_belirti, p_notlar` bekliyor

- Observation: `tohumlama_sonuc_gebe` ve `tohumlama_sonuc_bos` fonksiyonlarında `WHERE id = v_toh.hayvan_id::uuid` kullanılıyor. `hayvanlar.id` TEXT tipinde ('H000013' gibi) ama ::uuid cast'i 'H000013' gibi bir string UUID olmadığı için başarısız oluyor. Hata: `operator does not exist: text = uuid`. Frontend'deki log: `tohSonuc error: [tohumlama_sonuc_gebei] operator does not exist`.
  Evidence: `tohumlama_sonuc_gebe` prosrc + `information_schema.columns` — `hayvanlar.id` = text, `hayvanlar.durum` = text

## Decision Log

- Decision: BUG-3'ün asıl sorunu `result.oneri` formatı değil, backend'in döndürdüğü `oneri` değerinin kullanıcı için anlamsız olması ("Hayvan kartındaki Notlar bölümüne ekleyin"). Frontend kodu doğru. Kapatılacak.
  Rationale: Backend `ok:false` + `oneri` döndüğünde frontend 211-214 satırları ile doğru şekilde yakalıyor ve toast gösteriyor.
  Date/Author: 2026-04-09

- Decision: BUG-4'ün fix hedefi düzeltildi — `RPC_TABLES`'a ekleme değil, `buildRpcParams()` case düzeltmesi.
  Rationale: Kod incelemesinde `kizginlik_kaydet: ['kizginlik_log','gorev_log']` `api.js:208`'de zaten mevcut. Asıl hata `ui.js:2935-2940`'ta: `p_gozlem` alanı RPC'de yok, `p_belirti`/`p_notlar` olmalı.
  Date/Author: 2026-04-09

## Outcomes & Retrospective

(Tamamlandıktan sonra doldurulacak)

---

## Context and Orientation

Proje `/root/egesut-erp1` dizininde. Ana JS dosyaları:

- `js/api.js` — Supabase client, `pullTables()` (satır 234), `rpc()` wrapper, `RPC_TABLES` map (satır 200), `REALTIME_TABLES` dizisi (satır 366)
- `js/forms.js` — Form submit fonksiyonları; `submitKizginlik` (satır 192)
- `js/ui.js` — DOM render; `_detUremeHtml` (satır 420)
- `js/state.js` — `getState` / `setState`
- `supabase/migrations/` — tüm SQL migration dosyaları

Backend RPC fonksiyonları `supabase/migrations/20260306000008_blok1_backend.sql` içinde. Supabase proje ref: `zqnexqbdfvbhlxzelzju` (eu-west-1).

**Önemli kural:** Tüm backend yazma işlemleri sadece RPC üzerinden yapılır. Direkt REST yazma YASAK.

---

## Plan of Work

### BUG-1: pullTables sessiz veri kaybı (Kritik)

`pullTables` içinde bir fetch hata verse bile `FETCHERS[t]()` hatasız döner — Supabase JS client başarısız istekleri exception yerine `{data: [], error: {...}}` olarak döner. `idbClearAndPut` boş dizi yazdığı için eski veri kaybolur.

Düzeltme: `pullTables` içinde her fetcher'ın `error` kontrolü yapılacak. Hata varsa o tablo için IDB güncellenmez, konsola uyarı yazılır.

Dosya: `js/api.js`, fonksiyon `pullTables` (satır 234-266)

### BUG-2: kizginlik_log Realtime'da yok (Orta)

`REALTIME_TABLES` dizisine `'kizginlik_log'` ekle. Bu basit bir diziye eleman ekleme işlemidir.

Dosya: `js/api.js`, satır 366

### BUG-3: submitKizginlik ulaşılamaz kod (Düşük)

Backend `ok:false` + `oneri` döndüğünde frontend 211-214 satırları doğru çalışıyor. Bug değil. Kapatılacak.

### BUG-4: Offline queue parametre uyumsuzluğu (Orta)

`RPC_TABLES` map'inde `kizginlik_kaydet` **zaten mevcut** (`api.js:208`). Asıl sorun `buildRpcParams()` fonksiyonunda: offline queue gönderiminde `kizginlik_kaydet` case'i yanlış parametre adı (`p_gozlem`) kullanıyor. RPC `p_belirti` ve `p_notlar` bekliyor; `p_notlar` da eksik.

Dosya: `js/ui.js`, satır 2935-2940

### BUG-5: Üreme sekmesi kızgınlık geçmişi yok (Orta)

`_detUremeHtml` fonksiyonu hem `tohumlama` hem `kizginlik_log` verisi alacak şekilde genişletilecek. Kızgınlık kayıtları gebelik tahmini için faydalı bilgi sağlar.

İki adım:
1. `openDet` çağrıldığında `_detUremeHtml`'e `kizginlik_log` verisi aktarılacak sekilde çağrıyı değiştir
2. `_detUremeHtml` fonksiyonu kızgınlık geçmişini listeleyecek

Dosya: `js/ui.js`, satır 420

---

## Concrete Steps

Tüm adımlar `/root/egesut-erp1` dizininde çalışır. Feature branch açılacak, commit'ler oraya yapılacak.

### Step 1 — Branch oluştur

```bash
cd /root/egesut-erp1
git checkout main
git pull origin main
git checkout -b fix/ureme-modulu-bakim
```

### Step 2 — BUG-1: pullTables error handling

`js/api.js` satır 259-260'ı değiştir:

Mevcut:
```javascript
    const results = await Promise.all(uniq.map(t => FETCHERS[t]()));
    await Promise.all(uniq.map((t, i) => idbClearAndPut(t, results[i].data || [])));
```

Yeni:
```javascript
    const results = await Promise.all(uniq.map(t => FETCHERS[t]()));
    await Promise.all(uniq.map((t, i) => {
      if (results[i].error) {
        console.warn(`⚠️ pullTables ${t}: ${results[i].error.message}`);
        return Promise.resolve();
      }
      return idbClearAndPut(t, results[i].data || []);
    }));
```

### Step 3 — BUG-2: kizginlik_log Realtime'a ekle

`js/api.js` satır 366:

Mevcut:
```javascript
const REALTIME_TABLES = ['hayvanlar','gorev_log','stok','stok_hareket','tohumlama','dogum','islem_log','ui_logs'];
```

Yeni:
```javascript
const REALTIME_TABLES = ['hayvanlar','gorev_log','stok','stok_hareket','tohumlama','dogum','kizginlik_log','islem_log','ui_logs'];
```

### Step 4 — BUG-4: buildRpcParams kizginlik_kaydet case düzelt

`js/ui.js` satır 2935-2940'ı değiştir:

Mevcut:
```javascript
    case 'kizginlik_kaydet':
      return {
        p_hayvan_id: data.hayvan_id,
        p_tarih: data.tarih,
        p_gozlem: data.gozlem
      };
```

Yeni:
```javascript
    case 'kizginlik_kaydet':
      return {
        p_hayvan_id: data.hayvan_id,
        p_tarih:     data.tarih,
        p_belirti:   data.belirti || null,
        p_notlar:    data.notlar  || null
      };
```

Not: `RPC_TABLES` map'inde `kizginlik_kaydet: ['kizginlik_log','gorev_log']` zaten mevcut (`api.js:208`) — dokunma.

### Step 5 — BUG-5: Kızgınlık geçmişi üreme sekmesinde

Önce `openDet`'in üreme sekmesi için hangi fonksiyonu çağırdığını bul (ui.js'de `_detUremeHtml` çağrısını ara). Kızgınlık log'larını `_detUremeHtml`'e aktar ve fonksiyon içinde listele.

Bu adım kod okunarak detaylı halledilecek. `_detUremeHtml` şu anda `tohs` (tohumlama listesi) alıyor, `kizginlik_log` verisi de `idbGetAll('kizginlik_log')` ile çekilerek fonksiyona aktarılabilir. Ancak `_detUremeHtml` async olmadığı için veri önceden hazırlanmalı.

Mevcut çağrı `_detUremeHtml(a, tohs)` şeklinde. Bu çağrının yapıldığı yeri bulup, kızgınlık log'larını filtreleyip aktar.

Kızgınlık listesi UI'ı gebelik bilgisi kadar önemli olmasa da tarihçe olarak listelenebilir. İmplementasyon sırasında en temiz yaklaşım belirlenecek.

### Step 6 — Syntax check

```bash
cd /root/egesut-erp1
node --check js/api.js js/ui.js
```

### Step 7 — Commit

```bash
git add js/api.js js/ui.js
git commit -m "fix: ureme modulu — BUG-1/2/4/5 duzeltmeleri"
git push origin fix/ureme-modulu-bakim
```

---

## Validation and Acceptance

Her bug için ayrı doğrulama senaryosu:

**BUG-1 doğrulaması:** Kızgınlık kaydı yap. Network sekmesinde isteği incele — RPC başarılı olmalı. IDB'de `kizginlik_log` tablosunda kayıt var mı kontrol et (Application > IndexedDB).

**BUG-2 doğrulaması:** Bir tarayıcıda kızgınlık kaydı yap. Başka bir tarayıcı/tarayıcı tab'ında aynı hayvan detayını aç — kızgınlık 5 sn içinde görünmeli (Realtime).

**BUG-3:** 12 aydan küçük bir dişi hayvana kızgınlık kaydı yapmayı dene. Backend red döndüğünde toast mesajı gelmeli. (Bug değil — kapatılacak.)

**BUG-4 doğrulaması:** Tarayıcıyı offline moda al (Network sekmesi > Offline). Kızgınlık kaydet. Queue'da bekliyor gösterilmeli. Online'a dön — 5 sn içinde `kizginlik_log` IDB'de görünmeli.

**BUG-5 doğrulaması:** Dişi bir hayvan detayını aç, Üreme sekmesine tıkla. Kızgınlık kayıtları varsa listelenmeli.

---

## Idempotence and Recovery

Değişiklikler sadece JS dosyalarında. Yanlış bir değişiklik olursa:
```bash
git checkout -- js/api.js js/ui.js
```
Sonra adımlar tekrarlanabilir.

---

## Artifacts and Notes

Supabase proje ref: `zqnexqbdfvbhlxzelzju`
