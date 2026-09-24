# ovsync-pg Full-Scope İnceleme Raporu — 2026-09-25

- **Repo / commit:** egesut-erp1 @ eae5765
- **İnceleme konusu:** ovsync-pg teslimi (R3.1/R3.2 açık-dişi + PG uygulama kapısı + SK10 geçişi + yayın seti) — reports/2026-09-24-ovsync-pg-tamamlandi.md'deki teslim iddialarının tam kapsamlı doğrulaması
- **Tüm kanıt etiketleri** `egesut-erp1@eae5765:<dosya>:<satır>` biçimindedir ve şüphecilik doğrulama turunda kodla satır düzeyinde çaprazlanmıştır.

---

## 1. Yöntem özeti

İnceleme 10 paralel lens ile koşuldu, her lensin taze bulguları bağımsız bir şüphecilik (doğrulama) turundan tek geçti (tek tur; ikinci tur gerekmedi — tüm bulgular ilk turda ya doğrulandı ya da önem düzeyi düzeltildi):

| # | Lens | Kapsam (özet) |
|---|------|----------------|
| 1 | db-migrations | 8 migration (20260923000001–06, 20260924000001–02) satır satır; SPEC S-1..S-10 + R3.1 (MK7–MK10) + R3.2/SK6–SK10 maddelerinin koda yansıması; trigger/idempotency/ACL doğrulaması + canlı pg_proc/protokol_ayar/islem_log ölçümleri |
| 2 | kabul-betigi | supabase/tests/ovsync_pg_kabul.sql (1762 satır) tamamı + README koşum sözleşmesi + PASS sayacı statik yeniden ölçümü; 19 EXCEPTION WHEN OTHERS bloğu denetimi |
| 3 | ui-plan | js/ui.js (P3–P10), js/forms.js, js/api.js, js/config.js, errorHandler, index.html ?v= damgası; unit test koşumu (1086 pass / 3 fail) |
| 4 | yayin-pages | pages.yml whitelist vs index.html referansları birebir çapraz; vendor fix + ?v= damga kökeni (git log -S) |
| 5 | operasyonel-iddialar | tamamlandi.md operasyonel ölçüm bloğu: canlı prod salt-okunur SELECT'ler, migration sabitleri, kabul betiğinin ROLLBACK'li gerçek koşumu (456 PASS + FAIL reprodüksiyonu), veri-eslesme ozet.json, commit izi |
| 6 | acik-dryrun | 20260924000002 dry-run migration'ı tam okuma + önceki versiyon/fix diff'i + tüm çağıran kod yolları + gerçek-yazım zinciri karşılaştırması |
| 7 | acik-p5-yaris | P5 "Boş ata ve uygula" zinciri uçtan uca (ui.js/api.js/forms.js) + tohumlama_sonuc_bos / seans_tamamla migration gövdeleri |
| 8 | acik-offline-kuyruk | js/api.js tam metin (747 satır): IndexedDB kuyruk, RPC_TABLES, syncNow replay; write() çağıranlarının tamamı |
| 9 | acik-sk10-stok | vaka kapanış migration'ı, stok ledger formülü, seans iptal iade yolları, kabul betiği SK10 bloğu |
| 10 | acik-demo-prod | demo↔prod davranış farkları: demo/ SQL'leri, IS_DEMO yüzeyi, ACL/cron koşullu blokları; kabul betiği iki kez ROLLBACK'li koşuldu (456 lokal / 448 demo-simülasyon) |

**Bulucu/verdict sayısı:** 10 lensin ürettiği bulgu adaylarının tamamı şüphecilik turuna girdi; **66 bulgu ayakta kaldı** (hiçbiri çürütülmedi; birkaçında önem düzeyi aşağı/yukarı düzeltildi). Önem dağılımı: **2 yüksek, 21 orta, 41 düşük, 2 belirsiz/doğrulama kaydı.**

---

## 2. Bulgular (kritiklik sıralı)

### YÜKSEK

**Y1. Manuel replay (dataTrafficTekGonder) iptal-PATCH'i gorev_tamamla RPC'sine çevirir — iptal işareti düşer, görev "tamamlandı" olur**
- Önem: **yüksek** | Kanıt: `egesut-erp1@eae5765:js/ui.js:L9245` (RPC_MAP `gorev_log: { PATCH: 'gorev_tamamla' }`), `js/ui.js:L9426-9428` (param builder yalnız `p_gorev_id`+`p_padok_hedef`; `p_iptal` yok), `js/ui.js:L1193` (ovsyncIptal kuyruğa `{tamamlandi:true, iptal:true}` tam satır PATCH'i yazar; ayrıca L1195, L2407, L6751, L8177), `js/api.js:L548-550` (otomatik syncNow aynı op'u REST dbUpdate ile sadık replay eder)
- Gerekçe: Kullanıcı Veri Trafik panelinden ↑ düğmesine basarsa iptal edilen görev sunucuda tamamlanmış işaretlenir (RPC gövdesi koşulsuz `tamamlandi=true` set eder, stok düşümü de tetikleyebilir); otomatik sync'te ise doğru şekilde iptal edilirdi. İki replay yolu aynı kayıt için farklı semantik üretir. Uygunsuz durum, RPC sonrası pull setiyle UI'a da düşer.

**Y2. TOHUMLAMA_SONUC_BOS sonuç-değer tutarsızlığı migration'lar arası: "Boş" vs "Bos" vs tohumlama_durumu üç farklı değer**
- Önem: **yüksek** (doğrulama turunda yükseltildi) | Kanıt: `egesut-erp1@eae5765:supabase/migrations/20260502000001_tohumlama_sonuc_bos_formal.sql:L40-45` (`sonuc='Boş'` + `tohumlama_durumu='Boş'`) vs `supabase/migrations/20260512000006_tohumlama_sonuc_bos.sql:L35-44` (`sonuc='Bos'` + `tohumlama_durumu='tohumlanabilir'`); 20260512000006 farklı imzalı (text) overload'u CREATE OR REPLACE ederek 20260403000001'in DROP'ini geri alır; `js/forms.js:3441` tek argümanla çağırır → (text) overload'u canlı çağrılabilir
- Gerekçe: Değer kümesi akışa bağlı iş mantığıdır (OVSYNC muafiyetleri "Bekliyor/Gebe" bakar). Hangi gövdenin canlı olduğu repodan kesin çözülemez; canlı DB doğrulaması gerekir: `SELECT pg_get_functiondef('public.tohumlama_sonuc_bos(text,text)'::regprocedure);` ve `SELECT proname, pronargs FROM pg_proc WHERE proname='tohumlama_sonuc_bos';`

