⟦ss-sub model=sonnet effort=medium rol=ss-worker iş=ovsync-tren S2: tren başlığına gecikmiş öneki + amber yazı rengi⟧
sonuc: TAMAM
kabul SHA: 4214d2d
BOYUT: bütçe 15 · gerçek 4 (ekleme; +2 silinen) · bütçe içinde

Bulgu yok (brief uygulanabilir).

## Yapılan
- `ovsyncTrenIsEtiketi`: `gecikmis = enErken < bugünIso` bayrağı; metin başına `gecikmiş · ` (CONFIRMED test).
- `ovsyncTrenBaslikHtml`: gecikmişte `class="ovs-tren-is ovs-tren-gecikmis" style="color:var(--amber)"` (mevcut `--amber` token; yeni renk yok; zemin/şerit yok). Ritim dışı ibaresi ayrıca kalır.
- Yeni test (ovsync-tren.test.js, +16 satır): geçmiş=önekli+amber, bugün/ileri=değişmez, ritim dışı+geçmiş.
- CSS kuralı index.html'e eklenmedi (yazılabilir kapsam yalnız damga); bu yüzden inline `style` kullanıldı.

## Mutant (CONFIRMED)
- `gecikmis = true` → ovsync-tren.test.js 2 fail (pass 41).
- `gecikmis = false` → 1 fail (pass 42).
- Geri alındı; son durum yeşil.

## Run kanıtı
(Runner: `ram-ultracode exec --class test --wait 300 -- bash ~/tmp/s2run.sh <dosya>`; içi `NODE_PATH=~/egesut-erp1/node_modules node --test <dosya>`)
```
NODE_PATH=~/egesut-erp1/node_modules node --test tests/unit/ovsync-tren.test.js
rc: 0
ℹ pass 43
ℹ fail 0
```
```
NODE_PATH=~/egesut-erp1/node_modules node --test tests/unit/ovsync-tren-entegrasyon.test.js
rc: 0
ℹ pass 102
ℹ fail 0
```

## Görsel kanıt
PNG: ~/tmp/s2-gecikmis/s2-gecikmis.png (demo, Playwright, port 8143, salt-okuma). DOM: "Tren · Çar 4 Kas · … · ritim dışı · gecikmiş · Çar 4 Kas: başlangıç günü" ve "Per 29 Eki … gecikmiş · Per 5 Kas: PG günü"; computed color rgb(201,125,10)=--amber; "bugün: …" ve "Per 12 Kas: …" değişmedi.

## Kırıntılar
- decision: index.html `?v=` damgası ARTIRILMADI. Artırınca ovsync-tren-entegrasyon UB1 ve UB5 kırıldı (tüm ?v= + manifest tek adımda 20261110-1 şartı; testler yazılabilir listede değil). Tarayıcı önbelleği için damga + manifest + UB5 birlikte artırılmalı → SORU: damga adımını kim yapacak (UB5 testi + manifest dahil)? Demo sunucusunda sahip sert yenileme yapmalı.
- assumption: kod commit'i yalnız js + test (report ayrı, commit edilmedi).
