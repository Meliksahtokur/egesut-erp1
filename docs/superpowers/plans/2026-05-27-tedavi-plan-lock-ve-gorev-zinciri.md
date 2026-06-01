# Tedavi Modal Lock Fix + Görev Zinciri — İmplementasyon Planı

> Topoloji: Hierarchical | 7 task | 1 paralel blok (Task 4+5)
> Model: deepseek-chat (flash) — aksi belirtilmedi
> Soru varsa devam etmeden önce sor. DB değişikliklerinde onay bekle.

**Hedef:** (Faz 1) Tedavi modalında kilitli günlere ilaç planlaması yazılabilsin — done sıralaması bozulmadan. (Faz 2) Görev sistemiyle tam entegrasyon — done işlemi görev kartından.
**Etkilenen dosyalar (Faz 1):** `js/ui.js`
**Etkilenen dosyalar (Faz 2):** `js/ui.js`, `supabase/migrations/`

---

## Başlamadan Önce

Sırayla oku:
1. `cat /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql`
2. `cat /root/egesut-erp1/.claude/rpc-reference.md`
3. `cat /root/egesut-erp1/.claude/domain-rules.md`

Sonra planı oku, net olmayan şey varsa sor.

---

# FAZ 1 — HIZLI FIX (Lock sadece done'ı engeller, plan yazmayı değil)

## Mevcut Bug Analizi

`js/ui.js` `renderCaseTimeline` fonksiyonunda (satır 2808–2869):

```
day._locked = lockAktif && idx > 0 && !sortedDays[idx-1].tamamlandi  ← satır 2812
```

Lock iki şeyi birden engelliyor:
1. `openAttr` (satır 2833): Kilitli günler otomatik kapalı başlar ✓ sorunsuz
2. `actionsHtml` (satır 2862): `aktif && !isDone && !isLocked ? ...` — ilaç ekleme dahil TÜM aksiyon butonları saklanıyor ✗ BUG

**Hedef davranış:**
- `+ İlaç`, `📝 Not`: Her aktif non-done günde görünür (locked bile olsa)
- `✅ Tamamla`: Sadece locked değilse görünür

---

## Task 1 — ui.js Lock Fix

**Okuma:**
```bash
sed -n '2807,2870p' /root/egesut-erp1/js/ui.js
```
Bulunacak kod bloğu (satır 2812 ve 2862 arası) — değiştirilecek iki yer.

**Uygulama:**

`js/ui.js` dosyasını doğrudan edit et (Read + Edit tool kullan):

**Değişiklik 1 — openAttr (satır 2833):**

Mevcut:
```js
const openAttr = (aktif && !isDone && !isLocked && day === sortedDays.find(d => !d.tamamlandi && !d._locked)) ? 'open' : '';
```

Yeni (kilitli günler de açılabilir — ilk tamamlanmamış gün açık başlar):
```js
const openAttr = (aktif && !isDone && day === sortedDays.find(d => !d.tamamlandi)) ? 'open' : '';
```

**Değişiklik 2 — actionsHtml bloğu (satır 2862–2869):**

Mevcut tek blok:
```js
const actionsHtml = aktif && !isDone && !isLocked ? `
  <div class="cd-acc-actions">
    <button onclick="caseDayTamamla('${day.day_id}')" ...>✅ Tamamla</button>
    <button onclick="caseDayNotAcById('${day.day_id}')" ...>📝 Not</button>
    <button onclick="caseDrugFormAc('${day.day_id}')" ...>+ İlaç</button>
    <button onclick="caseDaySaatAc('${day.day_id}','${day.time||''}')" ...>🕐</button>
    <button onclick="caseDaySil('${day.day_id}')" ...>🗑</button>
  </div>` : '';
```

