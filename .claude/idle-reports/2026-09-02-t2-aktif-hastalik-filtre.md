# T2 — Dashboard "Aktif Hastalık" kartı → sürü+hasta tag + dinamik hastalık filtresi (2026-09-02)

**Durum:** KAPANDI — main `e810ca3` (origin/main pushlu), 440/440 unit, subagent review APPROVE, kullanıcı canlı demo testinde onayladı. Worktree + branch silindi, serve 8082 kapatıldı.

**Commit'ler:** e72beec (feat) → f33b2db (review polish) → 0ab1f4a (renderAnimals sıralama fix) → e810ca3 (merge)

## Ne yapıldı

1. **Kart yönlendirmesi:** `_dashStatRow` "Aktif Hastalık ›" kartı `goTo('gecmis');loadGecmis('hastalik')` → `showHasta()`. showGebe'nin B20 deseni birebir: goTo('suru') chip'leri sıfırladığı için chip state'i programatik seçilir, render'ı sondaki filterA bırakır (clearTimeout önceki timer'ı iptal eder).
2. **Açılış tarihi sıralaması:** hasta listesi vaka açılışına göre en yeni→eski; `cases.start_date` (canlı şemadan doğrulandı, date), yoksa `created_at` fallback. Hayvan başına en yeni aktif vaka tarihi anahtar.
3. **Dinamik hastalık filtresi:** filtre-strip altı `#hasta-hastalik-filtre` konteyner; checkbox'lı dropdown **yalnız 🏥 Hasta tag aktifken**; seçenekler aktif vakalardan (cases status='active' + diseases ad eşlemesi) vaka sayılarıyla türetilir — vakası olmayan hastalık seçenekte çıkmaz. OR mantığı, ✕ Temizle, panel-dışı tıkla-kapan, aktif vaka yoksa kontrol hiç render edilmez.

## Saf çekirdek (unit'li, tests/unit/hasta-filtre.test.js — 16 test)

- `_hastaHastalikSecenekleri(vakalar,diseases)` → [{id,name,sayi}] tr-alfabetik
- `_aktifVakaAcilisMap(vakalar)` → animal_id → en yeni açılış
- `_hastaModuUygula(list,vakalar,secim)` → seçim filtresi + sıralama (kopya döner)
- `renderAnimals(list,{verilenSira:true})` → çağıranın sırası korunur

## Kritik ders: renderAnimals sıralamayı ezer

filterA'da sort yetmez — renderAnimals her çağrıda kendi sıralamasını uygular (gebe→tohumlama tarihi, sonra küpe). Kullanıcı "random liste" raporuyla bulundu; `opts.verilenSira` param'ı eklendi (eklemeli). Detay: `.claude/session-learnings.md` T2 bölümü.

## Etki yüzeyi

- state.js: `aktifVakalar` + `diseases` anahtarları (loadAnimals doldurur)
- handlers.js: `hasta-hastalik-drop` / `hasta-hastalik-temizle` action'ları
- ui.js `_dashStatRow`: T1 ile ortak çakışma yüzeyi — merge'de her iki kart davranışı alındı (showHasta + openSuttenKesModal)
- SQL değişikliği YOK — deploy yalnız JS (GitHub Pages)
