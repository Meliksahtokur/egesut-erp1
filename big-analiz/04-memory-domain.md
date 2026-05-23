# Memory ve Domain Kuralları Dökümü

**Tarih:** 2026-05-23  
**Kaynak:** tools-bank SQLite memory sistemi + .claude referans dosyaları  
**Not:** Bu döküm, EgeSüt ERP projesinin tüm iş kurallarını, sistem mimarisini ve hata geçmişini kapsamlı olarak belgeler. Yeni özellik geliştirirken veya hata ayıklama sırasında başvuru kaynağı olarak kullanılabilir.

---

## 1. Kritik Kurallar (critical_rules)

Projede uyulması zorunlu olan temel kurallar. Bu kuralları ihlal etmek sistem bütünlüğünü bozar.

### 1.1 Journal-First Pattern (Crash-Safe Workflow)
- **Tarih:** 2026-05-18
- **Tanım:** Tüm recipe'lere (worker.yaml, egesut.yaml, egesut-telsiz.yaml) journal-first pattern eklendi. Her task başlangıcında `blackboard/working/{task_id}.md` dosyası oluşturulur veya okunur. Tamamlanan adımlar `[x]` işaretlenir.
- **Amaç:** Crash sonrası worker kaldığı yerden devam edebilsin, token kaybını önle, araştırma context window'dan taşmasın.
- **Uygulanması:** egesut-telsiz'de dosya adı: `{agent_id}-{message_id}.md`

### 1.2 goused Restart Stratejisi (Cascade Watchdog)
- **Tarih:** 2026-05-17
- **Tanım:** Üç katmanlı restart sistemi:
  - **Katman 1:** mcp_watchdog.sh, her 2 dakikada /health ping, binary'yi yeniden başlatır
  - **Katman 2:** Binary içi graceful shutdown (signal.NotifyContext)
  - **Katman 3:** goused-watchdog binary, her 30 saniyede ping, exec.Command ile restart
- **Kritiklik:** goused binary'leri (proxy, api, telsiz) PRoot'ta io_uring SIGSEGV sorunu var → TOKIO_DISABLE_IO_URING=1 env var zorunlu

### 1.3 Telsiz Spam Önleme + Eksik Noktalar
- **Tarih:** 2026-05-17
- **Rate Limit:** task=10/dk, question=20/dk, heartbeat=3/dk
- **Dedup:** 5 saniye penceresinde aynı (from, to, payload_hash) reject
- **Cooldown:** Aynı (from, to) çifti 3 saniye aralık, priority:high atlar
- **Eksik Noktalar:**
  1. Priority queue — high mesaj öne geçmesi (henüz yok)
  2. DLQ — okunmamış süresi dolan kritik mesajlar
  3. agent_find(capability) tool
  4. Session resume — crash sonrası aynı session_id ile rejoin
  5. Broadcast to:* channel
- **Master Symlink:** tools-bank/docs/agent-telsiz-mimarisi.md

### 1.4 PRoot io_uring Crash (TOKIO_DISABLE_IO_URING=1)
- **Tarih:** 2026-05-19
- **Sorun:** goused-proxy/api/telsiz/watchdog binary'leri PRoot aarch64'te tokio io_uring syscall uyumsuzluğundan SIGSEGV (fault 0x1006)
- **Çözüm:** TOKIO_DISABLE_IO_URING=1 env var ile başlatmak
- **Etki:** PRoot ortamında goused altyapısının stabil çalışmasını sağlar

### 1.5 Turn Re-trigger Sorunu (Çözümsüz Workaround)
- **Tarih:** 2026-05-17
- **Sorun:** PTY injection Python'da denendi — olmadı (ekrana basıyor, satıra değil). Go'da da fark etmez, OS seviyesi aynı.
- **MCP Sampling:** Teorik ama 3 ajanın (Claude, DeepSeek, 3.) client implement etmesi gerekiyor — garantisiz
- **Çözüm:** DeepSeek context 300k'ya çık, oturum uzasın. Goose işin büyüğünü yapsın, main agent sadece review anında devreye girsin. Re-trigger ihtiyacı minimize edilir, çözülmez.

### 1.6 Daemon Crash Kök Nedeni (Tokio Runtime)
- **Tarih:** 2026-05-17
- **Kök Neden:** Goose Rust/tokio runtime kullanıyor. Tokio io_uring + agresif epoll → PRoot syscall stub'larına çarpıyor → panic
- **Çözüm Strateji:** daemon'u kaldır, Goose'u foreground on-demand çalıştır. Go runtime PRoot'ta teorik olarak stabil (io_uring yok) — test edilmedi.

### 1.7 Çözülen Kızgınlık View Sorunu
- **Tarih:** 2026-05-20
- **Düzeltme:** cozulmemis_kizginlik_view'a `kl.cozuldu=true` kontrolü eklendi. Artık tedaviyle çözülen kızgınlıklar da "cozuldu" sayılır, badge'de görünmez.
- **RPC Güncelleme:** tohumlama_geri_al RPC'sinde tedavi_case_id kontrolü eklendi: `AND tedavi_case_id IS NULL`

### 1.8 Migration Idempotency (SQL Yazma Kuralı)
- **Tarih:** 2026-05-16
- **Kural:** Tüm migration'lar idempotent olmalı: `DROP IF EXISTS` + `CREATE OR REPLACE` pattern
- **İhlal Sonucu:** Aynı migration iki kez çalıştırılırsa veri kaybı veya schema bozulması

### 1.9 Gebelik Protokol Birleştirme Review Edilmedi
- **Tarih:** 2026-05-19
- **Durum:** 4 paralel subagent model hatası (deepseek / sonnet provider hatası) nedeniyle çalışmadı
- **Manuel Tamamlama:** Syntax kontrolü: node --check js/api.js js/ui.js js/app.js — PASS
- **DB Doğrulama:** gebelik_protokol_kontrol() döndü {ok:true, olusturulan:0}, ileri_gebe_view 10 kayıt döndü
- **Açık Konu:** Subagent provider model konfigürasyonu gözden geçirilmeli

### 1.10 goused Review Kritik Bulguları (Go Code)
- **Tarih:** 2026-05-17
- **Göğüs Buluşları:**
  1. r.Body.Close() nil dereference — `if r.Body != nil` bloğu içine alınmalı
  2. recover() ListenAndServe goroutine'inde olmayabilir — `defer func(){recover()}()` ekle
  3. Non-JSON POST body 400 değil forward edilmeli
  4. http.Client per-request değil package-level olmalı
  5. ReadTimeout:5s → ReadHeaderTimeout:5s (streaming keser)
  6. isStream sadece request body değil upstream Content-Type:text/event-stream'e göre de set edilmeli
  7. http.Error(w,...) yerine http.Error(rw,...) — wrapper üzerinden yazılmalı

### 1.11 Git Commit Zorunlu Kuralı
- **Tarih:** 2026-05-16
- **Kural:** Tüm değişiklikler commit + push edilmeli. Commit, işin kanıtı.

### 1.12 PRoot setsid Sorunu (nohup ile Düzeltme)
- **Tarih:** 2026-05-17
- **Sorun:** PRoot'ta setsid çalışmaz (session oluşturamaz, process hemen olur)
- **Çözüm:** start_pipeline.sh'deki setsid'ler nohup ile değiştirildi. Ayrıca `set -e` kaldırıldı (sync_blackboard.py fail = pipeline olmesin)

