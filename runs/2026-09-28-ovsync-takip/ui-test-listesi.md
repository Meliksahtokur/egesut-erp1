# glmf-max UI test listesi — Ovsync Takip Ekranı (UI testi kapısı zarfı)

- Tarih: 2026-09-29 · Kaynak: plan v7 P12 (kabul 5; proje CLAUDE.md "UI testi kapısı") + katalog sürüm 2 §İNSAN-UI (1–15)
- **DURUM: ÜRÜN UI'SI UYGULANMADI — BU LİSTEDEKİ HİÇBİR MADDE BU TURDA PASS SAYILMAZ.** Sahibe demo linki VERİLMEZ; liste yalnız P5–P10 implementasyonundan SONRAKI glmf-max koşumu içindir.
- Koşum zemini: `?demo` (Demo-Mirror Supabase); `ovsync_pg_kurallari_aktif=1`, `sessiz_tohumlama_muafiyet_gun=40` [demo ölçüm 2026-09-29]. Playwright temsilciler: `tests/e2e/ovsync-takip.spec.js` (8/8 RED — 2026-09-29 Docker koşumu).
- Her madde: beklenen görünüm + kanıt türü (DOM / ekran / konsol). Madde başına PASS/FAIL + kanıt; FAIL → düzeltme → yalnız FAIL maddeler yeniden koşulur.

## A. Girişler ve omurga

1. **6. stat hücresi (T-56)** — Dashboard `.dash-row`'da `🔄 Ovsync ›` hücresi + aktif zincir sayısı; 2 kolonlu grid'de son satırı tamamlar. Sınıf: S0>0 ∨ muayene-vakti dolan>0 → `alert`; yalnız bekleyen-başlatma>0 → `warn`; sakin → `ok`. Tık → `#pg-ovsync` açılır. Kanıt: DOM (hücre sayısı+sınıf üç koşumda) + ekran.
2. **KPA şeridi (T-59)** — Aktif / Bugün / Geciken / Muayene bekleyen / Bekleyen başlatma; sayılar RPC `kpa` ile eşit; "Bekleyen başlatma" alt metni "(N takipte)". Kanıt: DOM (beş sayaç değeri) + RPC çıktı karşılaştırması (konsol).
3. **S0–S4 bölümleri (T-32)** — Bugün/geciken canlı kartlar; aktif zincir kartları; sonuç bekleyenler; başlatılmayı bekleyenler; sonlananlar (katlanır). **Boş bölüm HİÇ render edilmez** (boş başlık/placeholder yok). Kanıt: DOM (boş koşumda bölüm eleman sayısı=0) + ekran.
4. **🔔 "Tüm takibi aç →" + Görevler köprüsü (T-57)** — 🔔 🌱 bölümünde link ovsync sayfasına; Görevler başlığında "Tüm ovsync takibi →"; takip görevi 🌱 Üreme çipinde (K14). Kanıt: DOM (link href/handler) + ekran.
5. **Sayı eşitliği (kabul 9)** — Ovsync sayfası bekleyen-başlatma = 🔔 🌱 sayısı (aynı anda; uyarılar alt kümesi). Kanıt: DOM (iki yüzeyden okunan sayı) + ekran.

## B. Boş sonrası devam (§6c) — pozitifler

6. **Devam seçici (T-01/T-07)** — Boş seçince "Devam nasıl olsun? (zorunlu)" seçici; üç kart (🔄 Ovsync ÖN SEÇİLİ · 💉 PG · 🔍 Takibe bırak +7 g); Kaydet etiketi seçimle değişir ("Boş ata + Ovsync başlat" / "Boş ata + PG uygula" / "Boş ata + takibe bırak"); alt not "tek işlemde"; **"yalnız Kaydet" düğmesi YOK**. Kanıt: DOM (radio checked + buton metni) + ekran (mockup 01).
7. **PG ön dolu (T-02)** — PG kartı seçilince ürün/doz alanı son kullanılanla DOLU ve düzenlenebilir. Kanıt: DOM (input değeri + enabled) + ekran (mockup 03).
8. **TAKIP kurulumu (T-03)** — Takibe bırak: gün ön ayarı +7 (düzenlenebilir), saat atama anı; Kaydet → Görevler'de görev seçilen gün+saatte (🌱 Üreme), Ovsync S3'te "🔍 takipte · muayene GG.AA SS:DD" rozeti. Kanıt: DB (gorev_log) + DOM + ekran.
9. **Kilitli Ovsync (T-14..T-17)** — Kısır: "🔒 Kısır" gerekçe ÖNCE (S-1), kural günü ikinci satır; düve/doğumlu kural günü: "🔒 Kural günü GG.AA — N gün var"; ön seçim Takibe bırak'a düşer. Kanıt: DOM (kilit metni) + ekran (mockup 02).
10. **PG kapısı (T-06)** — `PG_KAPI:*` redsinde `#pg-kapi-bs` onay penceresi; "Boş ata ve uygula" tek işlemdir, **devam seçici AÇILMAZ**. Kanıt: DOM (sheet + seçici yokluğu) + DB (tek transaction sonucu).

## C. Kapılar ve kapanışlar

