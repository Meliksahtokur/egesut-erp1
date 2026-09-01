# hekim_listesi() Karar Dosyası — GT v5 Regen Hazırlık (gt-taslak, 2026-09-02)

> **Durum:** KARAR KULLANICIDA — bu dosya iki seçeneği kanıtıyla serer ve öneri verir.
> Guardrail: Supabase'e sıfır çağrı; tüm kanıt repodan (snapshot + migrations + js).

## Sorun özeti (audit #16)

| Kaynak | Ne diyor |
|---|---|
| Canlı snapshot (2026-08-31) | `hekim_listesi` 185 benzersiz adın arasında YOK → **canlıda fn yok** |
| GT `99999999999999_ground_truth.sql:2610` | `GRANT EXECUTE ... hekim_listesi()` var, **CREATE yok** (GT iç tutarsızlığı) |
| `supabase/migrations/20260308000009:321` | Orijinal tanım: `RETURNS TABLE(id text, ad text, telefon text, aktif boolean)` `WHERE aktif = true ORDER BY ad`, SECURITY DEFINER |
| `js/app.js:30` | `await db.rpc('hekim_listesi')` çağırıyor; hata/boş dönüş catch ediliyor |

## Uygulama bugün nasıl çalışıyor (kanıtlar)

1. `app.js:28-39 loadHekimler()` — RPC başarısız olursa `console.warn` + config fallback; **kırılma yok**.
2. `js/api.js:423` — `hekimler: () => db.from('hekimler').select('*').eq('aktif', true)` →
   `hekimler` tablosu pullTables/işlem-cache hattından **doğrudan** okunuyor.
3. `js/config.js:83-88 loadHekimlerFromDB()` — `getData('hekimler')` ile `HEKIMLER` güncelleniyor
   (RPC'den bağımsız ikinci doğrudan-tablo yolu).
4. `api.js:33` — `pullTables` listesinde `hekimler` var; `api.js:345-346` — `hekim_ekle/guncelle`
   cache invalidation'ı tabloya bağlı.
5. Hekim yönetimi canlıda çalışıyor: `hekim_ekle/guncelle/sil` RPC'leri canlı snapshot'ta VAR
   (113-115. satırlar), `hekimler` tablosu canlıda mevcut (`id TEXT`), UI çağrıları rpc-reference'ta kayıtlı.

**Sonuç:** RPC olmasa da uygulamanın hekim verisi iki bağımsız doğrudan-tablo yolundan akıyor;
`hekim_listesi` işlevsel olarak **tamamen yedekli**.

## Seçenekler

### (a) Geri yükleme — canlıya `hekim_listesi()` CREATE

**Taslak SQL** (20260308000009:321'den aynen; mevcut `hekimler(id text)` şemasıyla uyumlu —
snapshot tablo listesi `hekimler: id TEXT` teyitli; GT:7059-7064 kolon tanımı `id text, ad, telefon, aktif` ile birebir uyumlu):

```sql
CREATE OR REPLACE FUNCTION public.hekim_listesi()
RETURNS TABLE(id text, ad text, telefon text, aktif boolean)
LANGUAGE sql SECURITY DEFINER AS $$
  SELECT id, ad, telefon, aktif
  FROM public.hekimler
  WHERE aktif = true
  ORDER BY ad;
$$;
GRANT EXECUTE ON FUNCTION public.hekim_listesi() TO anon, authenticated;
```

- Artı: app.js:30 çağrısı anlamlı hale gelir; migration zinciri ↔ canlı tutarlılığı restore
  sonrası GT regen fn'i doğal olarak içerir (CREATE'siz GRANT sorunu otomatik kapanır).
- Eksi: mevcut iki doğrudan-tablo yoluna karşı **üçüncü, yedekli** bir yol ekler; RPC'nin
  getirdiği hiçbir veri (`aktif=true` filtresi zaten `api.js:423`'te var) yok.
- Risk: düşük (SECURITY DEFINER + RLS `USING(true)` — tablo zaten anon'e açık).

### (b) Temizleme — RPC'yi bırakma, çağrıyı silme (ÖNERİLEN)

Adımlar:
1. **Kod:** `app.js:28-39 loadHekimler()` gövdesindeki `db.rpc('hekim_listesi')` çağrısı
   kaldırılır; fonksiyon `loadHekimlerFromDB()` (config.js:83) çağrısına ya da tamamen
   kaldırılmaya daraltılır → **kod-temizlik görevi kapsamında** (bu idle görev kod değiştirmiyor).
2. **GT:** canlıdan üretilecek GT v5'te fn olmadığı için GRANT de satır olarak **düşer**
   (pg_dump var olmayan fn için GRANT üretmez). Ek işlem: GT regen sonrası `grep hekim_listesi`
   ile 0 eşleşme doğrulanır.
3. **rpc-reference.md:** mevcut `⚠️ CANLIDA YOK` notu "kaldırıldı kararı" ile güncellenir
   (denetimli oturumda tek satır).

- Artı: yedekli yol kapanır; "canlıdan düşmüş" belirsizliği kalıcı olarak çözülür; kod ve DB
  tek gerçeğe (doğrudan tablo okuma) yakınsar.
- Eksi: app.js'de küçük kod değişikliği gerekir (kullanıcı onaylı ayrı görev).

## Öneri

**(b) temizleme.** Gerekçe: fn'nin sağladığı veri, `api.js:423` ve `config.js:83` olmak üzere
iki bağımsız doğrudan-tablo yoluyla zaten sağlanıyor; RPC geri yüklemek kalıcı bakım yüzeyini
büyütür. `hekim_listesi`'nin canlıdan düşüş nedeni belgelenmemiş olsa da (muhtemelen eski bir
deploy atlantı), 4+ aydır hiçbir kullanıcı semptomu üretememiş olması yedeklilik tezini doğruluyor.

| Kriter | (a) geri yükle | (b) temizle |
|---|---|---|
| Uygulama davranışı değişir mi | Hayır (yedekli yol) | Hayır (fallback zaten çalışıyor) |
| Yeni bakım yüzeyi | +1 RPC | −1 ölü çağrı |
| GT tutarlılığı | Regende otomatik çözülür | Regende otomatik çözülür |
| Ek iş | 1 deploy | 1 kod-temizlik görevi (zaten planlı) |

## Karar sonrası izlenecek yol

- Karar (a) → taslak SQL denetimli oturumda deploy edilir, app.js olduğu gibi kalır.
- Karar (b) → kod-temizlik görevine `app.js:30` çağrısının silinmesi eklenir; GT regen +
  rpc-reference güncellemesi denetimli oturumda yapılır.
