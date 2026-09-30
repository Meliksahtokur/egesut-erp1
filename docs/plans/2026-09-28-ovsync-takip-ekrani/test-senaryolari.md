# Ovsync Takip + Boş-devam — Senaryo Test Kataloğu

- Tarih: 2026-09-28 · Katalog sürümü 1 · Yazar: test koltuğu (glm-max lead), GÖREV: `runs/2026-09-28-ovsync-takip/test-GOREV.md`
- **Katalog sürümü 2 (2026-09-29):** plan v7 (§10c–§10h) ile hizalama — KATALOG GÜNCELLEME 1–17 birebir uygulandı (P12 1. adım D7). T-04/T-05/T-25/T-26/T-39/T-44/T-45/T-61/T-72/T-73 güncellendi; **T-74..T-94 yeni** (21 senaryo); SPEC SORULARI'nın hepsi kapandı (açık soru yok). Kaynak: `plan.md` §KATALOG GÜNCELLEME + `design.md` §9, §10c–§10h.
- **Katalog sürümü 3 (2026-09-30):** kapsam-açık denetimi — planın açık P2b/P3a sözleşme guard'ları olup v2'de sınamayan 6 davranış için **T-95..T-100** eklendi (§S); toplam **100** senaryo. Denetim raporu: `runs/2026-09-28-ovsync-takip/katalog-kapsam-DONE.md`.
- Otorite: SPEC v3 `docs/plans/2026-09-28-ovsync-takip-ekrani/design.md` (§4b, §5, §6b, §6c, §7, §9, §10) + `.harness/references/domain-rules.md` §18 (bağlayıcı)
- Mockup (sahip onaylı): `runs/2026-09-28-ovsync-takip/mockup/bos-devam/01..07` — beklenen görünüm kaynağı
- PROD kenar durum kaynağı: `runs/2026-09-28-ovsync-takip/db-ovsync-durum-raporu.md` (A1–A10), `runs/2026-09-28-ovsync-takip/w2-veri-modeli-raporu.md`

## 0. Kullanım kuralları

**Ad notasyonu (v2 güncel):** RPC/görev-tipi adları plan v7 ile KESİNLEŞTİ: `ovsync_takip_listele` (P1), `tohumlama_bos_ve_devam` (P2b), takip görev tipi `TAKIP_MUAYENE` + `gorev_log.takip_kapanis_nedeni` (P2a), kapanış tetikleyicileri (P3a). Koşucular bu adları kullanır; davranış değişirse plan-madde referansı izlenir.

**Katmanlar:**
- **DB-SQL** — demo veritabanında psql/RPC doğrudan çağrı; kurulum seed'leri demo'da yazabilir. Üretim (PROD) veritabanına bu katalog kapsamında **hiçbir erişim yok** (kural: yazma yok; okuma yalnız demo).
- **UI-Playwright** — `tests/*.spec.js`, `PLAYWRIGHT_DEMO_MODE=1`, `tests/support/app.js` yardımcıları; veri-agnostik politika (küpe varsayımı yok, `E2E-` marker disiplini); DB doğrulaması spec istedikçe demo RPC/REST ile.
- **İnsan-UI** — glmf-max koltuğunda tarayıcıda elle gezinme (proje CLAUDE.md "UI testi kapısı"); madde listesi §İNSAN-UI'de.

**Yaygın ön koşullar (her senaryoda tekrarlanmaz):** `protokol_ayar.ovsync_pg_kurallari_aktif = 1` (demo); kullanıcı demo'da oturumlu; tarih hesapları "bugün" = koşum günü. "H" = senaryoya özel seçilmiş/demo-seed hayvan.

---

## A. Devam seçici — her seçenek × her Boş giriş noktası (kapsam 1)

### T-01 — Tohumlama sonuç modalı: Boş + Ovsync uygula (ön seçim, hemen)
- **Ref:** §6c.1, K12, S3b, S3 · kabul 11 · §18.15 · mockup 01
- **Katman:** UI-Playwright + DB-SQL
- **Ön koşul:** H sağmal, kural günü gelmiş (son doğum +51 g önce), `kisir=false`; sonucu=Bekliyor tohumlaması var; açık takip görevi yok.
- **Adımlar:** 1) Bekliyor tohumlama satırı → detay modalı → "Sonuç Güncelle" → ❌ Boş. 2) Devam seçici görünür: üç kart, **Ovsync ön seçili**, ön ayar "hemen". 3) Kaydet — etiket **"Boş ata + Ovsync başlat"**.
- **BEKLENEN — DB:** `tohumlama.sonuc='Boş'`; `cases`'te yeni `active` OVSYNC vakası (`start_date`=bugün, `source_template_id`=şablon, snapshot dolu); 4 `treatment_days` (d0/d7/d8/d9 = bugün+0/7/8/9); TAI görevi `TOHUMLAMA_PLANLI` hedef=bugün+10, `hedef_saat`=şablon saati; hayvanın eski `GEBELIK_KONTROL`/`TOHUMLAMA_HAZIRLIK` görevleri iptal; `pg_application_event` YENİ satır YOK.
- **BEKLENEN — Ekran:** onay toast; modal kapanır; Ovsync ekranı S1'de yeni satır; hayvan S2'den düşmüş; `window.__ovsyncTakip = null` (invalidate).
- **Ters kanıt:** "yalnız Boş ata" tek başına kaydedilmedi; ikinci bir `OVSYNC_BASLAT` görevi doğmadı; stok düşümü olmadı.

### T-02 — Sonuç modalı: Boş + PG uygula (ürün/doz ön dolu)
- **Ref:** §6c.1 tablo PG satırı, S4 · kabul 11 · mockup 03
- **Katman:** UI-Playwright + DB-SQL
- **Ön koşul:** T-01 + hayvanda daha önce kullanılmış bir PG ürünü+dozu var (demo geçmişinde PG uygulaması).
- **Adımlar:** 1) Boş seç → PG kartı seç. 2) "Ürün ve doz (son kullanılan, değiştirilebilir)" alanı **son kullanılan ürün/dozla dolu ve düzenlenebilir** görünür (mockup 03: "Estrumate 2 ml ▾"). 3) Kaydet — "Boş ata + PG uygula".
- **BEKLENEN — DB:** `sonuc='Boş'`; PG çekirdeği (mevcut bağımsız PG yolu) işledi: `pg_application_event` satırı (karar=ALLOW), stok düşümü aynı kurallarla; hayvan TAI'a uygunsa +48 s `TOHUMLAMA_PLANLI` (`kaynak='PG_TOHUMLAMA:<olay_id>'`); uygunsuzsa `UYGUNSUZ` olay kaydı ve görev yok (§18.6 — doğru davranış).
- **BEKLENEN — Ekran:** toast; Ovsync ekranında hayvan varsa S1 (aktif TAI zinciriyle) / uygunsuzsa Boş'un düşeceği bölüm.
- **Ters kanıt:** Ovsync vakası AÇILMADI (`cases` yeni satır yok); doz alanı salt-okur değil.

### T-03 — Sonuç modalı: Boş + Takibe bırak (varsayılan +7 g, saat = atama anı)
- **Ref:** §6c.1 tablo Takip satırı, S2, S5 · kabul 11 · §18.15 · mockup 01
- **Katman:** UI-Playwright + DB-SQL
- **Ön koşul:** T-01 ön koşulu.
- **Adımlar:** 1) Boş seç → Takibe bırak kartı seç. 2) Gün ön ayarı **+7** (düzenlenebilir), saat alanı **atama anındaki saat**. 3) Kaydet — "Boş ata + takibe bırak".
- **BEKLENEN — DB:** `sonuc='Boş'`; tek takip muayenesi görevi: `hedef_tarih`=bugün+7, `hedef_saat`=atama saati, ayırt edici takip işareti (tip/kaynak — plan kesinleştirir); `tamamlandi=false, iptal=false`; kapanış-nedeni alanı boş.
- **BEKLENEN — Ekran:** Görevler'de görev seçilen gün+saatte görünür (🌱 Üreme kategorisi, §18.16); Ovsync ekranı S3'te "🔍 takipte · muayene GG.AA SS:SS" rozeti.
- **Ters kanıt:** `OVSYNC_BASLAT` görevi doğmadı (bkz. T-12); vaka açılmadı; ikinci takip görevi yok.

### T-04 — Birleşik muayene sonucu (K15): Gebe / Boş→seçici / Muayeneyi ertele (v2)
- **Ref:** §6c.1 ("HER giriş noktası"), S8, **K15 (§10c #5)**, **§18.17**, **§10d #3** · kabul 11 · §18.13
- **Katman:** UI-Playwright + DB-SQL
- **Ön koşul:** H tohumlaması son-tohumlama+≥40 günü geçmiş (sonuç Bekliyor); `GEBELIK_KONTROL` görevi açık (tek üretici cron — T-80); eşik ayarı 40.
- **Adımlar:** Görev/hayvan üzerinden **birleşik muayene sonuç ekranı** (K15): **Gebe** · **Boş (→ devam seçici: Ovsync/PG/Takibe bırak)** · **Muayeneyi ertele** (+7 ön ayar, saat **varsayılan SAATSİZ**). Varyant a) Gebe b) Boş+üç seçenek c) Ertele — her biri ayrı koşum.
- **BEKLENEN — DB/UI:** b) T-01/02/03 ile birebir aynı sonuçlar (tek fark giriş yüzeyi); a) T-78 çekirdek yolu; c) T-75 erteleme sözleşmesi. **Ekran özdeşliği:** bu ekran TAKIP_MUAYENE ekranıyla AYNI ekrandır (T-76); etiketlerde "Boş ata" öneki YOK (S-10: "Muayene tamam + …").
- **Ters kanıt:** gebelik muayenesi yüzeyinde "yalnız Boş" kaydet yolu yok; jenerik `gorev_tamamla` bu görevi sonuçsuz KAPATAMAZ (T-74 guard); seçici dışı eski akışa (Boş → otomatik OVSYNC_BASLAT) düşülmedi; "21. gün kontrol" ifadesi yok (§18.13).

### T-05 — Takip muayenesi sonuç ekranı (6c.4): seçenek seti + Gebe (v2)
- **Ref:** §6c.4, **S-3 (§10b/§10e D1)**, **K15** · kabul 11 · mockup 05
- **Katman:** İnsan-UI + UI-Playwright
- **Ön koşul:** H açık takip muayenesi görevinde (T-03 ile kurulmuş), muayene günü gelmiş; görev "🔍 Küpe X — muayene GG.AA SS:SS".
- **Adımlar:** Görevi aç → "🔍 Takip muayenesi — Küpe X" ekranı: başlıkta "Boş atandı GG.AA · takip N. gün"; **aynı devam seçici + Gebe** (tam set: **GEBE / Ovsync / PG / Muayeneyi ertele**; TAKIP_MUAYENE yolunda yeniden Takibe bırak YOK — P2b seçim tablosu) + bağlantı **"🐄 Kızgınlıkta → tohumlama kaydına geç"**.
- **BEKLENEN — Ekran:** mockup 05 birebir; Kaydet etiketi seçime göre değişir ve **"Boş ata" ÖNEKİ YOK** (S-10 kapandı — §10c copy: "Muayene tamam + …": "Ovsync başlat" / "PG uygula" / "Muayeneyi ertele"); ertele ön ayarı +7 gün, saat **varsayılan SAATSİZ** (§10d #3 — mockup'taki saat ön ayarı geçersiz kılındı).
- **BEKLENEN — DB (Gebe seçilirse):** S-3 kararı — önceki Boş **hatalı** sayılır: son tohumlama `sonuc='Gebe'`'ye çevrilir (çekirdek `_tohumlama_gebe_uygula`, `p_bos_duzeltme=true`), takip `GEBE_BULUNDU` ile kapanır; üreme geçmişinde iki satır (T-84). (Ovsync seçilirse: takip kapanır + vaka T-01 ile aynı.)
- **Ters kanıt:** bu ekranda "yalnız sonuç kaydet" yok; **genel `tohumlama_sonuc_gebe` RPC'si Boş tohumlamayı hâlâ REDDEDER** (Bekliyor-only — çekirdek genişlemesi sızıntı değil, T-83); ertelemede görev UPDATE (yeni görev INSERT değil — bkz. T-25).

### T-06 — PG kapısı "Boş ata ve uygula" = Boş+PG karşılığı; seçici AÇILMAZ
- **Ref:** §6c.1 son paragraf, S7 · kabul 11 · §18.8 (`_pgKapiHata`, `#pg-kapi-bs`)
- **Katman:** UI-Playwright + DB-SQL
- **Ön koşul:** H'de sunucu `PG_KAPI:*` raise edecek durum (mevcut PG kapı koşullarından biri; ör. açık tohumlama/görev çakışması) ve PG uygulanmak isteniyor.
- **Adımlar:** 1) PG giriş noktasından sunucu `PG_KAPI:*` redsi → `_pgKapiHata` onay penceresi (`#pg-kapi-bs`: "Boş ata ve uygula" / "Vazgeç"). 2) "Boş ata ve uygula".
- **BEKLENEN — DB:** tek işlemde: `tohumlama.sonuc='Boş'` + PG uygulaması + (uygunsa) +48 s TAI — T-02 ile aynı sonucun hepsi.
- **BEKLENEN — Ekran:** devam seçici **hiç görünmez** (bu yol = "Boş + PG" seçiminin kendisi).
- **Ters kanıt:** çift onay/çift kayıt yok; "Vazgeç" dalında (aynı koşumda ayrı adım) hiçbir şey yazılmaz — `sonuc` Bekliyor kalır.

