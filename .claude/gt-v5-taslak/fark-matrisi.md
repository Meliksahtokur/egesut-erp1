# Fark Matrisi — GT ↔ Canlı(snapshot) ↔ rpc-reference (gt-taslak, 2026-09-02)

> **Yöntem:** Supabase'e SIFIR çağrı. Kanıt zinciri: `.claude/schema-snapshots/2026-08-31-live-schema-imzalar.md`
> (canlı imzalar) · `supabase/migrations/99999999999999_ground_truth.sql` (GT, worktree e6d8782) ·
> `supabase/migrations/` kanonik sıra (gövde niyeti, son kazanan) · `.claude/rpc-reference.md` · `js/`.
> Gövde karşılaştırmaları Python normalize ile (yorum at, whitespace düzleştir, DEFAULT değerlerini at,
> `without time zone`/`character varying` at/çevir, `int`≡`integer`, şema prefix'i at).

## §A — Delta durum: audit'in 17 denetimli-regen maddesinin akıbeti

IDLE-GÖREV.md delta notu doğru çıktı: 2026-09-01 sonrası ara oturumlar (ikiz doğum 048b39c,
küpe revizyonu 31bd93, GT sync 3f1e57f, review e6d8782) audit maddelerinden **HİÇBİRİNİ**
kapatmadı — GT sync yalnızca YENİ işlerin (olay_id, dogum_kaydet v2, sayım 10+7=17) GT'ye
işlenmesini kapsadı. 17 maddenin tamamı hâlâ AÇIK:

| # | Nesne | GT durumu (e6d8782) | Canlı snapshot (2026-08-31) | rpc-reference | Çözüm / taslak |
|---|---|---|---|---|---|
| 1-3 | `_guard_dogum_ileri_tarih` · `_guard_hayvanlar_cinsiyet_grup` · `_guard_tohumlama_yas_cinsiyet` | YOK (grep 0 eşleşme) | VAR (trigger) | — (internal trigger, kapsam dışı notu) | Taslak A§1-3; gövde 20260831000003 |
| 4 | `_tohumlama_gorev_uygunluk(2p)` | YOK | VAR :: text | — (internal) | Taslak A§4; gövde 20260730000002:21 |
| 5-6 | `agent_plans_prune` · `agent_threads_prune` | YOK | VAR :: void | "kullanılmıyor (cron)" notu | Taslak A§5-6; gövdeler 20260622000001 / 20260621000004 |
| 7 | `planli_tohumlama_kaydet(8p)` | YOK | VAR (imza 8p ✓) | VAR (forms.js:334 dinamik) | Taslak A§7; gövde 20260730000001:478 (son kazanan) |
| 8-9 | `search_code` · `search_memory_notes` | YOK | VAR (pgvector, TABLE) | "kullanılmıyor (tools-bank)" | **STUB** — migrations zincirinde tanım YOK (backup/ dahil tarandı); gövde canlıdan |
| 10 | `tedavi_sablon_tohumlama_gorev_ekle(2p)` | YOK | VAR | VAR | Taslak A§10; gövde 20260730000002:45 (son kazanan) |
| 11 | `vaka_tohumlama_ekle(3p)` | YOK | VAR | VAR | Taslak A§11; gövde 20260730000002 (tek tanım) |
| 12 | `tohumlama_abort` | 2-param (GT:6536) | 3-param ANA + 2-param eski overload | VAR (3p işaretli) | Taslak B; gövde 20260830000034:9. Regende İKİ imza da canlıdan alınmalı |
| 13 | `_gorev_dinle` | 3-param (GT:9416) | 4-param (`p_tarih date` ekli) | — (internal) | Taslak B; gövde 20260628000002:28. Canlıda 3p overload görünmüyor → regende overload sayısı da doğrulanmalı |
| 14 | `tohumlama.id` | `text` (GT:116) | **uuid** | — (js metin id kullanır; `id::text` gövde cast'leri uuid'de çalışır) | GT v5'te `id uuid` yazılır; ALTER taslağı C§14 (FK bağımlılığı YOK) |
| 15 | `stok_hareket.id` | `text` (GT:40) | **uuid** | — | GT v5'te `id uuid`; ALTER taslağı C§15 (FK bağımlılığı YOK) |
| 16 | `hekim_listesi()` | CREATE yok + GRANT var (GT:2610) | **YOK** (185 adda değil) | "⚠️ CANLIDA YOK" notu | **Karar dosyası**: hekim_listesi-karar.md — öneri (b) temizleme |
| 17-20 | GT iç duplikatları (`add_treatment_day` 1667+11076 · `update_treatment_time` 914+11432 · `set_deneme_no` 876+1883 · `drug_product_ekle` 932+5725) | HÂLÂ duplikat | tek imza | — | Regende otomatik tekilleşir (taslak yok); GT'nin ara `DROP FUNCTION` satırları (3698, 5032) sıralı-yeniden-oynatma içindir, regen bunları içermez |
| 21-22 | kozmetik alias + DEFAULT gösterimi | — | — | — | İşlem yok (audit kararı değişmedi) |

**Dolgu sayımı:** audit özeti "GT 182 CREATE / 174 ad" — GT e6d8782'de +dogum_kaydet sync ve
+2 yeni fn (hayvan_belirsiz_ureme_listele, kupe revizyonu işleri mevcut adları REPLACE etti)
sonrası kesin sayım regen oturumunda yeniden alınmalı (bu görev için kritik değil; tablo §B ile sınırlı tutuldu).

## §B — DELTA: 20260901000001/000002 (ikiz doğum + küpe revizyonu) fn'lerinin GT ↔ migration durumu

Canlı imza snapshot'ı BU İKİ MIGRATION'dAN ÖNCE alındığı için üçüncü sütun burada "migration
son-kazanan imzası"dır (canlıya bu dosyalar deploy edildi: 048b39c "canlı DB deploy tamam",
e6d8782 "redeploy bu commit ile" — memory + commit mesajları).

