---
id: G-20260913-SURUM-GECMISI
status: delivered
report_type: lead-teslim
created: 2026-09-13
lead_lane: agent/surum-gecmisi-diff
head: d6acf03
workers: [agent/surum-gecmisi-diff-W1 (8c4b629), agent/surum-gecmisi-diff-W2 (1e49fd4)]
goal: .harness/goals/2026/G-20260913-SURUM-GECMISI.md
---

# L2 Sürüm geçmişi + diff + biletli geri al — Lead teslim raporu

## 0. Özet

L2'nin üç fazı da teslim edildi ve lead dalına merge edildi (uç `d6acf03`).
Her iş verisi değişikliği artık `degisim_log`'a (39 iş tablosu, I/U/D, tam
satır görüntüleri, kaynak damgası) iniyor; ayrı bir "Değişiklikler" sayfası
tx-bazlı diff gösteriyor; geri alma, pgcrypto doğrulamalı 1 saatlik sahip
biletiyle çalışıyor ve geri almanın kendisi de yeni sürüm kaydı bırakıyor.
Eski Geçmiş sekmesi ve 7 legacy `*_geri_al` RPC'sine dokunulmadı. Migration'lar
**yalnız demo DB'de** uygundu; PROD'a hiçbir şey uygulanmadı ve hiç
bağlanılmadı.

Kabul sonuçları: **K1 PASS, K2 PASS, K3 PASS, K4 PASS, K5 PARTIAL (sahip
final testine), K6 = bu rapor.** Deviation: şerit kuralı 2 (luna review) bu
turda koşulmadı — sahip direktifi (yalnız glmf kolu + boşta ajan yok + "raporu
yazınca dur"); zarf hazır: `.ss/surum-gecmisi-diff-luna-zarf.md` (root koşabilir).

## 1. Faz başı SHA'lar

| Faz | Dal | Son SHA | Merge (lead dalında) |
|---|---|---|---|
| Goal açılış (frozen sözleşmeler) | agent/surum-gecmisi-diff | f2027d1 | — (taban 621f12a) |
| Sözleşme düzeltmeleri | agent/surum-gecmisi-diff | 3674e62, 9476721 | — |
| F1+F2 DB | agent/surum-gecmisi-diff-W1 | 8c4b629 | **66324c5 (KABUL)** |
| F3 UI | agent/surum-gecmisi-diff-W2 | 1e49fd4 | **a69358b (KABUL)** |
| Docs checkpoint (ui-map + rpc-reference) | agent/surum-gecmisi-diff | feba7f2 | — |
| Entegrasyon (stub sökümü, damga 20260913-16) | agent/surum-gecmisi-diff | d6acf03 | — (uç) |

## 2. Kapsam tablosu (F1) — 39 dahil / 11 hariç (gerekçeleriyle)

Canlı DEMO şema envanteri: 50 public base tablo. **39'u kapsamda** (her
birinde `trg_degisim_log` attach kanıtı, `pg_trigger` sayımı 39; döküm
`reports/2026-09-13-surum-gecmisi-W1/k1_iud_log.out`). Hariç 11:

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

`gorev_log` dahil (sahip talimatı); composite PK'lı `vaccine_diseases`
(2 kolon) ve `pedigree_meta` (farm_id+key) dahil, nesne-`satir_pk` şemasıyla
test edildi (k3).

## 3. Kabul yeniden-ölçüm sonuçları (lead tekrarı; worker raporu kanıt değil)

- **K1 PASS** — W1: k1 **156/156** (39 tablonun her birinde I→1, gerçek
  U→`degisen_alanlar` doğru 1, D→tam `eski` 1 kayıt; içerik-değişmez UPDATE→
  kayıt yok; kaynak damgası `SET LOCAL ROLE authenticated` + jwt claims ile
  kanıtlandı). Lead'in bağımsız probe'ları: no-op kuralı ✓,
  `teknikal_mi=t, degisen_alanlar={updated_at}` ✓, txid grubu ✓.
  **İmmutability red-before'lu**: k1b'de altı beklenen-red **lead merged-durum
  tekrarında da aynen** — `UPDATE/DELETE/TRUNCATE → degisim_log
  degistirilemez`, authenticated DML ve anon SELECT `42501`.