### T-07 — Seçim zorunlu; seçilmeden Kaydet pasif
- **Ref:** §6c.1 ("Seçim ZORUNLU… 'yalnız Boş ata' yolu YOK"), S3 · kabul 11
- **Katman:** UI-Playwright
- **Ön koşul:** herhangi bir Boş giriş noktası (T-01/T-04).
- **Adımlar:** Boş seç → seçici görünür; hiçbir kart seçilmeden Kaydet düğmesine çalış.
- **BEKLENEN — Ekran:** Kaydet **pasif** (disabled) — mockup 01: "biri seçilmeden Kaydet pasif" (07-akis); "Devam nasıl olsun? (zorunlu)" etiketi görünür.
- **Ters kanıt:** Boş sonucu seçicisiz kaydeden gizli yol yok (DB-SQL: `tohumlama_bos_ve_devam`'sız `sonuc='Boş'` yazan UI yolu yok —kod taraması ile desteklenir).

---

## B. Tek-işlem atomikliği (kapsam 2)

### T-08 — PG dalı hata → Boş ATANMAZ
- **Ref:** §6c.2 ("Tek transaction — biri düşerse Boş da atanmaz") · kabul 11
- **Katman:** DB-SQL (birincil) + UI-Playwright (stub: RPC hatası)
- **Ön koşul:** T-02 ön koşulu; PG stokunda yetersizlik kur (seed) YA DA geçersiz `p_pg_urun` ile RPC çağır.
- **Adımlar:** `tohumlama_bos_ve_devam(p_secim='PG', p_pg_urun=<geçersiz/stoksuz>)` → sunucu hatası.
- **BEKLENEN — DB:** `tohumlama.sonuc` HÂLÂ 'Bekliyor'; `pg_application_event` yeni satır yok; stok değişmedi; görev doğmadı. (UI varyantı: hata toast + modal açık kalır.)
- **Ters kanıt:** yarım durum yok — ne "Boş atandı ama PG olmadı" ne "PG oldu ama sonuç girilmedi".

### T-09 — Ovsync dalı hata → Boş ATANMAZ
- **Ref:** §6c.2 · kabul 11 · §18.3 (`OVSYNC_ERKEN`)
- **Katman:** DB-SQL
- **Adımlar:** kural günü gelmemiş H'de `p_secim='OVSYNC'` zorla → `OVSYNC_ERKEN:{…}` (veya kısır guard redsi).
- **BEKLENEN — DB:** sonuç Bekliyor; vaka/gün/görev hiç kurulmadı.
- **Ters kanıt:** UI bu yolu zaten kilitler (T-14..16) — sunucu katmanı da tek başına dayanıklı (UI atlanarak kötü çağrı).

### T-10 — TAKIP dalı hata → Boş ATANMAZ
- **Ref:** §6c.2 · kabul 11
- **Katman:** DB-SQL
- **Ön koşul:** görev kurulumunu kıracak durum (ör. `hedef_tarih` kısıtına aykırı geçersiz `p_gun`).
- **Adımlar:** `p_secim='TAKIP'`, geçersiz gün → sunucu red.
- **BEKLENEN — DB:** sonuç Bekliyor; görev yok.
- **Ters kanıt:** takip görevi "sonra kurulur" artığı yok.

### T-11 — PG kapısı yolunda atomiklik
- **Ref:** §6c.1 + §18.8 · kabul 11
- **Katman:** UI-Playwright + DB-SQL
- **Adımlar:** T-06 akışında sunucuyu PG çekirdeğinde hataya zorla (stok düşümü başarısız).
- **BEKLENEN — DB:** `sonuc` Bekliyor (Boş atanmadı); olay yok.
- **Ters kanıt:** "Boş atandı + PG düşmedi" yarı-durumu yok.

---

## C. Sıralama tuzağı (kapsam 3)

### T-12 — TAKIP seçiminde OVSYNC_BASLAT DOĞMAMALI
- **Ref:** §6c.2 ("takip görevi `_acik_disi_gorev_kur`'dan ÖNCE kurulur ya da çekirdek bu yolda o çağrıyı atlar") · kabul 11 · §18.15
- **Katman:** DB-SQL + UI-Playwright
- **Ön koşul:** H muafiyeti olmayan (kural günü gelmiş, açık görevi olmayan) hayvan.
- **Adımlar:** T-03 akışını koş (Boş + TAKIP). Sonra `gorev_log`'da H'nin `OVSYNC_BASLAT` satırlarını sorgula.
- **BEKLENEN — DB:** sıfır yeni `OVSYNC_BASLAT` (ne o an ne de `_acik_disi_gorev_kur`'un gecikmeli etkisi); yalnız takip görevi.
- **Ters kanıt:** muafiyet penceresi dolmadan görev satırı belirdi → HATA (regresyon: muafiyetten önce görev doğması spec'in açık korkusu).

### T-13 — Takip açıkken otomatik OVSYNC_BASLAT açılmaz (gece taraması)
- **Ref:** §6c.3, S2c · kabul 11 · §18.15
- **Katman:** DB-SQL
- **Ön koşul:** H'de açık takip görevi; H açık-dişi taramasına girecek durumda (aksi muafiyeti yok).
- **Adımlar:** açık-dişi kurulum yolunu tetikleyen mekanizmayı çağır (cron/reconcule karşılığı çekirdek; ad planla kesinleşir) ya da kurulum fonksiyonunu H ile doğrudan çağır.
- **BEKLENEN — DB:** H için görev KURULMAZ (muafiyet listesi "açık takip görevi olan"ı içerir); işlem kaydında muafiyet izi.
- **Ters kanıt:** takip kapanınca aynı tarama görevi KURAR (pozitif kontrol — kapanış sonrası kural günü geldiyse).

---

## D. Hard block — Ovsync kilidi (kapsam 4)

### T-14 — Kısır: Ovsync kartı kilitli + gerekçe; ön seçim Takibe bırak
- **Ref:** §6c.1 (hard block), S6 · kabul 11 · §18.5 · mockup 02 (kilit deseni)
- **Katman:** İnsan-UI + UI-Playwright
- **Ön koşul:** H `kisir=true`, sonucu Bekliyor tohumlaması.
- **Adımlar:** Boş seç → seçicide Ovsync kartı **kilitli + "🔒 Kısır"** gerekçesi; PG ve Takibe bırak seçilebilir; **ön seçim Takibe bırak'ya düşmüş**; Kaydet etiketi "Boş ata + takibe bırak" (mockup 02).
- **BEKLENEN — DB (Takibe bırak ile):** T-03 sonuçları.
- **Ters kanıt:** kilitli Ovsync kartı tıklanabilir değil; DB'de `p_secim='OVSYNC'` zorlaması red (T-18).

### T-15 — Kural günü gelmemiş — düve (doğum+12 ay 21 g)
- **Ref:** §6c.1, S6 · kabul 11 · §18.1
- **Katman:** UI-Playwright + DB-SQL
- **Ön koşul:** H düve, `dogum_tarihi` bugün−(12 ay 21 g − N gün) olacak şekilde (N=14 öneri); kural günü = bugün+14.
- **Adımlar:** Boş seç → Ovsync kartında **"🔒 Kural günü GG.AA — N gün var"** (mockup 02 deseni); ön seçim Takibe bırak.
- **BEKLENEN — DB:** Takibe bırak yürüyor; Ovsync denemesi (zorla) `OVSYNC_ERKEN`.
- **Ters kanıt:** kural günü metni düve formülüyle hesaplı (doğum+12ay21g); ekranda gün sayısı = kural_günü − bugün.

### T-16 — Kural günü gelmemiş — doğumlu/abortlu (GREATEST(son doğum, son abort)+51)
- **Ref:** §6c.1 · kabul 11 · §18.1
- **Katman:** UI-Playwright + DB-SQL
- **Ön koşul:** H'de son doğum bugün−20 (kural günü bugün+31); ayrı varyant: abort varsa ve abort daha yakınsa GREATEST abort'tan sayar.
- **Adımlar:** T-15 ile aynı; gerekçe "🔒 Kural günü bugün+31 — 31 gün var".
- **BEKLENEN/Ters:** T-15 ile aynı; abort-dalında da 51 g formülü doğru.

### T-17 — Kısır + kural günü gelmemiş (ikisi birden)
- **Ref:** §6c.1 · kabul 11 — **gerekçe önceliği spec'te tanımsız → SPEC SORUSU S-1**
- **Katman:** UI-Playwright
- **Ön koşul:** H `kisir=true` VE kural günü gelmemiş.
- **Adımlar:** Boş seç → Ovsync kilitli; görünen tek gerekçe metnini kaydet.
- **BEKLENEN — Ekran:** kilitli kart + EN AZ BİR gerekçe; hangi metin öncelikli olduğu plan cevabıyla dondurulur (S-1).
- **Ters kanıt:** iki gerekçe aynı anda yarım/yarış halinde basmıyor; davranış (kilit) her iki durumda da aynı.

### T-18 — Hard block sunucuda esnetilmez
- **Ref:** §6c.1 ("Kapı esnetilmez; istisna DB seed ile — sahip"), §18.3/§18.5 · kabul 11
- **Katman:** DB-SQL
- **Adımlar:** kısır ve kural-günü-gelmemiş H'lerde `p_secim='OVSYNC'`, `p_onay=true` dahil → red.
- **BEKLENEN — DB:** her ikisi de hata (kısır guard / `OVSYNC_ERKEN`); hiçbir yan yazma yok.
- **Ters kanıt:** `p_onay=true` hard block'u AŞMAZ (onay yalnız `TAKIP_ACIK` içindir).

---

## E. Takip otomatik kapanış (kapsam 5)

### T-19 — Yeni tohumlama → SESSİZ kapanış + neden kaydı
- **Ref:** §6c.3 (kapanış listesi 1. madde) · kabul 11 · mockup 07
- **Katman:** UI-Playwright + DB-SQL
- **Ön koşul:** H'de açık takip görevi; kızgınlık gözlemi/tohumlama kaydı girilecek.
- **Adımlar:** normal tohumlama kaydını gir (herhangi bir giriş yolu).
- **BEKLENEN — DB:** takip görevi KAPANDI (tamamlandı/iptal kombinasyonu planın tanımına göre); kapanış nedeni görevde **"yeni tohumlama"** iziyle kayıtlı (sessiz iptal DEĞİL — iz var); onay penceresi HİÇ açılmadı (sessizlik ekran tarafında).
- **Ters kanıt:** `TAKIP_ACIK` hatası/onayı çıkmadı; tohumlama engellenmedi.

### T-20 — PG/Ovsync → `TAKIP_ACIK` onayı: EVET
- **Ref:** §6c.3 (2. madde), S2b · kabul 11 · mockup 04
- **Katman:** İnsan-UI + UI-Playwright + DB-SQL
- **Ön koşul:** H'de açık takip (muayene GG.AA SS:SS); PG uygulama ekranına gel (bağımsız PG ya da Boş+PG).
- **Adımlar:** 1) Uygula → sunucu `TAKIP_ACIK:{…}`. 2) App'in kendi bottom-sheet'i (tarayıcı `confirm()` DEĞİL): **"Küpe X, GG.AA SS:SS'te rektal muayene takibinde. Takip kapatılıp PG uygulansın mı?"** (mockup 04). 3) "Evet, takibi kapat ve uygula" → `p_onay=true` ikinci çağrı.
- **BEKLENEN — DB:** takip kapandı (neden=takip kapatıldı/PG); PG uygulandı (T-02 sonucu) — ikisi TEK işlemde.
- **BEKLENEN — Ekran:** onayda küpe no + muayene tarihi/saati metni; tek onay penceresi.
- **Ters kanıt:** "Evet"te takip açık kalıp PG olması yok; düz hata toast'ı YASAK (§18.8 ruhu).

### T-21 — `TAKIP_ACIK` onayı: VAZGEÇ
- **Ref:** §6c.3 · kabul 11 · mockup 04
- **Katman:** UI-Playwright + DB-SQL
- **Adımlar:** T-20 adım 2'de "Vazgeç".
- **BEKLENEN — DB:** HİÇBİR değişiklik: takip açık, PG yok, vaka yok.
- **BEKLENEN — Ekran:** pencere kapanır, önceki ekrana dönülür; ikinci otomatik deneme yok.

### T-22 — Hayvan çıkışı → kapanış
- **Ref:** §6c.3 (3. madde) · kabul 11
- **Katman:** DB-SQL
- **Ön koşul:** H'de açık takip; çıkış (satış/ölüm) kaydı girilebilir demo durumu.
- **Adımlar:** çıkış işlemini gir.
- **BEKLENEN — DB:** takip kapandı, neden=çıkış; ek muayene görevi doğmadı.
- **Ters kanıt:** çıkış sonrası listede "muayene bekler" artığı yok (T-59 KPA ile bağlanır).

### T-23 — Kapanış nedeni üç olayda da kayıtlı
- **Ref:** §6c.3 ("Kapanış nedeni görevde kaydedilir — sessiz iptal değil") · kabul 11
- **Katman:** DB-SQL
- **Adımlar:** T-19, T-20, T-22 koşumlarının sonunda görev kaydının kapanış-nedeni alanını oku.
- **BEKLENEN — DB:** üç farklı olay üç ayırt edilebilir neden değeri; boş/null kapanış yok.
- **Ters kanıt:** hepsinde aynı genel "iptal" değeri değil (ayrıştırılabilirlik).

### T-24 — Aynı anda iki olay (çift kapanış yok)
- **Ref:** §6c.3 · kabul 11
- **Katman:** DB-SQL
- **Ön koşul:** H'de açık takip.
- **Adımlar:** tetik tablosuna aynı anı simüle eden çift olay (önce tohumlama sonra PG — aynı transaction sırası) uygula.
- **BEKLENEN — DB:** takip BİR kez kapanır; ikinci olay takibi zaten kapalı bulur (idempotent); hata/YARIM durum yok.
- **Ters kanıt:** çift kapanış izi/çift kapanış-nedeni üst üste yazımı yok.

---

## F. Muayene erteleme döngüsü (kapsam 6)

