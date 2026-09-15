# P2 — Prod Adım A: yedek + main borcu migration'ları (FİNAL)

Tarih: 2026-09-15 · Dal: `agent/prod-adim-a` · Sahip onaylı PROD YAZIMI
Zarf: `.ss/tasks/P2-prod-adim-a.md` · Kaynak ölçüm: `reports/2026-09-15-prod-migration-olcum.md` (P1)

**Kural uyumu:** Yedek salt-okunur SELECT'lerle alındı. Uygulama her dosya için
ayrı `BEGIN; <dosya>; COMMIT;` transaction'ı olarak Mgmt API'den koşuldu;
`#5` (`20260910000002`) ATLANDI, `20260902000001` koşulMADI. Token değeri hiçbir
dosyaya/rapora yazılmadı. Prod verisi git'e girmedi — yedek repo dışındadır.

## 1. Özet

- **Yedek:** uygulama ÖNCESİ alındı → `/home/melik/tmp/agents/prod-yedek-2026-09-15/`
  (repo dışı; 75 MiB, 59 dosya, 111,6 s). public şemasının 48 tablosunun tamamı
  (satır bazında json_agg) + fonksiyon/trigger/policy/grant/index/kolon/constraint/
  view/extensions tanımları. Referans doğrulaması: P1 `data_probe_prod.json`
  sayılarıyla 9/9 birebir eşleşti (bkz. §3).
