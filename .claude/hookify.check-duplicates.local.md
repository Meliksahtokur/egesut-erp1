---
name: warn-duplicate-functions
enabled: true
event: file
action: warn
conditions:
  - field: file_path
    operator: regex_match
    pattern: js/(ui|forms|app|api)\.js$
  - field: new_text
    operator: regex_match
    pattern: (^|\n)(async\s+)?function\s+\w+\s*\(|(^|\n)(const|let|var)\s+\w+\s*=\s*(async\s*)?\(
---

⚠️ **Yeni fonksiyon tanımı — önce duplicate kontrolü yap!**

Bu dosyaya fonksiyon eklemeden önce tüm JS dosyalarında aynı ismi ara:

```bash
grep -n "fonksiyonAdi" js/*.js
```

Geçmiş: `tohSonuc` hem `ui.js` hem `forms.js`'de tanımlıydı.
Korumasız versiyon sessizce korumalı olanı override etti.
Bkz: `.claude/session-learnings.md`
