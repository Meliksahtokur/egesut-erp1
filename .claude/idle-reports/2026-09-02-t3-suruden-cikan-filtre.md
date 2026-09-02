# T3 — Süruden Çıkan Hayvan Filtresi: Tarama Raporu

**Branch:** `idle/suruden-cikan-filtre` · **Worktree:** `/home/melik/egesut-wt/suruden-cikan-filtre`
**Commit'ler:** `ec65148` (ana fix) + `6b1412e` (review minorları) + `9c6d71e` (rapor) + `fa43970` (main d1de3e8/T4 merge — loadDash çağrı satırı çakışması çözüldü, _dashSutBuzagiBandi'ye aktifTasks verildi)
**Temel:** e8cd620 → main d1de3e8 ile senkron (T4 sonrası merge çatışması kalmaz)
**Test:** 413/413 unit yeşil (T4'ün 9 testi dahil) · **Review:** subagent APPROVE (2 minor uygulandı)

## 1. Rapor edilen sızıntı — kök neden ve canlı simülasyon (2026-09-02)

`js/ui.js loadDash` kızgınlık bandı (`births60`) dogum tablosundan [58..63] gün
penceresi alıyor, **annenin aktifliğini kontrol etmiyordu**; satır 296'daki filtre
yalnız "doğumdan sonra kızgınlık/tohumlama kaydı var mı"ya bakıyordu. Ek kusur:
bant ham UUID basıyordu.

Canlı pencere sorgusu (bugün 2026-09-02, pencere 2026-07-01..06) tam 2 anne verdi:

| anne_id | kupe | durum | bantta (eski) | bantta (fix sonrası) |
|---|---|---|---|---|
| 120ff1e6-…d2bdb7 | 157 | **Kesildi** (çıkış 2026-07-15, kesim) | ❌ görünüyordu | **düşer** |
| 0f449945-…03ad1e | 200 | **Aktif** | görünüyordu | **kalır** |

**0f449945 (kupe 200) kök nedeni:** Veri doğru — hayvan canlı DB'de gerçekten
`durum='Aktif'`, `cikis_tarihi=NULL`, cop_kutusu'nda yok. Kod hatası değil;
çıkış işlemi *yapılmamış*. Süruden çıktıysa kullanıcı çıkış kaydı girecek; kod
tarafı doğru davranıyor. (Fix sonrası bant bu hayvanı **"200" küpe no ile**
gösterir — ham UUID kusuru da kapandı.)

## 2. Genel tarama — hangi ekranda hangi sızıntı, neyle kapandı

| # | Ekran / bant | Kaynak | Eski durum | Çözüm |
|---|---|---|---|---|
| 1 | 💛 Kızgınlık Beklenenler (58-63g) | `dogum` [58..63g], **anne durumu kontrolsüz** | **SIZINTI** (rapor edilen: 157 Kesildi banttaydı) | `loadDash`: `aktifHayvanSatirlari(births60,'anne_id',…)` + ham UUID→kupe/devlet_kupe gösterimi |
| 2 | 🤰 Yaklaşan Doğumlar (≤7g) | `tohumlama sonuc='Gebe'` tarih filtresi, anne kontrolsüz | **SIZINTI** | `loadDash`: `gebeTohs→gebeTohsA` aktif-anne filtresi |
| 3 | Gebe sayacı (dashboard stat) | `gebeTohs` ham | Sızıntı (çıkmış hayvan sayıyordu) | aynı `gebeTohsA` stat'a verildi |
| 4 | 💉 Yaklaşan Aşılar bandı | `vaccination_log`, hayvan kontrolsüz | **SIZINTI** | `_dashVacAlerts` 4. opsiyonel param `aktifIdler` (geriye uyumlu) |
| 5 | Geciken/Bugün/Yaklaşan Aşı/Yarın Takviye bantları + Bekleyen Görev sayacı | `gorev_log` | Çıkış trigger'ı iptal ediyor ama IDB gecikmesi/stale kayıt riski | `loadDash`: `tasks→aktifTasks` güvenlik ağı |
| 6 | Görev listesi ekranı (`loadTasks`) | `gorev_log` (+allSubs) | Aynı risk | `aktifHayvanSatirlari(data/allSubs,'hayvan_id',…)` güvenlik ağı |
| 7 | ❗ Sessiz Hayvanlar bandı | RPC `sessiz_hayvanlar_listele` → `v_eligible` | ✅ temiz — view `h.durum='Aktif'` filtreli (canlıdan doğrulandı) | — |
| 8 | 🤰 İleri Gebeler bandı | RPC `gebelik_protokol_kontrol` | ✅ temiz — RPC `h.durum='Aktif'` JOIN'li (canlıdan doğrulandı) | — |
| 9 | Kızgınlık barı (üreme ekranı) | view `cozulmemis_kizginlik_view` | ✅ temiz — `JOIN hayvanlar h … h.durum='Aktif'` (canlıdan doğrulandı) | — |
| 10 | Sürü listesi + Gebe modalı | `getData('hayvanlar',a=>a.durum==='Aktif')` | ✅ temiz | — |
| 11 | Hayvan detay sekmesindeki görevler (`_detGorevHtml`) | bilinçli bağlam (o hayvanın sayfası) | dokunulmadı | — |

**cop_kutusu kapsamı:** Çöpe taşınan hayvan `hayvanlar` tablosundan silinir →
aktif kümede yok → ona bağlı görev/dogum/tohumlama satırları da filtrelenir (testle sabit).

**Sunucu tarafı:** Ek SQL gerekmedi — sızıntı kaynaklarının hepsi ya client-side
okuma (dogum/tohumlama/vaccination_log IDB) ya da zaten server'da filtreli.
`trg_hayvan_cikis_gorev_iptal` trigger'ı canlıda doğrulandı (157'nin açık
görevi yok). → **DRAFT MIGRATION YOK, PROD SQL DEPLOY YOK.**