- **Uygulama:** 9/9 dosya OK — toplam 6,0 s, ilk hatada DUR tetiklenmedi.
- **Doğrulama:** P1 yöntemiyle (probe + verdict) yeniden ölçüm: uygulanan 9 dosya
  **CANLI**; kalan 36 dosyanın durumu değişmedi (#5 KISMİ, L2/L4 KISMİ/EKSİK).
  Prod artık: **26 CANLI · 5 KISMİ · 4 EKSİK · 1 N/A** (P1 öncesi: 17/12/6/1).

## 2. Uygulanan dosyalar × sonuç × süre

| # | Dosya | P1 durumu | Sonuç | Süre |
|---|---|---|---|---|
| 1 | `20260831000003_tablo_guard_triggerlari.sql` | KISMİ | OK → CANLI | 0,6 s |
| 2 | `20260909100000_dozaj_std_dose_seed.sql` | EKSİK | OK → CANLI | 0,5 s |
| 3 | `20260909110000_dozaj_helper_min_max_rpc.sql` | EKSİK | OK → CANLI | 0,7 s |
| 4 | `20260910000001_planli_tohumlama_sperma_dus.sql` | KISMİ | OK → CANLI | 0,5 s |
| — | ~~`20260910000002_sperma_eslesme_sertlestirme.sql`~~ | KISMİ | **ATLANDI** (P3) | — |
| 5 | `20260910000003_gebelik_kaydet_manual_42804_fix.sql` | KISMİ | OK → CANLI | 0,5 s |
| 6 | `20260911000001_dogum_buzagi_id_foundation.sql` | KISMİ | OK → CANLI | 1,1 s |
| 7 | `20260911000002_pedigree_foundation.sql` | KISMİ | OK → CANLI | 0,8 s |
| 8 | `20260911000003_pedigree_farm_backfill.sql` | KISMİ | OK → CANLI | 0,7 s |
| 9 | `20260911000004_pedigree_projection_rpc.sql` | KISMİ | OK → CANLI | 0,6 s |

Ham yanıtlar: `apply_01..09_*.txt` + `apply_log.json`; betik `apply_migrations.py`
(dosya kendi BEGIN/COMMIT'i içerirse durur — hiçbiri içermedi, kapı denetiminde
doğrulandı). Kanıt dizini: `reports/2026-09-15-prod-adim-a/`.

**#5 dokunulmazlık kanıtı:** (a) 9 dosyanın hiçbirinde
`tohumlama_kaydet`/`tohumlama_tekrar_kaydet` CREATE/DROP tanımı yok (kapı grepleri;
3 dosyadaki geçiş yalnız yorum satırlarında); (b) uygulama öncesi (P1 probe) ve
sonrası (bu işin probe'u) canlı gövde md5'leri birebir aynı:
`tohumlama_kaydet cf6949f61d`, `tohumlama_tekrar_kaydet ac51767d2a`.

## 3. Yedek

- **Yer:** `/home/melik/tmp/agents/prod-yedek-2026-09-15/` (repo DIŞI — `git add` YOK)
- **Kapsam:** 48 public tablosunun tüm satırları (`table_<tablo>.json`, parçalı
  json_agg, 500'lük parça + hâlâ büyükerse yarıya bölme) + `functions` (195 fn,
  public+surum_gizli), `triggers` (32), `policies` (73), `grants_routine` (672),
  `grants_table` (1409), `indexes` (118), `columns` (677), `constraints` (120),
  `views` (13), `extensions` (64), `roles_grants_schema` (1) → toplam 59 JSON.
- **Manifest:** `manifest.json` — dosya başına satır/bayt/sha256 + doğrulama
  tablosu + süre. Yöntem: Mgmt API `/database/query`, yalnız SELECT.

### Satır doğrulaması (P1 referansı ile — zarf kapısı)

| Tablo | P1 | Yedek | |
|---|---|---|---|
| hayvanlar | 166 | 166 | OK |
| tohumlama | 282 | 282 | OK |
| dogum | 72 | 72 | OK |
| gorev_log | 3084 | 3084 | OK |
| cases | 113 | 113 | OK |
| drug_products | 33 | 33 | OK |
| stok | 49 | 49 | OK |
| islem_log | 4253 | 4253 | OK |
| vaccines | 12 | 12 | OK |

Tam dosya listesi + satır + bayt + sha256: Ek A (aşağıda).

**Tutarlılık notu (sapma değil, sınır):** Mgmt API istekleri ayrı oturumlarda
koşar; tablolar arası anlık-görüntü (snapshot) tutarlılığı garanti edilemez.
Yedek 13:51'de alındı; en son veri yazımı stok_hareket'te 09:12 (UTC) — yedek
penceresinde yazma trafiği görünmedi, risk düşük kabul edilir.

## 4. Doğrulama (salt okunur)

### 4.1 Şema: P1 yöntemiyle yeniden ölçüm (`verify/`)

`probe.py prod` + `verdict.py` bu işin kanıt dizininde yeniden koşuldu
(P1 çıktılarına dokunulmadı; demo probe'u P1'den kopyalandı — bu iş demo'ya
dokunmaz). Sonuç:

- Uygulanan 9 dosya: **hepsi CANLI** (madde bazında verdicts.json'da: fonksiyon/
  kolon/tetik/policy/index/grant OK; guard fn gövdesi artık dosya revizyonuyla
  eşleşiyor).
- Değişen 9 dışında hiçbir dosyanın durumu değişmedi:
  `#5` KISMİ; `#11–#13, #17` KISMİ; `#14–#16, #18` EKSİK; `20260902000001` N/A.
- Prod toplam: **26 CANLI · 5 KISMİ · 4 EKSİK · 1 N/A**.

### 4.2 Veri (`verify_data.py` / `verify_data.json`)

| Kontrol | Sonuç | Not |
|---|---|---|
| `drug_products` std_dose | 33 toplam, **26 dolu**, min 11, max 11 | demo: 26/32 dolu |
| Seed isim eşleşmesi (P1 risk 4) | prod isim kümesi == demo isim kümesi (26=26, fark 0) | ✓ |
| `dogum.buzagi_id` | 72 toplam, **71 dolu** | 1 NULL → bkz. sapma 2 |
| `pedigree_nodes` | **166** (hayvanlar=166), `pedigree_parentage` 59 | ≈166 beklentisi ✓ |
| `pedigree_integrity_report()` | çalıştı, 4 grup döndürdü | bkz. sapma 3 |

### 4.3 Canlı site etkisi (pg_proc)

Main arayüzünün çağırdığı üç RPC prod'da VAR, imza beklentisiyle:
`ilac_dozaj_guncelle(p_id uuid, p_guncellemeler jsonb)` ·
`hayvan_kilo_guncelle(p_id text, p_canli_agirlik numeric)` ·
`pedigree_subgraph_for_animal(p_hayvan_id text, p_ancestor_depth integer, p_descendant_depth integer)`.
Ayrıca `fn_sperma_stok_dus(text,text)` ve `gebelik_kaydet_manual(text,date,text)` canlı.
EXECUTE grant'leri (#10'un authenticated maddesi dahil) verdict CANLI kapsamında doğrulandı.

## 5. Sapmalar / gözlemler (engel değil, kayıt)

0. **Root talimatı (commit öncesi düzeltme, 2026-09-15):** prod satırı/değeri taşıyan
   `verify_data.json` commit EDİLMEDİ — yalnız worktree'de durur (ana checkout'a root
   kopyaladı). `verify/probe_prod.json` ve `verify/probe_demo.json` şema çıktısı /
   kod niteliğinde (fonksiyon gövdeleri) olduğundan committe KALDI (root kararı).
   Commit önce yeniden yazıldı (soft reset → temiz commit; itme/merge olmadığından
   veri git geçmişine girmiş olmadı); commit edilen / edilmeyen tam liste §7'de.
   **`backup_prod.py` içindeki `OUT` klasörü SABİTtir**
   (`/home/melik/tmp/agents/prod-yedek-2026-09-15/` — betiğe gömülü): **Adım B'de
   yeni yedek alınacaksa bu sabit değiştirilmeli / parametrelendirilmelidir**;
   yoksa B yedeği A yedeğinin üzerine yazar.

