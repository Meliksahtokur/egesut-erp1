# W3 — Doğum Tarihleri DB Denetimi (salt-okuma)

Tarih: 2026-09-13 (rev. 2 — root denetimi R1–R3 işlendi) · Dal: `agent/dogum-tarih-denetimi` ·
Görev zarfı: `.ss/tasks/W3-dogum-tarih-denetimi.md` · v1: commit `1cc569a`

**Yöntem:** Canlı prod (Supabase Management API `/database/query`, yalnız SELECT) üzerinden
tüm ilgili tablolar (`hayvanlar` 166, `dogum` 72, `tohumlama` 282, `cases` 112,
`kizginlik_log` 30, `uygulama_log` 120, `gorev_log` 3055) diske çekildi; defter
karşılaştırması ve anomaliler bu çekimler üzerinde deterministik Python analiziyle
yapıldı (`reports/w3/analiz.py`, `reports/w3/tarama.py` — bu dalda); özet sayılar
ayrıca doğrudan SQL ile teyit edildi. DB'ye yazma yok, kod değişikliği yok.
Ham çekimler: `/home/melik/tmp/agents/w3/*.json`.

**Rev. 2 değişiklikleri (root denetimi):** (R1) `hayvanlar.anne_id` üzerinden anne
çakışma denetimi eklendi — yalnız `dogum` tablosuna bakmak buzağı 51/195 çakışmasını
kaçırmıştı; satır 51 (ve aynı sınıftan 59, 60) "OY" olarak yeniden sınıflandı; (R2)
185/188 için dolaylı tohumlama kanıtı eklendi; (R3) analiz betikleri ve betik
kontrollerinin SQL eşdeğerleri bu dala işlendi.

## Özet

| Ölçüm | Değer |
|---|---|
| Defter satırı | 52 |
| Tarih + cinsiyet **UYUMLU (UY)** | **46** — içinde 1 "UY*": satır 15 (buzağı 44), tarih/cinsiyet uyumlu ama anne ataması defterle çelişkili |
| Tarih uyumlu ama **anne bağlantısı kusurlu (OY)** | **4** (buzağı 32, 51, 59, 60) |
| **GÜN-AY TERS** | **0** |
| **TARİH FARKLI** | **0** |
| **CİNSİYET FARKLI** | **0** |
| **KAYIT YOK (KY)** | 2 (185, 188 → Eyl-2025; dolaylı tohumlama izi var, bkz. satır 2–3) |
| `anne_id` hiç girilmemiş doğum kaydı | 11 |
| Aynı buzağıya çift doğum kaydı | 1 (buzağı 55) |
| `hayvanlar.anne_id`/`dogum.anne_id` birleşik kaynakta ineğe binen çakışan doğum çifti (>5g, <330g) | 2 — **195: 100 gün (31+51, gerçek çelişki)**; 008: 307 gün (sınırda) |
| Mükerrer `kupe_no` (bugün) | 0 — 982fbd16 toplu girişte kupe 51 + anne 195 idi, bugün kupe 31'e çevrilmiş; **değişiklik `islem_log`'da izsiz** (RPC dışı düzenleme) |
| Tohumlama→doğum aralığı 260–300 dışı | 4 (191: 145g, 167: 215g, 134: 302g, 176: 311g) |
| Gün/ay takasla 260–300'e oturan kayıt | **0** |
| Sonucu "Doğum Yaptı" olup 240–320 gün penceresinde doğum olayı olmayan tohumlama | 29 (sistemik; çoğu uygulama-öncesi geçmiş, 185/188 dahil) |
| Gelecek tarihli olay | 0 |

**Ana sonuç:** Kırmızı senaryo (Android'de `mm/dd/yyyy` yüzünden gün≤12 tarihlerin
ters girilmesi) DB verisinde **gerçekleşmemiş**. 52/52 satırda tutarlılık ya tarih
olarak birebir ya da kaydın hiç/eksik girmesi şeklinde; tek bir gün-ay yer
değiştirmeye rastlanmadı. `created_at` sinyali de bunu doğruluyor (Soru 4).
Gerçek veri kalitesi sorunları tarih-biçimi değil **anne bağlantıları** ve
**eksik doğum kayıtları** etrafında toplanıyor.

## Soru 1 — Tarih kolonları nasıl saklanıyor?

`information_schema.columns` taraması (public şeması, sistem şemaları hariç):

- **Tüm olay tarihleri native `date` tipinde:** `dogum.tarih`, `tohumlama.tarih`,
  `tohumlama.kontrol_tarihi`, `tohumlama.dogum_tarihi`, `tohumlama.abort_tarihi`,
  `hayvanlar.dogum_tarihi/cikis_tarihi/suttten_kesme_tarihi/tohumlama_onay_tarihi`,
  `kizginlik_log.tarih`, `cases.start_date`, `uygulama_log.tarih`,
  `hastalik_log.tarih/kapanis_tarihi/kapanma_tarihi`, `vaccination_log.vaccination_date`,
  `gorev_log.hedef_tarih`, `treatment_days.treatment_date`.
