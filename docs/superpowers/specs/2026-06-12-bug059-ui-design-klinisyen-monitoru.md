# BUG-059 UI Design Spec — Klinisyen Monitörü

**Tarih:** 2026-06-12
**Yazar:** Tasarım oturumu Faz 5 öncesi
**Bağlam:** BUG-059 Saat Bazlı Tedavi Seans Sistemi — Faz 5 UI entegrasyonu
**İlgili:** `.claude/notes/handoff-bug059-ui-developer-prompt.md` (operasyonel rehber)
**Referans:** `docs/superpowers/specs/2026-06-10-tedavi-saat-bazli-seans.md` (DB kontratı)

---

## 1. Vizyon (1 Paragraf)

> **Hedef:** Eczacı 1 saniyede "şu an ne yapmalıyım?" sorusuna cevap bulsun.
>
> **EKG şeridi** = 24 saatlik kesintisiz zaman çizgisi. Her seans kendi saatinde bir pip. Mavi **"şu an"** cursor'u yavaşça sağa kayar. Geciken pip kırmızı yanıp söner. Yapılan pip sakin yeşile dönüşür.
>
> Koyu zemin, monospace numerik, klinik renkler, abartısız animasyon. **Sıcak/samimi değil** — profesyonel, hızlı, sahada çalışır. Bir kalp monitörünün sakin disiplini, bir çiftlik defterinin sıcaklığı değil.

**İlham:** Defibrilatör ekranı, hasta monitörü (SpO2, kalp hızı), Holter cihazı, EKG kağıdı. **Hastane ekipmanı** estetiği.

**Reddettiğimiz yönler:** Sıcak kahverengi, el yazısı, köylü/çiftlik temaları, "arkadaş canlısı" ikonografi, yumuşak gölgeler, emoji ağırlıklı UI.

---

## 2. Tasarım Token'ları (Sadece BUG-059 Modal'ı)

**Global CSS değişkenleri (mevcut) KORUNUR.** Sadece BUG-059 modalları override eder.

### 2.1 Renkler (Klinik Palet)

| Token | Değer | Kullanım |
|-------|-------|----------|
| `--med-bg` | `#0A1014` | Modal arka plan (koyu klinik siyah) |
| `--med-bg2` | `#0F1820` | Card / surface |
| `--med-bg3` | `#16222D` | Hover / elevated |
| `--med-grid` | `rgba(232, 240, 244, 0.06)` | EKG grid çizgisi (24h) |
| `--med-grid-major` | `rgba(232, 240, 244, 0.12)` | 6h major grid |
| `--med-ink` | `#E8F0F4` | Primer metin |
| `--med-ink2` | `#B4C2CC` | Sekonder metin |
| `--med-ink3` | `#6B7B86` | Dim metin / label |
| `--med-green` | `#00D084` | Done (sakin klinik yeşil) |
| `--med-amber` | `#FFB627` | Due soon (±30 min) |
| `--med-red` | `#FF3B5C` | Overdue (uyanış) |
| `--med-blue` | `#2BA3FF` | Now cursor / info |
| `--med-glow-green` | `rgba(0, 208, 132, 0.18)` | Done pip halo |
| `--med-glow-red` | `rgba(255, 59, 92, 0.22)` | Overdue blink glow |
| `--med-glow-blue` | `rgba(43, 163, 255, 0.24)` | Now cursor glow |

### 2.2 Tipografi

| Kullanım | Font | Weight | Boyut |
|----------|------|--------|-------|
| Body (modals) | Plus Jakarta Sans (mevcut) | 400/700 | 0.85rem |
| Saat numerikleri (EKG, list) | **JetBrains Mono** (Google Fonts) | 500 | 1.1rem |
| Saat büyük (hero) | JetBrains Mono | 600 | 1.6rem |
| Modal başlık | Plus Jakarta Sans | 800 | 1.05rem |
| Label uppercase | Plus Jakarta Sans | 800 | 0.62rem, letter-spacing 0.08em |

```html
<!-- index.html <head> içine ekle -->
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@500;600&display=swap" rel="stylesheet">
```

### 2.3 Spacing & Radius

