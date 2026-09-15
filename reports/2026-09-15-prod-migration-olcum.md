# P1 — Prod migration ölçümü (SALT OKUNUR) — FİNAL

Tarih: 2026-09-15 · Dal: `agent/prod-migration-olcum` · Worker ölçümü
WIP durumu `aac73a9` (dondurma noktası) bu teslimle kapanır; ölçüm yöntemi aynıdır,
üzerine teşhis + veri spot-probe'ları eklenmiştir.

**Kural uyumu:** Prod'a ve demo'ya karşı yapılan TÜM sorgular `BEGIN READ ONLY;
SELECT ...; ROLLBACK;` zarfındadır (Mgmt API). DDL/DML/GRANT yok, yazan fonksiyon
çağrısı yok. Token değerleri hiçbir rapora/çıktıya yazılmadı. Kanıt: `queries.sql`,
`data_probe_prod.json` (hata mesajları dahil ham çıktı), `probe_prod.json`,
`probe_demo.json`, `diagnosis.json`, `verdicts.json`.

## 1. Özet

| DB | CANLI | KISMİ | EKSİK | N/A (salt-DML) |
|---|---|---|---|---|
| **prod** | 17 | 12 | 6 | 1 |
| **demo** | 31 | 4 | 0 | 1 |

- `supabase_migrations.schema_migrations` prod'da `20260531400000`'da bitiyor; zarftaki
  not doğrulandı — bu kanıt değildir. Canlı şema ölçümü şunu gösterdi: **prod, 36-dosya
  setinin 20260902000001'e kadar olan kısmını (DML'leri dahil) fiilen almış,
  20260909100000 (dozaj seed)'dan itibaren hiçbirini almamıştır.** L2 (sürüm geçmişi)
  ve L4 (geri alma akışı) prod'da tamamen yoktur.
- Prod veri büyüklüğü küçüktür: hayvanlar=166, tohumlama=282, dogum=72, gorev_log=3084, cases=113, drug_products=33, vaccines=12, stok=49, islem_log=4253.

## 2. Dosya × prod × demo durumu ve kanıt

