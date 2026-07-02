# Demo-Mirror — Demo Projesi Kurulum SQL'leri

Bu klasör **yalnızca DEMO Supabase projesinde** (ref `vtzqjmazsvurxdeondmi`, eu-west-1) çalışır.
**Prod'a UYGULAMA** — `prod_fdw` şeması sadece demo'da vardır, prod'da patlar.
Bunlar `supabase/migrations/` (prod migration'ları) değildir; migration tooling bunları çalıştırmaz.

Tam yol haritası: `../docs/demo-mirror-ROADMAP.md`. Mimari: Seçenek D (ayrı proje + postgres_fdw köprüsü + tek-tık/saatlik klon).

## Uygulama sırası (demo Management API veya `mcp__supabase-demo__*`)

| Dosya | Ne yapar | Faz |
|---|---|---|
| (D0) | Demo şema+veri ilk doldurma — prod'dan `pg_dump via demo_reader` (BYPASSRLS). Detay ROADMAP D0. | D0 ✅ |
| `00_grants.sql` | authenticated CRUD grant'ları (D0 pg_dump ACL taşımadı → 42501 fix) + ALTER DEFAULT PRIVILEGES | D0+ ✅ |
| `01_fdw_bridge.sql` | `postgres_fdw` + `prod_srv` + `USER MAPPING` + `IMPORT FOREIGN SCHEMA` → `prod_fdw` canlı prod aynası | D1 ✅ |
| `02_demo_klonla.sql` | `demo_klon_log` + `demo_klonla()` RPC (atomik birebir klon, dinamik, `statement_timeout=300s`) | D2 ✅ |
| `03_sema_diff.sql` | `demo_sema_diff()` — prod↔demo şema drift uyarısı (salt-okuma) | D-şema ✅ |

**UI (frontend):** `js/api.js` IS_DEMO + demo client · `js/auth.js` "🧪 Demo Girişi" + oto-login · `js/demo.js` bant + klon butonu + popup + drift uyarısı. **Demo giriş:** login ekranı "🧪 Demo Girişi" veya URL `?demo`. **Gömülü kullanıcı:** `demo@egesut.web` / `demo2026`.

## `demo_klonla()` — nasıl çalışır (DİNAMİK)

**Hiçbir tablo/kolon adı gömülü değil** — kapsam, FK sırası, kolonlar ve sequence'ler tek transaction içinde demo'nun kendi katalogundan (`pg_class`/`pg_constraint`/`information_schema`) hesaplanır. Demo'ya tablo/kolon eklenince klon **otomatik** kapsar; fonksiyonu yeniden üretmek gerekmez.

Tek transaction, atomik (yarım-klon yok):
1. **Kapsam + topolojik sıra runtime:** public base tabloları (agent_* / demo_klon_log / 3 vector-infra hariç, sadece `prod_fdw`'de karşılığı olanlar). FK grafiğinden recursive CTE ile en-uzun-ebeveyn-yolu sırası (DAG, self-FK hariç) → ebeveyn önce.
2. Her tabloda `DISABLE TRIGGER USER` — app trigger'ları susar (klon prod'u birebir yansıtır, sahte görev üretmez). `postgres` sahip olduğu için yeter; `DISABLE TRIGGER ALL` superuser ister (Supabase'de yasak).
3. Tüm tabloları tek `TRUNCATE` deyiminde boşalt (FK-güvenli).
4. **Topolojik sırayla** (ebeveyn→çocuk) `INSERT..SELECT FROM prod_fdw.*`. Kolon listesi = **demo ∩ prod_fdw** kesişimi (iki yönlü drift-güvenli).
5. `SET CONSTRAINTS ALL IMMEDIATE` — ertelenmiş FK kontrollerini zorla (yoksa `pending trigger events` → `ALTER TABLE` patlar).
6. `ENABLE TRIGGER USER` geri aç. Set tablolarının sequence'lerini runtime bulup `setval`.
7. `demo_klon_log`'a satır sayısı + süre + durum yaz. Dönüş: `{ok, rows, ms, tables}`.

Çağrı: `SELECT public.demo_klonla();` → 44 tablo / ~6700 satır / ~1-2 sn. `GRANT EXECUTE ... TO authenticated`.

## Kapsam

- **Klonlanan:** tüm egesut/çiftlik tabloları (44).
- **Hariç:** `agent_*` (gerçek kullanıcı AI-sohbeti — gizlilik), `demo_klon_log` (audit), 3 AI-infra vector tablosu (demo'da yok).

## Sıradaki (kararlar 2026-07-02)

- ❌ **Saatlik veri cron — İPTAL.** Prod saat başı değişmiyor; buton yeter. Veri tazeliği/temizliği kullanıcı kararına bırakıldı.
- **D4 UI:** `config.js` `IS_DEMO` host-tespiti + "🧪 Demo Girişi" + "↻ Prod'dan Klonla" butonu ("emin misiniz?" onayı → ~1-2 sn). Girişten sonra **popup**: "işlem yapmadan önce senkronizasyon butonuna bas" + "bir daha gösterme" kutucuğu (auto-reset yerine).
- **Şema-senkron = cron değil, prod-migration iş akışı adımı:** prod'a migration atınca aynı SQL'i demo'ya da uygula (Management API, elindeki SQL) + tablo eklendiyse `IMPORT FOREIGN SCHEMA` yenile. `demo_klonla()` dinamik olduğu için tablo listesini elle güncellemek gerekmez.
- **Şema-diff denetimi:** demo vs prod tablo/kolon kümesini karşılaştıran küçük on-demand kontrol (drift uyarısı). Cron şart değil.