## 3. Değişim özeti (dar tutuldu — T1/T4 çakışma uyarısına uygun)

- `js/utils/helpers.js`: **+1 saf fonksiyon** `aktifHayvanSatirlari(rows,idKey,aktifIdler)` + export. Sözleşme: idKey'siz satır kalır; Set/dizi kabul; `null` → filtre kapalı (fail-safe); saf, yeni dizi.
- `js/ui.js loadDash`: 4 nokta filtre takası + `aktifIdler`/`gebeTohsA` tanımı. **İmza değişmedi.**
- `js/ui.js _dashBands`: yalnız kızgınlık bandı satır şablonu (UUID→kupe). Başka bantlara dokunulmadı.
- `js/ui.js _dashVacAlerts`: opsiyonel 4. param (mevcut 3-arg çağrılar/tests etkilenmez).
- `js/ui.js loadTasks`: data + allSubs filtre satırları.
- `tests/unit/cikis-filtre.test.js`: 13 test (sözleşme, canlı senaryo, boş-Set fail-safe, kupe fallback'leri).

Toplam: 2 dosya, ~55 net satır. Review bulguları: (1) boş hayvan listesi →
`null` geçir (tümünü gizleme), (2) `allSubs` da filtrelesin — ikisi uygulandı.

## 4. CANLIDA TEST EDİLECEKLER (kullanıcı)

> Merge+push SONRASI — GitHub Pages JS günceller, **SQL deploy adımı YOK**.

1. Dashboard → 💛 Kızgınlık bandı: **157 görünmemeli**, **200 küpe no ile görünmeli** (ham UUID değil).
2. Dashboard → 🤰 Yaklaşan Doğumlar ve 💉 Yaklaşan Aşılar: çıkmış hayvan olmamalı.
3. Görevler ekranı: sürüden çıkmış hayvana ait açık görev olmamalı (normalde trigger zaten kapatıyor — boş liste normal).
4. İleri Gebeler / Sessiz bandı: değişiklik yok (zaten temizdi).
5. Kupe 200 gerçekten sürüde değilse: hayvana çıkış kaydı gir (Satıldı/Kesimdi…) → banttan da düşer.

## 5. Nasıl test edilIR (lokal)

```bash
cd /home/melik/egesut-wt/suruden-cikan-filtre
npm run test:unit            # 404/404
python3 -m http.server 8093  # çalışıyor: http://127.0.0.1:8093
# Tarayıcı Console: localStorage.EGESUT_DEMO='1' → demo mod
```
