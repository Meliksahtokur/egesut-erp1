VERDICT: DÜZELTME

Salt-okuma rereview. Plan v3, SPEC v4 §10c/§10d ve domain-rules §14/§18 karşılaştırıldı; kod uygulanmadı.

## A — 17 bulgunun kapanışı

| Bulgu | Hüküm | Kanıt |
|---:|---|---|
| 1 | KISMİ | `docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:310-315,330-335,508-512` — dört olay için trigger/kapı gövdesi var; fakat bütün PG yolları ve onay akışı D4'teki bulk/birleşik-kapı açığı nedeniyle tam kapanmış değil. |
| 2 | KAPANDI | `docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:252,265,484` — PG kapısı `tohumlama_bos_ve_devam(p_secim='PG')` tek transaction'a taşınıyor; eski iki-RPC zinciri açıkça kaldırılıyor. |
| 3 | KISMİ | `docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:251,483`; `supabase/migrations/20260830000031_gebe_sonuc_mesaji.sql:21-27` — Gebe modu tarif edilmiş, ancak takipteki önceki `Boş` kayıt mevcut çekirdekte reddediliyor (D1). |
| 4 | KISMİ | `docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:257,502-509` — birleşik payload/sheet/retry yazılmış; mevcut PG preflight'ı ve bulk yolunun tek payload/tek onayla nasıl birleşeceği yok (D4). |
| 5 | KISMİ | `docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:250,454,481-483`; `docs/plans/2026-09-28-ovsync-takip-ekrani/design.md:299` — GEBELIK_KONTROL yüzeyi ve seçici var, fakat kesin RPC imzası `TAKIP` seçimini dışarıda bırakıyor (D3). |
| 6 | KAPANDI | `docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:446,458,460-463` — dry-run `bayrak_kapali`, seçicinin açılmaması, eski Boş davranışı ve offline fail-closed yolu yazılmış. |
| 7 | KAPANDI | `docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:256,454,463,696` — `p_saat` seçilebilir, varsayılan NULL/saatsiz ve ≥21 gün tek onay açıkça bağlanmış. |
| 8 | KAPANDI | `docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:187,194,399,424,432` — toplam KPA, `bekleyen_baslatma_takipte` ve 🔔 alt-küme eşitliği ayrıştırılmış. |
| 9 | KISMİ | `docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:248,222,265,624` — XOR ve hata kodları var; `p_tohumlama_id` yolunda hangi hayvan/tohumlama satırının kilitleneceği açık değil, T-72 kabulü tek başına kilit sözleşmesi değil (D5). |
| 10 | KAPANDI | `docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:100,249,457,666` — TOPLU_ILAC için `islem_log.snapshot.miktar` ve ürün adı kullanımı açık; “doz belirsiz” iddiası kaldırılmış. |
| 11 | KAPANDI | `docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:106,192,201,667` — `gebelik_muayene_listele` mevcut fonksiyon olarak bağlanmış; eski “migration'da yok” kalemi silinmiş. S2'nin tam predicate kopyası ise yeni D2'dir. |
| 12 | KAPANDI | `docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:563-569,709` — ground-truth replay sonrası son-kazanan gövde/ACL doğrulaması ve yenileme için ayrı manifest/sahip kapısı var. |
| 13 | KISMİ | `docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:197,214,221,307`; `supabase/migrations/99999999999999_ground_truth.sql:49-65` — §14 niyeti doğru, fakat mevcut `gorev_log` için `farm_id` damgasının live-schema kolonu doğrulanmadan emredilmesi D8'dir. |
| 14 | KAPANDI | `docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:427-432`; `.harness/references/domain-rules.md:484-487` — K14 görev eşlemesi ve hastalık adı kümesi açık; katalog değişmiyor. Mevcut test/katalog yüzeyi D6-D7'dir. |
| 15 | KAPANDI | `docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:516-551,575-625` — T-01..T-73 için katman/sahip matrisi ve P11/P12 yürütme yerleri eklenmiş. |
| 16 | KISMİ | `docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:229-337,331-332,710` — P2/P3 bölünmüş ve ana sarmal imza kesin; elle Ovsync RPC adı hâlâ “canlı şema teyidiyle” bırakılmış, bu nedenle kesin giriş envanteri kapanmamış. |
| 17 | KAPANDI | `docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:397-399,421-422,450-451,504-505,516-525,555-571` — kırmızı test adımı ilgili P maddelerinin önüne yazılmış, P13 açıkça sıralı sona alınmış. |

