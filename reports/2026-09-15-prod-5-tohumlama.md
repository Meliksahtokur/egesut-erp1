# P4 — Prod: #5 `20260910000002_sperma_eslesme_sertlestirme.sql` uygulaması (FİNAL)

Tarih: 2026-09-15 · Dal: `agent/prod-tohumlama-5` · Sahip onaylı PROD YAZIMI
Zarf: `.ss/tasks/P4-prod-5-tohumlama.md` (sahip kararı: P3 önerisi A onaylandı)
Kaynaklar: P3 raporu `reports/2026-09-15-tohumlama-kaydet-drift.md` (+ betikleri),
P2 raporu `reports/2026-09-15-prod-adim-a.md` (+ yedek/apply betikleri).

**Kural uyumu:** Bu işte YALNIZ #5 dosyası prod'a yazıldı — L2 (`20260913*`),
L4 (`20260914*`) ve `20260902000001_asi_stok_backfill.sql` koşulMADI.
Ön kontrol ve doğrulamanın tamamı `BEGIN READ ONLY; … ROLLBACK;` sarmında;
yedek salt-okunur SELECT'lerle alındı. `tohumlama_kaydet`/`_tekrar_kaydet`
test çağrısı YAPILMADI. Token değeri hiçbir dosyaya/rapora yazılmadı.
Prod verisi git'e girmedi (yedek repo dışında).

## 0. Sonuç (tek paragraf)

**#5 prod'da CANLI.** Ön kontrol üç kapıyı da geçti (M1 ön koşulu + prod hâlâ
eski sürümde + dosya denetimi), uygulama öncesi tam yedek alındı ve canlı
`count(*)` ile satır bazında doğrulandı, #5 dosya metni olduğu gibi tek istekle
uygulandı (0,8 s, hatasız), sonrasında tüm zarf kapıları yeşil: iki fonksiyonun
canlı gövde md5'i #5/demo ile **birebir** (`e4ab00a63d` / `83fe917252`),
overload sayıları 1, `SECURITY DEFINER` ve ACL uygulama öncesiyle aynı, 52
tablonun satır sayıları yedekle aynı. Sapma yok; tek olay ilk apply denemesinde
betik içi yol hatası (istek prod'a gitmedi — §6.1).

## 1. Ön kontrol (salt okunur) — `p4_precheck.py` / `precheck_prod.json`

| Kapı | Ölçüm | Sonuç |
|---|---|---|
| M1 ön koşulu | `fn_sperma_stok_dus(p_sperma text, p_notlar text) -> void` prod'da VAR, **tek overload** (P2'de M1 ile girmişti; root 14:3x ölçümüyle uyumlu) | OK |
| Prod = eski sürüm | `tohumlama_kaydet` md5_normall **`e144cf1f71`** (= P3 §2'deki (b) `20260830000034` sürümü), `tohumlama_tekrar_kaydet` **`64dc7fc09a`** (= (c′) `20260722000004`) | OK |
| Overload sayısı | iki fonksiyon da **1**; `secdef=true`, `volatile`, `-> jsonb` | OK |

Uygulama öncesi yakalanan ACL (`proacl`, sonraki karşılaştırma için):
`tohumlama_kaydet` → `{postgres=X,authenticated=X,service_role=X,anon=X}/postgres`;
`tohumlama_tekrar_kaydet` → `{postgres=X,authenticated=X,service_role=X}/postgres`.

## 2. #5 dosya denetimi (grep kanıtı)

- Üst-seviye DDL: **yalnız 2 adet `CREATE OR REPLACE FUNCTION`** (`tohumlama_kaydet`
  satır 45, `tohumlama_tekrar_kaydet` satır 230). DROP/ALTER/GRANT/TABLE/veri
  ifadesi YOK (görünen INSERT/UPDATE'lerin tamamı fonksiyon gövdeleri içinde —
  çağrı anında koşar, uygulama anında değil).
- Tek `DO $do$ … $do$;` bloğu (satır 43–285) = **tek statement, atomik**.
- Dosya kendi BEGIN/COMMIT'ini İÇERMEZ (review B5 kararı) → çift sarmalama
  yapılmadı, Mgmt API'ye dosya metni olduğu gibi gitti.
- `fn_sperma_stok_dus` CREATE/DROP'ı dosyada YOK (helper M1'de kuruldu) —
  yalnız 2 `PERFORM` çağrısı gövdede.

