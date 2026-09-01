# İkiz / Çoklu Doğum Modeli — Spec

Tarih: 2026-09-01 · Worktree: `ikiz-dogum-modeli` (main @ 97bcd8b) · Durum: **CANLIDA + KULLANICI TESTİ BAŞARILI (2026-09-01)** — deploy `supabase_migrate`, merge `048b39c`, push origin/main; 901/77-78 backfill doğrulandı, triaj smoke `dogum_sayisi:1`. Sonradan: `gorev_sayisi` sayım düzeltmesi (10+7=17; canlı+GT) ve paralel küpe-revizyon akışının K1/K5 kurallarıyla birleşik canlı gövde (`20260901000002` bazlı).

## Sorun

`dogum_kaydet` yapısal olarak tek buzağılı: formda tek küpe + tek cinsiyet, RPC tek `p_kupe` alır.
İkiz bugün fiilen "formu 2 kez doldur" ile çözülüyor ve ikinci çağrıda:

1. 9 anne görevi **duplike** olur (guard yok; ideas doc'ta bilinen hasar)
2. `tohumlama.buzagi_kupe` tekil → 2. buzağının küpesi tohumlamaya yazılamaz
3. `dogum_sayısı` = satır sayısı → triaj (`hayvan_belirsiz_ureme_listele`) ve `v_ureme_dongusu` ikizi "2 doğum" sayar
4. Dashboard "Kızgınlık Beklenenler (58-63g)" bandı anneyi 2 kez listeler
5. İkinci kayıtta "Gebelerden Seç" boş → anne manuel girilir (typo riski)

Kanonik backlog: `.claude/ideas/ikiz-dogum-destegi.md` (2026-06-03) — "2 buzağı = 2 dogum satırı modeli doğrudur" notuyla.

## Karar özeti (kullanıcı onaylı)

| Konu | Karar |
|---|---|
| Veri modeli | `dogum` tablosunda **1 satır = 1 buzağı** korunur; bağ için yeni kolon `olay_id uuid DEFAULT gen_random_uuid()` |
| Olay bağlama | Yazma zamanında: `dogum_kaydet` aynı annede **olay penceresi** içinde olay bulursa `olay_id`'yi yeniden kullanır (okuma tarafında pencere hesabı YOK) |
| Olay penceresi | **10 gün** (`p_tarih - 10 .. p_tarih`) — kullanıcı kararı. Kızgınlık kaydı (`kizginlik_log`) bu mantığa hiç karışmaz; pencere yalnız `dogum` satırlarına bakar |
| Anne görev guard'ı | **60 gün** — bu pencerede anne doğumu varsa anne yan etkileri (9 görev, tohumlama kapatma, grup/padok, protokol, BESLEME iptali) **asla tekrarlanmaz**. Kullanıcı kuralı: "birinci yavrunun yarattığı hiçbir anne görevi tekrarlanmaz" |
| tohumlama.buzagi_kupe | Değişmez — "ilk buzağının küpesi" olarak dokümante edilir; tam yavru listesi olay join'i ile çıkar |
| Metrikler | `COUNT(DISTINCT olay_id)` = doğum sayısı; `COUNT(*)` = buzağı sayısı |
| UI — kardeş | **Yeni box YOK.** Hayvan kartında `Anne:` bloğunun altına koşullu satır: "Kardeş (ikiz): 🐄 78" — `openDet` linkli, **yeşil tema** (dikkat çeker), font küçük ama okunur (.8rem satır / .78rem chip), satırda **✕ ile kapatma** |
| UI — buton | "➕ Bu doğuma yavru ekle" — **yeşil** (dikkat çeker), kompakt (yanlışlıkla basılmaz); yanlış basılırsa modal açılır, İptal/X ile tek tıkla kapanır, submit olmadan veri değişmez |
| Kardeş tespiti (frontend) | `hayvanlar` üzerinden: aynı `anne_id` + **aynı `dogum_tarihi`** (olay_id'ye ihtiyaç yok → migration öncesi/sonrası uyumlu, offline IDB'de de çalışır) |
| Kapsam dışı | Ölü doğum (küpesiz yavru), ayrı `dogum_olay` tablosu, `buzagi_kupe` birleştirme, 260g oto-kapatma entegrasyonu |

## DB değişiklikleri (tek migration: `supabase/migrations/20260901000001_ikiz_dogum_olay_id.sql`)

### 1. Şema

```sql
ALTER TABLE public.dogum ADD COLUMN IF NOT EXISTS olay_id uuid DEFAULT gen_random_uuid();
```

### 2. Backfill

Canlıda tek çoklu doğum vakası: anne 901, buzağı 77 + 78 (ikisi 2026-04-08).
Aynı `(anne_id, tarih)` çoklu satır → ilk satırın `olay_id`'si ortaklanır:

```sql
UPDATE public.dogum d SET olay_id = ilk.olay_id
FROM (SELECT DISTINCT ON (anne_id, tarih) anne_id, tarih, olay_id FROM public.dogum) ilk
WHERE d.anne_id = ilk.anne_id AND d.tarih = ilk.tarih
  AND d.olay_id IS DISTINCT FROM ilk.olay_id;
```

### 3. `dogum_kaydet` v2

Mevcut gövde (GT 9742-9840) korunur; eklenenler:

- **İkiz guard:** aynı `(anne_id, yavru_kupe)` zaten varsa `ok:false` reddi
- **Olay penceresi (10g):** yakın olay varsa `olay_id` yeniden kullanılır → `coklu_dogum:true`
- **Anne görev guard'ı (60g):** yakın doğum varsa tüm anne yan etkileri atlanır
  (11-60 gün arası geç hatırlanan ikiz: kendi olayını açar AMA anne görevleri yine tekrarlanmaz)
- **Baba autofill (2. yavru):** Gebe tohumlama yoksa aynı olayın `baba_bilgi`'sinden alınır
- **Dönüş eklentileri:** `coklu_dogum`, `olay_id`, `yavru_sirasi`; `gorev_sayisi` hardcoded 17 yerine gerçek sayı (9+7 veya 7)

Tam SQL: `docs/plans/2026-09-01-ikiz-dogum-modeli.md` (Task 3).

### 4. Metrik düzeltmeleri

- `hayvan_belirsiz_ureme_listele` (GT 7970-7987): iki `COUNT(*)` → `COUNT(DISTINCT olay_id)`
- `v_ureme_dongusu` (GT 8811+): `dogum_sayisi` subquery'si aynı şekilde

## Frontend değişiklikleri

1. **Saf yardımcılar** (ui.js, test edilebilir): `_kardeslerBul(animals, a)`,
   `_ikinciYavruDogumu(births, bugunStr, pencere)`, `_dogumAnneBazliTekillestir(births)`
2. **Kardeş satırı** (`_detOzetHtml`, ui.js:1721): `Anne:` bloğu altında, yeşil tema,
   chip'ler `openDet` linkli, satır sonu ✕ satırı DOM'dan kaldırır
3. **"➕ Bu doğuma yavru ekle" butonu** (`_detOzetHtml`): bu hayvanın `births` (kendi dogum
   satırları) içinde son 10 günde doğum varsa; yeşil kompakt buton → `ikinciYavruAc()`
   (anne + tarih + baba prefilled modal)
4. **Toast dalı** (forms.js:188): `data.coklu_dogum` true ise "İkiz kaydedildi — N. yavru" mesajı
5. **Dashboard bandı dedup** (ui.js:273-297): `births60F` → `_dogumAnneBazliTekillestir` → `_dashBands`

## Test planı

- **Unit:** `tests/unit/ikiz-dogum.test.js` — 3 saf yardımcı (kardeş bulma, pencere, dedup)
- **E2E (stub):** mevcut stub altyapı uygunsa ikiz akışı; değilse blocker notu commit'te
- **SQL:** migration worktree'de dosya olarak commit; **canlı deploy ayrı adım,
  kullanıcının açık "deploy et" emriyle**

## Uygulama sırası

1. ✅ Spec onayı
2. ✅ Blast radius (gitnexus impact + bu spec içindeki tüketici envanteri)
3. Implementasyon (subagent, `docs/plans/` planı ile) → commit'ler worktree'de
4. Review (diff + testler + detect_changes) → kullanıcıya rapor
5. Kullanıcı **"deploy et"** emri → `supabase_migrate` ile canlı DB
6. Merge main'e (deploy'dan SONRA — eski DB + yeni frontend karışımı "yavru ekle" butonunda
   eski RPC'ye düşer ve anne görevi duplike riski doğurur)
7. Kullanıcı canlı girişleri test eder → sorun yoksa worktree kapanır, dokümantasyon yazılır

## Riskler / kenar durumlar

- **11-60 gün arası hatırlanan ikiz:** yeni olay_id alır ama anne görevleri yine tekrarlanmaz
  (60g guard). İstenirse olay penceresi ileride genişletilebilir — veri kaybı yok, sadece
  olay gruplaması ayrık kalır
- **60+ gün sonra hatırlanan ikiz:** tam Dal A (anne görevleri yeniden açılır) — pratikte veri
  hatası; bilinçli kabul
- **Typo ile farklı küpe, aynı anne, aynı gün:** meşru ikizden ayırt edilemez — kabul
  (guard yalnız birebir aynı küpeyi yakalar)
- **geri_al:** olaydan bir buzağı geri alınırsa kalan satır(lar) olay_id'yi korur → olay
  1 buzağıya iner, tutarlı
- **Offline replay** (ui.js buildRpcParams): parametre seti değişmiyor → dokunulmaz
- **gorev_sayisi 17 hardcoded:** aslında 16 görev vardı (9+7) — v2 gerçek sayıyı döner, toast düzelir
