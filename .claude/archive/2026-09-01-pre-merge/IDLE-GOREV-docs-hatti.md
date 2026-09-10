# İDLE GÖREV: Canlı-şema Doküman Hattı (Idle-A)

> Omurga: `/home/melik/egesut-erp1/.claude/plans/2026-08-31-fix-roadmap-ve-idle-omurgasi.md` §3/Idle-A.
> Bu worktree: `idle/docs-hatti` · Ana repo: `/home/melik/egesut-erp1` (main).

## Guardrail'ler (ZORUNLU)

- **Supabase'e hiçbir MCP çağrısı YOK** (okuma dahil). Tek şema kaynağın:
  `.claude/schema-snapshots/2026-08-31-live-schema-imzalar.md` (imza düzeyi, 195 fn + 44 tablo + 13 view + trigger envanteri)
  + repo'daki `supabase/migrations/` (gövde/niyet için).
- **Deploy yok, main'e push yok.** Sadece bu worktree'de commit.
- Kod değişikliği YOK (yalnızca `.claude/rpc-reference.md`, `.claude/domain-rules.md`, `.claude/ui-map.md`,
  `supabase/migrations/99999999999999_ground_truth.sql` ve idle raporu).
- Şüpheli bulguda kaynağı düzeltme — rapora yaz.
- Rapor: `.claude/idle-reports/<tarih>-docs-hatti.md` (ana repo working tree'sine DEĞİL, bu worktree'ye).

## Çıktılar (sırayla)

1. **`.claude/rpc-reference.md` sıfırdan regen** — snapshot'taki 195 fonksiyonun tamamı:
   imza + dönüş şekli + js çağrı yerleri (grep ile bul). Bilinen düzeltmeler:
   C1 `hayvan_ekle` p_padok_id, C2 `hayvan_guncelle` p_padok_id/p_kisir, C3 `add_drug_administration`
   p_drug_product_id/p_stok_id (p_drug_id yok), C4 `hekim_ekle` 2-param; `geri_al` tek girdiye indir;
   D1 notu ("online yazma RPC'dir; offline kuyruk replay db.from PATCH/POST kullanır"),
   D2 notu ("rpc() sarmalayıcısı ok:false'ı Error'a çevirir, err.data gövdeyi taşır");
   73 eksik RPC'yi ekle (docs denetim raporu §1.5 listesi: `.claude/idle-reports/2026-08-31-docs-tutarlilik.md`).
   Dosyayı **git'e işle** (şu an untracked).
2. **GT v5 AUDIT (regen değil)**: snapshot'taki imzalarla GT'deki CREATE FUNCTION imzalarını
   karşılaştır; sapmaları tablo yap (bilinenler: tohumlama_abort 2p→3p canlı, tohumlama_kaydet
   DEFAULT'lar, hekim_listesi CREATE'siz GRANT, stok_hareket.id text→uuid, tohumlama.id uuid).
   GT gövde-level regen DENETİMLİ oturum ister — sen sadece audit tablosu üret.
3. **`.claude/domain-rules.md`** — docs denetimi §2.2'deki 8 çelişki + §2.3'teki 8 bayatlığı düzelt
   (16 görev/d2·d25·d39/E Vitamini/Buzağı Padok/'Pasif'/islem_log-gorev_tipi listeleri/farm_id UUID).
4. **`.claude/ui-map.md` yeniden üret** — mevcut kod satırlarından (grep ile bölüm başları + aralıklar);
   memory notu: eski aralıklar ~2.8k satırlık dönemden, güvenme.

## Kabul Kriterleri

- rpc-reference: 195 fonksiyonun tamamı + her birinde en az bir js çağrı yeri veya "kullanılmıyor (cron/Edge/legacy)" notu
- GT audit tablosu: satır sayısı + hangilerinin denetimli regen gerektirdiği
- domain-rules: 16 düzeltme yapılmış, "hangi taraf doğru" gerekçeleriyle
- Worktree'de tek commit + rapor dosyası