- **Zaman damgaları `timestamptz`:** tüm `created_at/updated_at`, `islem_log.tarih`,
  `stok_hareket.tarih`, `bildirim_log.olusturma/erteleme` vb.
- **Text tipinde tarih kolonu: YOK.** 322 text/varchar kolonun adı tek tek
  elendi; tarih-adayı (`tarih/date` deseni) 0 adet.

Sonuç: saklama katmanı sorunsuz — değerler ISO `date`. "Gösterim değil giriş"
ön-teşhisi doğru; bu girdi katmanı biçiminin DB'de iz bırakmadığını gösterir.

## Soru 2 — Defter karşılaştırması (satır satır)

Durumlar: **UY** = UYUMLU · **UY\*** = UYUMLU ama anne ataması çelişkili ·
**OY** = tarih+cinsiyet uyumlu, anne bağlantısı kusurlu · **KY** = KAYIT YOK.
DB sütunu: `dogum.tarih` (yoksa `hayvanlar.dogum_tarihi`), anne kupe ve buzağının
güncel durumu. Cinsiyet karşılaştırması hem `dogum.yavru_cins` hem buzağının
`hayvanlar.cinsiyet` değeriyle; anne denetimi **üç kaynakla** yapıldı:
`dogum.anne_id`, `hayvanlar.anne_id`, defter küpesi ↔ `kupe_no`/`devlet_kupe`
(son-4 dahil). Defter kodları: `ex`=öldü, `₺`=satıldı.