1. **Yedek kapsamı zarftan geniş:** zarf "public şemasındaki HER tablo" dedi;
   public'te 48 tablo vardı — tools-bank kaynaklı `code_embeddings` (4482 satır),
   `goose_embeddings`, `memory_notes` gibi tablolar da yedeklendi (kural gereği
   hariç tutma yapmadım). Yedek 75 MiB'nin ~59 MiB'si bu üç tablodan.
2. **`dogum.buzagi_id` 1 NULL:** 2025-12-04 doğumu (yavru kupe "55", Dişi,
   Normal, olay_id dd0feb9f…) buzağı kaydıyla eşleşmedi — yavru `hayvanlar`'da
   yok ya da doğum tarihi tutmuyor. Backfill davranışı, veri kalitesi gözlemi;
   `pedigree_integrity_report` da `dogum_buzagi_missing=1` veriyor. Düzeltme bu
   işin kapsamı değil.
3. **`pedigree_integrity_report()` çıktısı:** `child_without_sire=166` (prod'da
   baba bilgisi hiç yok — semen_catalog boş), `child_without_dam=14`,
   `maternal_tarihsel_uyumsuz=2`, `dogum_buzagi_missing=1`. Fonksiyon beklendiği
   gibi çalışıyor; bulgular veri kalitesi kararıdır (sahip/P3).
