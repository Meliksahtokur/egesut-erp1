# Task-dev-006 Tamamlandı — Security Hardening

**Branch:** `gwen/dev-006`
**Commit:** `ffe854a`

---

## Yapılan Düzeltmeler

### 1. SECURITY DEFINER + search_path ✅
```sql
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = public, pg_temp;
```
**Sorun:** Schema hijacking riski  
**Çözüm:** Explicit search_path eklendi

### 2. GRANT EXECUTE — anon kaldırıldı ✅
```sql
GRANT EXECUTE ON FUNCTION public.drug_product_ekle(...)
  TO authenticated;  -- anon kaldırıldı
```
**Sorun:** Unauthenticated users RPC'yi çağırabiliyordu  
**Çözüm:** Sadece authenticated users

### 3. unique_violation exception handler ✅
```sql
BEGIN
  INSERT INTO drug_products ...
  RETURNING id INTO v_id;
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'Bu ilaç zaten kayıtlı: %', p_brand_name;
END;
```
**Sorun:** TOCTOU race condition — EXISTS check + INSERT arasında window  
**Çözüm:** Manual check kaldırıldı, unique constraint + exception handler

### 4. stok validation ✅
```sql
IF p_stok_id IS NOT NULL THEN
  IF NOT EXISTS (SELECT 1 FROM stok WHERE id = p_stok_id) THEN
    RAISE EXCEPTION 'Stok kaydı bulunamadı: %', p_stok_id;
  END IF;
  UPDATE stok SET drug_product_id = v_id WHERE id = p_stok_id;
END IF;
```
**Sorun:** Geçersiz stok_id sessizce ignore ediliyordu  
**Çözüm:** Existence check eklendi

### 5. Frontend error handling ✅
```javascript
const { data: dp, error: dpErr } = await db.rpc('drug_product_ekle', {...});
if (dpErr) throw new Error(dpErr.message);  // RPC error mesajı göster
if (!dp) throw new Error('İlaç kaydı oluşturulamadı');
```
**Sorun:** Generic error mesajı  
**Çözüm:** RPC exception mesajı kullanıcıya iletiliyor

---

## Kabul Kriterleri

- [x] `SECURITY DEFINER SET search_path = public, pg_temp` var
- [x] `GRANT EXECUTE TO authenticated` (anon yok)
- [x] INSERT unique_violation exception handler var
- [x] stok IF NOT EXISTS check var
- [x] `node --check` temiz
- [x] Branch: `gwen/dev-006` — main'e dokunulmadı

---

## Code Review Düzeltmeleri

| Review Issue | Durum |
|--------------|-------|
| SECURITY DEFINER without SEARCH_PATH | ✅ Düzeltildi |
| GRANT EXECUTE to `anon` | ✅ Düzeltildi |
| Duplikat check TOCTOU | ✅ Exception handler |
| Missing stok validation | ✅ Düzeltildi |
| Frontend error handling | ✅ Düzeltildi |

---

## PR

https://github.com/Meliksahtokur/egesut-erp1/pull/new/gwen/dev-006

---

**Tarih:** 2026-04-01
**Durum:** ✅ Tamamlandı — Tüm security hardening düzeltmeleri yapıldı
