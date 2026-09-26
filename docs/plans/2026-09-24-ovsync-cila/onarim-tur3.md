# ONARIM TUR 3 — S5 spec/plan kalan boşluk kapatma kaydı (2026-09-24, 23:40+)

- **Tetik:** Reviewer FAIL; workflow'tan bulgu listesi gelmedi (`BULGULAR: undefined`) → bağımsız yeniden doğrulama.
- **Bağlam:** R3 (972c803) ve 2. onarım turu (7b63bcc) bu dosya ailesinin büyük bölümünü kapatmıştı. Bu tur, tüm kanıt iddialarını **bağımsız olarak** yeniden doğruladı; önceki turların kapattıkları teyit edildi ve yalnız **kalan boşluklar** işlendi.
- **Yöntem:** repo satır-okumaları (grep/sed, kanıt etiketli) + **canlı demo psql pooler** (`SUPABASE_DEMO_POOLER` + `SUPABASE_DEMO_DB_PASSWORD`, salt-okunur SELECT; R3'ün kullandığı `SUPABASE_DEMO_PAT` query-endpoint'iyle aynı demo hedefi, alternatif kanal) + yerel `egesut_lsp` aynası (çapraz-check).
- **Yetki zarfı:** yalnız bu dizin (spec-s5.md, plan-s5.md, bu kayıt). Koda dokunulmadı; BUGS.md'ye dokunulmadı.

## 1. Önceki turların kapattıkları — bağımsız teyit (yeniden ölçüldü, uyumlu)