- **K2 PASS** — W1 (k2): 100 INSERT + 100 UPDATE tek tx → txid_sayisi=1;
  yük medyanları (stok_hareket, 2000 satır, 3 tekrar, açık/kapalı dönüşümlü):
  INSERT +81.8 µs/satır, UPDATE +147.0 µs/satır, DELETE +70.4 µs/satır.
  Lead'in bağımsız ölçümü tutarlı (100 satır UPDATE ≈ +96 ms, ~1 ms/satır
  pooler'lı üst sınır).
- **K3 PASS** — W1 (k3): **43/43** — bilet akışları (SIFRE_AYARLI_DEGIL /
  SIFRE_HATALI / kalan_sn≈3600 / BILET_SURESI_DOLMUS + kullanım kaydı /
  bilinmeyen-uuid→BILET_GECERSIZ / **çok kullanımlılık: aynı bilet 8 revert**),
  alan-satır-işlem 3 seviye revert, **revert-in-revert ×2**, çakışma→CAKISMA
  (bypass yok), bağımlılık KADEMELİ/ENGEL, composite-PK hedefleri, cascade
  revert'te topolojik EKLE sırası (S12), temizlik (demo başlangıç durumuna
  döndü). **Lead merged-durum tekrarı: 43 vaka / 0 fail.** Ek lead probe'ları
  (canlı): `degisim_onizle` anahtar seti sözleşme birebir; biletsiz
  `degisim_geri_al` → `BILET_GECERSIZ`.
- **K4 PASS** — taban lead teyidi **796/795/1** (bilinen kırmızı
  `gecmis-pipeline.test.js:283` hariç); W2 sonrası **814/813/1** (18 yeni saf
  katman testi: diff üretimi + Türkçe etiketler) — lead entegrasyon
  sonrası tekrarı da 814/813/1.