### T-25 — Tek erteleme: +7 gün, saat seçilebilir VARSAYILAN SAATSİZ (v2 — §10d #3)
- **Ref:** §6c.4 ("yeni muayene tarihi yeniden hesaplanır, aynı takip zinciri sürer"), **S-2 kapandı (§10b) → §10d #3 güncellemesi** · kabul 11 · mockup 05
- **Katman:** UI-Playwright + DB-SQL
- **Ön koşul:** H takip muayenesi gününde (T-05 ekranı açık).
- **Adımlar:** "📅 Muayeneyi ertele" (+7 ön ayar) → saat alanı boş bırakılır (SAATSİZ ön ayar) → onayla. Ayrı varyant: saat girilir (düzenlenebilir).
- **BEKLENEN — DB:** görev `hedef_tarih` = eski+7; **saat girilmediyse `hedef_saat` NULL (saatsiz görev)** — eski atama saati korunmaz, sıfırlanmaz; girildiyse girilen saat atanır; görev satırı UPDATE (yeni görev INSERT değil); takip işareti korunur; kapanış yok.
- **BEKLENEN — Ekran:** S3 rozeti yeni "muayene GG.AA" (saatsizse saat gösterilmez); Görevler'de tarih kaydı görünür.
- **Ters kanıt:** ikinci/paralel takip görevi doğmadı; "önceki saat ön ayarlı" davranış YOK (S-2'nin eski hali §10d #3 ile geçersiz).

### T-26 — Çoklu erteleme (zincir 2+ kez) + ≥21 g tek onay (v2 — S-7 kapandı)
- **Ref:** §6c.4, **S-7 (§10b SAHİP: sınırsız + ≥21 g onay)** · kabul 11
- **Katman:** UI-Playwright + DB-SQL
- **Adımlar:** T-25'i arka arkaya 3 kez (aralarında gün ilerletme/tarih seçiciyle). Varyant: toplam takip süresi (ilk kuruluştan) **≥21 gün** olunca ertele → tek onay "Bu hayvan N gündür takipte, emin misiniz?" → Evet → ertelenir.
- **BEKLENEN — DB/UI:** her turda +7; TEK görev satırı; muayene ekranı başlığındaki "takip N. gün" güncel; ≥21 g onayda `p_onay=false` ile red (`TAKIP_UZADI:{toplam_gun}`), tek onayla geçer.
- **Ters kanıt:** erteleme tavanı YOK (sınırsız); onaysız geçiş yok; çift onay penceresi yok.

### T-27 — Erteleme sonrası S3 rozeti güncellenir
- **Ref:** §6c.5 · kabul 11 · mockup 06
- **Katman:** İnsan-UI
- **Adımlar:** T-25 sonrası Ovsync ekranını aç.
- **BEKLENEN — Ekran:** satır rozeti "🔍 takipte · muayene <yeni tarih> <aynı saat>"; hayvan hiçbir bölümden düşmedi.
- **Ters kanıt:** eski tarih rozeti kalmadı.

---

## G. Deneme sayacı (kapsam 7)

### T-28 — Doğum sonrası sayaç sıfırlanır
- **Ref:** §4 (deneme rozeti), K13, R8 · kabul 3 · §18.14
- **Katman:** DB-SQL + UI-Playwright
- **Ön koşul:** H: 3 tohumlama + doğum kaydı (eski) + yeni tohumlama (sonuç Bekliyor) → ovsync ekranında satır.
- **Adımlar:** RPC satırının `deneme_sayisi` alanını ve S2/S1 rozetini oku.
- **BEKLENEN — DB:** `deneme_sayisi` = son `dogum.tarih`'ten beri tohumlama sayısı (bu kurulumda 1).
- **BEKLENEN — Ekran:** rozet "1. deneme".
- **Ters kanıt:** ömür-boyu sayım (4) gösterilmedi.

### T-29 — Doğumsuz düve
- **Ref:** K13 · kabul 3 · §18.14
- **Katman:** DB-SQL
- **Adımlar:** hiç doğumu olmayan H (2 önceki tohumlamalı) satırını oku.
- **BEKLENEN — DB:** `deneme_sayisi` = ömür boyu tohumlama sayısı (2) — "son doğum yoksa ömür boyu".
- **Ters kanıt:** 0/boş değil.

### T-30 — `tohumlama.deneme_no` kolonuyla KARIŞMAZ
- **Ref:** §18.14 (kolon ömür boyu sayar), B8 · kabul 3
- **Katman:** DB-SQL + UI-Playwright
- **Ön koşul:** H: doğum + yeni tohumlama; kolon `deneme_no`=4 (ömür boyu) iken hesaplanan=1.
- **Adımlar:** RPC satırı + UI rozeti.
- **BEKLENEN:** gösterim 1 ("1. deneme"); RPC `deneme_sayisi=1`.
- **Ters kanıt:** `deneme_no` kolonunun ham değeri hiçbir yüzeye sızmıyor.

### T-31 — Rozet metni "N. deneme — önceki boş"
- **Ref:** §4 (deneme rozeti örneği) · kabul 3 · mockup 01 ("2. deneme (bu laktasyon)")
- **Katman:** İnsan-UI
- **Adımlar:** önceki sonucu Boş olan H'nin S1/S2 satırını incele.
- **BEKLENEN — Ekran:** "2. deneme — önceki boş" kalıbı (mockup 01'de "2. deneme (bu laktasyon)" — nihai metin planla kesinleşir, İNCELE).
- **Ters kanıt:** sayı, görsel olarak doğum öncesi denemeleri içermiyor.

---

## H. Takip ekranı — §4b matrisi HER satırı + bölüm kuralları (kapsam 8)

### T-32 — S0 BUGÜN & GECİKEN + boşsa gizli
- **Ref:** §3 (S0), §4b · kabul 3
- **Katman:** UI-Playwright + DB-SQL
- **Ön koşul:** bugün TAI'ı olan hayvan (S0 kart adayı) + gecikmiş günü olan hayvan; ikinci koşum: hiçbiri yok.
- **BEKLENEN — Ekran:** "Küpe X — TAI bugün SS:MM [▶]" canlı kart; geciken kart kırmızı; **ikinci koşumda S0 bölümü hiç render edilmiyor**.
- **Ters kanıt:** boş S0 başlığı/placeholder yok.

### T-33 — S3 pencere dışı: 🔒 + hedef tarih, aksiyon yok
- **Ref:** §4b satır 1 · kabul 3 · §18.3
- **Katman:** İnsan-UI + UI-Playwright
- **Ön koşul:** `OVSYNC_BASLAT` görevi hedefi bugün+8 (pencere = hedef−2 dışı).
- **BEKLENEN — Ekran:** satır "X · Düve · hedef GG.AA (N gün)" + 🔒 kilidi (mockup 06: "🔒 Başlat −2 gün penceresinde" / "🔒 kilitli"); ▶ Başlat YOK; bilgi satırı "N gün sonra başlatılabilir".
- **Ters kanıt:** Ertele/✕ gibi mevcut satır aksiyonları kalır ama Başlat çizilmez.

### T-34 — S3 pencere içinde (hedef−2): ▶ Başlat → S1
- **Ref:** §4b satır 2 · kabul 3, 10
- **Katman:** UI-Playwright + DB-SQL
- **Adımlar:** hedefi bugün+2 görevli H satırında ▶ Başlat (inline `ovsyncBaslat` → `start_first_service_protocol`).
- **BEKLENEN — DB:** vaka + 4 gün + TAI görevi (§6 w2 raporu deseni).
- **BEKLENEN — Ekran:** satır S1'e taşınır (listeler tazelenir); S3 sayısı azalır.
- **Ters kanıt:** ek onay modalsız inline; erken (pencere dışı) satırda buton yok (T-33 ile çift yönlü).

### T-35 — S1 gün vakti: amber + modal
- **Ref:** §4b satır 3 · kabul 3 · §4 (gün → `openCaseDet`)
- **Katman:** İnsan-UI + UI-Playwright
- **Ön koşul:** H'nin bugünü planlı ilaç günü (gecikme 0).
- **BEKLENEN — Ekran:** gün noktası **amber**; tarih görünür; satır altı "N/4 uygulandı · sıradaki: N+1. uygulama"; dokunuş → `openCaseDet` zaman çizelgesi modalı (`renderCaseTimeline`); PG doğrudan dokunuşu YOK (§18.8 — gün detayına düşer).
- **Ters kanıt:** gün satırından tek dokunuşla ilaç uygulama yok.

### T-36 — S1 gün gecikti: kırmızı + "+Ng", öne alınır, Ertele
- **Ref:** §4b satır 4 · kabul 3
- **Katman:** UI-Playwright
- **Ön koşul:** H'nin planlı günü bugün−N (gecikme N>0).
- **BEKLENEN — Ekran:** kırmızı "+Ng"; satır bölümde öne alınmış; inline Ertele + `openCaseDet` var.
- **Ters kanıt:** gecikmeli satır listede rastgele sırada değil.

### T-37 — S1 TAI günü: BUGÜN → openTaskDet → S2
- **Ref:** §4b satır 5 · kabul 3 · §4 (TAI → `openTaskDet` "Tohumlamayı Kaydet")
- **Katman:** UI-Playwright + DB-SQL
- **Adımlar:** TAI hedefi bugün olan H (S0 kartı da var) → [▶] → görev detayı → "Tohumlamayı Kaydet" (tohumlama kaydı).
- **BEKLENEN — DB:** `tohumlama` satırı (Bekliyor); TAI görevi tamamlandı; vaka kapanış kuralları (§18.6 senkron kapanış) işler.
- **BEKLENEN — Ekran:** satır S2'ye geçer ("Sonuç bekleyenler": küpe + TAI tarihi + sayaç + deneme rozeti).
- **Ters kanıt:** S1'de TAI'lı satır kalmıyor; S0 kartı düşüyor.

### T-38 — S2 muayeneye N gün: sayaç, aksiyon yok
- **Ref:** §4b satır 6, K2 · kabul 3
- **Katman:** UI-Playwright + DB-SQL
- **Ön koşul:** TAI bugün−10 (eşik 40 → kalan 30).
- **BEKLENEN — DB/UI:** "muayeneye 30 gün"; satırda aksiyon butonu yok (bilgi).
- **Ters kanıt:** "21. gün kontrol" ifadesi / 21'e dayalı sayaç YOK.

### T-39 — S2 muayene vakti (≥40 g) → birleşik muayene sonuç ekranı (v2 — K15)
- **Ref:** §4b satır 7, K2, **K15**, **S-9 kapandı (§10b: `kalan_gun <= 0` → "muayene vakti")**, **§10d #4** · kabul 3, 11 · §18.13
- **Katman:** UI-Playwright + DB-SQL
- **Ön koşul:** TAI bugün−40 (kalan 0 — **sınır tanımı kapandı: `kalan_gun <= 0`**).
- **Adımlar:** satır → **birleşik muayene sonuç ekranı** (K15 — "mevcut gebelik sonuç akışı" DEĞİL; `muayene_gorev_id`'ye bağlanır). a) **Gebe** b) **Boş** (→ devam seçici) c) **Muayeneyi ertele**. Açık görev yoksa (görev ertesi sabah cron'la gelir) satır **hayvan detayına** gider (§10d #2).
- **BEKLENEN — a):** `sonuc='Gebe'` (T-78 çekirdek yolu); satır **S4**'e taşınır (sonlanma rozeti + toh_sonuc=Gebe). b): devam seçici (§6c) → seçime göre S1/S3 (T-41). c): T-75.
- **Ters kanıt:** muayene vakti satırında ölü aksiyon yok; satırdan görev ZORLA doğmaz (§10d #2 — görev cron'undur); sayaç "vakti" metnine döner.

### T-40 — S4 sonlananlar: salt-okuma + pencere + katlanır
- **Ref:** §4b satır 8, §3 (S4), §5 (`p_sonlanan_gun` 60) · kabul 3
- **Katman:** UI-Playwright + DB-SQL
- **Ön koşul:** kapalı vakalar: 30/59/61 gün önce.
- **BEKLENEN — DB/UI:** RPC default'ta 30 ve 59 döner, 61 dönmez; bölüm katlanır (kapalı başlar); satır rozet (TOHUMLAMA/PG/IPTAL/ERKEN_KAPANIS/Eski) + `toh_sonuc`; dokunuş `openCaseDet` salt-okuma; `p_sonlanan_gun=90` çağrısında 61 döner.
- **Ters kanıt:** S4'te yazma aksiyonu (başlat/ertele/kaydet) yok.

### T-41 — Akış yerleşimi: Boş sonrası doğru bölüme düşer
- **Ref:** §6c.5 + mockup 07 · kabul 3, 11
- **Katman:** UI-Playwright
- **Adımlar:** üç dalı koş: Boş+Ovsync → S1; Boş+PG (uygun, TAI'lı) → S1; Boş+TAKIP → S3 "🔍 takipte"; sonuç girilen hayvan S2'den düşer.
- **BEKLENEN — Ekran:** mockup 07 haritası birebir; "Boş hayvan hiçbir bölümden düşmez".
- **Ters kanıt:** S2'de "yeni deneme bekliyor" satırı kalmıyor (spec'in açık v1 Mockup-farkı notu).

### T-42 — Dalga gruplama + tekil başlangıçlar
- **Ref:** §3 (dalga anahtarı) · kabul 3
- **Katman:** UI-Playwright + DB-SQL
- **Ön koşul:** 3 vaka aynı `OVSYNC_BASLAT.hedef_tarih` (dalga), 1 vaka görevsiz (elle; anahtar=`start_date`), 1 tekil görevli.
- **BEKLENEN — Ekran:** dalga grubu tek başlıkta (hedef→fiilen + hayvan sayısı + ortak sıradaki adım); görevsiz vakalar kendi anahtarında; tekil kalanlar "tekil başlangıçlar".
- **Ters kanıt:** gruplamada görevli/görevsiz karışmıyor; başlıkta hedef≠fiili sapma görünür (T-69 ile bağlanır).

---

## I. Muayene eşiği 40 — ayar tek kaynağı (kapsam 9)

### T-43 — Ayar değişince sayaç değişir
- **Ref:** K2, §5 (`esikler`), §7.10 · kabul 3, 2
- **Katman:** DB-SQL + UI-Playwright
- **Ön koşul:** demo `sessiz_tohumlama_muafiyet_gun=40`; TAI bugün−38 (kalan 2).
- **Adımlar:** 1) sayacı doğrula ("muayeneye 2 gün"; "muayene vakti" değil). 2) ayarı 35 yap (demo yazması — koşum turunda izinli). 3) ekranı tazele.
- **BEKLENEN — DB/UI:** `esikler.muayene_gun=35`; satır artık "muayene vakti" (kalan 0); muayene tarihi = TAI+35. 4) ayarı 40'a geri getir (temizlik).
- **Ters kanıt:** sayaç ayardan türemeden sabitse HATA.