| # | Defter (anne/tarih/cins/buzağı) | DB | Durum | Not |
|---|---|---|---|---|
| 1 | 156 / 05.09.2025 / düve / 32 | 2025-09-05, Dişi/Aktif | **OY** | `dogum` olayı yok; hayvanlar.dogum_tarihi doğru; buzağı 32'nin `anne_id` NULL (156'ya bağlı değil) |
| 2 | 185 / 08.09.2025 / dana / ? | — | **KY** | doğum kaydı/buzağı yok. **Dolaylı iz:** tohumlama 2024-11-27, sonucu "Doğum Yaptı" → +285 gün = 2025-09-08 (defterle aynı). 185'in ikinci döngüsü tutarlı: toh 2025-10-15 → +280g ≈ #93'ün gerçek doğumu (2026-07-22) |
| 3 | 188 / 08.09.2025 / düve / ? | — | **KY** | doğum kaydı/buzağı yok. **Dolaylı iz:** tohumlama 2024-12-12, sonucu "Doğum Yaptı" → +270 gün = 2025-09-08 (defterle aynı). Sonraki döngü: toh 2025-11-15 → +274g = #97 (2026-08-16, birebir) |
| 4 | 1940-5621 / 15.09.2025 / dana / 33 ₺ | 2025-09-15, anne 5621 (devlet TR354341940), Erkek/Satıldı | **UY** | "1940-5621" = devlet kupe sonu + kupe |
| 5 | 145 / 17.09.2025 / dana / 34 ₺ | 2025-09-17, Erkek/Satıldı | **UY** | |
| 6 | 177 / 17.09.2025 / dana / 35 ₺ | 2025-09-17, Erkek/Satıldı | **UY** | anne_id NULL (dogum + hayvanlar); 177 hayvanlar'da yok |
| 7 | 142 / 06.10.2025 / düve / 36 | 2025-10-06, Dişi/Aktif | **UY** | |
| 8 | 153 / 08.10.2025 / düve / 37 ex | 2025-10-08, Dişi/Ölü | **UY** | ex ✓ |
| 9 | 182 / 14.10.2025 / düve / 38 | 2025-10-14, Dişi/Aktif | **UY** | |
| 10 | 107 / 19.10.2025 / dana / 39 | 2025-10-19, Erkek/Aktif | **UY** | anne_id NULL (dogum + hayvanlar); 107 hayvanlar'da yok |
| 11 | Küpesiz düve / 21.10.2025 / dana / 40 ₺ | 2025-10-21, Erkek/Satıldı | **UY** | anne_id NULL (dogum + hayvanlar) |
| 12 | 008 / 29.10.2025 / dana / 41 ₺ | 2025-10-29, Erkek/Satıldı | **UY** | |
| 13 | 167 / 02.11.2025 / dana / 42 ₺ | 2025-11-02, Erkek/Satıldı | **UY** | |
| 14 | 178 / 03.11.2025 / dana / 43 | 2025-11-03, Erkek/Aktif | **UY** | |
| 15 | 162 / 07.11.2025 / dana / 44 | 2025-11-07, Erkek/Aktif | **UY\*** | **ANNE ÇELİŞKİSİ:** DB anne=904; defterdeki 162 DB'de yok; ayrıca 904'ün devlet kupe sonu 7125 defterde buzağı 60'ın annesi yazılı → 904'e 38 gün arayla iki doğum biniyor, en az biri hatalı |
| 16 | 197 / 09.11.2025 / düve / 45 | 2025-11-09, Dişi/Aktif | **UY** | |
| 17 | 191 / 13.11.2025 / düve / 46 | 2025-11-13, Dişi/Aktif | **UY** | tohumlama aralığı 145 gün (bkz. Soru 3) |
| 18 | 155 / 13.11.2025 / dana / 47 | 2025-11-13, Erkek/Aktif | **UY** | |
| 19 | 5708 / 15.11.2025 / dana / 48 | 2025-11-15, Erkek/Aktif | **UY** | |
| 20 | 2045 / 16.11.2025 / dana / 49 | 2025-11-16, anne 905 (devlet TR354342045 → son4 "2045"), Erkek/Aktif | **UY** | |
| 21 | 179 / 16.11.2025 / düve / 50 ex | 2025-11-16, Dişi/Ölü | **UY** | anne_id NULL (dogum + hayvanlar); 179 hayvanlar'da yok; ex ✓ |
| 22 | 195 / 17.11.2025 / düve / 51 | 2025-11-17, anne 195 (dogum olayı), Dişi/Aktif | **OY** | hayvanlar a67cd118 (kupe 51) `anne_id` NULL. **ANNE ÇAKIŞMASI:** kupe 31 (982fbd16, Tr093150354, 2025-08-09, `anne_id`=195) → 195'e 100 gün arayla iki buzağı (31+51) biniyor, biyolojik olarak imkansız, en az biri yanlış. 982fbd16 toplu girişte (2026-06-01) kupe 51 + anne 195 olarak girilmişti, bugün kupe 31'e çevrilmiş; değişiklik `islem_log`'da izsiz |
| 23 | 181 / 23.11.2025 / dana / 52 ex | 2025-11-23, Erkek/Ölü | **UY** | ex ✓ |
| 24 | 199 / 29.11.2025 / dana / 53 | 2025-11-29, Erkek/Aktif | **UY** | |
| 25 | 147 / 03.12.2025 / dana / 54 | 2025-12-03, Erkek/Aktif | **UY** | |
| 26 | 196 / 04.12.2025 / düve / 55 | 2025-12-04, anne 196, Dişi/Aktif | **UY** | **ÇİFT doğum kaydı:** aynı gün `anne_id` NULL ikinci kayıt var |
| 27 | 101 / 08.12.2025 / düve / 56 | 2025-12-08, Dişi/Aktif | **UY** | |
| 28 | 5638 / 09.12.2025 / düve / 57 ex | 2025-12-09, Dişi/Ölü | **UY** | ex ✓ |
| 29 | Minik panda / 12.12.2025 / dana / 58 ex | 2025-12-12, Erkek/Ölü | **UY** | anne_id NULL (dogum + hayvanlar); ex ✓ |
| 30 | 5748 / 14.12.2025 / dana / 59 | 2025-12-14, Erkek/Aktif | **OY** | 5748 DB'de VAR (54f31c94, Dişi/Aktif); dogum kaydında ve hayvanlar'da `anne_id` NULL → bağlantı eksik |
| 31 | 7125 / 15.12.2025 / dana / 60 | 2025-12-15, Erkek/Aktif | **OY** | dogum kaydında ve hayvanlar'da `anne_id` NULL; defter "7125" = 904'ün devlet kupe son-4'ü (bkz. #15 çelişkisi) |
| 32 | 1956 / 18.12.2025 / düve / 61 | 2025-12-18, anne 903 (devlet TR354341956 → son4 "1956"), Dişi/Aktif | **UY** | |
| 33 | 154 / 23.12.2025 / düve / 62 | 2025-12-23, Dişi/Aktif | **UY** | |
| 34 | 159 / 23.12.2025 / düve / 63 ex | 2025-12-23, Dişi/Ölü | **UY** | anne_id NULL (dogum + hayvanlar); 159 hayvanlar'da yok; ex ✓ |
| 35 | 187 / 12.01.2026 / dana / 64 | 2026-01-12, Erkek/Aktif | **UY** | |
| 36 | 161 / 17.01.2026 / dana / 65 | 2026-01-17, Erkek/Aktif | **UY** | anne_id NULL (dogum + hayvanlar); 161 hayvanlar'da yok |
| 37 | 189 / 02.02.2026 / dana / 66 ex | 2026-02-02, Erkek/Ölü | **UY** | ex ✓ |
| 38 | 106 / 03.02.2026 / dana / xx (erken doğum) ex | 2026-02-03, kupe "xx", Erkek | **UY** | anne_id NULL; yavru hayvanlar'a alınmamış (ex) |
| 39 | 141 / 05.02.2026 / dana / 67 | 2026-02-05, Erkek/Aktif | **UY** | |
| 40 | 176 / 06.02.2026 / düve / 68 | 2026-02-06, Dişi/Aktif | **UY** | |
| 41 | 152 / 07.02.2026 / düve / 69 | 2026-02-07, Dişi/Aktif | **UY** | |
| 42 | 115 / 09.02.2026 / dana / 70 ex | 2026-02-09, Erkek/Ölü | **UY** | ex ✓ |
| 43 | 134 / 10.02.2026 / dana / 71 | 2026-02-10, Erkek/Aktif | **UY** | tohumlama aralığı 302 gün (bkz. Soru 3) |
| 44 | 175 / 15.02.2026 / dana / 72 ex | 2026-02-15, Erkek/Ölü | **UY** | ex ✓ |
| 45 | 183 / 16.02.2026 / dana / 73 | 2026-02-16, Erkek/Aktif | **UY** | |
| 46 | 121 / 19.02.2026 / düve / 74 | 2026-02-19, Dişi/Aktif | **UY** | |
| 47 | 146 / 19.03.2026 / düve / 75 | 2026-03-19, Dişi/Aktif | **UY** | |
| 48 | 192 / 19.03.2026 / dana / 76 | 2026-03-19, Erkek/Aktif | **UY** | |
| 49 | 901 / 08.04.2026 / düve / 77 | 2026-04-08, Dişi/Aktif | **UY** | |
| 50 | 901 / 08.04.2026 / düve / 78 (ikiz) | 2026-04-08, Dişi/Aktif | **UY** | ikiz DB'de de aynı gün ✓ |
| 51 | 173 / 14.04.2026 / düve / 79 | 2026-04-14, Dişi/Aktif | **UY** | |
| 52 | 180 / 16.04.2026 / dana / 80 | 2026-04-16, Erkek/Aktif | **UY** | |

