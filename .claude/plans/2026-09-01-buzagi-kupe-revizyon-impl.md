# Buzağı Küpe Revizyonu — Implementation Plan

> **REQUIRED SUB-SKILL:** subagent-driven-development (implementer subagent + iki aşamalı review).
> Spec: `.claude/specs/2026-09-01-buzagi-kupe-revizyon-kararlar.md` (K1-K12 FİNAL) · Worktree: `/home/melik/egesut-wt/buzagi-kupe-revizyon`
> Test komutu (worktree'de node_modules YOK): `NODE_PATH=/home/melik/egesut-erp1/node_modules node --test tests/unit/*.test.js`

**Goal:** Çıkmış hayvan küpe recycle + erkek 500-599 zorunluluğu + boş küpe öneri butonu + aktif-öncelik arama.

**Blast radius (gitnexus_impact, 2026-09-01):** `_kupeKontrolEt` LOW (0 çağıran — blur handler), `openDetByKupe` LOW (0 çağıran). SQL RPC'ler graph dışı; `kupe_musait_mi` çağıranları: `hayvan_ekle` (legacy), `_kupeKontrolEt`; `dogum_kaydet` çağıranı: `submitBirth` (forms.js:155).

---

### Task 1 — Migration: `supabase/migrations/20260901000001_kupe_revizyon.sql`

**TDD scenario:** Modifying tested code — mevcut testler sonunda koşar; SQL için test = deploy öncesi dublikasyon taraması (orchestrator yapar).

**Steps:**
1. Dosyayı oluştur, `BEGIN; ... COMMIT;` içinde:

   **1a. `kupe_musait_mi` (imza AYNEN — PostgREST overload çözümü bozulmasın):**
   ```sql
   CREATE OR REPLACE FUNCTION public.kupe_musait_mi(
     p_kupe_no text, p_devlet_kupe text, p_hayvan_id text DEFAULT NULL)
   RETURNS jsonb AS $func$
   DECLARE
     v_aktif_cakisma text; v_devlet_cakisma text;
     v_gecmis_id text; v_gecmis_durum text;
   BEGIN
     IF p_kupe_no IS NOT NULL AND p_kupe_no <> '' THEN
       SELECT id INTO v_aktif_cakisma FROM public.hayvanlar
        WHERE kupe_no = p_kupe_no AND durum = 'Aktif'
          AND (p_hayvan_id IS NULL OR id <> p_hayvan_id) LIMIT 1;
       IF v_aktif_cakisma IS NULL THEN
         SELECT id, durum INTO v_gecmis_id, v_gecmis_durum FROM public.hayvanlar
          WHERE kupe_no = p_kupe_no AND durum IS DISTINCT FROM 'Aktif'
            AND (p_hayvan_id IS NULL OR id <> p_hayvan_id)
          ORDER BY cikis_tarihi DESC NULLS LAST LIMIT 1;
       END IF;
     END IF;
     IF p_devlet_kupe IS NOT NULL AND p_devlet_kupe <> '' THEN
       SELECT id INTO v_devlet_cakisma FROM public.hayvanlar
        WHERE devlet_kupe = p_devlet_kupe
          AND (p_hayvan_id IS NULL OR id <> p_hayvan_id) LIMIT 1;
     END IF;
     RETURN jsonb_build_object(
       'musait', (v_aktif_cakisma IS NULL AND v_devlet_cakisma IS NULL),
       'kupe_cakisma_id', v_aktif_cakisma,
       'kupe_gecmis_id', v_gecmis_id,
       'kupe_gecmis_durum', v_gecmis_durum,
       'devlet_cakisma_id', v_devlet_cakisma);
   END; $func$ LANGUAGE plpgsql;
   ```

   **1b. `dogum_kaydet`:** Gövdeyi `99999999999999_ground_truth.sql`'deki kanonik halden KOPYALA, yalnızca şu iki yeri değiştir:
   - Dup check satırı → `SELECT id INTO v_dup FROM public.hayvanlar WHERE (kupe_no = p_kupe AND durum = 'Aktif') OR devlet_kupe = p_kupe LIMIT 1;`
   - Dup check'ten HEMEN SONRA erkek kuralı:
   ```sql
   IF p_cins = 'Erkek' AND p_kupe ~ '^[0-9]+$'
      AND (p_kupe::int < 500 OR p_kupe::int > 599) THEN
     RETURN jsonb_build_object('ok', false, 'mesaj',
       'Erkek buzağı küpesi 500-599 aralığında olmalı (girilen: ' || p_kupe || ')');
   END IF;
   ```

   **1c. Partial unique index:**
   ```sql
   CREATE UNIQUE INDEX IF NOT EXISTS hayvanlar_kupe_no_key
     ON public.hayvanlar (kupe_no)
    WHERE durum = 'Aktif' AND kupe_no IS NOT NULL AND kupe_no <> '';
   ```

   **1d. h11 overload'larına kontrol:** `20260706000006_h11_hayvan_yas_grup_validasyon.sql` içindeki `hayvan_ekle` (:22) ve `hayvan_guncelle` (:94) gövdelerini aynen KOPYALA; `hayvan_ekle` gövdesinin başına (INSERT'ten önce):
   ```sql
   SELECT public.kupe_musait_mi(p_kupe_no, p_devlet_kupe) INTO v_chk;
   IF NOT (v_chk->>'musait')::boolean THEN
     RETURN jsonb_build_object('ok', false, 'mesaj',
       CASE WHEN v_chk->>'kupe_cakisma_id' IS NOT NULL
         THEN 'İşletme küpesi zaten kayıtlı (aktif): ' || COALESCE(p_kupe_no,'')
         ELSE 'Devlet küpesi zaten kayıtlı: ' || COALESCE(p_devlet_kupe,'') END);
   END IF;
   ```
   (`DECLARE v_chk jsonb;` ekle.) `hayvan_guncelle`'e aynı kontrol `p_hayvan_id = p_id` ile (kupe/devlet NULL ise atla).
   **DİKKAT:** Bu iki fonksiyonun h11'deki parametre listeleri ve GRANT satırları birebir korunmalı (PostgREST overload çözümü argüman adlarına bağlı).

   **1e. `asistan_hayvan_detay`:** Kanonik gövdeyi KOPYALA, ana SELECT'e sıralama ekle:
   `... ORDER BY (durum = 'Aktif') DESC, id LIMIT 1;`

   **1f.** `NOTIFY pgrst, 'reload schema';` + `COMMIT;`