## B — K14/K15 ve §10d hükmü

- **K14:** `_katTipMap.ureme` içine `GEBELIK_KONTROL` ve `TAKIP_MUAYENE`, `muayene` listesinden ilk tipin çıkarılması ve hastalık kataloğunun değişmemesi plan gövdesinde doğru (`plan.md:427-428`). Ancak mevcut exact map/protocol-family testleri yeni davranışla uyumsuz; D6. Katalogdaki K15/K14 beklentileri de hâlâ eski SPEC soruları olarak duruyor; D7.
- **K15:** Aynı muayene bileşeni, jenerik `gorev_tamamla` guard'ı, GEBELIK_KONTROL için özel akış, açık görevli dashboard satırı ve görevsiz satırda hayvan detayı planlanmış (`plan.md:454,481-491`). Fakat takipte Gebe yolu mevcut `tohumlama_sonuc_gebe` guard'ı ile çalışmaz (D1), 40 g eş-küme tarifi cooldown'ı eksik bırakır (D2) ve ana RPC imzası GEBELIK_KONTROL'ün zorunlu `Takibe bırak` seçimiyle çelişir (D3).
- **§10d:** +21/+35 üretiminin kaldırılması P2c, eski açık görev temizliği P2d, `p_saat=NULL` P2b/P8 ve dashboard 40 g satırı P9'a ayrı maddeler olarak taşınmış (`plan.md:269-299,256,485-486,690-699`). `tohumlama_sonuc_bos`'un tip-bazlı açık GEBELIK_KONTROL iptali de etki analizinde belirtilmiş; muayene yolu görevi önce tamamlıyor (`plan.md:108-114`). Bu dört kararın metinsel karşılığı var, ancak K15 test/kaynak ve gerçek birleşik kapı sözleşmesi tamamlanmadığı için VERDICT kabul değildir.

## C — “Mevcut akış haritası” nokta-kontrolleri

| Nokta | Kaynak kontrolü | Hüküm |
|---|---|---|
| A1 — tohumlama sonucu | `plan.md:31-44` zinciri; `js/ui.js:11590-11599` `openTohDet`, `js/forms.js:4335-4358` `tohSonuc` ve RPC çağrıları, `supabase/migrations/20260924000001_ovsync_pg_r32_acik_disi.sql:535-566` sonuç/hayvan/görev etkileri | **DOĞRU.** Dosya:satır referansları ve ekran→fonksiyon→RPC→tablo halkaları mevcut davranışla eşleşiyor. |
| A2 — PG kapısı | `plan.md:46-57`; `js/ui.js:1432-1472` `_pgKapiHata`/`_pgKapiAc` ve `_pgKapiBosAtaUygula`; W5 ekranı ve `akis-yuruyus/NOTLAR.md` W5 notu | **DOĞRU AS-IS, DÜZELTME BEKLER.** Mevcut iki-RPC yarım durum doğru yakalanmış; fakat harita üç gerçek PG RPC'sini (`hizli_uygulama`, `seans_tamamla`, `bulk_ilac`) tek düğümde topluyor. P10 bunları listeliyor (`plan.md:508`), fakat birleşik kapı açığı D4'tür. |
| A3/A4 — gebelik görevi ve dashboard | `plan.md:59-90`; `js/ui.js:612-627,8702,8956-8973,2733-2760`, `js/forms.js:3891-3903`, `supabase/migrations/20260925000002_sessiz_siniflandirma.sql:327-374` | **DOĞRU AS-IS.** W3/W2 görüntüleriyle jenerik kapanış ve `openDet` sonucu doğrulanıyor; planın K15 to-be dalları mevcut zincirin eksik noktalarını doğru hedefliyor. S2'nin tam küme eşitliği D2 nedeniyle ayrıca düzeltilmeli. |

## D — Yeni bulgular