*\* Defter notları DB ile uyumlu: `ex` yazılan 10 buzağın tamamı DB'de `Ölü`,
`₺` yazılanlar (33, 34, 35, 40, 41, 42) DB'de `Satıldı`.*

## Soru 3 — Genel tarama bulguları

Kapsam: `dogum.tarih`, `tohumlama.tarih/kontrol_tarihi/dogum_tarihi`,
`kizginlik_log.tarih`, `cases.start_date`, `uygulama_log.tarih`
(test hayvanları hariç). Kuruya ayırma: DB'de **ayrı olay tipi yok**
(`gorev_tipi` dağılımında kuru görev tipi bulunmuyor) → bu kategori taranamadı.
`tedavi` tablosu prod'da **0 satır**; tedavi verisi `treatment_days` (424) /
`treatment_day_uygulamalar` (564) / `uygulama_log` (120) tablolarında yaşıyor.

| Kontrol | Sonuç |
|---|---|
| Gelecek tarihli olay (> 2026-09-13) | **0** |
| Yavru, annenin kendi doğumundan önce / anne <660 gün | **0** |
| **Anne çakışması — birleşik kaynak** (`hayvanlar.anne_id` ∪ `dogum.anne_id`; >5g ve <330g; 0–5g'ler ikiz/aynı doğumun iki kaynak kaydı olduğundan hariç) | **2** |
| — **195: 2025-08-09 (kupe 31) → 2025-11-17 (kupe 51) = 100 gün** — biyolojik olarak imkansız; hayvanlar.anne_id yolu yalnız bu kontrolle görünür (root R1) |
| — 008: 2025-10-29 → 2026-09-01 = 307 gün (sınırda; 2026-09-01'deki #500+#3 ikizdir, defter kapsamı dışı) |
| Mükerrer `kupe_no` (canlı, bugün) | **0** — 982fbd16'nın 51→31 değişimi bugün yapılmış; `islem_log`'da bu değişikliğin izi yok (yalnız padok olayları var) → RPC dışı düzenleme |
| Tohumlama→doğum aralığı 260–300 dışı (doğumdan önceki son tohumlamayla) | **4** |
| — 191: 2025-06-21 → 2025-11-13 = **145 gün** (biyolojik olarak imkansız; gün≤12 değil, takasla da düzelmez) |
| — 167: 2025-04-01 → 2025-11-02 = **215 gün**; takasla (toh→2025-01-04) 302 gün — hâlâ dışarıda, sınırda |
| — 134: 2025-04-14 → 2026-02-10 = **302 gün**; takas adayı aralık 260–300'e oturmuyor |
| — 176: 2025-04-01 → 2026-02-06 = **311 gün**; takasla da oturmuyor |
| **Takasla 260–300'e oturan kayıt** | **0** |
| `kontrol_tarihi` ≤ tohumlama tarihi (sıra bozuk) | **0** |
| Planlanan `dogum_tarihi` < tohumlama tarihi | **0** |
| Aynı buzağı kupeye iki doğum kaydı | **1** — buzağı 55 (2025-12-04 ×2; biri anne=196, biri `anne_id` NULL) |
| Sonucu "Doğum Yaptı" olup 240–320g penceresinde doğum olayı olmayan tohumlama | **29** — sistemik: çoğu uygulama-öncesi (2022–2024) geçmiş kaydı; defterle ilgili olanlar 185 (2024-11-27) ve 188 (2024-12-12) |

Ek tespit: **Test hayvanları prod'da duruyor** ("Test inek cabbar", "Test buzağı
cabbiş", "Test inek 3", "Test buzağı 3" + 2026-01-01/2026-05-23/2026-06-06
tarihli tohumlama ve doğum kayıtları). Analizden arındırıldı; temizlik önerisi
aşağıda.

## Soru 4 — `created_at` ile olay tarihi farkı sinyali

- 2026-05-09, 2026-05-27 ve 2026-06-01 tarihli **üç toplu içe aktarma
  dilimi** hariç tutuldu (defterden geriye dönük anahtar, `created_at` hepsinde
  aynı dakikada). Bu dilimdeki kayıtlarda sinyal kullanılamaz.
- Kalan **331 olay kaydında** 310'unun `|tarih − created_at| ≤ 7 gün` —
  yani günlük kullanım. **Gün/ay tersi girilmişse** `created_at` girilen
  tarihin tersinden ~1 ay uzakta olmalıdır: `|created_at − swap(tarih)| ≤ 7 gün`
  koşuluyla tarandı → **0 kayıt**.
- 45–120 gün arası sapan 4 tohumlama kaydı (196 −102g, 5748 −66g, 06 −65g,
  07 −76g) ve daha büyük sapmalar Haziran-Temmuz 2026'daki arka-doldurma
  girişleridir; ters-girme deseni değil.

**Sonuç:** `created_at` sinyali ters girme kanıtı üretmiyor — çünkü ters girme
olmamış (Soru 2 ile tutarlı).

## Soru 5 — Yedekler ve kayıt bazlı değişim geçmişi

- **Yedekler** (indirme/geri yükleme yapılmadı): `.github/workflows/db-backup.yml`
  — günlük 00:00 UTC'de GitHub Actions koşuyor; pooler üzerinden `pg_dump`
  (custom format, compress-9), çıktı `openssl enc -aes-256-cbc -pbkdf2` ile
  `BACKUP_PASSWORD` secret'ı şifrelenip **GitHub Actions artifact** olarak
  yükleniyor (`egesut-backup-<run_id>`, **retention 90 gün**). Erişim: repo
  Actions → "DB Backup" run → Artifacts; decrypt için sahibin
  `BACKUP_PASSWORD` değeri gerekir.
- **Kayıt bazlı "ne zaman değişti" sorusu:** prod'da `islem_log` tablosu
  (4.235 satır, 2026-05-09 → bugün; 72 adet DOGUM tipli) `tip`, `tarih`,
  `ref_tablo`, `ref_id`, `snapshot` (jsonb), `payload` (jsonb),
  `geri_alma_tarihi` kolonlarıyla her RPC işleminin izini tutuyor. Belirli bir
  kaydın geçmişi: `SELECT * FROM islem_log WHERE ref_id = '<kayıt-id>' ORDER BY tarih;`
  — `snapshot`/`payload` önceki değerleri taşıdığı için tarih değişikliği
  buradan görülebilir. Ayrıca `hayvanlar.updated_at` satır bazlı son
  güncellemeyi verir. **Sınır (bu denetimde ölçüldü):** `islem_log` yalnız
  RPC-tracked işlemleri görür — kupe 51→31 değişikliği (982fbd16) burada yok;
  `snapshot`/`payload` metininde `Tr093150354` aranması 0 satır döndü. Yani
  RPC dışı yapılan düzenlemeler bu tarihe düşmez. 90 gün retention **artifact
  dosyaları** içindir; `islem_log` tablosu DB'de durduğu sürece tüm uygulama
  dönemini kapsar.

## Kullanılan SQL

Mgmt API `/database/query` üzerinden koşulanlar (salt-okuma). Betik
kontrollerinin (defter karşılaştırması, takas-yakınlık, çakışma eşleştirmeleri)
tam kodu bu dalda: `reports/w3/analiz.py`, `reports/w3/tarama.py`.

```sql
-- (a) Şema taraması: tarih kolonları ve tipleri
SELECT table_name, column_name, data_type FROM information_schema.columns
WHERE table_schema='public'
  AND (column_name ~* 'tarih|tari|date|_at$' OR data_type IN ('date','timestamp with time zone'))
  AND NOT (table_name ~ '^_') ORDER BY table_name, ordinal_position;

-- (b) Text tipinde tarih-adayı kolon var mı?
SELECT table_name, column_name FROM information_schema.columns
WHERE table_schema='public' AND data_type IN ('text','character varying')
  AND substr(table_name,1,1) <> '_' ORDER BY table_name;
-- 322 satır döndü; tarih-deseni elle elendi: 0 adet.

-- (c) Tablo çekimleri (analiz girdisi; tamamı diske kaydedildi)
SELECT id,kupe_no,devlet_kupe,cinsiyet,dogum_tarihi,anne_id,durum,cikis_tarihi,
       cikis_sebebi,cikis_tipi,notlar,created_at,updated_at
  FROM hayvanlar ORDER BY created_at;                      -- 166 satır
SELECT * FROM dogum ORDER BY created_at;                   -- 72
SELECT id,hayvan_id,tarih,kontrol_tarihi,sonuc,deneme_no,deneme_sayisi,
       dogum_tarihi,buzagi_kupe,abort_tarihi,abort_notlar,created_at,gerceklesme_at
  FROM tohumlama ORDER BY created_at;                      -- 282
SELECT id,animal_id,start_date,status,created_at,closed_at FROM cases;   -- 112
SELECT * FROM kizginlik_log;                               -- 30
SELECT * FROM uygulama_log;                                -- 120
SELECT * FROM gorev_log;                                   -- 3055
SELECT * FROM cop_kutusu;                                  -- 0

-- (d) anne_id'si hiç hayvana çözümlenmeyen doğum (başıboş referans)
SELECT count(*) FROM dogum d LEFT JOIN hayvanlar h ON h.id = d.anne_id
WHERE d.anne_id IS NOT NULL AND h.id IS NULL;              -- 0
-- Sorunun kendisi anne_id IS NULL olan 11 kayıt:
SELECT yavru_kupe, tarih FROM dogum WHERE anne_id IS NULL AND yavru_kupe IS NOT NULL;

-- (e) Aynı buzağıya çift doğum kaydı
SELECT yavru_kupe, count(*) n, string_agg(coalesce(anne_id,'-'),' | ') anneler
FROM dogum WHERE yavru_kupe IS NOT NULL
GROUP BY yavru_kupe HAVING count(*) > 1;                   -- 55 (×2)

-- (f) Gelecek tarih sayımı
SELECT count(*) FROM (
  SELECT tarih FROM dogum UNION ALL SELECT tarih FROM tohumlama
  UNION ALL SELECT tarih FROM kizginlik_log UNION ALL SELECT start_date FROM cases
  UNION ALL SELECT tarih FROM uygulama_log) t
WHERE tarih > CURRENT_DATE;                                -- 0

-- (g) Tohumlama→doğum aralığı 260–300 dışı (doğumdan önceki SON tohumlama)
SELECT h.kupe_no anne, d.tarih dogum, t.tarih son_toh, d.tarih - t.tarih aralik_gun
FROM dogum d
JOIN hayvanlar h ON h.id = d.anne_id
JOIN LATERAL (SELECT t2.tarih FROM tohumlama t2
              WHERE t2.hayvan_id = d.anne_id AND t2.tarih <= d.tarih
              ORDER BY t2.tarih DESC LIMIT 1) t ON true
WHERE (h.kupe_no ILIKE '%test%' OR d.yavru_kupe ILIKE '%test%') IS NOT TRUE
  AND (d.tarih - t.tarih) NOT BETWEEN 260 AND 300
ORDER BY aralik_gun;                                       -- 4 satır (191,167,134,176)

-- (h) Mükerrer devlet küpesi (904/162 çelişkisi araştırması)
SELECT * FROM hayvanlar WHERE devlet_kupe IN (
  SELECT devlet_kupe FROM hayvanlar WHERE devlet_kupe IS NOT NULL
  GROUP BY devlet_kupe HAVING count(*) > 1);               -- 0

-- (i) islem_log kapsamı
SELECT min(tarih)::date ilk, max(tarih)::date son, count(*) n,
       count(*) FILTER (WHERE tip LIKE '%DOGUM%') dogum_tipli FROM islem_log;

-- (j) ANNE ÇAKIŞMASI — birleşik kaynak (root R1; analiz.py/tarama.py §3 ile aynı mantık)
--     0–5g'ler ikiz/aynı doğumun iki kaynak kaydıdır, çakışma sayılmaz.
WITH buz AS (
  SELECT anne_id, dogum_tarihi d FROM hayvanlar
   WHERE anne_id IS NOT NULL AND dogum_tarihi IS NOT NULL
  UNION ALL
  SELECT anne_id, tarih FROM dogum WHERE anne_id IS NOT NULL AND tarih IS NOT NULL
), seri AS (
  SELECT anne_id, d, LAG(d) OVER (PARTITION BY anne_id ORDER BY d) onceki FROM buz
)
SELECT h.kupe_no anne, seri.onceki, seri.d sonraki, seri.d - seri.onceki aralik_gun
FROM seri JOIN hayvanlar h ON h.id = seri.anne_id
WHERE seri.onceki IS NOT NULL
  AND seri.d - seri.onceki BETWEEN 6 AND 329
ORDER BY aralik_gun;                                       -- 195: 100g, 008: 307g

-- (k) Anne yaşı: yavru doğumu − anne doğumu < 660 gün
SELECT c.kupe_no yavru, m.kupe_no anne, m.dogum_tarihi anne_dogum, c.dogum_tarihi
FROM hayvanlar c JOIN hayvanlar m ON m.id = c.anne_id
WHERE c.dogum_tarihi IS NOT NULL AND m.dogum_tarihi IS NOT NULL
  AND c.dogum_tarihi - m.dogum_tarihi < 660;               -- 0

-- (l) kontrol_tarihi sırası + planlanan doğum
SELECT h.kupe_no, t.tarih, t.kontrol_tarihi FROM tohumlama t
JOIN hayvanlar h ON h.id = t.hayvan_id
WHERE t.kontrol_tarihi <= t.tarih                            -- 0 satır
UNION ALL
SELECT h.kupe_no, t.tarih, t.dogum_tarihi FROM tohumlama t
JOIN hayvanlar h ON h.id = t.hayvan_id
WHERE t.dogum_tarihi < t.tarih;                              -- 0 satır
```

```sql
-- (m) Mükerrer kupe_no
SELECT kupe_no, count(*) n FROM hayvanlar
WHERE kupe_no IS NOT NULL AND kupe_no <> ''
GROUP BY kupe_no HAVING count(*) > 1;                      -- 0 (bugün)

-- (n) "Doğum Yaptı" öksüzleri: 240–320g penceresinde dogum olayı yok
SELECT h.kupe_no, t.tarih toh, t.sonuc
FROM tohumlama t JOIN hayvanlar h ON h.id = t.hayvan_id
WHERE t.sonuc ILIKE '%do%um%' AND h.kupe_no NOT ILIKE '%test%'
  AND NOT EXISTS (SELECT 1 FROM dogum d
                  WHERE d.anne_id = t.hayvan_id
                    AND d.tarih BETWEEN t.tarih + 240 AND t.tarih + 320)
ORDER BY t.tarih;                                          -- 29 satır (185, 188 dahil)
```

Created_at sinyalinin SQL eşdeğeri (takas-yakınlık; import dilimleri hariç) —
canlıda koşuldu, **0 satır** (betik çıktısıyla aynı):

```sql
-- (o) |created_at::date − swap(tarih)| ≤ 7 gün  →  güçlü ters-girme şüphesi
--     swap = make_date(yıl, GÜN, AY)  (kolon sırasına dikkat: gün önce gelir)
WITH olay AS (
  SELECT 'dogum' t, d.anne_id kim, d.yavru_kupe yk, d.tarih, d.created_at c FROM dogum d
  UNION ALL SELECT 'tohumlama', hayvan_id, NULL, tarih, created_at FROM tohumlama
  UNION ALL SELECT 'kizginlik', hayvan_id, NULL, tarih, olusturma FROM kizginlik_log
  UNION ALL SELECT 'vaka', animal_id, NULL, start_date, created_at FROM cases
  UNION ALL SELECT 'uygulama', hayvan_id, NULL, tarih, created_at FROM uygulama_log
), filtre AS (
  SELECT * FROM olay
  WHERE c::date NOT IN (DATE '2026-05-09', DATE '2026-05-27', DATE '2026-06-01')
    AND tarih IS NOT NULL
    AND EXTRACT(day FROM tarih) BETWEEN 1 AND 12
    AND EXTRACT(day FROM tarih) <> EXTRACT(month FROM tarih)
)
SELECT count(*) swap_suphesi FROM filtre
WHERE ABS(c::date - make_date(EXTRACT(year FROM tarih)::int,
                              EXTRACT(day FROM tarih)::int,
                              EXTRACT(month FROM tarih)::int)) <= 7;   -- 0
```

## Önerilen düzeltme listesi (uygulama YOK — onaya)

1. **Buzağı 32:** `dogum` olayı eksik; `hayvanlar`'da anne bağlantısı yok.
   Öneri: dogum kaydı ekle (anne=156, 2025-09-05) + `hayvanlar.anne_id`'yi 156'ya bağla.
2. **Buzağı 51 / anne 195 çakışması (root R1):** kupe 31 (2025-08-09) ve kupe 51
   (2025-11-17) ikisi de anne 195'e biniyor (100 gün) — sahip defteriyle teyit
   etmeli: hangi buzağı 195'in? Kupe 51'in `hayvanlar.anne_id`'si (a67cd118) bu
   teyitle doldurulmalı; yanlış olan atama düzeltilmelidir.
3. **185 ve 188 (Eyl-2025 doğumları):** doğum kaydı + buzağı girişi yapılmamış;
   tohumlama kanıtı defteri doğruluyor (185: 2024-11-27 +285g, 188: 2024-12-12
   +270g = 2025-09-08). Öneri: defterden doğum olayı + buzağı girilmeli (ya da
   bu doğumlar kayıt dışı kaldıysa tohumlama "Doğum Yaptı" sonuçları gözden
   geçirilmeli).
4. **Buzağı 55 çift kayıt:** `anne_id` NULL olan mükerrer `dogum` satırı
   silinmeli (doğru kayıt anne=196, 2025-12-04 zaten var).
5. **Buzağı 59 ve 60:** 5748 DB'de mevcut (54f31c94) → 59'un anne bağlantısı
   kurulmalı; 60 için defter "7125" = 904 diyor ama 904 aynı zamanda #15'teki
   buzağı 44'ün annesi olarak kayıtlı (38 gün arayla iki doğum imkansız) —
   44/60 anne atamaları tek kararda netleştirilmeli.
6. **11 doğumda `anne_id` NULL:** anneler 177, 107, 179, 159, 161, 106 DB'de
   hiç yok (sürüden çıkmış + import edilmemiş olabilir). Sahip kararı: bu
   anneler hayvan olarak mı eklenecek (ÇIKTI durumuyla) yoksa boş mu kalacak?
7. **Tohumlama→doğum aralığı sapmaları:** 191 (145g) ve 167 (215g) kesin hata —
   ya tohumlama ya doğum tarihi yanlış (defterden teyit gerekli). 134 (302g) ve
   176 (311g) sınırda — tohumlama tarihi teyidi önerilir.
8. **Sistemik:** 29 adet "Doğum Yaptı" sonucu, karşılığında doğum kaydı olmayan
   tohumlama var (çoğu uygulama-öncesi 2022–2024 geçmişi). Toplu temizlik/düzeltme
   sahibin kararı.
9. **RPC dışı düzenleme riski:** kupe 51→31 değişikliği `islem_log`'a düşmemiş.
   Hayvan kayıtlarının RPC üzerinden güncellenmesi (iz sürülebilirlik) önerilir.
10. **Test hayvanları** ("Test inek cabbar" vb.) prod verisinden çıkarılabilir
    (ayrı sahip kararı; `cop_kutusu` şu an boş, silme akışı test edilmeli).
11. **Önlem (giriş katmanı):** bu denetim DB'de hasar bulmadı ama Android
    Firefox `<input type="date">` riski sürüyor. İstenirse ayrı görev: tarih
    girişinde metin-biçimli doğrulama / bölgesel-bağımsız takvim gösterimi.

## Kapsam notları ve sınırlar

- "Kuruya ayırma" olayı DB'de ayrı bir tip olarak tutulmuyor → taranamadı
  (zarfın 3. sorusundaki tek karşılanamayan kategori).
- `hastalik_log` ve `tedavi` tabloları prod'da boş; tarama `cases` +
  `uygulama_log` üzerinden yapıldı.
- 2026-05-09 öncesi DB kaydı yok (uygulama kabul tarihi); defterin
  Eyl-2025–Nis-2026 dilimi DB'ye May-Haz-2026'da girilmiştir.
- Analiz betiklerindeki Pyright "Optional operand" uyarıları geçici betik
  kodundadır (çalışma anında tarih alanları süzgeçlerle garanti); koşum
  hatasız, repo ürün koduna dokunulmadı.
- v1'deki iki düzyazı hatası bu sürümde düzeltildi: "5748 hayvanlar'da yok"
  (doğrusu: 5748 DB'de VAR, bağlantı eksik) ve satır 38'in v1 betik çıktısında
  yanlışlıkla KY görünmesi (raporda zaten UY verilmişti; betik de artık UY
  üretiyor).