| Fn | Migration (son kazanan) | GT karşılığı | Sonuç | Aksiyon |
|---|---|---|---|---|
| `dogum_kaydet` (8p) | 20260901000002:76 | GT:9743 | **EŞİT** (normalize; yalnız `$function$`/`$$` + LANGUAGE konumu biçim farkı). `gorev_sayisi` THEN 10 ✓, `buzagi_kupe` ✓, olay_id ikiz mantığı ✓ | Yok — senkron doğrulandı |
| `hayvan_belirsiz_ureme_listele()` | 20260901000001:153 | GT:7971 | **EŞİT** (birebir, 990B) | Yok |
| `kupe_musait_mi` (3p) | 20260901000002:29 | GT:2115 | **GT ESKİ** — benzerlik 0.49; GT `v_kupe_cakisma` iki-durumlu eski gövde, migration üç durumlu (`v_aktif_cakisma`, `v_gecmis_id`, `v_gecmis_durum`, `<>`, aktif-filtre K1 + global devlet K2) | **YENİ sapma** → taslak D1 |
| `hayvan_ekle` 15p overload | 20260901000002:227 | GT:7125 | **GT ESKİ** — benzerlik 0.71; migration `v_yas_gun`/`v_chk` + `kupe_musait_mi(p_kupe_no, p_devlet_kupe)` ön kontrolü içeriyor | **YENİ sapma** → taslak D2 |
| `hayvan_guncelle` 18p overload | 20260901000002:311 | GT:8219 | **GT ESKİ** — benzerlik 0.70; migration `v_efektif_dt`/`v_efektif_grup`/`v_yas_gun` + küpe kontrolü | **YENİ sapma** → taslak D3 |
| `asistan_hayvan_detay` (2p) | 20260901000002:428 | GT:519 | **GT ESKİ** — benzerlik 0.98; migration kupe eşleşmesinde `ORDER BY (durum='aktif') DESC, id` (K7 aktif-öncelik) | **YENİ sapma** → taslak D4 |

