---
name: code-change-precheck
description: EgeSüt ERP'de bir tablo/kolon/RPC/fonksiyon/view'ı DEĞİŞTİRMEDEN, migration yazmadan veya ui.js/api.js/forms.js gibi JS dosyalarını düzenlemeden ÖNCE zorunlu kod-zekası ön-kontrolü. MUTLAKA kullan — blast radius (etki yarıçapı) gör, sessiz hataları ve olmayan kolon/tablo referanslarını önceden yakala, iş bitince LSP'yi kapat. Tetikleyen durumlar: "migration yaz", "kolon ekle/sil", "RPC veya fonksiyon değiştir", "tabloya alan ekle", "view güncelle", "ui.js düzenle", "şu fonksiyonu refactor et", "yeni RPC oluştur". SADECE gerçek kod/şema değişikliği için — salt-okuma sorgu, kayıt sayma veya "bu RPC ne yapıyor" açıklaması için DEĞİL.
---

# Kod Değişikliği Öncesi Ön-Kontrol (LSP + Impact)

## Neden var

Bu projede çok sayıda agent (Claude Code, openclaude, Goose, DeepSeek — Goose kolu 2026-10-01'de arşivlendi; kanon: worker sonnet-medium) kod yazıyor ve
en sık hasar **değişikliğin etkisini kestirememekten** ve **sessiz hatalardan** geliyor:
olmayan bir kolona referans veren migration, bir fonksiyonu kırınca onu çağıran 10 yeri
fark etmeme, yanlış imzayla RPC. Elimizde bunları **önceden** yakalayan araçlar var:
canlı şemaya bağlı SQL LSP, JS için built-in LSP, ve JS çağrı grafiğini bilen atlas
(`mcp__tools-bank__atlas_query`; gitnexus yalnız isteğe bağlı yardımcı).
Amaç bu araçları değişiklikten **önce** refleks olarak kullanmak — sonra değil.

**Asıl hedef: blast radius (etki yarıçapı).** Bir şeyi değiştirmeden önce "bu neyi kırar?"
sorusunun cevabını görmek.

## Ne zaman zorunlu

- **Her şeyden önce:** `.harness/references/domain-rules.md` okunur (sahip kuralı 2026-09-26) —
  plan/spec/SQL/JS değişikliği iş kuralına uymuyorsa blast-radius temiz olsa da yanlıştır.
- **Migration / SQL yazmadan önce** (yeni RPC, ALTER, kolon/tablo ekleme-değiştirme, view).
- **JS değiştirmeden önce** (`js/ui.js`, `api.js`, `forms.js`, `ai-asistan.js` vb. — özellikle
  global fonksiyon/`rpc`/`pullTables` gibi çok yerden çağrılanlar).
- Küçük görünen tek-satır değişiklik de dahil — "basit" sandığın değişiklik en çok burada patlıyor.

Atlanabilir: salt-okuma keşif, doküman, yorum, test verisi.

## Agent yetenek matrisi (önce kendi durumunu bil)

| Agent | JS için | SQL/migration için |
|---|---|---|
| **Claude Code** | built-in `LSP` aracı (enabled, lazy) + atlas `etki` | SQL LSP `sql-lsp@egesut-local` (reload sonrası aktif) |
| **openclaude** | built-in `LSP` (plugin `false` → önce enable + `/reload-plugins`) | SQL LSP (aynı, on-demand) |
| **Goose / DeepSeek** (ARŞİV 2026-10-01: Goose kolu artık yok; kanon: Claude Code worker sonnet-medium) | built-in LSP YOK → atlas `etki` | built-in LSP YOK → `supabase_migrate` ile canlı `information_schema`/`pg_get_functiondef` doğrulaması |

Built-in `LSP` aracı yoksa (Goose/DeepSeek) panik yok: aynı işi atlas `etki` (kod) +
`supabase_migrate` (DB şema sorgusu) ile yap.

## İş akışı — JS değişikliği

1. **Blast radius:** `mcp__tools-bank__atlas_query(repo="egesut-erp1", komut="etki", arg="<fnAdı>", derinlik=2)`
   → geçişli çağıranlar (atlas_query tazeliği kendisi doğrular; sonuç şüpheliyse `atlas_status`).
   Etki katmanında `index.html:<satır>` id'li çağıran onclick/inline handler kökenlidir (zincir orada
   biter); ayrıntı için `komut="fn"` → `inline_cagiranlar`. Atlas risk seviyesi vermez: çağıran sayısı
   fazlaysa ya da birden çok katmana (ui/api/forms/app/state) yayılıyorsa kullanıcıya bildir.
   Yerel kurulumdaki (settings.local.json) PreToolUse hook'u `js/(ui|api|forms|app|state).js` Edit/Write'ını son 600 sn içinde
   başarılı atlas `etki` çağrısı yoksa bloklar.
