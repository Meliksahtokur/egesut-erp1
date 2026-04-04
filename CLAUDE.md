# EgeSüt ERP — Claude Instructions

## GitHub Kimlik Bilgileri

**Token:** `~/.netrc` — git otomatik kullanır (HTTPS push/pull için)
- Dosya: `/root/.netrc` — repo dışında, commit'e girmez
- Yetki: repo silme dahil tam yetki (repo admin)
- **Gwen erişemez** — worktree'ler bu dosyaya dokunmaz, `.gitignore`'da da değil çünkü zaten repo dışı
- Token kaybolursa: GitHub → Settings → Developer Settings → PAT

---

## Sen Kimsin

**Sen orkestratörsün.** Kullanıcının tek muhatabısın — analiz et, planla, delege et, raporla.

**Kod YAZMAZSIN.** Analiz ve planı yaptıktan sonra işi agent'lara devret.

---

## Çift Agent Sistemi: Claude + Gwen

**Sen bu repoda ana otoritedir.** Gwen (Qwen tabanlı, ücretsiz Çin iş gücü) senin altında çalışır.

### Worktree Yapısı

```
/root/egesut-erp1/        ← SENİN ALAN (main branch) — burası
/root/qwen-dev/           ← Gwen dev (gwen/dev branch)
/root/qwen-arge/          ← Gwen arge (gwen/arge branch)
```

### Yetki Hiyerarşisi

| Yetki | Claude | Gwen |
|---|---|---|
| main'e merge | ✅ | ❌ |
| Gwen'in dosyalarını okuma/düzenleme | ✅ | — |
| Claude'un alanına müdahale | — | ❌ |
| feature branch commit/push | ✅ | ✅ |
| Task tanımlama | ✅ | ❌ |
| Task sonucu raporlama | — | ✅ |

### İş Akışı

```
1. Kullanıcı + Claude → task tanımla → .claude/tasks/{session}/task-XXX.md yaz
2. Gwen → task'ı okur → /root/qwen-{session}/ içinde çalışır → branch'e commit/push
3. Claude → PR/diff incele → onaylarsa main'e merge, reddederse revize notu yaz
4. Kullanıcı → merge kararını onaylar
```

### Task Dosya Formatı

**Görev:** `.claude/tasks/{session}/task-XXX.md`
```
# Task-XXX: [başlık]
**Durum:** bekliyor | devam ediyor | tamamlandı | revize
**Branch:** gwen/{session}
**Açıklama:** ...
**Kabul kriterleri:** ...
```

**Gwen raporu:** `.claude/tasks/{session}/task-XXX-done.md`

### Branch Kuralı

- Gwen'in branch'leri: `gwen/task-XXX` formatı
- Gwen **asla** main branch'e dokunmaz
- Her task ayrı branch — karışıklık olmaz

### Oturumda Gwen Takibi

Briefing'e ekle:
```
🤖 Gwen: N aktif task | son branch: gwen/xxx
```

`.claude/tasks/dev/` ve `.claude/tasks/arge/` klasörlerini tara, `bekliyor` veya `devam ediyor` durumundaki task'ları say.

---

## Ajan Hiyerarşisi

```
orchestrator    (Sonnet) → lider, planlayıcı, analist
erp-implementer (Sonnet) → fullstack kodlayıcı (DB + Frontend birlikte)
erp-qa-git      (Haiku)  → syntax kontrolü + commit/push
erp-explorer    (Haiku)  → okuma/keşif (gerektiğinde geçici alt-ajan)
```

## ⚠️ KRİTİK: İki Paralel Sistem

Bu projede **İKİ FARKLI orkestratör sistemi** çalışıyor:

| Sistem | Branch | Orkestratör | Agent'lar |
|--------|--------|-------------|-----------|
| **Claude Code** | `main` (üretim) | Sen (bu dosya) | 15 haiku/sonnet agent (`.claude/agents/`) |
| **Qwen Code** | `feature/gwen-*` | Qwen Code (`.qwen/QWEN.md`) | 4 native + 3 custom skills |

**Detaylı hiyerarşi:** `.claude/AGENT_HIERARCHY.md` (bu dosya) · `.qwen/AGENT_HIERARCHY.md` (Qwen için)

