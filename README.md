# EgeSüt ERP

130+ hayvanlık süt çiftliği için offline-first web tabanlı yönetim sistemi.

**Live:** https://meliksahtokur.github.io/egesut-erp1/
**Backend:** Supabase (PostgreSQL)
**Repo:** github.com/Meliksahtokur/egesut-erp1

---

## Teknik Stack

| Katman | Teknoloji |
|--------|-----------|
| Frontend | Vanilla JS, tek `index.html`, framework yok |
| Backend | Supabase (PostgreSQL + RPC) |
| Offline Cache | IndexedDB (`egesut_v9`) |
| Deploy | GitHub Pages (her push otomatik) |
| DB Migration | GitHub Actions → Supabase CLI |

---

## Modüller ve Durum

| Modül | Durum | Açıklama |
|-------|-------|----------|
| **Sürü** | ✅ Tamamlandı | Hayvan kaydı, kart, grup/padok, filtre |
| **Görev** | ✅ Tamamlandı | Otomatik görev üretimi, tamamlama, aşılama |
| **Stok** | ✅ Tamamlandı | İlaç/malzeme, ledger, kritik eşik |
| **Üreme** | 🟡 Kısmen | Tohumlama → gebelik → doğum akışı çalışıyor; aşılama frontend eksik |
| **Klinik** | 🟡 Kısmen | DB hazır (cases sistemi, mig-022), frontend tamamlanmadı |

---

## Mimari Prensipler

- **İş mantığı DB'de** — frontend sadece render ve input toplar, hesap yapmaz
- **Sadece RPC ile yaz** — direkt REST INSERT/UPDATE/DELETE yasak; tüm yazma işlemleri Supabase RPC üzerinden geçer
- **Controlled entities** — hastalık, ilaç, hayvan asla free-text; FK + dropdown zorunlu
- **Stok ledger immutable** — `stok_hareket` asla silinmez; düzeltme yeni kayıt olarak girilir
- **Offline-first** — tüm okumalar IndexedDB'den, yazma Supabase'e kuyruğa alınır
- **Migration idempotent** — her migration `DROP IF EXISTS + CREATE OR REPLACE` ile yazılır

---

## Kaynak Dosyalar

```
index.html              — HTML yapısı + CSS + tüm modaller (1125 satır)
js/
  config.js             — GRUP_PADOK mapping, sabitler (68 satır)
  state.js              — getState / setState / state.on (84 satır)
  api.js                — Supabase client, IndexedDB sync, RPC wrapper (335 satır)
  app.js                — Uygulama init, routing, global state (750 satır)
  ui.js                 — Tüm render fonksiyonları (2865 satır)
  forms.js              — Form submit, validasyon, RPC çağrıları (941 satır)
  utils/
    helpers.js          — DOM yardımcıları, toast, autocomplete, debounce
    modal.js            — Modal yönetimi (openM/closeM/mClose)
    errorHandler.js     — Merkezi hata yönetimi (withErrorHandling)
supabase/migrations/      — 31 migration dosyası (PostgreSQL)
```

---

## Veritabanı Özeti

```
hayvanlar (çekirdek)
  ├── tohumlama          — üreme olayları
  ├── dogum              — doğum kayıtları
  ├── kizginlik_log      — kızgınlık takibi
  ├── gorev_log          — görev sistemi
  └── cases              — klinik vakalar (mig-022)
        └── treatment_days → drug_administrations → drugs → stok

stok
  └── stok_hareket       — ledger (immutable)

diseases                 — controlled hastalık listesi
drugs                    — controlled ilaç listesi (stok bağlantılı)
```

Canlı DB şeması: [`db_schema_snapshot.md`](db_schema_snapshot.md)
Mimari kararlar: [`ARCHITECTURE.md`](ARCHITECTURE.md)

---

## Aktif Teknik Borç

| Sorun | Önem |
|-------|------|
| Klinik frontend tamamlanmadı (DB hazır, UI eksik) | 🟡 Yüksek |
| tohumlama_sonuc_bos RPC 42883 hatası (DB'de fonksiyon yok/yanlış) | 🔴 Kritik |
| Migration 013-014 repo'da yok (SQL Editor'dan uygulandı) | 🟠 Orta |
| ui.js monolitik (3000+ satır) - refactor gerekli | 🟠 Orta |

**Düzeltilen (2026-04-03):**
- ✅ vaccines + vaccination_log IDB store eklendi (DB_VER 14)
- ✅ tohumlama write path rpcOptimistic'e geçirildi
- ✅ `openNotModal` / `selDis` duplicate temizlendi
- ✅ drug_products/stok REST → RPC
- ✅ Offline kuyruk RPC_MAP ile RPC'ye yönlendiriliyor

---

## Geliştirme Notları

```bash
# Bağımlılıkları kur
npm install

# Supabase CLI ile migration uygula
npx supabase db push

# JS syntax kontrolü
node --check js/ui.js
node --check js/forms.js
```
