# test-manifest-DONE — katalog v3 → tests/test-manifest.yaml üretimi

- Tarih: 2026-09-30 · Girdi: `docs/plans/2026-09-28-ovsync-takip-ekrani/test-senaryolari.md` (katalog sürümü 3, T-01..T-100)
- Çıktı: `tests/test-manifest.yaml` (63 260 bayt) · Kaynak dosyaya DOKUNULMADI
- Commit yok; /tmp'ye sabit dosya yok.

## 1. Toplam sayı

| İddia | Kanıt | Etiket |
|---|---|---|
| 100 kayıt (yaml.safe_load) | `python3 -c "import yaml…; print(len(d))"` → `100` | CONFIRMED |
| 100 `- scenario:` satırı | `grep -c '^ - scenario:'` → `100` | CONFIRMED |
| T-01..T-100 tam, duplikatsiz, sıralı | manifest id listesi == beklenen liste → `True` | CONFIRMED |
| Manifest id kümesi ≡ katalog `### T-` başlıkları | iki `grep -o | sort | diff` → `FARK YOK`; katalog başlık sayısı `100` | CONFIRMED |
| Kaynak dosya değişmedi | `git status --porcelain <test-senaryolari.md>` → boş | CONFIRMED |
| Tüm kayıtlarda 10 zorunlu alan dolu; `max_self_repair=2` | alan taraması → eksik `YOK`, sapma `YOK` | CONFIRMED |

## 2. Risk dağılımı (manifest dosyasından sayıldı — CONFIRMED)

| Risk | Adet | Senaryolar |
|---|---|---|
| R6 (açık sözleşme) | 2 | T-87, T-93 |
| R5 (yarış/kilit/deadlock) | 4 | T-72, T-73, T-94, T-100 |
| R4 (ACL/anon/EXECUTE/imza/bulk/preflight) | 4 | T-60, T-77, T-86, T-90 |
| R3 (atomik/transaction/tek işlem/XOR/guard/RAISE) | 13 | T-04, T-06, T-08, T-09, T-11, T-18, T-20, T-24, T-74, T-95, T-96, T-97, T-98 |
| R2 (UI-PW + DB-SQL birlikte) | 37 | T-01..T-03, T-12, T-15, T-16, T-19, T-21, T-25, T-26, T-28, T-30, T-32, T-34, T-37..T-40, T-42..T-44, T-46, T-56, T-58, T-59, T-63..T-68, T-70, T-71, T-75, T-78, T-79, T-89 |
| R1 (tek katman) | 38 | T-05, T-07, T-10, T-13, T-14, T-17, T-22, T-23, T-27, T-29, T-31, T-33, T-35, T-36, T-41, T-45, T-47..T-55, T-57, T-61, T-62, T-69, T-76, T-80..T-84, T-91, T-92, T-99 |
| R0 (yalnız UNIT/helper) | 2 | T-85, T-88 |
| **Toplam** | **100** | |

## 3. Owner dağılımı (kural: R5/R6→glm; R3/R4→glmf+review; gerisi→glmf)

| Owner | Adet | Kaynak riskler | Tutarlılık kontrolü |
|---|---|---|---|
| glm | 6 | R5+R6 | risk-owner tutarsız kayıt: `YOK` (CONFIRMED) |
| glmf+review | 17 | R3+R4 | |
| glmf | 77 | R2+R1+R0 | |

## 4. target_file dağılımı (CONFIRMED)

| Hedef | Adet | Not |
|---|---|---|
| tests/sql/ovsync_takip_test.sql | 42 | ağırlıkla DB-SQL |
| tests/e2e/ovsync-takip.spec.js | 41 | ana dosya; aile adı bölüm yorum satırında (A..S) — `-s2/-s3` sonek YOK |
| runs/2026-09-28-ovsync-takip/ui-test-listesi.md | 10 | insan-ui taşıyanlar: T-05, T-14, T-20, T-27, T-31, T-33, T-35, T-67, T-69, T-76 |
| tests/unit/ovsync-takip.test.js | 4 | T-62, T-85, T-88, T-94 |
| tests/concurrency/ovsync-takip-t72b.mjs | 3 | T-72, T-73, T-87 (R5/R6 DB yarışı) |

