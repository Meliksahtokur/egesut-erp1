# Kızgınlık Uyarı Sistemi — Tasarım (v2)

> **Tarih:** 2026-05-17
> **Mimari Prensip:** İş mantığı backend'de (view), frontend sadece render + toggle
> **Şema Değişikliği:** Yok — `tohumlama.created_at` zaten mevcut (ground_truth:30)

---

## Problem

Kızgınlık kaydı girilen hayvanların 12 saat içinde tohumlanıp tohumlanmadığı
takip edilemiyor. Şu an:
- Kızgınlık → `kizginlik_log` INSERT (RPC: `kizginlik_kaydet`)
- Tohumlama → `tohumlama` INSERT (RPC: `tohumlama_kaydet`)
- İkisi arasında FK/bağlantı YOK
- Kızgınlık kaydı sadece Üreme > Kızgınlık tab'ında listeleniyor

---

## Çözüm

### Mimarideki Yer

```
#shell
  #topbar (logo · durum noktası · yenile butonu)
  #sync-bar (senkronizasyon durumu — sadece offline/error)
  #kizginlik-bar  ← YENİ: kızgınlık uyarı şeridi (tüm ekranlarda)
  #pages (sayfa içeriği)
  #nav (alt gezinme — nb-ureme butonuna kırmızı nokta)
```

**Strip her sayfada görünür**, `_dashBands` içinde değil. `#sync-bar` ile aynı
desende: `display:none` varsayılan, `.on` class'ı ile göster/gizle.

---

### A. Backend: View + GRANT

`kizginlik_log.olusturma` (timestamptz, `DEFAULT now()`) ve
`tohumlama.created_at` (timestamptz, `DEFAULT now()`) kullanılır.
`tarih` kolonu `date` tipindedir — saat bazlı karşılaştırma için timestamp
kolonları gerekir.

**DISTINCT ON (kl.hayvan_id):** Aynı hayvanın 3 gün içinde birden çok
kızgınlık kaydı varsa sadece en günceli dikkate alınır. Strip "X kayıt" değil
"X hayvan" gösterir.

```sql
CREATE OR REPLACE VIEW public.cozulmemis_kizginlik_view AS
SELECT DISTINCT ON (kl.hayvan_id)
  kl.id AS kizginlik_id,
  kl.hayvan_id,
  h.kupe_no,
  h.padok,
  h.grup,
  kl.tarih AS kizginlik_tarihi,
  kl.olusturma AS kizginlik_zamani,
  kl.belirti,
  EXTRACT(EPOCH FROM (NOW() - kl.olusturma))/3600 AS gecen_saat,
  CASE
    WHEN EXISTS (
      SELECT 1 FROM tohumlama t
      WHERE t.hayvan_id = kl.hayvan_id
        AND COALESCE(t.created_at, t.tarih::timestamptz) >= kl.olusturma
        AND COALESCE(t.created_at, t.tarih::timestamptz) < kl.olusturma + INTERVAL '12 hours'
    ) THEN 'cozuldu'
    WHEN EXTRACT(EPOCH FROM (NOW() - kl.olusturma))/3600 > 24 THEN 'bekleniyor'
    WHEN EXTRACT(EPOCH FROM (NOW() - kl.olusturma))/3600 > 12 THEN 'uyari'
    ELSE 'izleniyor'
  END AS durum
FROM kizginlik_log kl
JOIN hayvanlar h ON h.id = kl.hayvan_id AND h.durum = 'Aktif'
WHERE kl.olusturma >= NOW() - INTERVAL '3 days'
ORDER BY kl.hayvan_id, kl.olusturma DESC;
```

**GRANT SELECT (bloklayıcı — unutulursa 403):**
```sql
GRANT SELECT ON public.cozulmemis_kizginlik_view TO anon, authenticated;
```

#### RPC (opsiyonel)

```sql
CREATE OR REPLACE FUNCTION public.cozulmemis_kizginlik_sayisi()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object(
      'toplam',   count(*),
      'uyari',    count(*) FILTER (WHERE durum = 'uyari'),
      'bekleniyor', count(*) FILTER (WHERE durum = 'bekleniyor')
    )
    FROM public.cozulmemis_kizginlik_view
    WHERE durum != 'cozuldu'
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.cozulmemis_kizginlik_sayisi() TO anon, authenticated;
```

Frontend view'ı doğrudan sorgulayabilir — RPC sadece count yetiyorsa alternatif.

---

### B. Frontend: UI Elemanları

#### B1. HTML (index.html)

`#sync-bar` ile aynı hizada, `#topbar` ile `#pages` arasına:

```html
<div id="kizginlik-bar" onclick="goTo('ureme')" style="cursor:pointer">
  <span id="kizginlik-bar-txt"></span>
</div>
```

#### B2. CSS (index.html)

```css
#kizginlik-bar{display:none;padding:6px 14px;flex-shrink:0;align-items:center;gap:8px;cursor:pointer}
#kizginlik-bar.on{display:flex}
#kizginlik-bar.on.red{background:var(--red);color:#fff}
#kizginlik-bar.on.amber{background:var(--amber);color:#fff}
#kizginlik-bar-txt{font-size:.72rem;font-weight:700;color:#fff;flex:1}
```

