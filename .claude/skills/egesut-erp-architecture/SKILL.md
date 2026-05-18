---
name: egesut-erp-architecture
description: EgeSüt ERP mimari felsefesi + zorunlu pre-check kuralları. Her oturumda yüklenir.
---

# EgeSüt ERP — Mimari Felsefe

> **Frontend asla iş mantığı yapmaz.** Sadece veri toplar ve görüntüler.
> Tüm iş mantığı, validasyon, hesaplama, state machine'ler PostgreSQL'de.
> Frontend ERP sistemlerinde **güvenilmezdir** — tarayıcıdaki JS kullanıcı tarafından değiştirilebilir.

## Neden Frontend Güvenilmez

| Sorun | Etki |
|-------|------|
| DevTools ile JS override edilebilir | İş mantığı bypass edilir |
| İki cihazda farklı versiyon | Tutarsız state → veri kaybı |
| Offline çalışırken güncel olmayabilir | Eski veriyle karar verilir |
| Race condition | Çift kayıt, yanlış state geçişi |

PostgreSQL'de bu sorunlar yoktur: ACID, RLS, trigger, CHECK constraint.

## Katman Sorumlulukları

```
UI Layer (index.html + js/*.js)
  • Form input toplama
  • Veri görüntüleme (render)
  • Kullanıcı etkileşimi → RPC çağrısı
  ✗ Hesap yapmaz
  ✗ State machine işletmez
  ✗ Validasyon yapmaz (sadece UX guard)

DB Layer (PostgreSQL / Supabase)
  • Tüm iş mantığı (RPC)
  • Validasyon (CHECK, trigger)
  • Hesaplama (view, RPC)
  • State machine (trigger, RPC)
  • Yetkilendirme (RLS)
  • Ledger (immutable)
```

## Operasyonel Kurallar

### Kural 1 — Sadece RPC ile yaz
```js
// YANLIŞ ❌
await db.from('hayvanlar').update({...}).eq('id', id);
await write('hayvanlar', {...}, 'PATCH', `id=eq.${id}`);

// DOĞRU ✅
await rpc('hayvan_guncelle', { p_id: id, p_grup: '...' });
```

### Kural 2 — Hesap backend'de
```js
// YANLIŞ ❌
const guncel = baslangic_miktar - moves.reduce(...);

// DOĞRU ✅
const { guncel_stok, stok_durum } = row; // stok_tuketim_view'dan
```

### Kural 3 — State machine backend'de
Frontend asla `tohumlama_durumu`, `tamamlandi`, `iptal` gibi state alanlarını direkt yazmaz.

### Kural 4 — View'lar hazır veri döndürür
| View | Hesapladığı |
|------|-------------|
| `stok_tuketim_view` | guncel_stok, stok_durum |
| `gebelik_ozet_view` | gebelik istatistikleri |
| `tohumlanabilir_hayvanlar` | tohumlanabilir liste |

---

## ZORUNLU PRE-CHECK KURALLARI

**RPC yazmadan ÖNCE mutlaka yap:**

### 1. Tablo şemasını oku
```sql
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'HEDEF_TABLO'
ORDER BY ordinal_position;
```
Olmayan kolon referans etme! (kurum, tip, grup_adi gibi hatalar bundan çıktı)

### 2. ID Tipleri Haritası (EZBERle!)

| Tablo | id tipi | Örnek |
|-------|---------|-------|
| hayvanlar | **text** | 'f454bdd3-...' |
| stok | **text** | 'e45e1a66-...' |
| hekimler | **text** | 'H1778958770' |
| tohumlama | **text** | uuid string |
| gorev_log | **uuid** | uuid native |
| stok_hareket | **uuid** | uuid native |
| padoklar | **uuid** | uuid native |
| vaccines | **uuid** | uuid native |
| grup_padok_eslem | **uuid** | uuid native |
| islem_log | **uuid** | uuid native |

