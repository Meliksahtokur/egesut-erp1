# L1 Luna Root Kapısı — Tek Global Tarih Seçici

**Tarih:** 2026-09-13
**Denetlenen dal:** `agent/tarih-secici-standardi`
**Denetlenen kapanış:** `46abbc8b6a130deb47d62c06eb6fe3d8fd6f5ecf`
**Taban:** `621f12a`
**Güncel main:** `0601e63f74bbf84b51ad1993d3043be13063450`

Bu rapor, lead luna incelemesini tekrarlamaz; hedef dalı detached checkout'ta
yeniden ölçer ve root sorularını cevaplar. Ürün koduna, DB'ye veya main'e yazım
yapılmadı.

## Gelen iş kapısı

**KABUL ET VE BAŞLA.** Zarf ve goal, ölçülebilir bir yeniden ölçüm seti veriyor.
Belge uyumsuzluğu olarak owner zarfındaki `reports/…` yolu ile goal/report'taki
`.harness/reports/…` yolu ve "all green" ile izin verilen `836/835/1` dili
kırıntıya yazıldı; root kapısı bu farkı doğrudan ölçümle çözdü.

## 1. DOĞRU — `type="date"` ve runtime istisnası

Komut:

```text
rg -n -F 'type="date"' index.html js
```

Çıktı eşleşme üretmedi; `rg` çıkışı `1`, sayım `0`.

Runtime istisnası taraması:

```text
rg -n -i -e "\.type\s*=\s*['\"]date['\"]" \
  -e "setAttribute\s*\(\s*['\"]type['\"]\s*,\s*['\"]date['\"]" \
  index.html js
```

```text
js/ui.js:6983:  el.type = 'date';
```

Ürün kaynaklarında literal `type="date"` yok; bilinçli gizli taşıyıcı ataması
tam olarak tek noktada ve `js/ui.js:6978-6983` çevresinde.

## 2. DOĞRU — unit suite ve main karşılaştırması

Önce istenen detached target checkout'ta çıplak komut çalıştırıldı:

```text
node --test tests/unit/*.test.js
target_exit=1
```

Bu ilk koşu ürün hatasıyla değil, detached worktree'de bağımlılık ağacı
bulunmadığı için 10 dosyada `MODULE_NOT_FOUND: fast-check` ile ölçülemedi.
Target worktree'de `node_modules` yoktu. Aynı repo bağımlılığının
`fast-check` `4.8.0` sürümü main checkout'ta mevcut olduğundan, ürün dosyalarını
değiştirmeden kontrollü tekrar:

```text
NODE_PATH=/home/melik/egesut-erp1/node_modules node --test tests/unit/*.test.js
target_nodepath_exit=1
ℹ tests 836
ℹ pass 835
ℹ fail 1
```

Tek kırmızı:

```text
tests/unit/gecmis-pipeline.test.js:283
_gmGroupHtml: ...
AssertionError: assert.ok(dun.includes('DÜN'))
```

Güncel main'de aynı test komutu:

```text
cd /home/melik/egesut-erp1
node --test tests/unit/*.test.js
main_exit=1
ℹ tests 796
ℹ pass 795
ℹ fail 1
```

Main'deki tek kırmızı da aynı `_gmGroupHtml` testidir. Target'ın 40 test farkı
yeni tarih-seçici test dosyalarından geliyor; target'taki kırmızı `js/gecmis.js`
değişikliğinden gelmiyor. Çıplak target komutunun bağımlılık eksikliği ayrıca
ölçülmemiş ortam sınırı olarak bırakıldı; kaynak kod sonucu kontrollü bağımlılık
yoluyla doğrudan ölçüldü.

## 3. DOĞRU — main ile birleşme

Komut:

```text
git merge-tree --write-tree 0601e63 agent/tarih-secici-standardi
a2e4ed2c9b779bec8f4a77db494da1d7494b41e1
merge_tree_exit=0
```

`git merge-base 0601e63 agent/tarih-secici-standardi` sonucu `621f12a`.
Sentetik birleşme ağacı çatışmasız oluştu. Main'in hedef dalın tabanından sonra
eklediği rapor dosyaları sentetik ağaçta korunuyor; örneğin
`reports/2026-09-13-{buzagi-51-arastirma,dogum-tarih-denetimi,kupe-degisim-adli,sahip-tablosu-karsilastirma,tarihe-git-altyapi}.md`
ve `reports/w3/*` ağacında kaldı.

