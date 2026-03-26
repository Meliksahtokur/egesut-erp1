# Agent Feedback Format

Her agent, görev bitiminde bu dosyayı değil kendi feedback dosyasını günceller:
`.claude/feedback/[agent-adı].md`

## Format

```markdown
## [YYYY-MM-DD] [görev-özeti-2-3-kelime]
- Sorun: [tekrar eden engel veya eksiklik]
- Öneri: [şöyle olsa daha iyi çalışırdım]
- İstek: [ihtiyaç duyduğum araç / yetki / bilgi]
```

## Kurallar

- Sadece **gerçekten yaşadıklarını** yaz — kurgu değil
- Sıradan, sorunsuz görevler için feedback gerekmez
- Bir görevde birden fazla madde olabilir
- Orkestratör bu dosyaları periyodik olarak okur ve sana raporlar

## Örnek

```markdown
## [2026-03-26] forms-duplicate-fix
- Sorun: forms.js'de aynı validasyon pattern'i 3 ayrı yerde — her seferinde grep ile bulmak zaman alıyor
- Öneri: Ortak bir `validateField(field, rules)` utility olsa daha hızlı çalışırdım
- İstek: ui-map.md'ye forms.js bölüm haritası da eklense
```