Yeni iki ayrı blok:
```js
// Planlama butonları — lock durumundan bağımsız (tüm aktif non-done günlerde)
const planHtml = aktif && !isDone ? `
  <div style="display:flex;gap:6px;flex-wrap:wrap;margin-top:6px">
    <button onclick="caseDrugFormAc('${day.day_id}')" style="background:var(--blue);color:#fff;border:none;border-radius:8px;padding:7px 12px;font-size:.78rem;cursor:pointer">+ İlaç</button>
    <button onclick="caseDayNotAcById('${day.day_id}')" style="background:var(--card2);color:var(--ink);border:1px solid var(--card3);border-radius:8px;padding:7px 12px;font-size:.78rem;cursor:pointer">📝 Not</button>
  </div>` : '';

// Done butonu — sadece locked değilse
const doneHtml = aktif && !isDone && !isLocked ? `
  <div style="display:flex;gap:6px;flex-wrap:wrap;margin-top:6px">
    <button onclick="caseDayTamamla('${day.day_id}')" style="background:var(--green);color:#fff;border:none;border-radius:8px;padding:7px 14px;font-size:.78rem;font-weight:700;cursor:pointer">✅ Tamamla</button>
    <button onclick="caseDaySaatAc('${day.day_id}','${day.time||''}')" style="background:none;border:1px solid var(--card3);border-radius:8px;padding:7px 10px;font-size:.78rem;color:var(--ink3);cursor:pointer">🕐</button>
    <button onclick="caseDaySil('${day.day_id}')" style="background:rgba(192,50,26,.08);color:var(--red);border:1px solid rgba(192,50,26,.18);border-radius:8px;padding:7px 10px;font-size:.78rem;cursor:pointer">🗑</button>
  </div>` : (aktif && !isDone && isLocked ? `
  <div style="margin-top:4px">
    <span style="font-size:.7rem;color:var(--ink3)">⏳ Önceki günü tamamla</span>
  </div>` : '');

const actionsHtml = planHtml + doneHtml;
```

**Önemli:** HTML template'de `${actionsHtml}` zaten kullanılıyor (satır 2893) — değiştirilmez.

**Doğrulama:**
```bash
node --check /root/egesut-erp1/js/ui.js
```
Hata yoksa devam et.

**Commit:**
```bash
git add js/ui.js && git commit -m "fix(tedavi): plan/done ayrımı — kilitli günlere ilaç yazılabilsin"
```

**Checkpoint:**
```
memory_add({content: "Faz 1 tamamlandı: renderCaseTimeline lock fix — planHtml/doneHtml ayrıldı. actionsHtml → planHtml+doneHtml. openAttr locked günleri de açar.", category: "code_change", priority: "medium", tags: "tedavi,lock,fix"})
```

---

# FAZ 2 — GÖREV ZİNCİRİ (Plan → Otomatik görev oluştur, done görevden)

> Faz 1 tamamlandıktan sonra başla.

## Mimari Hedef

```
Kullanıcı → Tedavi modalı → Gün ekle (sadece plan)
  └─ add_treatment_day RPC → treatment_days + gorev_log (TEDAVI_GUN tipi)

Kullanıcı → Görev listesi → TEDAVI_GUN kartı → ✅ Done
  └─ treatment_day_tamamla(day_id) + gorev tamamla
  └─ Sonraki günün görevi aktif olur (sequential unlock)
```

## Task 2 — DB Okuma (Görev Sistemi Analizi)

**Okuma:**
```
supabase_query({table: "gorev_log", filters: "gorev_tipi=eq.TEDAVI_GUN", limit: 5})
```
→ Eğer `TEDAVI_GUN` tipi yoksa: 0 kayıt döner, yeni tip ekleneceğini not et.

```
supabase_query({table: "gorev_log", limit: 3, select: "*"})
```
→ Mevcut kolonları gör: `gorev_tipi`, `ref_id`, `ref_tablo`, `hedef_tarih`, `aciklama`, `tamamlandi` kolonlarını not et.

```
supabase_query({table: "treatment_days", limit: 3, select: "*"})
```
→ `id`, `case_id`, `day_no`, `treatment_date` kolonlarını doğrula.

**Hiçbir şey yazma bu task'ta — sadece oku.**

---

## Task 3 — DB Migration: add_treatment_day → gorev_log entegrasyonu

**Okuma (önce):**
```bash
grep -n "add_treatment_day" /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql
```
Mevcut `add_treatment_day` fonksiyonunun tam tanımını bul.

**Uygulama:**

Aşağıdaki migration'ı `supabase_migrate` ile deploy et:

