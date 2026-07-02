# Demo-Mirror (Demo Hesap) — Yol Haritası

> **Seçilen mimari: Seçenek D** — ayrı Supabase projesi + FDW köprüsü + tek-tık/saatlik klon.
> Araştırma: `research/2026-07-01-demo-hesap-mirror-arastirma/rapor.md` (+ `rapor-L-rpc-drift-audit.md`)
> İlgili disiplin: `.claude/farm-id-discipline.md` (D, aynı zamanda Faz 2 staging'i olarak ikiye katlanır)
> Durum: **D0 sürüyor** (2026-07-02). Demo projesi kuruldu, şema kaynağı = **günlük backup dump'ı** (aşağıda). Ön-koşul farm_id disiplini ✅ (commit `0e421f3`).

## Altyapı / Bağlantılar (2026-07-02)

**Demo Supabase projesi** — ref `vtzqjmazsvurxdeondmi` · region `eu-west-1` (prod ile AYNI) · PG 17.6.
- Sırlar `.env`'de (gitignored): `SUPABASE_DEMO_REF`, `SUPABASE_DEMO_PAT`, `SUPABASE_DEMO_DB_PASSWORD`, `SUPABASE_DEMO_POOLER`.
- psql: `postgresql://postgres.$SUPABASE_DEMO_REF@$SUPABASE_DEMO_POOLER:5432/postgres?sslmode=require`
- MCP (proje seviyesi, `.mcp.json` → `supabase-demo`): `@supabase/mcp-server-supabase@0.8.2`, project-ref demo'ya kilitli, features `database,development,debugging`. Token env `SUPABASE_DEMO_PAT`. **Restart sonrası** `mcp__supabase-demo__*` görünür.

**Prod** — ref `zqnexqbdfvbhlxzelzju` · region `eu-west-1`. Doğrudan DB şifresi lokalde YOK (GitHub secret `SUPABASE_DB_PASSWORD`).

**ŞEMA + VERİ KAYNAĞI = günlük backup** (`.github/workflows/db-backup.yml`): her gün 03:00 TSİ, Docker `pg_dump --format=custom --no-owner --no-acl` (extensions/graphql/net/realtime vb. şemalar hariç; **public + auth dahil**), openssl `aes-256-cbc -pbkdf2` ile şifreli GitHub artifact (90 gün). Not: `--no-acl` → **GRANT'lar dump'ta YOK, restore sonrası yeniden verilmeli** (anon/authenticated PostgREST erişimi için).

**Backup indir + çöz (recipe):**
```bash
export GH_TOKEN=$(git remote get-url origin | sed -E 's|https://([^@]+)@.*|\1|')   # PAT git remote'da gömülü
RID=$(gh run list --workflow=db-backup.yml -L1 --json databaseId -q '.[0].databaseId')
gh run download "$RID" -D /tmp/bk
openssl enc -d -aes-256-cbc -pbkdf2 -pass pass:"$BACKUP_PASSWORD" \
  -in /tmp/bk/*/egesut_*.pg.enc -out /tmp/bk/dump.pg     # BACKUP_PASSWORD = GitHub secret
# demo'ya sadece public: pg_restore --schema=public --no-owner -d "<demo psql url>" /tmp/bk/dump.pg
```
**Not:** `BACKUP_PASSWORD` yok (şifreli artifact çözülemiyor). Onun yerine D0'da **doğrudan prod'dan** çekildi (aşağı bkz).

### D0 GERÇEKLEŞEN yöntem (2026-07-02) — pg_dump via demo_reader
`BACKUP_PASSWORD` olmadığı için şifreli artifact yerine prod'dan doğrudan çekildi:
1. Prod'da `demo_reader` rolü (Management API/SB_MGMT_TOKEN ile, LOGIN + SELECT-only + **BYPASSRLS**). BYPASSRLS şart: policy'si `TO authenticated` olan tablolar (ör. drug_products) aksi halde 0 satır döner.
2. `pg_dump --schema=public --no-owner` prod (aws-1-eu-west-1 pooler, user `demo_reader.<prodref>`), **hariç:** `code_embeddings/entity_graph/memory_notes` (AI-infra, vector) tabloları + `agent_threads/messages/plans` **verisi** (gerçek kullanıcı sohbeti sızmasın; yapı kalır). Dump ~1.8MB (prod'un 207MB'ı embeddings+chat'ten; farm verisi minik → **D3 egress endişesi yok**).
3. `pg_restore --no-owner` demo'ya.
Sonuç: 47 tablo + tam veri (hayvanlar 153, gorev_log 1246, drug_products 25) + 172 fn + 14 view + 68 policy + 26 trigger + grant'lar. Eksik = sadece vector-infra (farm app'i kullanmaz).
**AÇIK:** `demo_reader` prod'da duruyor (D2 klon için gerekli; bitince `DROP ROLE demo_reader`).

### D1 GERÇEKLEŞEN yöntem (2026-07-02) — postgres_fdw köprüsü kuruldu
Demo tarafında (demo Management API `/database/query` ile) çalıştırıldı:
1. `CREATE EXTENSION postgres_fdw;`
2. `CREATE SERVER prod_srv` → host `aws-1-eu-west-1.pooler.supabase.com`, **port 5432 (session mode; transaction-mode 6543 FDW için uygun değil)**, dbname `postgres`, `sslmode 'require'`.
3. `CREATE USER MAPPING FOR postgres` → user `demo_reader.zqnexqbdfvbhlxzelzju` (pooler `.ref` sonekli), password (`demo_reader` prod rolü, SELECT-only + BYPASSRLS). Mapping **postgres** için: D2 klon RPC SECURITY DEFINER + pg_cron postgres olarak koşar.
4. `IMPORT FOREIGN SCHEMA public EXCEPT (code_embeddings, entity_graph, memory_notes) FROM SERVER prod_srv INTO prod_fdw;` → **prod_fdw** şemasına 61 foreign relation (prod'un tüm tablo+view'ları; 3 AI-infra `vector` tablo hariç, demo'da tip yok).
5. Read testi: `SELECT count(*) FROM prod_fdw.hayvanlar` → 153, `gorev_log` → **1251** (D0 dump'ında 1246'ydı → köprünün **canlı** prod okuduğunun kanıtı). Eksik base tablo = 0 (demo'daki her tablo köprüde karşılanıyor → D2 klonu hepsini doldurabilir).

**TUZAK:** Demo Management API'ye Python `urllib` ile POST → **Cloudflare error 1010** (client-signature ban). **`curl` kullan** (veya browser UA header). MCP `mcp__supabase-demo__*` (restart sonrası) bu sorunu yaşamaz.
**AÇIK:** `demo_reader` prod'da SELECT-only + BYPASSRLS olarak duruyor — köprü buna bağlı, artık D2/kalıcı klon için gerekli (DROP etme).

### D2 GERÇEKLEŞEN yöntem (2026-07-02) — demo_klonla() RPC kuruldu + canlı test geçti
SQL repoda: `demo/02_demo_klonla.sql` (+ `demo/01_fdw_bridge.sql`, `demo/README.md`). **Demo-only, prod migration DEĞİL.**
- **DİNAMİK** (2026-07-02 yükseltme): tablo listesi + FK sırası + kolonlar + sequence'ler runtime demo katalogundan (`pg_class`/`pg_constraint` recursive CTE topo-sort + `information_schema`). Gömülü ad yok → demo'ya tablo/kolon eklenince klon otomatik kapsar, regen gerekmez. 44 tablo (agent_* + demo_klon_log + 3 vector-infra hariç, sadece prod_fdw'de olanlar). Kolon listesi = demo ∩ prod_fdw (iki yönlü drift-güvenli).
- **Superuser tuzağı:** Supabase `postgres` superuser değil → `DISABLE TRIGGER ALL` (FK constraint trigger) yasak. Çözüm: `DISABLE TRIGGER USER` (app trigger'ları sustur, sahiplik yeter) + topolojik sıra (FK açık ama sağlanır).
- **pending trigger events tuzağı:** gorev_log'un bir FK'sı DEFERRABLE INITIALLY DEFERRED → INSERT'ten sonra `ALTER TABLE ENABLE TRIGGER` "pending trigger events" ile patlar. Çözüm: re-enable öncesi `SET CONSTRAINTS ALL IMMEDIATE`.
- Kolon listesi çalışma anında **demo** katalogundan üretilir (prod kolon eklese bile demo'nunkiyle sınırlı → drift'e kısmen dayanıklı).
- Tek transaction (atomik, yarım-klon yok). `demo_klon_log` audit (farm_id disiplinli). `GRANT EXECUTE TO authenticated`.
- **CANLI TEST:** `SELECT demo_klonla()` → 44 tablo / 6715 satır / **957ms**. Doğrulama: 8/8 kritik tablo demo == prod_fdw (canlı) birebir (hayvanlar 153, gorev_log 1251, tohumlama 258, cases 27, stok 39, drug_products 25, treatment_days 81, padoklar 9).

## Amaç

Login ekranında "🧪 Demo Girişi" butonu → ayrı Supabase projesinde gerçek verinin **kopyası**. Demo'daki yazmalar **geçici**: prod → demo klon her tetiklendiğinde üzerine yazılır. Tetik iki yoldan: **pg_cron (saatlik)** + **UI "↻ Prod'dan Klonla" butonu**.

## Mimari Özet

```
KULLANICI ──┬─ gerçek giriş ──▶ PROD PROJESİ (canlı, read-only kaynak)
            └─ 🧪 demo giriş ─▶ DEMO PROJESİ (klon şema, geçici yazma)
                                     │
                                     └─ postgres_fdw ──▶ PROD'u OKUR (pull)
                                        (yön: demo→prod; prod demo'yu GÖRMEZ
                                         → canlı veri asla kirlenmez)
```

- Prod ↔ Demo **iki ayrı proje** — şema birebir aynı (`ground_truth.sql`).
- Köprü tek yönlü: demo, prod'u **okur**. Prod demo'ya erişmez.
- **service_role ASLA client-side** — demo de anon key + RLS `USING(true)` ile çalışır (prod ile aynı model).
- FDW auth için prod'da **read-only rol** (demo yanlışlıkla prod'a yazamaz).

## Fazlar

| Faz | İş | Efor | Durum |
|---|---|---|---|
| **D0** | Demo projesi + şema+veri (prod'dan pg_dump via `demo_reader`, BYPASSRLS) | ½ gün | ✅ **2026-07-02** |
| **D1** | FDW köprüsü: `CREATE SERVER`/`USER MAPPING`/`IMPORT FOREIGN SCHEMA` + read testi | ½ gün | ✅ **2026-07-02** |
| **D2** | `demo_klonla()` RPC: FK-ters TRUNCATE + FK-düz INSERT..SELECT + `setval` — tek transaction + `demo_klon_log` | 1 gün | ✅ **2026-07-02** |
| ~~D3~~ | ~~pg_cron saatlik~~ **İPTAL (2026-07-02)** — prod yavaş değişir, buton yeter. Yerine: girişte popup-hatırlatma (D4) + şema-senkron prod-migration adımı + on-demand şema-diff | — | ❌ iptal |
| **D4** | UI: `config.js` `IS_DEMO` host-tespiti + demo client + login butonu + demo bandı + "↻ Klonla" + giriş-popup ("bir daha gösterme") | 1 gün | ⬜ |
| **D-şema** | Şema-senkron = prod migration'ı demo'ya da uygula + FDW yenile (cron değil, workflow adımı); + on-demand şema-diff uyarısı | ¼ gün | ⬜ |
| **D5** | Sağlamlaştırma: yazma-geçicilik teyidi, service_role client'ta yok kontrolü, klon sırası UI kilidi, deploy | ½ gün | ⬜ |

**Toplam: ~4 gün efor (≈1 hafta takvim).** Faz 2 multi-tenant (~3-4 hafta) DEĞİL — D bilinçli olarak hafif tutuldu.

## Klon RPC Mantığı (D2)

1. **FK-ters sırayla TRUNCATE** (çocuk→ebeveyn: gorev_log, tohumlama, tedavi… önce).
2. **FK-düz sırayla `INSERT..SELECT FROM prod_fdw.*`** (ebeveyn→çocuk: hayvanlar, padoklar… sonra).
3. Her tablo için `setval(seq, max(id))` sequence senkron.
4. Tamamı **tek transaction** (BEGIN..COMMIT — ya hep ya hiç, yarım-klon yok).
5. `demo_klon_log` audit tablosu (tarih, süre, satır sayısı) — **farm_id disiplini**: `farm_id uuid NOT NULL DEFAULT REAL_FARM_ID`.

FK sırası **elle değil**, `ground_truth.sql` tablo bağımlılık grafiğinden topolojik türetilir.

## Kritik Kararlar / Tuzaklar

| Konu | Karar | Neden |
|---|---|---|
| Köprü yönü | demo → prod OKUR | Prod görmez → canlı veri kirlenmez |
| service_role | ASLA client-side | RLS bypass eder (Supabase maintainer uyarısı) |
| FDW auth | prod read-only rol | Demo prod'a yazamaz |
| Klon atomikliği | tek transaction | Yarım-klon = tutarsız demo |
| FK sırası | ground_truth graph'tan | Elle sıralama = kaçınılmaz FK hatası |
| Demo yazma | kalıcılık YOK | Sonraki klon üzerine yazar (istenen) |

## ⚠️ Tek Uzun-Vade Riski: Şema Drift

Prod'a yeni tablo/migration eklenince demo şeması eskir → `demo_klonla()` yeni tabloyu bilmez → klon eksik/patlar. **Çözüm (D3):** prod migration'larını demo'ya da replay eden basit senkron script (veya haftalık `ground-truth-audit.sh` benzeri şema-diff denetimi).

## Faz 2 Bağlantısı

D'nin ayrı projesi, ileride **Faz 2 multi-tenant staging'i** olarak kullanılabilir — farm_id disiplini bugün aktif olduğu için yeni nesneler zaten tenant-hazır doğuyor. Bkz `ReFactorRoadmap.md` Faz 2.