- Modal radius: **12px** (mevcut 22px yerine — daha keskin, klinik)
- Card radius: 8px
- Pip boyutu: 14px çap, glow 24px
- Now cursor: 1.5px genişlik
- Modal padding: 16px

### 2.4 Motion

| Hareket | Süre | Eğri | Kullanım |
|---------|------|------|----------|
| Done commit | 200ms | ease-out | Pip scale 0.8→1 + opacity 0→1 |
| Now cursor sweep | 60s | linear | Her dakika x pozisyonu kayar |
| Overdue blink | 1200ms | ease-in-out alternate infinite | Pip glow + scale 1→1.1 |
| Due-soon halo | 2500ms | ease-in-out alternate infinite | Halo scale 1→1.4 opacity 0.4→0 |
| Scan line | 4000ms | linear infinite | Modal üstünde 1px gradient sweep (CRT hissi) |
| Modal open | 280ms | cubic-bezier(.22,1,.36,1) | slideup korunur |

**YASAK:** Spring/bounce, jelly, overshoot, scale >1.15. Klinik = sakin.

### 2.5 Scan Line (isteğe bağlı, sahne kuran detay)

```css
.med-modal::before {
  content: '';
  position: absolute;
  top: 0; left: 0; right: 0;
  height: 1px;
  background: linear-gradient(90deg, transparent, var(--med-blue), transparent);
  opacity: 0.4;
  animation: scan 4s linear infinite;
  pointer-events: none;
}
@keyframes scan {
  0% { transform: translateX(-100%); }
  100% { transform: translateX(100%); }
}
```

---

## 3. Kompozisyon (Layout)

```
┌─────────────────────────────────────────┐
│  [scan line — 1px gradient sweep]       │  ← subtle CRT hissi
│                                         │
│  KÜPE-1847 — Anoestrus                  │  ← başlık (küpe, hastalık)
│  Gün 2 / 5   ⏱ 14:32                   │  ← meta (gün sayacı + canlı saat)
│                                         │
│  ┌───────────────────────────────────┐  │
│  │ 00  03  06  09  12  15  18  21  24│  │  ← EKG ribbon
│  │   · · · · │· ·○●· · · · · · · · ·│  │  ← pip + cursor
│  │            ↑                      │  │
│  │          şu an                   │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ▼ 08:00 — Dalmazin 5ml IM        [✓]  │  ← session card
│     Planlandı: 06:00 · Şimdi: 14:32    │     (gecikmiş → kırmızı)
│  ▼ 16:00 — Ademin 20ml IM         [✓]  │
│     Bekliyor (1sa 28dk)                 │     (yaklaşıyor → amber)
│  ▼ 24:00 — Vitamin B 10ml SC      [✓]  │
│     Bekliyor (9sa 28dk)                 │     (planlanmış → gri)
│                                         │
│  [+ Seans Ekle]                         │
│                                         │
│  [Vakayı Kapat]                         │
└─────────────────────────────────────────┘
```

**Layout prensibi:**
- **Vertical stack**, modal %100 width
- **Ribbon üstte** (ilk bakış noktası — "şu an nerede?")
- **Session list** altta (operasyonel — "ne yapacağım?")
- **Footer** butonlar (eylem)

---

## 4. EKG Ribbon — Detay

### 4.1 Yapı

```
┌──────────────────────────────────────────────────────┐
│ 00   03   06   09   12   15   18   21   24           │  ← saat etiketleri (6h major)
│ ··········│··········│··········│··········│·········│  ← gridlines
│        ○  ●              ▲                          │  ← pips + cursor
│        ↑  ↑              ↑                          │
│      done now          scheduled                    │  ← alt etiketler (5px, dim)
└──────────────────────────────────────────────────────┘
```

### 4.2 CSS İskeleti