2. **Doğrula / gez:** built-in `LSP` aracıyla
   - `goToDefinition` — gerçek tanımı bul (ui.js 8000+ satır, grep'le boğulma).
   - `findReferences` — değiştireceğin sembolün tüm kullanımları (blast radius'u somutlaştırır).
   - `documentSymbol` — dosyanın haritası.
3. Değişikliği yap.
4. **Commit/merge öncesi:** atlas'ta diff→sembol yok. Değişen fonksiyon adlarını
   `git diff -U0 -- js/` hunk'larından çıkar → her biri için `atlas_query` `komut="etki"`.
   gitnexus `detect_changes` zorunlu değil, isteğe bağlı yardımcı: js/ui.js'i görmez (512 KB sınırı),
   indeks bayat olabilir.
5. **Kapat** (aşağıdaki yaşam döngüsü).

## İş akışı — migration / SQL

1. **Şema taze mi?** SQL LSP, Neon'daki şema aynasına bakar. Aynanın canlıyla güncel olması için
   son migration'dan sonra tazelenmiş olmalı:
   ```bash
   bash /root/egesut-erp1/scripts/refresh_lsp_schema.sh   # canlıdan Management API ile çeker
   ```
   Şüphedeysen önce bunu çalıştır — **bayat ayna = yanlış-pozitif** (var olan kolona "yok" der).
2. **Doğrula:** yazacağın SQL'i bir dosyaya koyup
   ```bash
   postgrestools check --config-path=/root/egesut-erp1/postgres-language-server.jsonc /tmp/yeni.sql
   ```
   → olmayan kolon `42703`, olmayan tablo `42P01` yakalanır. (Claude Code/openclaude'da `.sql`
   açınca built-in `LSP` aracı da aynı diagnostic'i verir.)
3. **Referans = canlı şema (birincil) + ground_truth (doğrulandı).** ground_truth.sql 2026-06-25 Faz 2'de onarıldı (41 tablo · 12 view · 165 fn kanonik eşleşme).
   (dogum tablosu gövdesiz vb. — onarım ayrı görev). Kolon/tablo doğruluğu için **SQL LSP / canlı
   şemaya** güven, ground_truth'a değil. Bkz proje memory `project_lsp_neon_schema_source`.
4. **DB blast radius (gelişmiş):** "bu kolonu/fonksiyonu değiştirsem ne kırılır?" sorusunun
   cevabını tek komutla al. İki katmanlı tarama (structural pg_depend + textual gövde grep)
   canlı Supabase'den çalışır, Neon'a dokunmaz:
   ```bash
   bash scripts/db-blast-radius.sh hayvanlar                # tablo bazlı
   bash scripts/db-blast-radius.sh tohumlama case_id        # kolon bazlı
   bash scripts/db-blast-radius.sh hayvan_ekle              # fonksiyon bazlı
   ```
   Çıktı: view / FK / trigger / fonksiyon gövdesi / view tanımı bağımlıları + risk seviyesi
   (0=düşük, 1-4=orta, 5+=yüksek — kullanıcıya bildir).
5. Migration'ı yaz → **dry-run** ile Neon aynasında dene (canlıya dokunmadan, BEGIN/ROLLBACK):
   ```bash
   bash scripts/db-dry-run.sh /tmp/yeni-migration.sql
   ```
   Hata kodlarını yakalar (42703 yok-kolon / 42P01 yok-tablo / 42883 yok-fonksiyon).
   Uyguladıktan sonra `refresh_lsp_schema.sh` ile aynayı tazele.
5b. **db-validation kapısı (ZORUNLU):** dry-run sonrası `scripts/db-validate.sh <migration>` kanıtı olmadan migration teslim edilmez — taslak üzerinde ve final dosyada koş, rapor `reports/db-validation-<sha8>.md`; detay: `.claude/skills/db-validation/SKILL.md`.

6. **farm_id ileri-disiplini (YENİ nesne ise):**
   - Yeni tablo **tenant-scoped** mu? → `farm_id uuid NOT NULL DEFAULT '400b9107-a85e-4126-af2c-fd7fe73fb68e'` kolonu + `(farm_id, ...)` index. FK YOK (farms Faz 2'de).
   - Yeni yazma fonksiyonu tenant tabloya INSERT mi? → `farm_id = public.current_farm_id()` damgası.
   - Yeni RLS policy → `USING(true)` KALSIN (Faz 2'de flip edilecek).
   - Detay + global-katalog istisnası: `.claude/farm-id-discipline.md`.

## On-demand yaşam döngüsü (ZORUNLU — RAM disiplini)

LSP sunucuları açıkken ~503MB RAM + CPU yer. Ortam RAM'i dar. **Kullan, işin bitince KAPAT.**

- **Claude Code:** plugin `true` ama lazy — sunucu sadece `LSP` aracını çağırınca doğar.
- **openclaude:** önce enable et (`/reload-plugins`), kullan.
- **İş bitince kapat:**
  ```bash
  bash /root/egesut-erp1/scripts/lsp-ctl.sh stop-openclaude   # TS/JS LSP süreçlerini öldür
  bash /root/egesut-erp1/scripts/sql-lsp.sh stop              # SQL LSP süreçlerini öldür
  ```
- Durum kontrol: `bash scripts/lsp-ctl.sh status` · boşta hiçbir LSP süreci kalmamalı.

**Kural:** Bir oturumda LSP'yi başlattıysan, kod/migration işin bittiğinde kapatmadan bırakma.

## Hızlı kontrol listesi

Değişiklikten önce kendine sor:
- [ ] Bu bir JS veya SQL/migration değişikliği mi? (evet → devam)
- [ ] Blast radius'a baktım mı? (JS: atlas `etki` + `findReferences` · DB: `pg_depend`)
- [ ] Çağıran sayısı fazla / geniş katman (DB: yüksek risk) varsa kullanıcıya bildirdim mi?
- [ ] (SQL) Şema aynası taze mi, SQL LSP "yok kolon/tablo" diyor mu?
- [ ] (YENİ tablo / yazma RPC) **farm_id ileri-disiplini** uygulandı mı? → bkz `.claude/farm-id-discipline.md`
- [ ] İş bitince LSP'yi kapattım mı?

## Bilinen sınırlar (yanılmamak için)

- Neon aynası **constraint-free** (FK/PK/index yok) → FK-tabanlı lint'ler kapalı, gürültü vermez ama
  referans bütünlüğü kontrolü beklenmez. Kolon/tablo/fonksiyon **varlık** ve tip kontrolü çalışır.
- Aynanın tazeliği `refresh_lsp_schema.sh`'in son çalıştırılma zamanına bağlı — migration sonrası tazele.
- ground_truth.sql onarımı ayrı bekleyen iş (Görev B).
