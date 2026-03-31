# Aktif Bug'lar ve Yarım Kalan İşler

> Son güncelleme: 2026-03-28

---

## Aktif Bug'lar (8 açık)

### 🔴 Kritik

**BUG-009 — `tohSonuc()` direkt REST PATCH (forms.js:640)**
- DB tarafı hazır: `tohumlama_sonuc_gebe/bos/bekliyor` RPC'leri mevcut (migration 20260327000001)
- Frontend güncellenmedi — `tohSonuc()` hâlâ `write()` ile direkt PATCH yapıyor
- Durum: `inceleniyor` — açıkça "sonraki oturuma" ertelendi
- Etki: Tohumlama sonuç butonları (Gebe/Boş/Bekliyor) RLS ve trigger'ları bypass ediyor

---

### 🟠 Yüksek

**BUG-004 — `drug_products` direkt `.insert()` (forms.js:765)**
- Yeni ilaç ürünü eklenirken RPC yerine direkt REST insert
- RLS policy, trigger, backend validasyon tamamen atlanıyor

**BUG-005 — `stok` direkt `.update()` (forms.js:775)**
- İlaç-stok bağlantısı güncellenirken direkt REST update
- Stok tablosu ledger prensibiyle RPC üzerinden yönetilmeli

**BUG-006 — `drugs` direkt batch `.update()` (ui.js:1160)**
- Stok-ilaç bağlantısı silinirken direkt batch update
- RLS policy kontrolü yok

**BUG-007 — Offline kuyruk direkt REST bypass (ui.js:2745, 2749)**
- `dataTrafficTekGonder` offline→online geçişte ilgili tablolara direkt insert/update yapıyor
- Backend validasyonu ve RPC guard'ları tamamen devre dışı kalıyor
- Etki: Offline'da biriken veriler RPC'siz senkronize ediliyor

---

### 🟡 Orta

**BUG-002 — `openNotModal` duplikat (forms.js:319 + ui.js:663)**
- `ui.js` versiyonu input temizleme adımını içermiyor
- Hangi versiyonun çalıştığı script yükleme sırasına göre değişiyor

**BUG-003 — `selDis` duplikat (app.js:647 + ui.js:2605)**
- `app.js`: 2 parametreli, `ui.js`: 1 parametreli (tani-btn reset eksik)
- Tanı seçimi sonrası aktif buton görseli yanlış kalabilir

**BUG-008 — `submitInsem` sonrası UI refresh garantisiz (forms.js)**
- `pullTables(['tohumlama','gorev_log']).then(renderSafe)` commit d562d03'te kaldırıldı
- RPC'nin gerçekten otomatik invalidation tetikleyip tetiklemediği doğrulanmamış
- Etki: Tohumlama kaydından sonra liste ekranı eski veriyi gösterebilir

---

## Yarım Kalan İşler

### Kod Değişikliği Gereken

**İ-003 — Tohumlama write-path refactor** *(kısmen tamamlandı)*
- DB: ✅ `tohumlama_sonuc_gebe/bos/bekliyor` RPC'leri hazır
- Frontend: ❌ `tohSonuc()` (forms.js:640) ve `tohSonucGuncelle()` (ui.js) hâlâ eski yolu kullanıyor
- Bloke eden: BUG-009 ile aynı iş

**Klinik frontend tamamlanmadı** *(ARCHITECTURE.md §7 Aşama 2)*
- DB hazır: `cases`, `treatment_days`, `drug_administrations`, `diseases`, `drugs` tabloları mig-022'de kurulu
- Eksik: diseases/drugs dropdown'ları, vaka açma→gün ekleme→ilaç ekleme→kapatma tam UI akışı
- Eksik: `treatment_timeline` view'dan vaka detay render

---

### Yapısal / Dokümantasyon

**İ-002 — ADR'lar yazılmadı** *(bekliyor)*
- `.claude/arch-decisions/` dizini boş
- Kritik kararlar sadece commit mesajlarında yaşıyor (4 ADR gerekli)

**İ-007 — JS syntax check CI'a taşınmadı** *(bekliyor)*
- `startup-check.sh`'ten kaldırıldı (commit 6d9b0d8), alternatif pre-commit hook henüz yok

---

### Eski Mimariyle Kalmış Öneriler *(temizlenmeli)*

| Öneri | Sorun |
|-------|-------|
| İ-004 | `erp-planner` / `feature-dev` referansı — bu agent'lar artık yok |
| İ-005 | `erp-qa-agent haiku→sonnet` — bu agent artık `erp-qa-git` |
| İ-006 | `arge-local-reader` / `arge-web-researcher` feedback formatı — bu agent'lar kaldırıldı |

---

## Bilinen Teknik Borç (ARCHITECTURE.md)

| Sorun | Önem | Plan |
|-------|------|------|
| `state.js` benimseme tamamlanmadı, `_appState` paralel yaşıyor | 🟡 | Organik geçiş |
| `hastalik_log.ilac_stok_id` ve `ilac_miktar` orphan kolonlar | 🟡 | mig-029'da DROP |
| `buzagi_takip` tablosu kullanılmıyor | 🟡 | mig-029'da DROP veya entegre et |
| Migration 013-014 repo'da yok (SQL Editor'dan uygulandı) | 🟠 | Ground truth sync migration |
| `setInterval(syncNow, 5000)` polling | 🟢 | Realtime'a organik geçiş |