| Dosya | Prod | Demo | Prod kanıt (eksik/farklı maddeler) |
|---|---|---|---|
| `20260830000010_abort_vwp_penceresi.sql` | CANLI | KISMİ | — (tümü canlı) |
| `20260830000020_sessiz_vaka_filtresi_kaldir.sql` | CANLI | CANLI | — (tümü canlı) |
| `20260830000030_cift_abort_log_fix.sql` | CANLI | CANLI | — (tümü canlı) |
| `20260830000031_gebe_sonuc_mesaji.sql` | CANLI | CANLI | — (tümü canlı) |
| `20260830000032_geri_al_uuid_fallback.sql` | CANLI | CANLI | — (tümü canlı) |
| `20260830000033_geri_al_hardening.sql` | CANLI | CANLI | — (tümü canlı) |
| `20260830000034_review_fix_paketi.sql` | CANLI | KISMİ | — (tümü canlı) |
| `20260831000001_sessiz_ankra_fixi.sql` | CANLI | CANLI | — (tümü canlı) |
| `20260831000002_duve_sessiz_13ay.sql` | CANLI | CANLI | — (tümü canlı) |
| `20260831000003_tablo_guard_triggerlari.sql` | KISMİ | CANLI | public._guard_tohumlama_yas_cinsiyet() — MISMATCH (gövde hiçbir dosya sürümüyle eşleşmedi (md5 61c351cdf5; son tanım 2026) |
| `20260901000001_ikiz_dogum_olay_id.sql` | CANLI | CANLI | — (tümü canlı) |
| `20260901000002_kupe_revizyon.sql` | CANLI | CANLI | — (tümü canlı) |
| `20260902000001_asi_stok_backfill.sql` | N/A | N/A | — |
| `20260902000002_asi_stok_serbest_dusum.sql` | CANLI | CANLI | — (tümü canlı) |
| `20260902000003_asi_planli_gorev.sql` | CANLI | CANLI | — (tümü canlı) |
| `20260902000004_asi_toplu_gorev.sql` | CANLI | CANLI | — (tümü canlı) |
| `20260906000001_postpartum_d53_e_vitamin_tek.sql` | CANLI | KISMİ | — (tümü canlı) |
| `20260906120000_vaka_toplu_ac.sql` | CANLI | CANLI | — (tümü canlı) |
| `20260909000001_sablon_aktif_vakaya_uygula.sql` | CANLI | CANLI | — (tümü canlı) |
| `20260909100000_dozaj_std_dose_seed.sql` | EKSİK | CANLI | drug_products.std_dose — MISSING (yok); drug_products.std_dose_unit — MISSING (yok); drug_products_std_dose_unit_check — MISSING (yok) |
| `20260909110000_dozaj_helper_min_max_rpc.sql` | EKSİK | CANLI | public.ilac_dozaj_guncelle(uuid,jsonb) — MISSING (yok); public.hayvan_kilo_guncelle(text,numeric) — MISSING (yok); drug_products.std_dose_min — MISSING (yok) |
| `20260910000001_planli_tohumlama_sperma_dus.sql` | KISMİ | CANLI | public.fn_sperma_stok_dus(text,text) — MISSING (yok) |
| `20260910000002_sperma_eslesme_sertlestirme.sql` | KISMİ | KISMİ | public.tohumlama_tekrar_kaydet(text,date,text,text,text) — MISMATCH (gövde hiçbir dosya sürümüyle eşleşmedi (md5 f7b2d72ed7; son tanım 2026) |
| `20260910000003_gebelik_kaydet_manual_42804_fix.sql` | KISMİ | CANLI | public.gebelik_kaydet_manual(text,date,text) — MISMATCH (gövde hiçbir dosya sürümüyle eşleşmedi (md5 ab8eee5bfc; son tanım 2026) |
| `20260911000001_dogum_buzagi_id_foundation.sql` | KISMİ | CANLI | public._dogum_buzagi_backfill() — MISSING (yok); dogum.buzagi_id — MISSING (yok); dogum_buzagi_id_uidx — MISSING (yok) |
| `20260911000002_pedigree_foundation.sql` | KISMİ | CANLI | public.assert_is_operator() — MISSING (yok); public.pedigree_ensure_farm_node(text) — MISSING (yok); public.pedigree_is_ancestor(uuid,uuid) — MISSING (yok) |
| `20260911000003_pedigree_farm_backfill.sql` | KISMİ | CANLI | public.pedigree_try_timestamptz(text) — MISSING (yok); public.pedigree_farm_backfill() — MISSING (yok); public.pedigree_integrity_report() — MISSING (yok) |
| `20260911000004_pedigree_projection_rpc.sql` | KISMİ | CANLI | public.pedigree_subgraph(uuid,integer,integer) — MISSING (yok); public.pedigree_subgraph_for_animal(text,integer,integer) — MISSING (yok); EXECUTE ON public.pedigree_subgraph(uuid, integer, integer) TO authenticated; — FAIL (authenticated:YOK:EXECUTE) |
| `20260913000001_surum_gecmisi_f1_degisim_log.sql` | KISMİ | CANLI | public._degisim_log_degistirilemez() — MISSING (yok); public._degisim_log_yaz() — MISSING (yok); degisim_log — MISSING (yok) |
| `20260913000002_surum_gecmisi_f2_geri_alma.sql` | KISMİ | CANLI | surum_gizli._cagiran() — MISSING (yok); surum_gizli._kapsamda(text) — MISSING (yok); surum_gizli._pk_kolonlar(text) — MISSING (yok) |
| `20260913000003_surum_gecmisi_f2_sahip_sifresi.sql` | KISMİ | CANLI | public.sahip_sifresi_ayarla(text) — MISSING (yok); EXECUTE ON public.sahip_sifresi_ayarla(text) TO service_role; — FAIL (service_role:YOK:EXECUTE) |
| `20260913000004_luna_bilet_maske.sql` | EKSİK | CANLI | public._degisim_log_yaz() — MISSING (yok) |
| `20260914000001_l4_islem_log_kopru.sql` | EKSİK | CANLI | public._islem_log_degisim_txid() — MISSING (yok); islem_log.degisim_txid — MISSING (yok); trg_islem_log_degisim_txid ON islem_log — MISSING (yok) |
| `20260914000002_l4_geri_alma_zincir.sql` | EKSİK | CANLI | surum_gizli._l4_zaman_txid(text,jsonb,text,bigint,text,timestamp with time zone) — MISSING (yok); surum_gizli._degisim_plan(jsonb,text) — MISSING (yok); surum_gizli._l4_zincir(jsonb) — MISSING (yok) |
| `20260914000003_l4_onarim.sql` | KISMİ | CANLI | public._islem_log_degisim_txid() — MISSING (yok); public._islem_log_geri_alindi_kapisi() — MISSING (yok); surum_gizli._l4_rehber_uyesi(jsonb) — MISSING (yok) |
| `20260914000004_l4_stok_uyari_txid.sql` | EKSİK | CANLI | surum_gizli._degisim_plan(jsonb,text) — MISSING (yok); surum_gizli._l4_zincir(jsonb) — MISSING (yok) |

Tam madde-madde kanıt: `verdicts.json` (dosya → prod/demo → her nesnenin durumu ve kanıt metni).

## 3. Prod'a uygulanacak kesin sıralı liste

Uygulama sırası = dosya adı sırası (migration kronolojisi). Bağımlılıklar bu sırayla
zaten çözülür: dozaj kolonları → dozaj RPC'leri; buzagi_id temeli → dogum_kaydet;
pedigree temeli → backfill → projection RPC'leri; L2-F1 → L2-F2 → sahip şifresi →
bilet maskeleme → L4 köprü → zincir → onarım → txid.

| # | Dosya | Prod durumu | Eksik olan (KISMİ için madde) |
|---|---|---|---|
| 1 | `20260831000003_tablo_guard_triggerlari.sql` | KISMİ | `_guard_tohumlama_yas_cinsiyet` gövdesi prod'da dosya-dışı eski sürüm (canlı md5 13a0a02039 ≠ dosya a9bc818b5c). Diğer 2 guard fn + 3 trigger CANLI. Dosyanın yeniden çalıştırılması yeterli (CREATE OR REPLACE). |
| 2 | `20260909100000_dozaj_std_dose_seed.sql` | EKSİK | `drug_products.std_dose`, `.std_dose_unit` kolonları, CHECK constraint'i ve 27+10 seed UPDATE'inin tümü yok (veri probe: std_dose kolonu 42703). |
| 3 | `20260909110000_dozaj_helper_min_max_rpc.sql` | EKSİK | `std_dose_min`/`std_dose_max` kolonları, `ilac_dozaj_guncelle`, `hayvan_kilo_guncelle`, min/max seed'leri yok. |
| 4 | `20260910000001_planli_tohumlama_sperma_dus.sql` | KISMİ | `fn_sperma_stok_dus(text,text)` yok (REVOKE'ları da). |
| 5 | `20260910000002_sperma_eslesme_sertlestirme.sql` | KISMİ | `tohumlama_kaydet` prod'da 20260830000034 sürümünde (e144cf1f71), dosya sürümü eksik; `tohumlama_tekrar_kaydet` prod'da 20260722000004 sürümünde (64dc7fc09a), dosya sürümü eksik. |
| 6 | `20260910000003_gebelik_kaydet_manual_42804_fix.sql` | KISMİ | `gebelik_kaydet_manual` prod'da 20260605000002 (Haziran) sürümünde (314d9c0397); 42804 fix'i eksik. |
| 7 | `20260911000001_dogum_buzagi_id_foundation.sql` | KISMİ | `dogum.buzagi_id` kolonu + FK + kısmi unique index + `_dogum_buzagi_backfill` + dogum_kaydet'in buzagi-bağlayan sürümü yok (veri probe: 42703). |
| 8 | `20260911000002_pedigree_foundation.sql` | KISMİ | 4 tablo (pedigree_nodes/parentage/semen_catalog/pedigree_meta), 8 fn, `trg_pedigree_hayvan_insert`, 4 policy, 5 index, RLS ve grant'lerin tümü yok. |
| 9 | `20260911000003_pedigree_farm_backfill.sql` | KISMİ | 3 fn yok; `pedigree_farm_backfill()` çağrısı (DML) #8'e bağımlı. |
| 10 | `20260911000004_pedigree_projection_rpc.sql` | KISMİ | `pedigree_subgraph`, `pedigree_subgraph_for_animal` + EXECUTE grant'leri yok. |
| 11 | `20260913000001_surum_gecmisi_f1_degisim_log.sql` | KISMİ | `degisim_log` tablosu (veri probe: 42P01), 2 trigger-fn, 2 immutable trigger, 3 index, policy, SELECT grant'i ve 39 tabloya `trg_degisim_log` (prod 0/39) yok. |
| 12 | `20260913000002_surum_gecmisi_f2_geri_alma.sql` | KISMİ | `surum_gizli` şeması, 13 fn, 3 tablo, 1 index, tüm grant'ler yok. `pgcrypto` extension zaten mevcut (o madde OK). |
| 13 | `20260913000003_surum_gecmisi_f2_sahip_sifresi.sql` | KISMİ | `sahip_sifresi_ayarla(text)` + service_role EXECUTE grant'i yok. |
| 14 | `20260913000004_luna_bilet_maske.sql` | EKSİK | `_degisim_log_yaz`'ın bilet-maskeli sürümü yok (#11'e bağımlı). |
| 15 | `20260914000001_l4_islem_log_kopru.sql` | EKSİK | `islem_log.degisim_txid` kolonu, 2 fn, trigger, index yok. |
| 16 | `20260914000002_l4_geri_alma_zincir.sql` | EKSİK | `surum_gizli._l4_zaman_txid`, `_degisim_plan`, `_l4_zincir`, `degisim_onizle/geri_al` sürümleri yok. |
| 17 | `20260914000003_l4_onarim.sql` | KISMİ | `surum_gizli.l4_rehber_adimlari` tablosu, `_l4_rehber_uyesi`, `_islem_log_geri_alindi_kapisi`, islem_log trigger/policy yeniden tanımları yok (bir kısım fn #16'daki tanımlarla paylaşıldığından KISMİ). |
| 18 | `20260914000004_l4_stok_uyari_txid.sql` | EKSİK | `_degisim_plan`/`_l4_zincir` dosya sürümleri yok (#16/17'ye bağımlı). |

CANLI görünen 17 dosya için uygulama gerekmez; N/A dosya (`20260902000001_asi_stok_backfill.sql`)
yalnız DML içerir ve **prod'da zaten uygulanmıştır** (veri probe: `STOK-AŞI-%` 12 satır,
Coglavax + Vac-Sules Feedlot bağlı) — yeniden çalıştırılmamalıdır (INSERT guard'sız,
tekrarında 12 satır daha ekler).

## 4. Teşhis: prod'daki sürüm drift'i ve demo drift'i

### 4.1 Prod'da dosyalarla eşleşmeyen canlı sürümler (`diagnosis.json`)
- `gebelik_kaydet_manual` → prod = `20260605000002_timezone_fix.sql` (Haziran) — 20260910000003'ün 42804 fix'i yok.
- `tohumlama_tekrar_kaydet` → prod = `20260722000004_tohumlama_son_kayit_tarih_siralama.sql` (Temmuz).
- `hayvan_ekle` (eski overload) → prod = `20260306000008_blok1_backend.sql` (Mart) — 20260901000002'nin yeni 17-param sürümü AYRI overload olarak CANLI (eski overload düşürülmemiş; çift overload prod'da da demo'da da duruyor).
- `hayvan_guncelle` (bir overload) → prod VE demo'da aynı, hiçbir migration dosyasıyla eşleşmeyen sürüm (md5 67b2d434a3) → canlıya elle uygulanan ortak hotfix izlenimi; prod'a #1-#18 ile dokunulmuyor.
- `_guard_tohumlama_yas_cinsiyet` → prod gövdesi 20260831000003 dosyasınınkinden farklı → prod'a o dönemki WIP sürümü uygulanmış, dosya sonra revize edilmiş.
- `tohumlama_abort(text, text)` (2-param eski overload) → her iki DB'de de dosya-dışı sürüm (md5 4032d1ad88) duruyor; 20260830000033'ün REVOKE'u yalnız 3-param sürüm içindir. Ölçülen ACL (routine_grants): eski overload authenticated+service_role'a EXECUTE açık, **anon'a kapalı** — güvenlik açığı görünümü yok, yalnız dosya-dışı sürüm notu.

### 4.2 Demo'da dosyalardan farklı sürümler (L2/L4 test ortamı dikkat)
- `tohumlama_kaydet` — demo'da 36 dosyanın VE tüm migration geçmişinin hiçbir sürümüyle
  eşleşmeyen bir sürüm var (md5 e4ab00a63d). Demo, branch'teki
  `20260910000002_sperma_eslesme_sertlestirme.sql` sürümünü taşımıyor. Bu 3 dosyayı
  demo-KISMİ yapıyor: 20260830000010, 20260830000034, 20260910000002.
  **Karar noktası (sahibin):** demo'daki bu canlı sürüm bir hotfix ise dosyaya alınmalı;
  alınmadan prod'a 20260910000002 uygulanırsa prod, demo'da test edilenden farklı bir
  tohumlama_kaydet'e kavuşur.
- `protokol_eksik_tara` — demo = `20260730000002_dogum_sonrasi_e_vitamini.sql` (Temmuz);
  20260906000001'in Eylül revizyonu demo'da yok → demo dogum_kaydet'i yeni ama
  protokol_eksik_tara'sı eski.
- İki demo grant teyidi: `pedigree_subgraph → authenticated` EXECUTE **mevcut**,
  `sahip_sifresi_ayarla → service_role` EXECUTE **mevcut** (routine_grants kanıtı).
  Tablodaki ilgili prod FAIL'leri fonksiyonun prod'da hiç olmamasından kaynaklanır.
- Demo `trg_degisim_log`: 39/39 tabloda mevcut (fazla/eksik yok) → L2-F1 demo'da tam.

### 4.3 Veri düzeyi spot-probe sonuçları (prod)
| Kontrol | Sonuç | Yorum |
|---|---|---|
| abort_tarihi backfill | 282 tohumlama, 0 boş | 20260830000010/34 DML'i uygulanmış |
| dogum.olay_id backfill | 72 dogum, 0 boş | 20260901000001 DML'i uygulanmış |
| STOK-AŞI satırları | 12 | 20260902000001 uygulanmış (yeniden koşulmamalı) |
| vaccines bağlantısı | Coglavax ✓, Vac-Sules Feedlot ✓ | aynı |
| ASI_PLANLI görev | 3 kayıt | 20260902000003 DML'i uygulanmış |
| D53 E-Vitamin görevleri | 46 kayıt | 20260906000001 DML'i uygulanmış |
| std_dose / std_dose_min | kolon yok (42703) | 20260909100000+ hiç uygulanmamış |
| buzagi_id | kolon yok (42703) | 20260911000001 uygulanmamış |
| pedigree_nodes / degisim_log | tablo yok (42P01) | L2/pedigree uygulanmamış |

## 5. Riskler

1. **Kilitleme:** Tüm etkilenen tablolar küçüktür (en büyük: islem_log 4253, gorev_log
   3084 satır). `ADD COLUMN`, `CREATE INDEX`, trigger ekleme kilitleri bu boyutta
   milisaniye düzeyidir. Yine de uygulama penceresinde uzun süren açık transaction
   bırakılmamalıdır (AccessExclusive bekleme zinciri).
2. **39 tabloya `trg_degisim_log`:** Her INSERT/UPDATE/DELETE satırı için degisim_log'a
   satır-yazısı eklenir. Prod işlem hacmi düşük olduğundan (islem_log toplam 4253)
   normal kullanımda yük ihmal edilebilir; ancak toplu veri içe aktarma / bulk update
   yapılacaksa degisim_log büyümesi izlenmeli, batch'ler bölünmelidir.
3. **Backfill'ler:** `_dogum_buzagi_backfill` (72 dogum) ve `pedigree_farm_backfill`
   (166 hayvan) küçük veri üzerinde koşar — uzun sürecek backfill riski yoktur.
   Zaten uygulanmış abort/olay_id backfill'leri idempotenttir (COALESCE/0 eksik satır).
4. **Seed'ler isim-eşleşmeli:** dozaj seed UPDATE'leri `WHERE lower(btrim(brand_name)) =
   '...'` koşulludur. Prod `drug_products` 33 satırdır; isimler demo ile birebir
   eşleşmezse seed sessizce 0 satır günceller. Uygulama sonrası
   `SELECT count(*) FROM drug_products WHERE std_dose IS NOT NULL` ile satır sayısı
   demo'dakine yakınsanmalıdır.
5. **Guard gövde farkı (#1):** prod'daki `_guard_tohumlama_yas_cinsiyet` dosyadan
   farklıdır; dosyanın yeniden çalıştırılması prod davranışını değiştirir (dosya
   revizyonu geçerli olur). Bu bilinçli kabul edilmelidir.
6. **Demo-drift (#4.2):** prod'a 20260910000002 uygulanınca tohumlama_kaydet, demo'daki
   test edilen sürümden farklı olur. Sahip kararı olmadan o dosya uygulanmamalıdır.

## 6. Yedek planı (yalnız yazı; uygulanmadı)

**Mevcut durum (Mgmt API `GET /database/backups`):** `pitr_enabled: false`,
`backups: []`, `walg_enabled: true`. Listelenebilir yedek YOK, PITR KAPALI.
→ Migration öncesi elle yedek alınması zorunludur; aksi hâlde geri dönüş kancası yoktur.

1. **Ön yedek (şema + veri):**
   ```bash
   # Değişkenler .env'den; parola asla komuta gömülmez
   export PGPASSWORD="$PROD_DB_PASSWORD"
   pg_dump -h "$PROD_POOLER_HOST" -p 6543 -U "postgres.zqnexqbdfvbhlxzelzju" -d postgres \
     -Fc --schema=public -f "prod_oncesi_$(date +%Y%m%d-%H%M).dump"
   ```
   (Doğrudan bağlantı tercih edilirse host/port Mgmt API
   `GET /v1/projects/zqnexqbdfvbhlxzelzju/database`'ten okunur; pooler 6543
   transaction-mode iken pg_dump için session pooler 5432 ya da direct bağlantı
   kullanılmalıdır.)
2. **Yedek doğrulama:** `pg_restore --list prod_oncesi_*.dump` ile içerik sayımı +
   data_probe_prod.json'daki satır sayılarıyla restore karşılaştırması (166/282/72/
   3084/113/33/12/49/4253).
3. **Uygulama sırası:** §3'teki 18 dosya, dosya-sırasıyla, her biri ayrı transaction;
   hata olursa o dosya durur, öncekiler kalır (hepsi ya da hiç denir? — hayır: her
   dosya kendi içinde atomiktir; dosyalar arası ilerleme kalıcıdır).
4. **Rollback stratejisi:**
   - Fonksiyon/trigger/policy tanımları CREATE OR REPLACE → yeniden koşum güvenli.
   - Kolon/tablo/index eklemeleri IF NOT EXISTS / additif → geri dönüşte
     `ALTER TABLE ... DROP COLUMN`, `DROP TABLE` tek tek uygulanabilir (additif
     oldukları için prod verisini bozmazlar).
   - Eski overload DROP'ları → geri dönüş, ilgili tanımın eski migration'daki metniyle
     yeniden CREATE edilmesidir (kayıp yok).
   - Seed UPDATE'leri absolute SET → tekrar koşum aynı sonucu verir. Tek
     idempotent-olmayan madde `20260902000001` INSERT'idir — o zaten uygulanmıştır,
     listede yoktur.
   - Tam geri dönüş: ön yedek dump'ı AYRI bir restore veritabanına açıp tablo bazlı
     geri kopyalama; prod üzerine doğrudan `pg_restore` yapılmaz.
5. **Uygulama sonrası doğrulama:** `probe.py prod` yeniden koşulur; 18 dosya CANLI'ya döner (36'nın 35'i CANLI, 1'i N/A) ve demo ile eşleşme tablosu yenilenir. Veri probe'larından
   std_dose/buzagi_id/pedigree/degisim_log sayıları beklenen değerlere ulaşır.

## 7. Teslim dosyaları

- Bu rapor: `reports/2026-09-15-prod-migration-olcum.md`
- Ham çıktılar: `reports/2026-09-15-prod-migration-olcum/` — `probe_prod.json`,
  `probe_demo.json`, `queries.sql`, `inventory.json`, `inventory_flat.txt`,
  `verdicts.json`, `diagnosis.json`, `data_probe_prod.json`, `backup_status.json`,
  script'ler (`parse_migrations.py`, `probe.py`, `verdict.py`, `diagnose.py`,
  `data_probe.py`).
- WIP: `aac73a9` (dondurma noktası) — bu commit ile kapanır.