### 1.13 EgeSüt ERP Mimari Felsefesi
- **Tarih:** 2026-05-16
- **Prensip:** Frontend asla iş mantığı yapmaz, sadece render ve input toplar. Tüm iş mantığı, validasyon, hesaplama, state machine'ler PostgreSQL'de (RPC + trigger + view).
- **Gerekçe:** Frontend ERP'de güvenilmezdir (DevTools override, çoklu cihaz, offline)
- **Dokümantasyon:** .claude/skills/egesut-erp-architecture/SKILL.md'ye yazıldı, DeepSeek TUI'ye symlinklendi

### 1.14 goused-api Kritik Fix'leri
- **Tarih:** 2026-05-17
- **Düzeltmeler:**
  1. s.Create() goroutine spawn'dan ÖNCE çağrılmalı — aksi halde hızlı çıkan process Wait goroutine'i DB kaydını bulamaz
  2. logFile.Close() cmd.Start() sonrası parent'ta çağrılmalı — child fork'ta fd inherit eder
  3. runningCmds map + sync.Mutex ile cmd takibi — cmd.Wait() goroutine zombie'yi reap eder
  4. StopProcess: tracked cmd üzerinden SIGTERM → fallback FindProcess

### 1.15 PostgREST Function Overload Sorunu
- **Tarih:** 2026-05-16
- **Sorun:** Aynı isimde farklı parametreli iki fonksiyon varsa PostgREST PGRST203 hatası
- **Çözüm:** Eski versiyonu DROP FUNCTION IF EXISTS ile silmeden yeni versiyon CREATE OR REPLACE yapılırsa, eski parametreli versiyon kalır ve çakışır. CREATE OR REPLACE sadece AYNI imzayı günceller.

### 1.16 Git Race Condition — Commit Lock (Planlandı)
- **Tarih:** 2026-05-18
- **Sorun:** 3+ eşzamanlı worker (2026-05-18) aynı anda git add/commit yapabilir → corrupt commit, kayıp değişiklik
- **Çözüm (Planlandı):** goused-api'ye commit-lock endpoint ekle
  - Worker akışı: POST /commit-lock/acquire → git add → git commit → git push → POST /commit-lock/release
  - Go mutex + TTL (worker crash durumunda otomatik release)
- **Alternatif:** Orchestrator tüm worker'lar bitince tek commit yapar (atomic ama partial commit edilemiyor)

### 1.17 goused-proxy Kritik Fix'leri
- **Tarih:** 2026-05-17
- **Düzeltmeler:**
  1. r.Body.Close() nil dereference — `if r.Body != nil` bloğu içine alınmalı (GET body nil)
  2. recover() ListenAndServe goroutine'inde olmalı
  3. Non-JSON POST body 400 reject değil log+forward
  4. http.Client package-level olmalı (connection pool)
  5. ReadTimeout:5s → ReadHeaderTimeout:5s (streaming keser)
  6. isStream: request body "stream":true VE upstream Content-Type:text/event-stream
  7. http.Error(w,...) yerine http.Error(rw,...) — wrapper üzerinden yazılmalı

### 1.18 tools-bank MCP Server Python Import Hatası
- **Tarih:** 2026-05-19
- **Sorun:** from mcp_server.server import main → ModuleNotFoundError. 'main' fonksiyonu bulunamıyor
- **Durum:** 'main' fonksiyonu bulunamıyor. Bunun yerine doğrudan terminal'den goose -i veya -t ile başlatılıyor.
- **Çözüm:** Araştırılmalı

### 1.19 tohumlama.id Canlı DB Tipi vs Belgeler Uyumsuzluğu
- **Tarih:** 2026-05-18
- **Sorun:** AGENTS.md text yazıyor, canlı DB'de uuid
- **Doğru Bilgi:** Tablo ID tipleri referansı — önceki kayıt YANLIŞ, gorev_log.id uuid DEĞİL text'tir

### 1.20 SQL Approval Gate + Canonical Referans Kuralı
- **Tarih:** 2026-05-18 (Tüm agent dokümantasyonuna eklendi)

#### Kural 1 — CANONICAL REFERANS:
SQL veya RPC yazmadan önce ZORUNLU okunacak dosyalar:
1. `supabase/migrations/99999999999999_ground_truth.sql` — tek canonical kaynak
2. `.claude/rpc-reference.md` — mevcut RPC imzaları
3. `.claude/domain-rules.md` — iş kuralları

**YASAK:** *_revize.sql, *_fix.sql, herhangi ara migration dosyası referans olarak kullanmak.

**Neden:** Goose 2026-05-18'de revize migration'ı referans alarak 30 hayvan için yanlış görev açtı.

#### Kural 2 — APPROVAL GATE:
Herhangi CREATE/ALTER/UPDATE/INSERT/DELETE yazmadan önce orchestrator/kullanıcıya onay sor:
- **Format:** "ONAY GEREKLİ: [ne yapılacak] · Etkilenecek: [tablolar] · Risk: [...] · SQL taslağı: [sql]"
- **Kural:** Onay gelmeden hiçbir DB yazma yapma
- **Muafiyet:** Sadece SELECT/okuma → onay gerekmez

#### Kural 3 — DEPLOY:
Migration dosyası repoda = canlıda DEĞIL
- supabase_migrate MCP aracı ile ayrıca deploy gerekli
- GitHub Pages sadece JS günceller, SQL'i Supabase'e göndermez

**Güncellenen Dosyalar (Tüm Kurallar):**
- CLAUDE.md (Claude için)
- AGENTS.md (Goose/Pi için)
- egesut-erp-architecture/SKILL.md (Claude skill)
- tools-bank/skills/egesut-erp/SKILL.md (Goose skill)
- tools-bank/skills/kaz_cobani/SKILL.md (orchestration skill)
- tools-bank/recipes/goose-ops.yaml (Tier-1 orchestrator recipe)
- tools-bank/recipes/egesut-telsiz.yaml (worker recipe)
- tools-bank/recipes/egesut.yaml (blackboard worker recipe)

### 1.21 gorev_log.id Tipi TEXT (UUID String)
- **Tarih:** 2026-05-18
- **Doğru Bilgi:** 
  - Fiziksel kolon tipi: TEXT PRIMARY KEY
  - İçerik: UUID string saklar (örn: 'f454bdd3-...')
  - INSERT için: gen_random_uuid()::text veya gen_random_uuid() (PostgreSQL implicit cast yapar)
  - WHERE için: WHERE id = p_gorev_id — cast GEREKMİYOR, iki taraf da text

### 1.22 DeepSeek Proxy Başlatma Kuralı
- **Tarih:** 2026-05-17
- **Kural:** Proxy DEEPSEEK_API_KEY env değişkeni olmadan başlarsa 401 döner
- **Başlatma:** `DEEPSEEK_API_KEY=<key> setsid python3 /root/tools-bank/workers/deepseek_proxy.py > /tmp/deepseek_proxy.log 2>&1 &`

### 1.23 Deploy Hatası (Migration Repoda ≠ Canlı)
- **Tarih:** 2026-05-16
- **Sorun:** Migration dosyası repoda olması canlı DB'ye uygulandığı anlamına GELMEZ
- **Çözüm:** supabase_migrate MCP aracıyla veya supabase db push ile ayrıca deploy
- **Not:** GitHub Pages JS'i günceller ama SQL'i Supabase'e göndermez

### 1.24 Tablo ID Tipleri Referansı (Düzeltme)
- **Tarih:** 2026-05-18
- **Eski Kayıt:** YANLIŞ, gorev_log.id uuid yazıyordu
- **Doğru Referans:**
  - **TEXT ID:** hayvanlar, stok, hekimler, tohumlama, gorev_log
  - **UUID ID:** stok_hareket, padoklar, vaccines, grup_padok_eslem, islem_log

