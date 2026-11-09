# UB (N4) brief'lerine taşınacak ekler — UA1 T1 KABUL (2026-11-09, ss-reviewer)
1. ovsyncTrenHataMetni düz metin döner: tüketen her yer textContent/esc ile basar; toast()'ın innerHTML kullanıp kullanmadığını UB1'de ölç, innerHTML ise esc zorunlu (XSS).
2. ovsyncTrenSor içinde `await o.acModal(...)` (js/ovsync-tren.js:225) try/catch dışında: UB2/UB4 çağıranı reddi yakalayıp toast göstermeli ya da UA1'e küçük düzeltme.
3. Kalite: SECIM geçerlilik koşulu 3 tekrar (:328, :350, :406) → tek yardımcı; Vazgeç/Onay satırı 2 kopya (:184, :410) → yardımcı; başlık yorumu "inline onclick yok" ile :468/:483 tutarsız → UB3 bağlama kalıbına göre düzelt.
4. Sözleşme eki alanları (L-DB D4/D6/D7): kupe_no, kural_tarihi, uye_kupeler, pg_pay, ritim_disi_neden, pg1_zaman, ovsync_tren, tren_sayisi, dokunulmaz{bagimsiz,ritim_disi}, ovsync_uyari{kupe_no,planlanan_tarih,tamamlanan_tarih,bastan_tren_gunu} — UA1'deki isteğe bağlı dallar artık dolu veriyle sınanır.
5. UB2: "(n hayvan)" = uye_kupeler.length (sorulan hayvan hariç); onizle gecikmiş görevde gelecek treni döner + gorev_hedef_eski alanı (root ruling, L-DB D4 ek tur).

# DM1 (N6) eki
- Demo apply sonrası yeni/değişen TÜM imzalar için `has_function_privilege('anon', '<imza>', 'EXECUTE')` = false ölçülür (kabul DB'si anon default EXECUTE vermediği için yalnız metin doğrulandı — L-DB notu).
6. UB3 (L-DB RL-16): "Tren gününü ertele…" düğmesi YALNIZ bugünden itibaren ilk ritim günü başlığında çizilir; ileri tarih sunucuda OVSYNC_TREN_GUNU_DEGIL:{sebep:'ONCEKI_TREN_VAR', ilk_tren} → ovsyncTrenHataMetni'ne ekle. RL-14 ileri_vakalar[], RL-12 iptal_tai[] dönüşleri önizleme/sonuç metninde gösterilir. (root: itiraz yok, 2026-11-09)

# N6 eki — ZAMAN SENARYOSU (sahip onayı 2026-11-09: "tamam ekle")
Amaç: tekil testlerin görmediği "olaylar üst üste binince" hatalarını yakalamak. 4–5 hayvan, 3 haftalık takvim, araya gerçek dünya olayları.
1. DB tarafı (yerel kabul DB, `kb_bugun()` ilerletilerek, BEGIN/ROLLBACK): hafta 1 — 4 hayvan trene biner (biri bağımsız başlar); gün 3 — biri hastalık günü (K9, bağımsıza düşer); hafta 2 — PG1 bir hayvanda 1 gün geç (tolerans içi) ve birinde tolerans dışı (K11 uyarısı → baştan başlat); tren günü toptan 1 hafta ertelenir (aşama 2 üyesi SECIM ister); hafta 3 — tren ayarı çapası değişir (bağımsız ve hastalıklı trene GİRMEZ — D9). Her adımda: `ovsync_tren_listele` üyeleri/aşamaları, açık görevlerin hedef tarihleri, `ovsync_tren`/`ovsync_bagimsiz` değerleri beklenen tabloyla birebir.
2. UI tarafı (demo, tek sonnet yürüyüşü, DM2 test listesine ek): aynı olay dizisi demo'da geriye tarihli kayıtlarla kurulur; her adımda Ovsync ekranı, görevler ekranı ve vaka kartı "bu hafta hangi gün kaç hayvanla ne iş var" sorusuna doğru cevap veriyor mu — madde başına PASS/FAIL + ekran görüntüsü.
Beklenen tablo senaryo yazılırken önce PLAN R1–R20 ve design.md K1–K11'den çıkarılır (yürütücü tahmin etmez); belirsiz adım → root'a SORU.