#### B3. Nav Indicator (HTML + CSS)

```html
<!-- #nb-ureme içinde, #tbadge ile aynı desen -->
<div id="ubadge" class="nbadge" style="display:none">!</div>
```

```css
/* #ubadge .nbadge class'ını kullanır (tbadge ile aynı stil) */
#ubadge.nbadge{display:none}
#ubadge.nbadge.on{display:flex}
```

`#ubadge`, `#tbadge` ile birebir aynı mantık: count gösterir, `99+` kırpımı.
`display:none` default, `.on` class'ı ile görünür.

---

### C. Frontend: Mantık

#### C1. Güncelleme Fonksiyonu (ui.js)

`loadDash`'ten bağımsız:

```js
async function updateKizginlikAlert() {
  try {
    const { data } = await db.from('cozulmemis_kizginlik_view')
      .select('hayvan_id,durum')
      .neq('durum', 'cozuldu');
    const bar = document.getElementById('kizginlik-bar');
    const txt = document.getElementById('kizginlik-bar-txt');
    const nb = document.getElementById('nb-ureme');
    if (data?.length) {
      const uyariSayisi = data.filter(d => d.durum === 'uyari').length;
      bar.className = 'on ' + (uyariSayisi > 0 ? 'red' : 'amber');
      txt.textContent = `🔴 ${data.length} hayvan kızgınlıkta — tohumlanmadı`;
      nb?.classList.add('has-alert');
    } else {
      bar.className = '';
      nb?.classList.remove('has-alert');
    }
  } catch(e) { /* sessiz */ }
}
```

#### C2. Tetikleyiciler

| Nerede | Ne zaman |
|--------|----------|
| `forms.js` — `kizginlik_kaydet` başarılı yanıt | Hemen `updateKizginlikAlert()` |
| `forms.js` — `tohumlama_kaydet` başarılı yanıt | Hemen `updateKizginlikAlert()` |
| `app.js` — `goTo(pg)` (sayfa geçişi) | `loadDash()` ile birlikte |
| `app.js` — `initApp` | İlk yüklemede |
| `app.js` — `pullTables` sonrası | `['kizginlik_log','tohumlama']` geldiyse |

`setInterval` ile periyodik polling gerekmez — kullanıcı etkileşimi sonrası
tetiklenir.

#### C3. Strip'e Tıklandığında

`goTo('ureme')` → Üreme sayfası açılır. İsteğe bağlı: kızgınlık tab'ına
otomatik odaklanır (`loadUreme('kizginlik')`).

---

### D. Sınır Durumlar

| Durum | Davranış |
|-------|---------|
| Aynı hayvanın 3 günde 2 kızgınlık kaydı | DISTINCT ON sayesinde sadece en günceli değerlendirilir |
| Kızgınlıktan 12 saat sonra tohumlama | `cozuldu` sayılmaz, alarm devam eder |
| Kist / tohumlamayı atlama kararı | View veriye bakar. `kizginlik_log.notlar` manuel not içindir |
| Hayvan pasif/çıkış yapmış | `h.durum = 'Aktif'` filtresi sayesinde alarmda görünmez |
| `tohumlama.created_at` NULL | COALESCE ile `tarih::timestamptz` kullanılır (date → midnight) |
| View'dan SELECT yetkisi yoksa | `GRANT SELECT TO anon, authenticated` ile çözülür |

---

### E. Değişmeyenler

- `kizginlik_kaydet` RPC — aynı kalır
- `tohumlama_kaydet` RPC — aynı kalır
- `kizginlik_log` tablo şeması — aynı kalır
- `tohumlama` tablo şeması — aynı kalır
- `_dashBands` — değişmez
- `loadDash` — değişmez (sadece yan tetikleyici eklenir)
- Mevcut Üreme > Kızgınlık tab'ı — aynı kalır
- Mevcut `#sync-bar` — aynı kalır

---

## Uygulama Sırası

1. **`tohumlama.created_at` kontrol** — `.github/20260310000013_ground_truth.sql:30`
   zaten ekliyor, production'da muhtemelen var. Migration gerekmez.
   COALESCE fallback view'da kalır (zararsız).
2. **Migration** — CREATE VIEW + GRANT SELECT (RLS)
3. **HTML + CSS** — `#kizginlik-bar` elementi + stiller
4. **`updateKizginlikAlert()`** — `ui.js`'ye yeni fonksiyon
5. **Nav indicator CSS** — `#nb-ureme.has-alert::after`
6. **Tetikleyiciler** — RPC callback'leri + sayfa geçişi + init
7. **Test** — canlıda kızgınlık kaydı + tohumlama testi

---

## Referans: Mevcut Desenler

- `#sync-bar`: `display:none` → `.on{display:flex}`, `#topbar` altı persist strip
- `band()`: `_dashBands` içinde `aband` render fonksiyonu (bu işte kullanılmaz)
- `#tbadge`: `nbadge` class'ı ile görev sayısı (bu işte kullanılmaz)
- `loadDash()`: dashboard içeriğini render eder, her sayfa geçişinde tetiklenir
