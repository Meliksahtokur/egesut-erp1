# Padok Transfer UX — Sürü Dashboardı Entegrasyonu

**Tarih:** 2026-05-25  
**Durum:** Fikir — henüz planlanmadı  
**Motivasyon:** Mevcut padok-transfer akışı (Padok Düzenle → gizli buton → ayrı modal) fazla katmanlı ve junior-level görünüyor.

---

## Mevcut Sorun

- `m-padok-det` iki iş yapıyor: edit formu + hayvan listesi (single responsibility yok)
- Gizli buton → `m-padok-transfer` → tek aksiyon → 3 katman, overkill
- Kullanıcı "padoğu düzenleyeyim" niyetiyle açıyor, karşısında hayvan transfer akışı çıkıyor

---

## Önerilen Akış

**Sürü dashboardında seçim + bottom action bar:**

1. **Seçim modu:** Hayvana uzun basış → seçim modu aktif, kart highlight olur
   - Sonraki tıklamalar toggle eder (checkbox'sız, native mobil hissi)
   - Seçim modu aktifken küpe solunda floating ✓ belirir
2. **Bottom action bar:** Seçim yapılınca alttan yükselir
   - "N hayvan seçildi — Taşı →"
   - Her zaman görünmez, sadece seçim varken
3. **Inline padok seçimi:** Action bar üzerinde "Hedef padok: [dropdown]" — ayrı modal açılmaz
4. **Confirm:** Action bar'da inline "✅ Taşı" → "Emin misiniz?" → bitti

**Sonuç:** 3 modal → 0 modal, daha native, daha az katman

---

## Validasyon

- Hedef padok kapasitesi doluysa taşımadan önce uyar
- `padok_degistir` RPC'sine kapasite kontrolü eklenebilir (yoksa)

---

## Temizlik (bu akış kurulunca)

- `m-padok-transfer` silinir
- `m-padok-det` sadeleşir: sadece isim/kapasite edit kalır, hayvan listesi çıkar
- `pd-toplu-tasi-btn` ve ilgili JS (`padokTopluTasi`, `padokTransferOnayla`) silinir

---

## İlgili Dosyalar

- `js/ui.js` → `padokTopluTasi()`, `padokTransferOnayla()`, `openStokDet()` (~line 4280+)
- `js/utils/handlers.js` → `padok-toplu-tasi`, `padok-transfer-onay`
- `index.html` → `m-padok-det`, `m-padok-transfer`