- **B1/T6-F3 İPTAL teyit:** canlı demo `tohumlama_sonuc_bos` **tek imza** `(text,text)`; `(text)` overload yok; ASCII `'Bos'` gövdede yok. Ağaç-geçmişi çelişkisi (20260403000001:6 DROP → 20260512000006:4+44 yeniden CREATE + anon GRANT, sonrası DROP yok) ile canlı tek-imza arasındaki fark R3'te "canlı otorite"yle çözülmüştü — teyit edildi. Ayrıca **yerel ayna (`egesut_lsp`) da tek imza gösteriyor** (çapraz-check; mirror `pg_proc` count=1).
- **B2/V3 damga VAR teyit:** `aciklama ILIKE '%senkron%'` → 16 satır (tamamı ILAC, '39. Gün PG (Presynch-14 senkron)', kaynak 'DOGUM-<uuid>'), **2'si açık** (ayrı count sorgusuyla doğrulandı). `kaynak ILIKE '%senkron%'` → **0 satır**.
- **V1/V2 teyit:** canlı `gorev_tamamla` tek imza (text,text), `proconfig` NULL (SET search_path YOK), gövde `islem_log` INSERT içeriyor; `anon=false`, `authenticated=true` (2. turun AYNA-OBSERVED V2 kaydıyla uyumlu; bu tur **canlı demo'da** doğruladı).
- **V10 teyit:** canlı `protokol_eksik_tara` gövdesinde 'OVSYNC' yok (`position`=0).
- **Ayna-canlı birebirlik:** `_acik_disi_hedef_ic` gövdesi whitespace-normalize md5 **eş** (canlı demo ↔ `egesut_lsp` aynası) → ayna, kanıt katmanı olarak güvenilir (bu iş için).
- **Baseline teyit:** `npm run test:unit` → 1089 test / 1086 pass / **3 fail** (LUNA-3 canlı DEMO şema + bc-tarih 2 alttest) — plan Adım 0 beklentisiyle birebir.

## 2. Bu turun kapattığı KALAN boşluklar (önceki turlarda yoktu)

| # | Boşluk | Kanıt | İşlem |
|---|---|---|---|
| C1 | **Spec §5.2 ölçüm SQL'i BOZUK:** `WHERE sonuc ILIKE '%bos%' OR tohumlama_durumu ILIKE '%bos%'` — `tohumlama_durumu` kolonu `tohumlama` tablosunda YOK (canlı ERROR: "column does not exist", OBSERVED 2026-09-24). Kolon `hayvanlar`'dadır (canlı `information_schema.columns` teyidi; 20260924000001:536 `UPDATE public.hayvanlar SET tohumlama_durumu`). R3'ün "Adım 1'den kalan: dağılım + anon sayımı" maddesi bu sorguyla koşsaydı hata verirdi | OBSERVED canlı + kolon listesi | spec §5.2 iki ayrı SELECT'e düzeltildi; **sorgular canlıda koşuldu**: `tohumlama.sonuc` = 'Boş' 137 / 'Doğum Yaptı' 82 / 'Gebe' 43 / 'Bekliyor' 31 / 'Abort' 4 (ASCII 'Bos' **0**); `hayvanlar.tohumlama_durumu` = NULL 91 / 'gebe' 38 / 'Gebe' 28 / 'Boş' 8 / 'bos' 2 / 'Tohumlanabilir' 1; anon=false. **Ö1 kanıtı TAMAMLANDI** (plan Adım 1-2 + spec §5.4) |
| C2 | **Veri-notu (kapsam dışı, kayıt):** `hayvanlar.tohumlama_durumu`'nda case-variant kirlilik ('gebe' küçük-harf ×38, 'bos' ASCII ×2). Muafiyet otoritesi bu kolonu değil `tohumlama.sonuc`'u okur (temiz: 'Gebe' 43/'Bekliyor' 31, case-variant yok) — davranışa etkisi bu spec yoluyla yok; kirli kolonu okuyan başka yollar T6 ölçüm raporuna not | OBSERVED canlı dağılım | spec §5.2 + plan Adım 1-2'ye not |
| C3 | **Spec §7.3-D7 yanlış beklenti:** "188 için F2 sonrası da **üretim döndürüyor**" — 188 canlıda **NULL** döndürüyor (açık OVSYNC_BASLAT muafiyeti; `_ovsync_kural_tarihi`=2026-10-06 üretim için hazır). Eş-kanıtı NULL=NULL'dur; "üretim etkilenmedi"nin güçlü kanıtı yoktu | OBSERVED canlı: 188 = kupe `188`, id `f5124a14-ab80-4028-a799-09d165466b24`, 1 açık OVSYNC_BASLAT, fonksiyon → NULL | spec §7.3-D7 + plan Adım 11 koşum satırı düzeltildi; **D7-b eklendi**: genel üretim sayısı apply öncesi/sonrası eş — `SELECT count(*) FILTER (WHERE public._acik_disi_ovsync_hedef(id) IS NOT NULL), count(*) FROM public.hayvanlar WHERE durum='Aktif' AND cinsiyet='Dişi'` → **ön-ölçüm 13/115 kaydedildi** (canlı) |
| C4 | **Plan Adım 11-D8 damga-alan hizasızlığı:** D8 "test satırına `kaynak ILIKE '%senkron%'`'lu görev yaz" diyordu — oysa R3'ün kendi B2 bulgusuna göre damga canlıda **`aciklama`** alanında; `kaynak`'a damga yazan test, F2 filtresinin canlıda işleyen bacağını (aciklama) test etmez | CONFIRMED tutarsızlık (plan §0 V3 notu ↔ Adım 11-D8) | D8, damga `aciklama`'ya yazılacak şekilde düzeltildi (spec §7.3-2 + plan Adım 11) |
| C5 | **Adım 1-4 (V10) ve Adım 1-5 (D7 ön-ölçüm) tamamlanmış işlere dönüştürüldü:** V10 canlı teyidi (position=0), 188 id çözümü + NULL ön-ölçüm + D7-b 13/115 — Adım 1'den kalan tek DB işi **yok** (yalnız K-4 apply-zamanı gövde gömmeleri kalır) | OBSERVED canlı | plan Adım 1 maddelerine 3. TUR NOTU |

## 3. Benimsenen önceki-tur kararları (değişiklik yok)

- **F7 hedefi:** 2. turun "errorHandler.js'te bilinçli tutma" kararı benimsendi (davranış `msg.includes` döngüsünde eşdeğer; dosya zarfı F1-F8 korunuyor). `js/config.js` `PG_HATA_SOZLUGU` (:183) alternatifi spec §8.2'de kayıt altında. Bu turun doğrulaması: `GOREV_ERTELENEMEZ`/`GECMIS_TARIH` iki sözlükte de yok (çakışma riski 0); jenerik dal ham `KOD:{json}` metnini geçirir ( getUserMessage errorHandler:59 ':' kuralıyla) — bulgu geçerli.
- **K-7 / ENGEL-5:** `supabase_migrate` MCP = PROD hedefli (R3 B3) — bu turda doğrulandı ve benimsendi; bu turun canlı ölçümleri psql pooler kanalıyla yapıldı (PROD'a dokunulmadı; tools-bank `SB_PROJECT=zqne…` server.py:312 — R3 ile uyumlu).
- **Tutarlılık turu paralel düzenmeleri** (migration `<BOŞ-NUMARA>` kuralı, `?v=20260925-02` bump koordinasyonu (S5 kapanışında uygulandı — 2026-09-25, index.html tek değer -02), Adım 3-3 K-7 kanal notu): aynı dosyada paralel ajanın tamam edilmiş, benimkiyle çakışmayan düzeltmeleri — benimsendi, dokunulmadı.

## 4. ENGEL durumu (bu tur sonrası)

- ENGEL-1 (drift hedef): kapalıydı — teyit.
- ENGEL-2 (D9 ertelenmiş): değişiklik yok (Plan 2 sonrası).
- ENGEL-3 (T6-F3): **kapandı** (R3; bu turda ayna çapraz-check'iyle pekişti).
- ENGEL-4 (F2 damga): **kapandı** (R3; bu turda açık-görev sayısı 2 ile netleşti).
- ENGEL-5 (araç): **kapandı** — çalışan kanallar kanıtlandı (psql pooler bu turda; PAT query endpoint R3'te).
- ENGEL-6/7: değişiklik yok.

## 5. Sıradaki adım

Implementasyon kulvarı planın güncel haliyle koşmaya hazır: Adım 0 baseline + Adım 1'in V1/V2/V3/V10/T6/D7-ön bölümleri bu turda (ve R3'te) kanıtlandı — **tekrar koşulmaz**; Adım 1'den kalan yalnız K-4 apply-zamanı canlı gövde gömmeleridir. JS kulvarı (Adım 6-9, 13) bağımsız başlayabilir.
