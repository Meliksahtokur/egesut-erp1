# Task-arge-011: Operator Mimarisi Danışma + Tasarım

**Durum:** bekliyor
**Branch:** gwen/arge
**Tarih:** 2026-04-02
**Öncelik:** yüksek
**Tip:** araştırma + tasarım (kod yazmayacaksın — öneri üreteceksin)

---

## Bağlam

Şu an Gwen tek bir ana agent olarak çalışıyor. Her task'ı baştan sona tek başına yapıyor.

Claude ve kullanıcı şunu fark etti:
- Qwen Code session içinde birden fazla subagent otomatik spawn edilebiliyor
- Paralel okuma/analiz için 5-6 subagent aynı anda çalışabiliyor
- Bu kapasite şu an kullanılmıyor

**Hedef:** `gwen.md` → **operator** olsun. Her task için kendi ekibini kursun, işi dağıtsın, sonuçları derlesin.

---

## Senden İstenen

Sen Qwen CLI'ı ve agent sistemini Claude'dan daha iyi tanıyorsun.
**Kendi sistemini incele ve operator mimarisini tasarla.**

### Araştırma Soruları

1. **Qwen Code agent spawning nasıl çalışıyor?**
   - `agent` tool ile ne spawn edebilirsin?
   - Spawn edilen agent ile nasıl iletişim kurulur? (return value, shared state, tool calls?)
   - Parallel spawn mümkün mü? Nasıl?
   - Max kaç subagent aynı anda?

2. **Mevcut gwen.md'nin sınırları neler?**
   - Hangi task'larda tek agent yeterli, hangilerinde fazla yük biniyor?
   - Hangi adımlar paralelize edilebilir?

3. **Operator pattern nasıl uygulanabilir?**
   - Qwen Code'da "worker agent" tanımı nasıl yapılır?
   - gwen.md operator olursa hangi subagent'lara ihtiyaç var?
   - Önerilen roller: araştırmacı, analist, kodlayıcı?
   - Bu roller gwen-reviewer, gwen-architect ile nasıl ilişkilenir?

### Kısıtlar

- **MCP ekleme YASAK** — bash/grep/native tool yeterli
- **Yeni agent tanımı YAZMAYACAKSIN** — sadece tasarım önerisi
- **Kod yazmayacaksın** — sadece analiz ve öneri belgesi yaz
- Tasarım sonunda Claude onaylarsa task-arge-012 oluşturulacak (implementasyon)

---

## Çıktı

`.claude/tasks/arge/task-arge-011-done.md` içinde:

```markdown
# Operator Mimarisi Tasarımı

## Qwen Code Agent Spawning — Nasıl Çalışıyor
[Gözlemler, kısıtlar, yetenekler]

## Mevcut gwen.md Analizi
[Hangi adımlar yavaş, hangileri paralelize edilebilir]

## Önerilen Operator Mimarisi
[Diagram veya tablo — hangi agent ne yapıyor]

## Subagent Rolleri
[Her rol için: isim, sorumluluk, giriş/çıkış]

## Implementasyon Önerisi
[task-arge-012 için ne yazılacak — öncelik sırası]

## Riskler / Dikkat Edilecekler
[Coordination overhead, loop riski, context sınırı vb.]
```

---

## Kabul Kriterleri

- [ ] Qwen agent spawn mekanizması belgelendi
- [ ] gwen.md'nin mevcut sınırları analiz edildi
- [ ] En az 3 subagent rolü tanımlandı
- [ ] Operator workflow diyagramı (ASCII veya tablo) var
- [ ] task-arge-011-done.md yazıldı, push edildi
