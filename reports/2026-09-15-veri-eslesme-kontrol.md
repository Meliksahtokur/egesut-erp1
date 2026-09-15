# Prod veri eşleşme kontrolü — 2026-09-15 (P6)

Soru: **bugün prod'a uygulanan 10 migration (Adım A 9 dosya + #5) prod'a demo/test
verisi soktu mu?**

Araç: `scripts/veri-eslesme-kontrol.py` (kalıcı; her prod uygulamasından sonra
tekrar koşulur). Bu koşu: `python3 scripts/veri-eslesme-kontrol.py hepsi`.
Çıktı dizini (repo dışı, ayrıntılar orada): `~/tmp/agents/veri-eslesme-20260915/`.

## Hüküm

```
HÜKÜM: BULGU: 59 (betik, mekanik)
```

İnsan değerlendirmesiyle: **bugünkü 10 migration prod'a demo/test verisi
SOKMADI.** Betiğin `BULGU: 59`'u 59 tablo×kolon×işaret eşleşme kombinasyonudur;
dağılım ve gerekçeler aşağıda. Tek gerçek veri bulgusu, migration'lardan aylar
önce (2026-05-16 – 2026-06-06) açılmış sahibin 6 test hayvan kaydıdır —
migration kaynaklı değildir, silinmesi ayrı sahip kararıdır.

Salt-okunur kanıt: betik açılışında her iki DB'de READ ONLY guard self-test
koşar (`BEGIN READ ONLY; CREATE TEMP TABLE ...` → **reddedildi**, `read-only`
hatası döndü); tüm sorgular `BEGIN READ ONLY; ... ROLLBACK;` sarmındadır.
Prod'a ve demo'ya hiçbir şey yazılmadı; `sorgular.sql` kanıt dosyası çıktı
dizininde.

## Kontrol 1 — `sizinta` (demo-doğumlu satırın prod'da bulunması)