rpc-reference bu 6 fn'nin tamamında GÜNCEL (kupe revizyon notları 2b41bd0/0ddebc2 ile işlenmiş;
dogum_kaydet ikiz bölümü 3f1e57f). Yani sapma yalnızca GT dosyasında.

**Sonuç:** GT sync (3f1e57f) bilinçli olarak dar kapsamlıymış (olay_id + dogum_kaydet v2 + K1/K5
içerikleri dogum_kaydet içinde). Küpe revizyonunun hayvan_ekle/guncelle/kupe_musait_mi/
asistan_hayvan_detay gövdeleri GT'ye hiç işlenmemiş — bunlar audit'in 17 maddesine EK 4 delta
maddesidir ve toplam denetimli-regen kapsamını **21 maddeye** çıkarır.

## §C — Sayım gizemi: "195 giriş" vs 189 imza / 185 ad — **UNVERIFIED**

Kesin sayımlar (dosyadan, script ile):

- Snapshot fn bloğu: **189 fiziksel imza satırı**, **185 benzersiz ad**; overload'lu adlar:
  `hayvan_ekle`(2), `hayvan_guncelle`(3), `tohumlama_abort`(2) → 189 − 4 = 185 ✓ tutarlı.
- Başlık: "195 giriş". Fark: **+6**.
- Aynı desen tablolarda da var: başlık "44 tablo", liste **47 girişe** ayrışıyor (fark −3;
  47'nin 3'ü id'siz yapılar: `protokol_ayar`, `vaccine_diseases`, `hayvan_override`).

### Hipotezler (kanıt sırasıyla)

1. **Başlık sayısı ayrı bir `count(*)` sorgusundan geldi, liste elle derlendi ve uzlaştırılmadı**
   (en güçlü hipotez — tablo tarafındaki 44↔47 ters yönlü farkı bunu destekliyor: iki başlık
   sayısı da listeden türetilmemiş). Plan dosyası (2026-08-31-fix-roadmap:109) snapshot'ı
   tamamlanırken "195 fn + 44 tablo" olarak kaydetmiş; yani sayılar P3 yürütme anından.
2. Ham `pg_proc` sayımı `prokind` filtresiz alınmış olabilir (+6: aggregate/window/procedure
   kayıtları veya extension-ait girişler). pgvector/tools-bank kurulumu `public` şemasına fn
   bırakmış olabilir (bkz. #8-9: search_* fn'leri migration dışı kurulmuş — aynı kurulum
   başka yardımcı fn'ler de bırakmış olabilir).
3. Liste elle derlenirken 6 iç/sistem girişi atılmış olabilir.

### Çözüm — denetimli regen oturumunda tek sorgu seti

```sql
-- A) ham sayı (başlıktaki 195'in kaynağı testi):
SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public';
-- B) türe göre kırılım (prokind filtresi farkını görünür kılar):
SELECT p.prokind, count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' GROUP BY 1;
-- C) listede olmayan 6 aday (195 - 189 = 6):
SELECT proname FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
EXCEPT SELECT <189 satırlık liste — snapshot'tan taşınır>;
```

Sonuç satırı regen oturumunda snapshot başlığı düzeltilerek veya gerekçeyle işaretlenerek
kapatılacaktır. **Bu görev için durum: UNVERIFIED (DB erişim guardrail'i nedeniyle doğrulanamaz).**

## §D — Kaynak önceliği kararı (regen oturumunda çatışma olursa)

1. **İmza:** canlı `pg_proc` (denetimli oturumda taze çekim) > 2026-08-31 snapshot > migration.
2. **Gövde:** canlı `pg_get_functiondef` > migration son-kazanan (bu paketin taslakları).
3. **rpc-reference:** çağrı yeri/durum notları için; imza otoritesi DEĞİL.
4. 20260901000001/000002 sonrası canlıda imza değişen fn'ler (§B'deki 4 ESKİ-GT gövdesi) için
   snapshot değil migration imzası esastır; regen zaten canlıdan çekerek bunu aşar.
