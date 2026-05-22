# ✅ Tohumlama Hard Block + Intercept Modal — Implementasyon Planı (TAMAMLANDI)

> **Durum:** 2026-05-22 tarihinde implemente edildi. Tüm task'ler tamamlandı ve `main`'e push edildi.
>
> Soru varsa devam etmeden önce sor. DB değişikliklerinde onay bekle.

**Hedef:** Tekrar aşım güvenliğini backend'e taşı. Soft-block'u (disabled buton) kaldır. Modal açılmadan önce intercept kontrolü yap.

**Etkilenen dosyalar:**
- `supabase/migrations/20260522000005_tohumlama_kaydet_hardblock.sql` (YENİ)
- `index.html` (soft-block kaldır + m-insem-intercept modal ekle)
- `js/ui.js` (revert + naming + openInsemSafe + call replacement)
- `js/utils/handlers.js` (intercept modal action'ları)

---

## Başlamadan Önce

Sırayla oku:
```bash
cat /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql | sed -n '716,778p'
cat /root/egesut-erp1/.claude/rpc-reference.md
cat /root/egesut-erp1/.claude/domain-rules.md
```

Sonra planı oku. Net olmayan şey varsa sor.

---

## Task 1 — DB: tohumlama_kaydet Hard Block

**Amaç:** 15 gün içinde Bekliyor tohumlama varsa `RAISE EXCEPTION` ile dur. Frontend'i bypass edemez.

**Okuma:**
```bash
sed -n '716,778p' /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql
```

**Uygulama:**

Yeni migration dosyası oluştur ve deploy et:

```
supabase_migrate({sql: `
-- Migration: tohumlama_kaydet_hardblock
-- Amaç: 15 gün içinde Bekliyor tohumlama varsa hard block

CREATE OR REPLACE FUNCTION public.tohumlama_kaydet(
  p_hayvan_id   text,
  p_tarih       date,
  p_sperma      text,
  p_hekim_id    text    DEFAULT NULL,
  p_irk_bilgisi text    DEFAULT NULL
) RETURNS jsonb AS $$
DECLARE
  v_hayvan   record;
  v_yas_gun  integer;
  v_deneme   integer;
  v_toh_id   uuid := gen_random_uuid();
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı');
  END IF;

  -- Erkek kontrolü
  IF v_hayvan.cinsiyet = 'Erkek' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Erkek hayvana tohumlama yapılamaz');
  END IF;

  -- Yaş kontrolü (12 ay = 365 gün)
  IF v_hayvan.dogum_tarihi IS NOT NULL THEN
    v_yas_gun := CURRENT_DATE - v_hayvan.dogum_tarihi;
    IF v_yas_gun < 365 THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan 12 aydan küçük — tohumlama yapılamaz');
    END IF;
  END IF;

  -- Zaten gebe mi?
  IF EXISTS (SELECT 1 FROM public.tohumlama WHERE hayvan_id = p_hayvan_id AND sonuc = 'Gebe') THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan zaten gebe — önce gebeliği kapatın');
  END IF;

  -- ── HARD BLOCK: 15 gün içinde Bekliyor var mı? ───────────────────────────
  IF EXISTS (
    SELECT 1 FROM public.tohumlama
    WHERE hayvan_id = p_hayvan_id
      AND sonuc = 'Bekliyor'
      AND p_tarih - tarih BETWEEN 0 AND 15
  ) THEN
    RAISE EXCEPTION 'Son 15 gün içinde bekleyen tohumlama mevcut — Tekrar Aşım kullanın';
  END IF;

  -- Deneme no
  SELECT COALESCE(MAX(deneme_no), 0) + 1 INTO v_deneme FROM public.tohumlama WHERE hayvan_id = p_hayvan_id;

  -- Tohumlama kaydı
  INSERT INTO public.tohumlama (id, hayvan_id, tarih, sperma, irk_bilgisi, hekim_id, sonuc, deneme_no)
  VALUES (v_toh_id, p_hayvan_id, p_tarih, p_sperma, p_irk_bilgisi, p_hekim_id, 'Bekliyor', v_deneme);

  -- Kontrol görevleri
  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
  VALUES
    (gen_random_uuid(), p_hayvan_id, 'TOHUMLAMA_HAZIRLIK', '21. Gün gebelik kontrolü', p_tarih + 21, false),
    (gen_random_uuid(), p_hayvan_id, 'TOHUMLAMA_HAZIRLIK', '35. Gün gebelik kontrolü', p_tarih + 35, false);

  -- Sperma stok düş (varsa)
  INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
  SELECT s.id, 'Tohumlama', 1,
    'Tohumlama — ' || v_hayvan.kupe_no, false
  FROM public.stok s
  WHERE (s.urun_adi ILIKE '%' || p_sperma || '%' OR s.urun_adi = p_sperma)
    AND s.tur = 'Sperma'
  LIMIT 1;

  RETURN jsonb_build_object('ok', true, 'tohumlama_id', v_toh_id, 'deneme_no', v_deneme);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.tohumlama_kaydet(text,date,text,text,text) TO anon, authenticated;
`})
```

Ardından dosyayı oluştur:
```bash
cat > /root/egesut-erp1/supabase/migrations/20260522000005_tohumlama_kaydet_hardblock.sql << 'SQLEOF'
-- Migration: tohumlama_kaydet_hardblock
-- İçerik: yukarıdaki supabase_migrate ile deploy edilen SQL'in tam kopyası
SQLEOF
```
(İçeriği migration dosyasına yaz — deploy zaten yukarıda yapıldı, dosya sadece repoda iz için)

**Doğrulama:**
```
supabase_rpc({
  function_name: "tohumlama_kaydet",
  params: JSON.stringify({
    p_hayvan_id: "TEST_ID_BEKLIYOR_VAR",
    p_tarih: new Date().toISOString().slice(0,10),
    p_sperma: "test"
  })
})
```
Beklenen: hata `"Son 15 gün içinde bekleyen tohumlama mevcut"` veya ok:false.

Gerçek test için:
```
supabase_query({
  table: "tohumlama",
  filters: "sonuc=eq.Bekliyor",
  select: "hayvan_id,tarih",
  limit: 3
})
```
Bir hayvan_id al, aynı hayvan için 5 gün sonrasına tarihli tohumlama_kaydet RPC çağır.

**Commit:**
```bash
git add supabase/migrations/20260522000005_tohumlama_kaydet_hardblock.sql
git commit -m "feat(db): tohumlama_kaydet hard block — 15 gün içinde Bekliyor varsa RAISE EXCEPTION"
```

---

## Task 2 + Task 3 — Paralel Çalıştır

Bu iki task farklı dosyalara dokunuyor, bağımsız. `/skill:delegate` ile paralel aç.

---

### Task 2 — index.html: Soft-Block Kaldır + Intercept Modal Ekle

Dosya: `index.html` (tek sahip)

**Okuma:**
```bash
grep -n "insem-tekrar-uyari\|insem-submit-btn\|m-insem-intercept\|m-insem-tekrar" \
  /root/egesut-erp1/index.html
```

**Adım A — Soft-block kaldır:**

Line 593 `insem-tekrar-uyari` div'ini tamamen sil:
```
Bul:
      <div id="insem-tekrar-uyari" style="display:none;font-size:.75rem;color:#92400e;background:rgba(245,158,11,.12);border:1px solid rgba(245,158,11,.3);border-radius:8px;padding:8px 10px;margin-bottom:8px">⚠️ Son 15 gün içinde tohumlama mevcut. <b>🔁 Tekrar Aşım</b> butonunu kullanın.</div>
      <button class="btn btn-g" id="insem-submit-btn" data-action="submit-insem">💉 Kaydet + Kontrol Görevleri</button>

Değiştir:
      <button class="btn btn-g" data-action="submit-insem">💉 Kaydet + Kontrol Görevleri</button>
```
(Sadece div satırı silinir ve `id="insem-submit-btn"` kaldırılır — buton aynı kalır)

**Adım B — Intercept modal ekle:**

`m-insem-tekrar` modalinin kapanış `</div></div>` satırından hemen sonra yeni modal ekle:
```html
  <!-- Tohumlama intercept uyarı modalı -->
  <div id="m-insem-intercept" class="modal-overlay" style="display:none">
    <div class="modal" style="max-width:340px">
      <div class="modal-hdr"><span>⚠️ Bekleyen Tohumlama</span><button class="mcls" data-action="close-insem-intercept">✕</button></div>
      <div style="padding:16px">
        <div id="insem-intercept-info" style="font-size:.82rem;color:var(--ink2);margin-bottom:12px;padding:8px 10px;background:rgba(245,158,11,.1);border-radius:8px;border:1px solid rgba(245,158,11,.3)"></div>
        <p style="font-size:.82rem;color:var(--ink2);margin-bottom:16px">Son 15 gün içinde bekleyen tohumlama var. Ne yapmak istersiniz?</p>
        <button class="btn" style="width:100%;margin-bottom:8px;background:var(--amber);color:#fff;border:none;padding:10px;font-weight:700" data-action="intercept-tekrar-asim">🔁 Tekrar Aşım Yap</button>
        <button class="btn btn-o" style="width:100%;padding:10px" data-action="close-insem-intercept">↩️ İptal</button>
      </div>
    </div>
  </div>
```

**Doğrulama:**
```bash
grep -c "insem-tekrar-uyari\|insem-submit-btn" /root/egesut-erp1/index.html
# Beklenen: 0

grep -c "m-insem-intercept\|insem-intercept-info\|intercept-tekrar-asim" /root/egesut-erp1/index.html
# Beklenen: her birinden 1+
```

**Commit:**
```bash
git add index.html
git commit -m "feat(ui): insem intercept modal + soft-block kaldır"
```

---

### Task 3 — ui.js + handlers.js: Revert + Naming + openInsemSafe + Calls

Dosyalar: `js/ui.js`, `js/utils/handlers.js`

**Okuma:**
```bash
grep -n "_checkInsemTekrarMode\|openInsemSafe\|openMWithHayvan.*m-insem\|deneme_no" \
  /root/egesut-erp1/js/ui.js | head -20
grep -n "close-insem\|submit-insem\|intercept" \
  /root/egesut-erp1/js/utils/handlers.js
```

**Adım A — ui.js: _checkInsemTekrarMode çağrısını kaldır (line ~3549):**
```
Bul:
    if(modalId==='m-insem') _checkInsemTekrarMode(kupeNo);

Değiştir: (satırı tamamen sil)
```

**Adım B — ui.js: _checkInsemTekrarMode fonksiyonunu tamamen sil (line ~3554-3571):**
```
Bul ve sil (fonksiyon başından kapanış '}' dahil):
async function _checkInsemTekrarMode(kupeNo){
  const uyari=document.getElementById('insem-tekrar-uyari');
  const btn=document.getElementById('insem-submit-btn');
  if(!uyari||!btn) return;
  // Reset
  uyari.style.display='none'; btn.disabled=false; btn.style.opacity=''; btn.style.cursor='';
  if(!kupeNo) return;
  const hayvan=(getState('animals')||[]).find(a=>a.kupe_no===kupeNo||a.devlet_kupe===kupeNo);
  if(!hayvan) return;
  const tohs=await getData('tohumlama',t=>t.hayvan_id===hayvan.id);
  const bekliyor=tohs.find(t=>t.sonuc==='Bekliyor');
  if(!bekliyor) return;
  const gun=Math.floor((Date.now()-new Date(bekliyor.tarih))/86400000);
  if(gun>=0&&gun<=15){
    uyari.style.display='';
    btn.disabled=true; btn.style.opacity='0.4'; btn.style.cursor='not-allowed';
  }
}
```

**Adım C — ui.js: deneme_no isimlendirme düzelt (line ~1617):**
```
Bul:
    sub=`${data.deneme_no||1}. deneme · <b style="color:${sc}">${data.sonuc||'Bekliyor'}</b>${hkName}`;

Değiştir:
    sub=`${data.deneme_no||1}. Tohumlama · <b style="color:${sc}">${data.sonuc||'Bekliyor'}</b>${hkName}`;
```

**Adım D — ui.js: openInsemSafe + _openInsemIntercept fonksiyonlarını ekle:**

`openTekrarAsim` fonksiyonunun hemen ÖNÜNE ekle:
```js
async function openInsemSafe(kupeNo){
  const hayvan=(getState('animals')||[]).find(a=>a.kupe_no===kupeNo||a.devlet_kupe===kupeNo);
  if(!hayvan){ openMWithHayvan('m-insem','i-hid',kupeNo); return; }
  const tohs=await getData('tohumlama',t=>t.hayvan_id===hayvan.id);
  const bekliyor=tohs.find(t=>t.sonuc==='Bekliyor');
  if(bekliyor){
    const gun=Math.floor((Date.now()-new Date(bekliyor.tarih))/86400000);
    if(gun>=0&&gun<=15){ _openInsemIntercept(hayvan,bekliyor); return; }
  }
  openMWithHayvan('m-insem','i-hid',kupeNo);
}

function _openInsemIntercept(hayvan,bekliyor){
  const gun=Math.floor((Date.now()-new Date(bekliyor.tarih))/86400000);
  const hid=hayvan.kupe_no||hayvan.devlet_kupe||hayvan.id;
  const infoEl=document.getElementById('insem-intercept-info');
  if(infoEl) infoEl.innerHTML=`<b>${hid}</b> — ${bekliyor.sperma||'?'} · <b>${gun}. gün</b> (${(bekliyor.tarih||'').slice(0,10)})`;
  globalThis._insemInterceptHayvan={id:hayvan.id,kupeNo:hid,tohId:bekliyor.id};
  openM('m-insem-intercept');
}
```

**Adım E — ui.js: openMWithHayvan('m-insem') çağrılarını openInsemSafe ile değiştir:**

Tam 5 yer — her birini kontrol ederek değiştir:

1. Line ~777 (bekleyenToh varken "Tohumlama Ekle"):
```
Bul:    onclick="openMWithHayvan('m-insem','i-hid','${hid}')"
Değiştir: onclick="openInsemSafe('${hid}')"
```
Not: Bu aynı string 3 yerde (777, 782, 784) geçiyor. Bağlam farklı olduğundan her birini ayrı değiştir.

Daha güvenli: her birini çevresindeki metinle birlikte bul-değiştir yap:

Line 777:
```
Bul:    <button class="btn btn-g" style="flex:1;padding:9px" onclick="openMWithHayvan('m-insem','i-hid','${hid}')">💉 Tohumlama Ekle</button>`;
    if(_tohGun>=0&&_tohGun<=15){
Değiştir: <button class="btn btn-g" style="flex:1;padding:9px" onclick="openInsemSafe('${hid}')">💉 Tohumlama Ekle</button>`;
    if(_tohGun>=0&&_tohGun<=15){
```

Line 782:
```
Bul:    onclick="openMWithHayvan('m-insem','i-hid','${hid}')">💉 Yeni Tohumlama Ekle</button>`;
Değiştir: onclick="openInsemSafe('${hid}')">💉 Yeni Tohumlama Ekle</button>`;
```

Line 784:
```
Bul:    onclick="openMWithHayvan('m-insem','i-hid','${hid}')">💉 Tohumlama Ekle</button>`;
  }
  h+='</div>';
Değiştir: onclick="openInsemSafe('${hid}')">💉 Tohumlama Ekle</button>`;
  }
  h+='</div>';
```

Line 1349 (görev listesi "Tohumla" butonu):
```
Bul:    onclick="event.stopPropagation();openMWithHayvan('m-insem','i-hid','${kupe}')">💉 Tohumla</button>
Değiştir: onclick="event.stopPropagation();openInsemSafe('${kupe}')">💉 Tohumla</button>
```

Line 3204 (m-toh-det "Yeni Tohumlama" butonu):
```
Bul:  openMWithHayvan('m-insem','i-hid', kupe);
Değiştir:  openInsemSafe(kupe);
```

**Adım F — handlers.js: intercept modal action'larını ekle:**

`'close-tekrar-asim'` satırından sonra ekle:
```js
  'close-insem-intercept': () => closeM('m-insem-intercept'),
  'intercept-tekrar-asim': () => {
    closeM('m-insem-intercept');
    const h=globalThis._insemInterceptHayvan;
    if(h) openTekrarAsim(h.id, h.kupeNo);
  },
```

**Doğrulama:**
```bash
# Kaldırılan fonksiyon yok mu?
grep -c "_checkInsemTekrarMode" /root/egesut-erp1/js/ui.js
# Beklenen: 0

# Eski çağrılar yok mu?
grep -c "openMWithHayvan.*m-insem" /root/egesut-erp1/js/ui.js
# Beklenen: 0

# Yeni fonksiyon var mı?
grep -c "openInsemSafe\|_openInsemIntercept" /root/egesut-erp1/js/ui.js
# Beklenen: 4+ (tanım + çağrılar)

# Syntax kontrolü
node --check /root/egesut-erp1/js/ui.js
node --check /root/egesut-erp1/js/utils/handlers.js
# Beklenen: hiç hata yok
```

**Commit:**
```bash
git add js/ui.js js/utils/handlers.js
git commit -m "feat(ui): openInsemSafe intercept + soft-block revert + deneme_no naming"
```

---

## Task 4 — Push + Son Doğrulama

**Push:**
```bash
git push origin main
```

**Manuel UI testi (tarayıcıda):**
1. 15 gün içinde Bekliyor tohumlaması olan bir hayvan aç
2. "Tohumlama Ekle" butonuna tıkla
3. Beklenen: m-insem-intercept modal açılır (💉 Kaydet formu değil)
4. "🔁 Tekrar Aşım Yap" → m-insem-tekrar açılmalı
5. "↩️ İptal" → modal kapanmalı

**DB testi (hard block):**
```
supabase_rpc({
  function_name: "tohumlama_kaydet",
  params: JSON.stringify({p_hayvan_id:"<bekliyor_olan_hayvan_id>", p_tarih:"<bugunun_tarihi>", p_sperma:"Test"})
})
```
Beklenen: `RAISE EXCEPTION` — "Son 15 gün içinde bekleyen tohumlama mevcut — Tekrar Aşım kullanın"

**Tamamlanma raporu:**
```
TAMAMLANDI

Task 1 — Hard block migration: ✅ [commit hash]
Task 2 — index.html intercept modal: ✅ [commit hash]
Task 3 — ui.js + handlers.js: ✅ [commit hash]
Task 4 — Push: ✅

DB doğrulama: [hard block test sonucu]
UI doğrulama: [intercept modal çalıştı mı]
Açık soru: [varsa yaz]
```