4. **Dozaj seed'de 7 ürün isim eşleşmedi:** prod'da 33 üründen 26'sına seed
   yazıldı (demo 32'den 26). Yazılan isim kümeleri birebir aynı — eşleşmeyenler
   prod'da olmayan ya da demo'da olmayan ürünler, UPDATE-by-name tasarımının
   normal etkisi.
5. **Uygulama betiğinde ilk koşumda yol hatası:** `HERE.parents[1]` yerine
   `parents[3]` hesaplanmıştı — ilk istek prod'a gitMEDEN FileNotFoundError ile
   düştü, düzeltildi. Başka yeniden koşum olmadı.

## 6. Teslim durumu

- Uygulanan: 9 dosya, prod CANLI doğrulandı; #5 ve L2/L4'e dokunulmadı.
- Kalan borç (bu işte YOK): `#5` demo drift incelemesi (P3), `#11–#18` L2+L4 (sonraki adım).
- Yedek geri yükleme: `table_*.json` satır verisi + şema tanım yakalamaları ile
  elle geri yükleme mümkün (yöntem ve hash'ler Ek A'da / manifest'te).

## 7. Commit kapsamı — edilen / edilmeyen (root kuralı: prod verisi git'e girmez)

**Commit EDİLEN (23 dosya):**

| Dosya | Tür |
|---|---|
| `reports/2026-09-15-prod-adim-a.md` | özet rapor (bu dosya) |
| `yedek_ek_tablosu.md` | sayım özeti (satır/bayt/sha256 ilk 12) |
| `apply_01..09_*.txt` (9 dosya) | DDL yanıtı — tamamı `[]` |
| `apply_log.json` | süre/durum günlüğü |
| `apply_migrations.py`, `backup_prod.py`, `verify_data.py` | betikler |
| `verify/probe.py`, `verify/verdict.py`, `verify/parse_migrations.py` | betikler (P1'den kopya) |
| `verify/probe_prod.json`, `verify/probe_demo.json` | şema çıktıları — fonksiyon gövdeleri/kolon/grant dökümü (kod; root kararıyla kalır) |
| `verify/queries.sql` | sorgu metinleri (kanıt) |
| `verify/verdicts.json` | dosya × durum kararı + eşleşme kanıtı (şema kimliği, iş verisi yok) |
| `verify/inventory.json` | beklenen nesne sayımı (migration dosyalarından türetilmiş) |

**Commit EDİLMEYEN (1 dosya — worktree'de kalır; root ana checkout'a kopyaladı):**

| Dosya | İçerik |
|---|---|
| `verify_data.json` | gerçek prod iş değerleri (ürün adları, dozlar, integrity anahtarları, zaman damgaları) |

Prod yedeğinin kendisi (`/home/melik/tmp/agents/prod-yedek-2026-09-15/`, 75 MiB)
zaten repo dışındadır ve hiçbir aşamada git'e girmedi.

## Ek A — Yedek dosya listesi (satır / bayt / sha256)

Yol: `/home/melik/tmp/agents/prod-yedek-2026-09-15/` — 59 dosya, 77.546.952 bayt,
sha256'lar `manifest.json` ile birebir aynıdır (yedek dizini değişmedi).

| Dosya | Satır | Bayt | sha256 (ilk 12) |
|---|---|---|---|
| `columns.json` | 677 | 843746 | `c34078228ad9` |
| `constraints.json` | 120 | 19943 | `225186bd396d` |
| `extensions.json` | 64 | 3655 | `af768346bea9` |
| `functions.json` | 195 | 404693 | `aa6179da8b04` |
| `grants_routine.json` | 672 | 222206 | `e76fa5098060` |
| `grants_table.json` | 1409 | 328177 | `6c06fbe2061e` |
| `indexes.json` | 118 | 27668 | `6d271972e6a5` |
| `policies.json` | 73 | 15710 | `981ca6b7afa5` |
| `roles_grants_schema.json` | 1 | 62 | `4a72a108e8d9` |
| `table_agent_messages.json` | 94 | 63777 | `c9e286f580fb` |
| `table_agent_plans.json` | 5 | 2941 | `a85f9bd4c30e` |
| `table_agent_threads.json` | 26 | 6566 | `65118c98e6ca` |
| `table_bildirim_log.json` | 70 | 22132 | `b05de282b6f4` |
| `table_cases.json` | 113 | 36992 | `9f76ff1e081d` |
| `table_chat.json` | 14 | 6252 | `d03574146d19` |
| `table_code_embeddings.json` | 4482 | 62288645 | `b7d2d64616c6` |
| `table_cop_kutusu.json` | 0 | 59 | `f88912287107` |
| `table_diseases.json` | 47 | 7122 | `2e9ebfe2f8da` |
| `table_dogum.json` | 72 | 27616 | `8450d9fca736` |
| `table_drug_administrations.json` | 646 | 254182 | `d6f1b335e5e2` |
| `table_drug_classes.json` | 52 | 15053 | `4855b69f8725` |
| `table_drug_products.json` | 33 | 9413 | `2696bfe3df3c` |
| `table_drugs.json` | 17 | 4051 | `388ed9bef0e3` |
| `table_entity_graph.json` | 15 | 4718 | `2e07d0b94853` |
| `table_goose_embeddings.json` | 167 | 2315048 | `52ad9e93b286` |
| `table_gorev_log.json` | 3084 | 2178488 | `57d74dfb1988` |
| `table_grup_padok_eslem.json` | 10 | 1324 | `706142dd23de` |
| `table_hastalik_log.json` | 0 | 61 | `8b32d391e740` |
| `table_hayvan_override.json` | 0 | 64 | `a7e01d69e47d` |
| `table_hayvanlar.json` | 166 | 140981 | `9a22b7e44944` |
| `table_hekimler.json` | 3 | 262 | `24f300f956b5` |
| `table_irk_esik.json` | 7 | 1350 | `5e1f768c94a6` |
| `table_islem_log.json` | 4253 | 2974603 | `16ae3b08dc23` |
| `table_kizginlik_log.json` | 30 | 8890 | `b44501c42b1e` |
| `table_memory_notes.json` | 274 | 3766631 | `67a663ef3627` |
| `table_padoklar.json` | 9 | 1612 | `39d6de8a6b8c` |
| `table_protokol_ayar.json` | 9 | 1957 | `28caa67a3635` |
| `table_protokol_dismiss.json` | 35 | 7950 | `64c694ac6c6e` |
| `table_protokol_instance.json` | 141 | 48882 | `7f9e743a9371` |
| `table_sablon_hastalik_eslem.json` | 45 | 9291 | `0e94cd681e17` |
| `table_stok.json` | 49 | 15728 | `4d60d9d4c9c6` |
| `table_stok_hareket.json` | 1007 | 348022 | `ca19608995f4` |
| `table_stok_kategorileri.json` | 16 | 2351 | `6ee29e28d029` |
| `table_tasks.json` | 48 | 30804 | `de955fe51827` |
| `table_tedavi.json` | 0 | 55 | `58dc013a7d1d` |
| `table_tedavi_sablonu.json` | 10 | 2653 | `17524cbbf620` |
| `table_tedavi_sablonu_kalem.json` | 57 | 19211 | `2f5f5c6a95c6` |
| `table_tohumlama.json` | 282 | 155245 | `7589ff27888c` |
| `table_treatment_day_uygulamalar.json` | 572 | 368999 | `52b9b872db71` |
| `table_treatment_days.json` | 428 | 162345 | `0cd58ae9cfe8` |
| `table_ui_logs.json` | 265 | 129626 | `acfcbe6366da` |
| `table_uygulama_log.json` | 122 | 37110 | `d1c83f97e018` |
| `table_vaccination_log.json` | 381 | 160695 | `05021d916e85` |
| `table_vaccination_schedule.json` | 4 | 1162 | `a60361bcbb7f` |
| `table_vaccine_diseases.json` | 17 | 1934 | `54802a3998a3` |
| `table_vaccine_protocol_steps.json` | 14 | 2918 | `a64e39bbd6cc` |
| `table_vaccines.json` | 12 | 4687 | `02effd4a84fd` |
| `triggers.json` | 32 | 7931 | `f964d85d5656` |
| `views.json` | 13 | 22703 | `4fe8a42d77a1` |