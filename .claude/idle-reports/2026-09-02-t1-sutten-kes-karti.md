# T1 — Dashboard 🍼 Sütten Kes Kartı: Kesilecekler Kümesi Raporu

**Branch:** `idle/sutten-kes-liste` · **Worktree:** `/home/melik/egesut-wt/sutten-kes-liste` (kapanışta silindi)
**Commit'ler:** `1cd599c` (ana fix) + `b4e3483` (review minorları) — main'e **ff-merge + pushlu** (9f4e7fe..b4e3483, 2026-09-02)
**Temel:** d1de3e8 (T4) üzerinde yazıldı, T3 merge'i (9f4e7fe) sonrası **rebase** — 2 çakışma çözüldü (bkz. §5)
**Test:** 424/424 unit yeşil (T3'ün filtre testleri dahil, 11 yeni test) · **Review:** subagent APPROVE (0 blocker; 2 minor + 1 nit `b4e3483`'te kapandı)

## 1. Rapor edilen sorun — kök neden

Dashboard stat kartı "🍼 Sütten Kes ›" `onclick="goTo('suru');filterA()"` ile argsız
`filterA()` çağırıyordu → filtreler sıfırlanıp sürü listesinin **TAMAMI** açılıyordu
(kullanıcının deyişiyle "random ekran"). Ayrıca kartın sayacı kendine özgün bir küme
sayıyordu: `grup.includes('Süt İçen Buzağı')` + **sabit** 60 gün — modalın kanonik
kümesinden (`_sutIcenBuzagilar`: aktif + kesilmemiş + (grup 'Buzağı' içerir VEYA yaş ≤ 180))
hem set hem eşik kaynağı olarak ayrışıyordu. Yani sayaç ile listelenecek küme zaten
tutarsızdı; kart yalnız yanlış ekrana değil, yanlış sayıyla da gidiyordu.

## 2. Tasarım kararı — modal deseni (gerekçeli)

| Seçenek | Karar |
|---|---|
| **`openSuttenKesModal()` aç** | ✅ SEÇİLDİ — modal zaten kanonik kümesi checkbox+arama ile listeliyordu (yeniden icat yok); T4 bandındaki "Toplu Kes →" ile aynı davranışa biner (iki giriş, tek modal); T4 ile tutarlılık şartnamede açıkça istenmişti |
| Sürü filtresine bağla | ❌ argsız `filterA()` sıfırlama sorununu başka şekilde çözmez; filtreli-sürü state'i yeni icat demek; mevcut UI desenine modal daha yakın |

## 3. Tek kaynak: helpers.js saf katmanı

`js/utils/helpers.js`'e taşındı (SÖZLEŞME yorumu + `tests/unit/sutten-kes-secim.test.js`
ile kilitli):

- `sutIcenBuzagiSec(animals)` — kanonik setin saf aynası; `forms.js _sutIcenBuzagilar`
  buna delege oldu (artık `getState('animals')`'ı ona veriyor).
- `suttenKesimeHazirSec(animals, esik=60)` — "kesim vakti gelenler" (yaş ≥ eşik).
- `suttenKesListeSirala(animals, esik=60)` — vakti gelenler önce, grup içi sıra stable.
- `forms.js suttenKesmeEsigi()` (YENİ) — `protokol_ayar 'sutten_kesme_gun'`, `?? 60`.

Kart sayacı = `suttenKesimeHazirSec(animals, suttenKesmeEsigi()).length`. Review minoru
olarak T4 bandının kendi `|| 60` eşik okuması da `suttenKesmeEsigi()`'e bağlandı
(degenerate `'0'`/`''` değerinde kart↔bant ayrışmaması için).

## 4. Modal geliştirmesi + canlı doğrulama (demo, 2026-09-02)

- Vakti gelen satırlar en üstte + yeşil zemin + "🍼 Kesim vakti" rozeti; `index.html`
  modalına `#sk-ozet` satırı: "N buzağı kesim vakti (≥ X gün) · toplam M süt içen".
- Canlı demo ölçümü (port 8081, `?demo`): eşik 60 · **13 süt içen buzağı** ·
  **2 kesim vakti (küpe 85 ve 88)** → kart 2, modal özeti "2 buzağı kesim vakti
  (≥ 60 gün) · toplam 13 süt içen", rozetli satır sayısı 2 — **sayaç ↔ rozet birebir**.
  Arama filtresi, Tümünü Seç/Temizle, İptal ve T4 bandıyla birlikte hatasız doğrulandı.

## 5. Merge notları (T3 sonrası rebase, 2026-09-02)

- `helpers.js`: T3 (`aktifHayvanSatirlari`) + T1 (sutten-kes bloğu) ikisi de dosya
  sonuna eklemişti → iki blok korundu, `module.exports` satırı birleştirildi.
- `js/ui.js` loadDash: T3'ün `_dashSutBuzagiBandi(...,aktifTasks,...)` çağrı satırı ile
  T1'in `kesimEsik=suttenKesmeEsigi()` satırı birleştirildi (aktifTasks korunmalı —
  T3'ün aktiflik güvenlik ağı bozulmadı).

## 6. Genel ders: test tarihlerinde timezone flake'i

Boundary testinde `setDate(-n)` ile üretilen yerel-takvim günü, `_sutGunYasi`'nın
`new Date('YYYY-MM-DD')` = **UTC geceyarısı** parse'ıyla birleşince UTC+3'te gece
00:00–03:00 arası 1 gün kayıyor (60 → 59, test kırılıyor). Çözüm: ms tabanlı üretim
`new Date(Date.now() - n*86400000).toISOString()` (forms-validation `gunOnce` deseni)
— floor timezone'dan bağımsız her zaman n. Yeni tarihli testlerde bu desen kullanılmalı.

## 7. CANLIDA TEST EDİLECEKLER (Pages yayını sonrası)

1. Kart tıklaması → sürü DEĞİL "🍼 Sütten Kes" modalı.
2. Kart sayacı = modal özetindeki "N buzağı kesim vakti" = yeşil rozetli satır sayısı.
3. Vakti gelenler üstte + rozetli; gençler altta rozetsiz.
4. Ayarlar → sutten_kesme_gun değişimi (60→45) sayacı/rozetleri/özeti kaydırıyor; T4 bandı da aynı eşiği izliyor.
5. Bir buzağıyı kes → sayaç düşüyor, hayvan modal listesinden çıkıyor.
6. T4 bandı "Toplu Kes →" ile kart aynı modalı açıyor; bandın kırmızı kesim chip'leri kart kümesiyle örtüşüyor.
