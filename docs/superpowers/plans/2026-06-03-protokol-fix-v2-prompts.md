# Protokol Fix v2 — DeepSeek TUI Batch Prompts

## Kullanım

Her batch için aşağıdaki prompt'u DeepSeek TUI'ye yapıştır. Batch tamamlanınca sonraki batch'e geç.

**Skill:** `/skill:executing-plans`
**Plan dosyası:** `/root/egesut-erp1/docs/superpowers/plans/2026-06-03-protokol-fix-v2.md`

## Durum

| Batch | Durum | Not |
|-------|-------|-----|
| **Batch 1** | ✅ TAMAMLANDI | Claude doğrudan deploy etti — DeepSeek BEGIN/COMMIT kaldırmadığı için migration başarısız olmuştu |
| **Batch 2** | Bekliyor | UI fix'leri |
| **Batch 3** | ✅ TAMAMLANDI | ground_truth sync — Claude doğrudan yaptı |

### Batch 1 Düzeltme Notu

Orijinal plan `gorev_log.id`'yi TEXT sanıyordu ama gerçekte UUID. Root cause:
- `_gorev_dinle` fonksiyonunda `v_gorev_id text` → UUID kolonu text ile karşılaştırılamaz
- Fix: `v_gorev_id uuid` yapıldı, deploy edildi
- `ileri_gebe_asi_tamamla` ve `gorev_geri_al`'daki `::uuid` cast'ları DOĞRUYDU — kaldırılmamalı

---

## Batch 2: UI Fixes (Task 5-7)

```
/skill:executing-plans

Plan dosyası: /root/egesut-erp1/docs/superpowers/plans/2026-06-03-protokol-fix-v2.md

Task 5-7'yi sırayla uygula. Bunlar UI fix'leri.

ÖNEMLİ BAĞLAM:
- Batch 1 (DB fixes) tamamlandı — uuid=text hatası çözüldü, scanner deploy edildi, backfill yapıldı
- gorev_log.id tipi UUID'dir (TEXT DEĞİL) — dikkat et
- js/api.js zaten güncellendi: DB_VER=21, TABLES'da 'uygulama_log' var

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
1. Edit öncesi MUTLAKA file_read ile dosyayı oku — dosyalar son commit'te değişmiş olabilir
2. _satirHtml fonksiyonu: satır gövdesine onclick="_showProtokolDetay(...)" ekle, buton container'a event.stopPropagation()
3. _showProtokolDetay ve _protoDetayHayvanGit FONKSİYONLARI: _showProtokolEkran'dan HEMEN SONRA, _ETKEN_FILTERE'den ÖNCE ekle
4. popstate handler: proto-detay-bs → protokol-bs → det sıralamasıyla kontrol et
5. Task 7'de loadDash() çağrılarını kaldır, yerine scanner refresh + badge güncelle + ekran yenile pattern'i koy
6. Her task sonrası commit+push: cd /root/egesut-erp1 && git add <files> && git commit -m "..." && git push origin main
7. Plandaki kodu BİREBİR kullan — yorum, değişken adı, style değiştirme
8. esc() fonksiyonu zaten mevcut — tanımlama, yeniden yazma, import yapma
9. fmtTarih() fonksiyonu zaten mevcut — tanımlama, yeniden yazma, import yapma

DOSYA YAPISI ÖNEMLİ — js/ui.js sırası:
  ~705: _showProtokolEkran (satır tıklama onclick eklenecek — Task 5)
  ~750: << _showProtokolDetay ve _protoDetayHayvanGit BURAYA EKLE — Task 5 >>
  ~752: _ETKEN_FILTERE (dokunma)
  ~761: _protokolUygula (dokunma)
  ~805: _protokolUygulaKaydet (Task 7 — loadDash yerine scanner refresh)
  ~828: _protokolDismiss (Task 7 — loadDash yerine scanner refresh)
  ~847: _protokolGeriAl (Task 7 — loadDash yerine scanner refresh)

SIRALAMA:
Task 5 → commit+push → Task 6 → commit+push → Task 7 → commit+push

Başla.
```

---

## Doğrulama (Batch 2 Bittikten Sonra)

```
Aşağıdaki kontrolleri yap:

1. UI fonksiyonları var mı:
   file_read("/root/egesut-erp1/js/ui.js")
   → _showProtokolDetay fonksiyonu var mı?
   → _protoDetayHayvanGit fonksiyonu var mı?
   → _satirHtml'de onclick="_showProtokolDetay" var mı?

2. popstate handler:
   file_read("/root/egesut-erp1/js/app.js")
   → proto-detay-bs kontrolü var mı?
   → protokol-bs display restore var mı?

3. İşlem sonrası:
   → _protokolUygulaKaydet'te loadDash() YOK, rpc('protokol_eksik_tara') VAR mı?
   → _protokolDismiss'te loadDash() YOK mı?
   → _protokolGeriAl'da loadDash() YOK mı?

4. Commit geçmişi:
   git log --oneline -5 ile 3 commit olmalı (Task 5 + 6 + 7)

Sonuçları raporla.
```
