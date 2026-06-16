# EMİR RAPORU — ground_truth.sql Canlı DB'den Yeniden Üretimi

**Hedef ajan:** Pi
**Hazırlayan:** Claude (orkestratör)
**Tarih:** 2026-06-13
**Hedef dosya:** `supabase/migrations/99999999999999_ground_truth.sql`

---

## 1. AMAÇ

`99999999999999_ground_truth.sql` dosyasını **canlı Supabase DB'nin birebir aynası** olacak
şekilde yeniden üret. Migration dosyalarından KOPYALAMA — **tek doğruluk kaynağı canlı DB'dir.**
Canlı DB'de ne varsa o yazılır; ground_truth'ta olup canlıda olmayan ölü kod silinir.

**Mevcut durum (referans sayımlar — bunlardan AZ olamaz):**
- 32 tablo · 152 fonksiyon · 17 view · 11.039 satır

**Proje:** ref=`zqnexqbdfvbhlxzelzju` · URL=`https://zqnexqbdfvbhlxzelzju.supabase.co`

---

## 2. MUTLAK KURALLAR

1. **Tek yazıcı.** Hedef dosyaya yalnızca SEN yazarsın. Paralel dosya yazma YASAK.
2. **Önce yedek.** İlk iş: mevcut dosyayı `supabase/migrations/backup/99999999999999_ground_truth.PRE-REGEN.sql`
   olarak kopyala (git zaten izliyor ama yine de al).
3. **Sadece `public` şeması.** `auth`, `storage`, `realtime`, `extensions`, `vault` vb. Supabase iç
   şemalarına DOKUNMA.
4. **Doğrulama kapısı.** §6'daki sayım kontrolü geçmeden işi "bitti" sayma.
5. **Helper temizliği.** Dump için fonksiyon oluşturduysan, iş bitince `DROP` et.
6. Bitince **commit + push** (`git push origin main`).

---

## 3. YÖNTEM SEÇİMİ — önce karar ver

İki yol var. **Yöntem A** daha eksiksizdir (tablolar dahil her şey). **Yöntem B** şifresiz çalışır.

### Karar adımı (önce bunu yap)
```
supabase_migrate("SELECT 1 AS ok")
```
- Eğer **satır döndürüyorsa** → Management API SQL çalıştırabiliyor → **Yöntem B** kullan (şifresiz, garantili).
- Eğer DB connection string / postgres şifresi elde edebiliyorsan (kullanıcıdan iste:
  *Supabase Dashboard → Settings → Database → Connection string → "Session pooler" / port 5432*)
  → **Yöntem A** kullan (en eksiksiz).

**Öneri:** Şifre kolayca alınabiliyorsa A; alınamıyorsa B. İkisini KARIŞTIRMA.

---

## 4. YÖNTEM A — pg_dump (en eksiksiz, şifre gerekir)

Connection string'i kullanıcıdan al. Biçim:
```
postgresql://postgres.zqnexqbdfvbhlxzelzju:[ŞİFRE]@aws-0-[REGION].pooler.supabase.com:5432/postgres
```
> ⚠️ **Session pooler / direct (port 5432)** kullan. Transaction pooler (6543) pg_dump'ı tam desteklemez.

```bash
pg_dump "postgresql://postgres.zqnexqbdfvbhlxzelzju:[ŞİFRE]@aws-0-[REGION].pooler.supabase.com:5432/postgres" \
  --schema=public \
  --schema-only \
  --no-owner \
  --no-comments \
  -f /tmp/gt_raw.sql
```
> `--no-privileges` KOYMA — RLS GRANT'ları (anon/authenticated) korunmalı. RLS policy'ler
> `--schema=public` dump'ına zaten dahildir.

**Sonra:**
1. `/tmp/gt_raw.sql` başına şu başlığı ekle (§5 başlık bloğu).
2. `extensions` şemasına referanslı `CREATE EXTENSION` satırları yoksa sorun değil — bunlar
   ayrı şemada; not düş.
3. Çıktıyı `supabase/migrations/99999999999999_ground_truth.sql` olarak yaz (tek yazıcı, sen).
4. §6 doğrulamasına geç.

