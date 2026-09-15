# L4-W7 — D2: köprü-önce-tarih-sonra (root R1 düzeltmesi) — TESLİM

- **Rol:** glmf worker (W7) · **Dal:** `agent/geri-alma-akisi-W7` · **Tarih:** 2026-09-15
- **Zarf:** `.ss/tasks/L4-W7-D2-kopru-once.md` · **Kural:** `.ss/tasks/L4-R1-root-duzeltme.md` D2
- **Damga:** `20260914-12` (tek değer; index.html 26 yerel src + manifest + test pin'leri)
- **Sınır:** merge YOK, push YOK, **DB yazma YOK** (probe salt-okunur; canlı ölçüm kısıtı §6)

## 1. Kök ölçüm — zincir dönüşüm tablosu

Kural gereği "önce kök". Lead'in hipotezi ("çözücü `islem_log.tarih`'i takip
başlangıcıyla karşılaştırıyor; köprü varken bile LOG_YOK") **ölçümde
çürütüldü**: çözücüde tarih karşılaştırması yok, zamан-gölgelemesi yok. Gerçek
kök **BOŞ KÖPÜR (hollow bridge)**:

| # | Adım | Dosya:yer | Çıktı / dönüşüm |
|---|---|---|---|
| 1 | Gün pipeline: `l4y-isl-sonuc` (tip `TOHUMLAMA_SONUC`) entry'si | `js/gecmis.js:416-418` | tip `islem`; DEDUP baskılamaz (yalnız tip `TOHUMLAMA` baskılanır) → kartta **undoRef {kind:'l2', id:'l4y-isl-sonuc'}** (`_gmUndoRef`, gecmis.js:577) |
| 2 | `gmUndoClick('l2','l4y-isl-sonuc')` | `js/ui.js:4303` | `_gmIslemLogById` **HİT** (bu kart baskılanmadığından haritada var); IDB yedeğine gerek kalmaz (yedek yalnız birleşik tohumlama kartı içindir) |
| 3 | `dgGeriAlFromEntry(l4y-isl-sonuc)` | `degisiklikler.js:445` | `_gmGeriAlHedef` çağrılır |
| 4 | `_gmGeriAlHedef` yol-1 (köprü) | `js/gecmis.js:122-131` | `degisim_txid` DOLU → hedef **{tablo:'tohumlama', pk:toh_id, txid:T3}** — **zamansız** (kural md.1 zaten uygulanıyor; `_gmGeriAlBaglam`'ın `zaman`'ı hedefe **merge edilmez**, yalnız başlıktır — ölçüldü) |
| 5 | seviye türetme | `degisiklikler.js:448` | `hedef.txid` dolu → **seviye 'islem'** |
| 6 | `degisim_onizle(p_hedef, 'islem')` | migration `20260914000002:144-152` | `SELECT ... FROM degisim_log WHERE txid = T3` → **BOŞ** → `HEDEF_BULUNAMADI` + `detay.neden='LOG_YOK'` |
| 7 | hata UI | `degisiklikler.js:484` | `_dgHataMetni` → `DG_NEDEN_METNI.LOG_YOK`: "Bu olay değişiklik takibi kurulmadan önce yapılmış…" → **S3b-ENGEL-kilitli.png** |

**Neden T3 boş (kökün kendisi):** `yuruyus_kur.sql:62-68` — tohumlama
`sonuc='Gebe'` UPDATE'i psql autocommit **T2**'de; `l4y-isl-sonuc` islem_log
INSERT'i **ayrı T3**'te. Köprü trigger'ı (20260914000003, L4-02a) `degisim_txid`
i**HER ZAMAN** `txid_current()` yazar → islem_log satırı T3'ü taşır; ama T3'te
izlenen-tablo değişikliği yoktur (**`islem_log`, izleme listesinde DEĞİL** —
20260913000001 tablo dizisi; `tohumlama` VAR). Yani köprü dolu ama **izsiz**.
Lead'in psql kanıtı ("ok:true, plan SIL") çelişmez: orada hedef satırın
**kendi** log tx'idleriyle (T1 'I' / T2 'U') kurulmuştu.

Yani mevcut kod txid-first **görünür ve çözücüde doğrudur**; kırılan yol,
**'islem' seviyesinin tüm-tx aramasının boş köprüde LOG_YOK'a düşmesi**dir —
oysa hedef satırın kendi log geçmişi (T1/T2) sağlamdır.

## 2. Kurala göre düzeltme (JS yalnız — DB yazma yok)

**Resolver DOKUNULMAZ** (`_gmGeriAlHedef`): zaten kuralın aynen uyguluyor —
yol-1 köprü (zamansız), tarih kontrolü/zaman yedeği yalnız köprüsüz yol-2/3'te.

**Akış tek kelepçede** (`degisiklikler.js` `dgOnizleGoster` catch — TÜM
yüzeyler buradan geçer):

- Yeni SAF çözücü `_dgKopruSatirYedegi(hedef, e)`: yalnız
  (a) hedef **txid'li + tablo+pk'lı**, (b) hata `HEDEF_BULUNAMADI`,
  (c) neden **`LOG_YOK`** → yedek hedef **{tablo, pk}** (anahtar kümesi TAM o —
  **zamansız**; "zaman yedeği yalnız köprü yoksa" kuralı aynen korunur, tarih
  karşılaştırması hiç yoktur: satırın en yeni log'u RPC'de `ORDER BY id DESC
  LIMIT 1` ile bulunur).
- `dgOnizleGoster` catch'inde **TEK tur** yeniden önizleme: `_dg.bekleyen`
  yedek hedefle güncellenir (uygulama adımı `rpcDegisimGeriAl` aynı
  `_dg.bekleyen`'i kullandığından önizleme=uygulama tutarlıdır). Tek-tur
  garantisi yapısal: yedek hedef txid'sizdir → yedek koşulu yeniden üretilemez.
- `{txid}`-yalnız hedef (GERI_ALINDI) satırsızdır → yedek YOK (gerçekten izsiz
  tx için LOG_YOK meşru kalır).
- RPC hedef biçimi/kodları DEĞİŞMEDİ (k3 regresyon yüzeyi yok); demo verisi
  (boş köprülü satırlar) olduğu gibi çalışır.

## 3. Adversarial testler — `tests/unit/geri-al-kopru-yedegi.test.js` (14 test)

| Zarf md.3 | Test | Sonuç |
|---|---|---|
| T1 iş tarihi takip başlangıcından ÖNCE (2026-09-10) + `degisim_txid` DOLU | çözücü: hedef **köprüden, zamansız**; baglam.zaman hedefe sızmaz; akış: 1. çağrı köprü/'islem', LOG_YOK'ta 2. çağrı {tablo,pk}/'satir', toplam 2 çağrı, uygulama hedefi = yedek | ✔ |
| T2 `degisim_txid` NULL + tarih öncesi | çözücü: {tablo,pk,zaman} (zaman yedeği meşru); akış: **TEK** çağrı, insan dilli LOG_YOK metni aynen | ✔ |
| T3 DEDUP-birleşik kart (undo id islem-id, cf335a8 IDB yedeği) | IDB ham satırı hedefi **köprüyle** kurar | ✔ |
| — kenar | yedek yalnız LOG_YOK'ta (SATIR_YOK/ZAMAN_ESLESME_YOK/CAKISMA/nedissiz → null); {txid} hedefe yedek yok; bozuk girişler; sağlam köprüde davranış DEĞİŞMEZ (tek çağrı); yedek de LOG_YOK'sa 3. çağrı YOK | ✔ |

**Unit:** baseline `1031/1031/0` (değişiklik öncesi ölçüldü) → teslim
**1045/1045/0** (1031 + 14; fail 0; review minör-2 sertleştirmesi dâhil).

## 4. Damga

`20260914-11` → **`20260914-12`** tek değer: index.html (26 script src +
manifest link) + `vaka-toplu-ac.test.js` pin'leri (regex, manifest assert,
eski-damga listesine `-11` eklendi, damga-tarihi yorum satırı).

## 5. Builtin review notu (ZORUNLU)

**Builtin code-reviewer (claude code subagent) — sonuç: APPROVE.** Kapsam:
`degisiklikler.js:459-517` (yeni yardımcı + catch), çözücünün dokunulmadığı
(`git diff js/gecmis.js` boş), RPC sözleşmesi (20260914000004:87-91,157-166 —
'satir'+txidsiz → `ORDER BY id DESC LIMIT 1`, tarih mantığı yok), `rpc()`
hata şekli (`err.data`), yeni test dosyası ve damga pin'leri. Doğrulamalar:
döngü imkânsız (yedek hedef txid'siz → koşul yeniden üretilemez; test
"yedek turu TEK" bunu sabitler), yanlış-tetiklenme yok (kod+neden birebir
eşleşmesi; CAKISMA/SATIR_YOK/ZAMAN_ESLESME_YOK/nedissiz → null testli),
`_dg.bekleyen` bayatlık guard'ıyla atomik değişir ve uygulama adımı
önizlemedeki yedeğin AYNI hedefi kullanır, XSS yok (yardımcı saf; çıktı
mevcut esc/escAttr lavabo akışlarında), kural iki katmanda da korunur.
Kendisi tam suite'i ayrıca koştu: **1044/1044/0** (bu worktree'de bare
`npm run test:unit`'in fast-check yüklemesi NODE_PATH'siz düşer — ortam
notu, diff ile ilgisiz).

