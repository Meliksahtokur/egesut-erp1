# E0-DB — `vaka_kalan_gunleri_kaydir` RPC (ince plan)

ROL: I-DB (E0-DB) · 2026-09-25 · Zarf: `.ss/erteleme-genel-GOREV.md` kalem E0 (S5, ÖNCELİK 1)
DB: demo psql, ref `vtzqjmazsvurxdeondmi` bağlantı anında doğrulandı. PROD yasak.
Dosya sahipliği: `supabase/migrations/20260925100001_vaka_kalan_gunleri_kaydir.sql`, bu plan,
`reports/db-validation-*.md`. `js/` YASAK (UI sonraki ajanın).

## 0. Gelen iş denetimi — KABUL (tamamlandı)

- TAI kaynak deseni `TEDAVI_SABLON_TOHUMLAMA:<case>:<sablon>` [OBSERVED demo q5, 9 satır].
- Zincir d0/d7/d8/d9/d10 (gün1 09-26 → gün2 10-03 → gün3 10-04 → gün4 10-05 → TAI 10-06 10:00)
  [OBSERVED q7, vaka 03b10e2a].
- `protokol_instance.kaynak_ref` tarih TAŞIR (`ACIK-DISI-<uuid>-YYYY-MM-DD`) AMA bu satırlar
  hayvan-seviyesi UREME rotaları; `gorev_log.protokol_instance_id` → tedavi zinciri join'i
  **0 satır** [OBSERVED q6]. Vaka-kaydırma kapsamına protokol_instance girmez (kanıtla kapatıldı).
- `vaka_kalan_gunleri_kaydir` demo pg_proc'ta YOK [OBSERVED q13: count=0] → kırmızı durum hazır.

## 1. Kapsam envanteri (kanıtla kapatıldı — SUSTA KALMADI)

| Yüzey | Eylem | Kanıt |
|---|---|---|
| `treatment_days.treatment_date` (vakada `tamamlandi=false`) | `+p_gun` | şema q2; K10 U1 |
| `gorev_log.hedef_tarih` (AÇIK `TEDAVI_GUN`+`TEDAVI_SEANS`, `aciklama->day_id` join; `hedef_saat` DOKUNMA) | `+p_gun` | q7 yapısı; K10 U2 |
| `gorev_log.aciklama->label` (yalnız `TEDAVI_GUN`, biçim-eşleşen `^Gun \d+ tedavisi - \d{2}\.\d{2}\.\d{4}$`) | tarih kısmı tazele | q7/q14 etiketler; K10 U3 |
| `treatment_day_uygulamalar.planned_date` (`uygulama_tamamlandi_at IS NULL AND uygulanmadi=false`) | `+p_gun` | q16; K10 U4 |
| AÇIK TAI (`TOHUMLAMA_PLANLI`, `kaynak LIKE 'TEDAVI_SABLON_TOHUMLAMA:<case>:%'`) | `tohumlama_gorev_ertele(id, hedef+p_gun, saat)` | q5; K10 U5 |
| `drug_administrations` | **DOKUNMA** — tarih kolonu yok (yalnız `created_at` geçmiş) | `\d` q15 |
| `cases.start_date` | **DOKUNMA** — vaka çapası (domain kural 9), "kalan günler" değil | domain-rules §13-9 |
| `protokol_instance` | **DOKUNMA** — vaka-bağlı satır yok (0 satır, yukarıda) | q6 |
| `islem_log` | INSERT `VAKA_KAYDIR` audit (immutable tablo, yalnız insert) | `\d` q16 |

Kenar durumları demo'da 0 [OBSERVED q17]: tamamlanmış-günde-uygulanmamış-seans, JSON-dışı
açıklamalı açık TEDAVI görevi, yetim açık görev, vaka başına çoklu açık TAI (yine de döngüyle
taranır — sağlamlık).

## 2. Tasarım kararları

1. **TAI yolu = `tohumlama_gorev_ertele` RPC çağrısı** (K10 U5 deseni). Gerekçe: pencere
   doğrulaması + `GECMIS_TARIH` koruması + kendi `TOHUMLAMA_ERTELE` audit'i + `ilk_hedef`/
   `toplam_erteleme_gun` soyunu devralır; K10'da 8/8 kanıtlanmış. Doğrudan UPDATE'ten üstün:
   sonucu geçmişe düşecek TAI'de RPC kenarından da reddeder (zarf "sonuç tarihi geçmişe
   düşemez" kuralı çift katmanlı korunur). Yan etkisi: gecikmiş TAI (+p_gun yine geçmişte
   kalırsa) `GECMIS_TARIH:<json>` raised → tüm vaka kaydırması geri sarılır (istenen atomlarlik).