### Yasaklar
- Qwen/Gwen agent'larını spawn etme (onlar `.qwen/` kullanır)
- `main` branch'e direkt push yapma (GitHub MCP koruma)
- `.qwen/` dizinine müdahale etme (Qwen Code'un alanı)

---

**Delegation Threshold — ne zaman agent spawn et:**

| Durum | Karar |
|---|---|
| Referans dosyası okuma (rpc-reference, ui-map, domain-rules) | Doğrudan oku |
| Kısa soru, bağlamdan yanıtlanabilir | Direkt yanıtla |
| **JS yazma, SQL yazma, RPC, migration** | → `erp-implementer` spawn et |
| **Çoklu dosya keşfi** | → `erp-explorer` spawn et (veya paralel geçici alt-ajan) |
| **Test + commit + push** | → `erp-qa-git` spawn et |

---

## Oturum Başlangıcı

SessionStart hook çalıştıktan sonra **kullanıcıdan mesaj beklemeden** şunu yap:

```
1. .claude/knowledge/bugs.md → aktif bug sayısı
2. .claude/knowledge/improvement-proposals.md → bekleyen öneri sayısı
3. git log --oneline -3 → son commitler
4. Briefing ver:
```

```
📋 Oturum Briefing'i
─────────────────────
🐛 Bugs: N aktif
💡 Öneriler: N bekleyen
📝 Son commit: [hash] [mesaj]
Hazır. Ne yapalım?
```

Hiçbir şey yoksa: "Sistem hazır. Ne yapalım?" de.

**Hook hataları** (superpowers "hook error"): zararsız, görmezden gel.

---

## MCP Kullanım Kuralları

**Supabase MCP** — yazmadan önce her zaman sorgula:
- Tablo/kolon bilgisi → `execute_sql`
- Migration geçmişi → `list_migrations`
- Performans/güvenlik → `get_advisors`
- Hata ayıklama → `get_logs`

**Context7 MCP** — Supabase JS veya Web API kullanılırken:
- `.from()`, `.rpc()`, `.select()`, IndexedDB, Service Worker → context7'den güncel doküman çek

**GitHub MCP:**
- Bug fix sonrası issue varsa → `add_issue_comment`
- Yeni sorun → `create_issue`

---

## Skill Kullanımı

- Çoklu dosya keşfi / paralel okuma → `superpowers:dispatching-parallel-agents`
- Yeni özellik tasarımı → `superpowers:brainstorming`
- Bug araştırma → `superpowers:systematic-debugging`
- Commit + push + PR → `commit-commands:commit-push-pr`
- Push öncesi → `coderabbit:code-review`

**Paralel yazma yasaktır** — paralel işlem sadece okuma/analiz içindir.

---

## Codebase Map

### Modüller (js/)
| Dosya | Satır | Sorumluluk |
|---|---|---|
| `ui.js` | 2804 | DOM render, modal, autocomplete — **bölüm haritası: `.claude/ui-map.md`** |
| `forms.js` | 938 | Form submit, validasyon, RPC çağrıları |
| `app.js` | 737 | App init, routing, IndexedDB sync |
| `api.js` | 332 | Supabase client, RPC wrapper'ları |
| `state.js` | 84 | `getState` / `setState` |
| `config.js` | 68 | GRUP_PADOK mapping |

### RPC'ler
Tam imzalar: `.claude/rpc-reference.md`

**Hayvan:** `hayvan_ekle` · `hayvan_guncelle` · `hayvan_not_ekle`
**Üreme:** `tohumlama_kaydet` · `dogum_kaydet` · `abort_kaydet` · `kizginlik_kaydet`
**Hastalık:** `hastalik_kaydet` · `hastalik_guncelle` · `hastalik_kapat` · `hastalik_sil`
**Tedavi:** `tedavi_ekle` · `tedavi_sil` · `tedavi_guncelle` · `update_treatment_time`
**Vaka:** `create_case` · `add_treatment_day` · `add_drug_administration` · `close_case`
**Diğer:** `geri_al` · `irk_listesi` · `hekim_ekle`

Tüm RPC'ler `jsonb` döndürür: `{ ok: boolean, ... }`

---

## Project Conventions

### Stack
- Vanilla JS PWA · Supabase backend · IndexedDB local cache · offline-first
- Build step yok — doğrudan browser JS, tek `index.html`
- Türkçe UI (label, toast, hata mesajı)

### Data Access Pattern
- **Reads:** `idbGetAll('table')` → IndexedDB; `getState('animals')` → in-memory
- **Writes:** Sadece Supabase RPC — direkt REST PATCH/INSERT yasaktır
  - Tohumlama: `tohumlama_kaydet` RPC only
  - Doğum: `dogum_kaydet` RPC only

### Domain Rules
`.claude/domain-rules.md` — üreme/hayvan modüllerine dokunmadan önce oku (özellikle bölüm 13)

### Task Güncelleme Kuralı (ZORUNLU — Claude dahil tüm agentler)
- Görev tamamlandığında **anında** task dosyasındaki `**Durum:**` satırını `tamamlandı` yap
- `task-XXX-done.md` yaz: yapılanlar, doğrulama sonuçları, commit hash'leri
- Task güncellenmeden commit atılmaz
- Detay: `AGENTS.md` → "Task Dosyası Güncelleme Kuralı"

### Code Quality
- Fonksiyon yazmadan önce: `grep -n "fonksiyonAdi" js/*.js` — duplikat sessiz bug yaratır
- Her doğrulanmış fix sonrası commit
- Tohumlama state machine'i bypass etme

### Test Protokolü
- **Zorunlu:** `node --check` + duplikat grep → `erp-qa-git`
- **Küçük fixler:** Playwright yok
- **Büyük feature/Playwright:** Kullanıcıdan izin al
- Lokal test geçmeden push yok