Hedef belirleme politikası (uygulanmış kural): insan-ui → liste; DB-yarışı (T-72/73/87) → t72b; aksi hâlde kataloğun **ilk-listelenen katmanı** "ağırlık" sayılır (ör. T-08 "DB-SQL (birincil) + PW" → sql; T-11 "UI-PW + DB-SQL" → e2e).

## 5. Şüpheli / yorum-kararı senaryolar (OBSERVED — eşleme kararları)

1. **T-17** — gövdede "yarım/**yarış**" geçiyor ama özne iki UI gerekçe metninin basımı (DB yarışı değil); ayrıca çözülmüş S-1 notu hâlâ gövdede → risk R1, `escalate_if: [spec_conflict]`.
2. **T-31** — "nihai metin planla kesinleşir, İNCELE" notu taşıyor → risk R1, `escalate_if: [spec_conflict]`.
3. **T-87, T-93** — gerçek **açık sözleşme** satırları (fail-closed BLOKE / satır JSON alan adı P3b'de sabitlenecek) → R6, owner glm, `escalate_if: [spec_conflict]`.
4. **T-74** — gövdede "kilit sırası değişmez" geçiyor; ama testin öznesi üç-dal guard/RAISE sözleşmesi → **R3** verildi (R5 değil). Kilit-sırası ölçümü zaten T-87'nin işi.
5. **T-92** — "kilitsiz keşif → hayvan NKU" H4 uygulama-deseni anlatımı; testin öznesi tanıdan bağımsız kapı redi → **R1** verildi.
6. **T-58** — "tazeleme yarışını önle" metodoloji notu; özne sayı tutarlılığı → **R2**.
7. **UI "🔒 kilitli kart"** (T-14, T-17, T-33) — "kilit" kelimesi geçer ama hard-block göstergesidir; **R5'e sayılmadı** (kurallar DB kilidi/yarışı demektir).
8. **Merdiven-aralığı** — unit+db-sql (T-61, T-62) ve ui-pw+unit (T-84) kombinasyonlarının birebir kovası yok → R1'e düşürüldü; T-85/T-88 "helper/formatter" gerekçesiyle R0.
9. **T-94** — başlıkta 40P01/55P03 özne → kural sırasına göre **R5** (owner glm); ama katman UNIT+PW → hedef `tests/unit/ovsync-takip.test.js` (hedef katmandan, riskten değil).
10. **T-90** — "bugün eski imza canlı → assertion RED (beklenen)" özel zemini oracle'a yazıldı; ölçülmüş demo zeminleri (PGRST202/404, 42501) katalogdaki OBSERVED etiketiyle taşındı.

Eşlenemeyen senaryo: **YOK** (100/100 eşlendi — CONFIRMED).

## 6. Kural-dışı üretim notları

- Oracle maddeleri senaryo metninden kısaltıldı; davranış uydurulmadı. Ters-kanıt satırları olumsuz beklenti olarak yeniden ifade edildi (ör. "X yok" → "X olmamalı").
- `escalate_if` yalnız 4 senaryoda dolu: T-17, T-31, T-87, T-93; diğer 96'da boş liste.
- Manifest başındaki yorum bloğu risk/target politikasını ve "UI kilitli ≠ R5" yorumunu belgeler.

## 7. Bitirme kapısı — kanıt özeti

- `verification-before-completion-obra` skill'i yüklendi; tüm iddialar yukarıdaki §1–§4'teki taze koşum çıktılarıyla etiketli (CONFIRMED).
- yaml modülü mevcuttu; regex-fallback gerekmedi (ikisi de koşuldu: 100 == 100).
