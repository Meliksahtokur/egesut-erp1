# REV-5 — idle/sessiz-ui: Sessiz listesi UX — det'tan listeye dönüş + gruplu gösterim

**Tarih:** 2026-09-02 · **Taban:** main `a71b7a0` · **Branch:** `idle/sessiz-ui` (worktree: `/home/melik/egesut-wt/sessiz-ui`)
**Kaynak:** kullanıcı geri bildirimi — "hayvanın kartına gidip geri döndüğümde direkt dashboarda atıyor, kaldığım yere dönmüyor, listede sürekli gözle tarama yapıyorum"; "liste gruplar halinde gösterilebilir"

## Ölçülmüş kök neden (orchestratör, 2026-09-02 — yeniden araştırma GEREKMEZ, doğrula)

- Sessiz sheet'i **router modalı DEĞİL**: `_showSessizList()` (js/ui.js:1107-1122) `sessiz-bs` adlı ham
  fixed div üretir (body'ye append, z-index 300; pushState/_modalStack YOK).
- Satır onclick: `document.getElementById('sessiz-bs').remove();openDet('${s.hayvan_id}')` — sheet
  **DOM'dan siliniyor**; scroll pozisyonu dahil her şey gidiyor.
- `closeDet()` (js/ui.js:2253): `document.getElementById('det').classList.remove('on')` — **tek choke point**.
  app.js:128 popstate det dalı da closeDet çağırır; det'teki geri butonu da.
- Dash bandı satırları (ui.js:240-247, slice(0,8)) `openDet()` çağırır ama band dash üstünde kalır —
  dönüş dash = doğru; **band'a dokunma**.
- Sheet router'da olmadığı için sheet açıkken Android geri → sentinel confirm'i ("Uygulamadan çıkmak…") — ikincil pürüz.
- Aynı desenin sağlıklı örneği: `_showBelirsizList`/`_belirsizRender` (ui.js:1125+) — chip/bölüm deseni + scroll korunumu (prevScroll) orada var.

## İş 1 — Det'tan listeye dönüş (ZORUNLU)

1. Sheet satır onclick'inde `remove()` yerine: sheet'i **gizle** (`display:none`) + `globalThis._sessizReturn=true`
   (yeni minik helper, örn. `_sessizSheetGizle()`; onclick inline kalabilir: `_sessizSheetGizle();openDet('...')`).
2. `closeDet()` sonunda: `globalThis._sessizReturn` varsa `sessiz-bs`'i geri göster (`display:flex`) + flag temizle.
   DOM korunduğu için **scroll pozisyonu kendiliğinden korunur**. Hem ✕/geri butonu hem Android geri (app.js popstate det dalı) bu tek noktadan döner.
3. Kenar durumlar: det'tan çıkıp başka sayfaya geçilirse (goTo) flag+saklanan sheet temizlenmeli
   (goTo içinde ya da renderFromLocal başında: görünmez sessiz-bs'i remove et, flag sıfırla).
   Sheet yeniden açılırsa (Tümünü Gör) eski flag ezilmeli.

## İş 2 — Gruplu liste (ZORUNLU)

- Sheet içi satırlar **grup'a göre bölümlenmiş** listelensin: bölüm başlığı = grup adı + adet
  (örn. "Sağmal (Laktasyonda) · 9"). Grup sırası: en yüksek sessiz_gun'u içeren grup önce; grup içi sessiz_gun DESC.
- **"Hiç kayıt yok" (sessiz_gun>=9999) her zaman EN ALTta ayrı bölüm** (kayıtsız — grup etiketi ne olursa olsun
  orada toplanır; satırda grup etiketi görünür kalsın). Sentinel-son kuralı (bb4ea92) korunur.
- Gruplama saf fonksiyona çıkar: `_sessizGrupla(list)` → `[{grup, items}]` — unit test yaz
  (tests/unit/ui-pure.test.js desenine uygun; boş liste / tek grup / 9999 karışımı / Türkçe grup adları).
- Kompakt kal: yeni ağır mekanizma/chip filtresi EKLEME (kullanıcı tercihi: mevcut bloğa koşullu bölüm);
  başlık+sayı+açıklama satırı mevcut halini korusun.

## İş 3 — Android geri sheet'i kapatsın (OLABİLİYSE — kırılırsa bırak)

- Sheet açılınca `history.pushState({sessiz_bs:1},'')`; popstate handler'a (app.js:96 dalı, _mstack kontrolünün
  hemen öncesine) `sessiz-bs` görünürse: gizle/remove + `return` dalı ekle. B2/B21 E2E kilitleri router-modalları
  ve protokol sheet'ini test eder — sessiz-bs'e dokunmaz; yine de stub E2E (modal-router + kritik-akis, docker,
  PLAYWRIGHT_STUB_BACKEND=1) koşup yeşil olduğunu kanıtla. Herhangi bir test kırılırsa BU İŞİ GERİ AL, rapora yaz.

## Guardrail + disiplin

- Push YOK · tek commit · rapor `.claude/idle-reports/2026-09-02-sessiz-ui.md` (commit'e dahil).
- **Paralel uyarı:** REV-2 agent'ı şu anda başka worktree'de ui.js'in BAŞKA sembollerini düzenliyor
  (renderTask, _detOzetHtml/_detUremeHtml/_detSaglikRender/_detGorevHtml, _uremeKizginlik ~2611,
  renderPadokDolulukBar ~7304, animalGrupDegisti). Bu sembollere ve 1800-2100 + 7300 bölgelerine DOKUNMA;
  senin alanın: `_showSessizList` (1107-1122), `closeDet` (2253), app.js popstate (96-143), goTo temizlik noktası.
- GitNexus (repo:"egesut-erp1" her çağrıda): düzenlemeden önce `impact` — en az `_showSessizList` ve `closeDet`
  için; sonuçlar rapora. Commit öncesi `detect_changes({scope:"all", repo:"egesut-erp1", worktree:"<worktree yolu>"})`.
- onclick içinde `esc()` YASAK; hayvan_id uuid (üretilmiş) — mevcut desenle kal; grup adları esc'li.
- Toplu sed YASAK; sonrası self-shadow taraması. `npm run test:unit` 362+ yeşil + yeni _sessizGrupla testleri;
  `node --check` dokunulan js.
- UI tercihleri: kompakt, kırmızı yalnız iptal/sil; kolay kapanış korunur (backdrop-tap zaten var).

Tek commit: "idle: sessiz-ui — det'tan listeye dönüş + gruplu sessiz listesi".
