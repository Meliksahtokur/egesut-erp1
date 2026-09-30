# DONE — T-95..T-100 diyagram review

1. **Profil:** `luna/max` doğrulandı: `gpt-5.6-luna`, `model_reasoning_effort=max` [OBSERVED: `ps -eo args= | rg 'codex --.*model=gpt-5.6-luna.*model_reasoning_effort=max'`]. Dal `ovsync-takip`, HEAD `40feed3c6b1e5da55b44ba998618fdb24a5ee250` [OBSERVED: `git rev-parse --abbrev-ref HEAD && git rev-parse HEAD`].

## 2. Blok tablosu

| Blok | Kapsama | Doğruluk | Mermaid |
|---|---|---|---|
| T-95 | ✔ — üç adım, iki görev tipi, yazmasız red ve UNIT↔DB kenarı çizilmiş [CONFIRMED `diyagramlar.md:24-55`; `test-senaryolari.md:795-801`] | ✔ — `TAKIP_YENIDEN_SECILEMEZ` ve `SECIM_TANIMSIZ` doğru [CONFIRMED `plan.md:301`] | ✔ — alt grafikler, yönler ve sınıflar statik kontrolde tutarlı [OBSERVED `rg -c '^```mermaid'` / `rg -c '^flowchart LR'`] |
| T-96 | ✔ — iki XOR ihlali ve SUTTEN_KESME görev-tipi red yolu ile hiçbir yazma yolu var [CONFIRMED `diyagramlar.md:67-98`; `test-senaryolari.md:803-809`] | ✔ — `GIRIS_CIFT_ANLAMLI` ve `MUAYENE_GOREV_TIPI_UYUMSUZ` plan/katalogla birebir [CONFIRMED `plan.md:298`] | ✔ — kırmızı red ve güvenli yazmasız düğümler doğru ayrılmış [OBSERVED statik Mermaid yapısı] |
| T-97 | ✗ — tam `p_tohumlama_id` fixture'ı ve üç çağrıda aynı kimlik gösterilmemiş; bu nedenle bayrak red kapısının XOR'dan sonra geldiği kanıtlanmıyor [CONFIRMED `diyagramlar.md:110-137`; `test-senaryolari.md:814-817`] | ✗ — düzeltilmiş katalogdaki “red bayrağa gelir, `GIRIS_CIFT_ANLAMLI` beklenmez” sınırı diyagramda yok [CONFIRMED `test-senaryolari.md:814-816`] | ✔ — statik yapı tutarlı; tam tarayıcı render'ı aşağıdaki ortam sınırı nedeniyle ölçülmedi |
| T-98 | ✗ — fixture (a)'nın izinli hata kümesi ve fixture (b)'nin deterministik sonluk kurulumu akışa doğru bağlanmamış [CONFIRMED `diyagramlar.md:159-187`; `test-senaryolari.md:822-825`] | ✗ — fixture (a) doğrudan yalnız `BOS_DUZELTME_KOSUL` düğümüne gidiyor; katalog `{TOH_SONUCLU, BOS_DUZELTME_KOSUL}` kabul ediyor [CONFIRMED `diyagramlar.md:165-166,181`; `test-senaryolari.md:824`] | ✔ — kırmızı/yeşil sınıflar ve akış yönleri statik kontrolde tutarlı |
| T-99 | ✔ — PG onayıyla kapanış, INSERT ve geri-al sonrası kalıcılık/ters kanıt dalları var [CONFIRMED `diyagramlar.md:203-247`; `test-senaryolari.md:827-833`] | ✔ — `geri_alindi_at`, `PG` nedeni ve yeni takip/OVSYNC ürünü yokluğu doğru [CONFIRMED `plan.md:385-387`] | ✔ — red/başarı ayrımı ve kesikli ters kanıt kenarları tutarlı [OBSERVED statik Mermaid yapısı] |
| T-100 | ✗ — katalogdaki H3 `pg_get_functiondef` kaynak kanıtı adımı diyagramda yok [CONFIRMED `test-senaryolari.md:835-841`; `diyagramlar.md:265-286`] | ✔ — bayrak-bağımsız eski-yol kapanışı, `YENI_TOHUMLAMA`, `OZELLIK_KAPALI` ve hayvan kilidi beklentisi doğru yazılmış [CONFIRMED `diyagramlar.md:267-274`; `plan.md:386-392`] | ✔ — statik yapı tutarlı; tam render ortam nedeniyle `UNMEASURED` |

**Mermaid ölçüm sınırı:** `mmdc` 12.0.0 bulundu ancak tek blok render denemesi `exit=1` ile `chrome-headless-shell` eksikliğinde durdu [OBSERVED: `awk -v want=1 ... | mmdc -q -i - -o - >/dev/null`]. Bu, kaynak diyagram bulgusu değil; tam render sonucu `UNMEASURED` bırakıldı. Altı Mermaid bloğu ve altı `flowchart LR` başlığı statik olarak ölçüldü [OBSERVED: `rg -c '^```mermaid'` = 6; `rg -c '^flowchart LR'` = 6].

## 3. Katalog sonrası üç düzeltme noktası

| Nokta | Uyum | Kanıt |
|---|---|---|
| T-97 — tam `p_tohumlama_id`, aynı kimlik, red bayrağa ait | ✗ | Diyagram yalnız `p_secim` modlarını gösteriyor [CONFIRMED `diyagramlar.md:111,123-131`]; kanonik ön koşul tam kimlik ve bayrak red sınırını ister [CONFIRMED `test-senaryolari.md:814-816`; `plan.md:288-300`]. |
| T-98 — (a) izinli red kümesi; (b) `treatment_date`/`created_at` sırası | ✗ | Diyagram fixture (a)'yı tek `BOS_DUZELTME_KOSUL` dalına bağlıyor [CONFIRMED `diyagramlar.md:181`], fixture (b)'de yalnız “son değil” diyor [CONFIRMED `diyagramlar.md:182`]; katalog iki düzeltmeyi açıkça normatif yapıyor [CONFIRMED `test-senaryolari.md:822,824`]. |
| T-100 — H3 `pg_get_functiondef` kaynak kanıtı | ✗ | Diyagram sonuç/ters kanıt düğümlerini çiziyor ama kaynak-gövde okuma adımı yok [CONFIRMED `diyagramlar.md:268-286`]; katalog bu adımı zorunlu kılıyor [CONFIRMED `test-senaryolari.md:839`]. |

## 4. Bulgu listesi

1. **ÖNEMLİ — T-97 kimlik fixture'ı ve guard sınırı eksik.** `t97_ui` yalnız `p_secim` değerlerini içeriyor; tam `p_tohumlama_id` ve tüm çağrıların aynı kimliği kullandığı gösterilmiyor [CONFIRMED `diyagramlar.md:111`]. Kanonik T-97 bunu zorunlu kılıyor ve red'in `OZELLIK_KAPALI` kapısından gelmesini, `GIRIS_CIFT_ANLAMLI` beklenmemesini söylüyor [CONFIRMED `test-senaryolari.md:814-816`].
2. **ÖNEMLİ — T-98 düzeltilmiş fixture dalları diyagramla eşleşmiyor.** Fixture (a) katalogda `{TOH_SONUCLU, BOS_DUZELTME_KOSUL}` izinli kümesidir; diyagramdaki fixture (a) kenarı yalnız `t98_red`e gider, o düğüm yalnız `BOS_DUZELTME_KOSUL` yazar [CONFIRMED `diyagramlar.md:165,181`; `test-senaryolari.md:824`]. Fixture (b) için katalogdaki `treatment_date`, eşitlikte `created_at` sırası da diyagramda yok; düğüm yalnız “son değil” der [CONFIRMED `diyagramlar.md:159-164,182`; `test-senaryolari.md:822`].
3. **MİNÖR — T-100 H3 kaynak kanıtı eksik.** Diyagram `_takip_kapat` için “hayvan kilidi ALMAZ” ve `40P01/55P03` yokluğunu sonuç olarak çiziyor [CONFIRMED `diyagramlar.md:269-274`], ancak katalogda eklenen `pg_get_functiondef` ile gövdeyi okuyup `FOR UPDATE`/`LOCK` kalıbını arama adımı bulunmuyor [CONFIRMED `test-senaryolari.md:839`].

T-95, T-96 ve T-99 için kapsam/doğruluk bulgusu yoktur. Ürün kodu, plan, katalog, DB, commit, merge veya push değiştirilmedi; zarf gereği yalnız bu DONE dosyası yazıldı [OBSERVED `git status --short -- <DONE yolu>`].

## 5. HÜKÜM: DÜZELTME

## 6. Re-check

1. **T-97 — KAPANDI.** Kanıt: tam `p_tohumlama_id` fixture'ı dört çağrının tümüne aynı kimlikle bağlanıyor; XOR geçişinden sonra red kapısı `OZELLIK_KAPALI`, `GIRIS_CIFT_ANLAMLI` değil [CONFIRMED `diyagramlar.md:110-138`; `test-senaryolari.md:814-816`].
2. **T-98 — KAPANDI.** Kanıt: fixture (a) `{TOH_SONUCLU, BOS_DUZELTME_KOSUL}` izinli red kümesine, fixture (b) ise `treatment_date` ve eşitlikte `created_at` ile deterministik yeni kayda bağlanıyor [CONFIRMED `diyagramlar.md:162-200`; `test-senaryolari.md:822-824`].
3. **T-100 — KAPANDI.** Kanıt: `pg_get_functiondef` ile `FOR UPDATE`/`LOCK` kaynak taraması birincil H3 kanıtı olarak çizilmiş; `40P01`/`55P03` yokluğu açıkça destekleyici ve tek başına yetersiz etiketlenmiş [CONFIRMED `diyagramlar.md:286-301`; `test-senaryolari.md:839-840`].

**Yeni HÜKÜM: KABUL** — üç kaynak düzeltmesi kapandı; tam Mermaid render sınırı önceki §2'deki `UNMEASURED` olarak korunur.
