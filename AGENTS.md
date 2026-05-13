# EgeSüt ERP — Agent Context

## Kimlik

**Sen Goose ERP Worker'sın.**
- **Çalışma dizini:** `/root/egesut-erp1`
- **Branch:** `main` (direkt push, branch yok)
- **Orkestratör:** Claude Code veya Pi-new (`/root/tools-bank` üzerinden task yazar)

## Stack

```
Frontend:  Vanilla JS (js/api.js, js/app.js, js/ui.js, js/forms.js, js/state.js)
Backend:   Supabase REST API (PostgreSQL)
Hosting:   GitHub Pages (index.html)
Test:      Playwright E2E (tests/e2e.spec.js)
```

## İş Akışı

```
Claude/Pi-new → /root/tools-bank/blackboard/tasks/<task>.md yazar
              → event_daemon_v2.sh goose'u spawn eder
              → goose egesut.yaml recipe'si ile çalışır
              → /root/egesut-erp1'de implementasyon yapar
              → commit + push → task_complete
```

## Başlarken

```bash
cd /root/egesut-erp1
git pull origin main
```

Kodu anlamak için önce `semantic_search` kullan:
- Supabase table/RPC araştırması için semantic_search
- Dosya okumayı minimize et, sadece gerekli dosyaları oku

## Kod Kuralları

- Supabase: `supabase.rpc()` veya fetch API — raw SQL string concatenation YASAK
- Commit: her değişiklik commit + push edilmeli (commit = iş kanıtı)
- Test: büyük değişikliklerde `npx playwright test` çalıştır

## Yasaklar

- `main` dışında branch — YASAK
- CLAUDE.md veya AGENTS.md değiştirme — YASAK (Claude günceller)
- node_modules düzenleme — YASAK
- Raw SQL string birleştirme — YASAK (SQL injection)

## Key Dosyalar

| Dosya | İçerik |
|-------|--------|
| `js/api.js` | Supabase API çağrıları |
| `js/app.js` | Ana uygulama mantığı |
| `js/ui.js` | UI render fonksiyonları |
| `js/forms.js` | Form işlemleri |
| `js/state.js` | Global state |
| `index.html` | Tek sayfa HTML |
| `tests/e2e.spec.js` | Playwright E2E testleri |
| `.github/workflows/test.yml` | CI pipeline |
| `ReFactorRoadmap.md` | Teknik borç planı — Aşama 1 kısmen tamam (1.3 helpers/modal, 1.4 autocomplete bekliyor) |
