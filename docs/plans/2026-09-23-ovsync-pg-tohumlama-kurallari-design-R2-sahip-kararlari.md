# Ovsync / PG / Tohumlama — R2: Sahip Kararları ve Nihai Tasarım

Tarih: 2026-09-23
Baz: R1 taslağı (dış) + mimari review (7/10) + tıbbi review + sahip kararları
Önceki: `2026-09-23-ovsync-pg-tohumlama-kurallari-design.md` (R0, af7d012)

## 0. Kanıtlanan kritik gerçek (canlı doğrulamalı)

**D11/D39 uyuşmazlığı GERÇEK ama BU TASARIMIN KAPSAMI DIŞINDA** [OBSERVED
canlı `pg_get_functiondef`, 2026-09-23]: canlı `dogum_kaydet` hâlâ D11 PG
üretiyor, scanner D39 arıyor; UI zaten 11. gün PG'yi göstermiyor (sahip
gözlemi) — ölü kod. Sahip açıklaması: D11 zaten iptal edilmişti; protokol
**2–25–39. gün PG**. Repodaki düzeltme migration'ı canlıya uygulanmamış —
**ayrı küçük bir düzeltme migration'ı olarak** spec'ten bağımsız uygulanır;
bu tasarımın parçası değildir.

## 1. Sahip kararları (R1 önerilerinden ayrılanlar)

### K1 — Bağımsız PG sonrası: DOĞRUDAN tohumlama görevi + ERTELEME (mevcut RPC)

R1'in `UREME_KONTROL` değerlendirme görevi **RED** — sahip kararı:
+48 saatte doğrudan `TOHUMLAMA_PLANLI` açılır (R0 davranışı), görev
**ertelenebilir** — üst sınır yok, pratiklik esastır.

- **Mevcut RPC kullanılır:** `hayvan_tohumlama_ertele` [CONFIRMED migration
  envanteri] — yeni yol yazılmaz; PG_TOHUMLAMA görevine bu aksiyon bağlanır.
- **Erteleme elle yapılır, tarih modalıyla** (sahip kararı): görevden
  **[Ertele]** → mevcut tarih seçim modalı → yeni tarih. Otomatik/yapay
  erteleme mantığı yok; üst sınır yok.
- Saat penceresi korunur (09–12 / 18–21, ileri yuvarlama).
- Erteleme `islem_log`'a yazılır (`TOHUMLAMA_ERTELE` mevcut tip,
  gecmis.js'te etiketli).
- Görev açıklamasında tıbbi not taşınır: "PG sonrası östrus değişkendir;
  kızgınlık görülmezse ertele/değerlendir."

### K2 — İlk tohumlama zinciri: gebe onayında ROTA, doğum/abort ile KESİNLEŞ

R1'in "gebe onayı tetiği tamamen iptal" önerisi **KISMEN KABUL**:

