# Implementasyon Planı — Buzağı Bakım Modal Checkbox + Bölünme Fix'i

> **Tarih:** 2026-09-01 · **Worktree:** `/home/melik/egesut-wt/buzagi-gorev-modal` (`idle/buzagi-gorev-modal`)
> **Spec:** `docs/2026-09-01-buzagi-gorev-modal-spec.md` · **Analiz:** `docs/2026-09-01-buzagi-gorev-modal-analiz.md`
> **Baseline:** 344/344 unit test yeşil (`npm run test:unit`). DB değişikliği YOK.

## Dokunulacak dosyalar

| Dosya | Değişiklik | Etki (GitNexus, 2026-09-01 ölçümü) |
|---|---|---|
| `js/ui.js` | `openTaskDet` (td-subs render), `detayTamamla` (guard), yeni: `renderTaskDetSubs`, `toggleSubDet`, `grupTamamla` | openTaskDet upstream=4 (LOW), detayTamamla upstream=1 (LOW) |
| `tests/unit/buzagi-gorev-modal.test.js` | YENİ — saf fonksiyon testleri | — |
| `index.html` | Beklenen: dokunulmaz (`td-subs` container hazır; içerik render string) | — |

Inline onclick üretimi nedeniyle GitNexus graph yeni çağrıları göremez → her adım sonrası
`grep -n "toggleSubDet\|grupTamamla\|renderTaskDetSubs" js/*.js index.html` bare-identifier taraması.

## Adımlar (TDD)

### 1. Unit testler önce (`tests/unit/buzagi-gorev-modal.test.js`)
`ui-pure.test.js` loader pattern'i ile:
- `renderTaskDetSubs(subs)` → done/bekleyen satırların HTML'i: `st-check done` sınıfı,
  `data-sub` dataset'i, onclick attribute'unda `toggleSubDet`, etiket `JSON.parse(p.label)`
  fallback'i, esc() kaçışı.
- `detayBtnEtiketi(acikSayi)` → 0 → `✅ Tamamlandı Olarak İşaretle`; >0 → `✅ N alt görevle birlikte tamamla`.
- `grupTamamla` plan saf kısmı: `ayrikKapanacaklar(subs)` → sadece `!tamamlandi && !iptal`.
- `npm run test:unit` → kırmızı → geçecek şekilde ui.js'te fonksiyonları yaz.

### 2. `openTaskDet`: td-subs interaktif render
- Şu anki statik blok (ui.js ~4715-4727) → `renderTaskDetSubs([...subsDone,...subs])`.
- `toggleSubDet(subId, parentId, el)`:
  - `getData('gorev_log')` ile mevcut durumu oku (toggleSub ile aynı semantik),
  - REST PATCH (`write('gorev_log', {...}, 'PATCH', 'id=eq.'+subId)`),
  - modal içi sayaç + buton etiketini güncelle (DOM'da `td-subs` başlığı ve `td-tamam-btn`),
  - son çocuk kapandıysa ana görevi KAPATMA — bunu kullanıcıya "tamamla" butonu yapsın
    (tek aksiyon noktası; mevcut toggleSub'un otomatik parent kapatması kart yolunda kalır),
  - `loadTasks(_curTaskFilter||'today')` ile kartı senkron tut (modal açıkken arka plan).
- K6: üretilen HTML'de attribute onclick + dataset (DOM property yasak).

### 3. `detayTamamla` guard (bölünmenin kapatılması)
`_curTaskDet` için açık alt sorgusu:
```js
const acikAltlar = (await idbGetAll('gorev_log'))
  .filter(s => s.parent_id === _curTaskDet.id && !s.tamamlandi && !s.iptal);
if (acikAltlar.length) return grupTamamla(_curTaskDet, acikAltlar);
```
`grupTamamla(parent, altlar)`:
1. Her alt: REST PATCH `tamamlandi=true, tamamlanma_tarihi=now()` (sıralı; hata → dur + toast).
2. Ana görev: `doneTask(parent.id, ...)` mevcut yolu → RPC `gorev_tamamla` (K3, islem_log izi).
3. Toast: `✅ N alt görev ve ana görev tamamlandı`; `closeM('m-task-det')`;
   `pullTables(['gorev_log'])` + `_islemSonrasiRefresh()` + `loadDash()` (doneTask zaten yapıyor).

### 4. Buton etiketi
`openTaskDet` içinde alt görev sayısı > 0 ise:
`tamamBtn.textContent = '✅ ' + acikAltlar.length + ' alt görevle birlikte tamamla'`.
Alt görevsiz görevlerde mevcut etiket (K4).

### 5. Doğrulama
- [ ] `gitnexus_impact` (openTaskDet, detayTamamla — tekrar, edit sonrası), `grep` taraması
- [ ] `npm run test:unit` → hepsi yeşil (344 + yeni)
- [ ] `gitnexus detect_changes` → beklenen kapsam dışı sembol yok
- [ ] Manuel smoke (lokal `npm run serve:local` + tarayıcı): alt görevli kart aç → checkbox tıkla →
  sayaç/etiket → "tamamla" → grup tamamen kapanıyor; alt görevsiz görev regressionız
- [ ] Canlıda gerçek doğrulama: kullanıcı (3 ve 500 buzağısının gerçek bakımı — test verisi yazma yok)

### 6. Kapanış prosedürü (kullanıcı "iş kapandı" deyince)
1. `detect_changes` + son unit koşusu
2. `idle/buzagi-gorev-modal` → `main` merge (fast-forward bekleniyor; main ilerlemişse merge commit)
3. GitHub Pages push sonrası canlıda kullanıcı doğrulaması
4. `git worktree remove /home/melik/egesut-wt/buzagi-gorev-modal` + branch sil
   (finishing-a-development-branch akışı)

## Riskler ve savunmalar

| Risk | Savunma |
|---|---|
| BESLEME/rapel gruplarına yan etki | K5 tip-agnostik + sadece modal yolu değişir; kart toggleSub yolu dokunulmaz; impact LOW |
| Sıralı PATCH ortasında hata (k lovedan sonra parent kalmaz) | grupTamamla sıralı + hata anında dur + toast; parent kapanmadığı için listede grup kartı açık kalır (bölünme yok) |
| Offline/IDB bayat sayaç | Her toggle'da `getData` ile taze okuma (toggleSub deseni) + iş sonrası pullTables |
| Modal router onclick yarışı | K6 attribute onclick + dataset (684534f deseni) |