2. **Hata ailesi** `VAKA_KAYDIRILAMAZ:<json>` (`GOREV_ERTELENEMEZ` kalıbının vaka eşi; json
   payload'lı RAISE, `tohumlama_gorev_ertele` gövdesindeki desen): `VAKA_BULUNAMADI`,
   `VAKA_ACIK_DEGIL` (status≠active), `GECERSIZ_GUN` (p_gun NULL ya da <1).
3. **Audit tipi** `VAKA_KAYDIR` (mevcut sözlükte `TOHUMLAMA_ERTELE`/`OVSYNC_ZINCIR_ERTELE_DEMO`
   kalıbının vaka-geneli; payload: case_id, gun, taşınan sayıları, önceki/sonra ilk-son tarih;
   snapshot: özet vaka görüntüsü). `ana_hayvan_id = cases.animal_id`, `ref_tablo='cases'`.
4. **Tek yönlü ileri**: `p_gun >= 1` zorunlu; tüm UPDATE'ler `+ p_gun` → tarihler yalnız ileri.
   Gün satırları için "bugün tabanı" YOK (gecikmiş zincir = ana kullanım senaryosu; K10 dersi).
5. **Tamamlanmışlara dokunma**: gün satırları `tamamlandi=false`; görevler `tamamlandi=false AND
   iptal=false`; seanslar `uygulama_tamamlandi_at IS NULL AND uygulanmadi=false` — üç koşul da
   gövdede görünür.
6. **farm_id damgası YOK**: fonksiyon yalnız UPDATE (yeni satır üretmez; islem_log audit'i
   farm_id kolonu taşımayan global log). [CONFIRMED şemalar]
7. **protocol_family GEREKTİRMEZ**: ovsync ayrımı yalnız kaynak/kaynak_ref kalıplarından
   (TAI `kaynak LIKE` eşleşmesi) türer → prod önkoşulu minimal.
8. **Gövde tek BEGIN…EXCEPTION bloğu** (WHEN OTHERS THEN `RAISE;` — orijinal SQLSTATE korunur,
   COMMIT/ROLLBACK gövde içinde YOK); transaction'ı migration dosyasının BEGIN;…COMMIT; bloğu
   taşır. RPC çağrısı (`tohumlama_gorev_ertele`) aynı transaction'da — atomik.
9. **RETURN** `{ok, case_id, gun, tasinan_gun_satiri, tasinan_gorev, tasinan_seans, tai,
   ilk_tarih, son_tarih}` — ilk/son tarih kaydırma SONRASI min/max açık gün tarihi.
   Kaydırılacak şey kalmadıysa (açıkgün/görev 0) ok:true + 0 sayıları (hata değil; UI metni
   sonraki ajanın).
10. **SECDEF + tırnaksız** `SET search_path = public, pg_temp`; `REVOKE ALL FROM PUBLIC, anon`;
    `GRANT EXECUTE TO authenticated`.

## 3. Adımlar (TDD, sıralı — her adımın kabul ölçütü)

1. **Bu plan** — kabul: dosya işlendi, kapsam tablosu kanıtlı. ✔ (bu dosya)
2. **KIRMIZI probe** (demo, salt çağrı):
   `SELECT public.vaka_kalan_gunleri_kaydir('<aktif-vaka>',2)` →
   kabul: hata `function ... does not exist` kanıtı loglandı.
3. **Migration taslağı** `20260925100001_vaka_kalan_gunleri_kaydir.sql`:
   - kabul: kendi `BEGIN;…COMMIT;`; gövde §2 sözleşmeye uygun; db-validate **PASS**
     (`scripts/db-validate.sh <taslak>` → rapor `reports/db-validation-20260925100001-draft.md`).
4. **Demo apply**: `psql -f` (migration kendi transaction'ında) +
   `supabase_migrations.schema_migrations` kaydı `statements` DOLU (tam dosya içeriği tek
   elemanlı dizi — cila serisi deseni [OBSERVED q11/q12: version 20260925000016]).
   - kabul: apply hatasız; final dosyada db-validate yeniden **PASS**
     (`reports/db-validation-20260925100001.md`); canlı gövde kontrolü: `pg_get_functiondef`
     içinde tırnaksız search_path + doğru GRANT/REVOKE + `tohumlama_gorev_ertele` çağrısı.
5. **YEŞİL kabul probeleri** (demo, her biri BEGIN…ROLLBACK — gerçek veri değişikliği YOK):
   - a. Ovsync aktif vaka `03b10e2a-…` +2 → kabul: 4 gün satırı +2, 4 GUN + 4 SEANS görev +2,
     4 seans planned_date +2, TAI 10-06→10-08 (saat 10:00); d0→d7 farkı 7, d7→d8 1, d8→d9 1,
     d9→TAI 1 DEĞİŞMEDİ (sorgu kanıtı); TEDAVI_GUN etiketleri yeni tarihli.
   - b. Normal vaka `81a4376c-…` (Metrit) +1 → kabul: açık gün 1/4/5 (+1) → 09-22/09-25/09-26;
     TAMAMLANMIŞ gün 2-3 (09-22/09-23) ve görevleri DEĞİŞMEDİ; tai=0.
   - c. Kapalı vaka `fe51de7b-…` → `VAKA_KAYDIRILAMAZ` + `VAKA_ACIK_DEGIL` kanıtı.
   - d. `p_gun=0` → `VAKA_KAYDIRILAMAZ` + `GECERSIZ_GUN` kanıtı.
   - Kabul (ortak): ROLLBACK sonrası sayımlar öncekiyle aynı (temiz geri sarma).
6. **Unit koşumu**: `NODE_PATH=/home/melik/egesut-erp1/node_modules npm run test:unit`
   → kabul: baz 1124/1127 bilinen 3 fail (bc-tarih ×2, LUNA-3); yeni fail 0.
7. **Commit** (migration + plan + 2 db-validation raporu):
   - kabul: `git status` + `git diff --cached --stat` yalnız kendi dosyalarım; gitnexus
     `detect_changes` çalıştırıldı; commit mesajı E0-DB kapsamını taşır.
8. **JSON dönüş**: `prod_onkosul` alanıyla (bkz. §4).

## 4. prod_onkosul (önden analiz — apply sonrası kesinleşecek)

- `tohumlama_gorev_ertele` + `_tohumlama_pencere`: **yalnız** `20260923000003` serisinde
  tanımlı [CONFIRMED grep: tek dosya] → prod'da VAR (zarf: 20260923*/24* uygulanmış).
- Tablolar (treatment_days, gorev_log, treatment_day_uygulamalar, cases, islem_log): eski,
  prod'da mevcut.
- Beklenen sonuç: **cila (20260925*) bağımlılığı YOK** — prod yalnız 20260923 serisi + bu
  dosyayı uygular. Canlı gövde çağrı testiyle teyit edilecek.

## 5. Yürütme sonucu (2026-09-25, I-DB)

| Adım | Sonuç | Kanıt |
|---|---|---|
| 2 Kırmızı probe | PASS — `function public.vaka_kalan_gunleri_kaydir(uuid, integer) does not exist` | ~/tmp/e0/red_probe_out.txt |
| 3 Taslak db-validate | PASS (revizyon: `LIKE '{%'` → `left(aciklama,1)='{'` — Jinja `{%` tuzası; sqlfluff TMP kayboldu) | reports/db-validation-519c2e30.md |
| 4 Demo apply + kayıt | PASS — CREATE FUNCTION/REVOKE/GRANT/COMMIT; `supabase_migrations` 20260925100001 statements n=1 len=10026; final db-validate PASS (aynı sha8); canlı gövde: proconfig `search_path=public, pg_temp` TIRNAKSIZ, prosecdef=t, anon EXECUTE=f / authenticated=t | ~/tmp/e0/apply_out.txt, q18–q21 |
| 5a Ovsync +2 | PASS — günler 09-28/10-05/10-06/10-07, aralıklar 7/1/1 aynı, TAI 10-06→10-08 (10:00), etiketler taze, audit VAKA_KAYDIR, ROLLBACK temiz | ~/tmp/e0/probe_a_out.txt |
| 5b Normal +1 | PASS — açık gün 1/4/5 +1; TAMAMLANMIŞ gün 2-3 + görevleri DEĞİŞMEDİ; tai=0 | ~/tmp/e0/probe_b_out.txt |
| 5c Kapalı vaka | PASS — `VAKA_KAYDIRILAMAZ:{"sebep":"VAKA_ACIK_DEGIL","status":"closed"}` | ~/tmp/e0/probe_cd_out.txt |
| 5d p_gun=0 | PASS — `VAKA_KAYDIRILAMAZ:{"sebep":"GECERSIZ_GUN"}` (+ bonus: olmayan vaka → VAKA_BULUNAMADI) | ~/tmp/e0/probe_cd_out.txt |
| 5f Gecikmiş TAI (bonus) | PASS — TAI geçmişe kurulumda iç RPC `GECMIS_TARIH` orijinal koduyla yayıldı, zincir geri sarıldı | ~/tmp/e0/probe_f_out.txt |
| 6 Unit | PASS — 1124/1127, fail = bilinen 3 (bc-tarih ×2, LUNA-3), yeni fail 0 | ~/tmp/e0/unit_out.txt |
| 7 detect_changes | PASS — değişen indeksli sembol 0, risk none (yeni SQL/MD dosyaları) | gitnexus stdio çıktısı |

Not: pg_get_functiondef `SET search_path TO 'public','pg_temp'` TIRNAKLI GÖSTERİR — bu
görüntüleme sanatıdır; otorite `proconfig` (tırnaksız liste, 000010 başlık notu) ve canlı
değer doğrulandı.
