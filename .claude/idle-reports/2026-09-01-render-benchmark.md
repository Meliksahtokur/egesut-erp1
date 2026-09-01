# Render Benchmark Karar Belgesi — renderAnimals/filterA (Aşama 3.1)

**Tarih:** 2026-09-01 · **Tür:** Karar belgesi (kod YOK) · **Omurga:** ReFactorRoadmap Aşama 3.1
**Kapsam:** `js/ui.js:921 renderAnimals` · `js/ui.js:1673 filterA` · `js/ui.js:70 yasHesapla` · `js/ui.js:901 _animalCardHtml`
**Yöntem:** Gerçek şablon kodu (`_animalCardHtml`/`_animalTagsHtml`/`yasHesapla`) repodan extract edilip
stub bağımlılıklarla vm'de değerlendirildi; string üretimi `performance.now()` ile 20 tekrar ortalaması
(/tmp/bench-render.js — commit dışı). DOM parse/layout node'da ölçülemedi → varsayım tabanlı, aşağıda açıkça işaretli.

## 1. Mevcut render zinciri

```
realtime/pullTables ─→ renderSafe (60ms debounce) ─→ renderFromLocal (app.js:152)
arama/filtre girdisi ─→ filterA (250ms debounce, ui.js:1673)
                              └─ filtre zinciri (O(N)) → renderAnimals(f)
                                     └─ sort (O(N log N)) → suru-body.innerHTML = N kart (tam yeniden yazım)
```

Her `renderAnimals` çağrısı: tam liste sıralama + **kart başına 1 `yasHesapla`** + tam `innerHTML` değişimi.
`filterA` her vuruşta (250ms debounce ile) zinciri baştan koşar.

## 2. Ölçüm (gerçek kod, masaüstü CPU — Legion; mobilde 3-5x katlanım varsay)

| N (hayvan) | kart string üretimi | üretilen HTML | filterA arama filtresi | sort komparatörü |
|---|---|---|---|---|
| 27 (mevcut sürü ~) | 0.18 ms | 24 KB | 0.010 ms | 0.004 ms |
| 100 | 0.45 ms | 89 KB | 0.016 ms | 0.010 ms |
| 250 | 1.12 ms | 222 KB | 0.038 ms | 0.025 ms |
| 500 | 2.23 ms | 445 KB | 0.079 ms | 0.051 ms |
| 1000 | 4.73 ms | 891 KB | 0.213 ms | 0.109 ms |

**Okuma:** JS tarafı (string üretimi + filtre + sort + `yasHesapla`×N) doğrusal ve **hiçbir ölçekte darboğaz
değil** — N=1000'de bile toplam ~5 ms (masaüstü). `yasHesapla` kart başına tek çağrı; maliyeti string üretimi
içinde kayboluyor (ayrı ölçmeye değmez).

## 3. Gerçek darboğaz: `innerHTML` tam değişim (ölçülmeyen kısım — varsayım)

Maliyetin baskın kısmı string üretimi DEĞİL, `el.innerHTML = ...` atamasının tetiklediği:
HTML parse (~890 KB @ N=1000) + eski DOM ağacının yıkımı + ~12-15k yeni node kurulumu + style/layout/paint.
Orta seviye mobil tarayıcıda bu büyüklükte bir tam yeniden yazım için tipik **100-500 ms** bantı kabul edilir
(literatür: parse+layout ~ node sayısıyla doğrusal; web.dev uzun görev eşikleri). Ek yan maliyetler:
kullanıcının kaydırma konumu sıfırlanır, her vuruşta tüm node'lar çöp toplayıcıya düşer.

Buna rağmen **bugünkü N≈27'de (24 KB, ~400 node) tam yeniden yazım ölçülebilir bir sorun yaratmıyor** —
mevcut davranışın değiştirilmesi için veri yok.

## 4. Karar kriterleri (eşikler)