### T-44 — 21 hiçbir yerde yok (v2 — §10d #1 ile GÜÇLENDİ)
- **Ref:** K2, §7.10 ("ekranda 21 g ya da başka sabit yok"), **§10d #1 (tek üretici cron ≥40 g)** · kabul 3
- **Katman:** DB-SQL (RPC) + UI-Playwright/kod taraması
- **Adımlar:** RPC çıktısında eşik yalnız `esikler`'den; UI katmanında `21` sabiti grep'i (JS test: eşik hesabı yapan modülde 21/40 hazır-değeri yok).
- **BEKLENEN:** eşik yalnız ayar kaynağından; JS'te muayene-günü sabiti yok; **üretim tarafında da 21/35 eşiği yok** — `tohumlama_kaydet`'in +21/+35 g görev üretimi KALDIRILMIŞ (P2c, T-80); 21 geçen katalog satırları yalnız ters-kanıt eşik-metnidir.
- **Ters kanıt:** "21. gün" metni/üretimi hiçbir yüzeyde görünmüyor (§18.13 iptal edilmiş karar + §10d #1).

### T-45 — Aynı eşik iki yüzeyde aynı — KÜME-TAM EŞİTLİK (v2 — D2)
- **Ref:** K2 ("dashboard 'gebelik muayenesi gerekenler' listesiyle aynı kaynak"), **D2 (§10e: S2 CTE `gebelik_muayene_listele` predicate'lerinin TAMAMINI taşır — 30 g tamamlanmış-cooldown dahil)**, **K15 küme-tam eşitlik** · kabul 3, 9
- **Katman:** DB-SQL
- **Adımlar:** prova verisi **cooldown'a giren** (son 30 g içinde tamamlanmış `GEBELIK-KONTROL-` görevi olan) **ve girmeyen** hayvanı birlikte taşır; `gebelik_muayene_listele` kümesi ile ovsync RPC S2 kümesi SQL'de tam karşılaştırılır (EXCEPT iki yönlü — fark=0).
- **BEKLENEN:** S2 satır kümesi ≡ gebelik-muayene listesi (iki yönlü fark boş; v2'deki "⊇/kesişim" hükmü küme-tam eşitliğe yükseldi); aynı tohumlama iki yüzeyde aynı kalan-gün.
- **Ters kanıt:** predicate setinden biri eksikse (ör. cooldown) iki yönlü fark boş çıkmaz; eşik değişiminde (T-43) iki yüzey AYNI anda kayar.

---

## J. Bayrak kapalı, offline, RPC hata (kapsam 10)

### T-46 — Bayrak kapalı: `{ok, bayrak_kapali}` + açık mesaj
- **Ref:** §5 ("sessiz boş liste YASAK"), R6 · kabul 2, 6 — **§6c davranışı → SPEC SORUSU S-5**
- **Katman:** DB-SQL + UI-Playwright
- **Ön koşul:** demo `ovsync_pg_kurallari_aktif=0` (koşum sonrası geri açılır).
- **Adımlar:** RPC çağır + sayfayı aç.
- **BEKLENEN — DB:** `{ok:true, bayrak_kapali:true}` (satırlar boş/verilmez).
- **BEKLENEN — Ekran:** bayrak-kapalı açık mesajı; **boş liste sessizce gösterilmez**.
- **Ters kanıt:** " hiç kayıt yok" yanıltıcı boş durumu yok.

### T-47 — Offline + önbellek var: bayat etiket
- **Ref:** §5 (R6), §6b · kabul 6
- **Katman:** UI-Playwright
- **Adımlar:** 1) online yükle (`__ovsyncTakip` dolu). 2) `context.setOffline(true)` 3) sayfayı/yeniden girişi dene.
- **BEKLENEN — Ekran:** bayat veri + **"çevrimdışı · HH:MM verisi"** etiketi.
- **Ters kanıt:** çevrimdışıyken sessiz taze-miş gibi davranış yok.

### T-48 — Offline + önbellek yok: açık mesaj
- **Ref:** §5 · kabul 6
- **Katman:** UI-Playwright
- **Adımlar:** önbelleksiz taze yüklemede offline.
- **BEKLENEN — Ekran:** **"İnternet yok — takip verisi alınamadı"**.
- **Ters kanıt:** boş kpa/satır render edilmedi.

### T-49 — RPC hata (500/timeout): offline yolu gibi
- **Ref:** §5 ("hata/offline → bayat önbellek + …") · kabul 6
- **Katman:** UI-Playwright (stub-backend hata enjeksiyonu)
- **BEKLENEN — Ekran:** T-47/T-48 davranışı (önbelleğe göre); hata toast'u veri yüzeyini ezmez.
- **Ters kanıt:** ham hata metni kullanıcıya sızmıyor (kullanıcı diline çevrilmiş).

### T-50 — Yazma akışları sonrası invalidate
- **Ref:** §5 ("invalidate listesi"), §6 · kabul 6, 10
- **Katman:** UI-Playwright
- **Adımlar:** sayfa açıkken: `ovsyncBaslat`, erteleme/kaydırma, tohumlama kaydı, Gebe/Boş atama, §6c RPC — her birinden sonra takip verisi tazelenmiş mi.
- **BEKLENEN:** her yazma sonrası `__ovsyncTakip=null` → yeniden yükle; ekran yeni durumu gösterir (özellikle: başka cihazta yapılmış gibi seed'lenmiş değişiklik değil, aynı oturumdaki yazma).
- **Ters kanıt:** bayat satır (kapanan vaka hâlâ "aktif" gibi) kalmıyor.

---

## K. Gezinme sözleşmesi §6b (kapsam 11)

### T-51 — Yatay geçiş; hub mecburiyeti yok
- **Ref:** §6b · kabul 8
- **Katman:** UI-Playwright
- **Adımlar:** Ana → Ovsync → Görevler → Ovsync (doğrudan, Ana'ya uğramadan).
- **BEKLENEN — Ekran:** her adım doğru yüzey; `goTo('ovsync')` pushState'e katılır (`navGeriKarar`).
- **Ters kanıt:** Ovsync↔Görevler geçişi Ana üzerinden zorlanmıyor.

### T-52 — Modal açıkken geri: yalnız modal kapanır
- **Ref:** §6b · kabul 8
- **Katman:** UI-Playwright
- **Adımlar:** Ovsync'te `openCaseDet` açıkken tarayıcı Geri.
- **BEKLENEN — Ekran:** modal kapanır, sayfa **yerinde tazelenir**; sayfa geçişi olmadı.
- **Ters kanıt:** geri = sayfadan çıkmak değil.

### T-53 — Kaydırma konumu korunur
- **Ref:** §6b (`_ovsyncScrollY`), R5 · kabul 8
- **Katman:** UI-Playwright
- **Adımlar:** uzun listede scroll → Görevler'e geç → Ovsync'e dön.
- **BEKLENEN — Ekran:** aynı kaydırma konumu; **veri taze** (her dönüşte yeniden yükleme).
- **Ters kanıt:** en üste sıfırlanma yok.

### T-54 — Padok filtresi korunur
- **Ref:** §6b (`_curOvsync*`) · kabul 8
- **Katman:** UI-Playwright
- **Adımlar:** filtre uygula → bölüm aç/kapa → ayrıl/dön.
- **BEKLENEN:** filtre ve bölüm açık/kapalı durumu korunur.
- **Ters kanıt:** dönüşte filtre sıfır değil.

### T-55 — ‹ = `history.back()`
- **Ref:** §6b, K11, R13 · kabul 8
- **Katman:** UI-Playwright
- **Adımlar:** Ana→Ovsync→Görevler akışından Ovsync'te ‹.
- **BEKLENEN — Ekran:** bir adım geri (geçmiş yığınından); `goTo('dash')` DEĞİL.
- **Ters kanıt:** ‹ her zaman Ana'ya atmıyor (yığın şişmiyor).

---

## L. Girişler + sayı tutarlılığı (kapsam 12)

### T-56 — Dashboard 6. stat hücresi + sınıf koşulları
- **Ref:** §6 (giriş butonu satırı), R4 · kabul 4
- **Katman:** UI-Playwright + DB-SQL
- **Adımlar:** üç durum kur ve sınıfı doğrula: a) S0>0 veya muayene vakti dolan>0 → `alert`; b) yalnız bekleyen-başlatma>0 → `warn`; c) sakin → `ok`. Hücre "🔄 Ovsync ›" + aktif zincir sayısı; tıkla → `goTo('ovsync')`; grid'de 6. hücre son satırı tamamlar (2 kolon).
- **BEKLENEN — Ekran:** üç koşumda üç sınıf; yönlendirme ovsync sayfası.
- **Ters kanıt:** sınıf eşikleri ters/Karışık değil (koşul sırası spec'inki).

### T-57 — İkincil giriş: 🔔 "Tüm takibi aç →" + Görevler köprüsü
- **Ref:** §6 (ikincil giriş, görevler köprüsü), K9/K10 · kabul 4
- **Katman:** UI-Playwright
- **BEKLENEN — Ekran:** 🔔 🌱 bölümünde "Tüm takibi aç →" ovsync sayfasına; Görevler başlığında "Tüm ovsync takibi →"; ovsync görevleri 🌱 Üreme çipinde (§18.16 — özel emoji opsiyonel, İNSAN-UI göz kararı).
- **Ters kanıt:** köprüler hub zorlamıyor.

### T-58 — Ovsync sayfası = 🔔 🌱 sayısı (aynı anda)
- **Ref:** §6 (sayı tutarlılığı), R2 · kabul 9
- **Katman:** UI-Playwright + DB-SQL
- **Adımlar:** aynı veri anında iki yüzeyin bekleyen-başlatma sayısını oku (tazeleme yarışını önle: önce 🔔 sonra ovsync, aynı pull).
- **BEKLENEN:** sayılar eşit; **Görevler roziti (IDB) ve çan roziti (iki RPC toplamı) için eşitlik iddiası YOK** — bunlar değişmedi (regresyon: iş onları bozmadı).
- **Ters kanıt:** ovsync sayfa sayısı 🔔'den farklıysa HATA.

### T-59 — KPA şerit tutarlılığı
- **Ref:** §3 (KPA şeridi), §5 · kabul 2, 3
- **Katman:** DB-SQL + UI-Playwright
- **Adımlar:** RPC `kpa` bloğunu (Aktif/Bugün/Geciken/Muayene bekleyen/Bekleyen başlatma) satır verisinden bağımsız yeniden hesapla (SQL) ve ekrandaki şeritle karşılaştır.
- **BEKLENEN:** beş sayı da üç yüzeyde (RPC / hesap / ekran) eşit. "Bekleyen başlatma" tanımı → SPEC SORUSU S-6 (takip dahil mi).
- **Ters kanıt:** ölü kayıt sayaçlara vuruyor mu — kapanan takip/vaka sonrası sayı düşüyor (canlılık; sessiz-varsayılan yasağı).

---

## M. Güvenlik (kapsam 13)

### T-60 — Anon/PUBLIC EXECUTE yok
- **Ref:** §5, §6c.2 ("anon/PUBLIC EXECUTE yok"), §18 REVOKE disiplini · kabul 2, 7
- **Katman:** DB-SQL (demo)
- **Adımlar:** iki RPC için `has_function_privilege('anon','…(…)','EXECUTE')` + `PUBLIC` kontrolü; `SET ROLE anon` ile çağrı denemesi.
- **BEKLENEN — DB:** ikisi de false/red; yalnız `authenticated` grant.
- **Ters kanıt:** default-privilege tuzağı (erteleme-turu dersi: REVOKE'a PUBLIC dahil) — yeni RPC'ler şablondan `TO anon` delmiyor.

### T-61 — farm_id disiplini: predikat/damga YOKLUĞUNUN kanıtı (v2 — §10c #13, D8/C6)
- **Ref:** domain §14, **§10c #13 (SAHİP: sistem tek-tenant; yalnız §14 uygulanır)**, **D8 ölçüm kararı (plan (f))**, **C6 (v5)** · kabul 2
- **Katman:** DB-SQL + kod taraması
- **Adımlar:** (1) `information_schema` ölçümü — P1/P2b'nin dokunduğu 16 tabloda (`tohumlama, hayvanlar, gorev_log, islem_log, stok, stok_hareket, uygulama_log, pg_application_event, cases, treatment_days, treatment_day_uygulamalar, protokol_ayar, protokol_instance, diseases, tedavi_sablonu, sablon_hastalik_eslem`) farm_id kolonu **yalnız `pg_application_event`'te** var [demo ölçümlü 2026-09-29]; (2) P1 CTE'lerinde ve `gorev_log` INSERT'lerinde farm_id predikatı/damgası **YOKLUĞUNUN** kanıtı (grep + gövde incelemesi); (3) `pg_application_event`'i okuyan tek yüzey (P2b `son_pg`) sorgusunda `farm_id = public.current_farm_id()` filtresinin VARLIĞININ kanıtı.
- **BEKLENEN:** kolon taşımayan 15 tabloya predikat/damga yazılmamış (§14: mevcut tabloya retrofit YOK); kolon taşıyan tek okumada filtre VAR.
- **Ters kanıt:** iki-farm negatif testi YOK (Faz 2'ye taşındı — §10c #13); kolonsuz tabloya predikat EKLENMİŞSE §14 ihlali (gereksiz retrofit).

### T-62 — RPC_TABLES disiplini
- **Ref:** §5 (salt-okuma invariant), R1 · kabul 7
- **Katman:** kod taraması (unit) + DB-SQL
- **Adımlar:** `RPC_TABLES` haritasında `ovsync_takip_listele` YOK; `tohumlama_bos_ve_devam` VAR (pull tablolarıyla); takip RPC'si `rpc()` doğrudan çağrıyla çalışıyor.
- **BEKLENEN:** salt-okuma RPC pull sistemine girmiyor (R1); yazma RPC giriyor (invalidate/pull zinciri).
- **Ters kanıt:** takip RPC'si tabloya eklenmişse R1 regresyonu.

---

## N. PROD kenar vakaları — demo replikasyonu (kapsam 14)

> PROD'a erişim yok (zarf kuralı). Aşağıdaki her senaryo PROD'taki anomalinin **demo'da eşdeğer seed'i** ile koşulur; kaynak: `db-ovsync-durum-raporu.md` A1–A10.

### T-63 — "Küpe 51" replika: TAI'sız, sebepsiz kapanmış vaka
- **Ref:** §4b S4, §7.4 (close_reason=NULL → "Eski/bilinmiyor"), §7.5 (toh_sonuc=bilinmiyor) · kabul 3
- **Katman:** DB-SQL + UI-Playwright
- **Seed:** vaka: 4 gün tamamlanmış, TAI görevi iptal, tohumlama YOK, `close_reason=NULL`, kapanmış.
- **BEKLENEN — DB/UI:** S4 satırı rozet **"Eski/bilinmiyor"**; `toh_sonuc='bilinmiyor'` (tahmin yok); gün noktaları tamam yeşil.
- **Ters kanıt:** "TOHUMLAMA ile kapandı" gibi uydurma rozet yok; sessiz satır-düşme yok.

### T-64 — "Küpe 19" replika: gelecek tarihli tamamlanmış günler + erken TAI
- **Ref:** §7.3 (`tutarsiz`), §4 (sapma rozetleri "erken Ng") · kabul 3
- **Katman:** DB-SQL + UI-Playwright
- **Seed:** gün2–4 `tamamlandi=true` ama `tamamlanma_tarihi` gelecek tarihli; tohumlama vaka başlangıç günü girilmiş (erken).
- **BEKLENEN — DB/UI:** o günler `tutarsiz` (⚠ veri tutarsız) — **`uygulanmadi` diye gösterilmez**; sapma rozeti "erken Ng" (hedef−fiili).
- **Ters kanıt:** ⚠ işaretsiz "tamam yeşil" görünümü HATA.

### T-65 — "Küpe 902" replika: aynı hayvanda kapalı (Gebe−) + aktif vaka
- **Ref:** §7.2 ("satırda yalnız aktif TAI"), §3 · kabul 3
- **Katman:** UI-Playwright + DB-SQL
- **Seed:** H: eski vaka kapalı (Boş sonuçlu tohumlama ile), yeni vaka aktif.
- **BEKLENEN — Ekran:** S1'de TEK satır (aktif); eski vaka S4'te ayrı satır; eski TAI/sonuç detayda.
- **Ters kanıt:** iki satır birleşmiş/çift aktif görünüm yok.

### T-66 — "Küpe 183" replika: sonuç girilmiş, vaka geç kapanmış
- **Ref:** §4b S4, K6 köprüsü, B7 kapsamı · kabul 3
- **Katman:** DB-SQL + UI-Playwright
- **Seed:** tohumlama sonucu Gebe (TAI+X gün); vaka sonuçtan 40 gün sonra kapanmış.
- **BEKLENEN — DB/UI:** S4'te `toh_sonuc='Gebe'` (K6: `hayvan_id` + TAI tarihi ∈ [start, kapanış+2g] eşleşmesi); sonlanma rozeti tutarlı.
- **Ters kanıt:** eşleşme penceresi dışında kalırsa `bilinmiyor` (kontrol varyantı: kapanış+2g dışı tohumlama).

### T-67 — "Küpe 197" replika: Boş + yeni deneme Bekliyor → S2 "2. deneme"
- **Ref:** §3 (S2), K13, mockup 01 (197 örnek karakteri) · kabul 3
- **Katman:** İnsan-UI + UI-Playwright + DB-SQL
- **Seed:** H: önceki tohumlama Boş (TAI 40+ gün önce), yeni tohumlama Bekliyor (kalan <40).
- **BEKLENEN — Ekran:** S2 satırı: küpe + TAI tarihi + "muayeneye N gün" + **"2. deneme"** rozeti (mockup 01: "2. deneme (bu laktasyon)").
- **Ters kanıt:** Boş geçmişi sayaca vurmuyorsa HATA (T-28 bağlantısı).

### T-68 — "Küpe 121" replika: Bekliyor tohumlama dururken yeni aktif vaka
- **Ref:** §7.2, §3 · kabul 3 (A4 anomalisi)
- **Katman:** UI-Playwright + DB-SQL
- **Seed:** H: 09-17 tarihli Bekliyor tohumlama + aktif vaka (açık TAI görevi).
- **BEKLENEN — Ekran:** S1 satırı aktif TAI'yı gösterir; eski Bekliyor tohumlama satırda değil, **detayda** ("iptal/geçmiş TAI detayda", §7.2).
- **Ters kanıt:** satırda iki TAI görünmüyor.

### T-69 — Dalga sapması replika (hedef 09-24 → fiilen 09-27, +3g)
- **Ref:** §3 (dalga başlığı), §4 (sapma rozeti "hedef GG.AA → fiilen GG.AA (+Ng)"), P2 · kabul 3 (A9)
- **Katman:** İnsan-UI + UI-Playwright
- **Seed:** dalga: görev hedef_tarih X, vaka start X+3 (kaydırma geçmişi `islem_log VAKA_KAYDIR` ile).
- **BEKLENEN — Ekran:** grup başlığı "hedef→fiilen"; satırda "+3g" kayma rozeti; veri bükeri görünür (P2: gizlenmez).
- **Ters kanıt:** sapma satırdan silinmiş/beyazlatılmış değil.

### T-70 — Çift bayrak (tamamlandi=true + iptal=true) + görevsiz/erken tohumlama etiketleri
- **Ref:** §7.1 ("(tamamlandi, iptal) ikilisiyle yorumlanır"), §4 ("görevsiz" rozeti) · kabul 3 (A5, A6)
- **Katman:** DB-SQL + UI-Playwright
- **Seed:** a) görev `tamamlandi=t, iptal=t` (PG devraldı deseni); b) TAI görevi iptalli + görevsiz girilmiş tohumlama; c) hedeften erken girilmiş tohumlama.
- **BEKLENEN — DB/UI:** a) satırda tek yorumlu durum (kapandı-dendi ama devralındı ayrımı ikiliden doğru); b) "görevsiz" rozeti; c) "erken Ng" rozeti.
- **Ters kanıt:** üç desen de aynı genel duruma çökmedi (ayrıştırılabilir).

