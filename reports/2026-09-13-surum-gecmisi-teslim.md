---
id: G-20260913-SURUM-GECMISI
status: delivered
report_type: lead-teslim
created: 2026-09-13
lead_lane: agent/surum-gecmisi-diff
head: bu raporun commit'i (dal ucu — `git log -1` ile doğrulanır)
demo_ref: vtzqjmazsvurxdeondmi
prod_ref: zqnexqbdfvbhlxzelzju (LUNA §1'de yokluk kanıtlı; UYGULANMADI)
workers: [agent/surum-gecmisi-diff-W1 (8c4b629), agent/surum-gecmisi-diff-W2 (1e49fd4)]
goal: .harness/goals/2026/G-20260913-SURUM-GECMISI.md
luna_audit: agent/luna-denetim-l2 — reports/2026-09-13-luna-denetim-surum-gecmisi.md
---

# L2 Sürüm geçmişi + diff + biletli geri al — Lead teslim raporu

## 0. Özet

L2'nin üç fazı teslim edildi ve lead dalına merge edildi. Her iş verisi
değişikliği `degisim_log`'a (39 iş tablosu, I/U/D, tam satır görüntüleri,
kaynak damgası) iniyor; ayrı "Değişiklikler" sayfası tx-bazlı diff gösteriyor;
geri alma pgcrypto doğrulamalı 1 saatlik sahip biletiyle çalışıyor ve geri
almanın kendisi de yeni sürüm kaydı bırakıyor. Eski Geçmiş sekmesi ve 7 legacy
`*_geri_al` RPC'sine dokunulmadı. Migration'lar **yalnız demo DB'de**
(vtzqjmazsvurxdeondmi) uygulandı; **PROD'a (zqnexqbdfvbhlxzelzju) hiçbir şey
uygulanmadı** (LUNA §1 bağımsız yokluk probe'u da doğruladı).

Luna bağımsız denetimi (agent/luna-denetim-l2) 4 düzeltme istedi; tümü bu
turda işlendi (§4.6): (1) bilet sızıntısı kapatıldı + regression vaka,
(2) kapsam etiket haritası tamamlandı + 2 unit test, (3) rapor tazelendi
(DEMO ref, canlı kapsam listesi, K2 taze kanıt, diff hijyeni), (4) kabul
betiği paylaşılan gizli kayıtları artık silemiyor (yalnız kendi ürettiğini
temizler + koruma vakası). Madde 5 (gerçek-RPC tarayıcı testi) sahip final
testidir.

Kabul sonuçları: **K1 PASS, K2 PASS, K3 PASS (45/45), K4 PASS, K5 PARTIAL
(sahip final testine), K6 = bu rapor.** Şerit kuralı 2 (luna) bu teslimde
İŞLENDİ — denetim koştu, bulgular kapandı.

## 1. Faz başı SHA'lar

| Faz | Dal | Son SHA | Merge (lead dalında) |
|---|---|---|---|
| Goal açılış (frozen sözleşmeler) | agent/surum-gecmisi-diff | f2027d1 | — (taban 621f12a) |
| Sözleşme düzeltmeleri | agent/surum-gecmisi-diff | 3674e62, 9476721 | — |
| F1+F2 DB | agent/surum-gecmisi-diff-W1 | 8c4b629 | **66324c5 (KABUL)** |
| F3 UI | agent/surum-gecmisi-diff-W2 | 1e49fd4 | **a69358b (KABUL)** |
| Docs checkpoint (ui-map + rpc-reference) | agent/surum-gecmisi-diff | feba7f2 | — |
| Entegrasyon (stub sökümü, damga 20260913-16) | agent/surum-gecmisi-diff | d6acf03 | — |
| merge: F3 işaret commit'i | agent/surum-gecmisi-diff | f0814c4 | — |
| Teslim raporu v1 | agent/surum-gecmisi-diff | 97badf7 | — |
| LUNA düzeltmeleri (bu commit) | agent/surum-gecmisi-diff | bu commit | — (uç) |

## 2. Kapsam tablosu (F1) — 39 dahil / 12 hariç (gerekçeleriyle)

Canlı DEMO şema envanteri: W1 koşumunda 50, **LUNA denetiminde 51** public
base tablo (araya `tasks` girdi — aşağıda). **39'u kapsamda** (her birinde
`trg_degisim_log` attach; tam liste `reports/2026-09-13-surum-gecmisi-W1/
k1_iud_log.out` içinde tablo-bazo kanıtlı, ayrıca kapsamı:

`cases, diseases, dogum, drug_administrations, drug_classes, drug_products,
drugs, gorev_log, grup_padok_eslem, hastalik_log, hayvan_override, hayvanlar,
hekimler, irk_esik, kizginlik_log, padoklar, pedigree_meta, pedigree_nodes,
pedigree_parentage, protokol_ayar, protokol_dismiss, protokol_instance,
sablon_hastalik_eslem, semen_catalog, stok, stok_hareket, stok_kategorileri,
tedavi, tedavi_sablonu, tedavi_sablonu_kalem, tohumlama,
treatment_day_uygulamalar, treatment_days, uygulama_log, vaccination_log,
vaccination_schedule, vaccine_diseases, vaccine_protocol_steps, vaccines`

Hariç 12:

| Hariç tablo | Gerekçe |
|---|---|
| `degisim_log` | Log'un kendisi loglanmaz (sözleşme) + immutability trigger'lı |
| `islem_log` | Eski nesil log tablosu — loglansa her değişiklik çift kayıt |
| `bildirim_log` | Türetilmiş akış (altta yatan olay zaten loglanıyor); dahil etsek diff'te çift satır + bildirim revert'i olayı geri almaz. Gerekirse tek satırla attach edilebilir |
| `cop_kutusu` | Kendi yumuşak-silme/geri-yükleme yaşam döngüsü var |
| `ui_logs` | İstemci telemetrisi |
| `chat`, `agent_threads`, `agent_plans`, `agent_messages` | Ajan altyapısı |
| `goose_embeddings` | AI embedding önbelleği (teknik) |
| `demo_klon_log` | Klon işinin kendi altyapı kaydı |
| `tasks` (LUNA sonrası canlıya girdi) | Araç/görev-liste altyapısı (id,title,status,priority,assigned_to) — çiftlik iş verisi değil; W1 envanterinden sonra belirdi. Kapsama alınması istenirse trigger attach tek satırdır |

`gorev_log` dahil (sahip talimatı); composite PK'lı `vaccine_diseases` ve
`pedigree_meta` dahil, nesne-`satir_pk` şemasıyla test edildi (k3).

## 3. Kabul yeniden-ölçüm sonuçları (lead tekrarı; worker raporu kanıt değil)

- **K1 PASS** — W1: k1 **156/156** (39 tabloda I/U/D + no-op + kaynak
  damgası; `SET LOCAL ROLE authenticated` + jwt claims kanıtlı). Lead'in
  bağımsız probe'ları: no-op ✓, `teknikal_mi` ✓, txid grubu ✓.
  İmmutability red-before'lu: 6 beklenen-red lead merged-durum tekrarında da
  aynen (U/D/TRUNCATE → `degistirilemez`; authenticated DML + anon SELECT
  `42501`).
- **K2 PASS** — üç bağımsız koşum, medyan ek yük (µs/satır):

| Koşum | Ref | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| W1 teslim | 8c4b629 | +81.8 | +147.0 | +70.4 |
| LUNA | 6fabaf5 | +159.1 | +245.0 | +137.4 |
| Lead final (bu tur, dalda `k2_txid_yuk.out`) | bu commit | +120.4 | +206.0 | +108.4 |

  Ölçüm: `stok_hareket`, 2000 satır, 3 tekrar, trigger açık/kapalı dönüşümlü.
  Sapma paylaşımlı DEMO + pooler dalgalanmasıdır; oran-tablosu her koşumda
  5.5×–9.7× (I/U) bandında. txid gruplaması: 100+100 satır tek tx → 1 txid.
- **K3 PASS (45/45)** — W1'in 43 vakasına LUNA düzeltme vakaları eklendi:
  **S13** (LUNA-1: revert sonrası `degisim_log` içinde TAM bilet UUID geçmez;
  maskeli ilk-8+… bulunur), **S11b** (LUNA-4: koşum öncesi varolan gizli
  kayıt korunur), **S2c** maske beklentisine çevrildi. Kapsam: bilet akışları
  (SIFRE_AYARLI_DEGİL/SIFRE_HATALI/kalan_sn/BILET_SURESI_DOLMUS + kullanım
  kaydı/BILET_GECERSİZ/çok kullanımlılık), 3 seviye revert, revert-in-revert
  ×2, çakışma→CAKISMA (bypass yok), bağımlılık KADEMELİ/ENGEL, composite PK,
  cascade topolojik EKLE (S12), temizlik. Lead merged-durum + LUNA-fix
  tekrarları: **45 PASS / 0 FAIL**. Not: koşum penceresinde canlı UI trafiği
  (gorev_log, 7 satır) log'a düştü — o satırlar KASITLI olarak korunmuştur
  (LUNA-4 ilkesi: başkasının kaydına dokunulmaz).
- **K4 PASS** — taban 796/795/1 (bilinen kırmızı `gecmis-pipeline:283`);
  W2 sonrası 814/813/1; LUNA düzeltmeleriyle **816/815/1** (+2 LUNA-2 testi:
  kapsam-39 harita üyeliği + bulgu alanlarının Türkçeliği). LUNA'nın ölçtüğü
  ile birebir uyumlu.
- **K5 PARTIAL → sahip** — 8 ekran görüntüsü (stub-dönemi, gerçek tıklama
  akışı) dalda; entegrasyonda stub söküldü, gerçek RPC'ler canlı (RPC düzeyi
  gerçek demo doğrulaması yukarıda). **Gerçek veriyle tarayıcı akışı sahip
  final testinde** (LUNA madde 5: lead yapmaz). Lokal sunucu: 8097/8098
  (8080 sahibin SearXNG'si).
- **K6 = bu rapor.**

## 4. Sözleşme kararları ve sapmalar

1. **`degisim_listele` eklendi** (lead) — hayvan/tarih filtresi + tx-gruplama
   PostgREST jsonb sorgusuyla yapılamaz.
2. **c9f7fd34:** `satir_pk` jsonb nesne; `p_hedef.pk` tek-kolonda skaler /
   composite'ta nesne; opsiyonel `txid` (yoksa EN SON değişiklik). Goal
   3674e62. Çakışma kuralı değişmez (bypass yok).
3. **teknikal_mi** detay satırlarında (goal 9476721).
4. **W1 kararları:** `sahip_sifresi_ayarla` yalnız service_role;
   `degisim_log`'a authenticated INSERT grant'ı YOK (sahte-geçmiş yazımını
   kapatır); gizli tablolar `surum_gizli` şemasında (PostgREST expose
   etmez; `demo_klonla` yalnız public kopyalar → prod hash'i demo'ya sızmaz).
5. **Şerit kuralı 2:** luna denetimi v1 tesliminde koşulmadı (sahip
   direktifi: yalnız glmf, boşta ajan yok, "raporu yazınca dur") — root
   sonradan luna'yı koşturdu; bulgular bu turda kapatıldı.
6. **LUNA düzeltmeleri (bu commit):**
   - **LUNA-1 (güvenlik, Critical):** revert sırasında `kaynak.geri_alma.bilet`
     tam UUID olarak public `degisim_log`'a yazılıyordu → authenticated
     kullanıcı `degisim_listele` detayından 1 saatlik çok-kullanımlı bileti
     okuyup şifre kapısını atlayabiliyordu (LUNA probe'u: ticket_matches=t).
     Düzeltme: migration `20260913000004_luna_bilet_maske.sql` —
     `_degisim_log_yaz` CREATE OR REPLACE, log'a yalnız `left(bilet,8)||'…'`
     yazılır (tam bilet yalnız `surum_gizli`'de, korelasyon korunur).
     Regression: k3 S13.
   - **LUNA-2:** etiket haritası 4 eksik tablo (pedigree_meta/nodes/parentage,
     semen_catalog) + 5 alan (display_name, source_ref, code, target_type,
     label) ile tamamlandı; kapsam-39 üyelik testi eklendi.
   - **LUNA-3:** rapor tazelendi — DEMO/PROD ref'leri, canlı kapsam listesi
     (51/39/12, `tasks` gerekçeli), K2 taze koşum eşlemesi, diff hijyeni
     (`.out` trailing-whitespace temizliği; `git diff --check` temiz).
   - **LUNA-4:** k3 temizliği artık `surum_gizli`'de KOŞUM ÖNCESİ anlık
     görüntüyle çalışır — yalnız koşumun ürettiği bilet/kullanım satırları
     silinir; önceden var olan sahip şifresi üzerine yazıldıysa geri
     yüklenir (S0a paylaşılan-demo uyumlu, S11b koruma vakası).
7. **W2 kararları:** bilet `sessionStorage`'da, süre client saatinden +
   sunucu her kullanımda yeniden doğrular; UI her satır/alan revert'inde
   `txid` gönderir.

## 5. Test çıktıları (ham, dalda)

- `reports/2026-09-13-surum-gecmisi-W1/k1_iud_log.{sql,out}` — 156/156
- `reports/2026-09-13-surum-gecmisi-W1/k1b_immutability.{sql,out}` — red-before + 6 red
- `reports/2026-09-13-surum-gecmisi-W1/k2_txid_yuk.{sql,out}` — son (LUNA-fix) koşum
- `reports/2026-09-13-surum-gecmisi-W1/k3_geri_alma.{sql,out}` — **45/45**, son koşum
- W2: `tests/unit/degisiklikler-*.test.js` (20 test) + 8 PNG + akış JSON'u
- Lead tekrarları + karar zinciri: `.crumbs/surum-gecmisi-diff.jsonl`

## 6. Kalan riskler / ölçülmemiş sınırlar

- `UYGULAMA_HATASI` yolu (revert adımının iş trigger'ına takılması) sentetik
  senaryoda üretilemedi; kod yolu mevcut.
- Süperuser/owner `degisim_log`'u trigger-disable ile değiştirebilir.
- Toplu güncellemelerde ~120-250 µs/satır trigger yükü (koşuma göre
  değişken) — yüksek hacimde prod profiliyle tekrar ölçülmeli.
- Şifre denemesinde kilitleme/gecikme yok (bf(10) yavaşlatması var).
- Maske sonrası audit'te bilet yalnız ilk-8 ile görünür; tam eşleme
  `surum_gizli.geri_alma_kullanim` üzerinden (postgres) yapılır.
- `demo_klonla` penceresi: prod FDW çekimi `degisim_log`'u kopyalarsa o
  pencerede revert'ler log üretmez — runbook satırı önerilir.
- `degisim_onizle/listele` log büyüdükçe yavaşlar — prod öncesi GIN/ifade
  indeksi değerlendirilmeli.
- Worktree'de `npm run test:unit` tek başına çalışmaz (node_modules yok;
  `NODE_PATH=<ana checkout>/node_modules` şart) — ortam kısıtı, kod durumu değil.
- W2 artıkları: liste kartları klavye erişimi kısmi; kontrolcü için ayrı
  test yok; `index.html`'de kullanılmayan `.dg-stub` CSS kuralı kaldı.
- UI final testleri sahipte; ana-checkout'ta önceden var olan iki kozmetik
  sorun (IDB boot yarışı, boot'ta 401) bu işle ilgisiz.

## 7. PROD DEPLOY ADIMLARI — AYRI BÖLÜM (HİÇBİRİ UYGULANMADI; owner kapısı)

**Plan taslağıdır, talimat değildir. Uygulama yalnız owner emriyle, root
koşturur.** Önceki borç 7 migration (devir belgesi §3.1). Bu işten **4 yeni**
(additive/replay-safe, demo'da canlı testli; blob SHA'ları W1 raporu +
bu commit):

1. `20260913000001_surum_gecmisi_f1_degisim_log.sql` — degisim_log + trigger'lar
2. `20260913000002_surum_gecmisi_f2_geri_alma.sql` — pgcrypto + `surum_gizli` + 4 RPC
3. `20260913000003_surum_gecmisi_f2_sahip_sifresi.sql` — `sahip_sifresi_ayarla`
4. `20260913000004_luna_bilet_maske.sql` — LUNA-1: log'a maskeli bilet

Sıra: 7 eski → 1 → 2 → 3 → 4. Sonrası (owner): `sahip_sifresi_ayarla`
(service_role bağlantıyla), salt-okunur teyit (5 fonksiyon SECURITY DEFINER +
ACL; 39 attach; kolonlar), GT regen, §6 prod notları (klonla runbook satırı,
GIN indeksi, brute-force gözlemi).