### ORTA

**O1. Seans tamamla: PG kapısı devreye girince "✓ Seans tamamlandı" SAHTE başarı toast'u basılıyor (silent-success)**
- Önem: orta (yüksekten düzeltildi) | Kanıt: `egesut-erp1@eae5765:js/forms.js:L4013-4014` (koşulsuz başarı toast'u), `js/api.js:L695` (PG_KAPI yakalanınca throw etmez, `{ok:false,_pgKapi:true}` döner)
- Gerekçe: PLAN P5 kabulü "onaysız ağ çağrısı yapılmaz; modal karar bekler" der; gerçek akışta kullanıcıya işlem tamamlanmış deniyor. İkinci kol: `js/ui.js:L587-592` flushPendingDone pending'i döngüden ÖNCE clear eder → vazgeç seçilirse görev hiç uygulanmamışken pending kaydı yok olmuş olur.

**O2. P5 zinciri iki ayrı RPC, sıfır atomiklik/idempotency anahtarı: ilk adım commit olup ikincisi ağ hatası alırsa yarım-uygulanmış durum kalır, modal-içi retry kilitlenir**
- Önem: orta (yüksekten düzeltildi) | Kanıt: `egesut-erp1@eae5765:js/ui.js:L988-1004` (iki bağımsız RPC: `tohumlama_sonuc_bos` L996 + `__pgKapiTekrar` L999; L989 yorumu "idempotency sunucuda"), `supabase/migrations/20260502000001_tohumlama_sonuc_bos_formal.sql:L25-27` (durum-guard'ı yarım-zincir retry'ı reddedip akışı L997'de sonlandırır), `grep requestId|idempot` tüm migration'larda boş
- Gerekçe: "Zincir" yalnız client-side sıralamadır, sunucu transaction'ı değildir. Düzeltme notu: kalıcı kilit değil — kullanıcı modalı kapatıp normal yoldan PG uygulayabilir; kusur modal-içi retry körlüğü + yanıltıcı "PG uygulanıyor…" toast'ı.

**O3. flushPendingDone PG_KAPI öğesini sessizce düşürür: pending listesi modal açılmadan ÖNCE temizlenir, Vazgeç seçilirse görev kaybolur**
- Önem: orta | Kanıt: `egesut-erp1@eae5765:js/ui.js:L586-591` (L587 `_pendingDone.clear(); _savePending();` sonra L590 `rpcSeansTamamla`), `js/api.js:L696-698` (PG_KAPI throw etmez → catch tetiklenmez), `js/ui.js:L963,968-971` (Vazgeç yalnız kutuyu kaldırır, niyet hiçbir kuyruğa geri yazılmaz)
- Gerekçe: "Çevrimiçi olunca uygulanacak" vaadi (ui.js:L585) ile modal-red sonrası sessiz veri kaybı çelişiyor. loadTasks/recoverPendingDone önünde çağrıldığından kayıp otomatik-recover yollarında da oluşabilir.

**O4. SK10 "gecis" denetim izi sessizce düşüyor — _vaka_kapat payload'ı p_ref->>'gecis' alanını yazmıyor**
- Önem: orta (düşükten düzeltildi) | Kanıt: `egesut-erp1@eae5765:supabase/migrations/20260924000001_ovsync_pg_r32_acik_disi.sql:L1167-1168` ('gecis','SK10-2026-09-24' verilir) vs `supabase/migrations/20260923000005_ovsync_vaka_kapanis.sql:L222-236` (CASE_CLOSED_BY_TOHUMLAMA payload'ında gecis yok). Canlı: `islem_log` tip='CASE_CLOSED_BY_TOHUMLAMA' 10 satır, payload->>'gecis' hepsi null
- Gerekçe: SK10 kaynaklı kapanışlar audit'te normal TOHUMLAMA kapanışından ayırt edilemez; 'gecis' değeri üretiliyor ama tüketen/yazan hiçbir yol yok — sessiz-yutulan veri.

**O5. Kapı-5 fix'i eksik kalan kör nokta: dry-run "baslatilacaklar" bayrak kapalıyken başlatılmayacak görevleri vaat ediyor**
- Önem: orta | Kanıt: `egesut-erp1@eae5765:supabase/migrations/20260924000002_dryrun_bayrak_bagimsiz.sql:L165-176` (baslatilacaklar bayraksız doldurulur), L179-185 (dönüşte bayrak durumu alanı yok), L187-188 (gerçek dal kapalıysa `{ok:true, atlandi:'KAPALI'}`)
- Gerekçe: Bayrak KAPALIYKEN dry-run `baslatilacak_sayisi>0` gösterir ama gerçek koşum hiçbirini başlatmayacağını söylemez — kapı-5'te düzeltilen aynı yanıltma sınıfı başka kolonda kalıyor.

**O6. Gerçek tarama dalı LIMIT 1000 ile sessiz kesiliyor; "kesildi" raporu yalnız dry-run'da var**
- Önem: orta | Kanıt: `egesut-erp1@eae5765:supabase/migrations/20260924000001_ovsync_pg_r32_acik_disi.sql:L1000-1008` (LIMIT 1000 + `EXIT WHEN v_acilan >= c_tarama_ust`, cap 200 L870) vs L919-944 ('acilacak_listesi_kesildi' yalnız dry-run dönüşünde L944; gerçek v_ozet L1042-1049'da alan yok)
- Gerekçe: Dişi sayısı sınırı aşarsa gerçek tarama kalanları sessizce atlar; SPEC SK8 "görevi eksik her uygun hayvana görev açar" der — üst sınır var, kesildi sinyali yok (silent truncation).

**O7. Eligibility koşulları üç yerde kopyalandı — drift riski**
- Önem: orta | Kanıt: `egesut-erp1@eae5765:supabase/migrations/20260924000002_dryrun_bayrak_bagimsiz.sql:L38-59` (_acik_disi_hedef_ic), L140-151 (dry-run satır-içi tekrar; üstelik L140'ta fonksiyon zaten çağrıldığı için tekrar fazlalık), L262-277 (gerçek koşum sayım sorgusu)
- Gerekçe: Muafiyet seti değişirse üç noktanın senkron düzenlenmesi gerekir; tekining kaçırılması dry-run ile gerçek koşumun farklı hayvanlar raporlamasına yol açar (tam kapı-5 hata sınıfı). Şu an üç kopya tutarlı ve etki rapor/sayım tarafında.

**O8. Sistem satır koruması SPEC'ten geniş uygulanmış: TÜM drug_classes satırlarında sinif_kodu/sistem UPDATE yasağı (belge-drift)**
- Önem: orta (düşükten düzeltildi) | Kanıt: `egesut-erp1@eae5765:supabase/migrations/20260923000002_ovsync_pg_sema.sql:L196-204` (KATALOG_SINIF_KODU_KILITLI, yorum L176-178 "SPEC S-2 + mimar R3 eki") vs SPEC `docs/plans/2026-09-23-ovsync-pg-tohumlama-SPEC.md:L52` (yalnız sistem satırları)
- Gerekçe: Sıradan katalog satırında sınıf kodu UPDATE ile düzeltilemez. Kaçış yolu tam migration değil: hafif `SET LOCAL egesut.katalog_bakim='on'` oturum bayrağı (dosya içi HINT'te mevcut) — kasıtlı sertleştirme ama SPEC güncellenmemiş.

**O9. Ortam-bağımlı assertler: islem_log tablo-geneli sayım ve canlı stok kataloğuna bağlı BELIRSIZ-0 kontrolleri koşumlar arası kırılgan**
- Önem: orta (düşükten düzeltildi) | Kanıt: `egesut-erp1@eae5765:supabase/tests/ovsync_pg_kabul.sql:L1117/L1119` (paylaşılan DB'de eşzamanlı yazmada flaky; betik L1384-1385'te aynı riski FIRST_SERVICE_CRON için kendisi kabul edip farklı desene geçmiş), L128-130 (canlı stok setine bağlı BELIRSIZ-0)
- Gerekçe: "Her test kendi fixture'ını kurar" sözü (L12-13) bu iki assert için tam geçerli değil.

**O10. P7 DRIFT: toplu gönderim ÖNCESİ pg_uyari_kontrol önizlemesi ve "N engellenecek, M onay ister" ön bilgi tamamen yok**
- Önem: orta | Kanıt: `egesut-erp1@eae5765:js/forms.js:L3831-3848` (submitBulkIlac doğrudan `rpc('bulk_ilac')`), grep: pg_uyari_kontrol çağrısı yalnız api.js:322 yorumunda
- Gerekçe: PLAN DRIFT KAPISI ihlali — P7'nin önizleme yarısı implemente edilmedi; kullanıcı engellenecek/onay gerekecek sayıyı gönderim SONRASI öğreniyor. (Sonuç modalı, applied-yeniden-gönderilmeme ve gerekçe zorunluluğu doğru kurgulanmış.)

**O11. P8 TZ drift: p_occurred_at browser-yerel saat dilimiyle çevriliyor, PLAN "İstanbul saat dilimiyle" diyor**
- Önem: orta | Kanıt: `egesut-erp1@eae5765:js/ui.js:L2340` (`new Date(olcGun+'T'+(olcSaat||'12:00')+':00').toISOString()` — ofsetsiz ISO, ES spec gereği cihaz TZ'si), PLAN `docs/plans/2026-09-24-ovsync-pg-PLAN.md:L95`; sunucu penceresi Europe/Istanbul bazlı (`20260923000003:L34`, `20260923000004:L128`)
- Gerekçe: Yurt-dışı TZ'de çalışan tablette "dün 19:30" ±saatler kayar; 5dk-ileri/7gün-geri penceresi çarpık değerlendirilebilir. Günlük etki, hedef kitle ağırlıkla +03 olduğundan sınırlı.

**O12. P3/P10 DRIFT: OVSYNC_BASLAT kartında düve/inek doz etiketi ve beklenen TAI yok; B1 bildiriminde küpe/düve/seans sayısı ve dokunuş→hayvan kartı yok**
- Önem: orta (düşükten düzeltildi) | Kanıt: `egesut-erp1@eae5765:js/ui.js:L1161-1165, L1240-1256, L1181-1184` (bildirimde onclick yok, küpe/seans sayısı yok); plan karşılaştırması PLAN P3/P10
- Gerekçe: P3 ve P10/B1 kabul ölçütleri kısmen karşılanıyor; "bildirim dokunuşu → hayvan kartı" hiç yok.

**O13. modal-router test kapsamı: pg_kapi / ertele / toplu_sonuc pushState sheet'leri geri-tuşu invariant testine alınmamış**
- Önem: orta | Kanıt: `egesut-erp1@eae5765:js/ui.js:L971/L1033/L1098` (üç yeni pushState) — `tests/modal-router.spec.js`'de grep 0 sonuç; dosya son kez fe5f91d'den 469 commit önce değişti; PLAN `2026-09-24-ovsync-pg-PLAN.md:L77-78` açıkça "modal-router testi" der
- Gerekçe: Kod tarafı desen (history.state + _modalBackGuard) doğru ama sözleşme testle kilitlenmemiş; yeni sheet'ler mevcut testlerle dolaylı bile örtülmüyor — regresyon koruması yok.

**O14. Bulk ilaç başarı yolu pullTables'a gorev_log eklemiyor — S-4'te açılan +48s görevleri listede geç görünür**
- Önem: orta | Kanıt: `egesut-erp1@eae5765:js/forms.js:L3875` (liste: stok, stok_hareket, islem_log), bulk_ilac RPC_TABLES gorev_log içeriyor (`api.js:L335`) ama submitBulkIlac rpcOptimistic değil rpc() kullandığından harita-tabanlı pull tetiklenmez
- Gerekçe: Geçici UI bayatlığı — sonraki sync'te düzelir; plan-kabul ölçütü açısından tazelik kusuru.

**O15. Birim test süitesi 3 kırmızı (2 UI regresyon + 1 canlı DEMO şema testi)**
- Önem: orta | Kanıt: `npm run test:unit` @ eae5765: 1089 test / 1086 pass / 3 fail — `tests/unit/degisiklikler-etiketler.test.js:88` (LUNA-3 canlı DEMO), `tests/unit/vaka-toplu-ac.test.js:2574 ve 2594` (tarih-seçici)
- Gerekçe: Ovsync-PG testleri yeşil ve boş assertion'sız; ama teslim kapısı "test suite green" ise ihlal. Kırıklar bu PLAN'ın değil komşu alanın.

**O16. Kuyruk kayıtlarında şema-versiyonu/ts yok — sunucu şeması değişince op 5 kez sessizce hatalı denenip dead-letter'a düşer, otomatik sync kalıcı olarak atlar**
- Önem: orta | Kanıt: `egesut-erp1@eae5765:js/api.js:L251/255/274/278` (queueOp ts/versiyon yazmıyor), L546 (`>=5 continue`), L223 (dbInsert tüm alanları gönderir → PGRST204 riski), `js/ui.js:L9212` (ts hep '?')
- Gerekçe: Kırılma büyük ölçüde sessizdir (console.warn + dolu sync bar); manuel Gönder kurtarma yolu dur ama RPC_MAP karşılığı olmayan tablolar dead-letter'da kalır.

**O17. Yeni Ovsync RPC'leri offline kuyrukla hiç etkileşmiyor — offline'da çağrı throw eder, kullanıcı girdisi kuyruksuz kaybolur (bilinçli tasarım ama sessiz veri-kaybı yüzeyi)**
- Önem: orta | Kanıt: `egesut-erp1@eae5765:js/api.js:L501-504` (rpcOptimistic offline throw), `js/forms.js:L336` (tohumlama submit doğrudan rpc), `api.js:L741-747` + `ui.js:L10885` (close_case), `ui.js:L1176` (ovsyncBaslat); write() çağıranları grepte yalnız gorev_log/bildirim_log PATCH + drug_administrations/stok_hareket POST — write('tohumlama'|'cases'|'hayvanlar') sıfır → ui.js:L9241 RPC_MAP replay dalları ölü kod
- Gerekçe: Kullanıcıya "İnternet bağlantısı gerekli" toast'ı gösteriliyor (tamamen sessiz değil, kod içi "online-only RPC" yorumu var) ama offline'da tohumlama/vaka-kapatma girdisi kalıcı olmaksızın kaybolur.

**O18. Kabul betiği SK10'un stok-etki yolunu hiç test etmiyor (stok_iade assertion'ı yok)**
- Önem: orta | Kanıt: `egesut-erp1@eae5765:supabase/tests/ovsync_pg_kabul.sql:L1717-1754` (R32-10 bloğu yalnız kapatilan/status/audit assert eder; 'stok_iade' dosya genelinde hiç geçmiyor) — oysa fixture L1726'da tdu'lar açık bırakılarak `_vaka_kapat`'ın stok-iade UPDATE'lerini (20260923000005:L122-145, dönüş L240-245 'stok_iade') fiilen KOŞTURUYOR ama sonucunu ölçmüyor
- Gerekçe: Silent-success tipi kabul-kapsama boşluğu: yanlış stok-iade davranışı bu testi kırmaz.

**O19. veri-eşleşme özeti "hepsi → 0" der ama aracın kendi hükmü "BULGU: 57"**
- Önem: orta | Kanıt: `~/tmp/agents/veri-eslesme-20260924/ozet.json` (hukum: BULGU: 57; 2.609 test-işaretli satır), `egesut-erp1@eae5765:scripts/veri-eslesme-kontrol.py:L499-510`
- Gerekçe: Raporun saydığı üç kategori (sızıntı/yetim/türetilmiş) gerçekten 0 — teknik olarak doğru ama "hepsi" komutunun kararı TEMİZ değil; "temiz" okuması yanıltıcı.

**O20. SILENT-SUCCESS: pages.yml'de vendor ve icon kopyalamalarındaki "2>/dev/null || true" kopyalama hatasını yutuyor, bozuk site exit 0 ile yayınlanır**
- Önem: orta | Kanıt: `egesut-erp1@eae5765:.github/workflows/pages.yml:L36 ve L41` (etiket L37/L42 demişti — içerik mevcut); set -e bu satırlarda etkisiz
- Gerekçe: vendor/ silinir/checkout bozulursa build exit 0 döner, cytoscape 404 sessizce geri gelir — kapı-4'te yakalanan arızanın aynı sessiz-red sınıfı. Bugünkü HEAD'de aktif arıza değil, savunma boşluğu.

**O21. 456/445 sayı farkı kökü: kod analizi ve ölçüm 447-448 veriyor; raporun "9 assert atlanır" açıklaması da kodla uyuşmuyor — 2 PASS açıklanamıyor**
- Önem: orta (düşükten düzeltildi) | Kanıt: `egesut-erp1@eae5765:reports/2026-09-24-ovsync-pg-tamamlandi.md:L19` vs `supabase/tests/ovsync_pg_kabul.sql:L1537-1559` (MK10-ui bloğu 8 kb_ok, 9 değil), L1392-1395 (pg_cron 1 assert), L1016 (S6 saat-skip ±1)
- Gerekçe: Ölçülen: sahip-şifresi simülasyonu 448 PASS → atlama=8; statik hesap 456−8−1=447. 445'e götüren 2 assert ne kökten geliyor ne de betikte veri-bağımlı sayım var. Kalıcı davranış farkı değil, kanıt zinciri tutarsızlığı.

### DÜŞÜK

**D1. Dry-run önizleme ile gerçek koşum eligibleliği ayrışıyor: protokol_instance idempotensi önizlemede yok (over-count riski)** — Kanıt: `egesut-erp1@eae5765:supabase/migrations/20260924000002_dryrun_bayrak_bagimsiz.sql:L154` vs `20260924000001:L141-146` (ON CONFLICT (kaynak_ref) DO NOTHING → sessiz NULL). Açık görevi kapanmış ama instance'ı duran hayvan dry-run'da listeye girer, gerçek koşumda girmez. Veri bozmaz.

**D2. baslatilacak_sayisi sessiz kesiliyor — "kesildi" bayrağı simetrik uygulanmamış** — Kanıt: `20260924000002:L165-176, L183` (LIMIT c_limit=200; dönüşte baslatilacak tarafında kesildi alanı yok; acilacakta var L181).

**D3. Açık uç yanıt: dry-run'ı okuma-bekenten çağrı yolu yok — UI'da çağrıcı hiç yok; RPC_TABLES pull-seti ölü eşlenmiş** — Kanıt: `egesut-erp1@eae5765:js/api.js:324`; js/ ve html genelinde UI çağrıcısı sıfır; dry-run dalına giden tek çağrı kabul testi + cron yazım çağrısı.

**D4. Dry-run dalı "atlandi:KAPALI" yerine ok:true döner — kasıtlı ama 'ok' alanının anlamı iki dal arasında farklı (önizleme-başarılı vs koşum-başarılı)** — Kanıt: `20260924000002:L127-185 vs L187-189`; kabul R32-8/R32-11 ile yazmazlık testli.

**D5. _tohumlama_pencere IMMUTABLE işaretli ama adlandırılmış zaman dilimi kullanıyor (technically STABLE)** — Kanıt: `egesut-erp1@eae5765:supabase/migrations/20260923000003_ovsync_pg_yardimcilar.sql:L34-43`. Tz kuralı değişiminde index/plan-cache tutarsızlığı riski; pratikte etkisi düşük.

**D6. ACL parite drift: hizli_uygulama_geri_al GRANT'ında service_role yok; canlıda OR REPLACE ile korunmuş durumda** — Kanıt: `egesut-erp1@eae5765:supabase/migrations/20260923000004_ovsync_pg_uygulama_kapisi.sql:L617-618` vs canlı pg_proacl={postgres, authenticated, service_role}. Taze ortam/ROLLBACK reçetesinde service_role EXECUTE sessizce kaybolur → sessiz 403 riski.

**D7. ilk_tohumlama_zamanlayici(boolean) authenticated'a açık: 200 vakaya kadar toplu Ovsync başlatma elle tetiklenebilir** — Kanıt: `20260924000001:L1063-1064`; SPEC S-8-uyumlu, 200-cap + bayrak sınırlı; bilinçli risk kaydı.

**D8. bulk_ilac boş hayvan dizisi: stok kontrolü NULL-ifade ile geçer, dönüşte total=NULL** — Kanıt: `20260923000004:L400, L444-452, L520/531`. ok:true + {total:NULL, success:0} — işlevsiz çağrıyı hata olarak ayırt etmez (bayrak-bağımsız kalıt).

**D9. SK9: protokol_eksik_tara genişletilmedi; yerine yeni RPC ovsync_baslat_uyarilari eklendi** — Kanıt: `20260924000001:L1089-1126`; SPEC:L269 iki yola izin veriyor — kusur değil, tercih kaydı; frontend değişikliğine muhtaç.

**D10. SK10 geçişin zamansal tutarsızlığı: islem_log 2026-09-23 22:39 UTC'de, migration dosyası 2026-09-24** — Kanıt: canlı min/max(tarih)=2026-09-23 22:39:57+00, 10 satır; DO bloğu idempotent — "10 vaka [OBSERVED]" notu zaman-bağlı.

**D11. T25 SPEC maddesi (mevcut D11 görevi taşınmaz) kabul betiğinde hiç test edilmiyor** — Kanıt: `egesut-erp1@eae5765:supabase/tests/ovsync_pg_kabul.sql:L4` (T01–T25 iması) vs grep: T25 yalnız başlık yorumunda, test bloğu yok; S10 testi yalnız gövde-regex. "Mevcut D11 görevinin tarihi kaydırılmaz" davranışı hiç ölçülmemiş. (Düşükten düzeltildi.)

**D12. R32-4 testi kendi kendini kurtaran fixture: ilk koşumda görev açılmazsa test elle kurup idempotensi "doğrular"** — Kanıt: `kabul.sql:L1624-1627` ("elle garantile PERFORM kb_ok"). Taramanın gerçek başarısı asla assert edilmiyor.

**D13. "456/445" sayaç yapısı değerlendirmesi: kb_ok gerçek assertion başına satır ekliyor, boş PASS yok** — Kanıt: `kabul.sql:L34-41, L1759`; bağımsız yeniden sayım: 267 sabit + genişleme → maks ~458; 456'daki −2, dört ortam/koşullu kb_ok noktasından (L1014/L1395/L1483/L1626) ikisinin o koşumda ateşlenmemesiyle açıklanabilir. Doğrulama kararı, kusur değil.

**D14. README koşum sözleşmesi betikle uyumlu; ancak PASS/ATLANDI ayrımı README'de anlatılmıyor — "N PASS" sayısı ortama göre değişir** — Kanıt: `supabase/tests/README.md:L3-10` vs üç sessiz ATLANDI yolu (kabul.sql L1016/L1517/L1523). Kusur değil, gözlem.

**D15. Hata yutma denetimi: 19 EXCEPTION WHEN OTHERS bloğunun tamamı assert'li, sessiz-success yok; ancak prefix-level LIKE aynı prefixli farklı gerekçeli iç hatayı da PASS sayar (örn. L1007 GECMIS_TARIH sadece prefix)** — Kanıt: `kabul.sql:L180-181, L455-458, L656-657, L1006-1007`. Genel desen sağlam, blok-başı derinlik eşit değil.

**D16. P1 hata sözlüğü bypass: hızlı protokol uygulaması hatayı ham kod olarak gösteriyor (PG_ZAMAN_GECERSIZ Türkçeleşmiyor)** — Kanıt: `egesut-erp1@eae5765:js/ui.js:L2370` (toast('Hata: '+e.message); getUserMessage çağrılmıyor), `_ERR_MAP`'te PG_ZAMAN_GECERSIZ yok (api.js:L44-51); aynı desen L2424/L2439/L2533'te. P8 kabul ölçütü bu ekranda tutmaz.

**D17. P2 DRIFT: start_first_service_protocol pull seti plandaki kümenin alt kümesi — tedavi_sablonu, diseases, drugs eksik** — Kanıt: `egesut-erp1@eae5765:js/api.js:L320` (etiket L318 demişti) vs PLAN L48; protokol_instance çıkarılması DOĞRU (devrilmiş-fikir notu). Eksik üçü katalog tablosu; diseases/drugs/tedavi_sablonu diğer sync akışlarıyla senkron kaldığından kullanıcıya görünen risk düşük — plan-kabul diff'i fiilen ihlal.

**D18. P6 DRIFT: toplam_erteleme_gun kullanıcıya gösterilmiyor; GOREV_ERTELENEMEZ/GECMIS_TARIH hataları ham JSON olarak görünüyor** — Kanıt: `js/ui.js:L1059-1067`, `20260923000003:L620-625`, sözlükte kod yok; errorHandler sezgisel dalına düşer (asıl yol js/utils/errorHandler.js ~L61 — etiket sapması notlu). Ham JSON işletmeciye iniyor.

**D19. P9 DRIFT: senkronizasyon özetinde iptal GÖREV sayısı gösterilmiyor + plan-dışı ölü 'kapatilan_ovsyncler' fallback anahtarı** — Kanıt: `js/forms.js:L346-348`; RPC 'kapatilan_senkronizasyon_vakalari' döndürür (20260923000005:L536), fallback anahtarı üretilmiyor; iptal_gorev RPC'de var ama UI'a taşınmıyor (PLAN L101 formatı).

**D20. Pozitif doğrulamalar (kusur değil, plan-uyum ölçümleri)** — (a) 26 ?v= damgasının tamamı 20260924-01; (b) _katTipMap ureme eklendi (ui.js:L57); (c) pencereYuvarla tek kaynak, MK1 pencereleri aynalanmış; (d) yeni HTML'de escAttr+dataset kalıbı; (e) bayrak-kapalı aynası: tüm yeni UI yolları yalnız yeni dönüş anahtarlarıyla devreye giriyor (forms.js:L3861, migration 20260923000004:L122); (f) protokol_instance pull dışı (api.js:L318); (g) gebe inekte "Yine de uygula" butonu DOM'da yok (ui.js:L945-947).

**D21. Yayın seti vs repo farkı: referanslı hiçbir js dosyası dışarıda kalmıyor; js/_archive fazla yayını (zararsız kirlilik)** — Kanıt: `pages.yml:L39` (cp -r js), tek fazlalık js/_archive/ayarlarSperma.bak.js; sw.js no-op temizleyici + kayıt yok tutarlı.

**D22. manifest.json ?v= damgası manifest önbelleğini garanti ETMEZ** — Kanıt: `index.html:L11`; tarayıcı manifest fetch davranışı değişken; sessiz varsayım yerine açık not.

**D23. check-then-act yarışı tohumlama_sonuc_bos: FOR UPDATE yok — çift eşzamanlı çağrıda iki islem_log satırı yazılır** — Kanıt: `20260502000001:L17-47` (satır kilidi yok; UPDATE idempotent ama islem_log çift kayıt; id random uuid, tekilleştirme kısıtı yok; ground_truth:L9904 aynı kusur) vs seans_tamamla'nın FOR UPDATE + race guard'ı (`20260923000004:L226-234`). Önem düşük/orta bandına düzeltildi.

**D24. Ölü dal: rpc() ok:false gövdesini throw'a çevirdiği için ui.js:997'deki if (!r?.ok) hiç koşmaz** — Kanıt: `js/api.js:L86-90` vs `js/ui.js:L996-997`; üstelik alan uyuşmazlığı: sunucu 'error' alanı, rpc data.mesaj arar → hata ayrıntısı ancak catch yolundan e.data ile görülebilir. Ölü kod + mesaj ayrıntısı kaybı.

**D25. RPC_MAP'in hayvanlar/tohumlama/dogum/cases/kizginlik_log dalları ulaşılmaz; syncNow DELETE metodu yanlışlıkla dbInsert'e düşer** — Kanıt: `js/ui.js:L9242-9249` (write() üreticisi sıfır) + `js/api.js:L548-553` (DELETE→else→INSERT). Bugün üretici yok, latent; ileride write(...,'DELETE') eklenirse silinen kızgınlık kaydı yeniden doğar (sessiz veri bozulması).

**D26. ovsyncBaslat pull seti RPC_TABLES.start_first_service_protocol ile uyuşmuyor — islem_log eksik** — Kanıt: `js/api.js:L320` vs `js/ui.js:L1176/L1183`; online'da realtime kanalı (api.js:L627) telafi ediyor — tek seferlik tazeleme gecikmesi.

**D27. tohumlama_kaydet replay param map'i egzersize girmemiş; tek-Gönder çift-tık yarışı removeFromQueue'yu rpc'den sonra yaptığından çift uygulama açığı var** — Kanıt: `js/ui.js:L9237-9277` (op bulunur → rpc → removeFromQueue; iki hızlı tık iki rpc). Şu an tohumlama op'u kuyruğa girmiyor; istemci idempotency-token yok, dayanıklılık sunucu gövdesine muhtaç (close_case/tohumlama_kaydet ikinci-çağrı davranışı PG'den doğrulanmadı → belirsiz).

**D28. SK10 "açıksız-seanslı" filtresi td.tamamlandi bazlı; tdu-bazlı açık seans gün kapanmış olabilir (sembolik sapma) — stok sonucu yine tutarlı** — Kanıt: `20260924000001:L1156-1158` vs `20260923000005:L127-128` vs `20260613000005:L60-73` (tek-seanslı günde guard atlanır). Stok sızıntısı yok; yaygınlık canlı veri sayımıyla doğrulanmalı.

**D29. SK10 geçişi migration apply anında prod'da koşar (bayraktan bağımsız, örtük yazma)** — Kanıt: `20260924000001:L1183-1189` koşulsuz DO bloğu; L33/L54'te kasıtlılık + idempotens belgeli, REVOKE ile dışarıdan çağrıya kapalı — "migration=şema" varsayımını bozan gözlem.

**D30. TOHUMLAMA (SK10) kapanış audit'inde stok iade sayısı kaydedilmiyor** — Kanıt: `20260923000005:L226-234` (payload'da stok_iade yok; v_stok_iade hesaplanıp L244'te dönülüyor ama audit'e yazılmıyor). Gözlemlenebilirlik eksik.

**D31. Kabul betiği saat-bağımlı: S6-GECMIS_TARIH-saat testi yerel saate göre kendini atlar → "N PASS" koşum anına göre ±1 kayar** — Kanıt: `kabul.sql:L1009-1017` (İstanbul 09:00 eşiği; NOTICE şeffaf). Birebir sayı kıyaslaması koşum saati bilinmeden geçersiz.

**D32. pg_cron demo'da yok iddiası kodla tutarlı; ama demo'da gece-toplu ilk-tohumlama zinciri ASLA otomatik koşmaz — kalıcı demo/prod davranış farkı** — Kanıt: `20260923000006:L728-736` + `20260924000001:L1069-1077` + kırıntı `.crumbs/ovsync-pg-sql.jsonl:L29`. Demo S-8 zamanlayıcı davranışını sergileyemez; demo'daki zincirler trigger/elle kuruldu, cron yolu e2e kanıtsız.

**D33. demo_klonla() klon sırasında TÜM app trigger'larını susturur — klonlanan veride zincir/audit üretilmez (belgelenmiş tasarım)** — Kanıt: `demo/02_demo_klonla.sql` (DISABLE döngüsü L68-70, ENABLE L93-95 — etiket satır kayması notlu; INSERT penceresi içinde). Demo'da "geçmiş" prod trigger çıktısı, "gelecek" demo trigger çıktısıdır.

**D34. demo.js semaDiffKontrol hata yolunu sessizce yutar — şema-drift uyarısı RPC hata durumunda sinyalsiz yok olur** — Kanıt: `js/demo.js:L30` ("if (error || !data) return;") + L38 ("catch (_) {}"); klonla() L16-23 alert'li — tutarsızlık: tam uyarı verilmesi gereken senaryoda sessiz.

**D35. Demo'da AI asistan butonu gizlenmesi (dokümante, kasıtlı ortam farkı)** — Kanıt: `js/demo.js:L57-58`. "Bayrak kapalıyken bit-bit aynı" iddiaları değerlendirilirken ortam farkı olarak ayrıştırılmalı.

**D36. Kabul betiği demo koşumunda cron-job testini koşmaz ama S8-cron NOTICE yine "PASS … cron job kayıtlı" der — koşulsuz NOTICE, koşullu doğrulama** — Kanıt: `kabul.sql:L1392-1397` (assert IF içinde, NOTICE IF dışında). İnsan okuyucu demo çıktısından job doğrulandı sanabilir.

**D37. Seans iptali → stok geri yazımı VAR (ledger iptal=true yolu); stok eksik kalmıyor (olumlu)** — Kanıt: `20260923000005:L121-145` (iki UPDATE dalı), bakiye formülü `99999999999999_ground_truth.sql:L2097` (FILTER WHERE NOT iptal), `20260611000002:L295-310` (bireysel seans iptali), BUG-059 `20260613000002:L1-5` (gerçekleşmiş seanslar bilinçli iade edilmez). İade mekanizması bakiye formülüyle tutarlı.

**D38. Zincirin ikinci ayağı (seans_tamamla) sunucu tarafında çift-uygulamaya karşı sağlam (olumlu gözlem)** — Kanıt: `20260923000004:L226-234, L289-292` (FOR UPDATE + race guard + kilit sırası yorumu); bu akışta optimistic/RPC çakışma yüzeyi boş.

**D39. Operasyonel ölçüm iddialarının büyük kısmı canlı prod'da birebir DOĞRULANDI (olumlu)** — Kanıt: canlı SELECT'ler: bayrak=1 ✓, 41 rota ✓, 11 zincir + 30 görev (41=11+30 tutarlı) ✓, SK10=10 ✓, 6 sistem hormonu + PGF2A 2 satır ✓; kod: düve 12a21g (L99), inek +51 (L104), VWP 55 (20260923000003:L324); migration seti diskte ✓; 4bc8d98 pages.yml vendor ✓. Doğrulama kaydı, bulgu değil.

**D40. Cache-buster damgası tutarlı: 26/26 ?v=20260924-01, damgasız dosya yok (olumlu)** — Kanıt: index.html grep; tüm referanslı dosyalar HEAD'de mevcut.

**D41. Damga kökeni UI değişikliğiyle aynı commit'te → değişen dosyalar damgalanmış, bayat-içerik riski yok (olumlu)** — Kanıt: git log -S20260924-01 → yalnız fe5f91d; fe5f91d..HEAD aralığında index.html/js/vendor/sw.js'e dokunan commit yok.

**D42. pages.yml vendor fix'i doğru ve eksiksiz (olumlu)** — Kanıt: `pages.yml:L41-42`, vendor/ tek dosya (cytoscape.min.js, takipli), index.html:L2340 tek referans, commit zinciri c7231fc/4bc8d98 doğrulandı.

### BELİRSİZ / DOĞRULAMA KAYDI

**B1. "Kapsam dışı kalan iddialar — doğrulanamadı, sessiz varsayım yok"** — Rapor: "Demo: 18 zincir", "456/445 farkı 9 assert" (koşum T28'de kesildiği için ölçülemedi), "GitHub Pages canlı ?v=", "docker dry-run", ground-truth-audit "40 fark sahte". Bunlara kanıt bakılmadı/bakılamadı — **doğrulanmış sayılmamalı**. Kanıt: `reports/2026-09-24-ovsync-pg-tamamlandi.md:L19/L22/L23/L47`, `kabul.sql:L1016, L1522-1523`.

**B2. Kabul betiğinin 456 koşum-zamanı assertion yapısının sayısal tutarlılığı** — Bulgu D13'te çözümlendi (456 yapısal olarak türetilebilir; 445 demo farkının son 2 birimi canlı demo koşumu olmadan çözülemedi). Doğrulama kararı; ayrı kusur kaydı değildir.

---

## 3. "İddia ↔ Gerçek" çelişki tablosu

| # | İddia (rapor/plan) | Gerçek | Kanıt | Uyum |
|---|---|---|---|---|
| 1 | ovsync_pg_kurallari_aktif=1 (bayrak açık) | Canlı protokol_ayar deger=1 | canlı SELECT | ✅ |
| 2 | "Prod ilk koşum: 41 rota + 11 zincir + 30 gelecek görev" | 41 protokol_instance + 11 tamamlandi + 30 açık görev; 41=11+30 tutarlı | canlı SELECT | ✅ |
| 3 | "SK10 = 10 vaka kapandı" | islem_log CASE_CLOSED_BY_TOHUMLAMA = 10; ama 'gecis' işareti audit'te null — SK10 kapanışları ayırt edilemez | canlı + 20260923000005:L222-236 | ⚠️ kısmen (O4) |
| 4 | Katalog güvenliği: 6 sistem hormonu, PGF2A arındırması | drug_classes sistem=true 6 kayıt; PGF2A 2 satır (Kloprostenol NULL-tuzak temiz) | canlı + 20260923000002 | ✅ |
| 5 | Kural sabitleri: düve 12ay21g, inek +51, VWP 55, D50 hedefi | Kodda birebir (20260924000001:L99/L104; 20260923000003:L324) | kod | ✅ |
| 6 | "Kabul betiği: 456 PASS lokal" | Lokal ROLLBACK'li koşum OZET: 456 PASS (yeniden ölçüldü) | operasyonel lens koşumu | ✅ |
| 7 | "445 PASS demo (9 assert sahip-şifresi tablosu atlanır)" | Sahip-şifresi bloğu 8 assert (9 değil); 8+1(cron)=9 → 447 beklenir; 445'in 2 PASS'ı açıklanamıyor; ayrıca S6 saat-skip ±1 kaydırır | kabul.sql:L1537-1559, L1392-1395, L1016; simülasyon koşumu 448 | ❌ (O21, D31) |
| 8 | S-10 D39 düzeltmesi üç dogum_kaydet gövdesinde yerinde (+39 var, +11 yok) | Doğrulandı | db-migrations lens | ✅ |
| 9 | Kapı-5 dry-run fix doğru uygulandı, canlıda _acik_disi_hedef_ic mevcut; bayrak=1 | Doğrulandı; ama fix'in kapatmadığı iki kör nokta kaldı (baslatilacaklar yanıltması O5, eligible ayrışması D1) ve gerçek dal kesildi sinyalsiz (O6) | 20260924000002 | ⚠️ kısmen |
| 10 | 2026-09-23 "byte-parite: eski satırlar bayt-bayt korunur" (000004/000005) | Gövde-diff ile doğrulanmadı — yalnız migration metni okundu | db-migrations kapsam beyanı | ❓ doğrulanmadı |
| 11 | Demo: 18 zincir | Demo DB'ye erişim yok — kanıt yalnız kırıntı/kod çaprazı; cron yolu e2e kanıtsız | .crumbs/ovsync-pg-sql.jsonl:L29 + 20260923000006:L728-736 | ❓ doğrulanmadı (D32) |
| 12 | veri-eslesme-kontrol.py "hepsi → sızıntı/yetim/türetilmiş 0" | Üç kategori gerçekten 0; ama aracın kendi hükmü BULGU: 57 (2.609 test-işaretli satır) — "temiz" okuması yanıltıcı | ozet.json + veri-eslesme-kontrol.py:L499-510 | ⚠️ kısmen (O19) |
| 13 | GitHub Pages canlı + ?v=20260924-01 damgası | Kod/damga kökeni düzeyinde doğrulandı (26/26, fe5f91d); canlı deploy çıktısı ölçülemedi | index.html + git log -S | ⚠️ kod-kanıtı (D40-D42) |
| 14 | UI P1–P10 plan-uyumu | P5 (O1-O3), P7 önizleme (O10), P3/P10 (O12), P6 (D18), P9 (D19), P2 (D17), P8 (O11) maddelerinde drift; geri kalanlar plan-uyumlu (D20) | ui-plan lens | ⚠️ kısmen |
| 15 | "Test suite green" | Unit 1086/1089 pass, 3 fail (2 tarih-seçici UI regresyonu + 1 canlı DEMO şema); Playwright e2e koşulmadı | npm run test:unit | ⚠️ (O15) |
| 16 | "idempotency sunucuda" (ui.js:989 yorumu) | Sunucuda idempotency anahtarı yok; yalnız durum-guard'ı — yarım-zincir retry'ı reddediyor, tekrarlı-uygulamayı engellemiyor; tohumlama_sonuc_bos'ta FOR UPDATE de yok | 20260502000001:L17-47 | ❌ (O2, D23) |
| 17 | "dry-run = gerçek koşum önizlemesi" (20260924000002 başlığı) | Eligiblelik fix'li ama: instance-idempotensi önizlemede yok (over-count), baslatilacaklar bayrak-kapalı yanıltması, ok alanının anlamı dallar arası farklı | 20260924000002:L154/165-185 vs 20260924000001:L141-146 | ⚠️ kısmen (D1, O5, D4) |
| 18 | SK10 stok etki yolu | Stok iade mekanizması mevcut ve tutarlı (D37); ama kabul betiği bu yolu test etmiyor (O18), audit'e stok_iade yazılmıyor (D30) | 20260923000005:L121-145 | ⚠️ kod ✓ / test ✗ |
| 19 | "9 assert sahip-şifresi atlanır" sayısı | Bağımsız sayım: korumalı blokta 7-8 kb_ok; sayı ölçülemedi olarak da beyan edilmişti | kabul.sql:L1522-1559 | ⚠️ (O21, B1) |

---

## 4. Kapsanmayan alanlar (açık beyan)

Aşağıdakiler bu incelemede **doğrulanmadı**; bulgu üretilmedi ve üstü doldurulmadı:

1. **Canlı DB vs repo drift'i (kapsamlı):** Çoğu lens statik kod/migration okumasıyla çalıştı; canlı fonksiyon gövdeleri (özellikle tohumlama_sonuc_bos(text)/(text,text) hangisinin canlı olduğu, Y2), cron.job içeriği, ACL'ler ve pg_get_functiondef byte-parite iddiaları SELECT ile ölçülmedi.
2. **Demo projesi (vtzqjmazsvurxdeondmi):** Canlı demo DB'ye erişim yok — "18 zincir", "445 PASS" ve demo migration setinin repo ile birebirliği canlıdan doğrulanamadı (yalnız kod/kırıntı çapraz-kanıtı; 448 PASS'lı lokal demo-simülasyon koşumu var).
3. **Gerçek GitHub Pages deploy:** Workflow _site içeriği yalnız koddan türetildi; Actions log ve canlı URL 200 kontrolü kapsam dışı.
4. **Playwright e2e** (modal-router.spec.js, offline-kuyruk.spec.js) koşulmadı — yalnız dosya içerik grep'i; modal-router geri-tuşu invariant'ı üç yeni sheet için test-gapsiz (O13).
5. **Kabul betiğinin tam koşum-zamanı izi:** Lokal ROLLBACK'li koşum ilk FAIL'de değil ama T28 yoluyla sınırlı kalabilirdi — koşumun tüm ~246+ assertion'ının birebir satır eşlemesiyle 456'ya kırılımı yapılmadı (D13'te yapısal türetim).
6. **SPEC'in 305 satırının tamamı:** Yalnız T13'/T14'/T25/UREME_KONTROL ve matris başlıkları çaprazlandı; SK bloklarının testle birebir eşleşmesi eksiksiz denetlenmedi.
7. **Kod-dışı veri durumları:** SK10 sonrası oluşan 12 aktif OVSYNC vakanın iş kuralı uygunluğu; "td.tamamlandi=true + tdu açık" sapmasının canlı yaygınlığı; SK10'un prod'da kapattığı vakalarda gerçek stok_iade sayıları.
8. **Tarayıcı-düzeyi davranışlar:** çift dokunuş/pointer yarışı, history/back-guard modal yarışı, service worker (sw.js) önbellek etkileşimi, offline replay'de p_pg_onay kaybının gerçek kuyruk akışındaki sonucu — statik kod okuması.
9. **Sunucu RPC gövdelerinin ikinci-çağrı (idempotency) davranışı:** tohumlama_kaydet, close_case_with_remaining, start_first_service_protocol'ün r.zaten dalı dışındaki tekrar davranışı PG fonksiyon metninden derinlemesine okunmadı.
10. **PG kapı hata JSON'undaki kupe/tarih alanlarının XSS'i:** yalnız esc/fmtTarih yolları statik incelendi; canlı sunucu çıktısıyla sınanmadı.
11. **_ovsync_kural_tarihi'nin iç doğruluğu (kural matematiği)** ve **js/gecmis.js, js/degisiklikler/*, sw.js** yalnız isim geçişi tarandı.
12. **_ilk_tohumlama_rota_kur'un tüm tetik yollarının davranışsal testi:** yalnız T28' yolu koşuldu.