```sql
-- Faz 2: add_treatment_day → gorev_log TEDAVI_GUN entegrasyonu
-- add_treatment_day'e otomatik gorev oluşturma trigger'ı

CREATE OR REPLACE FUNCTION public.add_treatment_day(
  p_case_id uuid,
  p_date    date
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_day_id  uuid;
  v_day_no  int;
  v_case    record;
  v_gorev_id uuid;
BEGIN
  -- Mevcut day_no hesapla
  SELECT COALESCE(MAX(day_no), 0) + 1 INTO v_day_no
  FROM public.treatment_days
  WHERE case_id = p_case_id;

  -- Treatment day ekle
  INSERT INTO public.treatment_days(id, case_id, day_no, treatment_date)
  VALUES (gen_random_uuid(), p_case_id, v_day_no, p_date)
  RETURNING id INTO v_day_id;

  -- Case bilgisi al
  SELECT c.animal_id INTO v_case FROM public.cases c WHERE c.id = p_case_id;

  -- Gorev_log'a TEDAVI_GUN görevi ekle
  INSERT INTO public.gorev_log(
    id, gorev_tipi, ref_id, ref_tablo,
    hayvan_id, hedef_tarih, aciklama,
    tamamlandi, olusturma_tarihi
  ) VALUES (
    gen_random_uuid(),
    'TEDAVI_GUN',
    v_day_id::text,
    'treatment_days',
    v_case.animal_id,
    p_date,
    'Gün ' || v_day_no || ' tedavisi — ' || to_char(p_date, 'DD.MM.YYYY'),
    false,
    NOW()
  );

  RETURN jsonb_build_object('ok', true, 'day_id', v_day_id, 'day_no', v_day_no);
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_treatment_day(uuid, date) TO anon, authenticated;
```

> ⚠️ NOT: Bu RPC'nin mevcut imzasını ground_truth.sql'den oku. Kolon adları farklıysa uyarla.
> `gorev_log` tablosunda `hayvan_id` kolonu yoksa `ref_id` yeterlidir — o satırı kaldır.

**Doğrulama:**
```
supabase_rpc({function_name: "add_treatment_day", params: '{"p_case_id":"TEST_CASE_ID","p_date":"2026-05-30"}'})
```
→ `{ok: true, day_id: "...", day_no: N}` beklenir.

```
supabase_query({table: "gorev_log", filters: "gorev_tipi=eq.TEDAVI_GUN", limit: 5})
```
→ Oluşan görev görünmeli.

**Checkpoint:**
```
memory_add({content: "Faz 2 Task 3 tamamlandı: add_treatment_day TEDAVI_GUN gorev_log entegrasyonu", category: "code_change", priority: "medium", tags: "tedavi,gorev,migration"})
```

---

## Task 4 + Task 5 — Paralel Çalıştır

> Bağımsız task'lar — `/skill:delegate` ile paralel aç.
> Dosya sahipliği: Task 4 → `js/ui.js` (gorev render) | Task 5 → `js/ui.js` (tedavi modal)
> Her ikisi aynı dosyada — PARALEL YAZMA YASAK. Sırayla yap: önce Task 4 kaydet, sonra Task 5.

### Task 4 — Görev Kartında TEDAVI_GUN Render

**Okuma:**
```bash
grep -n "TEDAVI_GUN\|gorev_tipi\|loadTasks\|renderGorevler\|gorev.*kart" /root/egesut-erp1/js/ui.js | head -30
```
→ Görev kartlarının nasıl render edildiğini bul (render fonksiyonu, gorev_tipi switch/if bloğu).

**Uygulama:**

Görev kartı render fonksiyonunda `TEDAVI_GUN` tipini işle:

```js
// Mevcut görev tipi switch'ine eklenecek case:
case 'TEDAVI_GUN': {
  const dayId = gorev.ref_id;  // treatment_days.id
  ikonHtml = '💊';
  tipLabel = 'Tedavi';
  // Done butonu: sadece kilitli değilse
  // Kilitli kontrol: önceki TEDAVI_GUN görevi (aynı case) tamamlanmamışsa locked
  const oncekiTamamlandi = /* önceki gün görevi done mu? */ true; // basit: her zaman göster, RPC sequential kontrolü yapıyor
  doneHtml = !gorev.tamamlandi ? `
    <button onclick="gorevTedaviGunDone('${gorev.id}','${dayId}')"
      style="background:var(--green);color:#fff;border:none;border-radius:8px;padding:6px 14px;font-size:.78rem;font-weight:700;cursor:pointer">
      ✅ Tamamla
    </button>` : '';
  break;
}
```