2. Commit: `feat(db): küpe revizyon migration — recycle (aktif-filtre), erkek 500-599, partial unique index, h11 kontrolü, asistan aktif-öncelik`

### Task 2 — config.js saf fonksiyonlar + unit test (TAM TDD)

**Files:** Modify `js/config.js`; Create `tests/unit/kupe-oneri.test.js` (loader deseni için `tests/unit/config.test.js`'e bak — vm loader `tests/unit/support/loadModule.js`).

**Step 1 — failing test** (kısa örnekler): erkek→[500..599] ilk boşlar ascending; dişi→5xx atlar, 1'den başlar ascending; aktif "02"→2'yi bloklar (sayısal uzay); çıkmış (durum≠Aktif) bloklamaz; `erkekKupeUygunMu('612','Erkek')===false`, `('612','Dişi')===true`, `('Test','Erkek')===true` (sayısal değil).
**Step 2** — koş, FAIL gör. **Step 3** — `js/config.js`'e ekle:
```js
// Küpe numara planı (spec 2026-09-01, K5/K10/K11)
const KUPE_ERKEK_MIN = 500, KUPE_ERKEK_MAX = 599;
function erkekKupeUygunMu(kupe, cinsiyet) {
  if (cinsiyet !== 'Erkek' || !/^\d+$/.test(String(kupe || ''))) return true;
  const n = parseInt(kupe, 10);
  return n >= KUPE_ERKEK_MIN && n <= KUPE_ERKEK_MAX;
}
function bosKupeOner(hayvanlar, cinsiyet, adet = 10) {
  const dolu = new Set((hayvanlar || [])
    .filter(a => a && a.durum === 'Aktif' && a.kupe_no && /^\d+$/.test(String(a.kupe_no)))
    .map(a => parseInt(a.kupe_no, 10)));
  const erkek = cinsiyet === 'Erkek';
  const out = [];
  for (let n = erkek ? KUPE_ERKEK_MIN : 1; n <= (erkek ? KUPE_ERKEK_MAX : 999) && out.length < adet; n++) {
    if (!erkek && n >= KUPE_ERKEK_MIN && n <= KUPE_ERKEK_MAX) continue;
    if (!dolu.has(n)) out.push(String(n));
  }
  return out;
}
```
**Step 4** — testler PASS. **Step 5** — Commit: `feat(kupe): bosKupeOner + erkekKupeUygunMu (K5/K10/K11) + unit testler`

### Task 3 — forms.js doğrulama katmanı

**Files:** Modify `js/forms.js` (`_kupeKontrolEt` :26-57, `submitAnimal` :59+, `submitBirth` :155+), `index.html` (b-kupe yanına warn elementi), `tests/unit/forms-validation.test.js`.

1. `_kupeKontrolEt` üç durumlu: `musait===false` → `⚠️ Bu küpe zaten kayıtlı (aktif hayvan)` (engel, soft YOK); `musait!==false && res.data.kupe_gecmis_id` → `ℹ️ Bu numara geçmişte kullanılmış ({kupe_gecmis_durum}) — yeniden kullanılabilir` + `dataset.soft='1'` (engel değil); else temizle. `alan==='b-kupe'` desteği: params'ta `p_kupe_no` alan adından bağımsız set et (b-kupe işletme küpesi), warn id `b-kupe-warn`.
2. `index.html`: `b-kupe` input'una `onblur="_kupeKontrolEt('b-kupe')"` desenini mevcut `a-kupe` bağlama biçimiyle uyumlu ekle (a-kupe nasıl bağlıysa — HTML attribute onclick/blur pattern, DOM property DEĞİL) + `b-kupe-warn` için küçük warn div (a-kupe-warn markup'ını örnek al).
3. `submitBirth`: `submitAnimal`'daki `_kupeUyarisi` desenini kullanarak `b-kupe-warn` engel kontrolü + erkek sert engel:
   ```js
   if (!erkekKupeUygunMu(kupe, cins)) { toast('⚠️ Erkek buzağı küpesi 500-599 aralığında olmalı', true); return; }
   ```
