# SPEC S5 — Tutarlılık Paketi T1-T11 (Cila Turu, Plan 5'in Tur 2 iş dilimi)

- **Tarih:** 2026-09-24 · **Dal:** `ovysch-feature-cila-turu` (prod'a push/merge YOK)
- **R3 onarım revizyonu (2026-09-24):** reviewer 3. tur FAIL sonrası tüm kanıt iddiaları repodan ve canlı şemadan tek tek yeniden doğrulandı. Kesinleşenler: **T6/F3 İPTAL** (canlıda legacy `(text)` overload YOK — §5.1/§5.3), **V3 damga VAR** (canlı 16 satır — §7.2), **V1 canlı teyit** (§12). Satır-no drift'leri düzeltildi (§2, §4.1, §6, §8.1, §8.2, §9.2). Yeni operasyonel kural: `supabase_migrate` MCP **PROD hedeflidir, bu turda demo ölçüm/apply için YASAK** (demo yolu: `SUPABASE_DEMO_PAT` query endpoint — bkz. plan K-7).
- **Girdi:** `reports/plans/ovsync-cila-plan-5.md` (sahibin 5. maddesi + T1-T11 bulguları), `reports/plans/ovsync-cila-sentez.md` (§3 sıra, §5A sınıflandırma kuralı, §9 sahip kararları), canlı repo kodu (bu spec yazılırken satır düzeyinde yeniden doğrulandı — etiketler bkz. §11)
- **Kapsam:** T5 (replay iptali) → T3/T4 (PG zinciri atomikliği + flush kaybı) → T1/T2 (çift senkron) → T6 (doğrulama) → T7/T8/T10 (tutarlılık cilası)
- **Kapsam DIŞI (borç — fix YOK):** T9 kuyruk şema-versiyonu (`BUGS.md:195` BUG-KUYRUK-SHEMA-VERSIYONU [open/borç]) ve erteleme geneli (`BUGS.md:183` BUG-ERTELEME-KURAL-GENEL [open/borç]) — sahibin bağlayıcı kararı. T11 kod değişikliği değildir (§10, sahibe not). T7'nin O12/P3-P10 bildirim zenginliği kalemi Plan 3'ün işidir (bu spec'te YOK).

---

## 1. Amaç

Faure/Ovsync protokolünün devreye girmesinden sonra sistemde kalan **işletmeci-görünür tutarlılık bozukluklarını** kapatmak:

1. İptal edilen bir görevin offline→online el-replay'i görevi **yanlışlıkla "tamamlandı"ya çevirmesin** (T5);
2. PG kapısı akışında **yarım durum + sahte başarı toast'u** kalmasın (T3), pending-flush **işlenemeyen op'u kalıcı olarak kaybetmesin** (T4);
3. Açık senkron zinciri olan hayvana **ikinci ovsync planlaması üstüne binsin** — ama sahibin **kasıtlı çift zincir kararı (188) korunarak** (T1); 168/186 tipi çift planlama temizlik sonrası **ölçülebilir sıfırda** kalsın (T2);
4. `tohumlama_sonuc_bos` overload/sonuc-değer belirsizliği **canlı şemada ölçülüp** tek kanonik imzaya indirgensin (T6);
5. Toplu gönderim önizlemesi (O10), erteleme özeti + Türkçe hata (D18), vaka-kapanış özeti + ölü fallback anahtarı (D19), pull-seti eksikleri (D17), TZ drift (O11), ölü kod dalı + hata ayrıntısı kaybı (T8) ve rozet-panel sayı tutarlılığı (T10) düzeltsin.

Teslimat: **demo DB'de testte hazır** durum — sahibin lokal browser yürüyüşü (plan-5 §3 checklist'i) + son review kapısı bu spec'in çıkış kapılarıdır.

## 2. Dokunulacak dosyaların TAM listesi (tek-yazıcı zarfı)

Bu spec'in implementation'ı **yalnızca** aşağıdaki dosyalara yazar. Başka hiçbir dosyaya dokunulmaz; `reports/` altındaki plan dosyaları salt-okunur girdidir.

| # | Dosya | İş kalemleri | Yazıcı kulvarı |
|---|---|---|---|
| F1 | `supabase/migrations/20260925000001_cila_t5_gorev_tamamla_p_iptal.sql` (YENİ) | T5 | DB kulvarı |
| F2 | `supabase/migrations/20260925000002_cila_t1_acik_disi_senkron_muafiyet.sql` (YENİ) | T1 | DB kulvarı |
| F3 | ~~`supabase/migrations/20260925000003_cila_t6_sonuc_bos_overload_temizligi.sql`~~ (**İPTAL — R3 onarım:** canlı demo `pg_proc` ölçümü tek imza `(text,text)` gösterdi; legacy `(text)` overload canlıda YOK → §5.3 koşul-1 tutmuyor, kod değişikliği 0 meşru teslim) | T6 | DB kulvarı |
| F4 | `js/api.js` | T5 (yok — api.js dokunulmaz T5'te), T8 (`rpc()` mesaj zenginleştirme :86-90), T7-D17 (`RPC_TABLES.start_first_service_protocol` :320) | JS kulvarı |
| F5 | `js/ui.js` | T3 (ui tarafı `_pgKapiBosAtaUygula` :990-1005), T4 (`flushPendingDone` :583-597), T5 (`buildRpcParams` :9426-9427), T7-O10 (`dataTrafficGonder` :9229-9235), T7-D18 (`_erteleKaydet` toast :1058-1059), T7-O11 (`_protokolUygulaKaydet` :2338-2341), T8 (ölü dal :997), T10 (`loadDash` rozet bloğu :413-424 + panel önbellek :1829-1847) | JS kulvarı (aynı yazıcı, F4-F7 ile **sıralı**, paralel DEĞİL) |
| F6 | `js/forms.js` | T3 (toast kapısı `seansTamamla` :4012-4014), T7-D19 (kapanış özeti :346-350) | JS kulvarı |
| F7 | `js/utils/errorHandler.js` | T7-D18 (`USER_FRIENDLY` sözlüğe 2 anahtar) | JS kulvarı |
| F8 | `tests/unit/cila-tutarlilik.test.js` (YENİ) | T5/T4/T10 birim testleri | Test kulvarı |

Mevcut test dosyaları (`tests/unit/ovsync-pg-*.test.js`, `tests/unit/*tarih*`) **değiştirilmez**; Tur 2 ilk gün triage'ı (plan-5 §3.4 — bugün 3 kırmızı, OBSERVED) sadece koşturulup raporlanır.

## 3. Zorunlu kapılar (her iş kalemi için)

1. **Pre-check:** JS sembol/RPC değişiminden ÖNCE blast-radius pre-check (gitnexus `impact`/`context` + `code-change-precheck` skill'i). gitnexus kullanım öncesi indeks HEAD'e eş mi kontrol edilir; iş bitince `gitnexus analyze` ile indeks tazelenir ve `detect_changes` koşulur.
2. **db-validation kapısı:** F1-F3 her biri için taslakta BİR, apply etmeden ÖNCE final dosyada `scripts/db-validate.sh` — PASS kanıtsız migration yazılmaz/uygulanmaz.
3. **Anon kuralı:** Yeni migration'larda `TO anon` / `GRANT ... TO anon` YAZILMAZ; mevcut desen (ör. `20260924000001:L293` `REVOKE ALL ... FROM PUBLIC, anon, authenticated` + koşullu `GRANT ... TO authenticated`) izlenir.
4. **Canlı şema tek otorite:** F1-F3'teki her `CREATE OR REPLACE`, apply'dan hemen önce **canlı demo** `pg_get_functiondef` çıktısıyla karşılaştırılır (ground_truth bayat olabilir — T6 için zaten kanıtlandı: PGRST205, plan-5 §2.2).
5. **Commit disiplini:** her anlamlı adım sonrası bu dala commit; prod push/merge yok.
6. **Son review kapısı:** tüm kalemler + sahibin yürüyüşü sonrası ayrı review turu koşulur (sahibin talebi); review bulguları bu spec'in kabul maddelerine geri-ölçülür.

## 4. T5 — Manuel replay iptali "tamamlandı"ya çeviriyor (YÜKSEK ÖNCELİK)

### 4.1 Kanıt (doğrulandı)
- Kuyruk replay'i `gorev_log: { PATCH: 'gorev_tamamla' }` eşlemesi: CONFIRMED `js/ui.js:9245`.
- RPC parametre kurulumu iptal taşımıyor: CONFIRMED `js/ui.js:9426-9427` — `case 'gorev_tamamla': return { p_gorev_id: data.id, p_padok_hedef: data.padok || null };`
- `gorev_tamamla` imzasında `p_iptal` yok; tüm migration ağacında `p_iptal` grep'i BOŞ: OBSERVED (supabase/migrations/*.sql). Takip imzası (BAYAT kaynak, canlı doğrulanacak): ground_truth:7486 `(p_gorev_id text, p_padok_hedef text DEFAULT NULL)`.
- Otomatik sync doğru semantikte (ham REST PATCH, alanlar olduğu gibi): CONFIRMED `js/api.js:548-550` (`dbUpdate(op.table, idMatch[1], op.data[0])` — R3 onarımda satır tazelendi).
- Kuyruğa düşen `gorev_log` PATCH yazmalarının üreticisi offline `write()` yoludur: CONFIRMED `js/api.js:232-240` (`_writePatch`); iptal üreticisi örnek: `js/ui.js:1190-1199` (`ovsyncIptal` → `write('gorev_log',{...iptal:true,...},'PATCH',...)` — write satırı :1195).

### 4.2 Tasarım
**Seçenek A (ÖNERİLEN varsayılan):** `gorev_tamamla`'ya opsiyonel `p_iptal boolean DEFAULT false` ekle; replay parametre kurulumu `data.iptal === true`'yu taşısın. RPC yan etkileri (islem_log izi) korunur, RPC_MAP mimarisi bozulmaz, mevcut 6+ çağrı noktası default ile etkilenmez.
**Seçenek B (alternatif):** replay'de `gorev_log` PATCH'ini RPC yerine ham REST PATCH'e çevir (`dataTrafficTekGonder` içinde `dbUpdate`); DB değişikliği yok ama replay/online semantiği ayrışır ve RPC_MAP'in RPC-yan-etki felsefesi zayıflar.
**Karar noktası S2'de açık** (sahibin tek-cümlelik onayı); spec A varsayılanıyla yazılır. A seçilirse B hiç uygulanmaz.

### 4.3 Migration taslağı — F1 (gövde-seviyesi)

```sql
-- 20260925000001_cila_t5_gorev_tamamla_p_iptal.sql  (TASLAK — apply öncesi
-- canlı pg_get_functiondef('gorev_tamamla(text,text)') ile birebirleştirilir;
-- gövdenin kalanı CANLI tanımdan kopyalanır, aşağıdaki branş ÜSTTE eklenir)
CREATE OR REPLACE FUNCTION public.gorev_tamamla(
  p_gorev_id    text,
  p_padok_hedef text DEFAULT NULL::text,
  p_iptal       boolean DEFAULT false          -- YENİ (sona ekli, geriye uyumlu)
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp             -- mevcut canlı ayar ne ise o korunur [UNKNOWN: canlı SET satırı]
AS $fn$
DECLARE
  -- mevcut canlı gövdedeki DECLARE bloğu aynen korunur
BEGIN
  -- ═══ T5 branşı — ek koşul, mevcut mantık ikame EDİLMEZ ═══
  IF p_iptal IS TRUE THEN
    UPDATE public.gorev_log
       SET tamamlandi = true,
           tamamlanma_tarihi = COALESCE(tamamlanma_tarihi, now()),
           iptal = true
     WHERE id::text = p_gorev_id;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev bulunamadı');
    END IF;
    -- islem_log izi: canlı gövdedeki tamamlandı-iz deseninin aynısı, aciklama
    -- 'Görev iptal edildi (offline replay)' [UNKNOWN: canlı islem_log INSERT deseni]
    RETURN jsonb_build_object('ok', true, 'gorev_id', p_gorev_id, 'iptal', true);
  END IF;
  -- ═══ mevcut canlı gövde aynen devam eder ═══
  ...
END;
$fn$;
REVOKE ALL ON FUNCTION public.gorev_tamamla(text, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.gorev_tamamla(text, text, boolean) TO authenticated;
```

JS tarafı (F5) — `buildRpcParams` (ui.js:9426-9427):

```js
case 'gorev_tamamla':
  return { p_gorev_id: data.id, p_padok_hedef: data.padok || null,
           p_iptal: data.iptal === true };   // T5: iptal-PATCH replay'i iptal olarak gider
```

### 4.4 Kabul testleri (maddeli, ölçülebilir)
1. **U1 (birim):** `buildRpcParams('gorev_tamamla', {id:'g1', padok:'p1', iptal:true})` → `{p_gorev_id:'g1', p_padok_hedef:'p1', p_iptal:true}`; `iptal:false` ve `iptal:undefined` için → `p_iptal:false`. (F8)
2. **U2 (birim):** F1 SQL'i `scripts/db-validate.sh` PASS (taslak + final iki koşum kanıtı).
3. **D1 (demo DB, demo-apply sonrası):** demo'da bir `gorev_log` satırına offline-iptal kuyruk op'u kur → `dataTrafficTekGonder` → satırda `tamamlandi=true AND iptal=true` — **yanlış-semantik sayısı 0**.
4. **D2 (demo):** normal (iptalsiz) görev tamamlama replay'i → `iptal=false`, mevcut davranış değişmedi (regresyon).
5. **D3 (demo):** otomatik `syncNow` yolu (api.js:546) değişmedi — offline iptal + online otomatik sync → `iptal=true` (zaten çalışan davranışın kanıt-güncellemesi).

## 5. T6 — `tohumlama_sonuc_bos` overload doğrulaması (Adım 0'ın İLK DB adımı)

### 5.1 Kanıt ve bilinmeyenler
- Kanonik güncel tanım (text,text): CONFIRMED `20260924000001:L508` `(p_tohumlama_id text, p_notlar text DEFAULT NULL)`; sonuç yazımı `'Boş'` (Türkçe İ): CONFIRMED `20260924000001:L535-536` (`sonuc='Boş'`, `tohumlama_durumu='Boş'`).
- Tek-argümanlı eski overload (text): CONFIRMED `20260512000006:L4` + `:L44` `GRANT EXECUTE ... (text) TO anon, authenticated` (repo migration'ı; canlıda fonksiyon YOK — aşağıda).
- **Canlı overload durumu — R3 ONARIMINDA ÇÖZÜLDÜ (UNKNOWN değil artık):** demo canlı `pg_proc` ölçümü (SUPABASE_DEMO_PAT query endpoint, fdw=1 ile demo teyitli, 2026-09-24) `tohumlama_sonuc_bos` için **tek imza `(text,text)`** gösterdi; legacy `(text)` overload **canlıda YOK** (prod'da da tek imza — yan gözlem). Repo tarihçesi: `20260403000001:L6` overload'u DROP etmiş, `20260512000006` tekrar CREATE etmiş; canlıdaki nihai durum tek imza. → `20260512000006`'ın anon GRANT'lı (text) overload'ı canlıda mevcut OLMADIĞINDAN o "risk kaydı" **kapanır** (fonksiyon yok, GRANT'ı anlamsız).

### 5.2 Adım 0 ölçümü (salt-okunur, demo — TÜM T6 işlerinin ön-şartı)
```sql
SELECT p.oid::regprocedure::text AS imza,
       pg_get_functiondef(p.oid) AS govde
FROM pg_proc p
WHERE p.proname = 'tohumlama_sonuc_bos' AND p.pronamespace = 'public'::regnamespace;

SELECT sonuc, count(*) FROM public.tohumlama
WHERE sonuc ILIKE '%bos%' OR tohumlama_durumu ILIKE '%bos%' GROUP BY 1;  -- 'Boş'/'Bos' dağılımı
-- (ikinci kolon ayrı sorgu: SELECT tohumlama_durumu, count(*) ... )
SELECT p.oid::regprocedure::text, has_function_privilege('anon', p.oid, 'EXECUTE')
FROM pg_proc p WHERE p.proname='tohumlama_sonuc_bos';                     -- anon EXECUTE durumu
```

### 5.3 F3 koşullu migration taslağı — **R3 ONARIMINDA İPTAL EDİLDİ**
Koşul-1 canlı ölçümle çöktü: demo `pg_proc`'ta `(text)` overload **yok** (§5.1). Koşullar:

1. ~~Canlıda `(text)` + `(text,text)` birlikte~~ — **TUTMUYOR** (OBSERVED canlı: tek imza);
2. ~~`(text)` gövdesi davranışsal fark~~ — değerlendirilemez (fonksiyon canlıda yok);
3. ~~Sahip onayı~~ — gerek kalmadı.

**Sonuç: F3 YAZILMAZ / UYGULANMAZ — kesin.** "Kod değişikliği 0" bu kalemin meşru teslimidir; `20260925000003_*` dosyası oluşturulmaz. T6 için kalan iş yalnızca kanıt kaydıdır (Ö1). T6-F3 sahibe sorusu (§13-4) onay-sorusundan bilgi-notuna iner.

```sql
-- 20260925000003_cila_t6_sonuc_bos_overload_temizligi.sql — YAZILMADI (koşul-1 tutmadı)
-- Tarihsel taslak (uygulanmadı): DROP FUNCTION IF EXISTS public.tohumlama_sonuc_bos(text);
```

### 5.4 Kabul testleri
1. **Ö1:** Adım 0/1 ölçüm kaydı — imza listesi + 'Boş/Bos' dağılımı + anon ayrıcalık — sahibe sunulur (demo salt-okunur). R3 onarımı imza bölümünü zaten kanıtladı (tek imza `(text,text)`, demo); 'Boş/Bos' dağılımı ve anon ayrıcalık sayımı Adım 1'de tamamlanır.
2. **Ö2:** ~~F3 uygulanırsa~~ — **uygulama olmadan zaten sağlanıyor**: canlı `pg_proc` içinde `tohumlama_sonuc_bos` tek imza `(text,text)` (OBSERVED 2026-09-24). `has_function_privilege('anon', ...)` ölçümü Adım 1'e kalır (kapama kanıtı).
3. **Ö3 (F3'süz hâlâ geçerli — davranış kanıtı):** demo'da PG kapısı "Boş ata ve uygula" akışı (ui.js:996) çalışır: `tohumlama` satırı `sonuc='Boş'`, akış hatasız (plan-5 §3.2 K5 yürüyüş maddesine bağlanır — koşumu SAHİP yapar).

## 6. T3 + T4 — PG zinciri atomikliği ve flush kaybı

### 6.1 Kanıt
- **T3a (sahte başarı toast'u):** CONFIRMED `js/forms.js:4012-4014` — `const res = await rpcSeansTamamla(...)` sonrası `res` kontrol edilmeden `'✓ Seans tamamlandı'` toast'u basılıyor; oysa `rpcSeansTamamla` PG kapısında `{ ok:false, _pgKapi:true }` dönebiliyor: CONFIRMED `js/api.js:693-701` (dönüş :697).
- **T3b (iki bağımsız RPC):** CONFIRMED `js/ui.js:996-1003` — `_pgKapiBosAtaUygula`: önce `tohumlama_sonuc_bos` (commit 1), sonra `window.__pgKapiTekrar(true, gerekce)` → `hizli_uygulama` (commit 2). İkinci düşerse "Tohumlama Boş yapıldı" durumu kalır, catch'te yalnız hata toast'u — yarım durum için telafi yolu yok.
- **T4 (flush op kaybı):** CONFIRMED `js/ui.js:583-597` (R3 onarımda satır tazelendi) — `flushPendingDone`: `:587` `_pendingDone.clear()` **işleme döngüsünden ÖNCE**; `:593` catch yalnız toast → hatalı op kalıcı kayıp. **Plan-5'teki "PG_KAPI kapısını atlıyor" formülasyonu bu spec'te revize edildi:** kapı atlanmıyor — `rpcSeansTamamla` (api.js:693-701) PG RAISE'de `_pgKapiHata` ile modalı arka-planda açıyor; gerçek sorun clear-önce (:587) yüzünden **Vazgeç'te op'un zaten silinmiş olması**. (CONFIRMED okuma; plan-5 §2.2 T4'ün mekanik tanımı düzeltildi.)
- **T8 ile aynı nokta:** `js/ui.js:996-997` ölü dal — `rpc()` `ok:false` gövdesini throw'a çevirir (CONFIRMED `js/api.js:86-90`) → `if (!r?.ok)` hiç koşmaz; üstelik sunucu `'error'` alanı dönerken rpc `data.mesaj` okur (CONFIRMED `20260924000001:L522,L526` vs `api.js:87`) → hata ayrıntısı kaybolur.

### 6.2 Tasarım (JS-only; DB değişikliği YOK)
1. **F6 (forms.js:4012-4014):** toast'tan ÖNCE `if (res?._pgKapi) return;` — PG modalı açıldıysa sahte başarı basılmaz (modal kendi akışını yönetir).
2. **F5 (ui.js:583-597) flush yeniden yazımı:** clear döngüden SONRA taşınır; op yalnız **başarılı** işlemde pending'den düşer:
```js
const items=[..._pendingDone.values()];
const kalan=new Map(_pendingDone);
for(const it of items){
  try { /* mevcut üç dal aynı kalır */ kalan.delete(it.type==='seans'?it.params.seansId:it.params.gorevId); }
  catch(e){ toast('❌ Görev uygulanamadı: '+(e.message||''), true); /* op pending'de kalır */ }
}
_pendingDone.clear();
kalan.forEach((v,k)=>_pendingDone.set(k,v));
_savePending(); updatePendingFab();
```
   `recoverPendingDone` (ui.js:598-605) davranışı korunur — yeniden giriş flush'ı tekrar dener.
3. **F5 (ui.js:990-1005) `_pgKapiBosAtaUygula`:** ölü `if (!r?.ok)` dalı silinir (T8 — dal satırı :997); `tekrar` çağrısı try/catch'e alınır — hata durumunda `_pgKapiKapat()` ÇAĞRILMAZ, modal açık kalır ve "Tohumlama Boş kaydedildi, PG uygulanamadı — tekrar dene" net mesajı + aynı butonla yalnız-PG-retry verilir (yarım durum görünür ve telafi edilebilir olur).
4. **F4 (api.js:86-90) T8:** `new Error(data.mesaj || data.error || 'İşlem başarısız')` — sunucu `'error'` alanlı RPC'lerde (tohumlama_sonuc_bos deseni) Türkçe ayrıntı korunur. Ortak yol: tüm rpc() çağıranları yalnız hata-METNİ kalitesinde etkilenir, akış değişmez.

### 6.3 Kabul testleri
1. **U4 (birim, F8):** flushPendingDone simülasyonu — 3 op'tan 2. si hata fırlatır → 1. ve 3. pending'den düşer, 2. pending'de kalır; `_savePending` kalanı yazar.
2. **U5 (birim):** `rpcSeansTamamla` `{ok:false,_pgKapi:true}` döndüğünde `seansTamamla` (forms.js) toast BASMAZ.
3. **D4 (demo):** PG kapısı tetikleyen gerçek seansta "Vazgeç" → görev listede HÂLÂ açık; sayfa yenileyince de açık (recoverPendingDone kurtarır).
4. **D5 (demo):** "Boş ata ve uygula" akışında ikinci adım hata enjekte edilebildiği senaryoda (demo verisiyle) modal açık kalır, toast/uyarı net; Boş kaydı + uyarı görünür durumda.
5. **D6 (demo):** `rpc()` hata mesajı artık sunucunun Türkçe `'error'` metnini taşıyor (ör. "Sadece Bekliyor durumundaki tohumlama boş ilan edilebilir" — `20260924000001:L526`; nil-uuid çağrısında beklenen metin "Tohumlama bulunamadı" — `:L522`; ikisi de kanıt sayılır).

## 7. T1 + T2 — Çift senkron planlama

### 7.1 Kanıt ve sahibin bağlayıcı kararı
- Muafiyet fonksiyonu `_acik_disi_ovsync_hedef`: CONFIRMED `20260924000001:L237` (fn), `:265-271` aktif `cases.protocol_family IS NOT NULL` bloğu (`:269`), `:273-280` açık `gorev_tipi='OVSYNC_BASLAT'` bloğu (`:275`). Senkron zincir görevleri (ILAC/TOHUMLAMA_HAZIRLIK) iki blokta da GÖRÜNMÜYOR → T1 boşluğu.
- **Sahibin kararı (bağlayıcı):** 188 çift zincir **KASITLI, dokunulmaz** (sentez §9-S4). T1 önerisi "kasıtlı ardışık zincirleri engellemeyecek şekilde" revize edilir: mevcut OVSYNC_BASLAT bloğu **ikame edilmez**, üçüncü bir koşul **EKLENİR**; kasıtlı akış (Presynch görevleri kapanınca yeni hedef üretilir) korunur çünkü ek koşul yalnız **açık** senkron görevi varken üretimi durdurur, görevler kapanınca zamanlayıcı normal üretimine döner.
- 188'in kendisi mevcut :273-280 bloğuyla zaten muaf (açık OVSYNC_BASLAT'ı var — demo OBSERVED). Ek koşul 188 davranışını DEĞİŞTİRMEZ (kabul testi D7 ile kanıtlanır).
- T2 (168/186 canlı çift-planlama örnekleri, OBSERVED): kalıcı fix Plan 2 R1 reconcile + Plan 4'e aittir — **bu spec yalnız doğrulama ölçümünü taşır** (D9), implementasyon taşımaz.

### 7.2 Migration taslağı — F2 (gövde-seviyesi)

```sql
-- 20260925000002_cila_t1_acik_disi_senkron_muafiyet.sql (TASLAK — gövde CANLI
-- pg_get_functiondef('_acik_disi_ovsync_hedef(text)')'den kopyalanır; şu blok
-- mevcut :273-280 bloğunun ARKASINA EKLENİR)
CREATE OR REPLACE FUNCTION public._acik_disi_ovsync_hedef(p_hayvan_id text)
RETURNS date ... (canlı imza/ayarlar aynen) AS $fn$
DECLARE ... (canlı) BEGIN
  ... (canlı gövde: MK3 gebelik otoritesi + :265-271 vaka bloğu + :273-280 OVSYNC_BASLAT bloğu aynen) ...
  -- ═══ T1 ek koşulu — açık senkron-protokol görevi varsa yeni açık-dişi hedef üretme ═══
  IF EXISTS (
    SELECT 1 FROM public.gorev_log g
    WHERE g.hayvan_id = p_hayvan_id
      AND g.gorev_tipi IN ('ILAC', 'TOHUMLAMA_HAZIRLIK')
      AND COALESCE(g.tamamlandi, false) = false
      AND COALESCE(g.iptal, false) = false
      AND (g.kaynak ILIKE '%senkron%' OR g.aciklama ILIKE '%senkron%')
  ) THEN
    RETURN NULL;
  END IF;
  ... (canlı kuyruk: _ovsync_kural_tarihi + GREATEST) ...
END; $fn$;
REVOKE ALL ON FUNCTION public._acik_disi_ovsync_hedef(text) FROM PUBLIC, anon, authenticated;
-- (yardımcı fonksiyon — mevcut desen :293; harici çağrı beklenmiyorsa GRANT yazılmaz)
```

**Kapsam parametresi (S1 — sahibe tek-cümlelik soru, sentez §9-12):** filtre yalnız Presynch-14 damgalı görevlerle mi sınırlanmalı, her senkron ILAC zinciri mi kapsansın? Taslak geniş kapsam (`%senkron%`) ile yazıldı; S1 cevabı dar-kapsam isterse yalnız `kaynak ILIKE '%senkron%presynch%'`-tipi daraltma yapılır (final apply ÖNCEKİ, kapı 3.2-4 canlı doğrulamasından sonra).
**V3 — R3 ONARIMINDA ÇÖZÜLDÜ (damga VAR):** canlı demo ölçümü (2026-09-24, SUPABASE_DEMO_PAT query endpoint) `kaynak ILIKE '%senkron%' OR aciklama ILIKE '%senkron%'` filtresiyle **16 satır** buldu — tamamı `ILAC`, `aciklama='39. Gün PG (Presynch-14 senkron)'`, `kaynak='DOGUM-<uuid>'`; **2 tanesi açık** (tamamlandi=false, iptal=false). Damga `aciklama` alanında taşıdığından spec'teki geniş-kapsam filtresi (`kaynak OR aciklama`) canlı veriyle uyumludur; ENGEL-4 tetiklenmez, F2 yazılır. S1 notu: canlıda 'senkron' damgalı tek desen Presynch-14 PG görevleridir — dar-kapsam (presynch) alternatifi de aynı 16 satırı yakalar; canlı veri düzeyinde iki kapsamın farkı bugün sıfırdır (fark ancak gelecekte farklı adlandırılmış senkron göreviyle ortaya çıkar).

### 7.3 Kabul testleri
1. **D7 (demo, kritik — 188 koruması):** hayvan 188 için `_acik_disi_ovsync_hedef` F2 sonrası da üretim döndürüyor (kasıtlı zincir etkilenmedi) — apply öncesi/sonrası çıktı birebir eş.
2. **D8 (demo):** açık senkron ILAC görevi olan (ve açık OVSYNC_BASLAT'ı olmayan) test hayvanında fonksiyon NULL döner; görev kapatıldıktan sonra tekrar tarih döndürür (ardışık zincir akışı korunur).
3. **D9 (demo ölçüm, T2):** Adım 3 temizlik sonrası — açık sessiz `VETERINER_KONTROL` görevi İLE aynı hayvanda açık `TEDAVI_GUN`/`ILAC` senkron görevi çakışması **0 satır**:
```sql
SELECT count(*) FROM public.gorev_log g
WHERE g.gorev_tipi='VETERINER_KONTROL' AND COALESCE(g.tamamlandi,false)=false AND COALESCE(g.iptal,false)=false
  AND EXISTS (SELECT 1 FROM public.gorev_log g2
              WHERE g2.hayvan_id=g.hayvan_id AND g2.gorev_tipi IN ('TEDAVI_GUN','ILAC')
                AND COALESCE(g2.tamamlandi,false)=false AND COALESCE(g2.iptal,false)=false);
```

## 8. T7 — Plan-drift topluluğu (beş bağımsız küçük madde)

### 8.1 O10 — Toplu gönderim öncesi önizleme yok
- Kanıt: CONFIRMED `js/ui.js:9229-9234` (`dataTrafficGonder` doğrudan `syncNow()`; önizleme/onay yok).
- **F5 tasarımı:** `syncNow()` öncesi sayı+tablo kırılımı gösteren onay adımı: kuyruktan `getQueue()` ile kırılım (`gorev_log × n, tohumlama × m …`) içeren `confirm()` (mevcut UI dili Türkçe; ayrı sheet GEREKMEZ — en küçük doğru çözüm). Tek-kayıt `↑` (ui.js:9220 — R3 onarımda satır tazelendi) onaysız kalır.
- Kabul: **D10 (demo):** 3+ kayıtlı kuyrukta "Tümünü Gönder" → kırılım metni görünüyor, iptal edilebiliyor; onay sonrası syncNow eskisi gibi.

### 8.2 D18 — Erteleme özeti görünmüyor + ham hata JSON'u
- Kanıt: RPC `toplam_erteleme_gun` döndürüyor CONFIRMED `20260923000003:L620-625`; UI toast'u bu alanı göstermiyor CONFIRMED `js/ui.js:1058-1059` (R3 onarımda satır tazelendi; `_erteleKaydet` :1050-1066); `GOREV_ERTELENEMEZ`/`GECMIS_TARIH` kodları sözlükte yok → errorHandler jenerik dalına düşüyor (CONFIRMED `js/utils/errorHandler.js` USER_FRIENDLY döngüsü :54-56; sözlük :7-13'te 5 anahtar; `js/config.js:183` PG_HATA_SOZLUGU'nda da bu iki kod YOK — çakışma riski yok).
- **F5:** toast'a `r.toplam_erteleme_gun` eklenir: `'✅ Ertelendi → … · toplam N gün erteleme'` (N>0 ise). **F7:** `USER_FRIENDLY`'ye `GOREV_ERTELENEMEZ` ve `GECMIS_TARIH` anahtarları (Türkçe cümleler) eklenir.
- Kabul: **D11 (demo):** ertelenmiş görevde toast toplam günü gösteriyor; **U6 (birim):** getUserMessage iki kod için Türkçe cümle döndürüyor; zincir-tipi görev (BESLEME) ertelenmek istendiğinde ham JSON değil Türkçe mesaj.

### 8.3 D19 — Vaka-kapanış özeti eksik + ölü fallback anahtarı
- Kanıt: RPC `otomatik_bos_sayisi` (iptal görev sayısı) ve `kapatilan_senkronizasyon_vakalari` döndürüyor CONFIRMED `20260923000005:L533-539`; UI `kapatilan_ovsyncler` ölü fallback anahtarını okuyor (hiç üretilmiyor) ve `otomatik_bos_sayisi`'yi göstermiyor CONFIRMED `js/forms.js:346-350`.
- **F6:** ölü `|| result?.kapatilan_ovsyncler` silinir; özete iptal görev sayısı eklenir: `'… — N senkronizasyon protokolü sonlandırıldı, M görev otomatik iptal edildi'` (N/M > 0 ise).
- Kabul: **U7 (birim):** mock result ile özet metni üretimi (N=2, M=3 → doğru cümle; hepsi 0 → özet YOK, yalnız standart toast). **D12 (demo):** tohumlama kaydında senkron vakası kapanan senaryoda özet görünüyor (plan-5 §3.2 K1/K2 yürüyüşüne bağlanır).

### 8.4 D17 — `start_first_service_protocol` pull seti alt-küme
- Kanıt: CONFIRMED `js/api.js:321` — set `['cases','treatment_days','treatment_day_uygulamalar','drug_administrations','gorev_log','islem_log','stok','stok_hareket']`; plan kümesinde olup eksik üç katalog tablosu: `diseases`, `drugs`, `tedavi_sablonu` (tablo adları CONFIRMED `js/api.js:35`).
- **F4:** üç tablo sete eklenir. Katalog tabloları küçüktür; pull maliyeti önemsiz (INFERRED).
- Kabul: **D13 (demo):** RPC tetiklendiğinde üç tablonun IDB'ye indiği (get sayıları > 0) ve `TABLES` filtresiyle çakışmadığı; **U8 (birim):** `RPC_TABLES.start_first_service_protocol` seti tamamlanmış.

### 8.5 O11 — TZ drift: `p_occurred_at` browser-yerel saat
- Kanıt: CONFIRMED `js/ui.js:2338-2340` — `occurredAt = new Date(olcGun + 'T' + (olcSaat || '12:00') + ':00').toISOString()` → girilen tarih+saat **tarayıcının yerel dilimiyle** yorumlanır; PLAN Europe/Istanbul der. `p_occurred_at` üreten tek nokta burası (OBSERVED grep — `js/` ağacında tek `p_occurred_at` satırı).
- **F5:** sabit İstanbul ofsetiyle anchor: `new Date(olcGun + 'T' + (olcSaat || '12:00') + ':00+03:00').toISOString()` (Türkiye kalıcı +03, DST yok — INFERRED; standart kural "PLAN İstanbul der"). Kullanıcı başka dilimde olsa da kayıt İstanbul saatiyle sabitlenir; mevcut TR kullanıcılarında davranış farkı yalnız +03 dışı yerel dilim kurulu cihazlarda ortaya çıkar (düzeltme).
- Kabul: **U9 (birim):** `_protokolUygulaKaydet` tarih-saat kurulumu mock'lanır — '24.09.2026 12:00' → `2026-09-24T09:00:00.000Z` (İstanbul +03 sabitlenmiş); cihaz-diliminden bağımsız aynı çıktı.

## 9. T8 + T10 — Ölü dal ve rozet-panel tutarlılığı

### 9.1 T8
- §6.1'de kanıtlandı; fix §6.2 maddeleri 3-4'te (api.js mesaj + ui.js ölü-dal silme). Ayrı migration YOK.
- Kabul: **U10 (birim):** `rpc()` mock'ta `{ok:false, error:'Türkçe mesaj'}` → thrown `Error.message` = 'Türkçe mesaj'; **D6** (§6.3) ile demo kanıtı paylaşılır.

### 9.2 T10 — Rozet ↔ panel sayı tutarlılığı
- Kanıt: rozet yalnız `protokol_eksik_tara` çıktısını sayıyor CONFIRMED `js/ui.js:413-424` (rozet filtresi :417); `protokol_eksik_tara`'da OVSYNC bölümü YOK (bölümler: A doğum-sonrası :25, B ileri gebe :127, C kızgınlık :264 — CONFIRMED `20260718000001:L25,L127,L264` + `RETURN v_result` :344; **canlı gövdede de OVSYNC yok — R3 onarımında OBSERVED**, plan V10); panelin OVSYNC bölümü ayrı RPC `ovsync_baslat_uyarilari`'ndan besleniyor CONFIRMED `js/ui.js:1829-1847` (ovHtml :1829, rpc :1831, ovList :1832; canlıda RPC mevcut — OBSERVED).
- **Tasarım (b2 — varsayılan, DB değişikliği YOK):** `loadDash` rozet bloğu ikinci RPC'yi de çağırıp tek rozette birleştirir: `rozet = aktifProtokolSayısı + ovUyarıSayısı`; `window.__ovsyncUyarilar` önbelleğine yazar, panel (ui.js:1832, ovList okuma — R3 onarımda satır tazelendi) taze kayıt yoksa bu önbelleği kullanır (çift çağrı önlenir; panel açılışında kendi çağrısı her zaman tazeler).
- **Alternatif (a) — S3'e bağlı:** OVSYNC bölümünün `protokol_eksik_tara`'a katılması (tek DB kaynağı) — SK9/D9 tercihiyle çelişip çelişmediği sahibe sorulur; bu turda uygulanmaz, kayıt altında.
- Kabul: **D14 (demo — ölçülebilir formül):** rozet sayısı == panel başlık toplamı `(🔴 Gecikmiş + 🟡 Yaklaşan + 🌱 İlk Tohumlama)`; `99+` üstü tırmanma davranışı korunur; **U11 (birim):** birleştirme fonksiyonu (`protokol n + ov m` → n+m; ov çağrısı hata → yalnız n, konsol uyarı — mevcut `catch` deseni ui.js:424).

## 10. T11 — Sahibe not (kod değişikliği YOK)

"veri-eşleşme özeti hepsi→0" ile aracın BULGU:57 hükmü arasındaki fark **operasyonel rapor okuma disiplini** konusudur (CONFIRMED full-scope O19). Bu spec'in iş listesine girmez; teslim raporunda sahibe tek paragraf not olarak sunulur.

## 11. Geri-dönüş planı

| Değişiklik | Geri dönüş |
|---|---|
| F1 (`gorev_tamamla` +p_iptal) | Öncesi canlı gövde `pg_get_functiondef` çıktısı migration başına yorum olarak gömülür; geri dönüş = o gövdeyle `CREATE OR REPLACE` (eski imzaya döner; yeni 3-arg imza DROP edilir). UI tarafı `p_iptal` gönderimi tek satır — revert basit. |
| F2 (`_acik_disi_ovsync_hedef` ek koşul) | Aynı yöntem: öncesi canlı gövde gömülü; geri dönüş = eski gövde geri yüklenir. Ek koşul tek blok olduğundan blok-silmeli revert de yeterli. |
| F3 (overload DROP) | `DROP` geri alınamaz — F3 apply'dan ÖNCE eski overload gövdesi migration içine `CREATE OR REPLACE FUNCTION public.tohumlama_sonuc_bos(text) ...` olarak gömülür (revert = yeniden oluştur). Bu gömme F3'ün zorunlu bölümüdür. |
| F4-F7 (JS) | Git revert; `?v=` sürüm damgası tek değer güncellenir (teslim mekaniği kuralı). |
| Demo DB verisi | T5/T1/T6 demo-apply adımları şema-değişikliktir, veri silmez; T2 ölçümü salt-okunurdur. Veri yazan tek adım Plan 2 temizliğidir (bu spec dışı, dry-run'lı). |

## 12. Varsayımlar ve UNKNOWN listesi

| # | İfade | Etiket |
|---|---|---|
| V1 | `gorev_tamamla` canlı imzası `(text,text)` (ground_truth:7486'dan) | **CONFIRMED — canlı (R3 onarımı):** demo pg_proc'ta tek imza `(text,text)`, `SET search_path` YOK; F1 apply öncesi birebir gövde karşılaştırması K-4 olarak sürer |
| V2 | canlı `gorev_tamamla` gövdesinde islem_log INSERT deseni mevcut (F1 iptal-branı izini ona göre yazar) | **UNKNOWN** — canlı gövde okuması şart (Adım 1) |
| V3 | senkron zincir görevlerinde `kaynak`/`aciklama` 'senkron' damgası canlı demo'da geçiyor | **CONFIRMED — canlı (R3 onarımı):** 16 satır (tamamı ILAC, "39. Gün PG (Presynch-14 senkron)"), 2'si açık; bkz. §7.2 |
| V4 | canlıda `tohumlama_sonuc_bos` (text) overload'ı hâlâ duruyor ve davranışsal fark taşıyor | **ÇÜRÜTÜLDÜ — canlı (R3 onarımı):** demo pg_proc'ta tek imza `(text,text)`; overload YOK → F3 İPTAL (§5.3) |
| V5 | Türkiye saat dilimi kalıcı +03 (DST yok) → O11 fix'i tek sabit ofsetle güvenli | INFERRED (genel bilgi) + plan kuralı |
| V6 | RPC_MAP replay'inin queuelanan `gorev_log` PATCH'lerini iptal-tipli op'lar olarak aldığı (üretici `write()` yolu, ui.js:1193) | CONFIRMED kod yolu; canlı kuyruk içerik dağılımı UNKNOWN (client-IDB — ölçülemez, tasarım her iki opu doğru taşıyacak şekilde) |
| V7 | `start_first_service_protocol` pull setine üç katalog tablosu eklenmesinin kullanıcı-görünür yan etkisi yok | INFERRED (katalog küçük + B27 fetcher'ları mevcut, api.js:472) |
| V8 | rozet birleştirmesi için ek RPC çağrısı dashboard yükünü kabul edilebilir ölçüde artırır (mevcut 2 RPC'ye 1 ekleme) | INFERRED |
| V9 | 188'in kasıtlı zinciri F2'den etkilenmez (açık OVSYNC_BASLAT bloğu :273-280 korunur) | CONFIRMED (kod yapısı) + demo OBSERVED — D7 ile mühürlenir |
| V10 | `protokol_eksik_tara`'da OVSYNC bölümü yok | CONFIRMED `20260718000001` bölüm yapısı (canlı gövde de Adım 0'da tek sorguyla teyit edilir) |

## 13. Açık kararlar (Tur 2 başında sahibe seri sunulur — spec'i DURDURMAZ, varsayılanla ilerler)

1. **S2 (T5):** Seçenek A (`p_iptal` RPC parametresi — önerilen) mi, B (REST PATCH replay) mi?
2. **S1 (T1):** senkron muafiyet kapsamı — her senkron ILAC zinciri (taslak) mi, yalnız Presynch-14 mü? *(R3 notu: canlı veride 'senkron' damgalı tek desen Presynch-14'tür — bkz. §7.2; iki kapsam bugünkü veride aynı sonucu verir.)*
3. **S3 (T10):** rozet-panel tek veri kaynağına DB geçişi (alternatif a) isteniyor mu — varsayılan (b2) DB'siz birleştirme.
4. **~~T6-F3 onayı~~ → BİLGİ NOTU (R3 onarımı):** canlıda legacy overload zaten yok; F3 iptal edildi (§5.3), onay sorusu kalktı.

## 14. Uygulama sırası ve çıkış kapıları

1. Adım 0 (bu spec'in ölçümleri): §5.2 + §7.2 sorguları (salt-okunur, demo) — **R3 onarımında V1/V3/V4 zaten canlıdan kapandı** (bkz. §7.2, §12); kalan: 'Boş/Bos' dağılımı + anon ayrıcalık sayımı + D7 ön-ölçümü. 3 kırmızı unit test triage'ı (plan-5 §3.4) R3 onarımında teyit edildi: 1089 test / 1086 pass / 3 fail (2 tarih-seçici UI regresyonu + LUNA-3 canlı DEMO şema) — plan beklentisiyle birebir.
2. T5: F1 (db-validate taslak→final→demo-apply) + F5 tek satır + U1-U2 → D1-D3.
3. T3/T4/T8: F6, F5 (flush + pgKapi), F4 (rpc mesaj) + U4-U5, U10 → D4-D6.
4. T1: F2 (damga kanıtlı — §7.2) → D7-D8; T2 doğrulama D9 (Plan 2 temizliğinden sonra koşar — bu spec'in sırasını bekler).
5. T6: **F3 İPTAL (R3 onarımı — canlıda overload yok)**; kalan yalnız Ö1 kanıt kaydı + Ö3 davranış yürüyüşü.
6. T7/T10: F4-F7 + U6-U9, U11 → D10-D14.
7. Sahibin yürüyüşü: plan-5 §3 checklist (K1-K8; K5=PG kapı, K8=rozet tutarlılığı maddeleri bu spec'le bağlantılı).
8. **Son review kapısı** (sahibin talebi): ayrı review turu — bu spec'in tüm kabul maddeleri yeniden ölçülür; BUGS.md borç kalemlerine (T9, erteleme-geneli) yeni borç EKLENMEDİĞİ teyit edilir. *(R3 notu: BUGS.md'deki iki borç girdisi — BUG-ERTELEME-KURAL-GENEL :183, BUG-KUYRUK-SHEMA-VERSIYONU :195 — çalışma ağacında mevcut ama commit edilmemiş; teslim kulvarı bunları commit'lemekle yükümlü, içerik değişmez.)*
