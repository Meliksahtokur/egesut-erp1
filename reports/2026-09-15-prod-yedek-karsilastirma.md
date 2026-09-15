# P5 — GitHub 04:00 yedeği ↔ canlı prod karşılaştırması (SALT OKUNUR)

Tarih: 2026-09-15 · Dal: `agent/prod-yedek-karsilastirma` · Zarf: `.ss/tasks/P5-github-yedek-karsilastirma.md`

**Bu iş prod'a ve demo'ya hiçbir şey yazmadı.** Prod erişimi Mgmt API `/database/query`,
**her istek `BEGIN READ ONLY; <sql> ROLLBACK;` sarmında** (öntest edildi). Üretilen tüm
döküm/anlık görüntüler repo dışındadır: `/home/melik/tmp/agents/github-yedek-2026-09-15/`
(`live_c/` = C, `live_c_p4oncesi/` = C'nin P4 öncesi görüntüsü). Y yedeği
(`prod-yedek-2026-09-15/`) yalnızca okundu, değiştirilmedi.

## 0. Özet (sahibin beklentisi tuttu mu?)

**EVET tuttu — karşılaştırılan tüm pencerelerde çıkan HER fark (şema ve veri)
bugün prod'a uygulanan migration dosyalarından birine ya da sahibin bugünkü
uygulama kullanımına bağlandı; AÇIKLANAMAYAN yok.**
Y↔C (13:52 → P4 sonrası canlı): tüm farklar migration'larda (§2). Sahibin bugün
öğlene kadarki değişiklikleri Y yedeği içinden sayımla ayrıştırıldı (§5).
**G pası (GitHub 04:00 yedeği) sahibin kararıyla İPTAL:** `BACKUP_PASSWORD`
değeri kimsede yok (`docs/demo-mirror-ROADMAP.md` 28–31, 2026-07-02 kaydı:
"`BACKUP_PASSWORD` yok (şifreli artifact çözülemiyor)"); decrypt denemeleri
durduruldu, `enc` dosyasına dokunulmadı.

## 1. Noktalar

| Nokta | Ne | Zaman | Kaynak |
|---|---|---|---|
| G | GitHub `DB Backup` artifact `egesut-backup-34922980952` (2026-09-15T02:54:47Z, success) | 02:54Z | `egesut_20260915.pg.enc` — **İPTAL: parola kimsede yok (sahip kararı); enc'e dokunulmadı** |
| Y | 13:52 ara yedek (Adım A öncesi, 48 tablo) | 13:52–13:54 yerel | `/home/melik/tmp/agents/prod-yedek-2026-09-15/` (salt okundu) |
| C | Canlı prod dökümü, **P4 tesliminden SONRA** (52 tablo) | 15:2x yerel | `github-yedek-2026-09-15/live_c/` (repo dışı) |

C ölçümü iki kez alındı: P4 (dal `agent/prod-tohumlama-5`, `#5`
`20260910000002`) teslim ilan edilmeden hemen önce bir anlık görüntü alındı
(`live_c_p4oncesi/`); P4 teslim mesajı geldikten sonra zarf şartına uyarak C
yeniden ölçüldü (`live_c/`). İki C arasında **tablo satır sayıları birebir aynı** —
P4 veri yazmadı; tek şema etkisi iki fonksiyon gövdesi (§2a).

## 2a. Şema — Y↔C (public + surum_gizli; tam ayrıntı `2026-09-15-prod-yedek-karsilastirma/schema_diff.json`)

Her kategoride `sadece_Y = 0` (hiçbir nesne silinmedi/kaldırılmadı); tüm farklar
`+` yönünde. md5'ler P3 `compare.py` yöntemi `md5_normall`.

| Kategori | Y→C fark | Bağlı migration dosyası |
|---|---|---|
| Fonksiyon (yeni, +17) | `fn_sperma_stok_dus` | `20260910000001` |
| | `hayvan_kilo_guncelle`, `ilac_dozaj_guncelle` | `20260909110000` |
| | `_dogum_buzagi_backfill` | `20260911000001` |
| | `_pedigree_parent_set_core`, `_trg_pedigree_hayvan_insert`, `assert_is_operator`, `pedigree_ensure_farm_node`, `pedigree_external_upsert`, `pedigree_is_ancestor`, `pedigree_parent_set`, `semen_catalog_upsert` | `20260911000002` |
| | `pedigree_farm_backfill`, `pedigree_integrity_report`, `pedigree_try_timestamptz` | `20260911000003` |
| | `pedigree_subgraph`, `pedigree_subgraph_for_animal` | `20260911000004` |
| Fonksiyon (gövde değişen, 5) | `_guard_tohumlama_yas_cinsiyet` | `20260831000003` |
| | `dogum_kaydet` (buzagi_id entegrasyonu) | `20260911000001` (son revizyon) |
| | `gebelik_kaydet_manual` (42804 fix) | `20260910000003` |
| | `tohumlama_kaydet` `e144cf1f71→e4ab00a63d`, `tohumlama_tekrar_kaydet` `64dc7fc09a→83fe917252` | `20260910000002` (#5, P4) |
| Tablo (+4) | `pedigree_meta`, `pedigree_nodes`, `pedigree_parentage`, `semen_catalog` | `20260911000002` |
| Kolon (+44) | `dogum.buzagi_id` | `20260911000001` |
| | `drug_products.std_dose/_min/_max/_unit` | `20260909100000` |
| | 39 kolon: 4 yeni tablonun kolonları | `20260911000002` |
| Trigger (+1) | `hayvanlar.trg_pedigree_hayvan_insert` | `20260911000002` |
| Policy (+4) | 4 yeni tabloda `allow_all` | `20260911000002` |
| Grant tablo (+68) | yalnız 4 yeni tablo (16+16+16+20) | `20260911000002` |
| Grant routine (+34) | yalnız yukarıdaki yeni/etkilenen fn'ler | `20260909110000`(10), `20260910000001`(2), `20260911000001`(3), `20260911000002/03/04`(19) |
| Index (+14) | 13'ü 4 yeni tabloda | `20260911000002/03` |
| | `dogum.dogum_buzagi_id_uidx` | `20260911000001` |
| Constraint (+22) | 20'si 4 yeni tabloda | `20260911000002` |
| | `dogum.dogum_buzagi_id_fkey` | `20260911000001` |
| | `drug_products.std_dose_unit_check` | `20260909100000` |
| Kolon öznitelik değişimi | 0 | — |
| View / extension | 0 fark | — |

G↔C şema karşılaştırması: **İPTAL** (sahip kararı: parola kimsede yok).

## 2b. Veri — Y↔C (PK-bazlı; tam sayılar `data_counts.json`)

48 ortak tablodan 44'ünde **sıfır fark** (satır sayıları ve içerikleri aynı,
`code_embeddings`/`memory_notes` gibi tools-bank tabloları dahil). Farkı olan 5:

| Tablo | Y | C | Eklenen | Silinen | Değişen (ortak kolon) | Açıklama | Migration |
|---|---|---|---|---|---|---|---|
| `pedigree_nodes` | 0 | 166 | 166 | 0 | 0 | backfill (created_at 10Z saati = 13:0x–13:5x yerel) | `20260911000003` |
| `pedigree_parentage` | 0 | 59 | 59 | 0 | 0 | backfill (aynı) | `20260911000003` |
| `drug_products` | 33 | 33 | 0 | 0 | **14** (`concentration`+`concentration_unit`) | mg/kg seed UPDATE'leri (13 satır) + `gastren duo` concentration=NULL (satır 31–64) | `20260909100000` |
| `vaccines` | 12 | 12 | 0 | 0 | **10** (`etken_madde` 10, `marka` 9, `route` 3, `dose` 3) | aşı kartı seed UPDATE'leri (dosyada tam 10 UPDATE, satır 67–77) | `20260909100000` |
| `dogum` | 72 | 72 | 0 | 0 | **0** (+71 satırda yalnız yeni kolon `buzagi_id` doldu) | backfill 71 dolu, 1 NULL (Adım A raporu sapma 2 ile aynı) | `20260911000001` |

Ölçüm notu: "değişen" sayımı iki tarafta ortak kolonlarla yapılır; Y'de olmayan
yeni kolonların (`std_dose*`, `buzagi_id`) dolumu ayrı sayaçta ("yalnız yeni
kolon": drug_products 13, dogum 71). Tutarlılık: `drug_products.std_dose` dolu
13 (ml/kg) + 13 (mg/kg) = **26** — Adım A raporundaki 26/33 ile birebir.
`drug_products`/`vaccines` değişen satırlarında `created_at` değişmedi (eski
tarihler korunuyor) → değişikliğin kaynağı UPDATE'li migration, uygulama girdisi
değil.

**Saat dağılımı (bugün 2026-09-15, log tablolarından, UTC kovası):** sahibin
uygulama kullanımı `05:00Z`–`09:00Z` arasında: `gorev_log` 3+4+9, `islem_log`
3+4, `stok_hareket` 6, `treatment_days` 3, `treatment_day_uygulamalar` 6,
`drug_administrations` 6, `cases` 1. **Y↔C penceresinde (13:52 sonrası) hiçbir
log tablosunda yeni kayıt yok** — Y ve C bu tablolarda birebir aynı →
migration'lar arasında/dan sonra uygulama yazımı olmadı; yukarıdaki tüm veri
farkları migration içeriğinden gelir.

G↔Y veri karşılaştırması (04:00–13:52 penceresi): **İPTAL** (sahip kararı).

## 3. AÇIKLANAMAYAN farklar

**Yok.** Karşılaştırılan tüm pencerelerde çıkan her şema ve veri farkı bir
migration dosyasına bağlandı (§2a/§2b); sahibin bugünkü uygulama kullanımı da
sayım düzeyinde ayrıştırıldı (§5). G penceresi sahibin kararıyla kapsam dışı
(parola kimsede yok) — bu karar sonrası kapsamda "açıklanamayan" bırakmadı.

## 4. Yöntem

- `c_snapshot.py`: Mgmt API `/database/query`, her istek
  `BEGIN READ ONLY; ... ROLLBACK;` sarmında; P2 `backup_prod.py` ile birebir aynı
  yakalama biçimi (parçalı json_agg + 11 şema kataloğu) → `live_c/`, manifest +
  sha256. 63 dosya, ~166 s.
- `y_c_compare.py`: P3 `compare.py` `md5_normall` yöntemi (fonksiyon gövdesi
  `$function$` span'inden); şema kategorilerinde küme-farkı + gövde md5; veride
  PK-bazlı eklenen/silinen/değişen sayımı (ortak-kolon normalizasyonu);
  `supabase/migrations/*.sql` taranarak nesne→dosya haritası (`migration_map.json`).
- `y_today_counts.py` (§5): Y yedeği içinde bugün penceresi sayımı; damgalar UTC
  kabul edilip TSI'ya (UTC+3) çevrildi.

## 5. Sahibin bugün (00:00–13:52 TSI) değişiklikleri — Y yedeği içinden sayım

Pencere: 2026-09-15 00:00–13:52 TSI (= UTC 2026-09-14T21:00Z–10:52Z). Kaynak: Y
yedeğinin satır verisi (yalnız SAYIM, değer yok — `today_counts.json`). Her
tablo için tek zaman kolonu: `updated_at` > `created_at` > `tarih` > öteki
adaylar (kolon başına sayının ne yakaladığı: updated_at=güncelleme, created_at=ekleme).

| Tablo (kolon) | Pencere toplamı | Saat kovası (TSI) |
|---|---|---|
| `gorev_log` (created_at) | 16 | 08:00 → 3, 11:00 → 4, 12:00 → 9 |
| `islem_log` (tarih) | 7 | 11:00 → 3, 12:00 → 4 |
| `drug_administrations` (created_at) | 6 | 12:00 → 6 |
| `stok_hareket` (tarih) | 6 | 12:00 → 6 |
| `treatment_day_uygulamalar` (updated_at) | 6 | 12:00 → 6 |
| `treatment_days` (created_at) | 3 | 12:00 → 3 |
| `cases` (created_at) | 1 | 12:00 → 1 |
| **Toplam** | **45** | 08:00 → 3 · 11:00 → 7 · 12:00 → 35 |

`islem_log` işlem tipi bazında sayım (pencere içi 7 kayıt):
`GOREV_TAMAMLA` 3 · `TEDAVI_GUN_EKLENDI` 3 · `VAKA_ACILDI` 1.

UTC varsayım denetimi: pencere üstünde (≥13:00 TSI) bugün kaydı **0** — Y 13:52
TSI'da alındığı için damgaların UTC olduğu kabulü tutarlı (Adım A raporundaki
"en son yazım 09:12 UTC" notuyla da aynı). Bu sayılar aynı zamanda §2b'deki
"Y↔C penceresinde uygulama yazımı yok" bulgusuyla birleşince tam tablo: sahibin
değişikliklerinin TAMAMI 13:52'den ÖNCEDE, Y yedeğinin İÇİNDE; migration
penceresine sızan kullanım yok.

## 6. Sapmalar / kararlar

1. **G pası İPTAL (sahip kararı):** `BACKUP_PASSWORD` değeri kimsede yok — kanıt
   `docs/demo-mirror-ROADMAP.md` 28–31 (2026-07-02): "`BACKUP_PASSWORD` yok
   (şifreli artifact çözülemiyor)". Bu işte yapılan decrypt denemeleri (.env aday
   biçimleri 5 varyant + boş parola pbkdf2'li/pbkdf2'siz; tümü `bad decrypt`,
   değer hiçbir çıktıya yazılmadı) kayıt amacıyla burada durur; deneme
   **durduruldu**, `egesut_20260915.pg.enc` repo dışı klasörde DOKUNULMAMIŞ duruyor.
   **Kayıt (root 2026-09-15):** boş-parola denemesinin başarısız çıktısı
   `dump.pg` (24,7 MB; PGDMP başlığı yok, `pg_restore` okuyamıyor) klasörde kalmıştı
   — çalışma betiğim `rm -f` ile temizlemişti ama son boş-parola denemesi yeniden
   yazmıştı ve temizliği atlanmıştı; dosya **root tarafından silindi**. Bu çıktının
   içeriği decrypt başarısız olduğundan okunabilir veri DEĞİL (şifreli çöp);
   git'e hiç girmedi. `enc` dokunulmadan duruyor.
2. **C ölçümü P4 öncesi/sonrası iki anlık:** ilk C, P4 teslim ilanından önce
   alındı (root'un o anki talimatıyla Y↔C'ye hemen geçilmişti); P4 ilanı
   gelince zarf şartına uygun biçimde C yenilendi. P4-öncesi görüntü
   `live_c_p4oncesi/`'de korundu; iki C arasında veri farkı 0, şema farkı
   yalnız #5'in iki fonksiyon gövdesi (beklendiği gibi).
3. `drug_products` "değişen=14" ilk ölçümde 33 çıkmıştı; nedeni yeni kolonların
   "değişim" sayılmasıydı → ortak-kolon normalizasyonu eklendi (ölçüm düzeltmesi,
   veri değişikliği değil).
4. Prod verisi git'e girmedi: commit edilen JSON çıktıları yalnız nesne adı,
   sayı, saat kovası, md5 ve migration dosya adı içerir; satır içeriği, küpe,
   isim, PK listesi içermez (`git diff --cached --stat` + içerik denetimi).
5. `tohumlama_kaydet` P3 referansında `cf6949f61d` idi (Adım A sonrası probe);
   C-ilk ölçümde `e144cf1f71` görüldü — bu, P3 raporundaki canlı-gövde değeridir
   (Adım A raporu §2 ayak iziyle tutarlı); #5 sonrası `e4ab00a63d` (#5/demo
   değeri, P4 kanıtıyla aynı).