```css
.med-ribbon {
  position: relative;
  height: 84px;
  background: var(--med-bg);
  border: 1px solid var(--med-bg3);
  border-radius: 8px;
  padding: 8px 12px;
  margin-bottom: 14px;
  overflow: hidden;
}
.med-ribbon-grid {
  position: absolute;
  inset: 24px 12px 24px 12px;
  background-image:
    repeating-linear-gradient(90deg,
      var(--med-grid) 0,
      var(--med-grid) 1px,
      transparent 1px,
      transparent 25%),       /* 1h grid (her %4.16) */
    repeating-linear-gradient(90deg,
      var(--med-grid-major) 0,
      var(--med-grid-major) 1px,
      transparent 1px,
      transparent 150px);     /* 6h major */
  background-position: left;
}
.med-ribbon-cursor {
  position: absolute;
  top: 20px;
  bottom: 20px;
  width: 1.5px;
  background: var(--med-blue);
  box-shadow: 0 0 6px var(--med-glow-blue);
  transition: left 60s linear;  /* yumuşak sweep */
}
.med-pip {
  position: absolute;
  top: 50%;
  width: 14px;
  height: 14px;
  border-radius: 50%;
  transform: translate(-50%, -50%);
  transition: all 200ms ease-out;
}
.med-pip.scheduled {
  background: var(--med-ink3);
  opacity: 0.5;
}
.med-pip.due-soon {
  background: var(--med-amber);
  box-shadow: 0 0 12px rgba(255, 182, 39, 0.4);
  animation: med-halo 2500ms ease-in-out infinite alternate;
}
.med-pip.now {
  background: var(--med-blue);
  box-shadow: 0 0 16px var(--med-glow-blue);
}
.med-pip.overdue {
  background: var(--med-red);
  animation: med-blink 1200ms ease-in-out infinite alternate;
}
.med-pip.done {
  background: var(--med-green);
  box-shadow: 0 0 10px var(--med-glow-green);
}
.med-pip.done::after {
  content: '✓';
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 9px;
  font-weight: 900;
  color: #0A1014;
}
.med-pip.cancelled {
  background: transparent;
  border: 1.5px solid var(--med-ink3);
  opacity: 0.4;
}
.med-pip.cancelled::after {
  content: '✕';
  font-size: 8px;
  color: var(--med-ink3);
}

@keyframes med-blink {
  from { box-shadow: 0 0 8px var(--med-glow-red); transform: translate(-50%,-50%) scale(1); }
  to   { box-shadow: 0 0 20px var(--med-glow-red); transform: translate(-50%,-50%) scale(1.12); }
}
@keyframes med-halo {
  from { box-shadow: 0 0 8px rgba(255,182,39,0.3); }
  to   { box-shadow: 0 0 18px rgba(255,182,39,0.6); }
}
```

### 4.3 Pip Pozisyon Formülü

```js
// planned_time: "08:00" string → 0-1 arası oran
function timeToRatio(timeStr) {
  const [h, m] = timeStr.split(':').map(Number);
  return (h * 60 + m) / (24 * 60);
}

// Container width: clientWidth, padding 12px
// Pip left: (containerWidth - 24) * ratio + 12
// NOT: med-ribbon-grid padding 12px sol+sağ, ratio 0-1
```

### 4.4 Now Cursor

```js
// Her 60 saniyede bir cursor güncelle
function updateNowCursor() {
  const now = new Date();
  const ratio = (now.getHours() * 60 + now.getMinutes()) / 1440;
  const ribbon = document.querySelector('.med-ribbon');
  if (!ribbon) return;
  const cursor = ribbon.querySelector('.med-ribbon-cursor');
  const grid = ribbon.querySelector('.med-ribbon-grid');
  const trackWidth = grid.clientWidth;
  cursor.style.left = `${trackWidth * ratio}px`;
}
setInterval(updateNowCursor, 60_000);
updateNowCursor(); // initial
```

**Sub-pixel notu:** `now.getSeconds()` farkını kullanarak cursor'u saniye bazında da yumuşak kaydır (CSS transition: left 60s linear sayesinde otomatik olur, JS sadece her dakika tetikler).

---

## 5. Session Durum Matrisi (6 Durum)

