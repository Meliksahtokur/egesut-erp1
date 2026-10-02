# DONE — katalog v3 review (T-95..T-100)

1. **Profil:** `luna/max` görüldü: `gpt-5.6-luna`, `model_reasoning_effort=max` [OBSERVED: `ps -eo args= | rg 'codex --'`].

## 2. Odak A — T-95..T-100

| T | Plan sadakati / hata kodu | BEKLENEN sonucu | Çakışma ve karar |
|---|---|---|---|
| T-95 | P2b seçim tablosu ile birebir; `TAKIP_YENIDEN_SECILEMEZ` ve `SECIM_TANIMSIZ:{secim,gorev_tipi}` yazımları doğru [CONFIRMED: `plan.md:301`, `test-senaryolari.md:795-800`]. | GEBELIK_KONTROL/TAKIP_MUAYENE ayrımı, yazmasız red ve UNIT↔DB tablo eşitliği plandan türetilmiş [CONFIRMED: `plan.md:301`]. | T-05/T-76 aynı ekran/seçenek yüzeyini kapsar; bu doğrudan DB guard testi değildir. Gereksiz çift değil. **KABUL** [INFERRED: `test-senaryolari.md:60-67,649-654`]. |
| T-96 | XOR ve görev tipi guard'ları doğru; `GIRIS_CIFT_ANLAMLI` ve `MUAYENE_GOREV_TIPI_UYUMSUZ` birebir [CONFIRMED: `plan.md:298`, `test-senaryolari.md:803-808`]. | İki XOR ihlali ve yanlış görev tipinde red + yazmasızlık, plan gövdesinden türetilmiş [CONFIRMED: `plan.md:298`]. | T-87'de `GIRIS_CIFT_ANLAMLI` yalnız oracle kümesinde geçiyor; doğrudan guard testi değil. **KABUL** [CONFIRMED: `test-senaryolari.md:732-738,803-809`]. |
| T-97 | `OZELLIK_KAPALI` ve dry-run sözleşmesi doğru adlandırılmış [CONFIRMED: `plan.md:332`, `test-senaryolari.md:811-816`]. | Yazma modları beklentisi doğru; ancak dry-run ve üç yazma çağrısı için tam olarak bir `p_tohumlama_id` veya `p_muayene_gorev_id` verilmesi belirtilmemiş. P2b XOR guard'ı iki kimlik de boşken red eder; P8 çağıranı kimlikli çağrı kurar [INFERRED: `plan.md:288-300,569`; `test-senaryolari.md:814-816`]. | T-46 yalnız listeleme/dry-read ve ekran kapısını test eder; T-97'nin yazma kapsamı yeni, fakat fixture'sız hali deterministik değil. **DÜZELTME — ÖNEMLİ #1**. |
| T-98 | `BOS_DUZELTME_KOSUL:{eksik...}` plan metninde var [CONFIRMED: `plan.md:304`, `test-senaryolari.md:819-824`]. | Fixture (a) `GEBELIK_KONTROL` + hedef `Boş` için katalog yalnız `BOS_DUZELTME_KOSUL` bekliyor; plan aynı yolda `p_bos_duzeltme=false` ve `TOH_SONUCLU`/**veya** `BOS_DUZELTME_KOSUL` redlerine izin veriyor [CONFIRMED: `plan.md:302,304`]. Bu nedenle beklenen sonuç plandan daha dar. Fixture (b)'de sonluk koşulu için tarih/`created_at` sıralaması da açıkça sabitlenmeli [INFERRED: `plan.md:304`]. | T-77/T-78/T-83 meşru Gebe yolları/yan etkileri kapsar; T-98'in negatif koşul seti yeni ve gereklidir. **DÜZELTME — ÖNEMLİ #2**. |
| T-99 | P3a geri-al yolunun “takibi yeniden açmama” hükmü doğru [CONFIRMED: `plan.md:390`, `test-senaryolari.md:827-833`]. | PG onayıyla kapanmış takibin `PG` nedeni korunur ve geri-al sonrası yeni takip/OVSYNC ürünü doğmaz; kapanış kalıcılığıyla uyumlu [CONFIRMED: `plan.md:390`]. | T-20 PG kapanışını, T-24 idempotent kapanışı sınar; geri-al sonrası kalıcılık ayrı davranıştır. **KABUL** [CONFIRMED: `test-senaryolari.md:113-118,195-202`]. |
| T-100 | P3a tetikleyicisinin bayraktan bağımsızlığı ve H3 “hayvan kilidi yok” hükmü doğru aktarılmış [CONFIRMED: `plan.md:391-392`, `test-senaryolari.md:835-841`]. | Bayrak kapalı eski-yol INSERT'inin takip kapatması ve `YENI_TOHUMLAMA` nedeni doğru. Fakat tek çağrıda `40P01/55P03` görülmemesi, tetikleyicinin hayvan satırı kilidi almadığını kanıtlamaz; H3 için kaynak/lock ölçümü adımı yok [INFERRED: `test-senaryolari.md:838-841`]. | T-19 olay kapanışını, T-87 tetikleyici×sarmal yarışını kapsar; bayrak-kapalı davranış yeni, H3 alt iddiası ölçümsüz. **KISMİ — MİNÖR #3**. |

## 3. Odak B — genel bütünlük

- **100 başlık ve süreklilik:** `rg -c '^### T-'` = `100`; tam sayısal başlıklar T-01..T-100, tekrar/atlama yok [LOCAL-MEASURED: 2026-09-30, integrity command].
- **Sürüm ve §S:** Katalog sürümü 3 notu satır 5'te; §S satır 791'de T-94 sonrasına, kabul matrisi satır 860'a yerleşmiş [CONFIRMED: `test-senaryolari.md:5,791-860`].
- **Üç sayı cümlesi:** DONE satır 42, katalog v2 taban satırları 4–5 ve HANDOFF satır 7, v2'nin 94'ten v3'ün 100 senaryosuna geçişini açıklıyor; bayat toplam “96” yok. Kalan `96` kullanımları yalnız T-96 başlığı ve v2 aritmetik düzeltmesinin tarihsel açıklaması [OBSERVED: targeted `rg -n '96|T-74.*96|96 senaryo'`].
- **Kapsam matrisi / kapsam dışı:** T-95..T-100 tek satırda altı yeni davranışa bağlanmış; PROD, Faz 2 ve B9 dışlamaları yeni testlerin kapsamıyla çelişmiyor [CONFIRMED: `test-senaryolari.md:860,898-906`].

## 4. Bulgu listesi

### ÖNEMLİ

1. **T-97 dry-run kimlik fixture'ı eksik:** P2b XOR sözleşmesi tam bir giriş kimliği ister; senaryo yalnız bayrağı ön koşul yapıp `p_secim=NULL` ve yazma çağrılarını kimliksiz tarif ediyor. Sonuç, beklenen `bayrak_kapali`/`OZELLIK_KAPALI` yerine `GIRIS_CIFT_ANLAMLI` olabilir veya koşum tanımsız kalır [INFERRED: `plan.md:288-300`, `plan.md:569`, `test-senaryolari.md:814-816`]. Ön koşula H ve tam bir `p_tohumlama_id` ya da `p_muayene_gorev_id` eklenmeli.
2. **T-98 hata beklentisi fazla dar:** GEBELIK_KONTROL + `sonuc='Boş'` fixture'ında plan `TOH_SONUCLU`/`BOS_DUZELTME_KOSUL` alternatifini açık bırakıyor; katalog yalnız ikincisini kabul ediyor [CONFIRMED: `plan.md:304`, `test-senaryolari.md:822-824`]. İzinli hata kümesi açıkça yazılmalı veya fixture yalnız `p_bos_duzeltme=true` koşullarından birini ihlal edecek şekilde değiştirilmelidir; “son tohumlama değil” fixture'ı tarih/`created_at` ile deterministik yapılmalı.

### MİNÖR

3. **T-100 H3 alt iddiası ölçülmüyor:** Tek eski-yol çağrısında kapanışın tamamlanması bayrak bağımsızlığını sınar, fakat tetikleyicinin hayvan satırı kilidi almadığını kanıtlamaz. H3 beklentisi source/`pg_get_functiondef` veya kilit gözlemiyle ayrı assertion yapılmalı [INFERRED: `plan.md:391-392`, `test-senaryolari.md:839-841`].

## 5. HÜKÜM: DÜZELTME

T-95, T-96 ve T-99 kabul edilebilir; T-97/T-98 düzeltilmeden katalog v3 kabul edilemez. Bu turda zarf gereği yalnız bu DONE dosyası yazıldı; kaynak katalog, plan, `.harness`, `.ss` ve `.crumbs` değiştirilmedi.

## 6. Re-check

- **T-97 — KAPANDI:** Ön koşul artık `sonuc='Bekliyor'` olan Boş-yolu H ve TAM `p_tohumlama_id`; dry-run ile OVSYNC/PG/TAKIP çağrılarının hepsi aynı kimliği taşır. Metin ayrıca `GIRIS_CIFT_ANLAMLI` beklenmediğini açıkça sınırlar [CONFIRMED: `test-senaryolari.md:814-817`; plan sözleşmesi `plan.md:288-300`].
- **T-98 — KAPANDI:** Fixture (a) artık `{TOH_SONUCLU, BOS_DUZELTME_KOSUL}` izinli red kümesini kabul eder; fixture (b) daha yeni `treatment_date`, eşitlikte `created_at` ile deterministik sonluk sırasını kurar. (b)/(c) için kesin `BOS_DUZELTME_KOSUL` ve tüm redlerde yazmasızlık korunur [CONFIRMED: `test-senaryolari.md:822-825`; plan `plan.md:304`].
- **T-100 — KAPANDI:** H3 için kapanış tetikleyici gövdesi `pg_get_functiondef` ile okunur ve `hayvanlar` satır kilidi kalıbı aranır; `40P01/55P03` yokluğu artık yalnız destekleyici kanıttır [CONFIRMED: `test-senaryolari.md:839-841`; plan `plan.md:391-392`].

**Yeni HÜKÜM: KABUL** — önceki üç düzeltme bulguyu kapattı; T-95..T-100 katalog review kapısı açık bulgu bırakmıyor.