4. `submitAnimal`: erkek + sayısal + 5xx dışı → `toast('⚠️ Erkek hayvan küpesi için 500-599 aralığı önerilir')` ama DEVAM (engel yok, K5).
5. `forms-validation.test.js` güncelle: mock `kupe_musait_mi` senaryolarına `kupe_gecmis_id` durumunu ekle (bilgi mesajı + soft flag).
6. Testler PASS → Commit: `feat(kupe): üç durumlu küpe kontrolü + doğum formu ön kontrolü + erkek 5xx kuralları (K5)`

### Task 4 — "Boş küpeler" butonu + aktif-öncelik sweep

**Files:** Modify `index.html`, `js/forms.js` veya `js/ui.js` (buton handler), `js/ui.js:2451,2046`, `js/forms.js:169,286,427,550,974,1010,1077`.

1. **Buton (K6):** `b-kupe` ve `a-kupe` input'larının yanına `💡` butonu (`id="b-kupe-oner"`, `id="a-kupe-oner"`), **HTML attribute onclick** ile global fn çağırır (modal router kuralı — DOM property onclick YASAK). Handler (ui.js'e, mevcut desenlere uygun):
   - cinsiyeti eş select'ten oku (`b-cins` / `a-cinsiyet`; manuel formda cinsiyet boşsa Dişi havuzu göster + not)
   - `bosKupeOner(getState('animals'), cins)` → sayfa içinde küçük popover/chip listesi (mevcut chip/dropdown CSS sınıflarını kullan; yeni ağır stil YOK)
   - chip tıklanınca → input'a yaz + `_kupeKontrolEt` tetikle + kapat. Chip'ler de HTML attribute onclick (inline `onclick="kupeOnerSec('b-kupe','321')"`) veya event delegation — modal güvenliği açısından attribute/delegation öner.
2. **Aktif-öncelik (K7):** ortak helper (app.js veya ui.js):
   ```js
   function hayvanByKupeRef(ref) {
     const L = getState('animals') || [];
     const hit = a => a && (a.kupe_no === ref || a.devlet_kupe === ref || a.id === ref);
     return L.find(a => hit(a) && a.durum === 'Aktif') || L.find(hit);
   }
   ```
   Listedeki 9 çağrı noktasındaki `find(a => a.id===x || a.kupe_no===x || a.devlet_kupe===x)` desenini bu helper ile değiştir (davranış: id eşleşmesi aynen; küpe eşleşmesinde aktif önce). Global arama kutusu (`#srch`) DEĞİŞMEZ — her iki eşleşme de listelenebilir.
3. Mevcut testler PASS (+ forms-validation'da etkilenen varsa güncelle) → Commit: `feat(kupe): boş küpe öneri butonu (K6) + aktif-öncelik küpe arama sweep'i (K7)`

### Task 5 — Dokümantasyon + tam test

1. `.claude/domain-rules.md`: "Küpe Numara Planı (2026-09-01)" bölümü — erkek yeni doğum 500-599 zorunlu; dişi 1-999 (5xx hariç) serbest, öneri küçükten büyüğe; recycle: çıkmışın numarası hemen kullanılabilir; devlet küpesi ömür boyu global teklik; sıfır-trick (02/002) bilinçli özellik, normalizasyon YASAK; mevcut erkeklere dokunulmaz.
2. `.claude/rpc-reference.md`: `kupe_musait_mi` (yeni `kupe_gecmis_id/kupe_gecmis_durum` alanları, aktif-filtre), `dogum_kaydet` (erkek 5xx kuralı + aktif-filtre), `hayvan_ekle`/`hayvan_guncelle` (h11 overload artık kontrol ediyor), `asistan_hayvan_detay` (aktif-öncelik), yeni index `hayvanlar_kupe_no_key`.
3. `NODE_PATH=... node --test tests/unit/*.test.js` → 302+ PASS.
4. Commit: `docs(kupe): domain-rules numara planı + rpc-reference güncellemesi`

---

## Rollout (orchestrator yapar — subagent DEĞİL)

1. Aktif küpe dublikasyon taraması (canlı, read-only) → 0 beklenir (`002`≠`02` string farklı).
2. `supabase_migrate` ile migration deploy (kullanıcı canlı test akışı gereği; raporlanır).
3. Merge `idle/buzagi-kupe-revizyon` → `main` + push (GitHub Pages JS'i yayınlar; CI Playwright koşar).
4. Kullanıcı canlı test → onay → worktree kapanır (`finishing-a-development-branch`).

## Rollback

- Fonksiyonlar `CREATE OR REPLACE` — eski gövdeler GT'de mevcut, geri alınabilir.
- Index: `DROP INDEX IF EXISTS public.hayvanlar_kupe_no_key;`
- JS: merge revert.
