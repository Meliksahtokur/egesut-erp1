# W1-fix — luna F3: SQL fixture'a P1 gerçek-veri blokları

Bağımsız luna review (`.claude/reviews/2026-09-11-pedigree-p2-lead-review.md`, F3):
fixture'ın tüm iddiaları `v_*` sentetik graf üzerinden; goal G3 "P1'in 166 node/59 edge
verisi üzerinden focus'lu alt graf" ölçütü sentetik bloklarla karşılanmıyor (166/59
yalnız yorum satırında). Tek bulgu, tek dar iş.

## Düzeltme

`tests/sql/pedigree_projection_rpc_test.sql`'e **gerçek-veri blokları** ekle (salt
okunur — ROLLBACK kapsamı gerekmez, veri YAZMA):

1. Canlı grafın boyutunu doğrula: `pedigree_graph` düğüm/kenar sayısı == 166/59
   (esitlik değilse SKIP değil FAIL — ama dikkat: demo PAYLAŞIMLI, başka aktör veri
   ekleyebilir; eşitlik kırılgansa ">= 166 düğüm ve >= 59 kenar + sentetik olmayan
   v_* dışı id'ler mevcut" biçiminde sağlamlaştır, gerekçeyi yorumla yaz).
2. Gerçek bir odak hayvan üzerinden projeksiyon: kupe_no'su fixture içinden
   **sorgulanarak** seçilen (hardcode id YOK — id çürüğüne karşı) en az bir gerçek
   hayvanın alt grafiği: dönüş geçerli kontrat (focus=odak, farm düğümlerde
   farm_animal_id NOT NULL, kenar yönü parent→child), depth meta clamp ile uyumlu.
3. Gerçek veride dedup/paylaşılan ata: iki gerçek kardeşin ortak atası tek düğüm
   olarak döner (id sayımıyla iddia).

Sentetik bloklar (A-L) dursun — egzotik topoloji (döngü, truncation) ancak sentetikle
üretilir. Yeni blokları M-N (veya devamı) harfleriyle ekle, TESTDONE özetine kat.

## Kabul

- Fixture demo'da koş → tüm bloklar (A-L + yeniler) yeşil; komut + çıktı özeti teslim notunda.
- PROD YASAK. Sadece `tests/sql/pedigree_projection_rpc_test.sql` dosyası değişir.

## Teslim

- `idle/pedigree-p2-W1` üzerine yeni commit; şerit kuralı (subagent review notu) aynen.
- Kırıntı: `/home/melik/egesut-erp1/.crumbs/pedigree-p2-w1.jsonl`.
