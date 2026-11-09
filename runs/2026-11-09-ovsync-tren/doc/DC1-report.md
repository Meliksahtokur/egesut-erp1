⟦ss-sub model=sonnet effort=medium rol=ss-worker iş=ovsync-tren N5 DC1 domain-rules/rpc-reference/ui-map belge güncellemesi⟧
sonuc: TAMAM
commit: cab8885 `ovsync-tren N5 DC1: domain-rules/rpc-reference/ui-map` (yalnız 3 belge dosyası; push yok)
BOYUT: bütçe 350 · gerçek 169 net (+193/−24, belge; üretim kodu 0) · bütçe içinde
Gelen iş denetimi: bulgu yok. (Not: PLAN D9 ile "tek DDL" gevşedi; belge `cases.ovsync_bagimsiz` ikinci kolonu içeriyor.)

## Değişen / eklenen §
domain-rules.md (7 § + 1 başlık satırı + 1 komşu çelişki):
- §5 başlık + madde 6: doğum sonrası PG "UYGULAMA BEKLİYOR" → uygulandı (bayrak `dogum_sonrasi_pg_gorev_aktif`=0, ilk yavru anne görevi 5 / toplam 12; =1 → 8 / 15). Eski "2.Gün·11.Gün·25.Gün" satırı migration gövdesine göre d2·d25·d39 olarak düzeltildi (M1:136-138, CONFIRMED).
- §18.2 görev doğumu tren−2 + `p_hemen` (G7/G9/bastan).
- §18.3 başlangıç = tren günü, öne çekme ≤2 gün (kural günü değişmez).
- §18.9 (komşu çelişki, çelişen eski cümle kalmasın diye) yeniden başlat hedefi bayrak açıkken tren günü − 2 / `p_hemen`.
- §18.10 Ovsync görevleri genel ertelemenin dışında: Ovsync görevi tanımı (R5), K4–K7, K10; "Kalan Günleri Kaydır" cümlesine aşama dalı notu.
- §18.15 "Ovsync uygula" → K8 sorusu (Trene bin ön seçili; tren=bugün tek seçenek, R4).
- §18.18 hastalık günü → bağımsız (K9; `ovsync_tren` NULL + `ovsync_bagimsiz` true, `tren_ayrildi`).
- §18.19 "UYGULAMA BEKLİYOR" → UYGULANDI; R1–R20/RL özeti: ritim+çapa, üyelik, kalıcı bağımsızlık işareti `cases.ovsync_bagimsiz` (işaretli vaka çapa değişimi/yeniden hedefleme dahil hiçbir yoldan trene girmez; bayrak kapalıyken açılan eski vaka işaretsiz, açılışta R14 ile bağlanabilir), 7 K8 yolu, aşama/K5 birikimli, K6, toptan erteleme (yalnız bugünden itibaren üyesi olan ilk ritim günü `ONCEKI_TREN_VAR` RL-16; ileri D0'lı aşama 0 N gün kayar RL-14; aşama 2 PG48/BASTAN seçimi; belirsiz üye düşer, onay kapalı), K11, R14, R10/R19, R15, R20.
Numara/başlık değişmedi (karar7 testinin tuttuğu "18. **Hastalık = Ovsync içinde gün (karar 10" satırı aynen).

rpc-reference.md: yeni bölüm "Ovsync Treni" (Ovsync Takip ile Hayvan Takip arasında): 10 yeni RPC + 3 imza değişikliği tablosu + gövdesi değişen RPC listesi + iç yardımcılar/kolon/ayar. Kaynak migration dosya:satır (gövde, MEASURED yeniden grep):
ovsync_tren_onizle M4:545 · ovsync_tren_listele M7:65 · ovsync_tren_ertele_onizle M7:249 · ovsync_tren_ertele M7:267 · ovsync_hayvan_ertele M6:251 · ovsync_pg48_tohumla M6:333 · ovsync_bastan_baslat M6:399 (4. parametre `p_hedef`, RL-15) · ovsync_tren_yeniden_hedefle M8:19 (`belirsiz_asama`/`belirsiz_sayisi` M8:102-103) · ovsync_tren_ayar_guncelle M8:113 · dogum_sonrasi_pg_hatirlatma M1:193 · start_first_service_protocol M4:38 · _ovsync_baslat_gorev_kur M3:38 · _acik_disi_gorev_kur M3:154. Alanlar sözleşme raporu (UB-sozlesme-report) + gövde RAISE/dönüş satırlarıyla çapraz okundu; uydurma alan yok. Yazdığı tablolar: gövdedeki doğrudan DML + alt RPC zinciri ayrı yazıldı.

ui-map.md: yeni bölüm "Ovsync treni" (`js/ovsync-tren.js` modülü, tek tıklama dinleyicisi, 22 satırlık yüzey tablosu: veri çekimi, tren başlığı, ilk-başlık toptan düğmesi, aşama aksiyonları, bağımsızlar bloğu, toptan modal, tren ayarı paneli, K8 modal + 7 giriş yolu V2–V6/G7/G9, görevler ekranı "Ovsync ekranında düzenle →", çoklu atlama notu, vaka kartı kaydır aşama dalları, K11 sheet, 🔔 doğum PG + rozet) + mevcut takip ekranı bölümünde "dalga başlığı" satırına bayrak-açık notu. Satır no yok; her sembol `dosya:sembol` biçiminde.

## Çelişki / SORU
Yok. (PLAN R1–R20'de olmayan RL-11..18/RD9 ruling'leri belgeye progress.md kaynaklı işlendi; PLAN.md'ye işlenmesi root kaleminde, L-DB-DONE notu.)

## Run kanıtı
Komut 1 (kanca çıplak koşuma izin vermedi; betik `$HOME/tmp/dc1/run1.sh` içinde aynı komut, `ram-ultracode exec --class test --wait 600 -- bash $HOME/tmp/dc1/run1.sh` ile):
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && NODE_PATH=~/egesut-erp1/node_modules node --test tests/unit/domain-rules-karar7.test.js 2>&1 | tail -5
rc: 0
ℹ fail 0
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
ℹ duration_ms 103.690781
```
(ek, aynı betik: `node --test tests/unit/hayvan-takip-belge.test.js` → `ℹ pass 7`, `ℹ fail 0`.)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && git diff --stat HEAD~1 HEAD
rc: 0
 .harness/references/domain-rules.md  | 87 ++++++++++++++++++++++++---------
 .harness/references/rpc-reference.md | 94 ++++++++++++++++++++++++++++++++++++
 .harness/references/ui-map.md        | 36 +++++++++++++-
 3 files changed, 193 insertions(+), 24 deletions(-)
```
Ek ölçüm: `python3 -m unittest tests.harness.test_patterns` ui-map anchor testi — yeni eklenen hiçbir anchor eksik değil; kalan 4 eksik (`index.html:m-geri-al`, `js/api.js:ovsync_hastalik_gunu_ekle`, `js/forms.js:islemGeriAl`, `js/forms.js:openGeriAl`) HEAD'deki eski satırlardan, benim değişikliğim değil (MEASURED `git show HEAD~1:… | grep`). `test_repository_validate_loads_pattern_index` eski goal dosyalarından kırmızı (taban).

## Kırıntılar
- assumption: PLAN :554 "ilk yavru anne görevi 5" ile uyumlu olarak toplam 12 (5+7) yazıldı (M1:183 `CASE … ELSE 5 END + 7`).
- open_item: rpc-reference'taki imzalar kabul DB'si + migration gövdesine dayanır; prod apply sonrası canlı şema probe'u (anon ACL dahil, L-DB-DONE açık kalem 1) ayrıca gerekli.
- open_item: ui-map anchor testindeki 4 eski eksik (yukarıda) ayrı belge-bakım kalemi.

## ROOT-KABUL (2026-11-09)
Nokta-ölçüm: domain-rules "2·11·25 PG" → "d2·d25·d39" düzeltmesi sahip kararı satırıyla (11b48bc:177) ve sapma tablosu ❌2 (d11 20260628000001 ile kaldırıldı) ile tutarlı; gövde 20261110100001:27,137 CONFIRMED. Ruling: T1 ayrı review açılmadı (belge kaynağı dosya:satırlı sözleşme raporu; sahip demosu ve DM2 ek doğrulama) — maliyet: rpc-reference ayrıntı hatası DM2/sahip demosuna kalır. N5 KABUL, kabul SHA cab8885.
