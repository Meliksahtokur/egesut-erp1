# Padok Transfer Araştırması

**Tarih:** 2026-05-21  
**Durum:** Araştırma tamamlandı, implementasyon bekliyor

---

## Mevcut Durum

| Özellik | Durum |
|---|---|
| Tekli transfer | ✅ `padok_degistir(hayvan_id, yeni_padok_id)` RPC |
| Toplu transfer | ✅ `padok_degistir_toplu(hayvan_ids[], yeni_padok_id)` RPC + frontend UI |
| Otomatik görev | ✅ Buzağı sütten kesme + laktasyon kuru kontrol sonrası |
| MCP/Tool erişimi | ❌ Henüz eklenmemiş |

## Frontend Flow (Toplu Transfer)

Padok detay aç → checkbox (multi-select) → "Toplu Taşı" → hedef padok seçici modal → `padokTransferOnayla()`

Response: `res.basarili`, `res.basarisiz`, `res.hatalar`

## Kod Lokasyonları

- `js/ui.js` satır ~2650-2750 — transfer UI fonksiyonları
- `supabase/migrations/99999999999999_ground_truth.sql` — `padok_degistir`, `padok_degistir_toplu` RPC'leri
- `.claude/domain-rules.md` — grup-padok mapping kuralları

## Eksikler / Yapılabilecekler

1. **Filtre-then-bulk:** "Bu padoktaki tüm gebeleri taşı" gibi kriter bazlı otomatik seçim yok
2. **Cross-padok:** Birden fazla padoktan hayvan seçip farklı padoklara dağıtma yok
3. **MCP tool:** `padok_degistir_toplu` RPC'yi Supabase MCP tool olarak ekle → Claude/Goose direkt çağırabilir
