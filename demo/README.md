# Demo-Mirror — Demo Projesi Kurulum SQL'leri

Bu klasör **yalnızca DEMO Supabase projesinde** (ref `vtzqjmazsvurxdeondmi`, eu-west-1) çalışır.
**Prod'a UYGULAMA** — `prod_fdw` şeması sadece demo'da vardır, prod'da patlar.
Bunlar `supabase/migrations/` (prod migration'ları) değildir; migration tooling bunları çalıştırmaz.

Tam yol haritası: `../docs/demo-mirror-ROADMAP.md`. Mimari: Seçenek D (ayrı proje + postgres_fdw köprüsü + tek-tık/saatlik klon).

## Uygulama sırası (demo Management API veya `mcp__supabase-demo__*`)

| Dosya | Ne yapar | Faz |
|---|---|---|
| (D0) | Demo şema+veri ilk doldurma — prod'dan `pg_dump via demo_reader` (BYPASSRLS). Detay ROADMAP D0. | D0 ✅ |
| `01_fdw_bridge.sql` | `postgres_fdw` + `prod_srv` + `USER MAPPING` + `IMPORT FOREIGN SCHEMA` → `prod_fdw` canlı prod aynası | D1 ✅ |
| `02_demo_klonla.sql` | `demo_klon_log` tablosu + `demo_klonla()` RPC (atomik birebir klon) | D2 ✅ |

## `demo_klonla()` — nasıl çalışır

Tek transaction, atomik (yarım-klon yok):
1. 44 tabloda `DISABLE TRIGGER USER` — app trigger'ları susar (klon prod'u birebir yansıtır, sahte görev üretmez). `postgres` sahip olduğu için superuser gerekmez (`DISABLE TRIGGER ALL` gerekirdi).
2. Tüm 44 tabloyu tek `TRUNCATE` deyiminde boşalt (FK-güvenli).
3. **Topolojik FK sırasıyla** (ebeveyn→çocuk) `INSERT..SELECT FROM prod_fdw.*`. Kolon listesi çalışma anında demo katalogundan üretilir (prod'a kolon eklense bile demo'nunkiyle sınırlı → drift'e dayanıklı).
4. `SET CONSTRAINTS ALL IMMEDIATE` — ertelenmiş FK kontrollerini zorla (yoksa `pending trigger events` → `ALTER TABLE` patlar).
5. `ENABLE TRIGGER USER` geri aç. `setval` ile 4 sequence senkron.
6. `demo_klon_log`'a satır sayısı + süre + durum yaz. Dönüş: `{ok, rows, ms, tables}`.

Çağrı: `SELECT public.demo_klonla();` → ~6700 satır / ~1 sn. `GRANT EXECUTE ... TO authenticated`.

## Kapsam

- **Klonlanan:** tüm egesut/çiftlik tabloları (44).
- **Hariç:** `agent_*` (gerçek kullanıcı AI-sohbeti — gizlilik), `demo_klon_log` (audit), 3 AI-infra vector tablosu (demo'da yok).

## Sıradaki (D3+)

- **D3:** `pg_cron` saatlik `demo_klonla()` + şema-senkron (prod'a yeni tablo → demo eskir → klon eksik kalır).
- **D4:** UI — `config.js` `IS_DEMO` host-tespiti + "🧪 Demo Girişi" + "↻ Prod'dan Klonla" butonu.
