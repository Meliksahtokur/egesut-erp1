# L4-W1 — Geri alma motoru genişletmesi: DB teslim raporu

**Goal:** G-20260914-GERI-ALMA-AKISI (FAZ B, W1) · **Dal:** `agent/geri-alma-akisi-W1`
(taban 245c370 = `agent/geri-alma-akisi` L4 FAZ B açılışı) · **Tarih:** 2026-09-14
**Durum:** TESLIM — frozen contract §1-6 uygulandı, k4 22/22 + k3 regresyon 46/46,
unit 938/938/0. PROD'a hiçbir şey uygulanmadı.

---

## 1. Teslim kapsamı (dosyalar)

| Dosya | İçerik |
|---|---|
| `supabase/migrations/20260914000001_l4_islem_log_kopru.sql` | §1: `islem_log.degisim_txid bigint` + BEFORE INSERT trigger (`txid_current()`, `WHEN NEW.degisim_txid IS NULL`) + index. Blob SHA (git): `708edb7ef882a2d3377bc0deab4003c37de3bda5`, sha256 ilk-16: `4bff616ce2f19d36` |
| `supabase/migrations/20260914000002_l4_geri_alma_zincir.sql` | §2-6: `_l4_zaman_txid` helper, `_degisim_plan` genişletmesi (zaman hedefi + neden detayı + TAM çakışma listesi), `_l4_zincir` zincir planlayıcısı (K1), `degisim_onizle`/`degisim_geri_al` zincir yönlendirmesi + telafi kaydı. Blob SHA (git): `f8fbfd0a6da807efdcb5a1d7d6db3a662fffdaa9`, sha256 ilk-16: `efc2ed12964b7919` |
| `reports/2026-09-14-geri-alma-akisi-W1/k4_l4_motoru.{sql,out}` | Kabul koşumu (gitignored; kanıt .out'ta, özet §3'te) |
| `reports/2026-09-14-geri-alma-akisi-W1/k3_regresyon.out` | V9 regresyon koşumu |
| `reports/2026-09-14-geri-alma-akisi-W1/probe_sema{,2,3,3b}.{sql,out}` | Canlı şema yoklamaları (salt-okunur) |

İmza değişikliği YOK: 4 public RPC'nin imzası aynı (`degisim_onizle(jsonb,text)`,
`degisim_geri_al(jsonb,text,uuid,text)`, `degisim_listele(jsonb)`,
`geri_alma_bileti_al(text)`). Yeni p_seviye `'zincir'` ve yeni opsiyonel hedef
anahtarları (`zaman`, `l4_rehber`) ADDITIVE.

## 2. DB erişim beyanı

Yalnız DEMO (`vtzqjmazsvurxdeondmi`) dokunuldu. Kullanılan bağlantı deseni
(zarfın aynen):

```
set -a; source /home/melik/egesut-erp1/.env; set +a;
PGPASSWORD="$SUPABASE_DEMO_DB_PASSWORD" psql \
  "postgresql://postgres.$SUPABASE_DEMO_REF@$SUPABASE_DEMO_POOLER:5432/postgres?sslmode=require" \
  -f <betik>
```

PROD (`zqnexqbdfvbhlxzelzju`) veya başka hiçbir projeye bağlanılmadı — bu
oturumda PROD ref'i hiçbir komutta geçmedi. Neon şema aynası (yerel) yalnız
`db-dry-run`/postgrestools statik kontrolleri için kullanıldı (migration 1 temiz;
migration 2 aynada doğrulanamaz — ayna PROD şeklidir, `surum_gizli` L2 ile
yalnız DEMO'dadır; runtime doğrulama DEMO'da yapıldı).

## 3. Kabul kanıtları — V1..V9

Koşum komutları ve EXIT kodları (hepsi DEMO):

| Koşum | Komut | EXIT |
|---|---|---|
| Migration uygulama | `psql … -v ON_ERROR_STOP=1 -f supabase/migrations/20260914000001_l4_islem_log_kopru.sql` | 0 |
| Migration uygulama | `psql … -v ON_ERROR_STOP=1 -f supabase/migrations/20260914000002_l4_geri_alma_zincir.sql` | 0 (son gövde; replay da 0) |
| k4 kabul | `psql … -v ON_ERROR_STOP=1 -f reports/2026-09-14-geri-alma-akisi-W1/k4_l4_motoru.sql` → `k4_l4_motoru.out` | 0 |
| k3 regresyon | `psql … -v ON_ERROR_STOP=1 -f reports/2026-09-13-surum-gecmisi-W1/k3_geri_alma.sql` → `k3_regresyon.out` | 0 |
| Unit baseline | `NODE_PATH=/home/melik/egesut-erp1/node_modules node --test tests/unit/*.test.js` | 0 |