### 1.25 deerflow_gateway_restart() Tasarım Kuralları
- **Tarih:** 2026-05-20
- **Kural 1:** Gateway zaten çalışıyorsa ERKEN DÖN, process öldürme (deerflow_health() kontrolü önce)
- **Kural 2:** uvicorn komutu: `uv run uvicorn app.gateway.app:app --host 0.0.0.0 --port 8001 --log-level warning`
- **Kural 3:** cwd: ~/deer-flow/backend, env: pyenv PATH + UV_LINK_MODE=copy
- **Kural 4:** Max 60 saniye health check döngüsü, 2 saniye aralık
- **Kural 5:** Log: ~/deer-flow/logs/gateway.log, başlatılamadıysa son 10 satır döner
- **Akış:** deerflow_health() ❌ → deerflow_gateway_restart() → deerflow_health() ✅
- **TUI AÇMAZ:** tui+ scripti interaktif, agent için değil

### 1.26 GitHub Actions Deploy (supabase db push)
- **Tarih:** 2026-05-20
- **Tetikleyici:** Main branch'ine migration push'unda
- **Secret Gerekçe:** SUPABASE_ACCESS_TOKEN ve SUPABASE_DB_PASSWORD secret'ları repo'da yoksa workflow sessizce fail eder
- **Manuel Deploy:** supabase_migrate MCP tool ile deploy edilebilir

### 1.27 Fire-and-Forget RPC Sorunu (loadDash Güncelleme)
- **Tarih:** 2026-05-20
- **Sorun:** Fire-and-forget RPC sonucu loadDash() tetiklenmiyorsa dashboard güncellenmez
- **Çözüm:** app.js'de rpc('gebelik_protokol_kontrol').then(...) içinde loadDash() çağrılmalı
- **Genel Kural:** init'te fire-and-forget RPC varsa .then'de UI güncellemesini unutma

### 1.28 MCP Server Zombie İşlemi
- **Tarih:** 2026-05-16
- **Problem:** MCP server (tools-bank) process zombie olursa, pkill -9 -f "server.py --stdio" ile temizle
- **Recovery:** Runtime yeni session'da otomatik spawn eder
- **Belirti:** MCP tool çağrıları "Broken pipe" hatası veriyorsa server ölmüştür

---

## 2. RPC Referansları (rpc_reference)

Tüm RPC fonksiyonlarının imzaları ve davranışları. Frontend her zaman RPC üzerinden yazma yapmalı, direkt REST bypass yapmamalı.

### 2.1 tohumlama_geri_al RPC (Tedavi Case ID Kontrolü)
- **Tarih:** 2026-05-20
- **Param:** tohumlama_id
- **Koşul:** `WHERE cozuldu = true AND tedavi_case_id IS NULL`
- **Davranış:** Kızgınlığa bağlı tedavi varsa (tedavi_case_id dolu) cozuldu=false geri alınmıyor, kızgınlık "sonuçlanan" olarak kalıyor
- **Migration:** 20260520000001

### 2.2 Mevcut RPC Listesi
- **tohumlama_sonuc_bos(tohumlama_id)** → marks as bos
- **stok_duzelt(stok_id, miktar, aciklama)** → stock correction
- **hayvan_guncelle(hayvan_id, kup_no?, dogum_tarihi?, cinsiyet?)** → returns hayvan
- **tohumlama_sonuc_gebe(tohumlama_id, muayene_tarihi)** → marks tohumlama as gebe
- **hayvan_ekle(kup_no, dogum_tarihi, cinsiyet, ...)** → returns hayvan_id

### 2.3 ileri_gebe_view VIEW
- **Tanım:** 210+ gün gebe inekleri listeleme
- **Kolonlar:** hayvan_id, tarih, tohumlama_tarihi, gebelik_gun, kupe_no, devlet_kupe, grup, padok
- **Kullanıcı:** Dashboard'da ileriGebeler state'i bu view'dan doldurulur (eski: frontend'de hesaplanıyordu)
- **Migration:** supabase/migrations/20260519000001

### 2.4 gebelik_protokol_kontrol() RPC
- **Tür:** Parametresiz, SECURITY DEFINER
- **Dönüş:** jsonb şu yapıyla:
  ```json
  {
    "ok": true,
    "olusturulan": N,
    "hayvanlar": [
      {
        "hayvan_id": "uuid",
        "tarih": "YYYY-MM-DD",
        "gebelik_gun": N,
        "kupe_no": "text",
        "devlet_kupe": "text",
        "grup": "text",
        "padok": "text"
      }
    ]
  }
  ```
- **Milestone'lar:** 5 tane
  - 210 (PADOK_DEGISIM - kuru dönem)
  - 240 (ILERI_GEBE_ASI - Rota-Corona 1.doz)
  - 260 (ILERI_GEBE - SC Ademin)
  - 261 (ILERI_GEBE_ASI - Rota-Corona 2.doz düve)
  - 265 (ILERI_GEBE - IM E Vitamini)
- **Özellik:** Idempotent - NOT EXISTS ile duplicate kontrolü
- **Eski RPC'ler:** ileri_gebe_gorev_kontrol(), laktasyon_kuru_kontrol() DROP edildi

### 2.5 laktasyon_kuru_kontrol RPC (Final Versiyon)
- **Tarih:** 2026-05-18 deploy

