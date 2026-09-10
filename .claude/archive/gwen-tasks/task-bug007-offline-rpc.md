## Resolution

RPC_MAP exists in ui.js:2951-2978. dataTrafficTekGonder routes through rpc() wrapper, not direct REST. All table→RPC mappings implemented. node --check js/ui.js passes.

**Status:** done
**resolved_date:** 2026-05-02

---

# Task: BUG-007 — Offline Kuyruk RPC'ye Çevir

**Önem:** Yüksek  
**Branch:** `feature/gwen-bug007-fix`  
**Dosya:** `js/ui.js` (satır ~2851, 2855)  
**Kaynak:** `.claude/knowledge/bugs.md`

---

## Sorun (BUG-007)

`dataTrafficTekGonder()` fonksiyonu offline kuyruktaki işlemleri gönderirken direkt REST bypass yapıyor:

```javascript
// ❌ ŞU ANKİ KOD (satır 2844-2860)
async function dataTrafficTekGonder(qid){
  const q=await getQueue();
  const op=q.find(o=>o._qid===qid); if(!op) return;
  try {
    if(op.method==='POST'){
      const clean=op.data.map(item=>Object.fromEntries(...));
      for(const item of clean) await db.from(op.table).insert([item]); // ❌ REST bypass
    } else if(op.method==='PATCH'){
      const clean=Object.fromEntries(...);
      const [col,val]=op.filter.split('=eq.');
      await db.from(op.table).update(clean).eq(col,val); // ❌ REST bypass
    }
    await removeFromQueue(qid);
    toast('✅ Kayıt gönderildi');
  } catch(e){ toast('❌ '+e.message,true); }
  ...
}
```

**Problem:**
- RLS policy bypass ediliyor
- Trigger'lar çalışmıyor
- Backend validasyon devre dışı
- Ledger prensibi (stok) ihlal ediliyor

---

## Çözüm

### 1. RPC Mapping Tablosu Oluştur

Her tablo için hangi RPC'yi kullanmalı:

| Tablo | POST RPC | PATCH RPC |
|-------|----------|-----------|
| `hayvanlar` | `hayvan_ekle` | `hayvan_guncelle` |
| `tohumlama` | `tohumlama_kaydet` | - |
| `dogum` | `dogum_kaydet` | - |
| `gorev_log` | - | `gorev_guncelle` |
| `stok_hareket` | `stok_hareket_ekle` | - |
| `kizginlik_log` | `kizginlik_kaydet` | - |
| `cases` | `create_case` | - |
| `drug_administrations` | `add_drug_administration` | `update_drug_administration` |

### 2. `dataTrafficTekGonder` Refactor

