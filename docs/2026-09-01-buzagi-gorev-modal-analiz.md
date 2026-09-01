# Buzağı Bakım Görev Grubu — "Done'da Bölünme" Kök Neden Analizi

> **Tarih:** 2026-09-01 · **Worktree:** `/home/melik/egesut-wt/buzagi-gorev-modal` (`idle/buzagi-gorev-modal`, base `e6d8782`)
> **Şikâyet:** Doğum sonrası toplu açılan buzağı bakım görevleri, "done" yapınca 5-6 ayrı karta bölünüyor; modal'da checkbox ile seçim yapılamıyor.
> **Yöntem:** Kod okuma (ui.js/forms.js/index.html/GT) + canlı DB doğrulama (read-only SELECT) + GitNexus impact.

---

## 1. Veri modeli (canlı doğrulandı)

`dogum_kaydet` her buzağı için **1 ana görev + 6 alt görev** yaratır:

| Satır | gorev_tipi | parent_id | stok_id/miktar |
|---|---|---|---|
| Ana görev "Buzağı İlk Gün Bakımı (kupe)" | `BUZAGI_BAKIM` | — | yok |
| 6 alt görev (Kolostrum, Göbek kordonu, Küpeleme, Ademin, Maya, Probiyotik) | `BUZAGI_BAKIM` (aynı tip!) | ana görev id | yok |

Kaynak: GT `dogum_kaydet` gövdesi (99999999999999_ground_truth.sql:9757-9872).
Canlı kanıt (2026-09-01, read-only SELECT): iki grup da sağlam ve hiçbir üyesi kapanmamış —
`500 → 5bbb03af`, `3 → ba07757c`, her biri 6 açık alt görev. **Bölünme henüz canlıda yaşanmamış**
(`bolunmus_grup = 0`); davranış kod analiziyle kesin tespit edildi, done basılınca oluşacak.

## 2. Bölünme zinciri — kök neden (5 adım)

1. **Ana görev kapanır, altlar açık kalır.** `gorev_tamamla(p_gorev_id, ...)` (GT:6873+) yalnızca
   hedef satırı kapatır; alt görevlere cascade YOK. Alt görevler stok_id'siz olduğu için stok/padok
   yan etkisi de yok; sadece `islem_log('GOREV_TAMAMLA')` yazar.

2. **Trigger altları bilerek muaf tutar.** `_trg_gorev_parent_kapandi` (GT:10703-10769) parent
   kapandığında açık çocukları `iptal=true` yapar — ama yalnızca
   `c.gorev_tipi <> NEW.gorev_tipi` şartıyla. BUZAGI_BAKIM'da ana ve alt aynı tipte olduğundan
   trigger çocuklara dokunmaz (DELETE dalında da BUZAGI_BAKIM açıkça muaf). Bu kısım **yanlış değil**:
   çocuklar gerçek iş kalemleri, iptal edilmemeli.

3. **UI, kapanmış parent'ın çocuklarını top-level karta terfi ettirir.** Görev listesi filtresi
   (`js/ui.js:563`):
   ```js
   data = all.filter(t => !t.tamamlandi && !t.iptal && (t.gorev_tipi==='TEDAVI_SEANS' || !t.parent_id || _doneIds.has(t.parent_id)));
   ```
   Parent `tamamlandi` olduğundan `_doneIds.has(parent_id)` doğru döner → 6 çocuk 6 ayrı kart olur.
   Aynı terfi kalıbı: `updateTaskBadge` (ui.js:807), hayvan detay (ui.js:280-282, 2081-2083).

4. **Modal'da alt görevler statik.** `openTaskDet` (ui.js:4666) `td-subs` içine alt görevleri
   **tıklanamaz** nokta/etiket olarak basar (ui.js:4715 civarı — renkli daire, onclick yok).
   Tek aksiyon "✅ Tamamlandı Olarak İşaretle" (`td-tamam-btn`, index.html:1797 →
   `data-action="detay-tamamla"` → handlers.js:278 → `detayTamamla` ui.js:4864 →
   `doneTask` forms.js:1082 → RPC `gorev_tamamla`).