## 3. Yedek (uygulamadan ÖNCE) — `p4_backup_prod.py`

- **Yer:** `/home/melik/tmp/agents/prod-yedek-2026-09-15-p4/` (repo DIŞI).
  Mevcut `prod-yedek-2026-09-15/` ve diğer yedek klasörleri salt okunur —
  dokunulmadı. P2 raporu §5.0'daki OUT uyarısı bu işte uygulandı.
- **Kapsam:** 52 public tablosunun tüm satırları (parçalı json_agg) + fonksiyon
  (212, `proacl` dahil), trigger (33), policy (77), grants_routine (706),
  grants_table (1477), index (132), kolon (721), constraint (142), view (13),
  extensions (64), roles_grants_schema (1) → **63 dosya, 77.812.781 bayt, 147,7 s**.
- **Manifest:** `manifest.json` — dosya başına satır/bayt/sha256 + kapı sonuçları
  (Ek A'da özet; manifest repo dışında kalır).
- **Doğrulama (zarf kapısı):**
  - **Kapı A:** her tablo `backup_rows == yedek-başı count(*)` — 52/52 OK.
  - **Kapı B:** tüm tablolar bittikten sonra ikinci count turu == `backup_rows`
    — 52/52 OK → yedek penceresinde yazma trafiği görünmedi.
  - P1/P2 referans 9 tablo (`hayvanlar` 166, `tohumlama` 282, `dogum` 72,
    `gorev_log` 3084, `cases` 113, `drug_products` 33, `stok` 49, `islem_log`
    4253, `vaccines` 12) hepsi eşleşti (bilgilendirme).

## 4. Uygulama — `p4_apply.py` / `apply_log.json` / `apply_01_*.txt`

- Tek Mgmt API `/database/query` isteği; gönderilen = dosya metni (12.528 bayt),
  sarma yok (#5 tek DO statement — §2).
- Sonuç: **`[]` → "OK (0 sonuç kümesi)", 0,8 s.** Hata yok; DUR tetiklenmedi.
- Betik yalnız bu tek dosyayı gönderir (başka dosya koşulamaz — koruma satırı).

## 5. Doğrulama (salt okunur) — `p4_verify.py` / `verify_summary.json`

| Kapı | Ölçüm | Sonuç |
|---|---|---|
| md5 = #5/demo | `tohumlama_kaydet` **`e4ab00a63d`**, `tohumlama_tekrar_kaydet` **`83fe917252`** (P3 `compare.py` md5_normall yöntemi) | OK — birebir |
| Overload | iki fonksiyon **1**; `fn_sperma_stok_dus` hâlâ **tek overload** | OK |
| secdef + ACL | `secdef=true` ikisinde de; `proacl` uygulama öncesiyle **birebir** (§1'deki değerler) | OK |
| Veri | 52 tablonun satır sayıları yedekle **birebir** (tanım değişikliği veri değiştirmedi) | OK |
| Test çağrısı | fonksiyon çağrısı yapılmadı — yalnız pg_proc/pg_class okuması | OK |

## 6. Sapmalar / olay kaydı (engel değil)

1. **İlk apply denemesi yol hatasıyla düştü:** betikte repo kökü `parents[2]`
   hesaplanmıştı (P2 §5.5'teki aynı sınıf hata); `FileNotFoundError` —
   **istek prod'a gitmedi**, `parents[1]` düzeltmesi sonrası tek denemede OK.
2. **Yedek tablo sayısı P2'den 4 fazla (52 vs 48):** fark P2'nin kendi
   migration'larının kurduğu `pedigree_nodes` (166), `pedigree_parentage` (59),
   `pedigree_meta` (0), `semen_catalog` (0) — beklenmiş büyüme, sapma değil.
3. **Şema yakalama sayıları P2 yedeğine göre arttı** (fn 195→212, trigger
   32→33, policy 73→77, grants_routine 672→706, grants_table 1409→1477, index
   118→132, kolon 677→721, constraint 120→142): P2'nin 9 migration'ı + bu işin
   #5'i. Bazı tablo dosyalarının bayt boyu değişti (ör. `dogum` 27.616→30.760 B)
   — satır sayıları aynı, kolon eklenmesinden (P2 migration'ları).
4. `md5_normall` kıyasında zarfın vermediği `tohumlama_tekrar_kaydet`
   beklenen-eski değeri P3 raporu §2'den alındı (`64dc7fc09a`); ölçüm bunu
   doğruladı.

## 7. Teslim durumu ve commit kapsamı

- **Commit EDİLEN (12 dosya):** bu rapor + kanıt dizini
  `reports/2026-09-15-prod-5-tohumlama/`: 4 betik (`p4_precheck.py`,
  `p4_backup_prod.py`, `p4_apply.py`, `p4_verify.py`), apply günlüğü
  (`apply_log.json`, `apply_01_*.txt`="[]"), fonksiyon sondaj çıktıları
  (`precheck_prod.json`, `precheck_summary.json`, `verify_prod_fns.json`,
  `verify_summary.json` — fonksiyon gövdesi/md5/proacl; kod niteliği),
  satır sayım tablosu (`verify_table_counts.json` — yalnız sayım).
  **Satır/iş-değeri içeren JSON commit edilmedi** (kural; P2 §7 ile aynı ayrım).
- **Git'e GİRMEYEN:** prod yedeğinin kendisi (`/home/melik/tmp/agents/
  prod-yedek-2026-09-15-p4/`, 77,8 MB, repo dışı) ve `manifest.json`'ın ham
  hâli (repo dışında; özet Ek A'da).
- Kalan borç (bu işte YOK): L2 `20260913*` + L4 `20260914*` (ayrı sahip onayı).

## Ek A — Yedek dosya listesi (satır / bayt / sha256 ilk 12)

Yol: `/home/melik/tmp/agents/prod-yedek-2026-09-15-p4/` — manifest.json ile birebir.

| Dosya | Satır | Bayt | sha256 (ilk 12) |
|---|---|---|---|
| `columns.json` | 721 | 898788 | `ea0571ed7369` |
| `constraints.json` | 142 | 24181 | `7a71b37e71d0` |
| `extensions.json` | 64 | 3655 | `af768346bea9` |
| `functions.json` | 212 | 471835 | `3b93fdb55016` |
| `grants_routine.json` | 706 | 233614 | `92a0d9098c6e` |
| `grants_table.json` | 1477 | 344053 | `1947f2ae1786` |
| `indexes.json` | 132 | 31298 | `dfe924406ce3` |
| `policies.json` | 77 | 16532 | `4af9bbf1cbe5` |
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
| `table_dogum.json` | 72 | 30760 | `6e7a27c0759a` |
| `table_drug_administrations.json` | 646 | 254182 | `d6f1b335e5e2` |
| `table_drug_classes.json` | 52 | 15053 | `4855b69f8725` |
| `table_drug_products.json` | 33 | 12266 | `66a72efc9697` |
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
| `table_pedigree_meta.json` | 0 | 62 | `f6d55121f3c7` |
| `table_pedigree_nodes.json` | 166 | 77863 | `4b394d9189e0` |
| `table_pedigree_parentage.json` | 59 | 22840 | `1d7fe927c537` |
| `table_protokol_ayar.json` | 9 | 1957 | `28caa67a3635` |
| `table_protokol_dismiss.json` | 35 | 7950 | `64c694ac6c6e` |
| `table_protokol_instance.json` | 141 | 48882 | `7f9e743a9371` |
| `table_sablon_hastalik_eslem.json` | 45 | 9291 | `0e94cd681e17` |
| `table_semen_catalog.json` | 0 | 62 | `65eb6321ea6c` |
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
| `table_vaccines.json` | 12 | 5289 | `8eaabec25b71` |
| `triggers.json` | 33 | 8176 | `1a2d4a93a360` |
| `views.json` | 13 | 22703 | `4fe8a42d77a1` |

Toplam: 63 dosya, 77812781 bayt, 147.7 s. Kapı A: OK - her tablo backup_rows == yedek-basi count(*). Kapı B: OK - yedek-sonu count turu backup_rows ile birebir.
