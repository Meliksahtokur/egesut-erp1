# RPC Quick Reference Card

**Status:** ✅ MANDATORY - All writes must go through RPC  
**Return Type:** All RPCs return `jsonb { ok: boolean, ... }`  
**Security:** All RPCs use `SECURITY DEFINER`

---

## 🚨 Critical Rules

```
❌ DIREKT YAZILMAZ → supabase.from('X').insert/update/delete YASAK
✅ SADECE RPC KULLAN → rpcOptimistic(name, params)
```

---

## 🔥 Most Common RPCs

### Üreme (Reproduction)

| RPC | Ne Yapar |
|-----|----------|
| `tohumlama_kaydet(p_hayvan_id, p_tarih, p_sperma)` | Yeni tohumlama kaydeder |
| `tohumlama_sonuc_gebe(p_tohumlama_id)` | "Gebe" işaretler |
| `tohumlama_sonuc_bos(p_tohumlama_id)` | "Boş" işaretler |
| `dogum_kaydet(p_anne_id, p_tarih, p_kupe)` | Doğum + buzağı + 14 görev |
| `abort_kaydet(p_tohumlama_id)` | Abort kaydeder |

### Hayvan (Animal)

| RPC | Ne Yapar |
|-----|----------|
| `hayvan_ekle(p_kupe_no, p_devlet_kupe, p_irk, ...)` | Yeni hayvan ekler |
| `hayvan_guncelle(p_id, ...)` | Hayvan bilgilerini günceller |
| `hayvan_not_ekle(p_hayvan_id, p_not)` | Not ekler |

### Vaka (Case)

| RPC | Ne Yapar |
|-----|----------|
| `create_case(p_animal_id, p_disease_id)` | Yeni vaka oluşturur |
| `add_treatment_day(p_case_id)` | Tedavi günü ekler |
| `add_drug_administration(p_day_id, p_drug_id, ...)` | İlaç uygulaması kaydeder |
| `close_case(p_case_id)` | Vakayı kapatır |

---

## 📞 RPC Çağrı Pattern

```javascript
// ✅ DOĞRU
rpcOptimistic('tohumlama_kaydet', {
  p_hayvan_id: hayvanId,
  p_tarih: tarih,
  p_sperma: sperma
}, {
  success: 'Tohumlama kaydedildi',
  error: 'Hata: '
});

// ❌ YANLIŞ - Direkt REST
supabase.from('tohumlama').insert({...})
```

---

## 🔍 RPC Bypass Tespiti

Grep patterns (gwen-tester kullanır):

```bash
# ⚠️ BULUNURSA → BLOKE
supabase.from('tohumlama').insert
supabase.from('tohumlama').update
supabase.from('dogum').insert
supabase.from('hayvanlar').insert
write('tohumlama', ...)
```

---

## 📋 RPC Invalidation Map

`api.js` içinde `RPC_TABLES`:

```javascript
const RPC_TABLES = {
  'tohumlama_kaydet': ['tohumlama', 'islem_log', 'gorev_log'],
  'dogum_kaydet': ['dogum', 'hayvanlar', 'gorev_log'],
  'hayvan_ekle': ['hayvanlar', 'islem_log'],
  // ...
};
```

RPC başarılı → `pullTables(RPC_TABLES[name])` → `renderSafe()`

---

## 🎯 Offline Queue RPC Map

`js/ui.js` içinde `RPC_MAP`:

```javascript
const RPC_MAP = {
  'tohumlama': { POST: 'tohumlama_kaydet', ... },
  'dogum': { POST: 'dogum_kaydet', ... },
  'hayvanlar': { POST: 'hayvan_ekle', PATCH: 'hayvan_guncelle' },
  // ...
};
```

---

## ❌ Direkt Yazılamaz (RPC Zorunlu)

```
tohumlama     → tohumlama_kaydet
dogum         → dogum_kaydet
hayvanlar     → hayvan_ekle, hayvan_guncelle
islem_log     → RPC'ler otomatik yazar
gorev_log     → RPC'ler otomatik oluşturur
```

---

## 📚 Detaylı Referans

Tam imzalar: `.claude/rpc-reference.md`

Agent rehberi: `.agents/qwen/skills/rpc-contract/SKILL.md`

---

## ⚡ Hata Durumları

| Hata | Çözüm |
|------|-------|
| RPC adı yanlış | `.claude/rpc-reference.md` kontrol et |
| Parametre eksik | RPC imzasını oku (p_ prefix) |
| 42883 hatası | RPC DB'de yok → migration kontrol et |
| RPC bypass | gwen-tester BLOKE eder |

---

**⚠️ Unutma:** Sadece RPC ile yazılır. Direkt REST = Kural İhlali.
