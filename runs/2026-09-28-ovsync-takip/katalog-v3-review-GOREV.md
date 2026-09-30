# GOREV — katalog v3 review (ss-lead-codex, luna/max)

- **Koltuk:** ss-lead-codex — **luna/max profil BEKLENİR** (tur başında profilini doğrula, raporuna yaz; düşük profilde çalıştıysan bildir).
- **GÖREV zarfı:** bu dosya · **DONE:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/katalog-v3-review-DONE.md`
- Worktree: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip` (tüm yollar buna göre)

## İlk iş (sahip kuralı)

`/home/melik/.claude/skills/using-superpowers-obra/SKILL.md` ve `references/codex-tools.md` oku, uygula.

## Görev: senaryo kataloğu v3 review — kod + içerik, TEK TUR, hızlı

Dün teslim edilen katalog v2'ye (94 senaryo) bugün kapsam-açığı turuyla **T-95..T-100 eklendi** (katalog v3, toplam 100). Bu turların review'unu yapıyorsun. Review işin kendisinden büyük olamaz: tek tur, bulgu listesi + hüküm.

### Odak A — T-95..T-100 (bugün yazılanlar; katalog ~satır 795–843)

Her yeni senaryo için:
1. **Plan sadakati:** dayandığı plan maddesi gerçekten bunu mu söylüyor? (T-95: P2b seçim uzayı; T-96: P2b XOR guard #9; T-97: P2b #6 + MK9-K bayrak; T-98: P2b Boş-düzeltme koşul seti; T-99: P3a geri-al; T-100: P3a MK9-K bayrak-bağımsızlık + H3)
2. **Hata kodları birebir mi:** `TAKIP_YENIDEN_SECILEMEZ`, `SECIM_TANIMSIZ`, `GIRIS_CIFT_ANLAMLI`, `MUAYENE_GOREV_TIPI_UYUMSUZ`, `OZELLIK_KAPALI`, `BOS_DUZELTME_KOSUL` — plan gövdesindeki yazımla eşleşiyor mu?
3. **BEKLENEN sonuçlar** planın kabul ölçütlerinden türetilmiş mi; uydurma var mı?
4. **Çakışma/çiftleme:** T-01..T-94'teki hangi senaryolarla örtüşüyor, gereksiz çift var mı?

### Odak B — genel bütünlük

- 100 başlık iddiası ve T-01..T-100 sürekliliği (grep ile doğrula)
- Sürüm 3 başlık notu ve §S bölüm yerleşimi
- Üç düzeltilmiş sayı cümlesi (DONE §2, katalog satır ~4, HANDOFF satır ~7) — kalıntı bayat "96" var mı?
- Kapsam matrisi + kapsam dışı listesi (B9, Faz 2 vb.) tutarlı mı?

### Kaynaklar (mutlak)

- Katalog: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/test-senaryolari.md`
- Plan v7: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md` (P2b ~satır 279+, P3a ~satır 378+, KATALOG GÜNCELLEME ~satır 852+)
- Spec: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/design.md` §10c–§10h
- Kapsam turu raporu (dayanak): `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/katalog-kapsam-DONE.md`

### Hüküm kuralları

- Her bulgu `dosya:satır` kanıtı taşır; **hüküm dosyasız veya kaynakla çelişen bulgu RED sayılmaz** — kanıtlı düzeltme-zorlaması gönderilir.
- Bulgu sınıfları: KRİTİK / ÖNEMLİ / MİNÖR. Final hüküm: KABUL ya da DÜZELTME (KRİTİK varsa DÜZELTME).

## Yazma manifesti (TEK-YAZICI)

- **YALNIZ** `runs/2026-09-28-ovsync-takip/katalog-v3-review-DONE.md` yazabilirsin.
- Katalog dahil diğer HER dosya okuma-only. `plan.md`, `design.md`, `.harness/`, `.ss/`, `.crumbs/` dokunulmaz. Commit/merge/push YASAK. `/tmp`'ye sabit dosya YOK.

## DONE formatı

1. Profil doğrulama satırı (luna/max görüldü mü)
2. Odak A bulguları (T-95..T-100 tablo: plan sadakat / kod eşleşme / BEKLENEN / çakışma)
3. Odak B bulguları
4. Bulgu listesi (KRİTİK/ÖNEMLİ/MİNÖR + kanıt)
5. **HÜKÜM: KABUL / DÜZELTME** (tek satır, net)

DONE'ı yazınca turu bitir; pane'de tek satır bırak: `REVIEW-BITTI: <hüküm>`.