---

## 5. YÖNTEM B — Management API / SQL katalog dump (şifresiz, garantili)

`supabase_migrate` SELECT sonucu döndürüyorsa aşağıdaki sorguları **doğrudan** çalıştır.
Döndürmüyorsa: her sorguyu `CREATE FUNCTION _gtdump_x() RETURNS text ... ` ile sarmala,
`supabase_rpc("_gtdump_x")` ile çağır, sonunda `DROP FUNCTION _gtdump_x()` et.

Dosyayı şu **canonical sırayla** birleştir:

### 5.0 — Başlık bloğu (dosyanın en başı)
```sql
-- =====================================================================
-- GROUND TRUTH — Canlı DB Aynası
-- Kaynak: zqnexqbdfvbhlxzelzju (canlı Supabase) · Üretim: 2026-06-13
-- Yöntem: B (katalog dump) · Tek doğruluk kaynağı = canlı DB
-- Bu dosya ELLE düzenlenmez; yeniden üretim için emir raporuna bak.
-- =====================================================================
```

### 5.1 — ENUM / custom type'lar
```sql
SELECT string_agg(
  'CREATE TYPE public.'||t.typname||' AS ENUM ('||
  string_agg(quote_literal(e.enumlabel), ', ' ORDER BY e.enumsortorder)||');',
  E'\n')
FROM pg_type t
JOIN pg_enum e ON e.enumtypid = t.oid
JOIN pg_namespace n ON n.oid = t.typnamespace
WHERE n.nspname='public'
GROUP BY t.typname;
```

### 5.2 — Tablolar
> Katalogdan CREATE TABLE'ı SQL ile birebir yeniden kurmak kırılgandır (array/identity/generated
> kolon edge-case'leri). **Yöntem B'de tablolar için strateji:**
> 1. Canlı kolon yapısını çek (aşağıdaki sorgu).
> 2. Mevcut ground_truth'taki `CREATE TABLE` bloklarıyla **diff** al.
> 3. Fark varsa bloğu canlıya göre düzelt; fark yoksa mevcut bloğu **aynen koru.**
> 4. Canlıda olup ground_truth'ta olmayan tablo varsa ekle; tersini sil.
```sql
SELECT c.relname AS tablo,
       string_agg(
         a.attname||' '||format_type(a.atttypid,a.atttypmod)||
         CASE WHEN a.attnotnull THEN ' NOT NULL' ELSE '' END||
         COALESCE(' DEFAULT '||pg_get_expr(d.adbin,d.adrelid),''),
         E',\n  ' ORDER BY a.attnum)
FROM pg_class c
JOIN pg_namespace n ON n.oid=c.relnamespace
JOIN pg_attribute a ON a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped
LEFT JOIN pg_attrdef d ON d.adrelid=c.oid AND d.adnum=a.attnum
WHERE n.nspname='public' AND c.relkind='r'
GROUP BY c.relname ORDER BY c.relname;
```

### 5.3 — Constraint'ler (PK / FK / UNIQUE / CHECK)
```sql
SELECT 'ALTER TABLE public.'||c.relname||' ADD CONSTRAINT '||con.conname||' '||
       pg_get_constraintdef(con.oid)||';'
FROM pg_constraint con
JOIN pg_class c ON c.oid=con.conrelid
JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public'
ORDER BY c.relname, con.contype;
```

### 5.4 — Index'ler (constraint kaynaklı olmayanlar)
```sql
SELECT indexdef||';' FROM pg_indexes
WHERE schemaname='public'
  AND indexname NOT IN (
    SELECT conname FROM pg_constraint con
    JOIN pg_class c ON c.oid=con.conrelid
    JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public')
ORDER BY tablename, indexname;
```

### 5.5 — Fonksiyonlar + Prosedürler (en kritik bölüm — 152 adet)
```sql
SELECT pg_get_functiondef(p.oid)||E';\n'
FROM pg_proc p
JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.prokind IN ('f','p')
ORDER BY p.proname;
```

### 5.6 — View'lar (17 adet)
```sql
SELECT 'CREATE OR REPLACE VIEW public.'||viewname||' AS '||E'\n'||definition
FROM pg_views WHERE schemaname='public' ORDER BY viewname;
```