## 4. DOĞRU — kapsam ve 27 dosya

```text
git diff --name-only 621f12a 46abbc8 | wc -l
27

goal write_manifest sayısı: 28
manifest_actual_diff:
tests/unit/tarih-guard.test.js

supabase/ değişen dosya: 0
migration adlandırılmış dosya: 0
js/gecmis.js değişen dosya: 0
git diff --check: exit 0
```

27 değişen dosyanın tamamı goal manifesti ve frontend/docs/test zarfı içindedir:

```text
.claude/reviews/2026-09-13-tarih-secici-f1-teslim.md
.claude/reviews/2026-09-13-tarih-secici-f2-teslim.md
.claude/reviews/2026-09-13-tarih-secici-f3-denetim.md
.claude/reviews/2026-09-13-tarih-secici-f3-teslim.md
.claude/reviews/2026-09-13-tarih-secici-f4-red-before.log
.claude/reviews/2026-09-13-tarih-secici-f4-teslim.md
.claude/reviews/2026-09-13-tarih-secici-luna-review.md
.claude/tasks/2026-09-13-tarih-secici-f1.md
.claude/tasks/2026-09-13-tarih-secici-f2.md
.claude/tasks/2026-09-13-tarih-secici-f3-denetim.md
.claude/tasks/2026-09-13-tarih-secici-f3.md
.claude/tasks/2026-09-13-tarih-secici-f4.md
.claude/tasks/2026-09-13-tarih-secici-luna.md
.harness/decisions/D-20260909-CANONICAL-DATE-PICKER.md
.harness/goals/2026/G-20260913-TARIH-SECICI.md
.harness/references/domain-rules.md
.harness/references/ui-map.md
.harness/reports/2026-09-13-tarih-secici-teslim.md
index.html
js/app.js
js/forms.js
js/tarih/tarih.js
js/ui.js
js/utils/handlers.js
tests/tarih-secici.spec.js
tests/unit/tarih-saf.test.js
tests/unit/vaka-toplu-ac.test.js
```

`tests/unit/tarih-guard.test.js` goal manifestinde beyan edilmiş fakat bu
pakette değiştirilmemiştir; bu bir kapsam taşması değil, manifestteki boş
kalemdir. `js/gecmis.js` hem diff dışıdır hem de bilinen kırmızı testin
kaynağıdır; Geçmiş davranışı bu pakette değiştirilmemiştir.

## 5. DOĞRU — lead luna'nın tek beyanı ve kabul kararı

Lead'in `BULGU-7` beyanı (DÜŞÜK): `tests/unit/tarih-saf.test.js` içindeki
`muhafizKaynagi` yorumları regex ile soyuyor; JavaScript string sınırlarını
lexical olarak çözmediği için string içinde saklanan `Date.now()` benzeri metin
statik muhafızı yanıltabilir. Paket raporu ayrıca isimsiz closure biçimindeki
gelecekteki bir kopyanın isim-beyaz-listesini aşabileceğini residual olarak
belirtiyor.

Bu, mevcut ürün yolunda çalışan bir tarih seçici kusuru değil, gelecekteki
statik guard'ın biçimsel sınırıdır. Kanıtlar: hedefte guard odak testi `40/40`
geçti; `rg` ile `eval(` ve `new Function(` bulunmadı; mevcut kaynakta tek
runtime date ataması ölçüldü. Bulguyu güvenlik/parser garantisi varmış gibi
sunmadan, düşük seviyeli ve raporda açıkça beyan edilmiş residual olarak kabul
ediyorum. Bu nedenle düzeltme kapısı açılmadı.

## 6. DOĞRU — `?v=` damgası

Komut:

```text
rg -o '\?v=[^"&[:space:]]+' index.html | sort | uniq -c
```

```text
     23 ?v=20260913-16
```

Tek değer `20260913-16`'dır: manifest satırı `index.html:11` ve 22 yerel
script satırı (`index.html:2221-2242`) aynı değeri kullanır. CSS bu sayfada
inline; ayrı yerel CSS dosyası veya ikinci `?v=` değeri yoktur.

## Sonuç

KABUL