| Sürüş büyüklüğü | Tam innerHTML maliyeti (tahmin, mobil) | Karar |
|---|---|---|
| ≤150 | ≲30 ms | Dokunma (mevcut yapı korunsun) |
| 150-500 | ~30-250 ms | **Pagination** (Aşama 3.1 kapsamında uygula) |
| >500 | >250 ms | Pagination yeterli değilse virtual scroll değerlendir |

Kriter gerekçesi: bir render'ın "ücretsiz" sayılması için 16 ms kare bütçesinin, "kabul edilebilir" olması için
~100 ms etkileşim bütçesinin altında kalması gerekir. 150 eşiği mobil tahminiyle bu iki bandın arasına kondu
— kesin rakam değil, yeniden ölçümle güncellenebilir eşik.

## 5. Virtual scroll vs pagination

| Kriter | Pagination (sayfa başına ~50) | Virtual scroll (IntersectionObserver/scroll) |
|---|---|---|
| Uygulama maliyeti | **Düşük** — `filterA` sonunda `renderAnimals(f.slice(offset, offset+50))`, sayfa state + ileri/geri butonu | Yüksek — scroll sentinel, görünen pencere yönetimi, hızlı kaydırmada boşluk riski |
| Vanilla JS + mevcut mimari uyumu | **Tam** — dış mimariye sıfır dokunuş | renderAnimals'ın `sorted` sözleşmesi ve `a-seq` (global sıra no, ui.js:906) korunmalı; kart yüksekliği homojen olmalı |
| Arama/filtre entegrasyonu | **Doğal** — filtre sonrası sayfa 1'e dön | Filter değişince window reset; kaydırma konumu yönetimi ekstra |
| DOM node sayısı | ~50 kart/sayfa (sabit) | ~görünen+buffer (daha az, ama N<500'te fark anlamsız) |
| "Tek akışta gezinme" UX (mobil PWA alışkanlığı) | Kırılır (sayfa geçişi) | **Korunur** |
| Test edilebilirlik | Unit'te kolay (slice davranışı saf) | Scroll/IO sahtesi gerekir |
| Risk | Düşük | Orta-yüksek (kendi bug sınıfını getirir) |

## 6. ÖNERİ

1. **Bugün (N≈27): hiçbir şey yapma.** Mevcut tam-yeniden-yazım ölçülebilir sorun yaratmıyor; Aşama 3.1 için
   kod değişikliği gerekçesiz. Bu belge eşiği ve yöntemi sabitler.
2. **N>150 olduğunda (veya performans şikâyeti gelirse): pagination uygula** — sayfa boyutu 50, `filterA`
   sonrası sayfa 1'e reset, `a-seq` numarası GLOBAL listeden (filtre sonrası index) devam etsin (mevcut sözleşme).
   Gerekçe: en düşük maliyetli, mevcut mimariye en uyumlu, test edilebilir çözüm; virtual scroll'un tek
   avantajı (kesintisiz akış) bu uygulamanın kullanım deseninde (arama+filtre ağırlıklı) belirleyici değil.
3. **Virtual scroll yalnızca** N>500 **ve** kullanıcı araştırması "sonsuz akış" beklentisi ortaya koyarsa
   gündeme gelsin; o aşamada kart yüksekliği sabitliği ölçülüp doğrulanmalı.
4. Uygulama anında bu belgenin §2 tablosu hedef donanımda (telefon tarayıcısı) tekrar ölçülerek eşikler güncellensin.

## 7. Ek bulgular (bu kapsamda kod değişikliği YOK, kayıt altına)

- `renderAnimals` her çağrıda yeniden sıralar; sort maliyeti önemsiz (§2) — cache gereksiz.
- `_renderSuruStat` zaten `_suruStatCache` ile korunuyor (ui.js:945).
- `filterA`'nın 250ms debounce'u arama başına tam render sayısını zaten sınırlıyor; renderSafe'nin 60ms'i
  realtime patlamalarına karşı yeterli. Frekans tarafında iyileştirme gerekmiyor.