**Koşullar (3'ü de sağlanmalı):**
1. hayvanlar.durum = 'Aktif'
2. hayvanlar.grup ILIKE '%Sağmal%' AND NOT ILIKE '%Kuru%'
3. EXISTS (SELECT 1 FROM tohumlama t WHERE t.hayvan_id = h.id AND t.sonuc = 'Gebe')
4. dogum tablosuna JOIN, son doğumdan 210+ gün geçmiş (HAVING CURRENT_DATE - MAX(d.tarih) >= 210)

**Dedup Koşulu (aynı hayvana tekrar görev açmaz):**
```sql
WHERE NOT EXISTS (SELECT 1 FROM gorev_log 
  WHERE hayvan_id = v_rec.id AND gorev_tipi = 'PADOK_DEGISIM'
  AND aciklama ILIKE '%Kuru döneme%' AND iptal = false
  AND (NOT tamamlandi OR tamamlanma_tarihi > now() - interval '24 hours'))
```

**Açılan Görev:**
- Tip: PADOK_DEGISIM
- Açıklama: '⚠️ Kuru döneme geçiş zamanı (X. gün laktasyon) — Kuru/Gebe padoğuna transfer'
- Padok Hedef: (SELECT ad FROM padoklar WHERE ad ILIKE '%Kuru%' LIMIT 1)

**Yanlış Versiyonlar (Kullanma):**
- 20260513000003: dogum JOIN yok, sadece grup filtresi
- 20260513000006_revize: dogum JOIN yok, gebe filtresi yok → 30 yanlış görev açtı
- 20260518000002_hotfix: veri düzeltmesi var, RPC referansı değil

**Doğru Kaynak:** 20260518000003_laktasyon_kuru_kontrol_final.sql veya ground_truth.sql  
**Deploy:** supabase_migrate ile 2026-05-18'de canlıya alındı

---

## 3. Domain Kuralları ve İş Mantığı

### 3.1 Hayvan Yaşam Döngüsü
```
Doğum (Buzağı) → Süt İçen → Sütten Kesilmiş → Düve → Tohumlama → Gebe → Doğum
                                                  ↓
                                            Sağmal/Kuru
                                                  ↓
                                            Kızgınlık Döngüsü
                                                  ↓
                                              Kuru Dönem
```

### 3.2 Kızgınlık Uyarı Sistemi
- **Tarih:** 2026-05-17
- **View:** cozulmemis_kizginlik_view (son 3 gün, 12 saat içinde tohumlama varsa 'cozuldu', 24 saat içinde yoksa 'uyari')
- **Tablo:** Mevcut kizginlik_log + tohumlama tabloları kullanılır, yeni schema gerekmez
- **Frontend:** 
  - nb-ureme indicator + dashboard kırmızı alarm (sarıyı ezer)
  - Kızgınlık bar renk sıralaması: kırmızı (uyari) alarmlar üstte, sarı (amber/bekleniyor/kritik) alarmlar altta
  - HTML sırası: #kizginlik-bar önce, #sperma-warn-band sonra
- **Durum:** implementasyon henüz başlanmadı, ancak view tamamlandı

### 3.3 Kuru Dönem (Laktasyon Sonu) Mekanizması
- **210+ Gün Kuralı:** Son doğumdan 210+ gün geçmiş inekler kuru döneme geçmelidir
- **Trigger:** laktasyon_kuru_kontrol() RPC otomatik görev oluşturur
- **Görev Tipi:** PADOK_DEGISIM (Kuru/Gebe padoğuna transfer)
- **Grup Güncellemesi:** Tamamlandığında grup = 'Sağmal (Kuru Dönem)' set edilir

### 3.4 Tohumlama State Machine
```
[Bekliyor] ──→ [Gebe]      [Doğum Yaptı]
    ↓          ↓           (kalıcı)
  [Boş]    [Abort]
           (kalıcı)
```

| Sonuç | Anlamı | İzin verilen geçişler |
|---|---|---|
| Bekliyor | Tohumlama yapıldı, sonuç bekleniyor | → Gebe, → Boş |
| Gebe | Gebelik onaylandı | → Doğum Yaptı (RPC), → Abort (RPC) |
| Boş | Tohumlama tutmadı | → Bekliyor (hatalı kayıt düzeltme) |
| Doğum Yaptı | Doğum gerçekleşti | Değiştirilemez |
| Abort | Erken doğum / gebelik kaybı | Değiştirilemez |

**Kritik Kural:** Gebe ve Doğum Yaptı durumundaki kayıtlar frontend üzerinden doğrudan değiştirilemez. Tüm kritik geçişler RPC üzerinden yapılmalıdır.

### 3.5 Gebelik Süresi ve Kontrol Görevleri
- Tahmini doğum = tohumlama tarihi + 280 gün
- 21. gün gebelik kontrolü görevi otomatik oluşturulur
- 35. gün gebelik kontrolü görevi otomatik oluşturulur

### 3.6 Doğum Kaydının Yaptıkları (14 görev üretir)

1. dogum tablosuna kayıt ekler
2. Buzağıyı hayvanlar tablosuna ekler (grup: Süt İçen Buzağı, padok: Buzağı Ahırı)
3. Buzağıya anne ırkı atanır
4. Buzağıya baba bilgisi (p_baba) yazılır
5. Annenin açık tohumlama kaydını `sonuc = 'Doğum Yaptı'` olarak kapatır
6. Anneye doğum sonrası ilaç protokolü görevleri oluşturur (7 görev):
   - Doğum günü: Oksitosin + Ademin + Kalsiyum
   - 2. Gün: PG
   - 11. Gün: PG
   - 25. Gün: PG
   - 53. Gün: Ademin + Yeldif
   - 54. Gün: Yeldif
   - 58–63. Gün: Kızgınlık takibi
7. Buzağıya ilk gün bakım görevleri oluşturur (6 alt görev):
   - Kolostrum (ilk 2 saat)
   - Göbek kordonu dezenfeksiyonu (iyot)
   - Küpeleme
   - Ademin (1. gün)
   - Maya (1. gün)
   - Probiyotik (1. gün)

### 3.7 Recurring Task Sistemi (Kısmen Mevcut)
- **Mevcut:** vaccines.repeat_interval_days kolonu var, add_vaccination RPC next_due_date hesaplıyor ama gorev_log'a INSERT yapmıyor
- **Mevcut:** ileri_gebe_asi_tamamla RPC 21 günlük rapel görevi oluşturuyor
- **Eksik:** Genel amaçlı recurring engine (X-Y gün penceresi, trigger-start/end) YOK
- **Kayıt:** DEFERRED_FEATURES.md'de de kayıtlı değil

### 3.8 Anyonik Besleme (Henüz Eklenmemiş)
- **Tanım:** Pre-birth döneminde özel beslenme protokolü
- **Durumu:** EgeSüt ERP'de YOKTUR — sıfırdan eklenmeli
- **Mevcut Pre-Birth Görevleri:** 
  - 240.gün Rota-Corona 1.doz
  - 260.gün SC Ademin
  - 261.gün Rota-Corona 2.doz (düve)
  - 265.gün IM E Vitamini
- **Trigger:** trg_tohumlama_gebe_gorev + ileri_gebe_gorev_kontrol() RPC
- **Önerilen Gün:** 250-255
- **Pattern:** SC Ademin ile aynı (ILERI_GEBE tipi, stok yok, fn_gebe_gorev_yarat + RPC'ye ekle)
- **Effort:** S ~30 dakika
- **Rapor:** /root/tools-bank/reports/task-logic-audit-2026-05-18.md

### 3.9 Kritik İş Kuralları Özeti

1. **Erkek hayvan tohumlanamaz, sağmal/gebe grubuna girilemez**
2. **12 aydan küçük hayvan tohumlanamaz, kızgınlık kaydı yapılamaz**
3. **Aktif gebeliki olan hayvan tekrar tohumlanamaz**
4. **Tohumlama tarihi ileri tarih olamaz; doğum tarihi ileri tarih olamaz**
5. **12 aydan büyük hayvan buzağı grubuna eklenemez**
6. **Gebe ve Doğum Yaptı tohumlama kayıtları direkt değiştirilemez — RPC kullan**
7. **Doğum veya abort geçmişi olan dişi hayvan artık düve değil inek (Sağmal/Kuru)**
8. **Tohumlama verisi yalnızca RPC üzerinden yazılmalı; direkt REST PATCH validation'ı bypass eder**

### 3.10 Grup-Padok Eşlemeleri

| Grup | Padok |
|---|---|
| Sağmal (Laktasyonda) | Sağmal Padok |
| Sağmal (Kuru) | Kuru/Gebe Padok |
| Gebe Düve | Kuru/Gebe Padok |
| Düve (Büyük) | Düve Padok (Büyük) |
| Düve (Küçük) | Düve Padok (Küçük) |
| Süt İçen Buzağı | Buzağı Padok (Süt İçenler) |
| Sütten Kesilmiş Buzağı | Buzağı Padok (Sütten Kesilmiş) |
| Besi | Besi Padok (Erkek) veya Besi Padok (Dişi) |

**Erkek Kural:** Erkek hayvan Sağmal / Kuru / Gebe grubuna girmez. Backend ve frontend her ikisi de bu kontrolü yapar.

### 3.11 Yaşa Göre Grup Sınırları

**Dişi:**
| Yaş | İzin verilen gruplar |
|---|---|
| 0–75 gün | Süt İçen Buzağı |
| 76–180 gün | Sütten Kesilmiş Buzağı |
| 181–365 gün | Düve (Küçük) |
| 366–730 gün | Düve (Büyük), Düve (Küçük) |
| 730+ gün veya yaş bilinmiyor | Sağmal, Kuru, Gebe Düve, Düveler |
| Tohumlama geçmişi var | + Gebe Düve seçeneği eklenir |
| Doğum veya abort geçmişi var | Yalnızca Sağmal (Laktasyonda), Sağmal (Kuru) |

**Erkek:**
| Yaş | Grup |
|---|---|
| 0–75 gün | Süt İçen Buzağı |
| 76–180 gün | Sütten Kesilmiş Buzağı |
| 180+ gün | Besi |

---

## 4. Kod Değişiklik Geçmişi (code_change)

### 4.1 Tools-Bank Memory Iyileştirme
- **Tarih:** 2026-05-20
- **Değişiklikler:** obsolete + superseded_by altyapısı kuruldu
- **Ayrıntılar:** search_tool.py varsayılan olarak obsolete notları gizler. CLI çıktısında source + created_at gösterilir. Füzyon arama (FTS5+semantic hybrid) --hybrid flag ile.

### 4.2 Goused Skill Oluşturuldu
- **Tarih:** 2026-05-17
- **Konum:** egesut-erp1/.claude/skills/goused/SKILL.md
- **Trigger:** goose_start/status, agent_register/send/receive, telsiz, "direktif gönder", "goose worker başlat"
- **İçerik:** Binary durum kontrolü + başlatma komutu, 5 MCP tool referansı, 3 örnek akış (worker orkestrasyon, claude-as-orchestrator, question/answer), spam önleme tablosu
- **Symlink:** tools-bank/.claude/skills/goused → symlink (DeepSeek TUI erişimi)
- **Commit:** egesut-erp1 044f21b

### 4.3 Gebelik Protokol Birleştirme
- **Tarih:** 2026-05-19
- **Durum:** Review tamamlandı ve ONAYLANDI
- **Detay:** v_stok_id risksiz — Rotavirus Aşısı vaccines tablosunda mevcut (stock_item_id: STOK-AŞI-49f4007f-...)
- **ileri_gebe_view:** nearBirth hesabı değişmeden kaldı
- **Migration:** 20260519000001 deploy edildi
- **Commit:** 93e830b

### 4.4 USAGE_GUIDE.md Uyarlaması
- **Tarih:** 2026-05-17
- **Bölüm:** §8 goused API gateway
- **İçerik:** Binary tablosu, başlatma komutları, 5 MCP tool açıklaması (goose_start/status + agent_register/send/receive), orkestrasyon akış örneği, spam önleme/TTL tablosu, hata durumu
- **Konum:** /root/tools-bank/docs/USAGE_GUIDE.md
- **Commit:** bdf32f5

### 4.5 2026-05-20 Oturumu Kapsamlı Bugfix
- **Tarih:** 2026-05-20
- **Değişiklikler:**
  1. tohumlama_geri_al tedavi_case_id kontrolü
  2. cozulmemis_kizginlik_view kl.cozuldu=true
  3. Kızgınlık search+filtre UI
  4. Hayvan kartı openDet iptal gorev filtresi
  5. tools-bank memory obsolete altyapısı + Jina fix + fuzyon arama + MCP server fix
- **Commit:** 2e8f648..4f69d45 + /root/tools-bank/mcp_server/server.py

### 4.6 Researcher Recipe Fix
- **Tarih:** 2026-05-17
- **Sorun:** duckduckgo MCP references (uvx libstdbuf.so link error in PRoot)
- **Çözüm:** 
  - read→read_file değiştirildi
  - task_get() çağrıları kaldırıldı
  - Goose 1.31.1 için proper tool names eklendi
  - Web search fallback: exec_shell with curl to html.duckduckgo.com
- **Dosya:** /root/tools-bank/recipes/researcher.yaml

### 4.7 Kızgınlık Sayfası Arama ve Filtre
- **Tarih:** 2026-05-20
- **Değişiklikler:**
  - Küpe arama search bar (data-input=kizginlik-search, 250ms debounce)
  - Filtre butonları: Tümü / Bekleyen / Sonuçlanan
  - _uremeKizginlik'te globalThis._kizginlikFilter state'i
- **Cache Buster:** pre-commit hook otomatikleştirildi
- **Dosyalar:** index.html, ui.js, handlers.js

### 4.8 Goused Dizin Yapısı
- **Tarih:** 2026-05-17
- **Yapı:** /root/tools-bank/cmd/goused-proxy/, goused-api/, goused-telsiz/, goused-watchdog/ — her biri ayrı main.go
- **Paketler:** internal/proxy/, internal/api/, internal/telsiz/, internal/db/ paket bazlı
- **Module Adı:** tools-bank
- **Dış Bağımlılık:** github.com/mattn/go-sqlite3
- **SQLite Yolları:** 
  - goused-api → memory/goose_sessions.db
  - goused-telsiz → memory/telsiz.db
- **Build:** bin/build.sh

### 4.9 Telsiz-Enabled Recipe Stratejisi
- **Tarih:** 2026-05-17
- **Strateji:** Mevcut egesut.yaml, worker.yaml vb. çalışıyorsa DOKUNULMAZLAR
- **Yeni:** recipes/egesut-telsiz.yaml yazılır — telsiz_ac (agent_register) + direktif_bekle (agent_receive 60s) + iş mantığı + sonuc_bildir (agent_send type=result)
- **Deployment:** Test+stabil olunca eski recipe arşive. Öncelik: telsiz binary hazır olduktan sonra.

### 4.10 Tools-Bank MCP Tüm Araçlar Test (2026-05-17)
- **Tarih:** 2026-05-17
- **Sonuç:** TÜM araçlar çalışıyor
- **Stats:** 36 not, 8.82MB
- **Araçlar:** memory_stats (FTS5+sqlite-vec), memory_search, supabase_query (memory_notes), semantic_search (vektör), knowledge_graph_query, gitnexus_list_repos (egesut-erp1: 3172 sembol, 5572 edge), gitnexus_query, gitnexus_context, file_list, goose_search, context7_resolve_library_id, context7_get_library_docs
- **Toplam:** 13 extension, 61 araç aktif

### 4.11 Goused-Telsiz (:8744) Tamamlandı
- **Tarih:** 2026-05-17
- **Dosyalar:** internal/telsiz/store.go + handler.go + cmd/goused-telsiz/main.go
- **Özellikler:**
  - POST /register, POST /send, GET /receive/{id}?timeout= (long-poll 0.5s)
  - GET /whosonline, POST /heartbeat, GET /health
  - SQLite WAL, TTL temizleme (10dk), heartbeat checker (60s)
  - claimNextMessage: BeginTx LevelSerializable (BEGIN IMMEDIATE) ile çift teslim önlendi
- **Dedup:** hash 5s
- **Cooldown:** 3s, high atlar
- **Rate Limit:** 60s window
- **Build:** go build -o bin/goused-telsiz ./cmd/goused-telsiz/ ✓

### 4.12 Kızgınlık Uyarı Sistemi Tamamlandı
- **Tarih:** 2026-05-17
- **View:** cozulmemis_kizginlik_view (DISTINCT ON hayvan_id, olusturma/created_at timestamps ile 12s/24s state machine)
- **Frontend:** #kizginlik-bar persistent strip (tüm sayfalar, #sync-bar deseninde, kırmızı üstte/sarı altta)
- **Nav Indicator:** #ubadge (.nbadge class, count gösterilir, 99+ kırpım)
- **Migration:** 20260517000001_kizginlik_uyari_view.sql canlıda
- **Commit:** 2b5ab4b

### 4.13 Goused Sistem Testi Geçti
- **Tarih:** 2026-05-17
- **Tüm Binary'ler Ayakta:** proxy(:8742) + api(:8743) + telsiz(:8744) + watchdog
- **Testler Sonucu:**
  - health ✓
  - register ✓
  - send/receive ✓
  - whosonline ✓
  - duplicate reject ✓
  - api validation ✓
  - proxy upstream passthrough (401) ✓
- **Başlatma:** nohup /root/tools-bank/bin/goused-{proxy,api,telsiz,watchdog} > /tmp/goused-{}.log 2>&1 &
- **Watchdog Davranışı:** Sadece restart'larda log yazar (sessiz = sağlıklı)

### 4.14 Hayvan Kartında Görev Filtresi
- **Tarih:** 2026-05-20
- **Değişiklik:** openDet (hayvan kartı) görev listesinde iptal edilmiş PADOK_DEGISIM görevleri filtrelenerek başlandı
- **Kod:** ui.js:893,895'e !t.iptal eklendi
- **Not:** 18 Mayıs'ta loadDash/loadTasks düzeltilmişti ama openDet unutulmuştu

### 4.15 Jina API Fix
- **Tarih:** 2026-05-20
- **Sorun:** User-Agent curl/8.5.0 Cloudflare 403 hatası veriyordu
- **Çözüm:** Mozilla/5.0 olarak değiştirildi
- **İlave:** rebuild_missing() eklendi
- **Davranış:** semantic_search otomatik olarak arama anında eksik embeddingleri tamamlar (en fazla 5)

### 4.16 MCP Server Obsolete Altyapısı
- **Tarih:** 2026-05-20
- **Değişiklikler:** notes tablosuna obsolete + superseded_by kolonları eklendi
- **3 Yanlış Not:** 32, 36, 73 obsolete, superseded_by=93
- **Filtre:** _fts_search/_local_vec_search/memory_add'e AND obsolete=0 filtresi
- **User-Agent Fix:** curl/8.5.0 → Mozilla/5.0

### 4.17 Deepseek TUI Context Hazırlığı
- **Tarih:** 2026-05-18
- **Problem:** Goose TUI interaktif modda mimari kuralları bilmiyordu
- **Çözüm — 4 Katmanlı Context Zinciri:**

**1. TOM (Her tur inject, en öncelikli):**
- Dosya: ~/.goose-persistent.md
- Aktif env: GOOSE_MOIM_MESSAGE_FILE=~/.goose-persistent.md (.zshrc)
- İçerik: EgeSüt kritik kurallar, SQL pre-check özeti, ID tipleri, approval gate, commit lock
- Not: .zshrc'de openclaw source hatası da düzeltildi ([ -f ... ] && source ile sarıldı)

**2. Skill (On-demand, 'load_skill("egesut-erp")'):**
- Konum: /root/.config/goose/skills/egesut-erp → symlink → /root/tools-bank/skills/egesut-erp/
- İçerik: Tam mimari kılavuz, pre-check adımları, ID haritası, stok math, referans dosyalar, approval gate
- Pattern: Diğer symlink'lerle aynı (kaz-cobani, mem-tools → tools-bank)

**3. AGENTS.md (Proje dizininde developer extension ile okunur):**
- Güncellendi: SQL pre-check adımları, ground_truth referansı, approval gate, deploy süreci, gorev_log id fix

**4. Recipes (Recipe kullanılırken yüklenir):**
- egesut.yaml + egesut-telsiz.yaml + goose-ops.yaml: tüm approval gate template'leri eklendi

**Test Sonucu (2026-05-18):** 5/5 doğru yanıt. Bonus: gorev_log.id=text (uuid değil) hatasını kendisi tespit etti.

### 4.18 Goose + DeepSeek Pipeline Konfigürasyonu
- **GOOSE_PROVIDER:** openai
- **GOOSE_MODEL:** deepseek-v4-flash
- **OPENAI_HOST:** http://localhost:8742 (proxy)
- **OPENAI_API_KEY:** DeepSeek key
- **start_pipeline.sh:** Proxy'yi daemon'dan önce başlatır, API key'i config.yaml'dan otomatik çeker
- **stop_pipeline.sh:** Proxy'yi de durdurur

### 4.19 Conductor Recipe Tamamlandı
- **Tarih:** 2026-05-18
- **Lokasyon:** tools-bank/recipes/conductor.yaml
- **Görevi:** Multi-step spec executor
- **Parametreler:** spec_path + agent_id
- **Akış:** Spec dosyasını state olarak kullanır (crash-safe)
- **Max Turns:** 200
- **Temperature:** 0.1

### 4.20 Kuru Dönem Bug Fix (Kapsamlı Post-Mortem)
- **Tarih:** 2026-05-18
- **Sorun:** 4 inek (002, 185, 149, 122) kuru döneme geçirildi ama sistem düzgün çalışmadı

**Semptomlar:**
1. 30 inek için yanlış PADOK_DEGISIM görevi açıldı (tüm sağmal inekler etkilendi)
2. Görev tamamlandığında padok değişmedi
3. Grup 'Sağmal (Kuru Dönem)'e geçmedi
4. Tamamlanan ve iptal edilen görevler dashboard ve görevler sekmesinde görünmeye devam etti

**Kök Nedenler:**
- **A)** laktasyon_kuru_kontrol RPC: Goose, 20260513000006_laktasyon_kuru_kontrol_revize.sql'i referans aldı. Bu dosya kırıktı — sadece grup filtresi vardı, 'dogum' tablosu JOIN'i yoktu, 210 gün kontrolü yoktu, gebe filtresi yoktu. Tüm sağmal inekler için görev açtı.
- **B)** gorev_tamamla RPC: Padok değişikliğinde sadece hayvanlar.padok güncelliyordu, hayvanlar.grup = 'Sağmal (Kuru Dönem)' set etmiyordu.
- **C)** UI iptal filtresi: loadDash ve loadTasks'ta t=>!t.tamamlandi vardı ama !t.iptal yoktu.