| State | Tetik | Renk | Animasyon | İkon | Buton |
|-------|-------|------|-----------|------|-------|
| `scheduled` | `uygulama_tamamlandi_at = NULL` ve şu an - planned > 30 min (ileride) | gri (dim) | yok | ○ | "✓ Uygulandı" + "✕ Yapılamadı" |
| `due-soon` | planned_time - 30min ≤ şu an ≤ planned_time (öncesi) | amber | halo pulse | ◐ | aynı |
| `now` | planned_time ≤ şu an ≤ planned_time + 30min (vakti geldi) | mavi | glow | ● | **PRIMARY** (tek tık yeşil) |
| `overdue` | şu an > planned_time + 30min (geçti) | kırmızı | blink | ● | aynı + acil |
| `done` | `uygulama_tamamlandi_at != NULL` | yeşil | yok (sabit) | ✓ | "Geri al" (5dk undo window) |
| `cancelled` | `uygulanmadi = true` | üstü çizili dim | yok | ✕ | "Yeniden Aktifleştir" |

**Geçiş kuralları:**
- `scheduled` → `due-soon` (T-30min)
- `due-soon` → `now` (T+0)
- `now` → `overdue` (T+30min)
- `overdue` → blink devam eder (süresiz, kapatana kadar)
- Herhangi bir durum → `done` (eczacı "✓ Uygulandı" tıklar)
- Herhangi bir durum → `cancelled` (eczacı "✕ Yapılamadı" tıklar + onay + stok iade)

---

## 6. 4 Modal — ASCII Sketch + Davranış

### 6.1 Task Detay Modal (Mevcut + Ribbon Eklentisi)

**Trigger:** Dashboard'da `renderTask()` kartına tıklanınca (`openTaskDet`).

```
┌─────────────────────────────────────────┐
│ 1847 — Anoestrus tedavisi               │
│ Gün 2/5 · ⏱ 14:32 · ID: 1de1605a       │
├─────────────────────────────────────────┤
│ 00  03  06  09  12  15  18  21  24      │
│ ······│····●··○··│··▲···○··│············│
│       08:00 16:00  24:00                │
├─────────────────────────────────────────┤
│ ┌─────────────────────────────────────┐ │
│ │ ●  08:00  Dalmazin 5ml IM           │ │  ← overdue (kırmızı)
│ │   Planlandı: 08:00 · Gecikme: 6sa 32dk│ │
│ │   [✓ Uygulandı] [✕ Yapılamadı]      │ │
│ └─────────────────────────────────────┘ │
│ ┌─────────────────────────────────────┐ │
│ │ ◐  16:00  Ademin 20ml IM            │ │  ← due-soon (amber)
│ │   Bekliyor · 1sa 28dk kaldı         │ │
│ │   [✓ Uygulandı] [✕ Yapılamadı]      │ │
│ └─────────────────────────────────────┘ │
│ ┌─────────────────────────────────────┐ │
│ │ ○  24:00  Vitamin B 10ml SC         │ │  ← scheduled (gri)
│ │   Bekliyor · 9sa 28dk kaldı         │ │
│ └─────────────────────────────────────┘ │
├─────────────────────────────────────────┤
│ [Vakayı Kapat] [Kapat]                  │
└─────────────────────────────────────────┘
```

**Davranış:**
- Tek-seans gün (eski yol): ribbon gizli, sadece 1 seans card
- Vaka kapalı: tüm cardlar gri, kilitli, buton yok
- Çok-seans (5+): session list scroll
- "✓ Uygulandı" → `seans_tamamla(p_seans_admin_id, false, null)` → optimistic update
- "✕ Yapılamadı" → onay modalı → `seans_tamamla(p_seans_admin_id, true, not)` → stok iade

### 6.2 Tedavi Ekle Modal (YENİ)

