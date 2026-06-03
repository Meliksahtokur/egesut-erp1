# Protokol Fix v2 — DeepSeek TUI Batch Prompts

## Kullanım

Her batch için aşağıdaki prompt'u DeepSeek TUI'ye yapıştır. Batch tamamlanınca sonraki batch'e geç.

**Skill:** `/skill:executing-plans`
**Plan dosyası:** `/root/egesut-erp1/docs/superpowers/plans/2026-06-03-protokol-fix-v2.md`

---

## Batch 1: DB Fixes (Task 1-4)

```
/skill:executing-plans

Plan dosyası: /root/egesut-erp1/docs/superpowers/plans/2026-06-03-protokol-fix-v2.md

Task 1-4'ü sırayla uygula. Bunlar DB fix'leri:

GÖREV ÖZETİ:
- Task 1: js/api.js'de TABLES dizisine 'uygulama_log' ekle, DB_VER 20→21 yap
- Task 2: Migration dosyası oluştur — ileri_gebe_asi_tamamla'daki ::uuid cast'ı kaldır
- Task 3: Aynı migration'a backfill SQL'leri ekle (etken_kod + dismiss)
- Task 4: Aynı migration'a scanner fix ekle (DISTINCT ON + E_VIT) + index'ler + DEPLOY ET + TEST ET

ARAÇLAR:
- file_read: dosya okumak için (edit öncesi ZORUNLU oku)
- file_write: dosya yazmak/patch etmek için
- supabase_migrate: SQL'i Supabase'e deploy etmek için (Management API)
- supabase_rpc: test için (protokol_eksik_tara çağır)
- supabase_query: test için (protokol_dismiss, gorev_log sorgula)

KRİTİK KURALLAR:
1. Edit öncesi MUTLAKA file_read ile dosyayı oku
2. Task 2-3-4 SQL'leri TEK migration dosyasına yazılır: 20260603000005_protokol_fix_v2.sql
3. supabase_migrate çağrısında BEGIN/COMMIT satırlarını ÇIKAR — tool zaten transaction kullanır
4. Her commit sonrası git push origin main
5. ground_truth.sql'e DOKUNMA — o Task 9'da yapılacak
6. Referans: file_read("/root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql") — ileri_gebe_asi_tamamla fonksiyonu satır ~6356

SIRALAMA:
Task 1 → commit+push → Task 2 → Task 3 → Task 4 (deploy+test) → commit+push

Başla.
```

---

## Batch 2: UI Fixes (Task 5-7)

```
/skill:executing-plans

Plan dosyası: /root/egesut-erp1/docs/superpowers/plans/2026-06-03-protokol-fix-v2.md

Task 5-7'yi sırayla uygula. Bunlar UI fix'leri:

GÖREV ÖZETİ:
- Task 5: Protokol ekranında satır tıklama → iş detay bottom-sheet aç + hayvan kartına navigasyon
- Task 6: popstate handler'a protokol ekran stack desteği ekle + pushState
- Task 7: İşlem sonrası (uygula/dismiss/geri al) ekranları kapatma yerine yerinde güncelle

ARAÇLAR:
- file_read: dosya okumak için (edit öncesi ZORUNLU oku)
- file_write: dosya yazmak/patch etmek için

DEĞİŞECEK DOSYALAR:
- js/ui.js — Task 5 + 6 (pushState) + 7
- js/app.js — Task 6 (popstate handler)

KRİTİK KURALLAR:
1. Edit öncesi MUTLAKA file_read ile dosyayı oku
2. _satirHtml fonksiyonu: satır gövdesine onclick="_showProtokolDetay(...)" ekle, buton container'a event.stopPropagation()
3. _showProtokolDetay ve _protoDetayHayvanGit FONKSİYONLARI: _showProtokolEkran'dan HEMEN SONRA, _ETKEN_FILTERE'den ÖNCE ekle
4. popstate handler: proto-detay-bs → protokol-bs → det sıralamasıyla kontrol et
5. Task 7'de loadDash() çağrılarını kaldır, yerine scanner refresh + badge güncelle + ekran yenile pattern'i koy
6. Her task sonrası commit+push
7. Plandaki kodu BİREBİR kullan — yorum, değişken adı, style değiştirme

SIRALAMA:
Task 5 → commit+push → Task 6 → commit+push → Task 7 → commit+push

Başla.
```

---

## Batch 3: ground_truth Sync (Task 9)

```
/skill:executing-plans

Plan dosyası: /root/egesut-erp1/docs/superpowers/plans/2026-06-03-protokol-fix-v2.md

Task 9'u uygula — ground_truth.sql sync:

GÖREV ÖZETİ:
- ileri_gebe_asi_tamamla: 2 yerde p_gorev_id::uuid → p_gorev_id değiştir
- protokol_eksik_tara: Task 4'teki düzeltilmiş versiyonla değiştir (DISTINCT ON + E_VIT fix)
- Diğer yeni objelerin (uygulama_log, protokol_dismiss, _etken_kod_bul, _gorev_dinle, hizli_uygulama, trigger'lar) ground_truth'ta mevcut olduğunu doğrula

ARAÇLAR:
- file_read: ground_truth dosyasını oku (büyük dosya ~6500+ satır)
- file_write: değişiklikleri yaz

KRİTİK KURALLAR:
1. SADECE ground_truth.sql'i değiştir — başka dosyaya dokunma
2. Dosya çok büyük — ilgili fonksiyonları bul ve sadece onları değiştir
3. Yeni migration'daki (20260603000005) SQL'i ground_truth'a tekrar yazmaya GEREK YOK — sadece mevcut fonksiyonları güncelle
4. Commit + push

Başla.
```

---

## Doğrulama (Tüm Batch'ler Bittikten Sonra)

```
Aşağıdaki kontrolleri yap:

1. IDB Fix:
   file_read("/root/egesut-erp1/js/api.js") → DB_VER=21 ve TABLES'da 'uygulama_log' var mı?

2. uuid Fix:
   supabase_rpc("ileri_gebe_asi_tamamla", '{"p_gorev_id":"test-nonexistent"}')
   → "Görev bulunamadı" dönmeli (uuid=text HATASI DEĞİL)

3. Scanner:
   supabase_rpc("protokol_eksik_tara", "{}")
   → Duplikasyon yok, eski doğumlar dismiss edilmiş

4. Dismiss backfill:
   supabase_query("protokol_dismiss", "", "count", 100)
   → Kayıt var

5. UI: git log --oneline -5 ile commit'leri doğrula

Sonuçları raporla.
```
