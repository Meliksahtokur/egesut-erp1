# API Katmanı Refactor — ui.js Ayrıştırma

**Tarih:** 2026-06-05  
**Durum:** Fikir — Brainstorm aşaması, implemente edilmedi  
**Öncelik:** Orta — Kritik bug değil, ama yeni özellik geliştirmeyi yavaşlatıyor  
**Tahmini efor:** 3-5 oturum (kademeli, break etmeden)  
**Edge migration GEREKMİYOR** — mevcut mimarinin disiplinle kullanılması yeterli

---

## Problem: "İç içe" hissinin gerçek kaynağı

### Şu anki durum

```
ui.js (~3000+ satır)
├── DOM manipulation          ← doğru yer
├── template rendering         ← doğru yer
├── supabase.rpc() çağrıları  ← YANLIŞ yer — api.js'de olmalı
├── supabase.from().select()  ← YANLIŞ yer
├── validation logic           ← YANLIŞ yer — forms.js veya RPC'de olmalı
├── state management (window.__*) ← YANLIŞ yer — ayrı module olmalı
└── pullTables() çağrıları    ← YANLIŞ yer

forms.js (~2000+ satır)
├── form rendering             ← doğru yer
├── input validation           ← doğru yer  
├── supabase.rpc() çağrıları  ← YANLIŞ yer — api.js'de olmalı
└── duplicate business logic   ← BUG-011, BUG-012 kaynağı

api.js (mevcut ama zayıf)
├── rpcOptimistic()           ← doğru soyutlama
├── pullTables()              ← doğru soyutlama
└── ??? (büyük ölçüde bypass ediliyor)
```

### Somut örnek — bugün bir RPC çağrısı nasıl yapılıyor:

```javascript
// ui.js içinde — gerçek örnek pattern
async function submitBirth(btn) {
  // ...
  const { data, error } = await supabase.rpc('dogum_kaydet', {
    p_anne_id: hayvanId,
    p_tarih: tarih,
    p_kupe: kupe,
    // ...
  });
  if (error) { showToast('Hata: ' + error.message); return; }
  await pullTables(['hayvanlar', 'dogum', 'gorev_log', 'tohumlama']);
  renderSafe();
}
```

Bu pattern her RPC çağrısında tekrarlanıyor: error handling, pullTables, renderSafe. 40+ yerde.

---

## Hedef Mimari

```
Katman             Sorumluluk                        Dosya
──────────────────────────────────────────────────────────
Sunum              DOM + event handlers               ui.js (sadeleştirilmiş)
Form               Input validation + form state      forms.js (sadeleştirilmiş)
API                RPC wrapper + error handling        api.js (güçlendirilmiş)
State              window.__* yerine merkezi store    state.js (yeni, basit)
DB Logic           Business rules + transactions       PostgreSQL RPC (değişmez)
Stats/Reports      Aggregation + harici entegrasyon   Edge Functions (mevcut + genişletilebilir)
```

---

## api.js Nasıl Güçlendirilmeli?

### Şu an (tahminen):

```javascript
// api.js
async function rpcOptimistic(name, params, opts) { ... }
async function pullTables(tableList) { ... }
```

### Hedef:

```javascript
// api.js — her domain için typed wrapper

const Api = {
  hayvan: {
    async ekle(params)       { return rpc('hayvan_ekle', params) },
    async guncelle(params)   { return rpc('hayvan_guncelle', params) },
    async cikis(params)      { return rpc('hayvan_cikis', params) },
  },
  
  tohumlama: {
    async kaydet(params)     { return rpc('tohumlama_kaydet', params) },
    async tekrar(params)     { return rpc('tohumlama_tekrar_kaydet', params) },
    async sonucGebe(params)  { return rpc('tohumlama_sonuc_gebe', params) },
    async sonucBos(params)   { return rpc('tohumlama_sonuc_bos', params) },
  },
  
  dogum: {
    async kaydet(params)     { return rpc('dogum_kaydet', params) },
  },
  
  gorev: {
    async tamamla(id)        { return rpc('gorev_tamamla', { p_gorev_id: id }) },
    async iptal(id)          { return rpc('gorev_iptal', { p_gorev_id: id }) },
  }
};

// Tek merkezi error handler:
async function rpc(name, params) {
  try {
    const { data, error } = await supabase.rpc(name, params);
    if (error) throw error;
    return { ok: true, data };
  } catch (e) {
    console.error(`RPC ${name} failed:`, e);
    showToast('Hata: ' + (e.message || 'Bilinmeyen hata'));
    return { ok: false, error: e };
  }
}
```

### Faydası:

- `ui.js` içinde `supabase.rpc(...)` yok, sadece `await Api.dogum.kaydet(...)`
- Error handling tek yerde
- Gelecekte auth header, retry logic, offline queue entegrasyonu tek yerden
- TypeScript'e geçiş yapılmak istenirse tek dosya migrate edilir

---

## BUG-011 / BUG-012 ile Bağlantı

