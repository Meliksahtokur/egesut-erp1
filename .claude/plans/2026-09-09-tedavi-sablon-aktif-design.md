# Tasarım: Aktif Vakaya Tedavi Şablonu Uygulama

Tarih: 2026-09-09 · Durum: TASARIM (sahip onayı bekler)
Branch/worktree: `idle/tedavi-sablon-aktif` @ `/home/melik/egesut-wt/tedavi-sablon-aktif`
Pattern refs: `RPC-WRITE-01`, `MODAL-ROUTER-01`, `FORM-SUBMIT-01`, `TESTING-01`

## 1. Problem

Tedavi şablonları bugün **yalnızca vaka açılışında** (m-disease → `submitCase`,
forms.js:619-620) uygulanabiliyor. Açılmış (aktif) bir vakaya sonradan şablon
eklenemiyor: kullanıcı günleri/ilaçları tek tek elle açmak zorunda.

İstek: aktif vakaya da şablon uygulanabilsin; **kullanıcının seçtiği tarih
şablonun 1. günü (çapa tarih) sayılsın**.

## 2. Mevcut davranış (değişmez)

```
[Hayvan Kartı] ──🏥 Vaka Aç──► m-disease modalı
                                   ├─ hastalık seçimi ──► şablon radyo listesi
                                   │                      (_renderSablonSecim,
                                   │                       d-sablon-blok; yalnız
                                   │                       hastalığa bağlı şablonlar)
                                   └─ [Vakayı Aç] ──► create_case
                                                        └─ şablon seçildiyse:
                                                           tedavi_sablon_uygula(case, sablon)
                                                           tedavi_sablon_tohumlama_gorev_ekle(...)
                                                           ÇAPA HER İKİSİNDE DE: case.start_date
                                                           (RPC'de v_date := start_date + (gun_no-1))
```

- `tedavi_sablon_uygula(p_case_id, p_sablon_id)` (mig. 20260613000009):
  şablon kalemlerini `gun_no` sırasıyla `add_treatment_day_with_sessions`
  motoruna besler; kapalı vakayı reddeder; silinmiş ilaç/stok kalemlerini
  `atlanan[]` olarak raporlar.
- `tedavi_sablon_tohumlama_gorev_ekle(p_case_id, p_sablon_id)` **en güncel
  tanım** 20260730000002'dedir (bağımsız `TOHUMLAMA_PLANLI` satırı, parent
  YOK, `_tohumlama_gorev_uygunluk` kontrolü `sebep` döner, `nullif(...,
  'null'::jsonb)` koruması). Migration BU gövdeden türetilir.
- `vaka_toplu_ac` her iki RPC'yi içeriden çağırır (2 argüman) — PL/pgSQL
  çağrıları plan-anında isimle çözümlenir; DROP+CREATE+DEFAULT sonrası
  2-argümanlı iç çağrılar DEFAULT üzerinden aynı davranışla bağlanır
  (deploy sonrası demo smoke çağrısıyla doğrulanır).

## 3. Yeni davranış

```
[Vaka Detayı — m-case-det, AKTİF vaka]           (kapalı vakada cd-gun-bolum gizli)
 ┌─────────────────────────────────────────────────────────────┐
 │ cd-gun-bolum                                                │
 │  [➕ Tedavi Günü Ekle]            (mevcut, değişmez)         │
 │  [🐄 Planlı Tohumlama Ekle]       (mevcut, değişmez)         │
 │  [📋 Şablondan Plan Ekle ▾]       ◄── YENİ toggle butonu     │
 │  ┌─ cd-sablon-alan (katlanır; desen: bc-sablon-yukle-alan) ┐│
 │  │ Şablonun ilk günü: [2026-09-09 📅]  (varsayılan: bugün)  ││
 │  │                                                          ││
 │  │ Mantar Tedavisi — 3 gün · 5 seans · 🐄      [Uygula]     ││
 │  │ Mastitis 3 Günlük — 3 gün · 9 seans         [Uygula]     ││
 │  │ (yalnız VAKANIN HASTALIĞINA bağlı şablonlar — açılış     ││
 │  │  listesiyle aynı kaynak: sablon_hastalik_eslem)          ││
 │  └──────────────────────────────────────────────────────────┘│
 └─────────────────────────────────────────────────────────────┘
        [Uygula]
           ├─► tedavi_sablon_uygula(case, sablon, p_baslangic_tarihi=SEÇİLEN)
           ├─► tedavi_sablon_tohumlama_gorev_ekle(case, sablon, p_baslangic_tarihi=SEÇİLEN)
           ├─► toast'lar (submitCase dilini birebir korur: atlanan/sebep/başarı)
           └─► pullTables + renderCaseTimeline + _updateKapatBtn + alan kapanır
```

### Tarih çapası (öz)

