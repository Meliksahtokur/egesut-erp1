---
name: egesut-fullstack
description: EgeSüt ERP fullstack geliştirme — Tohumlama, doğum, hayvan yönetimi, veteriner domain kuralları ile kod yaz. Vanilla JS, Supabase, IndexedDB.
version: 2.0.1
session: dev
---

# EgeSüt ERP Fullstack Developer Skill

## 🗣️ Dil Kuralı (KRİTİK)

**ANADİL: TÜRKÇE**

- ✅ Tüm kod yorumları **Türkçe** (değişken adları İngilizce standart)
- ✅ Commit mesajları **Türkçe**
- ✅ Toast/error mesajları **Türkçe**
- ❌ Kullanıcı istemedikçe İngilizce kullanma

---

## 🎯 Ne Zaman Kullanılır

**Bu skill SADECE `dev` session'da aktif olur.**

- Tohumlama formu/düzenleme
- Doğum kaydı işlemleri
- Hayvan ekleme/güncelleme
- Hastalık/vaka yönetimi
- İlaç/stok işlemleri
- Padok yönetimi
- Raporlama ekranları

## ⚠️ Session Kilidi

**Bu skill SADECE `development` branch'inde çalışır.**

❌ `development` dışı branch → Bu skill çalışmaz
❌ Skill/agent/MCP geliştirme → `gwen-arge` kullan
❌ `.qwen/` dizininde değişiklik → `gwen-arge` kullan

---

## 📚 Domain Kuralları

### 1. Hayvan Kimliği
- Her hayvanın `kupe_no` (işletme) ve/veya `devlet_kupe` (devlet) vardır
- Tohumlama/doğum kayıtlarında `hayvan_id` bazen UUID, bazen kupe_no olabilir

### 2. Hayvan Grupları

| Grup | Padok |
|---|---|
| Sağmal (Laktasyonda) | Sağmal Padok |
| Sağmal (Kuru) | Kuru/Gebe Padok |
| Gebe Düve | Kuru/Gebe Padok |
| Düve (Büyük) | Düve Padok (Büyük) |
| Düve (Küçük) | Düve Padok (Küçük) |
| Süt İçen Buzağı | Buzağı Padok (Süt İçenler) |
| Sütten Kesilmiş Buzağı | Buzağı Padok (Sütten Kesilmiş) |
| Besi | Besi Padok (Erkek/Dişi) |

**Kural:** Erkek hayvan Sağmal/Kuru/Gebe grubuna girmez.

### 3. Yaş Sınırları

**Dişi:**
- 0–75 gün: Süt İçen Buzağı
- 76–180 gün: Sütten Kesilmiş Buzağı
- 181–365 gün: Düve (Küçük)
- 366–730 gün: Düve (Büyük)
- 730+ gün: Sağmal, Kuru, Gebe Düve

**Erkek:**
- 0–75 gün: Süt İçen Buzağı
- 76–180 gün: Sütten Kesilmiş Buzağı
- 180+ gün: Besi

### 4. Tohumlama Kuralları

**Ön Koşullar:**
- Cinsiyet: Dişi
- Yaş: ≥ 12 ay (365 gün)
- Durum: Aktif
- Gebelik: Yok

**Sonuç Durumları:**
```
[Bekliyor] → [Gebe] → [Doğum Yaptı]
    ↓           ↓
  [Boş]      [Abort]
```

**Kritik:** `Gebe` ve `Doğum Yaptı` kayıtları direkt değiştirilemez — RPC kullan!

### 5. Doğum

**RPC `dogum_kaydet` yapar:**
1. Buzağıyı ekle (grup: Süt İçen Buzağı)
2. Anne tohumlama kaydını kapat (`sonuc = 'Doğum Yaptı'`)
3. Anneye ilaç görevleri oluştur (7 görev)
4. Buzağıya bakım görevleri oluştur (6 görev)

---

## 🛠️ Teknik Stack

