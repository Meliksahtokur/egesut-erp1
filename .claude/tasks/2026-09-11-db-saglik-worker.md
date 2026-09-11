# Worker görevi — Bağımsız DB sağlık taraması (research — bulgu raporu, kod YOK)

Rol sözleşmen: `/home/melik/tools-bank/.superset/roles/worker.md` — bu bir
`research` tipi görevdir: **dosya değiştirme** (yalnız rapor dosyanı yaz),
bulgu raporu üret, karar YOK. Owner talebi (2026-09-11): "db'de kırılan
bozulan başka bir şey var mı bağımsız araştırılsın."

## Yöntem

1. **Anomali sınıflarını koddan türet** (ölçmeden iddia yazma; her sınıf için
   "hangi tablo/IPC tutarsızlığı" + probe SQL yaz):
   - yetim/geçersiz referanslar (v_orphan_gorev var — kullan; ref_tablo/ref_id
     hedefi olmayan islem_log satırları; anne_id'si olmayan hayvan çözümleri)
   - takılı kalan görevler (eski hedef_tarih + tamamlandi=false + iptal=false
     dağılımı; DÜN/gebe aşı sınıfları ayrı)
   - çift uygulamalar (907 vakası genel: aynı hayvan+etken/stok N dakika
     penceresi; N'i savunarak seç)
   - stok tutarsızlığı (negatif kalan; stok_hareket toplamı ↔ stok.miktar)
   - geri_alma yarım kalmaları (geri_alma_tarihi dolu ama bağlı satır aktif;
     snapshot boş; geri_al sonrası stok dönmemiş)
   - protokol hayaletleri (protokol_instance_id NULL/ölü beklentiler;
     vaccination_log ↔ uygulama_log çift-yazı sisteminin aksayanları)
   - tarih anomalileri (gelecek tarihli işlemler; dogum.tarih vs hayvan
     dogum_tarihi çelişkileri — pedigree P1 raporundaki 2 maternal blocker
     HARİÇ, biliniyor)
2. **Demo'da koş** (worktree .env: SUPABASE_DEMO_*; transactional BEGIN/ROLLBACK
   desenli salt-okunur sorgular). Demo verisi bayat olabilir — bulguları
   "demo anlık görüntüsü" olarak etiketle.
3. **PROD ölçümü gerekliyse:** raporuna `## Root'a: PROD probe istekleri`
   bölümüne koy (salt-okunur sorgular) — root koşar, çıktıyı ss-answer ile
   döner. PROD'a KENDİN bağlanma; yazma ZERRO.
4. BUGS.md'deki bilinen SMELL'leri tekrar keşfetme — kontrol listesi olarak
   kullan, YENİ sınıf ara.

## Teslim (dalına commit'le)

`.claude/idle-reports/2026-09-11-db-saglik-taramasi.md`:
- Anomali sınıfı tablosu: sınıf | probe SQL | demo sonucu | PROD gerekli mi
- Her bulgu: satır sayısı + örnek satır (kimlik) + önerilen düzeltim sınıfı
  (data-fix / kod / izle) — **düzenleme yapma**
- PROD probe istekleri bölümü
- "Bulgu yok" da geçerli cevaptır — bulgu uydurma.

## ŞERİT KURALI (owner, 2026-09-11)

Teslimden ÖNCE builtin subagent review koştur (bulgu/`bulgu yok` notu raporda).
