⟦ss-sub model=opus effort=high rol=ss-reviewer-kapi iş=Ovsync treni uygulama planını (PLAN.md @3fe0cdd) 6 boyutta plan kapısından geçir⟧
sonuc: TAMAM

```
VERDICT: DÜZELT
OKUDUM: kat1 yok (plan kapısı; brief dosyaları doğrudan) · PLAN.md 615/615 · design.md 194/194 · plan-brief 52 + plan-report 30 · domain-rules §18 455-541 · kanit/fn nokta: _ovsync_baslat_gorev_kur, _acik_disi_gorev_kur, gorev_ertele, seans_tamamla, treatment_day_tamamla, protokol_iptal, start_first_service_protocol, dogum_kaydet · araç 19
ÖLÇTÜM:
- git diff --stat b9542b1 3fe0cdd → 3 dosya, yalnız docs; gitnexus list egesut-erp1 Commit b9542b1 → JS indeksi dal için taze (MEASURED)
- 15 JS çapası sed -n (ui.js 2139/4461/5560/3793/13194/4324/4330/2922, api.js 1391/1237/1131, forms.js 827/882/5336/5696) → hepsi planın dediği çağrı (MEASURED)
- kanit/fn grep çağıranlar: _ovsync_baslat_gorev_kur ← _ilk_tohumlama_rota_kur:11, _acik_disi_gorev_kur:32, protokol_iptal:69; _acik_disi_gorev_kur ← hayvan_ekle:114, ilk_tohumlama_zamanlayici:154, tohumlama_sonuc_bos:16, tohumlama_bos_ve_devam:396, tedavi_sablon_bos_ata_uygula:28 → D3 etki listesi birebir (MEASURED)
- imzalar: start_first_service_protocol(uuid, boolean), _ovsync_baslat_gorev_kur(text,date,text,date), _acik_disi_gorev_kur(text), protokol_iptal(uuid,boolean,text) → plandaki DROP imzalarıyla aynı (MEASURED)
- seans_tamamla.sql:138 LEAST(now(), planlanan) var; treatment_day_tamamla.sql:87 zaten now() → K11 yalnız seans_tamamla değişikliği doğru (MEASURED)
- supabase/tests/ovsync_pg_kabul.sql:8-9,34-41 → tüm testler tek BEGIN…ROLLBACK, test başına geri sarma yok; kb_ok başarıda temp tabloya yazar (MEASURED)
- scripts/{db-validate.sh,db-dry-run.sh,etiket-tazelik.mjs,veri-eslesme-kontrol.py,ground-truth-audit.sh}, .harness/runbooks/db-migration.md, tests/e2e/ovsync-takip.spec.js, tests/unit/domain-rules-karar7.test.js → hepsi var (MEASURED)
İŞARETLİ:
- PLAN.md:339 (+ :98 R7 "1 → N ≤ tolerans kayar") — doğruluk/K5 — KRİTİK — Aşama 1 toleransı çağrı başına (`p_gun ≤ tolerans`) ölçülüyor, birikimli değil: aynı hayvana ertesi gün yine +1 (ya da tek hayvan +1 sonra toptan +1) verilebilir, PG1 sınırsız kayar; spec K5 "PG1 en fazla 1 gün ertelenir" çiğnenir. KANIT: design.md:87 K5 + domain-rules.md:534-535 §18.19 "aşama 1 PG ≤1 gün"; plan kabulü yalnız tek çağrı p_gun=2 (TR-K5-N1, PLAN.md:348) → beklenen birikimli red ≠ planlanan davranış. Düzeltme: tolerans = yeni PG1 tarihi − (GnRH1 gününün planlanan/gerçek tarihi + 7) ≤ tolerans; TR-K5-N2 (ardışık iki +1 → ikincisi OVSYNC_ASAMA1_TOLERANS) ve TR-K7 (tek hayvan +1 sonra toptan +1 → BASTAN) eklensin.
- PLAN.md:94 (R3 "aşama 1 kaydırmada değişmez") + PLAN.md:98 (R7 (iii) `ovsync_tren = X−7`) — doğruluk/K7 — KRİTİK — Üyelik etiketi gerçek iş gününden kopuyor: Review Focus 1 senaryosunda (X treni, 2 hayvan GnRH1 yaptı, toptan +1) yapılmış 2 hayvan KAYAR ile PG1'i X+8'e taşır ama `ovsync_tren` X kalır, diğer 2'si X+1 olur; X+8'deki toptan erteleme (iii) kümesi `ovsync_tren = X+1` olduğu için ilk 2 hayvanı SESSİZCE dışarıda bırakır (K7 "o tarihteki tüm Ovsync işleri" + "kısmi başarı yok" çiğnenir) ve `ovsync_tren_listele` aynı günlerde iş yapan hayvanları ritim dışı X ve X+1 diye iki başlıkta gösterir (K1 ritim çapa+7k). Tek hayvan aşama-1 +1'i de tersine hatayı doğurur: X+7 toptanı, PG1'i artık X+8'de olan hayvanı "o tarihin işi" sayıp yeniden kaydırır. KANIT: design.md:89 K7 + design.md:83 K1; planda bu çok-haftalı yolu ölçen test yok (TR-K7-KISMI yalnız önizleme, PLAN.md:376). Düzeltme: küme gerçek iş tarihinden türetilsin (X'te açık OVSYNC_BASLAT ∪ X'te tamamlanmamış Ovsync günü olan, `ovsync_tren IS NOT NULL` vaka) ya da her kaymada `ovsync_tren` += N (tren = ritim sınıfı etiketi); TR-K7-HAFTA2 testi (toptan +1 sonra ertesi hafta toptan → 4 hayvanın hepsi kümede).
- PLAN.md:173 + :247 (TR-K10-GUC) + :184 — test/kabul — ÖNEMLİ — Kabul betiği tek transaction'da koşuyor; `_ovsync_ic_ac()` (`set_config(...,true)`) D2'de bir kez çağrılınca `app.ovsync_tren_ic='1'` transaction sonuna kadar kalır → D5 TR-K10-1..4 kilidi göremez (yanlış FAIL); ayrıca birikmiş fixture'lar toplam assert'lerini (TR-ONIZLE-1 `uye_sayisi`, TR-K3-1, TR-LISTE-2 `ileri_sayisi 1`, TR-K7-1 X'in tüm üyeleri — önceki testlerin aşama 2 vakası SECIM_EKSIK doğurur) kirletir. KANIT: ovsync_pg_kabul.sql:8-9 (tek BEGIN…ROLLBACK), :34-41 (kb_ok geri sarmasız); mevcut sıfırlama kalıbı ovsync_pg_kabul.sql:220-222 (`egesut.katalog_bakim` off). Düzeltme: sözleşmeye "iç bayrağı kullanan her test sonunda `set_config('app.ovsync_tren_ic','',true)`" + "toplam assert'li her test kendine özgü çapa/X (kb_bugun()+7k ofseti) ya da sorguyu fixture hayvan kümesine süz" kuralı.
- PLAN.md:96 (R5) + :238 (`_ovsync_kilit_gorev` "R5 koşulunda") — domain/K10 kapsamı — ÖNEMLİ — `gorev_ertele` kilidinin görev-tipi koşulu tanımsız; R5'teki parantez ("hayvanın aktif OVSYNC vakası varsa") yalnız hayvana bakıyor → Ovsync'teki hayvanın aşı/mastit ILAC/GEBELIK dışı görevleri de kilitlenebilir. Spec K10 yalnız OVSYNC_BASLAT, Ovsync vakasının TEDAVI_GUN/SEANS'ı ve TAI'sini sayar; JS tarafı (PLAN.md:438 `ovsyncTrenGorevMu`) tipe göre daraltıyor → SQL/JS ayrışması. KANIT: design.md:92 K10; negatif test yok (TR-K10-6 Ovsync OLMAYAN hayvan, PLAN.md:323). Düzeltme: koşulu tip listesiyle yaz (`OVSYNC_BASLAT` ∪ Ovsync hayvanının `TOHUMLAMA_PLANLI`), TR-K10-7 "Ovsync hayvanının ILAC görevi gorev_ertele ile ertelenir".
- PLAN.md:92 (R1) — doğruluk — KÜÇÜK — `to_date('20261131','YYYYMMDD')` PG ≥10'da 22008 hatası atar, eşitlik karşılaştırmasına ulaşmaz → ham hata, `OVSYNC_TREN_AYAR` değil; ondalıklı numeric (20261112.5) da aynı. TR-AYAR-N2 (PLAN.md:245) kırmızıda yakalar; R1'e "EXCEPTION WHEN others → OVSYNC_TREN_AYAR" yazılsın. (INFERRED — PG davranışı, bu oturumda koşulmadı)
- PLAN.md:604 (P11 hızlı geri) — risk — KÜÇÜK — Hızlı geri yalnız iki bayrağı çevirir; bayraktan bağımsız giren R10 anahtar biçimi (PLAN.md:101) ve `_vaka_ac_tek` TR düzeltmesi (PLAN.md:291) hızlı geride kalır, P11'de "bayrakla geri dönmeyen değişiklikler" satırı yok. (ÖNERİ)
- PLAN.md:555-558, :567-580 — test/kabul — KÜÇÜK — K8'in 7 yolundan gerçek demo e2e'de ve UI kapısında yalnız V2 (▶ Başlat) yürünüyor; §18.15'i değiştiren G7 (Boş sonrası "Ovsync uygula") ve V3 (Vaka Aç + Ovsync) yalnız sahte-rpc birim testinde. UI kapısına G7 ve V3 maddesi eklensin. (ÖNERİ)
- PLAN.md:551-553 — test/kabul — KÜÇÜK — Demo'da bayrak açılmadan önce mevcut `tests/e2e/ovsync-takip.spec.js` (bayrak kapalı regresyon, ui.js renderOvsyncSayfa/_erteleBtnHtml değişti) koşumu yok. (ÖNERİ)
- PLAN.md:95 (R4) — spec izlenebilirliği — KÜÇÜK — "tren = bugün → modal yok, tek seçenek" spec §6'daki "iki düğme" ekranından sapma; mockup 1'in tren=bugün varyantı (PLAN.md:412) sahibe G-MOCK'ta görünür olduğu için bloklamaz, mockup README'de açıkça "R4 sapması" diye etiketlensin. (ÖNERİ)
BLOKLAYAN: 4 · ERTELENEBİLİR: 5
NOKTA NOTU: Kapı plan metni + seçili prod gövdeleri üzerinden verildi; D3/D5'in 487-600 satırlık gövde kopyalarındaki iç çağrı zincirleri (ör. vaka_kalan_gunleri_kaydir_coklu iç yapısı, _tohumlama_pencere'nin OVSYNC_BASLAT saatine etkisi) tek tek açılmadı.
```