5. **Net sonuç — "5'e bölünme":** Kullanıcı kart üzerinden 1 maddeyi işaretler (karttaki
   `st-check` checkbox'ı `toggleSub`'u çağırır — bu ÇALIŞIR), sonra modal'dan "✅ Tamamlandı"
   basar → ana görev kapanır, kalan **5 açık alt görev 5 ayrı kart** olarak listeye dökülür.
   Hiç işaretlemeden done basarsa 6'ya bölünür. Toast "✅ Tamamlandı" yanıltıcıdır: aslında
   yalnızca ana görev kapanmıştır, işler hâlâ açıktır.

> Not: Kart üzerindeki satır checkbox'ları (`renderTask` → `toggleSub`, ui.js:663+770) zaten
> çalışıyor ve son çocuk kapanınca parent'ı da REST PATCH ile kapatıyor (ui.js:777-781).
> Eksik olan **modal tarafı**: orada seçim yapılamıyor ve done butonu bölünmeyi tetikliyor.

## 3. Yan bulgular (kapsam notu)

- **`toggleSub` RPC bypass ediyor:** doğrudan REST PATCH (`write('gorev_log', ...)`) —
  `islem_log` GOREV_TAMAMLA izi yazılmıyor. BUZAGI_BAKIM altları stok/padok yan etkisi
  içermediğinden fonksiyonel kayıp yok, sadece denetim izi. Parent'ı kapatırken de REST PATCH
  kullanıyor (RPC değil).
- **`gorev_geri_al` kısıtı:** parent geri alınırken "çocuğu tamamlanmış görev geri alınamaz"
  guard'ı (GT:6842) rapel için yazılmış ama toplu tamamlama sonrası BUZAGI_BAKIM ana görevini
  de bloklar. Bu işin kapsamı dışında; spec'e not düştük.
- **Geçmiş görünümü:** çocuk görevler geçmiş listesine girmiyor (ui.js:3176 `!t.parent_id`
  filtresi, `_gecmisTumu` modu hariç) — tamamlanan kalemler ana görev satırında görünmüyor.
  Kapsam dışı, UX notu.
- **Diğer parent-child tüketicileri (regresyon riski):** BESLEME zinciri (çocuklar aynı tip →
  trigger muafı), rapel (ILERI_GEBE_ASI), TEDAVI_GUN/SEANS. Tasarım tip-agnostik yazılmalı,
  BUZAGI_BAKIM'e özgü `if` ile davranış değişikliği diğer zincirleri kırmamalı.

## 4. GitNexus etki yarıçapı (impact-before-plan)

| Sembol | Upstream çağrıcı | Risk |
|---|---|---|
| `detayTamamla` (ui.js) | 1 — `js/utils/handlers.js:278` (`detay-tamamla` data-action) | LOW |
| `openTaskDet` (ui.js) | 4 — `kaydetTaskEdit`, `go-back`, `submitTaskEdit` zinciri | LOW |
| `toggleSub` (ui.js) | 0 graph çağrıcısı — **inline onclick string'lerinden çağrılıyor** (renderTask üretimi HTML) | LOW |
| `doneTask` (forms.js) | `detayTamamla` + kart ck-btn onclick yolu | LOW (koda görsel) |

⚠️ Graf uyarısı: bu fonksiyonlar üretilen HTML onclick attribute'larından çağrıldığı için
GitNexus graph'ı çağrıcıları göremez; değişiklik sonrası `grep` ile bare-identifier taraması
zorunlu (ZCode oturum kontratı — memory: gitnexus-kontrat).

`gorev_tamamla` RPC'sinin DB tarafı değişmiyor (önerilen çözüm UI-only olduğundan);
`pg_depend` blast radius'u gerekmez.

## 5. Canlı doğrulama komutları (referans)

```sql
-- Bölünmüş grup var mı? (şu an 0)
SELECT count(*) FROM public.gorev_log p
WHERE p.gorev_tipi='BUZAGI_BAKIM' AND p.tamamlandi
  AND EXISTS (SELECT 1 FROM public.gorev_log c
              WHERE c.parent_id=p.id AND NOT c.tamamlandi AND NOT c.iptal);
```

Onarım migration'ı **gerekmiyor** (0 kayıt). Fix sonrası dahi bu sorgu 0 kalmalı
(çözüm, parent'ı çocuklar açıkken kapatmayı imkânsız kılıyor).