**Trigger:** Vaka modalı içinde "💊 Tedavi Ekle" butonu (mevcut `submit-case`'in uzantısı).

```
┌─────────────────────────────────────────┐
│ + Tedavi Ekle — 1847 / Anoestrus        │
├─────────────────────────────────────────┤
│ Tarih *                                 │
│ [2026-06-15]                            │
├─────────────────────────────────────────┤
│ ⏰ Seans Planı (2 seans)                │
│                                         │
│ ┌─ Seans 1 ─────────────────────────┐  │
│ │ Saat *      [08:00] [16:00] [24:00]│  │  ← hızlı şablon (chip)
│ │ İlaç *      [Ademin (20ml kaldı)▾]│  │
│ │ Doz *       [5    ] ml             │  │
│ │ Yol *       [IM  ] ▾               │  │
│ │ Not         [                    ] │  │
│ │              [🗑 Bu seansı sil]     │  │
│ └─────────────────────────────────────┘  │
│ ┌─ Seans 2 ─────────────────────────┐  │
│ │ Saat *      [16:00]                 │  │
│ │ İlaç *      [Dalmazin (94ml kaldı)▾]│  │
│ │ Doz *       [5    ] ml             │  │
│ │ Yol *       [IM  ] ▾               │  │
│ │              [🗑 Bu seansı sil]     │  │
│ └─────────────────────────────────────┘  │
│                                         │
│ 00  03  06  09  12  15  18  21  24      │  ← mini preview ribbon
│ ······│····●··○··│······················│
│       08:00 16:00                       │
│                                         │
│ [+ Seans Ekle]                          │
├─────────────────────────────────────────┤
│ [💾 Tedavi Planını Kaydet]              │
│ [İptal]                                │
└─────────────────────────────────────────┘
```

**Davranış:**
- 1 seans bırakılırsa → eski tek-seans davranış (`p_sessions = NULL`)
- 2+ seans → yeni çok-seans yolu
- "+ Seans Ekle" max 10 seans (validation)
- Mini ribbon preview her seans eklenince canlı güncellenir
- Hızlı şablon chip'ler (08:00, 16:00, 24:00) tek tıkla saat set eder
- "💾 Kaydet" → `add_treatment_day_with_sessions(case_id, date, sessions)`

### 6.3 Reçete Düzenle Modal (YENİ)

**Trigger:** Vaka modalında "📅 Reçeteyi Düzenle" butonu.

```
┌─────────────────────────────────────────┐
│ 📅 Reçete Düzenle — 1847 / Anoestrus    │
│ ⚠ Sadece henüz tamamlanmamış günler    │
│   düzenlenebilir                         │
├─────────────────────────────────────────┤
│ ▼ Gün 1 (12.06) — 🔒 tamamlandı        │  ← locked, görsel olarak dim
│   ○ 08:00 Ademin 20ml IM ✓             │
│   ○ 16:00 Dalmazin 5ml IM ✓            │
│                                         │
│ ▼ Gün 2 (13.06) — 🟡 0/2 seans         │  ← açık, düzenlenebilir
│   ⌃ Saat *  [08:00]                    │
│     İlaç   [Ademin ▾]  Doz [5] Yol [IM]│
│   ⌃ Saat *  [16:00]                    │
│     İlaç   [Dalmazin ▾] Doz [5] Yol [IM]│
│     [+ Seans Ekle]                      │
│                                         │
│ ▼ Gün 3 (14.06) — 0/2 seans            │  ← henüz tedavi günü açılmamış
│   ⌃ Saat *  [08:00]                    │
│     İlaç   [Ademin ▾]  Doz [5] Yol [IM]│
│   [+ Seans Ekle]                        │
│                                         │
│ ▼ Gün 4 (15.06) — ekle                 │  ← gün ekleme (boş accordion)
│ ▶ Gün 5 (16.06) — ekle                 │
├─────────────────────────────────────────┤
│ [💾 Reçeteyi Kaydet] [İptal]            │
└─────────────────────────────────────────┘
```

**Davranış:**
- Tamamlanmış günler (gün.tamamlandi = true) → sadece görüntüleme, düzenleme yok
- Açık günler (gün.tamamlandi = false) → seans ekle/sil, ilaç değiştir
- "Reçeteyi Kaydet" → `recete_guncelle(case_id, yeni_plan_jsonb)` → diff değil full replace
- Gün ekleme/silme mevcut gün sınırı içinde (case plan'ında belirtilen gün sayısı)

### 6.4 Vaka Kapat Modal (YENİ)

**Trigger:** Task det modalında "Vakayı Kapat" butonu (sadece son gün ise veya manuel).

```
┌─────────────────────────────────────────┐
│ ✕ Vakayı Kapat — 1847 / Anoestrus       │
├─────────────────────────────────────────┤
│ ⚠ 3 seans henüz tamamlanmadı:           │
│   • 14.06 08:00 — Ademin 5ml            │
│   • 15.06 16:00 — Dalmazin 5ml          │
│   • 16.06 08:00 — Vitamin B 10ml        │
│                                         │
│ Kapatınca:                              │
│   • Kalan seanslar "yapılamadı" işaretlenir│
│   • Stok iade edilir (Ademin 5ml, Dalmazin 5ml)│
│   • Vaka "kapalı" durumuna geçer        │
├─────────────────────────────────────────┤
│ Kapatma Notu                            │
│ [Hastanın durumu düzeldi, tedavi erken  ]│
│ [sonlandırıldı.                        ]│
├─────────────────────────────────────────┤
│ [✕ Kapat ve Stok İade Et]              │  ← kırmızı
│ [İptal]                                │
└─────────────────────────────────────────┘
```

**Davranış:**
- Açık seans yoksa → uyarı yerine "Tüm seanslar tamamlandı ✓" + basit kapatma
- "Kapat ve Stok İade Et" → `close_case_with_remaining(case_id, not)` → optimistic + rollback
- Stok iade sonrası toast: "✅ Vaka kapatıldı, 2 ilaç iade edildi"

---

## 7. Komponent Matrisi (Implementer İçin)

| Dosya | Sembol | Tip | Bağımlılık |
|-------|--------|-----|-----------|
| `index.html` | CSS `--med-*` değişkenleri + body override | E | Google Font JetBrains Mono |
| `index.html` | `<div id="m-tedavi-ekle">` modal template | Y | — |
| `index.html` | `<div id="m-recete-duzenle">` modal template | Y | — |
| `index.html` | `<div id="m-vaka-kapat">` modal template | Y | — |
| `index.html` | Mevcut `#m-task-det` içine ribbon div ekle | E | — |
| `js/api.js` | `pullTables()` → `treatment_day_uygulamalar` ekle | E | — |
| `js/api.js` | `rpcAddTreatmentDayWithSessions(caseId, date, sessions)` | Y | — |
| `js/api.js` | `rpcSeansTamamla(seansAdminId, uygulanmadi, not)` | Y | — |
| `js/api.js` | `rpcReceteGuncelle(caseId, yeniPlan)` | Y | — |
| `js/api.js` | `rpcCloseCaseWithRemaining(caseId, not)` | Y | — |
| `js/state.js` | `AppState.tedaviPlan` (caseId → {day_no, sessions}[]) | E | — |
| `js/config.js` | `UYGULAMA_YOLU = ['IM','IV','SC','PO','Topikal','Intrauterin']` | Y | — |
| `js/config.js` | `SEANS_STATE = { scheduled:'gri', dueSoon:'amber', now:'mavi', overdue:'kırmızı', done:'yeşil', cancelled:'üstü çizili' }` | Y | — |
| `js/ui.js` | `renderSessionsRibbon(sessions, opts)` | Y | state hesaplama |
| `js/ui.js` | `renderSessionCard(s, opts)` | Y | butonlar + state |
| `js/ui.js` | `updateNowCursor()` | Y | setInterval 60s |
| `js/ui.js` | `openTaskDet(taskId)` extend — ribbon + sessions inject | E | — |
| `js/forms.js` | `submitTedaviEkle(btn)` | Y | mini ribbon + RPC |
| `js/forms.js` | `submitReceteDuzenle(btn)` | Y | diff calc + RPC |
| `js/forms.js` | `submitVakaKapat(btn)` | Y | RPC + iade toast |
| `js/forms.js` | `seansTamamla(seansId, uygulanmadi, not, btn)` | Y | optimistic + rollback |

---

## 8. Edge Cases

| Durum | Davranış |
|-------|----------|
| Tek-seans gün (eski yol) | Ribbon gizli, sadece tek session card |
| 0 tedavi günü (yeni vaka) | Ribbon boş + "Henüz plan eklenmemiş" placeholder + CTA |
| Vaka kapalı (`status='closed'`) | Ribbon gri, kilitli, buton yok, "🔒 Vaka kapalı" rozet |
| 5+ seans (uzun gün) | Session list dikey scroll, ribbon sabit |
| Offline | Son cache + cursor "—:—" placeholder, RPC outbox |
| Mobile portrait | Ribbon okunabilir (84px height), session card full-width |
| Gece yarısı seans (00:00) | Pip sol kenarda, cursor geçtiyse blink |
| Eş zamanlı 2 seans (08:00 + 08:00 farklı ilaç) | Üst üste 2 pip, +6/-6px offset (max 5 aynı saat), hover tooltip'te ilaç adı |
| Stok yetersiz | Tedavi Ekle: "⚠ Yetersiz stok" uyarı chip (client-side check) |
| UNIQUE constraint (aynı saat aynı ilaç) | RPC error → toast: "❌ Aynı saatte aynı ilaç zaten var" |

---

## 9. "Yapma" Kuralları (Klinik Estetik Koruması)

1. **Mevcut pastel butonları OVERRIDE etme** — sadece BUG-059 modalları `--med-*` token'larını kullanır
2. **Mevcut sayfa layout'unu (dashboard, nav) değiştirme** — sadece modal içi
3. **Slide-up animasyonunu koru** (mobile için gerekli, 280ms cubic-bezier)
4. **Backdrop-filter blur(6px) koru** (depth hissi)
5. **Spring/bounce animasyon YASAK** (klinik = sakin)
6. **Renk sadece semantik anlam taşır** — kırmızı=uyarı, yeşil=done, mavi=now, amber=due-soon. Başka yerde renk kullanma
7. **Emoji sadece bilgi ikonu olarak** (✓, ✕, ⏱) — süsleme değil
8. **Border-radius max 12px** (yumuşak 22px'i bırak)
9. **Glow max 24px** (abartılı halo yok)
10. **Backend logic yazma** (RPC var) — sadece input → RPC → response render

---

## 10. Kabul Kriterleri (Definition of Done)

- [ ] EKG ribbon 24h, pips, now cursor renderlanıyor
- [ ] 6 seans durumu görsel olarak ayırt edilebilir (renk + animasyon + ikon)
- [ ] Geciken seans blink yapıyor (1.2s ease-in-out alternate)
- [ ] "Now" cursor her dakika güncelleniyor (60s interval)
- [ ] Due-soon seans amber halo pulse (2.5s)
- [ ] Done seans 200ms scale 0.8→1 commit animasyonu
- [ ] Tek-seans gün → ribbon yok, sadece session card
- [ ] 0 tedavi günü → "plan yok" placeholder
- [ ] Vaka kapalı → ribbon kilitli (gri)
- [ ] 3 yeni modal (Tedavi Ekle, Reçete Düzenle, Vaka Kapat) açılıp doğru RPC çağırıyor
- [ ] 10 E2E senaryosu PASS
- [ ] Mobile portrait'te ribbon + session card okunabilir
- [ ] Monospace numerik (saat) tutarlı (JetBrains Mono)
- [ ] Klinik estetik bütünlük: koyu zemin, monospace, klinik renkler, abartısız animasyon

---

## 11. Teknik Notlar

### 11.1 Font Yükleme
```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@500;600&display=swap" rel="stylesheet">
```

### 11.2 CSS Sınıf İsimlendirme
Tüm BUG-059 UI sınıfları `.med-*` prefix'i taşır (medical monitor):
- `.med-modal`, `.med-ribbon`, `.med-pip`, `.med-session-card`
- `.med-state-overdue`, `.med-state-done`, vb.
- `.med-btn-primary`, `.med-btn-secondary`, `.med-btn-danger`

### 11.3 State Hesaplama (Pure Function)
```js
function computeSeansState(seans, now = new Date()) {
  if (seans.uygulama_tamamlandi_at) return 'done';
  if (seans.uygulanmadi) return 'cancelled';

  const planned = new Date(`${seans.planned_date}T${seans.planned_time}`);
  const diffMin = (now - planned) / 60_000;

  if (diffMin > 30) return 'overdue';
  if (diffMin > -30 && diffMin <= 30) return 'now';
  if (diffMin > -60 && diffMin <= -30) return 'due-soon';
  return 'scheduled';
}
```

### 11.4 Optimistic Update Pattern (seans_tamamla)
```js
async function seansTamamla(seansId, uygulanmadi, not, btn) {
  // 1. Optimistic UI
  const card = btn.closest('.med-session-card');
  card.classList.add('med-state-done');
  // 2. RPC
  const res = await rpc('seans_tamamla', { p_seans_admin_id: seansId, p_uygulanmadi: uygulanmadi, p_not: not });
  // 3. Rollback on error
  if (!res?.ok) {
    card.classList.remove('med-state-done');
    toast('❌ ' + (res?.mesaj || 'Hata'), true);
  } else {
    toast(uygulanmadi ? '↩ Stok iade edildi' : '✓ Seans tamamlandı');
    pullTables(['treatment_day_uygulamalar', 'stok_hareket', 'gorev_log']);
  }
}
```

### 11.5 Ribbon Performans (60 seans = 60 pip)
- 60 pip DOM node → sorun değil, paint ucuz (14px circle)
- Cursor her dakika `left` update → 1px değişim, smooth transition 60s linear
- Hesaplama: O(n) where n=seans sayısı, tipik 5-15

---

## 12. İlgili Dosyalar

| Dosya | Amaç |
|-------|------|
| `.claude/notes/handoff-bug059-ui-developer-prompt.md` | Operasyonel rehber (kısa) |
| `.claude/notes/handoff-bug059-final.md` | Tüm Faz 0-4 handoff (871 satır) |
| `docs/superpowers/specs/2026-06-10-tedavi-saat-bazli-seans.md` | DB kontratı (Faz 1-2) |
| Bu dosya | UI design spec (klinik estetik) |

---

## 13. Karar Verilen Sorular (Kullanıcı Onayı, 2026-06-12)

| # | Soru | Karar |
|---|------|-------|
| 1 | Mobile landscape'te ribbon height? | **84px sabit** (portrait + landscape tutarlı) |
| 2 | Done seans "geri al" undo window? | **5 dakika** (sonra kalıcı) |
| 3 | Reçete düzenleme: tamamlanmış günler? | **Readonly görünür** (tarihçe, audit değeri) |
| 4 | Eş zamanlı 2 seans aynı saat? | **Üst üste 2 pip** (+0.5px offset, tooltip'te ilaç adları) |
| 5 | Ses bildirimi (due-soon)? | **Faz 5 sonrası** (şimdilik toast + glow yeterli) |

### 13.1 Karar Detayları

**Karar 2 — 5dk Undo Window:**
- Done pip tıklandıktan sonra pip üstünde "↩ Geri Al" chip belirir
- 5dk sonra kaybolur (CSS animation ile fade-out + scale)
- `data-undo-until` timestamp local state'te tutulur
- Backend'de `seans_tamamla` idempotent → ikinci çağrı hata dönmez, sessiz günceller

**Karar 3 — Readonly Tamamlanmış Günler:**
- Reçete modalı: gün accordion'ı açık, seanslar gri, input yok
- Sadece tamamlanmamış günler düzenlenebilir (renk: `--med-ink2`, opacity 0.6)
- "Bu gün tamamlandı" rozet (✓)
- Avantaj: eczacı reçetenin tüm geçmişini görür

**Karar 4 — Aynı Saat 2 Pip:**
- Ana pozisyon: `timeToRatio(time)` * trackWidth
- Çakışma kontrolü: aynı `timeToRatio` değerine sahip pip'leri grupla
- Grup içi offset: `[0, +6, -6, +12, -12]` px (max 5 aynı saat, 5 pip görünür)
- Hover: ilaç adı + doz tooltip
- CSS: `.med-pip.stacked-N` (N=0,1,2,3,4) → `transform: translate(calc(-50% + var(--offset, 0px)), -50%)`

**Karar 1 — 84px Sabit Ribbon:**
- Tüm viewport'larda (portrait + landscape + tablet) 84px
- Avantaj: tek CSS, tek test, tutarlı UX
- Dezavantaj: landscape'te daha az dikey alan (kabul edilebilir)
