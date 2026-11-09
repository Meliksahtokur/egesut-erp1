⟦ss-sub model=opus effort=high rol=ss-reviewer-kapi iş=D1 T2 review⟧
sonuc: TAMAM
VERDICT: PASS
(ss-reviewer-kapi sözlüğünde: KABUL)
OKUDUM: kat1 yok (brief nokta-review paketi değil; T2 şablonu base..head diff'i — 3 dosya 499 satırın tamamı okundu) · DONE D1-report.md tam · lead review yok (T2 ilk tur) · kat2 yok; diff: 20261110100001_dogum_pg_hatirlatma.sql 1-224, ovsync_tren_kabul.sql 1-251, README.md diff · PLAN.md:29-53,169-235,645-650 · progress.md RL-1..RL-8 · ortak.md · araç 17
ÖLÇTÜM:
- kabul koşumu (BEGIN/ROLLBACK, brief Run 1) → rc=0, son satır `NOTICE:  OZET: 24 PASS` (MEASURED)
- `bash ~/egesut-erp1/scripts/db-validate.sh …/20261110100001_dogum_pg_hatirlatma.sql` (RL-8 biçimi) → rc=0, `SONUÇ: PASS`, rapor ~/egesut-erp1/reports/db-validation-725fb9c8.md (MEASURED)
- `! grep -n CURRENT_DATE supabase/migrations/2026111010000*.sql` → rc=0, çıktı yok (MEASURED)
- `diff kanit/fn/dogum_kaydet.sql <migration 30-189>` → yalnız: +v_pg_gorev bildirimi; 3 PG satırı ana VALUES'tan çıkıp `IF _ayar(...)=1` arkasında ayrı INSERT'e (açıklama/gün/etken/kaynak birebir); gorev_sayisi ifadesi; son `$function$;` (MEASURED)
- govde-taban.md:20 dogum_kaydet prod md5 `756c56afb83401721521e42e613ab7f9` = migration:19, imza `(text,date,text,text,text,numeric,text,text)` aynı (MEASURED)
- `git diff --name-only cc6ed7a 4a32f60` → yalnız brief'in 3 yazılabilir dosyası (MEASURED; scope-violation yok)
- kabul DB: hayvanlar'da org/tenant kolonu yok (tek kiracı; SECDEF global sorgu sızıntı değil), protokol_ayar_pkey VAR, deger NOT NULL, idx_dogum_anne_tarih var (MEASURED)
İŞARETLİ:
- [KÜÇÜK] supabase/tests/ovsync_tren_kabul.sql:214-224 — TR-IZOL-1 (b) ayar + GUC geri sarımını ölçüyor (plan tanımı tam karşılanıyor; worker'ın RELEASE mutantı öldü), fixture sızıntısını ölçmüyor; D2+ toplam assert'leri buna yaslanacak — kanıt: (b) gövdesinde hayvanlar/dogum sorgusu yok — dar fix: (a)'ya bir `kb_hayvan()` ekle, (b)'de `SELECT count(*) FROM hayvanlar WHERE id LIKE 'KB-%'` = 0 assert'i ekle.
- [KÜÇÜK] supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql:206 — `h.cinsiyet = 'Dişi'` filtresi hiçbir test/mutantla ölçülmüyor (anne pratikte hep dişi; risk düşük) — kanit: D1-report mutant listesi 11 kalem, cinsiyet yok — dar fix: istenirse TR-F0-3'e erkek-anne fixture'ı (doğrudan dogum INSERT) eklenir; zorunlu değil.
- [KÜÇÜK] supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql:23-28 — plan `ON CONFLICT (anahtar) DO NOTHING` diyor, worker `WHERE NOT EXISTS` kullandı; prod-eş kabul DB'de protokol_ayar_pkey var, yalnız db-validate baseline'ında yok → sapma gerekçeli ve anlamca eş (tek oturumlu migration'da yarış yok); kök neden baseline aynasının bayatlığı (env-mismatch) — kanıt: `pg_constraint protokol_ayar_pkey p` — dar fix: D1'de yok; D2 brief'inde seed kalıbı açıkça NOT EXISTS yazılsın ya da db-validate baseline düzeltilsin.
- Plan dışı ama kabul edilen: migration:183 gorev_sayisi (bayrak 0 → 12, bayrak 1 → 15 = prod ile birebir; ikinci doğum → 7 değişmedi). Gerekçe MEASURED: js/forms.js:252 toast'ı "N görev oluşturuldu" diye gösteriyor; değişmeseydi açılmayan 3 görevi sayardı (silent-success). Doğru karar.
Odak maddeleri:
1 gövde türetimi: CONFIRMED (diff yukarıda). 2 md5: CONFIRMED doğru değer + imza, COALESCE(false) ile fail-closed, 20261031200007:19-23 kalıbı. 3 ACL: hatırlatma + dogum_kaydet REVOKE PUBLIC,anon + GRANT authenticated (iç yardımcı yok) — TR-F0-ACL 3 kb_ok ile ölçülüyor. 4 regresyon: bayrak 1 = eski davranış birebir (TR-F0-2: 3 PG görevi doğru gün/etken/kaynak, gorev_sayisi 15); bayrak 0 = yeni varsayılan (spec §5). 5 TR tarih: RPC `(now() AT TIME ZONE 'Europe/Istanbul')::date`, kb_bugun aynı ifade; ikisi de now() (işlem zamanı) → gece yarısında da tutarlı. Bu görevde hata kodu yok, yalnız `DOGUM_KAYDET_GOVDE_FARKLI`. 6 testler: 6 TR id'nin hepsi var, 24 kb_ok; vacuous assert yok (TR-F0-4 ayar satırı yoksa aktif=true döner → FAIL; TR-F0-3 her hayvan için uzunluk + gün + tarih); kırmızı koşum `FAIL TR-F0-1 … gerçek 3` raporlu. Sözleşme: yardımcılar + TEMP SEQUENCE ilk savepoint'ten önce (:27-83), 7 senaryonun hepsi SAVEPOINT/DO/ROLLBACK TO üçlüsünde, bayrak kurulumu senaryo içinde (Kapı tur 2 eki D1 uygulandı), OZET currval ile. 7 kapsam: temiz.
OZET sinyal=1
KALİTE: olcum-yok: 1 dosya — dil-desteksiz (supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql)
KALİTE: boyut 224/120 (bütçe aşımı, sinyal satırı: eklenen=224 butce=120) → gerekli — 160 satır prod gövde kopyası (Global Constraints: kanit/fn'den türet), yeni mantık ~40 satır; (a) ölçütü ihlal yok. (b)-(d): gorev_sayisi sabitleri prod kalıbı, hatırlatma RPC tek CTE, idx_dogum_anne_tarih NOT EXISTS'i karşılıyor; ÖNEMLİ kalite bulgusu yok.
BLOKLAYAN: 0 · ERTELENEBİLİR: 3
NOKTA NOTU: Nokta-review paketi yoktu, diffin tamamı okundu; kaçırılabilecek tek alan build.sh'nin taze kurulumu (brief gereği koşulmadı, kabul DB'si D8a ile paylaşımlı — koşum mevcut DB durumunda yapıldı).

## Kırıntılar
- decision (KALİTE: D1 T2 review PASS/KABUL, 4a32f60) — workspace fable-rol-ve-davranislar
- measurement: kabul rc=0 OZET 24 PASS; db-validate rc=0 PASS; CURRENT_DATE grep boş; sinyal=1 olcum-yok
- open_item: db-validate baseline'ında protokol_ayar PK yok, prod-eş kabul DB'de var → baseline bayat; D2 seed'leri etkilenir (--kosul guard kara listesine takıldı, koşulsuz kaydedildi)
- Not: gitnexus kullanılmadı (SQL-only diff, keşif gerekmedi); analyze koşulmadı (salt-okuma rol).

## Run kanıtı

1)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
```
rc: 0
```
NOTICE:  PASS TR-IZOL-1: savepoint geri sarımı ayar ve GUC'u sıfırlar
NOTICE:  PASS TR-F0-ACL: anon kapalı, authenticated açık
NOTICE:  OZET: 24 PASS
```

2)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql
```
rc: 0
```
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-725fb9c8.md
 İzole DB'ler drop edildi: egesut_val_1946516_983d23f8 egesut_val_1946516_358bf78c
```