**Uygulanan Fixler:**
1. Migration 20260518000001: gorev_tamamla RPC güncellendi — PADOK_DEGISIM + aciklama ILIKE '%Kuru döneme%' ise grup = 'Sağmal (Kuru Dönem)' set eder
2. Migration 20260518000002 (hotfix): 30 yanlış görevi iptal etti, yanlış grup değişikliğini geri aldı (kupe_no NOT IN ('002','185','149','122'))
3. Migration 20260518000003: laktasyon_kuru_kontrol final — dogum JOIN + 210 gün HAVING + EXISTS(tohumlama.sonuc='Gebe')
4. js/ui.js: loadDash line 208 → !t.iptal eklendi; loadTasks line 351, 375 → !t.iptal eklendi
5. js/forms.js doneTask: pullTables(['hayvanlar']) eklendi — padok değişikliği IDB cache'e yansısın

**Alınan Ders:** Spec'e ara migration referans vermek YASAK. Her zaman ground_truth.sql referans alınacak. Goose SQL yazmadan önce approval gate sorması zorunlu hale getirildi.

**Şu AN DURUM:** 4 inek DB'de Kuru/Gebe Padok'ta, grup 'Sağmal (Kuru Dönem)'. UI'dan uçtan uca test (padok seç → tamamla → hayvan kartı günceli) henüz kullanıcı tarafından doğrulanmadı.

