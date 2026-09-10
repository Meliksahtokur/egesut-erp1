# Goal A — Abort sonrası VWP koruması (abort'u mevcut postpartum mekanizmaya bağla)

**Tip:** backend RPC (migration) + frontend form · **Hat:** external worker + izole worktree
**Öncelik:** P1 · **Sahip:** glmf worker W1

## Zorunlu okuma (sadece bu aralıklar — dosyaların tamamını OKUMA)

1. `js/forms.js` satır **570-640** — `abortKaydet()` (şu an `tohumlama_abort` RPC'sini `p_tohumlama_id` + `p_notlar` ile çağırıyor)
2. `js/forms.js` satır **262-340** — `submitInsem()` ve VWP catch bloğu (`VWP_VIOLATION:(\d+):(\d+)` regex parse + `globalThis._vwpOverride` retry akışı)
3. `.claude/goals/assets/tohumlama_kaydet_canli.sql` — **canlı prod gövdesi** (172 satır). Bu dosya gerçekliktir; `ground_truth.sql`'deki kopya BAYATTIR, ona bakma.
4. `.claude/goals/assets/tohumlama_abort_canli.sql` — canlı prod gövdesi (25 satır)

## Ölçülmüş olgular — bunları ARAMA, doğrula ve kullan

| olgu | kaynak |
|---|---|
| Canlı `tohumlama_kaydet(text,date,text,text,text,jsonb,boolean)` imzası | asset dosyası satır 1 |
| Canlı VWP bloğu: `MAX(dogum.tarih)` çapası, `<55` gün + `NOT p_vwp_override` → `RAISE EXCEPTION 'VWP_VIOLATION:%:%'` | asset dosyası ~satır 60-66 |
| `planli_tohumlama_kaydet` `tohumlama_kaydet`'i çağırır → kapı otomatik miras kalır | canlı prod doğrulandı (Mgmt API) |
| `tohumlama` tablosunda `abort_tarihi` kolonu YOK (eklenecek), `abort_notlar` VAR | canlı information_schema |
| Frontend override akışı: confirm → `_vwpOverride=true` → yeniden submit | forms.js 322-335 |
| 2 mevcut Abort kaydı (147: 2026-05-24, 150: 2026-08-26) `islem_log`(tip='ABORT_KAYDI').ref_id ile tohumlama.id'ye bağlı | canlı prod sorgulandı |
| `sessiz_hayvanlar_listele`/`v_eligible` bu goal'e DOKUNMAZ — o başka worker'da | — |

## Sorun

Abort kaydedildiğinde hayvan tohumlamaya hemen uygun hale düşüyor. Doğum sonrası için zaten çalışan VWP (55 gün + override confirm) koruması abort'u tanımıyor. Abort, postpartum korumasına dahil edilmeli — **yeni bir pencere mekanizması YAZMA**, mevcut VWP akışına abort çapası ekle.

## Kapsam — üç adım, fazlası değil

### Adım 1 — Migration: `supabase/migrations/20260830000010_abort_vwp_penceresi.sql`

Tek dosya, sırayla:

a) Kolon:
```sql
ALTER TABLE public.tohumlama ADD COLUMN IF NOT EXISTS abort_tarihi date;
```

b) Backfill (canlıda onaylanmış bulk UPDATE — birebir bu):
```sql
UPDATE public.tohumlama t
SET abort_tarihi = COALESCE((
  SELECT MIN(il.tarih)::date FROM public.islem_log il
  WHERE il.tip = 'ABORT_KAYDI' AND il.ref_id = t.id::text
), t.tarih)
WHERE t.sonuc = 'Abort' AND t.abort_tarihi IS NULL;
```

c) `tohumlama_abort` yeniden tanım — **asset dosyası `tohumlama_abort_canli.sql` taban alınarak minimal diff**:
- İmzaya 3. parametre: `p_abort_tarihi date DEFAULT CURRENT_DATE`
- UPDATE satırı: `SET sonuc = 'Abort', abort_notlar = p_notlar, abort_tarihi = COALESCE(p_abort_tarihi, CURRENT_DATE)`
- islem_log snapshot'ındaki 'tohumlama' guncellenen nesnesine `'abort_tarihi', v_toh.abort_tarihi` ekle (geri_al uyumu için 'onceki' durumu)
- Sonuna: `GRANT EXECUTE ON FUNCTION public.tohumlama_abort(text, text, date) TO anon, authenticated;`
- **Eski 2-parametreli imzayı DROP ETME** (başka çağıranlar olabilir)

