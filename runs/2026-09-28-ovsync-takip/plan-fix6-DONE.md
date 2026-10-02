# DONE — Plan düzeltmesi 6: MK9 kapsam daraltması (plan v6 → v7)

SONUÇ: **TAMAM**
Checkout: ovsync-takip @ 40feed3 (yalnız plan.md + bu DONE + kırıntı yazıldı; kod, migration, `.ss/`, DB, commit DOKUNULMADI; ultracode KOŞULMADI; salt-okuma alt-ajan 0/3).

## Kalemler (1–9)

1. **H1 — TAMAM.** DEGISMEZ 13 §10h H1 ile daraltıldı (yalnız (a) yeni nesneler + (b) değişen RPC'lerin yeni kısmı; eski yollara kilit eklenmez; B9 yönlendirmesi). v6'nın eski-yol kilit maddeleri GERİ ALINDI: `tohumlama_sonuc_bos` giriş NKU (P2b Boş yolu maddesi yeniden yazıldı — çekirdek DAVRANIŞI sarmalın kendi gövdesinde YENİ kod olarak uygulanır, mevcut RPC gövdesi+imzası değişmez), `gorev_tamamla` görev→hayvan sıra düzeltmesi (guard maddesi + grafik hükmü), `create_case` genel giriş NKU (MK9-G (a) maddesi + grafik hükmü). `start_first_service_protocol` düzeltmesi KALDI (H1 istisnası, H4 örneği olarak işaretlendi).
2. **H2 — TAMAM.** MK9-G grafik başlığına "BİLGİ AMAÇLIDIR — KABUL ÖLÇÜTÜ DEĞİLDİR (§10h H2)" notu; "Açık kalemler / riskler" bölümüne **B9 "MK9 eski yol kilit denetimi"** maddesi eklendi (5 girdi: SUTTEN_KESME kolu, `hizli_uygulama_geri_al` çok-satır, ham REST yazıcıları, `tohumlama_sonuc_bos`, `gorev_tamamla` sırası — dosya:satır referanslı).
3. **H3 — TAMAM.** P3a'daki MK9-T maddesi GERİ ALINDI, yerine yazıldı: tetikleyiciler hayvan kilidi ALMAZ; yalnız o hayvanın açık TAKIP_MUAYENE `gorev_log` satır(lar)ını günceller (`_takip_kapat` — tek satır tipi, idempotent, bayraktan bağımsız); BEFORE INSERT ret tetikleyicileri (pg_application_event, cases) yalnız okur + RAISE. Yön kuralı P2b sarmal kilit sözleşmesine KURAL olarak işlendi: tohumlama satırı takip `gorev_log` satırından ÖNCE kilitlenir (DEGISMEZ 13 istisna + P2a/P2b maddeleri + grafik tetikleyici satırı güncellendi).
4. **H4 — TAMAM.** P3b'ye "H4 — yeni/değişen giriş noktalarında standart desen" maddesi eklendi: kilitsiz keşif → hayvan `FOR NO KEY UPDATE` → alt satır `FOR UPDATE` + yeniden doğrulama; üç yüzey (sarmal muayene/takip modları, `kizginlik_vaka_ac` kapısı, start düzeltmesi) her biri için tek cümle mevcut dönüş/hata sözleşmesiyle. C4 maddesinin (0) adımı bu standarda çevrildi.
5. **H5 — TAMAM.** `vaka_toplu_ac` + `bulk_ilac` için v6'nın `ORDER BY id` retry kilit maddeleri GERİ ALINDI (MK9-G (b) maddesi, D4 bulk yolu, C2 retry sözleşmesi, grafik `bulk_ilac` hükmü, P3b kabul C2 cümlesi). Yerine: mevcut döngü/kilit DEĞİŞMEZ; fonksiyon başında açık-takipli hayvanlar okunur; `p_takip_onaylar` dışındaki açık-takipli satır işlenmez, satır sonucu `TAKIP_ACIK` (kaynak desen referansı: PG bulk `p_pg_onaylar` satır-karar deseni [20260923000004:457-494]); içindekiler için `_takip_kapat` satır işlenmeden hemen önce; retry = onaylı alt kümeyle YENİ çağrı (`p_animal_ids` = onaylananlar); yeni boyut sınırı YOK. P3b imza tablosu değişmedi (imzalar aynı); P10 retry maddesi + katalog 17(c) + matris H5 satırı buna göre.
6. **H6 — TAMAM.** `gorev_tamamla` guard'ı daraltıldı: yalnız tamamlama dalı (`p_iptal` false/NULL) + yalnız GEBELIK_KONTROL/TAKIP_MUAYENE; `p_iptal=true` (T5, js/ui.js:1841-1844) ve SUTTEN_KESME/padok dalları AYNEN; guard yalnız görev tipini okur, kilit sırasını DEĞİŞTİRMEZ. Üç-dal davranış testi maddede + matris + katalog 17(b).
7. **H7 — TAMAM.** T-72b sonuç oracle'ına çevrildi: sabit 5 çift (sarmal × tohumlama_kaydet / × start / × seans_tamamla / × vaka_toplu_ac; kapanış tetikleyicisi × sarmal), iki bağlantılı betik, N=30 eşzamanlı tur, `lock_timeout='5s'`, demo DB; PASS = hiç `40P01`/`55P03` + her sonuç izinli kümede; "önce kırmızı" şartı KALDIRILDI. v6'nın "5+4 çift" listesi (grafik riskli çiftleri + bulk×bulk) P2b/P3b kabul + grafik çiftler paragrafı + matris + katalog 16(a)/17(a) üzerinden değiştirildi; MK9-G/T ayrı prova satırı matristen kaldırıldı.
8. **H8 — TAMAM.** Eşleme noktası kaynaktan bulundu [CONFIRMED js/api.js:44-93]: `_trErr`/`_ERR_MAP` [js/api.js:44-62] yalnız hata MESAJ METNİNİ eşler (`includes`), SQLSTATE kodunu eşlemez; PostgREST deadlock yanıtında `error.code='40P01'`/'55P03' taşır → kod dalı `rpc()`'nin hata satırına [js/api.js:93 `if (error) throw new Error(_trErr(error.message))`] eklenir: `İşlem başka bir kayıtla çakıştı, tekrar deneyin`, otomatik retry YOK. **Zarf P9/P10 tahmin etti; kaynak noktayı api.js P4'te gösterdi** — madde P4'e yazıldı (tek nokta tüm P9/P10 catch'lerini kapsar), birim testi P11'e. DONE sapması bilinçli.
9. **TAMAM.** Review kapanış tablosuna "v7 kapanış" sütunu (18 satır + **r4-1..r4-7 satırları** — sayım: 6 H-kararıyla KAPANDI / 1 B9'a devredildi); izlenebilirliğe §10h satırı; başlık v7 + sürüm notu; SPEC ÇELİŞKİLERİ'ne v7 turu satırı; P13 ground-truth listesinden `tohumlama_sonuc_bos` çıkarıldı.

## Geri alınan maddelerin listesi (v6 → v7)

1. `tohumlama_sonuc_bos` gövde girişi bayraktan-bağımsız hayvan NKU (P2b Boş yolu) — çekirdek sarmal gövdesine taşındı, mevcut RPC dokunulmaz.
2. `gorev_tamamla` padok-hedef dalı NKU + görev-önce-sıra düzeltmesi (P3b guard maddesi + grafik hükmü).
3. `create_case` gövde girişi genel hayvan NKU (MK9-G (a) + grafik hükmü).
4. `bulk_ilac` retry `p_takip_onaylar` dizisini `ORDER BY id` ile kilitleme maddesi (D4/C2 + grafik + kabul).
5. `vaka_toplu_ac` onaylı retry `ORDER BY id` kilitleme maddesi (MK9-G (b) + grafik).
6. MK9-T: tetikleyicilerin hayvan muteksi alması (P3a madde + P2a referansı + P2b MK9-K netliği + grafik tetikleyici satırı + katalog 16(d)).
7. T-72b "önce kırmızı" şartı + grafik riskli çiftleri eki (5+4 liste → sabit 5 çift oracle).

## §10h çelişki grep'i (çıktı özeti)

- `MK9-T`: 10 eşleşme — 8'i v7 geri-alım/bilgi metinleri veya v6/v5 sürüm notları (tarihsel); 1 aktif çelişki bulundu (P2b MK9-K netliği, satır 332) → DÜZELTİLDİ; 1'i MK9-T prova katalog maddesi (16(d)) → KALDIRILDI olarak işaretlendi.
- `tohumlama_sonuc_bos`+NKU: yalnız v7 notu + v6 notu (tarihsel) — aktif kilit maddesi YOK.
- `gorev_tamamla` sıra/NKU: aktif kilit-düzeltme maddesi YOK; kalan eşleşmeler v7 metinleri + grafik ölçüm satırı (bilgi amaçlı, B9 işaretli).
- `ORDER BY id`: aktif hüküm YOK — kalan eşleşmeler v5/v6 sürüm notları (tarihsel) + v7 geri-alım metinleri + izlenebilirlik v6 satırı (tarihsel).
- `kırmızı`: TDD kırmızı-iskelet maddeleri (kapsam dışı — #17 kuralı değişmez); T-72b önkırmızı v7 metinlerinde yalnız "şartı YOK" biçiminde.

**Sonuç: kalan eşleşmeler yalnız tarihsel bağlamda (sürüm notları) ya da v7'nin kendi geri-alım/bilgi metinleri — aktif çelişki 0.**

## Yeni SPEC SORULARI

YOK — §10h teknik yöndür (design.md §10h), domain kuralına (§14/§18) dokunmaz; DEGISMEZ 11, H6 daraltmasıyla korunur (guard tamamlama dalında; iptal dalı DEGISMEZ 11 kapsamı dışında zaten). SPEC ÇELİŞKİLERİ bölümüne v7 turu satırı eklendi.

## Yazılan dosyalar

- `docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md` (v7 — 30+ hedefli düzenleme)
- `runs/2026-09-28-ovsync-takip/plan-fix6-DONE.md` (bu dosya)
- `.crumbs/ovsync-takip.jsonl` (kırıntı satırları, role lead)