**KURAL:** 
- uuid kolonuna INSERT ederken `gen_random_uuid()` kullan (`::text` YAPMA!)
- text parametre ile uuid kolon karşılaştırırken `WHERE id = p_id::uuid` cast kullan
- PostgREST aynı isimde farklı parametreli fonksiyon görürse PGRST203 hatası verir — eski versiyonu `DROP FUNCTION IF EXISTS` ile sil

### 3. Stok Math (KRİTİK!)

```
stok_tuketim_view formülü:
  guncel_stok = baslangic_miktar - SUM(stok_hareket.miktar WHERE NOT iptal)

POZİTİF hareket = stok AZALIR (kullanım, görev düşümü)
NEGATİF hareket = stok ARTAR (ekleme, iade)

Stok eklemek için: INSERT stok_hareket ... miktar = -p_miktar
Stok düşmek için: INSERT stok_hareket ... miktar = +p_miktar
```

### 4. Mevcut RPC pattern'ini oku
Aynı tabloya yazan başka RPC varsa, o pattern'i takip et. Özellikle:
- islem_log snapshot formatı: `{olusturulan: [], guncellenen: [], silinen: []}`
- ref_id ve ref_tablo kolonları dolu olmalı
- GRANT EXECUTE ... TO anon, authenticated unutma

### 5. Deploy Süreci
- Migration dosyası repoda olması = canlıda çalışıyor DEĞİL
- `supabase_migrate` MCP aracı veya `supabase db push` ile ayrıca deploy et
- GitHub Pages sadece JS'i günceller, SQL'i Supabase'e göndermez

---

### 6. Referans Migration Seçimi (KRİTİK!)

**`*_revize.sql`, `*_fix.sql`, ara migration'lar YANLIŞ referanstır — kırık versiyon olabilir.**

| Doğru | Yanlış |
|-------|--------|
| `supabase/migrations/99999999999999_ground_truth.sql` | `20260513000006_laktasyon_kuru_kontrol_revize.sql` |
| `.claude/rpc-reference.md` | Herhangi ara `*_revize.sql`, `*_fix.sql` |

```bash
# Her SQL görevine başlamadan önce oku:
file_read("supabase/migrations/99999999999999_ground_truth.sql")
file_read(".claude/rpc-reference.md")
```

Neden: Goose revize migration'ı referans alınca 30 hayvan için yanlış görev açtı, tüm veri bozuldu (2026-05-18).

### 7. DB Değişikliği — Approval Gate (ZORUNLU)

Herhangi bir `CREATE/ALTER/UPDATE/INSERT/DELETE` yazmadan önce orchestrator'a sor:

```
agent_send(
  to="{from_agent}",
  message="ONAY GEREKLİ: [ne yapılacak]\nEtkilenecek tablolar: [...]\nRisk: [veri kaybı var mı?]\nSQL taslağı:\n[yazmak istediğin SQL]",
  message_type="approval_req"
)
# → "Onaylıyorum" mesajını BEKLE. Gelene kadar hiçbir DB yazma yapma.
```

**İstisna:** Sadece SELECT / okuma — onay gerekmez.

---

## Referans Dosyaları (task başında oku)

| Dosya | İçerik |
|-------|--------|
| `.claude/rpc-reference.md` | Tüm mevcut RPC imzaları |
| `.claude/domain-rules.md` | İş kuralları (yaş, state machine, ledger) |
| `supabase/migrations/99999999999999_ground_truth.sql` | Canonical DB state |
| `docs/architecture-violations.md` | Çözülen + kalan ihlaller |

## Acil Durum — Yeni Özellik Eklerken

1. Önce DB'de RPC/trigger/view var mı kontrol et
2. `write()` kullanma — `rpc()` kullan
3. View varsa frontend'de hesaplama yapma
4. State machine'i frontend'de işletme
5. Tarih/yaş/gün hesabını frontend'de yapma — DB yapar
6. SQL yazmadan önce ground_truth.sql oku, onay al