d) `tohumlama_kaydet` yeniden tanım — **asset dosyası `tohumlama_kaydet_canli.sql` taban alınarak SADECE şu iki dokunuş** (fazlası Regression üretir):
- DECLARE bloğuna: `v_son_abort date;`
- VWP bloğunun tamamını şununla değiştir (55 gün eşiği ve override davranışı AYNI kalır):
```sql
  SELECT MAX(d.tarih) INTO v_son_dogum FROM public.dogum d WHERE d.anne_id = p_hayvan_id;
  SELECT MAX(t.abort_tarihi) INTO v_son_abort FROM public.tohumlama t
    WHERE t.hayvan_id = p_hayvan_id AND t.sonuc = 'Abort' AND t.abort_tarihi IS NOT NULL;
  IF v_son_abort IS NOT NULL AND (v_son_dogum IS NULL OR v_son_abort > v_son_dogum) THEN
    v_vwp_gun := p_tarih - v_son_abort;
    IF v_vwp_gun < 55 AND NOT p_vwp_override THEN
      RAISE EXCEPTION 'ABORT_VWP_VIOLATION:%:%', v_vwp_gun, 55;
    END IF;
  ELSIF v_son_dogum IS NOT NULL THEN
    v_vwp_gun := p_tarih - v_son_dogum;
    IF v_vwp_gun < 55 AND NOT p_vwp_override THEN
      RAISE EXCEPTION 'VWP_VIOLATION:%:%', v_vwp_gun, 55;
    END IF;
  END IF;
```
- Fonksiyonun geri kalanı (otomatik Boş temizleme, protokol entegrasyonu, islem_log, NOTIFY...) **byte-byte aynı kalır**

Dosya sonuna: `NOTIFY pgrst, 'reload schema';`

### Adım 2 — `js/forms.js` `abortKaydet()`

`prompt()` ile abort tarihi al (mevcut `abort_notlar` prompt'unun hemen üstüne):
- Metin: `'Abort tarihi (YYYY-AA-GG, boş=bugün):'` — varsayılan değer bugün yüklü gelsin
- Girilen değer boşsa `bugün`, doluysa `/^\d{4}-\d{2}-\d{2}$/` ile doğrula; hatalıysa toast + return
- RPC çağrısına `p_abort_tarihi` ekle

### Adım 3 — `js/forms.js` `submitInsem()` VWP catch bloğu

Mevcut `VWP_VIOLATION` regex dalının YANINA aynı desende ikinci dal:
- `const abortMatch = msg.match(/ABORT_VWP_VIOLATION:(\d+):(\d+)/);`
- Confirm metni: `'❗ Abort sonrası VWP dolmadı: X/55 gün.\n\nBu hayvan abort yaptı — yeterli süre geçmemiş.\nYine de kaydetmek istiyor musunuz?'`
- Onaylanırsa aynı `globalThis._vwpOverride = true` + yeniden submit akışı (mevcut dalkiyle birebir aynı)

## Yazma manifesti

```
supabase/migrations/20260830000010_abort_vwp_penceresi.sql (YENİ)
js/forms.js
```
Manifest dışında HİÇBİR dosyaya yazma. `ground_truth.sql`'e DOKUNMA.

## §Kabul

1. `node --check js/forms.js` → exit 0
2. `grep -q "ABORT_VWP_VIOLATION" js/forms.js` → bulur
3. `grep -q "p_abort_tarihi" supabase/migrations/20260830000010_abort_vwp_penceresi.sql` → bulur
4. Migration'da backfill UPDATE'i var (`grep -q "ABORT_KAYDI" supabase/migrations/20260830000010_abort_vwp_penceresi.sql`)
5. `git diff --stat` → yalnız manifest'teki dosyalar
6. `attempts.md` dolu (başarısız yaklaşım yoksa içi tam olarak `## no failed attempts`)
7. Canlı DB'ye HİÇBİR bağlantı kurma denemesi yok (migration dosyası yazar, uygular lead)

## Sınır

- Commit: kendi worktree'inde commit etmekte serbestsin (tek commit, `feat: abort VWP window`); **push YASAK**
- Canlı prod'a (supabase/Mgmt API/psql) erişim YASAK — aletlerin read-only yerel
- Max elapsed: 25 dakika. Takılırsan dur, engeli attempts.md'ye yaz.