Duplikat fonksiyonlar (`ayarlarHekimEkle` 2x, `submitInsem` vs `openInsemSafe` vs `_openInsemIntercept`) bu refactor'ın doğal yan ürünü olarak temizlenebilir.

### Duplikat giriş noktaları — neden oluştu?

Büyük ihtimalle: `ui.js` zaten varken `forms.js`'e de "acil" bir özellik eklendi, iki yerde bitti.

### Çözüm stratejisi:

```
Her domain için tek giriş noktası kuralı:
- Tohumlama başlatma → SADECE openInsemSafe()
- Doğum kaydı → SADECE submitBirth()
- Ayarlar hekim ekleme → SADECE forms.js içinde

ui.js'deki duplikat versiyonlar silinir, forms.js versiyonu korunur (veya tersi — hangisi doğru ise)
```

---

## state.js — window.__ Karmaşasını Temizleme

Şu an global state şöyle çalışıyor:

```javascript
window.__hayvanlar = [];
window.__gorevler = [];
window.__ileriGebeListesi = [];  // BUG-051: bu doğum sonrası temizlenmiyordu
window.__stok = [];
// ... onlarca tane
```

Bu pattern'in sorunları:
1. Nerede set edildiği belli değil
2. Stale state bug'ları (BUG-051 gibi)
3. DevTools'ta debug zor

### Minimal state module (framework gerekmez):

```javascript
// state.js
const State = (() => {
  const _store = {};
  const _listeners = {};
  
  return {
    set(key, value) {
      _store[key] = value;
      (_listeners[key] || []).forEach(fn => fn(value));
    },
    get(key) { return _store[key]; },
    on(key, fn) {
      _listeners[key] = _listeners[key] || [];
      _listeners[key].push(fn);
    },
    clear(key) { delete _store[key]; }
  };
})();

// Kullanım:
State.set('hayvanlar', data);
State.get('hayvanlar');
State.on('hayvanlar', () => renderHayvanList()); // reactive
```

Büyük bang değil — `window.__hayvanlar` → `State.get('hayvanlar')` dönüşümü kademeli yapılabilir.

---

## Edge Functions — Ne Zaman Mantıklı?

Bu refactor Edge migration değildir. Ama Edge'i şu senaryolarda genişletmek mantıklı:

| Senaryo | Edge mi? | Neden |
|---|---|---|
| `dogum_kaydet` gibi CRUD + multi-insert | ❌ PostgreSQL | ACID gerekli |
| `stat-hesapla` gibi aggregation | ✅ Edge (mevcut) | Transaction gerekmez, TypeScript avantajı |
| PDF/Excel rapor export | ✅ Edge | Node kütüphaneleri, streaming |
| SMS/e-posta bildirim | ✅ Edge | External API çağrısı |
| Harici entegrasyon (e-devlet, TÜRKVET) | ✅ Edge | Webhook receiver |
| Offline sync çözümü | ❌ IndexedDB + RPC | Edge stateless, çözemez |

---

## Uygulama Sırası (Önerim — kademeli, break etmeden)

### Faz 1 — api.js güçlendirme (1 oturum)
- `rpc()` wrapper function
- En çok çağrılan 10 RPC için typed wrapper
- ui.js'deki bu 10'unu migrate et

### Faz 2 — BUG-011 duplikat cleanup (1 oturum)
- `ayarlarHekimEkle`, `ayarlarSpermaEkle`, `bildirimAc` duplikatlarını temizle
- Tek canonical versiyon belirle, diğerini sil

### Faz 3 — submitInsem / submitBirth giriş noktaları (1 oturum)
- `openInsemSafe` tek entry point, diğerleri onu çağırır veya silinir
- `submitBirth` tek entry point

### Faz 4 — state.js (1-2 oturum)
- Module yaz
- `window.__*` → `State.*` kademeli geçiş (hayvanlar, gorevler önce)

### Faz 5 — forms.js sadeleştirme (2 oturum)
- Sadece form rendering + input validation kalır
- RPC çağrıları api.js'e taşınır

---

## Açık Sorular

1. **Script yükleme sırası:** `state.js` ve `api.js` diğerlerinden önce yüklenmeli. `index.html`'deki script sırası buna izin veriyor mu?
2. **Offline queue (dataTrafficTekGonder):** Şu an direkt supabase çağrısı yapıyor. api.js'e taşınınca offline logic nasıl etkilenir?
3. **rpcOptimistic:** Mevcut optimistic update mekanizması api.js'e entegre edilecek mi yoksa ayrı mı tutulacak?

---

## Dikkat: Bu Refactor'da Ne Yapılmaz

- `forms.js` veya `ui.js` tamamen yeniden yazılmaz — kademeli
- Edge Functions'a business logic taşınmaz
- Framework (React/Vue/Svelte) eklenmez
- Test suite eklenmez (şimdilik)
- TypeScript'e geçiş yapılmaz (şimdilik)
