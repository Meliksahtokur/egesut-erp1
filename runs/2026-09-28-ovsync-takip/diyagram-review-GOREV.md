# GOREV — T-95..T-100 akış diyagramları review (ss-lead-codex, luna/max)

- **Koltuk:** ss-lead-codex — **luna/max profil BEKLENİR** (tur başında doğrula, rapora yaz).
- **GÖREV zarfı:** bu dosya · **DONE:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/diyagram-review-DONE.md`
- Worktree: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip`

## İlk iş (sahip kuralı)

`/home/melik/.claude/skills/using-superpowers-obra/SKILL.md` ve `references/codex-tools.md` oku, uygula.

## Görev: diyagram review — TEK TUR, hızlı

Hedef: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/diyagramlar.md` — 6 mermaid flowchart (T-95, T-96, T-97, T-98, T-99, T-100).

### KRİTİK BAĞLAM — katalog review'dan sonra DÜZELTİLDİ

Diyagramlar, katalogdaki şu düzeltmelerden ÖNCE üretilendi. Katalog `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/test-senaryolari.md` artık düzeltilmiş haliyle OTORİTE:

1. **T-97:** ön koşulda TAM `p_tohumlama_id` (Bekliyor tohumlama) var; tüm adımlar aynı kimlikle; red bayrak kapısından gelir, `GIRIS_CIFT_ANLAMLI` beklenmez.
2. **T-98:** fixture (a) izinli red kümesi **{`TOH_SONUCLU`, `BOS_DUZELTME_KOSUL`}`**; fixture (b) deterministik `treatment_date`/`created_at` sırası.
3. **T-100:** `pg_get_functiondef` kaynak kanıtı adımı (H3) eklendi.

Diyagramların bu üç noktayla uyumu AYRICA değerlendirilecek; eksikse bulgu olarak yaz (düzenleme senden istenmeyecek — bulgu yeter).

### Odak A — blok başına değerlendirme (6 blok)

1. **Kapsama:** diyagram, katalog senaryosunun tüm Adım + BEKLENEN dallarını gösteriyor mu (eksik dal = bulgu)?
2. **Doğruluk:** fonksiyon adları, hata kodları, tablo/tetikleyici adları plan v7 (`/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md` P2b ~satır 279–344, P3a ~satır 378–399) ve katalogla birebir mi? Uydurma düğüm/dal var mı?
3. **Mermaid kalitesi:** katman alt grafileri tutarlı mı, ok yönleri anlamlı mı, classDef kırmızı/yeşil ayrımı doğru yerde mi?

### Odak B — bütün

- Başlık/kaplama notları senaryo ile eşleşiyor mu?
- Bloklar arası tutarlılık (T-97 ile T-100'ün `OZELLIK_KAPALI` kesişimi vb.).

### Hüküm kuralları

- Her bulgu `dosya:satır` kanıtı taşır; hükümsüz veya kaynakla çelişen bulgu RED sayılmaz.
- Sınıflar: KRİTİK / ÖNEMLİ / MİNÖR. Final hüküm: KABUL ya da DÜZELTME.

## Yazma manifesti (TEK-YAZICI)

- **YALNIZ** `runs/2026-09-28-ovsync-takip/diyagram-review-DONE.md`.
- Diyagram dosyası, katalog, plan dahil diğer HER dosya okuma-only. Commit/merge/push YASAK.

## DONE formatı

1. Profil doğrulama satırı
2. Blok tablosu: T-95..T-100 → kapsam/ doğruluk/ mermaid (✔/✗ + tek satır)
3. Yukarıdaki 3 düzeltme noktasıyla uyum tablosu (T-97/T-98/T-100)
4. Bulgu listesi (sınıf + kanıt)
5. **HÜKÜM: KABUL / DÜZELTME** (tek satır)

Pane'de tek satır bırak: `DIYAGRAM-REVIEW-BITTI: <hüküm>`.