### k4 sonuç tablosu (22/22 PASS — tam satırlar `k4_l4_motoru.out` içinde)

| Vaka | Sonuç |
|---|---|
| S0 şifre kur | PASS |
| V1a zaman: kayit_zamani verilir → aynı tx eşleşir | PASS |
| V1b zaman: 120 sn aşan → HEDEF_BULUNAMADI + ZAMAN_ESLESME_YOK (en_yakin dolu) | PASS |
| V1c txid + zaman birlikte → txid kazanır | PASS |
| V1d olmayan (geçerli-tip) pk → neden=SATIR_YOK | PASS |
| V1e var olan ama logsuz satır → neden=LOG_YOK | PASS |
| V1f zincir boş txid → neden=LOG_YOK | PASS |
| V2 köprü: aynı tx'te iş satırı + islem_log INSERT → degisim_txid == degisim_log.txid | PASS |
| V4a zincir çapraz-satır: dogum bağımlı adım (BAGIMLI_ADIM), sıra dogum→tohumlama→tohumlama | PASS |
| V4b çapraz zincir uygula: 3 adım tek tx, tek geri_alma_txid; tohumlama=0 dogum=0 hayvan=1 | PASS |
| V6a telafi: GERI_ALINDI + ana_hayvan_id + payload{orijinal_tip=I,U, seviye=zincir, adim=3} | PASS |
| V6b orijinal islem_log satırı değişmedi (tam-satır karşılaştırma) | PASS |
| V8a satır hedef E1 → çakışma TAM liste (E2 VE E3) + zaman/degisen_alanlar/islem/log_id | PASS |
| V8b alan hedef (E2/ad) → ad'a dokunan TÜM sonraki değişiklikler (E3) | PASS |
| V3a zincir aynı-satır: 3 adım, sira E3→E2→E1 | PASS |
| V3b zincir uygula: TEK transaction, tek geri_alma_txid, satır silinir | PASS |
| V6c padok zincirinin telafi kaydı (adim=3, orijinal_tip=I,U) | PASS |
| V5a rehber: kaymalı zincirde geri_alinabilir=false, rehber plan sıralı (kaymalı birim dışarıda) | PASS |
| V5b rehber sırasıyla tekil geri alma: 2/2 ok | PASS |
| V7 zincir >100 adım → GECERSIZ_HEDEF + ZINCIR_COK_UZUN | PASS |
| V7b başlangıç adımı >100 (tx genişliği) → ZINCIR_COK_UZUN | PASS |
| TEMIZLIK: log=0 padok=0 hayvan=0 islem_log=0 | PASS |

### V3 lead probe senaryosu

`reports/2026-09-14-geri-alma-akisi-plan/olcum_zincir.sql` (lead worktree,
gitignored) deseni birebir kuruldu: padokta E1 INSERT + E2/E3 UPDATE → E1
zincir hedefi 3 adım, sira E3→E2→E1 (V3a `plan[0]=E3 log_id, plan[2]=E1 log_id`
kanıtlı), tek `geri_alma_txid` ile döndü (V3b).

### V9 regresyon

k3 46 vaka: **46 PASS / 0 FAIL** (`k3_regresyon.out` özet: `46 | 0 | 46`).
Not: S6c, L2'nin katı çakışma kuralının korunduğunu bu koşumda yeniden kanıtladı
(ilk taslaktaki global gevşetme S6c'yi kırmıştı; §4.3'teki işaret-geçişli
tasarımla düzeltildi).

### Unit baseline

`tests 938 · pass 938 · fail 0 · skipped 0` — taban (d4bd07f/245c370) ile aynı.

### Temizlik beyanı (S11 deseni)

Son koşum sonrası ölçüm: işaretli degisim_log=0, l4w1 padok/hayvan/tohumlama/dogum=0,
işaretli islem_log=0, sahip şifresi=0 (k3-öncesi baseline), bilet=1 (k3'ün
belgelediği ön-varolan bilet — dokunulmadı).

## 4. Tasarım notları (lead + W2 için)