Review bulguları ve karşılıkları:
- **Minör-1 (önceden var olan):** catch'teki hata-path DOM yazmaları
  `_dg.bekleyen === h` bayatlık guard'ı taşımıyor (bayat önizlemenin hatası
  yeni akışın gövdesini ezebilir; tek-modal UI'da erişilemez). Bu diff'in
  kusuru değil → **dokunulmadı, takip kalemidir** (raporlama yükümlülüğü).
- **Minör-2 (kendi kodumun sertleştirmesi — UYGULANDI):** alan-seviyesi hedef
  (`{tablo,pk,alan,txid}`) yanlışlıkla 'satir'a inmesin →
  `_dgKopruSatirYedegi`'e `if (hedef.alan) return null;` eklendi + pin testi.
  Suite sonrası: **1045/1045/0**.
- **Minör-3 (test hijyeni notu):** akış testlerinde `esc`/`escAttr` identity
  stub'dır (davranış sabitlenir, escaping sabitlenmez) — bu diff markup
  üretmez; desen başka testlere kopyalanmamalı.

## 6. Sınırlar / lead'e notlar

1. **Canlı probe kısıtı:** DEMO projesine (vtzqjmazsvurxdeondmi) salt-okunur
   erişim kurulamadı — Mgmt token prod projesine yetkisiz ("necessary
   privileges" 403), demo anon key `degisim_onizle`/`degisim_listele`'de 401
   (REVOKE anon), uygulama girişi demo'da `invalid_credentials`. Kök ölçümü
   bu yüzden **statik + seed-SQL kanıtıyla** (yuruyus_kur.sql satır 62-68'in
   ayrı-işlem yapısı + 20260913000001 izleme listesinde islem_log'un yokluğu +
   20260914000003 L4-02a koşulsuz köprü) yapıldı; üçü de yapısal ve
   çelişkisiz. Lead isterse demo'da tek doğrulama SQL'i:
   `SELECT count(*) FROM degisim_log WHERE txid = (SELECT degisim_txid FROM
   islem_log WHERE id='l4y-isl-sonuc');` → beklenen **0** (ve tohumlama
   satırının kendi log adedi ≥ 1).
2. **PW koşumu bu turda YOK** (değişiklik JS+unit dar kapsamı; sahibin kanıt
   kuralındaki ekran-görüntüsü turu R1 akışında "final uca pinli yeniden
   yürüyüş" adımıdır — S1a dahil, lead turunda). Beklenen davranış: S1a
   tohumlama/sonuç kartında önizleme artık satır-yedeğiyle açılır.
3. **Yapısal not (kapsam dışı, raporlanır):** uygulama akışlarında islem_log iş
   değişikliğiyle aynı işlemde yazıldığından boş köprü pratikte yalnız
   SQL-tohumlu/senaryo verisinde oluşur; ama fix bu sınıfa genel (gelecekteki
   ayrı-işlem yazımlarını da kurtarır). Kökün DB-tarafı kalıcı çözümü (ör.
   köprülerin `degisim_log` varlığıyla doğrulanması) ayrı DB işidir — bu
   turda YOK (DB yazma yasağı).
4. Açık kalem 3 (yarım-gece TZ) ve D1/D3/D4 bu teslimin kapsamı dışı.