| Ölçüm | Değer |
|---|---|
| Ortak tablo (public, iki DB'de de) | 49 |
| PK'sız (kontrol edilemeyen) tablo | 0 |
| Satır sayısı eşiği (100k) aşıp atlanan tablo | 0 |
| Demo-doğumlu satır toplamı (demo PK − prod PK) | 1950 |
| **SIZINTI** (demo-doğumlu PK'nın prod'da bulunanı) | **0** |
| Prod-only satır toplamı (bilgi: sahibin gerçek kullanımı) | 1834 |

Notlar:

- Zarf formülü (demo PK kümesi − prod PK kümesi elemanlarının prod'da aranması)
  tanımı gereği her zaman 0 döner; betik yine de her tablo için prod'da ayrı
  sorgu ile kanıtlar. Kopya sonrası doğumu `created_at` sinyaliyle yakalayan
  `--kopya-tarihi` parametresi eklendi; bu koşuda verilmedi (kopya tarihi
  belgeli değil), sinyal koşulmadı.
- Sızıntının asıl görünür kanalı bu koşunun kontrol 2 bulgusuyla çelişmez:
  prod'daki 6 test hayvanının PK'sı demo'da da mevcuttur (6/6) — yani kopya
  yönü prod→demo'dur (demo, prod'dan kopyalanmıştır); demo→prod sızıntısı yok.

## Kontrol 2 — `isaret` (prod'da test işaretleri)

14 sabit işaret tarandı (`l4-yuruyus, fixture, deneme, test, demo, w2b,
k1..k6, yuruyus, root-gate`; ≤3 karakter olanlar kelime sınırlı eşleşti).
Sonuç: **59 kombinasyon / 2550 satır** (işaret→satır: deneme 1671, test 863,
demo 5, k5 3, fixture 2, k1 2, k2 2, k3 1, k4 1). Değerlendirme:

| Kategori | Örnek (tablo×kolon×işaret = satır) | Hüküm |
|---|---|---|
| **Gerçek: sahibi test hayvanları** | `hayvanlar.kupe_no`×test = 6 | **GERÇEK** — 6 kayıt, adında "Test" kelimesi. `created_at` 2026-05-16…2026-06-06: bugünkü migration'lardan (2026-09-09…11) aylar önce. Migration kaynaklı değil; sahibin kendi prod testleri. |
| aynı kayıtların view yansımaları | `hayvan_durum_view.kupe_no`×test = 6, `treatment_timeline.kupe_no`×test = 29, `hayvanlar.notlar`/`hayvan_durum_view.notlar`×test = 1+1 | GERÇEK ama tek kaynak: üçü de VIEW; kaynağın (6 hayvan) yansıması, ayrı satır değil |
| ilişkili işlem kayıtları | `stok_hareket.notlar`×test = 16, ×deneme = 5 | GERÇEK — aynı test hayvanlarının stok/tohumlama hareketleri ("… deneme — Test …" biçimli notlar) |
| alan adı yanlış pozitifi | `islem_log.snapshot`×deneme = 1170+73, `hayvan_timeline_view.detay`×deneme = 288, `islem_log.payload`×test/deneme = 48 | YANLIŞ POZİTİF — jsonb içindeki **`deneme_no` şema alanının adı** her snapshot'ta geçer; tohumlama deneme numarası işletme kavramı |
| ajan altyapı tabloları | `code_embeddings`×test/deneme = 663+, `memory_notes`×test = 69 (+tags 22), `goose_embeddings`×test = 30, `agent_messages`×test = 12; `k1..k5`, `fixture`, `demo` eşleşmelerinin tamamı yalnız bu tablolarda | YANLIŞ POZİTİF — bu makinenin ajan araç tabloları (kod gömme, not); ERP verisi değil, demo verisi de değil |

Önemli negatif sonuç: **`k1..k6` test küpe etiketleri prod ERP tablolarında
hiçbir eşleşme vermedi** (yalnız `memory_notes` not metinlerinde geçer) — L4
yürüyüş kupeleri (`k1..k6`), `l4-yuruyus`, `w2b`, `root-gate` işaretleri
prod'da yok.

## Kontrol 3 — `koken` (yeni tablo/kolonların prod kaynağa bağlanması)

| Bağ | Tip | Yetim/bağlanamayan |
|---|---|---|
| `pedigree_nodes.farm_animal_id` → `hayvanlar` | FK | 0 |
| `pedigree_parentage.(farm_id,child_node_id)` → `pedigree_nodes` | FK | 0 |
| `pedigree_parentage.(farm_id,parent_node_id)` → `pedigree_nodes` | FK | 0 |
| `semen_catalog.(farm_id,bull_node_id)` → `pedigree_nodes` | FK | 0 |
| `semen_catalog.stock_id` → `stok` | FK | 0 |
| `dogum.buzagi_id` → `hayvanlar.id` | FK (doldurulan kolon) | 0 |
| `semen_catalog.display_name` ↔ `tohumlama.sperma` | ad eşleşmesi | 0 |
| `drug_products.std_dose` dolu satır (bilgi) | seed | 26 satır |

**YETİM = 0.** Migration'ların doldurduğu her satır prod'daki gerçek kaynağa
bağlı; `semen_catalog` girişlerinin tamamı prod `tohumlama` sperma adlarına
eşleşiyor.

## Kontrol 4 — `statik` (migration DML'lerinin sınıflandırılması)

10 dosyada 85 doğrudan DML ifadesi:

| Dosya | sabit | rpc-govdesi | türetilmiş |
|---|---|---|---|
| 20260909100000_dozaj_std_dose_seed | 37 | 0 | 0 |
| 20260909110000_dozaj_helper_min_max_rpc | 10 | 2 | 0 |
| 20260910000001_planli_tohumlama_sperma_dus | 0 | 1 | 0 |
| 20260910000002_sperma_eslesme_sertlestirme | 0 | 13 | 0 |
| 20260910000003_gebelik_kaydet_manual_42804_fix | 0 | 2 | 0 |
| 20260911000001_dogum_buzagi_id_foundation | 0 | 13 | 0 |
| 20260911000002_pedigree_foundation | 0 | 7 | 0 |
| 20260831000003, 20260911000003, 20260911000004 | 0 | 0 | 0 |
| **Toplam** | **47** | **38** | **0** |

- **Türetilmiş = 0**: hiçbir migration `INSERT … SELECT`/`UPDATE … FROM` ile
  bir prod tablosundan diğerine satır kopyalamıyor — demo verisi taşıyan bir
  backfill-DML yok.
- **47 sabit değerin tamamı** `drug_products` doz seed'i (marka adına göre
  std_dose / std_dose_min / std_dose_max): **referans veridir** (prospektüs
  kaynaklı doz aralıkları), demo/test verisi değildir. Ürün adı bazlı
  koşulludur; prod'da 26 satır yakalamıştır (kontrol 3).
