# Bug Sinyalleri

Bu dosya erp-debug-agent ve arge-analyst tarafından doldurulur.
Orkestratör oturum açılışında bu dosyayı okur ve briefing'e dahil eder.

## Format

```markdown
## [YYYY-MM-DD] [BUG-ID] [başlık]
- Kaynak: [arge-analyst | erp-debug-agent | kullanıcı | supabase-log]
- Modül: [ui.js | forms.js | app.js | api.js | supabase | bilinmiyor]
- Önem: [kritik | yüksek | orta | düşük]
- Durum: [yeni | inceleniyor | çözüldü]
- Açıklama: [ne olduğu]
- Tetikleyici: [nasıl oluşuyor]
- İlgili commit: [hash veya "bilinmiyor"]
```

<!-- Buraya bug sinyalleri ekle -->
