# DONE — Plan düzeltmesi 3 (plan v3 → v4) — luna re-review D1–D8 + ek kalemler 11/12

**Sonuç: TAMAM** (12/12 kalem; kalem 7'nin "katalog dosyasına doğrudan yazım" yarısı yetki-gereği plan maddesine devredildi — aşağıda).

Plan: `docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md` @ **v4** (714 → 796 satır).
Zarf: `runs/2026-09-28-ovsync-takip/plan-fix3-GOREV.md` + dağıtan ek kalemleri (11: D1-UI, 12: göreli gün).

## Kalemler (1–12)

1. **D1 — KRİTİK, mimari: YAPILDI (P2b).** Genel `tohumlama_sonuc_gebe` Bekliyor-only KALIR (govde dokunulmaz davranış-bitişikliğiyle). Ortak gövde `_tohumlama_gebe_uygula(p_tohumlama_id, p_bos_duzeltme)` dahili çekirdeğine çıktı; REVOKE PUBLIC/anon/**authenticated** (yalnız sarmal). `p_bos_duzeltme=true` koşul seti (5'in HEPSİ): yalnız sarmal muayene kolu p_secim='GEBE' + görev TAKIP_MUAYENE + hedef = SON tohumlama + sonuc='Boş' + bağlı açık takip zinciri; aksi `RAISE 'BOS_DUZELTME_KOSUL:{...}'`. Audit (islem_log GEBE_ATAMA + `bos_duzeltme{eski_sonuc, bos_atama_tarihi}` bloğu) + FOR UPDATE + GEBE_BULUNDU kapanışı TEK transaction. GEBELIK_KONTROL yolu Bekliyor → mevcut kol (`p_bos_duzeltme=false`). **D1 yan-etki tablosu özeti** (plan P2b'de tam tablo):

   | Boş atamasının etkisi | Düzeltmede akibeti |
   |---|---|
   | `tohumlama.sonuc='Boş'` | GERİ ALINIR → 'Gebe' |
   | `hayvanlar.tohumlama_durumu='Boş'` | GERİ ALINIR → 'Gebe' |
   | Açık GEBELIK_KONTROL/TOHUMLAMA_HAZIRLIK iptali | GERİ ALINMAZ (muayene gerçekleşti; tarihsel doğru) |
   | `islem_log TOHUMLAMA_SONUC` kaydı | DOKUNULMAZ — Boş giriş tarihinin kaynak izi (D1-UI okur; geri_al işlenmez) |
   | `PERFORM _acik_disi_gorev_kur` | GERİ ALINACAK ŞEY YOK — TAKIP kolunda zaten atlanırdı (DEGISMEZ 1) + Bekliyor döneminde de doğmazdı ((i) bloğu) |

   Prova: T-05 Gebe varyantı + satır satır geri-alınma kanıtı + genel RPC'nin Boş'u hâlâ reddettiği + çekirdeğe REST red (P2b kabul maddeleri).
2. **D2: YAPILDI (P1).** S2 CTE `gebelik_muayene_listele`'nin 5 predicate'inin TAMAMINI taşır: sonuc='Bekliyor' + `tarih <= CURRENT_DATE - _ayar(40)` + Dişi/Aktif/kısır-değil + son-tohumlama (tarih DESC, created_at DESC) + **30 g tamamlanmış-cooldown** `NOT EXISTS (kaynak='GEBELIK-KONTROL-'||t.id AND tamamlandi AND tamamlanma_tarihi >= CURRENT_DATE-30)` [20260925000002:314-320 — v3'te eksikti]. T-45: cooldown'a giren + girmeyen hayvanla fark=0.
3. **D3: YAPILDI (P2b + P8 + P11).** `p_secim` görev tipine bağlı açık tablo: GEBELIK_KONTROL {GEBE, OVSYNC, PG, TAKIP, ERTALE}; TAKIP_MUAYENE {GEBE, OVSYNC, PG, ERTALE}. DB guard CASE; UI `_muayeneSecimleri(gorevTipi)` aynı tablo; P11 senkron testi migration CASE metnini okuyarak kilitler; tablo dışı → `SECIM_TANIMSIZ`.
4. **D4: YAPILDI (P3b + P10 + A2).** Üç PG RPC'si (`hizli_uygulama`, `seans_tamamla`, `bulk_ilac`) her birinde yazmadan ÖNCE PG_KAPI + TAKIP_ACIK birleşik PREFLIGHT (hızlı yolun `20260923000004:134-149` sırası korunur; takip kontrolü tetikleyiciye bırakılmaz — tetikleyici güvenlik ağı kalır); bulk'ta `v_pg_kapilar` deseni genişletilir → hayvan-bazlı onay listesi `{hayvan_id, pg_kapi_karar, takip_acik, takip_bilgi}`; tek retry yalnız onaylanan satırları aynı transaction'da kapatır/uygular; stok düşümü uygulanan satır sayısından. A2 akış haritası üç ayrı düğüme açıldı.
5. **D5: YAPILDI (P2b + P2a + T-72).** Kilit sözleşmesi: durum kontrollerinden ÖNCE, sabit sıra `tohumlama → hayvanlar → gorev_log` FOR UPDATE (deadlock önleme; çekirdek + `_takip_gorev_kur`/`_takip_kapat` aynı sırada; mevcut gebe RPC'nin kilit-sonra-kontrol deseni çekirdekte tersine çevrilir). T-72 iki-oturum provası tek kazanan (ikincisi kilitte bekler → kapalı/sonuçlu görür → red).
6. **D6: YAPILDI (P7 + P11).** P7 Files'a eklendi: `tests/unit/ovsync-pg-ui.test.js` (:27-29 exact liste → 4'lü liste, kırmızı→yeşil) + `tests/unit/gorev-kat-filtre.test.js` (C3-1/2/5; `_planliUremeTipler` türetim kararını izler; C3-6 sayı kanıtı değişmez). P11'e D6 kanıt testi.
7. **D7: YAPILDI — plan maddesi olarak (P12 1. adım).** Katalog hizalama `test-senyolari.md` P12'nin 1. adımı + **P12/P13 PASS ön koşulu** olarak yazıldı; KATALOG GÜNCELLEME listesi 14 maddeye çıkarıldı (12–14: T-45 cooldown, T-61 farm_id, v4 yeni senaryolar). **NOT:** zarfın "Kataloğu SEN düzeltme" ifadesine rağmen yazma listesi katalog dosyasını içermiyordu ve dağıtan ek kalemde "yazma listen değişmedi" dedi → dosyaya yazılmadı (liste-dışı YASAK); maddenin kendisi kuruldu, uygulayıcı (test koltuğu) yazar. [gate kırıntısı 2026-09-29]
8. **D8: YAPILDI — ölçüldü + karar işlendi.** **Ölçüm çıktısı [OBSERVED, demo, salt-okuma, 2026-09-29]:**
   ```
   psql (demo): SELECT column_name FROM information_schema.columns
     WHERE table_schema='public' AND table_name='gorev_log' AND column_name='farm_id';
   → 0 satır (kolon YOK; gorev_log toplam 22 kolon)
   psql (demo): 8 tablo taraması (tohumlama, gorev_log, cases, hayvanlar,
     treatment_days, treatment_day_uygulamalar, islem_log, stok) → HİÇBİRİNDE farm_id YOK
   ```
   **Karar (§14):** mevcut tabloya kolon EKLENMEZ → P2a `_takip_gorev_kur` INSERT'inden damga ÇIKARILDI; P1 CTE'lerinde farm_id predikatı hiçbir tabloya yazılmaz ("uygulayıcı teyit eder" koşulu karara dönüştü); DEGISMEZ 8 güncellendi; T-61 doğrulaması "yokluğun kanıtı"na çevrildi.
9. **Kalan KISMİ'ler: YAPILDI.** **#16 ölçüm çıktısı [OBSERVED, demo pg_proc, salt-okuma]:**
   ```
   cases'e INSERT yapan fonksiyonlar (pg_get_functiondef taraması):
     _vaka_ac_tek(p_hayvan_id text, p_disease_id uuid, p_notes text, p_tarih date)
     kizginlik_vaka_ac(p_kizginlik_id text, p_tani text, p_tohumlama_id text, p_notlar text)
   _vaka_ac_tek'i çağıranlar:
     create_case(p_animal_id text, p_disease_id uuid, p_notes text)  ← ELLE vaka aç RPC'si
     start_first_service_protocol(p_gorev_id uuid)
     vaka_toplu_ac(p_animal_ids text[], p_disease_id uuid, p_items jsonb, p_sablon_id uuid,
       p_notes text, p_tarih date, p_tohumlama boolean, p_tohumlama_gun_offset integer,
       p_tohumlama_saat text, p_tohumlama_cakisma text)
   hastalik_kaydet → YOK (şemada da JS'te de)
   ```
   Plan P3b/P10/P13'e kesin adlar işlendi; `hastalik_kaydet` adayı silindi; `vaka_toplu_ac` kapı listesine EKLENDİ (v3'te yoktu); `kizginlik_vaka_ac` kapsam dışı notu. Review kapanış tablosuna **"v4 kapanış" sütunu** eklendi — 17 bulgunun tamamı KAPANDI/TAMAM (#1 D4, #3 D1, #5 D3, #9 D5, #11 D2, #13 D8, #16 #16-ölçüm ile; kalanlar v3'te kapandı, değişmedi).
10. **Başlık v4 + matris + izlenebilirlik: YAPILDI.** Başlık v4 + değişiklik not bloğu; kapsama matrisine 4 yeni satır (D1 geri-alınma, D1-UI iki satır, D4 üç-yol, göreli gün) + T-45/T-61/T-72 notları; izlenebilirliğe "§10e / re-review D1–D8" ve "kalem 11/12" satırları. **SPEC çelişkisi ÇIKMADI** ("SPEC ÇELİŞKİLERİ durumu" #4).
11. **D1-UI (dağıtan ek kalemi, design.md §10e D1-UI): YAPILDI (P9 + P2b + P11 + P12).** `_uremeTohumlama` [js/ui.js:5978-6032, satır deseni :6018] — düzeltilen tohumlama İKİ SATIR: üstü çizili `❌ Boş (Boş giriş tarihi)` + `✅ Gebe (takip muayenesi tarihi)`; tahmini doğum Gebe'den. **Kayıt izi ölçümü:** `tohumlama`'da sonuc-tarihi kolonu YOK [OBSERVED: `tarih, abort_tarihi, dogum_tarihi, kontrol_tarihi, sonuc`] → iz `islem_log`'dan: Boş tarihi = TOHUMLAMA_SONUC kaydının `tarih`'i; Gebe tarihi = GEBE_ATAMA kaydının `tarih`'i + `bos_duzeltme` bloğu. Çekirdek izi YAZMAK ZORUNDA (P2b D1); UI yalnız okur (`_tohumlamaGecmisSatirlari` saf yardımcısı, P11 testi); T eşlemesi (T-05 Gebe varyantı + yeni iki-satır PW senaryosu) + KATALOG GÜNCELLEME maddesi 14.
12. **Göreli gün (dağıtan ek kalemi, design.md §10e UI-R1): YAPILDI (P9b).** Yeni küçük madde P9b: `gunFarkiEtiket(tarihISO)` saf yardımcı (js/utils/helpers.js, dışa aktarılır) — Europe/Istanbul YEREL takvim günü farkı; "bugün"/"dün"/"N gün önce" (ileri tarih "N gün sonra"); Node birim testi gece yarısı/UTC sınır caseleriyle (P11 iskeleti); bağlama kalem 11 ile AYNI render noktası `:6018` (her satırın KENDİ tarihinden). Paralellik: yardımcı+test K15'ten bağımsız; ui.js bağlaması tek-yazıcı zincirinde P9 sonrası (dosya çakışması görünür kılındı). T eşlemesi + KATALOG maddesi 14.

## Yeni SPEC SORULARI

**YOK** — v4 turunda SPEC (design.md v4 §10c/§10d/§10e) ile çelişki doğmadı; uydurma cevap verilmedi. Tek nitelendirme: D7'nin yetki çelişkisi SPEC sorusu değil, zarf-içi gate'tir (yukarıda kalem 7).

## Kanıt yüzeyi

- `docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md` @ v4 (tek yazım yüzeyi)
- Kırıntılar: `.crumbs/ovsync-takip.jsonl` (5 ölçüm/karar/gate + 1 teslim satırı, role "lead")
- Ölçüm komut çıktıları: bu dosyada kalem 8/9/11 altında
- `.ss/` altına hiçbir şey yazılmadı; handoff yazılmadı (zarf yasağı)