- **38 rpc-govdesi**: fonksiyon gövdelerinde parametreli/koşullu DML —
  çalışma zamanında çağıranın verisiyle koşar, sabit veri yazmaz.
- `20260911000003_pedigree_farm_backfill` doğrudan DML içermiyor: backfill'i
  yapan RPC'yi tanımlar (dolaylı yol;RPC gövdeleri yukarıda sınıflanmıştır).

## Betik kullanımı

```bash
python3 scripts/veri-eslesme-kontrol.py hepsi          # hepsi (önerilen)
python3 scripts/veri-eslesme-kontrol.py sizinta        # yalnız PK-sızıntı kontrolü
python3 scripts/veri-eslesme-kontrol.py isaret --ek-isaret eksper
python3 scripts/veri-eslesme-kontrol.py koken
python3 scripts/veri-eslesme-kontrol.py statik --dosya 20260912000001
python3 scripts/veri-eslesme-kontrol.py sizinta --kopya-tarihi 2026-06-01T00:00:00+03:00
python3 scripts/veri-eslesme-kontrol.py hepsi --cikti /ozel/dizin
```

- **Ne zaman koşulur:** her prod migration uygulamasından sonra; ayrıca demo
  kopyası alındığında `--kopya-tarihi` ile.
- Bağlantı: Management API (`SUPABASE_MANAGEMENT_TOKEN` @ tools-bank/.env;
  `SUPABASE_DEMO_REF`+`SUPABASE_DEMO_PAT` @ egesut-erp1/.env). Token hiçbir
  çıktıya yazılmaz.
- Çıktı: `ozet.json` (yalnız sayı/ad) + `sorgular.sql` (kanıt) +
  `isaret-baglam.txt` (eşleşme bağlamları — satır değeri içerdiğinden yalnız
  repo-dışı çıktı dizininde) — varsayılan `~/tmp/agents/veri-eslesme-<tarih>/`.
- Hüküm: `TEMIZ` / `BULGU: <n>` (n = sızıntı + yetim + işaret kombinasyonu);
  sorgu hatası varsa `HATA: <n> sorgu koşulamadı` (bu koşuda hata 0).

## Bu koşunun özet tablosu

| Kontrol | Sonuç |
|---|---|
| sizinta | SIZINTI 0 (49 ortak tablonun tamamında) |
| isaret | 59 kombinasyon / 2550 satır → 6'sı gerçek (migration-dışı, eski), geri kalanı alan adı + ajan tablosu yanlış pozitifi |
| koken | YETİM 0 (7 bağ da 0) |
| statik | türetilmiş 0; sabit 47 (hepsi referans seed); rpc-govdesi 38 |

**Sonuç: bugünkü 10 migration açısından prod TEMİZ.** Prod'daki bilinen tek
test izi, migration öncesi döneme ait 6 test hayvan kaydı ve ilişkili
hareketleridir (sayılar yukarıda; küpe/ad/PK bu rapora bilinçli olarak
yazılmadı — ayrıntılar çıktı dizininde).