### T-71 — "Test inek 3" kaos replika + test notu + tanınmayan yapı
- **Ref:** §7.7 (test notu), §7.8 (bilinmiyor), §18.7 (PG kapanışı) · kabul 3 (A3)
- **Katman:** DB-SQL + UI-Playwright
- **Seed:** H "Test X": vaka1 PG ile kapandı → vaka2 IPTAL → yeniden-başlat görevi iptalli → görevsiz tohumlama Bekliyor. Artı: bir vakada bozuk/bilinmeyen `protocol_snapshot` parçası.
- **BEKLENEN — DB/UI:** S4'te iki satır iki farklı rozet (PG, IPTAL); test hayvanı satırında "test" notu; bozuk yapıda satır hata vermez, alan **"bilinmiyor"** (sessiz varsayılan YASAK — burada bilinmiyor ETİKETİ basılır).
- **Ters kanıt:** bozuk snapshot tüm ekranı çökertmiyor; test notu kalıcı (B3 tamamlanana kadar not düzeyi).

---

## O. Eşzamanlılık (kapsam 15)

### T-72 — İki cihazdan aynı hayvana Boş — MK9 kilit sırası + tek kazanan (v2 — §10f/§10g)
- **Ref:** §6c.2 atomiklik + concurrency, **S-8 kapandı (§10b: `TOH_SONUCLU:{…}`, hiçbir yazma yok)**, **DEGISMEZ 13 (MK9-N: hayvan satırı İLK `FOR NO KEY UPDATE`)**, **H3 yön kuralı** · kabul 11
- **Katman:** UI-Playwright (iki context) + DB-SQL
- **Ön koşul:** iki oturum aynı Bekliyor tohumlamayı açık görüyor.
- **Adımlar:** A cihazı Boş+TAKIP kaydeder; B cihazı (bayat ekranla) aynı tohumlamaya Boş+Ovsync dener. DB katmanı: iki eşzamanlı oturum, kilit sırası provası — kazanan kilidi tutar, ikincisi bekler sonra **kapalı/sonuçlu durumu görür ve red alır**.
- **BEKLENEN — DB:** tek sonuç değişimi; diğer çağrı **`TOH_SONUCLU`** açık hatası; kaybedenden hiçbir yan yazma (vaka/görev/olay) yok. **Kilit dizisi:** sarmal hayvan NKU → tohumlama FU → (muayene yolunda) gorev_log FU; `start_first_service_protocol`'ün görev→hayvan ihlali düzeltilmiş (P3b) — eşzamanlı turda ikisi de hayvan muteksinden sonra kilitlenir, tek kazanan.
- **Ters kanıt:** çift deneme/çift görev doğmuyor; B'nin hatası sessiz başarı gibi görünmüyor; `p_onay=true` TOH_SONUCLU'yu aşmaz (onay yalnız TAKIP_ACIK içindir).