## Skorlar (6 boyut × 1-5)

| # | Boyut | Puan | Gerekçe (kısa) |
|---|---|---|---|
| 1 | Spec izlenebilirliği | 4 | K1–K11, Faz 0, §5–§9 hepsi göreve bağlı (öz denetim tablosu PLAN.md:612-613 doğrulandı); küçük taşmalar: `_vaka_ac_tek` TR düzeltmesi, R4 sapması, yeni `ovsync_hayvan_ertele` (K4/K5 için gerekli). |
| 2 | Domain-rules uyumu | 3 | §18.4/18.5/18.6/18.10 çevrimdışı korunuyor; ama aşama 1 toleransı birikimli değil (§18.19 "PG ≤1 gün" çiğnenir) ve K10 kilit kapsamı spec'ten geniş olabilir. |
| 3 | Test/kabul gücü | 3 | Kırmızı→yeşil, K başına pozitif+negatif, bayrak kapalı regresyon tabanı (D0/D8), gerçek demo e2e, sahip-sorusu ölçütlü UI kapısı güçlü; fakat test izolasyonu tanımsız (GUC + fixture birikimi) ve iki KRİTİK tasarım hatasını yakalayacak çok-adımlı test yok. |
| 4 | Görev bölünmesi | 5 | Net DAG, tek yazıcı tablosu, sıralı DB/UI düğümleri, boyut/model/review kademesi brief'e uygun (DB/UI opus, mekanik sonnet, D başına T2). |
| 5 | Risk ve geri dönüş | 4 | md5 gövde koruması, tek-transaction apply, rollback provası (D8), göç kuru→onay→uygula, REVOKE PUBLIC/anon/authenticated, TR tarih grep kapısı, P1(c) sahibe; hızlı geride bayraksız değişiklikler eksik. |
| 6 | Uygulanabilirlik/doğruluk | 3 | Andığı imza/çağıran/satır çapalarının hepsi ölçümle doğru; T1 (LEAST) ve T4 (cron/iptal hedefi) kapatılmış; ama tren üyelik modeli (R3+R7) ve tolerans hesabı (R7/ovsync_hayvan_ertele) çekirdek doğrulukta kırık; R1 to_date. |

**Ortalama: 22/6 = 3.67** → KABUL eşiği (≥4.0) altında, hiçbir boyut <3 değil → **DÜZELT** (RED değil).

Tur 2 için asgari: R3/R7 üyelik modeli düzeltmesi + birikimli tolerans + iki yeni çok-adımlı test; kabul betiği izolasyon kuralı; `_ovsync_kilit_gorev` tip koşulu + negatif test. KÜÇÜK'ler isteğe bağlı.

## Kırıntılar
- gate (unmeasured-claim): R3+R7 tren üyeliği etiketi aşama-1 kaymasında güncellenmiyor → ikinci hafta toptan erteleme hayvan kaçırır (PLAN.md:94,98).
- gate (unmeasured-claim): K5 toleransı çağrı başına, birikimli değil (PLAN.md:339).
- decision: KALİTE/kapı verdict DÜZELT, ort 3.67 (4/3/3/5/4/3).
