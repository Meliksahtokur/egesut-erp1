# S2-gecikmis — tren başlığında "gecikmiş" ibaresi
job_id: j-20261109T190140Z-ab778c

İlk iş: ~/.claude/skills/using-superpowers-obra/SKILL.md oku ve uygula (sahip kuralı; SUBAGENT-STOP bu kural için geçersiz).
Kod yazmadan önce: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/.harness/references/domain-rules.md (Ovsync bölümü) ve test-driven-development-obra.

## Plan maddesi
Sahip S2 = E (2026-11-09, birebir "3e"). Ovsync ekranındaki tren başlığının iş etiketi kısmı ("<gün>: <iş>", ör. "Çar 4 Kas: başlangıç günü") iş tarihi TR bugününden ÖNCE ise başına "gecikmiş · " eklenir ve bu iş etiketi yazı rengi amber olur (yalnız yazı rengi; zemin/şerit YOK — UI renk minimal kuralı). Bugün ya da ileri tarihli iş etiketi değişmez ("bugün: …" ve "Per 12 Kas: …" aynen).
Kod yeri: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/js/ovsync-tren.js (başlık üretimi ~:339-420, `_OVT_TREN_IS`, başlık yorum satırı :359). Mevcut amber/uyarı yazı rengi token'ı (css değişkeni) varsa onu kullan; yeni renk sabiti uydurma — yoksa report'ta SORU.

## Model
sonnet (ss-worker)

## Yazılabilir dosyalar
~/.herdr/worktrees/egesut-erp1/ovsync-tren/js/ovsync-tren.js
~/.herdr/worktrees/egesut-erp1/ovsync-tren/tests/unit/ovsync-tren.test.js
~/.herdr/worktrees/egesut-erp1/ovsync-tren/index.html
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/S2-gecikmis-report.md

index.html yalnız `js/ovsync-tren.js?v=` damgası artırımı için (tarayıcı önbelleği); başka satıra dokunma.

## Boyut bütçesi
Üretim kodu ≤15 satır değişiklik; test ≤40 satır.

## Önceden cevaplanmış kararlar
- Tanım: "gecikmiş" = iş etiketinin tarihi < TR (Europe/Istanbul) bugünü. Ritim dışı trenler de aynı kurala tabidir; "ritim dışı" ibaresi ayrıca kalır.
- Metin birebir: `gecikmiş · ` öneki (küçük harf, orta nokta, boşluklar).
- Renk: yalnız yazı rengi amber; satır/başlık zemini ve şerit eklenmez.
- RPC/SQL/veri değişikliği yok. Commit: yalnız yazılabilir dosyalar, `git add` dosya dosya, mesaj sonu `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Push/merge YOK.
- Sahip şu an demoda (http://localhost:8139/?demo, bu worktree'den servis); demo DB'ye yazma yok.

## Run
NODE_PATH=~/egesut-erp1/node_modules node --test tests/unit/ovsync-tren.test.js
NODE_PATH=~/egesut-erp1/node_modules node --test tests/unit/ovsync-tren-entegrasyon.test.js

(cwd = ~/.herdr/worktrees/egesut-erp1/ovsync-tren; runner farklıysa package.json'dan doğrusunu bul, report'ta yaz.)
Testte: geçmiş tarih → önek + amber sınıfı/stil var; bugün ve ileri tarih → yok. Mutant: öneki koşulsuz yapınca ve koşulu kaldırınca test kırmızı olmalı (report'a yaz).

## Review: T0

## Görsel kanıt
Mümkünse demo ekranının bir PNG'si (Playwright; yardımcılar ~/tmp/dm2/wlib.cjs ve run.sh kalıbı, ayrı port, salt-okuma gezinme) — demoda geçmiş tarihli bir başlık (ör. "Çar 4 Kas") "gecikmiş ·" ile görünüyor mu. PNG'yi ~/tmp/s2-gecikmis/ altına koy, yolunu report'a yaz. Koşamazsan nedenini yaz; bu kanıt eksikliği TAMAM'ı engellemez ama report'ta açık yazılır.

## DONE
Report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/S2-gecikmis-report.md — `sonuc: TAMAM|KISMI|BLOKE`, `kabul SHA:`, `## Run kanıtı` (komut + rc + son ≤30 satır), mutant sonucu, PNG yolu.