- **K5 PARTIAL → sahip** — W2: 8 ekran görüntüsü gerçek tıklama akışıyla
  (`reports/2026-09-13-surum-gecmisi-W2/*.png`; liste/detay-diff/önizleme/
  bilet-hata/sonuç/çakışma/çevrimdışı/hayvan-filtresi) — o noktada RPC
  katmanı kontrat-şekilli stub'tı. Entegrasyonda (d6acf03) stub söküldü,
  gerçek RPC'ler canlı; RPC düzeyi gerçek demo doğrulaması yukarıda.
  **Gerçek veriyle tarayıcı akışı sahip final testinde** (lokal sunucu:
  `python3 -m http.server 8098` + demo DB; port 8080 sahibin SearXNG'si).
- **K6 = bu rapor.**

## 4. Sözleşme kararları ve sapmalar

1. **`degisim_listele` eklendi** (lead; 4 yerine 5 RPC) — hayvan/tarih
   filtresi + tx-gruplama PostgREST jsonb sorgusuyla yapılamaz.
2. **c9f7fd34 (W1 sorusu, lead onayı):** `satir_pk` jsonb nesne;
   `p_hedef.pk` tek-kolonda skaler / composite'ta nesne; satır/alan
   hedeflerinde opsiyonel `txid` (yoksa EN SON değişiklik). Goal 3674e62.
   Çakışma kuralı değişmedi (bypass yok). W2 UI'ı her satır/alan
   revert'inde `txid` gönderir.
3. **teknikal_mi** detay satırlarında (W2 istemi Q3) — goal 9476721;
   implementasyonda zaten vardı (lead sınamasıyla teyit).
4. **W1 kendi kararları (makul, kanıtlı):** `sahip_sifresi_ayarla` yalnız
   service_role; `degisim_log`'a authenticated INSERT grant'ı VERİLMEDİ
   (islem_log'un aksine — sahte-geçmiş yazımını kapatır; k1b kanıtlı);
   gizli tablolar (şifre hash'i, biletler, kullanım) `surum_gizli` şemasında
   (PostgREST expose etmez; `demo_klonla` yalnız public kopyaladığından prod
   hash'i demo'ya sızmaz); teknikal küme = canlıdan 5 zaman-damga kolonu.
5. **Şerit kuralı 2 sapması:** luna (codex max) review bu turda koşulmadı —
   sahip direktifi 2026-09-13 (worker koltukları asla claude kolu; yalnız
   glmf; boşta ajan yok; "raporu yazınca dur"). Worker-içi review'lar (kural
   1) iki worker'da da koştu ve belgeli: W2 1C/4I/7M → hepsi kapalı; W1
   **REQUEST_CHANGES 1 Critical** (cascade-revert'te çocuk-önce FK 23503) →
   Kahn topolojik EKLE sırasıyla çözüldü, betikler final motorla yeniden
   koşuldu. **Luna borcu root'ta** — zarf hazır.

## 5. Test çıktıları (ham, dalda)

- `reports/2026-09-13-surum-gecmisi-W1/k1_iud_log.{sql,out}` — 156/156
- `reports/2026-09-13-surum-gecmisi-W1/k1b_immutability.{sql,out}` — red-before + 6 red
- `reports/2026-09-13-surum-gecmisi-W1/k2_txid_yuk.{sql,out}` — txid + yük
- `reports/2026-09-13-surum-gecmisi-W1/k3_geri_alma.{sql,out}` — 43/43
- W2: `tests/unit/degisiklikler-*.test.js` (18 test) + 8 PNG + akış JSON'u
  (raporun "Screenshot run" bölümü)
- Lead tekrarları kırıntıda: `/home/melik/egesut-erp1/.crumbs/surum-gecmisi-diff.jsonl`

## 6. Kalan riskler / ölçülmemiş sınırlar

- `UYGULAMA_HATASI` yolu (revert adımının iş trigger'ına takılması) sentetik
  senaryoda üretilemedi; kod yolu mevcut (EXCEPTION → `ok:false`).
- Süperuser/owner `degisim_log`'u trigger-disable ile değiştirebilir
  (uygulama rollerine karşı koruma; DB sahibini kapsamaz).
- Toplu güncellemelerde ~147 µs/satır trigger yükü — yüksek hacimde ölçülmeli.
- Şifre deneme sayısında kilitleme/gecikme yok (bf(10) yavaşlatması var) —
  sahiplik tek-şifre modeli için kabul edilebilir, prod'da gözlemlenebilir.
- `demo_klonla` penceresi: prod FDW çekimi `degisim_log`'u da kopyalarsa o
  pencerede çalışan revert'ler log üretmez — runbook'a "klon sonrası
  degisim_log muafiyeti" satırı eklenmeli.
- `degisim_onizle/listele` log büyüdükçe yavaşlar — prod öncesi
  `degisen_alanlar` GIN + ifade indeksi değerlendirilmeli.
- W2 artıkları: liste kartları klavye erişimi kısmi (mevcut delegation
  pattern'ine bırakıldı); kontrolcü için ayrı test yok (saf katman goal'in
  gereğiydi); `index.html`'de kullanılmayan `.dg-stub` CSS kuralı kaldı
  (zararsız).
- UI final testleri sahipte; ana-checkout'ta önceden var olan iki kozmetik
  sorun gözlendi (IDB açılmadan Kayıt tıklaması, boot'ta bir 401) — bu işle
  ilgisiz.

## 7. PROD DEPLOY ADIMLARI — AYRI BÖLÜM (HİÇBİRİ UYGULANMADI; owner kapısı)

**Bu bölüm plan taslağıdır, talimat değildir. Uygulama yalnız owner emriyle,
root koşturur.** Önceki borçtan 7 migration devir belgesinde kayıtlı
(`20260910000001-3` bugfix → `20260911000001-3` pedigree P1 →
`20260911000004` P2). Bu işten 3 yeni (hepsi additive/replay-safe, demo'da
canlı testli, blob SHA'ları §1'deki W1 raporunda):

1. `20260913000001_surum_gecmisi_f1_degisim_log.sql` — degisim_log + trigger'lar
   (39 tabloya attach + drift-temizlik + identity-PK guard) + indeksler
2. `20260913000002_surum_gecmisi_f2_geri_alma.sql` — pgcrypto + `surum_gizli`
   şeması + 4 RPC (topolojik plan/uygula/kilit iç yardımcılarıyla)
3. `20260913000003_surum_gecmisi_f2_sahip_sifresi.sql` — `sahip_sifresi_ayarla`
   (yalnız service_role; **hash içermez**)

Sıra: 7 eski → 1 → 2 → 3. Sonrası (owner):
- `SELECT sahip_sifresi_ayarla('<sahip şifresi>');` — service_role bağlantısıyla
- salt-okunur teyit: `pg_proc` (5 fonksiyon, SECURITY DEFINER, ACL),
  `pg_trigger` sayımı (39 attach), `degisim_log` kolonları
- GT regen ayrı adım (LSP şema aynası yeni nesneleri öğrenecek)
- §6'daki prod notları: klonla muafiyeti runbook satırı, GIN indeks
  değerlendirmesi, brute-force gözlemi
