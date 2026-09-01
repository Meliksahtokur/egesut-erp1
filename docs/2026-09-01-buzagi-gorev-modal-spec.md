# Spec — Buzağı Bakım Görev Grubu: Modal'da Checkbox Tamamlama (Bölünmesiz)

> **Tarih:** 2026-09-01 · **Durum:** Taslak (kullanıcı onayı bekler)
> **Analiz:** `docs/2026-09-01-buzagi-gorev-modal-analiz.md` (kök neden kanıt zinciri)
> **Kapsam:** `m-task-det` modal'ı + `detayTamamla` akışı. DB şeması **değişmez**.

---

## 1. Problem (tek cümle)

Doğumla gelen `BUZAGI_BAKIM` ana görevinin modal'ında alt görevler tıklanamaz;
"✅ Tamamlandı" yalnızca ana görevi kapattığı için kalan 5-6 alt görev listede ayrı
kartlara bölünüyor.

## 2. Hedef davranış (user story)

Görev detay modal'ını açan kullanıcı:

1. **Alt görevleri checkbox ile işaretler** — her satır tıklanabilir (karttaki `st-check`
   görseliyle aynı dil); işaretleyince satır üstü çizilir, sayaç anında güncellenir (`2/6`).
2. **İşaretlemeden "tamamla" basarsa** tüm açık alt görevler + ana görev tek hamlede kapanır;
   buton etiketi bunu açıkça söyler: `✅ 6 alt görevle birlikte tamamla`.
3. **Kısmi işaretleme + "tamamla"** → kalan açık altlar da kapanır, ana görev kapanır,
   modal kapanır. Liste yenilenir; **grup kartı tamamen kaybolur**, hiçbir alt görev ayrı
   kart olarak görünmez (bölünme imkânsızlaşır).
4. Kart üzerindeki mevcut satır checkbox'ları (`toggleSub`) aynen çalışmaya devam eder;
   modal tekrar açıldığında sayaç doğru sayılır.

## 3. Davranış kuralları

| # | Kural |
|---|---|
| K1 | `td-subs` satırları tıklanabilir; tıklama = alt görev `tamamlandi` toggle (mevcut `toggleSub` semantiği: REST PATCH, `tamamlanma_tarihi` set/clear). Modal içi sayaç + buton etiketi senkron güncellenir. |
| K2 | `detayTamamla`, hedef görevin **açık alt görevi** varsa artık tek satır kapatmaz: önce tüm açık altlar, sonra ana görev kapanır (sıralı yazım; alt hata alırsa dur, toast ile bildir). |
| K3 | Ana görev kapanışı **daima** `gorev_tamamla` RPC'si ile olur (islem_log GOREV_TAMAMLA izi korunsun — mevcut `doneTask` yolu). Alt görev kapanışı REST PATCH kalabilir (stok/padok yan etkisi yok — analiz §3). |
| K4 | Alt görevi olmayan görevlerde modal **birebir bugünkü gibi** çalışır (etiket dahil). |
| K5 | Tip-agnostik: davranış `parent_id` varlığına bağlıdır, `BUZAGI_BAKIM` string'i koda yazılmaz — BESLEME/rapel gibi diğer gruplar da aynı iyileştirmeyi alır, davranışları değişmez (onlarda da bugün aynı bölünme potansiyeli var). |
| K6 | Modal router uyumu: üretilen HTML'de **HTML attribute onclick + dataset** (AGENTS.md kuralı — DOM property onclick yasak). |

## 4. Kapsam dışı (açık liste)

- `gorev_geri_al`'ın BUZAGI_BAKIM ana görevini bloklaması (rapel guard çakışması) — ayrı iş.
- Geçmiş görünümünde alt görevlerin gösterimi (analiz §3).
- Yeni RPC / DB migration — **yok**; canlı veri onarımı — **gerekmiyor** (0 bölünmüş grup).
- Alt görev ekleme/silme UI'ı.

## 5. Kabul kriterleri

1. Modal'da 6 satır tıklanabilir; işaretli satır `st-check done` görselli + üstü çizili; sayaç `N/6`.
2. "Tamamla" → açık tüm altlar + ana görev kapanır; toast `✅ N alt görev ve ana görev tamamlandı`;
   listede grup kartı yok, tek tek kart yok; `updateTaskBadge` şişmez.
3. Kısmi işaretleme senaryosu: 2/6 işaretli + tamamla → yalnız kalan 4 + ana kapanır.
4. Alt görevsiz görev modalı değişmez (regresyon).
5. `gorev_tamamla`'ya hâlâ sadece ana görev girer; altlar PATCH — islem_log'da 1 GOREV_TAMAMLA.
6. `npm run test:unit` → 344+ yeni testlerle geçer; yeni saf fonksiyonlar testli.
7. Impact-before-edit: dokunulan her sembol için `gitnexus_impact` raporu; commit öncesi
   `detect_changes` — beklenen kapsam: `openTaskDet`, `detayTamamla`, `toggleSub` komşuluğu.

## 6. Test stratejisi

- **Unit (node --test):** yeni saf render/etiket fonksiyonları (`tests/unit/` loader pattern'i,
  `ui-pure.test.js` komşuluğunda `buzagi-gorev-modal.test.js`).
- **Canlı doğrulama:** kullanıcı gerçek operasyonda (3 ve 500 buzağısının gerçek bakımı) —
  **canlı prod'a test verisi yazma yasağı** aynen geçerli; E2E stub'ları dışında otomatik
  canlı test yazılmaz (test stratejisi kararı, 2026-08-31).

## 7. Açık kararlar (kullanıcı onayı)

| Karar | Öneri | Alternatif |
|---|---|---|
| Alt görev toplu kapanışı nerede? | UI-only: `detayTamamla` sıralı PATCH + parent RPC (K3) | Yeni RPC `gorev_grup_tamamla(p_parent_id)` — atomik ama DB deploy ister |
| Onay adımı | Yok — buton etiketi yeterince açık (kompakt UI tercihi) | Confirm modal ("6 alt görev kapanacak") |
