# Katalog kapsam-açığı denetimi — DONE (2026-09-30)

Zarf: ovsync-takip senaryo kataloğu (v2, T-01..T-94) ↔ plan v7 davranışları kapsam denetimi.
Karar: **açıq VAR** → 6 gerçek senaryo yazıldı (T-95..T-100); uydurma doldurma yok (fail-closed kuralına uyuldu — her yeni senaryonun beklenen sonucu planın açık gövde maddesinden birebir türetildi).
Yazılan dosyalar: `test-senaryolari.md` (§S bölümü + kabul matrisi satırı + başlık sürüm notu), `test-uygulanabilir-DONE.md` (yalnız sayı cümlesi), `test-uygulanabilir-HANDOFF.md` (yalnız sayı cümlesi), bu rapor.

## 1. Kaynaklar (hedefli okuma)

- `.harness/references/domain-rules.md` — tam (§18 Ovsync/PG + §16 geçmiş + §17 tarih).
- `docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md` — §P1–P13 madde/kabul satırları (229–460), KATALOG GÜNCELLEME 1–17 (852–871), T-01..T-73 kapsama matrisi (725–795), açık kalemler (893–904).
- `docs/plans/2026-09-28-ovsync-takip-ekrani/design.md` — §6c (154–212), §7 (213–228), §9 kabul 1–11 (239–253), §10/§10b/§10c/§10d/§10e/§10f/§10g/§10h (254–378).
- `docs/plans/2026-09-28-ovsync-takip-ekrani/test-senaryolari.md` — başlık + bölüm haritası + tüm `### T-` başlık/Ref satırları + T-01..T-05, T-19..T-24, T-46, T-73, T-80..T-82, T-94 gövdeleri + §İNSAN-UI/§SPEC SORULARI/§Kapsam dışı/§Koşum notları.
- Katalog v2 durumu: `grep -c '^### T-'` = **94**, numaralar T-01..T-94 kesintisiz [OBSERVED: sed+sort+uniq — atlama yok].

## 2. Kaplama matrisi özeti (davranış → sınayan senaryo)