### 4.21 DeepSeek-v4-flash Uyumluluk (Thinking Mode)
- **Tarih:** 2026-05-17
- **Sorun:** deepseek-v4-flash thinking mode varsayılan açık gelir
- **API Hatası:** Thinking mode enabled ise API reasoning_content alanını geri ister, Goose bunu göndermez → 400 hatası
- **Çözüm:** /root/tools-bank/workers/deepseek_proxy.py proxy'si — her isteğe {\"thinking\":{\"type\":\"disabled\"}} ekler
- **Sonuç:** Goose normal OpenAI formatında çalışır

### 4.22 Goosed-Watchdog Tasarımı
- **Tarih:** 2026-05-17
- **Dosya:** cmd/goused-watchdog/main.go — tek dosya, stdlib only
- **Mekanizm:** Her 30 saniye proxy(:8742) + api(:8743) + telsiz(:8744) /health GET ping (5s timeout)
- **Restart:** 200 dışı veya hata → exec.Command(binPath).Start() ile non-blocking restart
- **Cooldown:** lastRestart map[string]time.Time, 10 saniye aynı binary'yi tekrar restart etme
- **Graceful Shutdown:** signal.NotifyContext, recover() her goroutine'de
- **Binary Yolu:** /root/tools-bank/bin/goused-{proxy,api,telsiz}