- **Frontend:** Vanilla JS (ES6+)
- **Backend:** Supabase (PostgreSQL + RPC)
- **Local:** IndexedDB (offline-first)
- **Build:** Yok (direkt browser)

## 📁 Proje Yapısı

```
/root/egesut-erp1/
├── index.html          # Ana HTML
├── js/
│   ├── ui.js          # DOM render, modal, autocomplete (2804 satır)
│   ├── forms.js       # Form submit, validasyon, RPC (938 satır)
│   ├── app.js         # App init, routing, IndexedDB (737 satır)
│   ├── api.js         # Supabase client, RPC wrapper (332 satır)
│   ├── state.js       # Global state (getState, setState)
│   └── config.js      # Domain sabitleri (GRUP_PADOK vb.)
├── .claude/
│   ├── domain-rules.md     # Veteriner kuralları
│   ├── rpc-reference.md    # RPC imzaları
│   └── ui-map.md           # UI bileşen haritası
└── .qwen/
    ├── QWEN.md             # Session kuralları
    └── AGENT_HIERARCHY.md  # Hiyerarşi
```

---

## 🔧 Kod Yazma Kuralları

### 1. RPC Kullanımı (KRİTİK)

**DOĞRU:**
```javascript
const { data } = await supabase.rpc('tohumlama_kaydet', {
  p_hayvan_id: hayvanId,
  p_tarih: tarih
});
```

**YANLIŞ:**
```javascript
// ❌ Direkt REST bypass — YASAK!
await supabase.from('tohumlama').insert({...});
await supabase.from('hayvanlar').update({...}).eq('id', id);
```

**Kural:** Direkt REST PATCH/INSERT/DELETE yasaktır — SADECE RPC kullan!

### 2. Validasyon

```javascript
// Tohumlama tarihi kontrolü
if (new Date(tohumlamaTarihi) > new Date()) {
  showToast('Tohumlama tarihi ileri olamaz!', 'error');
  return;
}

// Yaş kontrolü
const gunFark = (Date.now() - new Date(dogumTarihi)) / 86400000;
if (gunFark < 365) {
  showToast('Hayvan tohumlama için çok genç (< 12 ay)', 'error');
  return;
}
```

### 3. IndexedDB Pattern

```javascript
// Okuma
const animals = await idbGetAll('hayvanlar');

// Yazma (sync)
await idbPut('hayvanlar', hayvan);
// + Supabase'e gönder (offline kuyruk)
```

### 4. Toast Mesajları

```javascript
showToast('Başarılı!', 'success');
showToast('Hata oluştu!', 'error');
showToast('Uyarı mesajı', 'warning');
```

---

## 📋 Checklist (Her Task'ta)

```
[ ] domain-rules.md ilgili bölüm okundu mu?
[ ] rpc-reference.md imzası kontrol edildi mi?
[ ] node --check geçti mi?
[ ] Duplikat fonksiyon yok mu? (grep)
[ ] Türkçe toast/error mesajları var mı?
[ ] Branch: gwen/task-* kullanıldı mı?
[ ] DONE: commit mesajı hazır mı?
```

---

## 🚨 Sık Yapılan Hatalar

1. **Direkt REST bypass** → RPC kullan!
2. **State machine ihlali** → Gebe/Doğum Yaptı direkt değiştirilemez
3. **Yaş kontrolü eksik** → Her zaman kontrol et
4. **Duplikat fonksiyon** → grep ile kontrol et
5. **Türkçe mesaj yok** → Toast'lar Türkçe olmalı

---

## 📖 Referanslar

- **Domain Kuralları:** `.claude/domain-rules.md`
- **RPC İmzaları:** `.claude/rpc-reference.md`
- **UI Haritası:** `.claude/ui-map.md`
- **Session Kuralları:** `.qwen/QWEN.md`
- **Hiyerarşi:** `.qwen/AGENT_HIERARCHY.md`

---

**Bu skill yüklendiğinde:** EgeSüt ERP domain kuralları ve teknik pattern'leri otomatik aktif olur.

🔧 EgeSüt Fullstack hazır!