| # | Şiddet | Plan maddesi | Kanıt | Önerilen düzeltme |
|---:|---|---|---|---|
| 1 | **KRİTİK** | P2b/P9 | `plan.md:251,483`; `supabase/migrations/20260830000031_gebe_sonuc_mesaji.sql:21-27` mevcut çekirdeği yalnız `sonuc='Bekliyor'` kabul ediyor, oysa takip akışı önce Boş atıyor. | Takip muayenesinde son ve önceki Boş kaydı güvenli biçimde Gebe'ye çevirebilen, audit/concurrency guard'lı özel çekirdeği tanımla veya mevcut çekirdeği bu tek yetkili moda genişlet ve `GEBE_BULUNDU` kapanışını aynı transaction'da kanıtla. |
| 2 | **ÖNEMLİ** | P1 | `plan.md:192` yalnız `gebelik_muayene_listele:305-313` koşullarını sayıyor; gerçek fonksiyon `supabase/migrations/20260925000002_sessiz_siniflandirma.sql:314-320` son 30 günde tamamlanmış kontrol cooldown'ını da uyguluyor. | S2 CTE'sine cooldown dahil fonksiyonun bütün predicate'lerini birebir taşı ve T-45'te hem cooldown'a giren hem girmeyen hayvanla fark=0 kanıtı iste. |
| 3 | **ÖNEMLİ** | P2b/P8 | `plan.md:238-250` muayene `p_secim` kümesini `{GEBE,OVSYNC,PG,ERTALE}` diye sabitliyor; aynı plan `plan.md:250,454` ve `design.md:299` GEBELIK_KONTROL için `TAKIP` seçimini zorunlu kılıyor. | İmzayı görev tipine bağlı açık bir seçim tablosuna çevir: GEBELIK_KONTROL için `TAKIP` dahil, TAKIP_MUAYENE için `TAKIP` hariç; DB ve UI aynı tabloyu kullansın. |
| 4 | **ÖNEMLİ** | P3a/P3b/P10 | `plan.md:257,312-313,331,502-509` event trigger'ını ve scalar `p_takip_onay`ı tarif ediyor; `supabase/migrations/20260923000004_ovsync_pg_uygulama_kapisi.sql:134-149` PG_KAPI'yı event INSERT'inden önce yükseltiyor, `:457-494` bulk yolu olay hatasını hayvan başına yakalıyor. | Her PG çağrısı için yazmadan önce PG_KAPI+TAKIP_ACIK birleşik preflight/approval zarfını ve bulk için hayvan-bazlı onayı tanımla; tek retry yalnız onaylanan satırları aynı transaction'da kapatsın/uygulasın. |
| 5 | **ÖNEMLİ** | P2b/P12 | `plan.md:248,624` T-72'yi ister ama `FOR UPDATE`yi yalnız `p_muayene_gorev_id` satırına bağlar; `supabase/migrations/20260924000001_ovsync_pg_r32_acik_disi.sql:520-547` Boş yolunda durum kontrolü ile UPDATE arasında hedef tohumlama kilidi tarif etmez. | `p_tohumlama_id` yolunda hedef tohumlama ve ilgili hayvanı durum kontrolünden önce kilitle, `p_muayene_gorev_id` yolundaki görev kilidini ayrı belirt ve iki cihaz provasını tek kazananla sınırla. |
| 6 | **ÖNEMLİ** | P7/P11 | K14 planı `plan.md:427-428` ile iki listeyi değiştiriyor; fakat mevcut `tests/unit/ovsync-pg-ui.test.js:27-29` eski exact listeyi, `tests/unit/gorev-kat-filtre.test.js:1-4,25-65` eski `protocol_family` modelini doğruluyor. P11 yalnız yeni test dosyası öneriyor (`plan.md:520-530`). | P7/P11 yazma manifestine bu iki mevcut test/fixture güncellemesini ekle, hastalık adı kümesini ve yeni görev listesini kırmızı→yeşil kanıtıyla çalıştır. |
| 7 | **ÖNEMLİ** | P11/P12/P13 | Plan `plan.md:676-688` güncellemeyi “katalog sahibine” bırakıyor; mevcut `test-senaryolari.md:50-65,662-681` T-04/T-05/T-39/S-2..S-10 hâlâ K15 öncesi metni taşıyor. | `test-senaryolari.md` için açık sahip/madde ve kabul önkoşulu ekle, K15/§10d senaryolarını güncellemeden P12/P13 PASS verilmesini engelle. |
| 8 | **ÖNEMLİ** | P2a/P1 | `plan.md:214,221` mevcut `gorev_log` INSERT'ine `farm_id=current_farm_id()` emrediyor; tracked ground-truth `supabase/migrations/99999999999999_ground_truth.sql:49-65` tablosunda `farm_id` görünmüyor. Live schema bu salt-okuma turunda ölçülmedi. | `gorev_log` için P2a'ya information_schema canlı-kolon kapısı ekle; kolon yoksa §14'e uygun açık sahip kararı/ayrı yeni-nesne tasarımı olmadan `farm_id` INSERT'i planlama. |

