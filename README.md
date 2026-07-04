# EgeSüt ERP

130+ hayvanlık süt çiftliği için offline-first web tabanlı yönetim sistemi.

**Live:** https://meliksahtokur.github.io/egesut-erp1/
**Backend:** Supabase (PostgreSQL)
**Repo:** github.com/Meliksahtokur/egesut-erp1

---

## Teknik Stack

| Katman | Teknoloji |
|--------|-----------|
| Frontend | Vanilla JS, tek `index.html`, framework yok |
| Backend | Supabase (PostgreSQL + RPC) |
| Offline Cache | IndexedDB (`egesut_v9`) |
| Deploy | GitHub Pages (her push otomatik) |
| DB Migration | GitHub Actions → Supabase CLI |

---

## Modüller ve Durum

| Modül | Durum | Açıklama |
|-------|-------|----------|
| **Sürü** | ✅ Tamamlandı | Hayvan kartı, grup/padok, 🐣 Doğurdu chip (#66), kızgınlık bar, search+filter |
| **Görev** | ✅ Tamamlandı | Otomatik üretim, cascade/orphan zincir-guard, hayvan çıkışında iptal, ertelenmiş commit |
| **Stok** | ✅ Tamamlandı | İlaç katalog + ledger (immutable), kritik eşik, atomik RPC |
| **Üreme** | ✅ Tamamlandı | Tohumlama → gebelik → doğum, per-cycle state machine, genç anne, polish devam ediyor |
| **Klinik / Vaka** | ✅ Tamamlandı | Tedavi seans (BUG-059) + şablon, Klinisyen Monitörü (Faz 5), undo, atomik RPC'ler |
| **Aşı** | ✅ Tamamlandı | İçerik-odaklı yönetim (vaccines + hastalıklar + protocol_steps), primer/muadil, çoklu uygulama |
| **İstatistik** | ✅ Tamamlandı | stat_suru_ozet + v_ureme_dongusu, üreme verimliliği (Düve/İnek ×3), sperma/PI |
| **AI Asistan** | ✅ Tamamlandı | Supabase Edge Function + MiniMax, agent loop, plan+undo (Faz 0–2.6), salt-okuma SQL + HITL yazma |
| **Demo-Mirror** | ✅ Tamamlandı | postgres_fdw → demo atomik klon (D0–D4), günlük backup, demo login → canlı klon |

---

## Mimari Prensipler

- **İş mantığı DB'de** — frontend sadece render ve input toplar, **hesap yapmaz, state machine işletmez, validasyon yapmaz**. Frontend ERP'de güvenilmezdir (DevTools override, çoklu cihaz versiyon farkı, offline güncellik sorunu). Tüm iş mantığı PostgreSQL'de (RPC + trigger + view).
- **Sadece RPC ile yaz** — direkt REST INSERT/UPDATE/DELETE yasak; tüm yazma işlemleri Supabase RPC üzerinden geçer. `write()` fonksiyonu geçici offline queue çözümüdür, yeni kodda RPC tercih edilir.
- **Controlled entities** — hastalık, ilaç, hayvan asla free-text; FK + dropdown zorunlu
- **Stok ledger immutable** — `stok_hareket` asla silinmez; düzeltme yeni kayıt olarak girilir
- **Offline-first** — tüm okumalar IndexedDB'den, yazma Supabase'e kuyruğa alınır
- **Migration idempotent** — her migration `DROP IF EXISTS + CREATE OR REPLACE` ile yazılır

---

## Kaynak Dosyalar

```
index.html                    — HTML + CSS + tüm modaller (2246 satır)
js/
  config.js                   — GRUP_PADOK + sabitler (129 satır)
  state.js                    — AppState (92 satır)
  api.js                      — Supabase client, IDB sync, RPC wrapper (606 satır)
  app.js                      — Uygulama init + routing (719 satır)
  ui.js                       — Tüm render (8210 satır)
  forms.js                    — Form submit + validasyon (1898 satır)
  auth.js                     — Login gate, kayıt, şifre sıfırlama (267 satır)
  ai-asistan.js               — AI Asistan frontend (385 satır)
  demo.js                     — Demo-Mirror UI (87 satır)
  utils/
    helpers.js                — DOM, toast, autocomplete, debounce (103 satır)
    modal.js                  — openM/closeM/mClose (74 satır)
    errorHandler.js           — withErrorHandling (54 satır)
    handlers.js               — Global event handler'lar (354 satır)
    events.js                 — Event emitter (49 satır)
supabase/migrations/             — 214 migration dosyası (PostgreSQL)
scripts/                       — LSP, ground-truth-audit, sql-lsp daemon, vb.
lsp.json                       — OMP için SQL LSP kaydı (lsp-proxy)
plugins/                       — OMP/Claude Code için LSP plugin manifestleri (sql-lsp, ts-lsp)
```

## Veritabanı Özeti

**50 public base tablo** (canlı, 2026-07-04 LSP teyitli — ground_truth 41 + bugünden eklenenler; psql view ile 64 görünür çünkü extension nesneleri ve view'lar dahil).

```
hayvanlar (çekirdek)
  ├── tohumlama          — üreme olayları (per-cycle state machine)
  ├── dogum              — doğum kayıtları
  ├── kizginlik_log      — kızgınlık takibi (tedavi-silme entegre)
  ├── gorev_log          — görev sistemi (id text+uuid; cascade/orphan guard)
  └── cases              — klinik vakalar
        ├── treatment_days → drug_administrations → drugs → stok
        ├── tedavi_sablon_*, tedavi_sablon_uygulama — şablon motoru (#63)
        └── tedavi (legacy) — BUG-XXX-TEDAVI-ORPHAN temizlendi

stok
  └── stok_hareket       — ledger (immutable)

vaccines + vaccine_diseases + protocol_steps  — aşı yönetimi (içerik-odaklı)
agent_threads + agent_messages + agent_plans — AI Asistan hafıza + plan motoru
prod_fdw                                     — Demo-Mirror FDW köprüsü (postgres_fdw → demo atomik klon)
diseases / drugs                             — controlled listeler
```

Canlı DB şeması: [`db_schema_snapshot.md`](db_schema_snapshot.md)
Mimari kararlar: [`ARCHITECTURE.md`](ARCHITECTURE.md)
`ground_truth` referans: [`supabase/migrations/99999999999999_ground_truth.sql`](supabase/migrations/99999999999999_ground_truth.sql) (canlıyla regen tamamlandı 2026-06-25)

---

## Aktif Teknik Borç

| Sorun | Önem |
|-------|------|
| ui.js monolitik (8210 satır) — Aşama 3 event delegation + render motoru | 🟠 Orta |
| **BUG-XXX Modal Router** (6c4cfbe kısmi) — 2 alt bug stabil değil | 🟡 Yüksek |
| Tools-bank arama edge case'leri (TB-001/002/003): kod araması try/except yutuyor, semantic RPC ~10s JWT gecikmesi, Cloudflare bge-m3 intermittent degrade | 🟠 Orta |
| ground_truth kalıntıları (GT-B2): bazı fn header + $$/quote bozuk; workflow bozmuyor, LSP canlıdan beslenir | 🟢 Düşük |
| ReFactorRoadmap kalan — 1.1 (13 global app.js:81), 1.4 (acHayvan/acDisease), 3.x (render motoru + event delegation), 6.x (XSS `esc()` test gerekli) | 🟠 Orta |
| Multi-tenant retrofit (Faz 2) — `farm_id` ileri-disiplin aktif (YENİ nesneler), mevcut 41 tablo henüz retrofit edilmedi (kaynak: `.claude/farm-id-discipline.md`) | 🟡 Yüksek |

**Düzeltilen (2026-05-16 → 2026-07-04):**
- ✅ BUG-059 Tedavi seans → görev UI + Klinisyen Monitörü (Faz 5, 4c732a6)
- ✅ Tedavi şablon motoru (#63, 8086256 + 49f62bc + 636bd5f)
- ✅ ground_truth regen (a2e6d00) → `99999999999999_ground_truth.sql` canlıyla birebir
- ✅ Auth gate + anon kilidi (b3e777e, e0fd1e6)
- ✅ Sütten-kesme atomik RPC + UI + undo (54e95dd, a20ee28, f503537)
- ✅ BUG-064 hizli_uygulama 6-param imza + islem_log audit (4be01af)
- ✅ Detay-modal kupe no: DOM onclick → HTML attribute (684534f, modal router uyumu)
- ✅ Tedavi orphan cleanup (a4a5336)
- ✅ Aşı içerik-odaklı yönetim — vaccines + hastalıklar + protocol_steps M:N (3f90565, 8b48f82)
- ✅ Üreme per-cycle state machine + genç anne hibrit kategori (dc7581c, fb62104, 4cb146f)
- ✅ Kızgınlık ↔ tedavi çift yönlü entegrasyon + belirsiz liste (edf84a2, 14b35a7)
- ✅ GitNexus code intelligence + LSP precheck + DB blast radius (1499d42, 7cf732b, 64d217f)

## Geliştirme Notları

```bash
# Bağımlılıkları kur (geliştirme/test bağımlılıkları; runtime vanilla JS)
npm install

# Supabase CLI ile migration uygula (GitHub Actions otomatik çalıştırır)
npx supabase db push

# JS syntax kontrolü
node --check js/ui.js
node --check js/forms.js

# Değişiklik öncesi ZORUNLU precheck:
#   SQL/RPC: bash scripts/refresh_lsp_schema.sh && postgrestools check <sql>
#   JS:     mcp__gitnexus_impact({target: "<symbol>", direction: "upstream"})
# (skill: .claude/skills/code-change-precheck)
```