| Davranış kaynağı | Sınayan |
|---|---|
| §9 kabul 1 (db-validate) | Katalog ölçmez — kataloğun kendi notu: "ön koşul; kapısı ayrı koşulur" [CONFIRMED] |
| §9 kabul 2 (bayrak_kapali, anon yok) | T-46, T-60, T-61; KPA PROD nokta-doğrulaması → **kapsam dışı** (§Kapsam dışı, 1. madde) |
| §9 kabul 3 (ekran S0–S4) | T-32..T-44, T-28..T-31, T-63..T-71 |
| §9 kabul 4 (girişler) | T-56, T-57 |
| §9 kabul 5 (PW demo + glmf liste) | Tüm PW satırları + §İNSAN-UI (kapı) |
| §9 kabul 6 (invalidate/offline) | T-46..T-50, T-94 |
| §9 kabul 7 (RPC_TABLES) | T-62 |
| §9 kabul 8 (gezınme) | T-51..T-55 |
| §9 kabul 9 (sayı eşitliği) | T-58 (+T-45) |
| §9 kabul 10 (§7.9 yazma politikası) | T-34/35/37, T-62; §6c istisnası T-01..T-11 |
| §9 kabul 11 (§6c uçtan uca) | T-01..T-30, T-41, T-72/73, T-75..T-78, T-86, T-89, T-92, T-93 + **T-95..T-100 (yeni)** |
| §10 S1–S10 | T-57/İNSAN-UI 12, T-03, T-20, T-13, T-07, T-01, T-02, T-14, T-06, T-05/T-39, T-04/T-25 |
| §10b S-1..S-10 | T-17, T-25/T-26 (§10d #3), T-05/T-77, T-86, T-46, T-59, T-26, T-72/T-73, T-39, T-05/T-76 |
| §10c #1 (4 kapanış olayı) | T-19 (tohumlama), T-20/T-86 (PG onay; hızlı/seans/toplu), T-89/T-92 (Ovsync vaka), T-22 (çıkış), T-23 (neden kaydı), T-24 (idempotent) + **T-99 (geri-al kalıcılığı), T-100 (bayrak bağımsızlığı — yeni)** |
| §10c #2 (tek sarmal) | T-06, T-11, T-08..T-10 |
| §10c #3 (Gebe çekirdeği) | T-77, T-78 |
| §10c #4 (birleşik kapı) | T-86 |
| §10c #5 (K15) | T-04, T-39, T-74, T-75, T-76 |
| §10c #6 (bayrak kapalı) | T-46 (okuma+ekran) + **T-97 (yazma modu — yeni)** |
| §10c #9/#10 (XOR, son PG) | T-72/73 (XOR yarış: T-87 oracle kümesi) + **T-96 (XOR/tip doğrudan — yeni)**; son PG: T-02 |
| §10c #11–#14 | T-45/T-79 (eşik), T-91/#61 (farm_id), T-57 (K14) |
| §10d #1–#4 | T-80, T-81, T-82, T-44, T-75, T-79 |
| §10e D1/D1-UI/D2/UI-R1 | T-77, T-83, T-84, T-45/T-79, T-85, T-88 (C1 çözücü) |
| §10f C1–C6 | T-88, T-93/C2, T-89+T-92/C4, T-90/C5, T-91/C6, C3→§10g/h |
| §10g MK9-N/G/T/K/P | T-72, T-87 (P/oracle), MK9-K tetikleyici → **T-100 (yeni)**, MK9-K sarmal yazma → **T-97 (yeni)** |
| §10h H1–H8 | T-87 (H7), T-93 (H5), T-94 (H8), T-74 (H6); H1/H2 → **B9 kapsam dışı** |
| P2b seçim uzayı tablosu | **T-95 (yeni)** — v2'de sınamayan tek P2b sözleşme bloğu |
| P2b p_bos_duzeltme koşul seti | **T-98 (yeni)** |
| P3a geri-al madde satırı | **T-99 (yeni)** |

Sonuç: kalan tüm davranışlar ya T-01..T-94 ile kaplı ya kataloğun §Kapsam dışı listesinde açıkça işaretli. **Kaplamasız kalan 6 sınanabilir davranış bulundu** (bkz. §3) — plan sessiz davranış yok: her açık planın açık Is/kabul maddesine dayanıyor.

## 3. Yazılan yeni senaryolar (T-95..T-100, §S bölümü)

| T | Davranış | Plan kaynağı (satır kanıtı) | v2'de neden açık [kanıt] |
|---|---|---|---|
| T-95 | Seçim tablosu guard'ı: TAKIP_MUAYENE'de TAKIP → `TAKIP_YENIDEN_SECILEMEZ`; tablo-dışı → `SECIM_TANIMSIZ`; UNIT `_muayeneSecimleri` ↔ DB CASE senkron | plan P2b "Secim uzayi (#3/K15 + D3…)" maddesi | grep `TAKIP_YENIDEN_SECILEMEZ` = 0, `SECIM_TANIMSIZ` = 0, `MUAYENE_SECIM` = 0 [OBSERVED]; T-05 yalnız UI adım metninde anıyor, red davranışı yok |
| T-96 | Giriş kimliği XOR: `GIRIS_CIFT_ANLAMLI` (ikisi dolu/boş) + `MUAYENE_GOREV_TIPI_UYUMSUZ` | plan P2b "XOR guard (#9)" maddesi | grep `MUAYENE_GOREV_TIPI_UYUMSUZ` = 0; `GIRIS_CIFT_ANLAMLI` yalnız T-87 oracle izinli-küme listesinde, doğrudan davranış testi yok [OBSERVED] |
| T-97 | Bayrak kapalıyken sarmal YAZMA modları → `OZELLIK_KAPALI`, hiçbir yazma yok | plan P2b "Bayrak kapali (#6 + §10g MK9-K)… YAZMA modlarının hepsi RAISE 'OZELLIK_KAPALI'" | grep `OZELLIK_KAPALI` yalnız T-46 bağlamı (okuma `{bayrak_kapali}` + ekran); yazma modu testi yok [OBSERVED] |
| T-98 | `p_bos_duzeltme=true` 5-koşul seti: eksik koşulda `BOS_DUZELTME_KOSUL:{eksik...}` red, yazma yok | plan P2b "`p_bos_duzeltme=true` kosul seti (HEPSI zorunlu…)" maddesi | grep `BOS_DUZELTME_KOSUL` = 0 [OBSERVED] |
| T-99 | `pg_application_event.geri_alindi_at` (PG geri al) takibi YENİDEN AÇMAZ — kapanış kalıcı | plan P3a "Geri-al yolu… takibi YENIDEN ACMAZ (kapanis kalici)" maddesi | grep `geri_alindi_at` = 0; "yeniden açmaz" = 0 [OBSERVED] |
| T-100 | Kapanış tetikleyicileri bayraktan bağımsız (MK9-K): bayrak=0'da eski yol yazınca kapanış yine çalışır; tetikleyici hayvan kilidi almaz (H3) | plan P3a "MK9-K — tetikleyiciler bayraktan bağımsız (§10g; v7 güncellemesi)" maddesi | v2 bayrak-kapalı provası yalnız T-46 (okuma) — tetikleyici bayrak-bağımsızlık senaryosu yok [OBSERVED] |

Format mevcut girişlerle birebir (başlık `### T-NN —`, bölümler Ref/Katman/Ön koşul/Adımlar/BEKLENEN — DB/Ters kanıt; kaynak referansları plan maddeleri). Ayrıca kabul matrisi tablosuna `+ P2b/P3a sözleşme guard'ları → T-95..T-100` satırı, başlığa sürüm 3 notu eklendi.

## 4. Kapsam dışı bırakılanlar (senaryo YAZILMADI — gerekçeyle)

- **B9 — MK9 eski-yol kilit denetimi** (§10h H2): plan açıkça ayrı işe devretti [CONFIRMED: plan.md "Açık kalemler"].
- **FAZ 2** (iki-farm matris/toplu tamamla) + **iki-farm negatif testi** (§10c #13): spec faz sınırı.
- **PROD canlı nokta-doğrulama** (kabul 2'nin KPA yarısı): katalog kuralı — PROD erişimi yok; kataloğun §Kapsam dışı listesinde zaten işaretli.
- **Backlog B1–B8**: spec backlog'u (yalnız B3 not-düzeyinde T-71'de).
- **`gebelik_muayene_listele` yüzeyinin kendi senaryoları**: D2/K15 ile küme-tam eşitlik T-45/T-79/T-82'de ölçülüyor; yüzeyin kendi bağımsız senaryoları kapsam dışı (kataloğun kararı).
- **D1 kenar sınırı** (takip zincirinde `_acik_disi_gorev_kur` atlanması; Gebe çekirdeği iptal listesi değişmez): plan "mevcut davranış korunur — kapsam genişletilmez" diyor [CONFIRMED: plan.md açık kalemler son madde] → sınanacak YENİ davranış yok, senaryo yazılmadı (uydurma olurdu).
- **Performans/yük, tarayıcı matrisi, görsel regresyon**: kapsam tanımlı değil (katalog).
- **P11/P13'ün süreç kabulleri** (kırmızı-once kanıt dosyaları, ground-truth replay): davranış senaryosu değil — planın kendi kabul satırları; kataloğun ölçüm konusu değil.

## 5. Düzeltilen üç bayat sayı cümlesi (önce → sonra)

1. `runs/2026-09-28-ovsync-takip/test-uygulanabilir-DONE.md` (§2 sonu):
   - ÖNCE: "Senaryo sayıları: eski T-01..T-73 korundu; **T-74..T-96 = 23 yeni senaryo**; katalog toplam 96 senaryo."
   - SONRA: "…**T-74..T-94 = 21 yeni senaryo**; katalog v2 toplam 94 senaryo (ölçüm: `grep -c '^### T-'` = 94, T-95/T-96 yoktu — aritmetik kayma düzeltildi 2026-09-30). Kapsam-açık denetimi (2026-09-30): … **T-95..T-100 eklendi → katalog toplam 100 senaryo** …"
2. `test-senaryolari.md` satır ~4 (başlık):
   - ÖNCE: "…T-74..T-96 yeni; SPEC SORULARI'nın hepsi kapandı…"
   - SONRA: "…**T-74..T-94 yeni** (21 senaryo); SPEC SORULARI'nın hepsi kapandı…" + yeni sürüm 3 satırı (T-95..T-100, toplam 100).
3. `runs/2026-09-28-ovsync-takip/test-uygulanabilir-HANDOFF.md` satır ~7:
   - ÖNCE: "**Biten:** katalog v2 (T-74..T-96 yeni, SPEC sorusu 0)…"
   - SONRA: "**Biten:** katalog v2 (**T-74..T-94 yeni** — 21 senaryo; "T-96/23" aritmetik kaymaydı, 2026-09-30 düzeltildi; kapsam-açık denetimi T-95..T-100 ekledi → toplam 100; SPEC sorusu 0)…"

## 6. Doğrulama kanıtı (bitirme kapısı)

- `grep -c '^### T-' test-senaryolari.md` → **100** [OBSERVED]
- Numara sürekliliği (grep `^### T-` → sed → sort -n → atlama kontrolü): ilk 01, son 100, **atlama yok** [OBSERVED]
- `grep -n 'T-74..T-96\|96 senaryo'` üç dosyada → **0 eşleşme** [OBSERVED]
- Yazma manifesti: yalnız 4 izinli dosyaya yazıldı; plan.md/design.md/domain-rules.md/.harness/.ss/.crumbs okuma-only kaldı; commit/merge/push yok; /tmp'ye sabit dosya yazılmadı [CONFIRMED]