- **Gebe onayı anında** (`tohumlama_sonuc_gebe` — mevcut RPC'ye bağlanır):
  rota kurulur; görev henüz doğmaz, tarih yok.
- **Doğum olayı anında:** rota kesinleşir → D50 Ovsync + D60 tohumlama
  zinciri kurulur (idempotency anahtarı `ILK-TOH-<olay_id>`). Rota işaretinin
  saklama yeri (kolon/tablo) SPEC'te mevcut şemayla en az dokunuşla seçilir.
- **ABORT da doğum gibi muamele görür** (`abort_kaydet` / `tohumlama_abort`
  mevcut kapılar): doğum, erken doğum, abort — hepsi aynı "üreme döngüsü
  sıfırlama olayı" kapısına çıkar; **D50 sayacı olayın GERÇEKLEŞME
  tarihinden başlar** (sahip kararı). VWP kuralıyla çelişki olursa mevcut
  abort/VWP kapısı öncelikli kalır.

### K3 — Bekliyor PG uyarısı: sınırsız + tek ekranda "Boş ata"

- 25 gün sınırı **KALDIRILIR** (iki review'in P0 bulgusu kabul): `Bekliyor`
  döngüsü `Boş/Abort/Gebe` ile kapanana kadar her PG girişinde uyarı;
  25 gün yalnız görünürlük önceliği.
- **Modal içinden doğrudan aksiyon:** uyarı ekranında hayvan başına
  **[Boş ata]** butonu — **mevcut `tohumlama_sonuc_bos` RPC'sine bağlanır**
  [CONFIRMED migration envanteri; hayvan kartı/üreme tab'ındaki aynı fonksiyon].
  Tıklayınca o hayvanın son tohumlaması `Boş` olur, PG riskten düşer, aynı
  ekranda; modal-modal gezinti yok. Toplu listede satır içi aksiyon.

### K4 — D50'de direkt görev, uygunluk bürokrasisi YOK

Tıbbi review'in "uygunluk kontrolü adayı" önerisi **RED** — sahip kararı:
doğum/abort olayıyla D50 görevi **otomatik kurulur**, uygunsuz hayvanda
sahip **elle iptal eder**. Korunan muafiyetler (otomatik): 50. günden önce
tohumlama/gebe, hayvan aktif değil. Bunun dışında klinik eleme insan'a bırakılır.

## 2. R1'den AYNEN KABUL EDLENLER (tekrar tanımlanmaz)

- **Merkezi PG güvenlik kapısı** tüm gerçek uygulama yollarında DB tarafında
  atomik (hizli_uygulama, seans_tamamla, bulk_ilac, görev yolu); planlama ≠
  uygulama; TOCTOU'ya karşı commit anında yeniden kontrol + hayvan kilidi.
- **Gebe = hard block** (Yine de uygula yok; istisna ayrı yetkili akış).
- **cases provenance:** `source_template_id` + `protocol_family` +
  `protocol_snapshot`; belirsiz eski vaka `UNKNOWN` kalır, otomatik kapanmaz.
- **Tek kapanış motoru** typed `close_reason`; tek audit olayı
  `CASE_CLOSED_BY_TOHUMLAMA`; "başarıyla tamamlandı" değil "tohumlama ile
  sonlandırıldı" ifadesi; geçmişte uygulanmış seanslar korunur.
- **PG kimliği:** `farmakolojik_sinif_kodu='PGF2A'` (etken_kod yalnız PG
  kontrolü YASAK — kloprostenol NULL bugün); migration backfill + yeni
  maddeler kategoriden kod alır; çözümlenemeyen katalog = fail-closed blok.
- **Sistem etken maddeleri:** `sistem=true` + RPC guard + (gerekirse trigger);
  ürün bazında doz/konsantrasyon alanları ayrık (Enzaprost ≠ Dalmazin ml).
- **Doğum olayı bazlı idempotency** (ikiz tek olay); pg_cron birincil
  zamanlayıcı, app refresh reconcile; tek atomik `start_first_service_protocol`
  RPC (üç RPC'lik frontend zinciri kopyalanmaz).
- **bulk_ilac** standardizasyonu (gerçek uygulama kaydı üretmesi) PG kapısı
  kapsamı için zorunlu ön iş.
- Tüm R1 test matrisi (T01–T25) + ek: erteleme, abort-kapısı, modal içi
  Boş ata.

## 3. R2'ye özgü ek kabul testleri

- T26: Bağımsız PG +48s'te TOHUMLAMA_PLANLI doğar; [Ertele] +2 gün → görev
  yeni tarihte pencere içinde; `TOHUMLAMA_ERTELE` log'u var.
- T27: Erteleme 7 gün üst sınırını aşarsa uyarı görünür, gizli erteleme yok.
- T28: Gebe onayı → rota işareti; görev YOK. Doğum → D50/D60 kurulur.
- T29: Abort kaydı → doğumla aynı kapı: D50/D60 zinciri kurulabilir.
- T30: 31 gün Bekliyor + PG → uyarı görünür; modalda [Boş ata] → tohumlama
  Boş, PG riskten düşer, tek ekranda tamam.
- T31: D50 görevi uygunsuz hayvanda da kurulur; elle iptal `islem_log`'a düşer.

## 4. Sıradaki adım

1. `SPEC.md` — DB kontratları (yeni kolonlar, `pg_application_event`,
   kapanış motoru imzaları, RLS/izin, audit tipleri).
2. `PLAN.md` — migration sırası (D11→D39 canlı düzeltmesi İLK), backfill,
   bulk_ilac standardizasyonu, RPC'ler, frontend, feature flag.
3. D50/D60 saat programı (GnRH1–PG(+7g)–GnRH2(+56s)–TAI(+16s) zinciri)
   hekim onaylı şablon saatleriyle spec'te kilitlenir.