```javascript
async function dataTrafficTekGonder(qid){
  const q=await getQueue();
  const op=q.find(o=>o._qid===qid); if(!op) return;
  
  try {
    // RPC mapping
    const RPC_MAP = {
      hayvanlar: { POST: 'hayvan_ekle', PATCH: 'hayvan_guncelle' },
      tohumlama: { POST: 'tohumlama_kaydet' },
      dogum: { POST: 'dogum_kaydet' },
      gorev_log: { PATCH: 'gorev_guncelle' },
      stok_hareket: { POST: 'stok_hareket_ekle' },
      kizginlik_log: { POST: 'kizginlik_kaydet' },
      cases: { POST: 'create_case' },
      drug_administrations: { POST: 'add_drug_administration', PATCH: 'update_drug_administration' }
    };
    
    const rpcInfo = RPC_MAP[op.table];
    if(!rpcInfo) throw new Error(`Tablo ${op.table} için RPC tanımlı değil`);
    
    const rpcName = op.method === 'POST' ? rpcInfo.POST : rpcInfo.PATCH;
    if(!rpcName) throw new Error(`${op.method} için RPC tanımlı değil`);
    
    // RPC çağrısı
    const clean = op.method === 'POST' 
      ? op.data.map(item => Object.fromEntries(Object.entries(item).filter(([k,v]) => v !== null && v !== undefined && v !== '')))
      : Object.fromEntries(Object.entries(op.data[0]).filter(([k,v]) => v !== null && v !== undefined && v !== ''));
    
    // RPC parametrelerini hazırla (her RPC için farklı)
    const rpcParams = buildRpcParams(rpcName, clean, op);
    
    await rpc(rpcName, rpcParams);
    
    await removeFromQueue(qid);
    toast('✅ Kayıt gönderildi');
    
    // İlgili tabloları çek + render
    const tables = RPC_TABLES[rpcName] || [op.table];
    pullTables(tables).then(renderSafe).catch(console.warn);
    
  } catch(e) { 
    toast('❌ '+e.message, true); 
  }
  
  await dataTrafficYenile();
  updateSyncBar();
}

// RPC parametre builder
function buildRpcParams(rpcName, data, op) {
  switch(rpcName) {
    case 'hayvan_ekle':
      return {
        p_kupe_no: data.kupe_no,
        p_grup_id: data.grup_id,
        p_dogum_tarihi: data.dogum_tarihi,
        p_cinsiyet: data.cinsiyet,
        p_irk_id: data.irk_id
      };
    case 'hayvan_guncelle':
      // PATCH için: hangi alan güncellenecek?
      const [col, val] = op.filter.split('=eq.');
      return {
        p_id: data[col] || val,
        p_alan: Object.keys(data)[0],
        p_deger: Object.values(data)[0]
      };
    case 'tohumlama_kaydet':
      return {
        p_hayvan_id: data.hayvan_id,
        p_tarih: data.tarih,
        p_sperma_kodu: data.sperma_kodu,
        p_teknisyen: data.teknisyen
      };
    case 'dogum_kaydet':
      return {
        p_anne_id: data.anne_id,
        p_tarih: data.tarih,
        p_buzagi_cinsiyet: data.buzagi_cinsiyet,
        p_buzagi_kupe: data.buzagi_kupe
      };
    case 'stok_hareket_ekle':
      return {
        p_stok_id: data.stok_id,
        p_tur: data.tur,
        p_miktar: data.miktar,
        p_notlar: data.notlar
      };
    case 'kizginlik_kaydet':
      return {
        p_hayvan_id: data.hayvan_id,
        p_tarih: data.tarih,
        p_gozlem: data.gozlem
      };
    case 'create_case':
      return {
        p_hayvan_id: data.hayvan_id,
        p_tanis: data.tanis,
        p_tarih: data.tarih
      };
    case 'add_drug_administration':
      return {
        p_day_id: data.day_id,
        p_drug_product_id: data.drug_product_id,
        p_dose: data.dose,
        p_unit: data.unit,
        p_route: data.route,
        p_time: data.time
      };
    default:
      return data; // Fallback
  }
}
```

---

## Yapılacaklar Listesi

- [ ] `js/ui.js` içinde `dataTrafficTekGonder` fonksiyonunu bul
- [ ] RPC_MAP tablosu ekle
- [ ] `buildRpcParams` helper fonksiyonu ekle
- [ ] `dataTrafficTekGonder` içinde RPC çağrısı yap
- [ ] `rpc` ve `rpcOptimistic` fonksiyonlarının `api.js`'ten import edildiğini doğrula
- [ ] `node --check js/ui.js` syntax kontrolü
- [ ] Test: Offline modda kayıt ekle → online geç → gönder → DB'ye yazıldı mı?
- [ ] Commit: `DONE: dev — BUG-007: Offline kuyruk RPC'ye çevrildi`

---

## Riskler

1. **RPC parametreleri:** Her RPC farklı parametreler bekliyor — mapping doğru olmalı
2. **Offline queue data yapısı:** Queue'daki veri RPC parametrelerine dönüşebilir mi?
3. **Hata durumu:** RPC başarısız olursa queue'dan silinmemeli

---

## Test Senaryosu

1. Offline modda hayvan ekle
2. Offline modda tohumlama kaydet
3. Online geç
4. Data Traffic ekranından ↑ butonuna bas
5. Queue'dan silindi mi?
6. Supabase'de kayıt var mı? (RPC ile yazıldı mı?)
7. Trigger'lar çalıştı mı? (gorev_log, stok_hareket)