```
Şablon kalem gun_no'ları:      1          2          3
                               │          │          │
Seçilen tarih (örn 12.09):   12.09      13.09      14.09
                                      (tohumlama_plani.gun_ofset=2 → 14.09 09:00)

   tarih = p_baslangic_tarihi + (gun_no − 1)          ← uygula
   tarih = p_baslangic_tarihi + gun_ofset             ← tohumlama görevi
   p_baslangic_tarihi NULL ⇔ eski davranış (case.start_date çapası) — geriye uyumlu
```

## 4. Tasarım kararları

| # | Karar | Gerekçe / Alternatif |
|---|---|---|
| D1 | İki RPC'ye **opsiyonel 3. parametre** `p_baslangic_tarihi date DEFAULT NULL` eklenir; yeni RPC üretilmez | Tek motor tek kalır. Alternatif (yeni `tedavi_sablon_aktife_uygula` RPC'si) motoru kopyalar — reddedildi. 2 argümanlı mevcut çağrılar DEFAULT ile aynı çalışır (mig. DROP+CREATE ile aşırı-yükle belirsizliği de engellenir) |
| D2 | UI, m-case-det içinde **katlanır alan** (yeni modal değil) | Sahip kuralı: evdeki deseni birebir örnek al (bc-sablon-yukle-alan, forms.js:1382). Modal üstüne modal yok |
| D3 | Liste **yalnız vakanın hastalığına bağlı** şablonlar | Açılış listesiyle aynı kaynak ve kapsam (sablon_hastalik_eslem). Tüm şablonları listeleme fikri kapsam şişirmesi — YAGNI |
| D4 | Şablonda tohumlama planı varsa **otomatik eklenir** (çapa: seçilen tarih) | Açılış akışıyla birebir tutarlı (forms.js:620-624). Mükerrer `kaynak` anahtarıyla engelli. "Sadece tohumlamalı" şablon + tedavi günü yoksa RPC üst görev bulamaz → catch + bilgi toast'u (açılıştaki davranışla aynı) |
| D5 | Tarih girişi: **geçmiş/ gelecek serbest**, varsayılan bugün | Gün ekleme takvimi de serbest; geriye dönük kayıt girilebilir. Kısıt uydurma — YAGNI |
| D6 | Aktiflik kontrolü **iki katmanlı**: UI (cd-gun-bolum kapalıya gizli) + RPC (kapalı vaka reddi zaten var) | Mevcut guard'lar aynen geçerli |
| D7 | Çakışma semantiği: **eklemeli** — seçilen tarih aralığında varolan tedavi günleri **asla değiştirilmez**; şablon günleri yeni `treatment_days` satırları olarak düşer (day_no = MAX+1) | Şemada (case_id, treatment_date) unique kısıtı YOK; motor da tarihe göre dedupe yapmıyor. Timeline aynı tarihteki günleri ayrı kart gösterir. Mevcut planın üzerine yazma YOK (bc editöründeki "üzerine yazma onayı" bu yüzden gereksiz) |
| D8 | Stok/ilaç geçerliliği RPC'de: silinmiş ilaç/stok kalemleri `atlanan[]` olarak döner, akış **devam eder** | Mevcut `tedavi_sablon_uygula` davranışı aynen |
| D9 | Çevrimdışı: `navigator.onLine` kontrolü + uyarı (submitCase deseni) | rpc() çevrimdışı çağrılamaz |

## 5. Bileşen değişiklikleri

### 5.1 DB (supabase/migrations/`20260909000001_sablon_aktif_vakaya_uygula.sql` — yeni)

```sql
-- tedavi_sablon_uygula: 3. parametre, çapa tarihi (NULL ⇒ start_date)
DROP FUNCTION IF EXISTS public.tedavi_sablon_uygula(uuid, uuid);
CREATE FUNCTION public.tedavi_sablon_uygula(
  p_case_id uuid, p_sablon_id uuid,
  p_baslangic_tarihi date DEFAULT NULL) ...
  -- v_anchor date := COALESCE(p_baslangic_tarihi, v_case.start_date);
  -- v_date := v_anchor + (v_gun_no - 1);   (tek satır değişiklik)

-- tedavi_sablon_tohumlama_gorev_ekle: aynı 3. parametre
DROP FUNCTION IF EXISTS public.tedavi_sablon_tohumlama_gorev_ekle(uuid, uuid);
CREATE FUNCTION ... (p_case_id uuid, p_sablon_id uuid,
  p_baslangic_tarihi date DEFAULT NULL) ...
  -- v_date := COALESCE(p_baslangic_tarihi, v_case.start_date) + gun_ofset;
```

- `GRANT` satırları korunur. Kapalı-vaka/şablon-yok guard'ları aynen.
- Deployment ayrı kapı: **demo DB** lokal test için serbest (yerleşik izin),
  **PROD** yalnız sahibin açık emriyle.

### 5.2 index.html (m-case-det)