### 4.23 Multi-Tier Goose Agent Mimarisi
- **Tasarım Tarihi:** 2026-05-18
- **Struktur:**
  - **Tier 0:** Claude (1 instance, CEO, sadece üst kararlar + onay/ret)
  - **Tier 1:** Goose Orchestrator / goose-ops (max 2 eşzamanlı slot, COO rolü)
  - **Tier 2:** Goose Workers (her orchestrator max 3 worker = toplam 6)
- **Max Aktif:** 1 Claude + 2 Orchestrator + 6 Worker = 9 agent
- **Per-Task Spawn:** Her görev için fresh goose-ops instance — context sıfırlanır, crash izole olur. Bitince exit.

### 4.24 Goose Native Subagent Sistemi Keşfi
- **Tarih:** 2026-05-18
- **Öğrenilen:**
  - sub_agent: ayrı session tipi (scheduled/hidden/gateway/acp'den farklı)
  - subagent_created: notification tipi mevcut
  - [subagent:] tool call: tool graph'ta subagent bazında izleniyor
  - sub_recipes: recipe YAML'ında doğrudan subagent tanımlanabiliyor
  - summon extension: enabled=true, "Load knowledge and delegate tasks to subagents"
  - delegatesubagent + resuming builtin: subagent resumable
- **Kritik Test Gerekli:** summon ile spawn edilen subagent parent'ın MCP bağlantılarını paylaşıyor mu? Cevap mimariyi belirliyor.

### 4.25 API Gateway Keşfedilen Endpoint'ler
- **Tarih:** 2026-05-20
- **DeerFlow Gateway (localhost:8001):**
  - Thread listele: POST /api/threads/search {\"limit\": N}
  - Thread oluştur: POST /api/threads {}
  - Run/stream: POST /api/threads/{id}/runs/stream
  - Assistant listele: POST /api/assistants/search {}
  - Memory oku: GET /api/memory/status
  - Memory yaz: POST /api/memory/facts {\"content\":\"...\", \"category\":\"...\"}
  - Tüm routes: GET /openapi.json ile keşfedilebilir
- **CSRF:** Tüm POST'a zorunlu X-CSRF-Token header, session cookie'den alınır

---

## 5. Aktif Bug'lar ve Bekleyen Task'lar

### 5.1 Aktif Bug'lar Listesi

**Hepsi çözüldü (bugs.md'den):**
- BUG-001: rpcOptimistic yanlış çağrı — ✅ Çözüldü
- BUG-002: openNotModal duplikat — ✅ Çözüldü
- BUG-003: selDis duplikat — ✅ Çözüldü
- BUG-004: Direkt REST bypass (drug_products) — ✅ Çözüldü
- BUG-005: Direkt REST bypass (stok) — ✅ Çözüldü
- BUG-006: Direkt REST bypass (drugs) — ✅ Çözüldü
- BUG-007: Offline kuyruk gönderiminde direkt REST — ✅ Çözüldü
- BUG-009: tohSonuc() direkt REST PATCH — ✅ Çözüldü
- BUG-008: submitInsem sonrası UI refresh garantisiz — ✅ Çözüldü

### 5.2 Dev Task'ları

```
/root/egesut-erp1/.claude/tasks/dev/
├── task-026-gebelik-deneme-no.md
└── task-standardizasyon.md
```

### 5.3 ARGE Task'ları

(Listedeki task sayısı user özel, .claude/tasks/arge/ altında ekleyerek büyüyebilir)

---

## 6. Ertelenen Özellikler (DEFERRED_FEATURES.md)

### 6.1 Tamamlanmış Özellikler (Son 30 Gün)

#### Tohumlama Modülü RPC Refaktöring — %70 Tamamlandı
- ✅ tohumlama_kaydet RPC — Event stack + islem_log + geri al desteği (migration 030)
- ✅ tohumlama_sonuc_gebe RPC — Yeni kayıt (migration 030)
- ✅ tohSonucGuncelle kaldırıldı — Korumasız write path temizlendi
- ✅ tohSonuc tek versiyon — ui.js'deki çakışan fonksiyon silindi
- ✅ Geri al butonu — ref_id fix (migration 028)
- ✅ Tohumlama modal durum bazlı buton kontrolü
- ✅ Input validation — İleri tarih engeli (forms.js:40,113,155)

**Kalan İşler:**
- ✅ ~~tohumlama_sonuc_bos RPC~~ — DONE (2026-05-23) tohSonuc() full RPC'ye çevrildi
- ✅ ~~tohSonuc UI refresh~~ — DONE (2026-05-23) renderFromLocal + hayvan kartı openDet keepTab
- ✅ ~~XSS escaping~~ — DONE (2026-05-23) 9 innerHTML noktası esc() ile kapatıldı
- ✅ ~~Dead code~~ — DONE (2026-05-23) gebeIsaretle, insertOffline, updateOffline silindi
- ✅ ~~renderFromLocal await eksikleri~~ — DONE (2026-05-23) ureme/bildirim/raporlar await eklendi
- 🔴 tohumlama_abort RPC — Gebe → Abort için

#### SonarCloud Remediation — S2 & S3 Tamamlandı
- ✅ S1 — Gerçek Bug'lar (10 issue) — f8874a0
- ✅ S2 — BLOCKER Globals (28 issue) — 14cda49
- ✅ S3 — Mantık Tutarsızlıkları (~35 issue) — b572e26
- ✅ S4 — Cognitive Complexity + Nested Ternary (~75 issue) — 0f2f0e2
- ✅ S5 — Minor Modernizasyon (Bulk, ~100 issue) — 55e8212

**Kalan:**
- 🟡 WONTFIX katalog (~188 issue) — SonarCloud UI'da manuel işaretleme gerekli
  - Label accessibility (S6853): 64 issue
  - Non-native element (S6848): 24 issue
  - Mouse event (S7726): 24 issue
  - SQL literal duplication: 72 issue
  - Diğer: 4 issue

### 6.2 Yüksek Öncelikli (Gelecek Sprint)

#### LOGIC-003: Offline Modda Tedavi Günleri Görünmüyor
- **Sorun:** Offline modda eklenen tedavi günleri ve ilaç uygulamaları, online moda geçilene kadar UI'da görünmüyor
- **Kök Sebep:** renderCaseTimeline() fonksiyonu tedavi ve drug_administrations tablolarını IndexedDB'den okuyor, ancak offline modda write() ile eklenen kayıtlar timeline render'ından önce cache'e yansımıyor
- **Çözüm:** caseDrugKaydet() fonksiyonunda offline modda local cache oluştur, renderCaseTimeline() cache + DB merge refactor et
- **Tahmini:** 4-6 saat
- **Risk:** Orta

#### UI-003: Hayvan Listeleme — Input Odaklı Arama
- **Durum:** Kısmen çalışıyor
- **Açıklama:** Kızgınlık ve Doğum modallarında spesifik hayvan listesi çalışıyor (tohumlanabilir / anne adayları), Tohumlama ve Hastalık modallarında tüm hayvanlar listeleniyor
- **Öneri:** Tohumlama modalı: tohumlanabilir_hayvanlar view'ını kullan; Hastalık modalı: Aktif dişi hayvanları filtrele
- **Öncelik:** Düşük

### 6.3 Düşük Öncelikli İyileştirmeler

#### PERF-001: Hayvan Arama — Otomatik Tamamlama
- **Sorun:** Kullanıcılar hala rakam tuşlamak zorunda
- **Risk:** Çok fazla hayvan varsa dropdown performansı düşebilir

---

## 7. Proje Durumu Özeti (PROJE_DURUMU.md)

### 7.1 Teknik Stack

- **Frontend:** Vanilla JS, tek HTML dosyası (index.html)
- **Backend:** Supabase (PostgreSQL + REST API)
- **Geliştirme:** Node.js + supabase CLI
- **Offline:** IndexedDB + sync queue
- **Deploy:** GitHub Pages (otomatik, her push'ta)
- **DB Migration:** GitHub Actions → Supabase CLI

### 7.2 Proje Dosya Ağacı

```
/root/egesut-erp1/
├── index.html              (Tüm frontend kodunu içeren tek dosya)
├── package.json            (supabase CLI gibi geliştirme bağımlılıkları)
├── package-lock.json
├── supabase/               (DB migration dosyaları)
├── PROJE_DURUMU.md         (Bu dosya)
├── DEFERRED_FEATURES.md    (Ertelenen özellikler)
├── ReFactorRoadmap.md      (Refactor planı)
└── .claude/                (Referans + prompt dosyaları)
    ├── domain-rules.md
    ├── rpc-reference.md
    ├── knowledge/
    │   └── bugs.md
    └── tasks/
```

### 7.3 Supabase Bilgileri

- **Project ID:** zqnexqbdfvbhlxzelzju
- **URL:** https://zqnexqbdfvbhlxzelzju.supabase.co
- **API Key:** index.html içinde SB_KEY değişkeninde

### 7.4 Tamamlanan Özellikler (Özet)

- ✅ Offline-first IndexedDB sync
- ✅ Doğum kaydı → otomatik buzağı oluştur
- ✅ Doğum kaydı → Gebelerden Seç (280 gün hesabı)
- ✅ Tohumlama → otomatik 21/35 gün kontrol görevleri
- ✅ Stok yönetimi + kritik eşik uyarısı
- ✅ Data Traffic paneli (başarısız kayıt takibi)
- ✅ Hayvan fiziksel özellikler (boy, kilo, renk)
- ✅ GitHub Actions → Supabase otomatik migration
- ✅ Null field filtering (schema cache hataları çözüldü)
- ✅ Tohumlama Event Stack (Bekliyor→Boş otomatik)
- ✅ tohumlama_sonuc_gebe RPC
- ✅ tohumlama_kaydet RPC (islem_log + geri al desteği)
- ✅ SonarCloud S2–S5 fixleri (~250 issue)

### 7.5 Devam Eden / Yarım Kalan İşler

1. **~~🔴 Tohumlama — Kalan Write Path Refaktöring (KRİTİK)~~** ✅ DONE (2026-05-23): tohSonuc() full RPC, UI refresh, XSS fix, dead code temizliği, hayvan kartı tab korunması. Kalan: tohumlama_abort RPC

2. **🟠 LOGIC-003: Offline Klinik Cache Merge:** Offline modda eklenen ilaçlar UI'da görünmüyor. Yapılacak: renderCaseTimeline() cache + DB merge etsin.

3. **🟡 Prompt 4 — Raporlama Modülü:** Alt navda yeni RAPOR sekmesi, gebe oranı / doğum / hastalık / ilaç tüketimi kartları.

4. **🟢 Prompt 6 — Push Notifications:** Görev gecikince / stok kritikse / doğum yaklaşınca browser notification, 30 dakikada bir kontrol.

---

## 8. Refactor Roadmap (ReFactorRoadmap.md)

### 8.1 Aşama 1 — Altyapı ve Kod Organizasyonu (Durumu: %70 Kısmen Tamamlandı)

| Alt Aşama | Durum | Açıklama |
|---|---|---|
| 1.1 Global State | ⚠️ Kısmen | state.js/AppState var, ama 13 global hala app.js:81'de. **RİSKLİ → BEKLİYOR** |
| 1.2 Sabitler → config.js | ✅ Bitti | Tüm sabitler config.js'te, hiç tekrar tanım yok |
| 1.3 Yardımcılar → utils/ | ✅ DONE | helpers.js + modal.js oluşturuldu, app.js temizlendi |
| 1.4 Autocomplete tekilleştirme | ⚠️ Kısmen | setupAutocomplete() helpers.js'e eklendi. Dönüşüm **BEKLİYOR** |

### 8.2 Aşama 2 — Veri Yönetimi (Durumu: ✅ DONE)

- ✅ write() fonksiyonunun bölünmesi
- ✅ Senkronizasyon motorunun güçlendirilmesi
- ✅ IndexedDB Sorgularının Optimizasyonu
- ✅ RPC Optimistic Update

### 8.3 Aşama 3 — UI ve Render (Durumu: ⏸️ RİSKLİ → BEKLİYOR)

- ⏸️ Render motorunun hafifletilmesi
- ⏸️ Olay yönetiminin merkezileştirilmesi (event delegation ~150 handler)
- ⏸️ Modal bileşenlerinin sınıflara dönüştürülmesi
- ⏸️ Toast bildirim sisteminin geliştirilmesi

### 8.4 Aşama 4 — Hata Yönetimi (Durumu: ✅ DONE)

- ✅ Merkezi hata yakalama
- ✅ Kullanıcı dostu hata mesajları
- ✅ Debug modu

### 8.5 Aşama 5 — Migration Yönetimi (Durumu: ✅ DONE)

- ✅ Eksik migration'ların tamamlanması
- ✅ Ground truth migration'ı
- ✅ Migration'ların idempotent hale getirilmesi

### 8.6 Aşama 6 — Güvenlik (Durumu: ⏸️ Test Gerekli)

- ⏸️ Kullanıcı girdilerinin temizlenmesi
- ✅ RLS ve API anahtarı güvenliği

### 8.7 Aşama 7 — Performans (Durumu: ✅ DONE)

- ✅ Debounce ve throttle kullanımı
- ✅ Gereksiz render'ların önlenmesi

### 8.8 Aşama 8 — Test Edilebilirlik (Durumu: ✅ DONE)

- ✅ ESLint ve Prettier kurulumu
- ✅ JSDoc yorumları
- ⏸️ Unit test altyapısı (uzun vadeli)

### 8.9 Aşama 9 — Dokümantasyon (Durumu: ✅ DONE)

- ✅ README.md güncellemesi
- ✅ Yeni geliştiriciler için kılavuz

---

## 9. Tools-Bank Memory İstatistikleri

- **Toplam Not:** 133
- **Embedding Model:** Jina jina-embeddings-v5-text-small (1024-dim)

**Kategori Dağılımı:**
- code_change: 57
- critical_rules: 28
- tech_stack: 24
- rpc_reference: 11
- general: 6
- domain_rules: 6
- project: 1

---

## Sonuç

Bu döküm, EgeSüt ERP projesinin **tüm iş kurallarını**, **sistem mimarisini**, **hata geçmişini** ve **ilerleme durumunu** kapsamlı olarak belgeler.

**Temel Bilgiler:**
- Frontend asla iş mantığı yapmaz — tüm yazma RPC üzerinden yapılır
- Canonical referans: ground_truth.sql + rpc-reference.md + domain-rules.md
- Approval gate zorunlu: SQL yazma öncesi orchestrator onayı
- Commit lock gerekli: 3+ worker'ı git race condition'dan koru
- Tools-bank memory: 133 not, kritik kurallar + kod geçmişi + RPC imzaları

**Öncelikli Açık Konular:**
1. tohumlama_sonuc_bos RPC + tohSonuc() REST→RPC geçişi
2. Offline tedavi günleri cache merge
3. Goose native subagent MCP sharing test
4. islem_geri_al fonksiyonunun doğru çalışması doğrulama

Tüm yeni geliştirme bu dökümdeki kurallarına ve referanslara uymalıdır.
