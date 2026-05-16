# EgeSüt ERP — Mimari İhlal Raporu

> **Tarih:** 2026-05-16
> **Kapsam:** "Frontend asla iş mantığı yapmaz" prensibine aykırı kodlar
> **Kaynaks:** `egesut-erp-architecture` skill'inden otomatik türetilmiştir
> **Son Guncelleme:** 2026-05-16 — Faz 1/2/3 tamamlandi

## Ozet

| Kategori | Toplam | Cozuldu | Kalan | Risk |
|----------|--------|---------|-------|------|
| Grup A — RPC Bypass (`write()` ile direkt PATCH) | 6 | 6 | 0 | ✅ Kapatildi |
| Grup B — Direkt REST (`db.from().insert/update/delete`) | 10+ | 9 | 1-2 | 🟡 Az kaldi |
| Grup C — Frontend hesaplama (DB view'i bypass) | 8+ | 6 | 2 | 🟡 Az kaldi |

---

## Grup A — RPC Bypass

Frontend `write()` fonksiyonunu kullanarak REST PATCH yapıyor.
`write()` offline queue'ya yazıp REST'e gönderir, RPC'yi bypass eder.
Online'ken bu işlemler RPC'siz çalışır → state machine bypass, validasyon atlanır.

### A1 — Sütten Kesme Tarihi ✅ COZULDU (Faz 1)

**Fix:** `buzagi_sutten_kesme_onayla` RPC yazildi. Frontend `rpc()` kullaniyor.
**Commit:** 2bf381c (impl) + 76add8d (review fix)

### A2 — Tohumlanabilir Onay ✅ COZULDU (Faz 1)

**Fix:** `hayvan_tohumlanabilir_onayla` RPC yazildi. Yas >= 365 gun kontrolu, cinsiyet/kisir validasyonu DB'de.
**Commit:** 2bf381c (impl) + 76add8d (review fix — M1 yas check eklendi)

### A3 — Tohumlama Erteleme ✅ COZULDU (Faz 1)

**Fix:** `hayvan_tohumlama_ertele` RPC yazildi. Tarih hesabi DB'de `(p_ay || ' months')::interval` ile.
**Commit:** 2bf381c (impl) + 76add8d (review fix — M2 interval duzeltildi)

### A4 — Görev Tamamlama ✅ COZULDU (Faz 1)

**Fix:** `gorev_tamamla` RPC yazildi. Tek RPC icinde: gorev_log UPDATE + stok_hareket INSERT + hayvanlar padok UPDATE. Iptal check eklendi.
**Commit:** 2bf381c (impl) + 76add8d (review fix — H2 iptal check eklendi)

### A5 — Stok Ekleme/Güncelleme ✅ COZULDU (Faz 1)

**Fix:** `stok_ekle` ve `stok_ekleme` RPC'leri yazildi. Ledger immutability korunuyor: stok_ekleme negatif hareket INSERT yapar (`-p_miktar`).
**Commit:** 2bf381c (impl) + 76add8d (review fix — C2 double-subtract, C3 negatif miktar)

### A6 — Tohumlama Direkt INSERT ✅ COZULDU (Faz 1)

**Fix:** `gebelik_kaydet_manual` RPC yazildi. `deneme_no` otomatik hesaplaniyor (MAX+1). Frontend `rpc()` kullaniyor.
**Commit:** 2bf381c (impl) + 76add8d (review fix — C1 iptal kolonu, M3 deneme_no)

---

## Grup B — Direkt REST (`db.from()`)

Frontend doğrudan Supabase REST API'ye yazıyor. Bunların çoğu admin/yönetim arayüzü işlemleri.

### B1 — Stok İşlemleri ✅ COZULDU (Faz 3)

**Fix:** `stok_guncelle`, `stok_arsivle` RPC'leri yazildi. Frontend `rpc()` kullaniyor.
**Commit:** 1eddb2b (impl) + 76add8d (review fix — parametre isimleri duzeltildi)

### B2 — Admin CRUD ✅ COZULDU (Faz 3)

**Fix:** 9 RPC yazildi: `vaccine_rapel_guncelle`, `hekim_ekle`, `hekim_guncelle`, `padok_ekle`, `padok_guncelle`, `padok_sil`, `grup_padok_eslem_toggle`. Tumu `islem_log` snapshot + audit ile.
**Commit:** 1eddb2b (impl) + 76add8d (review fix — kolon isimleri, tip/kapasite, id tipi)

**Dogrulama:** `ui.js`'te `db.from()` ile yazma (insert/update/delete) calisi **kalmadi**. Kalan 4 `db.from()` cagrisi hep SELECT (okuma) — kabul edilebilir.

---

## Grup C — Frontend Hesaplama

DB'de view/RPC ile yapılan hesaplamalar frontend'de tekrar ediliyor.

### C1 — Stok Net Hesaplama (6 Kopya!) ✅ COZULDU (Faz 2)

**Fix:** 6 lokasyondaki `moves.filter().reduce()` stok hesabi kaldirildi. Frontend artik `stok_tuketim_view`'dan `s.guncel_stok` / `s.stok_durum` kullaniyor. FETCHERS'ta `stok` → `stok_tuketim_view` cevirildi.
**Fallback:** `+(s.guncel_stok ?? s.baslangic_miktar ?? 0)` — view'dan veri gelmezse guvenli.
**Commit:** a9ba636

### C2 — Tarih Hesaplamaları 🟡 KISMI

| Satir | Hesaplama | Durum |
|-------|-----------|-------|
| `forms.js:474` | `dFwd(... ay * 30)` — erteleme tarihi | ✅ COZULDU — `hayvan_tohumlama_ertele` RPC interval kullaniyor |
| `forms.js:886` | `Math.floor((Date.now()-new Date(t.tarih))/86400000)` — gun farki | ⚠️ KALDI — render amacli, dusuk risk |
| `ui.js:2000,2004` | `Math.round(gebe.length/aktif.length*100)` — yuzde | ⚠️ KALDI — raporlama, dusuk risk |

### C3 — Dashboard Istatistikleri ⚠️ KALDI

`ui.js:2000-2042` dashboard istatistikleri (gebe/bos orani, kritik stok sayisi) hala frontend'de hesaplaniyor. Stok durumu artik view'dan geliyor ama gebelik oranlari hala frontend hesabi. `gebelik_ozet_view` FETCHERS'a eklendi (Faz 2) — kullanimi genisletilebilir.
**Risk:** Dusuk — sadece goruntuleme, veri degistirmiyor.

---

## Remediation Plan — TAMAMLANDI

| Asama | Durum | Commitler |
|-------|-------|-----------|
| Faz 1 — Grup A (RPC Bypass) | ✅ 6/6 cozuldu | 2bf381c + 76add8d |
| Faz 2 — Grup C1 (Stok hesaplama) | ✅ 6/6 lokasyon temizlendi | a9ba636 |
| Faz 3 — Grup B (Admin CRUD) | ✅ 9 RPC yazildi, tum db.from() yazma kaldirildi | 1eddb2b + 76add8d |

### Kalan (dusuk oncelik, scope disinda birakildi)

| # | Ihlal | Risk | Neden kaldi |
|---|-------|------|-------------|
| C2-b | `forms.js:886` gun farki hesabi | LOW | Sadece render, veri degistirmiyor |
| C2-c | `ui.js:2000` gebelik yuzde hesabi | LOW | Sadece istatistik gosterim |
| C3 | Dashboard istatistikleri frontend'de | LOW | View'a tasima opsiyonel iyilestirme |

---

## Ek: Felsefe Kısa Referansı

```
Frontend yapar →                         Backend yapar →
─────────────────                         ─────────────────
Form toplama (input)                      Validasyon (CHECK, trigger)
Veri gösterme (render)                    İş mantığı (RPC)
RPC çağırma                               State machine (trigger)
Kullanıcı bildirimi (toast)               Hesaplama (view, RPC)
UX guard (boş alan uyarısı)               Yetkilendirme (RLS)
```

```js
// DOĞRU
const { data } = await rpc('tohumlama_kaydet', { p_hayvan_id, p_tarih, p_sperma });

// YANLIŞ
await write('tohumlama', { hayvan_id, tarih, sperma });
await db.from('tohumlama').insert({ hayvan_id, tarih, sperma });
```