### T-73 — Takip kapanırken muayene sonucu girilmesi — sözleşme kapandı (v2 — S-8)
- **Ref:** §6c.3 yarış, **S-8 kapandı (§10b)**, **P2b hata sözleşmesi** · kabul 11
- **Katman:** DB-SQL (+UI iki context varyantı)
- **Ön koşul:** H'de açık takip; iki işlem sırayla: 1) PG uygulama onayı (TAKIP_ACIK evet) tamamlanmak üzere, 2) diğer cihaz muayene sonucu gönderiyor.
- **Adımlar:** kapandı-sonrası penceresinde muayene sonucu RPC'si girilir (takip artık kapalı).
- **BEKLENEN — DB:** tanımlı davranış — **açık red `TAKIP_KAPALI:{…}`** (takip görevi zaten kapalı; P2b sözleşmesi; H4'te kilitsiz keşif → yeniden doğrulama aynı red döndürür); kayıp/gözden düşen sonuç YOK; yarı-kapalı takip kalmıyor.
- **Ters kanıt:** ikinci yazma ilkini geri almıyor; çift kapanış yok (T-24 ile tamamlayıcı); sessiz başarı yok.

---

## P. K15/birleşik muayene senaryoları (kapsam 16 — KATALOG GÜNCELLEME 6, 9, 11)

### T-74 — Jenerik `gorev_tamamla` guard — ÜÇ DAL (v2 — K15 + §10h H6)
- **Ref:** §10c #5 (K15), **DEGISMEZ 11**, **§10h H6** · kabul 11
- **Katman:** DB-SQL (T-73 katmanı; REST jenerik çağrı dahil) + PW
- **Ön koşul:** fixture `GEBELIK_KONTROL` ve `TAKIP_MUAYENE` görevli hayvan (E2E- marker; demo).
- **Adımlar:** (dal 1) jenerik `gorev_tamamla(p_gorev_id)` — `p_iptal` boş/false — muayene tipli görevde → **`MUAYENE_SONUC_GEREKLI:{gorev_tipi}` RED**, görev açık kalır; (dal 2) **`p_iptal=true`** aynı görevde → **iptal BAŞARILI** (T5 sözleşmesi — js/ui.js:1841 ilk-tohumlama iptali korunur); (dal 3) `SUTTEN_KESME`/padok tipli fixture görevin tamamlaması → **mevcut davranış** (kapanış + padok transferi), guard DOKUNMAZ.
- **BEKLENEN — DB:** üç dal davranışı ayrışır; guard yalnız tamamlama dalında ve yalnız iki muayene tipinde; kilit sırası değişmez (guard tipi ilk erişimden önce kilitsiz okur).
- **Ters kanıt:** dal 1'de görev sonuçsuz kapanmadı (sessiz kapanış = HATA); dal 2'de iptal guard'a takılmadı; dal 3'te mevcut akış bozulmadı.

### T-75 — GEBELIK_KONTROL erteleme yolu (birleşik ekrandan; saatsiz varsayılan)
- **Ref:** §10c #5, **§10d #3**, §18.17 · kabul 11
- **Katman:** UI-Playwright + DB-SQL
- **Ön koşul:** H'de açık `GEBELIK_KONTROL` (T-79/T-80 kurulumu).
- **Adımlar:** birleşik muayene ekranı → "Muayeneyi ertele" → +7 ön ayar, saat alanı boş → onayla. Varyant: saat girilir.
- **BEKLENEN — DB:** `hedef_tarih=bugün+7`; **`p_saat` girilmediyse `hedef_saat` NULL** (SAATSİZ — iki görev tipinde de); görev açık kalır (kapanış yok, UPDATE); zincir sürer; `ERTALE` seçimi sarmal muayene kolundan; genel "ertele" butonu bu tiplerde YOK (§10d #3).
- **Ters kanıt:** yeni görev INSERT değil; eski atama saati ön ayar olarak gelmiyor (S-2 eski hali geçersiz).

### T-76 — İki görev tipi ekran özdeşliği (GEBELIK_KONTROL ≡ TAKIP_MUAYENE; S-10 copy)
- **Ref:** K15, **§18.17**, **S-10 kapandı (§10c copy)** · kabul 11
- **Katman:** İnsan-UI + UI-Playwright
- **Adımlar:** aynı ekranı iki tip görevle aç: `GEBELIK_KONTROL` (cron görevli) ve `TAKIP_MUAYENE` (takip görevli) → DOM yapısını/kart setini karşılaştır.
- **BEKLENEN — Ekran:** AYNI sonuç ekranı — Gebe / Boş→devam seçici / Muayeneyi ertele; tek fark başlık bağlamı (takip N. gün / TAI+40 g); **"Muayene tamam + …" etiketleri** ("Boş ata" öneki hiçbir varyantta yok).
- **Ters kanıt:** tip bazlı ayrı ekran/sarıcı yok; mockup 05 literal "Boş ata + …" copy'si KULLANILMAZ (§10c copy satırı).

### T-77 — Takip muayenesinde Gebe (Boş→Gebe düzeltmesi, GEBE_BULUNDU)
- **Ref:** S-3, §10e D1/D1-UI, **§18.15 (sahip 2026-09-29)** · kabul 11
- **Katman:** DB-SQL + UI-Playwright
- **Ön koşul:** H'de son tohumlama `sonuc='Boş'` + buna bağlı AÇIK `TAKIP_MUAYENE` (`kaynak='TAKIP:'||toh_id`); muayene günü gelmiş.
- **Adımlar:** sarmal muayene kolundan `p_secim='GEBE'`.
- **BEKLENEN — DB:** önceki Boş **hatalı** sayılır: `tohumlama.sonuc='Gebe'` + `hayvanlar.tohumlama_durumu='Gebe'`; görev `tamamlandi=true` + `takip_kapanis_nedeni='GEBE_BULUNDU'`; `islem_log GEBE_ATAMA` snapshot'ında `bos_duzeltme:{eski_sonuc:'Boş', bos_atama_tarihi, takip_kapanis:'GEBE_BULUNDU'}`; Boş'un `TOHUMLAMA_SONUC` izi DOKUNULMAZ (geri_alindi işaretlenmez); açık `GEBELIK_KONTROL/TOHUMLAMA_HAZIRLIK` iptalleri geri ALINMAZ (yan-etki tablosu — T-83).
- **BEKLENEN — Ekran:** üreme geçmişinde iki satır (T-84); tahmini doğum Gebe'den.
- **Ters kanıt:** **genel `tohumlama_sonuc_gebe` RPC'si Boş tohumlamayı hâlâ REDDER** (Bekliyor-only; çekirdek genişlemesi sızıntı değil); çekirdeğe REST'ten doğrudan çağrı red (authenticated EXECUTE yok — yalnız sarmal).

### T-78 — Gebelik kontrolünde Gebe (Bekliyor tohumlama → çekirdek `p_bos_duzeltme=false` yolu)
- **Ref:** §10c #5, §10e D1, §18.17 · kabul 11
- **Katman:** DB-SQL + UI-Playwright
- **Ön koşul:** H'de son tohumlama `sonuc='Bekliyor'` (≥40 g) + açık `GEBELIK_KONTROL`.
- **Adımlar:** birleşik ekran → Gebe.
- **BEKLENEN — DB:** görev önce tamamlanır; çekirdek `p_bos_duzeltme=false` ile mevcut `tohumlama_sonuc_gebe` yan etkileri (sonuc Gebe + acik GEBELIK_KONTROL/TOHUMLAMA_HAZIRLIK/TOHUMLAMA_PLANLI iptali + `islem_log GEBE_ATAMA`, `bos_duzeltme` bloğu YOK).
- **Ters kanıt:** Boş'tan Gebe'ye çevrim yok (yanlış hayvanda düzeltme modu açılmıyor); davranış bugünkü Gebe atamasıyla bitişik.

### T-79 — Cron entegrasyonu: `gebelik_muayene_gorev_uret` ≥40 g görevi + S2 aynı küme
- **Ref:** §10d #1, §18.13, K15, D2 · kabul 3, 11
- **Katman:** DB-SQL + PW
- **Adımlar:** eşik dolmuş (son tohumlama ≥40 g) Bekliyor hayvanla `gebelik_muayene_gorev_uret(false)` çağır → `GEBELIK_KONTROL` görevi (`kaynak='GEBELIK-KONTROL-'||toh_id`, `ref_tohumlama_id`) doğar; `ovsync_takip_listele` S2 satırı ile karşılaştır (T-45).
- **BEKLENEN — DB/UI:** görev doğar; `NOT EXISTS` açık-görev koşuluyla tekrar çağrı çift görev ÜRETMEZ; S2 satırındaki `muayene_gorev_id` bu görevin id'si; dashboard 40 g satırı bu görevi açar (T-82).
- **Ters kanıt:** cron iki kez → tek görev; `gebelik_muayene_listele` predicate'leri dışındaki hayvanda görev/satır yok (cooldown dahil — T-45).

### T-80 — Tek üretici: yeni tohumlama sonrası GEBELIK_KONTROL DOĞMAZ (P2c; §10d #1)
- **Ref:** §10d #1, §18.13, plan P2c · kabul 11
- **Katman:** DB-SQL
- **Adımlar:** fixture hayvana yeni tohumlama kaydı gir (herhangi yol) → `gorev_log`'da o hayvanın `GEBELIK_KONTROL` satırlarını say.
- **BEKLENEN — DB:** **0 yeni görev** (+21/+35 üretimi kaldırıldı); `protokol_instance` UREME/TOHUMLAMA kaydı KURULUR (bağ kopmaz); eşik dolduğunda görevi yalnız cron kurar (T-79).
- **Ters kanıt:** tohumlama sonrası anında GEBELIK_KONTROL belirdiyse HATA (eski üretici hortladı); eşik dolmamışken cron görevi yok.

### T-81 — Temizlik sonrası çift görev yok (P2d; SAY→iptal→cron tek görev)
- **Ref:** §10d #1, plan P2d · kabul 11
- **Katman:** DB-SQL
- **Adımlar:** (1) SAY: `gorev_tipi='GEBELIK_KONTROL' AND NOT tamamlandi AND NOT iptal AND kaynak LIKE 'TOH-%'` adet+eşik dağılımı çıktısı DONE'a; (2) iptal (iz: `islem_log GOREV_GUNCELLENDI`, snapshot adet+ölçüt); (3) eşik dolmuş temizlenen hayvana cron → görev say.
- **BEKLENEN — DB:** temizlik sonrası açık +21/+35 görevi 0; cron **TEK** görev doğurur (her hayvanda açık GEBELIK_KONTROL ≤1); ikinci koşum 0 satır (idempotent).
- **Ters kanıt:** cron göreviyle +21/+35 görevi aynı hayvanda aynı anda açık kalmıyor (çift görev = HATA); PROD apply ayrı sahip kapısı (demo provası).

### T-82 — Dashboard 40 g satırı: açık görev → birleşik ekran; yoksa hayvan detayı (§10d #4)
- **Ref:** §10d #2/#4, §18.17, K15 · kabul 3
- **Katman:** UI-Playwright
- **Adımlar:** a) `acik_gorev_var=true` satıra tıkla → IDB'den açık `GEBELIK_KONTROL` bulunup **birleşik muayene ekranı** açılır; b) `acik_gorev_var=false` satıra tıkla → **hayvan detayı**.
- **BEKLENEN — Ekran:** a) muayene ekranı (`_muayeneSonucAc`); b) hayvan detay sayfası — satırdan görev DOĞMAZ (ertesi sabah cron'la gelir, §10d #2).
- **Ters kanıt:** b dalında görev oluşturma/sonuç ekranı yok; a dalında görev bulunamazsa sessiz boş ekran değil — hayvan detayına düşer.

## R. Plan v4–v7 hizalama senaryoları (kapsam 17 — KATALOG GÜNCELLEME 14–17)

### T-83 — D1 geri-alınma kanıtı (yan-etki tablosu satır satır)
- **Ref:** §10e D1, plan P2b yan-etki tablosu · kabul 11
- **Katman:** DB-SQL
- **Adımlar:** T-77 koşumunun ardından satır satır sorgula: (1) `tohumlama.sonuc` ve `hayvanlar.tohumlama_durumu` → `'Gebe'` (geri döndü); (2) Boş anındaki `GEBELIK_KONTROL/TOHUMLAMA_HAZIRLIK` iptalleri → **hâlâ iptal** (geri alınmaz); (3) Boş'un `islem_log TOHUMLAMA_SONUC` izi → durur, `geri_alindi` DEĞİL; (4) `PERFORM _acik_disi_gorev_kur` ürünü → Boş+TAKIP yolunda hiç doğmamıştır ((i)) → geri alınacak şey yok; (5) genel `tohumlama_sonuc_gebe(boş tohumlama)` → mevcut mesajla red.
- **BEKLENEN — DB:** beş satırın beşi de tabloyla birebir; SQL sorgu çıktısı provaya eklenir.
- **Ters kanıt:** iptal geri alma / iz silme / genel RPC'nin Boş'u kabul etmesi → HATA.

### T-84 — D1-UI iki satır: üstü çizili Boş + Gebe (üreme geçmişinde; C1 çözücü)
- **Ref:** §10e D1-UI (sahip: iki satır), plan kalem 11, §18.15 · kabul 3
- **Katman:** UI-Playwright + UNIT (C1 çözücü — T-88)
- **Adımlar:** T-77 sonrası hayvan kartı üreme geçmişini aç.
- **BEKLENEN — Ekran:** aynı tohumlama altında **iki satır**: üstü çizili `❌ Boş (bos_atama_tarihi)` + altında `✅ Gebe (takip muayenesi tarihi)`; tahmini doğum Gebe satırından; `bos_atama_tarihi` C1 normatif çözücüden (`islem_log` TOHUMLAMA_SONUC + `iptal_sebep='bos'`, `geri_alindi` dışlanır, `ORDER BY tarih DESC, id DESC`, Europe/Istanbul yerel gün); iz bulunamazsa Boş satırında tarih gizli (sessiz varsayılan değil).
- **Ters kanıt:** tek satıra çökme; `fmtTarih` ilk-10-karakter kesimiyle hesap (UTC kayması); tarih uydurma.

### T-85 — Göreli gün etiketi: "bugün"/"dün"/"N gün önce" (kalem 12)
- **Ref:** §10e UI-R1 (sahip isteği), plan kalem 12 · kabul 3
- **Katman:** UNIT (`gunFarkiEtiket`) + PW
- **Adımlar:** üreme/tohumlama geçmişi satırlarında tarih yanındaki göreli gün: sabit `+03:00` çapa (Europe/Istanbul, yaz saati kayması sabitlenerek kilitlenir); sınır caseleri 23:30 / 00:30 (UTC gece yarısı).
- **BEKLENEN:** 0 → "bugün", 1 → "dün", N → "N gün önce"; UTC 21:30 kaydı İstanbul'da ertesi güne düşer → yerel takvim günü esastır.
- **Ters kanıt:** saat-cinsinden fark; UTC kaymasına düşen yanlış gün; negatif/future gösterim.

### T-86 — D4: üç PG yolunda birleşik preflight + bulk satır-seçimli onay
- **Ref:** plan P3b D4, §10c #4, §18.8 · kabul 11
- **Katman:** DB-SQL + PW
- **Ön koşul:** fixture takipli hayvan; üç yol ayrı koşum: `hizli_uygulama` / `seans_tamamla` / `bulk_ilac` (karışık liste: takipli + takipsiz).
- **Adımlar:** her yolda yazma öncesi `TAKIP_ACIK` preflight (onaysız) → red; `p_pg_onay=true, p_takip_onay=true` TEK çağrıda → uygulanır; bulk'ta satır-bazlı karar listesi `{hayvan_id, pg_kapi_karar, takip_acik, takip_bilgi}`.
- **BEKLENEN — DB:** preflight İLK YAZMADAN önce: onaysız redde `uygulama_log`/`islem_log`/`pg_application_event` satırı DÜŞMEZ; onaylı takipte `_takip_kapat(neden=PG)` + uygulama tek işlemde; birleşik payload `PG_KAPI:TAKIP_ACIK:{...}` (iki gerekçe alt alta — S-4).
- **Ters kanıt:** tetikleyiciye (ilk yazmadan sonra) bırakılmış takip kontrolü yok; çift onay penceresi yok; bulk'ta onaysız satır işlenmedi (T-93).

### T-87 — T-72b çapraz deadlock provası — v7 SONUÇ ORACLE'I (final 5 çift)
- **Ref:** §10f C3, **§10h H7 (v7)**, plan P2b/P3b T-72b · kabul 11
- **Katman:** DB-SQL — betik `tests/concurrency/ovsync-takip-t72b.mjs` (demo DB)
- **Adımlar:** sabit 5 çift: (1) sarmal `tohumlama_bos_ve_devam` × `tohumlama_kaydet`; (2) sarmal × `start_first_service_protocol` (düzeltilmiş gövde); (3) sarmal × `seans_tamamla`; (4) sarmal × `vaka_toplu_ac`; (5) kapanış tetikleyicisi (tohumlama INSERT yolu) × sarmal. Her çift: iki gerçek DB bağlantısı, **N=30 eşzamanlı tur**, her bağlantıda `SET lock_timeout='5s'`.
- **BEKLENEN (oracle):** PASS = (a) hiçbir turda SQLSTATE `40P01`/`55P03` yok; (b) her turun sonucu çift başına İZİNLİ sonlu kümede (başarı ya da belgelenmiş iş hatası — `TOH_SONUCLU`, `TAKIP_ACIK`, `TAKIP_KAPALI`, `GIRIS_CIFT_ANLAMLI`, `OVSYNC_ERKEN`, `VWP_VIOLATION` vb.); **bilinmeyen kod/timeout asla PASS değil; "önce kırmızı" şartı YOK**.
- **Ters kanıt:** eski-yol çiftleri (`tohumlama_sonuc_bos` × sarmal vb.) prova DIŞI — B9 (H2); grafik çiftleri bilgi amaçlı.
- **Açık sözleşme (fail-closed):** çift 3'ün seans fixture'ı ve H5 satır-sonucu JSON alanı kaynakla kapanamadıysa betik o çifti `BLOKE` işaretler (bkz. `test-uygulanabilir-DONE.md`).

### T-88 — C1 çözücü üç vaka (bos_atama_tarihi normatif çözücü)
- **Ref:** §10f C1, plan P2b/P9b/P11 · kabul 11
- **Katman:** UNIT
- **Adımlar:** `islem_log` iz çözücü testi: (a) `durum='geri_alindi'` kayıt DIŞLANIR; (b) çoklu kayıtta `ORDER BY tarih DESC, id DESC` EN SON kazanır; (c) `tarih='2026-05-01T21:30:00Z'` → Istanbul yerel takvim günü **2 Mayıs** (ilk-10-karakter kesimi 1 Mayıs üretir — yanlışlık kilitlenir); iz yoksa `NULL` + UI tarih gizler.
- **BEKLENEN:** üç vaka çözücüyle doğru; `fmtTarih` kesimi kullanılmıyor.
- **Ters kanıt:** geri-alınmış izin sayılması; eski kaydın kazanması; UTC günü.

### T-89 — `kizginlik_vaka_ac` TAKIP_ACIK onay provası (kızgınlık sorun vaka yolu)
- **Ref:** §10f C4, plan P3b/P10 · kabul 11
- **Katman:** PW + DB-SQL
- **Adımlar:** takipli hayvanda sorun-vaka ekranından vaka aç → sunucu `TAKIP_ACIK:{...}` → UI kendi onay sheet'i ("tarayıcı confirm() DEĞİL") → Evet → `p_takip_onay=true`.
- **BEKLENEN — DB/UI:** onaysız: red + `cases`'e satır düşmez; onaylı: aynı tx'de takip `OVSYNC` nedeniyle kapanır + vaka açılır; sheet'te küpe + muayene tarih/saat metni.
- **Ters kanıt:** `confirm()` kullanımı; onaysız yazma; düz hata toast'u (§18.8 ruhu).

### T-90 — C5 PostgREST negatif: eski imza → `PGRST202`/HTTP 404 + anon ACL (AYRI assertion'lar)
- **Ref:** §10f C5, **§10g C5 (v6 beklenti düzeltmesi: 202 YANLIŞTI → `PGRST202`/404)**, plan P3b/T-73b · kabul 2, 7
- **Katman:** DB-SQL (REST probe) + kod taraması
- **Adımlar:** imzası değişen HER RPC için: (1) **eski parametre setiyle REST çağrısı** → `PGRST202` + HTTP 404 — **test önce demo'da gerçek yanıtı KAYDEDER, assertion o kayda sabitlenir** (gövde metni PostgREST sürümüyle değişebilir); (2) **yeni imza çalışır** (ayrı assertion); (3) **`anon` EXECUTE yok** (ayrı assertion — `has_function_privilege` + anon REST 42501).
- **BEKLENEN — ölçülmüş zemin (demo 2026-09-29):** olmayan/yeni-param çağrısı bugün dahi `HTTP 404 + PGRST202 "Could not find the function ... in the schema cache"` döner [OBSERVED]; `kizginlik_vaka_ac` anon=false/authenticated=true [OBSERVED]; anon REST → `HTTP 401 + 42501 permission denied` [OBSERVED]. Eski-imza red'i C5 DROP'larından SONRA yeşile döner — bugün eski imza canlı olduğundan bu assertion **RED (beklenen)**.
- **Ters kanıt:** `PGRST204` beklentisi (v5'in yanlış hali) kullanılmıyor; üç assertion tek tek doğrulanıyor (birleşik değil).

### T-91 — C6 farm_id envanter ölçümü (16 tablo; `son_pg` filtresi)
- **Ref:** §10f C6, plan (f) v5 ölçümü · kabul 2
- **Katman:** DB-SQL (demo `information_schema`, salt-okuma)
- **Adımlar:** 16 tablo listesi üzerinden `farm_id` kolon taraması → yalnız `pg_application_event` taşır; P2b dry-run `son_pg` sorgusunda `farm_id = public.current_farm_id()` filtresi varlığı (gövde incelemesi); erişim index `(farm_id, hayvan_id, occurred_at DESC)`.
- **BEKLENEN:** envanter taze ölçümle birebir; P1'e filtre maddesi DÜŞMEZ (P1 `pg_application_event` okumaz).
- **Ters kanıt:** kolonsuz tabloya predikat yazılması; filtresiz `pg_application_event` okuması.

### T-92 — C4 DB negatif: `kizginlik_vaka_ac` sunucu kapısı TANIDAN BAĞIMSIZ
- **Ref:** §10f C4, **§10g C4 (fail-closed, tanıdan bağımsız)**, §10h H4 · kabul 11
- **Katman:** DB-SQL (authenticated REST)
- **Adımlar:** fixture takipli hayvanla **iki tanı varyantı**: a) '💊 PG Protokolü' (Ovsync sınıfı) b) '+ Serbest Giriş' keyfi tanı (Ovsync-DIŞI) — her ikisinde de `p_takip_onay=false` authenticated REST çağrısı; sonra onaylı çağrı (ayrı koşum).
- **BEKLENEN — DB:** her iki varyantta da onaysız → **`TAKIP_ACIK:{muayene_tarihi, muayene_saat}`** red + `cases` satır düşmez; onaylı → aynı tx `_takip_kapat(neden='OVSYNC')` + vaka açılır. Kapı H4 deseniyle (kilitsiz keşif → hayvan NKU → yeniden doğrulama) yazılır; mevcut `KIZGINLIK_YOK`/çakışma redleri aynen.
- **Ters kanıt:** tanıya bağlı kapı dalı yok (keyfi tanı kaçmıyor — v4 dışlaması çürütüldü); onaysız vaka INSERT'i.