1. **Zincir kapsamı (K1) — somut kural:** kapanış üç kaynaktan büyür:
   (a) zincirdeki her (tablo,pk) için hedef adımından SONRAKI tüm girişler;
   (b1) zincirdeki INSERT adımlarının FK çocukları — izlenen çocuğun hedef'ten
   sonraki girişleri `BAGIMLI_ADIM`, aynı-tx çocuğu `KADEMELI`, izlenmeyen
   (logsuz) çocuk confdeltype≠'n' ise aşılamaz `ENGEL` (bypass yok);
   (b2) hayvan köprüsü — hedef satırın hayvanına (kolon listesi:
   hayvan_id/ana_hayvan_id/animal_id/anne_id/buzagi_id/farm_animal_id,
   degisim_listele ile aynı) bağlı satırlarda hedef'ten sonra doğmuş
   (islem='I') kayıtlar. **Üst taraf (hayvanlar satırının kendisi, ör. kilo
   güncellemesi) ve kardeş satırların U/D düzenlemeleri zincire girmez.**
   Köprü kolon eşleşmesi kolon-adı-varlığı ile yapılır (FK katı denetimi değil
   — degisim_listele precedent'i).
2. **Ölçülmüş canlı gerçek:** `tohumlama.hayvan_id` → hayvanlar FK var;
   `dogum`'un tohumlama'ya FK'sı YOK (yalnız `anne_id`/`buzagi_id` → hayvanlar).
   Dolayısıyla S3b zinciri yalnız hayvan köprüsüyle kurulur — V4 bunu kanıtlar.
   Ayrıca ölçüldü: `tohumlama.sonuc='Gebe'` UPDATE'i demo'da
   `trg_tohumlama_gebe_gorev` ile aynı tx'te protokol+görev doğurur — bu
   girişler zincire doğru şekilde girer (motor 7-adımlı zinciri hatasız
   döndürdü); k4 test sahnesi belirleyici olması için bu tetikleyiciyi seed
   UPDATE'i sırasında seçici kapatır (trg_degisim_log açık kalır).
3. **Sıralı rehberin çalışması için motor rafinasyonu (işaret-geçişli):**
   L2'nin katı çakışma kuralı, "önce 5'i, sonra 4'ü geri al" akışını bloklar
   (geri dönülmüş sonraki değişiklik hâlâ log'dadır ve SONRAKI_DEGISIKLIK
   sayılır — k3 S6c bu davranışı dondurur). Çözüm: rehber birimlerinin
   hedefleri `'l4_rehber': true` taşır; yalnız bu işaretli hedeflerde geri-alma
   izleri (`kaynak.geri_alma`) ve etkisi sonradan dönülmüş sonraki
   değişiklikler çakışma sayılmaz. İşaretsiz her çağrıda L2 kuralı AYNEN
   (k3 46/46 kanıtı). W2: rehber birimlerinin hedefini olduğu gibi RPC'ye
   geçmeli; kendi kurduğu hedeflere bu anahtarı KOŞMAMALI.
4. **Rehber sırası plan adım sırasıdır** (aynı satırda en yeni önce; bağımlı
   birim bağlandığı birimden önce, EKLE'ler anne-önce topo) — düz zaman-DESC
   çapraz-satırda uygulanamaz sıra üretir. Her birim plan-önek durumunda tekil
   geri alınabilir (V5b). Durum kaymalı (GUNCEL_DURUM_FARKLI) satır birimleri
   rehbere GİRMEZ (tekil geri alınamaz); cakismalar'da kalır.
5. **Telafi kaydı:** `tip='GERI_ALINDI'`, `ref_id` tek-kolon pk'da skalar metin,
   bileşik pk'da satir_pk::text; `ana_hayvan_id` hedef satırın hayvan
   kolonlarından çözülür (hedef hayvanlar ise pk); `payload={orijinal_tip
   (uygulanan adımların ayrık islem harfleri, örn. 'I,U'), seviye, adim}`.
   INSERT, apply try-blokunun DIŞINDA: telafi yazımı başarısızsa tüm geri alma
   transaction'ı atomik döner (telafisiz revert kalamaz; kullanım kaydı o
   halde yazılmaz — bilinçli takas). islem_log FORCE RLS altında INSERT,
   `service_insert` policy'si ile kanıtlandı (probe_sema3b).
6. **`l4_rehber` anahtarı** motor tarafından yok sayılan bilinmeyen anahtar
   geleneğinde ADDITIVE'dir; bilet kapısı arkasındadır. İmza/kırılım yok.
7. **Replay-safe:** `ADD COLUMN IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`,
   `DROP TRIGGER IF EXISTS`+`CREATE`, `CREATE INDEX IF NOT EXISTS`. Migration 1
   Neon aynasında kuru-koşumla doğrulandı; migration 2 (surum_gizli bağımlı)
   DEMO'da iki kez üst üste uygulandı (hata yok).
8. **Kilit-lint notu:** postgrestools, ADD COLUMN/CREATE INDEX için ACCESS
   EXCLUSIVE/SHARE kilidi uyarıları verir (lock_timeout yok). f1/f2 ile aynı
   desen; DEMO ölçeğinde kabul — prod runbook'u bakım penceresi kuralına tabi
   (root kapısı).

## 5. Builtin subagent review notu (ZORUNLU)

code-reviewer alt-ajanı (builtin) iki migration + f2 tabanı + frozen contract +
test çıktıları üzerinde koşturuldu. Sonuç: **CRITICAL 0**; HIGH 2, MEDIUM 4,
LOW 6. **Düzeltilenler** (yeniden uygulama + k4 22/22 + k3 46/46 ile kanıtlı):

- **[HIGH] Başlangıç-cap:** {txid} hedefi kendisi >100 adımsa (tek tx 150
  satır) zincir hatasız 150 adımlık plan döndürüyordu → cap artık hedef
  çözümünden hemen sonra da denetleniyor; V7b testi eklendi.
- **[MEDIUM] {tablo,pk,txid} satır-kökli oldu:** zincir artık yalnız o
  satırın o tx'teki girişlerini (+aynı-tx stok) başlangıç alır; tx-BÜTÜNÜ
  yalnız {txid} formunda. W2'nin satır önizle-mesindeki hedefi zincire
  geçirmesi artık sessiz genişleme üretmez.
- **[MEDIUM] v_eng_sayi ölü koddu** (kapanış-öncesi anlık): kapanış sonrasına
  taşındı → ZINCIR_DISI_ENGEL/ZINCIR_DISI_CAKISMA ayrımı canlı.
- **[MEDIUM] f2 cascade-UYARI paritesi** zincire port edildi (aynı-tx'te
  kademeli silinip zincir dışı kalan çocuklar bagimliliklar'da UYARI).
- **[MEDIUM] Rehber süzgeci:** üst kaydı geri eklenemeyecek EKLE birimleri
  rehbere girmez (her rehber satırı tekil geri alınabilir kalır).
- **[LOW] l4_rehber** artık değer testi (`::boolean IS true`, anahtar-varlığı
  değil); **[LOW] zaman eşitliği tie-breaker** (`l.id`) eklendi; **[LOW]
  alan-seviye** olmayan satırda neden=SATIR_YOK döner.

**Lead kararına sunulan (düzeltmedim — sözleşme tansiyonu):**

- **[HIGH] Hayvan köprüsü kapsam tansiyonu:** frozen §3 "yalnız engel/çakışma
  üretenler girer" der; ama S3b/V4, doğumun (tohumlamaya FK'sı YOK, yalnız
  hayvan köprüsüyle bağlı) zincire girmesini ZORUNLU kılar. İkisi birden
  mekanik olarak sağlanamaz: köprü INSERT'lerini kabul eden mevcut tasarım
  V4'ü geçirir ama aynı hayvana sonradan yapılmış ilgisiz bir aşı INSERT'ini
  de zincire alır (kilo örneği zaten dışarıda — üst-taraf). "İlgisizlik"
  predicate'i için FK/etki-dışı bir sinyal gerekir (ör. dogum.olay_id
  zinciri) — sahibi/lead'i sözleşme ekleyerek çözmeli. Kanıt: k4 V4a/b.
- **[LOW] Telafi INSERT hatası** ham hata olarak yayılır (kullanım kaydı
  yazılmaz) — atomiklik bilinçli tercihi (§4.5); **[LOW] alan+zaman:** zamanın
  gösterdiği tx alanı içermiyorsa GECERSIZ_HEDEF ("en yakın kazanır") — W2
  metni buna göre; **[LOW] islem_log tek-başına yazılan tx'lerde** köprü txidi
  iş satırı olmadığından çözümlenemez — UI zaten ref/tarih yoluna düşer.

Diğer tüm başlıklar (güvenlik, replay-safe, ACL, §1/§2/§6 doğruluğu) review'da
"sound" bulundu.

## 6. Açık sorular / kalıntı riskler

- Yok (engel görülmedi). Kalıntı riskler §4.8 (kilo-lint) ve §4.3 (mirror'da
  surum_gizli yokluğu — DEMO runtime kanıtıyla karşılanıyor) olarak
  belgelendi.

## 7. Teslim sonrası

`W1 teslim` commit'i bu dalda atılır; merge/push YOK (worker yetki sınırı).
Kırıntılar `.crumbs/geri-alma-akisi.jsonl` (goal local_paths) altında.
