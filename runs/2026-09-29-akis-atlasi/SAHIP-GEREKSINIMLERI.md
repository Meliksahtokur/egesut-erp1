# Akış atlası — sahip gereksinimleri

Bu iş ovsync-takip SONRASI ayrı iştir. Başlarken bu dosya + `ui-flow-atlas-research-2026-09-29/SENTEZ.md` okunur.

## G1 (sahip, 2026-09-29) — Mantığı çizen LLM katmanı + gerçek PNG'ler
Araştırmanın önerdiği trace-first katman (Playwright trace/HAR/dialog/IDB diff + plpgsql_check/pg_trigger/cron.job + GitNexus) "fena değil" ama YETMEZ. Ek olarak:
1. **Mantığı çizen LLM:** kanıt dosyalarını (flow.json/evidence) okuyup akışın iş mantığını anlatan ve diyagramını çizen katman — dallar, koşullar, "bu görevi kim üretir" sorusu.
2. **Gerçek PNG'ler:** her adımın gerçek ekran görüntüsü (demo tarayıcıdan), tıklanan öğe işaretli — adım adım görsel akış.
3. **Çizimler:** mantık diyagramları render edilmiş görsel olarak (PNG), yalnız `.mmd` kaynağı değil.

## G2 (sahip, 2026-09-29) — Tüketici AJANLARDIR; her katman ölçümle yerini kazanır
"Sadece benim dememle olmaz; bunlar ajanların işine yaramalı, onlar için üretiliyor, benim için değil."
- Atlasın birincil okuyucusu kodlama ajanlarıdır (plan/spec/review/test koltukları). İnsan görünümü yan üründür.
- G1'deki her katman (LLM mantık anlatımı, adım PNG'leri, render çizimler) ancak **ajan görevinde ölçülen fayda** gösterirse atlasa girer; göstermezse düşer.
- Kabul ölçümü (pilotun parçası): gerçek geçmiş kaçaklardan türetilmiş soru seti (ör. "GEBELIK_KONTROL'ü kim üretir?", "bu tıklama hangi `confirm()`'dan geçer?", "X RPC'si değişirse hangi ekran etkilenir?"). Aynı ajan, aynı sorular, kademeli girdi:
  (a) yalnız kod + GitNexus → (b) + kanıt JSON'u → (c) + LLM mantık anlatımı → (d) + PNG/çizim.
  Ölçüt: doğru cevap oranı (kaynaktan doğrulanır), harcanan token, süre. Bir kademe doğruluğu artırmıyor ya da token maliyetini haklı çıkarmıyorsa o katman atlasa girmez.
- Biçim önceliği: makine-okunur (JSON/YAML) birincil; PNG yalnız DOM'un taşımadığı bilgi (yerleşim, görsel durum, örtüşen modal) için aday — görüntü tokeni pahalıdır.

## Mimar notu (yön önerisi, sahip onayı bekler)
- Kanıt katmanı otoritedir; LLM yalnız anlatır/çizer. LLM'in çizdiği her kenar bir kanıt kimliğine (trace adımı, HAR isteği, SQL sorgusu, GitNexus yolu) bağlanır; kanıtsız kenar "çıkarım" olarak ayrı stilde gösterilir.
- PNG'ler Playwright trace'in adım ekran görüntülerinden türetilir (ek koşum gerekmez); işaretleme adım seçicisinden.
- Çizim/mockup işi Claude alt-ajanına değil glm-max lead'e (kota kuralı, 2026-09-28).
- Pilot: tohumlama → gebelik kontrol üreticileri (SENTEZ §1 günlük pilot) — ovsync-takip uygulandıktan sonra §10d doğrulaması da olur.
