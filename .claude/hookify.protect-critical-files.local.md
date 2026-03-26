---
name: warn-critical-files
enabled: true
event: file
action: warn
conditions:
  - field: file_path
    operator: regex_match
    pattern: (sw\.js|manifest\.json|js/config\.js|js/state\.js|\.claude/domain-rules\.md)$
---

⚠️ **Kritik dosya değişikliği!**

Bu dosyanın blast radius'u büyük. Devam etmeden önce değişikliğin kasıtlı olduğunu doğrula:

- `sw.js` — Service worker; bozulursa tüm PWA offline çalışmaz
- `manifest.json` — PWA manifest; kurulu app'i etkiler
- `js/config.js` — GRUP_PADOK mapping ve domain sabitleri
- `js/state.js` — Global state; tüm modülleri etkiler
- `.claude/domain-rules.md` — İş kuralları referansı; doğruluğu kritik

Değişikliği yaptıktan sonra kapsamlı test et.