11. **TAKIP_ACIK onay sheet (T-20/T-21)** — App'in KENDİ bottom-sheet'i (native `confirm()`/`alert()` YASAK — konsol/dialog kanıtıyla): "Küpe X, GG.AA SS:DD'te rektal muayene takibinde. Takip kapatılıp PG uygulansın mı?"; Evet → takip kapanır + PG; Vazgeç → hiçbir yazma yok. Kanıt: DOM + konsol (dialog event yokluğu) + DB.
12. **Birleşik kapı (S-4, T-86)** — PG_KAPI + TAKIP_ACIK birlikte: TEK sheet, iki gerekçe alt alta, TEK onay. Kanıt: DOM + ekran.
13. **Sessiz kapanış (T-19)** — Takipli hayvana tohumlama kaydı: hiçbir onay çıkmaz; takip görevi kapanır (neden kayıtlı), listeden düşer. Kanıt: konsol (onay yokluğu) + DB.
14. **Çıkış kapanışı (T-22)** — Hayvan çıkışı → takip kapanır (neden=çıkış). Kanıt: DB + DOM (satır düşer).

## D. Birleşik muayene + geçmiş (K15, kalem 11/12)

15. **Birleşik sonuç ekranı (T-04/T-76)** — `GEBELIK_KONTROL` ve `TAKIP_MUAYENE` görevlerinde AYNI ekran: Gebe / Boş→devam seçici / Muayeneyi ertele; etiketler **"Muayene tamam + …"** ("Boş ata" öneki YOK — S-10); jenerik "✅ Tamamlandı" akışı bu tiplerde sonuç ekranına yönlenir (T-74: doğrudan kapatma yok). Kanıt: DOM (iki görev tipinde aynı kart seti) + ekran.
16. **Ertelenin saatsiz ön ayarı (T-25/T-26/§10d #3)** — "Muayeneyi ertele": +7 ön ayar, saat alanı BOŞ (saatsiz); saat girilebilir; ≥21 g'de tek onay "Bu hayvan N gündür takipte…". Kanıt: DOM (input değeri) + DB (hedef_saat NULL).
17. **Üreme geçmişi iki satır (T-84)** — Takipte Gebe: üstü çizili `❌ Boş (GG.AA)` + `✅ Gebe (GG.AA)`; tahmini doğum Gebe'den. Kanıt: DOM (iki satır + stiller) + ekran.
18. **Göreli gün (T-85)** — Geçmiş satırı tarih yanında "bugün"/"dün"/"N gün önce" (yalnız hayvan kartı üreme/tohumlama geçmişi). Kanıt: DOM.

## E. Ekran doğruluğu, offline, gezinme

19. **S2 sayacı 40 g (T-38/T-43/T-44)** — "muayeneye N gün" / kalan 0 → "muayene vakti"; ayar 35'e çekilince iki yüzeyde aynı anda kayar; **"21" sabiti hiçbir yerde yok**. Kanıt: DOM + DB (ayar değişimi + geri alış).
20. **Satır gün şeması (T-35/36)** — d0● d7◌ d8◌ d9◌ TAI⏳; renk dili (tamam yeşil/plan amber/gecikti kırmızı/uygulanmadi soluk/**tutarsiz ⚠**); alt "N/4 uygulandı · sıradaki…"; gün etiketleri nötr "1./2./3./4. uygulama" (ilaç adı YASAK). Kanıt: DOM + ekran.
21. **Sapma/deneme rozetleri (T-69/T-67)** — "hedef GG.AA → fiilen GG.AA (+Ng)" / "erken Ng" / "görevsiz"; "2. deneme — önceki boş". Kanıt: DOM + ekran.
22. **Bayrak kapalı (T-46)** — `ovsync_pg_kurallari_aktif=0`: açık mesaj ("Ovsync/PG kuralları kapalı"); boş liste SESSİZ gösterilmez; §6c seçici açılmaz. Kanıt: DOM + ekran.
23. **Offline (T-47/T-48)** — Bayat: "çevrimdışı · HH:MM verisi"; önbelleksiz: "İnternet yok — takip verisi alınamadı". Kanıt: DOM + ekran.
24. **Gezinme (T-51..T-55)** — Yatay geçiş Ana⇄Ovsync⇄Görevler; ‹ = `history.back()` (goTo('dash') DEĞİL); modal açıkken geri yalnız modalı kapatır; dönüşte scroll + padok filtresi yerinde. Kanıt: DOM (URL/pushState + scrollY) + ekran.
25. **Invalidate (T-50)** — Her yazma sonrası `__ovsyncTakip=null` + taze; bayat satır kalmaz. Kanıt: konsol (`window.__ovsyncTakip` durumu) + DOM.

## Koşum sözleşmesi

- Her madde ayrı PASS/FAIL + kanıt; **FAIL olanlar düzeltme sonrası yalnız FAIL maddelerle tekrar** (Playwright `--only` koşumlarında `sonuclar.json` ezilme tuzağına karşı önce yedek).
- Bu tur koşumu: maddeler 1–25'in HİÇBİRİ koşulamadı (UI yok) — Playwright temsilciler 8/8 RED (kanıt: koşum çıktısı 2026-09-29). Implementasyon sonrası glmf-max koltuğu bu listeyi koşar; hepsi PASS olmadan sahibe demo linki VERİLMEZ.
- Sahip şifresine dokunulmaz; demo seed'ler E2E- marker'lıdır ve temizlenir.