### T-93 — H5 satır-sonucu provası: bulk karışık listede onaysız açık-takipli satır işlenmez + `TAKIP_ACIK`
- **Ref:** **§10h H5**, plan P3b C2/H5 · kabul 11
- **Katman:** DB-SQL + PW
- **Ön koşul:** `bulk_ilac`/`vaka_toplu_ac` karışık `p_animal_ids`: takipli (onay listesi DIŞI) + takipsiz + takipli-onaylı.
- **Adımlar:** çağrı → satır satır sonuç incele; retry = **onaylı alt kümeyle YENİ çağrı** (`p_animal_ids` = onaylananlar; `p_takip_onaylar`/`p_pg_onaylar` alt küme dışı id içeremez → `TAKIP_ONAY_KUME_UYUMSUZ`).
- **BEKLENEN — DB:** onaysız açık-takipli satır **İŞLENMEZ** ve satır sonucu `TAKIP_ACIK` (PG bulk `p_pg_onaylar` deseni); onaylılar için `_takip_kapat` satır işlenmeden hemen önce; mevcut döngü/kilit davranışı değişmez; boyut sınırı YOK.
- **Ters kanıt:** onaysız satırın yazması (uygulama/cases); retry'ın onaysızları yeniden denemesi.
- **Açık sözleşme:** `TAKIP_ACIK` satırının KESİN JSON alanı her iki RPC'de makine-okunur sözleşmeyle P3b'de sabitlenecek (rereview5 ÖNEMLİ #2 — mevcut dönüş anahtarları farklı: `vaka_toplu_ac` `{ok,toplam,basari,atlanan,hatalar,acilan}` [20260906120000:735-738]); betik bugün alan adını varsaymaz — "satır işlenmedi" koşulunu satırın `acilan`/başarı listelerinde OLMAMASIYLA sınar, alan adı sabitlenince daraltılır.

### T-94 — H8 istemci çakışma mesajı: 40P01/55P03 → sabit metin, otomatik retry yok
- **Ref:** **§10h H8**, plan P4/P11 · kabul 6
- **Katman:** UNIT + PW (hata enjeksiyonu)
- **Adımlar:** `rpc()` hata dalına `error.code='40P01'`/`'55P03'` enjekte → kullanıcı mesajı `İşlem başka bir kayıtla çakıştı, tekrar deneyin` (sabit); mock rpc çağrı sayısı = 1.
- **BEKLENEN:** iki kodda da aynı mesaj; **otomatik yeniden deneme çağrısı TETİKLENMEZ**; diğer kodlar mevcut `_trErr` akışında.
- **Ters kanıt:** ham SQLSTATE/sunucu mesajı sızmıyor; sessiz retry yok.

## S. Sarmal RPC + tetikleyici sözleşme guard'ları (kapsam-açık denetimi 2026-09-30)

Planın açık davranış maddeleri olup v2 kataloğunda sınanmayan kaplama açıkları (denetim raporu: `runs/2026-09-28-ovsync-takip/katalog-kapsam-DONE.md`). Beklenen sonuçlar plan gövde maddelerinden (P2b/P3a) birebir türetildi; uydurma davranış yok.

### T-95 — Sarmal seçim tablosu guard'ı: TAKIP_MUAYENE'de TAKIP red + tablo-dışı seçim red (P2b seçim uzayı)
- **Ref:** plan P2b "Secim uzayi (#3/K15 + D3 — gorev tipine bagli ACIK TABLO)", §18.17 · kabul 11
- **Katman:** DB-SQL + UNIT (P11 senkron)
- **Ön koşul:** (a) `muayene_gorev_id`'si `GEBELIK_KONTROL` tipli açık görev olan H; (b) `TAKIP_MUAYENE` tipli açık görev olan H; boş-sonuçlanmış tohumlama bağlamı T-01/T-05 kurulumuyla.
- **Adımlar:** 1) GEBELIK_KONTROL göreviyle sarmal muayene yolu `p_secim='TAKIP'` → 2) TAKIP_MUAYENE göreviyle `p_secim='TAKIP'` → 3) her iki görev tipiyle tablo dışı değer `p_secim='DIGER'`.
- **BEKLENEN — DB:** 1) **kabul** — GEBELIK_KONTROL setinde TAKIP geçerli (muayene sonrası yeni takip kurulabilir); 2) **red `TAKIP_YENIDEN_SECILEMEZ`** — takip zinciri zaten takiptir; görev sonucu girilmemiş, hiçbir yazma yok; 3) **red `SECIM_TANIMSIZ:{secim,gorev_tipi}`** — sessiz varsayılan YOK. UNIT: `_muayeneSecimleri(gorevTipi)` çıktısı DB CASE tablosuyla birebir (GEBELIK_KONTROL: GEBE/OVSYNC/PG/TAKIP/ERTALE; TAKIP_MUAYENE: GEBE/OVSYNC/PG/ERTALE).
- **Ters kanıt:** TAKIP_MUAYENE'den TAKIP seçimiyle ikinci takip zinciri doğmuyor; tablo-dışı seçim sessizce OVSYNC'e/varsayılana çökmüyor; UI seçici seti DB tablosundan ayrışmıyor.

### T-96 — Sarmal giriş kimliği guard'ları: XOR (`GIRIS_CIFT_ANLAMLI`) + muayene-tip (`MUAYENE_GOREV_TIPI_UYUMSUZ`)
- **Ref:** plan P2b "XOR guard (#9)" · kabul 11
- **Katman:** DB-SQL
- **Ön koşul:** açık TAKIP_MUAYENE görevi + Bekliyor tohumlaması olan H; guard provası için `SUTTEN_KESME` tipli bir görev id'si.
- **Adımlar:** 1) hem `p_tohumlama_id` hem `p_muayene_gorev_id` dolu çağrı; 2) ikisi birden boş çağrı; 3) `p_muayene_gorev_id`'ye muayene tipi OLMAYAN (SUTTEN_KESME) görev id'si verilmiş çağrı.
- **BEKLENEN — DB:** üç çağrı da red: 1-2) **`GIRIS_CIFT_ANLAMLI`** (ikisi birden dolu da, ikisi birden boş da red — XOR); 3) **`MUAYENE_GOREV_TIPI_UYUMSUZ`**; her üçünde hiçbir yazma yok (`tohumlama.sonuc`, `gorev_log`, `cases` değişmez). `GIRIS_CIFT_ANLAMLI` T-87 oracle izinli iş-hatası kümesinde de geçerli kalır.
- **Ters kanıt:** kimlik-belirsiz çağrıda sessiz default'a (ör. tohumlama yoluyla devam) düşme yok; muayene-olmayan görev id'siyle Boş/Gebe işlemi yapılmıyor.

### T-97 — Bayrak kapalıyken sarmal YAZMA modları → `OZELLIK_KAPALI` (hiçbir yazma yok)
- **Ref:** plan P2b "Bayrak kapali (#6 + §10g MK9-K)", §10b S-5 · kabul 2, 6
- **Katman:** DB-SQL
- **Ön koşul:** H'de geçerli Boş-yolu tohumlaması (`sonuc='Bekliyor'`) → sarmala TAM `p_tohumlama_id` verilir (kimlik XOR'unu geçmek için — review ÖNEMLİ #1 düzeltmesi); demo `ovsync_pg_kurallari_aktif=0` (koşum sonrası geri açılır; T-46 ile aynı seed).
- **Adımlar:** 1) sarmal dry-run (`p_secim=NULL`, aynı `p_tohumlama_id`); 2) üç yazma modu ayrı ayrı: `p_secim='OVSYNC'`, `'PG'`, `'TAKIP'` (hepsi aynı tam `p_tohumlama_id` ile).
- **BEKLENEN — DB:** 1) dry-run `{bayrak_kapali:true}` — yan etki YOK; 2) üç yazma modu da **`RAISE 'OZELLIK_KAPALI'`** — tohumlama `sonuc='Bekliyor'` kalır, takip görevi/vaka/olay doğmaz; devam seçici ekranı açılmaz (S-5 — T-46'nın YAZMA dalı; T-46 yalnız okuma yolu + ekrandır). Tam `p_tohumlama_id` ile kimlik XOR'u geçer; red bayrak kapısından gelir (`GIRIS_CIFT_ANLAMLI` beklenmez).
- **Ters kanıt:** bayrak kapalıyken herhangi bir modda yazma gerçekleşmesi HATA; sessiz boş-davranış (RAISE'siz normal dönüş) yok.

### T-98 — `BOS_DUZELTME_KOSUL`: Boş-düzeltme koşul seti sağlanmazsa red
- **Ref:** plan P2b "`p_bos_duzeltme=true` kosul seti (HEPSI zorunlu; biri bile degilse `RAISE 'BOS_DUZELTME_KOSUL:{eksik...}'`)" · kabul 11
- **Katman:** DB-SQL
- **Ön koşul:** planın 5 koşulundan birinin bilinçli KIRILDIĞI üç fixture: (a) muayene görevi TAKIP_MUAYENE değil (GEBELIK_KONTROL) + hedef tohumlama `sonuc='Boş'`; (b) hedef tohumlama hayvanın SON tohumlaması değil — üstüne `treatment_date` ile KESİN daha yeni kayıt (eşitlikte `created_at` belirler; deterministik sıra — review ÖNEMLİ #2 düzeltmesi); (c) o tohumlamaya bağlı AÇIK takip zinciri yok (görev kapalı).
- **Adımlar:** sarmal muayene yolu `p_secim='GEBE'` her fixture'da ayrı çağrılır.
- **BEKLENEN — DB:** (b) ve (c) **`RAISE 'BOS_DUZELTME_KOSUL:{eksik...}'`** ile red; (a) için izinli red kümesi **{`TOH_SONUCLU`, `BOS_DUZELTME_KOSUL`}** — planın koşul-4 dönmesi iki redten biriyle gelir, hangisi geldiği sınanmaz, ikisi de kabul (review ÖNEMLİ #2 düzeltmesi; `plan.md:304`). Tüm redlerde sonuc=Boş tohumlama dokunulmadan kalır, tohumlama_durumu değişmez, görev/vaka yazması yok. (Kontrast meşru yollar: TAKIP_MUAYENE+Boş+son+bağlı-açık-takip → T-77 Boş-düzeltme; GEBELIK_KONTROL+Bekliyor tohumlama → `p_bos_duzeltme=false` mevcut yoldan — T-78.)
- **Ters kanıt:** koşulları sağlamayan çağrıyla Boş→Gebe çevrimi (çekirdek genişlemesinin sızması) HATA; genel `tohumlama_sonuc_gebe` Bekliyor-only sözleşmesi T-05/T-83 ters kanıtıyla korunur.

### T-99 — PG geri alımı takibi YENİDEN AÇMAZ (kapanış kalıcı)
- **Ref:** plan P3a "Geri-al yolu (`pg_application_event.geri_alindi_at`) takibi YENIDEN ACMAZ (kapanis kalici)" · kabul 11
- **Katman:** DB-SQL
- **Ön koşul:** H'de açık takip (T-03 kurulumu); bağımsız PG uygulama ekranı (hızlı PG ya da seans).
- **Adımlar:** 1) PG uygula → `TAKIP_ACIK` onayı → evet (T-20 yolu; takip kapanır, neden=PG). 2) Aynı PG uygulamasını geri al (`pg_application_event.geri_alindi_at` doldurulur — mevcut geri-al yolu).
- **BEKLENEN — DB:** takip görevi **KAPALI KALIR** (`takip_kapanis_nedeni='PG'` bozulmaz); yeni `TAKIP_MUAYENE` görevi DOĞMAZ; `OVSYNC_BASLAT`/`_acik_disi_gorev_kur` ürünü üretilmez.
- **Ters kanıt:** geri alımın takibi yeniden açması (tamamlandi/iptal geri alınması) HATA; çift takip görevi doğması HATA.

### T-100 — Kapanış tetikleyicileri bayraktan bağımsız (MK9-K): bayrak KAPALIyken de çalışır
- **Ref:** plan P3a "MK9-K — tetikleyiciler bayraktan bağımsız (§10g; v7 güncellemesi)", §10h H3 · kabul 11
- **Katman:** DB-SQL
- **Ön koşul:** bayrak AÇIKken kurulan açık TAKIP_MUAYENE görevi (T-03 yolu); ardından demo `ovsync_pg_kurallari_aktif=0` yapılır (koşum sonrası geri açılır).
- **Adımlar:** 1) bayrak kapalıyken bayrak-bağımsız ESKİ yoldan (tohumlama kaydı) H'ye yeni tohumlama girilir; 2) H3 kaynak kanıtı: kapanış tetikleyici fonksiyon gövdesi `pg_get_functiondef` ile okunur — `hayvanlar` satır kilidi (`FOR UPDATE`/`LOCK`) kalıbı İÇERMEZ (review MİNÖR #3 düzeltmesi; 40P01/55P03'süzlük gözlemi destekleyici kalır, tek başına kanıt değil).
- **BEKLENEN — DB:** takip **KAPANIYOR** (tetikleyici bayrağı okumaz); `takip_kapanis_nedeni='YENI_TOHUMLAMA'`; tetikleyici hayvan kilidi ALMAZ (H3) — kapanış `40P01`/`55P03` olmadan tamamlanır. Sarmal bu zeminde yazamaz (T-97 `OZELLIK_KAPALI`) — tetikleyiciye yeni-yol girişi olmaz; eski yolun yazması tetikleyiciyi çalıştırır.
- **Ters kanıt:** bayrak kapalıyken kapanışın atlanması (takip açık kalması) HATA; tetikleyicinin hayvan satırı kilidi alması (H3 ihlali) HATA.