### 5.7 — Trigger'lar
```sql
SELECT pg_get_triggerdef(t.oid)||';'
FROM pg_trigger t
JOIN pg_class c ON c.oid=t.tgrelid
JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND NOT t.tgisinternal
ORDER BY c.relname, t.tgname;
```

### 5.8 — RLS policy'ler + ENABLE
```sql
SELECT 'ALTER TABLE public.'||tablename||' ENABLE ROW LEVEL SECURITY;'||E'\n'||
       'CREATE POLICY '||quote_ident(policyname)||' ON public.'||tablename||
       ' AS '||permissive||' FOR '||cmd||' TO '||array_to_string(roles,', ')||
       COALESCE(E'\n  USING ('||qual||')','')||
       COALESCE(E'\n  WITH CHECK ('||with_check||')','')||';'
FROM pg_policies WHERE schemaname='public'
ORDER BY tablename, policyname;
```

### 5.9 — GRANT'ler (anon/authenticated)
```sql
SELECT 'GRANT '||privilege_type||' ON public.'||table_name||' TO '||grantee||';'
FROM information_schema.role_table_grants
WHERE table_schema='public' AND grantee IN ('anon','authenticated','service_role')
ORDER BY table_name, grantee;
```
> Fonksiyon GRANT'leri genelde `pg_get_functiondef` çıktısına dahil değildir; gerekirse
> `information_schema.role_routine_grants` ile ekle.

---

## 6. DOĞRULAMA KAPISI (geçmeden "bitti" YOK)

Önce **canlı sayımları** al:
```sql
SELECT
 (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
   WHERE n.nspname='public' AND c.relkind='r') AS tablo,
 (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.prokind IN ('f','p')) AS fonksiyon,
 (SELECT count(*) FROM pg_views WHERE schemaname='public') AS view;
```
Sonra üretilen dosyayı say ve **eşleştir**:
```bash
echo "tablo:    $(grep -cE '^CREATE TABLE' supabase/migrations/99999999999999_ground_truth.sql)"
echo "fonksiyon:$(grep -cE 'CREATE (OR REPLACE )?FUNCTION|CREATE (OR REPLACE )?PROCEDURE' supabase/migrations/99999999999999_ground_truth.sql)"
echo "view:     $(grep -cE 'CREATE (OR REPLACE )?VIEW' supabase/migrations/99999999999999_ground_truth.sql)"
```

**Kabul kriteri:**
- Dosya sayımları ≥ canlı DB sayımları (fonksiyon sayısı canlı ile **birebir** eşleşmeli).
- `psql -f ... --single-transaction` ile (boş/geçici DB'de) sözdizimi hatası vermemeli;
  şifresiz isen en azından dosyada açık syntax bozukluğu (eksik `;`, kesik blok) olmadığını gözle doğrula.
- Helper fonksiyonlar DROP edilmiş olmalı (`_gtdump_*` kalmamalı).

**Sapma varsa** (ör. fonksiyon sayısı tutmuyor) → dur, hangi objelerin eksik/fazla olduğunu
listele, raporla. Tahminle doldurma.

---

## 7. TAMAMLAMA

1. Doğrulama geçti → değişikliği özetle (kaç tablo/fonksiyon/view, eski vs yeni satır sayısı,
   silinen ölü kod varsa listesi).
2. Commit:
   ```
   chore(ground-truth): canlı DB aynası olarak yeniden üretildi (Yöntem A/B)
   ```
3. `git push origin main`.
4. Yedek dosyayı (`backup/...PRE-REGEN.sql`) bırak — geri dönüş için.

---

## 8. RAPOR FORMATI (Claude'a dön)

```
GROUND_TRUTH REGEN — [BİTTİ / TIKANDI]
Yöntem: A / B
Sayımlar: tablo X/X · fonksiyon Y/Y · view Z/Z (dosya/canlı)
Satır: 11039 → N
Silinen ölü kod: [liste veya yok]
Commit: [hash]
Sorun/karar bekleyen: [varsa]
```
