---
name: verify-before-done
enabled: true
event: stop
action: warn
conditions:
  - field: transcript
    operator: not_contains
    pattern: node --check|npx playwright|playwright test|SyntaxError
---

💡 **Bu oturumda syntax doğrulaması tespit edilmedi.**

Build step olmayan vanilla JS'de syntax hataları sadece runtime'da ortaya çıkar.
JS dosyası değiştirdiysen şunu çalıştır:

```bash
node --check js/<degistirilen-dosya>.js
```

UI değişikliği yaptıysan:
```bash
npx playwright test
```

Küçük değişiklik yaptıysan ya da sadece SQL/markdown düzenlediysen bu uyarıyı yok sayabilirsin.
