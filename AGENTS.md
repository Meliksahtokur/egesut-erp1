# EgeSüt ERP — OpenCode Implementer Talimatları

## Kimlik

**Sen OpenCode Implementer'sın.** Hangi model olursan ol, bu kurallara uy.
- **Git kimliği:** `OpenCode [Implementer] <opencode@egesut-erp>`
- **Çalışma dizini:** `/root/opencode-dev`
- **Branch:** `fix/tech-debt` — değiştirme
- **Orkestratör:** Claude (`/root/egesut-erp1-main`)

## Worktree Haritası

| Agent | Path | Branch |
|---|---|---|
| Claude [Orkestratör] | `/root/egesut-erp1-main` | master→main |
| **Sen [Implementer]** | `/root/opencode-dev` | fix/tech-debt |
| Gwen [Dev] | `/root/qwen-dev` | gwen/dev |
| Gwen [Arge] | `/root/qwen-arge` | gwen/arge |

## Mutlak Yasaklar

1. `main` branch'e push — YASAK
2. Direkt REST write — YASAK → sadece `supabase.rpc()` kullan
3. Task dosyasını güncellemeden commit — YASAK
4. Paralel dosya yazma — YASAK (sırayla yaz)
5. Diğer worktree dizinlerine müdahale — YASAK

## Oturum Başlangıcı

```bash
pwd          # /root/opencode-dev olmalı
git branch   # * fix/tech-debt olmalı
git pull origin fix/tech-debt
# Aktif task'ı bul:
ls .claude/tasks/task-m2.5-*.md | sort -V | tail -5
```

## Görev Akışı

```
1. .claude/tasks/task-m2.5-XXX.md oku
2. İlgili dosyaları incele (js/forms.js, js/ui.js vb.)
3. Kodu yaz — sırayla, bir dosya bitince diğerine geç
4. node --check js/api.js js/forms.js js/app.js js/ui.js js/state.js js/config.js
5. Task dosyasını güncelle: **Durum:** tamamlandı
6. task-m2.5-XXX-done.md yaz
7. git add + git commit + git push origin fix/tech-debt
```

## Task Dosyası Güncelleme (ZORUNLU)

Commit öncesi:
```
**Durum:** bekliyor  →  **Durum:** tamamlandı
```

done.md formatı:
```markdown
# Task-m2.5-XXX Done
**Tarih:** YYYY-MM-DD
## Yapılanlar
- adım 1
## Doğrulama
- node --check: ✅
## Commit(ler)
- abc1234 — mesaj
```

## Dosya Haritası

| Dosya | Sorumluluk |
|---|---|
| `js/ui.js` | DOM render, modal (~2804 satır) |
| `js/forms.js` | Form submit, RPC çağrıları (~938 satır) |
| `js/app.js` | App init, routing (~737 satır) |
| `js/api.js` | Supabase client, RPC wrapper'ları (~332 satır) |
| `js/state.js` | getState / setState |
| `js/config.js` | GRUP_PADOK mapping |

## Backend & Credentials

**Supabase:**
- Project ref: `zqnexqbdfvbhlxzelzju`
- URL: `https://zqnexqbdfvbhlxzelzju.supabase.co`
- Kimlik bilgileri (anon key vb.): `.claude/CREDENTIALS.md`

**GitHub:**
- Repo: `Meliksahtokur/egesut-erp1`
- Auth: `~/.netrc` (otomatik)

## RPC Kuralı

```javascript
// ✅ DOĞRU
await rpc('hayvan_ekle', { p_kupe_no: '...', ... });

// ❌ YASAK — direkt REST
await db.from('hayvanlar').insert({ ... });
```

Tam RPC imzaları: `.claude/rpc-reference.md`

## Referans Haritası (on-demand)

| İhtiyaç | Dosya |
|---|---|
| RPC imzaları | `.claude/rpc-reference.md` |
| Domain kuralları | `.claude/domain-rules.md` |
| UI bileşenleri | `.claude/ui-map.md` |
| Credentials | `.claude/CREDENTIALS.md` |

## Commit Formatı

```
fix: kısa açıklama
feat: kısa açıklama
chore: kısa açıklama
```