**Yeni fonksiyon ekle (gorev tipi handler'ının yanına):**

```js
async function gorevTedaviGunDone(gorevId, dayId) {
  try {
    // 1. Treatment day'i tamamla (sequential kontrolü RPC yapar)
    await rpc('treatment_day_tamamla', { p_day_id: dayId, p_not: null });
    // 2. Görevi de tamamla
    await rpc('gorev_tamamla', { p_gorev_id: gorevId });
    toast('✅ Tedavi günü tamamlandı');
    await pullTables(['treatment_days', 'gorev_log']);
    renderSafe();
    // Tedavi modal açıksa güncelle
    if (_curCase) await renderCaseTimeline(_curCase.id);
  } catch(e) {
    toast('❌ ' + e.message, true);
  }
}
```

> ⚠️ `gorev_tamamla` RPC adını ground_truth.sql'den doğrula. Farklıysa uyarla.
> `treatment_day_tamamla` zaten sequential kontrolü yapıyor — "önceki bitmeden" hatası fırlatır, `catch` bunu yakalar.

**Doğrulama (node --check):**
```bash
node --check /root/egesut-erp1/js/ui.js
```

### Task 5 — Tedavi Modalında ✅ Tamamla Butonunu Kaldır

> Faz 2'de done işlemi görevden yapılıyor. Modal'dan Tamamla butonu kaldırılır.

**Okuma:**
```bash
sed -n '2860,2870p' /root/egesut-erp1/js/ui.js
```
Faz 1 değişikliği sonrası `doneHtml` bloğunu bul.

**Uygulama:**

`doneHtml` bloğundaki `✅ Tamamla` butonunu kaldır. Kilitli mesaj bırak, `🕐` ve `🗑` bırak:

```js
// Faz 2: done butonu kaldırıldı — görev listesinden yapılıyor
const doneHtml = aktif && !isDone ? `
  <div style="display:flex;gap:6px;flex-wrap:wrap;margin-top:6px">
    <button onclick="caseDaySaatAc('${day.day_id}','${day.time||''}')" style="background:none;border:1px solid var(--card3);border-radius:8px;padding:7px 10px;font-size:.78rem;color:var(--ink3);cursor:pointer">🕐</button>
    <button onclick="caseDaySil('${day.day_id}')" style="background:rgba(192,50,26,.08);color:var(--red);border:1px solid rgba(192,50,26,.18);border-radius:8px;padding:7px 10px;font-size:.78rem;cursor:pointer">🗑</button>
    ${isLocked ? '<span style="font-size:.7rem;color:var(--ink3)">⏳ Görev listesinden tamamla</span>' : ''}
  </div>` : '';
```

**Doğrulama:**
```bash
node --check /root/egesut-erp1/js/ui.js
```

---

## Task 6 — Faz 2 Entegrasyon Testi

**Manuel test (canlı sistemde):**
1. Vaka aç → "Gün Ekle" ile 3 gün ekle
2. `supabase_query({table: "gorev_log", filters: "gorev_tipi=eq.TEDAVI_GUN", limit: 5})` → 3 görev görünmeli
3. 1. günün görev kartından "✅ Tamamla" butonuna tıkla
4. `supabase_query({table: "treatment_days", filters: "tamamlandi=eq.true"})` → 1 kayıt
5. Tedavi modalında 1. gün ✅, 2. gün aktif, 3. gün kilitli görünmeli

**Commit:**
```bash
git add js/ui.js supabase/migrations/ && git commit -m "feat(tedavi): Faz 2 — görev zinciri, TEDAVI_GUN tipi, gorev kartında done"
```

---

## Son Task — Pattern Kayıt

Plan tamamlandıktan sonra:
```
memory_add({
  content: "Tedavi modal lock fix + görev zinciri: Faz 1 = planHtml/doneHtml ayrımı (sadece ui.js). Faz 2 = add_treatment_day→TEDAVI_GUN gorev, done modal değil görevden. treatment_day_tamamla sequential kontrolü RPC'de, UI'da tekrar yapılmıyor.",
  category: "code_change",
  priority: "medium",
  tags: "plan,tedavi,lock,gorev,zincir"
})
```

---

## Referans Bilgileri (araştırma özeti)

| Sembol | Dosya | Satır |
|--------|-------|-------|
| `renderCaseTimeline` | `js/ui.js` | 2749 |
| `day._locked` hesabı | `js/ui.js` | 2812 |
| `actionsHtml` (değiştirilecek) | `js/ui.js` | 2862 |
| `openAttr` (değiştirilecek) | `js/ui.js` | 2833 |
| `caseDayTamamla` → `treatment_day_tamamla` RPC | `js/ui.js` | 2937 |
| `caseGunEkleOnayla` → `add_treatment_day` RPC | `js/ui.js` | 3091 |
| `hstIlacEkle` | `js/forms.js` | 1269 |
| `islemGeriAl` (mevcut geri alma) | `js/forms.js` | 1071 |