- `cd-gun-bolum` içine, "Planlı Tohumlama Ekle" altına:
  toggle butonu `data-action="cd-sablon-toggle"` + gizli `cd-sablon-alan`
  (tarih input'u `cd-sablon-tarih` + `cd-sablon-list`).
- **?v= damgası**: index.html değiştiği için tek-ortak `?v=` değeri TÜM
  yerel kaynaklarda tek değere bump edilir (kısmi bump yasak — hafıza kuralı).

### 5.3 js/ui.js (vaka detayı burada yaşıyor)

- `caseSablonToggle()` — alan aç/kapa + liste render (bcSablonYukleToggle deseni).
- `caseSablonListeRender()` — `_curCase.disease_id`'ye bağlı şablonları listeler.
- **Saf çekirdek** `cdSablonListeBul(eslem, sablonlar, kalemler, diseaseId)`
  → `[{id, ad, gun, seans, tohumVar}]` — DOM'dan arındırılmış, birim testi
  birincil hedefi (bc listedeki hesabın aynısı: gun = unique gun_no, seans =
  kalem sayısı, tohumVar = plan.gun_ofset != null && planned_time).
- `caseSablonUygula(sablonId)` — D9 online kontrolü, tarih boş mu;
  iki RPC (3 argüman) sırayla; toast'lar submitCase:621-625 dilini birebir
  korur (`r.atlanan`, `planli.sebep`, başarı mesajı); pullTables
  (api.js:376-377 eşlemesindeki setler); `renderCaseTimeline(_curCase.id)`;
  `_updateKapatBtn`; alan kapanır.

### 5.4 js/utils/handlers.js

- `'cd-sablon-toggle'` ve `'cd-sablon-uygula'` (el.dataset.sablonId) router
  kayıtları — MODAL-ROUTER-01 dataset deseni.

### 5.5 js/api.js

- Değişiklik YOK: RPC→tablo eşlemesi (`tedavi_sablon_uygula`,
  `tedavi_sablon_tohumlama_gorev_ekle`) zaten mevcut (api.js:376-377).

### 5.6 Testler (TESTING-01, lokal unit kapı)

- `tests/unit/tedavi-sablon-aktif.test.js` — vm loader (loadModule.js):
  `cdSablonListeBul` saf testleri (eşleşme, gün/seans sayısı, 🐄 bayrağı,
  hastalık eşlemesi olmayan şablon dışlanır, boş girdi → []).
- Mevcut davranışın regresyonu: `tedavi_sablon_uygula`'yı 2 argümanla çağıran
  `submitCase` ve toplu vaka akışı JS tarafında değişmez — mevcut testler
  (vaka-toplu-ac.test.js, api.test.js) yeşil kalmalı.

## 6. Veri akışı (uygulama anı)

```
kullanıcı          ui.js                     supabase RPC                DB
   │ [Uygula] ──► caseSablonUygula(sablonId)      │                       │
   │              ├ online? tarih? (yoksa toast)  │                       │
   │              ├──────────────────────────► tedavi_sablon_uygula      │
   │              │                    (case, sablon, 2026-09-09) ──► her gun_no:
   │              │                                    add_treatment_day_with_sessions
   │              │                                    → treatment_days + seanslar
   │              │                                    + drug_administrations(plan)
   │              │◄─ {ok, gun_sayisi, seans_sayisi, atlanan[]}          │
   │              ├──────────────────────────► tedavi_sablon_tohumlama_gorev_ekle
   │              │◄─ {ok, olustu|sebep}              → gorev_log (TOHUMLAMA_PLANLI)
   │              ├ pullTables(...) + renderCaseTimeline + _updateKapatBtn
   │ ◄─ toast: ✅ Şablon uygulandı (N gün) [+ tohumlama]
```

## 7. Hata durumları

| Durum | Davranış |
|---|---|
| Vaka kapalı | UI butonu görünmez; RPC yine de reddeder (çift katman) |
| Tarih boş | toast «Şablonun ilk gününü seçin» — RPC çağrılmaz |
| Çevrimdışı | toast «⚠️ İnternet bağlantısı gerekli» (submitCase deseni) |
| Şablon kaleminde silinmiş ilaç/stok | kalem atlanır; sonunda «⚠️ N kalem atlandı» |
| Şablonda tohumlama + hayvan o tarihte uygun değil | görev açılmaz, `sebep` toast'u (bilgi) — uygunluk `_tohumlama_gorev_uygunluk(hayvan, seçilen tarih)` üzerinden, güncel RPC bağımsız olay olarak açar (parent gerektirmez) |
| Aynı şablon ikinci kez uygulanır | ilaç günleri tekrar eklenir (kullanıcı tercihi), tohumlama görevi `kaynak` anahtarıyla mükerrer açılmaz |

## 8. Kapsam dışı (bilinçli)

- Aktif vakanın hastalığı dışındaki şablonları listeleme (D3).
- Mevcut plan günlerini değiştirme/silme/üzerine yazma (D7 — ekleme yalnız).
- Toplu vaka editöründe değişiklik yok (bc akışı zaten kendi çözümüne sahip).
- Şablon önizleme modali (liste satırındaki «N gün · M seans · 🐄» özeti yeterli).