| Kabul (§9) | Senaryolar |
|---|---|
| 1 — Migration db-validate PASS | Tüm DB-SQL senaryolarının **ön koşulu** (katalog ölçmez; `scripts/db-validate.sh` kapısı ayrı koşulur) |
| 2 — RPC sözleşme (bayrak_kapali, anon yok, KPA nokta-doğrulama) | T-46, T-60, T-61; KPA: T-59 (+T-43). **PROD nokta-doğrulaması kapsam dışı (bkz. §Kapsam dışı)** |
| 3 — Ekran S0–S4, gruplama, rozetler, boş bölümler gizli, sayaç 40 | T-32..T-42, T-43, T-44, T-28..T-31, T-63..T-71 |
| 4 — Girişler (6. hücre sınıf koşulu, 🔔 link, Görevler köprüsü) | T-56, T-57 |
| 5 — Playwright demo PASS + glmf-max UI listesi | Tüm UI-Playwright satırları; İnsan-UI listesi §İNSAN-UI |
| 6 — Invalidate + offline (sessiz boş yok) | T-47, T-48, T-49, T-50, T-46 |
| 7 — RPC_TABLES yalnız §6c | T-62 (+kod taraması) |
| 8 — Gezinme | T-51..T-55 |
| 9 — Ovsync = 🔔 sayısı | T-58 (+T-45 eşik aynı kaynak) |
| 10 — Yazma yolu §7.9 (ekran yeni yazma yolu içermez) | T-34, T-35, T-37 (mevcut motorlara bağlanma), T-62; yalnız §6c istisnası: T-01..T-11 |
| 11 — §6c uçtan uca | T-01..T-30, T-41, T-72, T-73, T-75..T-78 (özellikle T-07 zorunluluk, T-12 sıralama, T-14..18 hard block, T-19..24 kapanış, T-25..27 ertele; v2: T-74 guard, T-77/T-78 Gebe yolları, T-86 preflight, T-89/T-92 kızgınlık kapısı, T-93 satır-sonucu) |
| **+ K15 (birleşik muayene, §10c #5/§18.17)** | T-04, T-05, T-39, T-74..T-78, T-82, T-76 ekran özdeşliği |
| **+ §10d (tek üretici + dashboard satırı)** | T-44, T-75, T-79, T-80, T-81, T-82 |
| **+ §10e/f (D1, C1, C4, C5, C6)** | T-77, T-83, T-84, T-85, T-88, T-89, T-90, T-91, T-92 |
| **+ §10g/h (MK9 daraltma, H5–H8, T-72b oracle)** | T-72, T-87, T-93, T-94 |
| **+ P2b/P3a sözleşme guard'ları (seçim uzayı, XOR+tip, bayrak-yazma, BOS_DUZELTME_KOSUL, geri-al kalıcılığı, tetikleyici bayrak-bağımsız — kapsam-açık turu)** | T-95..T-100 |

## İNSAN-UI — glmf-max tarayıcı listesi (UI testi kapısı)

Her madde tek tek koşulur; PASS kanıtı ekran görüntüsü/DOM. Kaynak mockup parantez içinde.

1. **Devam seçici görünümü** — "Devam nasıl olsun? (zorunlu)"; Ovsync ön seçili "hemen"; PG/Takibe bırak kartları; Kaydet etiketi seçimle değişiyor; alt not "tek işlemde" (mockup 01).
2. **Ovsync kilidi** — 🔒 Kural günü gerekçesi + ön seçim Takibe bırak; 🔒 Kısır varyantı (mockup 02).
3. **PG seçili** — ürün/doz alanı son kullanılanla dolu + değiştirilebilir dropdown (mockup 03).
4. **TAKIP_ACIK onay penceresi** — kendi bottom-sheet'i (tarayıcı `confirm()` değil!); küpe + tarih/saat metni; Evet/Vazgeç (mockup 04).
5. **Takip muayenesi sonuç ekranı** — "🔍 Takip muayenesi — Küpe X"; "Boş atandı GG.AA · takip N. gün"; ertele seçeneği "→ GG.AA SS:SS"; kızgınlık bağlantısı (mockup 05).
6. **S3 takipte rozeti** — "X · 🔍 takipte / muayene GG.AA SS:SS"; alt satır "Boş GG.AA · 7. gün muayenesi bekleniyor…"; bölüm başlığı "N görev · M takipte" (mockup 06).
7. **S0 canlı kart** — "Küpe X — TAI bugün SS:MM [▶]" (mockup yok — spec §3).
8. **KPA şeridi** — Aktif/Bugün/Geciken/Muayene bekleyen/Bekleyen başlatma; boş bölümler gizli (S0 koşumu).
9. **Satır gün şeması** — d0● d7◌ d8◌ d9◌ TAI⏳(tarih); renk dili: tamam yeşil/plan amber/gecikti kırmızı/uygulanmadi soluk/tutarsiz ⚠; alt satır "N/4 uygulandı · sıradaki…" (spec §4).
10. **Gezinme hissi** — ‹ geri; modal üstünde geri → modal kapanır; dönünce kaydırma/filtre yerinde.
11. **Offline etiketleri** — "çevrimdışı · HH:MM verisi" / "İnternet yok — takip verisi alınamadı".
12. **Görevler bağlamı** — takip görevi 🌱 Üreme çipinde; "Tüm ovsync takibi →" köprüsü çalışıyor. (K14-uyumlu — v2'de değişiklik yok.)
13. **Birleşik muayene sonuç ekranı** (K15) — GEBELIK_KONTROL ve TAKIP_MUAYENE görevlerinde AYNI ekran; Gebe / Boş→seçici / Muayeneyi ertele; etiketler "Muayene tamam + …" ("Boş ata" öneki yok — S-10).
14. **Üreme geçmişi düzeltme görünümü** — düzeltilen tohumlamada üstü çizili ❌ Boş (tarih) + ✅ Gebe (tarih); her satırda göreli gün ("bugün"/"dün"/"N gün önce"); tahmini doğum Gebe'den.
15. **Gebe yolu sonucu** — takip muayenesinde Gebe: son tohumlama Gebe'ye döner, takip `GEBE_BULUNDU` ile kapanır; gebelik kontrolünde Gebe: mevcut Gebe ataması davranışı.

## SPEC SORULARI — AÇIK SORU YOK (v2; hepsi design §10b/§10c/§10d ile kapandı)

| Soru | Cevap (kaynak) |
|---|---|
| S-1 (kısır + kural günü önceliği) | §10b S-1: kısır gerekçesi önce (kalıcı engel), kural günü ikinci satır |
| S-2 (erteleme saati) | §10b S-2 "önceki saat" → **§10d #3 ile geçersiz**: düzenlenebilir, varsayılan SAATSİZ |
| S-3 (takipte Gebe) | §10b S-3 + §10e D1: son tohumlama Gebe'ye çevrilir, takip `GEBE_BULUNDU` (T-77) |
| S-4 (PG_KAPI + TAKIP_ACIK) | §10b S-4: tek birleşik onay penceresi, tek `p_onay` (T-86) |
| S-5 (bayrak kapalı §6c) | §10b S-5: seçici açılmaz; `OZELLIK_KAPALI` (T-46) |
| S-6 (KPA takip dahil mi) | §10b S-6 + §10c #8: içerir; `bekleyen_baslatma_takipte` ayrı sayı |
| S-7 (erteleme tavanı) | §10b S-7: sınırsız; ≥21 g tek onay (T-26) |
| S-8 (sonuçlanmışa ikinci çağrı) | §10b S-8: `TOH_SONUCLU:{…}`, hiçbir yazma yok (T-72/T-73) |
| S-9 ("muayene vakti" sınırı) | §10b S-9: `kalan_gun <= 0` (T-39) |
| S-10 (muayene Kaydet etiketi) | §10c copy: "Muayene tamam + …"; "Boş ata" öneki yok (T-05/T-76) |
| (iki üretici çelişkisi) | §10d #1: +21/+35 üretimi kaldırılır; tek üretici cron ≥40 g (T-80/T-81) |

## Kapsam dışı bırakılanlar

- **PROD canlı nokta-doğrulama** (kabul 2'nin "KPA sayıları PROD verisiyle" yarısı): bu katalog turunda PROD erişimi yasak (zarf: okuma yalnız demo). Uygulama sonrası ayrı **salt-okuma** doğrulama turu önerilir.
- **FAZ 2** (hayvan×gün matrisi, toplu tamamla, başarı-oranı KPA'ları) — spec'in kendi faz sınırı.
- **Backlog B1–B8** (case_id backfill, TAI saat türetme, gün etiketi doğrulaması, `deneme_no` kolon hizalaması vb.) — spec backlog'u; yalnız B3 (test etiketi) not-düzeyinde T-71'de dokunuldu.
- **Performans/yük**, tarayıcı matrisi, görsel regresyon — kapsam tanımlı değil.
- **`gebelik_muayene_listele` yüzeyinin kendi** senaryoları — **v2 (D2/K15):** eşik-ortaklığı değil **küme-tam eşitlik + ekran entegrasyonu** test edildi (T-45/T-79/T-82); yüzeyin kendi bağımsız senaryoları kapsam dışı.
- **B9 — MK9 eski-yol kilit denetimi (§10h H2):** eski yolların (`tohumlama_sonuc_bos`, `gorev_tamamla` SUTTEN_KESME/padok, `hizli_uygulama_geri_al`, ham REST, eski tetikleyiciler) kilit grafı denetimi AYRI işe devredildi; T-72b eski-yol çiftleri prova dışı (T-87).
- **FAZ 2 iki-farm negatif testi** (§10c #13 — T-61).

## Koşum notları

- Demo yazmaları (seed, ayar değişimi T-43/T-46) koşum turunda yapılır, tur sonunda geri alınır/etiketlenir; `--only` yeniden koşumda `sonuclar.json` ezilmesin diye önce yedek (bilinen tuzak).
- RPC adları ve takip görev tipi plan v7 ile kesinleşti (§0 ad notasyonu); senaryolar fiili adlarla yazılır.
- **v2 koşum zemin (2026-09-29 ölçüm):** ürün implementasyonu başlamadan `tohumlama_bos_ve_devam`, `ovsync_takip_listele`, `takip_kapanis_nedeni` ve P3a tetikleyicileri demo'da YOK — buna bağlı senaryolar **beklenen kırmızı**; kırmızı koşumlar PASS SAYILMAZ (zarf kuralı). Çalıştırılabilir katmanlar: `tests/sql/ovsync_takip_test.sql` (DB-SQL + REST probe), `tests/concurrency/ovsync-takip-t72b.mjs` (T-87), `tests/e2e/ovsync-takip.spec.js` (PW temsilciler).
- Betikler demo dışı hedefe karşı fail-closed'dur: `ovsync_takip_test.sql` bağlantı öncesi `current_database()`/bağlantı hedefi demo projeye benzemiyorsa uyarır; T-72b betiği URL'de demo proje ref'i (`vtzqjmazsvurxdeondmi`) aramadan koşmaz (`T72B_ALLOW_ANY_HOST=1` ile aşılır — sahip kapısı).
