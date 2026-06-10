# İdea: `hizli_uygulama` Genişletilmiş İmza (11 parametreli)

**Tarih:** 2026-06-10
**Kaynak:** BUG-064 spec yazımı sırasında üretildi, implementasyon sırasında **gerçek 6 parametreli yapıyla çakıştığı tespit edildi**
**Durum:** 📋 ARŞİV — İleride refactor adayı

---

## 1. Arka Plan

BUG-064 spec yazımı sırasında, `hizli_uygulama` RPC'sinin "ideal" genişletilmiş imzası tasarlandı. Bu imza:

- **Sistemdeki diğer RPC'lerle** (özellikle `gorev_tamamla` ile) daha tutarlı
- **Köken takibi** (uygulayan kişi, protokol bağlamı) için daha zengin
- **Audit trail** için daha detaylı (kullanıcı notu, padok hedef)

Faz 0 doğrulamasında **gerçek implementasyonun 6 parametreli olduğu** ve JS tarafının bu yapıya bağımlı olduğu tespit edildi. 11 parametreli imza **şu an** uygulanabilir değil.

## 2. Önerilen İmza (11 parametreli)

```sql
CREATE OR REPLACE FUNCTION public.hizli_uygulama(
  p_hayvan_id       text,            -- 1. Zorunlu — hayvan UUID
  p_stok_id         text,            -- 2. Zorunlu — stok UUID
  p_doz             numeric,         -- 3. Zorunlu — uygulama dozu
  p_birim           text,            -- 4. Zorunlu — ml/mg/kg
  p_uygulama_tipi   text,            -- 5. Zorunlu — HIZLI / GOREV / PROTOKOL
  p_uygulayan       text,            -- 6. Zorunlu — kullanıcı adı (auth.uid() veya display_name)
  p_protokol_id     text DEFAULT NULL, -- 7. Opsiyonel — bağlı protokol
  p_gun_no          integer DEFAULT NULL, -- 8. Opsiyonel — protokolün kaçıncı günü
  p_notlar          text DEFAULT NULL, -- 9. Opsiyonel — serbest not
  p_padok_hedef     text DEFAULT NULL, -- 10. Opsiyonel — görevli padok (padok taşıma için)
  p_kullanici_notu  text DEFAULT NULL  -- 11. Opsiyonel — audit için ek açıklama
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER AS $$
...
END;
$$;
```

### Return Type Tartışması

| Return Tipi | Avantaj | Dezavantaj |
|---|---|---|
| `uuid` (önerilen 11-param) | Sade, zincirleme çağrılarda temiz | Caller `res.ok`/`res.mesaj` alamaz |
| `jsonb` (mevcut 6-param) | `res.ok`, `res.mesaj`, `res.stok_kalan` zengin bilgi | 11 parametreyle aynı yapı kurulabilir |

**Karar:** 11 parametreli versiyonda da `jsonb` kullanılabilir — geriye dönük uyum korunur.

## 3. Mevcut 6-Parametreli Yapı (Referans)

```sql
CREATE OR REPLACE FUNCTION public.hizli_uygulama(
  p_hayvan_id text,
  p_stok_id   text,
  p_doz       numeric,
  p_birim     text,
  p_rota      text,    -- ← mevcut yapıda "rota" var
  p_notlar    text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
...
END;
$$;
```

### 3 JS Caller'ın Tam Listesi

| Dosya | Satır | Çağrı Şekli | `res.ok`/`res.mesaj` Bağımlılığı |
|---|---|---|---|
| `js/ui.js` | L951-953 | `_protokolUygulaKaydet` | ✅ Evet (L957-958) |
| `js/ui.js` | L1090-1093 | `_hayvanHizliUygulaKaydet` | ✅ Evet (L1095-1096) |
| `js/ui.js` | L3978-3980 | Görev tamamlama | ❌ Sadece `await` (ardından `gorev_tamamla` çağrısı var) |

## 4. Geçiş Planı (Refactor Adayı)

Eğer ileride bu imzaya geçmek istersek:

1. **Mevcut 6-parametreli RPC'yi wrapper'a çevir** (alias olarak kalır)
2. **Yeni 11-parametreli RPC'yi ana fonksiyon yap** — mevcut `uygulama_log` + `stok_hareket` + yeni eklenen `islem_log` audit
3. **JS tarafını 3 caller'da güncelle** — `p_rota` kaldır, `p_uygulama_tipi` + `p_uygulayan` ekle
4. **3-6 ay geçiş dönemi** — eski caller'lar hâlâ çalışır (warning log), yeniler tam 11-param
5. **Son temizlik** — wrapper'ı kaldır, eski caller'ları refactor et

## 5. Açık Sorular (Gelecekte Çözülecek)

Bu sorular **BUG-064 fix tamamlandıktan sonra** cevaplanacak:

1. **`p_uygulama_tipi` enum değerleri:** `'HIZLI' | 'GOREV' | 'PROTOKOL' | 'BILINMIYOR'` yeterli mi?
2. **`p_uygulayan`:** Display name mi yoksa user_id mi? Audit trail'de hangisi anlamlı?
3. **`p_padok_hedef`:** Sadece `gorev_tamamla` akışında mı set edilecek?
4. **Geri alma simetrisi:** `hizli_uygulama_geri_al` da aynı 11 parametreyi almalı mı, yoksa sadece `p_uygulama_id` yeterli mi?

## 6. İlişkili Dosyalar

- **Spec:** `docs/specs/2026-06-10-bug060-protokol-stok-gorev-uyumsuzluk.md` (Rev 7 §3.2 — bu imzayı içeriyordu, Rev 8'de gerçek 6-parametreli yapıya çevrilecek)
- **Plan:** `.claude/plans/2026-06-10-bug064-impl.md` (migration 6-parametreli yapıya göre revize edilecek)
- **Migration:** `supabase/migrations/20260610000001_bug064_etken_kod_vitamin_audit.sql` (yazıldı ama yanlış imza — yeniden yazılacak)

## 7. Neden Şimdi Uygulanmıyor?

- **JS tarafı 6 parametreye bağımlı** — 3 caller var, hepsi `p_rota` kullanıyor
- **`stok_hareket` kolon seti farklı** — `(stok_id, hayvan_id, miktar, hareket_tipi, uygulama_log_id, tarih)` değil, `(id, stok_id, tur, miktar, notlar, iptal)`
- **Refactor kapsamı büyük** — sadece BUG-064 değil, 3 RPC + 3 JS caller + migration
- **Riskli** — aktif kullanılan 3 akış var, kırma lüksümüz yok

**Doğru zaman:** BUG-064 kapandıktan sonra, ayrı bir refactor sprint'inde.
